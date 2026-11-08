// The messages of `connectrpc.conformance.v1`, read and written by field number. They are simple
// enough — a header, a response definition, a payload that echoes the request — that writing
// them out is clearer than reaching through a generic message interface, and it keeps the bytes
// a caller sent byte-for-byte: `RequestInfo.requests` carries each request *as it arrived*,
// wrapped in an `Any`, which is what the suite compares against.
//
// The field numbers are the ones in `idl/service.proto`, which is also what the JSON codec of a
// Connect call is compiled from, so a JSON body and a binary one describe the same message.

///|
/// One header or trailer entry: a name and the values it appeared with.
pub(all) struct HeaderEntry {
  mut name : String
  values : Array[String]
}

///|
/// An error a definition asked for.
pub(all) struct ErrorSpec {
  mut code : Int32
  mut message : String?
}

///|
/// The response a unary or client-streaming call was asked to give.
pub(all) struct UnaryDef {
  headers : Array[HeaderEntry]
  mut data : Bytes
  mut has_data : Bool
  mut error : ErrorSpec?
  trailers : Array[HeaderEntry]
  mut delay_ms : Int32
}

///|
/// The responses a server-streaming or bidi call was asked to give.
pub(all) struct StreamDef {
  headers : Array[HeaderEntry]
  data : Array[Bytes]
  mut delay_ms : Int32
  mut error : ErrorSpec?
  trailers : Array[HeaderEntry]
}

///|
/// The definition a unary or client-streaming request carries, in field 1.
pub fn decode_unary_def(body : Bytes) -> UnaryDef {
  let out : UnaryDef = {
    headers: [],
    data: b"",
    has_data: false,
    error: None,
    trailers: [],
    delay_ms: 0,
  }
  walk(body, fn(number, wire, r) {
    match (number, wire) {
      (1, @proto.LengthDelim) => {
        out.headers.push(read_header(take_bytes(r)))
        true
      }
      (2, @proto.LengthDelim) => {
        out.data = take_bytes(r)
        out.has_data = true
        true
      }
      (3, @proto.LengthDelim) => {
        out.error = Some(read_error(take_bytes(r)))
        true
      }
      (4, @proto.LengthDelim) => {
        out.trailers.push(read_header(take_bytes(r)))
        true
      }
      (6, @proto.Varint) => {
        out.delay_ms = take_uint32(r)
        true
      }
      (_, _) => false
    }
  })
  out
}

///|
/// The definition a server-streaming or bidi request carries, in field 1.
pub fn decode_stream_def(body : Bytes) -> StreamDef {
  let out : StreamDef = {
    headers: [],
    data: [],
    delay_ms: 0,
    error: None,
    trailers: [],
  }
  walk(body, fn(number, wire, r) {
    match (number, wire) {
      (1, @proto.LengthDelim) => {
        out.headers.push(read_header(take_bytes(r)))
        true
      }
      (2, @proto.LengthDelim) => {
        out.data.push(take_bytes(r))
        true
      }
      (3, @proto.Varint) => {
        out.delay_ms = take_uint32(r)
        true
      }
      (4, @proto.LengthDelim) => {
        out.error = Some(read_error(take_bytes(r)))
        true
      }
      (5, @proto.LengthDelim) => {
        out.trailers.push(read_header(take_bytes(r)))
        true
      }
      (_, _) => false
    }
  })
  out
}

///|
/// The definition a request carries in field 1, or a definition that asks for nothing — which is
/// what the suite means by an unset one.
pub fn definition_of(body : Bytes) -> Bytes {
  let mut found = b""
  walk(body, fn(number, wire, r) {
    if number == 1 && wire == @proto.LengthDelim {
      found = take_bytes(r)
      true
    } else {
      false
    }
  })
  found
}

///|
/// Whether a bidi request asked for full duplex, which is field 2 of the first message.
pub fn full_duplex_of(body : Bytes) -> Bool {
  let mut wanted = false
  walk(body, fn(number, wire, r) {
    if number == 2 && wire == @proto.Varint {
      wanted = take_bool(r)
      true
    } else {
      false
    }
  })
  wanted
}

///|
/// One `Header`, from its wire form.
fn read_header(body : Bytes) -> HeaderEntry {
  let out : HeaderEntry = { name: "", values: [], }
  walk(body, fn(number, wire, r) {
    match (number, wire) {
      (1, @proto.LengthDelim) => {
        out.name = take_string(r)
        true
      }
      (2, @proto.LengthDelim) => {
        out.values.push(take_string(r))
        true
      }
      (_, _) => false
    }
  })
  out
}

///|
/// One `Error`, from its wire form. The details are `Any` messages and are carried through
/// untouched.
fn read_error(body : Bytes) -> ErrorSpec {
  let out : ErrorSpec = { code: 0, message: None, }
  walk(body, fn(number, wire, r) {
    match (number, wire) {
      (1, @proto.Varint) => {
        out.code = take_int32(r)
        true
      }
      (2, @proto.LengthDelim) => {
        out.message = Some(take_string(r))
        true
      }
      (_, _) => false
    }
  })
  out
}

///|
/// The next length-delimited value, or an empty one when the body ends inside it. A reader used
/// from a walker cannot raise into it, and a body that stops early has nothing more to say.
fn take_bytes(r : @proto.PbReader) -> Bytes {
  r.read_bytes() catch {
    _ => b""
  }
}

///|
fn take_string(r : @proto.PbReader) -> String {
  r.read_string() catch {
    _ => ""
  }
}

///|
fn take_int32(r : @proto.PbReader) -> Int32 {
  r.read_int32() catch {
    _ => 0
  }
}

///|
fn take_uint32(r : @proto.PbReader) -> Int32 {
  (r.read_uint32() catch { _ => 0U }).reinterpret_as_int()
}

///|
fn take_bool(r : @proto.PbReader) -> Bool {
  r.read_bool() catch {
    _ => false
  }
}

///|
/// Walk a message's fields, handing each to `f` with the reader positioned at its value. A body
/// that does not decode ends the walk: a caller of this service speaks a message this file
/// describes, and anything past the damage is not something to guess at.
fn walk(
  body : Bytes,
  f : (Int32, @proto.WireType, @proto.PbReader) -> Bool,
) -> Unit {
  let reader = @proto.PbReader::new(body)
  while !reader.eof() {
    let tag = reader.read_tag() catch { _ => break }
    let (number, wire) = tag
    // A field the caller did not take is skipped here, so that a message with fields this
    // service does not know about still reads to the end.
    if !f(number, wire, reader) {
      reader.skip(wire) catch {
        _ => break
      }
    }
  }
}

///|
/// A `Header` on the wire.
pub fn encode_header(entry : HeaderEntry) -> Bytes {
  let w = @proto.PbWriter::new()
  w.string_(1, entry.name)
  for value in entry.values {
    w.string_(2, value)
  }
  w.to_bytes()
}

///|
/// The `RequestInfo` a payload echoes: the headers seen, the deadline, and the request messages
/// wrapped in `Any` under `type_url`.
pub fn encode_request_info(
  headers : Array[HeaderEntry],
  timeout_ms : Int32?,
  requests : Array[Bytes],
  type_url : String,
) -> Bytes {
  let w = @proto.PbWriter::new()
  for header in headers {
    w.message_(1, encode_header(header))
  }
  match timeout_ms {
    Some(ms) => w.int64(2, ms.to_int64())
    None => ()
  }
  for request in requests {
    w.message_(3, encode_any(type_url, request))
  }
  w.to_bytes()
}

///|
/// A `google.protobuf.Any` holding `value` as `type_url`.
fn encode_any(type_url : String, value : Bytes) -> Bytes {
  let w = @proto.PbWriter::new()
  w.string_(1, type_url)
  w.bytes_(2, value)
  w.to_bytes()
}

///|
/// A `ConformancePayload`: the data a definition asked for, and the request echoed.
pub fn encode_payload(data : Bytes, has_data : Bool, info : Bytes) -> Bytes {
  let w = @proto.PbWriter::new()
  if has_data {
    w.bytes_(1, data)
  }
  // A later message of a stream carries only its data; an empty `request_info` written out
  // would be a field the suite sees as present rather than absent.
  if info.length() > 0 {
    w.message_(2, info)
  }
  w.to_bytes()
}

///|
/// A `UnaryResponse`, `ClientStreamResponse` or `BidiStreamResponse`: one payload, in field 1.
pub fn encode_payload_response(payload : Bytes) -> Bytes {
  let w = @proto.PbWriter::new()
  w.message_(1, payload)
  w.to_bytes()
}

///|
/// The headers a handler was asked to send, as the context's own.
pub fn apply_headers(
  ctx : @stream.RpcContext,
  entries : Array[HeaderEntry],
) -> Unit {
  for entry in entries {
    for value in entry.values {
      ctx.resp_headers.push({
        name: @utf8.encode(entry.name),
        value: @utf8.encode(value),
      })
    }
  }
}

///|
/// The trailers a handler was asked to send.
pub fn apply_trailers(
  ctx : @stream.RpcContext,
  entries : Array[HeaderEntry],
) -> Unit {
  for entry in entries {
    for value in entry.values {
      ctx.resp_trailers.push({
        name: @utf8.encode(entry.name),
        value: @utf8.encode(value),
      })
    }
  }
}

///|
/// The request's headers as the payload echoes them.
pub fn seen_headers(ctx : @stream.RpcContext) -> Array[HeaderEntry] {
  let out : Array[HeaderEntry] = []
  for h in ctx.metadata {
    out.push({
      name: @utf8.decode_lossy(h.name),
      values: [@utf8.decode_lossy(h.value)],
    })
  }
  out
}
