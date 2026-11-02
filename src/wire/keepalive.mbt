// The gRPC client keepalive state machine (← gRPC `keepalive_time` / `keepalive_timeout`): keep a
// long-lived connection healthy by sending a PING when it has been idle, and declaring it dead if
// the PING's ACK does not come back in time. This is the pure decision core — it takes the current
// time and answers "ping now?" / "dead now?"; the Channel drives it, sending the actual HTTP/2 PING
// frame and closing the connection. Time is in the caller's unit (the same clock passed throughout).

///|
/// Keepalive state for one connection: the idle threshold that triggers a PING, the ACK deadline
/// that declares the connection dead, and the timers tracking the last activity and any in-flight
/// PING.
pub struct Keepalive {
  keepalive_time : Int64
  keepalive_timeout : Int64
  mut last_activity : Int64
  mut ping_outstanding : Bool
  mut ping_sent_at : Int64
}

///|
/// A keepalive that pings after `keepalive_time` of idleness and gives a PING `keepalive_timeout`
/// to be acknowledged. `now` seeds the activity clock.
pub fn Keepalive::new(
  keepalive_time~ : Int64,
  keepalive_timeout~ : Int64,
  now~ : Int64 = 0L,
) -> Keepalive {
  {
    keepalive_time,
    keepalive_timeout,
    last_activity: now,
    ping_outstanding: false,
    ping_sent_at: 0L,
  }
}

///|
/// Record connection activity (a frame sent or received) at `now`, resetting the idle timer.
pub fn Keepalive::on_activity(self : Keepalive, now : Int64) -> Unit {
  self.last_activity = now
}

///|
/// Whether a keepalive PING should be sent at `now`: the connection has been idle at least
/// `keepalive_time` and no PING is already awaiting its ACK.
pub fn Keepalive::should_ping(self : Keepalive, now : Int64) -> Bool {
  !self.ping_outstanding && now - self.last_activity >= self.keepalive_time
}

///|
/// Record that a keepalive PING was sent at `now`.
pub fn Keepalive::on_ping_sent(self : Keepalive, now : Int64) -> Unit {
  self.ping_outstanding = true
  self.ping_sent_at = now
}

///|
/// Record that the PING's ACK arrived at `now` — the connection is alive, and this counts as
/// activity.
pub fn Keepalive::on_ping_ack(self : Keepalive, now : Int64) -> Unit {
  self.ping_outstanding = false
  self.last_activity = now
}

///|
/// Whether the connection is dead at `now`: a PING is outstanding and its ACK has not arrived within
/// `keepalive_timeout` of sending it.
pub fn Keepalive::is_timed_out(self : Keepalive, now : Int64) -> Bool {
  self.ping_outstanding && now - self.ping_sent_at >= self.keepalive_timeout
}

///|
/// A server's keepalive policy (gRPC A8): `time` is how long an idle connection is left
/// alone before the server pings it, `timeout` how long the PING may go unanswered before
/// the connection is declared dead, `min_ping_interval` the shortest gap the server will
/// tolerate between a peer's PINGs, and `max_ping_strikes` how many of those too-soon PINGs
/// a peer gets before the connection is closed.
pub(all) struct ServerKeepalive {
  time : Int64
  timeout : Int64
  min_ping_interval : Int64
  permit_without_calls : Bool
  max_ping_strikes : Int32
}

///|
/// The policy gRPC core uses when a server sets none: two hours of idleness before a PING,
/// twenty seconds to answer it, a PING no more often than every five minutes, and two
/// strikes before the peer is told to calm down (`ENHANCE_YOUR_CALM`).
pub let server_keepalive : ServerKeepalive = {
  time: 7_200_000L,
  timeout: 20_000L,
  min_ping_interval: 300_000L,
  permit_without_calls: false,
  max_ping_strikes: 2,
}

///|
/// The guard a server keeps against a peer that pings it faster than the policy allows: a
/// PING inside `min_interval` is a strike, and `max_strikes` of them end the connection.
/// This is what stops a client from keeping a hundred thousand connections alive with a
/// PING every millisecond.
pub(all) struct PingGuard {
  min_interval : Int64
  max_strikes : Int32
  mut last : Int64
  mut strikes : Int32
}

///|
/// A guard that has seen no PING yet.
pub fn PingGuard::new(
  min_interval~ : Int64,
  max_strikes~ : Int32,
  now~ : Int64 = 0L,
) -> PingGuard {
  { min_interval, max_strikes, last: now, strikes: 0, }
}

///|
/// Record a PING at `now` and say whether the peer has struck out. The first PING of a
/// connection is never a strike: `last` starts at the connection's own start.
pub fn PingGuard::observe(self : PingGuard, now : Int64) -> Bool {
  // A well-spaced PING earns back nothing: the count is of strikes on this connection,
  // not a rate, so a peer that hammers three times and then behaves is still out.
  if now - self.last < self.min_interval {
    self.strikes = self.strikes + 1
  }
  self.last = now
  self.strikes > self.max_strikes
}

///|
/// The guard a policy implies, or `None` when the server takes no view on PING rate.
pub fn ServerKeepalive::ping_guard(
  self : ServerKeepalive,
  now~ : Int64 = 0L,
) -> PingGuard {
  PingGuard::new(
    min_interval=self.min_ping_interval,
    max_strikes=self.max_ping_strikes,
    now~,
  )
}
