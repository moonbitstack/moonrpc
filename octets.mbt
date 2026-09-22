// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// An ASCII string as octets.
///
/// HTTP/2 field names and values are byte sequences and gRPC's `-bin` metadata is
/// binary, so everything crossing the wire here is `Bytes`; what this converts is the
/// ASCII a path, an authority or a status message is written as in the first place.
fn octets(s : String) -> Bytes {
  let buf = Buffer()
  for i = 0; i < s.length(); i = i + 1 {
    buf.write_byte((s[i].to_int() & 0xff).to_byte())
  }
  buf.to_bytes()
}
