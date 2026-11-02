// Compression through the real engines: what the server picks for its replies from what
// the caller said it accepts, and what both ends do with a body that is compressed.

///|
/// A request header block carrying `grpc-encoding` and `grpc-accept-encoding` — the two
/// headers a compressed call is negotiated with.
fn compressed_block(
  enc : @hpack.Encoder,
  path : Bytes,
  encoding~ : Bytes = b"",
  accept~ : Bytes = b"",
) -> Bytes {
  let extra : Array[@header.Header] = []
  if encoding.length() > 0 {
    extra.push({ name: b"grpc-encoding", value: encoding, })
  }
  if accept.length() > 0 {
    extra.push({ name: b"grpc-accept-encoding", value: accept, })
  }
  req_block(enc, path, extra~)
}

///|
/// What a reply's `grpc-encoding` header says, its framed messages' compression flags, and
/// the reply bodies as they came off the wire.
fn reply_body(out : Array[@http2.Frame]) -> (String, Array[Bool], Bytes) {
  let dec = @hpack.Decoder::new()
  let mut encoding = ""
  let flags : Array[Bool] = []
  let mut body = b""
  for f in out {
    match f {
      Headers(fragment~, ..) => {
        let headers = dec.decode(fragment) catch { _ => abort("bad block") }
        for h in headers {
          if h.name == b"grpc-encoding" {
            encoding = @utf8.decode_lossy(h.value[:])
          }
        }
      }
      Data(data~, ..) => body = body + data
      _ => ()
    }
  }
  // The flag lives on each framed message, at the head of the body it shares.
  let mut at = 0
  while @wire.message_len(body[:], at~) is Some(len) {
    flags.push(body[at].to_int() != 0)
    at = at + 5 + len
  }
  (encoding, flags, body)
}

///|
test "compression: a reply is gzipped when the caller said it accepts gzip" {
  let engine = H2Server::new()
  engine.set_encoding(Gzip)
  let message = b"\x00".repeat(512)
  engine.register("/echo.Echo/Say", _req => message)
  let enc = @hpack.Encoder::new()
  let block = compressed_block(
    enc,
    b"/echo.Echo/Say",
    accept=b"identity,gzip,deflate",
  )
  let _ = engine.feed(Settings(params=[], ack=false))
  let _ = engine.feed(
    Headers(
      stream_id=1,
      fragment=block,
      end_stream=false,
      end_headers=true,
      priority=None,
      padding=0,
    ),
  )
  let out = engine.feed(
    Data(
      stream_id=1,
      data=@wire.encode_message(b"go"),
      end_stream=true,
      padding=0,
    ),
  )
  let (encoding, flags, body) = reply_body(out)
  assert_eq(encoding, "gzip")
  assert_eq(flags, [true])
  let (_, payload) = @wire.decode_message(body).unwrap()
  assert_eq(@wire.Encoding::Gzip.decode(payload[:]).unwrap(), message)
  // The compressed reply is far smaller than the body it carries.
  assert_true(payload.length() < message.length() / 8)
}

///|
test "compression: a caller that accepts nothing but identity gets identity" {
  let engine = H2Server::new()
  engine.set_encoding(Gzip)
  engine.register("/echo.Echo/Say", _req => b"\x00".repeat(512))
  let enc = @hpack.Encoder::new()
  // No grpc-accept-encoding at all: the old default is identity, and gRPC says a server
  // must not compress at it.
  let block = req_block(enc, b"/echo.Echo/Say")
  let _ = engine.feed(Settings(params=[], ack=false))
  let _ = engine.feed(
    Headers(
      stream_id=1,
      fragment=block,
      end_stream=false,
      end_headers=true,
      priority=None,
      padding=0,
    ),
  )
  let out = engine.feed(
    Data(
      stream_id=1,
      data=@wire.encode_message(b"go"),
      end_stream=true,
      padding=0,
    ),
  )
  let (encoding, flags, body) = reply_body(out)
  assert_eq(encoding, "identity")
  assert_eq(flags, [false])
  let (_, payload) = @wire.decode_message(body).unwrap()
  assert_eq(payload.length(), 512)
}

///|
test "compression: a deflating server answers in deflate to a caller that accepts it" {
  let engine = H2Server::new()
  engine.set_encoding(Deflate)
  engine.register("/echo.Echo/Say", _req => b"\x00".repeat(512))
  let enc = @hpack.Encoder::new()
  let block = compressed_block(
    enc,
    b"/echo.Echo/Say",
    accept=b"identity,deflate",
  )
  let _ = engine.feed(Settings(params=[], ack=false))
  let _ = engine.feed(
    Headers(
      stream_id=1,
      fragment=block,
      end_stream=false,
      end_headers=true,
      priority=None,
      padding=0,
    ),
  )
  let out = engine.feed(
    Data(
      stream_id=1,
      data=@wire.encode_message(b"go"),
      end_stream=true,
      padding=0,
    ),
  )
  let (encoding, flags, body) = reply_body(out)
  assert_eq(encoding, "deflate")
  assert_eq(flags, [true])
  let (_, payload) = @wire.decode_message(body).unwrap()
  assert_eq(
    @wire.Encoding::Deflate.decode(payload[:]).unwrap(),
    b"\x00".repeat(512),
  )
}

///|
test "compression: a gzipped request reaches the handler as the message it was" {
  let engine = H2Server::new()
  let seen : Array[Bytes] = []
  engine.register("/echo.Echo/Say", req => {
    seen.push(req)
    req
  })
  let enc = @hpack.Encoder::new()
  let block = compressed_block(enc, b"/echo.Echo/Say", encoding=b"gzip")
  let _ = engine.feed(Settings(params=[], ack=false))
  let _ = engine.feed(
    Headers(
      stream_id=1,
      fragment=block,
      end_stream=false,
      end_headers=true,
      priority=None,
      padding=0,
    ),
  )
  let body = @wire.Encoding::Gzip.encode(b"plain as day"[:])
  let out = engine.feed(
    Data(
      stream_id=1,
      data=@wire.encode_message(body, compressed=true),
      end_stream=true,
      padding=0,
    ),
  )
  assert_eq(seen, [b"plain as day"])
  let (_, _flags, reply) = reply_body(out)
  let (_, payload) = @wire.decode_message(reply).unwrap()
  assert_eq(payload, b"plain as day")
}

///|
test "compression: a deflated request reaches the handler as the message it was" {
  let engine = H2Server::new()
  let seen : Array[Bytes] = []
  engine.register("/echo.Echo/Say", req => {
    seen.push(req)
    req
  })
  let enc = @hpack.Encoder::new()
  let block = compressed_block(enc, b"/echo.Echo/Say", encoding=b"deflate")
  let _ = engine.feed(Settings(params=[], ack=false))
  let _ = engine.feed(
    Headers(
      stream_id=1,
      fragment=block,
      end_stream=false,
      end_headers=true,
      priority=None,
      padding=0,
    ),
  )
  let body = @wire.Encoding::Deflate.encode(b"plain as day"[:])
  let _ = engine.feed(
    Data(
      stream_id=1,
      data=@wire.encode_message(body, compressed=true),
      end_stream=true,
      padding=0,
    ),
  )
  assert_eq(seen, [b"plain as day"])
}

///|
test "compression: a compressed message with no encoding named is refused" {
  let engine = H2Server::new()
  let mut called = false
  engine.register("/echo.Echo/Say", req => {
    called = true
    req
  })
  let enc = @hpack.Encoder::new()
  let block = req_block(enc, b"/echo.Echo/Say")
  let _ = engine.feed(Settings(params=[], ack=false))
  let _ = engine.feed(
    Headers(
      stream_id=1,
      fragment=block,
      end_stream=false,
      end_headers=true,
      priority=None,
      padding=0,
    ),
  )
  let body = @wire.Encoding::Gzip.encode(b"ciphertext"[:])
  let out = engine.feed(
    Data(
      stream_id=1,
      data=@wire.encode_message(body, compressed=true),
      end_stream=true,
      padding=0,
    ),
  )
  assert_eq(called, false)
  let dec = @hpack.Decoder::new()
  let mut status = -1
  for f in out {
    match f {
      Headers(fragment~, ..) => {
        let headers = dec.decode(fragment) catch { _ => abort("bad block") }
        for h in headers {
          if h.name == b"grpc-status" {
            status = 12
          }
        }
      }
      _ => ()
    }
  }
  assert_eq(status, 12)
}
