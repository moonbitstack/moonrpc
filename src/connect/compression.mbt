// The compression algorithms the Connect protocol names. The IANA names are the wire names:
// `identity`, `gzip`, `br` (Brotli), `zstd`, `deflate` (RFC 1950 zlib, not raw DEFLATE — the
// name is a historical misnomer that gRPC and Connect both inherited) and `snappy` in its
// framed stream format. All six come from moonzip; this file is the one place that decides
// which bytes a name means, so a caller never has to.

///|
/// The names this library reads and writes, in the order it advertises them.
pub let compression_names : Array[String] = [
  "identity", "gzip", "br", "zstd", "deflate", "snappy",
]

///|
/// Whether `name` is an encoding this library can decode. `identity` counts: a body that is
/// not compressed is still an answer to the question.
pub fn known_compression(name : String) -> Bool {
  for one in compression_names {
    if one == name {
      return true
    }
  }
  false
}

///|
/// Compress a unary body or one envelope's payload. An unknown or `identity` name leaves the
/// bytes alone; a caller that advertises a name it cannot write would be lying to the peer.
pub fn encode_compression(name : String, body : Bytes) -> Bytes {
  match name {
    "gzip" => @gzip.gzip(body[:])
    "br" => @brotli.brotli(body[:])
    "zstd" => @zstd.zstd(body[:])
    "deflate" => @zlib.zlib(body[:])
    "snappy" => @snappy.frame(body[:])
    _ => body
  }
}

///|
/// Undo `encode_compression`, or `None` when the name is unknown or the bytes will not
/// inflate. A malformed compressed message is a protocol failure, not a message to hand on.
pub fn decode_compression(name : String, body : Bytes) -> Bytes? {
  if name == "identity" || body.length() == 0 {
    // Go's snappy framed writer emits zero octets for an empty message, and every other
    // encoder's empty body is empty plain text too. There is nothing to inflate.
    return Some(body)
  }
  let result : Result[Bytes, Unit] = Ok(
    match name {
      "zstd" => @zstd.unzstd(body[:])
      "gzip" => @gzip.gunzip(body[:])
      "br" => @brotli.unbrotli(body[:])
      "deflate" => @zlib.unzlib(body[:])
      "snappy" => @snappy.unframe(body[:])
      _ => return None
    },
  ) catch {
    _ => Err(())
  }
  match result {
    Ok(bytes) => Some(bytes)
    Err(_) => None
  }
}

///|
/// The name a `content-encoding` or `connect-content-encoding` header carries, with an
/// absent header meaning no compression was applied.
pub fn compression_of(header : String?) -> String {
  match header {
    Some(name) => name
    None => "identity"
  }
}
