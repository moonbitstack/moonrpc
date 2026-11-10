// The native tRPC driver: the protocol stack in `trpc/` over a TCP socket. One frame at a
// time in each direction, which is all the protocol asks of a connection.

///|
/// A client-side link: one connection, frames taken in the order they arrive.
pub struct TrpcChannel {
  conn : @tcp.Conn
}

///|
pub async fn TrpcChannel::connect(
  host : String,
  port : Int32,
  tls? : @tls.Client,
) -> TrpcChannel {
  { conn: @tcp.dial(host, port~, tls?), }
}

///|
pub fn TrpcChannel::close(self : TrpcChannel) -> Unit {
  self.conn.close()
}

///|
pub impl @trpc.Link for TrpcChannel with fn write(self, bytes) {
  self.conn.write(bytes) catch {
    _ => raise @trpc.Truncated
  }
}

///|
pub impl @trpc.Link for TrpcChannel with fn read(self) {
  read_trpc_frame(self.conn)
}

///|
pub extend TrpcChannel with @trpc.Link::{read, write}

///|
/// Take one frame: the fixed head first, so the length it announces can be read in one
/// go rather than byte by byte.
async fn read_trpc_frame(conn : @tcp.Conn) -> @trpc.Frame raise @trpc.TrpcError {
  let head = conn.read_exactly(@trpc.head_len) catch {
    _ => raise @trpc.Truncated
  }
  let total = @trpc.Frame::announced_len(head)
  let rest = conn.read_exactly(total - @trpc.head_len) catch {
    _ => raise @trpc.Truncated
  }
  let whole = @buffer.Buffer()
  whole.write_bytes(head)
  whole.write_bytes(rest)
  let (frame, _) = @trpc.Frame::decode(whole.to_bytes())
  frame
}

///|
/// Bind the socket a tRPC server accepts on. Port 0 asks the system for one, and the
/// address this returns is the one to dial.
pub async fn bind_trpc(
  host~ : String = "127.0.0.1",
  port~ : Int32 = 12000,
) -> @tcp.Listener {
  @tcp.listen(host~, port~)
}

///|
/// Serve `server` on `host:port` until the running task is cancelled.
pub async fn serve_trpc(
  host~ : String = "127.0.0.1",
  port~ : Int32 = 12000,
  server : @trpc.Server,
) -> Unit {
  serve_trpc_on(bind_trpc(host~, port~), server)
}

///|
/// Serve on a socket already bound — the form a caller needs when it must learn the port
/// before the accept loop starts.
pub async fn serve_trpc_on(
  listener : @tcp.Listener,
  server : @trpc.Server,
) -> Unit {
  @async.with_task_group(group => {
    for ;; {
      let (conn, _) = listener.accept() catch { _ => continue }
      group.spawn_bg(allow_failure=true, () => {
        defer conn.close()
        serve_trpc_connection(conn, server) catch {
          _ => ()
        }
      })
    }
  })
}

///|
async fn serve_trpc_connection(
  conn : @tcp.Conn,
  server : @trpc.Server,
) -> Unit raise @trpc.TrpcError {
  let session = @trpc.Session::new(server)
  for ;; {
    let frame = read_trpc_frame(conn)
    for reply in session.handle(frame) {
      conn.write(reply) catch {
        _ => raise @trpc.Truncated
      }
    }
  }
}
