// A service config filling in a call's retry, deadline and wait-for-ready.

///|
fn config_document() -> String {
  "{\"methodConfig\":[{\"name\":[{\"service\":\"greet.Greeter\"," +
  "\"method\":\"SayHello\"}],\"waitForReady\":true,\"timeout\":\"1.5s\"," +
  "\"retryPolicy\":{\"maxAttempts\":4,\"initialBackoff\":\"0.1s\"," +
  "\"maxBackoff\":\"1s\",\"backoffMultiplier\":2," +
  "\"retryableStatusCodes\":[\"UNAVAILABLE\"]}}]}"
}

///|
fn invocation_for(path : String) -> Invocation {
  {
    path,
    requests: [b"x"],
    metadata: [],
    timeout_millis: None,
    retry: None,
    wait_for_ready: false,
  }
}

///|
test "config: an unset invocation takes the method's retry, deadline and wait" {
  let config = @balance.ServiceConfig::parse(config_document()) catch {
    _ => abort("a valid config must parse")
  }
  let out = resolve(invocation_for("/greet.Greeter/SayHello"), Some(config))
  assert_eq(out.timeout_millis, Some(1500))
  assert_true(out.wait_for_ready)
  assert_true(out.retry is Some(_))
}

///|
test "config: a caller's explicit deadline is not overridden" {
  let config = @balance.ServiceConfig::parse(config_document()) catch {
    _ => abort("a valid config must parse")
  }
  let base = invocation_for("/greet.Greeter/SayHello")
  let out = resolve({ ..base, timeout_millis: Some(99), }, Some(config))
  assert_eq(out.timeout_millis, Some(99))
}

///|
test "config: a method the config does not name keeps the caller's invocation" {
  let config = @balance.ServiceConfig::parse(config_document()) catch {
    _ => abort("a valid config must parse")
  }
  let out = resolve(invocation_for("/other.Service/M"), Some(config))
  assert_eq(out.timeout_millis, None)
  assert_false(out.wait_for_ready)
  assert_true(out.retry is None)
}

///|
test "config: no config leaves the invocation unchanged" {
  let out = resolve(invocation_for("/greet.Greeter/SayHello"), None)
  assert_eq(out.timeout_millis, None)
  assert_false(out.wait_for_ready)
}
