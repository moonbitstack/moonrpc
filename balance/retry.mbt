// gRPC client retries, as proposal A6 defines them: the retry policy, the throttle
// shared by every call to one server, the server's pushback, and the decision a call
// makes after each attempt. All of it is pure; the channel sends, sleeps and reads.
// https://github.com/grpc/proposal/blob/master/A6-client-retries.md

///|
/// A method's retry policy (A6 `retryPolicy`). `backoff` carries `maxAttempts` as
/// `attempts`, `initialBackoff` as `base`, `maxBackoff` as `cap` and
/// `backoffMultiplier` as `factor`; `codes` is `retryableStatusCodes`.
pub(all) struct Retry {
  backoff : @moonward.Backoff
  codes : Array[@wire.Status]
} derive(Eq, Debug)

///|
pub extend Retry with Eq::{equal, not_equal}

///|
pub extend Retry with Debug::{to_repr}

///|
/// A6's example policy: four attempts, a hundred milliseconds doubling to a second
/// with a fifth either way, retrying `UNAVAILABLE`.
pub let retry : Retry = {
  backoff: { ..@moonward.backoff, attempts: 4, },
  codes: [Unavailable],
}

///|
/// A policy by A6's field names, the jitter the preset's.
pub fn Retry::new(
  attempts~ : Int32 = retry.backoff.attempts,
  base~ : @moondate.Span = retry.backoff.base,
  cap~ : @moondate.Span = retry.backoff.cap,
  factor~ : Double = retry.backoff.factor,
  codes~ : Array[@wire.Status] = retry.codes,
) -> Retry {
  { backoff: { ..retry.backoff, attempts, base, cap, factor, }, codes, }
}

///|
/// The most attempts a client makes whatever a policy asks for. A6 puts it on the
/// client because a service config can arrive over DNS.
pub let limit : Int32 = 5

///|
/// Retry throttling (A6 `retryThrottling`): `tokens` is `maxTokens`, `ratio` is
/// `tokenRatio`. There is no preset, because a channel without one does not throttle.
pub(all) struct Throttling {
  tokens : Int32
  ratio : Double
} derive(Eq, Debug)

///|
pub extend Throttling with Eq::{equal, not_equal}

///|
pub extend Throttling with Debug::{to_repr}

///|
/// Throttling by name.
pub fn Throttling::new(tokens~ : Int32, ratio~ : Double) -> Throttling {
  { tokens, ratio, }
}

///|
/// The token count one server name shares across every call to it. A failure takes a
/// token, a success gives back `ratio`, and at or below half the maximum no call is
/// retried or hedged. Kept in thousandths of a token as gRPC core keeps it, so a
/// ratio is read to three decimal places and nothing drifts.
pub struct Throttle {
  priv max : Int32
  priv ratio : Int32
  priv mut count : Int32
}

///|
/// A throttle starting full.
pub fn Throttle::new(throttling : Throttling) -> Throttle {
  let max = throttling.tokens * 1000
  { max, ratio: (throttling.ratio * 1000.0).to_int(), count: max, }
}

///|
/// Whether a retry or a further hedge may go out.
pub fn Throttle::allows(self : Throttle) -> Bool {
  self.count > self.max / 2
}

///|
/// A call that succeeded.
pub fn Throttle::pass(self : Throttle) -> Unit {
  let up = self.count + self.ratio
  self.count = if up > self.max { self.max } else { up }
}

///|
/// A call that failed with a retryable status, or that the server pushed back.
pub fn Throttle::fail(self : Throttle) -> Unit {
  let down = self.count - 1000
  self.count = if down < 0 { 0 } else { down }
}

///|
/// The tokens left.
pub fn Throttle::tokens(self : Throttle) -> Double {
  self.count.to_double() / 1000.0
}

///|
/// What the server said about trying again, in `grpc-retry-pushback-ms`.
pub(all) enum Pushback {
  /// Nothing: the policy decides.
  Absent
  /// Try again after exactly this long.
  After(@moondate.Span)
  /// Do not try again: a negative or unreadable value, or more than one.
  Stop
} derive(Eq, Debug)

///|
pub extend Pushback with Eq::{equal, not_equal}

///|
pub extend Pushback with Debug::{to_repr}

///|
/// The pushback a reply's trailers carry.
pub fn Pushback::read(trailers : ArrayView[@header.Header]) -> Pushback {
  let mut found : Bytes? = None
  for h in trailers {
    if h.name == b"grpc-retry-pushback-ms" {
      guard found is None else { return Stop }
      found = Some(h.value)
    }
  }
  match found {
    None => Absent
    Some(raw) =>
      match millis(raw) {
        Some(ms) => After(@moondate.Span::new(millis=ms.to_int64()))
        None => Stop
      }
  }
}

///|
/// A non-negative 32-bit decimal, or nothing.
fn millis(raw : Bytes) -> Int32? {
  if raw.length() == 0 || raw.length() > 10 {
    return None
  }
  let mut n = 0L
  for b in raw {
    guard b >= b'0' && b <= b'9' else { return None }
    n = n * 10L + (b.to_int() - '0'.to_int()).to_int64()
  }
  if n > 0x7FFFFFFFL {
    None
  } else {
    Some(n.to_int())
  }
}

///|
/// One call's retry state across its attempts.
pub struct Attempts {
  priv retry : Retry?
  priv throttle : Throttle?
  priv limit : Int32
  priv mut made : Int32
  priv mut since_pushback : Int32
  priv mut transparent : Bool
}

///|
/// The state before the first attempt. Without `retry` the call is still retried
/// transparently, as A6 asks of every call.
pub fn Attempts::new(
  retry? : Retry,
  throttle? : Throttle,
  limit~ : Int32 = limit,
) -> Attempts {
  { retry, throttle, limit, made: 1, since_pushback: 0, transparent: false, }
}

///|
/// Attempts sent under the policy so far, the first being 1. Transparent retries
/// are not counted.
pub fn Attempts::made(self : Attempts) -> Int32 {
  self.made
}

///|
/// What to do after an attempt ended with `status` and `trailers`: `None` hands this
/// result to the caller, `Some(wait)` sends another attempt after `wait`.
///
/// `committed` is a call whose response headers arrived, which A6 never retries;
/// `unprocessed` is one the server refused or a GOAWAY says it never handled, which
/// is retried once at once without counting. `roll` draws the jitter, from `[0, 1)`.
/// The order of the checks is grpc-go's.
pub fn Attempts::next(
  self : Attempts,
  status : Int32,
  trailers : ArrayView[@header.Header],
  committed~ : Bool = false,
  unprocessed~ : Bool = false,
  roll~ : Double = 0.5,
) -> @moondate.Span? {
  if status == @wire.Status::code(Ok) {
    if self.throttle is Some(t) {
      t.pass()
    }
    return None
  }
  if unprocessed && !committed && !self.transparent {
    self.transparent = true
    return Some(@moondate.Span::new())
  }
  guard !committed && self.retry is Some(retry) else { return None }
  let pushback = Pushback::read(trailers)
  if pushback is Stop {
    if self.throttle is Some(t) {
      t.fail()
    }
    return None
  }
  guard retry.codes.iter().any(c => c.code() == status) else { return None }
  if self.throttle is Some(t) {
    t.fail()
    guard t.allows() else { return None }
  }
  let most = if retry.backoff.attempts < self.limit {
    retry.backoff.attempts
  } else {
    self.limit
  }
  guard self.made < most else { return None }
  self.made += 1
  match pushback {
    After(wait) => {
      self.since_pushback = 0
      Some(wait)
    }
    _ => {
      self.since_pushback += 1
      Some(retry.backoff.delay(self.since_pushback, random=roll))
    }
  }
}
