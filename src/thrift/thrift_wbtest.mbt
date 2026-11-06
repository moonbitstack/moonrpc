// The two protocols over the same messages, the processor's dispatch, and the shared
// `skip`.

///|
test "thrift: the binary protocol round-trips every primitive" {
  let writer = Binary::new(b"")
  writer.write_message_begin("ping", message_call, 7)
  writer.write_field_begin(type_string, 1)
  writer.write_string("hello")
  writer.write_field_begin(type_i32, 2)
  writer.write_i32(-7)
  writer.write_field_begin(type_i64, 3)
  writer.write_i64(-9_000_000_000L)
  writer.write_field_begin(type_bool, 4)
  writer.write_bool(true)
  writer.write_field_begin(type_double, 5)
  writer.write_double(-1.5)
  writer.write_field_begin(type_list, 6)
  writer.write_list_begin(type_i32, 2)
  writer.write_i32(10)
  writer.write_i32(20)
  writer.write_field_begin(type_map, 7)
  writer.write_map_begin(type_string, type_i32, 1)
  writer.write_string("k")
  writer.write_i32(42)
  writer.write_field_stop()

  let reader : &Protocol = Binary::new(writer.output())
  let (name, kind, seqid) = reader.read_message_begin()
  assert_eq(name, "ping")
  assert_eq(kind, message_call)
  assert_eq(seqid, 7)
  reader.read_struct_begin()
  let (ft1, id1) = reader.read_field_begin()
  assert_eq((ft1, id1), (type_string, 1))
  assert_eq(reader.read_string(), "hello")
  let (ft2, id2) = reader.read_field_begin()
  assert_eq((ft2, id2), (type_i32, 2))
  assert_eq(reader.read_i32(), -7)
  let (ft3, id3) = reader.read_field_begin()
  assert_eq((ft3, id3), (type_i64, 3))
  assert_eq(reader.read_i64(), -9_000_000_000L)
  let (ft4, id4) = reader.read_field_begin()
  assert_eq((ft4, id4), (type_bool, 4))
  assert_true(reader.read_bool())
  let (ft5, id5) = reader.read_field_begin()
  assert_eq((ft5, id5), (type_double, 5))
  assert_eq(reader.read_double(), -1.5)
  let (ft6, id6) = reader.read_field_begin()
  assert_eq((ft6, id6), (type_list, 6))
  let (elem, n) = reader.read_list_begin()
  assert_eq((elem, n), (type_i32, 2))
  assert_eq(reader.read_i32(), 10)
  assert_eq(reader.read_i32(), 20)
  let (ft7, id7) = reader.read_field_begin()
  assert_eq((ft7, id7), (type_map, 7))
  let (kt, vt, size) = reader.read_map_begin()
  assert_eq((kt, vt, size), (type_string, type_i32, 1))
  assert_eq(reader.read_string(), "k")
  assert_eq(reader.read_i32(), 42)
  let (ft8, _) = reader.read_field_begin()
  assert_eq(ft8, type_stop)
}

///|
test "thrift: the compact protocol round-trips every primitive" {
  let writer = Compact::new(b"")
  writer.write_message_begin("ping", message_call, 7)
  writer.write_field_begin(type_string, 1)
  writer.write_string("hello")
  writer.write_field_begin(type_i32, 2)
  writer.write_i32(-7)
  writer.write_field_begin(type_i64, 3)
  writer.write_i64(-9_000_000_000L)
  writer.write_field_begin(type_bool, 4)
  writer.write_bool(true)
  writer.write_field_begin(type_double, 5)
  writer.write_double(-1.5)
  writer.write_field_begin(type_list, 6)
  writer.write_list_begin(type_i32, 2)
  writer.write_i32(10)
  writer.write_i32(20)
  writer.write_field_begin(type_map, 7)
  writer.write_map_begin(type_string, type_i32, 1)
  writer.write_string("k")
  writer.write_i32(42)
  writer.write_field_stop()

  let reader : &Protocol = Compact::new(writer.output())
  let (name, kind, seqid) = reader.read_message_begin()
  assert_eq(name, "ping")
  assert_eq(kind, message_call)
  assert_eq(seqid, 7)
  reader.read_struct_begin()
  let (ft1, id1) = reader.read_field_begin()
  assert_eq((ft1, id1), (type_string, 1))
  assert_eq(reader.read_string(), "hello")
  let (ft2, id2) = reader.read_field_begin()
  assert_eq((ft2, id2), (type_i32, 2))
  assert_eq(reader.read_i32(), -7)
  let (ft3, id3) = reader.read_field_begin()
  assert_eq((ft3, id3), (type_i64, 3))
  assert_eq(reader.read_i64(), -9_000_000_000L)
  let (ft4, id4) = reader.read_field_begin()
  assert_eq((ft4, id4), (type_bool, 4))
  assert_true(reader.read_bool())
  let (ft5, id5) = reader.read_field_begin()
  assert_eq((ft5, id5), (type_double, 5))
  assert_eq(reader.read_double(), -1.5)
  let (ft6, id6) = reader.read_field_begin()
  assert_eq((ft6, id6), (type_list, 6))
  let (elem, n) = reader.read_list_begin()
  assert_eq((elem, n), (type_i32, 2))
  assert_eq(reader.read_i32(), 10)
  assert_eq(reader.read_i32(), 20)
  let (ft7, id7) = reader.read_field_begin()
  assert_eq((ft7, id7), (type_map, 7))
  let (kt, vt, size) = reader.read_map_begin()
  assert_eq((kt, vt, size), (type_string, type_i32, 1))
  assert_eq(reader.read_string(), "k")
  assert_eq(reader.read_i32(), 42)
  let (ft8, _) = reader.read_field_begin()
  assert_eq(ft8, type_stop)
}

///|
/// The bytes Apache Thrift's compact protocol writes for a small call, so a change in
/// our encoding is caught here rather than by a peer.
test "thrift: the compact protocol matches Apache's bytes" {
  let writer = Compact::new(b"")
  writer.write_message_begin("ping", message_call, 1)
  writer.write_struct_begin("ping_args")
  writer.write_field_begin(type_string, 1)
  writer.write_string("go")
  writer.write_field_stop()
  writer.write_struct_end()
  // 82 21 01 04 'ping' 18 02 'go' 00
  //  |  |  |  |        |  |  |
  //  |  |  |  |        |  |  \_ the value
  //  |  |  |  |        |  \_ its length, a varint
  //  |  |  |  |        \_ delta 1 in the high half, binary (8) in the low
  //  |  |  |  \_ name length, a varint
  //  |  |  \_ seqid, a varint
  //  |  \_ version 1, CALL (1) shifted into the high three bits
  //  \_ protocol id
  assert_eq(writer.output(), b"\x82\x21\x01\x04ping\x18\x02go\x00")
}

///|
test "thrift: compact doubles are little-endian, binary doubles big-endian" {
  let compact = Compact::new(b"")
  compact.write_double(1.5)
  // 1.5 is 0x3FF8000000000000.
  assert_eq(compact.output(), b"\x00\x00\x00\x00\x00\x00\xF8\x3F")
  let binary = Binary::new(b"")
  binary.write_double(1.5)
  assert_eq(binary.output(), b"\x3F\xF8\x00\x00\x00\x00\x00\x00")
  let compact_back : &Protocol = Compact::new(compact.output())
  assert_eq(compact_back.read_double(), 1.5)
  let binary_back : &Protocol = Binary::new(binary.output())
  assert_eq(binary_back.read_double(), 1.5)
}

///|
test "thrift: a truncated body is refused, not read past its end" {
  let writer = Binary::new(b"")
  writer.write_string("a string that is longer than what follows")
  let body = writer.output()
  let cut = body[:body.length() - 3].to_owned()
  let raised = try {
    let reader : &Protocol = Binary::new(cut)
    ignore(reader.read_string())
    false
  } catch {
    Truncated => true
    _ => false
  }
  assert_true(raised)
}

///|
test "thrift: the processor answers a call and refuses an unknown method" {
  let processor = Processor::new()
  processor.add("ping", proto => {
    let (ft, id) = proto.read_field_begin()
    if (ft, id) != (type_string, 1) {
      abort("the ping argument is field 1, a string")
    }
    let text = proto.read_string()
    ignore(proto.read_field_begin())
    proto.write_field_begin(type_string, 0)
    proto.write_string("pong:" + text)
  })
  let call_message = Binary::new(b"")
  call_message.write_message_begin("ping", message_call, 3)
  call_message.write_struct_begin("ping_args")
  call_message.write_field_begin(type_string, 1)
  call_message.write_string("hi")
  call_message.write_field_stop()
  call_message.write_struct_end()
  let proto : &Protocol = Binary::new(b"")
  let reply = processor.process(proto, call_message.output())
  let reader : &Protocol = Binary::new(reply)
  let (name, kind, seqid) = reader.read_message_begin()
  assert_eq((name, kind, seqid), ("ping", message_reply, 3))
  reader.read_struct_begin()
  let (ft, id) = reader.read_field_begin()
  assert_eq((ft, id), (type_string, 0))
  assert_eq(reader.read_string(), "pong:hi")

  let missing = Binary::new(b"")
  missing.write_message_begin("nope", message_call, 4)
  missing.write_struct_begin("nope_args")
  missing.write_field_stop()
  missing.write_struct_end()
  let refused = processor.process(proto, missing.output())
  let reader2 : &Protocol = Binary::new(refused)
  let (_, kind2, _) = reader2.read_message_begin()
  assert_eq(kind2, message_exception)
}

///|
test "thrift: the same service answers in the compact protocol" {
  let processor = Processor::new()
  processor.add("add", proto => {
    ignore(proto.read_field_begin())
    let a = proto.read_i32()
    ignore(proto.read_field_begin())
    let b = proto.read_i32()
    ignore(proto.read_field_begin())
    proto.write_field_begin(type_i32, 0)
    proto.write_i32(a + b)
  })
  let call_message = Compact::new(b"")
  call_message.write_message_begin("add", message_call, 9)
  call_message.write_struct_begin("add_args")
  call_message.write_field_begin(type_i32, 1)
  call_message.write_i32(20)
  call_message.write_field_begin(type_i32, 2)
  call_message.write_i32(22)
  call_message.write_field_stop()
  call_message.write_struct_end()
  let proto : &Protocol = Compact::new(b"")
  let reply = processor.process(proto, call_message.output())
  let reader : &Protocol = Compact::new(reply)
  let (_, kind, seqid) = reader.read_message_begin()
  assert_eq((kind, seqid), (message_reply, 9))
  reader.read_struct_begin()
  let (ft, id) = reader.read_field_begin()
  assert_eq((ft, id), (type_i32, 0))
  assert_eq(reader.read_i32(), 42)
}

///|
test "thrift: read_success decodes field 0 and refuses another field" {
  let writer = Binary::new(b"")
  writer.write_field_begin(type_i32, 0)
  writer.write_i32(42)
  writer.write_field_stop()
  let proto : &Protocol = Binary::new(writer.output())
  let value = read_success(proto, proto => proto.read_i32()) catch {
    _ => abort("field 0 is the success value")
  }
  assert_eq(value, 42)

  let failed = Binary::new(b"")
  failed.write_field_begin(type_string, 1)
  failed.write_string("boom")
  failed.write_field_stop()
  let proto2 : &Protocol = Binary::new(failed.output())
  let raised = try {
    ignore(read_success(proto2, proto => proto.read_i32()))
    false
  } catch {
    Application(message) => message == "boom"
    _ => false
  }
  assert_true(raised)
}

///|
fn compact_protocol(input : Bytes) -> &Protocol {
  Compact::new(input)
}

///|
fn binary_protocol(input : Bytes) -> &Protocol {
  Binary::new(input)
}

///|
test "thrift: skip walks a nested struct in either protocol" {
  for compact in [false, true] {
    let writer : &Protocol = if compact {
      compact_protocol(b"")
    } else {
      binary_protocol(b"")
    }
    writer.write_field_begin(type_struct, 1)
    writer.write_struct_begin("inner")
    writer.write_field_begin(type_double, 1)
    writer.write_double(2.5)
    writer.write_field_begin(type_list, 2)
    writer.write_list_begin(type_bool, 2)
    writer.write_bool(true)
    writer.write_bool(false)
    writer.write_field_begin(type_map, 3)
    writer.write_map_begin(type_i32, type_string, 1)
    writer.write_i32(1)
    writer.write_string("one")
    writer.write_field_stop()
    writer.write_struct_end()
    writer.write_field_begin(type_i32, 2)
    writer.write_i32(7)
    writer.write_field_stop()

    let reader : &Protocol = if compact {
      compact_protocol(writer.output())
    } else {
      binary_protocol(writer.output())
    }
    reader.read_struct_begin()
    let (ft, id) = reader.read_field_begin()
    assert_eq((ft, id), (type_struct, 1))
    skip(reader, ft) catch {
      _ => abort("the struct must be skippable")
    }
    let (ft2, id2) = reader.read_field_begin()
    assert_eq((ft2, id2), (type_i32, 2))
    assert_eq(reader.read_i32(), 7)
  }
}

///|
test "thrift: a frame announces its body length" {
  let body = b"hello"
  let framed = frame(body)
  assert_eq(framed.length(), 9)
  assert_eq(frame_len(framed[:4].to_owned()), 5)
  assert_eq(framed[4:].to_owned() == body, true)
}

///|
test "thrift: a uuid is sixteen raw bytes, with no length in front" {
  let uuid = b"\x00\x11\x22\x33\x44\x55\x66\x77\x88\x99\xaa\xbb\xcc\xdd\xee\xff"
  let writer = Binary::new(b"")
  writer.write_field_begin(type_uuid, 1)
  writer.write_uuid(uuid)
  writer.write_field_stop()
  // The binary field header is the type byte and a big-endian id; the value follows as
  // it was given, which is why the first nineteen bytes are the whole of it.
  let binary = writer.output()
  assert_eq(binary[0:19].to_owned(), b"\x10\x00\x01" + uuid)

  let compact = Compact::new(b"")
  compact.write_field_begin(type_uuid, 1)
  compact.write_uuid(uuid)
  compact.write_field_stop()
  // The compact header packs the id delta above the type; a uuid's type code is 0x0D.
  assert_eq(compact.output()[0:17].to_owned(), b"\x1d" + uuid)

  for proto in [binary_protocol(binary), compact_protocol(compact.output())] {
    proto.read_struct_begin()
    let (ft, id) = proto.read_field_begin()
    assert_eq((ft, id), (type_uuid, 1))
    assert_eq(proto.read_uuid() == uuid, true)
    let (stop, _) = proto.read_field_begin()
    assert_eq(stop, type_stop)
  }
}

///|
test "thrift: skip walks past a uuid" {
  for compact in [false, true] {
    let writer : &Protocol = if compact {
      compact_protocol(b"")
    } else {
      binary_protocol(b"")
    }
    writer.write_field_begin(type_uuid, 1)
    writer.write_uuid(b"0123456789abcdef")
    writer.write_field_begin(type_i32, 2)
    writer.write_i32(9)
    writer.write_field_stop()
    let reader : &Protocol = if compact {
      compact_protocol(writer.output())
    } else {
      binary_protocol(writer.output())
    }
    reader.read_struct_begin()
    let (ft, _) = reader.read_field_begin()
    skip(reader, ft) catch {
      _ => abort("a uuid must be skippable")
    }
    let (ft2, _) = reader.read_field_begin()
    assert_eq(ft2, type_i32)
    assert_eq(reader.read_i32(), 9)
  }
}

///|
test "thrift: a handler that fails answers a TApplicationException" {
  let processor = Processor::new()
  processor.add("half", proto => {
    // The handler gets as far as writing a field, then fails: the processor must drop
    // that half-written result rather than splice an exception into it.
    ignore(proto.read_field_begin())
    ignore(proto.read_string())
    proto.write_field_begin(type_string, 0)
    proto.write_string("partial")
    raise Application("no")
  })
  for compact in [false, true] {
    let call_message = if compact {
      compact_protocol(b"")
    } else {
      binary_protocol(b"")
    }
    call_message.write_message_begin("half", message_call, 5)
    call_message.write_struct_begin("half_args")
    call_message.write_field_begin(type_string, 1)
    call_message.write_string("x")
    call_message.write_field_stop()
    call_message.write_struct_end()
    let proto = if compact {
      compact_protocol(b"")
    } else {
      binary_protocol(b"")
    }
    let reply = processor.process(proto, call_message.output())
    let reader = if compact {
      compact_protocol(reply)
    } else {
      binary_protocol(reply)
    }
    let (name, kind, seqid) = reader.read_message_begin()
    assert_eq((name, kind, seqid), ("half", message_exception, 5))
    reader.read_struct_begin()
    let (ft, id) = reader.read_field_begin()
    assert_eq((ft, id), (type_string, 1))
    // The message the handler raised, not its repr: this is what an Apache Thrift
    // server puts in the exception a client reads.
    assert_eq(reader.read_string(), "no")
    let (ft2, id2) = reader.read_field_begin()
    assert_eq((ft2, id2), (type_i32, 2))
    assert_eq(reader.read_i32(), 6)
  }
}

///|
test "thrift: a set carries its own type, not the list's" {
  // The field header says `set`, and in the compact protocol so does the collection
  // header's low nibble: a reader that took one for the other would still see the three
  // numbers, so the test pins the bytes instead of the values.
  let binary = Binary::new(b"")
  binary.write_field_begin(type_set, 1)
  binary.write_set_begin(type_i32, 3)
  for n in [1, 2, 42] {
    binary.write_i32(n)
  }
  binary.write_field_stop()
  assert_eq(
    binary.output()[0:8].to_owned(),
    b"\x0e\x00\x01\x08\x00\x00\x00\x03",
  )

  let compact = Compact::new(b"")
  compact.write_field_begin(type_set, 1)
  compact.write_set_begin(type_i32, 3)
  for n in [1, 2, 42] {
    compact.write_i32(n)
  }
  compact.write_field_stop()
  assert_eq(compact.output()[0:5].to_owned(), b"\x1a\x35\x02\x04\x54")

  // The compact protocol does not distinguish the two in the collection header itself:
  // the same three numbers in a list differ only in the field header's nibble.
  let as_list = Compact::new(b"")
  as_list.write_field_begin(type_list, 1)
  as_list.write_list_begin(type_i32, 3)
  for n in [1, 2, 42] {
    as_list.write_i32(n)
  }
  assert_eq(as_list.output()[0:5].to_owned(), b"\x19\x35\x02\x04\x54")

  let reader : &Protocol = Compact::new(compact.output())
  reader.read_struct_begin()
  let (ft, _) = reader.read_field_begin()
  assert_eq(ft, type_set)
  let (elem, n) = reader.read_set_begin()
  assert_eq((elem, n), (type_i32, 3))
  assert_eq(reader.read_i32(), 1)
  assert_eq(reader.read_i32(), 2)
  assert_eq(reader.read_i32(), 42)
}
