///|
/// Somewhere handlers are registered by path: grpc-go's `ServiceRegistrar`.
/// The in-memory engine and the native server both are, so a generated
/// service registers on either.
pub(open) trait Registrar {
  fn register_handler(Self, String, Handler) -> Unit
}
