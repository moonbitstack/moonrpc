// The envelope, against the shapes tRPC's own server writes and reads.

///|
test "trpcio: a single call carries its input bare, and a query puts it in the query" {
  let call = Call::new("greet.hello", input=Json::string("moon"))
  let post = request_of(call)
  assert_eq(post.target, "greet.hello")
  assert_eq(post.body, "\"moon\"")
  assert_eq(post.batch, false)
  let get = request_of(call, get=true)
  assert_eq(get.target, "greet.hello?input=%22moon%22")
  assert_eq(get.body, "")
  assert_eq(get.get, true)
}

///|
test "trpcio: a call with no input sends no body" {
  let call = Call::new("greet.now")
  assert_eq(single_body(call), "")
  let request = request_of(call, get=true)
  // Nothing to carry, so nothing to ask for: the target stays the path alone.
  assert_eq(request.target, "greet.now")
}

///|
test "trpcio: a batch keys its inputs by position and names its paths in order" {
  let calls = [
    Call::new("a.one", input=Json::number(1)),
    Call::new("b.two"),
    Call::new("c.three", input=Json::object({ "x": Json::string("y") })),
  ]
  assert_eq(batch_body(calls), "{\"0\":1,\"2\":{\"x\":\"y\"}}")
  let request = batch_request_of(calls)
  assert_eq(request.target, "a.one,b.two,c.three?batch=1")
  assert_eq(request.batch, true)
}

///|
test "trpcio: a reply is a result or an error, alone or in an array" {
  let one = decode_reply("{\"result\":{\"data\":{\"greeting\":\"hi\"}}}", batch=false)
  match one {
    Some([Ok(value)]) =>
      match value {
        Object(members) =>
          match members.get("greeting") {
            Some(String(text)) => assert_eq(text, "hi")
            _ => abort("the value did not survive")
          }
        _ => abort("the value was not an object")
      }
    _ => abort("a successful reply did not decode")
  }
  let failed = decode_reply(
    "{\"error\":{\"message\":\"no such thing\",\"code\":-32004,\"data\":{\"code\":\"NOT_FOUND\",\"httpStatus\":404,\"path\":\"x.y\"}}}",
    batch=false,
  )
  match failed {
    Some([Failed(failure)]) => {
      assert_eq(failure.name, "NOT_FOUND")
      assert_eq(failure.http_status, 404)
      assert_eq(failure.message, "no such thing")
      assert_eq(failure.path, "x.y")
    }
    _ => abort("a failure did not decode")
  }
  let many = decode_reply(
    "[{\"result\":{\"data\":1}},{\"error\":{\"message\":\"no\",\"code\":-32603,\"data\":{\"code\":\"INTERNAL_SERVER_ERROR\",\"httpStatus\":500}}}]",
    batch=true,
  )
  match many {
    Some([Ok(_), Failed(failure)]) =>
      assert_eq(failure.name, "INTERNAL_SERVER_ERROR")
    _ => abort("a batch reply did not decode")
  }
}

///|
test "trpcio: percent-encoding leaves what encodeURIComponent leaves" {
  let text = "{\"a\":\"b c/d?e=f&g\"}"
  let encoded = percent_encode(text)
  assert_eq(encoded, "%7B%22a%22%3A%22b%20c%2Fd%3Fe%3Df%26g%22%7D")
  assert_eq(percent_decode(encoded), text)
  // `+` is a space in a query string, as a form-encoded parameter reads it.
  assert_eq(percent_decode("a+b"), "a b")
}

///|
/// A transport that answers from a table and records what it was asked, so a test sees the
/// request the protocol produced.
fn answering(status : Int, body : String) -> (Send, Ref[String]) {
  let seen = Ref("")
  let send : Send = async fn(request) {
    seen.val = request.target + " " + request.body
    (status, body)
  }

  (send, seen)
}

///|
async test "trpcio: the client asks for a query and reads its value" {
  let (send, seen) = answering(200, "{\"result\":{\"data\":\"hello\"}}")
  let client = Client::new(send)
  let value = client.query("greet.hello", input=Json::string("moon")) catch {
    e => abort("the call failed")
  }
  assert_eq(@moonjson.dumps(value), "\"hello\"")
  assert_eq(seen.val, "greet.hello \"moon\"")
}

///|
async test "trpcio: the client raises the failure the server named" {
  let (send, _seen) = answering(
    404,
    "{\"error\":{\"message\":\"No procedure found on path \\\"x.y\\\"\",\"code\":-32004,\"data\":{\"code\":\"NOT_FOUND\",\"httpStatus\":404,\"path\":\"x.y\"}}}",
  )
  let client = Client::new(send)
  let outcome : Result[Json, Failure] = try {
    Ok(client.query("x.y"))
  } catch {
    CallFailed(failure) => Err(failure)
  }
  match outcome {
    Err(failure) => {
      assert_eq(failure.name, "NOT_FOUND")
      assert_eq(failure.http_status, 404)
    }
    Ok(_) => abort("a failure was reported as a value")
  }
}

///|
async test "trpcio: a batch answers every call in the order it was asked" {
  let (send, seen) = answering(
    200,
    "[{\"result\":{\"data\":1}},{\"error\":{\"message\":\"no\",\"code\":-32603,\"data\":{\"code\":\"INTERNAL_SERVER_ERROR\",\"httpStatus\":500}}}]",
  )
  let client = Client::new(send)
  let outcomes : Array[Outcome] = try {
    client.batch([Call::new("a.one"), Call::new("b.two")])
  } catch {
    e => abort("the batch failed")
  }
  assert_eq(outcomes.length(), 2)
  assert_eq(seen.val, "a.one,b.two?batch=1 {}")
  match outcomes {
    [Ok(_), Failed(failure)] => assert_eq(failure.name, "INTERNAL_SERVER_ERROR")
    _ => abort("the batch answers were out of order")
  }
}

///|
/// A server with one call of each kind, so the request handling is exercised end to end.
fn sample_server() -> Server {
  let server = Server::new()
  server.query("greet.hello", input => {
    let who = match input {
      Some(String(name)) => name
      _ => "world"
    }
    Ok({ "greeting": Json::string("hello " + who) })
  })
  server.mutation("greet.remember", _input => Ok(Json::boolean(true)))
  server.query("greet.fail", _input => {
    Failed(failure_of("FORBIDDEN", "not for you", path="greet.fail"))
  })
  server
}

///|
test "trpcio: a server answers a GET query, a POST mutation, and what it does not know" {
  let server = sample_server()
  let hello = server.handle("GET", "greet.hello?input=%22moon%22", "")
  assert_eq(hello.status, 200)
  assert_eq(
    hello.body,
    "{\"result\":{\"data\":{\"greeting\":\"hello moon\"}}}",
  )

  let mutation = server.handle("POST", "greet.remember", "{\"name\":\"moon\"}")
  assert_eq(mutation.status, 200)
  assert_eq(mutation.body, "{\"result\":{\"data\":true}}")

  let unknown = server.handle("GET", "greet.nope", "")
  assert_eq(unknown.status, 404)
  assert_eq(
    unknown.body,
    "{\"error\":{\"message\":\"No procedure found on path \\\"greet.nope\\\"\",\"code\":-32004,\"data\":{\"code\":\"NOT_FOUND\",\"httpStatus\":404,\"path\":\"greet.nope\",\"stack\":null,\"cause\":null}}}",
  )

  // A mutation is not something a link may repeat.
  let wrong_verb = server.handle("GET", "greet.remember", "")
  assert_eq(wrong_verb.status, 405)

  let refused = server.handle("GET", "greet.fail", "")
  assert_eq(refused.status, 403)

  let broken = server.handle("POST", "greet.hello", "{not json")
  assert_eq(broken.status, 400)
}

///|
test "trpcio: a server answers a batch, failures included, in the caller's order" {
  let server = sample_server()
  let answer = server.handle(
    "POST",
    "greet.hello,greet.fail?batch=1",
    "{\"0\":\"moon\"}",
  )
  // The first failure decides the status, as tRPC's own `initResponse` does.
  assert_eq(answer.status, 403)
  assert_eq(
    answer.body,
    "[{\"result\":{\"data\":{\"greeting\":\"hello moon\"}}},{\"error\":{\"message\":\"not for you\",\"code\":-32003,\"data\":{\"code\":\"FORBIDDEN\",\"httpStatus\":403,\"path\":\"greet.fail\",\"stack\":null,\"cause\":null}}}]",
  )
}

///|
async test "trpcio: the client and the server agree without a socket" {
  let server = sample_server()
  let send : Send = async fn(request) {
    let method = if request.get { "GET" } else { "POST" }
    let answer = server.handle(method, request.target, request.body)
    (answer.status, answer.body)
  }
  let client = Client::new(send)
  let value = try client.query("greet.hello", input=Json::string("moon")) catch {
    e => abort("the call failed")
  }
  assert_eq(@moonjson.dumps(value), "{\"greeting\":\"hello moon\"}")
}
