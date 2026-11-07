// The proto3 JSON mapping, over a schema built by hand: the shapes the specification fixes,
// and the round trip that every transport speaks JSON through.

///|
fn json_test_schema() -> Schema {
  let mood : EnumDescriptor = {
    name: "Mood",
    values: [
      { name: "MOOD_CALM", number: 0, },
      { name: "MOOD_GLAD", number: 1, },
      { name: "MOOD_GRUMPY", number: 5, },
    ],
  }
  let inner = MessageDescriptor::new("Inner", [
    FieldDescriptor::new("value", 1, TypeInt32),
  ])
  // The entry message protoc makes for a `map<string, int64>`, nested in the message that
  // declares the map.
  let entry = MessageDescriptor::new(
    "ExtraEntry",
    [
      FieldDescriptor::new("key", 1, TypeString),
      FieldDescriptor::new("value", 2, TypeInt64),
    ],
    map_entry=true,
  )
  // `Profile` is the message every case below is about: one field of each shape a JSON
  // mapping has to get right.
  let profile = MessageDescriptor::new(
    "Profile",
    [
      FieldDescriptor::new("name", 1, TypeString),
      FieldDescriptor::new("age", 2, TypeInt32),
      FieldDescriptor::new("score", 3, TypeDouble),
      FieldDescriptor::new("id", 4, TypeInt64),
      FieldDescriptor::new("flag", 5, TypeBool),
      FieldDescriptor::new("data", 6, TypeBytes),
      FieldDescriptor::new("mood", 7, TypeEnum, type_name=".test.Mood"),
      FieldDescriptor::new("tags", 8, TypeString, label=LabelRepeated),
      FieldDescriptor::new("nums", 9, TypeInt32, label=LabelRepeated),
      FieldDescriptor::new(
        "extra",
        10,
        TypeMessage,
        label=LabelRepeated,
        type_name=".test.Profile.ExtraEntry",
      ),
      FieldDescriptor::new("inner", 11, TypeMessage, type_name=".test.Inner"),
      FieldDescriptor::new("nick", 12, TypeString),
    ],
    nested=[entry],
  )
  let file = FileDescriptor::new(
    "test.proto",
    "test",
    messages=[profile, inner],
    enums=[mood],
  )
  Schema::of([file])
}

///|
/// A `Profile` with every kind of field set, in wire form.
fn json_test_profile() -> Bytes {
  let w = PbWriter::new()
  w.string_(1, "Ada")
  w.int32(2, 37)
  w.double_(3, 1.5)
  w.int64(4, 9007199254740993L)
  w.bool_(5, true)
  w.bytes_(6, b"\x01\x02\xff")
  w.enum_(7, 1)
  w.string_(8, "a")
  w.string_(8, "b")
  // A packed run of repeated int32: what protoc writes by default.
  w.write_tag(9, LengthDelim)
  w.write_len_delim(b"\x01\x02\x03")
  // One map entry: "k" -> 42.
  let entry = PbWriter::new()
  entry.string_(1, "k")
  entry.int64(2, 42L)
  w.message_(10, entry.to_bytes())
  let inner = PbWriter::new()
  inner.int32(1, 7)
  w.message_(11, inner.to_bytes())
  w.string_(12, "nick")
  w.to_bytes()
}

///|
test "proto JSON: every shape of field maps as the specification says" {
  let schema = json_test_schema()
  let json = schema.to_json(".test.Profile", json_test_profile())
  let want : Map[String, Json] = Map([
    ("name", Json::string("Ada")),
    ("age", Json::number(37.0, repr="37")),
    ("score", Json::number(1.5)),
    // A 64-bit integer is a string: a JSON number is a double, and 2^53+1 is not one.
    ("id", Json::string("9007199254740993")),
    ("flag", Json::boolean(true)),
    ("data", Json::string("AQL/")),
    ("mood", Json::string("MOOD_GLAD")),
    ("tags", Json::array([Json::string("a"), Json::string("b")])),
    (
      "nums",
      Json::array([
        Json::number(1.0, repr="1"),
        Json::number(2.0, repr="2"),
        Json::number(3.0, repr="3"),
      ]),
    ),
    ("extra", Json::object(Map([("k", Json::string("42"))]))),
    ("inner", Json::object(Map([("value", Json::number(7.0, repr="7"))]))),
    ("nick", Json::string("nick")),
  ])
  assert_eq(json, Json::object(want))
}

///|
test "proto JSON: the wire bytes survive a trip through JSON" {
  let schema = json_test_schema()
  let bytes = json_test_profile()
  let json = schema.to_json(".test.Profile", bytes)
  let back = schema.to_bytes(".test.Profile", json)
  // The JSON writer drops a field that holds its zero value, so the comparison is of what
  // the bytes decode to, not of the bytes themselves.
  assert_eq(schema.to_json(".test.Profile", back), json)
}

///|
test "proto JSON: a field at its zero value is left out" {
  let schema = json_test_schema()
  let w = PbWriter::new()
  w.string_(1, "Bo")
  let json = schema.to_json(".test.Profile", w.to_bytes())
  assert_eq(json, Json::object(Map([("name", Json::string("Bo"))])))
}

///|
test "proto JSON: an unknown field number is skipped, not refused" {
  let schema = json_test_schema()
  let w = PbWriter::new()
  w.string_(1, "Ada")
  // Field 99 is not in the descriptor: a newer writer's field, which proto3 says to skip.
  w.string_(99, "later")
  let json = schema.to_json(".test.Profile", w.to_bytes())
  assert_eq(json, Json::object(Map([("name", Json::string("Ada"))])))
}

///|
test "proto JSON: null means absent, and an absent field stays absent" {
  let schema = json_test_schema()
  let json = Json::object(
    Map([("name", Json::string("Ada")), ("age", Json::null())]),
  )
  let bytes = schema.to_bytes(".test.Profile", json)
  // `null` and an absent field mean the same thing in proto3 JSON, so what comes back is the
  // one member that carried a value.
  assert_eq(
    schema.to_json(".test.Profile", bytes),
    Json::object(Map([("name", Json::string("Ada"))])),
  )
}

///|
test "proto JSON: a timestamp is an RFC 3339 string" {
  let stamp = MessageDescriptor::new("Timestamp", [
    FieldDescriptor::new("seconds", 1, TypeInt64),
    FieldDescriptor::new("nanos", 2, TypeInt32),
  ])
  let file = FileDescriptor::new(
    "google/protobuf/timestamp.proto",
    "google.protobuf",
    messages=[stamp],
  )
  let schema = Schema::of([file])
  let w = PbWriter::new()
  w.int64(1, 1_700_000_000L)
  w.int32(2, 500_000_000)
  assert_eq(
    schema.to_json(".google.protobuf.Timestamp", w.to_bytes()),
    Json::string("2023-11-14T22:13:20.500Z"),
  )
  // And back: the same seconds and nanos.
  let bytes = schema.to_bytes(
    ".google.protobuf.Timestamp",
    Json::string("2023-11-14T22:13:20.500Z"),
  )
  let reader = PbReader::new(bytes)
  let (first, first_wire) = reader.read_tag()
  assert_eq(first, 1)
  assert_eq(first_wire is Varint, true)
  assert_eq(reader.read_int64(), 1_700_000_000L)
  let (second, second_wire) = reader.read_tag()
  assert_eq(second, 2)
  assert_eq(second_wire is Varint, true)
  assert_eq(reader.read_int32(), 500_000_000)
}

///|
test "proto JSON: a duration ends in s, with as many digits as it needs" {
  let duration = MessageDescriptor::new("Duration", [
    FieldDescriptor::new("seconds", 1, TypeInt64),
    FieldDescriptor::new("nanos", 2, TypeInt32),
  ])
  let schema = Schema::of([
    FileDescriptor::new("google/protobuf/duration.proto", "google.protobuf", messages=[
      duration,
    ]),
  ])
  let w = PbWriter::new()
  w.int64(1, 3L)
  w.int32(2, 500_000_000)
  assert_eq(
    schema.to_json(".google.protobuf.Duration", w.to_bytes()),
    Json::string("3.5s"),
  )
  let empty = PbWriter::new()
  assert_eq(
    schema.to_json(".google.protobuf.Duration", empty.to_bytes()),
    Json::string("0s"),
  )
}

///|
test "proto JSON: a wrapper is the bare value it wraps" {
  let wrapper = MessageDescriptor::new("Int64Value", [
    FieldDescriptor::new("value", 1, TypeInt64),
  ])
  let schema = Schema::of([
    FileDescriptor::new("google/protobuf/wrappers.proto", "google.protobuf", messages=[
      wrapper,
    ]),
  ])
  let w = PbWriter::new()
  w.int64(1, -7L)
  assert_eq(
    schema.to_json(".google.protobuf.Int64Value", w.to_bytes()),
    Json::string("-7"),
  )
  assert_eq(
    schema.to_bytes(".google.protobuf.Int64Value", Json::string("-7")),
    w.to_bytes(),
  )
}

///|
test "proto JSON: a field mask is the comma-joined camelCase paths" {
  let mask = MessageDescriptor::new("FieldMask", [
    FieldDescriptor::new("paths", 1, TypeString, label=LabelRepeated),
  ])
  let schema = Schema::of([
    FileDescriptor::new("google/protobuf/field_mask.proto", "google.protobuf", messages=[
      mask,
    ]),
  ])
  let w = PbWriter::new()
  w.string_(1, "user.display_name")
  w.string_(1, "photo")
  assert_eq(
    schema.to_json(".google.protobuf.FieldMask", w.to_bytes()),
    Json::string("user.displayName,photo"),
  )
  assert_eq(
    schema.to_bytes(
      ".google.protobuf.FieldMask",
      Json::string("user.displayName,photo"),
    ),
    w.to_bytes(),
  )
}

///|
test "proto JSON: a nested message's field names are camelCase on both sides" {
  let inner = MessageDescriptor::new("Inner", [
    FieldDescriptor::new("some_value", 1, TypeInt32),
  ])
  let outer = MessageDescriptor::new("Outer", [
    FieldDescriptor::new("the_inner", 1, TypeMessage, type_name=".t.Inner"),
  ])
  let schema = Schema::of([
    FileDescriptor::new("t.proto", "t", messages=[outer, inner]),
  ])
  let w = PbWriter::new()
  let sub = PbWriter::new()
  sub.int32(1, 5)
  w.message_(1, sub.to_bytes())
  let json = schema.to_json(".t.Outer", w.to_bytes())
  assert_eq(
    json,
    Json::object(
      Map([
        (
          "theInner",
          Json::object(Map([("someValue", Json::number(5.0, repr="5"))])),
        ),
      ]),
    ),
  )
  // The proto spelling is accepted on the way in, as every implementation does.
  let bytes = schema.to_bytes(
    ".t.Outer",
    Json::object(Map([("the_inner", Json::object(Map([])))])),
  )
  assert_eq(bytes.length(), 2)
}

///|
test "proto JSON: an enum arrives by name and leaves by name" {
  let schema = json_test_schema()
  let bytes = schema.to_bytes(
    ".test.Profile",
    Json::object(Map([("mood", Json::string("MOOD_GRUMPY"))])),
  )
  let reader = PbReader::new(bytes)
  let (tag, wire) = reader.read_tag()
  assert_eq(tag, 7)
  assert_eq(wire is Varint, true)
  assert_eq(reader.read_int32(), 5)
}

///|
test "proto JSON: a double that JSON has no number for travels as a string" {
  let schema = json_test_schema()
  let w = PbWriter::new()
  w.double_(3, @double.infinity)
  assert_eq(
    schema.to_json(".test.Profile", w.to_bytes()),
    Json::object(Map([("score", Json::string("Infinity"))])),
  )
  let bytes = schema.to_bytes(
    ".test.Profile",
    Json::object(Map([("score", Json::string("NaN"))])),
  )
  let reader = PbReader::new(bytes)
  let (tag, wire) = reader.read_tag()
  assert_eq(tag, 3)
  assert_eq(wire is Fixed64, true)
  assert_eq(reader.read_double().is_nan(), true)
}
