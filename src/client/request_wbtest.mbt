// What the engines put in a request, and what they do around the size of a message.

///|
test "client: a request names this library and what it will decode" {
  let client = H2Client::new()
  let (_id, frames) = client.unary("/echo.Echo/Say", b"x")
  let dec = @hpack.Decoder::new()
  let mut agent = b""
  for f in frames {
    if f is Headers(fragment~, ..) {
      let headers = dec.decode(fragment) catch {
        _ => abort("bad header block")
      }
      for h in headers {
        if h.name == b"user-agent" {
          agent = h.value
        }
      }
    }
  }
  assert_eq(agent, @utf8.encode(user_agent))
  assert_true(agent.length() > 0)
}

///|
test "client: a caller's own user-agent replaces the default" {
  let client = H2Client::new()
  client.set_user_agent("acme-portal/2")
  let (_id, frames) = client.unary("/echo.Echo/Say", b"x")
  let dec = @hpack.Decoder::new()
  let mut agent = b""
  for f in frames {
    if f is Headers(fragment~, ..) {
      let headers = dec.decode(fragment) catch {
        _ => abort("bad header block")
      }
      for h in headers {
        if h.name == b"user-agent" {
          agent = h.value
        }
      }
    }
  }
  assert_eq(agent, b"acme-portal/2")
}

///|
test "client: a table size the peer asks for is announced before the next block" {
  let client = H2Client::new()
  let (_id, first) = client.unary("/echo.Echo/Say", b"x")
  // The peer shrinks its table; the next request has to say so first (RFC 7541 §6.3).
  let _ = client.feed(
    Settings(params=[(@http2.settings_header_table_size, 0)], ack=false),
  )
  let (_id2, second) = client.unary("/echo.Echo/Say", b"y")
  let block = match second[0] {
    Headers(fragment~, ..) => fragment
    _ => abort("no request HEADERS")
  }
  // A dynamic table size update is 001xxxxx: the first octet is 0x20 for a size of 0.
  assert_eq(block[0].to_int() & 0xE0, 0x20)
  // And it is a block the peer can still decode, size update and all.
  let dec = @hpack.Decoder::new()
  let headers = dec.decode(block) catch { _ => abort("bad header block") }
  assert_true(headers.length() > 0)
  ignore(first)
}
