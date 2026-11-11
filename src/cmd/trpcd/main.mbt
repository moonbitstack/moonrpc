// A tRPC service on one socket, and a client that calls it.
//
//     trpcd [port]        serve on 127.0.0.1 (12000)
//     trpcd check [port] [host]  call it with this library
//
// Four methods, one per cardinality: `SayHello` is unary and echoes the caller's `x-test`
// metadata, `Count` streams the numbers up to what it is asked for, `Sum` adds the numbers it
// is sent and answers once, and `Chat` answers each message with its value doubled as it
// arrives. The messages are written by hand rather than generated, because the frame is what
// this command is about: `SayHelloRequest { string name = 1 }`, `SayHelloReply { string
// text = 1; string metadata = 2 }`, `CountRequest { int32 n = 1 }`, `Number { int32 value = 1 }`.

///|
/// The request of `SayHello`: one string field.
fn read_name(body : Bytes) -> String raise @proto.PbError {
  let reader = @proto.PbReader::new(body)
  let mut name = ""
  while !reader.eof() {
    let (field, wire) = reader.read_tag()
    match field {
      1 => name = reader.read_string()
      _ => reader.skip(wire)
    }
  }
  name
}

///|
/// The one number `Count` counts to.
fn read_n(body : Bytes) -> Int32 raise @proto.PbError {
  let reader = @proto.PbReader::new(body)
  let mut n = 0
  while !reader.eof() {
    let (field, wire) = reader.read_tag()
    match field {
      1 => n = reader.read_int32()
      _ => reader.skip(wire)
    }
  }
  n
}

///|
fn greeter() -> @trpc.Server {
  let server = @trpc.Server::new()
  server.register(
    "/trpc.test.Greeter/SayHello",
    @stream.Handler::Unary((ctx, body) => {
      let name = read_name(body) catch { _ => "" }
      let out = @proto.PbWriter::new()
      if name == "" {
        ctx.fail(@wire.Status::code(InvalidArgument), "name is required")
        return out.to_bytes()
      }
      out.string_(1, "Hello, " + name)
      match ctx.metadata_get(b"x-test") {
        Some(value) => out.string_(2, @utf8.decode_lossy(value))
        None => ()
      }
      out.to_bytes()
    }),
  )
  server.register(
    "/trpc.test.Greeter/Count",
    @stream.Handler::ServerStreaming((_ctx, body) => {
      let n = read_n(body) catch { _ => 0 }
      let out : Array[Bytes] = []
      for i = 1; i <= n; i = i + 1 {
        out.push(number(i))
      }
      out
    }),
  )
  server.register(
    "/trpc.test.Greeter/Sum",
    @stream.Handler::ClientStreaming((_ctx, bodies) => {
      let mut total = 0
      for body in bodies {
        total = total + (read_n(body) catch { _ => 0 })
      }
      number(total)
    }),
  )
  server.register(
    "/trpc.test.Greeter/Chat",
    @stream.Handler::Bidi(_ctx => {
      // Answering from `on_message` is what makes this a bidirectional stream rather than a
      // stream of requests answered at the end: the reply goes out while the caller may still
      // be sending.
      on_message: body => [number((read_n(body) catch { _ => 0 }) * 2)],
      on_end: () => [],
    }),
  )
  server
}

///|
/// One `Number{int32 value = 1}`.
fn number(value : Int32) -> Bytes {
  let out = @proto.PbWriter::new()
  out.int32(1, value)
  out.to_bytes()
}

///|
/// The two messages a reply carries, read back.
fn reply_text(body : Bytes) -> (String, String) raise @proto.PbError {
  let reader = @proto.PbReader::new(body)
  let mut text = ""
  let mut metadata = ""
  while !reader.eof() {
    let (field, wire) = reader.read_tag()
    match field {
      1 => text = reader.read_string()
      2 => metadata = reader.read_string()
      _ => reader.skip(wire)
    }
  }
  (text, metadata)
}

///|
async fn check(host : String, port : Int32) -> Unit {
  let channel = @net.TrpcChannel::connect(host, port)
  defer channel.close()
  let client = @trpc.Client::new(channel, caller="trpc.moonrpc.client.service")
  let (text, metadata) = {
    let request = @proto.PbWriter::new()
    request.string_(1, "world")
    let reply = client.unary(
      "/trpc.test.Greeter/SayHello",
      request.to_bytes(),
      metadata=[{ name: b"x-test", value: b"moonrpc", }],
      timeout_millis=5000,
    ) catch {
      e => abort("SayHello failed: \{e}")
    }
    reply_text(reply) catch {
      e => abort("SayHello reply did not decode: \{e}")
    }
  }
  println("SayHello  \{text}  x-test=\{metadata}")
  let numbers = client.stream("/trpc.test.Greeter/Count", [number(3)]) catch {
    e => abort("Count failed: \{e}")
  }
  for reply in numbers {
    println("Count     \{read_n(reply) catch { _ => 0 }}")
  }
  // A client-streaming call: four numbers out, one answer back once the send side closes.
  let sum = client.client_stream("/trpc.test.Greeter/Sum", [
    number(1),
    number(2),
    number(3),
    number(4),
  ]) catch {
    e => abort("Sum failed: \{e}")
  }
  println("Sum       \{read_n(sum) catch { _ => 0 }}")
  // A bidirectional call, one message at a time: the answer to each is read before the next
  // is sent, which a server that waited for the close could not give.
  let exchange = client.open("/trpc.test.Greeter/Chat") catch {
    e => abort("Chat failed to open: \{e}")
  }
  for i = 1; i <= 3; i = i + 1 {
    exchange.send(number(i)) catch {
      e => abort("Chat send failed: \{e}")
    }
    let answer : Result[Bytes?, @wire.StatusError] = Ok(exchange.next()) catch {
      e => Err(e)
    }
    match answer {
      Err(e) => abort("Chat read failed: \{e.to_string()}")
      Ok(Some(reply)) => println("Chat      \{read_n(reply) catch { _ => 0 }}")
      Ok(None) => abort("Chat closed before answering \{i}")
    }
  }
  exchange.close() catch {
    e => abort("Chat close failed: \{e.to_string()}")
  }
  // A refusal has to arrive as one: the server ends the call with INVALID_ARGUMENT, and the
  // deadline the caller asked for has to be what the server sees.
  let refused = try {
    ignore(
      client.unary(
        "/trpc.test.Greeter/SayHello",
        @proto.PbWriter::new().to_bytes(),
      ),
    )
    "ok"
  } catch {
    @wire.StatusError(status, message) => "\{status.code()} \{message}"
  }
  println("refused   \{refused}")
  println("client and server agree")
}

///|
async fn main {
  let args = @env.args()
  let check_mode = args.length() > 1 && args[1] == "check"
  let port_index = if check_mode { 2 } else { 1 }
  let port = if args.length() > port_index {
    @string.parse_int(args[port_index][:]) catch {
      _ => 12000
    }
  } else {
    12000
  }
  if check_mode {
    let host = if args.length() > port_index + 1 {
      args[port_index + 1]
    } else {
      "127.0.0.1"
    }
    check(host, port)
  } else {
    println("trpcd listening on 127.0.0.1:\{port}")
    @net.serve_trpc(port~, greeter())
  }
}
