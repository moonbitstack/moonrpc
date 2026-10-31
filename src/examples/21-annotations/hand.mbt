///|
/// The same messages written without annotations, field by field on a
/// `PbWriter`, and read back by hand.
fn hand_mood(m : Mood) -> Int32 {
  match m {
    Calm => 0
    Glad => 1
    Grumpy => 5
  }
}

///|
fn hand_mood_of(n : Int32) -> Mood {
  match n {
    1 => Glad
    5 => Grumpy
    _ => Calm
  }
}

///|
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
  if hand_mood(m.mood) != 0 {
    w.enum_(6, hand_mood(m.mood))
  }
  for k, v in m.extras {
    let entry = @moonrpc.PbWriter::new()
    entry.string_(1, k)
    entry.int64(2, v)
    w.message_(7, entry.to_bytes())
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
  for b in m.badges {
    let badge = @moonrpc.PbWriter::new()
    if b.label != "" {
      badge.string_(1, b.label)
    }
    w.message_(5, badge.to_bytes())
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
  let mut mood = Calm
  let extras = Map([])
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => name = r.read_string()
      (4, LengthDelim) => tags.push(r.read_string())
      (5, LengthDelim) => nickname = Some(r.read_string())
      (6, Varint) => mood = hand_mood_of(r.read_int32())
      (7, LengthDelim) => {
        let e = @moonrpc.PbReader::new(r.read_len_delim())
        let mut k = ""
        let mut v = 0L
        while !e.eof() {
          match e.read_tag() {
            (1, LengthDelim) => k = e.read_string()
            (2, Varint) => v = e.read_int64()
            (_, wire) => e.skip(wire)
          }
        }
        extras[k] = v
      }
      (_, wire) => r.skip(wire)
    }
  }
  { name, tags, nickname, mood, extras, }
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
      calls: req.extras.get("calls").unwrap_or(9000000000),
      scores: req.tags.map(t => t.length()),
      ratio: 0.5,
      badges: if req.mood is Grumpy {
        [{ label: "grumpy", }]
      } else {
        []
      },
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
  server.register_bidi("/greet.Greeter/Echo", _ctx => {
    let seen = []
    {
      on_message: body => {
        seen.push(hand_read_int(body) catch { _ => 0 })
        []
      },
      on_end: () => seen.rev().map(n => hand_int(1, n)),
    }
  })
}

///|
fn hand_field(
  name : String,
  number : Int32,
  type_ : @moonrpc.FieldType,
  label? : @moonrpc.FieldLabel,
  type_name? : String,
) -> @moonrpc.FieldDescriptor {
  @moonrpc.FieldDescriptor::new(name, number, type_, label?, type_name?)
}

///|
/// The descriptor written by hand, for reflection.
fn hand_descriptor() -> @moonrpc.FileDescriptor {
  let int_message = (name : String, field : String) => {
    @moonrpc.MessageDescriptor::new(name, [hand_field(field, 1, TypeInt32)])
  }
  let rpc = (
    name : String,
    input : String,
    output : String,
    client_streaming : Bool,
    server_streaming : Bool,
  ) => @moonrpc.MethodDescriptor::{
    name,
    input_type: ".greet." + input,
    output_type: ".greet." + output,
    client_streaming,
    server_streaming,
  }
  @moonrpc.FileDescriptor::new(
    "greeter.proto",
    "greet",
    messages=[
      @moonrpc.MessageDescriptor::new(
        "HelloRequest",
        [
          hand_field("name", 1, TypeString),
          hand_field("tags", 4, TypeString, label=LabelRepeated),
          @moonrpc.FieldDescriptor::new(
            "nickname",
            5,
            TypeString,
            oneof_index=0,
            proto3_optional=true,
          ),
          hand_field("mood", 6, TypeEnum, type_name=".greet.Mood"),
          hand_field(
            "extras",
            7,
            TypeMessage,
            label=LabelRepeated,
            type_name=".greet.HelloRequest.ExtrasEntry",
          ),
        ],
        nested=[
          @moonrpc.MessageDescriptor::new(
            "ExtrasEntry",
            [
              hand_field("key", 1, TypeString),
              hand_field("value", 2, TypeInt64),
            ],
            map_entry=true,
          ),
        ],
        oneofs=["_nickname"],
      ),
      @moonrpc.MessageDescriptor::new(
        "HelloReply",
        [
          hand_field("message", 1, TypeString),
          hand_field("calls", 2, TypeInt64),
          hand_field("scores", 3, TypeInt32, label=LabelRepeated),
          hand_field("ratio", 4, TypeDouble),
          hand_field(
            "badges",
            5,
            TypeMessage,
            label=LabelRepeated,
            type_name=".greet.HelloReply.Badge",
          ),
        ],
        nested=[
          @moonrpc.MessageDescriptor::new("Badge", [
            hand_field("label", 1, TypeString),
          ]),
        ],
      ),
      int_message("Upto", "n"),
      int_message("Number", "value"),
    ],
    enums=[
      {
        name: "Mood",
        values: [
          { name: "MOOD_CALM", number: 0, },
          { name: "MOOD_GLAD", number: 1, },
          { name: "MOOD_GRUMPY", number: 5, },
        ],
      },
    ],
    services=[
      {
        name: "Greeter",
        methods: [
          rpc("SayHello", "HelloRequest", "HelloReply", false, false),
          rpc("CountTo", "Upto", "Number", false, true),
          rpc("Sum", "Number", "Number", true, false),
          rpc("Echo", "Number", "Number", true, true),
        ],
      },
    ],
  )
}
