///|
/// Register `service` on a fresh pure server, call `path` with `request`, and return
/// the first reply message. Frames are shuttled between the two engines until the
/// call finishes, as the other examples do.
pub fn round_trip(
  register : (@moonrpc.H2Server) -> Unit,
  path : String,
  request : Bytes,
) -> Bytes raise {
  let server = @moonrpc.H2Server::new()
  register(server)
  let client = @moonrpc.H2Client::new()
  let (id, initial) = client.unary(path, request)
  let to_server : Array[@http2.Frame] = []
  let to_client : Array[@http2.Frame] = []
  to_server.append(client.preface())
  to_client.append(server.preface())
  to_server.append(initial)
  let mut si = 0
  let mut ci = 0
  let mut steps = 0
  while !client.is_done(id) && steps < 100000 {
    steps = steps + 1
    if si < to_server.length() {
      let f = to_server[si]
      si = si + 1
      to_client.append(server.feed(f))
    } else if ci < to_client.length() {
      let f = to_client[ci]
      ci = ci + 1
      to_server.append(client.feed(f))
    } else {
      break
    }
  }
  client.reply(id).messages[0]
}
