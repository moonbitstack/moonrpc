// Reconnecting after a backend fails: the channel waits out the backoff before dialling
// again, and picks the backend up once it answers.

///|
/// A backoff with no jitter and a fixed wait, so a test can time it.
fn fixed_backoff(millis : Int64) -> @moonrpc.Backoff {
  @moonrpc.Backoff::new(
    initial=@moondate.Span::new(millis~),
    max=@moondate.Span::new(millis~),
    factor=1.0,
    jitter=0.0,
  )
}

///|
async test "backoff: a failed dial puts the channel on a clock, not on a retry storm" {
  // Nothing listens here. The dial at connect time fails and arms the clock.
  let chan = ManagedChannel::connect(
    [("127.0.0.1", 18261)],
    backoff=fixed_backoff(60_000L),
    rand=() => 0.5,
  )
  let down = chan.unary("/echo.Echo/Say", b"x")
  assert_eq(down.grpc_status, @moonrpc.Status::code(Unavailable))
  // A second call does not dial again: the wait has not passed, so it answers the same way
  // without touching the socket — which is what keeps a hundred callers from becoming a
  // hundred dials at once.
  let too_soon = chan.unary("/echo.Echo/Say", b"x")
  assert_eq(too_soon.grpc_status, @moonrpc.Status::code(Unavailable))
  assert_true(chan.reconnect.wait_millis(@async.now()) > 0L)
  assert_eq(chan.channels.length(), 0)
}

///|
async test "backoff: once the wait is over, the channel dials again and finds the backend" {
  @async.with_task_group(g => {
    // A short wait, so the reconnect happens inside the test.
    let chan = ManagedChannel::connect(
      [("127.0.0.1", 18262)],
      backoff=fixed_backoff(200L),
      rand=() => 0.5,
    )
    let down = chan.unary("/echo.Echo/Say", b"x")
    assert_eq(down.grpc_status, @moonrpc.Status::code(Unavailable))
    // The backend comes up while the channel is waiting.
    let server = GrpcServer::new()
    server.register("/echo.Echo/Say", req => b"echo:" + req)
    let task = g.spawn(() => server.serve(port=18262))
    @async.sleep(400)
    let after = chan.unary("/echo.Echo/Say", b"x")
    assert_eq(after.grpc_status, 0)
    assert_eq(after.messages[0], b"echo:x")
    chan.close()
    task.cancel()
  })
}

///|
async test "backoff: a settled channel keeps answering without waiting" {
  @async.with_task_group(g => {
    let server = GrpcServer::new()
    server.register("/echo.Echo/Say", req => req)
    let task = g.spawn(() => server.serve(port=18263))
    @async.sleep(300)
    let chan = ManagedChannel::connect(
      [("127.0.0.1", 18263)],
      backoff=fixed_backoff(5000L),
      rand=() => 0.5,
    )
    // A channel whose dial worked has no wait on it: a long backoff must not slow the
    // first call down.
    let started = @async.now()
    let reply = chan.unary("/echo.Echo/Say", b"hello")
    assert_eq(reply.grpc_status, 0)
    assert_true(@async.now() - started < 1000L)
    chan.close()
    task.cancel()
  })
}
