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
fn context_of(
  path : String,
  headers : Array[@header.Header],
) -> @stream.RpcContext {
  // Connect names the deadline `connect-timeout-ms`; `grpc-timeout` is the other protocol's.
  let timeout = match header_value(headers, b"connect-timeout-ms") {
    Some(text) => parse_millis(text)
    None => None
  }
  {
    path,
    metadata: metadata_of(headers),
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
  // A unary reply carries its trailing metadata as response headers named `Trailer-<name>`,
  // which is how the protocol spells a trailer on a call whose body is one message and whose
  // framing is a length rather than a chunk. A reader strips the prefix and hands what is left
  // to the caller as a trailer; without it the entry would read as an ordinary header.
  if !content.streaming {
    for h in ctx.resp_trailers {
      out.push({ name: trailer_name(h.name), value: h.value, })
    }
  }
  out
}

///|
/// The header name a trailer is written under: `Trailer-` and the trailer's own name.
fn trailer_name(name : Bytes) -> Bytes {
  let out = Buffer()
  out.write_bytes(b"Trailer-")
  out.write_bytes(name)
  out.to_bytes()
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
      // An absent body is an empty message: proto3 JSON says every field may be omitted, and a
      // message with no fields set writes as nothing at all.
      if body.length() == 0 {
        return b""
      }
      let value = @moonjson.loads(@utf8.decode_lossy(body)[:], @moonjson.strict) catch {
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
      @utf8.encode(@moonjson.dumps(value))
    }
  }
}

///|
/// Compress `body` when the caller said it reads gzip, and say so in the reply's headers.
fn maybe_compress(
  headers : Array[@header.Header],
  body : Bytes,
  flags : Byte,
) -> (Bytes, Byte) {
  if !header_lists(headers, b"connect-accept-encoding", "gzip") {
    return (body, flags)
  }
  let compressed = @gzip.gzip(body)
  (compressed, (flags.to_int() | flag_compressed.to_int()).to_byte())
}

// -- a call in progress -----------------------------------------------------
//
// `serve` reads a whole request and writes a whole answer, which is right for every call whose
// shape is "one request, then the replies". A bidirectional call is not that shape: the caller
// may send a message and wait for the answer to it before sending the next, and a server that
// waits for the close deadlocks against it. `Session` is the same dispatch cut at the points a
// call actually has: the head is known at the start, a message may arrive at any time, and the
// end is both the last thing read and the last thing written.

///|
/// One call in progress.
pub struct Session {
  priv server : Server
  priv content : Content
  priv headers : Array[@header.Header]
  priv ctx : @stream.RpcContext
  priv route : Route?
  // A failure decided before a handler could run: the caller gets this and nothing else. The
  // third element is the HTTP status to answer with when the error code does not determine it.
  priv refuse : (@wire.Status, String, Int32)?
  // A non-streaming body is read whole; a streaming one is cut into envelopes as it arrives.
  priv body : Buffer
  priv pending : Buffer
  priv messages : Array[Bytes]
  priv bidi : @stream.BidiHandler?
  priv mut failure : (@wire.Status, String)?
  priv mut ended : Bool
  // Whether the end-stream envelope has been written. A call whose handler fails mid-stream is
  // closed there and then: the caller may still be sending, and waiting for it to stop would
  // deadlock against a caller waiting for the error.
  priv mut closed : Bool
}

///|
/// Begin a call: work out the codec, find the route, and build the context a handler sees. No
/// handler runs yet — a streaming call has nothing to give it.
pub fn Server::start(
  self : Server,
  path : String,
  headers : Array[@header.Header],
) -> Session {
  let parsed = match header_value(headers, b"content-type") {
    Some(text) => Content::parse(text)
    None => None
  }
  let content = match parsed {
    Some(c) => c
    None => { codec: Proto, streaming: false, }
  }
  let route = self.routes.get(path)
  let ctx = context_of(path, headers)
  let mut refuse : (@wire.Status, String, Int32)? = match parsed {
    Some(_) => None
    // A body in a content type this server does not read is refused as `unknown` — the code the
    // protocol reserves for "the request did not say what kind of body it carries" — with the
    // status a request that named a type it cannot have would get.
    None =>
      Some(
        (
          @wire.Status::Unknown,
          "content-type is not a Connect content type",
          415,
        ),
      )
  }
  if refuse is None {
    match route {
      None =>
        // The protocol answers a path it does not serve with 404, which a caller reads back as
        // `unimplemented`; the status is the part the protocol decides, the code is not.
        refuse = Some(
          (@wire.Status::Unimplemented, "no method at " + path, 404),
        )
      Some(r) =>
        match r.handler {
          Pushed(_) =>
            refuse = Some(
              (
                @wire.Status::Unimplemented,
                "a pushed handler needs a driver that can await it",
                0,
              ),
            )
          _ => ()
        }
    }
  }
  // A bidirectional handler is built now, because its first answer may come before the request
  // ends and there would be nowhere to build it later.
  let bidi = match route {
    Some(r) =>
      match r.handler {
        Bidi(factory) => Some(factory(ctx))
        _ => None
      }
    None => None
  }
  {
    server: self,
    content,
    headers,
    ctx,
    route,
    refuse,
    body: Buffer(),
    pending: Buffer(),
    messages: [],
    bidi,
    failure: None,
    ended: false,
    closed: false,
  }
}

///|
/// Whether the call is over: the end-stream envelope has been written, so the driver can end
/// the response without waiting for the request to end.
pub fn Session::closed(self : Session) -> Bool {
  self.closed
}

///|
pub fn Session::streaming(self : Session) -> Bool {
  self.content.streaming
}

///|
/// Whether the call was refused before a handler could run. A driver asks this before sending a
/// head: a refused streaming call carries its whole answer in `finish`, not in `head`.
pub fn Session::refused(self : Session) -> Bool {
  self.refuse is Some(_)
}

///|
/// The head to send now, for a streaming call. A non-streaming call's status is not known until
/// its handler has run, so its driver waits for `finish` instead.
pub fn Session::head(self : Session) -> Response {
  match self.refuse {
    Some((status, message, http)) =>
      failure(self.content, status, message, http~)
    None => {
      let headers = response_headers(self.ctx, self.content)
      if header_lists(self.headers, b"connect-accept-encoding", "gzip") {
        headers.push({ name: b"connect-content-encoding", value: b"gzip", })
      }
      { status: 200, headers, body: b"", }
    }
  }
}

///|
/// Take the next piece of the request body and hand back whatever may be written now: the
/// envelopes answering the messages that just became whole. A piece that ends in the middle of
/// an envelope answers nothing, and the rest of it waits for the next piece.
pub fn Session::feed(self : Session, data : Bytes) -> Bytes {
  if self.refuse is Some(_) || self.failure is Some(_) {
    return b""
  }
  if !self.content.streaming {
    self.body.write_bytes(data)
    return b""
  }
  self.pending.write_bytes(data)
  let out = Buffer()
  for ;; {
    let whole = self.pending.to_bytes()
    let (envelope, next) = match decode_envelope(whole[:]) {
      Some(pair) => pair
      None => break
    }
    let rest = whole[next:].to_owned()
    self.pending.reset()
    self.pending.write_bytes(rest)
    if envelope.is_end_stream() {
      self.ended = true
      match self.bidi {
        Some(handler) =>
          for reply in (handler.on_end)() {
            self.write_reply(out, reply)
          }
        None => ()
      }
      break
    }
    let payload = match self.inflate(envelope) {
      Some(bytes) => bytes
      None => break
    }
    let message = match self.decode(payload) {
      Some(m) => m
      None => break
    }
    self.dispatch(message, out)
    // A handler that failed while reading has said the last word on this call; the caller gets
    // the end marker now rather than after it decides to stop sending.
    if self.ctx.status_fail is Some(_) && self.failure is None {
      self.write_end(out)
      break
    }
  }
  out.to_bytes()
}

///|
/// End the call and hand back the rest of the answer: the replies a handler still owes, and the
/// end-stream envelope that closes the call with its outcome.
pub fn Session::finish(self : Session) -> Response {
  match self.refuse {
    Some((status, message, http)) =>
      return failure(self.content, status, message, http~)
    None => ()
  }
  match self.failure {
    Some((status, message)) =>
      // Streaming already sent its head, so the outcome travels in the end envelope instead.
      if !self.content.streaming {
        return failure(
          self.content,
          status,
          message,
          headers=self.ctx.resp_headers,
          trailers=self.ctx.resp_trailers,
        )
      }
    None => ()
  }
  if !self.content.streaming {
    return self.finish_unary()
  }
  self.finish_streaming()
}

///|
/// The payload of an envelope, inflated when the caller compressed it.
fn Session::inflate(self : Session, envelope : Envelope) -> Bytes? {
  if !envelope.is_compressed() {
    return Some(envelope.payload)
  }
  if !header_lists(self.headers, b"connect-content-encoding", "gzip") {
    // A message flagged as compressed on a call that declared no encoding it decodes is a
    // disagreement between the envelope and the head, not a feature this server lacks.
    self.failure = Some(
      (
        @wire.Status::Internal,
        "a compressed message arrived, but the call named no encoding",
      ),
    )
    return None
  }
  let inflated : Result[Bytes, Error] = Ok(@gzip.gunzip(envelope.payload[:])) catch {
    e => Err(e)
  }
  match inflated {
    Ok(bytes) => Some(bytes)
    Err(_) => {
      self.failure = Some(
        (@wire.Status::Internal, "a compressed message would not inflate"),
      )
      None
    }
  }
}

///|
fn Session::output_name(self : Session) -> String {
  match self.route {
    Some(r) => r.output
    None => ""
  }
}

///|
fn Session::decode(self : Session, payload : Bytes) -> Bytes? {
  let name = match self.route {
    Some(r) => r.input
    None => ""
  }
  let decoded : Result[Bytes, Error] = Ok(
    self.server.decode_message(payload, self.content.codec, name),
  ) catch {
    e => Err(e)
  }
  match decoded {
    Ok(bytes) => Some(bytes)
    Err(e) => {
      self.failure = Some((status_of_error(e), message_of_error(e)))
      None
    }
  }
}

///|
fn Session::dispatch(self : Session, message : Bytes, out : Buffer) -> Unit {
  match self.route {
    None => ()
    Some(route) =>
      match route.handler {
        Bidi(_) =>
          match self.bidi {
            Some(handler) =>
              for reply in (handler.on_message)(message) {
                self.write_reply(out, reply)
              }
            None => ()
          }
        ClientStreaming(_) => self.messages.push(message)
        _ =>
          // Unary and server-streaming take one request message; a second one is the caller's
          // mistake, and it is left for `finish` to notice.
          self.messages.push(message)
      }
  }
}

///|
/// One reply as an envelope, in the caller's codec and compression.
fn Session::write_reply(self : Session, out : Buffer, reply : Bytes) -> Unit {
  let encoded = self.server.encode_message(
    reply,
    self.content.codec,
    self.output_name(),
  ) catch {
    e => {
      self.failure = Some((status_of_error(e), message_of_error(e)))
      return
    }
  }
  let (payload, flags) = maybe_compress(self.headers, encoded, b'\x00')
  out.write_bytes(encode_envelope(payload, flags~))
}

///|
fn Session::finish_unary(self : Session) -> Response {
  // A unary body is compressed as a whole — `content-encoding` — where a streaming body is
  // compressed envelope by envelope. The header names the algorithm for the one message this
  // call carries.
  let raw = self.body.to_bytes()
  let bytes = match header_value(self.headers, b"content-encoding") {
    Some(encoding) =>
      if encoding.to_lower() == "gzip" {
        @gzip.gunzip(raw[:]) catch {
          _ => {
            self.failure = Some(
              (@wire.Status::Internal, "the request body would not inflate"),
            )
            b""
          }
        }
      } else {
        // An encoding this server does not read leaves the body unusable, which is what the
        // protocol's `unimplemented` is for.
        self.failure = Some(
          (
            @wire.Status::Unimplemented,
            "this server does not decode that content encoding",
          ),
        )
        b""
      }
    None => raw
  }
  let messages : Array[Bytes] = []
  if self.failure is None {
    match self.decode(bytes) {
      Some(m) => messages.push(m)
      None => ()
    }
  }
  match self.failure {
    Some((status, msg)) =>
      return failure(
        self.content,
        status,
        msg,
        headers=self.ctx.resp_headers,
        trailers=self.ctx.resp_trailers,
      )
    None => ()
  }
  let replies = match self.run(messages) {
    Some(r) => r
    None =>
      return failure(
        self.content,
        Internal,
        "the handler did not answer",
        headers=self.ctx.resp_headers,
        trailers=self.ctx.resp_trailers,
      )
  }
  let (status, why) = self.outcome()
  if status != @wire.Status::Ok {
    return failure(
      self.content,
      status,
      why,
      details=self.details(),
      headers=self.ctx.resp_headers,
      trailers=self.ctx.resp_trailers,
    )
  }
  guard replies.length() > 0 else {
    return failure(
      self.content,
      Internal,
      "the handler answered nothing",
      headers=self.ctx.resp_headers,
      trailers=self.ctx.resp_trailers,
    )
  }
  let encoded = self.server.encode_message(
    replies[0],
    self.content.codec,
    self.output_name(),
  ) catch {
    e =>
      return failure(
        self.content,
        status_of_error(e),
        message_of_error(e),
        headers=self.ctx.resp_headers,
        trailers=self.ctx.resp_trailers,
      )
  }
  let (body, _) = maybe_compress(self.headers, encoded, b'\x00')
  let headers = response_headers(self.ctx, self.content)
  if header_lists(self.headers, b"connect-accept-encoding", "gzip") {
    headers.push({ name: b"connect-content-encoding", value: b"gzip", })
  }
  { status: 200, headers, body, }
}

///|
fn Session::finish_streaming(self : Session) -> Response {
  let body = Buffer()
  // A call the handler already closed owes nothing more: the rest of the request is not read
  // and the envelopes still waiting for one are not parsed.
  if self.closed {
    let head = self.head()
    return { status: head.status, headers: head.headers, body: b"", }
  }
  if self.pending.to_bytes().length() > 0 && self.failure is None {
    self.failure = Some(
      (@wire.Status::Internal, "a truncated envelope ended the request"),
    )
  }
  // A call whose request ended badly is not one the handler gets to close: its `on_end` is for
  // "the caller is done", and a truncated body is not that.
  if !self.ended && self.failure is None {
    self.ended = true
    match self.bidi {
      Some(handler) =>
        for reply in (handler.on_end)() {
          self.write_reply(body, reply)
        }
      None => ()
    }
  }
  match self.run(self.messages) {
    Some(replies) =>
      for reply in replies {
        self.write_reply(body, reply)
      }
    None => ()
  }
  if !self.closed {
    body.write_bytes(self.end_marker())
  }
  let head = self.head()
  { status: head.status, headers: head.headers, body: body.to_bytes(), }
}

///|
/// The envelope that closes a streaming call: the outcome, and the trailing metadata a handler
/// attached. Writing it marks the call over, so a second caller — the end of the request, or a
/// failure noticed while the caller was still sending — does not write a second one.
fn Session::end_marker(self : Session) -> Bytes {
  self.closed = true
  let (status, why) = self.outcome()
  let members : Map[String, Json] = Map([])
  if status != @wire.Status::Ok {
    members["error"] = error_json(status, why, details=self.details())
  }
  // A metadata entry is a list of values, not one value: a key may be repeated, and the
  // protocol's own reader decodes `metadata` as a map of string to array.
  let trailing : Map[String, Array[String]] = Map([])
  for h in self.ctx.resp_trailers {
    let name = @utf8.decode_lossy(h.name)
    let value = @utf8.decode_lossy(h.value)
    match trailing.get(name) {
      Some(values) => values.push(value)
      None => trailing[name] = [value]
    }
  }
  if trailing.length() > 0 {
    let encoded : Map[String, Json] = Map([])
    for name, values in trailing {
      let items = []
      for value in values {
        items.push(Json::string(value))
      }
      encoded[name] = Json::array(items)
    }
    members["metadata"] = Json::object(encoded)
  }
  encode_envelope(
    @utf8.encode(@moonjson.dumps(Json::object(members))),
    flags=flag_end_stream,
  )
}

///|
/// Close the call into `out`: the end marker, and nothing after it.
fn Session::write_end(self : Session, out : Buffer) -> Unit {
  out.write_bytes(self.end_marker())
}

///|
/// The details a handler attached, as the protocol writes them: each is a `google.protobuf.Any`,
/// and the body carries the type's name and the value base64 encoded.
fn Session::details(self : Session) -> Array[(String, Json)] {
  let out = []
  for detail in self.ctx.error_details {
    let reader = @proto.PbReader::new(detail)
    let mut type_url = ""
    let mut value = b""
    while !reader.eof() {
      let tag = reader.read_tag() catch { _ => break }
      match tag {
        (1, @proto.LengthDelim) =>
          type_url = reader.read_string() catch { _ => "" }
        (2, @proto.LengthDelim) =>
          value = reader.read_bytes() catch { _ => b"" }
        (_, wire) => reader.skip(wire) catch { _ => break }
      }
    }
    // The protocol writes an error detail's bytes in unpadded base64; a padded value is
    // rejected by a reader that follows it, which is how this was found.
    out.push((last_segment(type_url), Json::string(unpadded(value))))
  }
  out
}

///|
/// `text` without the `=` padding base64 adds, which is the spelling the protocol uses.
fn unpadded(value : Bytes) -> String {
  let text = @base64.encode(value[:])
  let mut end = text.length()
  while end > 0 && text[end - 1] == '=' {
    end = end - 1
  }
  text.exact_view(start=0, end~).to_owned()
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
/// What the handler said before it returned, or OK.
fn Session::outcome(self : Session) -> (@wire.Status, String) {
  match self.ctx.status_fail {
    Some((code, why)) => (@wire.Status::of(code), why)
    None =>
      match self.failure {
        Some(f) => f
        None => (@wire.Status::Ok, "")
      }
  }
}

///|
/// Run the handler over the messages collected so far, for the three kinds that answer in one
/// go. A bidirectional handler answers as it reads, so it has nothing left to run.
fn Session::run(self : Session, messages : Array[Bytes]) -> Array[Bytes]? {
  let ctx = self.ctx
  match self.route {
    None => None
    Some(route) =>
      match route.handler {
        Unary(f) => {
          if messages.length() != 1 {
            if self.failure is None {
              self.failure = Some(
                (
                  @wire.Status::Unimplemented,
                  "a unary call carries exactly one message",
                ),
              )
            }
            return None
          }
          Some([f(ctx, messages[0])])
        }
        ServerStreaming(f) => {
          if messages.length() != 1 {
            if self.failure is None {
              self.failure = Some(
                (
                  @wire.Status::Unimplemented,
                  "a server-streaming call carries exactly one request message",
                ),
              )
            }
            return None
          }
          let out = []
          for r in f(ctx, messages[0]) {
            out.push(r)
          }
          Some(out)
        }
        ClientStreaming(f) => Some([f(ctx, messages)])
        Bidi(_) => Some([])
        Pushed(_) => None
      }
  }
}

// -- the whole-request entry point ------------------------------------------

///|
/// Answer one request that arrived whole. It is `start`, one `feed` and `finish` — the shape a
/// driver uses when the body is already in hand, and the shape every test here is written in.
pub fn Server::serve(self : Server, request : Request) -> Response {
  let session = self.start(request.path, request.headers)
  if session.streaming() {
    let head = session.head()
    if session.refused() {
      return head
    }
    let body = session.feed(request.body) + session.finish().body
    { status: head.status, headers: head.headers, body, }
  } else {
    ignore(session.feed(request.body))
    session.finish()
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
    @wire.StatusError(_, text) => text
    _ => "the handler failed"
  }
}

///|
/// A failure, in the shape the protocol asks for: an HTTP status and a JSON body for a unary
/// call, an end-stream envelope for a streaming one.
fn failure(
  content : Content,
  status : @wire.Status,
  message : String,
  details~ : Array[(String, Json)] = [],
  headers~ : Array[@header.Header] = [],
  trailers~ : Array[@header.Header] = [],
  http~ : Int32 = 0,
) -> Response {
  let body = error_json(status, message, details~)
  let http_status = if http == 0 { http_status_of(status) } else { http }
  if !content.streaming {
    let fields : Array[@header.Header] = [
      { name: b"content-type", value: @utf8.encode("application/json"), },
      { name: b"connect-protocol-version", value: b"1", },
    ]
    // A failure is still an answer from a handler, so the metadata it set travels with it —
    // the initial metadata as itself, the trailing metadata in the spelling a unary reply gives
    // it, which is the only trailer channel a one-message body has.
    for h in headers {
      fields.push(h)
    }
    for h in trailers {
      fields.push({ name: trailer_name(h.name), value: h.value, })
    }
    return {
      status: http_status,
      headers: fields,
      body: @utf8.encode(@moonjson.dumps(body)),
    }
  }
  let end = encode_envelope(
    @utf8.encode(@moonjson.dumps(body)),
    flags=flag_end_stream,
  )
  let headers : Array[@header.Header] = [
    { name: b"content-type", value: @utf8.encode(content.text()), },
    { name: b"connect-protocol-version", value: b"1", },
  ]
  { status: 200, headers, body: end, }
}
