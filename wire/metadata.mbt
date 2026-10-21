// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// True when a metadata key carries binary, which gRPC spells by suffixing the
/// key with `-bin`.
pub fn is_binary_metadata(name : Bytes) -> Bool {
  let n = name.length()
  n >= 4 &&
  name[n - 4] == b'-' &&
  name[n - 3] == b'b' &&
  name[n - 2] == b'i' &&
  name[n - 1] == b'n'
}

///|
/// Decode a metadata value coming off the wire: base64 for a `-bin` key,
/// verbatim otherwise.
///
/// Padding is optional on the wire, and a peer may pad or not; anything outside
/// the alphabet is skipped rather than rejected, which is what the gRPC spec
/// asks a receiver to tolerate.
pub fn metadata_value_from_wire(name : Bytes, value : Bytes) -> Bytes {
  if is_binary_metadata(name) {
    @base64.decode_lossy(@moonbase.text_of(value[:]))
  } else {
    value
  }
}

///|
/// Encode a metadata value for the wire: base64 for a `-bin` key, verbatim
/// otherwise.
pub fn metadata_value_to_wire(name : Bytes, value : Bytes) -> Bytes {
  if is_binary_metadata(name) {
    @base64.encode_bytes(value[:])
  } else {
    value
  }
}
