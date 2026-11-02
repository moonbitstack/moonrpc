// A runnable gRPC server over moonrpc's own stack, declared with `#rpc`
// annotations (`greet.g.mbt` comes from `cmd/rpc`), so a real client checks
// both the transport and what the generator writes: grpcurl lists, describes
// and calls it through Server Reflection, in the clear or over TLS.
//
//     greetd [port]                     serve h2c on 127.0.0.1
//     greetd [port] <cert> <key>        serve over TLS, ALPN h2
//     greetd check [port]               call a running greetd, generated client
//     greetd check [port] <ca>          the same over TLS

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
async fn check(port : Int32, ca : String?) -> Unit {
  let channel = match ca {
    Some(path) =>
      @net.Channel::connect("127.0.0.1", port, tls=read_client_tls(path))
    None => @net.Channel::connect("127.0.0.1", port)
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
  // A certificate and its key, or a CA bundle, follow the port when the run is over TLS.
  let files = if rest.length() > 1 { rest[1:] } else { [] }
  @async.run_async_main(() => {
    if checking {
      let ca = if files.length() > 0 { Some(files[0]) } else { None }
      check(port, ca)
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
