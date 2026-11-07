// The native HTTP/2 socket driver: it pumps bytes between a real connection and the pure
// `@moonrpc.H2Server` engine. All protocol logic lives in the engine; this file only reads
// whole frames off the socket, feeds them in, and writes the engine's replies back. The
// connection is `@tcp.Conn`, which reads and writes the same whether TLS sits under it or
// not. Native-only, because real sockets and `moonbitlang/async` have no JS/Wasm backend
// (`supported_targets`).

///|
/// Read exactly one HTTP/2 frame off a byte reader — the 9-octet header, then its
/// declared payload — and decode it with the pure frame codec. Raises when the
/// peer closes mid-frame (a short read) or the bytes are malformed.
async fn read_frame(conn : &@io.Reader) -> @http2.Frame {
  read_payload(conn, conn.read_exactly(9))
}

///|
/// Read one frame, refusing one over the size this endpoint advertised: `None` is a frame
/// too large to be one of ours, told from the nine-octet header alone so the payload is
/// never read. RFC 9113 §4.2 makes that a FRAME_SIZE_ERROR, and checking it here is what
/// stops a peer from making the server buffer an arbitrarily large frame first.
async fn read_frame_sized(conn : &@io.Reader) -> @http2.Frame? {
  let head = conn.read_exactly(9)
  let hdr = @http2.FrameHeader::decode(head)
  if hdr.length > @wire.default_max_frame_size {
    return None
  }
  Some(read_payload(conn, head))
}

///|
/// The rest of a frame whose 9-octet header is already read.
async fn read_payload(conn : &@io.Reader, head : Bytes) -> @http2.Frame {
  let hdr = @http2.FrameHeader::decode(head)
  let payload = if hdr.length > 0 { conn.read_exactly(hdr.length) } else { b"" }
  let buf = @buffer.Buffer()
  buf.write_bytes(head)
  buf.write_bytes(payload)
  let (frame, _) = @http2.decode(buf.to_bytes())
  frame
}

///|
/// Write each frame's exact wire bytes to the socket.
async fn write_frames(conn : &@io.Writer, frames : Array[@http2.Frame]) -> Unit {
  for f in frames {
    conn.write(f.encode())
  }
}

///|
/// One connection as the server holds it: the socket, the engine that owns its protocol
/// state, and the lock that serializes writes, so a call answered on its own task and a
/// shutdown GOAWAY never interleave their bytes.
struct Live {
  conn : @tcp.Conn
  engine : @moonrpc.H2Server
  writes : @async.Mutex
}

///|
/// Write frames to the connection under the connection's write lock. Every writer goes
/// through here: the reader's answers, a call running on its own task, a shutdown.
async fn send_frames(live : Live, frames : Array[@http2.Frame]) -> Unit {
  if frames.length() == 0 {
    return
  }
  live.writes.acquire()
  defer live.writes.release()
  write_frames(live.conn, frames)
}

///|
/// How often the driver looks at the clock while nothing is arriving: a call whose
/// deadline passes in a quiet connection is ended within this long.
let tick_millis : Int32 = 10

///|
/// Run one call the engine handed over, on a task of its own, so a slow handler holds up
/// nothing else on the connection. The handler answers through the responder, which comes
/// back into the engine as `push` and `end`; a handler that raises ends the call with
/// `INTERNAL` rather than leaving the stream open.
async fn run_call(live : Live, call : @moonrpc.Call) -> Unit {
  let responder : @moonrpc.Responder = {
    send: messages => send_frames(live, live.engine.push(call.id, messages)),
    finish: () => send_frames(live, live.engine.end(call.id)),
  }
  (call.run)(call.ctx, call.requests, responder) catch {
    _ => {
      call.ctx.fail(@wire.Status::code(Internal), "handler failed")
      ()
    }
  }
  // A handler that returned without finishing still ends its call: a stream left open
  // with no task behind it would hang the caller for ever.
  send_frames(live, live.engine.end(call.id)) catch {
    _ => ()
  }
}

///|
/// Drive one accepted connection to completion: validate the client connection
/// @http2.preface, send the server SETTINGS, then loop — read a frame, feed it to the
/// engine, write back whatever the engine produces — until the peer closes the connection,
/// a GOAWAY is seen, the engine reports a connection error, or the server is shutting down
/// and this connection has finished its last call.
///
/// Calls are not run inside `feed`: the engine queues them and this loop starts a task for
/// each, while a timer task watches the clock so a deadline passes even on a connection
/// that has gone quiet. Both write through the connection's lock, which is why the engine
/// is only ever stepped from one of them at a time.
async fn drive(live : Live, draining : () -> Bool) -> Unit {
  let engine = live.engine
  let got = live.conn.read_exactly(@http2.preface.length())
  if !@http2.has_preface(got) {
    return
  }
  send_frames(live, engine.preface())
  @async.with_task_group(g => {
    // The calls running on this connection, so a deadline or a reset can stop them.
    let tasks : Map[Int32, @async.Task[Unit]] = Map([])
    let stop = (ids : Array[Int32]) => {
      for id in ids {
        match tasks.get(id) {
          Some(task) => {
            tasks.remove(id)
            task.cancel()
          }
          None => ()
        }
      }
    }
    let ticker = g.spawn(allow_failure=true, () => {
      for ;; {
        @async.sleep(tick_millis)
        if engine.closing() || engine.goaway_received() {
          return
        }
        // A call that ran out of time is ended here, and its task stopped with it.
        send_frames(live, engine.tick()) catch {
          _ => return
        }
        stop(engine.ended_streams())
      }
    })
    let mut leaving = false
    while !leaving {
      let frame = read_frame_sized(live.conn) catch { _ => break }
      let frame = match frame {
        Some(frame) => frame
        None => {
          // Over the size we advertised: the connection ends with the reason on the wire,
          // and the frame itself is never buffered.
          send_frames(
            live,
            engine.fail(
              @http2.error_frame_size_error, "frame over SETTINGS_MAX_FRAME_SIZE",
            ),
          ) catch {
            _ => ()
          }
          break
        }
      }
      // Whatever the engine hands back goes out first, RST_STREAM and GOAWAY included:
      // a connection error is only closed *after* the peer has been told why
      // (RFC 9113 §5.4.1).
      send_frames(live, engine.feed(frame)) catch {
        _ => break
      }
      for call in engine.take_calls() {
        tasks[call.id] = g.spawn(allow_failure=true, () => {
          run_call(live, call)
          tasks.remove(call.id)
        })
      }
      stop(engine.ended_streams())
      if engine.closing() || engine.goaway_received() {
        leaving = true
      } else if draining() && engine.active_streams() == 0 {
        send_frames(live, engine.goaway(engine.highest_stream())) catch {
          _ => ()
        }
        leaving = true
      }
    }
    // The connection is over: the clock reader stops, and so does every call still
    // running on it — a handler waiting on something of its own would otherwise hold the
    // connection's task group open for ever.
    ticker.cancel()
    for _id, task in tasks {
      task.cancel()
    }
  })
}

///|
/// A gRPC server: a registry of handlers keyed by `/pkg.Service/Method` path,
/// served over the self-built HTTP/2 transport — h2c, or TLS with ALPN `h2`. Handlers
/// may be any of the four gRPC call kinds. Each accepted connection gets its own
/// `@moonrpc.H2Server` engine (HPACK and flow control are per-connection state).
pub(all) struct GrpcServer {
  handlers : Map[String, @moonrpc.Handler]
  // The connections being served right now, keyed by a serial number, so that a shutdown
  // can reach them. A connection removes itself when its driver returns; the engine
  // comes along because a shutdown has to ask whether the connection is between calls
  // before it interrupts.
  live : Map[Int32, Live]
  mut listener : @tcp.Listener?
  mut draining : Bool
  mut next_conn : Int32
  // What replies are compressed with, when the caller accepts it. Identity unless a
  // server opts in, so a program that does not care pays nothing for compression.
  mut encoding : @moonrpc.Encoding
  // The interceptor chain every connection's engine is built with, and the two limits a
  // server sets once and applies to each.
  interceptors : Array[@server.Interceptor]
  mut max_recv : Int32
  mut max_send : Int32
  mut keepalive : @wire.ServerKeepalive?
  // Where every connection's engine reports its calls.
  mut stats : @wire.StatsHandler?
}

///|
/// A gRPC server with no registered methods.
pub fn GrpcServer::new() -> GrpcServer {
  {
    handlers: Map([]),
    live: Map([]),
    listener: None,
    draining: false,
    next_conn: 0,
    encoding: @moonrpc.Encoding::Identity,
    interceptors: [],
    max_recv: @wire.max_message_size,
    max_send: @wire.max_message_size,
    keepalive: None,
    stats: None,
  }
}

///|
/// Add a server interceptor: every call on every connection this server accepts runs
/// through it, whichever of the four call kinds it is.
pub fn GrpcServer::add_interceptor(
  self : GrpcServer,
  interceptor : @server.Interceptor,
) -> Unit {
  self.interceptors.push(interceptor)
}

///|
/// Cap the messages this server accepts and sends, in octets, on every connection.
pub fn GrpcServer::set_max_message_size(
  self : GrpcServer,
  recv~ : Int32 = @wire.max_message_size,
  send~ : Int32 = @wire.max_message_size,
) -> Unit {
  self.max_recv = recv
  self.max_send = send
}

///|
/// Hold every peer to a keepalive policy: PINGs closer together than it allows are strikes,
/// and a peer that runs out of them is answered `GOAWAY(ENHANCE_YOUR_CALM)`.
pub fn GrpcServer::set_keepalive(
  self : GrpcServer,
  policy : @wire.ServerKeepalive,
) -> Unit {
  self.keepalive = Some(policy)
}

///|
/// Compress replies with `encoding` whenever the caller's `grpc-accept-encoding` lists it;
/// a caller that did not ask for it still gets identity.
pub fn GrpcServer::set_encoding(
  self : GrpcServer,
  encoding : @moonrpc.Encoding,
) -> Unit {
  self.encoding = encoding
}

///|
/// Report every call on every connection to `handler`, as grpc-go's stats handler does.
pub fn GrpcServer::set_stats_handler(
  self : GrpcServer,
  handler : @wire.StatsHandler,
) -> Unit {
  self.stats = Some(handler)
}

///|
/// Register `handler` at `path`, whichever of the four call shapes it is.
pub fn GrpcServer::register_handler(
  self : GrpcServer,
  path : String,
  handler : @moonrpc.Handler,
) -> Unit {
  self.handlers[path] = handler
}

///|
pub impl @moonrpc.Registrar for GrpcServer with fn register_handler(
  self,
  path,
  handler,
) {
  self.handlers[path] = handler
}

///|
/// Register a unary handler `(request) -> reply` (messages without their gRPC
/// length prefix) for a fully-qualified path `/pkg.Service/Method`.
pub fn GrpcServer::register(
  self : GrpcServer,
  path : String,
  handler : (Bytes) -> Bytes,
) -> Unit {
  self.handlers[path] = Unary((_ctx, req) => handler(req))
}

///|
/// Register a unary handler that receives the [`RpcContext`], so it can read request
/// metadata / the deadline and end the call with a non-OK status via `ctx.fail`.
pub fn GrpcServer::register_unary(
  self : GrpcServer,
  path : String,
  handler : (@moonrpc.RpcContext, Bytes) -> Bytes,
) -> Unit {
  self.handlers[path] = Unary(handler)
}

///|
/// Register a server-streaming handler: one request message in, an ordered
/// sequence of reply messages out.
pub fn GrpcServer::register_server_streaming(
  self : GrpcServer,
  path : String,
  handler : (@moonrpc.RpcContext, Bytes) -> Array[Bytes],
) -> Unit {
  self.handlers[path] = ServerStreaming(handler)
}

///|
/// Register a client-streaming handler: every request message is collected, and
/// after the client half-closes the handler returns one reply.
pub fn GrpcServer::register_client_streaming(
  self : GrpcServer,
  path : String,
  handler : (@moonrpc.RpcContext, Array[Bytes]) -> Bytes,
) -> Unit {
  self.handlers[path] = ClientStreaming(handler)
}

///|
/// Register a bidirectional-streaming handler.
pub fn GrpcServer::register_bidi(
  self : GrpcServer,
  path : String,
  factory : (@moonrpc.RpcContext) -> @moonrpc.BidiHandler,
) -> Unit {
  self.handlers[path] = Bidi(factory)
}

///|
/// Register the `grpc.reflection.v1.ServerReflection` service (and its v1alpha
/// alias) so a reflection client such as `grpcurl` can list and describe the
/// services in `refl`'s descriptor database.
pub fn GrpcServer::register_reflection(
  self : GrpcServer,
  refl : @moonrpc.ReflectionService,
) -> Unit {
  self.handlers[@moonrpc.reflection_v1_path] = refl.handler()
  self.handlers[@moonrpc.reflection_v1alpha_path] = refl.handler()
}

///|
/// Build a fresh per-connection engine seeded with this server's handlers.
fn GrpcServer::engine(self : GrpcServer) -> @moonrpc.H2Server {
  let e = @moonrpc.H2Server::new()
  // The engine is pure and has no clock, so `grpc-timeout` deadlines only mean anything
  // once one is handed to it.
  e.set_clock(() => @async.now())
  e.set_encoding(self.encoding)
  e.set_max_message_size(recv=self.max_recv, send=self.max_send)
  match self.stats {
    Some(handler) => e.set_stats_handler(handler)
    None => ()
  }
  match self.keepalive {
    Some(policy) => e.set_keepalive(policy)
    None => ()
  }
  for interceptor in self.interceptors {
    e.add_interceptor(interceptor)
  }
  // The driver runs each call on its own task, so one slow handler cannot hold up the
  // other streams on the connection.
  e.concurrent()
  for path, handler in self.handlers {
    e.register_handler(path, handler)
  }
  e
}

///|
/// The port a gRPC server listens on unless told otherwise.
///
/// gRPC runs on HTTP/2, which shares a TCP listener with HTTP/1.1 and
/// WebSocket, so it takes the family's number rather than gRPC's conventional
/// 50051: one port for every protocol a server speaks.
pub let port : Int32 = 12000

///|
/// The address this server listens on, or `None` before it is listening. With port 0 asked
/// for, this is where the port the system chose comes back from: a listener reports what it
/// actually bound, not the 0 it was given.
///
/// Kept separate from [`GrpcServer::bind`] because the accept loop can end before the port is
/// asked for, and a caller that already has the address holds it itself.
pub fn GrpcServer::addr(self : GrpcServer) -> @socket.Addr? {
  match self.listener {
    Some(l) => Some(l.addr())
    None => None
  }
}

///|
/// Bind the listening socket now and report the address it got, so a caller can reach the
/// server before the accept loop has started — and so a test asked to listen on port 0 learns
/// the port the system picked. Connections queue from the moment this returns, so the caller
/// may connect immediately; `serve` reuses the socket instead of binding a second one.
pub async fn GrpcServer::bind(
  self : GrpcServer,
  host~ : String = "127.0.0.1",
  port~ : Int32 = port,
  tls? : @tls.Server,
) -> @socket.Addr {
  let server = @tcp.listen(host~, port~, tls?)
  self.listener = Some(server)
  server.addr()
}

///|
/// Serve gRPC on `host:port` — h2c, or over TLS when `tls` is given, in which case every
/// accepted connection must have settled on ALPN `h2` — blocking in the accept loop until
/// the running task is cancelled or `graceful_stop` drains the server. Each connection is
/// driven by `drive`; a failure on one connection is isolated and does not stop the server.
///
/// A socket that [`GrpcServer::bind`] already opened is served as it is, on the address that
/// bind reported.
pub async fn GrpcServer::serve(
  self : GrpcServer,
  host~ : String = "127.0.0.1",
  port~ : Int32 = port,
  tls? : @tls.Server,
) -> Unit {
  let server = match self.listener {
    Some(l) => l
    None => @tcp.listen(host~, port~, tls?)
  }
  self.listener = Some(server)
  self.draining = false
  // The listener is closed from this task and nowhere else. Closing a socket that
  // another task is parked in `accept` on does not wake that task — it wedges it,
  // beyond the reach of cancellation — which is why `graceful_stop` knocks on the
  // port instead of reaching in here.
  defer self.shut(server)
  @async.with_task_group(g => {
    for ;; {
      // A connection whose handshake fails — a client offering no protocol we speak, a
      // certificate it will not accept — is a refused peer, not a broken server: the
      // accept loop goes on, or one bad client takes the listener with it.
      let (conn, _addr) = server.accept() catch { _ => continue }
      if self.draining {
        conn.close()
        break
      }
      // A handshake that did not settle on h2 leaves nothing to say in HTTP/2, so the
      // socket is closed rather than spoken to in a version it did not agree to
      // (RFC 9113 §3.2).
      if unnegotiated(conn) {
        conn.close()
        continue
      }
      let engine = self.engine()
      let id = self.next_conn
      self.next_conn = id + 1
      let live = { conn, engine, writes: @async.Mutex::Mutex(), }
      self.live[id] = live
      g.spawn_bg(allow_failure=true, () => {
        defer conn.close()
        defer self.live.remove(id)
        drive(live, () => self.draining) catch {
          _ => ()
        }
      })
    }
  })
}

///|
/// Release the listening socket and forget it. Only `serve` calls this, on its way out.
fn GrpcServer::shut(self : GrpcServer, server : @tcp.Listener) -> Unit {
  server.close()
  self.listener = None
}

///|
/// Stop serving without cutting anyone off: stop accepting new connections, let the
/// calls that are already running finish, and send every connection a GOAWAY naming
/// the last stream it opened, so clients know what was accepted and can reconnect
/// elsewhere. Returns once the last connection is gone, or after `grace`
/// milliseconds — a client that received the GOAWAY and then went quiet without
/// closing cannot be waited on forever. `serve` returns on its own once the accept
/// loop and the last driver are done, so the task running it ends without being
/// cancelled; if the grace period ran out with connections still open, cancelling
/// that task is what releases them.
pub async fn GrpcServer::graceful_stop(
  self : GrpcServer,
  grace~ : Int32 = 10000,
) -> Unit {
  self.draining = true
  // Knock on our own port. The accept loop is parked and only looks at `draining`
  // when a connection arrives, so this is what lets it notice and stop accepting.
  match self.listener {
    Some(l) =>
      try {
        let knock = @socket.Tcp::connect(l.addr())
        knock.close()
      } catch {
        _ => ()
      }
    None => ()
  }
  let deadline = @async.now() + grace.to_int64()
  while self.live.length() > 0 && @async.now() < deadline {
    for live in self.snapshot() {
      if live.engine.active_streams() == 0 {
        send_frames(live, live.engine.goaway(live.engine.highest_stream())) catch {
          _ => ()
        }
      }
    }
    @async.sleep(10)
  }
}

///|
/// The live connections as they stand right now. A shutdown suspends while it writes
/// and sleeps, and a driver that returns in the meantime removes itself, so walking
/// the map directly would be walking it while it changes.
fn GrpcServer::snapshot(self : GrpcServer) -> Array[Live] {
  let out = []
  for _id, l in self.live {
    out.push(l)
  }
  out
}

///|
/// A minimal in-process h2c gRPC client built on the same frame + HPACK codecs:
/// it drives a real unary call over a real TCP socket and returns
/// `(:status, grpc-status, reply message)`. Proves the server end-to-end.
async fn unary_call(
  host : String,
  port : Int32,
  path : Bytes,
  request : Bytes,
) -> (Bytes, Bytes, Bytes) {
  let conn = @socket.Tcp::connect(
    @socket.Addr::parse(host + ":" + port.to_string()),
  )
  // client @http2.preface + our SETTINGS.
  conn.write(@http2.preface)
  conn.write(@http2.Frame::Settings(params=[], ack=false).encode())
  // request HEADERS (HPACK-encoded pseudo-headers) then a single DATA message.
  let enc = @hpack.Encoder::new()
  let block = enc.encode([
    { name: b":method", value: b"POST", },
    { name: b":scheme", value: b"http", },
    { name: b":path", value: path, },
    { name: b":authority", value: b"127.0.0.1", },
    { name: b"content-type", value: b"application/grpc", },
    { name: b"te", value: b"trailers", },
  ])
  conn.write(
    @http2.Frame::Headers(
      stream_id=1,
      fragment=block,
      end_stream=false,
      end_headers=true,
      priority=None,
      padding=0,
    ).encode(),
  )
  conn.write(
    @http2.Frame::Data(
      stream_id=1,
      data=@moonrpc.encode_message(request),
      end_stream=true,
      padding=0,
    ).encode(),
  )
  // read frames until the END_STREAM trailer; collect status, grpc-status, body.
  let dec = @hpack.Decoder::new()
  let mut status = b""
  let mut grpc_status = b""
  let mut body = b""
  let mut done = false
  while !done {
    let frame = read_frame(conn)
    match frame {
      Settings(ack~, ..) =>
        if !ack {
          conn.write(@http2.Frame::Settings(params=[], ack=true).encode())
        }
      Headers(fragment~, end_stream~, ..) => {
        for h in dec.decode(fragment) {
          if h.name == b":status" {
            status = h.value
          }
          if h.name == b"grpc-status" {
            grpc_status = h.value
          }
        }
        if end_stream {
          done = true
        }
      }
      Data(data~, ..) => body = body + data
      _ => ()
    }
  }
  conn.close()
  let message = match @moonrpc.decode_message(body) {
    Some((_, p)) => p
    None => b""
  }
  (status, grpc_status, message)
}

///|
async test "unary gRPC call served over the self-built h2c transport" {
  @async.with_task_group(g => {
    let server = GrpcServer::new()
    server.register("/echo.Echo/Say", req => b"echo:" + req)
    let port_18071 = server.bind(port=0).port()
    let task = g.spawn(() => server.serve())
    @async.sleep(300)
    let (status, grpc_status, reply) = unary_call(
      "127.0.0.1", port_18071, b"/echo.Echo/Say", b"world",
    )
    assert_eq(status == b"200", true)
    assert_eq(grpc_status == b"0", true)
    assert_eq(reply == b"echo:world", true)
    task.cancel()
  })
}

///|
async test "an unregistered method is served UNIMPLEMENTED over h2c" {
  @async.with_task_group(g => {
    let server = GrpcServer::new()
    server.register("/echo.Echo/Say", req => req)
    let port_18072 = server.bind(port=0).port()
    let task = g.spawn(() => server.serve())
    @async.sleep(300)
    let (_status, grpc_status, _reply) = unary_call(
      "127.0.0.1", port_18072, b"/echo.Echo/Missing", b"x",
    )
    assert_eq(grpc_status == b"12", true)
    task.cancel()
  })
}

///|
/// A streaming in-process h2c gRPC client: it opens one stream, sends every
/// message in `requests` as its own length-prefixed DATA (the last carrying
/// END_STREAM, or END_STREAM on the HEADERS when there are none), then reads the
/// whole response, reassembling the reply messages in order and returning
/// `(:status, grpc-status, [reply messages])`. Drives both server- and
/// client-streaming (and the bidi collect-all case).
async fn streaming_call(
  host : String,
  port : Int32,
  path : Bytes,
  requests : Array[Bytes],
) -> (Bytes, Bytes, Array[Bytes]) {
  let conn = @socket.Tcp::connect(
    @socket.Addr::parse(host + ":" + port.to_string()),
  )
  conn.write(@http2.preface)
  conn.write(@http2.Frame::Settings(params=[], ack=false).encode())
  let enc = @hpack.Encoder::new()
  let block = enc.encode([
    { name: b":method", value: b"POST", },
    { name: b":scheme", value: b"http", },
    { name: b":path", value: path, },
    { name: b":authority", value: b"127.0.0.1", },
    { name: b"content-type", value: b"application/grpc", },
    { name: b"te", value: b"trailers", },
  ])
  let n = requests.length()
  conn.write(
    @http2.Frame::Headers(
      stream_id=1,
      fragment=block,
      end_stream=n == 0,
      end_headers=true,
      priority=None,
      padding=0,
    ).encode(),
  )
  for i = 0; i < n; i = i + 1 {
    conn.write(
      @http2.Frame::Data(
        stream_id=1,
        data=@moonrpc.encode_message(requests[i]),
        end_stream=i == n - 1,
        padding=0,
      ).encode(),
    )
  }
  let dec = @hpack.Decoder::new()
  let acc = @buffer.Buffer()
  let mut status = b""
  let mut grpc_status = b""
  let mut done = false
  while !done {
    let frame = read_frame(conn)
    match frame {
      Settings(ack~, ..) =>
        if !ack {
          conn.write(@http2.Frame::Settings(params=[], ack=true).encode())
        }
      Headers(fragment~, end_stream~, ..) => {
        for h in dec.decode(fragment) {
          if h.name == b":status" {
            status = h.value
          }
          if h.name == b"grpc-status" {
            grpc_status = h.value
          }
        }
        if end_stream {
          done = true
        }
      }
      Data(data~, ..) => acc.write_bytes(data)
      _ => ()
    }
  }
  conn.close()
  (status, grpc_status, @moonrpc.split_messages(acc.to_bytes()))
}

///|
async test "server-streaming: a real h2c call receives multiple framed replies in order" {
  @async.with_task_group(g => {
    let server = GrpcServer::new()
    server.register_server_streaming("/count.C/Up", (_ctx, req) => {
      [req + b"-1", req + b"-2", req + b"-3"]
    })
    let port_18073 = server.bind(port=0).port()
    let task = g.spawn(() => server.serve())
    @async.sleep(300)
    let (status, grpc_status, replies) = streaming_call(
      "127.0.0.1",
      port_18073,
      b"/count.C/Up",
      [b"n"],
    )
    assert_eq(status == b"200", true)
    assert_eq(grpc_status == b"0", true)
    assert_eq(replies.length(), 3)
    assert_eq(replies[0] == b"n-1", true)
    assert_eq(replies[1] == b"n-2", true)
    assert_eq(replies[2] == b"n-3", true)
    task.cancel()
  })
}

///|
async test "client-streaming: a real h2c call sends many messages and gets one reply" {
  @async.with_task_group(g => {
    let server = GrpcServer::new()
    server.register_client_streaming("/sum.S/Add", (_ctx, msgs) => {
      let buf = @buffer.Buffer()
      buf.write_bytes(b"got")
      for m in msgs {
        buf.write_byte(b'/')
        buf.write_bytes(m)
      }
      buf.to_bytes()
    })
    let port_18074 = server.bind(port=0).port()
    let task = g.spawn(() => server.serve())
    @async.sleep(300)
    let (status, grpc_status, replies) = streaming_call(
      "127.0.0.1",
      port_18074,
      b"/sum.S/Add",
      [b"a", b"b", b"c"],
    )
    assert_eq(status == b"200", true)
    assert_eq(grpc_status == b"0", true)
    assert_eq(replies.length(), 1)
    assert_eq(replies[0] == b"got/a/b/c", true)
    task.cancel()
  })
}

///|
async test "bidi-streaming: a real h2c call echoes each message and closes with a farewell" {
  @async.with_task_group(g => {
    let server = GrpcServer::new()
    server.register_bidi("/chat.C/Echo", _ctx => @moonrpc.BidiHandler::{
      on_message: m => [b"re:" + m],
      on_end: () => [b"bye"],
    })
    let port_18075 = server.bind(port=0).port()
    let task = g.spawn(() => server.serve())
    @async.sleep(300)
    let (status, grpc_status, replies) = streaming_call(
      "127.0.0.1",
      port_18075,
      b"/chat.C/Echo",
      [b"one", b"two"],
    )
    assert_eq(status == b"200", true)
    assert_eq(grpc_status == b"0", true)
    // an echo per request, then the farewell from on_end.
    assert_eq(replies.length(), 3)
    assert_eq(replies[0] == b"re:one", true)
    assert_eq(replies[1] == b"re:two", true)
    assert_eq(replies[2] == b"bye", true)
    task.cancel()
  })
}

///|
/// The descriptor of a `greet.Greeter` service, registered with reflection so the
/// in-process client below can discover it over the wire.
fn greet_descriptor() -> @moonrpc.FileDescriptor {
  @moonrpc.FileDescriptor::new(
    "greet.proto",
    "greet",
    messages=[
      @moonrpc.MessageDescriptor::new("HelloRequest", [
        @moonrpc.FieldDescriptor::new("name", 1, TypeString),
      ]),
    ],
    services=[
      @moonrpc.ServiceDescriptor::{
        name: "Greeter",
        methods: [
          @moonrpc.MethodDescriptor::{
            name: "SayHello",
            input_type: ".greet.HelloRequest",
            output_type: ".greet.HelloReply",
            client_streaming: false,
            server_streaming: false,
          },
        ],
      },
    ],
  )
}

///|
/// The end-to-end reflection milestone: a real bidi `ServerReflectionInfo` call
/// over the self-built h2c transport. An in-process reflection client lists the
/// server's services and describes one, receiving the real FileDescriptorProto
/// bytes back over the socket — exactly what `grpcurl list` / `describe` drive.
/// The mutation guard corrupts the transported descriptor and confirms the decode
/// then fails, so the assertions are load-bearing.
async test "reflection: a real h2c bidi call lists and describes a registered service" {
  @async.with_task_group(g => {
    let server = GrpcServer::new()
    server.register("/greet.Greeter/SayHello", req => req)
    let refl = @moonrpc.ReflectionService::new()
    refl.add_file(greet_descriptor())
    server.register_reflection(refl)
    let port_18076 = server.bind(port=0).port()
    let task = g.spawn(() => server.serve())
    @async.sleep(300)
    let refl_path = b"/grpc.reflection.v1.ServerReflection/ServerReflectionInfo"

    // ListServices over the wire.
    let (ls, ls_status, list_replies) = streaming_call(
      "127.0.0.1",
      port_18076,
      refl_path,
      [@moonrpc.encode_reflection_request(ListServices("*"))],
    )
    assert_eq(ls == b"200", true)
    assert_eq(ls_status == b"0", true)
    assert_eq(list_replies.length(), 1)
    match @moonrpc.decode_reflection_response(list_replies[0]) {
      ServiceList(names) => assert_eq(names.contains("greet.Greeter"), true)
      _ => abort("reflection ListServices did not return a service list")
    }

    // FileContainingSymbol over the wire -> a real FileDescriptorProto.
    let (_fs, fs_status, desc_replies) = streaming_call(
      "127.0.0.1",
      port_18076,
      refl_path,
      [
        @moonrpc.encode_reflection_request(
          FileContainingSymbol("greet.Greeter"),
        ),
      ],
    )
    assert_eq(fs_status == b"0", true)
    let protos = match @moonrpc.decode_reflection_response(desc_replies[0]) {
      FileDescriptors(p) => p
      _ => abort("reflection FileContainingSymbol did not return descriptors")
    }
    assert_eq(protos.length(), 1)
    let described = @moonrpc.FileDescriptor::decode(protos[0])
    assert_eq(described.services[0].name == "Greeter", true)
    assert_eq(described.name == "greet.proto", true)

    // MUTATION: corrupt a varint (the first field's length prefix) in the exact
    // bytes that came back over the socket -> the decode that just succeeded fails.
    let arr = protos[0].to_array()
    arr[1] = (0x7F).to_byte()
    let broke = try {
      let _ = @moonrpc.FileDescriptor::decode(Bytes::from_array(arr))
      false
    } catch {
      _ => true
    }
    assert_eq(broke, true)
    task.cancel()
  })
}

///|
/// Graceful shutdown over a real socket: a call that is already running is served to
/// completion, the connection then gets its GOAWAY, `serve` returns on its own, and
/// the port stops accept

///|
/// Graceful shutdown over a real socket: the call already running is served to
/// completion, the connection then gets its GOAWAY and closes, `serve` returns on
/// its own, and the port stops accepting.
async test "graceful_stop drains in-flight calls and releases the port" {
  @async.with_task_group(g => {
    let server = GrpcServer::new()
    server.register("/echo.Echo/Say", req => b"echo:" + req)
    let mut served = false
    let port_18077 = server.bind(port=0).port()
    let task = g.spawn(() => {
      server.serve()
      served = true
    })
    let (status, grpc_status, reply) = unary_call(
      "127.0.0.1", port_18077, b"/echo.Echo/Say", b"qwq",
    )
    assert_eq(status == b"200", true)
    assert_eq(grpc_status == b"0", true)
    assert_eq(reply == b"echo:qwq", true)
    server.graceful_stop(grace=3000)
    @async.sleep(200)
    // The accept loop unwound by itself rather than being cancelled.
    assert_eq(served, true)
    assert_eq(server.live.length(), 0)
    task.cancel()
  })
}

///|
/// A call that is still open when the drain starts is served to completion rather
/// than cut off: the stream is opened, `graceful_stop` runs while it is in flight,
/// and only then does the request body arrive. The reply still comes back OK.
async test "graceful_stop lets a call that is already open finish" {
  @async.with_task_group(g => {
    let server = GrpcServer::new()
    server.register("/echo.Echo/Say", req => b"echo:" + req)
    let port_18079 = server.bind(port=0).port()
    let task = g.spawn(() => server.serve())
    @async.sleep(300)
    let conn = @socket.Tcp::connect(@socket.Addr::parse("127.0.0.1:" + port_18079.to_string()))
    conn.write(@http2.preface)
    conn.write(@http2.Frame::Settings(params=[], ack=false).encode())
    let enc = @hpack.Encoder::new()
    let block = enc.encode([
      { name: b":method", value: b"POST", },
      { name: b":scheme", value: b"http", },
      { name: b":path", value: b"/echo.Echo/Say", },
      { name: b"content-type", value: b"application/grpc", },
      { name: b"te", value: b"trailers", },
    ])
    // HEADERS without END_STREAM: the stream is open and the server is waiting on us.
    conn.write(
      @http2.Frame::Headers(
        stream_id=1,
        fragment=block,
        end_stream=false,
        end_headers=true,
        priority=None,
        padding=0,
      ).encode(),
    )
    @async.sleep(200)
    let drain = g.spawn(() => server.graceful_stop(grace=5000))
    @async.sleep(200)
    // Now finish the request. A server that cut the call off at the drain would have
    // closed this socket already.
    conn.write(
      @http2.Frame::Data(
        stream_id=1,
        data=@moonrpc.encode_message(b"hhh"),
        end_stream=true,
        padding=0,
      ).encode(),
    )
    let dec = @hpack.Decoder::new()
    let mut grpc_status = b""
    let mut body = b""
    let mut done = false
    while !done {
      let frame = read_frame(conn)
      match frame {
        Headers(fragment~, end_stream~, ..) => {
          for h in dec.decode(fragment) {
            if h.name == b"grpc-status" {
              grpc_status = h.value
            }
          }
          if end_stream {
            done = true
          }
        }
        Data(data~, ..) => body = body + data
        _ => ()
      }
    }
    assert_eq(grpc_status == b"0", true)
    let message = match @moonrpc.decode_message(body) {
      Some((_, p)) => p
      None => b""
    }
    assert_eq(message == b"echo:hhh", true)
    conn.close()
    drain.wait()
    task.cancel()
  })
}

///|
/// Open a call carrying `timeout` as its `grpc-timeout`, let `delay` milliseconds of
/// real time pass before finishing the request, and return the `grpc-status` the server
/// answered with. The time is spent by the client, not by a handler: handlers are
/// synchronous, so the only way to spend real time inside a call is to be slow sending
/// it — which is also the shape of the deadline a real client hits.
async fn timed_call(port : Int32, timeout : Bytes, delay : Int32) -> Bytes {
  let conn = @socket.Tcp::connect(
    @socket.Addr::parse("127.0.0.1:" + port.to_string()),
  )
  conn.write(@http2.preface)
  conn.write(@http2.Frame::Settings(params=[], ack=false).encode())
  let enc = @hpack.Encoder::new()
  let block = enc.encode([
    { name: b":method", value: b"POST", },
    { name: b":scheme", value: b"http", },
    { name: b":path", value: b"/slow.S/Wait", },
    { name: b":authority", value: b"127.0.0.1", },
    { name: b"content-type", value: b"application/grpc", },
    { name: b"te", value: b"trailers", },
    { name: b"grpc-timeout", value: timeout, },
  ])
  conn.write(
    @http2.Frame::Headers(
      stream_id=1,
      fragment=block,
      end_stream=false,
      end_headers=true,
      priority=None,
      padding=0,
    ).encode(),
  )
  @async.sleep(delay)
  conn.write(
    @http2.Frame::Data(
      stream_id=1,
      data=@moonrpc.encode_message(b"qwq"),
      end_stream=true,
      padding=0,
    ).encode(),
  )
  let dec = @hpack.Decoder::new()
  let mut grpc_status = b""
  let mut done = false
  while !done {
    match read_frame(conn) {
      Settings(ack~, ..) =>
        if !ack {
          conn.write(@http2.Frame::Settings(params=[], ack=true).encode())
        }
      Headers(fragment~, end_stream~, ..) => {
        for h in dec.decode(fragment) {
          if h.name == b"grpc-status" {
            grpc_status = h.value
          }
        }
        if end_stream {
          done = true
        }
      }
      _ => ()
    }
  }
  conn.close()
  grpc_status
}

///|
async test "a call whose deadline passes on the wire is answered DEADLINE_EXCEEDED" {
  @async.with_task_group(g => {
    let server = GrpcServer::new()
    server.register("/slow.S/Wait", req => req)
    let port_18078 = server.bind(port=0).port()
    let task = g.spawn(() => server.serve())
    @async.sleep(300)
    // 50 ms of deadline, and 250 ms before the request finishes arriving: the engine
    // reads the driver's clock, so the call is over before the handler could run.
    assert_eq(timed_call(port_18078, b"50m", 250) == b"4", true)
    // The same call inside its deadline is served as usual.
    assert_eq(timed_call(port_18078, b"10S", 0) == b"0", true)
    task.cancel()
  })
}

///|
async test "a call left waiting past its deadline is cut off when the connection next speaks" {
  @async.with_task_group(g => {
    let server = GrpcServer::new()
    server.register_client_streaming("/slow.S/Collect", (_ctx, _msgs) => b"done")
    let port_18080 = server.bind(port=0).port()
    let task = g.spawn(() => server.serve())
    @async.sleep(300)
    let conn = @socket.Tcp::connect(@socket.Addr::parse("127.0.0.1:" + port_18080.to_string()))
    conn.write(@http2.preface)
    conn.write(@http2.Frame::Settings(params=[], ack=false).encode())
    let enc = @hpack.Encoder::new()
    let block = enc.encode([
      { name: b":method", value: b"POST", },
      { name: b":scheme", value: b"http", },
      { name: b":path", value: b"/slow.S/Collect", },
      { name: b":authority", value: b"127.0.0.1", },
      { name: b"content-type", value: b"application/grpc", },
      { name: b"te", value: b"trailers", },
      { name: b"grpc-timeout", value: b"50m", },
    ])
    // Open the call and then go quiet: nothing else will ever arrive for this stream.
    conn.write(
      @http2.Frame::Headers(
        stream_id=1,
        fragment=block,
        end_stream=false,
        end_headers=true,
        priority=None,
        padding=0,
      ).encode(),
    )
    @async.sleep(250)
    // Two PINGs the call has nothing to do with. The driver takes each one as its cue to
    // look at the clock, so the expired call is cut off between the two answers.
    conn.write(@http2.Frame::Ping(payload=b"heke1228", ack=false).encode())
    conn.write(@http2.Frame::Ping(payload=b"lfanke00", ack=false).encode())
    let dec = @hpack.Decoder::new()
    let mut grpc_status = b""
    let mut acks = 0
    while acks < 2 {
      match read_frame(conn) {
        Ping(ack~, ..) => if ack { acks = acks + 1 }
        Settings(ack~, ..) =>
          if !ack {
            conn.write(@http2.Frame::Settings(params=[], ack=true).encode())
          }
        Headers(fragment~, ..) =>
          for h in dec.decode(fragment) {
            if h.name == b"grpc-status" {
              grpc_status = h.value
            }
          }
        _ => ()
      }
    }
    assert_eq(grpc_status == b"4", true)
    conn.close()
    task.cancel()
  })
}
