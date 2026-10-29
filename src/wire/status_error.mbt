///|
/// The error a handler raises to answer with a status of its choosing:
/// grpc-go's `status.Error`. A typed handler turns it into the call's
/// `grpc-status` and `grpc-message`.
pub(all) suberror StatusError {
  StatusError(Status, String)
}

///|
pub impl Show for StatusError with fn output(self, logger) {
  let StatusError(status, message) = self
  logger.write_string(status.name() + ": " + message)
}

///|
pub extend StatusError with Show::{to_string, output}
