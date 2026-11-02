// One interceptor shape over all four call kinds, driven through the real engine: the
// chain has to see a unary call, both streaming shapes and a bidirectional one, and be
// able to change what the handler receives and what the caller gets back.

///|
/// Drive one call through the engine — a request header block, then one DATA frame per
/// message — and return the `grpc-status` and the reply messages it framed back.
fn placed_call(
  engine : H2Server,
  path : String,
  requests : Array[Bytes],
) -> (Int32, Array[Bytes]) {
  let enc = @hpack.Encoder::new()
  let block = enc.encode([
    { name: b":method", value: b"POST", },
    { name: b":scheme", value: b"http", },
    { name: b":path", value: @utf8.encode(path), },
    { name: b":authority", value: b"localhost", },
    { name: b"content-type", value: b"application/grpc", },
    { name: b"te", value: b"trailers", },
  ])
  let _ = engine.feed(Settings(params=[], ack=false))
  let out = engine.feed(
    Headers(
      stream_id=1,
      fragment=block,
      end_stream=requests.length() == 0,
      end_headers=true,
      priority=None,
      padding=0,
    ),
  )
  for i = 0; i < requests.length(); i = i + 1 {
    for
      f in engine.feed(
        Data(
          stream_id=1,
          data=@wire.encode_message(requests[i]),
          end_stream=i == requests.length() - 1,
          padding=0,
        ),
      ) {
      out.push(f)
    }
  }
  let dec = @hpack.Decoder::new()
  let mut body = b""
  let mut status : Int32 = -1
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
test "interceptors: one chain answers a unary call, changing both directions" {
  let engine = H2Server::new()
  engine.register("/echo.Echo/Say", req => b"echo:" + req)
  let seen : Array[String] = []
  engine.add_interceptor((info, _ctx, requests, next) => {
    seen.push(info.path)
    seen.push(info.client_streaming.to_string())
    seen.push(info.server_streaming.to_string())
    next(requests.map(r => b"pre:" + r)).map(r => b"post:" + r)
  })
  let (status, replies) = placed_call(engine, "/echo.Echo/Say", [b"x"])
  assert_eq(status, 0)
  assert_eq(replies, [b"post:echo:pre:x"])
  assert_eq(seen, ["/echo.Echo/Say", "false", "false"])
}

///|
test "interceptors: the same chain answers a server-streaming call" {
  let engine = H2Server::new()
  engine.register_server_streaming("/count.C/Up", (_ctx, req) => {
    [req + b"-1", req + b"-2"]
  })
  let shape : Array[String] = []
  engine.add_interceptor((info, _ctx, requests, next) => {
    shape.push("\{info.client_streaming}/\{info.server_streaming}")
    next(requests)
  })
  let (status, replies) = placed_call(engine, "/count.C/Up", [b"n"])
  assert_eq(status, 0)
  assert_eq(replies, [b"n-1", b"n-2"])
  assert_eq(shape, ["false/true"])
}

///|
test "interceptors: the same chain sees every request of a client-streaming call" {
  let engine = H2Server::new()
  engine.register_client_streaming("/sum.S/Add", (_ctx, msgs) => {
    let mut all = b""
    for m in msgs {
      all = all + m
    }
    all
  })
  let counted : Array[Int32] = []
  engine.add_interceptor((info, _ctx, requests, next) => {
    counted.push(requests.length())
    counted.push(if info.client_streaming { 1 } else { 0 })
    next(requests)
  })
  let (status, replies) = placed_call(engine, "/sum.S/Add", [b"a", b"b", b"c"])
  assert_eq(status, 0)
  assert_eq(replies, [b"abc"])
  assert_eq(counted, [3, 1])
}

///|
test "interceptors: a bidirectional call runs the chain per batch and at half-close" {
  let engine = H2Server::new()
  engine.register_bidi("/chat.C/Echo", _ctx => @stream.BidiHandler::{
    on_message: m => [b"re:" + m],
    on_end: () => [b"bye"],
  })
  let batches : Array[Int32] = []
  engine.add_interceptor((_info, _ctx, requests, next) => {
    batches.push(requests.length())
    next(requests).map(r => r)
  })
  let (status, replies) = placed_call(engine, "/chat.C/Echo", [b"one", b"two"])
  assert_eq(status, 0)
  assert_eq(replies, [b"re:one", b"re:two", b"bye"])
  // One batch per DATA frame as it arrives, and an empty one at the half-close where
  // `on_end` answers.
  assert_eq(batches, [1, 1, 0])
}

///|
test "interceptors: an interceptor that answers itself never reaches the handler" {
  let engine = H2Server::new()
  let mut called = false
  engine.register("/gate.G/Open", req => {
    called = true
    req
  })
  engine.add_interceptor((_info, ctx, _requests, _next) => {
    ctx.fail(@wire.Status::code(PermissionDenied), "no token")
    []
  })
  let (status, replies) = placed_call(engine, "/gate.G/Open", [b"x"])
  assert_eq(status, 7)
  assert_eq(replies.length(), 0)
  assert_eq(called, false)
}

///|
test "interceptors: the first registered runs first and wraps the rest" {
  let engine = H2Server::new()
  engine.register("/echo.Echo/Say", req => req)
  let order : Array[String] = []
  engine.add_interceptor((_info, _ctx, requests, next) => {
    order.push("outer-in")
    let out = next(requests)
    order.push("outer-out")
    out
  })
  engine.add_interceptor((_info, _ctx, requests, next) => {
    order.push("inner-in")
    let out = next(requests)
    order.push("inner-out")
    out
  })
  let (status, replies) = placed_call(engine, "/echo.Echo/Say", [b"x"])
  assert_eq(status, 0)
  assert_eq(replies, [b"x"])
  assert_eq(order, ["outer-in", "inner-in", "inner-out", "outer-out"])
}
