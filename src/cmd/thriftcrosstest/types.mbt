// The seven types Apache Thrift's cross test carries, with the field numbers its
// ThriftTest.thrift gives them. Nothing here is generated: the cross test is a fixed
// shape, so the codecs are written out where a reader can compare them with the IDL.
//
// A struct is read field by field and any field this file does not know is skipped, the
// same rule the generated code in `29-thrift-idl` follows.

///|
#derive(Eq)
struct Xtruct {
  string_thing : String
  byte_thing : Int32
  i32_thing : Int32
  i64_thing : Int64
}

///|
#derive(Eq)
struct Xtruct2 {
  byte_thing : Int32
  struct_thing : Xtruct
  i32_thing : Int32
}

///|
#derive(Eq)
struct Xception {
  error_code : Int32
  message : String
}

///|
#derive(Eq)
struct Xception2 {
  error_code : Int32
  struct_thing : Xtruct
}

///|
/// `map<Numberz, UserId>` beside `list<Xtruct>`. The map's keys are the enum's numbers,
/// which is all the wire carries; a `Map` is what makes the two sides compare equal
/// whatever order the entries arrived in.
#derive(Eq)
struct Insanity {
  user_map : Map[Int32, Int64]
  xtructs : Array[Xtruct]
}

///|
fn empty_xtruct() -> Xtruct {
  { string_thing: "", byte_thing: 0, i32_thing: 0, i64_thing: 0L, }
}

///|
fn empty_xtruct2() -> Xtruct2 {
  { byte_thing: 0, struct_thing: empty_xtruct(), i32_thing: 0, }
}

///|
fn empty_insanity() -> Insanity {
  { user_map: Map([]), xtructs: [], }
}

///|
fn read_xtruct(proto : &@thrift.Protocol) -> Xtruct raise @thrift.ThriftError {
  let mut string_thing = ""
  let mut byte_thing = 0
  let mut i32_thing = 0
  let mut i64_thing = 0L
  proto.read_struct_begin()
  for ;; {
    let (field_type, field_id) = proto.read_field_begin()
    if field_type == @thrift.type_stop {
      break
    }
    match field_id {
      1 => string_thing = proto.read_string()
      4 => byte_thing = proto.read_byte()
      9 => i32_thing = proto.read_i32()
      11 => i64_thing = proto.read_i64()
      _ => @thrift.skip(proto, field_type)
    }
  }
  proto.read_struct_end()
  { string_thing, byte_thing, i32_thing, i64_thing, }
}

///|
fn write_xtruct(proto : &@thrift.Protocol, value : Xtruct) -> Unit {
  proto.write_struct_begin("Xtruct")
  proto.write_field_begin(@thrift.type_string, 1)
  proto.write_string(value.string_thing)
  proto.write_field_begin(@thrift.type_byte, 4)
  proto.write_byte(value.byte_thing)
  proto.write_field_begin(@thrift.type_i32, 9)
  proto.write_i32(value.i32_thing)
  proto.write_field_begin(@thrift.type_i64, 11)
  proto.write_i64(value.i64_thing)
  proto.write_field_stop()
  proto.write_struct_end()
}

///|
fn read_xtruct2(proto : &@thrift.Protocol) -> Xtruct2 raise @thrift.ThriftError {
  let mut byte_thing = 0
  let mut struct_thing = empty_xtruct()
  let mut i32_thing = 0
  proto.read_struct_begin()
  for ;; {
    let (field_type, field_id) = proto.read_field_begin()
    if field_type == @thrift.type_stop {
      break
    }
    match field_id {
      1 => byte_thing = proto.read_byte()
      2 => struct_thing = read_xtruct(proto)
      3 => i32_thing = proto.read_i32()
      _ => @thrift.skip(proto, field_type)
    }
  }
  proto.read_struct_end()
  { byte_thing, struct_thing, i32_thing, }
}

///|
fn write_xtruct2(proto : &@thrift.Protocol, value : Xtruct2) -> Unit {
  proto.write_struct_begin("Xtruct2")
  proto.write_field_begin(@thrift.type_byte, 1)
  proto.write_byte(value.byte_thing)
  proto.write_field_begin(@thrift.type_struct, 2)
  write_xtruct(proto, value.struct_thing)
  proto.write_field_begin(@thrift.type_i32, 3)
  proto.write_i32(value.i32_thing)
  proto.write_field_stop()
  proto.write_struct_end()
}

///|
fn read_insanity(
  proto : &@thrift.Protocol,
) -> Insanity raise @thrift.ThriftError {
  let user_map : Map[Int32, Int64] = Map([])
  let xtructs : Array[Xtruct] = []
  proto.read_struct_begin()
  for ;; {
    let (field_type, field_id) = proto.read_field_begin()
    if field_type == @thrift.type_stop {
      break
    }
    match field_id {
      1 => {
        let (_, _, size) = proto.read_map_begin()
        for _ in 0..<size {
          let key = proto.read_i32()
          user_map[key] = proto.read_i64()
        }
      }
      2 => {
        let (_, size) = proto.read_list_begin()
        for _ in 0..<size {
          xtructs.push(read_xtruct(proto))
        }
      }
      _ => @thrift.skip(proto, field_type)
    }
  }
  proto.read_struct_end()
  { user_map, xtructs, }
}

///|
fn write_insanity(proto : &@thrift.Protocol, value : Insanity) -> Unit {
  proto.write_struct_begin("Insanity")
  proto.write_field_begin(@thrift.type_map, 1)
  proto.write_map_begin(
    @thrift.type_i32,
    @thrift.type_i64,
    value.user_map.length(),
  )
  for key, id in value.user_map {
    proto.write_i32(key)
    proto.write_i64(id)
  }
  proto.write_field_begin(@thrift.type_list, 2)
  proto.write_list_begin(@thrift.type_struct, value.xtructs.length())
  for item in value.xtructs {
    write_xtruct(proto, item)
  }
  proto.write_field_stop()
  proto.write_struct_end()
}

///|
fn write_xception(proto : &@thrift.Protocol, value : Xception) -> Unit {
  proto.write_struct_begin("Xception")
  proto.write_field_begin(@thrift.type_i32, 1)
  proto.write_i32(value.error_code)
  proto.write_field_begin(@thrift.type_string, 2)
  proto.write_string(value.message)
  proto.write_field_stop()
  proto.write_struct_end()
}

///|
fn read_xception(
  proto : &@thrift.Protocol,
) -> Xception raise @thrift.ThriftError {
  let mut error_code = 0
  let mut message = ""
  proto.read_struct_begin()
  for ;; {
    let (field_type, field_id) = proto.read_field_begin()
    if field_type == @thrift.type_stop {
      break
    }
    match field_id {
      1 => error_code = proto.read_i32()
      2 => message = proto.read_string()
      _ => @thrift.skip(proto, field_type)
    }
  }
  proto.read_struct_end()
  { error_code, message, }
}

///|
fn write_xception2(proto : &@thrift.Protocol, value : Xception2) -> Unit {
  proto.write_struct_begin("Xception2")
  proto.write_field_begin(@thrift.type_i32, 1)
  proto.write_i32(value.error_code)
  proto.write_field_begin(@thrift.type_struct, 2)
  write_xtruct(proto, value.struct_thing)
  proto.write_field_stop()
  proto.write_struct_end()
}

///|
fn read_xception2(
  proto : &@thrift.Protocol,
) -> Xception2 raise @thrift.ThriftError {
  let mut error_code = 0
  let mut struct_thing = empty_xtruct()
  proto.read_struct_begin()
  for ;; {
    let (field_type, field_id) = proto.read_field_begin()
    if field_type == @thrift.type_stop {
      break
    }
    match field_id {
      1 => error_code = proto.read_i32()
      2 => struct_thing = read_xtruct(proto)
      _ => @thrift.skip(proto, field_type)
    }
  }
  proto.read_struct_end()
  { error_code, struct_thing, }
}

///|
/// What `testMultiException` can answer instead of a value: the two exceptions its
/// `throws` clause declares, in the field each is numbered.
enum MultiFailure {
  Thrown(Xception)
  ThrownSecond(Xception2)
}

///|
/// `map<i32, map<i32, i32>>`, the shape `testMapMap` answers.
fn read_i32_map_of_maps(
  proto : &@thrift.Protocol,
) -> Map[Int32, Map[Int32, Int32]] raise @thrift.ThriftError {
  let (_, _, size) = proto.read_map_begin()
  let out : Map[Int32, Map[Int32, Int32]] = Map([])
  for _ in 0..<size {
    let key = proto.read_i32()
    out[key] = read_i32_map(proto)
  }
  out
}

///|
/// `map<i64, map<i32, Insanity>>`, the shape `testInsanity` answers.
fn read_insanity_map(
  proto : &@thrift.Protocol,
) -> Map[Int64, Map[Int32, Insanity]] raise @thrift.ThriftError {
  let (_, _, size) = proto.read_map_begin()
  let out : Map[Int64, Map[Int32, Insanity]] = Map([])
  for _ in 0..<size {
    let key = proto.read_i64()
    let (_, _, inner) = proto.read_map_begin()
    let values : Map[Int32, Insanity] = Map([])
    for _ in 0..<inner {
      let numberz = proto.read_i32()
      values[numberz] = read_insanity(proto)
    }
    out[key] = values
  }
  out
}
