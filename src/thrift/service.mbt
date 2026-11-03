// Thrift's service layer: a processor that reads a CALL and writes a REPLY, and a
// client request that goes the other way over any `Transport`. The transport is a
// trait so the native framed socket driver and an in-memory test implement the same
// contract.

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
/// One method: read its arguments from the reader, write its result fields (field 0
/// for a success value) to the writer.
pub type Method = (TReader, TWriter) -> Unit raise ThriftError

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
/// Register `method` under `name`, the Thrift method name on the wire.
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
  frame : Bytes,
) -> Bytes raise ThriftError {
  let reader = TReader::new(frame)
  let (name, kind, seqid) = reader.read_message_begin()
  if kind != message_call && kind != message_oneway {
    raise BadType(kind)
  }
  if kind == message_oneway {
    match self.methods.get(name) {
      Some(handler) => handler(reader, TWriter::new())
      None => ()
    }
    return b""
  }
  let out = TWriter::new()
  match self.methods.get(name) {
    Some(handler) => {
      out.write_message_begin(name, message_reply, seqid)
      handler(reader, out)
      out.write_field_stop()
      out.to_bytes()
    }
    None => {
      out.write_message_begin(name, message_exception, seqid)
      out.write_field_begin(type_string, 1)
      out.write_string("unknown method: " + name)
      out.write_field_begin(type_i32, 2)
      out.write_i32(1)
      out.write_field_stop()
      out.to_bytes()
    }
  }
}

///|
/// Send one CALL and return a reader positioned at its result struct.
pub async fn[T : Transport] request(
  transport : T,
  name : String,
  seqid : Int32,
  args : (TWriter) -> Unit raise ThriftError,
) -> TReader raise ThriftError {
  let writer = TWriter::new()
  writer.write_message_begin(name, message_call, seqid)
  args(writer)
  writer.write_field_stop()
  let reply = transport.round_trip(writer.to_bytes())
  let reader = TReader::new(reply)
  let (_, kind, _) = reader.read_message_begin()
  if kind == message_exception {
    let mut message = "thrift application exception"
    for ;; {
      let (field_type, field_id) = reader.read_field_begin()
      if field_type == type_stop {
        break
      }
      if field_id == 1 && field_type == type_string {
        message = reader.read_string()
      } else {
        reader.skip(field_type)
      }
    }
    raise Application(message)
  }
  if kind != message_reply {
    raise BadType(kind)
  }
  reader
}

///|
/// Send one CALL and decode its success value with `read`.
pub async fn[T : Transport, R] call(
  transport : T,
  name : String,
  seqid : Int32,
  args : (TWriter) -> Unit raise ThriftError,
  read : (TReader) -> R raise ThriftError,
) -> R raise ThriftError {
  let reader = request(transport, name, seqid, args)
  read_success(reader, read)
}

///|
/// Read a result struct: field 0 is the success value; any other field is an
/// exception, whose string message (when it has one) is raised.
pub fn[R] read_success(
  reader : TReader,
  read : (TReader) -> R raise ThriftError,
) -> R raise ThriftError {
  let (field_type, field_id) = reader.read_field_begin()
  if field_type == type_stop {
    raise Application("the reply carried no result")
  }
  if field_id != 0 {
    let message = if field_type == type_string {
      reader.read_string()
    } else {
      reader.skip(field_type)
      "the method raised a Thrift exception"
    }
    raise Application(message)
  }
  read(reader)
}

///|
/// A length-prefixed frame, as `TFramedTransport` writes it.
pub fn frame(body : Bytes) -> Bytes {
  let writer = TWriter::new()
  writer.write_i32(body.length())
  writer.write_raw(body)
  writer.to_bytes()
}

///|
/// The body length a frame header announces.
pub fn frame_len(header : Bytes) -> Int32 raise ThriftError {
  TReader::new(header).read_i32()
}
