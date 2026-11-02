// Server-side interceptors: one chain wrapped around every method, whatever its call
// kind. An interceptor sees a call the way the engine does — the request messages it
// carries and the replies it produces — so one shape covers all four kinds: a unary
// call has one request and one reply, a streaming side has many. Registration order is
// outer-to-inner: the first-registered interceptor runs first and wraps the rest.
//
// A bidirectional call is the one shape whose messages arrive over time, so its chain
// runs once per batch of requests and once at half-close with none, which is where
// `BidiHandler::on_end` answers.

///|
/// What a call is, apart from the messages in it: the path, and which of gRPC's two
/// streaming sides it has. An interceptor that only wants unary calls reads this and
/// passes anything else straight on.
pub(all) struct CallInfo {
  path : String
  client_streaming : Bool
  server_streaming : Bool
}

///|
/// A server interceptor: `(info, ctx, requests, next) -> replies`. Call `next(requests)`
/// to run the rest of the chain, with the messages possibly changed; return without
/// calling it to answer the call itself.
pub type Interceptor = (
  CallInfo,
  @stream.RpcContext,
  Array[Bytes],
  (Array[Bytes]) -> Array[Bytes],
) -> Array[Bytes]

///|
/// A unary server interceptor: `(ctx, request, next) -> reply`, the shape gRPC-go calls a
/// unary interceptor. It applies to unary methods only; [`Interceptor`] covers every kind.
pub type UnaryInterceptor = (
  @stream.RpcContext,
  Bytes,
  (@stream.RpcContext, Bytes) -> Bytes,
) -> Bytes

///|
/// A server-streaming interceptor: `(ctx, request, next) -> replies`. It applies to
/// server-streaming methods only.
pub type StreamInterceptor = (
  @stream.RpcContext,
  Bytes,
  (@stream.RpcContext, Bytes) -> Array[Bytes],
) -> Array[Bytes]

///|
/// Add an interceptor to the server's chain. It runs on every method the server serves,
/// whichever of the four call kinds it is; interceptors run in registration order,
/// outermost first.
pub fn H2Server::add_interceptor(
  self : H2Server,
  interceptor : Interceptor,
) -> Unit {
  self.interceptors.push(interceptor)
}

///|
/// Add a unary interceptor. It is an [`Interceptor`] that only answers unary calls, the
/// one-request-one-reply shape; every other kind passes through untouched.
pub fn H2Server::add_unary_interceptor(
  self : H2Server,
  interceptor : UnaryInterceptor,
) -> Unit {
  self.interceptors.push((info, ctx, requests, next) => {
    if info.client_streaming || info.server_streaming {
      return next(requests)
    }
    let request = if requests.length() > 0 { requests[0] } else { b"" }
    let reply = interceptor(ctx, request, (_c, r) => {
      let replies = next([r])
      if replies.length() > 0 {
        replies[0]
      } else {
        b""
      }
    })
    [reply]
  })
}

///|
/// Add a server-streaming interceptor: one request, an ordered run of replies.
pub fn H2Server::add_stream_interceptor(
  self : H2Server,
  interceptor : StreamInterceptor,
) -> Unit {
  self.interceptors.push((info, ctx, requests, next) => {
    if info.client_streaming || !info.server_streaming {
      return next(requests)
    }
    let request = if requests.length() > 0 { requests[0] } else { b"" }
    interceptor(ctx, request, (_c, r) => next([r]))
  })
}

///|
/// Run a call through the chain: `base` is the registered handler, adapted to
/// `requests -> replies`.
fn H2Server::intercepted(
  self : H2Server,
  info : CallInfo,
  ctx : @stream.RpcContext,
  requests : Array[Bytes],
  base : (Array[Bytes]) -> Array[Bytes],
) -> Array[Bytes] {
  let mut h = base
  for i = self.interceptors.length() - 1; i >= 0; i = i - 1 {
    let interceptor = self.interceptors[i]
    let next = h
    h = messages => interceptor(info, ctx, messages, next)
  }
  h(requests)
}

///|
/// The shape of a call a registered handler serves.
fn @stream.Handler::info(self : @stream.Handler, path : String) -> CallInfo {
  match self {
    Unary(_) => { path, client_streaming: false, server_streaming: false, }
    ServerStreaming(_) =>
      { path, client_streaming: false, server_streaming: true, }
    ClientStreaming(_) =>
      { path, client_streaming: true, server_streaming: false, }
    Bidi(_) => { path, client_streaming: true, server_streaming: true, }
  }
}
