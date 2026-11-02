// Connection backoff (gRPC `doc/connection-backoff.md`): after a backend fails, the next
// dial to it waits longer and longer, with jitter, so a hundred clients reconnecting to a
// restarted server do not arrive in the same millisecond. Pure decisions here; the channel
// dials when this says the wait is over.

///|
/// A backoff schedule: the first wait, the factor each failure multiplies it by, the cap,
/// and how much of the wait is jitter.
pub(all) struct Backoff {
  initial : @moondate.Span
  max : @moondate.Span
  factor : Double
  jitter : Double
}

///|
/// The schedule the gRPC document specifies: one second, times 1.6 each time, capped at two
/// minutes, with the wait drawn from ±20% of it.
pub let backoff : Backoff = {
  initial: @moondate.Span::new(millis=1000L),
  max: @moondate.Span::new(millis=120_000L),
  factor: 1.6,
  jitter: 0.2,
}

///|
/// The shortest time a connection attempt may be given before it counts as failed, however
/// short the backoff has become. The document's `minConnectTimeout`.
pub let min_connect_timeout : @moondate.Span = @moondate.Span::new(
  millis=20_000L,
)

///|
/// A schedule by its four numbers.
pub fn Backoff::new(
  initial~ : @moondate.Span = backoff.initial,
  max~ : @moondate.Span = backoff.max,
  factor~ : Double = backoff.factor,
  jitter~ : Double = backoff.jitter,
) -> Backoff {
  { initial, max, factor, jitter, }
}

///|
/// How long to wait before the `attempt`-th dial (the first being 1): the initial wait
/// times the factor once per earlier failure, capped, then spread by the jitter — `roll`
/// draws from `[0, 1)` and 0.5 is no spread at all.
pub fn Backoff::delay(
  self : Backoff,
  attempt : Int32,
  roll~ : Double = 0.5,
) -> @moondate.Span {
  let cap = self.max.nanos.to_double()
  let mut wait = self.initial.nanos.to_double()
  for _i = 1; _i < attempt; _i = _i + 1 {
    wait = wait * self.factor
    if wait > cap {
      wait = cap
      break
    }
  }
  // The jitter multiplies the wait by something in [1 - jitter, 1 + jitter).
  let spread = 1.0 + (roll * 2.0 - 1.0) * self.jitter
  @moondate.Span::new(nanos=(wait * spread).to_int64())
}

///|
/// One backend's reconnect clock: how many dials have failed in a row, and when the next one
/// may happen.
pub(all) struct Reconnect {
  backoff : Backoff
  mut failures : Int32
  mut next_at : Int64
}

///|
/// A reconnect clock that dials at once.
pub fn Reconnect::new(
  backoff~ : Backoff = backoff,
  now~ : Int64 = 0L,
) -> Reconnect {
  { backoff, failures: 0, next_at: now, }
}

///|
/// Record a failed dial at `now` and schedule the next one. `roll` draws the jitter.
pub fn Reconnect::failed(
  self : Reconnect,
  now : Int64,
  roll~ : Double = 0.5,
) -> Unit {
  self.failures = self.failures + 1
  let wait = self.backoff.delay(self.failures, roll~)
  self.next_at = now + wait.nanos / 1_000_000L
}

///|
/// Record a dial that worked: the next failure starts the schedule over.
pub fn Reconnect::succeeded(self : Reconnect) -> Unit {
  self.failures = 0
  self.next_at = 0L
}

///|
/// Whether a dial may be made now, or how long is left before it may (`0` when it may).
pub fn Reconnect::wait_millis(self : Reconnect, now : Int64) -> Int64 {
  let left = self.next_at - now
  if left < 0L {
    0L
  } else {
    left
  }
}

///|
/// Whether a dial may be made now.
pub fn Reconnect::due(self : Reconnect, now : Int64) -> Bool {
  self.wait_millis(now) == 0L
}
