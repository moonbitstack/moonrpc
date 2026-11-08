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
/// One HTTP/1.1 connection. Each exchange is handed to the dispatch as a session, so a
/// streaming call writes its head and its envelopes while the request is still arriving: a
/// bidirectional caller that waits for an answer before sending its next message gets one.
async fn serve_h1_connection(
  conn : @tcp.Conn,
  engine : @connect.Server,
  first~ : Bytes,
) -> Unit {
  let http = @http1.Conn::new(@http1.Role::Server)
  http.receive(first[:])
  let mut session : @connect.Session? = None
  let mut streamed = false
  // A streaming call's head is not written until its first envelope is: the headers a handler
  // sets come from the request, which has not been read when the head would otherwise go out.
  let mut head_pending = false
  let mut version = "HTTP/1.1"
  let body = Buffer()
  let mut head : @http1.Request? = None
  for ;; {
    let event = http.next() catch {
      // A head that does not parse ends the connection: there is no request to answer.
      _ => break
    }
    match event {
      @http1.Event::Request(request) => {
        // A Connect call is a POST; any other verb is answered with the one status that says
        // so, before a body is read.
        if request.verb != "POST" {
          let refusal = @http1.Response::of(
            405,
            fields=[{ name: b"allow", value: b"POST", }],
            body=@http1.Body::Sized(0),
          )
          conn.write(http.send(@http1.Event::Response(refusal))) catch {
            _ => break
          }
          conn.write(http.send(@http1.Event::End([]))) catch {
            _ => break
          }
          break
        }
        head = Some(request)
        version = request.version
        body.reset()
        let started = engine.start(request.target, request.fields)
        streamed = started.streaming() && !started.refused()
        session = Some(started)
        head_pending = streamed
      }
      @http1.Event::Data(bytes) =>
        match session {
          Some(s) => {
            let reply = s.feed(bytes)
            if reply.length() > 0 {
              if head_pending {
                head_pending = false
                write_h1_stream_head(conn, http, s, version) catch {
                  _ => break
                }
              }
              conn.write(http.send(@http1.Event::Data(reply))) catch {
                _ => break
              }
            }
            // A handler that failed while the caller was still sending has closed the call:
            // the response ends here, not when the caller stops sending.
            if s.closed() {
              conn.write(http.send(@http1.Event::End([]))) catch {
                _ => break
              }
              break
            }
          }
          None => ()
        }
      @http1.Event::End(_trailers) =>
        match (head, session) {
          (Some(request), Some(s)) => {
            let answer = s.finish()
            if streamed {
              if head_pending {
                head_pending = false
                write_h1_stream_head(conn, http, s, version) catch {
                  _ => break
                }
              }
              if answer.body.length() > 0 {
                conn.write(http.send(@http1.Event::Data(answer.body))) catch {
                  _ => break
                }
              }
              conn.write(http.send(@http1.Event::End([]))) catch {
                _ => break
              }
            } else {
              answer_h1(conn, http, answer) catch {
                _ => break
              }
            }
            head = None
            session = None
            streamed = false
            head_pending = false
            // A connection the peer asked to keep goes round again; one it did not is done.
            if request.keep_alive {
              http.start_next() catch {
                _ => break
              }
            } else {
              break
            }
          }
          _ => break
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
/// The head of a streaming answer, written once the first envelope is ready so that the headers
/// a handler set are the ones that go out.
async fn write_h1_stream_head(
  conn : @tcp.Conn,
  http : @http1.Conn,
  session : @connect.Session,
  version : String,
) -> Unit {
  let answer = session.head()
  let framing = if version == "HTTP/1.0" {
    @http1.Body::Closed
  } else {
    @http1.Body::Chunked
  }
  let reply = @http1.Response::of(
    answer.status,
    fields=answer.headers,
    body=framing,
  )
  conn.write(http.send(@http1.Event::Response(reply)))
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
