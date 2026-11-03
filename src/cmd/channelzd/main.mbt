// A runnable channelz server: one server node with a listening socket, the seven
// channelz RPCs over it, and server reflection that carries channelz.proto and the
// well-known files it imports.
//
//     channelzd [port]        serve h2c on 127.0.0.1 (default 12000)

///|
fn main {
  let port = match @env.args() {
    [_, p, ..] => @string.parse_int(p[:]) catch { _ => @net.port }
    _ => @net.port
  }
  @async.run_async_main(() => {
    let registry = @moonrpc.Registry::new()
    let server_id = registry.add_server()
    ignore(registry.add_server_socket(server_id, "127.0.0.1:\{port}"))
    let server = @net.GrpcServer::new()
    server.set_stats_handler(registry.server_handler(server_id))
    // A method to call, so the server's call counters move as a client works.
    server.register("/echo.Echo/Say", req => b"echo:" + req)
    let channelz = @moonrpc.ChannelzService::new(registry)
    channelz.install(server)
    let reflection = @moonrpc.ReflectionService::new()
    channelz.add_to_reflection(reflection)
    server.register_reflection(reflection)
    println("channelz serving on 127.0.0.1:\{port}")
    server.serve(host="127.0.0.1", port~)
  })
}
