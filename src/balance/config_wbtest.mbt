// A service config document parsed into the per-method settings a channel applies.

///|
fn sample_config() -> String {
  "{\"loadBalancingPolicy\":\"round_robin\",\"methodConfig\":[" +
  "{\"name\":[{\"service\":\"greet.Greeter\",\"method\":\"SayHello\"}]," +
  "\"waitForReady\":true,\"timeout\":\"1.5s\"," +
  "\"retryPolicy\":{\"maxAttempts\":4,\"initialBackoff\":\"0.1s\"," +
  "\"maxBackoff\":\"1s\",\"backoffMultiplier\":2," +
  "\"retryableStatusCodes\":[\"UNAVAILABLE\"]}}," +
  "{\"name\":[{\"service\":\"greet.Greeter\"}],\"timeout\":\"2s\"}]}"
}

///|
test "config: a grpc-go shaped document parses into per-method settings" {
  let config = ServiceConfig::parse(sample_config()) catch {
    _ => abort("a valid config must parse")
  }
  assert_true(config.load_balancing == Some(RoundRobin))
  let mc = match config.for_method("/greet.Greeter/SayHello") {
    Some(m) => m
    None => abort("the SayHello entry must match")
  }
  assert_true(mc.wait_for_ready == Some(true))
  assert_eq(mc.timeout_millis(), Some(1500))
  let retry = match mc.retry {
    Some(r) => r
    None => abort("the entry carries a retry policy")
  }
  assert_eq(retry.backoff.attempts, 4)
  assert_eq(retry.backoff.base.nanos, 100_000_000L)
  assert_eq(retry.backoff.cap.nanos, 1_000_000_000L)
  assert_eq(retry.codes, [Unavailable])
}

///|
test "config: a service-only entry matches any method on that service" {
  let config = ServiceConfig::parse(sample_config()) catch {
    _ => abort("a valid config must parse")
  }
  let mc = match config.for_method("/greet.Greeter/CountTo") {
    Some(m) => m
    None => abort("the service-wide entry must match CountTo")
  }
  assert_eq(mc.timeout_millis(), Some(2000))
  // The method-specific entry did not match, so it carries no retry of its own.
  assert_true(mc.retry is None)
}

///|
test "config: a path no entry names has no method config" {
  let config = ServiceConfig::parse(sample_config()) catch {
    _ => abort("a valid config must parse")
  }
  assert_true(config.for_method("/other.Service/M") is None)
}

///|
test "config: malformed JSON raises rather than yielding a half-read config" {
  let raised = try {
    ignore(ServiceConfig::parse("{not json"))
    false
  } catch {
    _ => true
  }
  assert_true(raised)
}

///|
test "config: maxAttempts comes from the document, not from the preset" {
  // The sample's four is also the preset's, so a field that was never read would
  // still answer four there.
  let config = ServiceConfig::parse(
    "{\"methodConfig\":[{\"name\":[{\"service\":\"s\"}]," +
    "\"retryPolicy\":{\"maxAttempts\":2,\"initialBackoff\":\"0.1s\"," +
    "\"maxBackoff\":\"1s\",\"backoffMultiplier\":2," +
    "\"retryableStatusCodes\":[\"UNAVAILABLE\"]}}]}",
  ) catch {
    _ => abort("a valid config must parse")
  }
  let retry = match config.for_method("/s/m") {
    Some({ retry: Some(r), .. }) => r
    _ => abort("the entry carries a retry policy")
  }
  assert_eq(retry.backoff.attempts, 2)
}
