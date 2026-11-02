// Compression over a real socket, both directions at once: a client that compresses its
// requests talking to a server that compresses its replies, in each encoding, and a plain
// client talking to the same compressed server.

///|
async test "compression: gzip in both directions completes every call kind" {
  @async.with_task_group(g => {
    let server = GrpcServer::new()
    server.set_encoding(@moonrpc.Encoding::Gzip)
    let bulky = b"z".repeat(4096)
    server.register_unary("/echo.Echo/Say", (_ctx, req) => req + bulky)
    server.register_server_streaming("/count.C/Up", (_ctx, req) => {
      [req, req + b"-2"]
    })
    server.register_client_streaming("/sum.S/Add", (_ctx, msgs) => {
      let mut all = b""
      for m in msgs {
        all = all + m
      }
      all
    })
    server.register_bidi("/chat.C/Echo", _ctx => @moonrpc.BidiHandler::{
      on_message: m => [m],
      on_end: () => [b"bye"],
    })
    let task = g.spawn(() => server.serve(port=18231))
    @async.sleep(300)
    let chan = Channel::connect(
      "127.0.0.1",
      18231,
      encoding=@moonrpc.Encoding::Gzip,
    )
    let first = chan.unary("/echo.Echo/Say", bulky)
    assert_eq(first.grpc_status, 0)
    assert_eq(first.messages[0], bulky + bulky)
    let up = chan.server_streaming("/count.C/Up", b"n")
    assert_eq(up.messages, [b"n", b"n-2"])
    assert_eq(
      chan.client_streaming("/sum.S/Add", [bulky, bulky]).messages[0],
      bulky + bulky,
    )
    assert_eq(chan.bidi("/chat.C/Echo", [b"x"]).messages, [b"x", b"bye"])
    chan.close()
    task.cancel()
  })
}

///|
async test "compression: deflate in both directions" {
  @async.with_task_group(g => {
    let server = GrpcServer::new()
    server.set_encoding(@moonrpc.Encoding::Deflate)
    let bulky = b"q".repeat(4096)
    server.register("/echo.Echo/Say", req => req)
    let task = g.spawn(() => server.serve(port=18232))
    @async.sleep(300)
    let chan = Channel::connect(
      "127.0.0.1",
      18232,
      encoding=@moonrpc.Encoding::Deflate,
    )
    assert_eq(chan.unary("/echo.Echo/Say", bulky).messages[0], bulky)
    chan.close()
    task.cancel()
  })
}

///|
async test "compression: a plain client still reads a compressed server" {
  @async.with_task_group(g => {
    let server = GrpcServer::new()
    server.set_encoding(@moonrpc.Encoding::Gzip)
    let bulky = b"w".repeat(4096)
    server.register("/echo.Echo/Say", req => req + bulky)
    let task = g.spawn(() => server.serve(port=18233))
    @async.sleep(300)
    // No encoding asked for: the server must fall back to identity rather than send a
    // gzip body at a caller that never said it could read one.
    let chan = Channel::connect("127.0.0.1", 18233)
    assert_eq(chan.unary("/echo.Echo/Say", b"p").messages[0], b"p" + bulky)
    chan.close()
    task.cancel()
  })
}
