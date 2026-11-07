// Thrift's service layer: a processor that reads a CALL and writes a REPLY, and a
// client request that goes the other way over any `Transport`. Both are written against
// `Protocol`, so a service works the same over the binary and the compact protocol.

///|
/// The largest framed body this library will accept, in octets.
pub let max_frame : Int32 = 16 * 1024 * 1024

///|
/// One framed round trip: a body out, a body back — and, for a method declared `oneway`,
/// a body out and nothing back. The native driver puts a length prefix on it; an in-memory
/// transport can carry the bytes directly.
///
/// `send` is separate from `round_trip` because a oneway call has no reply to wait for: a
/// transport that waited for one would hang until the peer closed, and a transport that
/// invented an empty reply would leave the caller reading a frame that never comes.
pub(open) trait Transport {
  async fn round_trip(Self, Bytes) -> Bytes raise ThriftError
  /// Write one body and return, for a method that answers nothing.
  async fn send(Self, Bytes) -> Unit raise ThriftError
}

///|
/// One method: read its arguments from the protocol, write its result fields (field 0
/// for a success value).
pub type Method = (&Protocol) -> Unit raise ThriftError

///|
/// A dispatcher over method names, one `Method` each, and the names that answer nothing.
pub(all) struct Processor {
  methods : Map[String, Method]
  oneway : Set[String]
}

///|
pub fn Processor::new() -> Processor {
  { methods: Map([]), oneway: Set([]), }
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
/// Register a method the IDL declares `oneway`: it runs, and no REPLY goes back.
///
/// The message kind alone cannot say this. Apache Thrift's Go client sends a ONEWAY call
/// as an ordinary CALL and simply never reads an answer, so a server that replies to one
/// leaves an unread frame on the connection and every later reply is off by one. The flag
/// belongs to the method, which is where the IDL puts it, not to the call.
pub fn Processor::add_oneway(
  self : Processor,
  name : String,
  handler : Method,
) -> Unit {
  self.methods[name] = handler
  self.oneway.add(name)
}

///|
/// Answer one CALL frame. A method that is not registered gets a
/// `TApplicationException` with `UNKNOWN_METHOD`, as Apache Thrift's processors do. A
/// ONEWAY call is run and answered with no bytes.
///
/// A handler that fails is not a closed connection: the frame it was building is
/// dropped and the caller gets a `TApplicationException` carrying the message, which is
/// what an Apache Thrift processor does with a `TException` raised out of a handler.
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
  if kind == message_oneway || self.oneway.contains(name) {
    match self.methods.get(name) {
      Some(handler) => handler(proto) catch { _ => () }
      None => ()
    }
    return b""
  }
  match self.methods.get(name) {
    Some(handler) => {
      proto.write_message_begin(name, message_reply, seqid)
      proto.write_struct_begin(name + "_result")
      let mut failure : String? = None
      handler(proto) catch {
        // An `Application` carries the message an Apache Thrift processor would have
        // put in the TApplicationException; anything else is described by its repr.
        e =>
          failure = Some(
            match e {
              Application(message) => message
              other => other.to_string()
            },
          )
      }
      match failure {
        None => {
          proto.write_field_stop()
          proto.write_struct_end()
          proto.output()
        }
        Some(message) => {
          // The half-written result struct is dropped, not patched: a reply is either a
          // result or an exception, and the exception's header has to come first.
          proto.reset(b"")
          application_exception(proto, name, seqid, message, internal_error)
        }
      }
    }
    None => {
      proto.reset(b"")
      application_exception(
        proto,
        name,
        seqid,
        "unknown method: " + name,
        unknown_method,
      )
    }
  }
}

// `TApplicationException`'s type codes, as Apache Thrift numbers them.

///|
let unknown_method : Int32 = 1

///|
let internal_error : Int32 = 6

///|
/// A REPLY that failed instead of answering: `TApplicationException` with its message in
/// field 1 and its type in field 2, framed as an EXCEPTION message.
fn application_exception(
  proto : &Protocol,
  name : String,
  seqid : Int32,
  message : String,
  type_ : Int32,
) -> Bytes {
  proto.write_message_begin(name, message_exception, seqid)
  proto.write_struct_begin("TApplicationException")
  proto.write_field_begin(type_string, 1)
  proto.write_string(message)
  proto.write_field_begin(type_i32, 2)
  proto.write_i32(type_)
  proto.write_field_stop()
  proto.write_struct_end()
  proto.output()
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
/// A ONEWAY call written whole: the header, the arguments and the end of the struct, with
/// no reply to wait for. A transport sends these bytes and returns.
pub fn oneway(
  proto : &Protocol,
  name : String,
  seqid : Int32,
  args : (&Protocol) -> Unit raise ThriftError,
) -> Bytes raise ThriftError {
  proto.reset(b"")
  proto.write_message_begin(name, message_oneway, seqid)
  proto.write_struct_begin(name + "_args")
  args(proto)
  proto.write_field_stop()
  proto.write_struct_end()
  proto.output()
}

///|
/// Send one ONEWAY call and return — the client half of a method the IDL declares `oneway`.
/// Nothing is read back, so this ends as soon as the bytes are handed to the transport; a
/// failure means they never left.
pub async fn[T : Transport] oneway_call(
  transport : T,
  proto : &Protocol,
  name : String,
  seqid : Int32,
  args : (&Protocol) -> Unit raise ThriftError,
) -> Unit raise ThriftError {
  transport.send(oneway(proto, name, seqid, args))
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
