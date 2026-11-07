// The Connect driver over a real socket: a client built on the same HTTP/1.1 state machine the
// server uses, so what is checked is the exchange rather than a hand-rolled reading of it.

///|
/// A server answering `/test.Echo/Say` with the body it was given.
fn echo_connect_server() -> ConnectServer {
  let server = ConnectServer::new()
  server.add("/test.Echo/Say", {
    input: "",
    output: "",
    handler: @stream.Handler::Unary((_ctx, req) => req),
  })
  server
}

///|
/// One exchange over an HTTP/1.1 connection: write the request, read the answer whole.
async fn h1_exchange(
  conn : @tcp.Conn,
  http : @http1.Conn,
  path : String,
  body : Bytes,
) -> (Int32, Bytes) {
  let fields = [
    @header.Header::of("content-type", "application/proto"),
    @header.Header::of("host", "127.0.0.1"),
  ]
  let request = @http1.Request::of(
    "POST",
    path,
    fields~,
    body=@http1.Body::Sized(body.length()),
  )
  conn.write(http.send(@http1.Event::Request(request)))
  if body.length() > 0 {
    conn.write(http.send(@http1.Event::Data(body)))
  }
  conn.write(http.send(@http1.Event::End([])))
  let status = Ref(0)
  let answer = Buffer()
  for ;; {
    let event = http.next() catch { _ => break }
    match event {
      @http1.Event::Response(response) => status.val = response.status
      @http1.Event::Data(bytes) => answer.write_bytes(bytes)
      @http1.Event::End(_) => break
      @http1.Event::NeedData => {
        let more = conn.read_some() catch { _ => break }
        let chunk = match more {
          Some(bytes) => bytes
          None => break
        }
        if chunk.length() == 0 {
          break
        }
        http.receive(chunk[:])
      }
      _ => break
    }
  }
  (status.val, answer.to_bytes())
}

///|
async fn h1_connect(port : Int32) -> (@tcp.Conn, @http1.Conn) {
  (@tcp.dial("127.0.0.1", port~), @http1.Conn::new(@http1.Role::Client))
}

///|
async test "connect over HTTP/1.1: a unary call answers the message it was given" {
  @async.with_task_group(g => {
    let server = echo_connect_server()
    let port = server.bind(port=0).port()
    let task = g.spawn(() => server.serve())
    let (conn, http) = h1_connect(port)
    defer conn.close()
    let (status, answer) = h1_exchange(
      conn, http, "/test.Echo/Say", b"hello connect",
    )
    assert_eq(status, 200)
    assert_eq(answer, b"hello connect")
    task.cancel()
  })
}

///|
async test "connect over HTTP/1.1: an unknown method is a 501 with an error body" {
  @async.with_task_group(g => {
    let server = echo_connect_server()
    let port = server.bind(port=0).port()
    let task = g.spawn(() => server.serve())
    let (conn, http) = h1_connect(port)
    defer conn.close()
    let (status, answer) = h1_exchange(conn, http, "/test.Echo/Missing", b"")
    assert_eq(status, 501)
    assert_true(@utf8.decode_lossy(answer).contains("unimplemented"))
    task.cancel()
  })
}

///|
async test "connect over HTTP/1.1: two calls on one kept-alive connection" {
  @async.with_task_group(g => {
    let server = echo_connect_server()
    let port = server.bind(port=0).port()
    let task = g.spawn(() => server.serve())
    let (conn, http) = h1_connect(port)
    defer conn.close()
    let (first_status, first) = h1_exchange(
      conn, http, "/test.Echo/Say", b"one",
    )
    assert_eq(first_status, 200)
    assert_eq(first, b"one")
    // The connection is reused when both sides are done with the exchange.
    http.start_next()
    let (second_status, second) = h1_exchange(
      conn, http, "/test.Echo/Say", b"two",
    )
    assert_eq(second_status, 200)
    assert_eq(second, b"two")
    task.cancel()
  })
}

///|
/// One HTTP/2 Connect call: the preface, a request stream, and the answer read back as its
/// status and body.
async fn h2_call(
  host : String,
  port : Int32,
  path : String,
  body : Bytes,
) -> (String, Bytes) {
  let conn = @tcp.dial(host, port~)
  defer conn.close()
  conn.write(@http2.preface)
  conn.write(@http2.Frame::Settings(params=[], ack=false).encode())
  let encoder = @hpack.Encoder::new()
  let block = encoder.encode([
    { name: b":method", value: b"POST", },
    { name: b":scheme", value: b"http", },
    { name: b":authority", value: @utf8.encode(host), },
    { name: b":path", value: @utf8.encode(path), },
    { name: b"content-type", value: b"application/proto", },
  ])
  conn.write(
    @http2.Frame::Headers(
      stream_id=1,
      fragment=block,
      end_stream=body.length() == 0,
      end_headers=true,
      priority=None,
      padding=0,
    ).encode(),
  )
  if body.length() > 0 {
    conn.write(
      @http2.Frame::Data(stream_id=1, data=body, end_stream=true, padding=0).encode(),
    )
  }
  let decoder = @hpack.Decoder::new()
  let mut status = ""
  let answer = Buffer()
  for ;; {
    let frame = read_frame(conn) catch { _ => break }
    match frame {
      @http2.Frame::Headers(stream_id~, fragment~, end_headers~, ..) =>
        if stream_id == 1 && end_headers {
          let fields : Array[@header.Header] = decoder.decode(fragment) catch {
            _ => []
          }
          for f in fields {
            if f.name == b":status" {
              status = @utf8.decode_lossy(f.value)
            }
          }
        }
      @http2.Frame::Data(stream_id~, data~, end_stream~, ..) =>
        if stream_id == 1 {
          answer.write_bytes(data)
          if end_stream {
            break
          }
        }
      @http2.Frame::Settings(ack~, ..) =>
        if !ack {
          conn.write(@http2.Frame::Settings(params=[], ack=true).encode())
        }
      @http2.Frame::GoAway(..) => break
      _ => ()
    }
  }
  (status, answer.to_bytes())
}

///|
async test "connect over HTTP/2: a unary call answers the message it was given" {
  @async.with_task_group(g => {
    let server = echo_connect_server()
    let port = server.bind(port=0).port()
    let task = g.spawn(() => server.serve())
    let (status, answer) = h2_call(
      "127.0.0.1", port, "/test.Echo/Say", b"hello h2",
    )
    assert_eq(status, "200")
    assert_eq(answer, b"hello h2")
    task.cancel()
  })
}

///|
async test "connect over HTTP/2: an unknown method is 501 with an error body" {
  @async.with_task_group(g => {
    let server = echo_connect_server()
    let port = server.bind(port=0).port()
    let task = g.spawn(() => server.serve())
    let (status, answer) = h2_call("127.0.0.1", port, "/test.Echo/None", b"")
    assert_eq(status, "501")
    assert_true(@utf8.decode_lossy(answer).contains("unimplemented"))
    task.cancel()
  })
}

///|
async test "connect client over HTTP/1.1: a unary call through the client reads the reply" {
  @async.with_task_group(g => {
    let server = echo_connect_server()
    let port = server.bind(port=0).port()
    let task = g.spawn(() => server.serve())
    let client : @connect.Client[Http1Transport] = @connect.Client::new(
      Http1Transport::new("127.0.0.1", port),
    )
    let reply = client.unary("/test.Echo/Say", b"through the client")
    assert_eq(reply.messages.length(), 1)
    assert_eq(reply.messages[0], b"through the client")
    task.cancel()
  })
}

///|
async test "connect client over HTTP/1.1: a streaming call reads every message and the end" {
  @async.with_task_group(g => {
    let server = ConnectServer::new()
    server.add("/test.Count/Up", {
      input: "",
      output: "",
      handler: @stream.Handler::ServerStreaming((_ctx, req) => [req, req]),
    })
    let port = server.bind(port=0).port()
    let task = g.spawn(() => server.serve())
    let client : @connect.Client[Http1Transport] = @connect.Client::new(
      Http1Transport::new("127.0.0.1", port),
    )
    let reply = client.server_stream("/test.Count/Up", b"twice")
    assert_eq(reply.messages.length(), 2)
    assert_eq(reply.messages[0], b"twice")
    assert_eq(reply.messages[1], b"twice")
    task.cancel()
  })
}

///|
async test "connect client: a failing call raises the status the server answered with" {
  @async.with_task_group(g => {
    let server = ConnectServer::new()
    server.add("/test.Echo/Fail", {
      input: "",
      output: "",
      handler: @stream.Handler::Unary((ctx, _req) => {
        ctx.fail(
          @wire.Status::code(@wire.Status::PermissionDenied),
          "not allowed",
        )
        b""
      }),
    })
    let port = server.bind(port=0).port()
    let task = g.spawn(() => server.serve())
    let client : @connect.Client[Http1Transport] = @connect.Client::new(
      Http1Transport::new("127.0.0.1", port),
    )
    let raised = try {
      ignore(client.unary("/test.Echo/Fail", b""))
      false
    } catch {
      @wire.StatusError(status, message) => {
        assert_eq(status, @wire.Status::PermissionDenied)
        assert_eq(message, "not allowed")
        true
      }
      _ => false
    }
    assert_true(raised)
    task.cancel()
  })
}
