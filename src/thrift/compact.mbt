// TCompactProtocol: the same messages in fewer bytes. Field ids travel as a delta from
// the previous field when the jump fits in four bits, integers are zigzag varints, a
// boolean's value rides in its field header, and a double is little-endian — the one
// place this protocol and TBinaryProtocol disagree on byte order.

///|
let compact_protocol_id : Int32 = 0x82

///|
let compact_version : Int32 = 1

///|
let compact_true : Int32 = 0x01

///|
let compact_false : Int32 = 0x02

///|
let compact_byte : Int32 = 0x03

///|
let compact_i16 : Int32 = 0x04

///|
let compact_i32 : Int32 = 0x05

///|
let compact_i64 : Int32 = 0x06

///|
let compact_double : Int32 = 0x07

///|
let compact_binary : Int32 = 0x08

///|
let compact_list : Int32 = 0x09

///|
let compact_set : Int32 = 0x0A

///|
let compact_map : Int32 = 0x0B

///|
let compact_struct : Int32 = 0x0C

///|
let compact_uuid : Int32 = 0x0D

///|
fn compact_of(type_ : Int32) -> Int32 {
  match type_ {
    t if t == type_bool => compact_true
    t if t == type_byte => compact_byte
    t if t == type_i16 => compact_i16
    t if t == type_i32 => compact_i32
    t if t == type_i64 => compact_i64
    t if t == type_double => compact_double
    t if t == type_string => compact_binary
    t if t == type_list => compact_list
    t if t == type_set => compact_set
    t if t == type_map => compact_map
    t if t == type_struct => compact_struct
    t if t == type_uuid => compact_uuid
    _ => type_stop
  }
}

///|
fn type_of(compact : Int32) -> Int32 raise ThriftError {
  match compact & 0x0F {
    0x00 => type_stop
    0x01 | 0x02 => type_bool
    0x03 => type_byte
    0x04 => type_i16
    0x05 => type_i32
    0x06 => type_i64
    0x07 => type_double
    0x08 => type_string
    0x09 => type_list
    0x0A => type_set
    0x0B => type_map
    0x0C => type_struct
    0x0D => type_uuid
    other => raise BadType(other)
  }
}

///|
/// A compact-protocol reader and writer over one message.
pub struct Compact {
  mut data : Bytes
  mut off : Int32
  mut out : @buffer.Buffer
  // The field id a delta counts from, saved and restored around a struct.
  mut last_field : Int32
  mut field_stack : Array[Int32]
  // A boolean field carries its value in the header, so the header is written when the
  // value is, and the value is remembered when the header is read.
  mut pending_field : Bool
  mut pending_id : Int32
  mut bool_value : Bool
  mut bool_ready : Bool
}

///|
pub fn Compact::new(input : Bytes) -> Compact {
  {
    data: input,
    off: 0,
    out: @buffer.Buffer(),
    last_field: 0,
    field_stack: [],
    pending_field: false,
    pending_id: 0,
    bool_value: false,
    bool_ready: false,
  }
}

///|
/// Whether the reader has consumed every octet it was given, which is how a frame's
/// padding is told from another field.
pub fn Compact::eof(self : Compact) -> Bool {
  self.off >= self.data.length()
}

///|
fn Compact::need(self : Compact, n : Int32) -> Unit raise ThriftError {
  if n < 0 || self.off + n > self.data.length() {
    raise Truncated
  }
}

///|
fn Compact::read_raw_byte(self : Compact) -> Int32 raise ThriftError {
  self.need(1)
  let value = self.data[self.off].to_int()
  self.off = self.off + 1
  value
}

///|
fn Compact::write_varint(self : Compact, value : Int64) -> Unit {
  // The value is non-negative, so an arithmetic shift here is a logical one.
  let mut v = value
  while v >= 0x80L {
    self.write_byte((v & 0x7FL).to_int() | 0x80)
    v = v >> 7
  }
  self.write_byte(v.to_int())
}

///|
fn Compact::read_varint(self : Compact) -> Int64 raise ThriftError {
  let mut result = 0L
  let mut shift = 0
  for _ in 0..<10 {
    let b = self.read_raw_byte()
    result = result | ((b & 0x7F).to_int64() << shift)
    if (b & 0x80) == 0 {
      return result
    }
    shift = shift + 7
  }
  raise BadType(-1)
}

///|
fn zigzag32(value : Int32) -> Int64 {
  let wide = value.to_int64()
  (wide << 1) ^ (wide >> 63)
}

///|
fn unzigzag(value : Int64) -> Int32 {
  let magnitude = (value >> 1) ^ -(value & 1L)
  to_i32(magnitude)
}

///|
fn to_i32(value : Int64) -> Int32 {
  let bits = value & 0xFFFFFFFFL
  if bits >= 0x80000000L {
    (bits - 0x100000000L).to_int()
  } else {
    bits.to_int()
  }
}

///|
fn Compact::write_field_header(
  self : Compact,
  compact_type : Int32,
  id : Int32,
) -> Unit {
  let delta = id - self.last_field
  if delta > 0 && delta <= 15 {
    self.write_byte((delta << 4) | compact_type)
  } else {
    self.write_byte(compact_type)
    self.write_varint(zigzag32(id))
  }
  self.last_field = id
}

///|

///|
pub impl Protocol for Compact with fn reset(self, input) {
  self.data = input
  self.off = 0
  self.out = @buffer.Buffer()
  self.last_field = 0
  self.field_stack = []
  self.pending_field = false
  self.pending_id = 0
  self.bool_value = false
  self.bool_ready = false
}

///|
pub impl Protocol for Compact with fn output(self) {
  self.out.to_bytes()
}

///|
pub impl Protocol for Compact with fn write_byte(self, value) {
  self.out.write_byte((value & 0xFF).to_byte())
}

///|
pub impl Protocol for Compact with fn read_byte(self) {
  self.read_raw_byte()
}

///|
pub impl Protocol for Compact with fn write_i16(self, value) {
  self.write_varint(zigzag32(value))
}

///|
pub impl Protocol for Compact with fn read_i16(self) {
  unzigzag(self.read_varint())
}

///|
pub impl Protocol for Compact with fn write_i32(self, value) {
  self.write_varint(zigzag32(value))
}

///|
pub impl Protocol for Compact with fn read_i32(self) {
  unzigzag(self.read_varint())
}

///|
pub impl Protocol for Compact with fn write_i64(self, value) {
  let zz = (value << 1) ^ (value >> 63)
  self.write_varint(zz)
}

///|
pub impl Protocol for Compact with fn read_i64(self) {
  let zz = self.read_varint()
  (zz >> 1) ^ -(zz & 1L)
}

///|
pub impl Protocol for Compact with fn write_bool(self, value) {
  let compact_type = if value { compact_true } else { compact_false }
  if self.pending_field {
    self.pending_field = false
    self.write_field_header(compact_type, self.pending_id)
  } else {
    self.write_byte(compact_type)
  }
}

///|
pub impl Protocol for Compact with fn read_bool(self) {
  if self.bool_ready {
    self.bool_ready = false
    return self.bool_value
  }
  self.read_raw_byte() == compact_true
}

// Eight bytes little-endian, where TBinaryProtocol writes them big-endian.

///|
pub impl Protocol for Compact with fn write_double(self, value) {
  let bits = value.reinterpret_as_uint64().to_be_bytes()
  for i in 0..<8 {
    self.write_byte(bits[7 - i].to_int())
  }
}

///|
pub impl Protocol for Compact with fn read_double(self) {
  let mut bits = 0L
  for i in 0..<8 {
    bits = bits | (self.read_raw_byte().to_int64() << (8 * i))
  }
  bits.reinterpret_as_double()
}

///|
pub impl Protocol for Compact with fn write_string(self, value) {
  let body = @utf8.encode(value)
  self.write_varint(body.length().to_int64())
  self.out.write_bytes(body)
}

///|
pub impl Protocol for Compact with fn read_string(self) {
  let n = self.read_varint().to_int()
  if n < 0 {
    raise Truncated
  }
  self.need(n)
  let body = self.data[self.off:self.off + n].to_owned()
  self.off = self.off + n
  @utf8.decode_lossy(body[:])
}

///|
pub impl Protocol for Compact with fn write_bytes(self, body) {
  self.write_varint(body.length().to_int64())
  self.out.write_bytes(body)
}

///|
pub impl Protocol for Compact with fn read_bytes(self) {
  let n = self.read_varint().to_int()
  if n < 0 {
    raise Truncated
  }
  self.need(n)
  let body = self.data[self.off:self.off + n].to_owned()
  self.off = self.off + n
  body
}

// Sixteen bytes with no varint in front, where a binary value would carry one.

///|
pub impl Protocol for Compact with fn write_uuid(self, body) {
  if body.length() != 16 {
    abort("a uuid is sixteen bytes")
  }
  self.out.write_bytes(body)
}

///|
pub impl Protocol for Compact with fn read_uuid(self) {
  self.need(16)
  let body = self.data[self.off:self.off + 16].to_owned()
  self.off = self.off + 16
  body
}

///|
pub impl Protocol for Compact with fn write_field_begin(self, type_, id) {
  if type_ == type_bool {
    self.pending_field = true
    self.pending_id = id
  } else {
    self.write_field_header(compact_of(type_), id)
  }
}

///|
pub impl Protocol for Compact with fn read_field_begin(self) {
  let header = self.read_raw_byte()
  if (header & 0x0F) == type_stop {
    return (type_stop, 0)
  }
  let modifier = (header >> 4) & 0x0F
  let id = if modifier == 0 {
    unzigzag(self.read_varint())
  } else {
    self.last_field + modifier
  }
  let compact_type = header & 0x0F
  if compact_type == compact_true || compact_type == compact_false {
    self.bool_ready = true
    self.bool_value = compact_type == compact_true
  }
  self.last_field = id
  (type_of(compact_type), id)
}

///|
pub impl Protocol for Compact with fn write_field_stop(self) {
  self.write_byte(type_stop)
}

///|
pub impl Protocol for Compact with fn write_message_begin(
  self,
  name,
  kind,
  seqid,
) {
  self.write_byte(compact_protocol_id)
  self.write_byte((compact_version & 0x1F) | ((kind << 5) & 0xE0))
  self.write_varint(seqid.to_int64() & 0xFFFFFFFFL)
  self.write_string(name)
}

///|
pub impl Protocol for Compact with fn read_message_begin(self) {
  let id = self.read_raw_byte()
  if id != compact_protocol_id {
    raise BadVersion(id)
  }
  let version_and_kind = self.read_raw_byte()
  let version = version_and_kind & 0x1F
  if version != compact_version {
    raise BadVersion(version_and_kind)
  }
  let kind = (version_and_kind >> 5) & 0x07
  let seqid = to_i32(self.read_varint())
  let name = self.read_string()
  (name, kind, seqid)
}

// A list and a set are the same bytes here: one header with the element type in the low
// four bits and the size in the high four, fifteen meaning a varint follows. Which of the
// two a field is says so in the field header; a nested collection does not tell, and
// Apache Thrift's readers do not ask.

///|
fn Compact::write_collection_begin(
  self : Compact,
  elem : Int32,
  size : Int32,
) -> Unit {
  let compact_type = compact_of(elem)
  if size <= 14 {
    self.write_byte((size << 4) | compact_type)
  } else {
    self.write_byte(0xF0 | compact_type)
    self.write_varint(size.to_int64() & 0xFFFFFFFFL)
  }
}

///|
fn Compact::read_collection_begin(
  self : Compact,
) -> (Int32, Int32) raise ThriftError {
  let header = self.read_raw_byte()
  let mut size = (header >> 4) & 0x0F
  if size == 15 {
    size = self.read_varint().to_int()
  }
  (type_of(header & 0x0F), size)
}

///|
/// A binary message has no closing marker: the last field's stop is the end.
pub impl Protocol for Compact with fn read_message_end(self) {
  ignore(self)
}

///|
pub impl Protocol for Compact with fn write_message_end(self) {
  ignore(self)
}

///|
pub impl Protocol for Compact with fn consumed(self) {
  self.off
}

///|
pub impl Protocol for Compact with fn write_list_begin(self, elem, size) {
  self.write_collection_begin(elem, size)
}

///|
pub impl Protocol for Compact with fn write_set_begin(self, elem, size) {
  self.write_collection_begin(elem, size)
}

///|
pub impl Protocol for Compact with fn read_set_begin(self) {
  self.read_collection_begin()
}

///|
pub impl Protocol for Compact with fn read_list_begin(self) {
  self.read_collection_begin()
}

///|
pub impl Protocol for Compact with fn write_map_begin(self, key, value, size) {
  if size == 0 {
    self.write_byte(0)
    return
  }
  self.write_varint(size.to_int64() & 0xFFFFFFFFL)
  self.write_byte((compact_of(key) << 4) | compact_of(value))
}

///|
pub impl Protocol for Compact with fn read_map_begin(self) {
  let size = self.read_varint().to_int()
  if size == 0 {
    return (type_stop, type_stop, 0)
  }
  let header = self.read_raw_byte()
  (type_of((header >> 4) & 0x0F), type_of(header & 0x0F), size)
}

// A struct's fields restart the delta at zero, and the enclosing struct's last field
// id is restored afterwards.

///|
pub impl Protocol for Compact with fn read_struct_begin(self) {
  self.field_stack.push(self.last_field)
  self.last_field = 0
}

///|
pub impl Protocol for Compact with fn read_struct_end(self) {
  self.last_field = self.field_stack.pop().unwrap_or(0)
}

///|
pub impl Protocol for Compact with fn write_struct_begin(self, name) {
  ignore(name)
  self.field_stack.push(self.last_field)
  self.last_field = 0
}

///|
pub impl Protocol for Compact with fn write_struct_end(self) {
  self.last_field = self.field_stack.pop().unwrap_or(0)
}

///|
pub extend Compact with Protocol::{
  reset,
  output,
  read_bytes,
  write_bytes,
  read_message_begin,
  write_message_begin,
  read_message_end,
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
