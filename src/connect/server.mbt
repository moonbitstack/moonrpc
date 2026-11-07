// The Connect server: one request in, one response out. It is a pure function over bytes —
// the request's head, its body, and the handler a path was registered with — so the same
// dispatch serves HTTP/1.1 and HTTP/2, and a test needs no socket.
//
// A unary call is one message in the body and one in the reply, with the outcome in the HTTP
// status. A streaming call is a run of envelopes, closed by the end-stream envelope, with the
// outcome in that envelope's JSON. The two are different enough that they are separate paths
// here too.

///|
/// One HTTP request as the engine sees it: the `:path` it arrived on, the headers, and the
/// whole body.
pub(all) struct Request {
  path : String
  headers : Array[@header.Header]
  body : Bytes
}

///|
/// The answer: an HTTP status, headers, and the body, already framed.
pub(all) struct Response {
  status : Int32
  headers : Array[@header.Header]
  body : Bytes
}

///|
/// A method a server answers, and the message types its body decodes to. The type names are
/// what a JSON body is read and written with; a method registered without them speaks the
/// binary codec only, and answers a JSON caller with `unimplemented` rather than guessing.
pub(all) struct Route {
  input : String
  output : String
  handler : @stream.Handler
}

///|
/// What a Connect server needs: the methods, and the schema a JSON body is read with.
pub struct Server {
  routes : Map[String, Route]
  schema : @proto.Schema
}

///|
pub fn Server::new(schema~ : @proto.Schema = @proto.Schema::empty()) -> Server {
  { routes: Map([]), schema, }
}

///|
/// Register a method. The four kinds are the same four gRPC has, and a handler is the same
/// shape, so a service written for one transport is served by the other without a second
/// copy of its logic.
pub fn Server::add(self : Server, path : String, route : Route) -> Unit {
  self.routes[path] = route
}

///|
/// The value of the first header named `name`.
fn header_value(headers : Array[@header.Header], name : Bytes) -> String? {
  for h in headers {
    if h.name == name {
      return Some(@utf8.decode_lossy(h.value))
    }
  }
  None
}

///|
/// Whether the first header named `name`, read as a comma-separated list, names `want`.
fn header_lists(
  headers : Array[@header.Header],
  name : Bytes,
  want : String,
) -> Bool {
  match header_value(headers, name) {
    None => false
    Some(text) => {
      for part in text.split(",") {
        if part.trim(chars=" \t").to_owned() == want {
          return true
        }
      }
      false
    }
  }
}

///|
/// The headers that are the call's metadata: everything but the HTTP's own and the protocol's
/// own, with a `-bin` value decoded from base64 as gRPC metadata is.
fn metadata_of(headers : Array[@header.Header]) -> Array[@header.Header] {
  let out : Array[@header.Header] = []
  for h in headers {
    let name = @utf8.decode_lossy(h.name)
    if name.has_prefix(":") ||
      name == "content-type" ||
      name == "content-length" ||
      name == "host" ||
      name == "connection" ||
      name == "transfer-encoding" ||
      name == "te" ||
      name == "accept" ||
      name == "accept-encoding" ||
      name == "user-agent" ||
      name.has_prefix("connect-") {
      continue
    }
    out.push({
      name: h.name,
      value: @wire.metadata_value_from_wire(h.name, h.value),
    })
  }
  out
}

///|
/// The context a handler sees: the path, the caller's metadata, the deadline the caller asked
/// for, and the slots it fills before returning.
fn context_of(request : Request) -> @stream.RpcContext {
  let timeout = match header_value(request.headers, b"connect-timeout") {
    Some(text) => parse_millis(text)
    None => None
  }
  {
    path: request.path,
    metadata: metadata_of(request.headers),
    deadline_millis: timeout,
    resp_headers: [],
    resp_trailers: [],
    status_fail: None,
    error_details: [],
  }
}

///|
/// A `connect-timeout` value in milliseconds, or `None` for a value that is not one.
fn parse_millis(text : String) -> Int32? {
  let result : Result[Int32, Error] = Ok(@string.parse_int(text[:])) catch {
    e => Err(e)
  }
  match result {
    Ok(n) => if n >= 0 { Some(n) } else { None }
    Err(_) => None
  }
}

///|
/// The reply headers a handler asked for, as HTTP headers.
fn response_headers(
  ctx : @stream.RpcContext,
  content : Content,
) -> Array[@header.Header] {
  let out : Array[@header.Header] = [
    { name: b"content-type", value: @utf8.encode(content.text()), },
    { name: b"connect-protocol-version", value: b"1", },
  ]
  for h in ctx.resp_headers {
    out.push(h)
  }
  // A unary reply has no trailer channel in this protocol, so the trailing metadata travels
  // beside the initial metadata rather than being dropped.
  if !content.streaming {
    for h in ctx.resp_trailers {
      out.push(h)
    }
  }
  out
}

///|
/// Decode one request body into the messages a handler takes: a unary body is one message, a
/// streaming one is a run of envelopes whose last is the end-stream envelope.
fn Server::request_messages(
  self : Server,
  request : Request,
  content : Content,
  route : Route,
) -> Array[Bytes] raise {
  if !content.streaming {
    return [self.decode_message(request.body, content.codec, route.input)]
  }
  let (envelopes, at) = split_envelopes(request.body)
  if at != request.body.length() {
    raise @wire.StatusError(Internal, "a truncated envelope ended the request")
  }
  let out : Array[Bytes] = []
  for envelope in envelopes {
    if envelope.is_end_stream() {
      break
    }
    let payload = if envelope.is_compressed() {
      if header_lists(request.headers, b"connect-content-encoding", "gzip") {
        @gzip.gunzip(envelope.payload[:]) catch {
          _ =>
            raise @wire.StatusError(
              Internal,
              "a compressed message would not inflate",
            )
        }
      } else {
        raise @wire.StatusError(
          Unimplemented,
          "this server does not decode that content encoding",
        )
      }
    } else {
      envelope.payload
    }
    out.push(self.decode_message(payload, content.codec, route.input))
  }
  out
}

///|
/// The wire bytes of one message, from the codec the caller asked for.
fn Server::decode_message(
  self : Server,
  body : Bytes,
  codec : Codec,
  name : String,
) -> Bytes raise {
  match codec {
    Proto => body
    Json => {
      if name.length() == 0 {
        raise @wire.StatusError(
          Unimplemented,
          "this method has no message schema registered for JSON",
        )
      }
      let value = @json.parse(@utf8.decode_lossy(body)) catch {
        _ => raise @wire.StatusError(Internal, "the request body is not JSON")
      }
      self.schema.to_bytes(name, value) catch {
        _ =>
          raise @wire.StatusError(
            Internal,
            "the request body does not fit the schema",
          )
      }
    }
  }
}

///|
/// One message as the caller's codec wants it.
fn Server::encode_message(
  self : Server,
  bytes : Bytes,
  codec : Codec,
  name : String,
) -> Bytes raise {
  match codec {
    Proto => bytes
    Json => {
      if name.length() == 0 {
        raise @wire.StatusError(
          Unimplemented,
          "this method has no message schema registered for JSON",
        )
      }
      let value = self.schema.to_json(name, bytes) catch {
        _ =>
          raise @wire.StatusError(Internal, "the reply does not fit the schema")
      }
      @utf8.encode(value.stringify())
    }
  }
}

///|
/// Compress `body` when the caller said it reads gzip, and say so in the reply's headers.
fn maybe_compress(
  request : Request,
  headers : Array[@header.Header],
  body : Bytes,
  streaming : Bool,
  flags : Byte,
) -> (Bytes, Array[@header.Header], Byte) {
  if !header_lists(request.headers, b"connect-accept-encoding", "gzip") {
    return (body, headers, flags)
  }
  let compressed = @gzip.gzip(body)
  let out = []
  for h in headers {
    out.push(h)
  }
  if streaming {
    out.push({ name: b"connect-content-encoding", value: b"gzip", })
  } else {
    out.push({ name: b"connect-content-encoding", value: b"gzip", })
  }
  (compressed, out, (flags.to_int() | flag_compressed.to_int()).to_byte())
}

///|
/// Answer one request.
pub fn Server::serve(self : Server, request : Request) -> Response {
  let content = match header_value(request.headers, b"content-type") {
    Some(text) =>
      match Content::parse(text) {
        Some(c) => c
        None =>
          return failure(
            request,
            { codec: Proto, streaming: false, },
            @wire.Status::Internal,
            "content-type is not a Connect content type",
          )
      }
    None =>
      return failure(
        request,
        { codec: Proto, streaming: false, },
        @wire.Status::Internal,
        "content-type is missing",
      )
  }
  let route = match self.routes.get(request.path) {
    Some(r) => r
    None =>
      return failure(
        request,
        content,
        @wire.Status::Unimplemented,
        "no method at " + request.path,
      )
  }
  let messages = self.request_messages(request, content, route) catch {
    e =>
      return failure(request, content, status_of_error(e), message_of_error(e))
  }
  self.answer(request, content, route, messages) catch {
    e => failure(request, content, status_of_error(e), message_of_error(e))
  }
}

///|
fn status_of_error(error : Error) -> @wire.Status {
  match error {
    @wire.StatusError(status, _) => status
    _ => @wire.Status::Internal
  }
}

///|
fn message_of_error(error : Error) -> String {
  match error {
    @wire.StatusError(_, message) => message
    other => other.to_string()
  }
}

///|
/// The failure every early exit answers with: a status, a JSON body, and the same body shape
/// whether the call was unary or streaming.
fn failure(
  request : Request,
  content : Content,
  status : @wire.Status,
  message : String,
) -> Response {
  let body = error_json(status, message)
  if !content.streaming {
    let headers : Array[@header.Header] = [
      { name: b"content-type", value: @utf8.encode("application/json"), },
      { name: b"connect-protocol-version", value: b"1", },
    ]
    return {
      status: http_status_of(status),
      headers,
      body: @utf8.encode(body.stringify()),
    }
  }
  let end = encode_envelope(
    @utf8.encode(body.stringify()),
    flags=flag_end_stream,
  )
  let headers : Array[@header.Header] = [
    { name: b"content-type", value: @utf8.encode(content.text()), },
    { name: b"connect-protocol-version", value: b"1", },
  ]
  ignore(request)
  { status: 200, headers, body: end, }
}

///|
fn Server::answer(
  self : Server,
  request : Request,
  content : Content,
  route : Route,
  messages : Array[Bytes],
) -> Response raise {
  let ctx = context_of(request)
  let replies : Array[Bytes] = []
  match route.handler {
    Unary(f) => {
      guard messages.length() == 1 else {
        return failure(
          request,
          content,
          @wire.Status::Internal,
          "a unary call carries exactly one message",
        )
      }
      replies.push(f(ctx, messages[0]))
    }
    ServerStreaming(f) => {
      guard messages.length() == 1 else {
        return failure(
          request,
          content,
          @wire.Status::Internal,
          "a server-streaming call carries exactly one request message",
        )
      }
      for r in f(ctx, messages[0]) {
        replies.push(r)
      }
    }
    ClientStreaming(f) => replies.push(f(ctx, messages))
    Bidi(factory) => {
      let bidi = factory(ctx)
      for m in messages {
        for r in (bidi.on_message)(m) {
          replies.push(r)
        }
      }
      for r in (bidi.on_end)() {
        replies.push(r)
      }
    }
    Pushed(_) =>
      return failure(
        request,
        content,
        @wire.Status::Unimplemented,
        "a pushed handler needs a driver that can await it",
      )
  }
  let mut status = @wire.Status::Ok
  let mut message = ""
  match ctx.status_fail {
    Some((code, why)) => {
      status = @wire.Status::of(code)
      message = why
    }
    None => ()
  }
  if !content.streaming {
    if status != @wire.Status::Ok {
      return failure(request, content, status, message)
    }
    let encoded = self.encode_message(replies[0], content.codec, route.output)
    let (body, headers, _) = maybe_compress(
      request,
      response_headers(ctx, content),
      encoded,
      false,
      b'\x00',
    )
    return { status: 200, headers, body, }
  }
  // A streaming answer: every reply as its own envelope, then the end-stream envelope that
  // carries the outcome and the trailing metadata.
  let body = Buffer()
  for reply in replies {
    let encoded = self.encode_message(reply, content.codec, route.output)
    let (payload, headers, flags) = maybe_compress(
      request,
      [],
      encoded,
      true,
      b'\x00',
    )
    ignore(headers)
    body.write_bytes(encode_envelope(payload, flags~))
  }
  let trailing : Map[String, Json] = Map([])
  let end_members : Map[String, Json] = Map([])
  if status != @wire.Status::Ok {
    end_members["error"] = error_json(status, message)
  }
  for h in ctx.resp_trailers {
    trailing[@utf8.decode_lossy(h.name)] = Json::string(
      @utf8.decode_lossy(h.value),
    )
  }
  if trailing.length() > 0 {
    end_members["metadata"] = Json::object(trailing)
  }
  body.write_bytes(
    encode_envelope(
      @utf8.encode(Json::object(end_members).stringify()),
      flags=flag_end_stream,
    ),
  )
  let headers = response_headers(ctx, content)
  let out = headers
  // The encoding the envelopes are in is the reply's, so the caller knows before the first
  // one arrives.
  if header_lists(request.headers, b"connect-accept-encoding", "gzip") {
    out.push({ name: b"connect-content-encoding", value: b"gzip", })
  }
  { status: 200, headers: out, body: body.to_bytes(), }
}
