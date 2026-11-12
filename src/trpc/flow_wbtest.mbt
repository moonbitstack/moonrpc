// Flow control, both directions: the window the far end grants, and the credit this end
// hands back as it consumes. Neither is visible in a round trip that fits in one window, so
// each case here opens the window down to a size that forces the wait.

///|
/// A link whose replies are whatever the test put there, and which records everything the
/// client wrote. The frames are handed over whole, so a test states the peer's side of the
/// conversation literally.
struct ScriptedLink {
  replies : Array[Frame]
  mut at : Int32
  written : Array[Frame]
}

///|
fn ScriptedLink::new(replies : Array[Frame]) -> ScriptedLink {
  { replies, at: 0, written: [], }
}

///|
impl Link for ScriptedLink with fn write(self, bytes) {
  let (frame, _) = Frame::decode(bytes)
  self.written.push(frame)
}

///|
impl Link for ScriptedLink with fn read(self) {
  if self.at >= self.replies.length() {
    raise Truncated
  }
  let frame = self.replies[self.at]
  self.at = self.at + 1
  frame
}

///|
pub extend ScriptedLink with Link::{read, write}

///|
/// A server whose one streaming method answers with messages of a stated size, so a window
/// can be chosen to fit exactly one of them.
fn windowed_server(message : Bytes) -> Server {
  let server = Server::new()
  server.register(
    "/test.Window/Echo",
    @stream.Handler::ServerStreaming((_ctx, _body) => [message, message]),
  )
  server.register(
    "/test.Window/Chat",
    @stream.Handler::Bidi(_ctx => {
      on_message: body => [body],
      on_end: () => [],
    }),
  )
  server
}

///|
/// An INIT frame naming the window the sender will accept.
fn init_frame(stream_id : Int64, window : UInt32) -> Frame {
  let meta = StreamInitMeta::new(
    request_meta=StreamInitRequestMeta::new(
      caller="test",
      callee="test.Window",
      func="/test.Window/Echo",
    ),
    window~,
  )
  Frame::new(Init, stream_id, meta.encode())
}

///|
async test "flow: a message past the window waits, and the CLOSE waits behind it" {
  let message = Bytes::make(30, b'x')
  let session = Session::new(windowed_server(message))
  let opening = session.handle(init_frame(1L, 40))
  // The head, and the credit for the window the caller named.
  assert_eq(opening.length(), 2)
  let (head, _) = Frame::decode(opening[0])
  assert_eq(head.kind, Init)

  let request = Frame::new(Data, 1L, b"ask")
  assert_eq(session.handle(request).length(), 1)

  // The handler answers with two thirty-octet messages inside a forty-octet window: the first
  // fits with ten to spare, the second does not, and the CLOSE that follows may not overtake it.
  let closing = session.handle(
    Frame::new(Close, 1L, StreamCloseMeta::new().encode()),
  )
  assert_eq(closing.length(), 1)
  let (sent, _) = Frame::decode(closing[0])
  assert_eq(sent.kind, Data)
  assert_eq(sent.payload.length(), 30)

  // Ten octets of credit cannot take a thirty-octet message either.
  let trickle = Frame::new(
    Feedback,
    1L,
    StreamFeedbackMeta::new(window_increment=10).encode(),
  )
  assert_eq(session.handle(trickle).length(), 0)

  // Thirty more can, and the CLOSE behind it goes out with it, in that order.
  let credit = Frame::new(
    Feedback,
    1L,
    StreamFeedbackMeta::new(window_increment=30).encode(),
  )
  let released = session.handle(credit)
  assert_eq(released.length(), 2)
  let (second, _) = Frame::decode(released[0])
  assert_eq(second.kind, Data)
  assert_eq(second.payload.length(), 30)
  let (end, _) = Frame::decode(released[1])
  assert_eq(end.kind, Close)
}

///|
async test "flow: the client waits for FEEDBACK before sending past the window" {
  let opening = StreamInitMeta::new(
    request_meta=StreamInitRequestMeta::new(
      caller="test",
      callee="test.Window",
      func="/test.Window/Echo",
    ),
    window=10,
  )
  let link = ScriptedLink::new([
    Frame::new(Init, 1L, opening.encode()),
    Frame::new(
      Feedback,
      1L,
      StreamFeedbackMeta::new(window_increment=10).encode(),
    ),
  ])
  let client = Client::new(link)
  let exchange = client.open("/test.Window/Echo") catch {
    e => abort("the call was refused: \{e.to_string()}")
  }
  // Ten octets fit the window exactly.
  exchange.send(b"0123456789") catch {
    _ => abort("the first message was refused")
  }
  // The next one waits for credit, and the FEEDBACK that is already queued is what lets it out.
  exchange.send(b"abcdefghij") catch {
    _ => abort("the second message was refused")
  }
  assert_eq(link.written.length(), 3)
  assert_eq(link.written[1].kind, Data)
  assert_eq(link.written[2].kind, Data)
}

///|
/// A link that keeps both directions: what the client wrote, and what the session answered.
/// The credit a reader hands back travels the first way, so a test that wants to see it needs
/// a record of the writes as well as the replies.
struct LoggingLink {
  session : Session
  replies : Array[Bytes]
  written : Array[Bytes]
  mut at : Int32
}

///|
fn LoggingLink::new(session : Session) -> LoggingLink {
  { session, replies: [], written: [], at: 0, }
}

///|
impl Link for LoggingLink with fn write(self, bytes) {
  self.written.push(bytes)
  let (frame, _) = Frame::decode(bytes)
  for reply in self.session.handle(frame) {
    self.replies.push(reply)
  }
}

///|
impl Link for LoggingLink with fn read(self) {
  if self.at >= self.replies.length() {
    raise Truncated
  }
  let (frame, _) = Frame::decode(self.replies[self.at])
  self.at = self.at + 1
  frame
}

///|
pub extend LoggingLink with Link::{read, write}

///|
async test "flow: a reply behind the CLOSE is kept, and nothing is credited for it" {
  let message = b"reply"
  let link = LoggingLink::new(Session::new(windowed_server(message)))
  let client = Client::new(link)
  let exchange = client.open("/test.Window/Echo") catch {
    e => abort("the call was refused: \{e.to_string()}")
  }
  exchange.send(b"ask") catch {
    _ => abort("the request was refused")
  }
  // This peer answers only once the send side closes, so both replies arrive behind the CLOSE.
  exchange.close() catch {
    e => abort("the call did not close: \{e.to_string()}")
  }
  // They are still the caller's: a reply that arrives as the stream ends is not lost.
  assert_eq(exchange.replies().length(), 2)
  // But no credit goes back for them. A FEEDBACK written after the CLOSE is a frame for a
  // stream the far end has already dropped — tRPC-Go answers one with `uninitialized meta` —
  // and the window it would return is worth nothing to a stream that is ending.
  let mut credited = 0
  for bytes in link.written {
    let (frame, _) = Frame::decode(bytes)
    if frame.kind == Feedback {
      let meta = StreamFeedbackMeta::decode(frame.payload) catch {
        _ => StreamFeedbackMeta::new()
      }
      credited = credited + meta.window_increment.reinterpret_as_int()
    }
  }
  assert_eq(credited, 0)
  // And the CLOSE is the last thing written: nothing follows it.
  let (last, _) = Frame::decode(link.written[link.written.length() - 1])
  assert_eq(last.kind, Close)
}

///|
async test "flow: a message past the window is not written until its credit is read" {
  let opening = StreamInitMeta::new(
    request_meta=StreamInitRequestMeta::new(
      caller="test",
      callee="test.Window",
      func="/test.Window/Echo",
    ),
    window=10,
  )
  let link = ScriptedLink::new([
    Frame::new(Init, 1L, opening.encode()),
    Frame::new(
      Feedback,
      1L,
      StreamFeedbackMeta::new(window_increment=10).encode(),
    ),
  ])
  let client = Client::new(link)
  let exchange = client.open("/test.Window/Echo") catch {
    e => abort("the call was refused: \{e.to_string()}")
  }
  // The INIT is the one frame read so far, and it named ten octets.
  assert_eq(link.at, (1 : Int32))
  exchange.send(b"0123456789") catch {
    _ => abort("the first message was refused")
  }
  // It fit, so no credit was read for it: the write went out on the window that was already
  // there.
  assert_eq(link.at, (1 : Int32))
  // Ten octets past what is left must be paid for first, and the credit is read before the
  // octets go out — a sender that wrote them anyway is what a strict peer disconnects over.
  exchange.send(b"abcdefghij") catch {
    _ => abort("the second message was refused")
  }
  assert_eq(link.at, (2 : Int32))
  assert_eq(link.written.length(), 3)
}

///|
async test "flow: nothing goes out after the CLOSE, not even credit" {
  // A message that arrives behind the CLOSE is kept for the caller, and no credit is written
  // for it: the far end has dropped the stream by then, and tRPC-Go answers a FEEDBACK for a
  // stream it no longer holds with `uninitialized meta`.
  let link = ScriptedLink::new([
    init_frame(1L, 100),
    Frame::new(Data, 1L, b"late"),
    Frame::new(Close, 1L, StreamCloseMeta::new().encode()),
  ])
  let client = Client::new(link)
  let exchange = client.open("/test.Window/Echo") catch {
    e => abort("the call was refused: \{e.to_string()}")
  }
  exchange.close() catch {
    e => abort("the call did not close: \{e.to_string()}")
  }
  assert_eq(exchange.replies().length(), 1)
  // The INIT and the CLOSE, and nothing else.
  assert_eq(link.written.length(), 2)
  assert_eq(link.written[1].kind, Close)
}
