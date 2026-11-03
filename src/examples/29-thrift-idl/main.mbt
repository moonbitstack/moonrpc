// The IDL example: a person and a greeter, both generated from `greet.thrift` by
// `cmd/thriftc`. The same service answers the binary and the compact protocol.
//
//     moon run src/examples/29-thrift-idl

///|
fn sample() -> Person {
  {
    name: "Ada",
    age: Some(37),
    tags: ["math", "engine"],
    scores: Map([("math", 10)]),
    portrait: b"\x01\x02",
    mood: Happy,
    stamped: SharedStamp::{ at: 1L, },
  }
}

///|
/// Call `hello` once with a freshly built frame, and print what comes back.
fn probe(proto : &@thrift.Protocol) -> Unit raise {
  proto.write_message_begin("hello", @thrift.message_call, 1)
  proto.write_struct_begin("hello_args")
  proto.write_field_begin(@thrift.type_struct, 1)
  sample().encode(proto)
  proto.write_field_stop()
  proto.write_struct_end()

  let processor = @thrift.Processor::new()
  register_greeter(
    processor,
    who => "Hello, \{who.name}!",
    (a, b) => a + b,
    text => println("  notify: \{text}"),
    () => "pong",
  )
  let reply = processor.process(proto, proto.output())
  // The same protocol reads what it just wrote: `reset` points it at the reply.
  proto.reset(reply)
  let (_, kind, _) = proto.read_message_begin()
  if kind != @thrift.message_reply {
    abort("the call was not answered")
  }
  proto.read_struct_begin()
  let (field_type, field_id) = proto.read_field_begin()
  if field_id != 0 || field_type != @thrift.type_string {
    abort("the reply does not carry a string in field 0")
  }
  println("  hello: \{proto.read_string()}")
}

///|
fn main raise {
  let binary : &@thrift.Protocol = @thrift.Binary::new(b"")
  println("binary")
  probe(binary)
  let compact : &@thrift.Protocol = @thrift.Compact::new(b"")
  println("compact")
  probe(compact)
}
