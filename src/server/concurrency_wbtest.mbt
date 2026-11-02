// Concurrent dispatch inside the engine, with no socket: a finished call is queued rather
// than run, and what the driver pushes back becomes frames.

///|
/// Feed a unary call's request and return the frames the engine answered with.
fn feed_unary(
  engine : H2Server,
  path : Bytes,
  request : Bytes,
) -> Array[@http2.Frame] {
  let enc = @hpack.Encoder::new()
  let block = req_block(enc, path)
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
  engine.feed(
    Data(
      stream_id=1,
      data=@wire.encode_message(request),
      end_stream=true,
      padding=0,
    ),
  )
}

///|
/// The `grpc-status` a run of frames ends with, and the reply bodies it carried.
fn status_and_replies(out : Array[@http2.Frame]) -> (Int32, Array[Bytes]) {
  let dec = @hpack.Decoder::new()
  let mut status : Int32 = -1
  let mut body = b""
  for f in out {
    match f {
      Headers(fragment~, ..) => {
        let headers = dec.decode(fragment) catch {
          _ => abort("bad header block")
        }
        for h in headers {
          if h.name == b"grpc-status" {
            let mut n = 0
            let mut digits = false
            for b in h.value {
              if b >= b'0' && b <= b'9' {
                n = n * 10 + (b.to_int() - 0x30)
                digits = true
              }
            }
            if digits {
              status = n
            }
          }
        }
      }
      Data(data~, ..) => body = body + data
      _ => ()
    }
  }
  (status, @wire.split_messages(body))
}

///|
test "concurrency: a concurrent engine queues a call instead of running it" {
  let engine = H2Server::new()
  engine.concurrent()
  let mut ran = false
  engine.register("/echo.Echo/Say", req => {
    ran = true
    b"echo:" + req
  })
  let out = feed_unary(engine, b"/echo.Echo/Say", b"x")
  // Nothing has been answered: the handler has not run at all.
  assert_eq(ran, false)
  assert_eq(out.length(), 0)
  let calls = engine.take_calls()
  assert_eq(calls.length(), 1)
  assert_eq(calls[0].id, 1)
  assert_eq(calls[0].requests, [b"x"])
  // Taking them again yields nothing: the driver owns them now.
  assert_eq(engine.take_calls().length(), 0)
  // What the driver pushes comes back as frames, and the call closes on `end`.
  let sent = engine.push(1, [b"echo:x"])
  assert_eq(sent.length() >= 2, true)
  let closed = engine.end(1)
  let all = sent
  for f in closed {
    all.push(f)
  }
  let (status, replies) = status_and_replies(all)
  assert_eq(status, 0)
  assert_eq(replies, [b"echo:x"])
  assert_eq(ran, false)
}

///|
async test "concurrency: a handler's refusal rides the trailers of the call it queued" {
  let engine = H2Server::new()
  engine.concurrent()
  engine.register_unary("/gate.G/Open", (ctx, _req) => {
    ctx.fail(@wire.Status::code(PermissionDenied), "no token")
    b""
  })
  let _ = feed_unary(engine, b"/gate.G/Open", b"x")
  let calls = engine.take_calls()
  assert_eq(calls.length(), 1)
  // What a driver does with the call: run it, and let the responder come back in.
  let frames : Array[@http2.Frame] = []
  let responder : @stream.Responder = {
    send: messages => {
      for f in engine.push(1, messages) {
        frames.push(f)
      }
    },
    finish: () => {
      for f in engine.end(1) {
        frames.push(f)
      }
    },
  }
  (calls[0].run)(calls[0].ctx, calls[0].requests, responder)
  let (status, replies) = status_and_replies(frames)
  assert_eq(status, 7)
  assert_eq(replies.length(), 0)
}

///|
test "concurrency: a pushed handler without a driver is refused, not left hanging" {
  let engine = H2Server::new()
  engine.register_handler(
    "/tick.T/Every",
    Pushed((_ctx, _requests, _out) => ()),
  )
  let out = feed_unary(engine, b"/tick.T/Every", b"go")
  let (status, _replies) = status_and_replies(out)
  assert_eq(status, 12)
  assert_eq(engine.take_calls().length(), 0)
}

///|
test "concurrency: a deadline ends a queued call and names the stream to stop" {
  let engine = H2Server::new()
  engine.concurrent()
  let mut now = 1000L
  engine.set_clock(() => now)
  engine.register_handler("/slow.S/Wait", Pushed((_ctx, _requests, _out) => ()))
  let enc = @hpack.Encoder::new()
  let block = req_block(enc, b"/slow.S/Wait", extra=[
    { name: b"grpc-timeout", value: b"50m", },
  ])
  let _ = engine.feed(Settings(params=[], ack=false))
  let _ = engine.feed(
    Headers(
      stream_id=1,
      fragment=block,
      end_stream=true,
      end_headers=true,
      priority=None,
      padding=0,
    ),
  )
  assert_eq(engine.take_calls().length(), 1)
  // Inside the deadline nothing happens.
  now = 1020L
  assert_eq(engine.tick().length(), 0)
  assert_eq(engine.ended_streams().length(), 0)
  // Past it, the call is answered and reported, so the driver can stop its task.
  now = 1100L
  let (status, _replies) = status_and_replies(engine.tick())
  assert_eq(status, 4)
  assert_eq(engine.ended_streams(), [1])
  // Nothing the handler pushes afterwards reaches a call that is over.
  assert_eq(engine.push(1, [b"late"]).length(), 0)
}
