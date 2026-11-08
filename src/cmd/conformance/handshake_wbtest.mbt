// The framing the suite's handshake uses: a four-octet big-endian length, then the message.

///|
test "handshake: the length is four octets, big-endian" {
  let framed = delimited(b"abc")
  assert_eq(framed.length(), 7)
  assert_eq(framed[0], b'\x00')
  assert_eq(framed[1], b'\x00')
  assert_eq(framed[2], b'\x00')
  assert_eq(framed[3], b'\x03')
  assert_eq(framed[4:7], b"abc")
}

///|
test "handshake: a length past one octet carries in the high octet" {
  let message = Bytes::make(300, b'x')
  let framed = delimited(message)
  // 300 is 0x0000_012C.
  assert_eq(framed[0], b'\x00')
  assert_eq(framed[1], b'\x00')
  assert_eq(framed[2], b'\x01')
  assert_eq(framed[3], b'\x2c')
  assert_eq(framed.length(), 304)
}

///|
test "handshake: the response names the host and the port" {
  let body = @proto.PbWriter::new()
  body.string_(1, "127.0.0.1")
  body.uint32(2, 12345U)
  let message = body.to_bytes()
  // field 1, a 9-octet string, then field 2, a varint.
  assert_eq(message[0], b'\x0a')
  assert_eq(message[1], b'\x09')
  assert_eq(message[11], b'\x10')
  let framed = delimited(message)
  assert_eq(framed[3], message.length().to_byte())
}
