// The transport a Connect client uses over HTTP/1.1: one POST per call, the reply read whole.

///|
/// An HTTP/1.1 endpoint a Connect client posts to. Every call opens its own connection, which
/// is what a client that answers one call at a time needs and what a proxy in front of a
/// server sees most often.
pub(all) struct Http1Transport {
  host : String
  port : Int32
}

///|
pub fn Http1Transport::new(host : String, port : Int32) -> Http1Transport {
  { host, port, }
}

///|
pub impl @connect.Transport for Http1Transport with fn post(
  self,
  path,
  content,
  body,
  headers,
) {
  let conn = @tcp.dial(self.host, port=self.port)
  defer conn.close()
  let http = @http1.Conn::new(@http1.Role::Client)
  let fields : Array[@header.Header] = [
    @header.Header::of("host", self.host),
    @header.Header::of("accept", "*/*"),
  ]
  for h in headers {
    fields.push(h)
  }
  let request = @http1.Request::of(
    "POST",
    path,
    fields~,
    body=@http1.Body::Sized(body.length()),
  )
  conn.write(http.send(@http1.Event::Request(request)))
  if body.length() > 0 {
    conn.write(http.send(@http1.Event::Data(body)))
  }
  conn.write(http.send(@http1.Event::End([])))
  ignore(content)
  let status = Ref(0)
  let answer = Buffer()
  let reply_headers : Array[@header.Header] = []
  for ;; {
    let event = http.next() catch { _ => break }
    match event {
      @http1.Event::Response(response) => {
        status.val = response.status
        for f in response.fields {
          reply_headers.push(f)
        }
      }
      @http1.Event::Data(bytes) => answer.write_bytes(bytes)
      @http1.Event::End(_extra) => break
      @http1.Event::NeedData => {
        let more = conn.read_some() catch { _ => break }
        let chunk = match more {
          Some(bytes) => bytes
          None => break
        }
        if chunk.length() == 0 {
          break
        }
        http.receive(chunk[:])
      }
      _ => break
    }
  }
  (status.val, reply_headers, answer.to_bytes())
}

///|
pub extend Http1Transport with @connect.Transport::{post}

///|
/// An HTTP/2 endpoint a Connect client posts to: the preface, one request stream, and the reply
/// read whole. One connection per call, which is what a client that answers one call at a time
/// needs — and what the conformance suite's client cases ask of a caller that is not multiplexing.
pub(all) struct Http2Transport {
  host : String
  port : Int32
}

///|
pub fn Http2Transport::new(host : String, port : Int32) -> Http2Transport {
  { host, port, }
}

///|
/// The body one DATA frame carries before the sender has to have been granted more room.
let h2_chunk : Int32 = 16384

///|
pub impl @connect.Transport for Http2Transport with fn post(
  self,
  path,
  content,
  body,
  headers,
) {
  ignore(content)
  let conn = @tcp.dial(self.host, port=self.port)
  defer conn.close()
  let encoder = @hpack.Encoder::new()
  let decoder = @hpack.Decoder::new()
  conn.write(b"PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n")
  conn.write(@http2.Frame::Settings(params=[], ack=false).encode())
  let fields : Array[@header.Header] = [
    { name: b":method", value: b"POST", },
    { name: b":scheme", value: b"http", },
    { name: b":authority", value: @utf8.encode(self.host), },
    { name: b":path", value: @utf8.encode(path), },
  ]
  for h in headers {
    fields.push({
      name: @utf8.encode(@utf8.decode_lossy(h.name).to_lower()),
      value: h.value,
    })
  }
  conn.write(
    @http2.Frame::Headers(
      stream_id=1,
      fragment=encoder.encode(fields),
      end_stream=body.length() == 0,
      end_headers=true,
      priority=None,
      padding=0,
    ).encode(),
  )
  // The protocol opens both windows at 65535 octets. A reply larger than that waits for a
  // WINDOW_UPDATE, and a client that only reads until END_STREAM never sends one: advertising
  // room up front is what keeps a large message from deadlocking against itself.
  conn.write(
    @http2.Frame::WindowUpdate(stream_id=0, increment=1 << 20).encode(),
  )
  conn.write(
    @http2.Frame::WindowUpdate(stream_id=1, increment=1 << 20).encode(),
  )
  // What the peer allows on this stream, which is its SETTINGS or the protocol's default.
  let mut window = 65535
  let mut sent = 0
  let reply_headers : Array[@header.Header] = []
  let answer = Buffer()
  let mut status = 0
  let mut done = body.length() == 0
  for ;; {
    // Send what the window allows before reading anything: the reply may be waiting for room
    // a body the peer is still reading from us would otherwise use up.
    while sent < body.length() && window > 0 {
      let room = body.length() - sent
      let allowed = if window < h2_chunk { window } else { h2_chunk }
      let size = if room < allowed { room } else { allowed }
      let piece = body[sent:sent + size].to_owned()
      sent = sent + size
      window = window - size
      conn.write(
        @http2.Frame::Data(
          stream_id=1,
          data=piece,
          end_stream=sent >= body.length(),
          padding=0,
        ).encode(),
      )
    }
    done = sent >= body.length()
    let frame = read_frame(conn) catch { _ => break }
    match frame {
      @http2.Frame::Settings(ack~, params~) =>
        if !ack {
          for p in params {
            if p.0 == @http2.settings_initial_window_size {
              window = p.1
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
        ignore(stream_id)
        if end_headers {
          let decoded = decoder.decode(fragment) catch { _ => [] }
          for h in decoded {
            let name = @utf8.decode_lossy(h.name)
            if name == ":status" {
              status = @string.parse_int(@utf8.decode_lossy(h.value)[:]) catch {
                _ => 0
              }
            } else if !name.has_prefix(":") {
              reply_headers.push(h)
            }
          }
        }
        if end_stream {
          break
        }
      }
      @http2.Frame::Data(stream_id~, data~, end_stream~, ..) => {
        ignore(stream_id)
        answer.write_bytes(data)
        // The window this connection opened for replies is large enough for anything the
        // suite sends; a peer that keeps sending would need a WINDOW_UPDATE, which a client
        // that reads to the end never has to give.
        if end_stream {
          break
        }
      }
      @http2.Frame::WindowUpdate(stream_id~, increment~) => {
        ignore(stream_id)
        window = window + increment
      }
      @http2.Frame::RstStream(..) => break
      @http2.Frame::GoAway(..) => break
      _ => ()
    }
    ignore(done)
  }
  (status, reply_headers, answer.to_bytes())
}

///|
pub extend Http2Transport with @connect.Transport::{post}
