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
    stamped: SharedStamp::{ at: 9L, },
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
  assert_eq(back.stamped.at, 9L)
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
    stamped: SharedStamp::default(),
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
  register_greeter(
    processor,
    who => "Hello, \{who.name}!",
    (a, b) => a + b,
    text => ignore(text),
    key => Ok("found " + key),
    _ => Ok(()),
    () => "pong",
  )
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

///|
/// A transport that hands the frame to a processor in the same process, so the generated
/// client and the generated service meet without a socket.
struct Loop {
  processor : @thrift.Processor
}

///|
impl @thrift.Transport for Loop with fn round_trip(self, body) {
  let proto : &@thrift.Protocol = @thrift.Binary::new(b"")
  self.processor.process(proto, body)
}

///|
fn failing_greeter() -> @thrift.Processor {
  let processor = @thrift.Processor::new()
  register_greeter(
    processor,
    who => "Hello, \{who.name}!",
    (a, b) => a + b,
    text => ignore(text),
    key => {
      if key == "ada" {
        Ok("found ada")
      } else {
        Err(SharedMissing({ message: "no \{key}", code: -1, }))
      }
    },
    text => {
      if text == "" {
        Err(SharedMissing({ message: "empty", code: 2, }))
      } else {
        Ok(())
      }
    },
    () => "pong",
  )
  processor
}

///|
test "thrift idl: a thrown exception is field 1 of the result, not the value" {
  let out : &@thrift.Protocol = @thrift.Binary::new(b"")
  out.write_message_begin("find", @thrift.message_call, 7)
  out.write_struct_begin("find_args")
  out.write_field_begin(@thrift.type_string, 1)
  out.write_string("nobody")
  out.write_field_stop()
  out.write_struct_end()
  let reply = failing_greeter().process(out, out.output())
  out.reset(reply)
  let (_, kind, seqid) = out.read_message_begin()
  assert_eq((kind, seqid), (@thrift.message_reply, 7))
  out.read_struct_begin()
  let (field_type, field_id) = out.read_field_begin()
  assert_eq((field_type, field_id), (@thrift.type_struct, 1))
  let missing = SharedMissing::decode(out)
  assert_eq(missing.message, "no nobody")
  assert_eq(missing.code, -1)
}

///|
async test "thrift idl: the generated client turns a thrown exception into Err" {
  let transport : Loop = { processor: failing_greeter(), }
  let proto : &@thrift.Protocol = @thrift.Binary::new(b"")
  let answered = greeter_find(transport, proto, "nobody")
  match answered {
    Ok(value) => fail("expected a failure, got \{value}")
    Err(SharedMissing(missing)) => {
      assert_eq(missing.message, "no nobody")
      assert_eq(missing.code, -1)
    }
  }
}

///|
async test "thrift idl: the same client reads a value from field 0" {
  let transport : Loop = { processor: failing_greeter(), }
  let proto : &@thrift.Protocol = @thrift.Binary::new(b"")
  match greeter_find(transport, proto, "ada") {
    Ok(value) => assert_eq(value, "found ada")
    Err(SharedMissing(_)) => fail("expected a value")
  }
}

///|
async test "thrift idl: an undeclared exception field is still raised" {
  let processor = @thrift.Processor::new()
  // A processor that answers the way a peer would when it throws something the IDL does
  // not declare: a string message in a field the client has no variant for.
  processor.add("find", proto => {
    for ;; {
      let (field_type, _) = proto.read_field_begin()
      if field_type == @thrift.type_stop {
        break
      }
      @thrift.skip(proto, field_type)
    }
    proto.write_field_begin(@thrift.type_string, 9)
    proto.write_string("something else broke")
  })
  let transport : Loop = { processor, }
  let proto : &@thrift.Protocol = @thrift.Binary::new(b"")
  let raised = try {
    ignore(greeter_find(transport, proto, "ada"))
    false
  } catch {
    @thrift.Application(message) => message == "something else broke"
    _ => false
  }
  assert_true(raised)
}

///|
async test "thrift idl: a void method that throws answers an empty result or a failure" {
  let transport : Loop = { processor: failing_greeter(), }
  let proto : &@thrift.Protocol = @thrift.Binary::new(b"")
  match greeter_shout(transport, proto, "hi") {
    Ok(_) => ()
    Err(SharedMissing(_)) => fail("expected a success")
  }
  match greeter_shout(transport, proto, "") {
    Ok(_) => fail("expected a failure")
    Err(SharedMissing(missing)) => {
      assert_eq(missing.message, "empty")
      assert_eq(missing.code, 2)
    }
  }
}

///|
test "thrift idl: a constant written in the IDL is a value of its type" {
  assert_eq(maxAge, 130)
  assert_eq(tags, ["math", "music"])
  assert_eq(scores.get("art"), Some(7))
  assert_eq(defaultMood.to_i32(), 1)
  // A struct constant fills the fields it names and leaves the rest at their defaults.
  assert_eq(ada.name, "Ada")
  assert_eq(ada.age, Some(37))
  assert_eq(ada.portrait, b"ab")
  assert_eq(ada.stamped.at, 9L)
  assert_eq(ada.mood.to_i32(), 2)
}
