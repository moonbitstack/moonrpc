// The client's half of compression: what it puts on the wire for its own requests, and
// what it does with a reply that is compressed under an encoding it did or did not ask for.

///|
/// The request headers a client engine put on the wire, decoded.
fn request_headers(frames : Array[@http2.Frame]) -> Array[@header.Header] {
  let dec = @hpack.Decoder::new()
  for f in frames {
    if f is Headers(fragment~, ..) {
      return dec.decode(fragment) catch { _ => abort("bad header block") }
    }
  }
  abort("no request HEADERS")
}

///|
/// The first DATA frame's body, which is the length-prefixed request message.
fn request_body(frames : Array[@http2.Frame]) -> Bytes {
  for f in frames {
    if f is Data(data~, ..) {
      return data
    }
  }
  abort("no request DATA")
}

///|
test "compression: a gzip client names the encoding and compresses what it sends" {
  let client = H2Client::new()
  client.set_encoding(Gzip)
  let (id, frames) = client.unary("/echo.Echo/Say", b"\x00".repeat(512))
  ignore(id)
  let headers = request_headers(frames)
  let mut named = b""
  let mut accepts = b""
  for h in headers {
    if h.name == b"grpc-encoding" {
      named = h.value
    }
    if h.name == b"grpc-accept-encoding" {
      accepts = h.value
    }
  }
  assert_eq(named, b"gzip")
  // The client says what it will read back, which is every encoding it can decode.
  assert_eq(accepts, @utf8.encode(@wire.accept_encodings))
  let framed = request_body(frames)
  assert_eq(framed[0].to_int(), 1)
  let (compressed, payload) = @wire.decode_message(framed).unwrap()
  assert_eq(compressed, true)
  assert_eq(
    @wire.Encoding::Gzip.decode(payload[:]).unwrap(),
    b"\x00".repeat(512),
  )
}

///|
test "compression: a deflate client compresses its request with deflate" {
  let client = H2Client::new()
  client.set_encoding(Deflate)
  let (_id, frames) = client.unary("/echo.Echo/Say", b"\x00".repeat(512))
  let mut named = b""
  for h in request_headers(frames) {
    if h.name == b"grpc-encoding" {
      named = h.value
    }
  }
  assert_eq(named, b"deflate")
  let framed = request_body(frames)
  assert_eq(framed[0].to_int(), 1)
  let (_, payload) = @wire.decode_message(framed).unwrap()
  assert_eq(
    @wire.Encoding::Deflate.decode(payload[:]).unwrap(),
    b"\x00".repeat(512),
  )
}

///|
test "compression: an identity client sends the body as it is and names no encoding" {
  let client = H2Client::new()
  let (_id, frames) = client.unary("/echo.Echo/Say", b"plain")
  let mut named = false
  for h in request_headers(frames) {
    if h.name == b"grpc-encoding" {
      named = true
    }
  }
  assert_eq(named, false)
  let framed = request_body(frames)
  assert_eq(framed[0].to_int(), 0)
  let (compressed, payload) = @wire.decode_message(framed).unwrap()
  assert_eq(compressed, false)
  assert_eq(payload, b"plain")
}

///|
test "compression: a compressed reply the client did not ask for fails INTERNAL" {
  let client = H2Client::new()
  let (id, _frames) = client.unary("/echo.Echo/Say", b"x")
  let _ = client.feed(Settings(params=[], ack=false))
  let enc = @hpack.Encoder::new()
  let block = enc.encode([
    { name: b":status", value: b"200", },
    { name: b"content-type", value: b"application/grpc", },
    { name: b"grpc-encoding", value: b"snappy", },
  ])
  let _ = client.feed(
    Headers(
      stream_id=id,
      fragment=block,
      end_stream=false,
      end_headers=true,
      priority=None,
      padding=0,
    ),
  )
  let _ = client.feed(
    Data(
      stream_id=id,
      data=@wire.encode_message(b"\x01\x02\x03", compressed=true),
      end_stream=false,
      padding=0,
    ),
  )
  let trailers = enc.encode([{ name: b"grpc-status", value: b"0", }])
  let _ = client.feed(
    Headers(
      stream_id=id,
      fragment=trailers,
      end_stream=true,
      end_headers=true,
      priority=None,
      padding=0,
    ),
  )
  let reply = client.reply(id)
  assert_eq(reply.grpc_status, 13)
  assert_eq(reply.messages.length(), 0)
}
