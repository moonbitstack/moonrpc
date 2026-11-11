// The native Thrift driver: TFramedTransport over a TCP socket, the mirror of the
// gRPC driver but with no HTTP/2 in between. The protocols and the processor live in
// `thrift/` and are pure; this file only moves frames.

///|
/// A Thrift client over one connection: one round trip per call, in whichever transport and
/// protocol it was handed.
pub struct ThriftClient {
  conn : @tcp.Conn
  proto : &@thrift.Protocol
  host : String
  wire : ThriftWire
  // The compressor and the decompressor a zlib connection needs, and the bytes of a reply
  // that arrived but were not part of the first message in them. A framed connection uses
  // neither: its reply is exactly one message.
  zlib_out : ZlibOut?
  zlib_in : ZlibIn?
  pending : @buffer.Buffer
  // The messages a compressed chunk carried beyond the one asked for.
  ready : Array[Bytes]
}

///|
/// Connect to a Thrift server at `host:port`, speaking `proto` over `wire`. The protocol
/// carries the connection's state — a compact reader's field-id deltas, a binary reader's
/// cursor — so it belongs to the client, not to each call.
pub async fn ThriftClient::connect(
  host : String,
  port : Int32,
  proto : &@thrift.Protocol,
  wire~ : ThriftWire = Framed,
) -> ThriftClient {
  let compressed = wire is Zlib
  {
    conn: @tcp.dial(host, port~),
    proto,
    host,
    wire,
    zlib_out: if compressed {
      Some(ZlibOut::new())
    } else {
      None
    },
    zlib_in: if compressed {
      Some(ZlibIn::new())
    } else {
      None
    },
    pending: @buffer.Buffer(),
    ready: [],
  }
}

///|
/// Close the underlying connection.
pub fn ThriftClient::close(self : ThriftClient) -> Unit {
  self.conn.close()
}

///|
pub impl @thrift.Transport for ThriftClient with fn round_trip(self, body) {
  self.exchange(body)
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
  serve_framed(conn, processor, make) catch {
    _ => ()
  }
}

///|
/// A ONEWAY call writes its message and returns: there is no reply to wait for, and waiting
/// for one would block until the peer closed. A POST still has an answer to read — the HTTP
/// exchange has to be finished or the next call would read this one's reply — so it is read
/// and dropped.
pub impl @thrift.Transport for ThriftClient with fn send(self, body) {
  match self.wire {
    Http => ignore(self.post(body))
    Zlib => {
      let compressed = match self.zlib_out {
        Some(deflater) => deflater.write(body)
        None => raise @thrift.Malformed("this client has no compressor")
      }
      self.conn.write(compressed) catch {
        _ => raise @thrift.Truncated
      }
    }
    Framed =>
      self.conn.write(@thrift.frame(body)) catch {
        _ => raise @thrift.Truncated
      }
    Buffered => self.conn.write(body) catch { _ => raise @thrift.Truncated }
  }
}

///|
pub extend ThriftClient with @thrift.Transport::{round_trip, send}
