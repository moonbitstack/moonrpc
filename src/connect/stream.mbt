// An incremental Connect call: one request body that stays open while the caller decides what
// to send next, and a reply that is read envelope by envelope. A one-shot POST cannot issue a
// cancellation before its send side closes, nor stop after a stated number of answers — those
// two shapes need the exchange to be driven in steps.
//
// The protocol work (envelopes, compression, errors, trailers) stays here; `net` supplies the
// two transports that keep a socket open across those steps.

///|
/// What a streaming transport owes an exchange. `open` writes the request head without an
/// end-of-body marker; `send` writes one piece; `end` closes the send side; `cancel` aborts the
/// whole exchange; `read` returns the next piece of the reply, or `None` when the reply (or
/// the connection) has ended. `head` is the status and headers read so far.
pub(open) trait StreamTransport {
  async fn open(Self, String, Content, Array[@header.Header]) -> Unit
  async fn send(Self, Bytes) -> Unit
  async fn end(Self) -> Unit
  async fn cancel(Self) -> Unit
  async fn read(Self) -> Bytes?
  fn head(Self) -> (Int32, Array[@header.Header])
  async fn close(Self) -> Unit
}

///|
/// A streaming call in progress. The caller sends messages, may read answers as they arrive,
/// closes its send side, and either reads the outcome or cancels — at any point.
pub(all) struct Exchange {
  priv stream : &StreamTransport
  priv content : Content
  priv encoding : String?
  priv body : @buffer.Buffer
  priv messages : Array[Bytes]
  priv trailers : Array[@header.Header]
  priv mut raw : Array[@header.Header]
  priv mut compressed : Bool
  priv mut stream_end : Bool
  priv mut cancelled : Bool
  priv mut send_closed : Bool
  priv mut error_body : Bool
}

///|
/// Open a call. The request head goes out now; the body is empty until the first `send`.
pub async fn Exchange::open(
  stream : &StreamTransport,
  path : String,
  content : Content,
  metadata~ : Array[@header.Header] = [],
  encoding? : String,
  accept~ : Array[String] = [],
  timeout_millis? : Int32,
) -> Exchange {
  let all = with_timeout(
    request_headers(content, metadata, encoding, accept),
    timeout_millis,
  )
  stream.open(path, content, all)
  {
    stream,
    content,
    encoding,
    body: Buffer(),
    messages: [],
    trailers: [],
    raw: [],
    compressed: false,
    stream_end: false,
    cancelled: false,
    send_closed: false,
    error_body: false,
  }
}

///|
/// One request message out, as its own envelope.
pub async fn Exchange::send(self : Exchange, message : Bytes) -> Unit {
  guard !self.cancelled && !self.send_closed else { return }
  self.stream.send(envelope_of(self.encoding, message))
}

///|
/// Close the send side: write the end-stream envelope and mark the body finished. A caller
/// that cancels instead of doing this has, by definition, cancelled before closing it.
pub async fn Exchange::close_send(self : Exchange) -> Unit {
  if self.cancelled || self.send_closed {
    return
  }
  self.stream.send(end_envelope(self.content))
  self.send_closed = true
  self.stream.end()
}

///|
/// Give up on the call. The transport aborts the request in flight — an HTTP/2 RST_STREAM or
/// a closed socket — so the far end sees a cancelled call rather than a client that merely
/// stopped reading. Anything read before this point is discarded from the outcome.
pub async fn Exchange::cancel(self : Exchange) -> Unit {
  if self.cancelled || self.stream_end {
    return
  }
  self.cancelled = true
  self.stream.cancel()
}

///|
/// Whether the caller gave up on the call.
pub fn Exchange::cancelled(self : Exchange) -> Bool {
  self.cancelled
}

///|
/// The messages read so far, in order.
pub fn Exchange::replies(self : Exchange) -> Array[Bytes] {
  self.messages
}

///|
/// The trailing metadata the end-stream envelope carried, once it has been read.
pub fn Exchange::trailers(self : Exchange) -> Array[@header.Header] {
  trailers_without_error(self.trailers)
}

///|
/// The reply's headers, with the protocol's own removed.
pub fn Exchange::headers(self : Exchange) -> Array[@header.Header] {
  reply_headers(split_unary_headers(self.raw).0)
}

///|
/// The next reply message, or `None` when the stream ended, the reply failed, or the caller
/// cancelled. Envelopes are decoded as they arrive, so a caller can stop after N answers
/// without waiting for the rest of the body.
pub async fn Exchange::next(self : Exchange) -> Bytes? {
  for ;; {
    if self.cancelled || self.error_body {
      return None
    }
    let data = self.body.to_bytes()
    if !self.content.streaming {
      // A unary reply is one bare message, not a run of envelopes.
      if self.stream_end {
        return None
      }
      let piece = self.stream.read() catch { _ => None }
      match piece {
        Some(bytes) => {
          self.body.write_bytes(bytes)
          self.note_head()
        }
        None => self.stream_end = true
      }
      continue
    }
    match decode_envelope(data[:]) {
      Some((envelope, stop)) => {
        self.body.reset()
        self.body.write_bytes(data[stop:].to_owned())
        if envelope.is_end_stream() {
          for trailer in trailers_of_end(envelope, self.reply_encoding()) {
            self.trailers.push(trailer)
          }
          self.stream_end = true
          return None
        }
        let message = if envelope.is_compressed() {
          self.compressed = true
          match decode_compression(self.reply_encoding(), envelope.payload) {
            Some(plain) => plain
            None => envelope.payload
          }
        } else {
          envelope.payload
        }
        self.messages.push(message)
        return Some(message)
      }
      None => {
        if self.stream_end {
          return None
        }
        let piece = self.stream.read() catch { _ => None }
        match piece {
          Some(bytes) => {
            if bytes.length() > 0 {
              self.body.write_bytes(bytes)
            }
            self.note_head()
          }
          None => self.stream_end = true
        }
      }
    }
  }
}

///|
/// The encoding the peer named for the reply's envelopes.
fn Exchange::reply_encoding(self : Exchange) -> String {
  response_encoding(self.raw, true)
}

///|
/// Copy the status and headers the transport has read, and notice a non-200 reply: its body
/// is a unary error document, not a run of envelopes, so no further envelope is decoded.
fn Exchange::note_head(self : Exchange) -> Unit {
  let (status, raw) = self.stream.head()
  self.raw = raw
  if status != 0 && status != 200 {
    self.error_body = true
  }
}

///|
/// Read the exchange to its end and answer with the reply, or with the failure it carried. A
/// cancelled exchange has no outcome: the messages it happened to read are not reported.
pub async fn Exchange::finish(self : Exchange) -> Reply raise CallFailed {
  for ;; {
    let answer : Bytes? = self.next() catch { _ => None }
    if answer is None {
      break
    }
  }
  if self.cancelled {
    raise CallFailed({
      status: Cancelled,
      message: "",
      details: [],
      headers: self.headers(),
      trailers: self.trailers(),
      payloads: self.messages,
    })
  }
  let (status, raw) = self.stream.head()
  let (headers, unary_trailers) = split_unary_headers(raw)
  if status != 200 {
    raise CallFailed(
      failure_of(
        status,
        self.body.to_bytes(),
        headers,
        trailers_without_error(self.trailers),
      ),
    )
  }
  check_response(self.content, headers, self.compressed)
  finish_stream(
    headers,
    self.messages,
    if self.trailers.length() > 0 {
      self.trailers
    } else {
      unary_trailers
    },
  )
}

///|
/// Close the underlying connection. An exchange is one call, so this is what a caller does
/// once it has the outcome or has cancelled.
pub async fn Exchange::close(self : Exchange) -> Unit {
  self.stream.close()
}
