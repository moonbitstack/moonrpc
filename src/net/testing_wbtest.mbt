// Test support: how a test that must not name a port gets one. Every test here binds port 0
// and reads back what the system chose, so parallel runs never fight over a number; the one
// case that cannot is a test that needs a connection *refused* before its server exists.

///|
/// A port nothing is listening on any more, for a test whose first call must be refused a
/// connection and whose server only starts later. A probe socket asks the system for a free
/// number and closes at once; the test then binds that number when its server is due, so the
/// two halves of the test agree without either of them naming a port.
async fn closed_port() -> Int32 {
  let probe = @tcp.listen(port=0)
  let p = probe.addr().port()
  probe.close()
  p
}
