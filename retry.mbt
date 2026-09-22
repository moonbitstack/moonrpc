// gRPC transparent-retry policy (the `retryPolicy` of a service config's method
// config): how many attempts a call may make, which `grpc-status` codes permit
// another attempt, and the exponential backoff between them. This is pure decision
// logic — all-backend and total — that the async `Channel` drives: it decides
// *whether* and *how long to wait*, the socket layer re-issues and sleeps.

///|
/// A method's retry policy. `max_attempts` counts the first try plus every retry
/// (gRPC caps it at 5); a call is retried only while attempts remain and its status
/// is in `retryable`. Backoff starts at `initial_backoff_millis` and grows by
/// `backoff_multiplier` each retry, capped at `max_backoff_millis`.
pub(all) struct RetryPolicy {
  max_attempts : Int
  initial_backoff_millis : Int
  max_backoff_millis : Int
  backoff_multiplier : Double
  retryable : Array[Int]
}

///|
/// A conventional default: up to 3 attempts, 100 ms initial backoff doubling to a
/// 1 s cap, retrying only `UNAVAILABLE` — the code a transient, safe-to-retry
/// transport failure carries.
pub fn RetryPolicy::default() -> RetryPolicy {
  {
    max_attempts: 3,
    initial_backoff_millis: 100,
    max_backoff_millis: 1000,
    backoff_multiplier: 2.0,
    retryable: [Status::code(Unavailable)],
  }
}

///|
/// Whether a call that has made `attempts_made` attempts (the first is 1) and got
/// `status_code` should be tried again: attempts must remain, and the status must be
/// non-OK and listed as retryable.
pub fn RetryPolicy::should_retry(
  self : RetryPolicy,
  status_code : Int,
  attempts_made : Int,
) -> Bool {
  // gRPC caps the effective attempt count at 5 regardless of the configured value.
  let cap = if self.max_attempts > 5 { 5 } else { self.max_attempts }
  if attempts_made >= cap || status_code == 0 {
    return false
  }
  for code in self.retryable {
    if code == status_code {
      return true
    }
  }
  false
}

///|
/// The backoff cap before the `retry_index`-th retry (the first retry is 1):
/// `min(initial * multiplier^(retry_index-1), max)`. gRPC sleeps a value drawn
/// uniformly from `[0, cap]`; the async driver applies that jitter, so this returns
/// the deterministic upper bound (which is also what a jitter-free driver sleeps).
pub fn RetryPolicy::backoff_millis(
  self : RetryPolicy,
  retry_index : Int,
) -> Int {
  // Before the first retry there is nothing to back off from, and the policy's own
  // starting value is the answer; the arithmetic after it is moonpool's.
  let index = if retry_index < 1 { 1 } else { retry_index }
  let schedule = @moonpool.Backoff::new(
    base=@moondate.Span::new(millis=self.initial_backoff_millis.to_int64()),
    factor=self.backoff_multiplier,
    cap=@moondate.Span::new(millis=self.max_backoff_millis.to_int64()),
    jitter=Rigid,
  )
  let ms = (schedule.ceiling(index).nanos / 1_000_000L).to_int()
  // Never sleep a negative duration, even if a policy is misconfigured with a negative
  // backoff.
  if ms < 0 {
    0
  } else {
    ms
  }
}
