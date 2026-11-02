///|
test "status details: a packed google.rpc.Status decodes to its parts" {
  let any = b"\x0a\x03abc\x12\x02hi"
  let w = PbWriter::new()
  w.int32(1, 5)
  w.string_(2, "gone")
  w.message_(3, any)
  let details = decode_status_details(w.to_bytes()[:]).unwrap()
  assert_eq(details.code, 5)
  assert_eq(details.message, "gone")
  assert_eq(details.details, [any])
  assert_eq(detail_type_url(any[:]).unwrap(), "abc")
  assert_eq(detail_body(any[:]).unwrap(), b"hi")
}
