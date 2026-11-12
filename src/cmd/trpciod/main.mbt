// A tRPC-for-TypeScript service, and a client that calls one.
//
//     trpciod [port]              serve on 127.0.0.1 (12000)
//     trpciod check [port] [host] call a server with this library
//
// The procedures are the ones `scripts/interop/trpcio_peers` registers on the TypeScript
// side, so the same checks run in both directions: a string in and an object out, two
// numbers added, a mutation that echoes what it was given, and a call that always fails.

///|
fn hello(name : String) -> Json {
  { "greeting": Json::string("hello " + name) }
}

///|
fn field(value : Json, name : String) -> Json? {
  match value {
    Object(members) => members.get(name)
    _ => None
  }
}

///|
fn as_string(value : Json?, fallback~ : String = "") -> String {
  match value {
    Some(String(text)) => text
    _ => fallback
  }
}

///|
fn as_number(value : Json?, fallback~ : Double = 0) -> Double {
  match value {
    Some(Number(number, ..)) => number
    _ => fallback
  }
}

///|
/// The four procedures, registered on whichever server the command is running.
fn service(server : @trpcio.Server) -> Unit {
  server.query("greet.hello", input => {
    Ok(hello(as_string(input, fallback="world")))
  })
  server.query("math.add", input => {
    let a = as_number(field_of(input, "a"))
    let b = as_number(field_of(input, "b"))
    Ok(Json::number(a + b))
  })
  server.mutation("greet.remember", input => {
    Ok({ "ok": Json::boolean(true), "name": Json::string(as_string(field_of(input, "name"))) })
  })
  server.query("greet.fail", _input => {
    Failed(@trpcio.failure_of("FORBIDDEN", "not for you", path="greet.fail"))
  })
}

///|
/// One field of an optional object input.
fn field_of(input : Json?, name : String) -> Json? {
  match input {
    Some(value) => field(value, name)
    None => None
  }
}

///|
/// Call a server and check every answer against what the procedures promise.
async fn check(host : String, port : Int32) -> Unit {
  let client = @net.trpcio_client(host, port, base="/trpc")
  let mut failures = 0

  let greeting = client.query("greet.hello", input=Json::string("moon")) catch {
    _ => {
      println("check: greet.hello did not answer")
      failures = failures + 1
      Json::null()
    }
  }
  let text = as_string(field(greeting, "greeting"))
  if text != "hello moon" {
    println("check: greet.hello answered \"" + text + "\"")
    failures = failures + 1
  }

  let sum = client.query("math.add", input={ "a": Json::number(2), "b": Json::number(40) }) catch {
    _ => {
      println("check: math.add did not answer")
      failures = failures + 1
      Json::null()
    }
  }
  if as_number(Some(sum)) != 42 {
    println("check: math.add did not add up")
    failures = failures + 1
  }

  let remembered = client.mutate("greet.remember", input={ "name": Json::string("moon") }) catch {
    _ => {
      println("check: greet.remember did not answer")
      failures = failures + 1
      Json::null()
    }
  }
  if as_string(field(remembered, "name")) != "moon" {
    println("check: greet.remember did not echo its input")
    failures = failures + 1
  }

  let refused : Result[Json, @trpcio.Failure] = try {
    Ok(client.query("greet.fail"))
  } catch {
    @trpcio.CallFailed(failure) => Err(failure)
  }
  match refused {
    Err(failure) =>
      if failure.name != "FORBIDDEN" || failure.http_status != 403 {
        println(
          "check: greet.fail answered " +
          failure.name +
          " at " +
          failure.http_status.to_string(),
        )
        failures = failures + 1
      }
    Ok(_) => {
      println("check: greet.fail answered instead of failing")
      failures = failures + 1
    }
  }

  // One request, three answers, in the order they were asked for.
  let batch = try {
    Ok(
      client.batch([
        @trpcio.Call::new("greet.hello", input=Json::string("batch")),
        @trpcio.Call::new("math.add", input={
          "a": Json::number(1),
          "b": Json::number(2),
        }),
        @trpcio.Call::new("greet.fail"),
      ]),
    )
  } catch {
    _ => Err("the batch did not answer")
  }
  match batch {
    Ok(outcomes) =>
      match outcomes {
        [Ok(first), Ok(second), Failed(failure)] => {
          if as_string(field(first, "greeting")) != "hello batch" {
            println("check: the batch's first answer was not the greeting")
            failures = failures + 1
          }
          if as_number(Some(second)) != 3 {
            println("check: the batch's second answer was not the sum")
            failures = failures + 1
          }
          if failure.name != "FORBIDDEN" {
            println("check: the batch's third answer was not the failure")
            failures = failures + 1
          }
        }
        _ => {
          println("check: the batch did not answer in the order it was asked")
          failures = failures + 1
        }
      }
    Err(why) => {
      println("check: " + why)
      failures = failures + 1
    }
  }

  if failures == 0 {
    println("trpciod check: ok")
  } else {
    println("trpciod check: " + failures.to_string() + " failed")
  }
}

///|
async fn main {
  let args = @env.args()
  let check_mode = args.length() > 1 && args[1] == "check"
  let port_index = if check_mode { 2 } else { 1 }
  let port = if args.length() > port_index {
    @string.parse_int(args[port_index][:]) catch { _ => 12000 }
  } else {
    12000
  }
  if check_mode {
    let host = if args.length() > port_index + 1 {
      args[port_index + 1]
    } else {
      "127.0.0.1"
    }
    check(host, port)
  } else {
    let server = @trpcio.Server::new()
    service(server)
    println("trpciod listening on 127.0.0.1:\{port}")
    @net.serve_trpcio(port~, server, base="/trpc")
  }
}
