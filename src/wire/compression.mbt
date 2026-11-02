// Message compression: the `grpc-encoding` a call's messages are compressed with, and
// `grpc-accept-encoding`, the list a peer says it will decode. gRPC names three:
// `identity` (none), `gzip` (RFC 1952) and `deflate` — which gRPC means as the raw
// DEFLATE stream of RFC 1951, without zlib's two-octet header, not as the zlib format.

///|
/// The `grpc-accept-encoding` value this library advertises, best first: the encodings a
/// peer may send us.
pub let accept_encodings : String = "identity,gzip,deflate"

///|
/// A message compression the gRPC protocol names.
pub(all) enum Encoding {
  Identity
  Gzip
  Deflate
} derive(Eq, Debug)

///|
pub extend Encoding with Eq::{not_equal, equal}

///|
pub extend Encoding with Debug::{to_repr}

///|
/// The `grpc-encoding` name of this encoding.
pub fn Encoding::code(self : Encoding) -> String {
  match self {
    Identity => "identity"
    Gzip => "gzip"
    Deflate => "deflate"
  }
}

///|
/// The encoding a `grpc-encoding` value names, or `None` for one we do not decode. An
/// empty value is `identity`, since a call that names no encoding is not compressed.
pub fn Encoding::of(name : BytesView) -> Encoding? {
  if name.length() == 0 {
    return Some(Identity)
  }
  if name == b"identity" {
    Some(Identity)
  } else if name == b"gzip" {
    Some(Gzip)
  } else if name == b"deflate" {
    Some(Deflate)
  } else {
    None
  }
}

///|
/// Compress `body` with this encoding. `identity` is the body itself.
pub fn Encoding::encode(self : Encoding, body : BytesView) -> Bytes {
  match self {
    Identity => body.to_owned()
    Gzip => @gzip.gzip(body)
    Deflate => @deflate.deflate(body)
  }
}

///|
/// Decompress `body` with this encoding, or `None` when it does not decode as one — a
/// corrupt member, or one that expands past `limit`, which bounds what a compressed
/// message can cost us (gRPC's own decompression limit).
pub fn Encoding::decode(
  self : Encoding,
  body : BytesView,
  limit~ : Int32 = max_message_size,
) -> Bytes? {
  if body.length() > limit {
    return None
  }
  match self {
    Identity => Some(body.to_owned())
    Gzip => Some(@gzip.gunzip(body, limit~)) catch { _ => None }
    Deflate => Some(@deflate.inflate(body, limit~)) catch { _ => None }
  }
}

///|
/// Whether a `grpc-accept-encoding` value — a comma-separated list, case-insensitive, with
/// optional spaces — names this encoding.
pub fn Encoding::accepted(self : Encoding, accept : BytesView) -> Bool {
  let want = @utf8.encode(self.code())
  let mut at = 0
  while at < accept.length() {
    let mut end = at
    while end < accept.length() && accept[end] != b',' {
      end = end + 1
    }
    let mut from = at
    let mut to = end
    while from < to && (accept[from] == b' ' || accept[from] == b'\t') {
      from = from + 1
    }
    while to > from && (accept[to - 1] == b' ' || accept[to - 1] == b'\t') {
      to = to - 1
    }
    if to - from == want.length() {
      let mut same = true
      for i = 0; i < want.length(); i = i + 1 {
        if lower(accept[from + i]) != want[i] {
          same = false
        }
      }
      if same {
        return true
      }
    }
    at = end + 1
  }
  false
}

///|
/// Lower-case one ASCII octet, leaving everything else alone: a header value is
/// case-insensitive ASCII, and a byte above 0x7F is not part of an encoding name.
fn lower(b : Byte) -> Byte {
  if b >= b'A' && b <= b'Z' {
    (b.to_int() + 32).to_byte()
  } else {
    b
  }
}

///|
/// What to compress a reply with, given what the server wants and what the caller said it
/// accepts: the server's encoding when the caller listed it, `identity` otherwise — never
/// a body the far end would have to guess at.
pub fn negotiated(server : Encoding, accept : BytesView) -> Encoding {
  match server {
    Identity => Identity
    encoding => if encoding.accepted(accept) { encoding } else { Identity }
  }
}
