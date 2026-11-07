// Connect's error model: a status code written as a lower_snake_case word, the HTTP status a
// unary reply carries it as, and the JSON body that goes with it. The codes are gRPC's sixteen,
// spelled the way this protocol spells them, so a call that fails here fails the same way it
// would over gRPC.

///|
/// The protocol's word for a status: `invalid_argument`, `deadline_exceeded`, and so on. The
/// pair with [`status_of_code`] is total, which is what lets a peer's error body be read back
/// into a status this library already speaks.
pub fn code_of_status(status : @wire.Status) -> String {
  match status {
    Ok => "ok"
    Cancelled => "canceled"
    Unknown => "unknown"
    InvalidArgument => "invalid_argument"
    DeadlineExceeded => "deadline_exceeded"
    NotFound => "not_found"
    AlreadyExists => "already_exists"
    PermissionDenied => "permission_denied"
    ResourceExhausted => "resource_exhausted"
    FailedPrecondition => "failed_precondition"
    Aborted => "aborted"
    OutOfRange => "out_of_range"
    Unimplemented => "unimplemented"
    Internal => "internal"
    Unavailable => "unavailable"
    DataLoss => "data_loss"
    Unauthenticated => "unauthenticated"
  }
}

///|
/// The status a Connect code names. A word this library does not know is `unknown`, which is
/// what a peer that speaks a later version of the protocol should be read as.
pub fn status_of_code(code : String) -> @wire.Status {
  match code {
    // `ok` never appears in an error body — a call that ended cleanly has no error at all —
    // but the pair is total, so the word maps back to the status it came from.
    "ok" => Ok
    "canceled" => Cancelled
    "invalid_argument" => InvalidArgument
    "deadline_exceeded" => DeadlineExceeded
    "not_found" => NotFound
    "already_exists" => AlreadyExists
    "permission_denied" => PermissionDenied
    "resource_exhausted" => ResourceExhausted
    "failed_precondition" => FailedPrecondition
    "aborted" => Aborted
    "out_of_range" => OutOfRange
    "unimplemented" => Unimplemented
    "internal" => Internal
    "unavailable" => Unavailable
    "data_loss" => DataLoss
    "unauthenticated" => Unauthenticated
    _ => Unknown
  }
}

///|
/// The HTTP status a unary call's failure travels as. A streaming call answers 200 and reports
/// the failure in its final envelope instead, so this is the unary half of the mapping.
pub fn http_status_of(status : @wire.Status) -> Int32 {
  match status {
    Ok => 200
    // The client hung up before the answer was ready; the code exists for logs and proxies.
    Cancelled => 499
    Unknown => 500
    InvalidArgument => 400
    DeadlineExceeded => 504
    NotFound => 404
    AlreadyExists => 409
    PermissionDenied => 403
    ResourceExhausted => 429
    FailedPrecondition => 400
    Aborted => 409
    OutOfRange => 400
    Unimplemented => 501
    Internal => 500
    Unavailable => 503
    DataLoss => 500
    Unauthenticated => 401
  }
}

///|
/// The body a failed unary call answers with: `code`, `message`, and whatever `details` the
/// service gave, each an already-serialized message beside its type.
pub fn error_json(
  status : @wire.Status,
  message : String,
  details~ : Array[(String, Json)] = [],
) -> Json {
  let members : Map[String, Json] = Map([])
  members["code"] = Json::string(code_of_status(status))
  if message.length() > 0 {
    members["message"] = Json::string(message)
  }
  if details.length() > 0 {
    let items = []
    for detail in details {
      let one : Map[String, Json] = Map([])
      one["type"] = Json::string(detail.0)
      one["value"] = detail.1
      items.push(Json::object(one))
    }
    members["details"] = Json::array(items)
  }
  Json::object(members)
}

///|
/// The status and message a peer's error body carries. A body this build cannot read is
/// `unknown` with the text it was given, since the alternative — pretending the call succeeded
/// — is worse.
pub fn error_of_json(value : Json) -> (@wire.Status, String) {
  match value {
    Object(members) => {
      let status = match members.get("code") {
        Some(String(code)) => status_of_code(code)
        _ => Unknown
      }
      let message = match members.get("message") {
        Some(String(text)) => text
        _ => ""
      }
      (status, message)
    }
    _ => (Unknown, "")
  }
}
