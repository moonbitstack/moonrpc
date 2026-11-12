// The reference service, served the way the conformance suite starts a server under test: the
// suite launches this process, and the process answers by writing a `ServerCompatResponse` —
// the host and the port it bound — to standard output, behind a four-octet big-endian length.
//
// The suite's request is not read. It says which protocol and HTTP version to support, and this
// server supports all of them on one listener: whether a connection speaks HTTP/1.1 or HTTP/2 is
// decided from its first octets. The `client` argument selects the other half, whose entry
// point is in `client.mbt`.

///|
fn main {
  // `client` is the half the suite drives by writing one request per case to standard input;
  // anything else is the server half, which announces the port it bound and then serves.
  for arg in @env.args() {
    if arg == "client" {
      client_main()
      return
    }
  }
  @async.run_async_main(() => {
    // The server half reads the suite's handshake: whether this run is over TLS, and the
    // certificate and key to serve with. The client half never reads it.
    let handshake = read_delimited() catch { _ => None }
    let (use_tls, cert_pem, key_pem) = match handshake {
      Some(bytes) => read_server_request(bytes) catch { _ => (false, "", "") }
      None => (false, "", "")
    }
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
    let tls : @tls.Server? = if use_tls &&
      cert_pem.length() > 0 &&
      key_pem.length() > 0 {
      let chain = @x509.pems(cert_pem) catch {
        e => {
          println("the TLS certificate did not parse: " + e.to_string())
          return
        }
      }
      let key = @x509.PrivateKey::pem(key_pem) catch {
        e => {
          println("the TLS key did not parse: " + e.to_string())
          return
        }
      }
      Some(
        @net.server_tls(chain, key, protocols=["h2", "http/1.1"]) catch {
          e => {
            println("TLS could not be set up: " + e.to_string())
            return
          }
        },
      )
    } else {
      None
    }
    let address = server.bind(host="127.0.0.1", port=0, tls?)
    let port = address.port()
    announce(port, if use_tls { cert_pem } else { "" }) catch {
      e => {
        println("cannot report the port: " + e.to_string())
        return
      }
    }
    server.serve()
  })
}

///|
/// The three things the server half needs from a `ServerCompatRequest`: whether to use TLS,
/// and the PEM certificate and key the suite provided for it.
fn read_server_request(bytes : Bytes) -> (Bool, String, String) raise {
  let reader = @proto.PbReader::new(bytes)
  let mut use_tls = false
  let mut cert = ""
  let mut key = ""
  while !reader.eof() {
    let (field, wire) = reader.read_tag() catch { _ => break }
    match field {
      4 => use_tls = reader.read_varint().to_int() != 0
      7 => {
        let creds = reader.read_len_delim() catch { _ => b"" }
        let inner = @proto.PbReader::new(creds)
        while !inner.eof() {
          let (part, part_wire) = inner.read_tag() catch { _ => break }
          match part {
            1 =>
              cert = @utf8.decode_lossy(
                inner.read_len_delim() catch {
                  _ => b""
                },
              )
            2 =>
              key = @utf8.decode_lossy(
                inner.read_len_delim() catch {
                  _ => b""
                },
              )
            _ => inner.skip(part_wire) catch { _ => () }
          }
        }
      }
      _ => reader.skip(wire) catch { _ => () }
    }
  }
  (use_tls, cert, key)
}

///|
/// Tell the suite where to connect: a `ServerCompatResponse` with `host` in field 1 and `port`
/// in field 2, behind the fixed-width length the suite's reader takes.
async fn announce(port : Int32, cert_pem : String) -> Unit {
  let body = @proto.PbWriter::new()
  body.string_(1, "127.0.0.1")
  body.uint32(2, port.reinterpret_as_uint())
  if cert_pem.length() > 0 {
    body.bytes_(3, @utf8.encode(cert_pem))
  }
  let message = body.to_bytes()
  // The port goes to standard output as bytes, not text: the length in front of the message is
  // binary, and `@fs` has no portable name for the stream this process was started with.
  @stdio.stdout.write(delimited(message))
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
