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
/// A streaming call in progress, which the caller drives message by message. This is the shape
/// a bidirectional call needs: send one, read the answers to it, send the next. A call that
/// sends everything before reading anything is the same object used without `next` in between.
pub struct Exchange {
  priv client : Client
  priv id : Int64
  // Whether the far end has closed, so a caller may keep asking and get `None`.
  priv mut ended : Bool
  // The replies that arrived while nothing was reading them — a call that closes its send side
  // before reading gets all of them here.
  priv queue : Array[Bytes]
  priv trailers : Array[@header.Header]
  // Octets the far end still permits this call to send, as INIT and FEEDBACK frames count it.
  // Negative means the far end named no window, and this end does not throttle: a peer that
  // never said how much it can take is not one to stall on a number it never gave.
  priv mut send_window : Int64
}

///|
/// Open a stream: INIT out, and the far end's INIT read before the first message, so a refusal
/// is a refusal of the call rather than of a message in it.
pub async fn Client::open(
  self : Client,
  path : String,
  metadata~ : Array[@header.Header] = [],
  content_encoding~ : UInt32 = compress_none,
) -> Exchange raise @wire.StatusError {
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
  let exchange : Exchange = {
    client: self,
    id,
    ended: false,
    queue: [],
    trailers: [],
    send_window: -1L,
  }
  exchange.write(Frame::new(Init, id, init.encode()))
  for ;; {
    let frame = self.receive()
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
        // The window the far end opened with. Zero is "no window named", not "no room".
        exchange.send_window = if meta.window == 0 {
          -1L
        } else {
          meta.window.to_int64()
        }
        break
      }
      Close => {
        exchange.finish_with(frame)
        break
      }
      _ => ()
    }
  }
  exchange
}

///|
/// One message out.
pub async fn Exchange::send(
  self : Exchange,
  body : Bytes,
) -> Unit raise @wire.StatusError {
  guard !self.ended else {
    raise @wire.StatusError(Internal, "a message after the stream closed")
  }
  if self.send_window >= 0 && body.length().to_int64() > self.send_window {
    self.await_window(body.length().to_int64())
  }
  self.write(Frame::new(Data, self.id, body))
  if self.send_window >= 0 {
    self.send_window = self.send_window - body.length().to_int64()
  }
}

///|
/// Wait until the far end's window can take `needed` octets. Frames that arrive while waiting
/// are not lost: a reply goes to the queue, a CLOSE ends the call, and a FEEDBACK adds its
/// credit. A message larger than the window as it stands waits for the credit that covers it,
/// which is what the window is for — writing past it is what a strict peer closes a connection
/// over, and tRPC-Go does.
async fn Exchange::await_window(
  self : Exchange,
  needed : Int64,
) -> Unit raise @wire.StatusError {
  while self.send_window >= 0 && self.send_window < needed && !self.ended {
    let frame = self.client.receive()
    if frame.stream_id != self.id {
      continue
    }
    match frame.kind {
      Feedback => {
        let meta = StreamFeedbackMeta::decode(frame.payload) catch {
          _ => StreamFeedbackMeta::new()
        }
        self.send_window = self.send_window + meta.window_increment.to_int64()
      }
      Data => {
        self.credit(frame.payload.length())
        self.queue.push(frame.payload)
      }
      Close => self.finish_with(frame)
      _ => ()
    }
  }
}

///|
/// Hand the far end back the window one consumed message cost. Without this a long stream
/// stops after the first window's worth: the peer has no other way to learn that the message
/// left this end's buffer.
async fn Exchange::credit(
  self : Exchange,
  octets : Int32,
) -> Unit raise @wire.StatusError {
  let meta = StreamFeedbackMeta::new(
    window_increment=octets.reinterpret_as_uint(),
  )
  self.write(Frame::new(Feedback, self.id, meta.encode()))
}

///|
/// The next message the far end sent, or `None` once it has closed the stream.
pub async fn Exchange::next(self : Exchange) -> Bytes? raise @wire.StatusError {
  if self.queue.length() > 0 {
    return Some(self.queue.remove(0))
  }
  if self.ended {
    return None
  }
  for ;; {
    let frame = self.client.receive()
    if frame.stream_id != self.id {
      continue
    }
    match frame.kind {
      Data => {
        self.credit(frame.payload.length())
        return Some(frame.payload)
      }
      Close => {
        self.finish_with(frame)
        return None
      }
      _ => ()
    }
  }
}

///|
/// Close the send side and read what the far end still owes: the messages this call never
/// asked for land in [`Exchange::replies`] once the stream is over.
///
/// Nothing is written after the CLOSE. A FEEDBACK for a message that arrives behind it is a
/// frame for a stream the far end has already forgotten — tRPC-Go answers one with
/// `uninitialized meta` and drops the connection — and the window it would have returned is
/// worth nothing to a stream that is ending.
pub async fn Exchange::close(self : Exchange) -> Unit raise @wire.StatusError {
  if self.ended {
    return
  }
  self.write(Frame::new(Close, self.id, StreamCloseMeta::new().encode()))
  for ;; {
    let frame = self.client.receive()
    if frame.stream_id != self.id {
      continue
    }
    match frame.kind {
      Data => self.queue.push(frame.payload)
      Close => {
        self.finish_with(frame)
        break
      }
      _ => ()
    }
  }
}

///|
/// The messages that arrived while the send side was still open, in the order they came.
pub fn Exchange::replies(self : Exchange) -> Array[Bytes] {
  self.queue
}

///|
/// The trailing metadata the far end closed with.
pub fn Exchange::trailers(self : Exchange) -> Array[@header.Header] {
  self.trailers
}

///|
/// Whether the far end has closed.
pub fn Exchange::ended(self : Exchange) -> Bool {
  self.ended
}

///|
async fn Exchange::write(
  self : Exchange,
  frame : Frame,
) -> Unit raise @wire.StatusError {
  self.client.link.write(frame.encode()) catch {
    error => raise @wire.StatusError(Unavailable, error.to_string())
  }
}

///|
/// Take the outcome a CLOSE frame carries: OK closes the stream, anything else is raised, and
/// the metadata the far end attached is kept.
fn Exchange::finish_with(
  self : Exchange,
  frame : Frame,
) -> Unit raise @wire.StatusError {
  self.ended = true
  let meta = StreamCloseMeta::decode(frame.payload) catch {
    _ => StreamCloseMeta::new()
  }
  for name, value in meta.trans_info {
    self.trailers.push({ name: @utf8.encode(name), value, })
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
}

///|
/// One frame from the far end, as the call's own failure if the link is gone.
async fn Client::receive(self : Client) -> Frame raise @wire.StatusError {
  self.link.read() catch {
    error => raise @wire.StatusError(Unavailable, error.to_string())
  }
}

///|
/// A client-streaming call: every request out, then the one reply. The send side closes before
/// anything is read, which is what tells the far end that the requests are all there.
pub async fn Client::client_stream(
  self : Client,
  path : String,
  requests : Array[Bytes],
  metadata~ : Array[@header.Header] = [],
  content_encoding~ : UInt32 = compress_none,
) -> Bytes raise @wire.StatusError {
  let exchange = self.open(path, metadata~, content_encoding~)
  for request in requests {
    exchange.send(request)
  }
  exchange.close()
  match exchange.replies() {
    [one, ..] => one
    [] =>
      raise @wire.StatusError(
        Internal,
        "a client-streaming call answered no message",
      )
  }
}

///|
/// A bidirectional call driven to its end: every request out, then every reply, in the order
/// they arrived. A caller that wants the answers while it is still sending uses
/// [`Client::open`] instead.
pub async fn Client::bidi(
  self : Client,
  path : String,
  requests : Array[Bytes],
  metadata~ : Array[@header.Header] = [],
  content_encoding~ : UInt32 = compress_none,
) -> Array[Bytes] raise @wire.StatusError {
  let exchange = self.open(path, metadata~, content_encoding~)
  for request in requests {
    exchange.send(request)
  }
  exchange.close()
  exchange.replies()
}

///|
/// A streaming call: INIT, one DATA per request, CLOSE, then every reply until the far end
/// closes. It is [`Client::bidi`] under a name that says what the four cardinalities of gRPC
/// call it, and the messages come back in the order they arrived.
pub async fn Client::stream(
  self : Client,
  path : String,
  requests : Array[Bytes],
  metadata~ : Array[@header.Header] = [],
  content_encoding~ : UInt32 = compress_none,
) -> Array[Bytes] raise @wire.StatusError {
  self.bidi(path, requests, metadata~, content_encoding~)
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
