///|
/// The gRPC rule written out byte by byte, as it was before the encoding moved to
/// moonhttp: a byte in `%x20-%x7E` other than `%` stays, anything else becomes `%XX`
/// in uppercase (PROTOCOL-HTTP2.md, "Responses").
///
/// Kept here as the oracle the shorter implementation is checked against, so the
/// move is proved rather than assumed.
fn grpc_rule(msg : String) -> Bytes {
  let src = @utf8.encode(msg)
  let digits = "0123456789ABCDEF"
  let buf = Buffer()
  for i = 0; i < src.length(); i = i + 1 {
    let c = src[i].to_int()
    if c >= 0x20 && c <= 0x7E && c != 0x25 {
      buf.write_byte(src[i])
    } else {
      buf.write_byte(b'%')
      buf.write_byte(digits[(c >> 4) & 0xf].to_int().to_byte())
      buf.write_byte(digits[c & 0xf].to_int().to_byte())
    }
  }
  buf.to_bytes()
}

///|
test "grpc-message encodes every ASCII byte exactly as the gRPC rule does" {
  // Each printable and control character on its own, so a single wrong entry in the
  // safe set shows up as the character it is.
  for c = 0; c < 0x80; c = c + 1 {
    let one = c.unsafe_to_char().to_string()
    assert_eq(percent_encode(one), grpc_rule(one))
  }
}

///|
test "grpc-message encodes multi-byte text as its UTF-8 octets" {
  for
    s in [
      "héllo", "日本語", "emoji 🎉", "100% done", "a%b", "tab\there", "",
    ] {
    assert_eq(percent_encode(s), grpc_rule(s))
  }
  // The two cases the rule exists for: a percent sign and a non-ASCII byte.
  assert_eq(percent_encode("100%"), b"100%25")
  assert_eq(percent_encode("é"), b"%C3%A9")
  // And what it leaves alone, punctuation and space included.
  assert_eq(percent_encode("not found: /a b?c"), b"not found: /a b?c")
}
