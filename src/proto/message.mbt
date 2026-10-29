///|
/// A protobuf message: prost's `Message`. The `#rpc` generator writes it for
/// each `#rpc.message` struct; a type of the program's own implements the two
/// methods to travel as a request or a reply.
pub(open) trait Message {
  fn encode(Self) -> Bytes
  fn decode(Bytes) -> Self raise PbError
}
