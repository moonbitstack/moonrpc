// The client half of rich errors: the trailer a non-OK call carries, read back into the
// status the server packed.

///|
test "client details: a grpc-status-details-bin trailer decodes to its status" {
  let any = @proto.PbWriter::new()
  any.string_(1, "type.googleapis.com/greet.Badge")
  any.bytes_(2, b"\x0a\x06denied")
  let packed = @proto.PbWriter::new()
  packed.int32(1, 7)
  packed.string_(2, "no token")
  packed.message_(3, any.to_bytes())
  let reply : CallReply = {
    status: b"200",
    grpc_status: 7,
    grpc_message: "no token",
    headers: [],
    messages: [],
    trailers: [
      {
        name: b"grpc-status-details-bin",
        value: @wire.metadata_value_to_wire(
          b"grpc-status-details-bin",
          packed.to_bytes(),
        ),
      },
    ],
    committed: true,
    unprocessed: false,
  }
  let details = reply.details().unwrap()
  assert_eq(details.code, 7)
  assert_eq(details.message, "no token")
  assert_eq(details.details.length(), 1)
  assert_eq(
    @proto.detail_type_url(details.details[0][:]).unwrap(),
    "type.googleapis.com/greet.Badge",
  )
  assert_eq(
    @proto.detail_body(details.details[0][:]).unwrap(),
    b"\x0a\x06denied",
  )
}

///|
test "client details: a call with no details trailer has none to read" {
  let reply : CallReply = {
    status: b"200",
    grpc_status: 5,
    grpc_message: "gone",
    headers: [],
    messages: [],
    trailers: [{ name: b"grpc-status", value: b"5", }],
    committed: true,
    unprocessed: false,
  }
  assert_eq(reply.details(), None)
}

///|
test "client details: a trailer that does not decode is no detail, not a panic" {
  let reply : CallReply = {
    status: b"200",
    grpc_status: 13,
    grpc_message: "",
    headers: [],
    messages: [],
    trailers: [
      { name: b"grpc-status-details-bin", value: b"bm90IGEgc3RhdHVz", },
    ],
    committed: true,
    unprocessed: false,
  }
  assert_eq(reply.details(), None)
}
