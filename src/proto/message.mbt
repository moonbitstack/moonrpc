///|
/// A protobuf message: prost's `Message`. The `#rpc` generator writes it for
/// each `#rpc.message` struct; a type of the program's own implements the two
/// methods to travel as a request or a reply.
pub(open) trait Message {
  fn encode(Self) -> Bytes
  fn decode(Bytes) -> Self raise PbError
}

///|
/// A protobuf enum: its number on the wire and back. The `#rpc` generator
/// writes it for each `#rpc.enum`; `of` gives the zero value, or the
/// constructor that keeps it, for a number the enum does not know.
pub(open) trait Enum {
  fn code(Self) -> Int32
  fn of(Int32) -> Self
}
