// trpc.io's protocol: the envelope its HTTP links put around a call.
//
// tRPC for TypeScript is not the `trpc.group` protocol in `trpc/`. That one is a binary
// framed protocol from Tencent's tRPC; this one is JSON over HTTP, with a batching envelope
// borrowed from JSON-RPC's shape but not its method dispatch: a call names its own path in
// the URL, and the body carries only inputs.
//
// A single call puts its input in the body as-is (or in `?input=`, url-encoded). A batch
// wraps each input in an object keyed by its position — `{"0":<input>,"1":<input>}` — and
// names the procedures in the URL as a comma-separated list with `?batch=1`. The reply is
// the same shape: one item, or an array of them, each either `{"result":{"data":...}}` or
// `{"error":{...}}`.
//
// The transformer is identity here. tRPC's `superjson` transformer wraps every value as
// `{"json": ...}`; a caller that wants that can hand `trpcio` the serialised value and read
// it back the same way, which is what the client's `transformer=` parameter is for.

///|
/// One call as the protocol states it: the procedure's path and its input, or no input at
/// all — a call with nothing to say sends no body and no `input` parameter.
pub(all) struct Call {
  path : String
  input : Json?
}

///|
pub fn Call::new(path : String, input? : Json) -> Call {
  { path, input }
}

///|
/// The procedures a batch names, in the order the reply will answer them.
fn paths_of(calls : Array[Call]) -> String {
  let out = StringBuilder()
  for index, call in calls {
    if index > 0 {
      out.write_char(',')
    }
    out.write_string(call.path)
  }
  out.to_string()
}

///|
/// The body one call sends. A call with no input has no body at all, which is not the same
/// as a body of `null`: the server passes `undefined` for the first and `null` for the second.
pub fn single_body(call : Call) -> String {
  match call.input {
    Some(value) => @moonjson.dumps(value)
    None => ""
  }
}

///|
/// The body a batch sends: one entry per call, keyed by position, with a call that has no
/// input left out rather than written as `null`.
pub fn batch_body(calls : Array[Call]) -> String {
  let out = StringBuilder()
  out.write_char('{')
  let mut first = true
  for index, call in calls {
    match call.input {
      Some(value) => {
        if !first {
          out.write_char(',')
        }
        first = false
        out.write_char('"')
        out.write_string(index.to_string())
        out.write_string("\":")
        out.write_string(@moonjson.dumps(value))
      }
      None => ()
    }
  }
  out.write_char('}')
  out.to_string()
}

///|
/// What one call answered: a value, or the failure the server described.
pub(all) enum Outcome {
  Ok(Json)
  Failed(Failure)
}

///|
/// A tRPC failure as the server states it: the JSON-RPC code, the name of the tRPC code, the
/// HTTP status it maps to, the message, and the procedure it happened in.
pub(all) struct Failure {
  code : Int
  name : String
  http_status : Int
  message : String
  path : String
  data : Json
}

///|
/// The name a JSON-RPC code stands for, from tRPC's own table: the codes above -32000 are
/// JSON-RPC's, and the rest are tRPC's, ending in the digits of the HTTP status they carry.
pub fn failure_name(code : Int) -> String {
  match code {
    -32700 => "PARSE_ERROR"
    -32600 => "BAD_REQUEST"
    -32603 => "INTERNAL_SERVER_ERROR"
    -32001 => "UNAUTHORIZED"
    -32002 => "PAYMENT_REQUIRED"
    -32003 => "FORBIDDEN"
    -32004 => "NOT_FOUND"
    -32005 => "METHOD_NOT_SUPPORTED"
    -32008 => "TIMEOUT"
    -32009 => "CONFLICT"
    -32012 => "PRECONDITION_FAILED"
    -32013 => "PAYLOAD_TOO_LARGE"
    -32015 => "UNSUPPORTED_MEDIA_TYPE"
    -32022 => "UNPROCESSABLE_CONTENT"
    -32028 => "PRECONDITION_REQUIRED"
    -32029 => "TOO_MANY_REQUESTS"
    -32099 => "CLIENT_CLOSED_REQUEST"
    _ => "INTERNAL_SERVER_ERROR"
  }
}

///|
/// The JSON-RPC code a name stands for — the inverse of `failure_name`, used by a server
/// answering in this protocol.
pub fn failure_code(name : String) -> Int {
  match name {
    "PARSE_ERROR" => -32700
    "BAD_REQUEST" => -32600
    "UNAUTHORIZED" => -32001
    "PAYMENT_REQUIRED" => -32002
    "FORBIDDEN" => -32003
    "NOT_FOUND" => -32004
    "METHOD_NOT_SUPPORTED" => -32005
    "TIMEOUT" => -32008
    "CONFLICT" => -32009
    "PRECONDITION_FAILED" => -32012
    "PAYLOAD_TOO_LARGE" => -32013
    "UNSUPPORTED_MEDIA_TYPE" => -32015
    "UNPROCESSABLE_CONTENT" => -32022
    "PRECONDITION_REQUIRED" => -32028
    "TOO_MANY_REQUESTS" => -32029
    "CLIENT_CLOSED_REQUEST" => -32099
    _ => -32603
  }
}

///|
/// The HTTP status a tRPC code is carried under. Every one of tRPC's codes is named after an
/// HTTP status, and this is that mapping read the other way.
pub fn failure_status(name : String) -> Int {
  match name {
    "PARSE_ERROR" => 400
    "BAD_REQUEST" => 400
    "UNAUTHORIZED" => 401
    "PAYMENT_REQUIRED" => 402
    "FORBIDDEN" => 403
    "NOT_FOUND" => 404
    "METHOD_NOT_SUPPORTED" => 405
    "TIMEOUT" => 408
    "CONFLICT" => 409
    "PRECONDITION_FAILED" => 412
    "PAYLOAD_TOO_LARGE" => 413
    "UNSUPPORTED_MEDIA_TYPE" => 415
    "UNPROCESSABLE_CONTENT" => 422
    "PRECONDITION_REQUIRED" => 428
    "TOO_MANY_REQUESTS" => 429
    "CLIENT_CLOSED_REQUEST" => 499
    _ => 500
  }
}

///|
/// The failure a server answering in this protocol writes: the shape `getErrorShape` builds,
/// which is what a tRPC client reads to reconstruct its `TRPCClientError`.
pub fn failure_of(
  name : String,
  message : String,
  path~ : String = "",
  cause~ : Json = Json::null(),
) -> Failure {
  let code = failure_code(name)
  let status = failure_status(name)
  {
    code,
    name,
    http_status: status,
    message,
    path,
    data: {
      "code": Json::string(name),
      "httpStatus": Json::number(status.to_double()),
      "path": Json::string(path),
      "stack": Json::null(),
      "cause": cause,
    },
  }
}

///|
/// One item of a reply body.
fn outcome_json(outcome : Outcome) -> Json {
  match outcome {
    Ok(value) => { "result": { "data": value } }
    Failed(failure) =>
      {
        "error": {
          "message": Json::string(failure.message),
          "code": Json::number(failure.code.to_double()),
          "data": failure.data,
        },
      }
  }
}

///|
/// The body of a reply: one item alone, or an array of them for a batch.
pub fn encode_reply(outcomes : Array[Outcome], batch~ : Bool) -> String {
  if batch {
    return @moonjson.dumps(Json::array(outcomes.map(outcome_json)))
  }
  match outcomes {
    [one] => @moonjson.dumps(outcome_json(one))
    [] => @moonjson.dumps(Json::null())
    _ =>
      // More than one answer to a call that was not a batch: answer them all rather than
      // drop one, and let the caller see the shape it asked for.
      @moonjson.dumps(Json::array(outcomes.map(outcome_json)))
  }
}

///|
/// A failure read back from the wire.
fn failure_from_json(value : Json) -> Failure {
  let message = match value {
    Object(members) =>
      match members.get("message") {
        Some(String(text)) => text
        _ => ""
      }
    _ => ""
  }
  let code = match value {
    Object(members) =>
      match members.get("code") {
        Some(Number(number, ..)) => number.to_int()
        _ => -32603
      }
    _ => -32603
  }
  let data = match value {
    Object(members) =>
      match members.get("data") {
        Some(inner) => inner
        None => Json::null()
      }
    _ => Json::null()
  }
  let name = match data {
    Object(members) =>
      match members.get("code") {
        Some(String(text)) => text
        _ => failure_name(code)
      }
    _ => failure_name(code)
  }
  let http_status = match data {
    Object(members) =>
      match members.get("httpStatus") {
        Some(Number(number, ..)) => number.to_int()
        _ => failure_status(name)
      }
    _ => failure_status(name)
  }
  let path = match data {
    Object(members) =>
      match members.get("path") {
        Some(String(text)) => text
        _ => ""
      }
    _ => ""
  }
  { code, name, http_status, message, path, data }
}

///|
/// One item of a reply read back.
fn outcome_of_json(value : Json) -> Outcome {
  match value {
    Object(members) =>
      match members.get("error") {
        Some(error) => Failed(failure_from_json(error))
        None =>
          match members.get("result") {
            Some(Object(result)) =>
              match result.get("data") {
                Some(data) => Ok(data)
                None => Ok(Json::null())
              }
            _ => Ok(Json::null())
          }
      }
    _ => Failed(failure_of("BAD_REQUEST", "the reply was not an object"))
  }
}

///|
/// Read a reply body. `batch` says whether an array is the shape the caller asked for;
/// a server that answers a single call with an array is still understood, because that is
/// what a batch of one looks like.
pub fn decode_reply(body : String, batch~ : Bool) -> Array[Outcome]? {
  let value = @moonjson.loads(body, @moonjson.strict) catch {
    _ => return None
  }
  // A batch answered with one object is a batch of one, and a single call answered with an
  // array is the same thing read the other way: the shape does not decide the meaning.
  match value {
    Array(items) => Some(items.map(outcome_of_json))
    _ => Some([outcome_of_json(value)])
  }
}

///|
/// The inputs a request body carries. A single call sends its input bare; a batch sends an
/// object keyed by position, and a call with no input is absent rather than null.
pub fn decode_inputs(body : String, batch~ : Bool) -> Array[Json?]? {
  if body.length() == 0 {
    return Some(if batch { [] } else { [None] })
  }
  let value = @moonjson.loads(body, @moonjson.strict) catch {
    _ => return None
  }
  if !batch {
    return Some([Some(value)])
  }
  match value {
    Object(members) => {
      let count = members.length()
      let out : Array[Json?] = []
      for index = 0; index < count; index = index + 1 {
        match members.get(index.to_string()) {
          Some(item) => out.push(Some(item))
          None => out.push(None)
        }
      }
      Some(out)
    }
    _ => None
  }
}

///|
/// The path list a batch request names: `a.b,c.d`.
pub fn decode_paths(path : String) -> Array[String] {
  let out : Array[String] = []
  for part in path.split(",") {
    let trimmed = part.trim(chars=" ").to_owned()
    if trimmed.length() > 0 {
      out.push(trimmed)
    }
  }
  out
}

///|
/// The request a client makes of this protocol: whether it is a batch, which procedures it
/// names, and what body to send.
pub(all) struct Request {
  // The path as it goes on the wire: one procedure, or a comma-separated list for a batch.
  target : String
  batch : Bool
  body : String
  // Whether the call may be made with GET, which is what tRPC's httpLink does for a query.
  get : Bool
}

///|
/// The request one call is made with. A query goes out as a GET with its input in the query
/// string, as tRPC's httpLink does, and anything else is a POST.
pub fn request_of(call : Call, get~ : Bool = false) -> Request {
  let body = single_body(call)
  if get && body.length() > 0 {
    {
      target: call.path + "?input=" + percent_encode(body),
      batch: false,
      body: "",
      get: true,
    }
  } else {
    { target: call.path, batch: false, body, get: false }
  }
}

///|
/// The request a batch of calls is made with.
pub fn batch_request_of(calls : Array[Call], get~ : Bool = false) -> Request {
  let body = batch_body(calls)
  let paths = paths_of(calls)
  if get && body.length() > 0 {
    {
      target: paths +
        "?batch=1&input=" +
        percent_encode(body),
      batch: true,
      body: "",
      get: true,
    }
  } else {
    { target: paths + "?batch=1", batch: true, body, get: false }
  }
}

///|
/// Percent-encode what a query parameter cannot carry literally. tRPC's own client uses
/// `encodeURIComponent`, which leaves `A-Za-z0-9-_.!~*'()` alone and escapes the rest.
pub fn percent_encode(text : String) -> String {
  let bytes = @utf8.encode(text)
  let out = StringBuilder()
  for byte in bytes {
    let value = byte.to_int()
    let plain = (value >= 0x41 && value <= 0x5A) ||
      (value >= 0x61 && value <= 0x7A) ||
      (value >= 0x30 && value <= 0x39) ||
      value == 0x2D ||
      value == 0x5F ||
      value == 0x2E ||
      value == 0x21 ||
      value == 0x7E ||
      value == 0x2A ||
      value == 0x27 ||
      value == 0x28 ||
      value == 0x29
    if plain {
      out.write_char(byte.to_char())
    } else {
      out.write_string("%")
      out.write_string(hex_of(value / 16))
      out.write_string(hex_of(value % 16))
    }
  }
  out.to_string()
}

///|
fn hex_of(nibble : Int) -> String {
  let digits = "0123456789ABCDEF"
  digits[nibble:nibble + 1].to_owned()
}

///|
/// Percent-decode a query parameter.
pub fn percent_decode(text : String) -> String {
  let bytes = @utf8.encode(text)
  let out = Buffer()
  let mut at = 0
  while at < bytes.length() {
    if bytes[at] == b'%' && at + 2 < bytes.length() {
      let hi = hex_value(bytes[at + 1].to_int())
      let lo = hex_value(bytes[at + 2].to_int())
      if hi >= 0 && lo >= 0 {
        out.write_byte((hi * 16 + lo).to_byte())
        at = at + 3
        continue
      }
    }
    // `+` is a space in a query string, the way `application/x-www-form-urlencoded` reads it.
    if bytes[at] == b'+' {
      out.write_byte(b' ')
    } else {
      out.write_byte(bytes[at])
    }
    at = at + 1
  }
  @utf8.decode_lossy(out.to_bytes())
}

///|
fn hex_value(value : Int) -> Int {
  if value >= 0x30 && value <= 0x39 {
    value - 0x30
  } else if value >= 0x61 && value <= 0x66 {
    value - 0x61 + 10
  } else if value >= 0x41 && value <= 0x46 {
    value - 0x41 + 10
  } else {
    -1
  }
}
