// The generated code over both protocols: the person's codec, the enum's numbers, and
// the service's dispatch.

///|
test "thrift idl: a person round-trips through the binary protocol" {
  let out : &@thrift.Protocol = @thrift.Binary::new(b"")
  let person : Person = {
    name: "Ada",
    age: Some(37),
    tags: ["math"],
    scores: Map([("math", 10)]),
    portrait: b"\x01\x02",
    mood: Happy,
  }
  person.encode(out)
  out.reset(out.output())
  let back = Person::decode(out)
  assert_eq(back.name, "Ada")
  assert_eq(back.age, Some(37))
  assert_eq(back.tags, ["math"])
  assert_eq(back.scores.get("math"), Some(10))
  assert_eq(back.portrait, b"\x01\x02")
  assert_eq(back.mood.to_i32(), 2)
}

///|
test "thrift idl: a person round-trips through the compact protocol" {
  let out : &@thrift.Protocol = @thrift.Compact::new(b"")
  let person : Person = {
    name: "Grace",
    age: None,
    tags: [],
    scores: Map([]),
    portrait: b"",
    mood: Calm,
  }
  person.encode(out)
  out.reset(out.output())
  let back = Person::decode(out)
  assert_eq(back.name, "Grace")
  assert_eq(back.age, None)
  assert_eq(back.mood.to_i32(), 1)
}

///|
test "thrift idl: an unset optional field is absent, not written empty" {
  let out : &@thrift.Protocol = @thrift.Binary::new(b"")
  Person::default().encode(out)
  let bytes = out.output()
  // struct begin/end write nothing, so the bytes are the fields that were set: the
  // string, the list, the map, the bytes and the mood, then the stop.
  assert_true(bytes.length() > 0)
  out.reset(bytes)
  let back = Person::decode(out)
  assert_eq(back.age, None)
  assert_eq(back.name, "")
}

///|
test "thrift idl: an enum crosses as its number" {
  assert_eq(Happy.to_i32(), 2)
  assert_eq(Mood::from_i32(1).to_i32(), 1)
  let raised = try {
    ignore(Mood::from_i32(9))
    false
  } catch {
    @thrift.BadType(_) => true
    _ => false
  }
  assert_true(raised)
}

///|
test "thrift idl: the generated service answers a call" {
  let processor = @thrift.Processor::new()
  register_greeter(processor, who => "Hello, \{who.name}!", (a, b) => a + b, text => {
    ignore(text)
  })
  let out : &@thrift.Protocol = @thrift.Binary::new(b"")
  out.write_message_begin("add", @thrift.message_call, 3)
  out.write_struct_begin("add_args")
  out.write_field_begin(@thrift.type_i32, 1)
  out.write_i32(20)
  out.write_field_begin(@thrift.type_i32, 2)
  out.write_i32(22)
  out.write_field_stop()
  out.write_struct_end()
  let reply = processor.process(out, out.output())
  out.reset(reply)
  let (_, kind, seqid) = out.read_message_begin()
  assert_eq((kind, seqid), (@thrift.message_reply, 3))
  out.read_struct_begin()
  let (field_type, field_id) = out.read_field_begin()
  assert_eq((field_type, field_id), (@thrift.type_i32, 0))
  assert_eq(out.read_i32(), 42)
}
