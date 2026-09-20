// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "a -bin key travels base64 encoded and comes back whole" {
  let raw = b"\x00\x01\x02\xff\xfe"
  let wire = @moonrpc.metadata_value_to_wire(b"x-bin", raw)
  assert_eq(wire, b"AAEC//4=")
  assert_eq(@moonrpc.metadata_value_from_wire(b"x-bin", wire), raw)
}

///|
test "an ordinary key travels verbatim" {
  assert_eq(@moonrpc.metadata_value_to_wire(b"x-id", b"abc"), b"abc")
  assert_eq(@moonrpc.metadata_value_from_wire(b"x-id", b"abc"), b"abc")
}

///|
test "a peer that leaves the padding off is still understood" {
  assert_eq(
    @moonrpc.metadata_value_from_wire(b"x-bin", b"AAEC//4"),
    b"\x00\x01\x02\xff\xfe",
  )
}

///|
test "only a -bin suffix means binary" {
  assert_true(@moonrpc.is_binary_metadata(b"trace-bin"))
  assert_false(@moonrpc.is_binary_metadata(b"trace-bi"))
  assert_false(@moonrpc.is_binary_metadata(b"bin"))
  assert_false(@moonrpc.is_binary_metadata(b"x-binary"))
}
