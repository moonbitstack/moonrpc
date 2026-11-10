// `RequestProtocol` and `ResponseProtocol`, the unary headers, plus the type codes both
// ends agree on. Encoded as the protobuf messages `trpc/trpc.proto` declares.

///|
/// The only protocol version the reference implementations write.
pub let version_v1 : UInt32 = 1

///|
/// `TrpcCallType_TRPC_UNARY_CALL`.
pub let call_unary : UInt32 = 0

///|
/// `TrpcCallType_TRPC_ONEWAY_CALL`: the caller does not wait for an answer.
pub let call_oneway : UInt32 = 1

///|
/// `TrpcContentEncodeType_TRPC_PROTO_ENCODE`, the default.
pub let encode_proto : UInt32 = 0

///|
/// `TrpcContentEncodeType_TRPC_JSON_ENCODE`.
pub let encode_json : UInt32 = 2

///|
/// `TrpcCompressType_TRPC_DEFAULT_COMPRESS`, i.e. no compression.
pub let compress_none : UInt32 = 0

///|
/// `TrpcCompressType_TRPC_GZIP_COMPRESS`.
pub let compress_gzip : UInt32 = 1

///|
/// `TrpcCompressType_TRPC_ZLIB_COMPRESS`.
pub let compress_zlib : UInt32 = 3

///|
/// `TrpcMessageType_TRPC_DYEING_MESSAGE`: the call carries a dyeing key.
pub let message_dyeing : UInt32 = 0x01

///|
/// `TrpcMessageType_TRPC_TRACE_MESSAGE`.
pub let message_trace : UInt32 = 0x02

///|
/// `TrpcMessageType_TRPC_MULTI_ENV_MESSAGE`.
pub let message_multi_env : UInt32 = 0x04

///|
/// `TrpcMessageType_TRPC_GRID_MESSAGE`.
pub let message_grid : UInt32 = 0x08

///|
/// `TrpcMessageType_TRPC_SETNAME_MESSAGE`.
pub let message_setname : UInt32 = 0x10

///|
/// The framework's key for the dyeing mark, carried in `trans_info` like any other.
pub let dyeing_key : String = "trpc-dyeing-key"

///|
/// The framework's key for the environment a call is routed to.
pub let env_key : String = "trpc-env"

///|
/// The unary request header. Every field is `RequestProtocol`'s, with the same number.
pub(all) struct Request {
  mut version : UInt32
  mut call_type : UInt32
  mut request_id : UInt32
  mut timeout : UInt32
  mut caller : Bytes
  mut callee : Bytes
  mut func : Bytes
  mut message_type : UInt32
  mut trans_info : Map[String, Bytes]
  mut content_type : UInt32
  mut content_encoding : UInt32
  mut attachment_size : UInt32
}

///|
pub fn Request::new(
  version~ : UInt32 = version_v1,
  caller~ : String = "",
  callee~ : String = "",
  func~ : String = "",
  request_id~ : UInt32 = 0,
  timeout~ : UInt32 = 0,
  call_type~ : UInt32 = call_unary,
  content_type~ : UInt32 = encode_proto,
  content_encoding~ : UInt32 = compress_none,
  message_type~ : UInt32 = 0,
  trans_info~ : Map[String, Bytes] = Map([]),
) -> Request {
  {
    version,
    call_type,
    request_id,
    timeout,
    caller: @utf8.encode(caller),
    callee: @utf8.encode(callee),
    func: @utf8.encode(func),
    message_type,
    trans_info,
    content_type,
    content_encoding,
    attachment_size: 0,
  }
}

///|
/// The path a call names. `func` is the field a server routes on; the Python
/// implementation leaves it out and sends only `callee`, so that is the fallback rather
/// than an error.
pub fn Request::path(self : Request) -> String {
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
/// The unary response header.
pub(all) struct Response {
  mut version : UInt32
  mut call_type : UInt32
  mut request_id : UInt32
  mut ret : Int32
  mut func_ret : Int32
  mut error_msg : Bytes
  mut message_type : UInt32
  mut trans_info : Map[String, Bytes]
  mut content_type : UInt32
  mut content_encoding : UInt32
  mut attachment_size : UInt32
}

///|
pub fn Response::new(
  request_id~ : UInt32 = 0,
  ret~ : Int32 = 0,
  func_ret~ : Int32 = 0,
  call_type~ : UInt32 = call_unary,
  content_type~ : UInt32 = encode_proto,
  content_encoding~ : UInt32 = compress_none,
  version~ : UInt32 = version_v1,
) -> Response {
  {
    version,
    call_type,
    request_id,
    ret,
    func_ret,
    error_msg: b"",
    message_type: 0,
    trans_info: Map([]),
    content_type,
    content_encoding,
    attachment_size: 0,
  }
}

///|
/// The answer to a request: the codes the request carried, and no error.
pub fn Response::to(request : Request) -> Response {
  {
    version: version_v1,
    call_type: request.call_type,
    request_id: request.request_id,
    ret: 0,
    func_ret: 0,
    error_msg: b"",
    message_type: request.message_type,
    trans_info: Map([]),
    content_type: request.content_type,
    content_encoding: request.content_encoding,
    attachment_size: 0,
  }
}

///|
fn write_trans_info(
  out : @proto.PbWriter,
  field : Int32,
  trans_info : Map[String, Bytes],
) -> Unit {
  // Sorted, because a map has no order of its own and two encoders that disagree on one
  // produce frames that differ byte for byte while meaning the same thing.
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
fn read_trans_info(
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
/// `RequestProtocol` as the reference implementations write it.
pub fn Request::encode(self : Request) -> Bytes {
  let out = @proto.PbWriter::new()
  if self.version != 0 {
    out.uint32(1, self.version)
  }
  if self.call_type != 0 {
    out.uint32(2, self.call_type)
  }
  if self.request_id != 0 {
    out.uint32(3, self.request_id)
  }
  if self.timeout != 0 {
    out.uint32(4, self.timeout)
  }
  if self.caller.length() > 0 {
    out.bytes_(5, self.caller)
  }
  if self.callee.length() > 0 {
    out.bytes_(6, self.callee)
  }
  if self.func.length() > 0 {
    out.bytes_(7, self.func)
  }
  if self.message_type != 0 {
    out.uint32(8, self.message_type)
  }
  write_trans_info(out, 9, self.trans_info)
  if self.content_type != 0 {
    out.uint32(10, self.content_type)
  }
  if self.content_encoding != 0 {
    out.uint32(11, self.content_encoding)
  }
  if self.attachment_size != 0 {
    out.uint32(12, self.attachment_size)
  }
  out.to_bytes()
}

///|
/// Read a `RequestProtocol`. A field this library does not know is skipped, which is what
/// keeps a peer that added one usable.
pub fn Request::decode(body : Bytes) -> Request raise @proto.PbError {
  let reader = @proto.PbReader::new(body)
  let request = Request::new()
  while !reader.eof() {
    let (field, wire) = reader.read_tag()
    match field {
      1 => request.version = reader.read_uint32()
      2 => request.call_type = reader.read_uint32()
      3 => request.request_id = reader.read_uint32()
      4 => request.timeout = reader.read_uint32()
      5 => request.caller = reader.read_bytes()
      6 => request.callee = reader.read_bytes()
      7 => request.func = reader.read_bytes()
      8 => request.message_type = reader.read_uint32()
      9 => read_trans_info(reader, request.trans_info)
      10 => request.content_type = reader.read_uint32()
      11 => request.content_encoding = reader.read_uint32()
      12 => request.attachment_size = reader.read_uint32()
      _ => reader.skip(wire)
    }
  }
  request
}

///|
/// `ResponseProtocol`, field for field.
pub fn Response::encode(self : Response) -> Bytes {
  let out = @proto.PbWriter::new()
  if self.version != 0 {
    out.uint32(1, self.version)
  }
  if self.call_type != 0 {
    out.uint32(2, self.call_type)
  }
  if self.request_id != 0 {
    out.uint32(3, self.request_id)
  }
  if self.ret != 0 {
    out.int32(4, self.ret)
  }
  if self.func_ret != 0 {
    out.int32(5, self.func_ret)
  }
  if self.error_msg.length() > 0 {
    out.bytes_(6, self.error_msg)
  }
  if self.message_type != 0 {
    out.uint32(7, self.message_type)
  }
  write_trans_info(out, 8, self.trans_info)
  if self.content_type != 0 {
    out.uint32(9, self.content_type)
  }
  if self.content_encoding != 0 {
    out.uint32(10, self.content_encoding)
  }
  if self.attachment_size != 0 {
    out.uint32(12, self.attachment_size)
  }
  out.to_bytes()
}

///|
pub fn Response::decode(body : Bytes) -> Response raise @proto.PbError {
  let reader = @proto.PbReader::new(body)
  let response = Response::new()
  while !reader.eof() {
    let (field, wire) = reader.read_tag()
    match field {
      1 => response.version = reader.read_uint32()
      2 => response.call_type = reader.read_uint32()
      3 => response.request_id = reader.read_uint32()
      4 => response.ret = reader.read_int32()
      5 => response.func_ret = reader.read_int32()
      6 => response.error_msg = reader.read_bytes()
      7 => response.message_type = reader.read_uint32()
      8 => read_trans_info(reader, response.trans_info)
      9 => response.content_type = reader.read_uint32()
      10 => response.content_encoding = reader.read_uint32()
      12 => response.attachment_size = reader.read_uint32()
      _ => reader.skip(wire)
    }
  }
  response
}
