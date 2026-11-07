// The Connect server over HTTP/2. The gRPC engine in `server/` is built around gRPC's framing
// and trailers, so this is its own driver: it moves the same `connect` dispatch over HTTP/2
// frames, with the HPACK codec and the frame codec moonhttp provides. A connection is one
// stream at a time here, because a Connect call's body is read whole before it is dispatched.
//
// The windows are opened wide at the start (a SETTINGS and one WINDOW_UPDATE) rather than
// tuned per message: a request is read to its end before anything is answered, so a peer that
// sends a large body must not be stopped halfway.

///|
/// The window this driver opens for itself on each connection: 16 MiB, comfortably past the
/// largest message a Connect call is likely to carry.
let h2_window : Int32 = 16 * 1024 * 1024

///|
/// One call in flight on an HTTP/2 connection.
priv struct H2Call {
  id : Int32
  block : Buffer
  mut headers : Array[@header.Header]
  body : Buffer
  mut window : Int32
  mut started : Bool
}

///|
fn H2Call::new(id : Int32, window : Int32) -> H2Call {
  { id, block: Buffer(), headers: [], body: Buffer(), window, started: false, }
}

///|
/// Drive one HTTP/2 connection that speaks Connect. `preface` is the 24 octets already read
/// from the socket.
async fn serve_h2_connection(
  conn : @tcp.Conn,
  engine : @connect.Server,
  preface~ : Bytes,
) -> Unit {
  ignore(preface)
  let decoder = @hpack.Decoder::new()
  let encoder = @hpack.Encoder::new()
  // Our SETTINGS, then the connection-level window, opened before the peer sends a body.
  conn.write(
    @http2.Frame::Settings(
      params=[(@http2.settings_initial_window_size, h2_window)],
      ack=false,
    ).encode(),
  )
  conn.write(
    @http2.Frame::WindowUpdate(stream_id=0, increment=h2_window - 65535).encode(),
  )
  let calls : Map[Int32, H2Call] = Map([])
  let writes : @async.Mutex = @async.Mutex::Mutex()
  for ;; {
    let frame = read_frame(conn) catch { _ => break }
    match frame {
      @http2.Frame::Settings(ack~, ..) =>
        if !ack {
          conn.write(@http2.Frame::Settings(params=[], ack=true).encode())
        }
      @http2.Frame::Ping(payload~, ack~) =>
        if !ack {
          conn.write(@http2.Frame::Ping(payload~, ack=true).encode())
        }
      @http2.Frame::Headers(
        stream_id~,
        fragment~,
        end_stream~,
        end_headers~,
        ..
      ) => {
        let call = match calls.get(stream_id) {
          Some(c) => c
          None => {
            let c = H2Call::new(stream_id, h2_window)
            calls[stream_id] = c
            c
          }
        }
        call.block.write_bytes(fragment)
        if end_headers {
          let decoded : Array[@header.Header] = decoder.decode(
            call.block.to_bytes(),
          ) catch {
            _ => []
          }
          call.headers = decoded
        }
        if end_stream {
          answer_h2(conn, engine, encoder, call) catch {
            _ => ()
          }
          calls.remove(stream_id)
        }
      }
      @http2.Frame::Continuation(stream_id~, fragment~, end_headers~) =>
        match calls.get(stream_id) {
          Some(call) => {
            call.block.write_bytes(fragment)
            if end_headers {
              let decoded : Array[@header.Header] = decoder.decode(
                call.block.to_bytes(),
              ) catch {
                _ => []
              }
              call.headers = decoded
            }
          }
          None => ()
        }
      @http2.Frame::Data(stream_id~, data~, end_stream~, ..) =>
        match calls.get(stream_id) {
          Some(call) => {
            call.body.write_bytes(data)
            if end_stream {
              answer_h2(conn, engine, encoder, call) catch {
                _ => ()
              }
              calls.remove(stream_id)
            }
          }
          None => ()
        }
      @http2.Frame::WindowUpdate(stream_id~, increment~) =>
        match calls.get(stream_id) {
          Some(call) => call.window = call.window + increment
          None => ()
        }
      @http2.Frame::RstStream(stream_id~, ..) => calls.remove(stream_id)
      @http2.Frame::GoAway(..) => break
      _ => ()
    }
  }
  ignore(writes)
}

///|
/// The value of the first field named `name`.
fn field_value(headers : Array[@header.Header], name : Bytes) -> Bytes? {
  for h in headers {
    if h.name == name {
      return Some(h.value)
    }
  }
  None
}

///|
/// Dispatch one finished call and write its answer: the head, then the body in the pieces the
/// peer's window allows.
async fn answer_h2(
  conn : @tcp.Conn,
  engine : @connect.Server,
  encoder : @hpack.Encoder,
  call : H2Call,
) -> Unit {
  if call.started {
    return
  }
  call.started = true
  let path = match field_value(call.headers, b":path") {
    Some(p) => @utf8.decode_lossy(p)
    None => ""
  }
  match field_value(call.headers, b":method") {
    Some(m) if m != b"POST" => {
      let head = encoder.encode([
        { name: b":status", value: b"405", },
        { name: b"allow", value: b"POST", },
      ])
      conn.write(
        @http2.Frame::Headers(
          stream_id=call.id,
          fragment=head,
          end_stream=true,
          end_headers=true,
          priority=None,
          padding=0,
        ).encode(),
      )
      return
    }
    _ => ()
  }
  let answer = engine.serve({
    path,
    headers: call.headers,
    body: call.body.to_bytes(),
  })
  let fields : Array[@header.Header] = [
    { name: b":status", value: @utf8.encode(answer.status.to_string()), },
  ]
  for h in answer.headers {
    fields.push(h)
  }
  let head = encoder.encode(fields)
  conn.write(
    @http2.Frame::Headers(
      stream_id=call.id,
      fragment=head,
      end_stream=answer.body.length() == 0,
      end_headers=true,
      priority=None,
      padding=0,
    ).encode(),
  )
  if answer.body.length() == 0 {
    return
  }
  // The body goes out in as many frames as the peer's window allows; a Connect call's answer
  // is produced whole, so there is nothing to wait for but the window.
  let mut at = 0
  let mut window = call.window
  while at < answer.body.length() {
    let room = if window < 1 {
      0
    } else if window > @wire.default_max_frame_size {
      @wire.default_max_frame_size
    } else {
      window
    }
    if room == 0 {
      // Nothing may be sent until the peer credits more; wait for its WINDOW_UPDATE.
      let frame = read_frame(conn) catch { _ => return }
      match frame {
        @http2.Frame::WindowUpdate(stream_id~, increment~) =>
          if stream_id == calling_stream(call) {
            window = window + increment
          }
        @http2.Frame::Settings(params~, ack~) =>
          if !ack {
            conn.write(@http2.Frame::Settings(params=[], ack=true).encode())
            for p in params {
              if p.0 == @http2.settings_initial_window_size {
                window = window + p.1
              }
            }
          }
        @http2.Frame::RstStream(..) => return
        _ => ()
      }
      continue
    }
    let stop = if answer.body.length() - at < room {
      answer.body.length()
    } else {
      at + room
    }
    conn.write(
      @http2.Frame::Data(
        stream_id=call.id,
        data=answer.body[at:stop].to_owned(),
        end_stream=stop >= answer.body.length(),
        padding=0,
      ).encode(),
    )
    window = window - (stop - at)
    at = stop
  }
}

///|
fn calling_stream(call : H2Call) -> Int32 {
  call.id
}
