// The native gRPC Channel client: a long-lived, multiplexed connection over a real
// `@tcp.Conn` — TLS with ALPN `h2`, or h2c — driven by the pure `@moonrpc.H2Client` engine.
// The engine allocates stream ids, builds request HEADERS + DATA, and reassembles replies;
// this file only pumps bytes — write the engine's request frames, read response frames off
// the socket, feed them back — and enforces the client-side deadline by racing the read
// loop against a timer.
//
// There is no background task: a call that finds the socket unread reads it for every
// call, so a channel needs no task group and any number of tasks may share one.

///|
/// A connected gRPC channel. One connection carries every call, each on its own
/// client-allocated (odd) stream id, so calls multiplex over the shared HPACK and
/// flow-control state the engine keeps.
pub struct Channel {
  conn : @tcp.Conn
  engine : @moonrpc.H2Client
  throttle : @moonrpc.Throttle?
  roll : () -> Double
  outgoing : @async.Mutex
  turn : @async.CondVar
  mut reading : Bool
  // The client interceptor chain every call on this channel goes through, outermost
  // first; empty unless a caller added one.
  interceptors : Array[@client.Interceptor]
}

///|
/// Open a channel to `host:port`: connect, then send the 24-octet connection preface and
/// the client SETTINGS. With `tls` the connection is a TLS one, and the handshake must
/// have settled on ALPN `h2` before a frame is sent. The server's SETTINGS are read and
/// acknowledged lazily on the first call.
///
/// `throttling` turns on A6 retry throttling for every call on the channel, which is
/// one server name. `rand` draws the backoff jitter from `[0, 1)`; without it the
/// channel draws from a system-seeded generator.
pub async fn Channel::connect(
  host : String,
  port : Int32,
  throttling? : @moonrpc.Throttling,
  rand? : () -> Double,
  tls? : @tls.Client,
  interceptors? : Array[@client.Interceptor],
) -> Channel {
  let conn = @tcp.dial(host, port~, tls?)
  // A handshake that did not settle on h2 leaves nothing to say in HTTP/2: the socket
  // is closed rather than spoken to in a version the peer did not agree to.
  if unnegotiated(conn) {
    conn.close()
    raise @io.ReaderClosed
  }
  let engine = @moonrpc.H2Client::new()
  conn.write(@http2.preface)
  write_frames(conn, engine.preface())
  {
    conn,
    engine,
    throttle: throttling.map(@moonrpc.Throttle::new),
    roll: rand.unwrap_or(system_roll()),
    outgoing: @async.Mutex::Mutex(),
    turn: @async.CondVar::Cond(),
    reading: false,
    interceptors: interceptors.unwrap_or([]),
  }
}

///|
/// Add a client interceptor to this channel: every call it makes from now on runs through
/// it, whichever of the four call kinds it is.
pub fn Channel::add_interceptor(
  self : Channel,
  interceptor : @client.Interceptor,
) -> Unit {
  self.interceptors.push(interceptor)
}

///|
/// Close the underlying connection. Outstanding calls are abandoned.
pub fn Channel::close(self : Channel) -> Unit {
  self.conn.close()
}

///|
/// Run `body` with the connection's write side to itself. The engine's frames must leave in
/// the order it made them, since HPACK state is shared and a header block overtaken by a later
/// one does not decode; a cancelled task still finishes, since half a frame ends the connection.
async fn[T] Channel::sending(self : Channel, body : async () -> T) -> T {
  @async.protect_from_cancel(() => {
    self.outgoing.acquire()
    defer self.outgoing.release()
    body()
  })
}

///|
/// Read one frame. A cancel lands only between frames: one inside a frame would leave the next
/// reader partway through it, and every call on the channel after that would fail.
async fn read_whole_frame(conn : @tcp.Conn) -> @http2.Frame {
  let first : FixedArray[Byte] = FixedArray::make(1, 0)
  if conn.read(first) == 0 {
    raise @io.ReaderClosed
  }
  @async.protect_from_cancel(() => {
    let head = [first[0], ..conn.read_exactly(8)]
    read_payload(conn, Bytes::from_array(head))
  })
}

///|
/// Take one step: read a frame for every call on the channel, or wait for the call that is. When
/// the reader leaves, by finishing, by its deadline or by the connection failing, the calls
/// waiting wake and one of them takes over.
async fn Channel::advance(self : Channel) -> Unit {
  if self.reading {
    self.turn.wait()
    return
  }
  self.reading = true
  defer {
    self.reading = false
    self.turn.broadcast()
  }
  let frame = read_whole_frame(self.conn)
  self.sending(() => write_frames(self.conn, self.engine.feed(frame)))
}

///|
/// Read response frames, feeding each to the engine and writing back whatever it produces
/// (SETTINGS ack, PING pong, WINDOW_UPDATE), until the engine marks call `id` complete.
async fn Channel::pump(self : Channel, id : Int32) -> Unit {
  while !self.engine.is_done(id) {
    self.advance()
  }
}

///|
/// Drive a call to completion, enforcing its deadline when one is set: if the timer
/// elapses first, reset the stream (RST_STREAM CANCEL) and return a synthetic
/// `DEADLINE_EXCEEDED` reply instead of the server's.
async fn Channel::drive(
  self : Channel,
  id : Int32,
  timeout_millis : Int32?,
) -> @moonrpc.CallReply {
  // Every path out of here — reply, deadline, cancellation — is the end of this call,
  // and the engine keeps its buffers until told otherwise. A `Channel` is one
  // long-lived connection, so without this the state of every RPC it ever carried
  // stays resident and every settings or window frame walks the lot.
  defer self.engine.release(id)
  match timeout_millis {
    None => {
      self.pump(id)
      self.engine.reply(id)
    }
    Some(ms) =>
      match (@async.with_timeout_opt(ms, () => self.pump(id)) : Unit?) {
        Some(_) => self.engine.reply(id)
        None => {
          self.sending(() => {
            write_frames(self.conn, [
              @http2.Frame::RstStream(
                stream_id=id,
                error_code=@http2.error_cancel,
              ),
            ])
          }) catch {
            _ => ()
          }
          deadline_reply()
        }
      }
  }
}

///|
/// Issue one unary attempt on a fresh stream and drive it to its reply.
async fn Channel::unary_once(
  self : Channel,
  path : String,
  request : Bytes,
  metadata : Array[@header.Header],
  timeout_millis : Int32?,
) -> @moonrpc.CallReply {
  let id = self.sending(() => {
    let (id, frames) = self.engine.unary(
      path,
      request,
      metadata~,
      timeout_millis?,
    )
    write_frames(self.conn, frames)
    id
  })
  self.drive(id, timeout_millis)
}

///|
/// Run one call from the interceptor chain inward: the chain first, then the call's
/// attempts under `retry`, transparently retrying a stream the server refused even
/// without one. The chain wraps the whole call, not each attempt, so a retry is one
/// invocation as far as an interceptor is concerned.
async fn Channel::call(
  self : Channel,
  invocation : @client.Invocation,
  once : async (@client.Invocation) -> @moonrpc.CallReply,
) -> @moonrpc.CallReply {
  let chain = @client.intercepted(self.interceptors, invocation => {
    let attempts = @moonrpc.Attempts::new(
      retry?=invocation.retry,
      throttle?=self.throttle,
    )
    attempting(
      attempts,
      self.roll,
      invocation.metadata,
      invocation.timeout_millis,
      (md, ms) => once({ ..invocation, metadata: md, timeout_millis: ms, }),
    )
  })
  chain(invocation)
}

///|
/// Make a unary call: one request message, one reply. `timeout_millis`, when set, is
/// sent as `grpc-timeout` and enforced locally across every attempt.
///
/// With a `retry` policy a failed call goes out again on a new stream as gRPC A6
/// says: while it is uncommitted, its status retryable, attempts left and the
/// channel not throttled, after the backoff or the server's pushback. Each retry
/// carries `grpc-previous-rpc-attempts`.
pub async fn Channel::unary(
  self : Channel,
  path : String,
  request : Bytes,
  metadata~ : Array[@header.Header] = [],
  timeout_millis? : Int32,
  retry? : @moonrpc.Retry,
) -> @moonrpc.CallReply {
  self.call({ path, requests: [request], metadata, timeout_millis, retry, }, inv => {
    let request = if inv.requests.length() > 0 { inv.requests[0] } else { b"" }
    self.unary_once(inv.path, request, inv.metadata, inv.timeout_millis)
  })
}

///|
/// Send `requests` on a new stream, half-close, and drive it to its reply.
async fn Channel::stream_once(
  self : Channel,
  path : String,
  requests : Array[Bytes],
  metadata : Array[@header.Header],
  timeout_millis : Int32?,
) -> @moonrpc.CallReply {
  let id = self.sending(() => {
    let id = self.engine.open(path, metadata~, timeout_millis?)
    for m in requests {
      write_frames(self.conn, self.engine.send(id, m))
    }
    write_frames(self.conn, self.engine.close_send(id))
    id
  })
  self.drive(id, timeout_millis)
}

///|
/// Make a server-streaming call: one request message, then read the ordered run of
/// reply messages (in `CallReply::messages`) until the server closes the stream.
/// `retry` works as for [`Channel::unary`]; a stream whose response headers arrived
/// is committed and never retried.
pub async fn Channel::server_streaming(
  self : Channel,
  path : String,
  request : Bytes,
  metadata~ : Array[@header.Header] = [],
  timeout_millis? : Int32,
  retry? : @moonrpc.Retry,
) -> @moonrpc.CallReply {
  self.call({ path, requests: [request], metadata, timeout_millis, retry, }, inv => {
    self.stream_once(inv.path, inv.requests, inv.metadata, inv.timeout_millis)
  })
}

///|
/// Open a streaming call and collect at least `count` reply messages, returning as soon as that
/// many have arrived or the server ends the stream. This bounds an otherwise unbounded stream (a
/// subscription such as etcd's Watch, or a long server-streaming feed) to the messages the
/// caller wants. Pass `half_close=false` for a bidi subscription that keeps its request side
/// open.
pub async fn Channel::stream_take(
  self : Channel,
  path : String,
  request : Bytes,
  count : Int32,
  metadata~ : Array[@header.Header] = [],
  timeout_millis? : Int32,
  half_close~ : Bool = true,
) -> Array[Bytes] {
  let id = self.sending(() => {
    let id = self.engine.open(path, metadata~, timeout_millis?)
    write_frames(self.conn, self.engine.send(id, request, end=half_close))
    id
  })
  let collected : Array[Bytes] = []
  // Taken before each step too: another call's read may already have fed this stream.
  for ;; {
    collected.append(self.engine.take_messages(id))
    if collected.length() >= count || self.engine.is_done(id) {
      return collected
    }
    self.advance()
  }
}

///|
/// Make a client-streaming call: send every message in `requests`, half-close, then
/// read the single reply. The whole request stream is in hand, so `retry` works as
/// for [`Channel::unary`].
pub async fn Channel::client_streaming(
  self : Channel,
  path : String,
  requests : Array[Bytes],
  metadata~ : Array[@header.Header] = [],
  timeout_millis? : Int32,
  retry? : @moonrpc.Retry,
) -> @moonrpc.CallReply {
  self.call({ path, requests, metadata, timeout_millis, retry, }, inv => {
    self.stream_once(inv.path, inv.requests, inv.metadata, inv.timeout_millis)
  })
}

///|
/// Make a bidirectional-streaming call: send every message in `requests`, half-close,
/// then read the ordered run of reply messages the server produced (in
/// `CallReply::messages`). This is the eager form the engine's synchronous core
/// models — every request is sent before the replies are collected, which pairs with
/// the eager server `BidiHandler`. An interactive exchange, sending while receiving, is
/// what `MuxChannel` is for. Because every request is in hand, `retry` works as for
/// [`Channel::unary`].
pub async fn Channel::bidi(
  self : Channel,
  path : String,
  requests : Array[Bytes],
  metadata~ : Array[@header.Header] = [],
  timeout_millis? : Int32,
  retry? : @moonrpc.Retry,
) -> @moonrpc.CallReply {
  self.call({ path, requests, metadata, timeout_millis, retry, }, inv => {
    self.stream_once(inv.path, inv.requests, inv.metadata, inv.timeout_millis)
  })
}

///|
/// Register the `grpc.health.v1.Health` service (Check + Watch) on this server.
pub fn GrpcServer::register_health(
  self : GrpcServer,
  health : @moonrpc.HealthService,
) -> Unit {
  for entry in health.handlers() {
    self.handlers[entry.0] = entry.1
  }
}
