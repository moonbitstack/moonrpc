// The client chain over a real socket: an interceptor written once has to reach the
// server on all four call kinds, through every channel class.

///|
/// An interceptor that stamps every call with a token, whichever kind it is.
fn with_token(token : Bytes) -> @client.Interceptor {
  (invocation, next) => {
    let metadata = invocation.metadata.copy()
    metadata.push({ name: b"x-token", value: token, })
    next({ ..invocation, metadata, })
  }
}

///|
/// What a handler saw of the token, so a test can tell the interceptor arrived.
fn seen_token(ctx : @moonrpc.RpcContext) -> Bytes {
  match ctx.metadata_get(b"x-token") {
    Some(v) => v
    None => b"none"
  }
}

///|
async test "client interceptors: the token reaches all four kinds of call" {
  @async.with_task_group(g => {
    let server = GrpcServer::new()
    server.register_unary("/echo.Echo/Say", (ctx, req) => {
      seen_token(ctx) + b":" + req
    })
    server.register_server_streaming("/count.C/Up", (ctx, req) => {
      [seen_token(ctx) + b":" + req]
    })
    server.register_client_streaming("/sum.S/Add", (ctx, msgs) => {
      let mut all = seen_token(ctx)
      for m in msgs {
        all = all + m
      }
      all
    })
    server.register_bidi("/chat.C/Echo", ctx => @moonrpc.BidiHandler::{
      on_message: m => [seen_token(ctx) + b":" + m],
      on_end: () => [],
    })
    let task = g.spawn(() => server.serve(port=18085))
    @async.sleep(300)
    let chan = Channel::connect("127.0.0.1", 18085, interceptors=[
      with_token(b"T"),
    ])
    assert_eq(chan.unary("/echo.Echo/Say", b"u").messages[0], b"T:u")
    assert_eq(chan.server_streaming("/count.C/Up", b"s").messages[0], b"T:s")
    assert_eq(
      chan.client_streaming("/sum.S/Add", [b"a", b"b"]).messages[0],
      b"Tab",
    )
    assert_eq(chan.bidi("/chat.C/Echo", [b"x"]).messages[0], b"T:x")
    chan.close()
    task.cancel()
  })
}

///|
async test "client interceptors: a reply is changed on the way back" {
  @async.with_task_group(g => {
    let server = GrpcServer::new()
    server.register("/echo.Echo/Say", req => req)
    let task = g.spawn(() => server.serve(port=18086))
    @async.sleep(300)
    let shout : @client.Interceptor = (invocation, next) => {
      let reply = next(invocation)
      { ..reply, messages: reply.messages.map(m => m + b"!"), }
    }
    let chan = Channel::connect("127.0.0.1", 18086, interceptors=[shout])
    assert_eq(chan.unary("/echo.Echo/Say", b"hi").messages[0], b"hi!")
    chan.close()
    task.cancel()
  })
}

///|
async test "client interceptors: a MuxChannel and a ManagedChannel run the chain too" {
  @async.with_task_group(g => {
    let server = GrpcServer::new()
    server.register_unary("/echo.Echo/Say", (ctx, req) => {
      seen_token(ctx) + b":" + req
    })
    let task = g.spawn(() => server.serve(port=18087))
    @async.sleep(300)
    let mux = MuxChannel::connect("127.0.0.1", 18087, interceptors=[
      with_token(b"M"),
    ])
    g.spawn_bg(() => mux.read_pump())
    assert_eq(mux.unary("/echo.Echo/Say", b"q").messages[0], b"M:q")
    mux.close()
    let managed = ManagedChannel::connect([("127.0.0.1", 18087)], interceptors=[
      with_token(b"D"),
    ])
    assert_eq(managed.unary("/echo.Echo/Say", b"w").messages[0], b"D:w")
    managed.close()
    task.cancel()
  })
}
