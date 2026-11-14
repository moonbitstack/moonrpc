// The rest of Apache Thrift's transports. `TFramedTransport` puts a length in front of every
// message, which is what `thrift.mbt` drives; the others do not, and each has its own way of
// saying where one message ends:
//
// - `TBufferedTransport` and the unframed one put nothing between messages, so a reader parses
//   the message it has and asks for more until it has one whole;
// - `TZlibTransport` is one zlib stream in each direction, synchronising-flushed at every
//   message, so the receiver decodes what has arrived and parses that;
// - `THttpClient` is one POST per call, the message as the body, so the message is the body.
//
// The three that need the end of a message find it with `@thrift.message_len`, which is the
// one place that knowledge lives.

///|
/// The transport a Thrift call travels in. The four are Apache Thrift's; the protocol inside is
/// independent of all of them.
pub(all) enum ThriftWire {
  /// TFramedTransport: a four-octet big-endian length in front of every message.
  Framed
  /// TBufferedTransport and its unbuffered twin: nothing between messages.
  Buffered
  /// TZlibTransport: a zlib stream over the socket, flushed at every message boundary.
  Zlib
  /// THttpClient: one POST per call, the message as the body.
  Http
}

///|
/// The writing half of the zlib transport: a DEFLATE stream behind the two header octets the
/// zlib container asks for, with a synchronising flush at every message so the peer can read
/// one before the connection ends.
pub struct ZlibOut {
  inner : @deflate.Writer
  mut header : Bytes
}

///|
/// A compressor at the level zlib's own default names, which is what the reference
/// implementations open with.
pub fn ZlibOut::new() -> ZlibOut {
  // The container's header is the two octets `zlib` writes for this level and window; taking
  // them from there rather than computing them keeps one statement of RFC 1950 §2.2.
  let empty = @zlib.zlib(b"", level=6)
  { inner: @deflate.Writer::new(level=6), header: empty[0:2].to_owned(), }
}

///|
/// One message, compressed: the header the first time, the block, and the flush that lets the
/// peer read it now.
pub fn ZlibOut::write(
  self : ZlibOut,
  body : Bytes,
) -> Bytes raise @thrift.ThriftError {
  let out = @buffer.Buffer()
  out.write_bytes(self.header)
  self.header = b""
  try {
    out.write_bytes(self.inner.push(body[:]))
    out.write_bytes(self.inner.flush())
  } catch {
    _ => raise @thrift.Malformed("the zlib stream would not deflate")
  }
  out.to_bytes()
}

///|
/// The reading half of the zlib transport: one DEFLATE stream, whose messages end where the
/// sender synchronising-flushed.
///
/// A synchronising flush is an empty stored block, and its four octets `00 00 ff ff` are the
/// only thing in a DEFLATE stream that says "a message ends here". The stream is not
/// self-describing in any other way, and a reader has to be handed a whole message at a time:
/// the decoder this library uses, asked to decode a block that is not all there, stops in a
/// state it cannot be woken from. Cutting at the marker is therefore what keeps one decoder
/// alive for a whole connection — which is required, because the compressor may refer back
/// into an earlier message and only a reader that still holds that window can decode it.
pub struct ZlibIn {
  reader : @deflate.Reader
  // The compressed octets since the last boundary, and the container's two header octets
  // until anything else can be read.
  pending : @buffer.Buffer
  header : @buffer.Buffer
  mut started : Bool
}

///|
pub fn ZlibIn::new() -> ZlibIn {
  {
    reader: @deflate.Reader::new(),
    pending: @buffer.Buffer(),
    header: @buffer.Buffer(),
    started: false,
  }
}

///|
/// Every message `chunk` completes, in order. A message split across two chunks is completed by
/// the second; a chunk that carries the end of one and the whole of the next gives two.
pub fn ZlibIn::feed(
  self : ZlibIn,
  chunk : Bytes,
) -> Array[Bytes] raise @thrift.ThriftError {
  let body = if self.started {
    chunk
  } else {
    // The container's two octets, which may arrive split or with the first message behind
    // them.
    self.header.write_bytes(chunk)
    let head = self.header.to_bytes()
    if head.length() < 2 {
      return []
    }
    self.started = true
    head[2:].to_owned()
  }
  self.pending.write_bytes(body)
  let out : Array[Bytes] = []
  for ;; {
    let data = self.pending.to_bytes()
    let end = match sync_end(data) {
      None => break
      Some(end) => end
    }
    let segment = data[0:end].to_owned()
    let rest = data[end:].to_owned()
    self.pending.reset()
    self.pending.write_bytes(rest)
    let plain = self.reader.flush(segment) catch {
      _ => raise @thrift.Malformed("the zlib stream would not inflate")
    }
    out.push(plain)
  }
  out
}

///|
/// Where the first synchronising flush in `data` ends, which is four octets past the start of
/// its marker.
fn sync_end(data : Bytes) -> Int32? {
  let mut at = 0
  let last = data.length() - 4
  while at <= last {
    if data[at] == b'\x00' &&
      data[at + 1] == b'\x00' &&
      data[at + 2] == b'\xff' &&
      data[at + 3] == b'\xff' {
      return Some(at + 4)
    }
    at = at + 1
  }
  None
}

// -- the server -------------------------------------------------------------

///|
/// Serve `processor` on `host:port` over `wire`, until the listener fails. Each connection gets
/// its own protocol object — a compact reader's field-id deltas and a text reader's cursor are
/// the connection's state — and its own task.
pub async fn[P : @thrift.Protocol] serve_thrift_wire(
  host~ : String = "127.0.0.1",
  port~ : Int32 = 9090,
  wire~ : ThriftWire,
  processor : @thrift.Processor,
  make : () -> P,
) -> Unit {
  serve_thrift_wire_on(bind_thrift(host~, port~), wire~, processor, make)
}

///|
/// The same on a socket that is already bound, the form a caller needs when it must learn the
/// port before the accept loop starts.
pub async fn[P : @thrift.Protocol] serve_thrift_wire_on(
  listener : @tcp.Listener,
  wire~ : ThriftWire,
  processor : @thrift.Processor,
  make : () -> P,
) -> Unit {
  @async.with_task_group(group => {
    for ;; {
      let (conn, _) = listener.accept() catch { _ => continue }
      group.spawn_bg(allow_failure=true, () => {
        defer conn.close()
        serve_one(conn, wire, processor, make) catch {
          _ => ()
        }
      })
    }
  })
}

///|
async fn[P : @thrift.Protocol] serve_one(
  conn : @tcp.Conn,
  wire : ThriftWire,
  processor : @thrift.Processor,
  make : () -> P,
) -> Unit raise @thrift.ThriftError {
  match wire {
    Framed => serve_framed(conn, processor, make)
    Buffered => serve_stream(conn, processor, make)
    Zlib => serve_zlib(conn, processor, make)
    Http => {
      serve_http(conn, processor, make)
      ()
    }
  }
}

///|
/// Frames: a length in front of every message, read whole before the dispatch sees it.
async fn[P : @thrift.Protocol] serve_framed(
  conn : @tcp.Conn,
  processor : @thrift.Processor,
  make : () -> P,
) -> Unit raise @thrift.ThriftError {
  let proto : &@thrift.Protocol = make()
  for ;; {
    let head = conn.read_exactly(4) catch { _ => break }
    let len = @thrift.frame_len(head)
    if len < 0 || len > @thrift.max_frame {
      break
    }
    let body = conn.read_exactly(len) catch { _ => break }
    let reply = processor.process(proto, body)
    if reply.length() > 0 {
      conn.write(@thrift.frame(reply)) catch {
        _ => break
      }
    }
  }
}

///|
/// A stream with no length in front of its messages. What arrives is decompressed as it comes,
/// and every whole message in the buffer is answered: the leftover stays for the next read,
/// which is what a message split across two packets needs.
async fn[P : @thrift.Protocol] serve_stream(
  conn : @tcp.Conn,
  processor : @thrift.Processor,
  make : () -> P,
) -> Unit raise @thrift.ThriftError {
  let proto : &@thrift.Protocol = make()
  // The octets no message has claimed yet.
  let pending = @buffer.Buffer()
  for ;; {
    let chunk = conn.read_some() catch { _ => break }
    let bytes = match chunk {
      None => break
      Some(bytes) => bytes
    }
    if bytes.length() == 0 {
      break
    }
    pending.write_bytes(bytes)
    for ;; {
      let data = pending.to_bytes()
      let length = @thrift.message_len(proto, data)
      let length = match length {
        None => break
        Some(length) => length
      }
      if length <= 0 || length > data.length() {
        raise @thrift.Malformed(
          "a message longer than the octets that carried it",
        )
      }
      let message = data[0:length].to_owned()
      let rest = data[length:].to_owned()
      pending.reset()
      pending.write_bytes(rest)
      let reply = processor.process(proto, message)
      if reply.length() > 0 {
        conn.write(reply) catch {
          _ => break
        }
      }
    }
  }
}

///|
/// The same, compressed: one inflater and one deflater for the whole connection, because that
/// is the state a zlib stream carries from one message to the next.
async fn[P : @thrift.Protocol] serve_zlib(
  conn : @tcp.Conn,
  processor : @thrift.Processor,
  make : () -> P,
) -> Unit raise @thrift.ThriftError {
  let proto : &@thrift.Protocol = make()
  let inflater = ZlibIn::new()
  let deflater = ZlibOut::new()
  for ;; {
    let chunk = conn.read_some() catch { _ => break }
    let bytes = match chunk {
      None => break
      Some(bytes) => bytes
    }
    if bytes.length() == 0 {
      break
    }
    for message in inflater.feed(bytes) {
      let reply = processor.process(proto, message)
      if reply.length() > 0 {
        conn.write(deflater.write(reply)) catch {
          _ => break
        }
      }
    }
  }
}

///|
/// One POST per call: the body is one message and the answer is one message. A kept-alive
/// connection goes round again, which is what Apache's Go client does with its `net/http`
/// connection.
async fn[P : @thrift.Protocol] serve_http(
  conn : @tcp.Conn,
  processor : @thrift.Processor,
  make : () -> P,
) -> Unit raise @thrift.ThriftError {
  let proto : &@thrift.Protocol = make()
  // The state machine has to be handed the first octets before it can be asked what they are.
  let first = conn.read_some() catch { _ => return }
  let opening = match first {
    None => return
    Some(bytes) => bytes
  }
  if opening.length() == 0 {
    return
  }
  let http = @http1.Conn::new(@http1.Role::Server)
  http.receive(opening[:]) catch {
    _ => raise @thrift.Malformed("the request did not parse")
  }
  let body = @buffer.Buffer()
  let mut head : @http1.Request? = None
  for ;; {
    let event = http.next() catch {
      // A head that does not parse ends the connection: there is no request to answer.
      _ => raise @thrift.Malformed("the request did not parse")
    }
    match event {
      @http1.Event::Request(request) => {
        head = Some(request)
        body.reset()
      }
      @http1.Event::Data(bytes) => body.write_bytes(bytes)
      @http1.Event::End(_trailers) => {
        let request = match head {
          None => break
          Some(request) => request
        }
        let reply = processor.process(proto, body.to_bytes()) catch { _ => b"" }
        let answer = @http1.Response::of(
          200,
          fields=[{ name: b"content-type", value: b"application/x-thrift", }],
          body=@http1.Body::Sized(reply.length()),
        )
        conn.write(http.send(@http1.Event::Response(answer))) catch {
          _ => break
        }
        if reply.length() > 0 {
          conn.write(http.send(@http1.Event::Data(reply))) catch {
            _ => break
          }
        }
        conn.write(http.send(@http1.Event::End([]))) catch {
          _ => break
        }
        head = None
        if request.keep_alive {
          http.start_next() catch {
            _ => break
          }
        } else {
          break
        }
      }
      @http1.Event::NeedData => {
        let chunk = conn.read_some() catch { _ => break }
        let bytes = match chunk {
          None => break
          Some(bytes) => bytes
        }
        if bytes.length() == 0 {
          break
        }
        http.receive(bytes[:]) catch {
          _ => break
        }
      }
      _ => break
    }
  }
}

// -- the client -------------------------------------------------------------

///|
/// Send one message over `wire` and take the reply, for a transport that has no framing.
pub async fn ThriftClient::exchange(
  self : ThriftClient,
  body : Bytes,
) -> Bytes raise @thrift.ThriftError {
  match self.wire {
    Framed => {
      self.conn.write(@thrift.frame(body)) catch {
        _ => raise @thrift.Truncated
      }
      let head = self.conn.read_exactly(4) catch {
        _ => raise @thrift.Truncated
      }
      let len = @thrift.frame_len(head)
      if len < 0 || len > @thrift.max_frame {
        raise @thrift.Application("frame too large")
      }
      self.conn.read_exactly(len) catch {
        _ => raise @thrift.Truncated
      }
    }
    Buffered => {
      self.conn.write(body) catch {
        _ => raise @thrift.Truncated
      }
      self.read_message()
    }
    Zlib => {
      let compressed = match self.zlib_out {
        Some(deflater) => deflater.write(body)
        None => raise @thrift.Malformed("this client has no compressor")
      }
      self.conn.write(compressed) catch {
        _ => raise @thrift.Truncated
      }
      self.read_message()
    }
    Http => self.post(body)
  }
}

///|
/// Read until the buffer holds one whole message, then hand exactly that over.
async fn ThriftClient::read_message(
  self : ThriftClient,
) -> Bytes raise @thrift.ThriftError {
  // A compressed chunk may carry more than one message; the ones not claimed yet wait here.
  if self.ready.length() > 0 {
    return self.ready.remove(0)
  }
  for ;; {
    if self.ready.length() > 0 {
      return self.ready.remove(0)
    }
    let data = self.pending.to_bytes()
    let length = @thrift.message_len(self.proto, data)
    match length {
      Some(length) => {
        let message = data[0:length].to_owned()
        let rest = data[length:].to_owned()
        self.pending.reset()
        self.pending.write_bytes(rest)
        return message
      }
      None => {
        let chunk = self.conn.read_some() catch { _ => raise @thrift.Truncated }
        let bytes = match chunk {
          None => raise @thrift.Truncated
          Some(bytes) => bytes
        }
        if bytes.length() == 0 {
          raise @thrift.Truncated
        }
        match self.zlib_in {
          Some(inflater) => {
            let messages = inflater.feed(bytes)
            for message in messages {
              self.ready.push(message)
            }
          }
          None => self.pending.write_bytes(bytes)
        }
      }
    }
  }
}

///|
/// One call as a POST: the message is the body, and the reply is the body that comes back.
async fn ThriftClient::post(
  self : ThriftClient,
  body : Bytes,
) -> Bytes raise @thrift.ThriftError {
  let http = @http1.Conn::new(@http1.Role::Client)
  let request = @http1.Request::of(
    "POST",
    "/",
    fields=[
      @header.Header::of("host", self.host),
      @header.Header::of("content-type", "application/x-thrift"),
      @header.Header::of("accept", "application/x-thrift"),
    ],
    body=@http1.Body::Sized(body.length()),
  )
  self.conn.write(http.send(@http1.Event::Request(request))) catch {
    _ => raise @thrift.Truncated
  }
  if body.length() > 0 {
    self.conn.write(http.send(@http1.Event::Data(body))) catch {
      _ => raise @thrift.Truncated
    }
  }
  self.conn.write(http.send(@http1.Event::End([]))) catch {
    _ => raise @thrift.Truncated
  }
  let answer = @buffer.Buffer()
  for ;; {
    let event = http.next() catch { _ => raise @thrift.Truncated }
    match event {
      // The status is not the protocol's business: Apache's client reads the body whether the
      // status was 200 or not, and the body is where an exception would arrive.
      @http1.Event::Response(_response) => ()
      @http1.Event::Data(bytes) => answer.write_bytes(bytes)
      @http1.Event::End(_trailers) => break
      @http1.Event::NeedData => {
        let chunk = self.conn.read_some() catch { _ => raise @thrift.Truncated }
        let bytes = match chunk {
          None => raise @thrift.Truncated
          Some(bytes) => bytes
        }
        if bytes.length() == 0 {
          raise @thrift.Truncated
        }
        http.receive(bytes[:]) catch {
          _ => raise @thrift.Truncated
        }
      }
      _ => break
    }
  }
  answer.to_bytes()
}
