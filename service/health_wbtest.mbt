// The health service and its protobuf message codec, exercised over the two pure
// engines: encode/decode round-trips for every serving status plus an end-to-end
// Check call driven client-to-server in memory.

///|
test "health: HealthCheckRequest service round-trips through the protobuf codec" {
  assert_eq(
    decode_health_request(encode_health_request(b"pkg.Svc")) == b"pkg.Svc",
    true,
  )
  // the overall-server check is the empty message.
  assert_eq(encode_health_request(b"").length(), 0)
  assert_eq(decode_health_request(b"") == b"", true)
}

///|
test "health: every ServingStatus round-trips through the response codec" {
  let all = [StatusUnknown, Serving, NotServing, ServiceUnknown]
  for s in all {
    let back = decode_health_response(encode_health_response(s))
    assert_eq(back == s, true)
    assert_eq(back.code(), s.code())
  }
  // the SERVING/0 default omits the field yet still decodes back to StatusUnknown=0.
  assert_eq(encode_health_response(StatusUnknown).length(), 0)
}

///|
test "health: check reports set status, the overall server, and unknown services" {
  let health = HealthService::new()
  health.set_status("pkg.A", Serving)
  health.set_status("pkg.B", NotServing)
  assert_eq(health.check("pkg.A") == Serving, true)
  assert_eq(health.check("pkg.B") == NotServing, true)
  // fresh service registers the whole server as serving.
  assert_eq(health.check("") == Serving, true)
  // never-registered services read as SERVICE_UNKNOWN.
  assert_eq(health.check("pkg.Missing") == ServiceUnknown, true)
}

///|
test "health: a request declaring more bytes than present decodes safely, not a crash" {
  // field 1, length-delimited, declared length 200, but only one body byte follows.
  // The hand-rolled decoder used to slice out of bounds and abort; it now yields the
  // empty (overall-server) service without crashing.
  assert_eq(decode_health_request(b"\x0a\xc8\x01\x41") == b"", true)
  // a truncated varint tag likewise decodes to empty rather than reading past the end.
  assert_eq(decode_health_request(b"\xff") == b"", true)
}
