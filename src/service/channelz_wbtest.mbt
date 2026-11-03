// The channelz registry fed from stats events.

///|
test "channelz: a channel's stats events become call and message counts" {
  let registry = Registry::new()
  let id = registry.add_channel("127.0.0.1:12000")
  let handler = registry.channel_handler(id)
  (handler.conn)(@wire.ConnStats::ConnBegin)
  (handler.rpc)(@wire.RpcStats::Begin(path="/a.B/C", name="C"))
  (handler.rpc)(@wire.RpcStats::OutPayload(length=3))
  (handler.rpc)(@wire.RpcStats::InPayload(length=4))
  (handler.rpc)(@wire.RpcStats::End(status=@wire.Status::Ok, message=""))
  (handler.rpc)(@wire.RpcStats::Begin(path="/a.B/D", name="D"))
  (handler.rpc)(
    @wire.RpcStats::End(status=@wire.Status::Unavailable, message="down"),
  )
  let node = match registry.channel(id) {
    Some(n) => n
    None => abort("the channel must be registered")
  }
  assert_eq(node.state, "READY")
  assert_eq(node.calls.started, 2L)
  assert_eq(node.calls.succeeded, 1L)
  assert_eq(node.calls.failed, 1L)
  assert_eq(node.messages_sent, 1L)
  assert_eq(node.messages_received, 1L)
  (handler.conn)(@wire.ConnStats::ConnEnd)
  assert_eq(node.state, "SHUTDOWN")
}

///|
test "channelz: a snapshot lists every channel and server in id order" {
  let registry = Registry::new()
  let a = registry.add_channel("a:1")
  let b = registry.add_channel("b:2")
  let s = registry.add_server()
  assert_true(a < b)
  assert_eq(registry.channels().length(), 2)
  assert_eq(registry.servers().length(), 1)
  assert_eq(registry.channels()[0].target, "a:1")
  assert_eq(registry.channels()[1].target, "b:2")
  match registry.server(s) {
    Some(node) => assert_eq(node.calls.started, 0L)
    None => abort("the server must be registered")
  }
}

///|
test "channelz: a server handler counts the calls it is told about" {
  let registry = Registry::new()
  let id = registry.add_server()
  let handler = registry.server_handler(id)
  (handler.rpc)(@wire.RpcStats::Begin(path="/a.B/C", name="C"))
  (handler.rpc)(@wire.RpcStats::End(status=@wire.Status::Ok, message=""))
  let node = match registry.server(id) {
    Some(n) => n
    None => abort("the server must be registered")
  }
  assert_eq(node.calls.started, 1L)
  assert_eq(node.calls.succeeded, 1L)
}
