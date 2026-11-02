// The standard health service on a real server: `Check` answers once, and `Watch` is a
// pushed method — the status at subscribe time, then again every time it changes, for as
// long as the caller keeps the stream open.

///|
/// How often a `Watch` looks at the status table. The service holds no notification to
/// hand out, so the watch loop reads it on a clock; ten milliseconds is well under the
/// notice any health consumer needs, and costs one comparison per watch.
let health_poll_millis : Int32 = 10

///|
/// Register the `grpc.health.v1.Health` service (Check + Watch) on this server. `Check` is
/// the unary method the service defines; `Watch` is pushed, since a real watch reports
/// every change for as long as it is open rather than answering once.
pub fn GrpcServer::register_health(
  self : GrpcServer,
  health : @moonrpc.HealthService,
) -> Unit {
  for entry in health.handlers() {
    // Watch is re-registered below as a pushed method; registering the eager one first
    // and replacing it keeps the service's own definition of the two paths in one place.
    guard entry.0 != @moonrpc.health_watch_path else { continue }
    self.handlers[entry.0] = entry.1
  }
  self.register_handler(
    @moonrpc.health_watch_path,
    Pushed((_ctx, requests, out) => {
      // A watch names its service in the one request message that opened it.
      let request = if requests.length() > 0 { requests[0] } else { b"" }
      let service = @utf8.decode_lossy(@moonrpc.decode_health_request(request))
      let mut last : @moonrpc.ServingStatus? = None
      // The first status goes out at once — a watcher is told where things stand before
      // it is told about any change — and then one message per change.
      for ;; {
        let now = health.check(service)
        if last != Some(now) {
          (out.send)([@moonrpc.encode_health_response(now)])
          last = Some(now)
        }
        @async.sleep(health_poll_millis)
      }
    }),
  )
}
