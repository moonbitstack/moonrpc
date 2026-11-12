// The client side of trpc.io's protocol: calls in, `Outcome`s out, over whatever carries
// HTTP. The transport is a function so that a test can answer without a socket and the
// native build can use its own connection.

///|
/// A call that did not produce a value. The `Failure` is the server's own description of
/// what went wrong, kept whole so a caller can read the code, the status or its `data`.
pub(all) suberror CallFailed {
  CallFailed(Failure)
}

///|
/// What a transport does with one request: the status, and the body it answered with.
pub type Send = async (Request) -> (Int, String) raise

///|
pub struct Client {
  send : Send
  // Whether a query travels as a GET, which is what tRPC's batching link does for one.
  // A POST carries the same call and is understood by every tRPC server.
  get_queries : Bool
}

///|
pub fn Client::new(send : Send, get_queries~ : Bool = false) -> Client {
  { send, get_queries }
}

///|
/// One call, resolved to its value or the failure the server named.
async fn Client::call(self : Client, call : Call, get~ : Bool) -> Json raise CallFailed {
  let request = request_of(call, get~)
  let (status, body) = (self.send)(request) catch {
    error =>
      raise CallFailed(
        failure_of("INTERNAL_SERVER_ERROR", error.to_string()),
      )
  }
  match decode_reply(body, batch=false) {
    Some([outcome]) =>
      match outcome {
        Ok(value) => value
        Failed(failure) => raise CallFailed(failure)
      }
    Some([]) => raise CallFailed(failure_of("BAD_REQUEST", "the reply was empty"))
    _ =>
      raise CallFailed(
        failure_of(
          "INTERNAL_SERVER_ERROR",
          "the reply was not the protocol's own shape (status " +
            status.to_string() +
            ")",
        ),
      )
  }
}

///|
/// A query: a call that answers a value and changes nothing.
pub async fn Client::query(
  self : Client,
  path : String,
  input? : Json,
) -> Json raise CallFailed {
  self.call({ path, input }, get=self.get_queries)
}

///|
/// A mutation: a call that may change something. Never a GET.
pub async fn Client::mutate(
  self : Client,
  path : String,
  input? : Json,
) -> Json raise CallFailed {
  self.call({ path, input }, get=false)
}

///|
/// Several calls in one request. The answers come back in the order the calls were given,
/// each one a value or a failure of its own.
pub async fn Client::batch(
  self : Client,
  calls : Array[Call],
) -> Array[Outcome] raise CallFailed {
  if calls.length() == 0 {
    return []
  }
  let request = batch_request_of(calls, get=self.get_queries)
  let (status, body) = (self.send)(request) catch {
    error =>
      raise CallFailed(
        failure_of("INTERNAL_SERVER_ERROR", error.to_string()),
      )
  }
  match decode_reply(body, batch=true) {
    Some(outcomes) =>
      if outcomes.length() == calls.length() {
        outcomes
      } else {
        raise CallFailed(
          failure_of(
            "BAD_REQUEST",
            "the reply answered " +
              outcomes.length().to_string() +
              " of " +
              calls.length().to_string() +
              " calls",
          ),
        )
      }
    None =>
      raise CallFailed(
        failure_of(
          "INTERNAL_SERVER_ERROR",
          "the reply was not JSON (status " + status.to_string() + ")",
        ),
      )
  }
}
