// gRPC hedging, as proposal A6 defines it: attempts sent in parallel, a new one every
// `delay` until one of them answers with a status that settles the call. Pure; the
// managed channel launches, waits and cancels.

///|
/// A method's hedging policy (A6 `hedgingPolicy`): `attempts` is `maxAttempts`,
/// `delay` is `hedgingDelay`, `codes` is `nonFatalStatusCodes`.
pub(all) struct Hedging {
  attempts : Int32
  delay : @moondate.Span
  codes : Array[@wire.Status]
} derive(Eq, Debug)

///|
pub extend Hedging with Eq::{equal, not_equal}

///|
pub extend Hedging with Debug::{to_repr}

///|
/// A6's example policy: four attempts half a second apart, `UNAVAILABLE`, `INTERNAL`
/// and `ABORTED` letting the others carry on.
pub let hedging : Hedging = {
  attempts: 4,
  delay: @moondate.Span::new(millis=500L),
  codes: [Unavailable, Internal, Aborted],
}

///|
/// A policy by A6's field names.
pub fn Hedging::new(
  attempts~ : Int32 = hedging.attempts,
  delay~ : @moondate.Span = hedging.delay,
  codes~ : Array[@wire.Status] = hedging.codes,
) -> Hedging {
  { attempts, delay, codes, }
}

///|
/// Whether another attempt may start when `started` have, under the policy and the
/// client's `limit`.
pub fn Hedging::more(
  self : Hedging,
  started : Int32,
  limit~ : Int32 = limit,
) -> Bool {
  started < (if self.attempts < limit { self.attempts } else { limit })
}

///|
/// Whether an attempt ending with `status` settles the call: OK does, and so does any
/// status outside `codes`. A non-fatal one sends the next attempt at once instead.
pub fn Hedging::commits(self : Hedging, status : Int32) -> Bool {
  status == @wire.Status::code(Ok) ||
  !self.codes.iter().any(c => c.code() == status)
}
