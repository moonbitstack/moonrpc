// The three encodings gRPC names, and the `grpc-accept-encoding` list they are chosen
// from: a name has to round-trip, a body has to survive its own encoding, and a choice
// has to fall back to identity rather than send something the far end cannot read.

///|
test "compression: each encoding names itself and is found by that name" {
  assert_eq(Encoding::Identity.code(), "identity")
  assert_eq(Encoding::Gzip.code(), "gzip")
  assert_eq(Encoding::Deflate.code(), "deflate")
  for encoding in [Identity, Gzip, Deflate] {
    assert_eq(Encoding::of(@utf8.encode(encoding.code())[:]), Some(encoding))
  }
  // A call that names no encoding is not compressed.
  assert_eq(Encoding::of(b""[:]), Some(Identity))
  assert_eq(Encoding::of(b"snappy"[:]), None)
  assert_eq(Encoding::of(b"GZIP"[:]), None)
}

///|
test "compression: a body survives each encoding" {
  let body = b"the quick brown fox jumps over the lazy dog, twice over so gzip has work"
  for encoding in [Identity, Gzip, Deflate] {
    let encoded = encoding.encode(body[:])
    let back = encoding.decode(encoded[:]).unwrap()
    assert_eq(back, body)
  }
  // Compression has to actually compress: gzip and deflate both shrink a repetitive body
  // well past their own headers.
  let long = @utf8.encode(
    "the quick brown fox jumps over the lazy dog. ".repeat(16),
  )
  assert_true(Encoding::Gzip.encode(long[:]).length() < long.length() / 4)
  assert_true(Encoding::Deflate.encode(long[:]).length() < long.length() / 4)
  assert_true(Encoding::Identity.encode(long[:]).length() == long.length())
}

///|
test "compression: the compression flag is what says a body is compressed" {
  let body = b"payload"
  let framed = encode_message(Encoding::Gzip.encode(body[:]), compressed=true)
  // One-octet flag, four-octet length, then the gzip member.
  assert_eq(framed[0].to_int(), 1)
  let (compressed, payload) = decode_message(framed).unwrap()
  assert_eq(compressed, true)
  assert_eq(Encoding::Gzip.decode(payload[:]).unwrap(), body)
}

///|
test "compression: a break in the encoded body decodes to nothing, not to garbage" {
  let body = b"a body long enough that gzip emits a member with a header and a trailer"
  let broken = Encoding::Gzip.encode(body[:])
  let flipped = broken.to_array()
  flipped[flipped.length() - 3] = (flipped[flipped.length() - 3].to_int() ^ 0xFF).to_byte()
  assert_eq(Encoding::Gzip.decode(Bytes::from_array(flipped)[:]), None)
  // Bytes that were never deflate at all.
  assert_eq(Encoding::Deflate.decode(b"not deflate"[:]), None)
}

///|
test "compression: decompression stops at the limit it was given" {
  // 4 KiB of zeros compresses to a few dozen octets and expands well past a 64-octet cap.
  let bomb = Encoding::Gzip.encode(b"\x00".repeat(4096)[:])
  assert_eq(Encoding::Gzip.decode(bomb[:], limit=64), None)
  assert_true(
    Encoding::Gzip.decode(bomb[:], limit=8192).unwrap().length() == 4096,
  )
}

///|
test "compression: an accept list is read the way a header is" {
  assert_eq(Encoding::Gzip.accepted(b"identity,gzip"[:]), true)
  assert_eq(Encoding::Deflate.accepted(b"identity,gzip,deflate"[:]), true)
  // Spaces around an item, and another case, are the same encoding.
  assert_eq(Encoding::Gzip.accepted(b" identity , GZIP "[:]), true)
  assert_eq(Encoding::Deflate.accepted(b"identity,gzip"[:]), false)
  assert_eq(Encoding::Gzip.accepted(b""[:]), false)
  // A name that merely starts with one of ours is a different name.
  assert_eq(Encoding::Gzip.accepted(b"gzipx"[:]), false)
  assert_eq(Encoding::Identity.accepted(b"identity"[:]), true)
}

///|
test "compression: identity is always what is left when nothing else was accepted" {
  assert_eq(negotiated(Gzip, b"identity,gzip"[:]), Gzip)
  assert_eq(negotiated(Deflate, b"identity,gzip,deflate"[:]), Deflate)
  // The far end did not list it: never send a body it would have to guess at.
  assert_eq(negotiated(Gzip, b"identity"[:]), Identity)
  assert_eq(negotiated(Gzip, b""[:]), Identity)
  // Nothing to negotiate when the server wants no compression.
  assert_eq(negotiated(Identity, b"identity,gzip"[:]), Identity)
}

///|
test "compression: the advertised list names every encoding we decode" {
  for encoding in [Identity, Gzip, Deflate] {
    assert_eq(encoding.accepted(@utf8.encode(accept_encodings)[:]), true)
  }
}
