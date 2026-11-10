// TLS for the gRPC port. HTTP/2 over TLS is chosen by ALPN, so both ends name `h2` and
// check what the handshake settled on before a frame is exchanged (RFC 9113 §3.2): a
// client that picked no protocol, or `http/1.1`, is not spoken to in HTTP/2, since a
// version-agnostic client would then read binary frames as an HTTP/1 response.

///|
/// The ALPN protocol identifier HTTP/2 answers to (RFC 9113 §3.1) — the only one this
/// client and server speak over TLS.
pub let alpn_h2 : String = "h2"

///|
/// A gRPC client's TLS configuration: `roots` are the trust anchors, and `protocols` is
/// what the client offers, `h2` alone unless a caller has reason to offer more.
pub fn client_tls(
  roots : @x509.Roots,
  protocols~ : Array[String] = [alpn_h2],
) -> @tls.Client {
  @tls.Client::new(roots, alpn=protocols)
}

///|
/// A gRPC server's TLS configuration: `chain` is the certificate chain, leaf first, and
/// `key` its key. `protocols` is what the server accepts, `h2` alone unless told otherwise.
pub fn server_tls(
  chain : Array[Bytes],
  key : @x509.PrivateKey,
  protocols~ : Array[String] = [alpn_h2],
) -> @tls.Server raise {
  @tls.Server::new(chain, key, alpn=protocols)
}

///|
/// Whether a connection's handshake settled on something other than HTTP/2. A plain
/// connection never does — there is nothing to negotiate — so only a TLS one can fail here.
fn unnegotiated(conn : @tcp.Conn) -> Bool {
  conn.is_tls() && conn.alpn() != Some(alpn_h2)
}

///|
/// Dial `host:port`, presenting `name` to TLS when one is given. The name is what the
/// ClientHello carries as SNI and what the certificate is checked against, which is how a
/// client reaches an address it resolved but a service it names — the shape a service mesh
/// or a DNS-discovered backend needs, and the reason the address and the name are two
/// parameters rather than one.
async fn dial(
  host : String,
  port : Int32,
  tls? : @tls.Client,
  name? : String,
) -> @tcp.Conn {
  match (tls, name) {
    (Some(config), Some(name)) => {
      let sock = @socket.Tcp::connect_to_host(host, port~)
      @tcp.Conn::client(sock, config, name)
    }
    _ => @tcp.dial(host, port~, tls?)
  }
}
