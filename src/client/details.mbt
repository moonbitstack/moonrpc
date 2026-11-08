// Reading the rich half of an error: the `google.rpc.Status` a server packs into
// `grpc-status-details-bin`, which carries the `Any` details a plain `grpc-status` cannot.

///|
/// The `google.rpc.Status` this call ended with, when the server sent one in
/// `grpc-status-details-bin`; `None` when it sent none, or when the trailer does not decode.
/// The status itself is still in `grpc_status` and `grpc_message`: a detail a client cannot
/// read is no reason to lose the error it came with.
pub fn CallReply::details(self : CallReply) -> @proto.StatusDetails? {
  for h in self.trailers {
    if h.name == b"grpc-status-details-bin" {
      // `trailers` already holds the decoded bytes: the reply reader applies the `-bin`
      // base64 to every binary value as the block arrives. Decoding it again here reads the
      // protobuf body as if it were base64 text, which decodes to nothing — the trailer is
      // there, and the status inside it is not.
      return @proto.decode_status_details(h.value[:])
    }
  }
  None
}
