// TBinaryProtocol: a strict message header, structs as typed fields, and every number
// fixed-width and big-endian. The doubles are the one place a reader has to be careful:
// this protocol writes them big-endian, TCompactProtocol writes them little-endian.

///|
/// A binary-protocol reader and writer over one message.
pub struct Binary {
  mut data : Bytes
  mut off : Int32
  mut out : @buffer.Buffer
}

///|
pub fn Binary::new(input : Bytes) -> Binary {
  { data: input, off: 0, out: @buffer.Buffer(), }
}

///|
pub fn Binary::eof(self : Binary) -> Bool {
  self.off >= self.data.length()
}

///|
fn Binary::need(self : Binary, n : Int32) -> Unit raise ThriftError {
  if n < 0 || self.off + n > self.data.length() {
    raise Truncated
  }
}

///|
pub impl Protocol for Binary with fn reset(self, input) {
  self.data = input
  self.off = 0
  self.out = @buffer.Buffer()
}

///|
pub impl Protocol for Binary with fn output(self) {
  self.out.to_bytes()
}

///|
pub impl Protocol for Binary with fn write_byte(self, value) {
  self.out.write_byte((value & 0xFF).to_byte())
}

///|
pub impl Protocol for Binary with fn read_byte(self) {
  self.need(1)
  let value = self.data[self.off].to_int()
  self.off = self.off + 1
  value
}

///|
pub impl Protocol for Binary with fn write_i16(self, value) {
  self.write_byte(value >> 8)
  self.write_byte(value)
}

///|
pub impl Protocol for Binary with fn read_i16(self) {
  let hi = self.read_byte()
  let lo = self.read_byte()
  let value = (hi << 8) | lo
  if value >= 0x8000 {
    value - 0x10000
  } else {
    value
  }
}

///|
pub impl Protocol for Binary with fn write_i32(self, value) {
  self.write_byte(value >> 24)
  self.write_byte(value >> 16)
  self.write_byte(value >> 8)
  self.write_byte(value)
}

///|
pub impl Protocol for Binary with fn read_i32(self) {
  let b0 = self.read_byte()
  let b1 = self.read_byte()
  let b2 = self.read_byte()
  let b3 = self.read_byte()
  (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
}

///|
pub impl Protocol for Binary with fn write_i64(self, value) {
  for shift in [56, 48, 40, 32, 24, 16, 8, 0] {
    self.write_byte(((value >> shift) & 0xFFL).to_int())
  }
}

///|
pub impl Protocol for Binary with fn read_i64(self) {
  let mut value = 0L
  for _ in 0..<8 {
    value = (value << 8) | self.read_byte().to_int64()
  }
  value
}

///|
pub impl Protocol for Binary with fn write_bool(self, value) {
  self.write_byte(if value { 1 } else { 0 })
}

///|
pub impl Protocol for Binary with fn read_bool(self) {
  self.read_byte() != 0
}

// Eight bytes big-endian: the bit pattern of the double.

///|
pub impl Protocol for Binary with fn write_double(self, value) {
  let bits = value.reinterpret_as_uint64().to_be_bytes()
  for i in 0..<8 {
    self.write_byte(bits[i].to_int())
  }
}

///|
pub impl Protocol for Binary with fn read_double(self) {
  let mut bits = 0L
  for _ in 0..<8 {
    bits = (bits << 8) | self.read_byte().to_int64()
  }
  bits.reinterpret_as_double()
}

///|
pub impl Protocol for Binary with fn write_string(self, value) {
  let body = @utf8.encode(value)
  self.write_i32(body.length())
  self.out.write_bytes(body)
}

///|
pub impl Protocol for Binary with fn read_string(self) {
  let n = self.read_i32()
  self.need(n)
  let body = self.data[self.off:self.off + n].to_owned()
  self.off = self.off + n
  @utf8.decode_lossy(body[:])
}

///|
pub impl Protocol for Binary with fn write_bytes(self, body) {
  self.write_i32(body.length())
  self.out.write_bytes(body)
}

///|
pub impl Protocol for Binary with fn read_bytes(self) {
  let n = self.read_i32()
  self.need(n)
  let body = self.data[self.off:self.off + n].to_owned()
  self.off = self.off + n
  body
}

///|
pub impl Protocol for Binary with fn write_uuid(self, body) {
  if body.length() != 16 {
    abort("a uuid is sixteen bytes")
  }
  self.out.write_bytes(body)
}

///|
pub impl Protocol for Binary with fn read_uuid(self) {
  self.need(16)
  let body = self.data[self.off:self.off + 16].to_owned()
  self.off = self.off + 16
  body
}

///|
pub impl Protocol for Binary with fn write_field_begin(self, type_, id) {
  self.write_byte(type_)
  self.write_i16(id)
}

///|
pub impl Protocol for Binary with fn read_field_begin(self) {
  let type_ = self.read_byte()
  if type_ == type_stop {
    (type_stop, 0)
  } else {
    (type_, self.read_i16())
  }
}

///|
pub impl Protocol for Binary with fn write_field_stop(self) {
  self.write_byte(type_stop)
}

///|
pub impl Protocol for Binary with fn write_message_begin(
  self,
  name,
  kind,
  seqid,
) {
  // Strict format: version 1 in the high half, the message type in the low byte.
  self.write_i32(-2147418112 | kind)
  self.write_string(name)
  self.write_i32(seqid)
}

///|
pub impl Protocol for Binary with fn read_message_begin(self) {
  let header = self.read_i32()
  if ((header >> 16) & 0xFFFF) != 0x8001 {
    raise BadVersion(header)
  }
  let kind = header & 0xFF
  let name = self.read_string()
  let seqid = self.read_i32()
  (name, kind, seqid)
}

///|
pub impl Protocol for Binary with fn write_list_begin(self, elem, size) {
  self.write_byte(elem)
  self.write_i32(size)
}

///|
pub impl Protocol for Binary with fn read_list_begin(self) {
  (self.read_byte(), self.read_i32())
}

// A set is laid out exactly as a list is; only the field's type byte says which one
// arrived, so the reader is the same walk and the writer the same bytes.

///|
pub impl Protocol for Binary with fn write_set_begin(self, elem, size) {
  self.write_byte(elem)
  self.write_i32(size)
}

///|
pub impl Protocol for Binary with fn read_set_begin(self) {
  (self.read_byte(), self.read_i32())
}

///|
pub impl Protocol for Binary with fn write_map_begin(self, key, value, size) {
  self.write_byte(key)
  self.write_byte(value)
  self.write_i32(size)
}

///|
pub impl Protocol for Binary with fn read_map_begin(self) {
  (self.read_byte(), self.read_byte(), self.read_i32())
}

// A struct has no markers in this protocol. Only the compact one's field-id deltas
// need to know where a struct starts and ends.

///|
pub impl Protocol for Binary with fn read_struct_begin(self) {
  ignore(self)
}

///|
pub impl Protocol for Binary with fn read_struct_end(self) {
  ignore(self)
}

///|
pub impl Protocol for Binary with fn write_struct_begin(self, name) {
  ignore(self)
  ignore(name)
}

///|
pub impl Protocol for Binary with fn write_struct_end(self) {
  ignore(self)
}

///|
pub extend Binary with Protocol::{
  reset,
  output,
  read_bytes,
  write_bytes,
  read_message_begin,
  write_message_begin,
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
