// End-to-end load balancing: a `ManagedChannel` dials two real `GrpcServer`s over actual
// sockets and its picker spreads calls across them. Each backend stamps its own identity on
// the reply, so the distribution is observable — this is the native proof that the pure pool
// + picker actually drive real connections, and the mutation-verification target for it.

///|
async test "managed channel: round-robin spreads calls across two live backends" {
  @async.with_task_group(g => {
    let a = GrpcServer::new()
    a.register("/echo.E/Say", req => b"A:" + req)
    let b = GrpcServer::new()
    b.register("/echo.E/Say", req => b"B:" + req)
    let port_18101 = a.bind(port=0).port()
    let ta = g.spawn(() => a.serve())
    let port_18102 = b.bind(port=0).port()
    let tb = g.spawn(() => b.serve())
    @async.sleep(300)
    let chan = ManagedChannel::connect(
      [("127.0.0.1", port_18101), ("127.0.0.1", port_18102)],
      policy=RoundRobin,
    )
    // Both backends dialed and READY, in resolver order.
    assert_eq(chan.ready_addresses(), [
      "127.0.0.1:" + port_18101.to_string(),
      "127.0.0.1:" + port_18102.to_string(),
    ])
    // Four calls alternate A, B, A, B — the picker cycles the ready set.
    let r1 = chan.unary("/echo.E/Say", b"x")
    let r2 = chan.unary("/echo.E/Say", b"x")
    let r3 = chan.unary("/echo.E/Say", b"x")
    let r4 = chan.unary("/echo.E/Say", b"x")
    assert_eq(r1.messages[0] == b"A:x", true)
    assert_eq(r2.messages[0] == b"B:x", true)
    assert_eq(r3.messages[0] == b"A:x", true)
    assert_eq(r4.messages[0] == b"B:x", true)
    chan.close()
    ta.cancel()
    tb.cancel()
  })
}

///|
async test "managed channel: hedging commits on the first OK and cancels the pending attempts" {
  @async.with_task_group(g => {
    let count = [0]
    let backend = GrpcServer::new()
    backend.register("/echo.E/Say", req => {
      count[0] = count[0] + 1
      b"A:" + req
    })
    let port_18107 = backend.bind(port=0).port()
    let tb = g.spawn(() => backend.serve())
    @async.sleep(300)
    let chan = ManagedChannel::connect([("127.0.0.1", port_18107)])
    // Three permitted attempts, but a long hedging delay: the first attempt's OK commits
    // before any hedge is due, so only one request reaches the backend.
    let policy = @moonrpc.Hedging::new(
      attempts=3,
      delay=@moondate.Span::new(millis=1000L),
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
async test "managed channel: pick_first pins every call to the first backend" {
  @async.with_task_group(g => {
    let a = GrpcServer::new()
    a.register("/echo.E/Say", req => b"A:" + req)
    let b = GrpcServer::new()
    b.register("/echo.E/Say", req => b"B:" + req)
    let port_18103 = a.bind(port=0).port()
    let ta = g.spawn(() => a.serve())
    let port_18104 = b.bind(port=0).port()
    let tb = g.spawn(() => b.serve())
    @async.sleep(300)
    // Default policy is PickFirst.
    let chan = ManagedChannel::connect([
      ("127.0.0.1", port_18103),
      ("127.0.0.1", port_18104),
    ])
    let r1 = chan.unary("/echo.E/Say", b"x")
    let r2 = chan.unary("/echo.E/Say", b"x")
    assert_eq(r1.messages[0] == b"A:x", true)
    assert_eq(r2.messages[0] == b"A:x", true)
    chan.close()
    ta.cancel()
    tb.cancel()
  })
}

///|
// A DNS A response resolving example.com -> 127.0.0.1 (0x7f000001), id 0x2a2a.
let mock_localhost_response : Bytes = b"\x2a\x2a\x81\x80\x00\x01\x00\x01\x00\x00\x00\x00\x07example\x03com\x00\x00\x01\x00\x01\xc0\x0c\x00\x01\x00\x01\x00\x00\x01\x2c\x00\x04\x7f\x00\x00\x01"

///|
async test "managed channel: dns_connect resolves a name over UDP then calls the resolved backend" {
  @async.with_task_group(g => {
    let backend = GrpcServer::new()
    backend.register("/echo.E/Say", req => b"A:" + req)
    let port_18106 = backend.bind(port=0).port()
    let tb = g.spawn(() => backend.serve())
    let dns = @socket.UdpServer(@socket.Addr::parse("127.0.0.1:0"))
    let dns_port = dns.addr.port()
    let td = g.spawn(() => {
      let buf = FixedArray::make(512, b'\x00')
      let (_, addr) = dns.recvfrom(buf)
      dns.sendto(mock_localhost_response, addr)
    })
    @async.sleep(300)
    // Resolve example.com -> 127.0.0.1 and dial it at the backend's port.
    let chan = ManagedChannel::dns_connect(
      "127.0.0.1", dns_port, "example.com", port_18106,
    )
    assert_eq(chan.ready_addresses(), ["127.0.0.1:" + port_18106.to_string()])
    let r = chan.unary("/echo.E/Say", b"x")
    assert_eq(r.messages[0] == b"A:x", true)
    chan.close()
    dns.close()
    tb.cancel()
    td.cancel()
  })
}

///|
async test "managed channel: a backend that fails to dial is skipped; calls route to the live one" {
  @async.with_task_group(g => {
    let a = GrpcServer::new()
    a.register("/echo.E/Say", req => b"A:" + req)
    let port_18105 = a.bind(port=0).port()
    let ta = g.spawn(() => a.serve())
    @async.sleep(300)
    // 18999 has nothing listening: its dial fails and its sub-connection never goes READY.
    let chan = ManagedChannel::connect(
      [("127.0.0.1", 18999), ("127.0.0.1", port_18105)],
      policy=RoundRobin,
    )
    // Only the live backend is ready — the dead one is filtered out.
    assert_eq(chan.ready_addresses(), ["127.0.0.1:" + port_18105.to_string()])
    let r1 = chan.unary("/echo.E/Say", b"x")
    let r2 = chan.unary("/echo.E/Say", b"x")
    assert_eq(r1.messages[0] == b"A:x", true)
    assert_eq(r2.messages[0] == b"A:x", true)
    chan.close()
    ta.cancel()
  })
}

///|
async test "managed channel: a backend that dies is left, and a call goes to the next" {
  @async.with_task_group(g => {
    let first = GrpcServer::new()
    first.register("/echo.E/Say", req => b"first:" + req)
    let second = GrpcServer::new()
    second.register("/echo.E/Say", req => b"second:" + req)
    let port_18221 = first.bind(port=0).port()
    let dying = g.spawn(() => first.serve())
    let port_18222 = second.bind(port=0).port()
    let surviving = g.spawn(() => second.serve())
    @async.sleep(300)
    let chan = ManagedChannel::connect([
      ("127.0.0.1", port_18221),
      ("127.0.0.1", port_18222),
    ])
    assert_eq(chan.unary("/echo.E/Say", b"a").messages[0], b"first:a")
    dying.cancel()
    @async.sleep(200)
    let failed = chan.unary("/echo.E/Say", b"b")
    assert_eq(failed.grpc_status, @moonrpc.Status::code(Unavailable))
    assert_eq(chan.unary("/echo.E/Say", b"c").messages[0], b"second:c")
    assert_eq(chan.ready_addresses(), ["127.0.0.1:" + port_18222.to_string()])
    surviving.cancel()
  })
}

///|
async test "managed channel: a retry policy reaches the next backend within one call" {
  @async.with_task_group(g => {
    let first = GrpcServer::new()
    first.register("/echo.E/Say", req => b"first:" + req)
    let second = GrpcServer::new()
    second.register("/echo.E/Say", req => b"second:" + req)
    let port_18223 = first.bind(port=0).port()
    let dying = g.spawn(() => first.serve())
    let port_18224 = second.bind(port=0).port()
    let surviving = g.spawn(() => second.serve())
    @async.sleep(300)
    let chan = ManagedChannel::connect([
      ("127.0.0.1", port_18223),
      ("127.0.0.1", port_18224),
    ])
    assert_eq(chan.unary("/echo.E/Say", b"a").messages[0], b"first:a")
    dying.cancel()
    @async.sleep(200)
    let reply = chan.unary("/echo.E/Say", b"b", retry=quick(3, 1))
    assert_eq(reply.grpc_status, 0)
    assert_eq(reply.messages[0], b"second:b")
    surviving.cancel()
  })
}

///|
async test "managed channel: with every backend gone it dials again" {
  @async.with_task_group(g => {
    let first = GrpcServer::new()
    first.register("/echo.E/Say", req => b"one:" + req)
    let port_18225 = first.bind(port=0).port()
    let gone = g.spawn(() => first.serve())
    @async.sleep(300)
    let chan = ManagedChannel::connect([("127.0.0.1", port_18225)])
    assert_eq(chan.unary("/echo.E/Say", b"a").messages[0], b"one:a")
    gone.cancel()
    @async.sleep(200)
    let down = chan.unary("/echo.E/Say", b"b")
    assert_eq(down.grpc_status, @moonrpc.Status::code(Unavailable))
    let still = chan.unary("/echo.E/Say", b"c")
    assert_eq(still.grpc_status, @moonrpc.Status::code(Unavailable))
    let again = GrpcServer::new()
    again.register("/echo.E/Say", req => b"two:" + req)
    let back = g.spawn(() => again.serve(port=port_18225))
    @async.sleep(300)
    assert_eq(chan.unary("/echo.E/Say", b"d").messages[0], b"two:d")
    back.cancel()
  })
}
