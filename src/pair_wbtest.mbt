// Both pure engines driven against each other in memory: request frames out of
// `H2Client`, through the real frame and HPACK codecs, into `H2Server`, and the
// response frames back. No sockets, so every backend runs these. Break request
// framing, reply reassembly, flow control, an interceptor chain or the health
// service and these fail.

///|
/// Shuttle frames between a client and server engine until the call `id` completes:
/// deliver the client's queued frames to the server, its replies back to the
/// client, and repeat. The @http2.preface handshake is seeded first.
fn drive_pair(
  server : @server.H2Server,
  client : @client.H2Client,
  id : Int32,
  initial : Array[@http2.Frame],
) -> Unit raise {
  let to_server : Array[@http2.Frame] = []
  let to_client : Array[@http2.Frame] = []
  for f in client.preface() {
    to_server.push(f)
  }
  for f in server.preface() {
    to_client.push(f)
  }
  for f in initial {
    to_server.push(f)
  }
  let mut si = 0
  let mut ci = 0
  let mut steps = 0
  while !client.is_done(id) && steps < 100000 {
    steps = steps + 1
    if si < to_server.length() {
      let f = to_server[si]
      si = si + 1
      for r in server.feed(f) {
        to_client.push(r)
      }
    } else if ci < to_client.length() {
      let f = to_client[ci]
      ci = ci + 1
      for r in client.feed(f) {
        to_server.push(r)
      }
    } else {
      break
    }
  }
}

///|
test "client+server: a unary call round-trips over the two pure engines" {
  let server = @server.H2Server::new()
  server.register("/echo.Echo/Say", req => b"echo:" + req)
  let client = @client.H2Client::new()
  let (id, frames) = client.unary("/echo.Echo/Say", b"world")
  drive_pair(server, client, id, frames)
  let reply = client.reply(id)
  assert_eq(reply.status == b"200", true)
  assert_eq(reply.grpc_status, 0)
  assert_eq(reply.messages.length(), 1)
  assert_eq(reply.messages[0] == b"echo:world", true)
}

///|
test "client+server: a server-streaming call reassembles every framed reply in order" {
  let server = @server.H2Server::new()
  server.register_server_streaming("/count.C/Up", (_ctx, req) => {
    [req + b"-1", req + b"-2", req + b"-3"]
  })
  let client = @client.H2Client::new()
  let id = client.open("/count.C/Up")
  let frames = client.send(id, b"n", end=true)
  drive_pair(server, client, id, frames)
  let reply = client.reply(id)
  assert_eq(reply.grpc_status, 0)
  assert_eq(reply.messages.length(), 3)
  assert_eq(reply.messages[0] == b"n-1", true)
  assert_eq(reply.messages[1] == b"n-2", true)
  assert_eq(reply.messages[2] == b"n-3", true)
}

///|
test "client+server: a client-streaming call sends many messages for one reply" {
  let server = @server.H2Server::new()
  server.register_client_streaming("/sum.S/Add", (_ctx, msgs) => {
    let buf = Buffer()
    buf.write_bytes(b"got")
    for m in msgs {
      buf.write_byte(b'/')
      buf.write_bytes(m)
    }
    buf.to_bytes()
  })
  let client = @client.H2Client::new()
  let id = client.open("/sum.S/Add")
  let all : Array[@http2.Frame] = []
  for f in client.send(id, b"a") {
    all.push(f)
  }
  for f in client.send(id, b"b") {
    all.push(f)
  }
  for f in client.send(id, b"c") {
    all.push(f)
  }
  for f in client.close_send(id) {
    all.push(f)
  }
  drive_pair(server, client, id, all)
  let reply = client.reply(id)
  assert_eq(reply.grpc_status, 0)
  assert_eq(reply.messages.length(), 1)
  assert_eq(reply.messages[0] == b"got/a/b/c", true)
}

///|
test "client+server: request metadata reaches the handler; response metadata reaches the client" {
  let server = @server.H2Server::new()
  server.register_unary("/meta.M/Do", (ctx, _req) => {
    let token = match ctx.metadata_get(b"x-token") {
      Some(v) => v
      None => b"none"
    }
    ctx.add_header(b"x-server", b"on")
    ctx.add_trailer(b"x-count", b"1")
    b"token:" + token
  })
  let client = @client.H2Client::new()
  let id = client.open("/meta.M/Do", metadata=[
    { name: b"x-token", value: b"abc", },
  ])
  let frames = client.send(id, b"", end=true)
  drive_pair(server, client, id, frames)
  let reply = client.reply(id)
  assert_eq(reply.messages[0] == b"token:abc", true)
  assert_true(reply.headers.contains({ name: b"x-server", value: b"on", }))
  assert_true(reply.trailers.contains({ name: b"x-count", value: b"1", }))
}

///|
test "interceptor: a unary chain runs outermost-first and can rewrite request and reply" {
  let server = @server.H2Server::new()
  server.register("/svc.S/M", req => b"handler(" + req + b")")
  // outer prepends a tag to the reply; inner prepends to the request.
  server.add_unary_interceptor((ctx, req, next) => {
    b"outer[" + next(ctx, req) + b"]"
  })
  server.add_unary_interceptor((ctx, req, next) => next(ctx, b"inner+" + req))
  let client = @client.H2Client::new()
  let (id, frames) = client.unary("/svc.S/M", b"x")
  drive_pair(server, client, id, frames)
  // outer wraps the whole thing; inner mutated the request the handler saw.
  assert_eq(client.reply(id).messages[0] == b"outer[handler(inner+x)]", true)
}

///|
test "interceptor: a unary interceptor can short-circuit without calling the handler" {
  let server = @server.H2Server::new()
  let reached = Ref(false)
  server.register("/svc.S/Guard", _req => {
    reached.val = true
    b"handler-ran"
  })
  server.add_unary_interceptor((_ctx, _req, _next) => b"denied")
  let client = @client.H2Client::new()
  let (id, frames) = client.unary("/svc.S/Guard", b"x")
  drive_pair(server, client, id, frames)
  assert_eq(client.reply(id).messages[0] == b"denied", true)
  // the handler never ran.
  assert_eq(reached.val, false)
}

///|
test "interceptor: a server-streaming chain can post-process the reply sequence" {
  let server = @server.H2Server::new()
  server.register_server_streaming("/svc.S/Str", (_ctx, req) => {
    [req + b"-1", req + b"-2"]
  })
  // append an extra trailing message produced by the interceptor.
  server.add_stream_interceptor((ctx, req, next) => {
    let out = next(ctx, req)
    out.push(b"intercepted")
    out
  })
  let client = @client.H2Client::new()
  let id = client.open("/svc.S/Str")
  let frames = client.send(id, b"n", end=true)
  drive_pair(server, client, id, frames)
  let reply = client.reply(id)
  assert_eq(reply.messages.length(), 3)
  assert_eq(reply.messages[0] == b"n-1", true)
  assert_eq(reply.messages[1] == b"n-2", true)
  assert_eq(reply.messages[2] == b"intercepted", true)
}

///|
test "health: a Check call round-trips over the two engines and reports NOT_SERVING" {
  let server = @server.H2Server::new()
  let health = @service.HealthService::new()
  health.set_status("pkg.Down", NotServing)
  health.install(server)
  let client = @client.H2Client::new()
  let (id, frames) = client.unary(
    @service.health_check_path,
    @service.encode_health_request(b"pkg.Down"),
  )
  drive_pair(server, client, id, frames)
  let reply = client.reply(id)
  assert_eq(reply.grpc_status, 0)
  assert_eq(reply.messages.length(), 1)
  assert_eq(
    @service.decode_health_response(reply.messages[0]) == NotServing,
    true,
  )
}

///|
test "health: a Watch call emits the current status as its first streamed message" {
  let server = @server.H2Server::new()
  let health = @service.HealthService::new()
  health.set_status("pkg.Up", Serving)
  health.install(server)
  let client = @client.H2Client::new()
  let id = client.open(@service.health_watch_path)
  let frames = client.send(
    id,
    @service.encode_health_request(b"pkg.Up"),
    end=true,
  )
  drive_pair(server, client, id, frames)
  let reply = client.reply(id)
  assert_eq(reply.grpc_status, 0)
  assert_eq(reply.messages.length(), 1)
  assert_eq(@service.decode_health_response(reply.messages[0]) == Serving, true)
}
