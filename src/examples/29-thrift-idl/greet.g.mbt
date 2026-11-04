// Generated from greet.thrift by thriftc. Do not edit.
// The package importing this file needs `moonbitstack/moonrpc/thrift`.

pub(all) enum Mood {
  Calm
  Happy
}

pub impl Eq for Mood with fn equal(self : Mood, other : Mood) -> Bool {
  self.to_i32() == other.to_i32()
}

pub impl Eq for Mood with fn not_equal(self : Mood, other : Mood) -> Bool {
  self.to_i32() != other.to_i32()
}

pub fn Mood::to_i32(self : Mood) -> Int32 {
  match self {
    Calm => 1
    Happy => 2
  }
}

pub fn Mood::from_i32(value : Int32) -> Mood raise @thrift.ThriftError {
  match value {
    1 => Calm
    2 => Happy
    other => raise @thrift.BadType(other)
  }
}

pub(all) struct SharedStamp {
  at : Int64
}

pub fn SharedStamp::default() -> SharedStamp {
  {
    at: 0L,
  }
}

pub fn SharedStamp::encode(self : SharedStamp, proto : &@thrift.Protocol) -> Unit {
  proto.write_struct_begin("SharedStamp")
  proto.write_field_begin(@thrift.type_i64, 1)
  proto.write_i64(self.at)
  proto.write_field_stop()
  proto.write_struct_end()
}

pub fn SharedStamp::decode(proto : &@thrift.Protocol) -> SharedStamp raise @thrift.ThriftError {
  let mut at : Int64 = 0L
  proto.read_struct_begin()
  for ;; {
    let (field_type, field_id) = proto.read_field_begin()
    if field_type == @thrift.type_stop {
      break
    }
    match field_id {
      1 => at = proto.read_i64()
      _ => @thrift.skip(proto, field_type)
    }
  }
  proto.read_struct_end()
  { at, }
}

pub(all) struct SharedMissing {
  message : String
  code : Int32
}

pub fn SharedMissing::default() -> SharedMissing {
  {
    message: "",
    code: 0,
  }
}

pub fn SharedMissing::encode(self : SharedMissing, proto : &@thrift.Protocol) -> Unit {
  proto.write_struct_begin("SharedMissing")
  proto.write_field_begin(@thrift.type_string, 1)
  proto.write_string(self.message)
  proto.write_field_begin(@thrift.type_i32, 2)
  proto.write_i32(self.code)
  proto.write_field_stop()
  proto.write_struct_end()
}

pub fn SharedMissing::decode(proto : &@thrift.Protocol) -> SharedMissing raise @thrift.ThriftError {
  let mut message : String = ""
  let mut code : Int32 = 0
  proto.read_struct_begin()
  for ;; {
    let (field_type, field_id) = proto.read_field_begin()
    if field_type == @thrift.type_stop {
      break
    }
    match field_id {
      1 => message = proto.read_string()
      2 => code = proto.read_i32()
      _ => @thrift.skip(proto, field_type)
    }
  }
  proto.read_struct_end()
  { message, code, }
}

pub(all) struct Person {
  name : String
  age : Option[Int32]
  tags : Array[String]
  scores : Map[String, Int32]
  portrait : Bytes
  mood : Mood
  stamped : SharedStamp
}

pub fn Person::default() -> Person {
  {
    name: "",
    age: None,
    tags: ([] : Array[String]),
    scores: (Map([]) : Map[String, Int32]),
    portrait: b"",
    mood: Mood::Calm,
    stamped: SharedStamp::default(),
  }
}

pub fn Person::encode(self : Person, proto : &@thrift.Protocol) -> Unit {
  proto.write_struct_begin("Person")
  proto.write_field_begin(@thrift.type_string, 1)
  proto.write_string(self.name)
  match self.age {
    Some(value) => {
      proto.write_field_begin(@thrift.type_i32, 2)
      proto.write_i32(value)
    }
    None => ()
  }
  proto.write_field_begin(@thrift.type_list, 3)
  write_list_string(proto, self.tags)
  proto.write_field_begin(@thrift.type_map, 4)
  write_map_string_i32(proto, self.scores)
  proto.write_field_begin(@thrift.type_string, 5)
  proto.write_bytes(self.portrait)
  proto.write_field_begin(@thrift.type_i32, 6)
  proto.write_i32(self.mood.to_i32())
  proto.write_field_begin(@thrift.type_struct, 7)
  self.stamped.encode(proto)
  proto.write_field_stop()
  proto.write_struct_end()
}

pub fn Person::decode(proto : &@thrift.Protocol) -> Person raise @thrift.ThriftError {
  let mut name : String = ""
  let mut age : Option[Int32] = None
  let mut tags : Array[String] = ([] : Array[String])
  let mut scores : Map[String, Int32] = (Map([]) : Map[String, Int32])
  let mut portrait : Bytes = b""
  let mut mood : Mood = Mood::Calm
  let mut stamped : SharedStamp = SharedStamp::default()
  proto.read_struct_begin()
  for ;; {
    let (field_type, field_id) = proto.read_field_begin()
    if field_type == @thrift.type_stop {
      break
    }
    match field_id {
      1 => name = proto.read_string()
      2 => age = Some(proto.read_i32())
      3 => tags = read_list_string(proto)
      4 => scores = read_map_string_i32(proto)
      5 => portrait = proto.read_bytes()
      6 => mood = Mood::from_i32(proto.read_i32())
      7 => stamped = SharedStamp::decode(proto)
      _ => @thrift.skip(proto, field_type)
    }
  }
  proto.read_struct_end()
  { name, age, tags, scores, portrait, mood, stamped, }
}

pub fn write_list_string(proto : &@thrift.Protocol, value : Array[String]) -> Unit {
  proto.write_list_begin(@thrift.type_list, value.length())
  for item in value {
    proto.write_string(item)
  }
}

pub fn read_list_string(proto : &@thrift.Protocol) -> Array[String] raise @thrift.ThriftError {
  let (elem_type, size) = proto.read_list_begin()
  ignore(elem_type)
  let out : Array[String] = ([] : Array[String])
  for _ in 0..<size {
    out.push(proto.read_string())
  }
  out
}

pub fn write_map_string_i32(proto : &@thrift.Protocol, value : Map[String, Int32]) -> Unit {
  proto.write_map_begin(@thrift.type_string, @thrift.type_i32, value.length())
  for key, item in value {
    proto.write_string(key)
    proto.write_i32(item)
  }
}

pub fn read_map_string_i32(proto : &@thrift.Protocol) -> Map[String, Int32] raise @thrift.ThriftError {
  let (key_type, value_type, size) = proto.read_map_begin()
  ignore(key_type)
  ignore(value_type)
  let out : Map[String, Int32] = (Map([]) : Map[String, Int32])
  for _ in 0..<size {
    let key = proto.read_string()
    out[key] = proto.read_i32()
  }
  out
}

pub let maxAge : Int32 = 130

pub let tags : Array[String] = ["math", "music"]

pub let scores : Map[String, Int32] = Map([("math", 10), ("art", 7)])

pub let defaultMood : Mood = Mood::Calm

pub let ada : Person = { name: "Ada", age: Some(37), tags: ["math"], scores: Map([("math", 10)]), portrait: b"ab", mood: Mood::Happy, stamped: { at: 9L } }

/// The declared failures of `find`.
pub(all) enum GreeterFindError {
  SharedMissing(SharedMissing)
}

/// The declared failures of `shout`.
pub(all) enum GreeterShoutError {
  SharedMissing(SharedMissing)
}

pub fn register_greeter(
  processor : @thrift.Processor,
  hello : (Person) -> String,
  add : (Int32, Int32) -> Int32,
  notify : (String) -> Unit,
  find : (String) -> Result[String, GreeterFindError],
  shout : (String) -> Result[Unit, GreeterShoutError],
  ping : () -> String,
) -> Unit {
  processor.add("hello", proto => {
    let mut arg_who : Person = Person::default()
    for ;; {
      let (field_type, field_id) = proto.read_field_begin()
      if field_type == @thrift.type_stop {
        break
      }
      match field_id {
        1 => arg_who = Person::decode(proto)
        _ => @thrift.skip(proto, field_type)
      }
    }
    let result = hello(arg_who)
    proto.write_field_begin(@thrift.type_string, 0)
    proto.write_string(result)
  })
  processor.add("add", proto => {
    let mut arg_a : Int32 = 0
    let mut arg_b : Int32 = 0
    for ;; {
      let (field_type, field_id) = proto.read_field_begin()
      if field_type == @thrift.type_stop {
        break
      }
      match field_id {
        1 => arg_a = proto.read_i32()
        2 => arg_b = proto.read_i32()
        _ => @thrift.skip(proto, field_type)
      }
    }
    let result = add(arg_a, arg_b)
    proto.write_field_begin(@thrift.type_i32, 0)
    proto.write_i32(result)
  })
  processor.add("notify", proto => {
    let mut arg_text : String = ""
    for ;; {
      let (field_type, field_id) = proto.read_field_begin()
      if field_type == @thrift.type_stop {
        break
      }
      match field_id {
        1 => arg_text = proto.read_string()
        _ => @thrift.skip(proto, field_type)
      }
    }
    notify(arg_text)
  })
  processor.add("find", proto => {
    let mut arg_key : String = ""
    for ;; {
      let (field_type, field_id) = proto.read_field_begin()
      if field_type == @thrift.type_stop {
        break
      }
      match field_id {
        1 => arg_key = proto.read_string()
        _ => @thrift.skip(proto, field_type)
      }
    }
    match find(arg_key) {
      Ok(value) => {
        proto.write_field_begin(@thrift.type_string, 0)
        proto.write_string(value)
      }
      Err(SharedMissing(value)) => {
        proto.write_field_begin(@thrift.type_struct, 1)
        value.encode(proto)
      }
    }
  })
  processor.add("shout", proto => {
    let mut arg_text : String = ""
    for ;; {
      let (field_type, field_id) = proto.read_field_begin()
      if field_type == @thrift.type_stop {
        break
      }
      match field_id {
        1 => arg_text = proto.read_string()
        _ => @thrift.skip(proto, field_type)
      }
    }
    match shout(arg_text) {
      Ok(_) => ()
      Err(SharedMissing(value)) => {
        proto.write_field_begin(@thrift.type_struct, 1)
        value.encode(proto)
      }
    }
  })
  processor.add("ping", proto => {
    for ;; {
      let (field_type, _) = proto.read_field_begin()
      if field_type == @thrift.type_stop {
        break
      }
      @thrift.skip(proto, field_type)
    }
    let result = ping()
    proto.write_field_begin(@thrift.type_string, 0)
    proto.write_string(result)
  })
}

pub async fn[T : @thrift.Transport] greeter_hello(
  transport : T,
  proto : &@thrift.Protocol,
  who : Person,
) -> String raise @thrift.ThriftError {
  @thrift.call(transport, proto, "hello", 1, proto => {
    proto.write_field_begin(@thrift.type_struct, 1)
    who.encode(proto)
  }, proto => proto.read_string())
}

pub async fn[T : @thrift.Transport] greeter_add(
  transport : T,
  proto : &@thrift.Protocol,
  a : Int32,
  b : Int32,
) -> Int32 raise @thrift.ThriftError {
  @thrift.call(transport, proto, "add", 1, proto => {
    proto.write_field_begin(@thrift.type_i32, 1)
    proto.write_i32(a)
    proto.write_field_begin(@thrift.type_i32, 2)
    proto.write_i32(b)
  }, proto => proto.read_i32())
}

pub async fn[T : @thrift.Transport] greeter_notify(
  transport : T,
  proto : &@thrift.Protocol,
  text : String,
) -> Unit raise @thrift.ThriftError {
  @thrift.request(transport, proto, "notify", 1, proto => {
    proto.write_field_begin(@thrift.type_string, 1)
    proto.write_string(text)
  })
}

pub async fn[T : @thrift.Transport] greeter_find(
  transport : T,
  proto : &@thrift.Protocol,
  key : String,
) -> Result[String, GreeterFindError] raise @thrift.ThriftError {
  @thrift.call_result(transport, proto, "find", 1, proto => {
    proto.write_field_begin(@thrift.type_string, 1)
    proto.write_string(key)
  },
  proto => proto.read_string(),
  (proto, id) => {
    match id {
      1 => Some(SharedMissing(SharedMissing::decode(proto)))
      _ => None
    }
  })
}

pub async fn[T : @thrift.Transport] greeter_shout(
  transport : T,
  proto : &@thrift.Protocol,
  text : String,
) -> Result[Unit, GreeterShoutError] raise @thrift.ThriftError {
  @thrift.call_result_unit(transport, proto, "shout", 1, proto => {
    proto.write_field_begin(@thrift.type_string, 1)
    proto.write_string(text)
  },
  (proto, id) => {
    match id {
      1 => Some(SharedMissing(SharedMissing::decode(proto)))
      _ => None
    }
  })
}

pub async fn[T : @thrift.Transport] greeter_ping(
  transport : T,
  proto : &@thrift.Protocol,
) -> String raise @thrift.ThriftError {
  @thrift.call(transport, proto, "ping", 1, _ => (), proto => proto.read_string())
}

