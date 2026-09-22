// The standard `grpc.health.v1.Health` service (Check + Watch). The two messages
// are small enough to hand-code against the protobuf wire format (a `string`
// field and an `enum` field) without pulling in a full message runtime: a health
// probe is `HealthCheckRequest { string service = 1 }` and the reply is
// `HealthCheckResponse { ServingStatus status = 1 }`.

///|
/// The `grpc.health.v1.HealthCheckResponse.ServingStatus` enum.
pub(all) enum ServingStatus {
  StatusUnknown
  Serving
  NotServing
  ServiceUnknown
} derive(Eq)

///|
/// The wire value of a serving status (the protobuf enum number).
pub fn ServingStatus::code(self : ServingStatus) -> Int {
  match self {
    StatusUnknown => 0
    Serving => 1
    NotServing => 2
    ServiceUnknown => 3
  }
}

///|
/// The serving status for a protobuf enum number; out-of-range numbers read as
/// `StatusUnknown`.
pub fn ServingStatus::from_code(n : Int) -> ServingStatus {
  match n {
    1 => Serving
    2 => NotServing
    3 => ServiceUnknown
    _ => StatusUnknown
  }
}

// -- minimal protobuf wire helpers ------------------------------------------

///|
/// Encode a `HealthCheckRequest`: field 1 (`service`, a length-delimited string).
/// An empty service name encodes to the empty message, the wire form of the
/// overall-server check.
pub fn encode_health_request(service : Bytes) -> Bytes {
  let buf = Buffer()
  if service.length() > 0 {
    buf.write_byte(b'\x0a') // field 1, wire type 2 (length-delimited)
    @leb128.write(buf, service.length().to_uint64())
    buf.write_bytes(service)
  }
  buf.to_bytes()
}

///|
/// Decode the `service` field of a `HealthCheckRequest`, or empty bytes when the
/// field is absent (the overall-server check). Unknown fields are skipped.
pub fn decode_health_request(msg : Bytes) -> Bytes {
  let r = PbReader::new(msg)
  let mut service = b""
  // The bounded PbReader raises on any malformed/over-long field; a bad request then
  // reads as the empty (overall-server) check rather than aborting the process.
  try {
    while !r.eof() {
      let (field, wire) = r.read_tag()
      if field == 1 && wire is LengthDelim {
        service = r.read_bytes()
      } else {
        r.skip(wire)
      }
    }
  } catch {
    _ => ()
  }
  service
}

///|
/// Encode a `HealthCheckResponse`: field 1 (`status`, a varint enum). The `SERVING`
/// default `0` still encodes to the empty message per protobuf default-omission.
pub fn encode_health_response(status : ServingStatus) -> Bytes {
  let buf = Buffer()
  if status.code() != 0 {
    buf.write_byte(b'\x08') // field 1, wire type 0 (varint)
    @leb128.write(buf, status.code().to_uint64())
  }
  buf.to_bytes()
}

///|
/// Decode the `status` field of a `HealthCheckResponse`; an absent field reads as
/// the `0` default (`StatusUnknown`).
pub fn decode_health_response(msg : Bytes) -> ServingStatus {
  let r = PbReader::new(msg)
  let mut status = 0
  try {
    while !r.eof() {
      let (field, wire) = r.read_tag()
      if field == 1 && wire is Varint {
        status = r.read_int32()
      } else {
        r.skip(wire)
      }
    }
  } catch {
    _ => ()
  }
  ServingStatus::from_code(status)
}

// -- the service ------------------------------------------------------------

///|
/// The gRPC HTTP/2 path of the `Check` method.
pub let health_check_path : String = "/grpc.health.v1.Health/Check"

///|
/// The gRPC HTTP/2 path of the `Watch` method.
pub let health_watch_path : String = "/grpc.health.v1.Health/Watch"

///|
/// A `grpc.health.v1.Health` service backed by a per-service status table. The
/// empty key `""` is the overall-server status; a fresh service reports the whole
/// server `SERVING`.
pub struct HealthService {
  statuses : Map[String, ServingStatus]
}

///|
/// A health service reporting the overall server as `SERVING`.
pub fn HealthService::new() -> HealthService {
  { statuses: Map([("", Serving)]), }
}

///|
/// Set the serving status of a named service (or the overall server with `""`).
pub fn HealthService::set_status(
  self : HealthService,
  service : String,
  status : ServingStatus,
) -> Unit {
  self.statuses[service] = status
}

///|
/// The serving status of a named service: its set status, or `ServiceUnknown` when
/// the service was never registered.
pub fn HealthService::check(
  self : HealthService,
  service : String,
) -> ServingStatus {
  match self.statuses.get(service) {
    Some(s) => s
    None => ServiceUnknown
  }
}

///|
/// The `(path, handler)` pairs implementing the service: `Check` as a unary method
/// and `Watch` as a server-streaming method that emits the current status. A live
/// `Watch` that also pushes on every later change needs a streaming source the
/// pure engine's eager `ServerStreaming` shape does not model, so this emits the
/// status at subscribe time — the first message a real `Watch` always sends.
pub fn HealthService::handlers(
  self : HealthService,
) -> Array[(String, Handler)] {
  let check : Handler = Unary((_ctx, req) => {
    let service = bytes_to_ascii(decode_health_request(req))
    encode_health_response(self.check(service))
  })
  let watch : Handler = ServerStreaming((_ctx, req) => {
    let service = bytes_to_ascii(decode_health_request(req))
    [encode_health_response(self.check(service))]
  })
  [(health_check_path, check), (health_watch_path, watch)]
}

///|
/// Register `Check` and `Watch` on a pure server engine.
pub fn HealthService::install(self : HealthService, server : H2Server) -> Unit {
  for entry in self.handlers() {
    server.register_handler(entry.0, entry.1)
  }
}

///|
pub extend ServingStatus with Eq::{not_equal, equal}
