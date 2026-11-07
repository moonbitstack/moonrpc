///|
/// Hedging exists to race attempts, so the parallel path is the one that matters.
/// With one backend there is nothing to hedge onto, so exactly one attempt must run
/// and the call must still answer normally.
async test "hedging with no delay does not double up on a single backend" {
  @async.with_task_group(g => {
    let count = [0]
    let backend = GrpcServer::new()
    backend.register("/echo.E/Say", req => {
      count[0] = count[0] + 1
      b"A:" + req
    })
    let port_18193 = backend.bind(port=0).port()
    let tb = g.spawn(() => backend.serve())
    @async.sleep(300)
    let chan = ManagedChannel::connect([("127.0.0.1", port_18193)])
    let policy = @moonrpc.Hedging::new(
      attempts=3,
      delay=@moondate.Span::new(millis=0L),
    )
    let r = chan.unary_hedged("/echo.E/Say", b"x", hedging=policy)
    assert_eq(r.grpc_status, 0)
    assert_eq(r.messages[0] == b"A:x", true)
    assert_eq(count[0], 1)
    chan.close()
    tb.cancel()
  })
}

///|
/// Two backends and no delay is the case the fix exists for: both attempts start at
/// once, land on different channels, and the call answers normally instead of putting
/// two readers on one socket.
async test "hedging runs two attempts in parallel across two backends" {
  @async.with_task_group(g => {
    let a_hits = [0]
    let b_hits = [0]
    let a = GrpcServer::new()
    a.register("/echo.E/Say", req => {
      a_hits[0] = a_hits[0] + 1
      b"A:" + req
    })
    let b = GrpcServer::new()
    b.register("/echo.E/Say", req => {
      b_hits[0] = b_hits[0] + 1
      b"B:" + req
    })
    let port_18194 = a.bind(port=0).port()
    let ta = g.spawn(() => a.serve())
    let port_18195 = b.bind(port=0).port()
    let tb2 = g.spawn(() => b.serve())
    @async.sleep(300)
    let chan = ManagedChannel::connect([
      ("127.0.0.1", port_18194),
      ("127.0.0.1", port_18195),
    ])
    let policy = @moonrpc.Hedging::new(
      attempts=2,
      delay=@moondate.Span::new(millis=0L),
    )
    let r = chan.unary_hedged("/echo.E/Say", b"x", hedging=policy)
    assert_eq(r.grpc_status, 0)
    // Whichever committed, at most one attempt reached each backend — never two on one.
    assert_eq(a_hits[0] <= 1, true)
    assert_eq(b_hits[0] <= 1, true)
    assert_eq(a_hits[0] + b_hits[0] >= 1, true)
    chan.close()
    ta.cancel()
    tb2.cancel()
  })
}

///|
/// Two backends for the A6 cases: the first answers UNAVAILABLE, with `pushback` in
/// its trailers when given; the second answers OK. Each counts its calls.
async fn pair(
  g : @async.TaskGroup[Unit],
  counts : Array[Int32],
  pushback~ : Bytes = b"",
) -> (@async.Task[Unit], @async.Task[Unit], Int32, Int32) {
  let a = GrpcServer::new()
  a.register_unary("/echo.E/Say", (ctx, _req) => {
    counts[0] = counts[0] + 1
    if pushback.length() > 0 {
      ctx.add_trailer(b"grpc-retry-pushback-ms", pushback)
    }
    ctx.fail(@moonrpc.Status::code(Unavailable), "down")
    b""
  })
  let b = GrpcServer::new()
  b.register("/echo.E/Say", req => {
    counts[1] = counts[1] + 1
    b"B:" + req
  })
  let first = a.bind(port=0).port()
  let second = b.bind(port=0).port()
  (g.spawn(() => a.serve()), g.spawn(() => b.serve()), first, second)
}

///|
async test "a non-fatal status sends the next hedge at once, not after the delay" {
  @async.with_task_group(g => {
    let counts = [0, 0]
    let (ta, tb, p1, p2) = pair(g, counts)
    @async.sleep(300)
    let chan = ManagedChannel::connect([
      ("127.0.0.1", p1),
      ("127.0.0.1", p2),
    ])
    // Ten seconds between hedges; the call is bounded to three, so only the
    // shortcut can answer it.
    let policy = @moonrpc.Hedging::new(
      attempts=2,
      delay=@moondate.Span::new(seconds=10L),
    )
    let r = chan.unary_hedged(
      "/echo.E/Say",
      b"x",
      hedging=policy,
      timeout_millis=3000,
    )
    assert_eq(r.grpc_status, 0)
    assert_eq(r.messages[0] == b"B:x", true)
    assert_eq(counts, [1, 1])
    chan.close()
    ta.cancel()
    tb.cancel()
  })
}

///|
async test "a pushback to stop sends no further hedge" {
  @async.with_task_group(g => {
    let counts = [0, 0]
    let (ta, tb, p1, p2) = pair(g, counts, pushback=b"-1")
    @async.sleep(300)
    let chan = ManagedChannel::connect([
      ("127.0.0.1", p1),
      ("127.0.0.1", p2),
    ])
    let policy = @moonrpc.Hedging::new(
      attempts=2,
      delay=@moondate.Span::new(seconds=10L),
    )
    let r = chan.unary_hedged(
      "/echo.E/Say",
      b"x",
      hedging=policy,
      timeout_millis=3000,
    )
    assert_eq(r.grpc_status, @moonrpc.Status::code(Unavailable))
    assert_eq(counts, [1, 0])
    chan.close()
    ta.cancel()
    tb.cancel()
  })
}

///|
async test "a throttled channel sends no further hedge" {
  @async.with_task_group(g => {
    let counts = [0, 0]
    let (ta, tb, p1, p2) = pair(g, counts)
    @async.sleep(300)
    let chan = ManagedChannel::connect(
      [("127.0.0.1", p1), ("127.0.0.1", p2)],
      throttling=@moonrpc.Throttling::new(tokens=2, ratio=1.0),
    )
    let policy = @moonrpc.Hedging::new(
      attempts=2,
      delay=@moondate.Span::new(seconds=10L),
    )
    let r = chan.unary_hedged(
      "/echo.E/Say",
      b"x",
      hedging=policy,
      timeout_millis=3000,
    )
    assert_eq(r.grpc_status, @moonrpc.Status::code(Unavailable))
    assert_eq(counts, [1, 0])
    chan.close()
    ta.cancel()
    tb.cancel()
  })
}
