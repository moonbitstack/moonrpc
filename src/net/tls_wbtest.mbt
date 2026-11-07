// TLS over the gRPC port: the handshake has to settle on ALPN `h2` before either end
// speaks HTTP/2, and both the server and every client class have to be able to do it.

///|
/// A self-signed P-256 certificate for `localhost` and its key — what a test server
/// presents. Made here rather than kept as a fixture so the pair never expires.
fn self_signed_pair() -> (Bytes, @x509.PrivateKey) raise {
  let seed = @moonseed.Replay::new(
    b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f\x20\x21\x22\x23\x24\x25\x26\x27\x28\x29\x2a\x2b\x2c\x2d\x2e\x2f\x30\x31",
  )
  let key = @ecdsa.PrivateKey::generate(seed)
  let pair : @x509.PrivateKey = Ec(key)
  let der = @x509.self_signed(
    key=pair,
    cn="localhost",
    serial=b"\x2a",
    not_before=1767225600L,
    not_after=2082758400L,
  )
  (der, pair)
}

///|
/// A client TLS configuration that accepts what the test server presents. The certificate
/// carries no subjectAltName — `self_signed` writes a minimal profile — and a verifier that
/// never fails is how a caller pins a certificate it already trusts.
fn trusting_tls(protocols~ : Array[String] = [alpn_h2]) -> @tls.Client {
  let roots = @x509.Roots::new() catch {
    _ => abort("an empty root store cannot be malformed")
  }
  @tls.Client::new(roots, alpn=protocols, verify=Custom((_chain, _host) => ()))
}

///|
async test "TLS: a channel negotiates h2 and a unary call crosses the encrypted socket" {
  @async.with_task_group(g => {
    let (cert, key) = self_signed_pair()
    let server = GrpcServer::new()
    server.register("/echo.Echo/Say", req => b"echo:" + req)
    let port_18081 = server.bind(port=0, tls=server_tls([cert], key)).port()
    let task = g.spawn(() => {
      server.serve()
    })
    let chan = Channel::connect("127.0.0.1", port_18081, tls=trusting_tls())
    assert_eq(chan.conn.alpn(), Some(alpn_h2))
    let reply = chan.unary("/echo.Echo/Say", b"tls")
    assert_eq(reply.grpc_status, 0)
    assert_eq(reply.messages[0], b"echo:tls")
    chan.close()
    task.cancel()
  })
}

///|
async test "TLS: a peer that does not offer h2 is not served" {
  @async.with_task_group(g => {
    let (cert, key) = self_signed_pair()
    let server = GrpcServer::new()
    server.register("/echo.Echo/Say", req => req)
    let port_18082 = server.bind(port=0, tls=server_tls([cert], key)).port()
    let task = g.spawn(() => {
      server.serve()
    })
    let refused = try {
      let chan = Channel::connect(
        "127.0.0.1",
        port_18082,
        tls=trusting_tls(protocols=["http/1.1"]),
      )
      chan.close()
      false
    } catch {
      _ => true
    }
    assert_eq(refused, true)
    task.cancel()
  })
}

///|
async test "TLS: a MuxChannel carries concurrent calls over TLS" {
  @async.with_task_group(g => {
    let (cert, key) = self_signed_pair()
    let server = GrpcServer::new()
    server.register("/echo.Echo/Say", req => b"echo:" + req)
    let port_18083 = server.bind(port=0, tls=server_tls([cert], key)).port()
    let task = g.spawn(() => {
      server.serve()
    })
    let chan = MuxChannel::connect("127.0.0.1", port_18083, tls=trusting_tls())
    assert_eq(chan.conn.alpn(), Some(alpn_h2))
    g.spawn_bg(() => chan.read_pump())
    let first = g.spawn(() => chan.unary("/echo.Echo/Say", b"a"))
    let second = g.spawn(() => chan.unary("/echo.Echo/Say", b"b"))
    let both = first.wait()
    let also = second.wait()
    assert_eq(both.messages[0], b"echo:a")
    assert_eq(also.messages[0], b"echo:b")
    chan.close()
    task.cancel()
  })
}

///|
async test "TLS: a ManagedChannel dials a TLS backend" {
  @async.with_task_group(g => {
    let (cert, key) = self_signed_pair()
    let server = GrpcServer::new()
    server.register("/echo.Echo/Say", req => b"echo:" + req)
    let port_18084 = server.bind(port=0, tls=server_tls([cert], key)).port()
    let task = g.spawn(() => {
      server.serve()
    })
    let chan = ManagedChannel::connect(
      [("127.0.0.1", port_18084)],
      tls=trusting_tls(),
    )
    let reply = chan.unary("/echo.Echo/Say", b"managed")
    assert_eq(reply.grpc_status, 0)
    assert_eq(reply.messages[0], b"echo:managed")
    chan.close()
    task.cancel()
  })
}

///|
async test "TLS: a handshake that settles on http/1.1 carries no gRPC call" {
  @async.with_task_group(g => {
    let (cert, key) = self_signed_pair()
    let server = GrpcServer::new()
    server.register("/echo.Echo/Say", req => req)
    let port_18271 = server.bind(port=0, tls=server_tls([cert], key, protocols=["http/1.1"])).port()
    let task = g.spawn(() => {
      server.serve()
    })
    let served = try {
      let chan = Channel::connect(
        "127.0.0.1",
        port_18271,
        tls=trusting_tls(protocols=[alpn_h2, "http/1.1"]),
      )
      let reply = chan.unary("/echo.Echo/Say", b"x")
      chan.close()
      reply.grpc_status == 0
    } catch {
      _ => false
    }
    assert_eq(served, false)
    task.cancel()
  })
}

///|
async test "TLS: a client that names no protocol carries no gRPC call" {
  @async.with_task_group(g => {
    let (cert, key) = self_signed_pair()
    let server = GrpcServer::new()
    server.register("/echo.Echo/Say", req => req)
    let port_18272 = server.bind(port=0, tls=server_tls([cert], key)).port()
    let task = g.spawn(() => {
      server.serve()
    })
    let served = try {
      let chan = Channel::connect(
        "127.0.0.1",
        port_18272,
        tls=trusting_tls(protocols=[]),
      )
      let reply = chan.unary("/echo.Echo/Say", b"x")
      chan.close()
      reply.grpc_status == 0
    } catch {
      _ => false
    }
    assert_eq(served, false)
    task.cancel()
  })
}
