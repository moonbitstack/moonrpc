// The stats observable, mirroring grpc-go's `stats` package: a handler a channel or
// a server calls at each point of an RPC's life. The events are the transport-level
// facts both engines already know — when a call begins, each header and payload that
// moves, and how it ended — so a handler can meter or trace without touching the
// wire. Pure: the engines call it inline, so it runs on every backend.

///|
/// One RPC lifecycle event. The same shape serves the client and the server, the way
/// grpc-go's `stats.RPCStats` does: `In*` is what arrived, `Out*` what was sent.
pub(all) enum RpcStats {
  /// A call began: its `path` (`/pkg.Service/Method`) and `name` (`Method`).
  Begin(path~ : String, name~ : String)
  /// Response initial metadata arrived (client) or the request's did (server).
  InHeader(metadata~ : Array[@header.Header])
  /// Request metadata went out (client) or the response's did (server).
  OutHeader(metadata~ : Array[@header.Header])
  /// One message arrived, of `length` payload octets.
  InPayload(length~ : Int32)
  /// One message went out, of `length` payload octets.
  OutPayload(length~ : Int32)
  /// Trailing metadata arrived.
  InTrailer(metadata~ : Array[@header.Header])
  /// Trailing metadata went out.
  OutTrailer(metadata~ : Array[@header.Header])
  /// The call ended with `status` and the peer's `message`.
  End(status~ : Status, message~ : String)
}

///|
/// A connection lifecycle event, the coarser grain grpc-go reports alongside RPCs.
pub(all) enum ConnStats {
  ConnBegin
  ConnEnd
}

///|
/// A sink for the events a channel or a server observes. Register one with
/// `H2Client::set_stats_handler` or `H2Server::set_stats_handler`; every call on
/// that connection reports to it. A [`Handler`] is a pair of functions, as the
/// other callbacks in this library are, so a caller can build one from closures.
pub(all) struct Handler {
  rpc : (RpcStats) -> Unit
  conn : (ConnStats) -> Unit
}

///|
/// A handler from its two callbacks; `conn` may be left out when only RPCs matter.
pub fn Handler::new(
  rpc~ : (RpcStats) -> Unit,
  conn? : (ConnStats) -> Unit,
) -> Handler {
  { rpc, conn: conn.unwrap_or(_ => ()), }
}
