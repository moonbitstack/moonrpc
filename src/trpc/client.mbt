// The tRPC client half: one call is one frame out and one frame back, or a stream of
// frames either way. Written against a link that moves bytes, so the socket is `net/`'s
// business and a test needs none.

///|
/// Where a client's frames go. A link owns one connection and hands one frame at a time,
/// which is what a multiplexed stream needs and what a test double stands in for.
pub(open) trait Link {
  async fn write(Self, Bytes) -> Unit raise TrpcError
  async fn read(Self) -> Frame raise TrpcError
}

///|
/// A client over one link. `caller` is the name the far end sees; `next_id` numbers calls
/// the way the reference implementations do, from one, so a trace of this client reads
/// like a trace of theirs.
pub struct Client {
  link : &Link
  caller : String
  streams : Set[String]
  mut next_id : Int64
}

///|
pub fn Client::new(link : &Link, caller~ : String = "moonrpc.client") -> Client {
  { link, caller, streams: Set([]), next_id: 0, }
}

///|
/// Treat the methods of `file` as streaming, so a generated stub's call reaches a
/// streaming method with the frames a streaming method expects. A path nothing declared
/// is a unary call.
pub fn Client::declare_streams(
  self : Client,
  file : @proto.FileDescriptor,
) -> Unit {
  for service in file.services {
    for definition in service.methods {
      if definition.client_streaming || definition.server_streaming {
        self.streams.add("/" + service.name + "/" + definition.name)
      }
    }
  }
}

///|
fn Client::id(self : Client) -> Int64 {
  self.next_id = self.next_id + 1
  self.next_id
}

///|
/// The service part of a path: `/package.Service/Method` names `package.Service`.
fn callee_of(path : String) -> String {
  match path.split("/").collect() {
    ["", service, ..] => service.to_owned()
    _ => path
  }
}

///|
/// Whether a reply's code means the call failed, and what to raise when it does. A
/// failure a handler chose travels in `func_ret`; one the framework reports, in `ret`.
fn refuse(response : Response) -> Unit raise @wire.StatusError {
  if response.ret != 0 {
    raise @wire.StatusError(
      ret_status(response.ret),
      @utf8.decode_lossy(response.error_msg),
    )
  }
  if response.func_ret != 0 {
    raise @wire.StatusError(
      @wire.Status::of(response.func_ret),
      @utf8.decode_lossy(response.error_msg),
    )
  }
}

///|
/// One unary call: the request frame out, the reply frame back.
pub async fn Client::unary(
  self : Client,
  path : String,
  body : Bytes,
  metadata~ : Array[@header.Header] = [],
  timeout_millis? : Int32,
  content_encoding~ : UInt32 = compress_none,
) -> Bytes raise @wire.StatusError {
  let id = self.id()
  let request = Request::new(
    caller=self.caller,
    callee=callee_of(path),
    func=path,
    request_id=id.to_int().reinterpret_as_uint(),
    timeout=match timeout_millis {
      Some(millis) => if millis > 0 { millis.reinterpret_as_uint() } else { 0 }
      None => 0
    },
    content_encoding~,
    trans_info=headers_trans_info(metadata),
  )
  let header = request.encode()
  let payload = @buffer.Buffer()
  payload.write_bytes(header)
  payload.write_bytes(encode_body(content_encoding, body))
  let frame = Frame::new(
    Unary,
    id,
    payload.to_bytes(),
    header_len=header.length(),
  )
  self.link.write(frame.encode()) catch {
    error => raise @wire.StatusError(Unavailable, error.to_string())
  }
  let reply = self.link.read() catch {
    error => raise @wire.StatusError(Unavailable, error.to_string())
  }
  guard reply.kind == Unary else {
    raise @wire.StatusError(
      Internal,
      "a unary call was answered with a streaming frame",
    )
  }
  let response = Response::decode(reply.header()) catch {
    _ => raise @wire.StatusError(Internal, "the reply header did not decode")
  }
  refuse(response)
  match decode_body(response.content_encoding, reply.body()) {
    Some(body) => body
    None =>
      raise @wire.StatusError(Internal, "the reply body did not decompress")
  }
}

///|
/// A streaming call: INIT, one DATA per request, CLOSE, then every reply until the far
/// end closes. The messages come back in the order they arrived.
pub async fn Client::stream(
  self : Client,
  path : String,
  requests : Array[Bytes],
  metadata~ : Array[@header.Header] = [],
  content_encoding~ : UInt32 = compress_none,
) -> Array[Bytes] raise @wire.StatusError {
  let id = self.id()
  let init = StreamInitMeta::new(
    request_meta=StreamInitRequestMeta::new(
      caller=self.caller,
      callee=callee_of(path),
      func=path,
      trans_info=headers_trans_info(metadata),
    ),
    content_encoding~,
  )
  let out : Array[Bytes] = []
  let send = async fn(frame : Frame) -> Unit raise @wire.StatusError {
    self.link.write(frame.encode()) catch {
      error => raise @wire.StatusError(Unavailable, error.to_string())
    }
  }
  send(Frame::new(Init, id, init.encode()))
  for body in requests {
    send(Frame::new(Data, id, encode_body(content_encoding, body)))
  }
  send(Frame::new(Close, id, StreamCloseMeta::new().encode()))
  for ;; {
    let frame = self.link.read() catch {
      error => raise @wire.StatusError(Unavailable, error.to_string())
    }
    if frame.stream_id != id {
      continue
    }
    match frame.kind {
      Init => {
        let meta = StreamInitMeta::decode(frame.payload) catch {
          _ =>
            raise @wire.StatusError(Internal, "the INIT frame did not decode")
        }
        if meta.response_meta.ret != 0 {
          raise @wire.StatusError(
            ret_status(meta.response_meta.ret),
            @utf8.decode_lossy(meta.response_meta.error_msg),
          )
        }
      }
      Data =>
        match decode_body(content_encoding, frame.payload) {
          Some(body) => out.push(body)
          None =>
            raise @wire.StatusError(Internal, "a reply body did not decompress")
        }
      Close => {
        let meta = StreamCloseMeta::decode(frame.payload) catch {
          _ => StreamCloseMeta::new()
        }
        if meta.ret != 0 || meta.func_ret != 0 {
          raise @wire.StatusError(
            if meta.ret != 0 {
              ret_status(meta.ret)
            } else {
              @wire.Status::of(meta.func_ret)
            },
            @utf8.decode_lossy(meta.message),
          )
        }
        break
      }
      _ => ()
    }
  }
  out
}

///|
/// One call through the generated stubs. A path the client was told is streaming takes
/// the four-frame route; anything else is a unary call, and more than one request on a
/// unary path is what gRPC calls a cardinality violation.
pub impl @client.Caller for Client with fn invoke(
  self,
  path,
  requests,
  metadata,
  timeout_millis,
  retry,
) {
  if retry is Some(_) {
    raise @wire.StatusError(
      Unimplemented,
      "a tRPC client does not retry; a call is one frame on one connection",
    )
  }
  let messages = if self.streams.contains(path) {
    self.stream(path, requests, metadata~)
  } else {
    match requests {
      [request] => [self.unary(path, request, metadata~, timeout_millis?)]
      _ =>
        raise @wire.StatusError(
          InvalidArgument,
          "a unary tRPC call carries exactly one request message",
        )
    }
  }
  {
    status: b"",
    grpc_status: 0,
    grpc_message: "",
    headers: [],
    messages,
    trailers: [],
    committed: true,
    unprocessed: false,
  }
}

///|
pub extend Client with @client.Caller::{invoke}
