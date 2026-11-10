// The tRPC server half: the same `Registrar` the gRPC engines implement, driven by the
// frames of one connection. Pure — a session turns frames into frames, and the socket
// driver in `net/` decides when to read the next one.

///|
/// Where tRPC methods are registered, keyed by the path a call names
/// (`/package.service/Method`). The same generated `register` that fills a gRPC server
/// fills this one, so a service is written once and answered over either protocol.
pub struct Server {
  handlers : Map[String, @stream.Handler]
}

///|
pub fn Server::new() -> Server {
  { handlers: Map([]), }
}

///|
/// Register `handler` at `path`.
pub fn Server::register(
  self : Server,
  path : String,
  handler : @stream.Handler,
) -> Unit {
  self.handlers[path] = handler
}

///|
/// The handler at `path`, if one is registered.
pub fn Server::handler(self : Server, path : String) -> @stream.Handler? {
  self.handlers.get(path)
}

///|
pub impl @stream.Registrar for Server with fn register_handler(
  self,
  path,
  handler,
) {
  self.handlers[path] = handler
}

///|
pub extend Server with @stream.Registrar::{register_handler}

///|
/// One streaming call in flight: the request that opened it, the messages that have
/// arrived, and the handler driving it.
struct Live {
  path : String
  ctx : @stream.RpcContext
  request : Request
  inbound : Array[Bytes]
  bidi : @stream.BidiHandler?
}

///|
/// One connection's worth of state: the server's handlers, and the streams it has opened.
/// A session is not shared between connections, so stream ids never collide.
pub struct Session {
  server : Server
  streams : Map[Int64, Live]
}

///|
pub fn Session::new(server : Server) -> Session {
  { server, streams: Map([]), }
}

///|
/// The metadata a `trans_info` map carries, read as headers so a handler that already
/// knows `@header.Header` needs no second shape.
pub fn trans_info_headers(
  trans_info : Map[String, Bytes],
) -> Array[@header.Header] {
  let out : Array[@header.Header] = []
  for name, value in trans_info {
    out.push({ name: @utf8.encode(name), value, })
  }
  out
}

///|
/// The `trans_info` a header list becomes, which is how a caller's metadata reaches the
/// far end.
pub fn headers_trans_info(
  headers : Array[@header.Header],
) -> Map[String, Bytes] {
  let out : Map[String, Bytes] = Map([])
  for header in headers {
    out[@utf8.decode_lossy(header.name)] = header.value
  }
  out
}

///|
/// The body of a unary frame: everything between the header and the attachment.
fn unary_body(frame : Frame, request : Request) -> Bytes {
  let end = frame.payload.length() -
    request.attachment_size.reinterpret_as_int()
  if end < frame.header_len {
    return b""
  }
  frame.payload[frame.header_len:end].to_owned()
}

///|
fn decode_body(encoding : UInt32, body : Bytes) -> Bytes? {
  match encoding {
    0 => Some(body)
    g if g == compress_gzip => @wire.Encoding::Gzip.decode(body[:])
    z if z == compress_zlib => @wire.Encoding::Deflate.decode(body[:])
    _ => None
  }
}

///|
fn encode_body(encoding : UInt32, body : Bytes) -> Bytes {
  match encoding {
    0 => body
    g if g == compress_gzip => @wire.Encoding::Gzip.encode(body[:])
    z if z == compress_zlib => @wire.Encoding::Deflate.encode(body[:])
    _ => body
  }
}

///|
/// One frame in, the frames to write back. A frame this session cannot attribute is
/// answered with nothing rather than an error frame: the reference implementations treat
/// a DATA or CLOSE for an unknown stream as already finished.
pub fn Session::handle(self : Session, frame : Frame) -> Array[Bytes] {
  match frame.kind {
    Unary => [self.answer_unary(frame)]
    Init => self.open(frame)
    Data => self.receive(frame)
    Feedback => []
    Close => self.close(frame)
  }
}

///|
fn Session::answer_unary(self : Session, frame : Frame) -> Bytes {
  let request = Request::decode(frame.header()) catch {
    _ =>
      return unary_failure(
        0, ret_server_decode, "the request header did not decode",
      )
  }
  let body = match
    decode_body(request.content_encoding, unary_body(frame, request)) {
    Some(body) => body
    None =>
      return unary_failure(
        request.request_id,
        ret_server_decode,
        "the request body is compressed with an encoding this server does not read",
      )
  }
  let ctx : @stream.RpcContext = {
    path: request.path(),
    metadata: trans_info_headers(request.trans_info),
    deadline_millis: if request.timeout == 0 {
      None
    } else {
      Some(request.timeout.reinterpret_as_int())
    },
    resp_headers: [],
    resp_trailers: [],
    status_fail: None,
    error_details: [],
  }
  let (reply, ret, message) = match self.server.handler(ctx.path) {
    None => (None, ret_server_nofunc, "no method is registered at " + ctx.path)
    Some(handler) =>
      match handler {
        @stream.Handler::Unary(f) => {
          let reply = f(ctx, body)
          (Some(reply), 0, "")
        }
        _ =>
          (
            None,
            ret_server_nofunc,
            ctx.path + " is a streaming method; a unary call cannot reach it",
          )
      }
  }
  let (ret, message) = match ctx.status_fail {
    Some((code, why)) => (status_ret(@wire.Status::of(code)), why)
    None => (ret, message)
  }
  let response = {
    let response = Response::to(request)
    response.ret = ret
    response.error_msg = @utf8.encode(message)
    response
  }
  let header = response.encode()
  let reply = match reply {
    Some(reply) if ret == 0 => encode_body(request.content_encoding, reply)
    _ => b""
  }
  let payload = @buffer.Buffer()
  payload.write_bytes(header)
  payload.write_bytes(reply)
  Frame::new(
    Unary,
    request.request_id.to_int64(),
    payload.to_bytes(),
    header_len=header.length(),
  ).encode()
}

///|
fn unary_failure(request_id : UInt32, ret : Int32, message : String) -> Bytes {
  let response = Response::new(request_id~, ret~)
  response.error_msg = @utf8.encode(message)
  let header = response.encode()
  Frame::new(Unary, request_id.to_int64(), header, header_len=header.length()).encode()
}

///|
fn Session::open(self : Session, frame : Frame) -> Array[Bytes] {
  let meta = StreamInitMeta::decode(frame.payload) catch {
    _ =>
      return [
        stream_init_failure(
          frame.stream_id,
          ret_server_decode,
          "the INIT frame did not decode",
        ),
      ]
  }
  let path = meta.request_meta.path()
  let request = Request::new(
    caller=@utf8.decode_lossy(meta.request_meta.caller),
    callee=@utf8.decode_lossy(meta.request_meta.callee),
    func=path,
    request_id=frame.stream_id.to_int().reinterpret_as_uint(),
    content_type=meta.content_type,
    content_encoding=meta.content_encoding,
    trans_info=meta.request_meta.trans_info,
  )
  let ctx : @stream.RpcContext = {
    path,
    metadata: trans_info_headers(meta.request_meta.trans_info),
    deadline_millis: None,
    resp_headers: [],
    resp_trailers: [],
    status_fail: None,
    error_details: [],
  }
  match self.server.handler(path) {
    None =>
      return [
        stream_init_failure(
          frame.stream_id,
          ret_server_nofunc,
          "no method is registered at " + path,
        ),
      ]
    Some(handler) =>
      match handler {
        @stream.Handler::Unary(_) =>
          return [
            stream_init_failure(
              frame.stream_id,
              ret_server_nofunc,
              path + " is a unary method; a streaming call cannot reach it",
            ),
          ]
        _ => ()
      }
  }
  let bidi = match self.server.handler(path) {
    Some(@stream.Handler::Bidi(f)) => Some(f(ctx))
    _ => None
  }
  let live : Live = { path, ctx, request, inbound: [], bidi, }
  self.streams[frame.stream_id] = live
  let reply = StreamInitMeta::new(
    request_meta=meta.request_meta,
    response_meta=StreamInitResponseMeta::new(),
    window=init_window_size,
    content_type=meta.content_type,
    content_encoding=meta.content_encoding,
  )
  [
    Frame::new(Init, frame.stream_id, reply.encode()).encode(),
    feedback(frame.stream_id, meta.window),
  ]
}

///|
fn stream_init_failure(
  stream_id : Int64,
  ret : Int32,
  message : String,
) -> Bytes {
  let meta = StreamInitMeta::new(
    response_meta=StreamInitResponseMeta::new(ret~, error_msg=message),
  )
  Frame::new(Init, stream_id, meta.encode()).encode()
}

///|
fn feedback(stream_id : Int64, increment : UInt32) -> Bytes {
  Frame::new(
    Feedback,
    stream_id,
    StreamFeedbackMeta::new(window_increment=increment).encode(),
  ).encode()
}

///|
fn Session::receive(self : Session, frame : Frame) -> Array[Bytes] {
  match self.streams.get(frame.stream_id) {
    None => []
    Some(live) =>
      match live.bidi {
        Some(bidi) => {
          let replies = (bidi.on_message)(frame.payload)
          let out = []
          for reply in replies {
            out.push(Frame::new(Data, frame.stream_id, reply).encode())
          }
          // Grant back what this frame cost, which is what keeps a sender that honours
          // the window going on a long stream.
          out.push(
            feedback(
              frame.stream_id,
              frame.payload.length().reinterpret_as_uint(),
            ),
          )
          out
        }
        None => {
          live.inbound.push(frame.payload)
          [
            feedback(
              frame.stream_id,
              frame.payload.length().reinterpret_as_uint(),
            ),
          ]
        }
      }
  }
}

///|
fn Session::close(self : Session, frame : Frame) -> Array[Bytes] {
  let live = match self.streams.get(frame.stream_id) {
    None => return []
    Some(live) => live
  }
  let meta = StreamCloseMeta::decode(frame.payload) catch {
    _ => StreamCloseMeta::new()
  }
  self.streams.remove(frame.stream_id)
  if meta.close_type == close_reset {
    let reset = StreamCloseMeta::new(close_type=close_reset)
    return [Frame::new(Close, frame.stream_id, reset.encode()).encode()]
  }
  let (replies, ret, message) = match live.bidi {
    Some(bidi) => {
      let replies = (bidi.on_end)()
      (replies, 0, "")
    }
    None =>
      match self.server.handler(live.path) {
        None =>
          ([], ret_server_nofunc, "no method is registered at " + live.path)
        Some(handler) =>
          match handler {
            @stream.Handler::ServerStreaming(f) =>
              match live.inbound {
                [one, ..] => (f(live.ctx, one), 0, "")
                [] =>
                  (
                    [],
                    ret_server_decode,
                    "the stream carried no request message",
                  )
              }
            @stream.Handler::ClientStreaming(f) =>
              ([f(live.ctx, live.inbound)], 0, "")
            _ =>
              (
                [],
                ret_server_nofunc,
                live.path + " has no handler for a streaming call",
              )
          }
      }
  }
  let (ret, message) = match live.ctx.status_fail {
    Some((code, why)) => (status_ret(@wire.Status::of(code)), why)
    None => (ret, message)
  }
  let out = []
  for reply in replies {
    out.push(
      Frame::new(
        Data,
        frame.stream_id,
        encode_body(live.request.content_encoding, reply),
      ).encode(),
    )
  }
  let closing = StreamCloseMeta::new(ret~, message~)
  for header in live.ctx.resp_trailers {
    closing.trans_info[@utf8.decode_lossy(header.name)] = header.value
  }
  out.push(Frame::new(Close, frame.stream_id, closing.encode()).encode())
  out
}

///|
/// The streams this session still holds open, for a driver that has to report them.
pub fn Session::open_streams(self : Session) -> Int32 {
  let mut n = 0
  for _, _ in self.streams {
    n = n + 1
  }
  n
}
