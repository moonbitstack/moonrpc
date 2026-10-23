// The load-balanced gRPC client: a `ManagedChannel` dials one real `Channel` per resolved
// address, tracks each address's connectivity in the pure `@moonrpc.ConnectionPool`, and
// routes every call to a READY sub-connection its LB policy picks. This is where the pure
// decision cores (connectivity state machine + pool + picker) meet real sockets — the pool
// says *which* address to use, this drives the actual bytes over that address's connection.

///|
/// A load-balanced channel over several backends. The pool holds one sub-connection per
/// address (its connectivity state); `channels` holds the live `Channel` for each address
/// that dialed successfully.
pub struct ManagedChannel {
  pool : @moonrpc.ConnectionPool
  channels : Map[String, Channel]
  throttle : @moonrpc.Throttle?
  roll : () -> Double
}

///|
/// The `grpc-status` an RPC gets when no backend is reachable.
fn unavailable_reply() -> @moonrpc.CallReply {
  {
    status: b"",
    grpc_status: @moonrpc.Status::code(Unavailable),
    grpc_message: "no backend available",
    headers: [],
    messages: [],
    trailers: [],
    committed: false,
    unprocessed: false,
  }
}

///|
/// Dial every backend in `targets` (each a `host, port`), marking each sub-connection READY
/// on a successful connect and TRANSIENT_FAILURE on a dial error, then load-balance calls
/// across the ones that came up. Addresses keep their given order, which is the order
/// `RoundRobin` cycles and `PickFirst` prefers.
///
/// `throttling` and `rand` are as for [`Channel::connect`]: the backends are one
/// server name, so they share one throttle.
pub async fn ManagedChannel::connect(
  targets : Array[(String, Int32)],
  policy~ : @moonrpc.LbPolicy = PickFirst,
  throttling? : @moonrpc.Throttling,
  rand? : () -> Double,
) -> ManagedChannel {
  let keys = targets.map(t => t.0 + ":" + t.1.to_string())
  let pool = @moonrpc.ConnectionPool::new(keys, policy~)
  let channels : Map[String, Channel] = Map([])
  for t in targets {
    let key = t.0 + ":" + t.1.to_string()
    guard pool.subconn(key) is Some(sc) else { continue }
    sc.connect()
    try {
      let ch = Channel::connect(t.0, t.1)
      channels[key] = ch
      sc.on_connected()
    } catch {
      _ => sc.on_failure()
    }
  }
  {
    pool,
    channels,
    throttle: throttling.map(@moonrpc.Throttle::new),
    roll: rand.unwrap_or(system_roll()),
  }
}

///|
/// Resolve `name`'s A records via the DNS server at `dns_server:dns_port`, then dial each
/// resolved address at `target_port` and load-balance across them — gRPC's `dns:///`
/// target end to end (name resolution feeding the connection pool).
pub async fn ManagedChannel::dns_connect(
  dns_server : String,
  dns_port : Int32,
  name : String,
  target_port : Int32,
  policy~ : @moonrpc.LbPolicy = PickFirst,
  id~ : Int32 = 0x2a2a,
  throttling? : @moonrpc.Throttling,
  rand? : () -> Double,
) -> ManagedChannel {
  let addrs = resolve_a(dns_server, dns_port, name, id~)
  ManagedChannel::connect(
    addrs.map(a => (a, target_port)),
    policy~,
    throttling?,
    rand?,
  )
}

///|
/// The live `Channel` for the next attempt, chosen by the pool's picker over the
/// READY sub-connections. A connection that has received GOAWAY opens no stream, so
/// the next live one stands in for it. `None` when nothing is reachable.
fn ManagedChannel::pick(self : ManagedChannel) -> Channel? {
  if self.pool.pick() is Some(address) &&
    self.channels.get(address) is Some(ch) &&
    !ch.engine.goaway_received() {
    return Some(ch)
  }
  for address in self.pool.ready_addresses() {
    if self.channels.get(address) is Some(ch) && !ch.engine.goaway_received() {
      return Some(ch)
    }
  }
  None
}

///|
/// A READY backend that no in-flight attempt has claimed, preferring one this call
/// has not tried yet, together with its address. Hedging needs this because a
/// `Channel` drives one call at a time: two attempts sharing one channel would read
/// the same socket concurrently, which aborts the event loop.
fn ManagedChannel::pick_unused(
  self : ManagedChannel,
  claimed : Array[String],
  tried~ : Array[String] = [],
) -> (String, Channel)? {
  let mut fallback = None
  for address in self.pool.ready_addresses() {
    guard !claimed.contains(address) &&
      self.channels.get(address) is Some(ch) &&
      !ch.engine.goaway_received() else {
      continue
    }
    if !tried.contains(address) {
      return Some((address, ch))
    }
    if fallback is None {
      fallback = Some((address, ch))
    }
  }
  fallback
}

///|
/// The addresses of every backend currently carrying calls, in resolver order — the READY
/// subset the picker draws from.
pub fn ManagedChannel::ready_addresses(self : ManagedChannel) -> Array[String] {
  self.pool.ready_addresses()
}

///|
/// Run a call's attempts, each on a backend picked for it, so a retry can land on a
/// different backend from the attempt that failed (gRPC A6). No READY backend is an
/// `UNAVAILABLE` attempt, which a policy that retries it waits out.
async fn ManagedChannel::call(
  self : ManagedChannel,
  metadata : Array[@header.Header],
  timeout_millis : Int32?,
  retry : @moonrpc.Retry?,
  send : async (Channel, Array[@header.Header], Int32?) -> @moonrpc.CallReply,
) -> @moonrpc.CallReply {
  let attempts = @moonrpc.Attempts::new(retry?, throttle?=self.throttle)
  attempting(attempts, self.roll, metadata, timeout_millis, (md, ms) => {
    match self.pick() {
      Some(ch) => send(ch, md, ms)
      None => unavailable_reply()
    }
  })
}

///|
/// Make a unary call on a picked backend, under `retry` as [`Channel::unary`] does it.
pub async fn ManagedChannel::unary(
  self : ManagedChannel,
  path : String,
  request : Bytes,
  metadata~ : Array[@header.Header] = [],
  timeout_millis? : Int32,
  retry? : @moonrpc.Retry,
) -> @moonrpc.CallReply {
  self.call(metadata, timeout_millis, retry, (ch, md, ms) => {
    ch.unary_once(path, request, md, ms)
  })
}

///|
/// Make a unary call under `hedging` (gRPC A6): the first attempt at once, another
/// every `delay` on a backend no other attempt holds, until one settles the call.
///
/// A non-fatal status sends the next attempt at once. The server's pushback either
/// stops further attempts or sets when the next one goes. Past the first, an attempt
/// goes out only while the channel's throttle allows it. When the last attempt ends
/// without settling the call and no other can start, its reply is the answer.
pub async fn ManagedChannel::unary_hedged(
  self : ManagedChannel,
  path : String,
  request : Bytes,
  hedging~ : @moonrpc.Hedging = @moonrpc.hedging,
  metadata~ : Array[@header.Header] = [],
  timeout_millis? : Int32,
) -> @moonrpc.CallReply {
  let left = budget(timeout_millis)
  let run = () => {
    @async.with_task_group(g => {
      let finished : @aqueue.Queue[(String, @moonrpc.CallReply)] = @aqueue.Queue::Queue(
        kind=Unbounded,
      )
      let claimed : Array[String] = []
      let tried : Array[String] = []
      let mut started = 0
      let mut running = 0
      let mut stopped = false
      let can_start = () => {
        !stopped &&
        hedging.more(started) &&
        (started == 0 || self.throttle.map(t => t.allows()).unwrap_or(true))
      }
      let start = () => {
        guard can_start() &&
          self.pick_unused(claimed, tried~) is Some((address, ch)) else {
          return false
        }
        claimed.push(address)
        tried.push(address)
        let md = with_previous(metadata, started)
        let ms = left()
        started += 1
        running += 1
        g.spawn_bg(() => {
          finished.put((address, ch.unary_once(path, request, md, ms)))
        })
        true
      }
      // The timer only matters while there is an attempt to start and a backend
      // free to start it on; otherwise only a reply can change anything.
      let waiting = () => {
        can_start() && self.pick_unused(claimed, tried~) is Some(_)
      }
      let delay = (hedging.delay.nanos / 1_000_000L).to_int()
      let mut wait = delay
      let mut last = unavailable_reply()
      guard start() else { return last }
      for ;; {
        let next = if waiting() {
          @async.with_timeout_opt(wait, () => finished.get())
        } else {
          Some(finished.get())
        }
        match next {
          None => {
            ignore(start())
            wait = delay
          }
          Some((address, reply)) => {
            running -= 1
            last = reply
            claimed.retain(a => a != address)
            if hedging.commits(reply.grpc_status) {
              if reply.grpc_status == 0 && self.throttle is Some(t) {
                t.pass()
              }
              g.return_immediately(reply)
            }
            if self.throttle is Some(t) {
              t.fail()
            }
            match @moonrpc.Pushback::read(reply.trailers) {
              Stop => stopped = true
              After(span) => wait = (span.nanos / 1_000_000L).to_int()
              Absent => {
                ignore(start())
                wait = delay
              }
            }
            if running == 0 && !start() {
              return last
            }
          }
        }
      }
      last
    })
  }
  match timeout_millis {
    None => run()
    Some(ms) =>
      match (@async.with_timeout_opt(ms, run) : @moonrpc.CallReply?) {
        Some(reply) => reply
        None => deadline_reply()
      }
  }
}

///|
/// Make a server-streaming call on a picked backend, under `retry`.
pub async fn ManagedChannel::server_streaming(
  self : ManagedChannel,
  path : String,
  request : Bytes,
  metadata~ : Array[@header.Header] = [],
  timeout_millis? : Int32,
  retry? : @moonrpc.Retry,
) -> @moonrpc.CallReply {
  self.call(metadata, timeout_millis, retry, (ch, md, ms) => {
    ch.stream_once(path, [request], md, ms)
  })
}

///|
/// Make a client-streaming call on a picked backend, under `retry`.
pub async fn ManagedChannel::client_streaming(
  self : ManagedChannel,
  path : String,
  requests : Array[Bytes],
  metadata~ : Array[@header.Header] = [],
  timeout_millis? : Int32,
  retry? : @moonrpc.Retry,
) -> @moonrpc.CallReply {
  self.call(metadata, timeout_millis, retry, (ch, md, ms) => {
    ch.stream_once(path, requests, md, ms)
  })
}

///|
/// Make a bidirectional-streaming call on a picked backend, under `retry`.
pub async fn ManagedChannel::bidi(
  self : ManagedChannel,
  path : String,
  requests : Array[Bytes],
  metadata~ : Array[@header.Header] = [],
  timeout_millis? : Int32,
  retry? : @moonrpc.Retry,
) -> @moonrpc.CallReply {
  self.call(metadata, timeout_millis, retry, (ch, md, ms) => {
    ch.stream_once(path, requests, md, ms)
  })
}

///|
/// Close every live backend connection.
pub fn ManagedChannel::close(self : ManagedChannel) -> Unit {
  for _addr, ch in self.channels {
    ch.close()
  }
}
