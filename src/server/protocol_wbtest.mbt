// What the engine refuses at the frame level: frames on the control stream, a push from a
// client, a PING rate over the policy, settings nobody acknowledges.

///|
/// The GOAWAY a run of frames ends with: its error code and debug text, or `None` when the
/// frames carry none.
fn goaway_of(out : Array[@http2.Frame]) -> (Int32, String)? {
  for f in out {
    if f is GoAway(error_code~, debug~, ..) {
      return Some((error_code, @utf8.decode_lossy(debug[:])))
    }
  }
  None
}

///|
test "protocol: DATA on the control stream is a connection error" {
  let engine = H2Server::new()
  let out = engine.feed(
    Data(stream_id=0, data=b"x", end_stream=false, padding=0),
  )
  match goaway_of(out) {
    Some((code, _why)) => assert_eq(code, @http2.error_protocol_error)
    None => abort("no GOAWAY for DATA on stream 0")
  }
  assert_eq(engine.closing(), true)
}

///|
test "protocol: HEADERS on the control stream is a connection error" {
  let engine = H2Server::new()
  let enc = @hpack.Encoder::new()
  let out = engine.feed(
    Headers(
      stream_id=0,
      fragment=enc.encode([]),
      end_stream=false,
      end_headers=true,
      priority=None,
      padding=0,
    ),
  )
  assert_eq(goaway_of(out).unwrap().0, @http2.error_protocol_error)
}

///|
test "protocol: PUSH_PROMISE from a client is a connection error" {
  let engine = H2Server::new()
  let enc = @hpack.Encoder::new()
  let out = engine.feed(
    PushPromise(
      stream_id=1,
      promised_id=2,
      fragment=enc.encode([{ name: b":path", value: b"/x", }]),
      end_headers=true,
      padding=0,
    ),
  )
  // A client cannot push, so the promise is a protocol error rather than something to
  // decode and honour (RFC 9113 §6.6).
  assert_eq(goaway_of(out).unwrap().0, @http2.error_protocol_error)
  assert_eq(engine.closing(), true)
}

///|
test "protocol: a PING rate over the policy ends the connection with ENHANCE_YOUR_CALM" {
  let engine = H2Server::new()
  let mut now = 0L
  engine.set_clock(() => now)
  engine.set_keepalive(@wire.ServerKeepalive::{
    time: 7_200_000L,
    timeout: 20_000L,
    min_ping_interval: 300_000L,
    permit_without_calls: false,
    max_ping_strikes: 2,
  })
  // Three PINGs in the same millisecond: strike, strike, then out.
  let first = engine.feed(Ping(payload=b"aaaaaaaa", ack=false))
  assert_eq(goaway_of(first), None)
  assert_eq(first.length(), 1)
  let second = engine.feed(Ping(payload=b"bbbbbbbb", ack=false))
  assert_eq(goaway_of(second), None)
  now = 1L
  let third = engine.feed(Ping(payload=b"cccccccc", ack=false))
  let (code, why) = goaway_of(third).unwrap()
  assert_eq(code, @http2.error_enhance_your_calm)
  assert_eq(why, "too many pings")
  assert_eq(engine.closing(), true)
}

///|
test "protocol: a PING spaced the way the policy asks is never a strike" {
  let engine = H2Server::new()
  let mut now = 0L
  engine.set_clock(() => now)
  engine.set_keepalive(@wire.server_keepalive)
  for i = 0; i < 10; i = i + 1 {
    now = now + 300_000L
    let out = engine.feed(Ping(payload=b"aaaaaaaa", ack=false))
    assert_eq(goaway_of(out), None)
    assert_eq(out.length(), 1)
  }
  assert_eq(engine.closing(), false)
}

///|
test "protocol: settings nobody acknowledges end the connection" {
  let engine = H2Server::new()
  let mut now = 0L
  engine.set_clock(() => now)
  let _ = engine.preface()
  // Inside the limit nothing happens.
  now = 9_000L
  assert_eq(engine.tick().length(), 0)
  // Past it the connection is given up, because a peer that never acks is not reading.
  now = 11_000L
  let (code, why) = goaway_of(engine.tick()).unwrap()
  assert_eq(code, @http2.error_settings_timeout)
  assert_true(why.contains("SETTINGS"))
  assert_eq(engine.closing(), true)
}

///|
test "protocol: an acknowledged SETTINGS stops the timeout" {
  let engine = H2Server::new()
  let mut now = 0L
  engine.set_clock(() => now)
  let _ = engine.preface()
  let _ = engine.feed(Settings(params=[], ack=true))
  now = 60_000L
  assert_eq(engine.tick().length(), 0)
  assert_eq(engine.closing(), false)
}

///|
test "protocol: a zero-increment WINDOW_UPDATE on the connection is refused" {
  let engine = H2Server::new()
  let out = engine.feed(WindowUpdate(stream_id=0, increment=0))
  assert_eq(goaway_of(out).unwrap().0, @http2.error_protocol_error)
}

///|
test "protocol: announcing a setting sends it and holds the peer to it" {
  let engine = H2Server::new()
  let out = engine.announce([(@http2.settings_max_concurrent_streams, 7)])
  assert_eq(out.length(), 1)
  match out[0] {
    Settings(params~, ack~) => {
      assert_eq(ack, false)
      assert_eq(params, [(@http2.settings_max_concurrent_streams, 7)])
    }
    _ => abort("announce did not send SETTINGS")
  }
}
