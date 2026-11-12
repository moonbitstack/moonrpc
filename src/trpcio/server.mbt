// The server side of trpc.io's protocol: a table of procedures, and the one function that
// turns an HTTP request into an HTTP answer.
//
// tRPC's own server is a router of nested objects with builders; what reaches the wire is
// only a path and an input, so that is what a procedure is here. Anything a TypeScript
// router can do — middleware, input validation, context — happens in the handler, before it
// returns an `Outcome`.

///|
/// What a procedure answers: a value, or the failure the caller will read.
pub type Handler = (Json?) -> Outcome

///|
/// The two kinds of call tRPC distinguishes. The difference is only in the HTTP method:
/// a query may be asked for with GET, a mutation may not.
pub(all) enum Kind {
  Query
  Mutation
}

///|
/// One procedure: how it may be called, and what answers it.
pub(all) struct Procedure {
  kind : Kind
  handler : Handler
}

///|
/// A table of procedures, keyed by the path a call names (`greet.hello`).
pub struct Server {
  procedures : Map[String, Procedure]
  // The largest batch this server answers. tRPC's default is unbounded; a server that
  // remembers every answer of a batch has a reason to bound it.
  max_batch : Int32
}

///|
pub fn Server::new(max_batch~ : Int32 = 32) -> Server {
  { procedures: Map([]), max_batch, }
}

///|
pub fn Server::query(self : Server, path : String, handler : Handler) -> Unit {
  self.procedures[path] = { kind: Query, handler, }
}

///|
pub fn Server::mutation(
  self : Server,
  path : String,
  handler : Handler,
) -> Unit {
  self.procedures[path] = { kind: Mutation, handler, }
}

///|
/// One answer to one request: the status, and the body to send with it.
pub(all) struct Answer {
  status : Int32
  body : String
  // The content type the body is in. A failure answers in JSON like a success does.
  content_type : String
}

///|
fn json_answer(status : Int32, body : String) -> Answer {
  { status, body, content_type: "application/json", }
}

///|
/// The failure answer: the same error shape a successful call's failure would carry, at the
/// status that shape names.
fn failure_answer(failure : Failure, batch~ : Bool) -> Answer {
  json_answer(failure.http_status, encode_reply([Failed(failure)], batch~))
}

///|
/// The value of one query parameter, or `None`.
fn parameter(query : String, name : String) -> String? {
  for part in query.split("&") {
    match part.split_once("=") {
      Some((key, value)) =>
        if key == name {
          return Some(percent_decode(value.to_owned()))
        }
      None => if part == name { return Some("") }
    }
  }
  None
}

///|
/// Split a request target into its path and its query string.
fn split_target(target : String) -> (String, String) {
  match target.split_once("?") {
    Some((path, query)) => (path.to_owned(), query.to_owned())
    None => (target, "")
  }
}

///|
/// Answer one HTTP request. `verb` is the method it arrived with, `target` the request target
/// as it arrived (path and query), and `body` the request body — empty for a GET, whose input
/// travels in the query string.
pub fn Server::handle(
  self : Server,
  verb : String,
  target : String,
  body : String,
) -> Answer {
  let (path, query) = split_target(target)
  let batch = match parameter(query, "batch") {
    Some(_) => true
    None => false
  }
  if batch && body.length() == 0 && parameter(query, "input") is None {
    // A batch with nothing in it: an empty array is the honest answer, and is what tRPC
    // answers for `{"0":{}}`-less bodies too.
    return json_answer(200, "[]")
  }
  let paths = decode_paths(path)
  if paths.length() == 0 {
    return failure_answer(
      failure_of("NOT_FOUND", "no procedure was named"),
      batch~,
    )
  }
  if batch && paths.length() > self.max_batch {
    return failure_answer(
      failure_of(
        "PAYLOAD_TOO_LARGE", "the batch is larger than this server accepts",
      ),
      batch~,
    )
  }
  let raw = if verb == "GET" {
    match parameter(query, "input") {
      Some(text) => text
      None => ""
    }
  } else {
    body
  }
  let inputs = match decode_inputs(raw, batch~) {
    Some(values) => values
    None =>
      return failure_answer(
        failure_of("PARSE_ERROR", "the request body is not JSON"),
        batch~,
      )
  }
  let outcomes : Array[Outcome] = []
  for index, name in paths {
    let input = if index < inputs.length() { inputs[index] } else { None }
    outcomes.push(self.call(verb, name, input))
  }
  let status = status_of(outcomes)
  json_answer(status, encode_reply(outcomes, batch~))
}

///|
/// One procedure's answer, or the failure that stands in for it.
fn Server::call(
  self : Server,
  verb : String,
  path : String,
  input : Json?,
) -> Outcome {
  let procedure = match self.procedures.get(path) {
    Some(found) => found
    None => {
      // tRPC answers a path it does not know at 404, with the shape of any other failure.
      let failure = failure_of(
        "NOT_FOUND",
        "No procedure found on path \"" + path + "\"",
        path~,
      )
      return Failed(failure)
    }
  }
  if verb == "GET" && procedure.kind is Mutation {
    // A mutation is not something to repeat by following a link: tRPC's HTTP handler
    // refuses a GET for one, and so does this.
    let failure = failure_of(
      "METHOD_NOT_SUPPORTED",
      "Mutations cannot be called with GET",
      path~,
    )
    return Failed(failure)
  }
  if verb != "GET" && verb != "POST" {
    let failure = failure_of(
      "METHOD_NOT_SUPPORTED",
      "Only GET and POST are answers this protocol speaks",
      path~,
    )
    return Failed(failure)
  }
  (procedure.handler)(input)
}

///|
/// The status a batch of answers is carried under: the first failure's, or 200 when every
/// call succeeded. tRPC's own `initResponse` looks at the first error it finds.
fn status_of(outcomes : Array[Outcome]) -> Int32 {
  for outcome in outcomes {
    match outcome {
      Failed(failure) => return failure.http_status
      Ok(_) => ()
    }
  }
  200
}
