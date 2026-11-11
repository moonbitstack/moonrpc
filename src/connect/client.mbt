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
/// The headers a call sends: the content type the body is in, and the caller's metadata.
fn request_headers(
  content : Content,
  metadata : Array[@header.Header],
) -> Array[@header.Header] {
  let out : Array[@header.Header] = [
    { name: b"content-type", value: @utf8.encode(content.text()), },
    { name: b"connect-protocol-version", value: b"1", },
    { name: b"connect-accept-encoding", value: b"identity", },
  ]
  for h in metadata {
    out.push(h)
  }
  out
}

///|
/// Read a streaming reply body: every envelope, with the end-stream envelope's `metadata`
/// turned back into trailing headers and its `error` into a trailer the caller can see.
fn read_stream(body : Bytes) -> (Array[Bytes], Array[@header.Header]) {
  let messages : Array[Bytes] = []
  let trailers : Array[@header.Header] = []
  let (envelopes, _at) = split_envelopes(body)
  for envelope in envelopes {
    if envelope.is_end_stream() {
      let value = @moonjson.loads(
        @utf8.decode_lossy(envelope.payload)[:],
        @moonjson.strict,
      ) catch {
        _ => Json::null()
      }
      match value {
        Object(members) => {
          match members.get("error") {
            Some(error) =>
              trailers.push({
                name: b"connect-error",
                value: @utf8.encode(@moonjson.dumps(error)),
              })
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
    } else {
      messages.push(envelope.payload)
    }
  }
  (messages, trailers)
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
) -> Reply {
  let headers = request_headers(content, metadata)
  let all = match timeout_millis {
    Some(millis) =>
      append(headers, {
        name: b"connect-timeout-ms",
        value: @utf8.encode(millis.to_string()),
      })
    None => headers
  }
  let (status, raw_headers, body) = self.transport.post(
    path, content, request, all,
  )
  if status != 200 {
    let (code, message) = error_of_status(status, body)
    raise @wire.StatusError(code, message)
  }
  let (headers, trailers) = split_unary_headers(raw_headers)
  { messages: [body], headers: reply_headers(headers), trailers, }
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
) -> Reply {
  let headers = request_headers(content, metadata)
  let all = match timeout_millis {
    Some(millis) =>
      append(headers, {
        name: b"connect-timeout-ms",
        value: @utf8.encode(millis.to_string()),
      })
    None => headers
  }
  let body = Buffer()
  body.write_bytes(encode_envelope(request))
  body.write_bytes(encode_envelope(b"", flags=flag_end_stream))
  let (status, raw_headers, answer) = self.transport.post(
    path,
    content,
    body.to_bytes(),
    all,
  )
  if status != 200 {
    let (code, message) = error_of_status(status, answer)
    raise @wire.StatusError(code, message)
  }
  let (messages, trailers) = read_stream(answer)
  for trailer in trailers {
    if @utf8.decode_lossy(trailer.name) == "connect-error" {
      let (code, message) = error_of_json(
        @moonjson.loads(@utf8.decode_lossy(trailer.value)[:], @moonjson.strict) catch {
          _ => Json::null()
        },
      )
      raise @wire.StatusError(code, message)
    }
  }
  {
    messages,
    headers: reply_headers(raw_headers),
    trailers: trailers_without_error(trailers),
  }
}

///|
/// A client-streaming call: every request message out in one body, one reply back.
pub async fn[T : Transport] Client::client_stream(
  self : Client[T],
  path : String,
  requests : Array[Bytes],
  content~ : Content = { codec: Proto, streaming: true, },
  metadata~ : Array[@header.Header] = [],
) -> Reply {
  let body = Buffer()
  for request in requests {
    body.write_bytes(encode_envelope(request))
  }
  body.write_bytes(encode_envelope(b"", flags=flag_end_stream))
  let (status, raw_headers, answer) = self.transport.post(
    path,
    content,
    body.to_bytes(),
    request_headers(content, metadata),
  )
  if status != 200 {
    let (code, message) = error_of_status(status, answer)
    raise @wire.StatusError(code, message)
  }
  let (messages, trailers) = read_stream(answer)
  {
    messages,
    headers: reply_headers(raw_headers),
    trailers: trailers_without_error(trailers),
  }
}

///|
/// A bidirectional call, answered when its request half closes — the same shape the server
/// offers, since a Connect call's body is one POST.
pub async fn[T : Transport] Client::bidi(
  self : Client[T],
  path : String,
  requests : Array[Bytes],
  content~ : Content = { codec: Proto, streaming: true, },
  metadata~ : Array[@header.Header] = [],
) -> Reply {
  self.client_stream(path, content~, requests, metadata~)
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
/// The status and message an HTTP error status and its body stand for. The protocol puts the
/// code in the body; a proxy that answered instead puts nothing there, so the status itself is
/// mapped.
fn error_of_status(status : Int32, body : Bytes) -> (@wire.Status, String) {
  let text = @utf8.decode_lossy(body)
  let value = @moonjson.loads(text[:], @moonjson.strict) catch {
    _ => Json::null()
  }
  match value {
    Object(_) => error_of_json(value)
    _ => (status_of_http(status), "")
  }
}

///|
/// The status an HTTP status stands for when there is no error body, by the mapping the
/// protocol's own implementations use.
fn status_of_http(status : Int32) -> @wire.Status {
  match status {
    400 => @wire.Status::InvalidArgument
    401 => @wire.Status::Unauthenticated
    403 => @wire.Status::PermissionDenied
    404 => @wire.Status::Unimplemented
    408 => @wire.Status::DeadlineExceeded
    409 => @wire.Status::Aborted
    429 => @wire.Status::Unavailable
    502 | 503 | 504 => @wire.Status::Unavailable
    _ => @wire.Status::Unknown
  }
}
