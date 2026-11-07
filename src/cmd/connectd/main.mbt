// A Connect server, in one file: the messages, the service, and the socket. It is what the
// README's Connect chapter runs, and what a client written against the protocol can be
// pointed at.
//
//     moon run src/cmd/connectd -- 12000
//
// `connect.Echo/Say` echoes the text it is given; `connect.Echo/Count` answers `n` messages;
// `connect.Echo/Fail` answers INVALID_ARGUMENT.

///|
/// `EchoRequest { text = 1 }` and `EchoReply { text = 1 }`, as descriptors: a JSON caller is
/// read through these, and the binary codec does not need them.
fn echo_schema() -> @proto.Schema {
  let request = @proto.MessageDescriptor::new("EchoRequest", [
    @proto.FieldDescriptor::new("text", 1, @proto.FieldType::TypeString),
  ])
  let reply = @proto.MessageDescriptor::new("EchoReply", [
    @proto.FieldDescriptor::new("text", 1, @proto.FieldType::TypeString),
  ])
  @proto.Schema::of([
    @proto.FileDescriptor::new("echo.proto", "connect", messages=[
      request, reply,
    ]),
  ])
}

///|
/// The one string field of a message, or the empty string.
fn read_text(body : Bytes) -> String {
  let reader = @proto.PbReader::new(body)
  let mut text = ""
  while !reader.eof() {
    let outcome : Result[(Int32, @proto.WireType), @proto.PbError] = Ok(
      reader.read_tag(),
    ) catch {
      e => Err(e)
    }
    match outcome {
      Ok((1, @proto.LengthDelim)) =>
        text = reader.read_string() catch { _ => "" }
      Ok((_, wire)) => reader.skip(wire) catch { _ => break }
      Err(_) => break
    }
  }
  text
}

///|
fn write_text(text : String) -> Bytes {
  let writer = @proto.PbWriter::new()
  writer.string_(1, text)
  writer.to_bytes()
}

///|
fn main {
  let args = @env.args()
  let port = if args.length() > 1 {
    let parsed : Result[Int32, Error] = Ok(@string.parse_int(args[1][:])) catch {
      e => Err(e)
    }
    match parsed {
      Ok(n) => n
      Err(_) => 12000
    }
  } else {
    12000
  }
  let server = @net.ConnectServer::new(schema=echo_schema())
  server.add("/connect.Echo/Say", {
    input: ".connect.EchoRequest",
    output: ".connect.EchoReply",
    handler: @stream.Handler::Unary((_ctx, req) => req),
  })
  server.add("/connect.Echo/Count", {
    input: ".connect.EchoRequest",
    output: ".connect.EchoReply",
    handler: @stream.Handler::ServerStreaming((_ctx, req) => {
      let text = read_text(req)
      let out = []
      for i = 0; i < 3; i = i + 1 {
        out.push(write_text(text + "#" + (i + 1).to_string()))
      }
      out
    }),
  })
  server.add("/connect.Echo/Fail", {
    input: ".connect.EchoRequest",
    output: ".connect.EchoReply",
    handler: @stream.Handler::Unary((ctx, _req) => {
      ctx.fail(
        @wire.Status::code(@wire.Status::InvalidArgument),
        "asked to fail",
      )
      b""
    }),
  })
  @async.run_async_main(() => {
    println("connectd listening on " + port.to_string())
    server.serve(port~)
  })
}
