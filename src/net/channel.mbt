// The native gRPC Channel client: a long-lived, multiplexed h2c connection over a
// real `@socket.Tcp`, driven by the pure `@moonrpc.H2Client` engine. The engine
// allocates stream ids, builds request HEADERS + DATA, and reassembles replies;
// this file only pumps bytes — write the engine's request frames, read response
// frames off the socket, feed them back — and enforces the client-side deadline by
// racing the read loop against a timer.

///|
/// A connected gRPC channel. One TCP connection carries every call, each on its own
/// client-allocated (odd) stream id, so calls multiplex over the shared HPACK and
/// flow-control state the engine keeps.
pub struct Channel {
  conn : @socket.Tcp
  engine : @moonrpc.H2Client
  throttle : @moonrpc.Throttle?
  roll : () -> Double
}

///|
/// Open a channel to `host:port`: connect, send the 24-octet connection preface and
/// the client SETTINGS. The server's SETTINGS are read and acknowledged lazily on
/// the first call.
///
/// `throttling` turns on A6 retry throttling for every call on the channel, which is
/// one server name. `rand` draws the backoff jitter from `[0, 1)`; without it the
/// channel draws from a system-seeded generator.
pub async fn Channel::connect(
  host : String,
  port : Int32,
  throttling? : @moonrpc.Throttling,
  rand? : () -> Double,
) -> Channel {
  let conn = @socket.Tcp::connect(
    @socket.Addr::parse(host + ":" + port.to_string()),
  )
  let engine = @moonrpc.H2Client::new()
  conn.write(@http2.preface)
  write_frames(conn, engine.preface())
  {
    conn,
    engine,
    throttle: throttling.map(@moonrpc.Throttle::new),
    roll: rand.unwrap_or(system_roll()),
  }
}

///|
/// Close the underlying connection. Outstanding calls are abandoned.
pub fn Channel::close(self : Channel) -> Unit {
  self.conn.close()
}

///|
/// Read response frames for call `id`, feeding each to the engine and writing back
/// whatever it produces (SETTINGS ack, PING pong, WINDOW_UPDATE), until the engine
/// marks the call complete.
async fn Channel::pump(self : Channel, id : Int32) -> Unit {
  while !self.engine.is_done(id) {
    let frame = read_frame(self.conn)
    write_frames(self.conn, self.engine.feed(frame))
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
          write_frames(self.conn, [
            @http2.Frame::RstStream(
              stream_id=id,
              error_code=@http2.error_cancel,
            ),
          ]) catch {
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
  let (id, frames) = self.engine.unary(
    path,
    request,
    metadata~,
    timeout_millis?,
  )
  write_frames(self.conn, frames)
  self.drive(id, timeout_millis)
}

///|
/// Run a call's attempts on this channel under `retry`, transparently retrying a
/// stream the server refused even without one.
async fn Channel::call(
  self : Channel,
  metadata : Array[@header.Header],
  timeout_millis : Int32?,
  retry : @moonrpc.Retry?,
  once : async (Array[@header.Header], Int32?) -> @moonrpc.CallReply,
) -> @moonrpc.CallReply {
  let attempts = @moonrpc.Attempts::new(retry?, throttle?=self.throttle)
  attempting(attempts, self.roll, metadata, timeout_millis, once)
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
  self.call(metadata, timeout_millis, retry, (md, ms) => {
    self.unary_once(path, request, md, ms)
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
  let id = self.engine.open(path, metadata~, timeout_millis?)
  for m in requests {
    write_frames(self.conn, self.engine.send(id, m))
  }
  write_frames(self.conn, self.engine.close_send(id))
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
  self.call(metadata, timeout_millis, retry, (md, ms) => {
    self.stream_once(path, [request], md, ms)
  })
}

///|
/// Open a streaming call and collect at least `count` reply messages read inline off the
/// socket — no background reader — returning as soon as that many have arrived or the server
/// ends the stream. This bounds an otherwise unbounded stream (a subscription such as etcd's
/// Watch, or a long server-streaming feed) to the messages the caller wants, then the caller
/// closes the channel; reading inline keeps the whole exchange in one task with a clean
/// close, avoiding a demux pump that a blocked socket read can't be cancelled out of. Pass
/// `half_close=false` for a bidi subscription that keeps its request side open.
pub async fn Channel::stream_take(
  self : Channel,
  path : String,
  request : Bytes,
  count : Int32,
  metadata~ : Array[@header.Header] = [],
  timeout_millis? : Int32,
  half_close~ : Bool = true,
) -> Array[Bytes] {
  let id = self.engine.open(path, metadata~, timeout_millis?)
  write_frames(self.conn, self.engine.send(id, request, end=half_close))
  let collected : Array[Bytes] = []
  while collected.length() < count && !self.engine.is_done(id) {
    let frame = read_frame(self.conn)
    write_frames(self.conn, self.engine.feed(frame))
    for m in self.engine.take_messages(id) {
      collected.push(m)
    }
  }
  collected
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
  self.call(metadata, timeout_millis, retry, (md, ms) => {
    self.stream_once(path, requests, md, ms)
  })
}

///|
/// Make a bidirectional-streaming call: send every message in `requests`, half-close,
/// then read the ordered run of reply messages the server produced (in
/// `CallReply::messages`). This is the eager form the engine's synchronous core
/// models — every request is sent before the replies are collected, which pairs with
/// the eager server `BidiHandler`. A truly interactive exchange (sending while
/// receiving) or several concurrent calls multiplexed on one channel need the shared
/// read-demux loop on the roadmap; until then a `Channel` drives one call at a time.
/// Because every request is in hand, `retry` works as for [`Channel::unary`].
pub async fn Channel::bidi(
  self : Channel,
  path : String,
  requests : Array[Bytes],
  metadata~ : Array[@header.Header] = [],
  timeout_millis? : Int32,
  retry? : @moonrpc.Retry,
) -> @moonrpc.CallReply {
  self.call(metadata, timeout_millis, retry, (md, ms) => {
    self.stream_once(path, requests, md, ms)
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
