// The Connect server over HTTP/2. The gRPC engine in `server/` is built around gRPC's framing
// and trailers, so this is its own driver: it moves the same `connect` dispatch over HTTP/2
// frames, with the HPACK codec and the frame codec moonhttp provides.
//
// A call is answered as it arrives: the reply headers go out as soon as the request headers are
// decoded, and each message the caller sends is answered in DATA frames while the stream is
// still open. That is what a bidirectional call needs — a driver that waited for END_STREAM
// would hold the answer to a message until the caller closed, and the caller is waiting for the
// answer before it sends the next one.
//
// Flow control is the peer's window, not ours: the two are separate, and a reply that ignored
// the peer's would be a protocol error the moment it exceeded it.

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
  mut session : @connect.Session?
  // What the peer's flow-control window still allows this driver to send.
  mut window : Int32
  // Reply bytes waiting for room in that window.
  pending : Buffer
  mut head_sent : Bool
  mut want_end : Bool
  mut end_sent : Bool
}

///|
fn H2Call::new(id : Int32, window : Int32) -> H2Call {
  {
    id,
    block: Buffer(),
    headers: [],
    session: None,
    window,
    pending: Buffer(),
    head_sent: false,
    want_end: false,
    end_sent: false,
  }
}

///|
/// Drive one HTTP/2 connection that speaks Connect. `preface` is the 24 octets already read from
/// the socket.
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
  // What the peer allows us to send on a new stream, until its SETTINGS says otherwise.
  let mut peer_window : Int32 = 65535
  let calls : Map[Int32, H2Call] = Map([])
  for ;; {
    let frame = read_frame(conn) catch { _ => break }
    match frame {
      @http2.Frame::Settings(ack~, params~) =>
        if !ack {
          for p in params {
            if p.0 == @http2.settings_initial_window_size {
              peer_window = p.1
            }
          }
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
            let c = H2Call::new(stream_id, peer_window)
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
          open_h2_call(conn, engine, encoder, call) catch {
            _ => ()
          }
        }
        if end_stream {
          finish_h2_call(conn, encoder, call) catch {
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
              open_h2_call(conn, engine, encoder, call) catch {
                _ => ()
              }
            }
          }
          None => ()
        }
      @http2.Frame::Data(stream_id~, data~, end_stream~, ..) =>
        match calls.get(stream_id) {
          Some(call) => {
            feed_h2_call(conn, encoder, call, data) catch {
              _ => ()
            }
            // A handler that failed while the caller was still sending has closed the call:
            // the response ends here, not when the caller gives up on a reply that never comes.
            if h2_call_closed(call) {
              call.want_end = true
              flush_h2(conn, encoder, call) catch {
                _ => ()
              }
              calls.remove(stream_id)
            }
            if end_stream {
              finish_h2_call(conn, encoder, call) catch {
                _ => ()
              }
              calls.remove(stream_id)
            }
          }
          None => ()
        }
      @http2.Frame::WindowUpdate(stream_id~, increment~) =>
        match calls.get(stream_id) {
          Some(call) => {
            call.window = call.window + increment
            flush_h2(conn, encoder, call) catch {
              _ => ()
            }
          }
          None => ()
        }
      @http2.Frame::RstStream(stream_id~, ..) => calls.remove(stream_id)
      @http2.Frame::GoAway(..) => break
      _ => ()
    }
  }
}

///|
/// The same fields with lowercase names. HTTP/2 requires them — a name with a capital in it is
/// a connection error the peer reports as `PROTOCOL_ERROR` — while a handler names the metadata
/// it sets the way HTTP/1.1 spells it, so the fold happens at the one place that needs it.
fn lower_fields(fields : Array[@header.Header]) -> Array[@header.Header] {
  let out : Array[@header.Header] = []
  for h in fields {
    out.push({
      name: @utf8.encode(@utf8.decode_lossy(h.name).to_lower()),
      value: h.value,
    })
  }
  out
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
/// Whether the call in flight has written its end marker.
fn h2_call_closed(call : H2Call) -> Bool {
  match call.session {
    Some(session) => session.closed()
    None => false
  }
}

///|
/// Start the call the request headers describe, and send the reply headers when the answer can
/// begin before the request ends.
async fn open_h2_call(
  conn : @tcp.Conn,
  engine : @connect.Server,
  encoder : @hpack.Encoder,
  call : H2Call,
) -> Unit {
  let verb = match field_value(call.headers, b":method") {
    Some(m) => m
    None => b""
  }
  if verb != b"POST" {
    let head = encoder.encode(
      lower_fields([
        { name: b":status", value: b"405", },
        { name: b"allow", value: b"POST", },
      ]),
    )
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
    call.head_sent = true
    call.end_sent = true
    return
  }
  let path = match field_value(call.headers, b":path") {
    Some(p) => @utf8.decode_lossy(p)
    None => ""
  }
  let session = engine.start(path, call.headers)
  call.session = Some(session)
  // The reply head waits for the first envelope, in `flush_h2`: the headers to send are the ones
  // a handler sets from the request, and the request has not been read yet.
  ignore(encoder)
}

///|
/// Hand one piece of the request body to the dispatch and write what it answers now.
async fn feed_h2_call(
  conn : @tcp.Conn,
  encoder : @hpack.Encoder,
  call : H2Call,
  data : Bytes,
) -> Unit {
  if call.end_sent {
    return
  }
  match call.session {
    Some(session) =>
      if session.streaming() && !session.refused() {
        let reply = session.feed(data)
        if reply.length() > 0 {
          call.pending.write_bytes(reply)
          flush_h2(conn, encoder, call) catch {
            _ => ()
          }
        }
      } else {
        // A unary call is answered once its body has arrived, so nothing leaves yet.
        ignore(session.feed(data))
      }
    None => ()
  }
}

///|
/// End the call: write the head if it is still owed, then the rest of the body.
async fn finish_h2_call(
  conn : @tcp.Conn,
  encoder : @hpack.Encoder,
  call : H2Call,
) -> Unit {
  if call.end_sent {
    return
  }
  match call.session {
    None => {
      // Headers that never decoded: the stream is closed without an answer.
      conn.write(
        @http2.Frame::RstStream(
          stream_id=call.id,
          error_code=@http2.error_internal_error,
        ).encode(),
      )
      call.end_sent = true
    }
    Some(session) => {
      let answer = session.finish()
      if !call.head_sent {
        let fields : Array[@header.Header] = [
          { name: b":status", value: @utf8.encode(answer.status.to_string()), },
        ]
        for h in answer.headers {
          fields.push(h)
        }
        conn.write(
          @http2.Frame::Headers(
            stream_id=call.id,
            fragment=encoder.encode(lower_fields(fields)),
            end_stream=answer.body.length() == 0,
            end_headers=true,
            priority=None,
            padding=0,
          ).encode(),
        )
        call.head_sent = true
        if answer.body.length() == 0 {
          call.end_sent = true
          return
        }
      }
      if answer.body.length() > 0 {
        call.pending.write_bytes(answer.body)
      }
      call.want_end = true
      flush_h2(conn, encoder, call) catch {
        _ => ()
      }
    }
  }
}

///|
/// Write as much of the pending reply as the peer's window allows, ending the stream on the last
/// frame once there is nothing left to send.
async fn flush_h2(
  conn : @tcp.Conn,
  encoder : @hpack.Encoder,
  call : H2Call,
) -> Unit {
  if call.end_sent {
    return
  }
  // The reply headers go out with the first envelope, not before it: a handler sets them while
  // it reads the request.
  if !call.head_sent {
    match call.session {
      Some(session) =>
        if !session.streaming() || session.refused() {
          return
        } else {
          let answer = session.head()
          let fields : Array[@header.Header] = [
            { name: b":status", value: b"200", },
          ]
          for h in answer.headers {
            fields.push(h)
          }
          conn.write(
            @http2.Frame::Headers(
              stream_id=call.id,
              fragment=encoder.encode(lower_fields(fields)),
              end_stream=false,
              end_headers=true,
              priority=None,
              padding=0,
            ).encode(),
          )
          call.head_sent = true
        }
      None => return
    }
  }
  for ;; {
    let pending = call.pending.to_bytes()
    if pending.length() == 0 {
      if call.want_end {
        conn.write(
          @http2.Frame::Data(
            stream_id=call.id,
            data=b"",
            end_stream=true,
            padding=0,
          ).encode(),
        )
        call.end_sent = true
        call.want_end = false
      }
      return
    }
    if call.window <= 0 {
      // Nothing may be sent until the peer credits more; the read loop will see its
      // WINDOW_UPDATE and call back here.
      return
    }
    let room = if call.window > @wire.default_max_frame_size {
      @wire.default_max_frame_size
    } else {
      call.window
    }
    let stop = if pending.length() - 0 < room { pending.length() } else { room }
    let piece = pending[0:stop].to_owned()
    let rest = pending[stop:].to_owned()
    call.pending.reset()
    call.pending.write_bytes(rest)
    let last = call.want_end && call.pending.to_bytes().length() == 0
    conn.write(
      @http2.Frame::Data(
        stream_id=call.id,
        data=piece,
        end_stream=last,
        padding=0,
      ).encode(),
    )
    call.window = call.window - stop
    if last {
      call.end_sent = true
      call.want_end = false
    }
  }
}
