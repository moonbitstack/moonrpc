///|
/// One request goes as a unary call, any other number as a stream that is
/// half-closed after the last; both collect every reply under `retry`.
pub impl @moonrpc.Caller for Channel with fn invoke(
  self,
  path,
  requests,
  metadata,
  timeout_millis,
  retry,
) {
  match requests {
    [request] => self.unary(path, request, metadata~, timeout_millis?, retry?)
    _ => self.bidi(path, requests, metadata~, timeout_millis?, retry?)
  }
}

///|
/// As for `Channel`, on the backend the policy picks.
pub impl @moonrpc.Caller for ManagedChannel with fn invoke(
  self,
  path,
  requests,
  metadata,
  timeout_millis,
  retry,
) {
  match requests {
    [request] => self.unary(path, request, metadata~, timeout_millis?, retry?)
    _ => self.bidi(path, requests, metadata~, timeout_millis?, retry?)
  }
}

///|
/// Concurrent with the channel's other calls. A `MuxChannel` sends a call once,
/// so a `retry` policy is refused rather than left unapplied.
pub impl @moonrpc.Caller for MuxChannel with fn invoke(
  self,
  path,
  requests,
  metadata,
  timeout_millis,
  retry,
) {
  if retry is Some(_) {
    raise @wire.StatusError(
      Unimplemented,
      "a MuxChannel does not retry; call through a Channel or a ManagedChannel",
    )
  }
  self.call({ path, requests, metadata, timeout_millis, retry, })
}

///|
pub extend Channel with @moonrpc.Caller::{invoke}

///|
pub extend ManagedChannel with @moonrpc.Caller::{invoke}

///|
pub extend MuxChannel with @moonrpc.Caller::{invoke}
