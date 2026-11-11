// TJSONProtocol: Thrift's second wire format, the text one. A message is a JSON array
// `[1,"ping",1,7,{...}]`; a struct is an object keyed by field id whose every value is
// another object naming its own type, `{"1":{"str":"hi"}}`; a list is `["i32",2,1,2]` and a
// map `["str","i32",1,{"k":9}]`, with the element types in front.
//
// A text format needs two things a binary one does not: where the commas and colons go, and
// where a container ends. The first is a stack of contexts, as the reference implementation
// has. The second is here a count: a list knows how many elements it declared, so its `]` is
// written — and read — the moment the last element is, and a caller that never asks for the
// end of a list still gets a well-formed message. A struct has no count, so it ends where a
// reader sees `}` in front of the next field.

///|
/// Where a value is being written (or read): at the top, after a list's `[` and before its
/// first element, between a list's elements, after an object's `{` and before its first key,
/// between an object's members, and at the colon of a member.
priv enum Shape {
  Top
  ListFirst
  List
  ObjFirst
  ObjKey
  ObjValue
}

///|
/// What kind of container a closer counts.
priv enum Tally {
  /// A list or set, one element at a time.
  Items
  /// A map's entry object, two values per entry.
  Entries
}

///|
/// A container that ends itself once its declared contents have gone by.
priv struct Closer {
  depth : Int32
  tally : Tally
  mut remaining : Int32
}

///|
/// A JSON-protocol reader and writer over one message.
pub struct Json {
  priv mut data : Bytes
  priv mut off : Int32
  priv mut out : @buffer.Buffer
  // The contexts of what is being written and what is being read. They are separate because a
  // protocol object writes a reply while the request it read is still on its stack: the
  // processor reads a call and answers it without a second `reset`.
  priv mut dump : Array[Shape]
  priv mut parse : Array[Shape]
  priv mut dump_closers : Array[Closer]
  priv mut parse_closers : Array[Closer]
  // The `{`-objects a field opened and whose `}` is still owed, as the depth each was opened
  // at. The contract has no `write_field_end`, so the close goes out with whatever comes next:
  // the following field, or the end of the struct. The depth is what keeps a field of a nested
  // struct from closing its grandparent's field — only the object at the current depth is the
  // one the next field ends. The reading side is the same, one value behind.
  priv mut open_fields : Array[Int32]
  priv mut read_fields : Array[Int32]
}

///|
/// The version word a JSON message opens with.
let json_version : Int32 = 1

///|
pub fn Json::new(input : Bytes) -> Json {
  {
    data: input,
    off: 0,
    out: @buffer.Buffer(),
    dump: [Top],
    parse: [Top],
    dump_closers: [],
    parse_closers: [],
    open_fields: [],
    read_fields: [],
  }
}

///|
pub impl Protocol for Json with fn reset(self, input) {
  self.data = input
  self.off = 0
  self.out = @buffer.Buffer()
  self.dump = [Top]
  self.parse = [Top]
  self.dump_closers = []
  self.parse_closers = []
  self.open_fields = []
  self.read_fields = []
}

///|
pub impl Protocol for Json with fn output(self) {
  self.out.to_bytes()
}

// -- writing ----------------------------------------------------------------

///|
/// The punctuation in front of a value: a comma between list elements or object members, a
/// colon before a member's value.
fn Json::pre(self : Json) -> Unit {
  match self.dump[self.dump.length() - 1] {
    List | ObjKey => self.out.write_byte(b',')
    ObjValue => self.out.write_byte(b':')
    _ => ()
  }
}

///|
/// Move the writer on past the value it just wrote, and close whatever that value completed.
fn Json::post(self : Json) -> Unit {
  advance(self.dump)
  self.close_finished()
}

///|
fn advance(stack : Array[Shape]) -> Unit {
  let last = stack.length() - 1
  match stack[last] {
    ListFirst => stack[last] = List
    ObjFirst | ObjKey => stack[last] = ObjValue
    ObjValue => stack[last] = ObjKey
    _ => ()
  }
}

///|
/// Count the value that just went out against the container it belongs to, and write the end
/// of every container whose last value that was.
fn Json::close_finished(self : Json) -> Unit {
  for ;; {
    let closer = match self.dump_closers.last() {
      Some(c) => c
      None => break
    }
    if closer.depth != self.dump.length() - 1 {
      break
    }
    let arrived = match closer.tally {
      Items => self.dump[self.dump.length() - 1] is List
      Entries => self.dump[self.dump.length() - 1] is ObjKey
    }
    if !arrived {
      break
    }
    closer.remaining = closer.remaining - 1
    if closer.remaining > 0 {
      break
    }
    ignore(self.dump_closers.pop())
    match closer.tally {
      Items => {
        self.out.write_byte(b']')
        ignore(self.dump.pop())
      }
      Entries => {
        self.out.write_byte(b'}')
        ignore(self.dump.pop())
        self.out.write_byte(b']')
        ignore(self.dump.pop())
      }
    }
    advance(self.dump)
  }
}

///|
fn Json::begin_object(self : Json) -> Unit {
  self.pre()
  self.out.write_byte(b'{')
  self.dump.push(ObjFirst)
}

///|
fn Json::end_object(self : Json) -> Unit {
  self.out.write_byte(b'}')
  ignore(self.dump.pop())
  self.post()
}

///|
fn Json::in_key(self : Json) -> Bool {
  match self.dump[self.dump.length() - 1] {
    ObjFirst | ObjKey => true
    _ => false
  }
}

///|
fn Json::value_i64(self : Json, value : Int64) -> Unit {
  self.pre()
  // A member's key is a string in JSON even when the protocol makes it a number, so a field id
  // and an integer map key are written quoted.
  if self.in_key() {
    self.out.write_byte(b'"')
    self.out.write_string_utf8(value.to_string())
    self.out.write_byte(b'"')
  } else {
    self.out.write_string_utf8(value.to_string())
  }
  self.post()
}

///|
/// A quoted JSON string, escaped the way the reference implementation escapes it.
fn Json::quoted(self : Json, text : String) -> Unit {
  self.out.write_byte(b'"')
  self.escape(text)
  self.out.write_byte(b'"')
}

///|
/// A string as a JSON string body. `<`, `>` and `&` are escaped because the reference
/// implementation escapes them, and a message carrying one has to be byte-identical to its
/// output for the two to be compared.
fn Json::escape(self : Json, text : String) -> Unit {
  for ch in text {
    match ch {
      '"' => self.out.write_string_utf8("\\\"")
      '\\' => self.out.write_string_utf8("\\\\")
      '\n' => self.out.write_string_utf8("\\n")
      '\r' => self.out.write_string_utf8("\\r")
      '\t' => self.out.write_string_utf8("\\t")
      '\u{08}' => self.out.write_string_utf8("\\b")
      '\u{0C}' => self.out.write_string_utf8("\\f")
      '<' => self.out.write_string_utf8("\\u003c")
      '>' => self.out.write_string_utf8("\\u003e")
      '&' => self.out.write_string_utf8("\\u0026")
      '\u{2028}' => self.out.write_string_utf8("\\u2028")
      '\u{2029}' => self.out.write_string_utf8("\\u2029")
      c =>
        if c.to_int() < 0x20 {
          self.out.write_string_utf8(six_digit_escape(c))
        } else {
          self.out.write_char_utf8(c)
        }
    }
  }
}

///|
/// `\u001f`-style for a control character.
fn six_digit_escape(ch : Char) -> String {
  let value = ch.to_int()
  let hi = hex_char((value >> 4) & 0xF)
  let lo = hex_char(value & 0xF)
  "\\u00" + hi.to_string() + lo.to_string()
}

///|
/// A type's name in the protocol's vocabulary.
fn type_name(type_ : Int32) -> String {
  match type_ {
    t if t == type_bool => "tf"
    t if t == type_byte => "i8"
    t if t == type_i16 => "i16"
    t if t == type_i32 => "i32"
    t if t == type_i64 => "i64"
    t if t == type_double => "dbl"
    t if t == type_string => "str"
    t if t == type_struct => "rec"
    t if t == type_map => "map"
    t if t == type_set => "set"
    t if t == type_list => "lst"
    t if t == type_uuid => "uid"
    other =>
      abort("this protocol does not define the type " + other.to_string())
  }
}

///|
/// The type id a protocol name stands for.
fn type_of_name(name : String) -> Int32 raise ThriftError {
  match name {
    "tf" => type_bool
    "i8" => type_byte
    "i16" => type_i16
    "i32" => type_i32
    "i64" => type_i64
    "dbl" => type_double
    "str" => type_string
    "rec" => type_struct
    "map" => type_map
    "set" => type_set
    "lst" => type_list
    "uid" => type_uuid
    other =>
      raise Unsupported("this protocol does not define the type " + other)
  }
}

///|
/// Close the field object still owed at this depth, if any: the `}` after a field's value.
fn Json::close_field(self : Json) -> Unit {
  match self.open_fields.last() {
    Some(depth) if depth == self.dump.length() => {
      ignore(self.open_fields.pop())
      self.end_object()
    }
    _ => ()
  }
}

///|
pub impl Protocol for Json with fn write_message_begin(self, name, kind, seqid) {
  self.pre()
  self.out.write_byte(b'[')
  self.dump.push(ListFirst)
  self.value_i64(json_version.to_int64())
  self.pre()
  self.quoted(name)
  self.post()
  self.value_i64(kind.to_int64())
  self.value_i64(seqid.to_int64())
}

///|
pub impl Protocol for Json with fn write_message_end(self) {
  self.out.write_byte(b']')
  ignore(self.dump.pop())
  self.post()
}

///|
pub impl Protocol for Json with fn write_struct_begin(self, name) {
  ignore(name)
  self.begin_object()
}

///|
pub impl Protocol for Json with fn write_struct_end(self) {
  self.close_field()
  self.end_object()
}

///|
pub impl Protocol for Json with fn write_field_begin(self, type_, id) {
  self.close_field()
  self.value_i64(id.to_int64())
  self.begin_object()
  self.pre()
  self.quoted(type_name(type_))
  self.post()
  self.open_fields.push(self.dump.length())
}

///|
pub impl Protocol for Json with fn write_field_stop(self) {
  ignore(self)
}

///|
pub impl Protocol for Json with fn write_bool(self, value) {
  self.value_i64(if value { 1L } else { 0L })
}

///|
pub impl Protocol for Json with fn write_byte(self, value) {
  self.value_i64(value.to_int64())
}

///|
pub impl Protocol for Json with fn write_i16(self, value) {
  self.value_i64(value.to_int64())
}

///|
pub impl Protocol for Json with fn write_i32(self, value) {
  self.value_i64(value.to_int64())
}

///|
pub impl Protocol for Json with fn write_i64(self, value) {
  self.value_i64(value)
}

///|
pub impl Protocol for Json with fn write_double(self, value) {
  self.pre()
  // A JSON number has no spelling for the three values IEEE 754 has and it does not, so the
  // protocol quotes them, as the reference implementation does.
  if value.is_nan() {
    self.quoted("NaN")
  } else if value == @double.infinity {
    self.quoted("Infinity")
  } else if value == @double.neg_infinity {
    self.quoted("-Infinity")
  } else {
    self.out.write_string_utf8(value.to_string())
  }
  self.post()
}

///|
pub impl Protocol for Json with fn write_string(self, value) {
  self.pre()
  self.quoted(value)
  self.post()
}

///|
pub impl Protocol for Json with fn write_bytes(self, body) {
  self.pre()
  self.quoted(@base64.encode(body[:]))
  self.post()
}

///|
/// A uuid as the sixteen bytes it is, written as the canonical `8-4-4-4-12` text: the
/// reference implementation writes that form rather than base64.
pub impl Protocol for Json with fn write_uuid(self, body) {
  if body.length() != 16 {
    abort("a uuid is sixteen bytes")
  }
  self.pre()
  self.quoted(uuid_text(body))
  self.post()
}

///|
fn uuid_text(body : Bytes) -> String {
  let out = StringBuilder()
  for i in 0..<16 {
    if i == 4 || i == 6 || i == 8 || i == 10 {
      out.write_char('-')
    }
    let byte = body[i].to_int()
    out.write_char(hex_char((byte >> 4) & 0xF))
    out.write_char(hex_char(byte & 0xF))
  }
  out.to_string()
}

///|
/// One hexadecimal digit as a character.
fn hex_char(value : Int32) -> Char {
  if value < 10 {
    Int32::unsafe_to_char(0x30 + value)
  } else {
    Int32::unsafe_to_char(0x61 + value - 10)
  }
}

///|
pub impl Protocol for Json with fn write_list_begin(self, elem, size) {
  self.pre()
  self.out.write_byte(b'[')
  self.dump.push(ListFirst)
  self.pre()
  self.quoted(type_name(elem))
  self.post()
  self.value_i64(size.to_int64())
  if size > 0 {
    self.dump_closers.push({
      depth: self.dump.length() - 1,
      tally: Items,
      remaining: size,
    })
  } else {
    self.out.write_byte(b']')
    ignore(self.dump.pop())
    self.post()
  }
}

///|
pub impl Protocol for Json with fn write_set_begin(self, elem, size) {
  self.write_list_begin(elem, size)
}

///|
/// A map is a list of two type names and a size, and then an object holding the entries.
pub impl Protocol for Json with fn write_map_begin(self, key, value, size) {
  self.pre()
  self.out.write_byte(b'[')
  self.dump.push(ListFirst)
  self.pre()
  self.quoted(type_name(key))
  self.post()
  self.pre()
  self.quoted(type_name(value))
  self.post()
  self.value_i64(size.to_int64())
  self.begin_object()
  if size > 0 {
    self.dump_closers.push({
      depth: self.dump.length() - 1,
      tally: Entries,
      // One per entry: a key and its value arrive as a pair, and only the value counts.
      remaining: size,
    })
  } else {
    // An empty map still carries its entry object: `["str","i32",0,{}]`.
    self.end_object()
    self.out.write_byte(b']')
    ignore(self.dump.pop())
    self.post()
  }
}

// -- reading ----------------------------------------------------------------

///|
/// Step over the whitespace between values.
fn Json::skip_space(self : Json) -> Unit {
  while self.off < self.data.length() {
    let byte = self.data[self.off]
    if byte == b' ' || byte == b'\t' || byte == b'\n' || byte == b'\r' {
      self.off = self.off + 1
    } else {
      break
    }
  }
}

///|
fn Json::peek(self : Json) -> Byte? {
  self.skip_space()
  if self.off < self.data.length() {
    Some(self.data[self.off])
  } else {
    None
  }
}

///|
fn Json::expect(self : Json, byte : Byte) -> Unit raise ThriftError {
  self.skip_space()
  if self.off >= self.data.length() {
    raise Truncated
  }
  if self.data[self.off] != byte {
    raise Malformed(
      "expected " + byte.to_int().to_string() + " at " + self.off.to_string(),
    )
  }
  self.off = self.off + 1
}

///|
/// The punctuation before a value of the innermost container.
fn Json::read_pre(self : Json) -> Unit raise ThriftError {
  self.skip_space()
  match self.parse[self.parse.length() - 1] {
    List | ObjKey =>
      match self.peek() {
        Some(b']') | Some(b'}') => ()
        Some(b',') => {
          self.off = self.off + 1
          self.skip_space()
        }
        Some(_) =>
          raise Malformed("expected a separator at " + self.off.to_string())
        None => raise Truncated
      }
    ObjValue => self.expect(b':')
    _ => ()
  }
}

///|
fn Json::read_post(self : Json) -> Unit raise ThriftError {
  advance(self.parse)
  self.read_close_finished()
}

///|
/// Count the value that just came in against the container it belongs to, and consume the end
/// of every container whose last value that was.
fn Json::read_close_finished(self : Json) -> Unit raise ThriftError {
  for ;; {
    let closer = match self.parse_closers.last() {
      None => break
      Some(c) => c
    }
    if closer.depth != self.parse.length() - 1 {
      break
    }
    let arrived = match closer.tally {
      Items => self.parse[self.parse.length() - 1] is List
      Entries => self.parse[self.parse.length() - 1] is ObjKey
    }
    if !arrived {
      break
    }
    closer.remaining = closer.remaining - 1
    if closer.remaining > 0 {
      break
    }
    ignore(self.parse_closers.pop())
    match closer.tally {
      Items => {
        self.expect(b']')
        ignore(self.parse.pop())
      }
      Entries => {
        self.expect(b'}')
        ignore(self.parse.pop())
        self.expect(b']')
        ignore(self.parse.pop())
      }
    }
    advance(self.parse)
  }
}

///|
fn Json::begin_read_object(self : Json) -> Unit raise ThriftError {
  self.read_pre()
  self.expect(b'{')
  self.parse.push(ObjFirst)
}

///|
fn Json::end_read_object(self : Json) -> Unit raise ThriftError {
  self.expect(b'}')
  ignore(self.parse.pop())
  self.read_post()
}

///|
/// The closing `}` of the field object a value was read out of, when the reader is back at the
/// depth that object was opened at.
fn Json::close_read_field(self : Json) -> Unit raise ThriftError {
  match self.read_fields.last() {
    Some(depth) if depth == self.parse.length() => {
      ignore(self.read_fields.pop())
      self.end_read_object()
    }
    _ => ()
  }
}

///|
/// A string as a value: the punctuation before it, its contents, and the step past it.
fn Json::read_text(self : Json) -> String raise ThriftError {
  self.read_pre()
  let text = self.token_text()
  self.read_post()
  text
}

///|
/// A string's contents, from the `"` at the cursor to its matching `"`, with no punctuation
/// before it and no step past it — the form the type names in a container's header take.
fn Json::token_text(self : Json) -> String raise ThriftError {
  self.skip_space()
  if self.off >= self.data.length() {
    raise Truncated
  }
  if self.data[self.off] != b'"' {
    // `null` is what an absent string reads as in the reference implementation.
    if self.data[self.off] == b'n' {
      if self.off + 4 > self.data.length() {
        raise Truncated
      }
      self.off = self.off + 4
      return ""
    }
    raise Malformed("expected a string at " + self.off.to_string())
  }
  self.off = self.off + 1
  let out = @buffer.Buffer()
  for ;; {
    if self.off >= self.data.length() {
      raise Truncated
    }
    let byte = self.data[self.off]
    self.off = self.off + 1
    if byte == b'"' {
      break
    }
    if byte != b'\\' {
      out.write_byte(byte)
      continue
    }
    if self.off >= self.data.length() {
      raise Truncated
    }
    let escape = self.data[self.off]
    self.off = self.off + 1
    match escape {
      b'"' => out.write_byte(b'"')
      b'\\' => out.write_byte(b'\\')
      b'/' => out.write_byte(b'/')
      b'b' => out.write_byte(8)
      b'f' => out.write_byte(12)
      b'n' => out.write_byte(b'\n')
      b'r' => out.write_byte(b'\r')
      b't' => out.write_byte(b'\t')
      b'u' => {
        let mut value = 0
        for _ in 0..<4 {
          if self.off >= self.data.length() {
            raise Truncated
          }
          let digit = hex_digit(self.data[self.off])
          self.off = self.off + 1
          value = (value << 4) | digit
        }
        // A character outside the basic plane arrives as a surrogate pair: two escapes.
        if value >= 0xD800 && value <= 0xDBFF {
          if self.off + 6 <= self.data.length() &&
            self.data[self.off] == b'\\' &&
            self.data[self.off + 1] == b'u' {
            self.off = self.off + 2
            let mut low = 0
            for _ in 0..<4 {
              low = (low << 4) | hex_digit(self.data[self.off])
              self.off = self.off + 1
            }
            if low >= 0xDC00 && low <= 0xDFFF {
              let code = 0x10000 + ((value - 0xD800) << 10) + (low - 0xDC00)
              out.write_bytes(
                @utf8.encode(Int32::unsafe_to_char(code).to_string()),
              )
            }
          }
        } else {
          out.write_bytes(
            @utf8.encode(Int32::unsafe_to_char(value).to_string()),
          )
        }
      }
      other =>
        raise Malformed(
          "this protocol does not define the escape " +
          other.to_int().to_string(),
        )
    }
  }
  @utf8.decode_lossy(out.to_bytes())
}

///|
fn hex_digit(byte : Byte) -> Int32 raise ThriftError {
  let value = byte.to_int()
  if value >= 0x30 && value <= 0x39 {
    value - 0x30
  } else if value >= 0x61 && value <= 0x66 {
    value - 0x61 + 10
  } else if value >= 0x41 && value <= 0x46 {
    value - 0x41 + 10
  } else {
    raise Malformed("not a hexadecimal digit")
  }
}

///|
/// An integer as a value.
fn Json::read_int(self : Json) -> Int64 raise ThriftError {
  self.read_pre()
  let value = self.token_int()
  self.read_post()
  value
}

///|
/// An integer the protocol writes bare in a value position and quoted where JSON demands a
/// string — a field id, or a map's key.
fn Json::token_int(self : Json) -> Int64 raise ThriftError {
  self.skip_space()
  if self.off >= self.data.length() {
    raise Truncated
  }
  let quoted = self.data[self.off] == b'"'
  if quoted {
    self.off = self.off + 1
  }
  let start = self.off
  while self.off < self.data.length() {
    let byte = self.data[self.off]
    if byte == b'-' ||
      byte == b'+' ||
      (byte >= b'0' && byte <= b'9') ||
      byte == b'.' ||
      byte == b'e' ||
      byte == b'E' {
      self.off = self.off + 1
    } else {
      break
    }
  }
  if self.off == start {
    raise Malformed("expected a number at " + start.to_string())
  }
  let text = @utf8.decode_lossy(self.data[start:self.off])
  if quoted {
    if self.off >= self.data.length() {
      raise Truncated
    }
    if self.data[self.off] != b'"' {
      raise Malformed(
        "expected the end of a quoted number at " + self.off.to_string(),
      )
    }
    self.off = self.off + 1
  }
  @string.parse_int64(text[:]) catch {
    _ => raise Malformed("not an integer: " + text)
  }
}

///|
pub impl Protocol for Json with fn read_message_begin(self) {
  self.read_pre()
  self.expect(b'[')
  self.parse.push(ListFirst)
  let version = self.read_int().to_int()
  if version != json_version {
    raise BadVersion(version)
  }
  let name = self.read_text()
  let kind = self.read_int().to_int()
  let seqid = self.read_int().to_int()
  (name, kind, seqid)
}

///|
pub impl Protocol for Json with fn read_message_end(self) {
  self.expect(b']')
  ignore(self.parse.pop())
  self.read_post()
}

///|
pub impl Protocol for Json with fn read_struct_begin(self) {
  self.begin_read_object()
}

///|
pub impl Protocol for Json with fn consumed(self) {
  self.off
}

///|
/// Nothing to do: the `read_field_begin` that reported the end of this struct has already
/// consumed its `}`. A caller that still asks for the end finds the stream where it belongs
/// rather than one byte past it.
pub impl Protocol for Json with fn read_struct_end(self) {
  ignore(self)
}

///|
pub impl Protocol for Json with fn read_field_begin(self) {
  self.close_read_field()
  match self.peek() {
    None => raise Truncated
    Some(b'}') => {
      // The end of this struct: its `}` goes with the report, so the enclosing container — a
      // field object, a list, or the message itself — is where the cursor now stands.
      self.expect(b'}')
      ignore(self.parse.pop())
      self.read_post()
      (type_stop, 0)
    }
    Some(_) => {
      self.read_pre()
      let id = self.token_int().to_int()
      self.read_post()
      self.begin_read_object()
      let name = self.token_text()
      self.read_post()
      let type_ = type_of_name(name)
      self.read_fields.push(self.parse.length())
      (type_, id)
    }
  }
}

///|
pub impl Protocol for Json with fn read_bool(self) {
  self.read_int() != 0L
}

///|
pub impl Protocol for Json with fn read_byte(self) {
  self.read_int().to_int()
}

///|
pub impl Protocol for Json with fn read_i16(self) {
  self.read_int().to_int()
}

///|
pub impl Protocol for Json with fn read_i32(self) {
  self.read_int().to_int()
}

///|
pub impl Protocol for Json with fn read_i64(self) {
  self.read_int()
}

///|
pub impl Protocol for Json with fn read_double(self) {
  self.read_pre()
  if self.peek() == Some(b'"') {
    self.off = self.off + 1
    let start = self.off
    while self.off < self.data.length() && self.data[self.off] != b'"' {
      self.off = self.off + 1
    }
    if self.off >= self.data.length() {
      raise Truncated
    }
    let text = @utf8.decode_lossy(self.data[start:self.off])
    self.off = self.off + 1
    self.read_post()
    return match text {
      "NaN" => @double.not_a_number
      "Infinity" => @double.infinity
      "-Infinity" => @double.neg_infinity
      other =>
        raise Malformed("this protocol does not define the double " + other)
    }
  }
  let start = self.off
  while self.off < self.data.length() {
    let byte = self.data[self.off]
    if (byte >= b'0' && byte <= b'9') ||
      byte == b'-' ||
      byte == b'+' ||
      byte == b'.' ||
      byte == b'e' ||
      byte == b'E' {
      self.off = self.off + 1
    } else {
      break
    }
  }
  let text = @utf8.decode_lossy(self.data[start:self.off])
  self.read_post()
  @string.parse_double(text[:]) catch {
    _ => raise Malformed("not a double: " + text)
  }
}

///|
pub impl Protocol for Json with fn read_string(self) {
  self.read_text()
}

///|
pub impl Protocol for Json with fn read_bytes(self) {
  let text = self.read_text()
  @base64.decode(text[:]) catch {
    _ => raise Malformed("not base64")
  }
}

///|
/// Sixteen bytes from the canonical text form.
pub impl Protocol for Json with fn read_uuid(self) {
  let text = self.read_text()
  if text.length() != 36 {
    raise Malformed("a uuid is thirty-six characters")
  }
  let out = Array::make(16, b'\x00')
  let mut at = 0
  let mut i = 0
  while i < 36 {
    if i == 8 || i == 13 || i == 18 || i == 23 {
      if text[i] != '-' {
        raise Malformed("a uuid is dashed every four bytes")
      }
      i = i + 1
      continue
    }
    let hi = hex_of(text[i].to_int())
    let lo = hex_of(text[i + 1].to_int())
    out[at] = ((hi << 4) | lo).to_byte()
    at = at + 1
    i = i + 2
  }
  Bytes::from_array(out)
}

///|
fn hex_of(value : Int32) -> Int32 raise ThriftError {
  if value >= 0x30 && value <= 0x39 {
    value - 0x30
  } else if value >= 0x61 && value <= 0x66 {
    value - 0x61 + 10
  } else if value >= 0x41 && value <= 0x46 {
    value - 0x41 + 10
  } else {
    raise Malformed("not a hexadecimal digit")
  }
}

///|
/// The comma between two entries of a container's own header, which is read before its element
/// context opens and so has no context to put the comma in.
fn Json::comma(self : Json) -> Unit raise ThriftError {
  self.skip_space()
  if self.off >= self.data.length() {
    raise Truncated
  }
  if self.data[self.off] != b',' {
    raise Malformed("expected a comma at " + self.off.to_string())
  }
  self.off = self.off + 1
}

///|
/// `["type",size,` — the type name and the count are read before the element context opens, so
/// that only the elements themselves count towards the container's own end.
fn Json::begin_counted(self : Json) -> (Int32, Int32) raise ThriftError {
  self.read_pre()
  self.expect(b'[')
  let type_ = type_of_name(self.token_text())
  self.comma()
  let size = self.token_int().to_int()
  if size > 0 {
    // The comma between the count and the first element is part of the header: the element
    // context opens after it, so nothing would put it there.
    self.comma()
  }
  (type_, size)
}

///|
pub impl Protocol for Json with fn read_list_begin(self) {
  let (type_, size) = self.begin_counted()
  if size == 0 {
    self.expect(b']')
    self.read_post()
  } else {
    self.parse.push(ListFirst)
    self.parse_closers.push({
      depth: self.parse.length() - 1,
      tally: Items,
      remaining: size,
    })
  }
  (type_, size)
}

///|
pub impl Protocol for Json with fn read_set_begin(self) {
  self.read_list_begin()
}

///|
pub impl Protocol for Json with fn read_map_begin(self) {
  self.read_pre()
  self.expect(b'[')
  let key = type_of_name(self.token_text())
  self.comma()
  let value = type_of_name(self.token_text())
  self.comma()
  let size = self.token_int().to_int()
  self.comma()
  self.expect(b'{')
  if size == 0 {
    self.expect(b'}')
    self.expect(b']')
    self.read_post()
  } else {
    // The map's own `[`, then the object its entries live in: the two contexts the close has to
    // unwind, in the order they were entered.
    self.parse.push(ListFirst)
    self.parse.push(ObjFirst)
    self.parse_closers.push({
      depth: self.parse.length() - 1,
      tally: Entries,
      // One per entry: a key and its value arrive as a pair, and only the value counts.
      remaining: size,
    })
  }
  (key, value, size)
}

///|
pub extend Json with Protocol::{
  reset,
  output,
  read_bytes,
  write_bytes,
  read_message_begin,
  read_message_end,
  write_message_begin,
  write_message_end,
  consumed,
  read_struct_begin,
  read_struct_end,
  write_struct_begin,
  write_struct_end,
  read_field_begin,
  write_field_begin,
  write_field_stop,
  read_bool,
  read_byte,
  read_i16,
  read_i32,
  read_i64,
  read_double,
  read_string,
  read_uuid,
  read_list_begin,
  read_set_begin,
  read_map_begin,
  write_bool,
  write_byte,
  write_i16,
  write_i32,
  write_i64,
  write_double,
  write_string,
  write_uuid,
  write_list_begin,
  write_set_begin,
  write_map_begin,
}
