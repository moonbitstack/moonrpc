// The protocol's own shapes: the fixed head, the two unary headers, and what a session
// does with a frame it cannot route.

///|
fn routes(server : Server) -> Unit {
  server.register(
    "/test.Echo/Say",
    @stream.Handler::Unary((_ctx, body) => body),
  )
  server.register(
    "/test.Echo/Count",
    @stream.Handler::ServerStreaming((_ctx, body) => [body, body]),
  )
  server.register(
    "/test.Echo/Sum",
    @stream.Handler::ClientStreaming((_ctx, bodies) => {
      let out = @buffer.Buffer()
      for body in bodies {
        out.write_bytes(body)
      }
      out.to_bytes()
    }),
  )
  server.register(
    "/test.Echo/Chat",
    @stream.Handler::Bidi(_ctx => {
      on_message: body => [body],
      on_end: () => [],
    }),
  )
}

///|
test "frame: the head is the one the reference implementations write" {
  let frame = Frame::new(Unary, 7, b"\x18\x01", header_len=2)
  let bytes = frame.encode()
  assert_eq(bytes.length(), 18)
  // Two octets of magic, then the data-frame type.
  assert_eq(bytes[0].to_int(), 0x09)
  assert_eq(bytes[1].to_int(), 0x30)
  assert_eq(bytes[2].to_int(), 0x00)
  assert_eq(bytes[3].to_int(), 0x00)
  // The total length counts the head itself.
  assert_eq(bytes[7].to_int(), 18)
  // The header is the two octets before the message.
  assert_eq(bytes[9].to_int(), 2)
  // The stream id is big-endian in octets 11 to 14.
  assert_eq(bytes[13].to_int(), 7)
  // Version one, nothing reserved.
  assert_eq(bytes[14].to_int(), 1)
  assert_eq(bytes[15].to_int(), 0)
  let (decoded, used) = Frame::decode(bytes)
  assert_eq(used, 18)
  assert_eq(decoded.kind, Unary)
  assert_eq(decoded.stream_id, 7)
  assert_eq(decoded.header(), b"\x18\x01")
}

///|
test "frame: a head that does not start with the magic is refused" {
  let bytes = b"\x00\x00\x00\x00\x00\x00\x00\x10\x00\x00\x00\x00\x00\x01\x00\x00"
  assert_eq(
    try {
      ignore(Frame::decode(bytes))
      "decoded"
    } catch {
      BadMagic(_) => "BadMagic"
      _ => "other"
    },
    "BadMagic",
  )
}

///|
test "frame: a stream frame names its own kind" {
  for kind in [Init, Data, Feedback, Close] {
    let frame = Frame::new(kind, 3, b"")
    let bytes = frame.encode()
    assert_eq(bytes[2].to_int(), 1)
    let (decoded, _) = Frame::decode(bytes)
    assert_eq(decoded.kind, kind)
  }
}

///|
test "protocol: a request survives its encoder" {
  let request = Request::new(
    caller="trpc.app.server.service",
    callee="trpc.test.Greeter",
    func="/trpc.test.Greeter/SayHello",
    request_id=41,
    timeout=2000,
  )
  request.trans_info["trpc-dyeing-key"] = b"blue"
  request.message_type = message_dyeing
  let decoded = Request::decode(request.encode())
  assert_eq(decoded.request_id, 41)
  assert_eq(decoded.timeout, 2000)
  assert_eq(@utf8.decode_lossy(decoded.func), "/trpc.test.Greeter/SayHello")
  assert_eq(decoded.path(), "/trpc.test.Greeter/SayHello")
  assert_eq(decoded.trans_info.get("trpc-dyeing-key"), Some(b"blue"))
  assert_eq(decoded.message_type, message_dyeing)
}

///|
test "protocol: a response's return code is signed" {
  let response = Response::new(request_id=9, ret=ret_server_noservice)
  response.error_msg = @utf8.encode("no such service")
  let decoded = Response::decode(response.encode())
  assert_eq(decoded.request_id, 9)
  assert_eq(decoded.ret, 11)
  assert_eq(@utf8.decode_lossy(decoded.error_msg), "no such service")
}

///|
test "protocol: a path with no `func` comes from the callee, which is what Python sends" {
  let request = Request::new(callee="trpc.test.Greeter")
  assert_eq(request.path(), "/trpc/test/Greeter")
}

///|
async test "session: a unary call is answered and the path is routed" {
  let server = Server::new()
  routes(server)
  let link = MemoryLink::new(Session::new(server))
  let client = Client::new(link)
  let reply = client.unary("/test.Echo/Say", b"hello")
  assert_eq(reply, b"hello")
}

///|
async test "session: a method that is not registered is `nofunc`" {
  let link = MemoryLink::new(Session::new(Server::new()))
  let client = Client::new(link)
  assert_eq(
    try {
      ignore(client.unary("/test.Echo/Say", b"hello"))
      "ok"
    } catch {
      @wire.StatusError(status, message) => "\{status.code()} \{message}"
    },
    "12 no method is registered at /test.Echo/Say",
  )
}

///|
async test "session: a server-streaming method answers every message" {
  let server = Server::new()
  routes(server)
  let link = MemoryLink::new(Session::new(server))
  let client = Client::new(link)
  let replies = client.stream("/test.Echo/Count", [b"x"])
  assert_eq(replies.length(), 2)
  assert_eq(replies[0], b"x")
  assert_eq(replies[1], b"x")
}

///|
async test "session: a client-streaming method sees every message" {
  let server = Server::new()
  routes(server)
  let link = MemoryLink::new(Session::new(server))
  let client = Client::new(link)
  let reply = client.stream("/test.Echo/Sum", [b"ab", b"cd"])
  assert_eq(reply, [b"abcd"])
}

///|
async test "session: a bidirectional method answers as the messages arrive" {
  let server = Server::new()
  routes(server)
  let link = MemoryLink::new(Session::new(server))
  let client = Client::new(link)
  let replies = client.stream("/test.Echo/Chat", [b"a", b"b"])
  assert_eq(replies, [b"a", b"b"])
}

///|
async test "session: a unary call reaches a streaming method and is refused" {
  let server = Server::new()
  routes(server)
  let link = MemoryLink::new(Session::new(server))
  let client = Client::new(link)
  assert_eq(
    try {
      ignore(client.unary("/test.Echo/Count", b"x"))
      "ok"
    } catch {
      @wire.StatusError(status, message) => "\{status.code()} \{message}"
    },
    "12 /test.Echo/Count is a streaming method; a unary call cannot reach it",
  )
}

///|
async test "session: a compressed request is inflated before it reaches the handler" {
  let server = Server::new()
  routes(server)
  let link = MemoryLink::new(Session::new(server))
  let client = Client::new(link)
  let reply = client.unary(
    "/test.Echo/Say",
    b"a body long enough that gzip makes it shorter than the plain bytes",
    content_encoding=compress_gzip,
  )
  assert_eq(
    reply, b"a body long enough that gzip makes it shorter than the plain bytes",
  )
}
