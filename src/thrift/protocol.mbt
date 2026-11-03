// Thrift's protocol contract, and the pieces every protocol shares: the type ids, the
// message kinds, and `skip`, which is written once here against the contract rather
// than per protocol. `binary.mbt` and `compact.mbt` fill in the bytes.

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
/// One message's worth of reading and writing. `reset` points a protocol at the bytes
/// to read and clears what it has written, so one object serves a whole connection:
/// read a frame, write the reply, read the next frame.
///
/// Both byte orders live behind this contract. TBinaryProtocol writes fixed-width
/// big-endian numbers; TCompactProtocol writes zigzag varints and encodes a boolean's
/// value inside its field header. Nothing above this trait — the processor, the client
/// request, a service's handlers — knows which one it is talking to.
pub(open) trait Protocol {
  /// Point at `input` to read, and drop anything written before.
  fn reset(Self, Bytes) -> Unit
  /// The bytes written since the last `reset`.
  fn output(Self) -> Bytes
  fn read_message_begin(Self) -> (String, Int32, Int32) raise ThriftError
  fn write_message_begin(Self, String, Int32, Int32) -> Unit
  /// Enter a struct. TBinaryProtocol writes nothing; TCompactProtocol resets the field
  /// id that its deltas count from.
  fn read_struct_begin(Self) -> Unit
  fn read_struct_end(Self) -> Unit
  fn write_struct_begin(Self, String) -> Unit
  fn write_struct_end(Self) -> Unit
  fn read_field_begin(Self) -> (Int32, Int32) raise ThriftError
  fn write_field_begin(Self, Int32, Int32) -> Unit
  fn write_field_stop(Self) -> Unit
  fn read_bool(Self) -> Bool raise ThriftError
  fn read_byte(Self) -> Int32 raise ThriftError
  fn read_i16(Self) -> Int32 raise ThriftError
  fn read_i32(Self) -> Int32 raise ThriftError
  fn read_i64(Self) -> Int64 raise ThriftError
  fn read_double(Self) -> Double raise ThriftError
  fn read_string(Self) -> String raise ThriftError
  fn read_list_begin(Self) -> (Int32, Int32) raise ThriftError
  fn read_map_begin(Self) -> (Int32, Int32, Int32) raise ThriftError
  fn write_bool(Self, Bool) -> Unit
  fn write_byte(Self, Int32) -> Unit
  fn write_i16(Self, Int32) -> Unit
  fn write_i32(Self, Int32) -> Unit
  fn write_i64(Self, Int64) -> Unit
  fn write_double(Self, Double) -> Unit
  fn write_string(Self, String) -> Unit
  fn write_list_begin(Self, Int32, Int32) -> Unit
  fn write_map_begin(Self, Int32, Int32, Int32) -> Unit
}

///|
/// Walk past one value of `type_`, whatever it contains.
pub fn skip(proto : &Protocol, type_ : Int32) -> Unit raise ThriftError {
  skip_at(proto, type_, 0)
}

///|
fn skip_at(
  proto : &Protocol,
  type_ : Int32,
  depth : Int32,
) -> Unit raise ThriftError {
  if depth > max_depth {
    raise Depth
  }
  match type_ {
    // A boolean is read, not counted: TCompactProtocol may hold its value in the field
    // header, and reading it is what clears that.
    t if t == type_bool => ignore(proto.read_bool())
    t if t == type_byte => ignore(proto.read_byte())
    t if t == type_i16 => ignore(proto.read_i16())
    t if t == type_i32 => ignore(proto.read_i32())
    t if t == type_i64 => ignore(proto.read_i64())
    t if t == type_double => ignore(proto.read_double())
    t if t == type_string => ignore(proto.read_string())
    t if t == type_struct => {
      proto.read_struct_begin()
      for ;; {
        let (field_type, _) = proto.read_field_begin()
        if field_type == type_stop {
          break
        }
        skip_at(proto, field_type, depth + 1)
      }
      proto.read_struct_end()
    }
    t if t == type_list || t == type_set => {
      let (elem, n) = proto.read_list_begin()
      for _ in 0..<n {
        skip_at(proto, elem, depth + 1)
      }
    }
    t if t == type_map => {
      let (key, value, n) = proto.read_map_begin()
      for _ in 0..<n {
        skip_at(proto, key, depth + 1)
        skip_at(proto, value, depth + 1)
      }
    }
    other => raise BadType(other)
  }
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
