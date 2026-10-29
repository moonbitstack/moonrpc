///|
/// The same messages written without annotations, field by field on a
/// `PbWriter`, and read back by hand.
fn hand_request(m : HelloRequest) -> Bytes {
  let w = @moonrpc.PbWriter::new()
  if m.name != "" {
    w.string_(1, m.name)
  }
  for t in m.tags {
    w.string_(4, t)
  }
  if m.nickname is Some(n) {
    w.string_(5, n)
  }
  w.to_bytes()
}

///|
fn hand_reply(m : HelloReply) -> Bytes {
  let w = @moonrpc.PbWriter::new()
  if m.message != "" {
    w.string_(1, m.message)
  }
  if m.calls != 0L {
    w.int64(2, m.calls)
  }
  if !m.scores.is_empty() {
    w.packed_int32(3, m.scores)
  }
  if m.ratio != 0.0 {
    w.double_(4, m.ratio)
  }
  w.to_bytes()
}

///|
fn hand_int(field : Int32, v : Int32) -> Bytes {
  let w = @moonrpc.PbWriter::new()
  if v != 0 {
    w.int32(field, v)
  }
  w.to_bytes()
}

///|
/// Field 1 of a message holding one `int32`.
fn hand_read_int(body : Bytes) -> Int32 raise {
  let r = @moonrpc.PbReader::new(body)
  let mut v = 0
  while !r.eof() {
    match r.read_tag() {
      (1, Varint) => v = r.read_int32()
      (_, wire) => r.skip(wire)
    }
  }
  v
}

///|
fn hand_read_request(body : Bytes) -> HelloRequest raise {
  let r = @moonrpc.PbReader::new(body)
  let mut name = ""
  let tags = []
  let mut nickname = None
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => name = r.read_string()
      (4, LengthDelim) => tags.push(r.read_string())
      (5, LengthDelim) => nickname = Some(r.read_string())
      (_, wire) => r.skip(wire)
    }
  }
  { name, tags, nickname, }
}

///|
/// The service registered by hand on raw bytes.
fn hand_register(server : @moonrpc.H2Server, g : Greeter) -> Unit {
  server.register_unary("/greet.Greeter/SayHello", (ctx, body) => {
    let req = hand_read_request(body) catch {
      e => {
        ctx.fail(13, "grpc: error unmarshalling request: \{e}")
        return b""
      }
    }
    if req.name == "" {
      ctx.fail(3, "a name, please")
      return b""
    }
    ctx.add_header(b"x-greeter", b"annotated")
    let who = req.nickname.unwrap_or(req.name)
    hand_reply({
      message: "\{g.greeting}, \{who}",
      calls: 9000000000,
      scores: req.tags.map(t => t.length()),
      ratio: 0.5,
      cached: false,
    })
  })
  server.register_server_streaming("/greet.Greeter/CountTo", (_ctx, body) => {
    let n = hand_read_int(body) catch { _ => 0 }
    Array::makei(n, i => hand_int(1, i + 1))
  })
  server.register_client_streaming("/greet.Greeter/Sum", (_ctx, bodies) => {
    let mut total = 0
    for b in bodies {
      total += hand_read_int(b) catch { _ => 0 }
    }
    hand_int(1, total)
  })
}

///|
fn hand_field(
  name : String,
  number : Int32,
  type_ : @moonrpc.FieldType,
  label? : @moonrpc.FieldLabel,
) -> @moonrpc.FieldDescriptor {
  @moonrpc.FieldDescriptor::scalar(name, number, type_, label?)
}

///|
/// The descriptor written by hand, for reflection.
fn hand_descriptor() -> @moonrpc.FileDescriptor {
  let int_message = (name : String, field : String) => @moonrpc.MessageDescriptor::{
    name,
    fields: [hand_field(field, 1, TypeInt32)],
  }
  @moonrpc.FileDescriptor::new(
    "greeter.proto",
    "greet",
    messages=[
      {
        name: "HelloRequest",
        fields: [
          hand_field("name", 1, TypeString),
          hand_field("tags", 4, TypeString, label=LabelRepeated),
          hand_field("nickname", 5, TypeString),
        ],
      },
      {
        name: "HelloReply",
        fields: [
          hand_field("message", 1, TypeString),
          hand_field("calls", 2, TypeInt64),
          hand_field("scores", 3, TypeInt32, label=LabelRepeated),
          hand_field("ratio", 4, TypeDouble),
        ],
      },
      int_message("Upto", "n"),
      int_message("Number", "value"),
    ],
    services=[
      {
        name: "Greeter",
        methods: [
          {
            name: "SayHello",
            input_type: ".greet.HelloRequest",
            output_type: ".greet.HelloReply",
            client_streaming: false,
            server_streaming: false,
          },
          {
            name: "CountTo",
            input_type: ".greet.Upto",
            output_type: ".greet.Number",
            client_streaming: false,
            server_streaming: true,
          },
          {
            name: "Sum",
            input_type: ".greet.Number",
            output_type: ".greet.Number",
            client_streaming: true,
            server_streaming: false,
          },
        ],
      },
    ],
  )
}
