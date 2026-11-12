// trpc.io over HTTP/1.1: one request per call on the client, and a small server that hands
// each request to the procedure table in `trpcio/`.

///|
/// A client for the tRPC-for-TypeScript protocol. Each call opens a connection, writes one
/// request and reads one answer — the protocol has no session to keep.
pub fn trpcio_client(
  host : String,
  port : Int32,
  base~ : String = "",
) -> @trpcio.Client {
  let send : @trpcio.Send = async fn(request) {
    let method = if request.get {
      "GET"
    } else {
      "POST"
    }
    let body = if request.get { "" } else { request.body }
    let (status, answer) = http_call(
      host,
      port,
      method,
      base + "/" + request.target,
      body,
    )
    (status, answer)
  }
  @trpcio.Client::new(send)
}

///|
/// One HTTP/1.1 request, one answer: the status and the body read whole.
async fn http_call(
  host : String,
  port : Int32,
  method : String,
  target : String,
  body : String,
) -> (Int, String) {
  let conn = @tcp.dial(host, port~)
  defer conn.close()
  let http = @http1.Conn::new(@http1.Role::Client)
  let payload = @utf8.encode(body)
  let fields : Array[@header.Header] = [
    @header.Header::of("host", host),
    @header.Header::of("accept", "application/json"),
    @header.Header::of("content-type", "application/json"),
    @header.Header::of("trpc-accept", "application/json"),
    @header.Header::of("x-trpc-source", "moonrpc"),
  ]
  let request = @http1.Request::of(
    method,
    target,
    fields~,
    body=@http1.Body::Sized(payload.length()),
  )
  conn.write(http.send(@http1.Event::Request(request)))
  if payload.length() > 0 {
    conn.write(http.send(@http1.Event::Data(payload)))
  }
  conn.write(http.send(@http1.Event::End([])))
  let mut status = 0
  let answer = Buffer()
  for ;; {
    let event = http.next() catch {
      _ => break
    }
    match event {
      @http1.Event::Response(response) => status = response.status
      @http1.Event::Data(bytes) => answer.write_bytes(bytes)
      @http1.Event::End(_) => break
      _ => ()
    }
  }
  (status, @utf8.decode_lossy(answer.to_bytes()))
}

///|
/// Serve a procedure table on `host:port` until the running task is cancelled.
pub async fn serve_trpcio(
  host~ : String = "127.0.0.1",
  port~ : Int32 = 12000,
  server : @trpcio.Server,
  base~ : String = "",
) -> Unit {
  serve_trpcio_on(bind_trpcio(host~, port~), server, base~)
}

///|
/// Bind the socket a tRPC-for-TypeScript server accepts on. Port 0 asks the system for one.
pub async fn bind_trpcio(
  host~ : String = "127.0.0.1",
  port~ : Int32 = 12000,
) -> @tcp.Listener {
  @tcp.listen(host~, port~)
}

///|
/// Serve on a socket already bound, so a caller can learn the port before the loop starts.
pub async fn serve_trpcio_on(
  listener : @tcp.Listener,
  server : @trpcio.Server,
  base~ : String = "",
) -> Unit {
  @async.with_task_group(group => {
    for ;; {
      let (conn, _) = listener.accept() catch { _ => continue }
      group.spawn_bg(allow_failure=true, () => {
        defer conn.close()
        serve_trpcio_connection(conn, server, base~) catch {
          _ => ()
        }
      })
    }
  })
}

///|
/// One connection: a request in, an answer out, and around again while the peer keeps it
/// alive. The body is read whole before the dispatch sees it — a tRPC call is one object,
/// not a stream.
async fn serve_trpcio_connection(
  conn : @tcp.Conn,
  server : @trpcio.Server,
  base~ : String,
) -> Unit raise {
  let http = @http1.Conn::new(@http1.Role::Server)
  let body = Buffer()
  let mut head : @http1.Request? = None
  for ;; {
    let event = http.next() catch { _ => break }
    match event {
      @http1.Event::Request(request) => {
        head = Some(request)
        body.reset()
      }
      @http1.Event::Data(bytes) => body.write_bytes(bytes)
      @http1.Event::End(_) => {
        match head {
          Some(request) => {
            let path = strip_base(request.target, base)
            let answer = server.handle(
              request.verb,
              path,
              @utf8.decode_lossy(body.to_bytes()),
            )
            let fields : Array[@header.Header] = [
              @header.Header::of("content-type", answer.content_type),
            ]
            let payload = @utf8.encode(answer.body)
            let response = @http1.Response::of(
              answer.status,
              fields~,
              body=@http1.Body::Sized(payload.length()),
            )
            conn.write(http.send(@http1.Event::Response(response)))
            if payload.length() > 0 {
              conn.write(http.send(@http1.Event::Data(payload)))
            }
            conn.write(http.send(@http1.Event::End([])))
          }
          None => break
        }
        head = None
      }
      _ => ()
    }
  }
}

///|
/// The request target without the prefix the server was mounted under. A server mounted at
/// `/trpc` answers `/trpc/greet.hello` as `greet.hello`.
fn strip_base(target : String, base : String) -> String {
  if base.length() == 0 {
    return target
  }
  match target.strip_prefix(base + "/") {
    Some(rest) => rest.to_string()
    None => target
  }
}
