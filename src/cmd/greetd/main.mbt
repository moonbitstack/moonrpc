// A runnable gRPC server over moonrpc's own h2c stack, declared with `#rpc`
// annotations (`greet.g.mbt` comes from `cmd/rpc`), so a real client checks
// both the transport and what the generator writes: grpcurl lists, describes
// and calls it through Server Reflection.
//
//     greetd [port]          serve on 127.0.0.1
//     greetd check [port]    call a running greetd through the generated client

///|
async fn serve(port : Int32) -> Unit {
  let server = @net.GrpcServer::new()
  Greeter::{ }.register(server)
  let reflection = @moonrpc.ReflectionService::new()
  reflection.add_file(descriptor())
  server.register_reflection(reflection)
  server.serve(host="127.0.0.1", port~)
}

///|
fn hex(b : Bytes) -> String {
  let out = StringBuilder()
  for x in b {
    out.write_string(x.to_int().to_string(radix=16).pad_start(2, '0'))
  }
  out.to_string()
}

///|
fn same(what : String, client : String, channel : String) -> Unit {
  if client != channel {
    abort("\{what} differs:\n  client:  \{client}\n  channel: \{channel}")
  }
  println("\{what}  \{client}")
}

///|
fn[T : @moonrpc.Message] bytes_of(messages : Array[T]) -> String {
  messages.map(m => hex(@moonrpc.Message::encode(m))).join(" ")
}

///|
/// Every method once through `GreeterClient` and once as raw bytes on the
/// same `Channel`: the replies and statuses must agree.
async fn check(port : Int32) -> Unit {
  let channel = @net.Channel::connect("127.0.0.1", port)
  defer channel.close()
  let client = GreeterClient::new(channel)
  let request : HelloRequest = {
    name: "world",
    mood: Glad,
    extras: { "a": 2, "b": 40 },
  }
  let reply = client.say_hello(request)
  let raw = channel.unary(
    "/greet.Greeter/SayHello",
    @moonrpc.Message::encode(request),
  )
  same("SayHello", bytes_of([reply]), raw.messages.map(hex).join(" "))
  let refused = try {
    ignore(client.say_hello({ ..request, name: "", }))
    "OK"
  } catch {
    @wire.StatusError(status, message) => "\{status.code()} \{message}"
    e => "\{e}"
  }
  let raw = channel.unary(
    "/greet.Greeter/SayHello",
    @moonrpc.Message::encode({ ..request, name: "", }),
  )
  same("SayHello refused", refused, "\{raw.grpc_status} \{raw.grpc_message}")
  let numbers = client.count_to({ n: 3, })
  let raw = channel.server_streaming(
    "/greet.Greeter/CountTo",
    @moonrpc.Message::encode(Upto::{ n: 3, }),
  )
  same("CountTo", bytes_of(numbers), raw.messages.map(hex).join(" "))
  let ins : Array[Number] = [{ value: 1, }, { value: 2, }, { value: 39, }]
  let total = client.sum(ins)
  let raw = channel.client_streaming(
    "/greet.Greeter/Sum",
    ins.map(m => @moonrpc.Message::encode(m)),
  )
  same("Sum", bytes_of([total]), raw.messages.map(hex).join(" "))
  let back = client.echo(ins)
  let raw = channel.bidi(
    "/greet.Greeter/Echo",
    ins.map(m => @moonrpc.Message::encode(m)),
  )
  same("Echo", bytes_of(back), raw.messages.map(hex).join(" "))
  println("client and channel agree")
}

///|
fn main {
  let (checking, rest) = match @env.args() {
    [_, "check", .. rest] => (true, rest)
    [_, .. rest] => (false, rest)
    [] => (false, [])
  }
  let port = match rest {
    [p, ..] => @string.parse_int(p[:]) catch { _ => @net.port }
    [] => @net.port
  }
  @async.run_async_main(() => if checking { check(port) } else { serve(port) })
}
