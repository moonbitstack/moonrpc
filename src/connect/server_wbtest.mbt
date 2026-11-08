// The dispatch, without a socket: one request in, one response out, in both codecs and all
// four call kinds.

///|
fn echo_server() -> Server {
  let server = Server::new(schema=say_schema())
  server.add("/test.Echo/Say", {
    input: ".test.SayRequest",
    output: ".test.SayReply",
    handler: @stream.Handler::Unary((_ctx, req) => req),
  })
  server
}

///|
/// A schema with one request and one reply message: `SayRequest { text = 1 }` and
/// `SayReply { text = 1 }`.
fn say_schema() -> @proto.Schema {
  let request = @proto.MessageDescriptor::new("SayRequest", [
    @proto.FieldDescriptor::new("text", 1, @proto.FieldType::TypeString),
  ])
  let reply = @proto.MessageDescriptor::new("SayReply", [
    @proto.FieldDescriptor::new("text", 1, @proto.FieldType::TypeString),
  ])
  @proto.Schema::of([
    @proto.FileDescriptor::new("test.proto", "test", messages=[request, reply]),
  ])
}

///|
/// The wire bytes of a `SayRequest` carrying `text`.
fn say_request(text : String) -> Bytes {
  let w = @proto.PbWriter::new()
  w.string_(1, text)
  w.to_bytes()
}

///|
/// A body read as JSON, or null when it is not JSON at all — a test that expected JSON fails
/// on the assertion below rather than on a parse.
fn parse_json(body : Bytes) -> Json {
  @json.parse(@utf8.decode_lossy(body)) catch {
    _ => Json::null()
  }
}

///|
fn header(name : String, value : String) -> @header.Header {
  { name: @utf8.encode(name), value: @utf8.encode(value), }
}

///|
test "connect server: a unary call answers one message in the body" {
  let server = echo_server()
  let response = server.serve({
    path: "/test.Echo/Say",
    headers: [header("content-type", "application/proto")],
    body: say_request("hello"),
  })
  assert_eq(response.status, 200)
  assert_eq(response.body, say_request("hello"))
  let mut saw_type = false
  for h in response.headers {
    if @utf8.decode_lossy(h.name) == "content-type" {
      assert_eq(@utf8.decode_lossy(h.value), "application/proto")
      saw_type = true
    }
  }
  assert_true(saw_type)
}

///|
test "connect server: a JSON unary call is read and answered through the schema" {
  let server = echo_server()
  let response = server.serve({
    path: "/test.Echo/Say",
    headers: [header("content-type", "application/json")],
    body: b"{\"text\":\"hello\"}",
  })
  assert_eq(response.status, 200)
  assert_eq(@utf8.decode_lossy(response.body), "{\"text\":\"hello\"}")
}

///|
test "connect server: a handler that fails answers its HTTP status and an error body" {
  let server = Server::new()
  server.add("/test.Echo/Say", {
    input: ".test.SayRequest",
    output: ".test.SayReply",
    handler: @stream.Handler::Unary((ctx, _req) => {
      ctx.fail(
        @wire.Status::code(@wire.Status::InvalidArgument),
        "text is required",
      )
      b""
    }),
  })
  let response = server.serve({
    path: "/test.Echo/Say",
    headers: [header("content-type", "application/proto")],
    body: b"",
  })
  assert_eq(response.status, 400)
  let body = parse_json(response.body)
  let (status, message) = error_of_json(body)
  assert_eq(status, @wire.Status::InvalidArgument)
  assert_eq(message, "text is required")
}

///|
test "connect server: an unknown path is unimplemented, not a 404 without a body" {
  let server = echo_server()
  let response = server.serve({
    path: "/test.Echo/Missing",
    headers: [header("content-type", "application/proto")],
    body: b"",
  })
  assert_eq(response.status, 501)
  let body = parse_json(response.body)
  assert_eq(error_of_json(body).0, @wire.Status::Unimplemented)
}

///|
test "connect server: a content type that is not Connect is refused" {
  let server = echo_server()
  let response = server.serve({
    path: "/test.Echo/Say",
    headers: [header("content-type", "application/grpc")],
    body: b"",
  })
  assert_eq(response.status is 500 || response.status is 415, true)
}

///|
/// A server-streaming route that answers three messages, and the end-stream envelope that
/// closes it.
fn streaming_server() -> Server {
  let server = Server::new(schema=say_schema())
  server.add("/test.Count/Up", {
    input: ".test.SayRequest",
    output: ".test.SayReply",
    handler: @stream.Handler::ServerStreaming((_ctx, req) => [req, req, req]),
  })
  server
}

///|
test "connect server: a server-streaming call is envelopes closed by the end marker" {
  let server = streaming_server()
  let request = Buffer()
  request.write_bytes(encode_envelope(say_request("a")))
  request.write_bytes(encode_envelope(b"", flags=flag_end_stream))
  let response = server.serve({
    path: "/test.Count/Up",
    headers: [header("content-type", "application/connect+proto")],
    body: request.to_bytes(),
  })
  assert_eq(response.status, 200)
  let (envelopes, at) = split_envelopes(response.body)
  assert_eq(at, response.body.length())
  assert_eq(envelopes.length(), 4)
  assert_eq(envelopes[0].payload, say_request("a"))
  assert_eq(envelopes[3].is_end_stream(), true)
  assert_eq(envelopes[3].payload, b"{}")
}

///|
test "connect server: a streaming call whose handler fails says so in the end marker" {
  let server = Server::new()
  server.add("/test.Count/Up", {
    input: ".test.SayRequest",
    output: ".test.SayReply",
    handler: @stream.Handler::ServerStreaming((ctx, _req) => {
      ctx.fail(@wire.Status::code(@wire.Status::Unavailable), "down")
      []
    }),
  })
  let response = server.serve({
    path: "/test.Count/Up",
    headers: [header("content-type", "application/connect+proto")],
    body: encode_envelope(b"") + encode_envelope(b"", flags=flag_end_stream),
  })
  assert_eq(response.status, 200)
  let (envelopes, _) = split_envelopes(response.body)
  assert_eq(envelopes.length(), 1)
  assert_eq(envelopes[0].is_end_stream(), true)
  let end = parse_json(envelopes[0].payload)
  let error = match end {
    Object(members) =>
      match members.get("error") {
        Some(value) => value
        None => Json::null()
      }
    _ => Json::null()
  }
  assert_eq(error_of_json(error).0, @wire.Status::Unavailable)
}

///|
test "connect server: the trailing metadata travels in the end marker" {
  let server = Server::new()
  server.add("/test.Count/Up", {
    input: ".test.SayRequest",
    output: ".test.SayReply",
    handler: @stream.Handler::ServerStreaming((ctx, req) => {
      ctx.add_trailer(b"x-done", b"yes")
      [req]
    }),
  })
  let response = server.serve({
    path: "/test.Count/Up",
    headers: [header("content-type", "application/connect+proto")],
    body: encode_envelope(say_request("a")) +
    encode_envelope(b"", flags=flag_end_stream),
  })
  let (envelopes, _) = split_envelopes(response.body)
  let end = parse_json(envelopes[envelopes.length() - 1].payload)
  let metadata = match end {
    Object(members) =>
      match members.get("metadata") {
        Some(Object(m)) => m
        _ => Map([])
      }
    _ => Map([])
  }
  assert_eq(metadata.get("x-done"), Some(Json::string("yes")))
}

///|
test "connect server: the caller's metadata and deadline reach the handler" {
  let server = Server::new()
  let seen = Ref("")
  let deadline = Ref(None)
  server.add("/test.Echo/Say", {
    input: ".test.SayRequest",
    output: ".test.SayReply",
    handler: @stream.Handler::Unary((ctx, req) => {
      seen.val = match ctx.metadata_get(b"x-trace") {
        Some(v) => @utf8.decode_lossy(v)
        None => ""
      }
      deadline.val = ctx.deadline_millis
      req
    }),
  })
  let response = server.serve({
    path: "/test.Echo/Say",
    headers: [
      header("content-type", "application/proto"),
      header("x-trace", "abc"),
      header("connect-timeout", "250"),
    ],
    body: b"",
  })
  assert_eq(response.status, 200)
  assert_eq(seen.val, "abc")
  assert_eq(deadline.val, Some(250))
}

///|
test "connect server: a client-streaming call collects its messages into one reply" {
  let server = Server::new()
  server.add("/test.Sum/Add", {
    input: ".test.SayRequest",
    output: ".test.SayReply",
    handler: @stream.Handler::ClientStreaming((_ctx, msgs) => {
      let buf = Buffer()
      for m in msgs {
        buf.write_bytes(m)
      }
      buf.to_bytes()
    }),
  })
  let request = Buffer()
  request.write_bytes(encode_envelope(b"a"))
  request.write_bytes(encode_envelope(b"b"))
  request.write_bytes(encode_envelope(b"", flags=flag_end_stream))
  let response = server.serve({
    path: "/test.Sum/Add",
    headers: [header("content-type", "application/connect+proto")],
    body: request.to_bytes(),
  })
  let (envelopes, _) = split_envelopes(response.body)
  assert_eq(envelopes[0].payload, b"ab")
}

///|
test "connect server: a bidi call is answered message by message, then at the close" {
  let server = Server::new()
  server.add("/test.Chat/Echo", {
    input: ".test.SayRequest",
    output: ".test.SayReply",
    handler: @stream.Handler::Bidi(_ctx => @stream.BidiHandler::{
      on_message: m => [m],
      on_end: () => [b"bye"],
    }),
  })
  let request = Buffer()
  request.write_bytes(encode_envelope(b"one"))
  request.write_bytes(encode_envelope(b"two"))
  request.write_bytes(encode_envelope(b"", flags=flag_end_stream))
  let response = server.serve({
    path: "/test.Chat/Echo",
    headers: [header("content-type", "application/connect+proto")],
    body: request.to_bytes(),
  })
  let (envelopes, _) = split_envelopes(response.body)
  assert_eq(envelopes.length(), 4)
  assert_eq(envelopes[0].payload, b"one")
  assert_eq(envelopes[1].payload, b"two")
  assert_eq(envelopes[2].payload, b"bye")
  assert_eq(envelopes[3].is_end_stream(), true)
}

///|
/// A bidirectional route that appends `!` to every message and says goodbye at the close.
fn echo_chat_server() -> Server {
  let server = Server::new()
  server.add("/test.Chat/Echo", {
    input: "",
    output: "",
    handler: @stream.Handler::Bidi(_ctx => @stream.BidiHandler::{
      on_message: m => [m + b"!"],
      on_end: () => [b"bye"],
    }),
  })
  server
}

///|
test "connect session: a bidi call answers a message before the next one arrives" {
  let server = echo_chat_server()
  let session = server.start("/test.Chat/Echo", [
    header("content-type", "application/connect+proto"),
  ])
  assert_eq(session.streaming(), true)
  let head = session.head()
  assert_eq(head.status, 200)
  // The first message is answered while the request is still open: this is the difference
  // between a session and `serve`, which would have nothing until the body ended.
  let first = session.feed(encode_envelope(b"one"))
  let (answered, at) = split_envelopes(first)
  assert_eq(at, first.length())
  assert_eq(answered.length(), 1)
  assert_eq(answered[0].payload, b"one!")
  assert_eq(answered[0].is_end_stream(), false)
}

///|
test "connect session: an envelope split across pieces is answered once it is whole" {
  let server = echo_chat_server()
  let session = server.start("/test.Chat/Echo", [
    header("content-type", "application/connect+proto"),
  ])
  ignore(session.head())
  let whole = encode_envelope(b"two")
  // Three octets of a five-octet header are not an envelope yet.
  let nothing = session.feed(whole[0:3].to_owned())
  assert_eq(nothing.length(), 0)
  // The rest completes it, and the same feed carries the end of the request.
  let rest = session.feed(
      whole[3:].to_owned() + encode_envelope(b"", flags=flag_end_stream),
    ) +
    session.finish().body
  let (answered, at) = split_envelopes(rest)
  assert_eq(at, rest.length())
  assert_eq(answered.length(), 3)
  assert_eq(answered[0].payload, b"two!")
  assert_eq(answered[1].payload, b"bye")
  assert_eq(answered[2].is_end_stream(), true)
  // The end envelope says the call succeeded and carries no error.
  let end = parse_json(answered[2].payload)
  assert_eq(end, Json::object(Map([])))
}

///|
test "connect session: two envelopes in one piece are both answered" {
  let server = echo_chat_server()
  let session = server.start("/test.Chat/Echo", [
    header("content-type", "application/connect+proto"),
  ])
  ignore(session.head())
  let both = encode_envelope(b"a") + encode_envelope(b"b")
  let (answered, _) = split_envelopes(session.feed(both))
  assert_eq(answered.length(), 2)
  assert_eq(answered[0].payload, b"a!")
  assert_eq(answered[1].payload, b"b!")
}

///|
test "connect session: the whole-request entry point is the same three steps" {
  let server = echo_chat_server()
  let body = encode_envelope(b"one") +
    encode_envelope(b"two") +
    encode_envelope(b"", flags=flag_end_stream)
  let whole = server.serve({
    path: "/test.Chat/Echo",
    headers: [header("content-type", "application/connect+proto")],
    body,
  })
  let stepped = {
    let session = server.start("/test.Chat/Echo", [
      header("content-type", "application/connect+proto"),
    ])
    ignore(session.head())
    session.feed(body) + session.finish().body
  }
  assert_eq(whole.body, stepped)
}

///|
test "connect session: a request that ends mid-envelope fails the call" {
  let server = echo_chat_server()
  let session = server.start("/test.Chat/Echo", [
    header("content-type", "application/connect+proto"),
  ])
  ignore(session.head())
  ignore(session.feed(encode_envelope(b"one")[0:3].to_owned()))
  let tail = session.finish()
  let (answered, _) = split_envelopes(tail.body)
  assert_eq(answered.length(), 1)
  assert_eq(answered[0].is_end_stream(), true)
  let end = parse_json(answered[0].payload)
  let error = match end {
    Object(members) =>
      match members.get("error") {
        Some(value) => value
        None => Json::null()
      }
    _ => Json::null()
  }
  assert_eq(error_of_json(error).0, @wire.Status::Internal)
}
