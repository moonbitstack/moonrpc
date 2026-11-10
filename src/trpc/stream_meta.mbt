// The four streaming frames' headers: what an INIT, a FEEDBACK and a CLOSE carry. A DATA
// frame carries the message itself and nothing else, so it has no record here.

///|
/// The window a receiver grants a sender to begin with, in octets — the reference
/// implementations' 64 KiB minus one.
pub let init_window_size : UInt32 = 65535

///|
/// `TrpcStreamCloseType_TRPC_STREAM_CLOSE`: one direction ends, the stream lives on.
pub let close_normal : Int32 = 0

///|
/// `TrpcStreamCloseType_TRPC_STREAM_RESET`: the whole stream is torn down.
pub let close_reset : Int32 = 1

///|
/// Who is calling whom, and with what: the request half of an INIT frame.
pub(all) struct StreamInitRequestMeta {
  mut caller : Bytes
  mut callee : Bytes
  mut func : Bytes
  mut message_type : UInt32
  mut trans_info : Map[String, Bytes]
}

///|
pub fn StreamInitRequestMeta::new(
  caller~ : String = "",
  callee~ : String = "",
  func~ : String = "",
  trans_info~ : Map[String, Bytes] = Map([]),
) -> StreamInitRequestMeta {
  {
    caller: @utf8.encode(caller),
    callee: @utf8.encode(callee),
    func: @utf8.encode(func),
    message_type: 0,
    trans_info,
  }
}

///|
/// The path a streaming call names.
pub fn StreamInitRequestMeta::path(self : StreamInitRequestMeta) -> String {
  let func = @utf8.decode_lossy(self.func)
  if func != "" {
    return func
  }
  let callee = @utf8.decode_lossy(self.callee)
  if callee == "" {
    return ""
  }
  "/" + callee.replace_all(old=".", new="/")
}

///|
/// How a stream began: zero when it opened, a return code when it did not.
pub(all) struct StreamInitResponseMeta {
  mut ret : Int32
  mut error_msg : Bytes
}

///|
pub fn StreamInitResponseMeta::new(
  ret~ : Int32 = 0,
  error_msg~ : String = "",
) -> StreamInitResponseMeta {
  { ret, error_msg: @utf8.encode(error_msg), }
}

///|
/// An INIT frame: the request meta, the response meta, the receive window the sender is
/// granted, and the codec in force.
pub(all) struct StreamInitMeta {
  mut request_meta : StreamInitRequestMeta
  mut response_meta : StreamInitResponseMeta
  mut window : UInt32
  mut content_type : UInt32
  mut content_encoding : UInt32
}

///|
pub fn StreamInitMeta::new(
  request_meta~ : StreamInitRequestMeta = StreamInitRequestMeta::new(),
  response_meta~ : StreamInitResponseMeta = StreamInitResponseMeta::new(),
  window~ : UInt32 = init_window_size,
  content_type~ : UInt32 = encode_proto,
  content_encoding~ : UInt32 = compress_none,
) -> StreamInitMeta {
  { request_meta, response_meta, window, content_type, content_encoding, }
}

///|
/// How much window a FEEDBACK frame hands back.
pub(all) struct StreamFeedbackMeta {
  mut window_increment : UInt32
}

///|
pub fn StreamFeedbackMeta::new(
  window_increment~ : UInt32 = 0,
) -> StreamFeedbackMeta {
  { window_increment, }
}

///|
/// A CLOSE frame: which direction ends (or both, on a reset), the code, the message, and
/// the trailing metadata the far end should see.
pub(all) struct StreamCloseMeta {
  mut close_type : Int32
  mut ret : Int32
  mut message : Bytes
  mut message_type : UInt32
  mut trans_info : Map[String, Bytes]
  mut func_ret : Int32
}

///|
pub fn StreamCloseMeta::new(
  close_type~ : Int32 = close_normal,
  ret~ : Int32 = 0,
  message~ : String = "",
  func_ret~ : Int32 = 0,
  trans_info~ : Map[String, Bytes] = Map([]),
) -> StreamCloseMeta {
  {
    close_type,
    ret,
    message: @utf8.encode(message),
    message_type: 0,
    trans_info,
    func_ret,
  }
}

///|
fn read_map(
  reader : @proto.PbReader,
  trans_info : Map[String, Bytes],
) -> Unit raise @proto.PbError {
  let entry = reader.read_bytes()
  let inner = @proto.PbReader::new(entry)
  let mut key = ""
  let mut value : Bytes = b""
  while !inner.eof() {
    let (field, wire) = inner.read_tag()
    match field {
      1 => key = inner.read_string()
      2 => value = inner.read_bytes()
      _ => inner.skip(wire)
    }
  }
  trans_info[key] = value
}

///|
fn write_map(
  out : @proto.PbWriter,
  field : Int32,
  trans_info : Map[String, Bytes],
) -> Unit {
  let keys : Array[String] = []
  for key, _ in trans_info {
    keys.push(key)
  }
  keys.sort()
  for key in keys {
    let entry = @proto.PbWriter::new()
    entry.bytes_(1, @utf8.encode(key))
    match trans_info.get(key) {
      Some(value) => entry.bytes_(2, value)
      None => ()
    }
    out.bytes_(field, entry.to_bytes())
  }
}

///|
pub fn StreamInitRequestMeta::encode(self : StreamInitRequestMeta) -> Bytes {
  let out = @proto.PbWriter::new()
  if self.caller.length() > 0 {
    out.bytes_(1, self.caller)
  }
  if self.callee.length() > 0 {
    out.bytes_(2, self.callee)
  }
  if self.func.length() > 0 {
    out.bytes_(3, self.func)
  }
  if self.message_type != 0 {
    out.uint32(4, self.message_type)
  }
  write_map(out, 5, self.trans_info)
  out.to_bytes()
}

///|
pub fn StreamInitRequestMeta::decode(
  body : Bytes,
) -> StreamInitRequestMeta raise @proto.PbError {
  let reader = @proto.PbReader::new(body)
  let meta = StreamInitRequestMeta::new()
  while !reader.eof() {
    let (field, wire) = reader.read_tag()
    match field {
      1 => meta.caller = reader.read_bytes()
      2 => meta.callee = reader.read_bytes()
      3 => meta.func = reader.read_bytes()
      4 => meta.message_type = reader.read_uint32()
      5 => read_map(reader, meta.trans_info)
      _ => reader.skip(wire)
    }
  }
  meta
}

///|
pub fn StreamInitResponseMeta::encode(self : StreamInitResponseMeta) -> Bytes {
  let out = @proto.PbWriter::new()
  if self.ret != 0 {
    out.int32(1, self.ret)
  }
  if self.error_msg.length() > 0 {
    out.bytes_(2, self.error_msg)
  }
  out.to_bytes()
}

///|
pub fn StreamInitResponseMeta::decode(
  body : Bytes,
) -> StreamInitResponseMeta raise @proto.PbError {
  let reader = @proto.PbReader::new(body)
  let meta = StreamInitResponseMeta::new()
  while !reader.eof() {
    let (field, wire) = reader.read_tag()
    match field {
      1 => meta.ret = reader.read_int32()
      2 => meta.error_msg = reader.read_bytes()
      _ => reader.skip(wire)
    }
  }
  meta
}

///|
pub fn StreamInitMeta::encode(self : StreamInitMeta) -> Bytes {
  let out = @proto.PbWriter::new()
  // The request meta is written even when it is empty: a server that sees an INIT frame
  // without one cannot name the method, and a peer that always writes it is what the
  // reference implementations do.
  out.bytes_(1, self.request_meta.encode())
  out.bytes_(2, self.response_meta.encode())
  if self.window != 0 {
    out.uint32(3, self.window)
  }
  if self.content_type != 0 {
    out.uint32(4, self.content_type)
  }
  if self.content_encoding != 0 {
    out.uint32(5, self.content_encoding)
  }
  out.to_bytes()
}

///|
pub fn StreamInitMeta::decode(
  body : Bytes,
) -> StreamInitMeta raise @proto.PbError {
  let reader = @proto.PbReader::new(body)
  let meta = StreamInitMeta::new()
  while !reader.eof() {
    let (field, wire) = reader.read_tag()
    match field {
      1 =>
        meta.request_meta = StreamInitRequestMeta::decode(reader.read_bytes())
      2 =>
        meta.response_meta = StreamInitResponseMeta::decode(reader.read_bytes())
      3 => meta.window = reader.read_uint32()
      4 => meta.content_type = reader.read_uint32()
      5 => meta.content_encoding = reader.read_uint32()
      _ => reader.skip(wire)
    }
  }
  meta
}

///|
pub fn StreamFeedbackMeta::encode(self : StreamFeedbackMeta) -> Bytes {
  let out = @proto.PbWriter::new()
  if self.window_increment != 0 {
    out.uint32(1, self.window_increment)
  }
  out.to_bytes()
}

///|
pub fn StreamFeedbackMeta::decode(
  body : Bytes,
) -> StreamFeedbackMeta raise @proto.PbError {
  let reader = @proto.PbReader::new(body)
  let meta = StreamFeedbackMeta::new()
  while !reader.eof() {
    let (field, wire) = reader.read_tag()
    match field {
      1 => meta.window_increment = reader.read_uint32()
      _ => reader.skip(wire)
    }
  }
  meta
}

///|
pub fn StreamCloseMeta::encode(self : StreamCloseMeta) -> Bytes {
  let out = @proto.PbWriter::new()
  if self.close_type != 0 {
    out.int32(1, self.close_type)
  }
  if self.ret != 0 {
    out.int32(2, self.ret)
  }
  if self.message.length() > 0 {
    out.bytes_(3, self.message)
  }
  if self.message_type != 0 {
    out.uint32(4, self.message_type)
  }
  write_map(out, 5, self.trans_info)
  if self.func_ret != 0 {
    out.int32(6, self.func_ret)
  }
  out.to_bytes()
}

///|
pub fn StreamCloseMeta::decode(
  body : Bytes,
) -> StreamCloseMeta raise @proto.PbError {
  let reader = @proto.PbReader::new(body)
  let meta = StreamCloseMeta::new()
  while !reader.eof() {
    let (field, wire) = reader.read_tag()
    match field {
      1 => meta.close_type = reader.read_int32()
      2 => meta.ret = reader.read_int32()
      3 => meta.message = reader.read_bytes()
      4 => meta.message_type = reader.read_uint32()
      5 => read_map(reader, meta.trans_info)
      6 => meta.func_ret = reader.read_int32()
      _ => reader.skip(wire)
    }
  }
  meta
}
