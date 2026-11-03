// The other half of gRPC's rich errors: reading `grpc-status-details-bin` back into the
// `google.rpc.Status` the server packed — its code, its message, and the `Any` details a
// client can decode into whatever message they carry.

///|
/// A `google.rpc.Status` as it arrives in the `grpc-status-details-bin` trailer: the status
/// code, the message, and the serialized `google.protobuf.Any` details in order.
#derive(Eq, Debug)
pub(all) struct StatusDetails {
  code : Int32
  message : String
  details : Array[Bytes]
}

///|
pub extend StatusDetails with Eq::{not_equal, equal}

///|
pub extend StatusDetails with Debug::{to_repr}

///|
/// Decode a `google.rpc.Status` (`code` = 1, `message` = 2, repeated `details` = 3). `None`
/// when the bytes are not one: a trailer that will not decode is worse than no trailer, but
/// it is not something to fail a call over, since the status itself already came in the
/// `grpc-status` header.
pub fn decode_status_details(body : BytesView) -> StatusDetails? {
  let r = PbReader::new(body.to_owned())
  let mut code = 0
  let mut message = ""
  let details : Array[Bytes] = []
  let parsed = try {
    while !r.eof() {
      match r.read_tag() {
        (1, Varint) => code = r.read_int32()
        (2, LengthDelim) => message = r.read_string()
        (3, LengthDelim) => details.push(r.read_bytes())
        (_, w) => r.skip(w)
      }
    }
    true
  } catch {
    _ => false
  }
  if parsed {
    Some({ code, message, details, })
  } else {
    None
  }
}

///|
/// The type URL of a `google.protobuf.Any` detail: field 1 of the `Any`, the message name
/// such as `type.googleapis.com/greet.Badge`, or `None` when the bytes are not an `Any`.
pub fn detail_type_url(detail : BytesView) -> String? {
  let r = PbReader::new(detail.to_owned())
  let found = try {
    while !r.eof() {
      match r.read_tag() {
        (1, LengthDelim) => return Some(r.read_string())
        (_, w) => r.skip(w)
      }
    }
    None
  } catch {
    _ => None
  }
  found
}

///|
/// The body of a `google.protobuf.Any` detail (field 2): the message the type URL names,
/// ready for that message's own `decode`.
pub fn detail_body(detail : BytesView) -> Bytes? {
  let r = PbReader::new(detail.to_owned())
  let found = try {
    while !r.eof() {
      match r.read_tag() {
        (2, LengthDelim) => return Some(r.read_bytes())
        (_, w) => r.skip(w)
      }
    }
    None
  } catch {
    _ => None
  }
  found
}
