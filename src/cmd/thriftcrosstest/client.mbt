// The client half of Apache Thrift's cross test: the calls
// `test/go/src/bin/testclient/main.go` makes, in the same order and against the same
// expected answers, so pointing this at a reference server checks what that client checks.
//
// A mismatch stops the run: the sequence is one conversation, and a wrong answer early
// makes the rest of it meaningless.

///|
/// A scalar or a list standing where the reference client compares one: the message names
/// the call, since the caller has no stack trace to read.
fn[T : Eq + Debug] expect(what : String, want : T, got : T) -> Unit {
  if want != got {
    abort(
      "\{what}: want \{@debug.Debug::to_repr(want)}, got \{@debug.Debug::to_repr(got)}",
    )
  }
}

///|
/// The same for the structs here, which have no `Show` to print themselves with.
fn expect_struct(what : String, same : Bool) -> Unit {
  if !same {
    abort("\{what}: the answer differs from the request")
  }
}

///|
async fn check(
  client : @net.ThriftClient,
  proto : &@thrift.Protocol,
) -> Unit raise @thrift.ThriftError {
  let mut seqid = 0
  let next = () => {
    seqid = seqid + 1
    seqid
  }
  // testVoid: the result struct is empty — a STOP and nothing else — so there is no field
  // 0 to read. `request` stops after the message header, which is the whole answer.
  @thrift.request(client, proto, "testVoid", next(), _ => ())
  let thing = @thrift.call(
    client,
    proto,
    "testString",
    next(),
    proto => {
      proto.write_field_begin(@thrift.type_string, 1)
      proto.write_string("thing")
    },
    proto => proto.read_string(),
  )
  expect("testString", "thing", thing)

  for value in [true, false] {
    let echoed = @thrift.call(
      client,
      proto,
      "testBool",
      next(),
      proto => {
        proto.write_field_begin(@thrift.type_bool, 1)
        proto.write_bool(value)
      },
      proto => proto.read_bool(),
    )
    expect("testBool", value, echoed)
  }

  let byte = @thrift.call(
    client,
    proto,
    "testByte",
    next(),
    proto => {
      proto.write_field_begin(@thrift.type_byte, 1)
      proto.write_byte(42)
    },
    proto => proto.read_byte(),
  )
  expect("testByte", 42, byte)

  let i32 = @thrift.call(
    client,
    proto,
    "testI32",
    next(),
    proto => {
      proto.write_field_begin(@thrift.type_i32, 1)
      proto.write_i32(4242)
    },
    proto => proto.read_i32(),
  )
  expect("testI32", 4242, i32)

  let i64 = @thrift.call(
    client,
    proto,
    "testI64",
    next(),
    proto => {
      proto.write_field_begin(@thrift.type_i64, 1)
      proto.write_i64(424242L)
    },
    proto => proto.read_i64(),
  )
  expect("testI64", 424242L, i64)

  let double = @thrift.call(
    client,
    proto,
    "testDouble",
    next(),
    proto => {
      proto.write_field_begin(@thrift.type_double, 1)
      proto.write_double(42.42)
    },
    proto => proto.read_double(),
  )
  expect("testDouble", 42.42, double)

  // Every byte value, so a reader that sign-extends a byte, or swaps one, is caught.
  let mut binary = b""
  for n in 0..<256 {
    binary = binary + b"\{n.to_byte()}"
  }
  let echoed_binary = @thrift.call(
    client,
    proto,
    "testBinary",
    next(),
    proto => {
      proto.write_field_begin(@thrift.type_string, 1)
      proto.write_bytes(binary)
    },
    proto => proto.read_bytes(),
  )
  expect("testBinary", binary, echoed_binary)

  let uuid = b"\x00\x11\x22\x33\x44\x55\x66\x77\x88\x99\xaa\xbb\xcc\xdd\xee\xff"
  let echoed_uuid = @thrift.call(
    client,
    proto,
    "testUuid",
    next(),
    proto => {
      proto.write_field_begin(@thrift.type_uuid, 1)
      proto.write_uuid(uuid)
    },
    proto => proto.read_uuid(),
  )
  expect("testUuid", uuid, echoed_uuid)

  let xtruct = {
    string_thing: "thing",
    byte_thing: 42,
    i32_thing: 4242,
    i64_thing: 424242L,
  }
  let echoed_xtruct = @thrift.call(
    client,
    proto,
    "testStruct",
    next(),
    proto => {
      proto.write_field_begin(@thrift.type_struct, 1)
      write_xtruct(proto, xtruct)
    },
    proto => read_xtruct(proto),
  )
  expect_struct("testStruct", xtruct == echoed_xtruct)

  let nested = { byte_thing: 0, struct_thing: xtruct, i32_thing: 0, }
  let echoed_nested = @thrift.call(
    client,
    proto,
    "testNest",
    next(),
    proto => {
      proto.write_field_begin(@thrift.type_struct, 1)
      write_xtruct2(proto, nested)
    },
    proto => read_xtruct2(proto),
  )
  expect_struct("testNest", nested == echoed_nested)

  let map = Map([(1, 2), (3, 4), (5, 42)])
  let echoed_map = @thrift.call(
    client,
    proto,
    "testMap",
    next(),
    proto => {
      proto.write_field_begin(@thrift.type_map, 1)
      write_i32_map(proto, map)
    },
    proto => read_i32_map(proto),
  )
  expect("testMap", map.length(), echoed_map.length())
  for key, value in map {
    expect("testMap[\{key}]", value, echoed_map[key])
  }

  let string_map = Map([("a", "2"), ("b", "blah"), ("some", "thing")])
  let echoed_string_map = @thrift.call(
    client,
    proto,
    "testStringMap",
    next(),
    proto => {
      proto.write_field_begin(@thrift.type_map, 1)
      proto.write_map_begin(
        @thrift.type_string,
        @thrift.type_string,
        string_map.length(),
      )
      for key, value in string_map {
        proto.write_string(key)
        proto.write_string(value)
      }
    },
    proto => read_string_map(proto),
  )
  expect("testStringMap", string_map, echoed_string_map)

  // A set comes back in whatever order the server keeps it, so it is compared as one.
  let set = [1, 2, 42]
  let echoed_set = @thrift.call(
    client,
    proto,
    "testSet",
    next(),
    proto => {
      proto.write_field_begin(@thrift.type_set, 1)
      proto.write_set_begin(@thrift.type_i32, set.length())
      for item in set {
        proto.write_i32(item)
      }
    },
    proto => read_i32_set(proto),
  )
  expect("testSet", set.length(), echoed_set.length())
  for item in set {
    expect("testSet holds \{item}", true, echoed_set.contains(item))
  }

  let list = [1, 2, 42]
  let echoed_list = @thrift.call(
    client,
    proto,
    "testList",
    next(),
    proto => {
      proto.write_field_begin(@thrift.type_list, 1)
      write_i32_list(proto, @thrift.type_i32, list)
    },
    proto => read_i32_list(proto),
  )
  expect("testList", list, echoed_list)

  // Numberz TWO is 2; the enum travels as its number and nothing else.
  let numberz = @thrift.call(
    client,
    proto,
    "testEnum",
    next(),
    proto => {
      proto.write_field_begin(@thrift.type_i32, 1)
      proto.write_i32(2)
    },
    proto => proto.read_i32(),
  )
  expect("testEnum", 2, numberz)

  let typedef = @thrift.call(
    client,
    proto,
    "testTypedef",
    next(),
    proto => {
      proto.write_field_begin(@thrift.type_i64, 1)
      proto.write_i64(42L)
    },
    proto => proto.read_i64(),
  )
  expect("testTypedef", 42L, typedef)

  let map_map = @thrift.call(
    client,
    proto,
    "testMapMap",
    next(),
    proto => {
      proto.write_field_begin(@thrift.type_i32, 1)
      proto.write_i32(42)
    },
    proto => read_i32_map_of_maps(proto),
  )
  let negative = map_map.get(-4)
  let positive = map_map.get(4)
  guard negative is Some(negative) && positive is Some(positive) else {
    abort("testMapMap: want the keys -4 and 4, got \{map_map.length()} entries")
  }
  for step in [1, 2, 3, 4] {
    expect("testMapMap[-4][-\{step}]", -step, negative[-step])
    expect("testMapMap[4][\{step}]", step, positive[step])
  }

  let crazy = {
    user_map: Map([(5, 5L), (8, 8L)]),
    xtructs: [
      { string_thing: "Goodbye4", byte_thing: 4, i32_thing: 4, i64_thing: 4L, },
      { string_thing: "Hello2", byte_thing: 2, i32_thing: 2, i64_thing: 2L, },
    ],
  }
  let insanity = @thrift.call(
    client,
    proto,
    "testInsanity",
    next(),
    proto => {
      proto.write_field_begin(@thrift.type_struct, 1)
      write_insanity(proto, crazy)
    },
    proto => read_insanity_map(proto),
  )
  expect("testInsanity: the map holds two entries", 2, insanity.length())
  for numberz in [2, 3] {
    match insanity.get(1L) {
      Some(inner) =>
        match inner.get(numberz) {
          Some(value) =>
            expect_struct("testInsanity[1][\{numberz}]", crazy == value)
          None => abort("testInsanity: no entry for \{numberz}")
        }
      None => abort("testInsanity: no entry for 1")
    }
  }
  match insanity.get(2L) {
    Some(inner) =>
      match inner.get(6) {
        Some(value) =>
          expect(
            "testInsanity[2][6] is empty",
            0,
            value.user_map.length() + value.xtructs.length(),
          )
        None => abort("testInsanity: no entry for 6")
      }
    None => abort("testInsanity: no entry for 2")
  }

  let multi = @thrift.call(
    client,
    proto,
    "testMulti",
    next(),
    proto => {
      proto.write_field_begin(@thrift.type_byte, 1)
      proto.write_byte(42)
      proto.write_field_begin(@thrift.type_i32, 2)
      proto.write_i32(4242)
      proto.write_field_begin(@thrift.type_i64, 3)
      proto.write_i64(424242L)
      proto.write_field_begin(@thrift.type_map, 4)
      proto.write_map_begin(@thrift.type_i16, @thrift.type_string, 2)
      proto.write_i16(1)
      proto.write_string("blah")
      proto.write_i16(2)
      proto.write_string("thing")
      proto.write_field_begin(@thrift.type_i32, 5)
      proto.write_i32(8)
      proto.write_field_begin(@thrift.type_i64, 6)
      proto.write_i64(24L)
    },
    proto => read_xtruct(proto),
  )
  expect_struct(
    "testMulti",
    multi ==
    {
      string_thing: "Hello2",
      byte_thing: 42,
      i32_thing: 4242,
      i64_thing: 424242L,
    },
  )

  let declared = @thrift.call_result_unit(
    client,
    proto,
    "testException",
    next(),
    proto => {
      proto.write_field_begin(@thrift.type_string, 1)
      proto.write_string("Xception")
    },
    (proto, field_id) => {
      match field_id {
        1 => Some(read_xception(proto))
        _ => None
      }
    },
  )
  match declared {
    Ok(_) => abort("testException(Xception): want the declared exception")
    Err(failure) => {
      expect("testException(Xception).errorCode", 1001, failure.error_code)
      expect("testException(Xception).message", "Xception", failure.message)
    }
  }

  // The reference servers answer this one with a TApplicationException rather than a
  // declared exception, which the client sees as a Thrift error, not a result.
  let application : Result[Unit, @thrift.ThriftError] = Ok(
    @thrift.request(client, proto, "testException", next(), proto => {
      proto.write_field_begin(@thrift.type_string, 1)
      proto.write_string("TException")
    }),
  ) catch {
    e => Err(e)
  }
  match application {
    Ok(_) => abort("testException(TException): want an application exception")
    // Each implementation words the wrapper differently — Go's says "Internal error
    // processing testException: Just TException" — so the handler's own text is what is
    // checked, which is the part Apache's client compares too.
    Err(Application(message)) =>
      if !message.contains("Just TException") {
        abort("testException(TException).message: got \{message}")
      }
    Err(other) =>
      abort(
        "testException(TException): want Application, got \{other.to_string()}",
      )
  }

  let multi_exception = @thrift.call_result(
    client,
    proto,
    "testMultiException",
    next(),
    proto => {
      proto.write_field_begin(@thrift.type_string, 1)
      proto.write_string("Xception")
      proto.write_field_begin(@thrift.type_string, 2)
      proto.write_string("ignoreme")
    },
    proto => read_xtruct(proto),
    (proto, field_id) => {
      match field_id {
        1 => Some(MultiFailure::Thrown(read_xception(proto)))
        2 => Some(MultiFailure::ThrownSecond(read_xception2(proto)))
        _ => None
      }
    },
  )
  match multi_exception {
    Ok(_) => abort("testMultiException(Xception): want the declared exception")
    Err(MultiFailure::Thrown(failure)) => {
      expect("testMultiException(Xception).errorCode", 1001, failure.error_code)
      expect(
        "testMultiException(Xception).message",
        "This is an Xception",
        failure.message,
      )
    }
    Err(MultiFailure::ThrownSecond(_)) =>
      abort("testMultiException(Xception): want Xception")
  }

  let second = @thrift.call_result(
    client,
    proto,
    "testMultiException",
    next(),
    proto => {
      proto.write_field_begin(@thrift.type_string, 1)
      proto.write_string("Xception2")
      proto.write_field_begin(@thrift.type_string, 2)
      proto.write_string("ignoreme")
    },
    proto => read_xtruct(proto),
    (proto, field_id) => {
      match field_id {
        1 => Some(MultiFailure::Thrown(read_xception(proto)))
        2 => Some(MultiFailure::ThrownSecond(read_xception2(proto)))
        _ => None
      }
    },
  )
  match second {
    Ok(_) => abort("testMultiException(Xception2): want the declared exception")
    Err(MultiFailure::Thrown(_)) =>
      abort("testMultiException(Xception2): want Xception2")
    Err(MultiFailure::ThrownSecond(failure)) => {
      expect(
        "testMultiException(Xception2).errorCode",
        2002,
        failure.error_code,
      )
      expect(
        "testMultiException(Xception2).string_thing",
        "This is an Xception2",
        failure.struct_thing.string_thing,
      )
    }
  }

  let accepted = @thrift.call_result(
    client,
    proto,
    "testMultiException",
    next(),
    proto => {
      proto.write_field_begin(@thrift.type_string, 1)
      proto.write_string("success")
      proto.write_field_begin(@thrift.type_string, 2)
      proto.write_string("ignoreme")
    },
    proto => read_xtruct(proto),
    (proto, field_id) => {
      match field_id {
        1 => Some(MultiFailure::Thrown(read_xception(proto)))
        2 => Some(MultiFailure::ThrownSecond(read_xception2(proto)))
        _ => None
      }
    },
  )
  match accepted {
    Ok(value) =>
      expect("testMultiException(success)", "ignoreme", value.string_thing)
    Err(_) =>
      abort("testMultiException(success): want the value, not an exception")
  }

  // A ONEWAY call gets no reply at all: the next call must be answered on the same
  // connection, which is what proves the server did not wait to answer this one.
  client.send(
    @thrift.oneway(proto, "testOneway", next(), proto => {
      proto.write_field_begin(@thrift.type_i32, 1)
      proto.write_i32(2)
    }),
  )
  @thrift.request(client, proto, "testVoid", next(), _ => ())
}
