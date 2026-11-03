// A gRPC service config: the JSON document a name resolver (or a caller) can hand a
// channel to set per-method retry, hedging, timeout and wait-for-ready, plus the
// channel-wide load-balancing policy and retry throttling.
// https://github.com/grpc/grpc/blob/master/doc/service_config.md

///|
/// One method's configuration. `service` and `name` are the two halves of a method
/// name; either may be left out to match every method of that service or of every
/// service.
pub(all) struct MethodConfig {
  service : String?
  name : String?
  retry : Retry?
  hedging : Hedging?
  timeout : @moondate.Span?
  wait_for_ready : Bool?
}

///|
/// A parsed service config: the per-method entries in the order they were written
/// (first match wins), the channel-wide load-balancing policy and retry throttling.
pub(all) struct ServiceConfig {
  methods : Array[MethodConfig]
  load_balancing : LbPolicy?
  throttling : Throttling?
}

///|
/// An empty config: no method overrides, no policy.
pub fn ServiceConfig::empty() -> ServiceConfig {
  { methods: [], load_balancing: None, throttling: None, }
}

///|
/// Parse a service config document, as grpc-go's `encoding/json` does.
pub fn ServiceConfig::parse(
  text : String,
) -> ServiceConfig raise @json.ParseError {
  ServiceConfig::of_json(@json.parse(text))
}

///|
/// The entry that governs `path` (`/pkg.Service/Method`), the first whose service and
/// method both match (an omitted half matches anything).
pub fn ServiceConfig::for_method(
  self : ServiceConfig,
  path : String,
) -> MethodConfig? {
  let (service, name) = match split_path(path) {
    Some(parts) => parts
    None => return None
  }
  for m in self.methods {
    let service_ok = match m.service {
      Some(s) => s == service
      None => true
    }
    let name_ok = match m.name {
      Some(n) => n == name
      None => true
    }
    if service_ok && name_ok {
      return Some(m)
    }
  }
  None
}

///|
/// The timeout in whole milliseconds, for the `attempting` loop.
pub fn MethodConfig::timeout_millis(self : MethodConfig) -> Int32? {
  self.timeout.map(span => (span.nanos / 1_000_000L).to_int())
}

///|
/// Split `/pkg.Service/Method` into its service and method halves.
fn split_path(path : String) -> (String, String)? {
  let mut first = -1
  let mut second = -1
  let mut i = 0
  for ch in path {
    if ch == '/' {
      if first < 0 {
        first = i
      } else if second < 0 {
        second = i
      }
    }
    i = i + 1
  }
  if first < 0 || second < 0 {
    return None
  }
  let service = path.exact_view(start=first + 1, end=second).to_owned()
  let name = path.exact_view(start=second + 1).to_owned()
  Some((service, name))
}

///|
fn ServiceConfig::of_json(json : @json.Json) -> ServiceConfig {
  let obj = match object_of(json) {
    Some(o) => o
    None => return ServiceConfig::empty()
  }
  let methods : Array[MethodConfig] = []
  match array_field(obj, "methodConfig") {
    Some(arr) =>
      for j in arr {
        match method_of_json(j) {
          Some(m) => methods.push(m)
          None => ()
        }
      }
    None => ()
  }
  {
    methods,
    load_balancing: match string_field(obj, "loadBalancingPolicy") {
      Some(s) => lb_policy(s)
      None => None
    },
    throttling: match obj.get("retryThrottling") {
      Some(tj) => throttling_of_json(tj)
      None => None
    },
  }
}

///|
fn method_of_json(json : @json.Json) -> MethodConfig? {
  let obj = match object_of(json) {
    Some(o) => o
    None => return None
  }
  let mut service : String? = None
  let mut name : String? = None
  match array_field(obj, "name") {
    Some(names) =>
      match names {
        [first, ..] =>
          match object_of(first) {
            Some(no) => {
              service = string_field(no, "service")
              name = string_field(no, "method")
            }
            None => ()
          }
        [] => ()
      }
    None => ()
  }
  Some({
    service,
    name,
    retry: match obj.get("retryPolicy") {
      Some(r) => retry_of_json(r)
      None => None
    },
    hedging: match obj.get("hedgingPolicy") {
      Some(h) => hedging_of_json(h)
      None => None
    },
    timeout: match string_field(obj, "timeout") {
      Some(s) => parse_span(s)
      None => None
    },
    wait_for_ready: bool_field(obj, "waitForReady"),
  })
}

///|
fn retry_of_json(json : @json.Json) -> Retry? {
  let obj = match object_of(json) {
    Some(o) => o
    None => return None
  }
  Some(
    Retry::new(
      attempts=match number_field(obj, "maxAttempts") {
        Some(d) => d.to_int()
        None => retry.backoff.attempts
      },
      base=match string_field(obj, "initialBackoff") {
        Some(s) => parse_span(s).unwrap_or(retry.backoff.base)
        None => retry.backoff.base
      },
      cap=match string_field(obj, "maxBackoff") {
        Some(s) => parse_span(s).unwrap_or(retry.backoff.cap)
        None => retry.backoff.cap
      },
      factor=match number_field(obj, "backoffMultiplier") {
        Some(d) => d
        None => retry.backoff.factor
      },
      codes=match array_field(obj, "retryableStatusCodes") {
        Some(a) => statuses(a)
        None => retry.codes
      },
    ),
  )
}

///|
fn hedging_of_json(json : @json.Json) -> Hedging? {
  let obj = match object_of(json) {
    Some(o) => o
    None => return None
  }
  Some(
    Hedging::new(
      attempts=match number_field(obj, "maxAttempts") {
        Some(d) => d.to_int()
        None => hedging.attempts
      },
      delay=match string_field(obj, "hedgingDelay") {
        Some(s) => parse_span(s).unwrap_or(hedging.delay)
        None => hedging.delay
      },
      codes=match array_field(obj, "nonFatalStatusCodes") {
        Some(a) => statuses(a)
        None => hedging.codes
      },
    ),
  )
}

///|
fn throttling_of_json(json : @json.Json) -> Throttling? {
  let obj = match object_of(json) {
    Some(o) => o
    None => return None
  }
  let tokens = match number_field(obj, "maxTokens") {
    Some(d) => d.to_int()
    None => return None
  }
  let ratio = match number_field(obj, "tokenRatio") {
    Some(d) => d
    None => return None
  }
  Some(Throttling::new(tokens~, ratio~))
}

///|
fn string_field(obj : Map[String, @json.Json], key : String) -> String? {
  match obj.get(key) {
    Some(j) => string_of(j)
    None => None
  }
}

///|
fn bool_field(obj : Map[String, @json.Json], key : String) -> Bool? {
  match obj.get(key) {
    Some(j) => bool_of(j)
    None => None
  }
}

///|
fn number_field(obj : Map[String, @json.Json], key : String) -> Double? {
  match obj.get(key) {
    Some(j) => number_of(j)
    None => None
  }
}

///|
fn array_field(
  obj : Map[String, @json.Json],
  key : String,
) -> Array[@json.Json]? {
  match obj.get(key) {
    Some(j) => array_of(j)
    None => None
  }
}

///|
fn statuses(arr : Array[@json.Json]) -> Array[@wire.Status] {
  let out : Array[@wire.Status] = []
  for j in arr {
    match string_of(j) {
      Some(s) =>
        match @wire.Status::from_name(s) {
          Some(st) => out.push(st)
          None => ()
        }
      None => ()
    }
  }
  out
}

///|
fn lb_policy(name : String) -> LbPolicy? {
  if name == "round_robin" {
    Some(RoundRobin)
  } else if name == "pick_first" {
    Some(PickFirst)
  } else {
    None
  }
}

///|
/// A gRPC duration: decimal seconds with an `s` suffix (`"1.5s"`, `"0.1s"`).
fn parse_span(text : String) -> @moondate.Span? {
  let n = text.length()
  if n < 2 {
    return None
  }
  if text.exact_view(start=n - 1, end=n).to_owned() != "s" {
    return None
  }
  let mut whole : Int64 = 0
  let mut frac : Int64 = 0
  let mut digits = 0
  let mut dot = false
  for ch in text.exact_view(end=n - 1) {
    if ch == '.' {
      if dot {
        return None
      }
      dot = true
      continue
    }
    let d = ch.to_int() - '0'.to_int()
    if d < 0 || d > 9 {
      return None
    }
    if dot {
      if digits < 9 {
        frac = frac * 10L + d.to_int64()
        digits = digits + 1
      }
    } else {
      whole = whole * 10L + d.to_int64()
    }
  }
  let mut scale = 1L
  for i = digits; i < 9; i = i + 1 {
    scale = scale * 10L
  }
  Some({ nanos: whole * 1_000_000_000L + frac * scale, })
}

///|
fn object_of(json : @json.Json) -> Map[String, @json.Json]? {
  if json is Object(m) {
    Some(m)
  } else {
    None
  }
}

///|
fn string_of(json : @json.Json) -> String? {
  if json is String(s) {
    Some(s)
  } else {
    None
  }
}

///|
fn bool_of(json : @json.Json) -> Bool? {
  if json is True {
    Some(true)
  } else if json is False {
    Some(false)
  } else {
    None
  }
}

///|
fn number_of(json : @json.Json) -> Double? {
  if json is Number(n, ..) {
    Some(n)
  } else {
    None
  }
}

///|
fn array_of(json : @json.Json) -> Array[@json.Json]? {
  if json is Array(a) {
    Some(a)
  } else {
    None
  }
}
