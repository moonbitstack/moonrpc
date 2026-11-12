// Several tasks sharing one `Channel`: the calls of a process that talks to one backend from
// many tasks, which is the ordinary way to use a client.

///|
async test "channel: concurrent calls on one connection each get their own reply" {
  @async.with_task_group(g => {
    let server = GrpcServer::new()
    server.register("/echo.E/Say", req => b"echo:" + req)
    let port_18201 = server.bind(port=0).port()
    let task = g.spawn(() => server.serve())
    @async.sleep(300)
    let chan = Channel::connect("127.0.0.1", port_18201)
    @async.with_task_group(calls => {
      for i in 0..<8 {
        calls.spawn_bg(() => {
          for j in 0..<25 {
            let text = @utf8.encode("\{i}.\{j}")
            let reply = chan.unary("/echo.E/Say", text)
            assert_eq(reply.messages[0], b"echo:" + text)
          }
        })
      }
    })
    chan.close()
    task.cancel()
  })
}

///|
async test "channel: a stream and unary calls run side by side" {
  @async.with_task_group(g => {
    let server = GrpcServer::new()
    server.register("/echo.E/Say", req => b"echo:" + req)
    server.register_server_streaming("/feed.F/Many", (_ctx, req) => {
      [req + b"1", req + b"2", req + b"3"]
    })
    let port_18202 = server.bind(port=0).port()
    let task = g.spawn(() => server.serve())
    @async.sleep(300)
    let chan = Channel::connect("127.0.0.1", port_18202)
    @async.with_task_group(calls => {
      calls.spawn_bg(() => {
        for _ in 0..<20 {
          let reply = chan.server_streaming("/feed.F/Many", b"m")
          assert_eq(reply.messages, [b"m1", b"m2", b"m3"])
        }
      })
      calls.spawn_bg(() => {
        for _ in 0..<20 {
          let got = chan.stream_take("/feed.F/Many", b"t", 2)
          assert_true(got.length() >= 2)
        }
      })
      calls.spawn_bg(() => {
        for _ in 0..<20 {
          let reply = chan.unary("/echo.E/Say", b"u")
          assert_eq(reply.messages[0], b"echo:u")
        }
      })
    })
    chan.close()
    task.cancel()
  })
}

///|
async test "channel: a reader whose deadline passes leaves the socket to the next call" {
  @async.with_task_group(g => {
    let server = @socket.TcpServer::TcpServer(
      @socket.Addr::parse("127.0.0.1:0"),
      reuse_addr=true,
    )
    // Port 0: the system picks one, so two tests never ask for the same number.
    let port_reader = server.addr.port()
    let task = g.spawn(() => {
      server.run_forever((conn, _addr) => {
        let engine = @moonrpc.H2Server::new()
        engine.register("/slow.S/Wait", req => b"ok:" + req)
        drive_slow(conn, engine, 400) catch {
          _ => ()
        }
      })
    })
    @async.sleep(300)
    let chan = Channel::connect("127.0.0.1", port_reader)
    let reading = g.spawn(() => {
      chan.unary("/slow.S/Wait", b"a", timeout_millis=120)
    })
    @async.sleep(20)
    let waiting = chan.unary("/slow.S/Wait", b"b")
    assert_eq(
      reading.wait().grpc_status,
      @moonrpc.Status::code(DeadlineExceeded),
    )
    assert_eq(waiting.grpc_status, 0)
    assert_eq(waiting.messages[0], b"ok:b")
    chan.close()
    task.cancel()
  })
}

///|
async test "channel: a waiting call honours its own deadline" {
  @async.with_task_group(g => {
    let server = @socket.TcpServer::TcpServer(
      @socket.Addr::parse("127.0.0.1:0"),
      reuse_addr=true,
    )
    // Port 0: the system picks one, so two tests never ask for the same number.
    let port_waiting = server.addr.port()
    let task = g.spawn(() => {
      server.run_forever((conn, _addr) => {
        let engine = @moonrpc.H2Server::new()
        engine.register("/slow.S/Wait", req => b"ok:" + req)
        drive_slow(conn, engine, 400) catch {
          _ => ()
        }
      })
    })
    @async.sleep(300)
    let chan = Channel::connect("127.0.0.1", port_waiting)
    let reading = g.spawn(() => chan.unary("/slow.S/Wait", b"a"))
    @async.sleep(20)
    let waiting = chan.unary("/slow.S/Wait", b"b", timeout_millis=120)
    assert_eq(waiting.grpc_status, @moonrpc.Status::code(DeadlineExceeded))
    assert_eq(reading.wait().messages[0], b"ok:a")
    chan.close()
    task.cancel()
  })
}

///|
async test "channel: a lost connection ends every call waiting on it" {
  @async.with_task_group(g => {
    let server = @socket.TcpServer::TcpServer(
      @socket.Addr::parse("127.0.0.1:0"),
      reuse_addr=true,
    )
    // Port 0: the system picks one, so two tests never ask for the same number.
    let port_lost = server.addr.port()
    let task = g.spawn(() => {
      server.run_forever((conn, _addr) => {
        ignore(conn.read_exactly(@http2.preface.length()))
        // Long enough for every call to be waiting when this connection ends.
        @async.sleep(200)
      })
    })
    @async.sleep(300)
    let chan = Channel::connect("127.0.0.1", port_lost)
    let ended = Ref(0)
    let settled = @async.with_timeout_opt(3000, () => {
      @async.with_task_group(calls => {
        for _ in 0..<3 {
          calls.spawn_bg(allow_failure=true, () => {
            defer {
              ended.val += 1
            }
            ignore(chan.unary("/gone.G/Call", b"x"))
          })
        }
      })
    })
    assert_true(settled is Some(_))
    assert_eq(ended.val, 3)
    chan.close()
    task.cancel()
  })
}
