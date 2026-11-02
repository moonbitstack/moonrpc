// The health service on a real server: a check that answers, one that answers NOT_FOUND
// for a service the server does not know, and a watch that keeps reporting.

///|
async test "health: Check answers the status, and NOT_FOUND for an unknown service" {
  @async.with_task_group(g => {
    let health = @moonrpc.HealthService::new()
    health.set_status("greet.Greeter", Serving)
    let server = GrpcServer::new()
    server.register_health(health)
    let task = g.spawn(() => server.serve(port=18251))
    @async.sleep(300)
    let chan = Channel::connect("127.0.0.1", 18251)
    let known = chan.unary(
      @moonrpc.health_check_path,
      @moonrpc.encode_health_request(b"greet.Greeter"),
    )
    assert_eq(known.grpc_status, 0)
    assert_eq(@moonrpc.decode_health_response(known.messages[0]).code(), 1)
    // The overall server is registered too, under the empty name.
    let overall = chan.unary(
      @moonrpc.health_check_path,
      @moonrpc.encode_health_request(b""),
    )
    assert_eq(overall.grpc_status, 0)
    let missing = chan.unary(
      @moonrpc.health_check_path,
      @moonrpc.encode_health_request(b"pkg.Missing"),
    )
    assert_eq(missing.grpc_status, @moonrpc.Status::code(NotFound))
    chan.close()
    task.cancel()
  })
}

///|
async test "health: Watch reports the status now and again when it changes" {
  @async.with_task_group(g => {
    let health = @moonrpc.HealthService::new()
    health.set_status("greet.Greeter", Serving)
    let server = GrpcServer::new()
    server.register_health(health)
    let task = g.spawn(() => server.serve(port=18252))
    @async.sleep(300)
    let chan = Channel::connect("127.0.0.1", 18252)
    let watch = g.spawn(() => {
      chan.stream_take(
        @moonrpc.health_watch_path,
        @moonrpc.encode_health_request(b"greet.Greeter"),
        2,
        timeout_millis=4000,
      )
    })
    // The first message is where things stand; the second is the change made after the
    // watch was already open, which is what an eager one-shot watch can never send.
    @async.sleep(150)
    health.set_status("greet.Greeter", NotServing)
    let messages = watch.wait()
    assert_eq(messages.length(), 2)
    assert_eq(@moonrpc.decode_health_response(messages[0]).code(), 1)
    assert_eq(@moonrpc.decode_health_response(messages[1]).code(), 2)
    chan.close()
    task.cancel()
  })
}
