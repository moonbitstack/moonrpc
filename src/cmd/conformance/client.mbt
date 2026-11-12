// The client half of the Connect conformance suite: the runner writes one length-delimited
// `ClientCompatRequest` to standard input for every case, and this process writes one
// length-delimited `ClientCompatResponse` back for each.
//
// The runner compares the result against what the test case says should happen, so the work
// here is to run the call the request describes and report it in the runner's own terms: the
// headers and trailers as lists of values, the payloads exactly as the server wrote them, and
// the failure as the protocol's status code rather than as an error of this program. A message
// the server sent is relayed, not re-encoded: the payload is the bytes between the response
// message's field tag and the next field, so a `ConformancePayload` this build has no schema
// for still reaches the runner intact.

///|
/// The request as this driver needs it, decoded from the runner's `ClientCompatRequest`.
priv struct Case {
  mut name : String
  mut http_version : Int32
  mut codec : Int32
  mut compression : Int32
  mut host : String
  mut port : Int32
  mut receive_limit : Int32
  mut service : String
  mut method_name : String
  mut stream_type : Int32
  headers : Array[(String, Array[String])]
  // Every request message's type URL and its protobuf bytes, which is what an `Any` carries.
  mut type_url : String
  messages : Array[Bytes]
  mut timeout_ms : Int32?
  mut request_delay_ms : Int32
  // Which way the caller gives up, and after how long.
  mut cancel_kind : Int32
  mut cancel_millis : Int32
  mut cancel_responses : Int32
}

///|
let stream_unary : Int32 = 1

///|
let stream_client : Int32 = 2

///|
let stream_server : Int32 = 3

///|
let stream_half_bidi : Int32 = 4

///|
let stream_full_bidi : Int32 = 5

///|

///|
let codec_json : Int32 = 2

///|
let compress_gzip : Int32 = 2

///|
/// The driver's entry point: one request in, one result out, until the runner closes stdin.
pub fn client_main() -> Unit {
  @async.run_async_main(() => {
    for ;; {
      let frame = read_delimited() catch { _ => break }
      let request = match frame {
        None => break
        Some(bytes) => bytes
      }
      let answer = run_case(request)
      write_delimited(answer) catch {
        _ => break
      }
    }
  })
}

///|
/// A message behind a four-octet big-endian length, which is the framing the suite's handshake
/// uses in both directions.
async fn read_delimited() -> Bytes? {
  let head = @stdio.stdin.read_exactly(4)
  let mut length = 0
  for i in 0..<4 {
    length = (length << 8) | head[i].to_int()
  }
  if length <= 0 || length > 16 * 1024 * 1024 {
    return None
  }
  Some(@stdio.stdin.read_exactly(length))
}

///|
async fn write_delimited(message : Bytes) -> Unit {
  let out = @buffer.Buffer()
  let length = message.length()
  out.write_byte(((length >> 24) & 0xFF).to_byte())
  out.write_byte(((length >> 16) & 0xFF).to_byte())
  out.write_byte(((length >> 8) & 0xFF).to_byte())
  out.write_byte((length & 0xFF).to_byte())
  out.write_bytes(message)
  @stdio.stdout.write(out.to_bytes())
}

// -- the request ------------------------------------------------------------

///|
/// Decode one `ClientCompatRequest`.
fn Case::decode(bytes : Bytes) -> Case raise @proto.PbError {
  let reader = @proto.PbReader::new(bytes)
  let c : Case = {
    name: "",
    http_version: 0,
    codec: 0,
    compression: 0,
    host: "127.0.0.1",
    port: 0,
    receive_limit: 0,
    service: "connectrpc.conformance.v1.ConformanceService",
    method_name: "",
    stream_type: 0,
    headers: [],
    type_url: "",
    messages: [],
    timeout_ms: None,
    request_delay_ms: 0,
    cancel_kind: 0,
    cancel_millis: 0,
    cancel_responses: 0,
  }
  while !reader.eof() {
    let (field, wire) = reader.read_tag()
    match field {
      1 => c.name = reader.read_string()
      2 => c.http_version = reader.read_varint().to_int()
      4 => c.codec = reader.read_varint().to_int()
      5 => c.compression = reader.read_varint().to_int()
      6 => c.host = reader.read_string()
      7 => c.port = reader.read_varint().to_int()
      10 => c.receive_limit = reader.read_varint().to_int()
      11 => c.service = reader.read_string()
      12 => c.method_name = reader.read_string()
      13 => c.stream_type = reader.read_varint().to_int()
      15 => c.headers.push(read_header(reader.read_len_delim()))
      16 => {
        let any = read_any(reader.read_len_delim())
        c.type_url = any.0
        c.messages.push(any.1)
      }
      17 => c.timeout_ms = Some(reader.read_varint().to_int())
      18 => c.request_delay_ms = reader.read_varint().to_int()
      19 => {
        let (kind, millis, responses) = read_cancel(reader.read_len_delim())
        c.cancel_kind = kind
        c.cancel_millis = millis
        c.cancel_responses = responses
      }
      _ => reader.skip(wire)
    }
  }
  c
}

///|
/// A `Header`: a name and the values it carried, in order.
fn read_header(bytes : Bytes) -> (String, Array[String]) raise @proto.PbError {
  let reader = @proto.PbReader::new(bytes)
  let mut name = ""
  let values : Array[String] = []
  while !reader.eof() {
    let (field, wire) = reader.read_tag()
    match field {
      1 => name = reader.read_string()
      2 => values.push(reader.read_string())
      _ => reader.skip(wire)
    }
  }
  (name, values)
}

///|
/// A `google.protobuf.Any`: the type's URL and the message's own bytes.
fn read_any(bytes : Bytes) -> (String, Bytes) raise @proto.PbError {
  let reader = @proto.PbReader::new(bytes)
  let mut url = ""
  let mut value = b""
  while !reader.eof() {
    let (field, wire) = reader.read_tag()
    match field {
      1 => url = reader.read_string()
      2 => value = reader.read_len_delim()
      _ => reader.skip(wire)
    }
  }
  (url, value)
}

///|
/// `ClientCompatRequest.Cancel`: which of the three ways, as a kind this driver switches on.
fn read_cancel(bytes : Bytes) -> (Int32, Int32, Int32) raise @proto.PbError {
  let reader = @proto.PbReader::new(bytes)
  let mut kind = 0
  let mut millis = 0
  let mut responses = 0
  while !reader.eof() {
    let (field, wire) = reader.read_tag()
    match field {
      1 => {
        // `before_close_send`: cancel instead of closing the send side.
        ignore(reader.read_len_delim())
        kind = 1
      }
      2 => {
        millis = reader.read_varint().to_int()
        kind = 2
      }
      3 => {
        responses = reader.read_varint().to_int()
        kind = 3
      }
      _ => reader.skip(wire)
    }
  }
  (kind, millis, responses)
}

// -- running one case -------------------------------------------------------

///|
/// One case: the call, and the result in the runner's terms. Nothing here raises — a failure is
/// part of the answer, and a driver that died on one would stop answering the rest.
async fn run_case(request : Bytes) -> Bytes {
  let case = Case::decode(request) catch {
    e => return client_error("", "the request did not decode: " + e.to_string())
  }
  // One case may not hold up the rest: the runner gives each twenty seconds, and a driver
  // that hung on one would stop answering every case behind it.
  let outcome : Result[Result_?, Error] = Ok(
    @async.with_timeout_opt(15000, () => perform(case)),
  ) catch {
    e => Err(e)
  }
  match outcome {
    Ok(Some(result)) => ok_response(case.name, result)
    Ok(None) =>
      client_error(case.name, "the case did not finish in fifteen seconds")
    Err(e) => client_error(case.name, e.to_string())
  }
}

///|
/// What a call produced, in the terms the response message is written in.
priv struct Result_ {
  headers : Array[(String, Array[String])]
  trailers : Array[(String, Array[String])]
  payloads : Array[Bytes]
  error : Bytes?
}

///|
async fn perform(case : Case) -> Result_ {
  let schema = @reference.Service::new() catch {
    e =>
      raise @wire.StatusError(
        Internal,
        "the conformance definitions: " + e.to_string(),
      )
  }
  let path = "/" + case.service + "/" + case.method_name
  // The request's own type URL names the message better than the stream type does: a case may
  // carry a message whose type is not the one its method is declared with.
  // The schema keys its messages by their fully-qualified name with the leading dot that a
  // protobuf reference uses.
  let request_input = if case.type_url.length() > 0 {
    dotted(last_segment(case.type_url))
  } else {
    request_type(case)
  }
  let response_output = response_type(case)
  // The request messages in the codec the case asked for.
  let messages : Array[Bytes] = []
  for message in case.messages {
    match case.codec {
      c if c == codec_json =>
        messages.push(
          @utf8.encode(
            @moonjson.dumps(schema.schema().to_json(request_input, message)),
          ),
        )
      _ => messages.push(message)
    }
  }
  let content : @connect.Content = {
    codec: if case.codec == codec_json {
      Json
    } else {
      Proto
    },
    streaming: case.stream_type != stream_unary,
  }
  let metadata : Array[@header.Header] = []
  for (name, values) in case.headers {
    for value in values {
      metadata.push({
        name: @utf8.encode(name),
        value: @wire.metadata_value_to_wire(
          @utf8.encode(name),
          @utf8.encode(value),
        ),
      })
    }
  }
  if case.request_delay_ms > 0 {
    @async.sleep(case.request_delay_ms)
  }
  let encoding : String? = if case.compression == compress_gzip {
    Some("gzip")
  } else {
    None
  }
  let accept : Array[String] = if case.compression == compress_gzip {
    ["gzip"]
  } else {
    []
  }
  // A call with a deadline is the caller's to give up on: the header tells the far end what it
  // has left, and a caller that stopped waiting only when the far end said so would wait for
  // a server that is under no obligation to hurry.
  let attempt : Result[@connect.Reply?, @connect.Failure] = match
    case.timeout_ms {
    Some(millis) =>
      Ok(
        @async.with_timeout_opt(millis, () => {
          match case.cancel_kind {
            2 =>
              cancel_after(
                case, path, content, messages, metadata, encoding, accept,
              )
            _ => post(case, path, content, messages, metadata, encoding, accept)
          }
        }),
      ) catch {
        @connect.CallFailed(failure) => Err(failure)
        e =>
          Err({
            status: DeadlineExceeded,
            message: e.to_string(),
            details: [],
            headers: [],
            trailers: [],
            payloads: [],
          })
      }
    None =>
      Ok(
        Some(
          match case.cancel_kind {
            2 =>
              // The caller gives up a stated time after closing its send side. The call runs
              // on its own task so it can be abandoned; if it finished first, that is it.
              cancel_after(
                case, path, content, messages, metadata, encoding, accept,
              )
            _ => post(case, path, content, messages, metadata, encoding, accept)
          },
        ),
      ) catch {
        @connect.CallFailed(failure) => Err(failure)
        e => raise e
      }
  }
  // `with_timeout_opt` answers `None` when the deadline passed, which is the failure the
  // protocol names for it.
  let outcome : Result[@connect.Reply, @connect.Failure] = match attempt {
    Ok(Some(reply)) => Ok(reply)
    Ok(None) =>
      Err({
        status: DeadlineExceeded,
        message: "",
        details: [],
        headers: [],
        trailers: [],
        payloads: [],
      })
    Err(failure) => Err(failure)
  }
  // Whatever the server sent, in the runner's terms: each message relayed as the payload it
  // carried, and a failure as the protocol's status with what came with it.
  let payloads : Array[Bytes] = []
  let mut in_message_error : Bytes? = None
  let reply_messages = match outcome {
    Ok(reply) => reply.messages
    Err(failure) => failure.payloads
  }
  let limit = case.receive_limit
  for message in reply_messages {
    if limit > 0 && message.length() > limit {
      raise @wire.StatusError(
        ResourceExhausted,
        "a message of " +
        message.length().to_string() +
        " octets exceeded the limit",
      )
    }
    let (payload, error) = split_response(
      case, response_output, message, schema,
    )
    match error {
      Some(error) => in_message_error = Some(error)
      None => payloads.push(payload)
    }
  }
  let kept = match case.cancel_kind {
    // Giving up after a number of answers keeps the answers that arrived before giving up.
    3 =>
      if payloads.length() > case.cancel_responses {
        payloads[0:case.cancel_responses].to_owned()
      } else {
        payloads
      }
    _ => payloads
  }
  let (headers, trailers, failure) = match outcome {
    Ok(reply) => (reply.headers, reply.trailers, in_message_error)
    Err(failure) =>
      (
        failure.headers,
        failure.trailers,
        Some(
          error_bytes(
            @wire.Status::code(failure.status),
            failure.message,
            details=failure.details,
          ),
        ),
      )
  }
  // A call that posted no message and is supposed to answer one has failed the way a handler
  // that answered nothing does.
  if kept.length() == 0 &&
    failure is None &&
    (case.stream_type == stream_unary || case.stream_type == stream_client) {
    raise @wire.StatusError(Internal, "the call answered no message")
  }
  {
    headers: group_headers(headers),
    trailers: group_headers(trailers),
    payloads: kept,
    error: match failure {
      Some(error) => Some(error)
      // Giving up is an outcome of the call, whichever way it happened: the answers that did
      // arrive are kept and the failure is the one the protocol names for it.
      None =>
        if case.cancel_kind != 0 {
          Some(error_bytes(1, ""))
        } else {
          None
        }
    },
  }
}

///|
/// Give up a stated time after the send side closed. The call is abandoned, and what it managed
/// to read first is kept — a server that answers as it reads may have answered everything.
async fn cancel_after(
  case : Case,
  path : String,
  content : @connect.Content,
  messages : Array[Bytes],
  metadata : Array[@header.Header],
  encoding : String?,
  accept : Array[String],
) -> @connect.Reply {
  let done : Ref[@connect.Reply?] = Ref(None)
  @async.with_task_group(g => {
    let task = g.spawn(() => {
      let reply = post(
        case, path, content, messages, metadata, encoding, accept,
      ) catch {
        _ => return
      }
      done.val = Some(reply)
    })
    @async.sleep(case.cancel_millis)
    if done.val is None {
      task.cancel()
    }
  })
  match done.val {
    Some(reply) => reply
    None =>
      raise @connect.CallFailed({
        status: Cancelled,
        message: "",
        details: [],
        headers: [],
        trailers: [],
        payloads: [],
      })
  }
}

///|
/// A message name as the schema keys it: with the leading dot.
fn dotted(name : String) -> String {
  "." + name
}

///|
/// The name a type URL ends with: `type.googleapis.com/pkg.Msg` is `pkg.Msg`.
fn last_segment(url : String) -> String {
  let mut cut = 0
  let mut at = 0
  for ch in url {
    if ch == '/' {
      cut = at + 1
    }
    at = at + 1
  }
  url.exact_view(start=cut, end=url.length()).to_owned()
}

///|
/// The call itself, shaped by the stream type.
async fn post(
  case : Case,
  path : String,
  content : @connect.Content,
  messages : Array[Bytes],
  metadata : Array[@header.Header],
  encoding : String?,
  accept : Array[String],
) -> @connect.Reply {
  let timeout = case.timeout_ms
  if case.http_version == 2 {
    let transport = @net.Http2Transport::new(case.host, case.port)
    let client = @connect.Client::new(transport)
    call(
      client, case, path, content, messages, metadata, timeout, encoding, accept,
    )
  } else {
    let transport = @net.Http1Transport::new(case.host, case.port)
    let client = @connect.Client::new(transport)
    call(
      client, case, path, content, messages, metadata, timeout, encoding, accept,
    )
  }
}

///|
async fn[T : @connect.Transport] call(
  client : @connect.Client[T],
  case : Case,
  path : String,
  content : @connect.Content,
  messages : Array[Bytes],
  metadata : Array[@header.Header],
  timeout : Int32?,
  encoding : String?,
  accept : Array[String],
) -> @connect.Reply {
  match case.stream_type {
    t if t == stream_unary =>
      client.unary(
        path,
        messages[0],
        content~,
        metadata~,
        timeout_millis?=timeout,
        encoding?,
        accept~,
      )
    t if t == stream_server =>
      client.server_stream(
        path,
        messages[0],
        content~,
        metadata~,
        timeout_millis?=timeout,
        encoding?,
        accept~,
      )
    t if t == stream_client =>
      client.client_stream(
        path,
        messages,
        content~,
        metadata~,
        encoding?,
        accept~,
        timeout_millis?=timeout,
      )
    _ =>
      client.bidi(
        path,
        messages,
        content~,
        metadata~,
        encoding?,
        accept~,
        timeout_millis?=timeout,
      )
  }
}

///|
/// The two things a response message can carry, relayed as the bytes the runner decodes: the
/// `payload` field, and the `error` field a reference service puts a requested failure in.
fn split_response(
  case : Case,
  output_type : String,
  message : Bytes,
  schema : @reference.Service,
) -> (Bytes, Bytes?) raise {
  let body = match case.codec {
    c if c == codec_json => {
      // An empty body is an empty message: the JSON mapping writes one as nothing at all.
      if message.length() == 0 {
        return (b"", None)
      }
      let value = @moonjson.loads(
        @utf8.decode_lossy(message)[:],
        @moonjson.strict,
      ) catch {
        _ => raise @wire.StatusError(Internal, "the reply is not JSON")
      }
      schema.schema().to_bytes(output_type, value) catch {
        _ =>
          raise @wire.StatusError(
            Internal,
            "the reply does not fit its own schema",
          )
      }
    }
    _ => message
  }
  let reader = @proto.PbReader::new(body)
  let mut payload = b""
  let mut error = b""
  while !reader.eof() {
    let (field, wire) = reader.read_tag() catch { _ => break }
    match field {
      1 => payload = reader.read_len_delim() catch { _ => b"" }
      2 => error = reader.read_len_delim() catch { _ => b"" }
      _ => reader.skip(wire) catch { _ => break }
    }
  }
  if error.length() > 0 {
    return (b"", Some(error))
  }
  (payload, None)
}

///|
/// The request type a method of this shape takes, by the name the schema knows it under.
fn request_type(case : Case) -> String {
  let prefix = ".connectrpc.conformance.v1."
  if case.method_name == "Unimplemented" {
    return prefix + "UnimplementedRequest"
  }
  match case.stream_type {
    t if t == stream_client => prefix + "ClientStreamRequest"
    t if t == stream_server => prefix + "ServerStreamRequest"
    t if t == stream_half_bidi || t == stream_full_bidi =>
      prefix + "BidiStreamRequest"
    _ => prefix + "UnaryRequest"
  }
}

///|
fn response_type(case : Case) -> String {
  let prefix = ".connectrpc.conformance.v1."
  if case.method_name == "Unimplemented" {
    return prefix + "UnimplementedResponse"
  }
  match case.stream_type {
    t if t == stream_client => prefix + "ClientStreamResponse"
    t if t == stream_server => prefix + "ServerStreamResponse"
    t if t == stream_half_bidi || t == stream_full_bidi =>
      prefix + "BidiStreamResponse"
    _ => prefix + "UnaryResponse"
  }
}

///|
/// Header pairs grouped by name, in the order each name first appeared: the runner compares a
/// header as one entry carrying every value.
fn group_headers(
  headers : Array[@header.Header],
) -> Array[(String, Array[String])] {
  let names : Array[String] = []
  let values : Array[Array[String]] = []
  for header in headers {
    let name = @utf8.decode_lossy(header.name)
    let value = @utf8.decode_lossy(header.value)
    let mut at = -1
    for i in 0..<names.length() {
      if names[i] == name {
        at = i
        break
      }
    }
    if at < 0 {
      names.push(name)
      values.push([value])
    } else {
      values[at].push(value)
    }
  }
  let out : Array[(String, Array[String])] = []
  for i in 0..<names.length() {
    out.push((names[i], values[i]))
  }
  out
}

// -- the answer -------------------------------------------------------------

///|
/// A `ClientCompatResponse` carrying a result.
fn ok_response(name : String, result : Result_) -> Bytes {
  let body = @proto.PbWriter::new()
  for (header, values) in result.headers {
    body.message_(1, header_bytes(header, values))
  }
  for payload in result.payloads {
    body.message_(2, payload)
  }
  match result.error {
    Some(error) => body.message_(3, error)
    None => ()
  }
  for (header, values) in result.trailers {
    body.message_(4, header_bytes(header, values))
  }
  let response = @proto.PbWriter::new()
  response.string_(1, name)
  response.message_(2, body.to_bytes())
  response.to_bytes()
}

///|
/// A `ClientCompatResponse` saying the driver could not run the case at all.
fn client_error(name : String, message : String) -> Bytes {
  let body = @proto.PbWriter::new()
  body.string_(1, message)
  let response = @proto.PbWriter::new()
  response.string_(1, name)
  response.message_(3, body.to_bytes())
  response.to_bytes()
}

///|
fn header_bytes(name : String, values : Array[String]) -> Bytes {
  let out = @proto.PbWriter::new()
  out.string_(1, name)
  for value in values {
    out.string_(2, value)
  }
  out.to_bytes()
}

///|
/// An `Error`: the protocol's status code and its message. The runner compares the code, and
/// the message only where the case names one.
fn error_bytes(
  code : Int32,
  message : String,
  details~ : Array[Bytes] = [],
) -> Bytes {
  let out = @proto.PbWriter::new()
  out.enum_(1, code)
  if message.length() > 0 {
    out.string_(2, message)
  }
  for detail in details {
    out.message_(3, detail)
  }
  out.to_bytes()
}
