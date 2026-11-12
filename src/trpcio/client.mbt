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
pub type Send = async (Request) -> (Int32, String)

///|
pub struct Client {
  send : Send
  // Whether a query travels as a GET. `@trpc/server` accepts a query only that way — it
  // answers a POST to one with 405 — so the HTTP driver in `net` turns this on. Left off,
  // every call is a POST, which this library's own server reads and theirs refuses.
  get_queries : Bool
}

///|
pub fn Client::new(send : Send, get_queries~ : Bool = false) -> Client {
  { send, get_queries, }
}

///|
/// One call, resolved to its value or the failure the server named.
async fn Client::call(
  self : Client,
  call : Call,
  get~ : Bool,
) -> Json raise CallFailed {
  let request = request_of(call, get~)
  let (status, body) = (self.send)(request) catch {
    error =>
      raise CallFailed(failure_of("INTERNAL_SERVER_ERROR", error.to_string()))
  }
  match decode_reply(body, batch=false) {
    Some([outcome]) =>
      match outcome {
        Ok(value) => value
        Failed(failure) => raise CallFailed(failure)
      }
    Some([]) =>
      raise CallFailed(failure_of("BAD_REQUEST", "the reply was empty"))
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
  self.call(Call::new(path, input?), get=self.get_queries)
}

///|
/// A mutation: a call that may change something. Never a GET.
pub async fn Client::mutate(
  self : Client,
  path : String,
  input? : Json,
) -> Json raise CallFailed {
  self.call(Call::new(path, input?, mutation=true), get=false)
}

///|
/// Several calls in one request. The answers come back in the order the calls were given,
/// each one a value or a failure of its own.
///
/// A batch travels as one verb, so tRPC's own batching link splits one by kind: the queries
/// as a GET, the mutations as a POST, and the two answers merged back into the order they
/// were asked for. A batch of one kind is one request either way, which is the common case.
pub async fn Client::batch(
  self : Client,
  calls : Array[Call],
) -> Array[Outcome] raise CallFailed {
  if calls.length() == 0 {
    return []
  }
  let queries : Array[Call] = []
  let queries_at : Array[Int32] = []
  let posts : Array[Call] = []
  let posts_at : Array[Int32] = []
  for index, call in calls {
    // Only a query this client asks to send as a GET is one; everything else, a mutation
    // included, is a POST.
    if self.get_queries && !call.mutation {
      queries.push(call)
      queries_at.push(index)
    } else {
      posts.push(call)
      posts_at.push(index)
    }
  }
  let answers : Array[Outcome?] = []
  for _ in calls {
    answers.push(None)
  }
  for offset, outcome in self.send_batch(queries, get=true) {
    answers[queries_at[offset]] = Some(outcome)
  }
  for offset, outcome in self.send_batch(posts, get=false) {
    answers[posts_at[offset]] = Some(outcome)
  }
  let out : Array[Outcome] = []
  for answer in answers {
    match answer {
      Some(outcome) => out.push(outcome)
      None =>
        raise CallFailed(
          failure_of("BAD_REQUEST", "a call in the batch was never answered"),
        )
    }
  }
  out
}

///|
/// One group of calls, sent as one request and read back in the order it was given.
async fn Client::send_batch(
  self : Client,
  calls : Array[Call],
  get~ : Bool,
) -> Array[Outcome] raise CallFailed {
  if calls.length() == 0 {
    return []
  }
  let request = batch_request_of(calls, get~)
  let (status, body) = (self.send)(request) catch {
    error =>
      raise CallFailed(failure_of("INTERNAL_SERVER_ERROR", error.to_string()))
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
