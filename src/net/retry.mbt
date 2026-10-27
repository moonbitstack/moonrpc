// Driving one call through its attempts (gRPC A6): send, ask `Attempts` what next,
// sleep, send again with `grpc-previous-rpc-attempts`, all inside the one deadline.

///|
/// The reply a call gets when its deadline passes between attempts.
fn deadline_reply() -> @moonrpc.CallReply {
  {
    status: b"",
    grpc_status: @moonrpc.Status::code(DeadlineExceeded),
    grpc_message: "deadline exceeded",
    headers: [],
    messages: [],
    trailers: [],
    committed: false,
    unprocessed: false,
  }
}

///|
/// The metadata of an attempt that follows `previous` others under the policy.
fn with_previous(
  metadata : Array[@header.Header],
  previous : Int32,
) -> Array[@header.Header] {
  guard previous > 0 else { return metadata }
  let out = metadata.filter(h => h.name != b"grpc-previous-rpc-attempts")
  out.push(
    @header.Header::of("grpc-previous-rpc-attempts", previous.to_string()),
  )
  out
}

///|
/// Run `once` until `attempts` hands a reply back. `once` gets each attempt's metadata
/// and its share of the deadline: what is left of `timeout_millis` when it starts, so
/// the server's `grpc-timeout` is never longer than the call has.
async fn attempting(
  attempts : @moonrpc.Attempts,
  roll : () -> Double,
  metadata : Array[@header.Header],
  timeout_millis : Int32?,
  once : async (Array[@header.Header], Int32?) -> @moonrpc.CallReply,
) -> @moonrpc.CallReply {
  let left = budget(timeout_millis)
  let run = () => {
    let mut reply = once(metadata, timeout_millis)
    while attempts.next(
            reply.grpc_status,
            reply.trailers,
            committed=reply.committed,
            unprocessed=reply.unprocessed,
            roll=roll(),
          )
          is Some(wait) {
      let ms = (wait.nanos / 1_000_000L).to_int()
      if ms > 0 {
        @async.sleep(ms)
      }
      reply = once(with_previous(metadata, attempts.made() - 1), left())
    }
    reply
  }
  match timeout_millis {
    None => run()
    Some(ms) =>
      match (@async.with_timeout_opt(ms, run) : @moonrpc.CallReply?) {
        Some(reply) => reply
        None => deadline_reply()
      }
  }
}

///|
/// What is left of `timeout_millis` each time it is asked, never below a
/// millisecond; nothing when there is no deadline.
fn budget(timeout_millis : Int32?) -> () -> Int32? {
  let start = @async.now()
  () => {
    timeout_millis.map(ms => {
      let rest = ms.to_int64() - (@async.now() - start)
      (if rest < 1L { 1L } else { rest }).to_int()
    })
  }
}

///|
/// A draw from `[0, 1)` for the backoff jitter.
fn system_roll() -> () -> Double {
  let source = @random.Rand()
  () => source.double()
}
