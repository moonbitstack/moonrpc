// The two message-size caps: what the server refuses to receive, and what it refuses to
// send. Both end the call rather than let one message cost more than the limit allows.

///|
test "limits: a request past the receive cap ends its call with RESOURCE_EXHAUSTED" {
  let engine = H2Server::new()
  engine.set_max_message_size(recv=64, send=@wire.max_message_size)
  let mut reached = false
  engine.register("/echo.Echo/Say", req => {
    reached = true
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
  let out = engine.feed(
    Data(
      stream_id=1,
      data=@wire.encode_message(b"x".repeat(200)),
      end_stream=true,
      padding=0,
    ),
  )
  assert_eq(reached, false)
  let dec = @hpack.Decoder::new()
  let mut status = -1
  for f in out {
    match f {
      Headers(fragment~, ..) => {
        let headers = dec.decode(fragment) catch {
          _ => abort("bad header block")
        }
        for h in headers {
          if h.name == b"grpc-status" {
            let mut n = 0
            for b in h.value {
              if b >= b'0' && b <= b'9' {
                n = n * 10 + (b.to_int() - 0x30)
              }
            }
            status = n
          }
        }
      }
      _ => ()
    }
  }
  assert_eq(status, 8)
}

///|
test "limits: a reply past the send cap ends its call with RESOURCE_EXHAUSTED" {
  let engine = H2Server::new()
  engine.set_max_message_size(recv=@wire.max_message_size, send=64)
  engine.register("/echo.Echo/Say", req => req)
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
  // The handler answers with 200 octets for a 64-octet cap.
  let out = engine.feed(
    Data(
      stream_id=1,
      data=@wire.encode_message(b"x".repeat(200)),
      end_stream=true,
      padding=0,
    ),
  )
  let dec = @hpack.Decoder::new()
  let mut status = -1
  let mut body = 0
  for f in out {
    match f {
      Headers(fragment~, ..) => {
        let headers = dec.decode(fragment) catch {
          _ => abort("bad header block")
        }
        for h in headers {
          if h.name == b"grpc-status" {
            let mut n = 0
            for b in h.value {
              if b >= b'0' && b <= b'9' {
                n = n * 10 + (b.to_int() - 0x30)
              }
            }
            status = n
          }
        }
      }
      Data(data~, ..) => body = body + data.length()
      _ => ()
    }
  }
  assert_eq(status, 8)
  // Not a truncated reply: nothing of the oversized message went out.
  assert_eq(body, 0)
}
