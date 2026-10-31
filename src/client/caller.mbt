///|
/// What a generated client stub calls through: something that sends `requests`
/// on `path` with `metadata`, half-closes, and returns how the call ended, under
/// an optional deadline in milliseconds and retry policy. The native `Channel`,
/// `ManagedChannel` and `MuxChannel` implement it; a test double or an
/// interceptor chain implements it to stand in their place, as tonic's
/// `GrpcService` does.
pub(open) trait Caller {
  async fn invoke(
    Self,
    String,
    Array[Bytes],
    Array[@header.Header],
    Int32?,
    @balance.Retry?,
  ) -> CallReply
}

///|
/// The reply messages of a call that ended `OK`. Any other status is raised as a
/// `StatusError` with the server's message; a 200 that ended without a
/// `grpc-status` is `INTERNAL`, as grpc-go reports it.
pub fn CallReply::ok(self : CallReply) -> Array[Bytes] raise @wire.StatusError {
  match self.grpc_status {
    0 => self.messages
    -1 =>
      raise @wire.StatusError(
        Internal,
        "server closed the stream without sending trailers",
      )
    code => raise @wire.StatusError(@wire.Status::of(code), self.grpc_message)
  }
}

///|
/// The one reply message of a unary or client-streaming call that ended `OK`.
/// None or more than one is `INTERNAL`, with grpc-go's cardinality messages.
pub fn CallReply::one(self : CallReply) -> Bytes raise @wire.StatusError {
  match self.ok() {
    [m] => m
    [] =>
      raise @wire.StatusError(
        Internal,
        "cardinality violation: received no response message from non-server-streaming RPC",
      )
    _ =>
      raise @wire.StatusError(
        Internal,
        "cardinality violation: expected <EOF> for non server-streaming RPCs, but received another message",
      )
  }
}

///|
/// A reply message decoded, or `INTERNAL` when it does not decode, as grpc-go
/// reports it.
fn[T : @proto.Message] received(body : Bytes) -> T raise @wire.StatusError {
  T::decode(body) catch {
    e =>
      raise @wire.StatusError(
        Internal,
        "grpc: failed to unmarshal the received message: \{e}",
      )
  }
}

///|
/// `one()`, decoded: the reply of a unary or client-streaming call.
pub fn[T : @proto.Message] CallReply::reply(
  self : CallReply,
) -> T raise @wire.StatusError {
  received(self.one())
}

///|
/// `ok()`, decoded: the replies of a server-streaming or bidirectional call.
pub fn[T : @proto.Message] CallReply::replies(
  self : CallReply,
) -> Array[T] raise @wire.StatusError {
  let out = []
  for body in self.ok() {
    out.push(received(body))
  }
  out
}
