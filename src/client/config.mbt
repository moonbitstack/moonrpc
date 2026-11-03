// Applying a service config to one call: the per-method retry, timeout and
// wait-for-ready a channel falls back on when the caller set nothing itself.

///|
/// Fill an invocation's retry policy, deadline and wait-for-ready from the service
/// config's entry for its method. An explicit caller setting always wins, so a
/// per-call argument is not silently overridden by the channel's config.
pub fn resolve(
  invocation : Invocation,
  config : @balance.ServiceConfig?,
) -> Invocation {
  let entry = match config {
    Some(c) => c.for_method(invocation.path)
    None => None
  }
  match entry {
    None => invocation
    Some(m) =>
      {
        ..invocation,
        retry: match invocation.retry {
          Some(_) => invocation.retry
          None => m.retry
        },
        timeout_millis: match invocation.timeout_millis {
          Some(_) => invocation.timeout_millis
          None => m.timeout_millis()
        },
        wait_for_ready: invocation.wait_for_ready ||
        m.wait_for_ready.unwrap_or(false),
      }
  }
}
