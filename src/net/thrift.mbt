// The native Thrift driver: TFramedTransport over a TCP socket, the mirror of the
// gRPC driver but with no HTTP/2 in between. The protocols and the processor live in
// `thrift/` and are pure; this file only moves frames.

///|
/// A Thrift client over one connection: a framed round trip per call, in whichever
/// protocol it was handed.
pub struct ThriftClient {
  conn : @tcp.Conn
  proto : &@thrift.Protocol
}

///|
/// Connect to a Thrift server at `host:port`, speaking `proto`. The protocol carries the
/// connection's state — a compact reader's field-id deltas, a binary reader's cursor —
/// so it belongs to the client, not to each call.
pub async fn ThriftClient::connect(
  host : String,
  port : Int32,
  proto : &@thrift.Protocol,
) -> ThriftClient {
  { conn: @tcp.dial(host, port~), proto, }
}

///|
/// Close the underlying connection.
pub fn ThriftClient::close(self : ThriftClient) -> Unit {
  self.conn.close()
}

///|
/// Write one framed body and return, for a ONEWAY call that has no reply to wait for.
pub async fn ThriftClient::send(
  self : ThriftClient,
  body : Bytes,
) -> Unit raise @thrift.ThriftError {
  self.conn.write(@thrift.frame(body)) catch {
    _ => raise @thrift.Truncated
  }
}

///|
pub impl @thrift.Transport for ThriftClient with fn round_trip(self, body) {
  self.send(body)
  let head = self.conn.read_exactly(4) catch { _ => raise @thrift.Truncated }
  let len = @thrift.frame_len(head) catch { _ => raise @thrift.Truncated }
  if len < 0 || len > @thrift.max_frame {
    raise @thrift.Application("frame too large")
  }
  self.conn.read_exactly(len) catch {
    _ => raise @thrift.Truncated
  }
}

///|
/// Bind the listening socket a Thrift server will accept on, and report the address — with
/// port 0, the one the system picked. Connections queue from the moment this returns, so a
/// caller may dial before [`serve_thrift_on`] has reached its accept loop.
pub async fn bind_thrift(
  host~ : String = "127.0.0.1",
  port~ : Int32 = 9090,
) -> @tcp.Listener {
  @tcp.listen(host~, port~)
}

///|
/// Serve `processor` on `host:port` until the listener fails, speaking whichever
/// protocol `make` builds. Each connection gets its own protocol object and its own
/// task, so one slow method does not hold up the others.
pub async fn[P : @thrift.Protocol] serve_thrift(
  host~ : String = "127.0.0.1",
  port~ : Int32 = 9090,
  processor : @thrift.Processor,
  make : () -> P,
) -> Unit {
  serve_thrift_on(bind_thrift(host~, port~), processor, make)
}

///|
/// Serve on a socket that is already bound — the form a caller needs when it must learn the
/// port before the accept loop starts.
pub async fn[P : @thrift.Protocol] serve_thrift_on(
  listener : @tcp.Listener,
  processor : @thrift.Processor,
  make : () -> P,
) -> Unit {
  @async.with_task_group(group => {
    for ;; {
      let (conn, _) = listener.accept() catch { _ => continue }
      group.spawn_bg(allow_failure=true, () => {
        defer conn.close()
        serve_connection(conn, processor, make) catch {
          _ => ()
        }
      })
    }
  })
}

///|
async fn[P : @thrift.Protocol] serve_connection(
  conn : @tcp.Conn,
  processor : @thrift.Processor,
  make : () -> P,
) -> Unit {
  let proto : &@thrift.Protocol = make()
  for ;; {
    let head = conn.read_exactly(4) catch { _ => break }
    let len = @thrift.frame_len(head)
    if len < 0 || len > @thrift.max_frame {
      break
    }
    let body = conn.read_exactly(len)
    let reply = processor.process(proto, body)
    if reply.length() > 0 {
      conn.write(@thrift.frame(reply))
    }
  }
}

///|
pub extend ThriftClient with @thrift.Transport::{round_trip}
