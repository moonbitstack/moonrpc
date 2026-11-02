// The rich half of an error as it leaves the server: a handler that fails with an `Any`
// detail, and the trailer a caller reads it back from.

///|
/// The `grpc-status-details-bin` trailer of a run of frames, decoded from base64.
fn details_trailer(out : Array[@http2.Frame]) -> Bytes? {
  let dec = @hpack.Decoder::new()
  for f in out {
    if f is Headers(fragment~, ..) {
      let headers = dec.decode(fragment) catch {
        _ => abort("bad header block")
      }
      for h in headers {
        if h.name == b"grpc-status-details-bin" {
          return Some(@wire.metadata_value_from_wire(h.name, h.value))
        }
      }
    }
  }
  None
}

///|
test "rich errors: a detail a handler attaches rides the trailers of its call" {
  let engine = H2Server::new()
  let badge = @proto.PbWriter::new()
  badge.string_(1, "denied")
  let any = @proto.PbWriter::new()
  any.string_(1, "type.googleapis.com/greet.Badge")
  any.bytes_(2, badge.to_bytes())
  engine.register_unary("/gate.G/Open", (ctx, _req) => {
    ctx.fail(@wire.Status::code(PermissionDenied), "no token")
    ctx.add_error_detail(any.to_bytes())
    b""
  })
  let enc = @hpack.Encoder::new()
  let block = req_block(enc, b"/gate.G/Open")
  let _ = engine.feed(Settings(params=[], ack=false))
  let _ = engine.feed(
    Headers(
      stream_id=1,
      fragment=block,
      end_stream=false,
      end_headers=true,
      priority=None,
      padding=0,
    ),
  )
  let out = engine.feed(
    Data(
      stream_id=1,
      data=@wire.encode_message(b"x"),
      end_stream=true,
      padding=0,
    ),
  )
  let packed = details_trailer(out).unwrap()
  // The trailer is a `google.rpc.Status` naming the status and carrying the Any whole.
  let details = @proto.decode_status_details(packed[:]).unwrap()
  assert_eq(details.code, @wire.Status::code(PermissionDenied))
  assert_eq(details.message, "no token")
  assert_eq(details.details.length(), 1)
  assert_eq(
    @proto.detail_type_url(details.details[0][:]).unwrap(),
    "type.googleapis.com/greet.Badge",
  )
  let body = @proto.detail_body(details.details[0][:]).unwrap()
  let reader = @proto.PbReader::new(body)
  let (_field, _wire) = reader.read_tag()
  assert_eq(reader.read_string(), "denied")
}

///|
test "rich errors: a failing call with no details still carries its status" {
  let engine = H2Server::new()
  engine.register_unary("/gate.G/Open", (ctx, _req) => {
    ctx.fail(@wire.Status::code(NotFound), "gone")
    b""
  })
  let enc = @hpack.Encoder::new()
  let block = req_block(enc, b"/gate.G/Open")
  let _ = engine.feed(Settings(params=[], ack=false))
  let _ = engine.feed(
    Headers(
      stream_id=1,
      fragment=block,
      end_stream=false,
      end_headers=true,
      priority=None,
      padding=0,
    ),
  )
  let out = engine.feed(
    Data(
      stream_id=1,
      data=@wire.encode_message(b"x"),
      end_stream=true,
      padding=0,
    ),
  )
  let details = @proto.decode_status_details(details_trailer(out).unwrap()[:]).unwrap()
  assert_eq(details.code, @wire.Status::code(NotFound))
  assert_eq(details.message, "gone")
  assert_eq(details.details.length(), 0)
}
