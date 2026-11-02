// Client interceptors: one chain wrapped around every call, whatever its kind. An
// interceptor sees an invocation the way the channel does — the method, every request
// message, the metadata, the deadline and the retry policy — so one shape covers unary,
// server-, client- and bidirectional streaming: a unary call simply carries one request.
// Registration order is outer-to-inner: the first interceptor runs first and wraps the
// rest.

///|
/// One call as an interceptor sees it: the method, the request messages it carries, the
/// metadata it goes out with, its deadline in milliseconds and its retry policy.
pub(all) struct Invocation {
  path : String
  requests : Array[Bytes]
  metadata : Array[@header.Header]
  timeout_millis : Int32?
  retry : @balance.Retry?
}

///|
/// A client interceptor: `(invocation, next) -> reply`. Change the invocation and hand it
/// to `next` to let the call go out, look at the reply on the way back, or answer the call
/// itself without calling `next`.
pub type Interceptor = async (Invocation, async (Invocation) -> CallReply) -> CallReply

///|
/// Fold `chain` around `base` so the first interceptor is the outermost. With an empty
/// chain this is `base` unchanged.
pub fn intercepted(
  chain : Array[Interceptor],
  base : async (Invocation) -> CallReply,
) -> async (Invocation) -> CallReply {
  let mut h = base
  for i = chain.length() - 1; i >= 0; i = i - 1 {
    let interceptor = chain[i]
    let next = h
    h = invocation => interceptor(invocation, next)
  }
  h
}
