// The reference service, served the way the conformance suite starts a server under test: the
// suite launches this process, and the process answers by writing a `ServerCompatResponse` —
// the host and the port it bound — to standard output, delimited by a varint length.
//
// The suite's request is not read. It says which protocol and HTTP version to support, and this
// server supports all of them on one listener: whether a connection speaks HTTP/1.1 or HTTP/2 is
// decided from its first octets.

///|
fn main {
  @async.run_async_main(() => {
    let service = @reference.Service::new() catch {
      e => {
        println("the conformance definitions do not compile: " + e.to_string())
        return
      }
    }
    let server = @net.ConnectServer::new(schema=service.schema())
    for route in service.routes() {
      server.add(route.0, route.1)
    }
    let address = server.bind(host="127.0.0.1", port=0)
    let port = address.port()
    announce(port) catch {
      e => {
        println("cannot report the port: " + e.to_string())
        return
      }
    }
    server.serve()
  })
}

///|
/// Tell the suite where to connect: a `ServerCompatResponse` with `host` in field 1 and `port`
/// in field 2, behind a varint length.
async fn announce(port : Int32) -> Unit {
  let body = @proto.PbWriter::new()
  body.string_(1, "127.0.0.1")
  body.uint32(2, port.reinterpret_as_uint())
  let message = body.to_bytes()
  let out = @fs.open("/dev/stdout", mode=@fs.WriteOnly)
  defer out.close()
  out.write(delimited(message))
}

///|
/// A message behind a four-octet big-endian length, which is the framing the suite's handshake
/// uses — the same one protobuf's `writeDelimitedTo` writes in Java and Go's `WriteDelimitedMessage`
/// reads here. It is not a varint: the reader takes the first four octets as a fixed-width
/// integer, so a varint prefix is read as a length in the hundreds of megabytes.
fn delimited(message : Bytes) -> Bytes {
  let out = @buffer.Buffer()
  let length = message.length()
  out.write_byte(((length >> 24) & 0xFF).to_byte())
  out.write_byte(((length >> 16) & 0xFF).to_byte())
  out.write_byte(((length >> 8) & 0xFF).to_byte())
  out.write_byte((length & 0xFF).to_byte())
  out.write_bytes(message)
  out.to_bytes()
}
