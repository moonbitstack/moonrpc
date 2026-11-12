// The two transports that keep a Connect request body open across calls. A one-shot POST
// writes the whole body and then reads; these write the request head first and take each
// envelope as it is produced, so a caller can close its send side, read an answer, or cancel
// at any point. Cancellation is real: HTTP/1.1 drops the socket mid-chunk, and HTTP/2 sends
// RST_STREAM with CANCEL, which is what a reference server observes as a cancelled call.

///|
/// The HTTP/2 reason code for "the caller gave up".
let h2_cancel : Int32 = 8

///|
/// An HTTP/1.1 request kept open with chunked transfer encoding.
pub(all) struct Http1StreamTransport {
  host : String
  port : Int32
  conn : Ref[@tcp.Conn?]
  http : Ref[@http1.Conn?]
  status : Ref[Int32]
  fields : Ref[Array[@header.Header]]
  cancelled : Ref[Bool]
  reply_end : Ref[Bool]
  closed : Ref[Bool]
}

///|
pub fn Http1StreamTransport::new(
  host : String,
  port : Int32,
) -> Http1StreamTransport {
  {
    host,
    port,
    conn: Ref(None),
    http: Ref(None),
    status: Ref(0),
    fields: Ref([]),
    cancelled: Ref(false),
    reply_end: Ref(false),
    closed: Ref(false),
  }
}

///|
pub impl @connect.StreamTransport for Http1StreamTransport with fn open(
  self,
  path,
  content,
  headers,
) {
  ignore(content)
  let conn = @tcp.dial(self.host, port=self.port)
  self.conn.val = Some(conn)
  self.http.val = Some(@http1.Conn::new(@http1.Role::Client))
  let mut text = "POST " + path + " HTTP/1.1\r\nHost: " + self.host + "\r\n"
  for h in headers {
    if @utf8.decode_lossy(h.name).to_lower() != "content-length" {
      text = text +
        @utf8.decode_lossy(h.name) +
        ": " +
        @utf8.decode_lossy(h.value) +
        "\r\n"
    }
  }
  // No length in front: each `send` is one chunk, and the body ends only when `end` writes
  // the last one. A cancellation simply never writes it.
  text = text + "Transfer-Encoding: chunked\r\n\r\n"
  conn.write(@utf8.encode(text))
}

///|
pub impl @connect.StreamTransport for Http1StreamTransport with fn send(
  self,
  bytes,
) {
  if self.cancelled.val {
    return
  }
  match self.conn.val {
    Some(conn) => conn.write(@http1.chunk(bytes[:]))
    None => ()
  }
}

///|
pub impl @connect.StreamTransport for Http1StreamTransport with fn end(self) {
  if self.cancelled.val {
    return
  }
  match self.conn.val {
    Some(conn) => conn.write(@http1.last_chunk())
    None => ()
  }
}

///|
pub impl @connect.StreamTransport for Http1StreamTransport with fn cancel(self) {
  if self.cancelled.val {
    return
  }
  self.cancelled.val = true
  match self.conn.val {
    Some(conn) => conn.close()
    None => ()
  }
  self.closed.val = true
}

///|
pub impl @connect.StreamTransport for Http1StreamTransport with fn read(self) {
  if self.cancelled.val || self.reply_end.val {
    return None
  }
  let http = match self.http.val {
    Some(http) => http
    None => return None
  }
  for ;; {
    let event = http.next() catch { _ => return None }
    match event {
      @http1.Event::Response(response) => {
        self.status.val = response.status
        self.fields.val = []
        for f in response.fields {
          self.fields.val.push(f)
        }
      }
      @http1.Event::Data(bytes) => return Some(bytes)
      @http1.Event::End(_extra) => {
        self.reply_end.val = true
        return None
      }
      @http1.Event::NeedData => {
        let more = match self.conn.val {
          Some(conn) => conn.read_some() catch { _ => None }
          None => None
        }
        match more {
          Some(chunk) =>
            if chunk.length() == 0 {
              self.reply_end.val = true
              return None
            } else {
              http.receive(chunk[:]) catch {
                _ => return None
              }
            }
          None => {
            self.reply_end.val = true
            return None
          }
        }
      }
      _ => {
        self.reply_end.val = true
        return None
      }
    }
  }
}

///|
pub impl @connect.StreamTransport for Http1StreamTransport with fn head(self) {
  (self.status.val, self.fields.val)
}

///|
pub impl @connect.StreamTransport for Http1StreamTransport with fn close(self) {
  if self.closed.val {
    return
  }
  self.closed.val = true
  match self.conn.val {
    Some(conn) => conn.close()
    None => ()
  }
}

///|
pub extend Http1StreamTransport with @connect.StreamTransport::{
  open,
  send,
  end,
  cancel,
  read,
  head,
  close,
}

///|
/// An HTTP/2 request kept open as one stream, cancelled with RST_STREAM.
pub(all) struct Http2StreamTransport {
  host : String
  port : Int32
  conn : Ref[@tcp.Conn?]
  encoder : Ref[@hpack.Encoder?]
  decoder : Ref[@hpack.Decoder?]
  window : Ref[Int32]
  status : Ref[Int32]
  fields : Ref[Array[@header.Header]]
  cancelled : Ref[Bool]
  reply_end : Ref[Bool]
  closed : Ref[Bool]
}

///|
pub fn Http2StreamTransport::new(
  host : String,
  port : Int32,
) -> Http2StreamTransport {
  {
    host,
    port,
    conn: Ref(None),
    encoder: Ref(None),
    decoder: Ref(None),
    window: Ref(65535),
    status: Ref(0),
    fields: Ref([]),
    cancelled: Ref(false),
    reply_end: Ref(false),
    closed: Ref(false),
  }
}

///|
pub impl @connect.StreamTransport for Http2StreamTransport with fn open(
  self,
  path,
  content,
  headers,
) {
  ignore(content)
  let conn = @tcp.dial(self.host, port=self.port)
  self.conn.val = Some(conn)
  self.encoder.val = Some(@hpack.Encoder::new())
  self.decoder.val = Some(@hpack.Decoder::new())
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
  let encoded = match self.encoder.val {
    Some(encoder) => encoder.encode(fields)
    None => b""
  }
  conn.write(
    @http2.Frame::Headers(
      stream_id=1,
      fragment=encoded,
      end_stream=false,
      end_headers=true,
      priority=None,
      padding=0,
    ).encode(),
  )
  conn.write(
    @http2.Frame::WindowUpdate(stream_id=0, increment=1 << 20).encode(),
  )
  conn.write(
    @http2.Frame::WindowUpdate(stream_id=1, increment=1 << 20).encode(),
  )
}

///|
pub impl @connect.StreamTransport for Http2StreamTransport with fn send(
  self,
  bytes,
) {
  if self.cancelled.val {
    return
  }
  let conn = match self.conn.val {
    Some(conn) => conn
    None => return
  }
  let mut at = 0
  while at < bytes.length() {
    while self.window.val <= 0 {
      // Nothing may go out until the peer grants room; a frame that arrives here is either a
      // WINDOW_UPDATE or the reply itself.
      if self.pump() is None {
        return
      }
    }
    let room = bytes.length() - at
    let allowed = if self.window.val < 16384 { self.window.val } else { 16384 }
    let size = if room < allowed { room } else { allowed }
    conn.write(
      @http2.Frame::Data(
        stream_id=1,
        data=bytes[at:at + size].to_owned(),
        end_stream=false,
        padding=0,
      ).encode(),
    )
    at = at + size
    self.window.val = self.window.val - size
  }
}

///|
pub impl @connect.StreamTransport for Http2StreamTransport with fn end(self) {
  if self.cancelled.val {
    return
  }
  match self.conn.val {
    Some(conn) =>
      conn.write(
        @http2.Frame::Data(stream_id=1, data=b"", end_stream=true, padding=0).encode(),
      )
    None => ()
  }
}

///|
pub impl @connect.StreamTransport for Http2StreamTransport with fn cancel(self) {
  if self.cancelled.val {
    return
  }
  self.cancelled.val = true
  match self.conn.val {
    Some(conn) => {
      conn.write(
        @http2.Frame::RstStream(stream_id=1, error_code=h2_cancel).encode(),
      ) catch {
        _ => ()
      }
      conn.close()
    }
    None => ()
  }
  self.closed.val = true
}

///|
/// One frame from the peer, with the connection-level bookkeeping it needs. Returns `Some`
/// when a DATA frame carried bytes, and `None` when the reply ended or the connection closed.
async fn Http2StreamTransport::pump(self : Http2StreamTransport) -> Bytes? {
  if self.reply_end.val || self.cancelled.val {
    return None
  }
  let conn = match self.conn.val {
    Some(conn) => conn
    None => return None
  }
  let frame = read_frame(conn) catch {
    _ => {
      self.reply_end.val = true
      return None
    }
  }
  match frame {
    @http2.Frame::Settings(ack~, params~) =>
      if !ack {
        for p in params {
          if p.0 == @http2.settings_initial_window_size {
            self.window.val = p.1
          }
        }
        conn.write(@http2.Frame::Settings(params=[], ack=true).encode()) catch {
          _ => ()
        }
      }
    @http2.Frame::Ping(payload~, ack~) =>
      if !ack {
        conn.write(@http2.Frame::Ping(payload~, ack=true).encode()) catch {
          _ => ()
        }
      }
    @http2.Frame::Headers(fragment~, end_stream~, end_headers~, ..) => {
      if end_headers {
        match self.decoder.val {
          Some(decoder) => {
            let decoded = decoder.decode(fragment) catch { _ => [] }
            for h in decoded {
              let name = @utf8.decode_lossy(h.name)
              if name == ":status" {
                self.status.val = @string.parse_int(
                  @utf8.decode_lossy(h.value)[:],
                ) catch {
                  _ => 0
                }
              } else if !name.has_prefix(":") {
                self.fields.val.push(h)
              }
            }
          }
          None => ()
        }
      }
      if end_stream {
        self.reply_end.val = true
      }
    }
    @http2.Frame::Data(data~, end_stream~, ..) => {
      if end_stream {
        self.reply_end.val = true
      }
      if data.length() > 0 {
        return Some(data)
      }
    }
    @http2.Frame::WindowUpdate(increment~, ..) =>
      self.window.val = self.window.val + increment
    @http2.Frame::RstStream(..) | @http2.Frame::GoAway(..) =>
      self.reply_end.val = true
    _ => ()
  }
  None
}

///|
pub impl @connect.StreamTransport for Http2StreamTransport with fn read(self) {
  for ;; {
    match self.pump() {
      Some(bytes) => return Some(bytes)
      None => if self.reply_end.val || self.cancelled.val { return None }
    }
  }
}

///|
pub impl @connect.StreamTransport for Http2StreamTransport with fn head(self) {
  (self.status.val, self.fields.val)
}

///|
pub impl @connect.StreamTransport for Http2StreamTransport with fn close(self) {
  if self.closed.val {
    return
  }
  self.closed.val = true
  match self.conn.val {
    Some(conn) => conn.close()
    None => ()
  }
}

///|
pub extend Http2StreamTransport with @connect.StreamTransport::{
  open,
  send,
  end,
  cancel,
  read,
  head,
  close,
}
