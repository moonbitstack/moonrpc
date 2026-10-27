// gRPC A6 retries and hedging as the pure decisions a channel asks after each
// attempt: whether to go again and how long to wait, what a server's pushback does,
// and how the throttle shared by one server's calls cuts retries off. The channel
// does the sending and the sleeping.
//
//     moon run src/examples/21-retry-hedging

///|
fn wait(span : @moondate.Span?) -> String {
  match span {
    Some(s) => "again after \{s.nanos / 1_000_000L} ms"
    None => "hand the reply back"
  }
}

///|
fn run() -> Unit {
  let unavailable = @moonrpc.Status::code(Unavailable)
  let not_found = @moonrpc.Status::code(NotFound)

  // A6's example policy: four attempts, 100 ms doubling to 1 s, a fifth either way.
  // A roll of 0.5 sits mid-spread, so the waits are the schedule itself.
  println("retry, UNAVAILABLE every time:")
  let call = @moonrpc.Attempts::new(retry=@moonrpc.retry)
  for _ in 0..<4 {
    println("  attempt \{call.made()}: \{wait(call.next(unavailable, []))}")
  }
  let other = @moonrpc.Attempts::new(retry=@moonrpc.retry)
  println("retry, NOT_FOUND: \{wait(other.next(not_found, []))}")

  // The server can name the wait, or refuse any more.
  let after : Array[@header.Header] = [
    @header.Header::of("grpc-retry-pushback-ms", "750"),
  ]
  let stop : Array[@header.Header] = [
    @header.Header::of("grpc-retry-pushback-ms", "-1"),
  ]
  let pushed = @moonrpc.Attempts::new(retry=@moonrpc.retry)
  println("pushback 750: \{wait(pushed.next(unavailable, after))}")
  println("then plain:   \{wait(pushed.next(unavailable, []))}")
  let refused = @moonrpc.Attempts::new(retry=@moonrpc.retry)
  println("pushback -1:  \{wait(refused.next(unavailable, stop))}")

  // A stream the server refused goes again at once, policy or not, uncounted.
  let bare = @moonrpc.Attempts::new()
  println(
    "refused stream: \{wait(bare.next(unavailable, [], unprocessed=true))}",
  )

  // Ten tokens, a tenth back per success: at five or fewer, nobody retries.
  let throttle = @moonrpc.Throttle::new(
    @moonrpc.Throttling::new(tokens=10, ratio=0.1),
  )
  for i in 0..<6 {
    let c = @moonrpc.Attempts::new(retry=@moonrpc.retry, throttle~)
    let next = wait(c.next(unavailable, []))
    println("call \{i + 1} fails, \{throttle.tokens()} tokens left: \{next}")
  }

  // Hedging: the next attempt starts every 500 ms, or at once after a non-fatal
  // status; anything else settles the call.
  let hedge = @moonrpc.hedging
  println("hedging, four attempts:")
  println("  a fifth may start: \{hedge.more(4)}")
  println("  UNAVAILABLE settles the call: \{hedge.commits(unavailable)}")
  println("  NOT_FOUND settles the call:   \{hedge.commits(not_found)}")
}

///|
#coverage.skip
fn main {
  run()
}
