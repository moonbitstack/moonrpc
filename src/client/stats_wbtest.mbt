// What a stats handler is told over one client call: the events, in order.

///|
test "client stats: a unary call reports begin, payloads, trailers and end" {
  let client = H2Client::new()
  let seen : Array[@wire.RpcStats] = []
  client.set_stats_handler(
    @wire.StatsHandler::new(rpc=event => seen.push(event)),
  )
  let (id, _req) = client.unary("/echo.Echo/Say", b"abc")
  let _ = client.feed(Settings(params=[], ack=false))
  let enc = @hpack.Encoder::new()
  let hblock = enc.encode([
    { name: b":status", value: b"200", },
    { name: b"content-type", value: b"application/grpc", },
  ])
  let _ = client.feed(
    Headers(
      stream_id=id,
      fragment=hblock,
      end_stream=false,
      end_headers=true,
      priority=None,
      padding=0,
    ),
  )
  let _ = client.feed(
    Data(
      stream_id=id,
      data=@wire.encode_message(b"xyz"),
      end_stream=false,
      padding=0,
    ),
  )
  let tblock = enc.encode([{ name: b"grpc-status", value: b"0", }])
  let _ = client.feed(
    Headers(
      stream_id=id,
      fragment=tblock,
      end_stream=true,
      end_headers=true,
      priority=None,
      padding=0,
    ),
  )
  let reply = client.reply(id)
  assert_eq(reply.grpc_status, 0)

  let kinds : Array[String] = []
  for e in seen {
    kinds.push(
      match e {
        @wire.RpcStats::Begin(..) => "begin"
        @wire.RpcStats::OutHeader(..) => "out-header"
        @wire.RpcStats::OutPayload(..) => "out-payload"
        @wire.RpcStats::InHeader(..) => "in-header"
        @wire.RpcStats::InPayload(..) => "in-payload"
        @wire.RpcStats::InTrailer(..) => "in-trailer"
        @wire.RpcStats::OutTrailer(..) => "out-trailer"
        @wire.RpcStats::End(..) => "end"
      },
    )
  }
  assert_eq(kinds, [
    "begin", "out-header", "out-payload", "in-header", "in-payload", "in-trailer",
    "end",
  ])
}

///|
test "client stats: the begin event names the method, and end carries the status" {
  let client = H2Client::new()
  let called : Array[String] = [""]
  let end_status : Array[Int32] = [0]
  client.set_stats_handler(
    @wire.StatsHandler::new(rpc=event => {
      match event {
        @wire.RpcStats::Begin(name~, ..) => called[0] = name
        @wire.RpcStats::End(status~, ..) => end_status[0] = status.code()
        _ => ()
      }
    }),
  )
  let (id, _req) = client.unary("/greet.Greeter/SayHello", b"x")
  let _ = client.feed(Settings(params=[], ack=false))
  let enc = @hpack.Encoder::new()
  let hblock = enc.encode([{ name: b":status", value: b"200", }])
  let _ = client.feed(
    Headers(
      stream_id=id,
      fragment=hblock,
      end_stream=false,
      end_headers=true,
      priority=None,
      padding=0,
    ),
  )
  let tblock = enc.encode([{ name: b"grpc-status", value: b"7", }])
  let _ = client.feed(
    Headers(
      stream_id=id,
      fragment=tblock,
      end_stream=true,
      end_headers=true,
      priority=None,
      padding=0,
    ),
  )
  let _ = client.reply(id)
  assert_eq(called[0], "SayHello")
  assert_eq(end_status[0], 7)
}
