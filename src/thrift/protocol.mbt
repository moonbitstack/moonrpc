// Thrift's TBinaryProtocol: a strict message header, structs as typed fields, and the
// primitive types big-endian. No transport here — `service.mbt` frames and dispatches;
// this file only reads and writes the bytes.

///|
pub(all) suberror ThriftError {
  BadVersion(Int32)
  Truncated
  BadType(Int32)
  Depth
  Unsupported(String)
  Application(String)
}

///|
pub let type_stop : Int32 = 0

///|
pub let type_bool : Int32 = 2

///|
pub let type_byte : Int32 = 3

///|
pub let type_double : Int32 = 4

///|
pub let type_i16 : Int32 = 6

///|
pub let type_i32 : Int32 = 8

///|
pub let type_i64 : Int32 = 10

///|
pub let type_string : Int32 = 11

///|
pub let type_struct : Int32 = 12

///|
pub let type_map : Int32 = 13

///|
pub let type_set : Int32 = 14

///|
pub let type_list : Int32 = 15

///|
pub let message_call : Int32 = 1

///|
pub let message_reply : Int32 = 2

///|
pub let message_exception : Int32 = 3

///|
pub let message_oneway : Int32 = 4

///|
/// The largest nesting `skip` will follow before giving up.
pub let max_depth : Int32 = 64

///|
/// A writer over the protocol's bytes.
pub struct TWriter {
  buf : @buffer.Buffer
}

///|
pub fn TWriter::new() -> TWriter {
  { buf: @buffer.Buffer(), }
}

///|
pub fn TWriter::to_bytes(self : TWriter) -> Bytes {
  self.buf.to_bytes()
}

///|
pub fn TWriter::write_raw(self : TWriter, body : Bytes) -> Unit {
  self.buf.write_bytes(body)
}

///|
pub fn TWriter::write_byte(self : TWriter, value : Int32) -> Unit {
  self.buf.write_byte((value & 0xFF).to_byte())
}

///|
pub fn TWriter::write_i16(self : TWriter, value : Int32) -> Unit {
  self.write_byte(value >> 8)
  self.write_byte(value)
}

///|
pub fn TWriter::write_i32(self : TWriter, value : Int32) -> Unit {
  self.write_byte(value >> 24)
  self.write_byte(value >> 16)
  self.write_byte(value >> 8)
  self.write_byte(value)
}

///|
pub fn TWriter::write_i64(self : TWriter, value : Int64) -> Unit {
  for shift in [56, 48, 40, 32, 24, 16, 8, 0] {
    self.write_byte(((value >> shift) & 0xFFL).to_int())
  }
}

///|
pub fn TWriter::write_bool(self : TWriter, value : Bool) -> Unit {
  self.write_byte(if value { 1 } else { 0 })
}

///|
pub fn TWriter::write_string(self : TWriter, value : String) -> Unit {
  let body = @utf8.encode(value)
  self.write_i32(body.length())
  self.write_raw(body)
}

///|
pub fn TWriter::write_field_begin(
  self : TWriter,
  type_ : Int32,
  id : Int32,
) -> Unit {
  self.write_byte(type_)
  self.write_i16(id)
}

///|
pub fn TWriter::write_field_stop(self : TWriter) -> Unit {
  self.write_byte(type_stop)
}

///|
pub fn TWriter::write_message_begin(
  self : TWriter,
  name : String,
  kind : Int32,
  seqid : Int32,
) -> Unit {
  // Strict format: version 1 in the high half, the message type in the low byte.
  self.write_i32(-2147418112 | kind)
  self.write_string(name)
  self.write_i32(seqid)
}

///|
pub fn TWriter::write_list_begin(
  self : TWriter,
  elem : Int32,
  size : Int32,
) -> Unit {
  self.write_byte(elem)
  self.write_i32(size)
}

///|
pub fn TWriter::write_map_begin(
  self : TWriter,
  key : Int32,
  value : Int32,
  size : Int32,
) -> Unit {
  self.write_byte(key)
  self.write_byte(value)
  self.write_i32(size)
}

///|
/// A reader over the protocol's bytes, with a cursor.
pub struct TReader {
  data : Bytes
  mut off : Int32
  mut depth : Int32
}

///|
pub fn TReader::new(data : Bytes) -> TReader {
  { data, off: 0, depth: 0, }
}

///|
pub fn TReader::eof(self : TReader) -> Bool {
  self.off >= self.data.length()
}

///|
fn TReader::need(self : TReader, n : Int32) -> Unit raise ThriftError {
  if n < 0 || self.off + n > self.data.length() {
    raise Truncated
  }
}

///|
pub fn TReader::read_byte(self : TReader) -> Int32 raise ThriftError {
  self.need(1)
  let value = self.data[self.off].to_int()
  self.off = self.off + 1
  value
}

///|
pub fn TReader::read_i16(self : TReader) -> Int32 raise ThriftError {
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
pub fn TReader::read_i32(self : TReader) -> Int32 raise ThriftError {
  let b0 = self.read_byte()
  let b1 = self.read_byte()
  let b2 = self.read_byte()
  let b3 = self.read_byte()
  (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
}

///|
pub fn TReader::read_i64(self : TReader) -> Int64 raise ThriftError {
  let mut value = 0L
  for _ in 0..<8 {
    value = (value << 8) | self.read_byte().to_int64()
  }
  value
}

///|
pub fn TReader::read_bool(self : TReader) -> Bool raise ThriftError {
  self.read_byte() != 0
}

///|
pub fn TReader::read_string(self : TReader) -> String raise ThriftError {
  let n = self.read_i32()
  self.need(n)
  let body = self.data[self.off:self.off + n].to_owned()
  self.off = self.off + n
  @utf8.decode_lossy(body[:])
}

///|
pub fn TReader::read_field_begin(
  self : TReader,
) -> (Int32, Int32) raise ThriftError {
  let type_ = self.read_byte()
  if type_ == type_stop {
    (type_stop, 0)
  } else {
    (type_, self.read_i16())
  }
}

///|
pub fn TReader::read_message_begin(
  self : TReader,
) -> (String, Int32, Int32) raise ThriftError {
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
pub fn TReader::read_list_begin(
  self : TReader,
) -> (Int32, Int32) raise ThriftError {
  (self.read_byte(), self.read_i32())
}

///|
pub fn TReader::read_map_begin(
  self : TReader,
) -> (Int32, Int32, Int32) raise ThriftError {
  (self.read_byte(), self.read_byte(), self.read_i32())
}

///|
pub fn TReader::skip(self : TReader, type_ : Int32) -> Unit raise ThriftError {
  if self.depth > max_depth {
    raise Depth
  }
  self.depth = self.depth + 1
  match type_ {
    t if t == type_bool || t == type_byte => ignore(self.read_byte())
    t if t == type_i16 => ignore(self.read_i16())
    t if t == type_i32 => ignore(self.read_i32())
    t if t == type_i64 => ignore(self.read_i64())
    t if t == type_double => {
      self.need(8)
      self.off = self.off + 8
    }
    t if t == type_string => {
      let n = self.read_i32()
      self.need(n)
      self.off = self.off + n
    }
    t if t == type_struct =>
      for ;; {
        let (field_type, _) = self.read_field_begin()
        if field_type == type_stop {
          break
        }
        self.skip(field_type)
      }
    t if t == type_list || t == type_set => {
      let (elem, n) = self.read_list_begin()
      for _ in 0..<n {
        self.skip(elem)
      }
    }
    t if t == type_map => {
      let (key, value, n) = self.read_map_begin()
      for _ in 0..<n {
        self.skip(key)
        self.skip(value)
      }
    }
    other => raise BadType(other)
  }
  self.depth = self.depth - 1
}

///|
pub impl Show for ThriftError with fn output(self, logger) {
  match self {
    BadVersion(v) => logger.write_string("BadVersion(" + v.to_string() + ")")
    Truncated => logger.write_string("Truncated")
    BadType(t) => logger.write_string("BadType(" + t.to_string() + ")")
    Depth => logger.write_string("Depth")
    Unsupported(what) => logger.write_string("Unsupported(" + what + ")")
    Application(message) => logger.write_string("Application(" + message + ")")
  }
}

///|
pub extend ThriftError with Show::{to_string, output}
