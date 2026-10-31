// A descriptor model for gRPC services and their messages, and the codec that
// turns it into the `FileDescriptorProto` / `FileDescriptorSet` wire bytes of
// `google/protobuf/descriptor.proto`. This is what Server Reflection hands a
// client so `grpcurl` can `list` and `describe` a service: reflection returns the
// serialised `FileDescriptorProto` of the file that defines a symbol. The model
// carries packages, imports, messages with their nested messages, enums, oneofs
// and map entries, and services with their methods; options other than
// `map_entry`, extensions, `json_name` and source info are skipped on decode, so
// a `protoc` set that uses them re-encodes to the modelled subset. Field numbers
// below are the ones fixed by descriptor.proto.

///|
/// The `FieldDescriptorProto.Type` enum (proto3's scalar and composite field
/// types). `TypeGroup` is intentionally absent — groups are removed from proto3.
pub(all) enum FieldType {
  TypeDouble
  TypeFloat
  TypeInt64
  TypeUint64
  TypeInt32
  TypeFixed64
  TypeFixed32
  TypeBool
  TypeString
  TypeMessage
  TypeBytes
  TypeUint32
  TypeEnum
  TypeSfixed32
  TypeSfixed64
  TypeSint32
  TypeSint64
} derive(Eq)

///|
/// The descriptor.proto enum number of a field type.
pub fn FieldType::code(self : FieldType) -> Int32 {
  match self {
    TypeDouble => 1
    TypeFloat => 2
    TypeInt64 => 3
    TypeUint64 => 4
    TypeInt32 => 5
    TypeFixed64 => 6
    TypeFixed32 => 7
    TypeBool => 8
    TypeString => 9
    TypeMessage => 11
    TypeBytes => 12
    TypeUint32 => 13
    TypeEnum => 14
    TypeSfixed32 => 15
    TypeSfixed64 => 16
    TypeSint32 => 17
    TypeSint64 => 18
  }
}

///|
/// The field type for a descriptor.proto enum number; an unrecognised number
/// (including the removed group type `10`) reads as `TypeMessage`.
pub fn FieldType::of(n : Int32) -> FieldType {
  match n {
    1 => TypeDouble
    2 => TypeFloat
    3 => TypeInt64
    4 => TypeUint64
    5 => TypeInt32
    6 => TypeFixed64
    7 => TypeFixed32
    8 => TypeBool
    9 => TypeString
    12 => TypeBytes
    13 => TypeUint32
    14 => TypeEnum
    15 => TypeSfixed32
    16 => TypeSfixed64
    17 => TypeSint32
    18 => TypeSint64
    _ => TypeMessage
  }
}

///|
/// The type's name in `.proto` source, for the scalars; `None` for a message or
/// an enum, which are written by name.
pub fn FieldType::keyword(self : FieldType) -> String? {
  match self {
    TypeDouble => Some("double")
    TypeFloat => Some("float")
    TypeInt64 => Some("int64")
    TypeUint64 => Some("uint64")
    TypeInt32 => Some("int32")
    TypeFixed64 => Some("fixed64")
    TypeFixed32 => Some("fixed32")
    TypeBool => Some("bool")
    TypeString => Some("string")
    TypeBytes => Some("bytes")
    TypeUint32 => Some("uint32")
    TypeSfixed32 => Some("sfixed32")
    TypeSfixed64 => Some("sfixed64")
    TypeSint32 => Some("sint32")
    TypeSint64 => Some("sint64")
    TypeMessage | TypeEnum => None
  }
}

///|
/// The `FieldDescriptorProto.Label`: proto3 fields are `LabelOptional` unless
/// `repeated`.
pub(all) enum FieldLabel {
  LabelOptional
  LabelRequired
  LabelRepeated
} derive(Eq)

///|
/// The descriptor.proto enum number of a label.
pub fn FieldLabel::code(self : FieldLabel) -> Int32 {
  match self {
    LabelOptional => 1
    LabelRequired => 2
    LabelRepeated => 3
  }
}

///|
/// The label for a descriptor.proto enum number; anything else reads as
/// `LabelOptional`.
pub fn FieldLabel::of(n : Int32) -> FieldLabel {
  match n {
    2 => LabelRequired
    3 => LabelRepeated
    _ => LabelOptional
  }
}

///|
/// One field of a message (`FieldDescriptorProto`). `type_name` is the
/// fully-qualified name of the referenced message or enum for `TypeMessage` /
/// `TypeEnum`, and empty for scalars. `oneof_index` places the field in one of
/// its message's `oneofs`; a proto3 `optional` field sits alone in a synthetic
/// one and sets `proto3_optional`.
pub(all) struct FieldDescriptor {
  name : String
  number : Int32
  label : FieldLabel
  type_ : FieldType
  type_name : String
  oneof_index : Int32?
  proto3_optional : Bool
} derive(Eq)

///|
pub fn FieldDescriptor::new(
  name : String,
  number : Int32,
  type_ : FieldType,
  label~ : FieldLabel = LabelOptional,
  type_name~ : String = "",
  oneof_index? : Int32,
  proto3_optional~ : Bool = false,
) -> FieldDescriptor {
  { name, number, label, type_, type_name, oneof_index, proto3_optional, }
}

///|
/// Encode a `FieldDescriptorProto`.
pub fn FieldDescriptor::encode(self : FieldDescriptor) -> Bytes {
  let w = PbWriter::new()
  w.string_(1, self.name)
  w.int32(3, self.number)
  w.enum_(4, self.label.code())
  w.enum_(5, self.type_.code())
  if self.type_name.length() > 0 {
    w.string_(6, self.type_name)
  }
  if self.oneof_index is Some(i) {
    w.int32(9, i)
  }
  if self.proto3_optional {
    w.bool_(17, true)
  }
  w.to_bytes()
}

///|
/// Decode a `FieldDescriptorProto`.
pub fn FieldDescriptor::decode(body : Bytes) -> FieldDescriptor raise PbError {
  let r = PbReader::new(body)
  let mut name = ""
  let mut number = 0
  let mut label = LabelOptional
  let mut type_ = TypeMessage
  let mut type_name = ""
  let mut oneof_index = None
  let mut proto3_optional = false
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => name = r.read_string()
      (3, Varint) => number = r.read_int32()
      (4, Varint) => label = FieldLabel::of(r.read_int32())
      (5, Varint) => type_ = FieldType::of(r.read_int32())
      (6, LengthDelim) => type_name = r.read_string()
      (9, Varint) => oneof_index = Some(r.read_int32())
      (17, Varint) => proto3_optional = r.read_bool()
      (_, w) => r.skip(w)
    }
  }
  { name, number, label, type_, type_name, oneof_index, proto3_optional, }
}

///|
/// One value of an enum (`EnumValueDescriptorProto`).
pub(all) struct EnumValueDescriptor {
  name : String
  number : Int32
} derive(Eq)

///|
/// Encode an `EnumValueDescriptorProto`.
pub fn EnumValueDescriptor::encode(self : EnumValueDescriptor) -> Bytes {
  let w = PbWriter::new()
  w.string_(1, self.name)
  w.int32(2, self.number)
  w.to_bytes()
}

///|
/// Decode an `EnumValueDescriptorProto`.
pub fn EnumValueDescriptor::decode(
  body : Bytes,
) -> EnumValueDescriptor raise PbError {
  let r = PbReader::new(body)
  let mut name = ""
  let mut number = 0
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => name = r.read_string()
      (2, Varint) => number = r.read_int32()
      (_, w) => r.skip(w)
    }
  }
  { name, number, }
}

///|
/// An enum type (`EnumDescriptorProto`): its simple name and its values.
pub(all) struct EnumDescriptor {
  name : String
  values : Array[EnumValueDescriptor]
} derive(Eq)

///|
/// Encode an `EnumDescriptorProto`.
pub fn EnumDescriptor::encode(self : EnumDescriptor) -> Bytes {
  let w = PbWriter::new()
  w.string_(1, self.name)
  for v in self.values {
    w.message_(2, v.encode())
  }
  w.to_bytes()
}

///|
/// Decode an `EnumDescriptorProto`.
pub fn EnumDescriptor::decode(body : Bytes) -> EnumDescriptor raise PbError {
  let r = PbReader::new(body)
  let mut name = ""
  let values = []
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => name = r.read_string()
      (2, LengthDelim) =>
        values.push(EnumValueDescriptor::decode(r.read_bytes()))
      (_, w) => r.skip(w)
    }
  }
  { name, values, }
}

///|
/// A message type (`DescriptorProto`): its simple name, its fields, the
/// messages and enums declared inside it, the names of its oneofs, and whether
/// it is the entry type protoc makes for a `map` field.
pub(all) struct MessageDescriptor {
  name : String
  fields : Array[FieldDescriptor]
  nested : Array[MessageDescriptor]
  enums : Array[EnumDescriptor]
  oneofs : Array[String]
  map_entry : Bool
} derive(Eq)

///|
pub fn MessageDescriptor::new(
  name : String,
  fields : Array[FieldDescriptor],
  nested~ : Array[MessageDescriptor] = [],
  enums~ : Array[EnumDescriptor] = [],
  oneofs~ : Array[String] = [],
  map_entry~ : Bool = false,
) -> MessageDescriptor {
  { name, fields, nested, enums, oneofs, map_entry, }
}

///|
/// Encode a `DescriptorProto`.
pub fn MessageDescriptor::encode(self : MessageDescriptor) -> Bytes {
  let w = PbWriter::new()
  w.string_(1, self.name)
  for f in self.fields {
    w.message_(2, f.encode())
  }
  for m in self.nested {
    w.message_(3, m.encode())
  }
  for e in self.enums {
    w.message_(4, e.encode())
  }
  if self.map_entry {
    let options = PbWriter::new()
    options.bool_(7, true)
    w.message_(7, options.to_bytes())
  }
  for o in self.oneofs {
    let oneof = PbWriter::new()
    oneof.string_(1, o)
    w.message_(8, oneof.to_bytes())
  }
  w.to_bytes()
}

///|
/// Decode a `DescriptorProto`.
pub fn MessageDescriptor::decode(
  body : Bytes,
) -> MessageDescriptor raise PbError {
  let r = PbReader::new(body)
  let mut name = ""
  let fields = []
  let nested = []
  let enums = []
  let oneofs = []
  let mut map_entry = false
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => name = r.read_string()
      (2, LengthDelim) => fields.push(FieldDescriptor::decode(r.read_bytes()))
      (3, LengthDelim) => nested.push(MessageDescriptor::decode(r.read_bytes()))
      (4, LengthDelim) => enums.push(EnumDescriptor::decode(r.read_bytes()))
      (7, LengthDelim) => {
        let options = PbReader::new(r.read_bytes())
        while !options.eof() {
          match options.read_tag() {
            (7, Varint) => map_entry = options.read_bool()
            (_, w) => options.skip(w)
          }
        }
      }
      (8, LengthDelim) => {
        let oneof = PbReader::new(r.read_bytes())
        let mut oneof_name = ""
        while !oneof.eof() {
          match oneof.read_tag() {
            (1, LengthDelim) => oneof_name = oneof.read_string()
            (_, w) => oneof.skip(w)
          }
        }
        oneofs.push(oneof_name)
      }
      (_, w) => r.skip(w)
    }
  }
  { name, fields, nested, enums, oneofs, map_entry, }
}

///|
/// One RPC method (`MethodDescriptorProto`): its name, the fully-qualified request
/// and response message names, and the two streaming flags that together pick the
/// call cardinality.
pub(all) struct MethodDescriptor {
  name : String
  input_type : String
  output_type : String
  client_streaming : Bool
  server_streaming : Bool
} derive(Eq)

///|
/// Encode a `MethodDescriptorProto`.
pub fn MethodDescriptor::encode(self : MethodDescriptor) -> Bytes {
  let w = PbWriter::new()
  w.string_(1, self.name)
  w.string_(2, self.input_type)
  w.string_(3, self.output_type)
  if self.client_streaming {
    w.bool_(5, true)
  }
  if self.server_streaming {
    w.bool_(6, true)
  }
  w.to_bytes()
}

///|
/// Decode a `MethodDescriptorProto`.
pub fn MethodDescriptor::decode(body : Bytes) -> MethodDescriptor raise PbError {
  let r = PbReader::new(body)
  let mut name = ""
  let mut input_type = ""
  let mut output_type = ""
  let mut client_streaming = false
  let mut server_streaming = false
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => name = r.read_string()
      (2, LengthDelim) => input_type = r.read_string()
      (3, LengthDelim) => output_type = r.read_string()
      (5, Varint) => client_streaming = r.read_bool()
      (6, Varint) => server_streaming = r.read_bool()
      (_, w) => r.skip(w)
    }
  }
  { name, input_type, output_type, client_streaming, server_streaming, }
}

///|
/// A service (`ServiceDescriptorProto`): its (simple) name and its methods.
pub(all) struct ServiceDescriptor {
  name : String
  methods : Array[MethodDescriptor]
} derive(Eq)

///|
/// Encode a `ServiceDescriptorProto`.
pub fn ServiceDescriptor::encode(self : ServiceDescriptor) -> Bytes {
  let w = PbWriter::new()
  w.string_(1, self.name)
  for m in self.methods {
    w.message_(2, m.encode())
  }
  w.to_bytes()
}

///|
/// Decode a `ServiceDescriptorProto`.
pub fn ServiceDescriptor::decode(
  body : Bytes,
) -> ServiceDescriptor raise PbError {
  let r = PbReader::new(body)
  let mut name = ""
  let methods : Array[MethodDescriptor] = []
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => name = r.read_string()
      (2, LengthDelim) => methods.push(MethodDescriptor::decode(r.read_bytes()))
      (_, w) => r.skip(w)
    }
  }
  { name, methods, }
}

///|
/// A single `.proto` file (`FileDescriptorProto`): its filename, package, the
/// files it imports, the messages, enums and services it defines, and the
/// syntax level. This is the unit Server Reflection returns.
pub(all) struct FileDescriptor {
  name : String
  package_ : String
  dependencies : Array[String]
  messages : Array[MessageDescriptor]
  enums : Array[EnumDescriptor]
  services : Array[ServiceDescriptor]
  syntax : String
} derive(Eq)

///|
/// A proto3 file with the given filename and package.
pub fn FileDescriptor::new(
  name : String,
  package_ : String,
  dependencies~ : Array[String] = [],
  messages~ : Array[MessageDescriptor] = [],
  enums~ : Array[EnumDescriptor] = [],
  services~ : Array[ServiceDescriptor] = [],
) -> FileDescriptor {
  { name, package_, dependencies, messages, enums, services, syntax: "proto3", }
}

///|
/// Encode a `FileDescriptorProto`.
pub fn FileDescriptor::encode(self : FileDescriptor) -> Bytes {
  let w = PbWriter::new()
  w.string_(1, self.name)
  if self.package_.length() > 0 {
    w.string_(2, self.package_)
  }
  for d in self.dependencies {
    w.string_(3, d)
  }
  for m in self.messages {
    w.message_(4, m.encode())
  }
  for e in self.enums {
    w.message_(5, e.encode())
  }
  for s in self.services {
    w.message_(6, s.encode())
  }
  if self.syntax.length() > 0 {
    w.string_(12, self.syntax)
  }
  w.to_bytes()
}

///|
/// Decode a `FileDescriptorProto`.
pub fn FileDescriptor::decode(body : Bytes) -> FileDescriptor raise PbError {
  let r = PbReader::new(body)
  let mut name = ""
  let mut package_ = ""
  let mut syntax = ""
  let dependencies = []
  let messages = []
  let enums = []
  let services = []
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => name = r.read_string()
      (2, LengthDelim) => package_ = r.read_string()
      (3, LengthDelim) => dependencies.push(r.read_string())
      (4, LengthDelim) =>
        messages.push(MessageDescriptor::decode(r.read_bytes()))
      (5, LengthDelim) => enums.push(EnumDescriptor::decode(r.read_bytes()))
      (6, LengthDelim) =>
        services.push(ServiceDescriptor::decode(r.read_bytes()))
      (12, LengthDelim) => syntax = r.read_string()
      (_, w) => r.skip(w)
    }
  }
  { name, package_, dependencies, messages, enums, services, syntax, }
}

///|
fn FileDescriptor::prefix(self : FileDescriptor) -> String {
  if self.package_.length() > 0 {
    self.package_ + "."
  } else {
    ""
  }
}

///|
/// The fully-qualified names this file defines: each service and its methods
/// (`package.Service.Method`), each message with the messages and enums inside
/// it, and each enum. These are the symbols a `FileContainingSymbol` reflection
/// request can resolve to this file.
pub fn FileDescriptor::symbols(self : FileDescriptor) -> Array[String] {
  let out = []
  let prefix = self.prefix()
  for s in self.services {
    out.push(prefix + s.name)
    for m in s.methods {
      out.push(prefix + s.name + "." + m.name)
    }
  }
  fn walk(scope : String, m : MessageDescriptor) {
    let name = scope + m.name
    out.push(name)
    for e in m.enums {
      out.push(name + "." + e.name)
    }
    for n in m.nested {
      walk(name + ".", n)
    }
  }

  for m in self.messages {
    walk(prefix, m)
  }
  for e in self.enums {
    out.push(prefix + e.name)
  }
  out
}

///|
/// The fully-qualified names of the services this file defines (`package.Service`).
pub fn FileDescriptor::service_names(self : FileDescriptor) -> Array[String] {
  let prefix = self.prefix()
  self.services.map(s => prefix + s.name)
}

///|
/// The `.proto` source this file describes. Types are written by their
/// fully-qualified names, `map` fields as `map<K, V>` with their entry types
/// left implicit, and proto3 `optional` fields with the keyword instead of
/// their synthetic oneofs.
pub fn FileDescriptor::source(self : FileDescriptor) -> String {
  let out = StringBuilder()
  let proto3 = self.syntax == "proto3"
  out.write_string(
    "syntax = \"\{if self.syntax == "" { "proto2" } else { self.syntax }}\";\n",
  )
  if self.package_.length() > 0 {
    out.write_string("\npackage \{self.package_};\n")
  }
  if !self.dependencies.is_empty() {
    out.write_string("\n")
    for d in self.dependencies {
      out.write_string("import \"\{d}\";\n")
    }
  }
  for m in self.messages {
    out.write_string("\n")
    write_message(out, m, "", proto3)
  }
  for e in self.enums {
    out.write_string("\n")
    write_enum(out, e, "")
  }
  for s in self.services {
    out.write_string("\nservice \{s.name} {\n")
    for m in s.methods {
      let input = (if m.client_streaming { "stream " } else { "" }) +
        m.input_type
      let output = (if m.server_streaming { "stream " } else { "" }) +
        m.output_type
      out.write_string("  rpc \{m.name}(\{input}) returns (\{output});\n")
    }
    out.write_string("}\n")
  }
  out.to_string()
}

///|
fn write_enum(out : StringBuilder, e : EnumDescriptor, indent : String) -> Unit {
  out.write_string("\{indent}enum \{e.name} {\n")
  for v in e.values {
    out.write_string("\{indent}  \{v.name} = \{v.number};\n")
  }
  out.write_string("\{indent}}\n")
}

///|
fn type_of(f : FieldDescriptor) -> String {
  f.type_.keyword().unwrap_or(f.type_name)
}

///|
fn write_message(
  out : StringBuilder,
  m : MessageDescriptor,
  indent : String,
  proto3 : Bool,
) -> Unit {
  out.write_string("\{indent}message \{m.name} {\n")
  let inner = indent + "  "
  let entries : Map[String, MessageDescriptor] = Map([])
  for n in m.nested {
    if n.map_entry {
      entries[n.name] = n
    }
  }
  let written : Map[Int32, Unit] = Map([])
  for f in m.fields {
    let entry = if f.label is LabelRepeated && f.type_ is TypeMessage {
      let short = match f.type_name.rev_find(".") {
        Some(i) => f.type_name.view(start_offset=i + 1).to_owned()
        None => f.type_name
      }
      entries.get(short)
    } else {
      None
    }
    match (entry, f.oneof_index) {
      (Some(e), _) => {
        let key = e.fields.search_by(x => x.number == 1).map(i => e.fields[i])
        let value = e.fields.search_by(x => x.number == 2).map(i => e.fields[i])
        guard key is Some(k) && value is Some(v) else { continue }
        out.write_string(
          "\{inner}map<\{type_of(k)}, \{type_of(v)}> \{f.name} = \{f.number};\n",
        )
      }
      (None, Some(i)) if !f.proto3_optional => {
        if written.contains(i) {
          continue
        }
        written[i] = ()
        let name = m.oneofs.get(i).unwrap_or("oneof_\{i}")
        out.write_string("\{inner}oneof \{name} {\n")
        for g in m.fields {
          if g.oneof_index == Some(i) {
            out.write_string(
              "\{inner}  \{type_of(g)} \{g.name} = \{g.number};\n",
            )
          }
        }
        out.write_string("\{inner}}\n")
      }
      _ => {
        let label = match f.label {
          LabelRepeated => "repeated "
          LabelRequired => "required "
          LabelOptional if f.proto3_optional || !proto3 => "optional "
          LabelOptional => ""
        }
        out.write_string(
          "\{inner}\{label}\{type_of(f)} \{f.name} = \{f.number};\n",
        )
      }
    }
  }
  for n in m.nested {
    if !n.map_entry {
      write_message(out, n, inner, proto3)
    }
  }
  for e in m.enums {
    write_enum(out, e, inner)
  }
  out.write_string("\{indent}}\n")
}

///|
/// Encode a `FileDescriptorSet` (`protoc --descriptor_set_out`): the concatenation
/// of `FileDescriptorProto`s under repeated field 1.
pub fn encode_file_descriptor_set(files : Array[FileDescriptor]) -> Bytes {
  let w = PbWriter::new()
  for f in files {
    w.message_(1, f.encode())
  }
  w.to_bytes()
}

///|
/// Decode a `FileDescriptorSet` into its files.
pub fn decode_file_descriptor_set(
  body : Bytes,
) -> Array[FileDescriptor] raise PbError {
  let r = PbReader::new(body)
  let files : Array[FileDescriptor] = []
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => files.push(FileDescriptor::decode(r.read_bytes()))
      (_, w) => r.skip(w)
    }
  }
  files
}

///|
pub extend EnumDescriptor with Eq::{not_equal, equal}

///|
pub extend EnumValueDescriptor with Eq::{not_equal, equal}

///|
pub extend FieldDescriptor with Eq::{not_equal, equal}

///|
pub extend FieldLabel with Eq::{not_equal, equal}

///|
pub extend FieldType with Eq::{not_equal, equal}

///|
pub extend FileDescriptor with Eq::{not_equal, equal}

///|
pub extend MessageDescriptor with Eq::{not_equal, equal}

///|
pub extend MethodDescriptor with Eq::{not_equal, equal}

///|
pub extend ServiceDescriptor with Eq::{not_equal, equal}
