// The incremental exchange, driven against a transport that records what it was asked to do.
// The socket halves are exercised by the official suite; here the protocol steps are checked
// without one.

///|
/// A transport whose reply is a fixed list of pieces and whose requests are recorded.
priv struct MockStream {
  sent : Array[Bytes]
  reply : Array[Bytes]
  fields : Array[@header.Header]
  status : Int32
  mut at : Int32
  mut cancelled : Bool
  mut ended : Bool
  mut closed : Bool
}

///|
fn MockStream::new(
  reply : Array[Bytes],
  status~ : Int32 = 200,
  fields~ : Array[@header.Header] = [],
) -> MockStream {
  {
    sent: [],
    reply,
    fields,
    status,
    at: 0,
    cancelled: false,
    ended: false,
    closed: false,
  }
}

///|
fn connect_fields() -> Array[@header.Header] {
  [@header.Header::of("content-type", "application/connect+proto")]
}

///|
impl StreamTransport for MockStream with fn open(
  self,
  _path,
  _content,
  _headers,
) {
  ignore(self)
}

///|
impl StreamTransport for MockStream with fn send(self, bytes) {
  self.sent.push(bytes)
}

///|
impl StreamTransport for MockStream with fn end(self) {
  self.ended = true
}

///|
impl StreamTransport for MockStream with fn cancel(self) {
  self.cancelled = true
}

///|
impl StreamTransport for MockStream with fn read(self) {
  if self.cancelled || self.at >= self.reply.length() {
    return None
  }
  let piece = self.reply[self.at]
  self.at = self.at + 1
  Some(piece)
}

///|
impl StreamTransport for MockStream with fn head(self) {
  (self.status, self.fields)
}

///|
impl StreamTransport for MockStream with fn close(self) {
  self.closed = true
}

///|
fn stream_of(reply : Array[Bytes]) -> (MockStream, &StreamTransport) {
  let mock = MockStream::new(reply, fields=connect_fields())
  let stream : &StreamTransport = mock
  (mock, stream)
}

///|
fn message(payload : Bytes) -> Bytes {
  encode_envelope(payload)
}

///|
fn end(payload : String) -> Bytes {
  encode_envelope(@utf8.encode(payload), flags=flag_end_stream)
}

///|
async test "an exchange sends each message separately and closes its send side" {
  let (mock, stream) = stream_of([
    message(b"first"),
    message(b"second"),
    end("{}"),
  ])
  let content : Content = { codec: Proto, streaming: true, }
  let exchange = Exchange::open(stream, "/svc/Method", content)
  exchange.send(b"one")
  exchange.send(b"two")
  exchange.close_send()
  let reply = exchange.finish() catch { _ => abort("a clean stream failed") }
  assert_eq(reply.messages.length(), 2)
  assert_eq(reply.messages[0], b"first")
  assert_eq(reply.messages[1], b"second")
  // Two request envelopes and the end-stream one: each is its own write.
  assert_eq(mock.sent.length(), 3)
  assert_true(mock.sent[2][0] == flag_end_stream)
  assert_true(mock.ended)
  exchange.close()
  assert_true(mock.closed)
}

///|
async test "cancelling before the send side closes aborts the request in flight" {
  let (mock, stream) = stream_of([message(b"never read")])
  let content : Content = { codec: Proto, streaming: true, }
  let exchange = Exchange::open(stream, "/svc/Method", content)
  exchange.send(b"one")
  exchange.cancel()
  let outcome : Result[Reply, Failure] = Ok(exchange.finish()) catch {
    CallFailed(failure) => Err(failure)
  }
  match outcome {
    Ok(_) => abort("a cancelled exchange answered with a reply")
    Err(failure) => {
      assert_eq(failure.status, @wire.Status::Cancelled)
      assert_eq(failure.payloads.length(), 0)
    }
  }
  assert_true(mock.cancelled)
  assert_false(mock.ended)
  // The end-stream envelope was never written: cancelling is not closing the send side.
  assert_eq(mock.sent.length(), 1)
}

///|
async test "an error in the end-stream envelope is the call's failure, with its earlier answers" {
  let (_, stream) = stream_of([
    message(b"answer"),
    end("{\"error\":{\"code\":\"resource_exhausted\",\"message\":\"no\"}}"),
  ])
  let content : Content = { codec: Proto, streaming: true, }
  let exchange = Exchange::open(stream, "/svc/Method", content)
  exchange.close_send()
  let outcome : Result[Reply, Failure] = Ok(exchange.finish()) catch {
    CallFailed(failure) => Err(failure)
  }
  match outcome {
    Ok(_) => abort("an end-stream error was reported as success")
    Err(failure) => {
      assert_eq(failure.status, @wire.Status::ResourceExhausted)
      assert_eq(failure.message, "no")
      assert_eq(failure.payloads.length(), 1)
      assert_eq(failure.payloads[0], b"answer")
    }
  }
}

///|
async test "a null error in the end-stream envelope is a clean end" {
  let (_, stream) = stream_of([end("{\"error\":null}")])
  let content : Content = { codec: Proto, streaming: true, }
  let exchange = Exchange::open(stream, "/svc/Method", content)
  exchange.close_send()
  let reply = exchange.finish() catch {
    _ => abort("a null error was treated as a failure")
  }
  assert_eq(reply.messages.length(), 0)
}

///|
async test "an answer arrives one envelope at a time" {
  // Split the reply in the middle of an envelope: `next` has to wait for the rest of it.
  let whole = message(b"split")
  let (_, stream) = stream_of([
    whole[:3].to_owned(),
    whole[3:].to_owned(),
    end("{}"),
  ])
  let content : Content = { codec: Proto, streaming: true, }
  let exchange = Exchange::open(stream, "/svc/Method", content)
  exchange.close_send()
  let answer : Bytes? = exchange.next() catch { _ => None }
  match answer {
    Some(bytes) => assert_eq(bytes, b"split")
    None => abort("a message split across two pieces was lost")
  }
  let last : Bytes? = exchange.next() catch { _ => None }
  assert_eq(last, None)
}
