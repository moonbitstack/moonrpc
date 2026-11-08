// A runnable gRPC server over moonrpc's own stack, declared with `#rpc`
// annotations (`greet.g.mbt` comes from `cmd/rpc`), so a real client checks
// both the transport and what the generator writes: grpcurl lists, describes
// and calls it through Server Reflection, in the clear or over TLS.
//
//     greetd [port]                     serve h2c on 127.0.0.1
//     greetd [port] <cert> <key>        serve over TLS, ALPN h2
//     greetd check [port]               call a running greetd, generated client
//     greetd check [port] <ca>          the same over TLS
//     greetd check [port] gzip          the same with every message compressed

///|
async fn serve(port : Int32, tls : @tls.Server?) -> Unit {
  let server = @net.GrpcServer::new()
  // Replies are compressed for any client that says it accepts gzip — a real grpc-go
  // client does — which is what makes the interop job cover the compressed path too.
  server.set_encoding(@moonrpc.Encoding::Gzip)
  // One interceptor, on every call and every kind: the interop job's traffic — grpcurl
  // included — goes through the chain, so a chain that disturbed the wire would show up
  // there rather than only in the tests.
  server.add_interceptor((info, _ctx, requests, next) => {
    println("call \{info.path} (\{requests.length()} request message(s))")
    next(requests)
  })
  Greeter::{ }.register(server)
  let reflection = @moonrpc.ReflectionService::new()
  reflection.add_file(descriptor())
  server.register_reflection(reflection)
  match tls {
    Some(config) => server.serve(host="127.0.0.1", port~, tls=config)
    None => server.serve(host="127.0.0.1", port~)
  }
}

///|
/// The text of a file the command line named, or a complaint: a certificate the
/// process cannot read is a configuration mistake, not a call to serve without TLS.
async fn text_of(path : String) -> String {
  @fs.read_file(path).text() catch {
    _ => abort("cannot read \{path}")
  }
}

///|
/// A server TLS configuration from a PEM chain and a PEM key.
async fn read_server_tls(cert_path : String, key_path : String) -> @tls.Server {
  @net.server_tls(
    @x509.pems(text_of(cert_path)),
    @x509.PrivateKey::pem(text_of(key_path)),
  ) catch {
    e => abort("bad TLS configuration: \{e}")
  }
}

///|
/// A client TLS configuration trusting the PEM bundle at `ca_path`, offering `h2`.
async fn read_client_tls(ca_path : String) -> @tls.Client {
  @net.client_tls(
    @x509.Roots::pem(text_of(ca_path)) catch {
      e => abort("bad CA bundle: \{e}")
    },
  )
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
async fn check(port : Int32, ca : String?, gzip : Bool) -> Unit {
  // Compression is a property of the channel, not of a call: a caller that asks for gzip
  // compresses every message it sends and advertises that it reads gzip back.
  let channel = match (ca, gzip) {
    (Some(path), true) =>
      @net.Channel::connect(
        "127.0.0.1",
        port,
        tls=read_client_tls(path),
        encoding=@moonrpc.Encoding::Gzip,
      )
    (Some(path), false) =>
      @net.Channel::connect("127.0.0.1", port, tls=read_client_tls(path))
    (None, true) =>
      @net.Channel::connect("127.0.0.1", port, encoding=@moonrpc.Encoding::Gzip)
    (None, false) => @net.Channel::connect("127.0.0.1", port)
  }
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
  // The rich half of the error: a `google.rpc.Status` in `grpc-status-details-bin`, carrying
  // a `google.protobuf.StringValue`. A client that only read `grpc-message` would never know
  // the difference between a server that sends details and one that does not.
  let details = match raw.details() {
    Some(d) => d
    None => abort("the refused call carried no grpc-status-details-bin")
  }
  if details.details.length() != 1 {
    abort("the refused call carried \{details.details.length()} details, not 1")
  }
  let url = match @moonrpc.detail_type_url(details.details[0][:]) {
    Some(text) => text
    None => abort("the detail carried no type url")
  }
  let body = match @moonrpc.detail_body(details.details[0][:]) {
    Some(bytes) => bytes
    None => abort("the detail carried no body")
  }
  same(
    "SayHello detail", url, "type.googleapis.com/google.protobuf.StringValue",
  )
  let reader = @moonrpc.PbReader::new(body)
  ignore(reader.read_tag())
  same("SayHello detail text", reader.read_string(), "name is required")
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
  // Metadata and the deadline are the two things a call carries beside its messages. The
  // server echoes both, so a value that never left, or one the far end dropped, shows up here
  // rather than in a test that only ever sends messages.
  let tagged = client.say_hello(
    request,
    metadata=[
      { name: b"x-test-a", value: b"1", },
      { name: b"x-test-b", value: b"2", },
    ],
    timeout_millis=1500,
  )
  same("SayHello echo", tagged.echo_headers.join(","), "x-test-a=1,x-test-b=2")
  if tagged.deadline_ms <= 0 || tagged.deadline_ms > 1500 {
    abort(
      "the deadline the server saw was \{tagged.deadline_ms}, not 0 < it <= 1500",
    )
  }
  println("deadline \{tagged.deadline_ms}")
  // A message that needs more than one HTTP/2 frame in each direction: the flow-control
  // window has to be credited mid-message, which a small echo never asks for.
  let batch : Batch = { values: Array::makei(40000, i => i), }
  let echoed = client.batch_echo(batch)
  same("BatchEcho size", echoed.values.length().to_string(), "40000")
  if echoed.values[39999] != 39999 {
    abort("BatchEcho did not come back whole")
  }
  println("batch  \{echoed.values.length()} values")
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
  // A certificate and its key, or a CA bundle, follow the port when the run is over TLS; the
  // word `gzip` asks the channel to compress, wherever it sits.
  let given = if rest.length() > 1 { rest[1:] } else { [] }
  let gzip = given.contains("gzip")
  let files = given.filter(f => f != "gzip")
  @async.run_async_main(() => {
    if checking {
      let ca = if files.length() > 0 { Some(files[0]) } else { None }
      check(port, ca, gzip)
    } else {
      let tls = if files.length() > 1 {
        Some(read_server_tls(files[0], files[1]))
      } else {
        None
      }
      serve(port, tls)
    }
  })
}
