// The service side of Apache Thrift's cross test: `ThriftTest`, the twenty-three methods
// `test/ThriftTest.thrift` declares, written against `Protocol` so one processor answers
// in the binary and in the compact protocol.
//
// Every method echoes what it was given, with the three exceptions the reference servers
// make — `testMapMap` and `testInsanity` answer a fixed shape, `testMulti` answers an
// `Xtruct` built from its arguments — so a client on the other end of the socket is
// checking the wire, not this file's arithmetic.

///|
/// Read a call's arguments to the end of the struct. `take` is handed each field's id and
/// type and answers for the ones it knows; anything else is skipped, which is what lets a
/// newer client send a field this service never heard of.
fn read_args(
  proto : &@thrift.Protocol,
  take : (Int32, Int32) -> Unit raise @thrift.ThriftError,
) -> Unit raise @thrift.ThriftError {
  for ;; {
    let (field_type, field_id) = proto.read_field_begin()
    if field_type == @thrift.type_stop {
      return
    }
    take(field_id, field_type)
  }
}

///|
fn read_i32_map(
  proto : &@thrift.Protocol,
) -> Map[Int32, Int32] raise @thrift.ThriftError {
  let (_, _, size) = proto.read_map_begin()
  let out : Map[Int32, Int32] = Map([])
  for _ in 0..<size {
    let key = proto.read_i32()
    out[key] = proto.read_i32()
  }
  out
}

///|
fn write_i32_map(proto : &@thrift.Protocol, value : Map[Int32, Int32]) -> Unit {
  proto.write_map_begin(@thrift.type_i32, @thrift.type_i32, value.length())
  for key, item in value {
    proto.write_i32(key)
    proto.write_i32(item)
  }
}

///|
fn read_string_map(
  proto : &@thrift.Protocol,
) -> Map[String, String] raise @thrift.ThriftError {
  let (_, _, size) = proto.read_map_begin()
  let out : Map[String, String] = Map([])
  for _ in 0..<size {
    let key = proto.read_string()
    out[key] = proto.read_string()
  }
  out
}

///|
fn read_i32_set(
  proto : &@thrift.Protocol,
) -> Array[Int32] raise @thrift.ThriftError {
  let (_, size) = proto.read_set_begin()
  let out : Array[Int32] = []
  for _ in 0..<size {
    out.push(proto.read_i32())
  }
  out
}

///|
fn read_i32_list(
  proto : &@thrift.Protocol,
) -> Array[Int32] raise @thrift.ThriftError {
  let (_, size) = proto.read_list_begin()
  let out : Array[Int32] = []
  for _ in 0..<size {
    out.push(proto.read_i32())
  }
  out
}

///|
fn write_i32_list(
  proto : &@thrift.Protocol,
  type_ : Int32,
  value : Array[Int32],
) -> Unit {
  proto.write_list_begin(type_, value.length())
  for item in value {
    proto.write_i32(item)
  }
}

///|
/// The `ThriftTest` processor. Every method is registered here, so a client that finds one
/// missing gets the same `UNKNOWN_METHOD` an Apache Thrift server would send.
fn processor() -> @thrift.Processor {
  let processor = @thrift.Processor::new()
  processor.add("testVoid", _ => ())
  processor.add("testString", proto => {
    let mut thing = ""
    read_args(proto, (_, field_type) => {
      match field_type {
        t if t == @thrift.type_string => thing = proto.read_string()
        _ => @thrift.skip(proto, field_type)
      }
    })
    proto.write_field_begin(@thrift.type_string, 0)
    proto.write_string(thing)
  })
  processor.add("testBool", proto => {
    let mut thing = false
    read_args(proto, (_, field_type) => {
      match field_type {
        t if t == @thrift.type_bool => thing = proto.read_bool()
        _ => @thrift.skip(proto, field_type)
      }
    })
    proto.write_field_begin(@thrift.type_bool, 0)
    proto.write_bool(thing)
  })
  processor.add("testByte", proto => {
    let mut thing = 0
    read_args(proto, (_, field_type) => {
      match field_type {
        t if t == @thrift.type_byte => thing = proto.read_byte()
        _ => @thrift.skip(proto, field_type)
      }
    })
    proto.write_field_begin(@thrift.type_byte, 0)
    proto.write_byte(thing)
  })
  processor.add("testI32", proto => {
    let mut thing = 0
    read_args(proto, (_, field_type) => {
      match field_type {
        t if t == @thrift.type_i32 => thing = proto.read_i32()
        _ => @thrift.skip(proto, field_type)
      }
    })
    proto.write_field_begin(@thrift.type_i32, 0)
    proto.write_i32(thing)
  })
  processor.add("testI64", proto => {
    let mut thing = 0L
    read_args(proto, (_, field_type) => {
      match field_type {
        t if t == @thrift.type_i64 => thing = proto.read_i64()
        _ => @thrift.skip(proto, field_type)
      }
    })
    proto.write_field_begin(@thrift.type_i64, 0)
    proto.write_i64(thing)
  })
  processor.add("testDouble", proto => {
    let mut thing = 0.0
    read_args(proto, (_, field_type) => {
      match field_type {
        t if t == @thrift.type_double => thing = proto.read_double()
        _ => @thrift.skip(proto, field_type)
      }
    })
    proto.write_field_begin(@thrift.type_double, 0)
    proto.write_double(thing)
  })
  processor.add("testBinary", proto => {
    let mut thing = b""
    read_args(proto, (_, field_type) => {
      match field_type {
        t if t == @thrift.type_string => thing = proto.read_bytes()
        _ => @thrift.skip(proto, field_type)
      }
    })
    proto.write_field_begin(@thrift.type_string, 0)
    proto.write_bytes(thing)
  })
  processor.add("testUuid", proto => {
    let mut thing = b""
    read_args(proto, (_, field_type) => {
      match field_type {
        t if t == @thrift.type_uuid => thing = proto.read_uuid()
        _ => @thrift.skip(proto, field_type)
      }
    })
    proto.write_field_begin(@thrift.type_uuid, 0)
    proto.write_uuid(thing)
  })
  processor.add("testStruct", proto => {
    let mut thing = empty_xtruct()
    read_args(proto, (_, field_type) => {
      match field_type {
        t if t == @thrift.type_struct => thing = read_xtruct(proto)
        _ => @thrift.skip(proto, field_type)
      }
    })
    proto.write_field_begin(@thrift.type_struct, 0)
    write_xtruct(proto, thing)
  })
  processor.add("testNest", proto => {
    let mut thing = empty_xtruct2()
    read_args(proto, (_, field_type) => {
      match field_type {
        t if t == @thrift.type_struct => thing = read_xtruct2(proto)
        _ => @thrift.skip(proto, field_type)
      }
    })
    proto.write_field_begin(@thrift.type_struct, 0)
    write_xtruct2(proto, thing)
  })
  processor.add("testMap", proto => {
    let mut thing : Map[Int32, Int32] = Map([])
    read_args(proto, (_, field_type) => {
      match field_type {
        t if t == @thrift.type_map => thing = read_i32_map(proto)
        _ => @thrift.skip(proto, field_type)
      }
    })
    proto.write_field_begin(@thrift.type_map, 0)
    write_i32_map(proto, thing)
  })
  processor.add("testStringMap", proto => {
    let mut thing : Map[String, String] = Map([])
    read_args(proto, (_, field_type) => {
      match field_type {
        t if t == @thrift.type_map => thing = read_string_map(proto)
        _ => @thrift.skip(proto, field_type)
      }
    })
    proto.write_field_begin(@thrift.type_map, 0)
    proto.write_map_begin(
      @thrift.type_string,
      @thrift.type_string,
      thing.length(),
    )
    for key, item in thing {
      proto.write_string(key)
      proto.write_string(item)
    }
  })
  processor.add("testSet", proto => {
    let mut thing : Array[Int32] = []
    read_args(proto, (_, field_type) => {
      match field_type {
        t if t == @thrift.type_set => thing = read_i32_set(proto)
        _ => @thrift.skip(proto, field_type)
      }
    })
    proto.write_field_begin(@thrift.type_set, 0)
    proto.write_set_begin(@thrift.type_i32, thing.length())
    for item in thing {
      proto.write_i32(item)
    }
  })
  processor.add("testList", proto => {
    let mut thing : Array[Int32] = []
    read_args(proto, (_, field_type) => {
      match field_type {
        t if t == @thrift.type_list => thing = read_i32_list(proto)
        _ => @thrift.skip(proto, field_type)
      }
    })
    proto.write_field_begin(@thrift.type_list, 0)
    write_i32_list(proto, @thrift.type_i32, thing)
  })
  processor.add("testEnum", proto => {
    let mut thing = 0
    read_args(proto, (_, field_type) => {
      match field_type {
        t if t == @thrift.type_i32 => thing = proto.read_i32()
        _ => @thrift.skip(proto, field_type)
      }
    })
    proto.write_field_begin(@thrift.type_i32, 0)
    proto.write_i32(thing)
  })
  processor.add("testTypedef", proto => {
    let mut thing = 0L
    read_args(proto, (_, field_type) => {
      match field_type {
        t if t == @thrift.type_i64 => thing = proto.read_i64()
        _ => @thrift.skip(proto, field_type)
      }
    })
    proto.write_field_begin(@thrift.type_i64, 0)
    proto.write_i64(thing)
  })
  processor.add("testMapMap", proto => {
    read_args(proto, (_, field_type) => {
      if field_type == @thrift.type_i32 {
        ignore(proto.read_i32())
      } else {
        @thrift.skip(proto, field_type)
      }
    })
    // The four negatives under -4 and the four positives under 4, whatever `hello` was.
    proto.write_field_begin(@thrift.type_map, 0)
    proto.write_map_begin(@thrift.type_i32, @thrift.type_map, 2)
    for sign in [-1, 1] {
      proto.write_i32(sign * 4)
      proto.write_map_begin(@thrift.type_i32, @thrift.type_i32, 4)
      for step in [1, 2, 3, 4] {
        proto.write_i32(sign * step)
        proto.write_i32(sign * step)
      }
    }
  })
  processor.add("testInsanity", proto => {
    let mut argument = empty_insanity()
    read_args(proto, (_, field_type) => {
      match field_type {
        t if t == @thrift.type_struct => argument = read_insanity(proto)
        _ => @thrift.skip(proto, field_type)
      }
    })
    // { 1 => { 2 => argument, 3 => argument }, 2 => { 6 => an empty Insanity } }
    proto.write_field_begin(@thrift.type_map, 0)
    proto.write_map_begin(@thrift.type_i64, @thrift.type_map, 2)
    proto.write_i64(1L)
    proto.write_map_begin(@thrift.type_i32, @thrift.type_struct, 2)
    proto.write_i32(2)
    write_insanity(proto, argument)
    proto.write_i32(3)
    write_insanity(proto, argument)
    proto.write_i64(2L)
    proto.write_map_begin(@thrift.type_i32, @thrift.type_struct, 1)
    proto.write_i32(6)
    write_insanity(proto, empty_insanity())
  })
  processor.add("testMulti", proto => {
    let mut arg0 = 0
    let mut arg1 = 0
    let mut arg2 = 0L
    // The enum and the i32 are the same type on the wire, so the field id is what tells
    // the arguments apart here.
    read_args(proto, (field_id, field_type) => {
      match field_id {
        1 => arg0 = proto.read_byte()
        2 => arg1 = proto.read_i32()
        3 => arg2 = proto.read_i64()
        4 => {
          let (_, _, size) = proto.read_map_begin()
          for _ in 0..<size {
            ignore(proto.read_i16())
            ignore(proto.read_string())
          }
        }
        5 => ignore(proto.read_i32())
        6 => ignore(proto.read_i64())
        _ => @thrift.skip(proto, field_type)
      }
    })
    proto.write_field_begin(@thrift.type_struct, 0)
    write_xtruct(proto, {
      string_thing: "Hello2",
      byte_thing: arg0,
      i32_thing: arg1,
      i64_thing: arg2,
    })
  })
  processor.add("testException", proto => {
    let mut arg = ""
    read_args(proto, (_, field_type) => {
      match field_type {
        t if t == @thrift.type_string => arg = proto.read_string()
        _ => @thrift.skip(proto, field_type)
      }
    })
    if arg == "Xception" {
      proto.write_field_begin(@thrift.type_struct, 1)
      write_xception(proto, { error_code: 1001, message: arg, })
    } else if arg == "TException" {
      // No field to put it in: this one is the application exception a processor builds
      // when a handler fails, which is what every other reference server answers here.
      raise @thrift.Application("Just TException")
    }
  })
  processor.add("testMultiException", proto => {
    let mut arg0 = ""
    let mut arg1 = ""
    read_args(proto, (field_id, field_type) => {
      match field_id {
        1 => arg0 = proto.read_string()
        2 => arg1 = proto.read_string()
        _ => @thrift.skip(proto, field_type)
      }
    })
    if arg0 == "Xception" {
      proto.write_field_begin(@thrift.type_struct, 1)
      write_xception(proto, {
        error_code: 1001,
        message: "This is an Xception",
      })
    } else if arg0 == "Xception2" {
      proto.write_field_begin(@thrift.type_struct, 2)
      write_xception2(proto, {
        error_code: 2002,
        struct_thing: {
          string_thing: "This is an Xception2",
          byte_thing: 0,
          i32_thing: 0,
          i64_thing: 0L,
        },
      })
    } else {
      proto.write_field_begin(@thrift.type_struct, 0)
      write_xtruct(proto, {
        string_thing: arg1,
        byte_thing: 0,
        i32_thing: 0,
        i64_thing: 0L,
      })
    }
  })
  // A ONEWAY method: the argument is consumed and nothing is written back. The reference
  // servers sleep for the argument first; sleeping here would hold the connection's frame
  // loop for something no client waits on, so the wait is left out, and the conformance
  // table says so.
  processor.add_oneway("testOneway", proto => {
    read_args(proto, (_, field_type) => {
      match field_type {
        t if t == @thrift.type_i32 => ignore(proto.read_i32())
        _ => @thrift.skip(proto, field_type)
      }
    })
  })
  processor
}
