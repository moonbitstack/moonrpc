// The multiplexed channel: concurrent calls sharing one h2c connection through the shared
// read pump. This is the native proof that the demux loop routes each stream's reply to
// the right waiting call.

///|
async test "mux channel: two concurrent unary calls multiplex on one connection" {
  @async.with_task_group(g => {
    let server = GrpcServer::new()
    server.register("/echo.E/Say", req => b"echo:" + req)
    let ts = g.spawn(() => server.serve(port=18108))
    @async.sleep(300)
    let ch = MuxChannel::connect("127.0.0.1", 18108)
    let tp = g.spawn(() => ch.read_pump())
    // Both calls are in flight at once — distinct streams on the same connection.
    let t1 = g.spawn(() => ch.unary("/echo.E/Say", b"one"))
    let t2 = g.spawn(() => ch.unary("/echo.E/Say", b"two"))
    let r1 = t1.wait()
    let r2 = t2.wait()
    assert_eq(r1.grpc_status, 0)
    assert_eq(r2.grpc_status, 0)
    assert_eq(r1.messages[0] == b"echo:one", true)
    assert_eq(r2.messages[0] == b"echo:two", true)
    // Cancelling the server closes the connection, so the pump's blocked read gets EOF
    // and exits on its own (a local close doesn't interrupt a pending native read).
    ts.cancel()
    let _ = tp.wait()
    ch.close()
  })
}

///|
async test "mux channel: keepalive keeps a live connection healthy by pinging" {
  @async.with_task_group(g => {
    let server = GrpcServer::new()
    server.register("/echo.E/Say", req => b"echo:" + req)
    let ts = g.spawn(() => server.serve(port=18110))
    @async.sleep(300)
    let ch = MuxChannel::connect("127.0.0.1", 18110)
    let tp = g.spawn(() => ch.read_pump())
    // Ping after 120 ms idle; a missing ACK within 300 ms would declare the connection dead.
    let tk = g.spawn(() => {
      ch.run_keepalive(keepalive_time=120L, keepalive_timeout=300L)
    })
    // Stay idle across several ping/pong cycles — the live server ACKs every PING.
    @async.sleep(600)
    // Still healthy: a call succeeds because the ACKs kept the connection from timing out.
    // Bounded so that if keepalive wrongly closed the connection, this fails cleanly.
    let r = (
      @async.with_timeout_opt(2000, () => ch.unary("/echo.E/Say", b"x")) :
      @moonrpc.CallReply?)
    match r {
      Some(reply) => {
        assert_eq(reply.grpc_status, 0)
        assert_eq(reply.messages[0] == b"echo:x", true)
      }
      None => fail("keepalive closed a healthy connection")
    }
    tk.cancel()
    ts.cancel()
    let _ = tp.wait()
    ch.close()
  })
}

///|
async test "mux channel: a streaming reply is read message by message via a bidi stream" {
  @async.with_task_group(g => {
    let server = GrpcServer::new()
    server.register_server_streaming("/count.C/Up", (_ctx, req) => {
      [req + b"-1", req + b"-2", req + b"-3"]
    })
    let ts = g.spawn(() => server.serve(port=18111))
    @async.sleep(300)
    let ch = MuxChannel::connect("127.0.0.1", 18111)
    let tp = g.spawn(() => ch.read_pump())
    let stream = ch.open_bidi("/count.C/Up")
    stream.send(b"n")
    stream.close_send()
    // Read replies one at a time until the server ends the stream.
    let got = []
    while stream.recv() is Some(m) {
      got.push(m)
    }
    assert_eq(got.length(), 3)
    assert_eq(got[0] == b"n-1", true)
    assert_eq(got[1] == b"n-2", true)
    assert_eq(got[2] == b"n-3", true)
    ts.cancel()
    let _ = tp.wait()
    ch.close()
  })
}

///|
async test "mux channel: many concurrent calls on one connection each get their own reply" {
  @async.with_task_group(g => {
    let server = GrpcServer::new()
    server.register("/echo.E/Say", req => b"r:" + req)
    let ts = g.spawn(() => server.serve(port=18109))
    @async.sleep(300)
    let ch = MuxChannel::connect("127.0.0.1", 18109)
    let tp = g.spawn(() => ch.read_pump())
    // Five concurrent calls; each reply must match its own request.
    let payloads = [b"a", b"b", b"c", b"d", b"e"]
    let tasks = []
    for p in payloads {
      tasks.push(g.spawn(() => ch.unary("/echo.E/Say", p)))
    }
    for i in 0..<payloads.length() {
      let r = tasks[i].wait()
      assert_eq(r.messages[0] == b"r:" + payloads[i], true)
    }
    // Cancelling the server closes the connection, so the pump's blocked read gets EOF
    // and exits on its own (a local close doesn't interrupt a pending native read).
    ts.cancel()
    let _ = tp.wait()
    ch.close()
  })
}

///|
async test "mux channel: a lost connection wakes a stream and fails a unary call" {
  @async.with_task_group(g => {
    let server = GrpcServer::new()
    server.register("/echo.E/Say", req => b"echo:" + req)
    let ts = g.spawn(() => server.serve(port=18112))
    @async.sleep(300)
    let ch = MuxChannel::connect("127.0.0.1", 18112)
    let tp = g.spawn(() => ch.read_pump())
    let bidi = ch.open_bidi("/echo.E/Nothing")
    let waiting = g.spawn(() => bidi.recv())
    @async.sleep(100)
    ts.cancel()
    let got = (@async.with_timeout_opt(3000, () => waiting.wait()) : Bytes??)
    assert_true(got is Some(None))
    let _ = tp.wait()
    let reply = (
      @async.with_timeout_opt(3000, () => ch.unary("/echo.E/Say", b"x")) catch {
        _ => None
      } : @moonrpc.CallReply?)
    if reply is Some(r) {
      assert_eq(r.grpc_status, 14)
    }
    ch.close()
  })
}

///|
async test "mux channel: close ends the pump while the peer keeps the connection open" {
  @async.with_task_group(g => {
    let server = @socket.TcpServer::TcpServer(
      @socket.Addr::parse("127.0.0.1:18211"),
      reuse_addr=true,
    )
    let holding = g.spawn(() => {
      server.run_forever((conn, _addr) => {
        ignore(conn.read_exactly(@http2.preface.length()))
        @async.sleep(60000)
      })
    })
    @async.sleep(300)
    let ended = @async.with_timeout_opt(3000, () => {
      @async.with_task_group(client => {
        let ch = MuxChannel::connect("127.0.0.1", 18211)
        client.spawn_bg(no_wait=true, () => ch.read_pump())
        @async.sleep(100)
        ch.close()
      })
    })
    assert_true(ended is Some(_))
    holding.cancel()
  })
}
