///|
/// A protobuf scalar a MoonBit type stands for.
priv enum Scalar {
  Str
  Raw
  Boolean
  I32
  I64
  U32
  U64
  F64
  F32
} derive(Eq)

///|
/// The protobuf type of a value: a scalar, or a message or an enum by its
/// MoonBit name.
priv enum Base {
  Scalar(Scalar)
  Message(String)
  Enum(String)
}

///|
/// How a field holds its values: once, optionally (proto3 `optional`), as a
/// list, or as a `map` keyed by a scalar of the given MoonBit type.
priv enum Card {
  Single
  Optional
  Repeated
  Keyed(Scalar, String)
} derive(Eq)

///|
fn scalar_of(ty : String) -> Scalar? {
  match ty {
    "String" => Some(Str)
    "Bytes" => Some(Raw)
    "Bool" => Some(Boolean)
    "Int" | "Int32" => Some(I32)
    "Int64" => Some(I64)
    "UInt" | "UInt32" => Some(U32)
    "UInt64" => Some(U64)
    "Double" => Some(F64)
    "Float" => Some(F32)
    _ => None
  }
}

///|
/// `T` out of `Name[T]`, or `None`.
fn inside(ty : StringView, name : String) -> String? {
  let ty = ty.trim(chars=" ")
  let open = name + "["
  if ty.has_prefix(open) && ty.has_suffix("]") {
    Some(
      ty
      .view(start_offset=open.length(), end_offset=ty.length() - 1)
      .trim(chars=" ")
      .to_owned(),
    )
  } else {
    None
  }
}

///|
/// `K` and `V` out of `K, V`, split at the comma outside any brackets.
fn pair(text : String) -> (String, String)? {
  let chars = text.to_array()
  let mut depth = 0
  for i, c in chars {
    match c {
      '[' | '(' => depth += 1
      ']' | ')' => depth -= 1
      ',' if depth == 0 => {
        let key = String::from_array(chars[:i]).trim(chars=" ").to_owned()
        let value = String::from_array(chars[i + 1:]).trim(chars=" ").to_owned()
        return Some((key, value))
      }
      _ => ()
    }
  }
  None
}

///|
/// A MoonBit type as its protobuf base and how it repeats; `None` for a type
/// protobuf has no field for. The element type, the value type of a map, is
/// returned alongside. A map key is a string, an integer or a bool, as the
/// protobuf language allows.
fn field_of(
  ty : String,
  messages : Map[String, String],
  enums : Map[String, String],
) -> (Base, Card, String)? {
  let ty = ty.trim(chars=" ").to_owned()
  let (inner, card) = if ty.has_suffix("?") {
    (ty.view(end_offset=ty.length() - 1).trim(chars=" ").to_owned(), Optional)
  } else if inside(ty, "Option") is Some(t) {
    (t, Optional)
  } else if inside(ty, "Array") is Some(t) {
    (t, Repeated)
  } else if inside(ty, "Map") is Some(kv) {
    guard pair(kv) is Some((k, v)) &&
      scalar_of(k) is Some(key) &&
      key is (Str | Boolean | I32 | I64 | U32 | U64) else {
      return None
    }
    (v, Keyed(key, k))
  } else {
    (ty, Single)
  }
  let base = match scalar_of(inner) {
    Some(s) => Scalar(s)
    None if messages.contains(inner) => Message(inner)
    None if enums.contains(inner) => Enum(inner)
    None => return None
  }
  Some((base, card, inner))
}

///|
/// The descriptor's `FieldType` for a base.
fn field_type(base : Base) -> String {
  match base {
    Scalar(Str) => "TypeString"
    Scalar(Raw) => "TypeBytes"
    Scalar(Boolean) => "TypeBool"
    Scalar(I32) => "TypeInt32"
    Scalar(I64) => "TypeInt64"
    Scalar(U32) => "TypeUint32"
    Scalar(U64) => "TypeUint64"
    Scalar(F64) => "TypeDouble"
    Scalar(F32) => "TypeFloat"
    Message(_) => "TypeMessage"
    Enum(_) => "TypeEnum"
  }
}

///|
/// The wire type a base is written with.
fn wire_of(base : Base) -> String {
  match base {
    Scalar(Str | Raw) | Message(_) => "LengthDelim"
    Scalar(F64) => "Fixed64"
    Scalar(F32) => "Fixed32"
    Scalar(_) | Enum(_) => "Varint"
  }
}

///|
/// Whether a repeated field of this base is written packed: the varint
/// scalars and enums. Doubles and floats go unpacked, which every parser reads
/// too.
fn packed(base : Base) -> Bool {
  base is (Scalar(Boolean | I32 | I64 | U32 | U64) | Enum(_))
}

///|
/// The call writing field `n` with value `e` on writer `w`.
fn write_call(base : Base, n : Int32, e : String) -> String {
  match base {
    Scalar(Str) => "w.string_(\{n}, \{e})"
    Scalar(Raw) => "w.bytes_(\{n}, \{e})"
    Scalar(Boolean) => "w.bool_(\{n}, \{e})"
    Scalar(I32) => "w.int32(\{n}, \{e})"
    Scalar(I64) => "w.int64(\{n}, \{e})"
    Scalar(U32) => "w.uint32(\{n}, \{e})"
    Scalar(U64) => "w.uint64(\{n}, \{e})"
    Scalar(F64) => "w.double_(\{n}, \{e})"
    Scalar(F32) => "w.float_(\{n}, \{e})"
    Message(_) => "w.message_(\{n}, @moonrpc.Message::encode(\{e}))"
    Enum(_) => "w.enum_(\{n}, @moonrpc.Enum::code(\{e}))"
  }
}

///|
/// The raw varint of a packed element `e` on writer `p`.
fn packed_write(base : Base, e : String) -> String {
  match base {
    Scalar(Boolean) => "p.write_varint(if \{e} { 1UL } else { 0UL })"
    Scalar(I32) => "p.write_varint(\{e}.to_int64().reinterpret_as_uint64())"
    Scalar(I64) => "p.write_varint(\{e}.reinterpret_as_uint64())"
    Scalar(U32) => "p.write_varint(\{e}.to_uint64())"
    Enum(_) =>
      "p.write_varint(@moonrpc.Enum::code(\{e}).to_int64().reinterpret_as_uint64())"
    _ => "p.write_varint(\{e})"
  }
}

///|
/// The expression reading one value of this base off reader `r`.
fn read_call(base : Base, r : String) -> String {
  match base {
    Scalar(Str) => "\{r}.read_string()"
    Scalar(Raw) => "\{r}.read_bytes()"
    Scalar(Boolean) => "\{r}.read_bool()"
    Scalar(I32) => "\{r}.read_int32()"
    Scalar(I64) => "\{r}.read_int64()"
    Scalar(U32) => "\{r}.read_uint32()"
    Scalar(U64) => "\{r}.read_uint64()"
    Scalar(F64) => "\{r}.read_double()"
    Scalar(F32) => "\{r}.read_float()"
    Message(_) => "@moonrpc.Message::decode(\{r}.read_len_delim())"
    Enum(_) => "@moonrpc.Enum::of(\{r}.read_int32())"
  }
}

///|
/// The value a field holds when the message does not carry it.
fn zero_of(base : Base) -> String {
  match base {
    Scalar(Str) => "\"\""
    Scalar(Raw) => "b\"\""
    Scalar(Boolean) => "false"
    Scalar(I32) => "0"
    Scalar(I64) => "0L"
    Scalar(U32) => "0U"
    Scalar(U64) => "0UL"
    Scalar(F64) => "0.0"
    Scalar(F32) => "(0.0 : Float)"
    Message(_) => "@moonrpc.Message::decode(b\"\")"
    Enum(_) => "@moonrpc.Enum::of(0)"
  }
}

///|
/// The test that `e` differs from the value a field leaves unwritten; `None`
/// for a message, which is written whenever it is there.
fn nonzero(base : Base, e : String) -> String? {
  match base {
    Message(_) => None
    Enum(_) => Some("@moonrpc.Enum::code(\{e}) != 0")
    Scalar(_) => Some("\{e} != \{zero_of(base)}")
  }
}

///|
/// `say_hello` as `SayHello`.
fn pascal(name : String) -> String {
  let out = StringBuilder()
  let mut up = true
  for c in name {
    if c == '_' {
      up = true
    } else {
      out.write_char(if up { c.to_ascii_uppercase() } else { c })
      up = false
    }
  }
  out.to_string()
}

///|
/// `InProgress` as `IN_PROGRESS`, and `HTTPError` as `HTTP_ERROR`.
fn upper_snake(name : String) -> String {
  let chars = name.to_array()
  let out = StringBuilder()
  for i, c in chars {
    if i > 0 && c.is_ascii_uppercase() {
      let before = chars[i - 1]
      let after_lower = i + 1 < chars.length() &&
        chars[i + 1].is_ascii_lowercase()
      if before.is_ascii_lowercase() ||
        before.is_ascii_digit() ||
        (before.is_ascii_uppercase() && after_lower) {
        out.write_char('_')
      }
    }
    out.write_char(c.to_ascii_uppercase())
  }
  out.to_string()
}

///|
fn quoted(text : String) -> String {
  @quote.string(text).to_string()
}
