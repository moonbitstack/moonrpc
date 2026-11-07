// Proto3 JSON: the mapping between a message's wire bytes and the JSON form the ecosystem
// expects, driven by the descriptor model rather than by generated code. A message this
// library has a descriptor for travels as JSON without a second codec being written for it,
// which is what the `+json` codec of a JSON-speaking transport needs.
//
// The mapping is proto3's: field names in lowerCamelCase, `int64` and its unsigned and fixed
// relatives as strings, `bytes` as base64, enums by name, a map as a JSON object, and a
// message's zero values left out. The well-known types keep the shapes the specification
// gives them — a `Timestamp` is an RFC 3339 string, a `Duration` ends in `s` — because those
// are what every other implementation writes and reads.

///|
/// The types one JSON mapping resolves a field's `type_name` against: every message and enum
/// of every file that can appear in the value, keyed by its fully-qualified name with the
/// leading dot.
pub(all) struct Schema {
  messages : Map[String, MessageDescriptor]
  enums : Map[String, EnumDescriptor]
}

///|
pub fn Schema::empty() -> Schema {
  { messages: Map([]), enums: Map([]), }
}

///|
/// A schema over `files`, nested types included.
pub fn Schema::of(files : Array[FileDescriptor]) -> Schema {
  let schema = Schema::empty()
  for file in files {
    schema.add_file(file)
  }
  schema
}

///|
fn Schema::add_file(self : Schema, file : FileDescriptor) -> Unit {
  let prefix = if file.package_.length() > 0 { "." + file.package_ } else { "" }
  for message in file.messages {
    self.add_message(prefix, message)
  }
  for e in file.enums {
    self.enums[prefix + "." + e.name] = e
  }
}

///|
fn Schema::add_message(
  self : Schema,
  prefix : String,
  message : MessageDescriptor,
) -> Unit {
  let full = prefix + "." + message.name
  self.messages[full] = message
  for nested in message.nested {
    self.add_message(full, nested)
  }
  for e in message.enums {
    self.enums[full + "." + e.name] = e
  }
}

///|
/// The field numbered `number`, or `None` for one this descriptor does not declare.
fn field_of(desc : MessageDescriptor, number : Int32) -> FieldDescriptor? {
  for f in desc.fields {
    if f.number == number {
      return Some(f)
    }
  }
  None
}

///|
/// The ASCII uppercase of a letter, which is all the camelCase conversion needs: a field name
/// is an identifier, so the only characters in it are letters, digits and `_`.
fn ascii_upper(ch : Char) -> Char {
  let code = ch.to_int()
  if code >= 0x61 && code <= 0x7A {
    Int32::unsafe_to_char(code - 32)
  } else {
    ch
  }
}

///|
/// The JSON name of a field: the lowerCamelCase of its wire name, which is what protoc
/// generates into `json_name` when nothing overrides it.
pub fn json_name(field : FieldDescriptor) -> String {
  let mut out = ""
  let mut upcase = false
  for ch in field.name {
    if ch == '_' {
      upcase = true
    } else if upcase {
      out = out + ascii_upper(ch).to_string()
      upcase = false
    } else {
      out = out + ch.to_string()
    }
  }
  out
}

///|
/// A value read off the wire, before it becomes JSON: enough of the wire form that the JSON
/// writer can shape it, and no more.
priv enum Raw {
  RBool(Bool)
  RInt(Int64)
  RUInt(UInt64)
  RDouble(Double)
  RBits(UInt64)
  RBlob(Bytes)
  RRun(Array[Raw])
}

///|
/// Whether a repeated field of this type travels packed when the length-delimited wire type is
/// what arrived. Strings, bytes and messages are length-delimited by nature and never packed.
fn is_packable(type_ : FieldType) -> Bool {
  match type_ {
    TypeString | TypeBytes | TypeMessage => false
    _ => true
  }
}

///|
/// The wire type a field of this type is written with.
fn wire_of(type_ : FieldType) -> WireType {
  match type_ {
    TypeDouble | TypeFixed64 | TypeSfixed64 => Fixed64
    TypeFloat | TypeFixed32 | TypeSfixed32 => Fixed32
    TypeString | TypeBytes | TypeMessage => LengthDelim
    _ => Varint
  }
}

///|
/// Read one value of `type_` at the reader's cursor.
fn read_raw(reader : PbReader, type_ : FieldType) -> Raw raise PbError {
  match type_ {
    TypeBool => RBool(reader.read_bool())
    TypeInt32 => RInt(reader.read_int32().to_int64())
    TypeInt64 => RInt(reader.read_int64())
    TypeSint32 => RInt(reader.read_sint32().to_int64())
    TypeSint64 => RInt(reader.read_sint64())
    TypeSfixed32 => RInt(reader.read_fixed32().reinterpret_as_int().to_int64())
    TypeSfixed64 => RInt(reader.read_fixed64().reinterpret_as_int64())
    TypeUint32 => RUInt(reader.read_uint32().to_uint64())
    TypeUint64 => RUInt(reader.read_uint64())
    TypeFixed32 => RBits(reader.read_fixed32().to_uint64())
    TypeFixed64 => RBits(reader.read_fixed64())
    TypeEnum => RInt(reader.read_varint().reinterpret_as_int64())
    TypeDouble => RDouble(reader.read_double())
    TypeFloat => RDouble(reader.read_float().to_double())
    TypeString | TypeBytes | TypeMessage => RBlob(reader.read_len_delim())
  }
}

///|
/// Every field of `desc` that the wire bytes carry, keyed by field number. A field the number
/// belongs to is typed by its descriptor; a number with no field is skipped, which is what
/// proto3 asks a parser to do with an unknown field.
fn read_fields(
  desc : MessageDescriptor,
  bytes : Bytes,
) -> Map[Int32, Array[Raw]] raise PbError {
  let out : Map[Int32, Array[Raw]] = Map([])
  let reader = PbReader::new(bytes)
  while !reader.eof() {
    let (number, wire) = reader.read_tag()
    match field_of(desc, number) {
      None => reader.skip(wire)
      Some(f) => {
        let values = match out.get(number) {
          Some(v) => v
          None => []
        }
        if f.type_ != TypeMessage &&
          f.label == LabelRepeated &&
          wire == LengthDelim &&
          is_packable(f.type_) {
          // A packed run: every element of one numeric type inside a single length-delimited
          // field. protoc writes these by default for proto3, and a reader has to take both.
          let run = PbReader::new(reader.read_len_delim())
          let items = []
          while !run.eof() {
            items.push(read_raw(run, f.type_))
          }
          values.push(RRun(items))
        } else if wire == wire_of(f.type_) {
          values.push(read_raw(reader, f.type_))
        } else {
          reader.skip(wire)
        }
        out[number] = values
      }
    }
  }
  out
}

///|
/// Whether this field is a `map`: a repeated field whose entry message protoc marked
/// `map_entry`.
fn is_map(schema : Schema, field : FieldDescriptor) -> Bool {
  if field.label != LabelRepeated || field.type_ != TypeMessage {
    return false
  }
  match schema.messages.get(field.type_name) {
    Some(entry) => entry.map_entry
    None => false
  }
}

///|
/// The JSON a message's wire bytes stand for. `name` is its fully-qualified descriptor name,
/// which is how a well-known type is recognised.
pub fn Schema::to_json(
  self : Schema,
  name : String,
  bytes : Bytes,
) -> Json raise PbError {
  match self.messages.get(name) {
    None => raise BadWireType(0)
    Some(desc) => self.message_json(name, desc, bytes)
  }
}

///|
fn Schema::message_json(
  self : Schema,
  name : String,
  desc : MessageDescriptor,
  bytes : Bytes,
) -> Json raise PbError {
  match self.well_known_json(name, desc, bytes) {
    Some(value) => value
    None => {
      let fields = read_fields(desc, bytes)
      let members : Map[String, Json] = Map([])
      for f in desc.fields {
        match fields.get(f.number) {
          None => ()
          Some(raws) =>
            if is_map(self, f) {
              members[json_name(f)] = self.map_json(f, raws)
            } else if f.label == LabelRepeated {
              let items = []
              for raw in raws {
                for one in flatten(raw) {
                  items.push(self.value_json(f, one))
                }
              }
              members[json_name(f)] = Json::array(items)
            } else if raws.length() > 0 {
              // A singular field repeated on the wire keeps its last value, as proto3 says.
              for one in flatten(raws[raws.length() - 1]) {
                members[json_name(f)] = self.value_json(f, one)
              }
            }
        }
      }
      Json::object(members)
    }
  }
}

///|
/// A packed run stands for its elements; anything else stands for itself.
fn flatten(raw : Raw) -> Array[Raw] {
  match raw {
    RRun(items) => items
    other => [other]
  }
}

///|
fn Schema::map_json(
  self : Schema,
  field : FieldDescriptor,
  raws : Array[Raw],
) -> Json raise PbError {
  let members : Map[String, Json] = Map([])
  let entry = match self.messages.get(field.type_name) {
    Some(e) => e
    None => return Json::object(members)
  }
  let key_field = match field_of(entry, 1) {
    Some(f) => f
    None => return Json::object(members)
  }
  let value_field = match field_of(entry, 2) {
    Some(f) => f
    None => return Json::object(members)
  }
  for raw in raws {
    for one in flatten(raw) {
      match one {
        RBlob(bytes) => {
          let parts = read_fields(entry, bytes)
          let key = match parts.get(1) {
            Some(v) if v.length() > 0 => key_text(key_field, v[0])
            _ => default_key(key_field)
          }
          let value = match parts.get(2) {
            Some(v) if v.length() > 0 => self.value_json(value_field, v[0])
            _ => self.value_json(value_field, zero_raw(value_field.type_))
          }
          members[key] = value
        }
        _ => ()
      }
    }
  }
  Json::object(members)
}

///|
/// A map key as JSON spells it: the number as text, the boolean as `true` or `false`.
fn key_text(field : FieldDescriptor, raw : Raw) -> String {
  match field.type_ {
    TypeBool =>
      match raw {
        RBool(b) => if b { "true" } else { "false" }
        _ => "false"
      }
    TypeUint32 | TypeUint64 | TypeFixed32 | TypeFixed64 =>
      match raw {
        RUInt(v) => v.to_string()
        RBits(v) => v.to_string()
        RInt(v) => v.to_string()
        _ => "0"
      }
    TypeString =>
      match raw {
        RBlob(b) => @utf8.decode_lossy(b)
        _ => ""
      }
    _ =>
      match raw {
        RInt(v) => v.to_string()
        _ => "0"
      }
  }
}

///|
fn default_key(field : FieldDescriptor) -> String {
  match field.type_ {
    TypeBool => "false"
    _ => "0"
  }
}

///|
/// The raw value a field's zero stands for, which is what a map's value falls back to.
fn zero_raw(type_ : FieldType) -> Raw {
  match type_ {
    TypeBool => RBool(false)
    TypeString | TypeBytes | TypeMessage => RBlob(b"")
    TypeDouble | TypeFloat => RDouble(0.0)
    TypeUint32 | TypeUint64 => RUInt(0UL)
    TypeFixed32 | TypeFixed64 => RBits(0UL)
    _ => RInt(0L)
  }
}

///|
/// One value as JSON, in the shape its field's type asks for.
fn Schema::value_json(
  self : Schema,
  field : FieldDescriptor,
  raw : Raw,
) -> Json raise PbError {
  match field.type_ {
    TypeBool =>
      match raw {
        RBool(b) => Json::boolean(b)
        _ => Json::null()
      }
    TypeInt32 | TypeSint32 | TypeSfixed32 =>
      match raw {
        RInt(v) => Json::number(v.to_double(), repr=v.to_string())
        _ => Json::null()
      }
    // 64-bit integers travel as strings: JSON numbers are doubles, and a double cannot hold
    // every value these types do.
    TypeInt64 | TypeSint64 | TypeSfixed64 =>
      match raw {
        RInt(v) => Json::string(v.to_string())
        _ => Json::null()
      }
    TypeUint32 =>
      match raw {
        RUInt(v) => Json::number(v.to_double(), repr=v.to_string())
        _ => Json::null()
      }
    TypeUint64 | TypeFixed64 =>
      match raw {
        RUInt(v) => Json::string(v.to_string())
        RBits(v) => Json::string(v.to_string())
        _ => Json::null()
      }
    TypeFixed32 =>
      match raw {
        RBits(v) => Json::number(v.to_double(), repr=v.to_string())
        _ => Json::null()
      }
    TypeDouble | TypeFloat =>
      match raw {
        RDouble(v) => double_json(v)
        _ => Json::null()
      }
    TypeString =>
      match raw {
        RBlob(bytes) => Json::string(@utf8.decode_lossy(bytes))
        _ => Json::null()
      }
    TypeBytes =>
      match raw {
        RBlob(bytes) => Json::string(@base64.encode(bytes[:]))
        _ => Json::null()
      }
    TypeEnum =>
      match raw {
        RInt(v) =>
          match self.enum_name(field.type_name, v.to_int()) {
            Some(name) => Json::string(name)
            None => Json::number(v.to_double(), repr=v.to_string())
          }
        _ => Json::null()
      }
    TypeMessage =>
      match raw {
        RBlob(bytes) =>
          match self.messages.get(field.type_name) {
            Some(desc) => self.message_json(field.type_name, desc, bytes)
            None => Json::object(Map([]))
          }
        _ => Json::null()
      }
  }
}

///|
/// A double as JSON: the three values JSON has no number for become strings, and anything
/// else is a number written so it reads back as the same double.
fn double_json(value : Double) -> Json {
  if value.is_nan() {
    Json::string("NaN")
  } else if value == @double.infinity {
    Json::string("Infinity")
  } else if value == -@double.infinity {
    Json::string("-Infinity")
  } else if value == value.to_int().to_double() && value.abs() < 1.0e16 {
    // An integral double is written without a fractional part, as every implementation does.
    Json::number(value, repr=value.to_int().to_string())
  } else {
    Json::number(value)
  }
}

///|
/// The name of `number` in the enum `name`, or `None` for a value the enum does not declare.
fn Schema::enum_name(self : Schema, name : String, number : Int32) -> String? {
  match self.enums.get(name) {
    None => None
    Some(e) => {
      for v in e.values {
        if v.number == number {
          return Some(v.name)
        }
      }
      None
    }
  }
}

// -- the well-known types ------------------------------------------------

///|
/// The JSON a well-known type stands for, or `None` when `name` is not one this mapping
/// gives a shape of its own.
fn Schema::well_known_json(
  self : Schema,
  name : String,
  desc : MessageDescriptor,
  bytes : Bytes,
) -> Json? raise PbError {
  if name == ".google.protobuf.Timestamp" {
    return Some(timestamp_json(read_fields(desc, bytes)))
  }
  if name == ".google.protobuf.Duration" {
    return Some(duration_json(read_fields(desc, bytes)))
  }
  if name == ".google.protobuf.Empty" {
    return Some(Json::object(Map([])))
  }
  if name == ".google.protobuf.FieldMask" {
    return Some(field_mask_json(read_fields(desc, bytes)))
  }
  if name == ".google.protobuf.Struct" {
    let fields = read_fields(desc, bytes)
    return Some(
      match fields.get(1) {
        Some(v) if v.length() > 0 => self.struct_json(v[0])
        _ => Json::object(Map([]))
      },
    )
  }
  if name == ".google.protobuf.Value" {
    return Some(self.wrapped_value_json(desc, bytes))
  }
  if name == ".google.protobuf.ListValue" {
    let fields = read_fields(desc, bytes)
    return Some(
      match fields.get(1) {
        Some(v) => self.list_json(v)
        _ => Json::array([])
      },
    )
  }
  if name == ".google.protobuf.Any" {
    return Some(self.any_json(desc, bytes))
  }
  match wrapper_type(name) {
    Some(type_) => Some(wrapper_json(type_, read_fields(desc, bytes)))
    None => None
  }
}

///|
/// The scalar a wrapper message wraps, or `None` for a message that is not a wrapper.
fn wrapper_type(name : String) -> FieldType? {
  if name == ".google.protobuf.DoubleValue" {
    Some(TypeDouble)
  } else if name == ".google.protobuf.FloatValue" {
    Some(TypeFloat)
  } else if name == ".google.protobuf.Int64Value" {
    Some(TypeInt64)
  } else if name == ".google.protobuf.UInt64Value" {
    Some(TypeUint64)
  } else if name == ".google.protobuf.Int32Value" {
    Some(TypeInt32)
  } else if name == ".google.protobuf.UInt32Value" {
    Some(TypeUint32)
  } else if name == ".google.protobuf.BoolValue" {
    Some(TypeBool)
  } else if name == ".google.protobuf.StringValue" {
    Some(TypeString)
  } else if name == ".google.protobuf.BytesValue" {
    Some(TypeBytes)
  } else {
    None
  }
}

///|
/// A wrapper's JSON is the bare value it wraps, and `null` when it wraps nothing.
fn wrapper_json(type_ : FieldType, fields : Map[Int32, Array[Raw]]) -> Json {
  match fields.get(1) {
    Some(v) if v.length() > 0 =>
      match (type_, v[0]) {
        (_, RBool(b)) => Json::boolean(b)
        (_, RInt(n)) =>
          match type_ {
            TypeInt64 => Json::string(n.to_string())
            _ => Json::number(n.to_double(), repr=n.to_string())
          }
        (_, RUInt(n)) =>
          match type_ {
            TypeUint64 => Json::string(n.to_string())
            _ => Json::number(n.to_double(), repr=n.to_string())
          }
        (_, RDouble(d)) => double_json(d)
        (_, RBlob(bytes)) =>
          match type_ {
            TypeBytes => Json::string(@base64.encode(bytes[:]))
            _ => Json::string(@utf8.decode_lossy(bytes))
          }
        _ => Json::null()
      }
    _ => Json::null()
  }
}

///|
fn Schema::struct_json(self : Schema, raw : Raw) -> Json raise PbError {
  match raw {
    RBlob(bytes) => {
      // `Struct` is a message whose field 1 is a `map<string, Value>`; the map's entry
      // message is what carries each member.
      let members : Map[String, Json] = Map([])
      let reader = PbReader::new(bytes)
      while !reader.eof() {
        let (number, wire) = reader.read_tag()
        if number == 1 && wire == LengthDelim {
          let entry = reader.read_len_delim()
          let er = PbReader::new(entry)
          let mut key = ""
          let mut value = Json::null()
          while !er.eof() {
            let (n, w) = er.read_tag()
            if n == 1 && w == LengthDelim {
              key = @utf8.decode_lossy(er.read_len_delim())
            } else if n == 2 && w == LengthDelim {
              let inner = er.read_len_delim()
              match self.messages.get(".google.protobuf.Value") {
                Some(desc) => value = self.wrapped_value_json(desc, inner)
                None => ()
              }
            } else {
              er.skip(w)
            }
          }
          members[key] = value
        } else {
          reader.skip(wire)
        }
      }
      Json::object(members)
    }
    _ => Json::object(Map([]))
  }
}

///|
/// A `Value`: exactly one of its six kinds is set.
fn Schema::wrapped_value_json(
  self : Schema,
  desc : MessageDescriptor,
  bytes : Bytes,
) -> Json raise PbError {
  let fields = read_fields(desc, bytes)
  for one in [6, 5, 4, 3, 2, 1] {
    match fields.get(one) {
      Some(v) if v.length() > 0 =>
        match one {
          1 => return Json::null()
          2 =>
            for raw in flatten(v[0]) {
              match raw {
                RDouble(d) => return double_json(d)
                _ => ()
              }
            }
          3 =>
            for raw in flatten(v[0]) {
              match raw {
                RBlob(b) => return Json::string(@utf8.decode_lossy(b))
                _ => ()
              }
            }
          4 =>
            for raw in flatten(v[0]) {
              match raw {
                RBool(b) => return Json::boolean(b)
                _ => ()
              }
            }
          5 =>
            for raw in flatten(v[0]) {
              match raw {
                RBlob(b) =>
                  match self.messages.get(".google.protobuf.Struct") {
                    Some(struct_desc) => {
                      let inner = read_fields(struct_desc, b)
                      match inner.get(1) {
                        Some(s) if s.length() > 0 =>
                          return self.struct_json(s[0])
                        _ => return Json::object(Map([]))
                      }
                    }
                    None => return Json::object(Map([]))
                  }
                _ => ()
              }
            }
          _ =>
            for raw in flatten(v[0]) {
              match raw {
                RBlob(b) =>
                  match self.messages.get(".google.protobuf.ListValue") {
                    Some(list_desc) => {
                      let inner = read_fields(list_desc, b)
                      match inner.get(1) {
                        Some(s) => return self.list_json(s)
                        _ => return Json::array([])
                      }
                    }
                    None => return Json::array([])
                  }
                _ => ()
              }
            }
        }
      _ => ()
    }
  }
  Json::null()
}

///|
/// A `ListValue`'s members, each a `Value`.
fn Schema::list_json(self : Schema, raws : Array[Raw]) -> Json raise PbError {
  let items = []
  for raw in raws {
    for one in flatten(raw) {
      match one {
        RBlob(b) =>
          match self.messages.get(".google.protobuf.Value") {
            Some(desc) => items.push(self.wrapped_value_json(desc, b))
            None => ()
          }
        _ => ()
      }
    }
  }
  Json::array(items)
}

///|
fn Schema::any_json(
  self : Schema,
  desc : MessageDescriptor,
  bytes : Bytes,
) -> Json raise PbError {
  let fields = read_fields(desc, bytes)
  let mut url = ""
  let mut value = b""
  match fields.get(1) {
    Some(v) if v.length() > 0 =>
      match v[0] {
        RBlob(b) => url = @utf8.decode_lossy(b)
        _ => ()
      }
    _ => ()
  }
  match fields.get(2) {
    Some(v) if v.length() > 0 =>
      match v[0] {
        RBlob(b) => value = b
        _ => ()
      }
    _ => ()
  }
  let members : Map[String, Json] = Map([])
  members["@type"] = Json::string(url)
  // The type is named by the last segment of the URL: `type.googleapis.com/pkg.Msg`.
  let name = "." + last_segment_after_slash(url)
  match self.messages.get(name) {
    Some(inner) =>
      match self.message_json(name, inner, value) {
        Json::Object(fields_json) =>
          for k, v in fields_json {
            members[k] = v
          }
        _ => ()
      }
    None => ()
  }
  Json::object(members)
}

///|
fn last_segment_after_slash(text : String) -> String {
  let mut cut = 0
  let mut i = 0
  for ch in text {
    i = i + 1
    if ch == '/' {
      cut = i
    }
  }
  text.exact_view(start=cut, end=text.length()).to_owned()
}

///|
fn timestamp_json(fields : Map[Int32, Array[Raw]]) -> Json {
  let mut seconds : Int64 = 0L
  let mut nanos : Int64 = 0L
  match fields.get(1) {
    Some(v) if v.length() > 0 =>
      match v[0] {
        RInt(s) => seconds = s
        _ => ()
      }
    _ => ()
  }
  match fields.get(2) {
    Some(v) if v.length() > 0 =>
      match v[0] {
        RInt(n) => nanos = n
        _ => ()
      }
    _ => ()
  }
  Json::string(rfc3339(seconds, nanos))
}

///|
fn duration_json(fields : Map[Int32, Array[Raw]]) -> Json {
  let mut seconds : Int64 = 0L
  let mut nanos : Int64 = 0L
  match fields.get(1) {
    Some(v) if v.length() > 0 =>
      match v[0] {
        RInt(s) => seconds = s
        _ => ()
      }
    _ => ()
  }
  match fields.get(2) {
    Some(v) if v.length() > 0 =>
      match v[0] {
        RInt(n) => nanos = n
        _ => ()
      }
    _ => ()
  }
  let negative = seconds < 0L || nanos < 0L
  let s = if seconds < 0L { -seconds } else { seconds }
  let n = if nanos < 0L { -nanos } else { nanos }
  let mut text = if negative { "-" } else { "" }
  text = text + s.to_string()
  if n > 0L {
    text = text + "." + fraction(n, 9).trim_end(chars="0").to_owned()
  }
  Json::string(text + "s")
}

///|
fn field_mask_json(fields : Map[Int32, Array[Raw]]) -> Json {
  let paths = []
  match fields.get(1) {
    Some(v) =>
      for raw in v {
        for one in flatten(raw) {
          match one {
            RBlob(b) => paths.push(camel_path(@utf8.decode_lossy(b)))
            _ => ()
          }
        }
      }
    None => ()
  }
  Json::string(paths.join(","))
}

///|
/// A field mask path in the JSON spelling: each snake_case segment becomes lowerCamelCase.
fn camel_path(path : String) -> String {
  let out = []
  for segment in path.split(".") {
    out.push(json_name(FieldDescriptor::new(segment.to_owned(), 0, TypeString)))
  }
  out.join(".")
}

///|
/// `seconds` and `nanos` as RFC 3339 in UTC: the fraction is written with three, six or nine
/// digits, whichever holds the nanoseconds exactly, and left out when there are none.
fn rfc3339(seconds : Int64, nanos : Int64) -> String {
  let days = floor_div(seconds, 86400L)
  let of_day = seconds - days * 86400L
  let (year, month, day) = civil_from_days(days)
  let hour = of_day / 3600L
  let minute = (of_day - hour * 3600L) / 60L
  let second = of_day - hour * 3600L - minute * 60L
  let mut text = pad(year, 4) +
    "-" +
    pad(month, 2) +
    "-" +
    pad(day, 2) +
    "T" +
    pad(hour, 2) +
    ":" +
    pad(minute, 2) +
    ":" +
    pad(second, 2)
  if nanos > 0L {
    let n = nanos
    let digits = if n % 1000000L == 0L {
      3
    } else if n % 1000L == 0L {
      6
    } else {
      9
    }
    text = text + "." + fraction(n, digits)
  }
  text + "Z"
}

///|
fn fraction(nanos : Int64, digits : Int32) -> String {
  let text = pad(nanos, 9)
  text.exact_view(start=0, end=digits).to_owned()
}

///|
fn pad(value : Int64, width : Int32) -> String {
  let text = value.to_string()
  let mut out = ""
  for _ in 0..<(width - text.length()) {
    out = out + "0"
  }
  out + text
}

///|
fn floor_div(a : Int64, b : Int64) -> Int64 {
  let q = a / b
  if a % b != 0L && (a < 0L) != (b < 0L) {
    q - 1L
  } else {
    q
  }
}

///|
/// Days since 1970-01-01 for a civil date, by the algorithm the standard library of every
/// language uses: it is exact for the whole range a `Timestamp` covers.
fn days_from_civil(year_in : Int64, month : Int64, day : Int64) -> Int64 {
  let y = if month <= 2L { year_in - 1L } else { year_in }
  let era = floor_div(y, 400L)
  let yoe = y - era * 400L
  let mp = if month > 2L { month - 3L } else { month + 9L }
  let doy = (153L * mp + 2L) / 5L + day - 1L
  let doe = yoe * 365L + yoe / 4L - yoe / 100L + doy
  era * 146097L + doe - 719468L
}

///|
fn civil_from_days(days : Int64) -> (Int64, Int64, Int64) {
  let z = days + 719468L
  let era = floor_div(z, 146097L)
  let doe = z - era * 146097L
  let yoe = (doe - doe / 1460L + doe / 36524L - doe / 146096L) / 365L
  let y = yoe + era * 400L
  let doy = doe - (365L * yoe + yoe / 4L - yoe / 100L)
  let mp = (5L * doy + 2L) / 153L
  let d = doy - (153L * mp + 2L) / 5L + 1L
  let m = if mp < 10L { mp + 3L } else { mp - 9L }
  (if m <= 2L { y + 1L } else { y }, m, d)
}

// -- JSON to the wire ----------------------------------------------------

///|
/// The wire bytes a JSON value stands for, under the message `name`.
pub fn Schema::to_bytes(
  self : Schema,
  name : String,
  value : Json,
) -> Bytes raise PbError {
  match self.messages.get(name) {
    None => raise BadWireType(0)
    Some(desc) => self.message_bytes(name, desc, value)
  }
}

///|
fn Schema::message_bytes(
  self : Schema,
  name : String,
  desc : MessageDescriptor,
  value : Json,
) -> Bytes raise PbError {
  match self.well_known_bytes(name, desc, value) {
    Some(bytes) => bytes
    None => {
      let writer = PbWriter::new()
      match value {
        Null => ()
        Object(members) =>
          for f in desc.fields {
            let held = member_of(members, f)
            match held {
              None => ()
              Some(v) =>
                match v {
                  Null => ()
                  _ => self.write_field(writer, f, v)
                }
            }
          }
        _ => raise BadWireType(0)
      }
      writer.to_bytes()
    }
  }
}

///|
/// The member a field is written from: its JSON name, or the proto spelling for a writer that
/// used that instead.
fn member_of(members : Map[String, Json], field : FieldDescriptor) -> Json? {
  match members.get(json_name(field)) {
    Some(v) => Some(v)
    None => members.get(field.name)
  }
}

///|
fn Schema::write_field(
  self : Schema,
  writer : PbWriter,
  field : FieldDescriptor,
  value : Json,
) -> Unit raise PbError {
  if is_map(self, field) {
    match value {
      Object(members) =>
        for key, item in members {
          let entry = PbWriter::new()
          let entry_desc = match self.messages.get(field.type_name) {
            Some(e) => e
            None => return ()
          }
          let key_field = match field_of(entry_desc, 1) {
            Some(f) => f
            None => return ()
          }
          let value_field = match field_of(entry_desc, 2) {
            Some(f) => f
            None => return ()
          }
          self.write_singular(entry, key_field, Json::string(key))
          match item {
            Null => ()
            _ => self.write_one(entry, value_field, item)
          }
          writer.message_(field.number, entry.to_bytes())
        }
      _ => ()
    }
    return
  }
  if field.label == LabelRepeated {
    match value {
      Array(items) =>
        for item in items {
          match item {
            Null => ()
            _ => self.write_one(writer, field, item)
          }
        }
      _ => ()
    }
    return
  }
  self.write_one(writer, field, value)
}

///|
/// One element of a repeated field, or the whole of a singular one.
fn Schema::write_one(
  self : Schema,
  writer : PbWriter,
  field : FieldDescriptor,
  value : Json,
) -> Unit raise PbError {
  self.write_singular(writer, field, value)
}

///|
fn Schema::write_singular(
  self : Schema,
  writer : PbWriter,
  field : FieldDescriptor,
  value : Json,
) -> Unit raise PbError {
  let number = field.number
  match field.type_ {
    TypeBool =>
      match value {
        True => writer.bool_(number, true)
        False => writer.bool_(number, false)
        _ => ()
      }
    TypeInt32 | TypeSint32 | TypeSfixed32 =>
      match number_text(value) {
        Some(text) =>
          match parse_i32(text) {
            Some(n) =>
              match field.type_ {
                TypeSint32 => writer.sint32(number, n)
                _ => writer.int32(number, n)
              }
            None => ()
          }
        None => ()
      }
    TypeInt64 | TypeSint64 | TypeSfixed64 =>
      match number_text(value) {
        Some(text) =>
          match parse_i64(text) {
            Some(n) =>
              match field.type_ {
                TypeSint64 => writer.sint64(number, n)
                _ => writer.int64(number, n)
              }
            None => ()
          }
        None => ()
      }
    TypeUint32 =>
      match number_text(value) {
        Some(text) =>
          match parse_u32(text) {
            Some(n) => writer.uint32(number, n)
            None => ()
          }
        None => ()
      }
    TypeUint64 | TypeFixed64 =>
      match number_text(value) {
        Some(text) =>
          match parse_u64(text) {
            Some(n) =>
              match field.type_ {
                TypeFixed64 => writer.fixed64(number, n)
                _ => writer.uint64(number, n)
              }
            None => ()
          }
        None => ()
      }
    TypeFixed32 =>
      match number_text(value) {
        Some(text) =>
          match parse_u32(text) {
            Some(n) => writer.fixed32(number, n)
            None => ()
          }
        None => ()
      }
    TypeDouble | TypeFloat =>
      match value {
        Number(d, ..) =>
          match field.type_ {
            TypeFloat => writer.float_(number, Float::from_double(d))
            _ => writer.double_(number, d)
          }
        String(s) =>
          match special_double(s) {
            Some(d) =>
              match field.type_ {
                TypeFloat => writer.float_(number, Float::from_double(d))
                _ => writer.double_(number, d)
              }
            None => ()
          }
        _ => ()
      }
    TypeString =>
      match value {
        String(s) => writer.string_(number, s)
        _ => ()
      }
    TypeBytes =>
      match value {
        String(s) => {
          let bytes = @base64.decode_any(s) catch { _ => raise BadWireType(0) }
          writer.bytes_(number, bytes)
        }
        _ => ()
      }
    TypeEnum =>
      match value {
        String(name) =>
          match self.enum_number(field.type_name, name) {
            Some(n) => writer.enum_(number, n)
            None => raise BadWireType(0)
          }
        Number(d, ..) => writer.enum_(number, d.to_int())
        _ => ()
      }
    TypeMessage =>
      match self.messages.get(field.type_name) {
        Some(desc) => {
          let body = self.message_bytes(field.type_name, desc, value)
          writer.message_(number, body)
        }
        None => ()
      }
  }
}

///|
/// The number a JSON number, or a number written as a string, stands for.
fn number_text(value : Json) -> String? {
  match value {
    Number(d, repr~) =>
      match repr {
        Some(text) => Some(text)
        None =>
          if d == d.to_int64().to_double() {
            Some(d.to_int64().to_string())
          } else {
            None
          }
      }
    String(s) => Some(s)
    _ => None
  }
}

///|
/// The integers a JSON number may spell, as options: a value out of range is not a number
/// this field can hold, and the field is left unset rather than written wrong.
fn parse_i64(text : String) -> Int64? {
  let result : Result[Int64, Error] = Ok(@string.parse_int64(text[:])) catch {
    e => Err(e)
  }
  match result {
    Ok(v) => Some(v)
    Err(_) => None
  }
}

///|
fn parse_u64(text : String) -> UInt64? {
  let result : Result[UInt64, Error] = Ok(@string.parse_uint64(text[:])) catch {
    e => Err(e)
  }
  match result {
    Ok(v) => Some(v)
    Err(_) => None
  }
}

///|
fn parse_i32(text : String) -> Int32? {
  let result : Result[Int32, Error] = Ok(@string.parse_int(text[:])) catch {
    e => Err(e)
  }
  match result {
    Ok(v) => Some(v)
    Err(_) => None
  }
}

///|
fn parse_u32(text : String) -> UInt32? {
  let result : Result[UInt32, Error] = Ok(@string.parse_uint(text[:])) catch {
    e => Err(e)
  }
  match result {
    Ok(v) => Some(v)
    Err(_) => None
  }
}

///|
/// The three doubles JSON writes as strings.
fn special_double(text : String) -> Double? {
  if text == "NaN" {
    Some(0.0 / 0.0)
  } else if text == "Infinity" {
    Some(@double.infinity)
  } else if text == "-Infinity" {
    Some(-@double.infinity)
  } else {
    None
  }
}

///|
/// The number an enum value name stands for.
fn Schema::enum_number(self : Schema, name : String, value : String) -> Int32? {
  match self.enums.get(name) {
    None => None
    Some(e) => {
      for v in e.values {
        if v.name == value {
          return Some(v.number)
        }
      }
      None
    }
  }
}

// -- the well-known types, read back ------------------------------------

///|
/// The wire bytes a well-known type's JSON stands for, or `None` when the name is not one.
fn Schema::well_known_bytes(
  self : Schema,
  name : String,
  desc : MessageDescriptor,
  value : Json,
) -> Bytes? raise PbError {
  if name == ".google.protobuf.Timestamp" {
    return Some(timestamp_bytes(desc, value))
  }
  if name == ".google.protobuf.Duration" {
    return Some(duration_bytes(desc, value))
  }
  if name == ".google.protobuf.Empty" {
    return Some(b"")
  }
  if name == ".google.protobuf.FieldMask" {
    return Some(field_mask_bytes(desc, value))
  }
  if name == ".google.protobuf.Struct" {
    return Some(self.struct_bytes(desc, value))
  }
  if name == ".google.protobuf.Value" {
    return Some(self.value_bytes(desc, value))
  }
  if name == ".google.protobuf.ListValue" {
    return Some(self.list_bytes(desc, value))
  }
  if name == ".google.protobuf.Any" {
    return Some(self.any_bytes(desc, value))
  }
  match wrapper_type(name) {
    Some(type_) => Some(wrapper_bytes(desc, type_, value))
    None => None
  }
}

///|
fn wrapper_bytes(
  desc : MessageDescriptor,
  type_ : FieldType,
  value : Json,
) -> Bytes raise PbError {
  let writer = PbWriter::new()
  match field_of(desc, 1) {
    Some(f) =>
      // The wrapped value is the field's own type; the schema is not consulted for a scalar.
      match (type_, value) {
        (TypeBool, True) => writer.bool_(1, true)
        (TypeBool, False) => writer.bool_(1, false)
        (TypeString, String(s)) => writer.string_(1, s)
        (TypeBytes, String(s)) => {
          let bytes = @base64.decode_any(s) catch { _ => raise BadWireType(0) }
          writer.bytes_(1, bytes)
        }
        (TypeDouble, Number(d, ..)) => writer.double_(1, d)
        (TypeFloat, Number(d, ..)) => writer.float_(1, Float::from_double(d))
        (_, Number(d, ..)) =>
          match f.type_ {
            TypeInt64 => writer.int64(1, d.to_int64())
            TypeInt32 => writer.int32(1, d.to_int())
            TypeUint64 => writer.uint64(1, d.to_int64().reinterpret_as_uint64())
            TypeUint32 => writer.uint32(1, d.to_int().reinterpret_as_uint())
            _ => ()
          }
        (_, String(s)) =>
          match f.type_ {
            TypeInt64 =>
              match parse_i64(s) {
                Some(n) => writer.int64(1, n)
                None => ()
              }
            TypeInt32 =>
              match parse_i32(s) {
                Some(n) => writer.int32(1, n)
                None => ()
              }
            TypeUint64 =>
              match parse_u64(s) {
                Some(n) => writer.uint64(1, n)
                None => ()
              }
            TypeUint32 =>
              match parse_u32(s) {
                Some(n) => writer.uint32(1, n)
                None => ()
              }
            _ => ()
          }
        _ => ()
      }
    None => ()
  }
  writer.to_bytes()
}

///|
fn timestamp_bytes(
  desc : MessageDescriptor,
  value : Json,
) -> Bytes raise PbError {
  let writer = PbWriter::new()
  match value {
    String(text) =>
      match parse_rfc3339(text) {
        Some((seconds, nanos)) => {
          if seconds != 0L {
            writer.int64(1, seconds)
          }
          if nanos != 0L {
            writer.int32(2, nanos.to_int())
          }
        }
        None => raise BadWireType(0)
      }
    _ => ()
  }
  ignore(desc)
  writer.to_bytes()
}

///|
fn duration_bytes(
  desc : MessageDescriptor,
  value : Json,
) -> Bytes raise PbError {
  let writer = PbWriter::new()
  match value {
    String(text) => {
      guard text.length() > 1 && text[text.length() - 1] == 's' else {
        raise BadWireType(0)
      }
      let body = text.exact_view(start=0, end=text.length() - 1).to_owned()
      let (negative, digits) = if body.length() > 0 && body[0] == '-' {
        (true, body.exact_view(start=1, end=body.length()).to_owned())
      } else {
        (false, body)
      }
      let mut whole = digits
      let mut fraction_text = ""
      let dot = digits.find(".")
      if dot is Some(i) {
        ignore(i)
        let at = i
        whole = digits.exact_view(start=0, end=at).to_owned()
        fraction_text = digits
          .exact_view(start=at + 1, end=digits.length())
          .to_owned()
      }
      let seconds = match parse_i64(whole) {
        Some(n) => n
        None => 0L
      }
      let nanos = fraction_nanos(fraction_text)
      let sign = if negative { -1L } else { 1L }
      if seconds != 0L {
        writer.int64(1, sign * seconds)
      }
      if nanos != 0L {
        writer.int32(2, (sign * nanos).to_int())
      }
    }
    _ => ()
  }
  ignore(desc)
  writer.to_bytes()
}

///|
/// The nanoseconds a fraction's digits stand for, at however many digits were written.
fn fraction_nanos(text : String) -> Int64 {
  let mut value : Int64 = 0L
  let mut scale : Int64 = 1L
  for ch in text {
    if value < 100000000L {
      value = value * 10L + (ch.to_int() - 0x30).to_int64()
      scale = scale * 10L
    }
  }
  let mut nanos = value
  while scale < 1000000000L {
    nanos = nanos * 10L
    scale = scale * 10L
  }
  nanos
}

///|
fn field_mask_bytes(desc : MessageDescriptor, value : Json) -> Bytes {
  let writer = PbWriter::new()
  match value {
    String(text) =>
      if text.length() > 0 {
        for path in text.split(",") {
          writer.string_(1, snake_path(path.to_owned()))
        }
      }
    _ => ()
  }
  ignore(desc)
  writer.to_bytes()
}

///|
/// A field mask path in its wire spelling: each lowerCamelCase segment becomes snake_case.
fn snake_path(path : String) -> String {
  let out = []
  for segment in path.split(".") {
    let mut text = ""
    for ch in segment {
      let code = ch.to_int()
      if code >= 0x41 && code <= 0x5A {
        text = text + "_" + Int32::unsafe_to_char(code + 32).to_string()
      } else {
        text = text + ch.to_string()
      }
    }
    out.push(text)
  }
  out.join(".")
}

///|
fn Schema::struct_bytes(
  self : Schema,
  desc : MessageDescriptor,
  value : Json,
) -> Bytes raise PbError {
  let writer = PbWriter::new()
  match value {
    Object(members) =>
      for key, item in members {
        let entry = PbWriter::new()
        entry.string_(1, key)
        match self.messages.get(".google.protobuf.Value") {
          Some(value_desc) => {
            let inner = self.value_bytes(value_desc, item)
            entry.message_(2, inner)
          }
          None => ()
        }
        writer.message_(1, entry.to_bytes())
      }
    _ => ()
  }
  ignore(desc)
  writer.to_bytes()
}

///|
fn Schema::value_bytes(
  self : Schema,
  desc : MessageDescriptor,
  value : Json,
) -> Bytes raise PbError {
  let writer = PbWriter::new()
  match value {
    Null => writer.enum_(1, 0)
    True => writer.bool_(4, true)
    False => writer.bool_(4, false)
    Number(d, ..) => writer.double_(2, d)
    String(s) => writer.string_(3, s)
    Array(items) =>
      match self.messages.get(".google.protobuf.ListValue") {
        Some(list_desc) => {
          let inner = self.list_bytes(list_desc, Json::array(items))
          writer.message_(6, inner)
        }
        None => ()
      }
    Object(members) =>
      match self.messages.get(".google.protobuf.Struct") {
        Some(struct_desc) => {
          let inner = self.struct_bytes(struct_desc, Json::object(members))
          writer.message_(5, inner)
        }
        None => ()
      }
  }
  ignore(desc)
  writer.to_bytes()
}

///|
fn Schema::list_bytes(
  self : Schema,
  desc : MessageDescriptor,
  value : Json,
) -> Bytes raise PbError {
  let writer = PbWriter::new()
  match value {
    Array(items) =>
      match self.messages.get(".google.protobuf.Value") {
        Some(value_desc) =>
          for item in items {
            let inner = self.value_bytes(value_desc, item)
            writer.message_(1, inner)
          }
        None => ()
      }
    _ => ()
  }
  ignore(desc)
  writer.to_bytes()
}

///|
fn Schema::any_bytes(
  self : Schema,
  desc : MessageDescriptor,
  value : Json,
) -> Bytes raise PbError {
  let writer = PbWriter::new()
  match value {
    Object(members) => {
      let url = match members.get("@type") {
        Some(String(s)) => s
        _ => ""
      }
      writer.string_(1, url)
      let name = "." + last_segment_after_slash(url)
      match self.messages.get(name) {
        Some(inner) => {
          // The remaining members are the wrapped message's own fields.
          let rest : Map[String, Json] = Map([])
          for key, item in members {
            if key != "@type" {
              rest[key] = item
            }
          }
          let body = self.message_bytes(name, inner, Json::object(rest))
          if body.length() > 0 {
            writer.bytes_(2, body)
          }
        }
        None => ()
      }
    }
    _ => ()
  }
  ignore(desc)
  writer.to_bytes()
}

///|
/// An RFC 3339 timestamp as `(seconds since the epoch, nanoseconds)`.
fn parse_rfc3339(text : String) -> (Int64, Int64)? {
  // YYYY-MM-DDTHH:MM:SS
  if text.length() < 20 {
    return None
  }
  if text[4] != '-' || text[7] != '-' || (text[10] != 'T' && text[10] != 't') {
    return None
  }
  let year = digits_at(text, 0, 4)
  let month = digits_at(text, 5, 2)
  let day = digits_at(text, 8, 2)
  let hour = digits_at(text, 11, 2)
  let minute = digits_at(text, 14, 2)
  let second = digits_at(text, 17, 2)
  if year is None ||
    month is None ||
    day is None ||
    hour is None ||
    minute is None ||
    second is None {
    return None
  }
  let mut at = 19
  let mut nanos : Int64 = 0L
  if at < text.length() && text[at] == '.' {
    let start = at + 1
    let mut stop = start
    while stop < text.length() && is_digit(text[stop].to_int()) {
      stop = stop + 1
    }
    if stop == start {
      return None
    }
    nanos = fraction_nanos(text.exact_view(start~, end=stop).to_owned())
    at = stop
  }
  let mut offset : Int64 = 0L
  if at < text.length() {
    match text[at] {
      'Z' | 'z' => at = at + 1
      '+' | '-' => {
        let sign : Int64 = if text[at] == '+' { 1L } else { -1L }
        let oh = digits_at(text, at + 1, 2)
        let om = digits_at(text, at + 4, 2)
        if oh is None || om is None {
          return None
        }
        offset = sign * (oh.unwrap() * 3600L + om.unwrap() * 60L)
        at = at + 6
      }
      _ => return None
    }
  }
  if at != text.length() {
    return None
  }
  let seconds = days_from_civil(year.unwrap(), month.unwrap(), day.unwrap()) *
    86400L +
    hour.unwrap() * 3600L +
    minute.unwrap() * 60L +
    second.unwrap() -
    offset
  Some((seconds, nanos))
}

///|
fn is_digit(code : Int32) -> Bool {
  code >= 0x30 && code <= 0x39
}

///|
fn digits_at(text : String, start : Int32, width : Int32) -> Int64? {
  if start + width > text.length() {
    return None
  }
  let mut value : Int64 = 0L
  for i in start..<(start + width) {
    let ch = text[i]
    if !is_digit(ch.to_int()) {
      return None
    }
    value = value * 10L + (ch.to_int() - 0x30).to_int64()
  }
  Some(value)
}
