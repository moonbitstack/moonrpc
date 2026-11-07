// The Connect server over HTTP/1.1: the same dispatch as the pure engine, driven by
// moonhttp's HTTP/1.1 connection state machine. One exchange is read whole — the head, then
// the body until the peer is done — dispatched, and answered; a kept-alive connection goes
// round again.
//
// HTTP/2 is served by the same engine through `server/`'s raw mode, and the two share a
// listener: the accept loop looks at a connection's first octets and hands it to whichever
// one speaks that.

///|
/// A Connect server: the methods, the schema a JSON body is read with, and the socket it
/// listens on.
pub(all) struct ConnectServer {
  engine : @connect.Server
  mut listener : @tcp.Listener?
  mut draining : Bool
}

///|
pub fn ConnectServer::new(
  schema~ : @proto.Schema = @proto.Schema::empty(),
) -> ConnectServer {
  { engine: @connect.Server::new(schema~), listener: None, draining: false, }
}

///|
/// Register a method: the path it answers on, the message types its body decodes to, and the
/// handler, which is the same shape a gRPC service uses.
pub fn ConnectServer::add(
  self : ConnectServer,
  path : String,
  route : @connect.Route,
) -> Unit {
  self.engine.add(path, route)
}

///|
pub fn ConnectServer::addr(self : ConnectServer) -> @socket.Addr? {
  match self.listener {
    Some(l) => Some(l.addr())
    None => None
  }
}

///|
/// Bind the listening socket and report the address, so port 0 can be used and the port read
/// back before the accept loop starts.
pub async fn ConnectServer::bind(
  self : ConnectServer,
  host~ : String = "127.0.0.1",
  port~ : Int32 = port,
  tls? : @tls.Server,
) -> @socket.Addr {
  let server = @tcp.listen(host~, port~, tls?)
  self.listener = Some(server)
  server.addr()
}

///|
/// Serve until the running task is cancelled. Each connection is driven on its own task, so a
/// slow handler holds up nothing.
pub async fn ConnectServer::serve(
  self : ConnectServer,
  host~ : String = "127.0.0.1",
  port~ : Int32 = port,
  tls? : @tls.Server,
) -> Unit {
  let server = match self.listener {
    Some(l) => l
    None => @tcp.listen(host~, port~, tls?)
  }
  self.listener = Some(server)
  defer server.close()
  @async.with_task_group(group => {
    for ;; {
      let (conn, _addr) = server.accept() catch { _ => continue }
      group.spawn_bg(allow_failure=true, () => {
        defer conn.close()
        serve_connect_connection(conn, self.engine) catch {
          _ => ()
        }
      })
    }
  })
}

///|
/// The preface an HTTP/2 client opens with. A connection that starts with it is handed to the
/// HTTP/2 driver; anything else is HTTP/1.1.
let h2_preface : Bytes = b"PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"

///|
/// Drive one accepted connection: read its first octets, decide which version it speaks, and
/// serve it.
async fn serve_connect_connection(
  conn : @tcp.Conn,
  engine : @connect.Server,
) -> Unit {
  let first = conn.read_exactly(24) catch { _ => return }
  if first == h2_preface {
    // The HTTP/2 driver owns this connection from here; it was handed the preface already.
    serve_h2_connection(conn, engine, preface=first) catch {
      _ => ()
    }
  } else {
    serve_h1_connection(conn, engine, first~) catch {
      _ => ()
    }
  }
}

///|
/// One HTTP/1.1 connection: read an exchange, answer it, repeat while the peer keeps it open.
async fn serve_h1_connection(
  conn : @tcp.Conn,
  engine : @connect.Server,
  first~ : Bytes,
) -> Unit {
  let http = @http1.Conn::new(@http1.Role::Server)
  http.receive(first[:])
  let body = Buffer()
  let mut head : @http1.Request? = None
  for ;; {
    let event = http.next() catch {
      // A head that does not parse ends the connection: there is no request to answer.
      _ => break
    }
    match event {
      @http1.Event::Request(request) => {
        head = Some(request)
        body.reset()
      }
      @http1.Event::Data(bytes) => body.write_bytes(bytes)
      @http1.Event::End(_trailers) =>
        match head {
          None => break
          Some(request) => {
            let answer = engine.serve({
              path: request.target,
              headers: request.fields,
              body: body.to_bytes(),
            })
            answer_h1(conn, http, answer) catch {
              _ => break
            }
            head = None
            // A connection the peer asked to keep goes round again; one it did not is done.
            if request.keep_alive {
              http.start_next() catch {
                _ => break
              }
            } else {
              break
            }
          }
        }
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
}

///|
/// Write one response: its head with a sized body, the body, and the end of the message.
async fn answer_h1(
  conn : @tcp.Conn,
  http : @http1.Conn,
  answer : @connect.Response,
) -> Unit {
  let fields = answer.headers
  let head = @http1.Response::of(
    answer.status,
    fields~,
    body=@http1.Body::Sized(answer.body.length()),
  )
  conn.write(http.send(@http1.Event::Response(head)))
  if answer.body.length() > 0 {
    conn.write(http.send(@http1.Event::Data(answer.body)))
  }
  conn.write(http.send(@http1.Event::End([])))
}
