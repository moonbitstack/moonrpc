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
/// A message with its length in front, which is the framing the suite's handshake uses.
fn delimited(message : Bytes) -> Bytes {
  let out = @buffer.Buffer()
  let mut length = message.length().reinterpret_as_uint()
  while length >= 0x80U {
    out.write_byte(((length & 0x7FU).reinterpret_as_int() | 0x80).to_byte())
    length = length >> 7
  }
  out.write_byte(length.reinterpret_as_int().to_byte())
  out.write_bytes(message)
  out.to_bytes()
}
