// Thrift's service layer: a processor that reads a CALL and writes a REPLY, and a
// client request that goes the other way over any `Transport`. Both are written against
// `Protocol`, so a service works the same over the binary and the compact protocol.

///|
/// The largest framed body this library will accept, in octets.
pub let max_frame : Int32 = 16 * 1024 * 1024

///|
/// One framed round trip: a body out, a body back. The native driver puts a length
/// prefix on it; an in-memory transport can carry the bytes directly.
pub(open) trait Transport {
  async fn round_trip(Self, Bytes) -> Bytes raise ThriftError
}

///|
/// One method: read its arguments from the protocol, write its result fields (field 0
/// for a success value).
pub type Method = (&Protocol) -> Unit raise ThriftError

///|
/// A dispatcher over method names, one `Method` each.
pub(all) struct Processor {
  methods : Map[String, Method]
}

///|
pub fn Processor::new() -> Processor {
  { methods: Map([]), }
}

///|
/// Register `handler` under `name`, the Thrift method name on the wire.
pub fn Processor::add(
  self : Processor,
  name : String,
  handler : Method,
) -> Unit {
  self.methods[name] = handler
}

///|
/// Answer one CALL frame. A method that is not registered gets a
/// `TApplicationException` with `UNKNOWN_METHOD`, as Apache Thrift's processors do. A
/// ONEWAY call is run and answered with no bytes.
pub fn Processor::process(
  self : Processor,
  proto : &Protocol,
  frame : Bytes,
) -> Bytes raise ThriftError {
  proto.reset(frame)
  let (name, kind, seqid) = proto.read_message_begin()
  if kind != message_call && kind != message_oneway {
    raise BadType(kind)
  }
  proto.read_struct_begin()
  if kind == message_oneway {
    match self.methods.get(name) {
      Some(handler) => handler(proto)
      None => ()
    }
    return b""
  }
  match self.methods.get(name) {
    Some(handler) => {
      proto.write_message_begin(name, message_reply, seqid)
      proto.write_struct_begin(name + "_result")
      handler(proto)
      proto.write_field_stop()
      proto.write_struct_end()
      proto.output()
    }
    None => {
      proto.write_message_begin(name, message_exception, seqid)
      proto.write_struct_begin("TApplicationException")
      proto.write_field_begin(type_string, 1)
      proto.write_string("unknown method: " + name)
      proto.write_field_begin(type_i32, 2)
      proto.write_i32(1)
      proto.write_field_stop()
      proto.write_struct_end()
      proto.output()
    }
  }
}

///|
/// Send one CALL and leave `proto` positioned inside its result struct.
pub async fn[T : Transport] request(
  transport : T,
  proto : &Protocol,
  name : String,
  seqid : Int32,
  args : (&Protocol) -> Unit raise ThriftError,
) -> Unit raise ThriftError {
  proto.reset(b"")
  proto.write_message_begin(name, message_call, seqid)
  proto.write_struct_begin(name + "_args")
  args(proto)
  proto.write_field_stop()
  proto.write_struct_end()
  let reply = transport.round_trip(proto.output())
  proto.reset(reply)
  let (_, kind, _) = proto.read_message_begin()
  proto.read_struct_begin()
  if kind == message_exception {
    let mut message = "thrift application exception"
    for ;; {
      let (field_type, field_id) = proto.read_field_begin()
      if field_type == type_stop {
        break
      }
      if field_id == 1 && field_type == type_string {
        message = proto.read_string()
      } else {
        skip(proto, field_type)
      }
    }
    raise Application(message)
  }
  if kind != message_reply {
    raise BadType(kind)
  }
}

///|
/// Send one CALL and decode its success value with `read`.
pub async fn[T : Transport, R] call(
  transport : T,
  proto : &Protocol,
  name : String,
  seqid : Int32,
  args : (&Protocol) -> Unit raise ThriftError,
  read : (&Protocol) -> R raise ThriftError,
) -> R raise ThriftError {
  request(transport, proto, name, seqid, args)
  read_success(proto, read)
}

///|
/// Read a result struct: field 0 is the success value; any other field is an exception,
/// whose string message (when it has one) is raised.
pub fn[R] read_success(
  proto : &Protocol,
  read : (&Protocol) -> R raise ThriftError,
) -> R raise ThriftError {
  let (field_type, field_id) = proto.read_field_begin()
  if field_type == type_stop {
    raise Application("the reply carried no result")
  }
  if field_id != 0 {
    let message = if field_type == type_string {
      proto.read_string()
    } else {
      skip(proto, field_type)
      "the method raised a Thrift exception"
    }
    raise Application(message)
  }
  read(proto)
}

///|
/// Read a result struct whose method declares exceptions: field 0 is the success value,
/// any other field is a failure that `exception` decodes by its field id. The decoder
/// answers `None` for a field it does not know and must not have read it; that one is
/// skipped and raised as `Application`, so a failure nobody declared is not swallowed as
/// a value.
pub fn[R, E] read_result(
  proto : &Protocol,
  read : (&Protocol) -> R raise ThriftError,
  exception : (&Protocol, Int32) -> E? raise ThriftError,
) -> Result[R, E] raise ThriftError {
  let (field_type, field_id) = proto.read_field_begin()
  if field_type == type_stop {
    raise Application("the reply carried no result")
  }
  if field_id == 0 {
    return Ok(read(proto))
  }
  match exception(proto, field_id) {
    Some(failure) => Err(failure)
    None => undeclared(proto, field_type)
  }
}

///|
/// The same, for a method that answers nothing: an empty result struct is success.
pub fn[E] read_result_unit(
  proto : &Protocol,
  exception : (&Protocol, Int32) -> E? raise ThriftError,
) -> Result[Unit, E] raise ThriftError {
  let (field_type, field_id) = proto.read_field_begin()
  if field_type == type_stop {
    return Ok(())
  }
  match exception(proto, field_id) {
    Some(failure) => Err(failure)
    None => undeclared(proto, field_type)
  }
}

///|
/// A failure field no `throws` clause declared. Its string message is what gets raised,
/// as with any other Thrift exception.
fn[E] undeclared(proto : &Protocol, field_type : Int32) -> E raise ThriftError {
  let message = if field_type == type_string {
    proto.read_string()
  } else {
    skip(proto, field_type)
    "the method raised an undeclared Thrift exception"
  }
  raise Application(message)
}

///|
/// Send one CALL and read a result that may be a declared exception.
pub async fn[T : Transport, R, E] call_result(
  transport : T,
  proto : &Protocol,
  name : String,
  seqid : Int32,
  args : (&Protocol) -> Unit raise ThriftError,
  read : (&Protocol) -> R raise ThriftError,
  exception : (&Protocol, Int32) -> E? raise ThriftError,
) -> Result[R, E] raise ThriftError {
  request(transport, proto, name, seqid, args)
  read_result(proto, read, exception)
}

///|
/// The same, for a method that returns nothing and may still throw.
pub async fn[T : Transport, E] call_result_unit(
  transport : T,
  proto : &Protocol,
  name : String,
  seqid : Int32,
  args : (&Protocol) -> Unit raise ThriftError,
  exception : (&Protocol, Int32) -> E? raise ThriftError,
) -> Result[Unit, E] raise ThriftError {
  request(transport, proto, name, seqid, args)
  read_result_unit(proto, exception)
}

///|
/// A length-prefixed frame, as `TFramedTransport` writes it.
pub fn frame(body : Bytes) -> Bytes {
  let writer : Binary = Binary::new(b"")
  writer.write_i32(body.length())
  writer.out.write_bytes(body)
  writer.output()
}

///|
/// The body length a frame header announces.
pub fn frame_len(header : Bytes) -> Int32 raise ThriftError {
  Binary::new(header).read_i32()
}
