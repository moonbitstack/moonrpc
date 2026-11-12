// The Connect client: the same four call kinds as the server, over a transport that does one
// HTTP POST and returns the reply whole. It is written against the protocol, not against a
// socket, so the same client speaks HTTP/1.1 and HTTP/2 and a test needs neither.

///|
/// One HTTP exchange as the client sees it: where to post, what type the body is, the body,
/// and the headers that go with it. A transport answers with the status, the headers and the
/// reply body.
pub(open) trait Transport {
  async fn post(Self, String, Content, Bytes, Array[@header.Header]) -> (
    Int32,
    Array[@header.Header],
    Bytes,
  )
}

///|
/// A call that failed: the protocol's status and message, the details it carried, and the
/// metadata the failure arrived with. A protocol error still has a head and, for a streaming
/// call, an end — and a caller that compares one needs what came with it, not only the code.
pub(all) struct Failure {
  status : @wire.Status
  message : String
  details : Array[Bytes]
  headers : Array[@header.Header]
  trailers : Array[@header.Header]
  // The messages that arrived before the call failed. A stream that answers twice and then
  // fails has answered twice, and a caller that compares the call needs both halves.
  payloads : Array[Bytes]
}

///|
pub(all) suberror CallFailed {
  CallFailed(Failure)
}

///|
/// A client over one transport.
pub struct Client[T] {
  transport : T
}

///|
pub fn[T] Client::new(transport : T) -> Client[T] {
  { transport, }
}

///|
/// A reply the caller reads: the messages in order, the headers the server sent, and any
/// trailing metadata from the end-stream envelope.
pub(all) struct Reply {
  messages : Array[Bytes]
  headers : Array[@header.Header]
  trailers : Array[@header.Header]
}

///|
/// The metadata headers a reply carried, which are the ones that are not the protocol's own.
fn reply_headers(headers : Array[@header.Header]) -> Array[@header.Header] {
  let out : Array[@header.Header] = []
  for h in headers {
    let name = @utf8.decode_lossy(h.name)
    if name == "content-type" ||
      name == "content-length" ||
      name == "connect-protocol-version" ||
      name == "connect-content-encoding" ||
      name.has_prefix(":") {
      continue
    }
    out.push(h)
  }
  out
}

///|
/// Whether a body is a run of envelopes: the first octet is the flag byte, and the four after
/// it are the length of the message they stand for. An end-stream-only reply — the shape a
/// failed client-streaming call takes — has a first envelope whose flag is 2, so the check
/// has to admit every combination of the compressed and end-stream bits.
fn looks_enveloped(body : Bytes) -> Bool {
  if body.length() < 5 {
    return false
  }
  if body[0].to_int() > 3 {
    return false
  }
  let mut length = 0
  for i in 1..<5 {
    length = (length << 8) | body[i].to_int()
  }
  length >= 0 && length + 5 <= body.length()
}

///|
/// Whether any envelope in a streaming body says it is compressed. A peer that flags one
/// without naming an encoding in the headers has sent a body this client cannot read.
fn any_compressed(body : Bytes) -> Bool {
  let (envelopes, _at) = split_envelopes(body)
  for envelope in envelopes {
    if envelope.is_compressed() {
      return true
    }
  }
  false
}

///|
/// The reply's protocol headers, checked before its body is read. A codec the caller did not
/// ask for, a content type that is not a Connect body at all, and an encoding the caller did
/// not offer are all failures of the exchange, not of the service.
fn check_response(
  content : Content,
  headers : Array[@header.Header],
  compressed : Bool,
) -> Unit raise CallFailed {
  let violation = (status : @wire.Status, why : String) => {
    raise CallFailed({
      status,
      message: why,
      details: [],
      headers: reply_headers(headers),
      trailers: [],
      payloads: [],
    })
  }
  match header_of(headers, "content-type") {
    None => violation(Unknown, "the reply has no content type")
    Some(text) =>
      match Content::parse(text) {
        None => violation(Unknown, "the reply is not a Connect body")
        Some(actual) =>
          if actual != content {
            violation(
              Internal,
              "the reply is in a codec this call did not ask for",
            )
          }
      }
  }
  match header_of(headers, "content-encoding") {
    Some(name) =>
      if name != "identity" && name != "gzip" {
        violation(
          Internal,
          "the reply uses an encoding this client cannot read",
        )
      }
    None => ()
  }
  match header_of(headers, "connect-content-encoding") {
    Some(name) =>
      if name != "identity" && name != "gzip" {
        violation(
          Internal,
          "the stream uses an encoding this client cannot read",
        )
      } else if compressed && name == "identity" {
        violation(
          Internal,
          "a message is compressed but the stream says it is not",
        )
      }
    None =>
      if compressed {
        violation(Internal, "a message is compressed but no encoding was named")
      }
  }
}

///|
/// The envelope that closes a streaming request. Its payload is the end-stream message, which
/// the protocol writes as JSON whatever the body's codec is: it is the protocol's own message,
/// not the service's, so `{}` is what both ends read.
fn end_envelope(content : Content) -> Bytes {
  ignore(content)
  encode_envelope(b"{}", flags=flag_end_stream)
}

///|
/// The headers a call sends, with the deadline it asked for when it asked for one.
fn with_timeout(
  headers : Array[@header.Header],
  timeout : Int32?,
) -> Array[@header.Header] {
  match timeout {
    Some(millis) =>
      append(headers, {
        name: b"connect-timeout-ms",
        value: @utf8.encode(millis.to_string()),
      })
    None => headers
  }
}

///|
/// One message as an envelope, compressed with the request's encoding when it has one.
fn envelope_of(encoding : String?, message : Bytes) -> Bytes {
  match encoding {
    Some("gzip") => encode_envelope(@gzip.gzip(message), flags=flag_compressed)
    _ => encode_envelope(message)
  }
}

///|
/// A unary reply's headers, split into the ones that are headers and the ones a `Trailer-`
/// prefix marks as trailing metadata. That prefix is how the protocol gives a call whose body
/// is a single message a trailer channel without chunking it.
fn split_unary_headers(
  headers : Array[@header.Header],
) -> (Array[@header.Header], Array[@header.Header]) {
  let plain : Array[@header.Header] = []
  let trailers : Array[@header.Header] = []
  for h in headers {
    if @utf8.decode_lossy(h.name).to_lower().has_prefix("trailer-") {
      trailers.push({ name: h.name[8:].to_owned(), value: h.value, })
    } else {
      plain.push(h)
    }
  }
  (plain, trailers)
}

///|
/// The headers a call sends: the content type the body is in, what the caller reads back, the
/// encoding it compressed the request with, and its metadata.
fn request_headers(
  content : Content,
  metadata : Array[@header.Header],
  encoding : String?,
  accept : Array[String],
) -> Array[@header.Header] {
  let out : Array[@header.Header] = [
    { name: b"content-type", value: @utf8.encode(content.text()), },
    { name: b"connect-protocol-version", value: b"1", },
    { name: b"connect-accept-encoding", value: @utf8.encode(join(accept)), },
  ]
  // The protocol names the request's encoding differently by shape: a unary body is compressed
  // whole and says so with `content-encoding`, while a streaming one compresses each envelope
  // and names the algorithm with `connect-content-encoding`.
  match encoding {
    Some(name) =>
      out.push({
        name: if content.streaming {
          b"connect-content-encoding"
        } else {
          b"content-encoding"
        },
        value: @utf8.encode(name),
      })
    None => ()
  }
  for h in metadata {
    out.push(h)
  }
  out
}

///|
/// A comma-separated list, which is how an encoding list travels.
fn join(names : Array[String]) -> String {
  let mut out = ""
  for name in names {
    out = if out.length() == 0 { name } else { out + "," + name }
  }
  out
}

///|
/// The body of a request, compressed when the caller asked for an encoding this client writes.
fn encode_request(encoding : String?, body : Bytes) -> Bytes {
  match encoding {
    Some("gzip") => @gzip.gzip(body)
    _ => body
  }
}

///|
/// The value of the first header named `name`.
fn header_of(headers : Array[@header.Header], name : String) -> String? {
  for h in headers {
    if @utf8.decode_lossy(h.name).to_lower() == name {
      return Some(@utf8.decode_lossy(h.value).to_lower())
    }
  }
  None
}

///|
/// A reply body as the caller reads it, decompressed when the reply said it was compressed.
fn decode_reply(
  headers : Array[@header.Header],
  body : Bytes,
) -> Bytes raise CallFailed {
  match header_of(headers, "content-encoding") {
    Some("gzip") =>
      @gzip.gunzip(body[:]) catch {
        _ =>
          raise CallFailed({
            status: Internal,
            message: "the reply body would not inflate",
            details: [],
            headers: [],
            trailers: [],
            payloads: [],
          })
      }
    _ => body
  }
}

///|
/// Read a streaming reply body: every envelope, with the end-stream envelope's `metadata`
/// turned back into trailing headers and its `error` into a trailer the caller can see.
fn read_stream(
  body : Bytes,
) -> (Array[Bytes], Array[@header.Header]) raise CallFailed {
  let messages : Array[Bytes] = []
  let trailers : Array[@header.Header] = []
  let (envelopes, _at) = split_envelopes(body)
  for envelope in envelopes {
    if envelope.is_end_stream() {
      // The end-stream message may be compressed like any other: a peer that compresses its
      // envelopes compresses this one too, and the metadata it carries is inside.
      let payload = if envelope.is_compressed() {
        @gzip.gunzip(envelope.payload[:]) catch {
          _ => b""
        }
      } else {
        envelope.payload
      }
      let value = @moonjson.loads(
        @utf8.decode_lossy(payload)[:],
        @moonjson.strict,
      ) catch {
        _ => Json::null()
      }
      match value {
        Object(members) => {
          // `null` in the error field means the call succeeded. Only an object is an error;
          // dumping a `null` here would make every clean stream look like a failure.
          match members.get("error") {
            Some(error) =>
              match error {
                Object(_) =>
                  trailers.push({
                    name: b"connect-error",
                    value: @utf8.encode(@moonjson.dumps(error)),
                  })
                _ => ()
              }
            None => ()
          }
          match members.get("metadata") {
            Some(Object(metadata)) =>
              for name, item in metadata {
                match item {
                  String(text) =>
                    trailers.push({
                      name: @utf8.encode(name),
                      value: @utf8.encode(text),
                    })
                  Array(values) =>
                    for one in values {
                      match one {
                        String(text) =>
                          trailers.push({
                            name: @utf8.encode(name),
                            value: @utf8.encode(text),
                          })
                        _ => ()
                      }
                    }
                  _ => ()
                }
              }
            _ => ()
          }
        }
        _ => ()
      }
    } else if envelope.is_compressed() {
      let inflated : Result[Bytes, Error] = Ok(
        @gzip.gunzip(envelope.payload[:]),
      ) catch {
        e => Err(e)
      }
      match inflated {
        Ok(bytes) => messages.push(bytes)
        Err(_) =>
          raise CallFailed({
            status: Internal,
            message: "a reply message would not inflate",
            details: [],
            headers: [],
            trailers: [],
            payloads: [],
          })
      }
    } else {
      messages.push(envelope.payload)
    }
  }
  (messages, trailers)
}

///|
/// Turn a stream's envelopes into a reply, or into the failure its end-stream envelope
/// carries. The messages read before that failure are kept: a stream that answered twice and
/// then failed has still answered twice.
fn finish_stream(
  headers : Array[@header.Header],
  messages : Array[Bytes],
  trailers : Array[@header.Header],
) -> Reply raise CallFailed {
  for trailer in trailers {
    if @utf8.decode_lossy(trailer.name).to_lower() == "connect-error" {
      let value = @moonjson.loads(
        @utf8.decode_lossy(trailer.value)[:],
        @moonjson.strict,
      ) catch {
        _ => Json::null()
      }
      let (status, message) = error_of_json(value)
      raise CallFailed({
        status,
        message,
        details: error_details(value),
        headers: reply_headers(headers),
        trailers: trailers_without_error(trailers),
        payloads: messages,
      })
    }
  }
  {
    messages,
    headers: reply_headers(headers),
    trailers: trailers_without_error(trailers),
  }
}

///|
/// A unary call: one request message out, one reply message back, or the failure the server
/// answered with.
pub async fn[T : Transport] Client::unary(
  self : Client[T],
  path : String,
  request : Bytes,
  content~ : Content = { codec: Proto, streaming: false, },
  metadata~ : Array[@header.Header] = [],
  timeout_millis? : Int32,
  encoding? : String,
  accept~ : Array[String] = [],
) -> Reply {
  let headers = request_headers(content, metadata, encoding, accept)
  let all = match timeout_millis {
    Some(millis) =>
      append(headers, {
        name: b"connect-timeout-ms",
        value: @utf8.encode(millis.to_string()),
      })
    None => headers
  }
  let (status, raw_headers, body) = self.transport.post(
    path,
    content,
    encode_request(encoding, request),
    all,
  )
  let (headers, trailers) = split_unary_headers(raw_headers)
  if status != 200 {
    raise CallFailed(
      failure_of(status, body, headers, trailers_without_error(trailers)),
    )
  }
  check_response(content, headers, false)
  {
    messages: [decode_reply(headers, body)],
    headers: reply_headers(headers),
    trailers,
  }
}

///|
/// Every reply message of a server-streaming call.
pub async fn[T : Transport] Client::server_stream(
  self : Client[T],
  path : String,
  request : Bytes,
  content~ : Content = { codec: Proto, streaming: true, },
  metadata~ : Array[@header.Header] = [],
  timeout_millis? : Int32,
  encoding? : String,
  accept~ : Array[String] = [],
) -> Reply {
  let headers = request_headers(content, metadata, encoding, accept)
  let all = match timeout_millis {
    Some(millis) =>
      append(headers, {
        name: b"connect-timeout-ms",
        value: @utf8.encode(millis.to_string()),
      })
    None => headers
  }
  let body = Buffer()
  body.write_bytes(envelope_of(encoding, request))
  body.write_bytes(end_envelope(content))
  let (status, raw_headers, answer) = self.transport.post(
    path,
    content,
    body.to_bytes(),
    all,
  )
  if status != 200 {
    raise CallFailed(failure_of(status, answer, raw_headers, []))
  }
  let (headers, unary_trailers) = split_unary_headers(raw_headers)
  check_response(content, headers, any_compressed(answer))
  let (messages, trailers) = read_stream(answer)
  finish_stream(
    headers,
    messages,
    if trailers.length() > 0 {
      trailers
    } else {
      unary_trailers
    },
  )
}

///|
/// A client-streaming call: every request message out as a run of envelopes, and one reply
/// back. The reply is a unary one — the protocol says so — with its trailing metadata in the
/// `Trailer-` headers, the same shape a unary call's reply has.
pub async fn[T : Transport] Client::client_stream(
  self : Client[T],
  path : String,
  requests : Array[Bytes],
  content~ : Content = { codec: Proto, streaming: true, },
  metadata~ : Array[@header.Header] = [],
  encoding? : String,
  accept~ : Array[String] = [],
  timeout_millis? : Int32,
) -> Reply {
  let body = Buffer()
  for request in requests {
    body.write_bytes(envelope_of(encoding, request))
  }
  body.write_bytes(end_envelope(content))
  let (status, raw_headers, answer) = self.transport.post(
    path,
    content,
    body.to_bytes(),
    with_timeout(
      request_headers(content, metadata, encoding, accept),
      timeout_millis,
    ),
  )
  let (headers, trailers) = split_unary_headers(raw_headers)
  if status != 200 {
    raise CallFailed(
      failure_of(status, answer, headers, trailers_without_error(trailers)),
    )
  }
  check_response(content, headers, any_compressed(answer))
  // The protocol lets a client-streaming reply be either one bare message or a run of
  // envelopes holding one message; the reference implementations write the second, and a
  // reader that knew only the first would read the envelope's five-octet header as content.
  // A failure answers with envelopes too — often only the end-stream one — so the stream is
  // read before the reply's cardinality is judged.
  let reply = if looks_enveloped(answer) {
    let (messages, stream_trailers) = read_stream(answer)
    finish_stream(
      headers,
      messages,
      if stream_trailers.length() > 0 {
        stream_trailers
      } else {
        trailers
      },
    )
  } else {
    {
      messages: [decode_reply(headers, answer)],
      headers: reply_headers(headers),
      trailers,
    }
  }
  // A client-streaming call has exactly one answer. Zero or two is a broken exchange rather
  // than an application error, which the protocol names with `unimplemented`.
  if reply.messages.length() != 1 {
    raise CallFailed({
      status: Unimplemented,
      message: "a client-streaming call must answer exactly one message",
      details: [],
      headers: reply.headers,
      trailers: reply.trailers,
      payloads: [],
    })
  }
  reply
}

///|
/// A bidirectional call: the same request body as a client-streaming one, and a run of reply
/// envelopes closed by the end-stream envelope. A caller that sends everything before it reads
/// anything sees the same answers, in the same order, as one that reads as it goes.
pub async fn[T : Transport] Client::bidi(
  self : Client[T],
  path : String,
  requests : Array[Bytes],
  content~ : Content = { codec: Proto, streaming: true, },
  metadata~ : Array[@header.Header] = [],
  encoding? : String,
  accept~ : Array[String] = [],
  timeout_millis? : Int32,
) -> Reply {
  let body = Buffer()
  for request in requests {
    body.write_bytes(envelope_of(encoding, request))
  }
  body.write_bytes(end_envelope(content))
  let (status, raw_headers, answer) = self.transport.post(
    path,
    content,
    body.to_bytes(),
    with_timeout(
      request_headers(content, metadata, encoding, accept),
      timeout_millis,
    ),
  )
  if status != 200 {
    raise CallFailed(failure_of(status, answer, raw_headers, []))
  }
  let (headers, unary_trailers) = split_unary_headers(raw_headers)
  check_response(content, headers, any_compressed(answer))
  let (messages, trailers) = read_stream(answer)
  finish_stream(
    headers,
    messages,
    if trailers.length() > 0 {
      trailers
    } else {
      unary_trailers
    },
  )
}

///|
fn append(
  headers : Array[@header.Header],
  extra : @header.Header,
) -> Array[@header.Header] {
  let out = []
  for h in headers {
    out.push(h)
  }
  out.push(extra)
  out
}

///|
fn trailers_without_error(
  trailers : Array[@header.Header],
) -> Array[@header.Header] {
  let out = []
  for h in trailers {
    if @utf8.decode_lossy(h.name) != "connect-error" {
      out.push(h)
    }
  }
  out
}

///|
/// The failure a reply stands for: the code and message from the body, the details the body
/// lists, and the metadata that came with it.
fn failure_of(
  status_code : Int32,
  body : Bytes,
  headers : Array[@header.Header],
  trailers : Array[@header.Header],
) -> Failure {
  // An error body is compressed like any other response body. The header that says so is a
  // protocol header, so it is still in `headers` here rather than filtered out.
  let plain = match header_of(headers, "content-encoding") {
    Some("gzip") => @gzip.gunzip(body[:]) catch { _ => body }
    _ => body
  }
  let value = @moonjson.loads(@utf8.decode_lossy(plain)[:], @moonjson.strict) catch {
    _ => Json::null()
  }
  // A body with a missing, null or unrecognized code is not a well-formed error. The HTTP
  // status is then the only code the exchange carried, and the protocol's implementations
  // fall back to it rather than inventing `unknown`.
  let fallback = status_of_http(status_code)
  let (status, message) = match value {
    Object(members) => {
      let code = match members.get("code") {
        Some(String(name)) => {
          let named = status_of_code(name)
          if named == Unknown && name != "unknown" {
            fallback
          } else {
            named
          }
        }
        _ => fallback
      }
      let message = match members.get("message") {
        Some(String(text)) => text
        _ => ""
      }
      (code, message)
    }
    _ => (fallback, "")
  }
  {
    status,
    message,
    details: error_details(value),
    headers: reply_headers(headers),
    trailers,
    payloads: [],
  }
}

///|
/// The status an HTTP status stands for when there is no error body, by the mapping the
/// protocol's own implementations use.
fn status_of_http(status : Int32) -> @wire.Status {
  match status {
    // A 400 is an internal failure: a Connect client that sent a well-formed request cannot
    // be the one at fault for the shape of the reply. The other unmapped statuses — 409, 412,
    // 413, 415, 431, 505 — have no protocol meaning and stay `unknown`.
    400 => @wire.Status::Internal
    401 => @wire.Status::Unauthenticated
    403 => @wire.Status::PermissionDenied
    404 => @wire.Status::Unimplemented
    429 | 502 | 503 | 504 => @wire.Status::Unavailable
    _ => @wire.Status::Unknown
  }
}
