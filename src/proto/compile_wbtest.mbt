// `.proto` source to descriptors, over the shapes a service definition actually uses: scalars and
// labels, nested messages, a map, a oneof, proto3 `optional`, and a name that refers to another
// file.

///|
/// The file a single source compiles to, so a test reads as the file it wrote.
fn compile_one(name : String, text : String) -> FileDescriptor raise {
  let files = compile_proto([(name, text)])
  assert_eq(files.length(), 1)
  files[0]
}

///|
/// The field numbered `number`, or a failure naming the field that is not there.
fn field(desc : MessageDescriptor, number : Int32) -> FieldDescriptor {
  for f in desc.fields {
    if f.number == number {
      return f
    }
  }
  abort("no field " + number.to_string() + " in " + desc.name)
}

///|
test "proto compile: a file's shapes survive into the descriptor model" {
  let file = compile_one(
    "echo.proto",
    (
      #|syntax = "proto3";
      #|package echo.v1;
      #|message Ping {
      #|  string text = 1;
      #|  int64 seq = 2;
      #|  repeated int32 nums = 3;
      #|}
      #|enum Mood {
      #|  MOOD_CALM = 0;
      #|  MOOD_GLAD = 1;
      #|}
      #|service Echo {
      #|  rpc Say(Ping) returns (Ping);
      #|  rpc Watch(Ping) returns (stream Ping);
      #|}
    ),
  )
  assert_eq(file.name, "echo.proto")
  assert_eq(file.package_, "echo.v1")
  assert_eq(file.syntax, "proto3")
  assert_eq(file.messages.length(), 1)
  let ping = file.messages[0]
  assert_eq(ping.name, "Ping")
  assert_eq(ping.fields.length(), 3)
  assert_true(field(ping, 1).type_ is TypeString)
  assert_true(field(ping, 2).type_ is TypeInt64)
  assert_true(field(ping, 3).type_ is TypeInt32)
  assert_true(field(ping, 3).label is LabelRepeated)
  assert_true(field(ping, 1).label is LabelOptional)
  assert_eq(file.enums.length(), 1)
  assert_eq(file.enums[0].name, "Mood")
  assert_eq(file.enums[0].values.length(), 2)
  assert_eq(file.enums[0].values[1].number, 1)
  assert_eq(file.services.length(), 1)
  let echo = file.services[0]
  assert_eq(echo.name, "Echo")
  assert_eq(echo.methods.length(), 2)
  assert_eq(echo.methods[0].name, "Say")
  assert_eq(echo.methods[0].input_type, ".echo.v1.Ping")
  assert_eq(echo.methods[0].server_streaming, false)
  assert_eq(echo.methods[1].server_streaming, true)
}

///|
test "proto compile: a nested name resolves to the type it stands in" {
  let file = compile_one(
    "nested.proto",
    (
      #|syntax = "proto3";
      #|package deep.v1;
      #|message Outer {
      #|  message Inner { int32 value = 1; }
      #|  Inner inner = 1;
      #|  Inner other = 2;
      #|}
    ),
  )
  let outer = file.messages[0]
  assert_eq(outer.nested.length(), 1)
  assert_eq(outer.nested[0].name, "Inner")
  // `Inner` is written relative to `Outer`, and the model keeps the absolute spelling.
  assert_eq(field(outer, 1).type_name, ".deep.v1.Outer.Inner")
  assert_true(field(outer, 1).type_ is TypeMessage)
}

///|
test "proto compile: a map becomes the entry message protoc would make" {
  let file = compile_one(
    "map.proto",
    (
      #|syntax = "proto3";
      #|package counts.v1;
      #|message Tally {
      #|  map<string, int64> counts = 1;
      #|}
    ),
  )
  let tally = file.messages[0]
  assert_eq(tally.nested.length(), 1)
  let entry = tally.nested[0]
  assert_eq(entry.name, "CountsEntry")
  assert_eq(entry.map_entry, true)
  assert_eq(entry.fields.length(), 2)
  assert_true(field(entry, 1).type_ is TypeString)
  assert_true(field(entry, 2).type_ is TypeInt64)
  let counts = field(tally, 1)
  assert_true(counts.label is LabelRepeated)
  assert_true(counts.type_ is TypeMessage)
  assert_eq(counts.type_name, ".counts.v1.Tally.CountsEntry")
}

///|
test "proto compile: a oneof is named, and proto3 optional sits in a synthetic one" {
  let file = compile_one(
    "oneof.proto",
    (
      #|syntax = "proto3";
      #|package pick.v1;
      #|message Choice {
      #|  oneof pick {
      #|    string name = 1;
      #|    int32 number = 2;
      #|  }
      #|  optional string nickname = 3;
      #|}
    ),
  )
  let choice = file.messages[0]
  // The declared oneof, then the synthetic one `optional` needs, which is what protoc writes.
  assert_eq(choice.oneofs.length(), 2)
  assert_eq(choice.oneofs[0], "pick")
  assert_eq(field(choice, 1).oneof_index, Some(0))
  assert_eq(field(choice, 2).oneof_index, Some(0))
  assert_eq(field(choice, 3).proto3_optional, true)
  assert_eq(field(choice, 3).oneof_index, Some(1))
}

///|
test "proto compile: a name from another file resolves to that file's type" {
  let files = compile_proto([
    (
      "shared.proto",
      (
        #|syntax = "proto3";
        #|package shared.v1;
        #|message Data { string value = 1; }
      ),
    ),
    (
      "app.proto",
      (
        #|syntax = "proto3";
        #|package app.v1;
        #|import "shared.proto";
        #|message Use {
        #|  shared.v1.Data data = 1;
        #|}
      ),
    ),
  ])
  assert_eq(files.length(), 2)
  // The second file refers to the first, and the reference is absolute whatever order the files
  // were given in.
  let user = files[1].messages[0]
  assert_eq(field(user, 1).type_name, ".shared.v1.Data")
  assert_eq(files[1].dependencies, ["shared.proto"])
}

///|
test "proto compile: a well-known type keeps its absolute name" {
  let file = compile_one(
    "any.proto",
    (
      #|syntax = "proto3";
      #|package carry.v1;
      #|import "google/protobuf/any.proto";
      #|message Carrier {
      #|  google.protobuf.Any payload = 1;
      #|}
    ),
  )
  let carrier = file.messages[0]
  // The imported file was not passed in, so nothing declares this name; it is kept as written,
  // anchored to its own package rather than to the file that refers to it.
  assert_eq(field(carrier, 1).type_name, ".google.protobuf.Any")
}

///|
test "proto compile: a compiled schema carries a message as JSON" {
  let schema = Schema::compile([
    (
      "profile.proto",
      (
        #|syntax = "proto3";
        #|package people.v1;
        #|message Profile {
        #|  string display_name = 1;
        #|  int64 id = 2;
        #|  repeated string tags = 3;
        #|}
      ),
    ),
  ])
  let wire = Schema::to_bytes(
    schema,
    ".people.v1.Profile",
    Json::object(
      Map([
        ("displayName", Json::string("Ada")),
        ("id", Json::string("42")),
        ("tags", Json::array([Json::string("math"), Json::string("code")])),
      ]),
    ),
  ) catch {
    e => fail("to_bytes: " + e.to_string())
  }
  // The bytes are what the compiled field numbers say they are: 1, 2 and 3, in that order.
  assert_eq(wire.length() > 0, true)
  let back = Schema::to_json(schema, ".people.v1.Profile", wire) catch {
    e => fail("to_json: " + e.to_string())
  }
  assert_eq(
    back,
    Json::object(
      Map([
        ("displayName", Json::string("Ada")),
        ("id", Json::string("42")),
        ("tags", Json::array([Json::string("math"), Json::string("code")])),
      ]),
    ),
  )
}

///|
test "proto compile: a source that does not parse is refused, not guessed at" {
  let refused = try {
    ignore(compile_proto([("broken.proto", "message { }")]))
    false
  } catch {
    BadSchema(_) => true
    _ => false
  }
  assert_true(refused)
}

///|
test "proto compile: a field whose type is an enum is an enum, not a message" {
  let file = compile_one(
    "level.proto",
    (
      #|syntax = "proto3";
      #|package level.v1;
      #|enum Level {
      #|  LEVEL_LOW = 0;
      #|  LEVEL_HIGH = 2;
      #|}
      #|message Alarm { Level level = 1; }
    ),
  )
  let alarm = file.messages[0]
  // The parser reports a named type without saying which kind it is, and a value written as a
  // message where the field is an enum is dropped rather than encoded.
  assert_true(field(alarm, 1).type_ is TypeEnum)
  assert_eq(field(alarm, 1).type_name, ".level.v1.Level")
  let schema = Schema::compile([
    (
      "level.proto",
      (
        #|syntax = "proto3";
        #|package level.v1;
        #|enum Level {
        #|  LEVEL_LOW = 0;
        #|  LEVEL_HIGH = 2;
        #|}
        #|message Alarm { Level level = 1; }
      ),
    ),
  ]) catch {
    e => abort(e.to_string())
  }
  let wire = Schema::to_bytes(
    schema,
    ".level.v1.Alarm",
    Json::object(Map([("level", Json::string("LEVEL_HIGH"))])),
  ) catch {
    e => abort(e.to_string())
  }
  // Field 1, varint, value 2.
  assert_eq(wire.length(), 2)
  assert_eq(wire[0], b'\x08')
  assert_eq(wire[1], b'\x02')
}
