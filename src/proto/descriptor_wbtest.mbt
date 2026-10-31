// Tests for the descriptor model: a hand-built service descriptor round-trips
// through the `FileDescriptorProto` / `FileDescriptorSet` wire format, the derived
// symbol and service-name sets are right, and corrupting the encoded bytes is
// caught on decode.

///|
/// The descriptor of a `greet` service with one unary method and its two messages,
/// reused across the descriptor and reflection tests.
fn greet_file() -> FileDescriptor {
  let request = MessageDescriptor::new("HelloRequest", [
    FieldDescriptor::new("name", 1, TypeString),
  ])
  let reply = MessageDescriptor::new("HelloReply", [
    FieldDescriptor::new("message", 1, TypeString),
  ])
  let greeter = ServiceDescriptor::{
    name: "Greeter",
    methods: [
      MethodDescriptor::{
        name: "SayHello",
        input_type: ".greet.HelloRequest",
        output_type: ".greet.HelloReply",
        client_streaming: false,
        server_streaming: false,
      },
    ],
  }
  FileDescriptor::new("greet.proto", "greet", messages=[request, reply], services=[
    greeter,
  ])
}

///|
test "FieldType / FieldLabel codes match descriptor.proto" {
  assert_eq(TypeDouble.code(), 1)
  assert_eq(TypeInt32.code(), 5)
  assert_eq(TypeString.code(), 9)
  assert_eq(TypeMessage.code(), 11)
  assert_eq(TypeBytes.code(), 12)
  assert_eq(TypeSint64.code(), 18)
  assert_eq(FieldType::of(9) == TypeString, true)
  assert_eq(FieldType::of(11) == TypeMessage, true)
  // the removed group type 10 (and any unknown) falls back to TypeMessage.
  assert_eq(FieldType::of(10) == TypeMessage, true)
  assert_eq(LabelRepeated.code(), 3)
  assert_eq(FieldLabel::of(3) == LabelRepeated, true)
  assert_eq(FieldLabel::of(1) == LabelOptional, true)
}

///|
test "FieldDescriptor encodes and decodes, type_name only when composite" {
  let scalar = FieldDescriptor::new("name", 1, TypeString)
  assert_eq(FieldDescriptor::decode(scalar.encode()) == scalar, true)
  let msg = FieldDescriptor::new(
    "author",
    2,
    TypeMessage,
    type_name=".greet.Person",
  )
  let back = FieldDescriptor::decode(msg.encode())
  assert_eq(back == msg, true)
  assert_eq(back.type_name == ".greet.Person", true)
  // a scalar carries no type_name field on the wire.
  assert_eq(scalar.type_name == "", true)
}

///|
test "MethodDescriptor: streaming flags survive the round-trip" {
  let bidi = MethodDescriptor::{
    name: "Chat",
    input_type: ".chat.Msg",
    output_type: ".chat.Msg",
    client_streaming: true,
    server_streaming: true,
  }
  assert_eq(MethodDescriptor::decode(bidi.encode()) == bidi, true)
}

///|
test "FileDescriptor: a full service round-trips deeply" {
  let file = greet_file()
  let back = FileDescriptor::decode(file.encode())
  assert_eq(back == file, true)
  assert_eq(back.syntax == "proto3", true)
  assert_eq(back.services[0].methods[0].name == "SayHello", true)
  assert_eq(back.messages.length(), 2)
}

///|
test "FileDescriptor: symbols and service names" {
  let file = greet_file()
  let syms = file.symbols()
  // package-qualified: one service, its method, two messages.
  assert_eq(syms.contains("greet.Greeter"), true)
  assert_eq(syms.contains("greet.Greeter.SayHello"), true)
  assert_eq(syms.contains("greet.HelloRequest"), true)
  assert_eq(syms.contains("greet.HelloReply"), true)
  let names = file.service_names()
  assert_eq(names.length(), 1)
  assert_eq(names[0] == "greet.Greeter", true)
}

///|
test "FileDescriptorSet: multiple files round-trip" {
  let a = greet_file()
  let b = FileDescriptor::new("health.proto", "grpc.health.v1", services=[
    ServiceDescriptor::{ name: "Health", methods: [], },
  ])
  let set = encode_file_descriptor_set([a, b])
  let back = decode_file_descriptor_set(set)
  assert_eq(back.length(), 2)
  assert_eq(back[0] == a, true)
  assert_eq(back[1] == b, true)
}

///|
test "MUTATION: corrupting a length prefix in an encoded file is caught on decode" {
  let file = greet_file()
  let good = file.encode()
  // the file's first field is `name` (tag 0x0A at index 0, length at index 1).
  // inflate that length past the buffer -> the decoder must reject it.
  assert_eq(good[0].to_int(), 0x0A)
  let corrupt = good.to_array()
  corrupt[1] = (0x7F).to_byte()
  let bad = Bytes::from_array(corrupt)
  let raised = try {
    let _ = FileDescriptor::decode(bad)
    false
  } catch {
    _ => true
  }
  assert_eq(raised, true)
  // with the prefix restored, the same bytes decode cleanly again.
  assert_eq(FileDescriptor::decode(good) == file, true)
}

///|
/// A file using every part of the model: an enum at the top and one nested in
/// a message, a nested message, a `map` field with its entry type, a proto3
/// `optional` field with its synthetic oneof, and a bidirectional method.
fn shelf_file() -> FileDescriptor {
  let state = EnumDescriptor::{
    name: "State",
    values: [
      { name: "STATE_DRAFT", number: 0, },
      { name: "STATE_DONE", number: 1, },
    ],
  }
  let entry = MessageDescriptor::new(
    "CountsEntry",
    [
      FieldDescriptor::new("key", 1, TypeString),
      FieldDescriptor::new("value", 2, TypeInt64),
    ],
    map_entry=true,
  )
  let page = MessageDescriptor::new("Page", [
    FieldDescriptor::new("number", 1, TypeUint32),
  ])
  let kind = EnumDescriptor::{
    name: "Kind",
    values: [
      { name: "KIND_BOOK", number: 0, },
      { name: "KIND_ZINE", number: 7, },
    ],
  }
  let book = MessageDescriptor::new(
    "Book",
    [
      FieldDescriptor::new("title", 1, TypeString),
      FieldDescriptor::new("state", 2, TypeEnum, type_name=".shelf.State"),
      FieldDescriptor::new(
        "counts",
        3,
        TypeMessage,
        label=LabelRepeated,
        type_name=".shelf.Book.CountsEntry",
      ),
      FieldDescriptor::new(
        "subtitle",
        4,
        TypeString,
        oneof_index=0,
        proto3_optional=true,
      ),
      FieldDescriptor::new(
        "pages",
        5,
        TypeMessage,
        label=LabelRepeated,
        type_name=".shelf.Book.Page",
      ),
      FieldDescriptor::new("kind", 6, TypeEnum, type_name=".shelf.Book.Kind"),
    ],
    nested=[entry, page],
    enums=[kind],
    oneofs=["_subtitle"],
  )
  FileDescriptor::new(
    "shelf.proto",
    "shelf",
    dependencies=["google/protobuf/empty.proto"],
    messages=[book],
    enums=[state],
    services=[
      {
        name: "Library",
        methods: [
          {
            name: "Trade",
            input_type: ".shelf.Book",
            output_type: ".shelf.Book",
            client_streaming: true,
            server_streaming: true,
          },
        ],
      },
    ],
  )
}

///|
test "enums, nested types, map entries and oneofs round-trip" {
  let file = shelf_file()
  let back = FileDescriptor::decode(file.encode())
  assert_eq(back == file, true)
  assert_eq(back.messages[0].nested[0].map_entry, true)
  assert_eq(back.messages[0].fields[3].oneof_index, Some(0))
  assert_eq(back.messages[0].fields[3].proto3_optional, true)
  assert_eq(back.enums[0].values[1].number, 1)
  assert_eq(back.dependencies, ["google/protobuf/empty.proto"])
  // an enum value of 0 and a oneof index of 0 are written, not left out.
  let zero = EnumValueDescriptor::{ name: "Z", number: 0, }
  assert_eq(EnumValueDescriptor::decode(zero.encode()) == zero, true)
}

///|
test "symbols reach nested messages, nested enums, top-level enums and methods" {
  let syms = shelf_file().symbols()
  assert_eq(syms, [
    "shelf.Library", "shelf.Library.Trade", "shelf.Book", "shelf.Book.Kind", "shelf.Book.CountsEntry",
    "shelf.Book.Page", "shelf.State",
  ])
}

///|
test "source writes the .proto the model describes" {
  inspect(
    shelf_file().source(),
    content=(
      #|syntax = "proto3";
      #|
      #|package shelf;
      #|
      #|import "google/protobuf/empty.proto";
      #|
      #|message Book {
      #|  string title = 1;
      #|  .shelf.State state = 2;
      #|  map<string, int64> counts = 3;
      #|  optional string subtitle = 4;
      #|  repeated .shelf.Book.Page pages = 5;
      #|  .shelf.Book.Kind kind = 6;
      #|  message Page {
      #|    uint32 number = 1;
      #|  }
      #|  enum Kind {
      #|    KIND_BOOK = 0;
      #|    KIND_ZINE = 7;
      #|  }
      #|}
      #|
      #|enum State {
      #|  STATE_DRAFT = 0;
      #|  STATE_DONE = 1;
      #|}
      #|
      #|service Library {
      #|  rpc Trade(stream .shelf.Book) returns (stream .shelf.Book);
      #|}
      #|
    ),
  )
}

///|
test "source groups a real oneof and writes proto2 labels" {
  let pick = MessageDescriptor::new(
    "Pick",
    [
      FieldDescriptor::new("id", 1, TypeInt64, label=LabelRequired),
      FieldDescriptor::new("name", 2, TypeString, oneof_index=0),
      FieldDescriptor::new("code", 3, TypeInt32, oneof_index=0),
      FieldDescriptor::new("note", 4, TypeString),
    ],
    oneofs=["by"],
  )
  let file = {
    ..FileDescriptor::new("pick.proto", "", messages=[pick]),
    syntax: "",
  }
  inspect(
    file.source(),
    content=(
      #|syntax = "proto2";
      #|
      #|message Pick {
      #|  required int64 id = 1;
      #|  oneof by {
      #|    string name = 2;
      #|    int32 code = 3;
      #|  }
      #|  optional string note = 4;
      #|}
      #|
    ),
  )
}
