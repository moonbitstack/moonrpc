// TBinaryProtocol round trips, the processor's dispatch, and a request over an
// in-memory transport.

///|
test "thrift: a message of every primitive round-trips" {
  let writer = TWriter::new()
  writer.write_message_begin("ping", message_call, 7)
  writer.write_field_begin(type_string, 1)
  writer.write_string("hello")
  writer.write_field_begin(type_i32, 2)
  writer.write_i32(-7)
  writer.write_field_begin(type_i64, 3)
  writer.write_i64(-9_000_000_000L)
  writer.write_field_begin(type_bool, 4)
  writer.write_bool(true)
  writer.write_field_begin(type_list, 5)
  writer.write_list_begin(type_i32, 2)
  writer.write_i32(10)
  writer.write_i32(20)
  writer.write_field_begin(type_map, 6)
  writer.write_map_begin(type_string, type_i32, 1)
  writer.write_string("k")
  writer.write_i32(42)
  writer.write_field_stop()

  let reader = TReader::new(writer.to_bytes())
  let (name, kind, seqid) = reader.read_message_begin() catch {
    _ => abort("the header must decode")
  }
  assert_eq(name, "ping")
  assert_eq(kind, message_call)
  assert_eq(seqid, 7)
  let (ft1, id1) = reader.read_field_begin() catch { _ => abort("thrift test") }
  assert_eq((ft1, id1), (type_string, 1))
  assert_eq(reader.read_string() catch { _ => abort("thrift test") }, "hello")
  let (ft2, id2) = reader.read_field_begin() catch { _ => abort("thrift test") }
  assert_eq((ft2, id2), (type_i32, 2))
  assert_eq(reader.read_i32() catch { _ => abort("thrift test") }, -7)
  let (ft3, id3) = reader.read_field_begin() catch { _ => abort("thrift test") }
  assert_eq((ft3, id3), (type_i64, 3))
  assert_eq(
    reader.read_i64() catch {
      _ => abort("thrift test")
    },
    -9_000_000_000L,
  )
  let (ft4, id4) = reader.read_field_begin() catch { _ => abort("thrift test") }
  assert_eq((ft4, id4), (type_bool, 4))
  assert_true(reader.read_bool() catch { _ => abort("thrift test") })
  let (ft5, id5) = reader.read_field_begin() catch { _ => abort("thrift test") }
  assert_eq((ft5, id5), (type_list, 5))
  let (elem, n) = reader.read_list_begin() catch { _ => abort("thrift test") }
  assert_eq((elem, n), (type_i32, 2))
  assert_eq(reader.read_i32() catch { _ => abort("thrift test") }, 10)
  assert_eq(reader.read_i32() catch { _ => abort("thrift test") }, 20)
  let (ft6, id6) = reader.read_field_begin() catch { _ => abort("thrift test") }
  assert_eq((ft6, id6), (type_map, 6))
  let (kt, vt, size) = reader.read_map_begin() catch {
    _ => abort("thrift test")
  }
  assert_eq((kt, vt, size), (type_string, type_i32, 1))
  assert_eq(reader.read_string() catch { _ => abort("thrift test") }, "k")
  assert_eq(reader.read_i32() catch { _ => abort("thrift test") }, 42)
  let (ft7, _) = reader.read_field_begin() catch { _ => abort("thrift test") }
  assert_eq(ft7, type_stop)
}

///|
test "thrift: a truncated body is refused, not read past its end" {
  let writer = TWriter::new()
  writer.write_string("a string that is longer than what follows")
  let body = writer.to_bytes()
  let cut = body[:body.length() - 3].to_owned()
  let raised = try {
    ignore(TReader::new(cut).read_string())
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
  processor.add("ping", (reader, writer) => {
    let (ft, id) = reader.read_field_begin()
    if (ft, id) != (type_string, 1) {
      abort("the ping argument is field 1, a string")
    }
    let text = reader.read_string()
    ignore(reader.read_field_begin())
    writer.write_field_begin(type_string, 0)
    writer.write_string("pong:" + text)
  })
  let call = TWriter::new()
  call.write_message_begin("ping", message_call, 3)
  call.write_field_begin(type_string, 1)
  call.write_string("hi")
  call.write_field_stop()
  let reply = processor.process(call.to_bytes()) catch {
    _ => abort("the call must be answered")
  }
  let reader = TReader::new(reply)
  let (name, kind, seqid) = reader.read_message_begin() catch {
    _ => abort("thrift test")
  }
  assert_eq((name, kind, seqid), ("ping", message_reply, 3))
  let (ft, id) = reader.read_field_begin() catch { _ => abort("thrift test") }
  assert_eq((ft, id), (type_string, 0))
  assert_eq(reader.read_string() catch { _ => abort("thrift test") }, "pong:hi")

  let missing = TWriter::new()
  missing.write_message_begin("nope", message_call, 4)
  missing.write_field_stop()
  let refused = processor.process(missing.to_bytes()) catch {
    _ => abort("an unknown method must be answered")
  }
  let reader2 = TReader::new(refused)
  let (_, kind2, _) = reader2.read_message_begin() catch {
    _ => abort("thrift test")
  }
  assert_eq(kind2, message_exception)
}

///|
test "thrift: read_success decodes field 0 and refuses another field" {
  let writer = TWriter::new()
  writer.write_field_begin(type_i32, 0)
  writer.write_i32(42)
  writer.write_field_stop()
  let value = read_success(TReader::new(writer.to_bytes()), reader => {
    reader.read_i32()
  }) catch {
    _ => abort("field 0 is the success value")
  }
  assert_eq(value, 42)

  let failed = TWriter::new()
  failed.write_field_begin(type_string, 1)
  failed.write_string("boom")
  failed.write_field_stop()
  let raised = try {
    ignore(
      read_success(TReader::new(failed.to_bytes()), reader => reader.read_i32()),
    )
    false
  } catch {
    Application(message) => message == "boom"
    _ => false
  }
  assert_true(raised)
}

///|
test "thrift: a frame announces its body length" {
  let body = b"hello"
  let framed = frame(body)
  assert_eq(framed.length(), 9)
  assert_eq(
    frame_len(framed[:4].to_owned()) catch {
      _ => abort("thrift test")
    },
    5,
  )
  assert_eq(framed[4:].to_owned() == body, true)
}

///|
test "thrift: skip walks a double field without a decoder" {
  let writer = TWriter::new()
  writer.write_field_begin(type_double, 1)
  writer.write_i64(0L)
  writer.write_field_stop()
  let reader = TReader::new(writer.to_bytes())
  let (field_type, _) = reader.read_field_begin() catch {
    _ => abort("the field header must decode")
  }
  assert_eq(field_type, type_double)
  reader.skip(field_type) catch {
    _ => abort("a double must be skippable")
  }
  let (stop, _) = reader.read_field_begin() catch {
    _ => abort("the stop byte must decode")
  }
  assert_eq(stop, type_stop)
}
