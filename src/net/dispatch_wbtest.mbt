// Concurrent dispatch on one connection: a handler that takes its time must not hold up
// another call on the same socket, a pushed handler must be able to answer over time, and
// a deadline must stop a handler that is still working rather than wait for it.

///|
async test "dispatch: a slow handler does not hold up another call on the same connection" {
  @async.with_task_group(g => {
    let server = GrpcServer::new()
    // Slow: awaits before answering. Registered as a pushed method because that is the
    // shape whose handler may take its time without the engine's thread.
    server.register_handler(
      "/slow.S/Wait",
      Pushed((_ctx, requests, out) => {
        @async.sleep(400)
        (out.send)(requests)
        (out.finish)()
      }),
    )
    server.register("/fast.F/Hit", req => b"fast:" + req)
    let port_18241 = server.bind(port=0).port()
    let task = g.spawn(() => server.serve())
    let chan = MuxChannel::connect("127.0.0.1", port_18241)
    g.spawn_bg(() => chan.read_pump())
    let started = @async.now()
    let slow = g.spawn(() => chan.unary("/slow.S/Wait", b"slow"))
    @async.sleep(50)
    let fast = chan.unary("/fast.F/Hit", b"x")
    let fast_took = @async.now() - started
    assert_eq(fast.grpc_status, 0)
    assert_eq(fast.messages[0], b"fast:x")
    // The fast call went through while the slow one was still asleep: a server that ran
    // the two in turn would have taken the slow one's whole 400 ms first.
    assert_true(fast_took < 300L)
    let slow_reply = slow.wait()
    assert_eq(slow_reply.grpc_status, 0)
    assert_eq(slow_reply.messages[0], b"slow")
    assert_true(@async.now() - started >= 400L)
    chan.close()
    task.cancel()
  })
}

///|
async test "dispatch: a pushed handler answers many times over one call" {
  @async.with_task_group(g => {
    let server = GrpcServer::new()
    server.register_handler(
      "/tick.T/Every",
      Pushed((_ctx, _requests, out) => {
        for i = 1; i <= 3; i = i + 1 {
          (out.send)([b"tick-" + @utf8.encode(i.to_string())])
          @async.sleep(20)
        }
        (out.finish)()
      }),
    )
    let port_18242 = server.bind(port=0).port()
    let task = g.spawn(() => server.serve())
    let chan = Channel::connect("127.0.0.1", port_18242)
    let reply = chan.bidi("/tick.T/Every", [b"go"])
    assert_eq(reply.grpc_status, 0)
    assert_eq(reply.messages, [b"tick-1", b"tick-2", b"tick-3"])
    chan.close()
    task.cancel()
  })
}

///|
async test "dispatch: a deadline ends a handler that is still working" {
  @async.with_task_group(g => {
    let server = GrpcServer::new()
    let mut finished = false
    server.register_handler(
      "/slow.S/Wait",
      Pushed((_ctx, requests, out) => {
        // Half a second of work for a call that has a tenth of a second to live.
        @async.sleep(500)
        (out.send)(requests)
        (out.finish)()
        finished = true
      }),
    )
    let port_18243 = server.bind(port=0).port()
    let task = g.spawn(() => server.serve())
    let chan = Channel::connect("127.0.0.1", port_18243)
    let started = @async.now()
    let reply = chan.bidi("/slow.S/Wait", [b"x"], timeout_millis=120)
    let took = @async.now() - started
    assert_eq(reply.grpc_status, @moonrpc.Status::code(DeadlineExceeded))
    // Answered when the deadline passed, not when the handler finally woke.
    assert_true(took < 400L)
    // The engine ended the call and the driver stopped the task behind it, so the handler
    // never reached its last statement.
    @async.sleep(600)
    assert_eq(finished, false)
    chan.close()
    task.cancel()
  })
}
