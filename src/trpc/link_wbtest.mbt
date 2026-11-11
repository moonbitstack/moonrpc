// The protocol against itself: frames round-trip, a unary call is answered, and the four
// streaming shapes go through one session as they would over a socket.

///|
/// A link that answers from a `Session` in the same process, so a test exercises the
/// client and the server halves without a socket.
struct MemoryLink {
  session : Session
  replies : Array[Bytes]
  mut at : Int32
}

///|
fn MemoryLink::new(session : Session) -> MemoryLink {
  { session, replies: [], at: 0, }
}

///|
impl Link for MemoryLink with fn write(self, bytes) {
  let (frame, _) = Frame::decode(bytes)
  for reply in self.session.handle(frame) {
    self.replies.push(reply)
  }
}

///|
impl Link for MemoryLink with fn read(self) {
  if self.at >= self.replies.length() {
    raise Truncated
  }
  let (frame, _) = Frame::decode(self.replies[self.at])
  self.at = self.at + 1
  frame
}

///|
pub extend MemoryLink with Link::{read, write}

///|
/// A server with the four streaming shapes, and a client on a link that answers in the same
/// process.
fn shapes() -> Client {
  let server = Server::new()
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
  let link = MemoryLink::new(Session::new(server))
  Client::new(link)
}

///|
async test "trpc: a client-streaming call sends every request and reads one reply" {
  let client = shapes()
  let reply = client.client_stream("/test.Echo/Sum", [b"a", b"b", b"c"]) catch {
    e => abort("client stream: \{e.to_string()}")
  }
  assert_eq(reply, b"abc")
}

///|
async test "trpc: a bidirectional call answers each message before the next is sent" {
  let client = shapes()
  let exchange = client.open("/test.Echo/Chat") catch {
    e => abort("open: \{e.to_string()}")
  }
  for body in [b"one", b"two", b"three"] {
    exchange.send(body) catch {
      e => abort("send: \{e.to_string()}")
    }
    let answer : Result[Bytes?, @wire.StatusError] = Ok(exchange.next()) catch {
      e => Err(e)
    }
    match answer {
      Err(e) => abort("next: " + e.to_string())
      Ok(Some(reply)) => assert_eq(reply, body)
      Ok(None) =>
        abort("the stream closed before answering " + @utf8.decode_lossy(body))
    }
  }
  exchange.close() catch {
    e => abort("close: \{e.to_string()}")
  }
  assert_true(exchange.ended())
  assert_eq(exchange.replies().length(), 0)
}

///|
async test "trpc: a bidirectional call driven to its end returns every reply in order" {
  let client = shapes()
  let replies = client.bidi("/test.Echo/Chat", [b"x", b"y"]) catch {
    e => abort("bidi: \{e.to_string()}")
  }
  assert_eq(replies.length(), 2)
  assert_eq(replies[0], b"x")
  assert_eq(replies[1], b"y")
}
