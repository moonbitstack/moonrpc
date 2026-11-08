// The header transport, checked against the frames Apache Thrift's Go implementation writes
// for the same messages — the bytes are the specification, and a reader that agrees with them
// agrees with every implementation that follows it.

///|
/// Hex to bytes, for the reference frames below.
fn unhex(text : String) -> Bytes {
  let digits = "0123456789abcdef"
  let out = @buffer.Buffer()
  let mut hi = -1
  for ch in text {
    let v = digits.find(ch.to_string())
    match v {
      Some(d) =>
        if hi < 0 {
          hi = d
        } else {
          out.write_byte(((hi << 4) | d).to_byte())
          hi = -1
        }
      None => ()
    }
  }
  out.to_bytes()
}

///|
fn to_hex(data : Bytes) -> String {
  let digits = [
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f",
  ]
  let mut out = ""
  for i = 0; i < data.length(); i = i + 1 {
    let b = data[i].to_int()
    out = out + digits[b >> 4] + digits[b & 0xF]
  }
  out
}

///|
/// The message every reference frame below carries: `ping(42)` as CALL, sequence id 7.
fn ping_message(proto : &Protocol) -> Unit {
  proto.write_message_begin("ping", message_call, 7)
  proto.write_struct_begin("ping_args")
  proto.write_field_begin(type_i32, 1)
  proto.write_i32(42)
  proto.write_field_stop()
  proto.write_struct_end()
}

///|
/// Frame the way the socket driver does, so what is compared is what goes on the wire.
fn framed(body : Bytes) -> Bytes {
  frame(body)
}

///|
test "thrift header: our binary frame is Apache's, byte for byte" {
  let header = Header::new()
  let writer : &Protocol = header
  ping_message(writer)
  let ours = framed(header.output())
  // Apache Thrift v0.22.0, Go bindings, THeaderTransport over TBinaryProtocol.
  assert_eq(
    to_hex(ours),
    "000000260fff000000000007000100000000800100010000000470696e67000000070800010000002a00",
  )
}

///|
test "thrift header: our compact frame is Apache's, byte for byte" {
  let header = Header::new()
  header.set_protocol(header_protocol_compact)
  let writer : &Protocol = header
  ping_message(writer)
  assert_eq(
    framed(header.output()),
    unhex("000000190fff0000000000070001020000008221070470696e67155400"),
  )
}

///|
test "thrift header: our headers block is Apache's, byte for byte" {
  let header = Header::new()
  header.add_header("trace-id", "abc")
  let writer : &Protocol = header
  ping_message(writer)
  assert_eq(
    framed(header.output()),
    unhex(
      "000000360fff0000000000070005000001010874726163652d696403616263000000800100010000000470696e67000000070800010000002a00",
    ),
  )
}

///|
test "thrift header: Apache's zlib frame decodes here" {
  let frame_bytes = unhex(
    "0000002f0fff000000000007000100010100789c6a6064606460606029c8cc4b67606060e70073b51800010000ffff25c7026f",
  )
  let (_, body) = split_frame(frame_bytes)
  let decoded = decode_header_frame(body)
  assert_eq(decoded.protocol, header_protocol_binary)
  assert_eq(decoded.transforms, [header_transform_zlib])
  let reader : &Protocol = Binary::new(decoded.payload)
  let (name, kind, seqid) = reader.read_message_begin()
  assert_eq(name, "ping")
  assert_eq(kind, message_call)
  assert_eq(seqid, 7)
  reader.read_struct_begin()
  let (field_type, field_id) = reader.read_field_begin()
  assert_eq((field_type, field_id), (type_i32, 1))
  assert_eq(reader.read_i32(), 42)
}

///|
/// The length prefix and the frame behind it, as a reader over a socket sees them.
fn split_frame(whole : Bytes) -> (Int32, Bytes) raise ThriftError {
  let len = frame_len(whole[:4].to_owned())
  (len, whole[4:4 + len].to_owned())
}

///|
test "thrift header: a call answered over the header protocol reads back whole" {
  let processor = Processor::new()
  processor.add("ping", proto => {
    proto.read_struct_begin()
    let mut n = 0
    for ;; {
      let (field_type, field_id) = proto.read_field_begin()
      if field_type == type_stop {
        break
      }
      if field_id == 1 && field_type == type_i32 {
        n = proto.read_i32()
      } else {
        skip(proto, field_type)
      }
    }
    proto.write_field_begin(type_i32, 0)
    proto.write_i32(n + 1)
  })
  // The server side reads whichever inner protocol the frame names, so a caller that sends
  // binary and one that sends compact both reach the same handler.
  for protocol in [header_protocol_binary, header_protocol_compact] {
    let header = Header::new()
    header.add_header("tenant", "acme")
    header.add_transform(header_transform_zlib)
    header.set_protocol(protocol)
    let writer : &Protocol = header
    ping_message(writer)
    let reply = processor.process(writer, header.output())
    let answer = @buffer.Buffer()
    answer.write_bytes(reply)
    let reader : &Protocol = header
    reader.reset(reply)
    let (name, kind, seqid) = reader.read_message_begin()
    assert_eq(name, "ping")
    assert_eq(kind, message_reply)
    assert_eq(seqid, 7)
    assert_eq(header.read_protocol(), protocol)
    reader.read_struct_begin()
    let (field_type, _) = reader.read_field_begin()
    assert_eq(field_type, type_i32)
    assert_eq(reader.read_i32(), 43)
  }
}

///|
test "thrift header: the caller's headers reach the service" {
  let header = Header::new()
  header.add_header("tenant", "acme")
  let writer : &Protocol = header
  ping_message(writer)
  let body = decode_header_frame(header.output())
  assert_eq(body.headers, [("tenant", "acme")])
  // A reader of the same frame sees them too.
  let reader = Header::new()
  let proto : &Protocol = reader
  proto.reset(header.output())
  assert_eq(reader.read_headers(), [("tenant", "acme")])
}

///|
test "thrift header: a transform this build does not have is refused" {
  let header = Header::new()
  let writer : &Protocol = header
  ping_message(writer)
  let plain = decode_header_frame(header.output())
  // Snappy is transform 2 in Apache's numbering and is not part of this build; reading it as
  // if it were plain would hand the handler compressed bytes.
  let refused = try {
    ignore(encode_header_frame(plain.payload, transforms=[2]))
    false
  } catch {
    Unsupported(_) => true
    _ => false
  }
  assert_true(refused)
}

///|
test "thrift header: a body that is not a header frame is refused, not misread" {
  // Fewer octets than the meta block.
  let short = try {
    ignore(decode_header_frame(b"\x0f\xff"))
    false
  } catch {
    Truncated => true
    _ => false
  }
  assert_true(short)
  // A plain binary message: its first word is a version and a type, not this magic, and
  // reading it as a header frame would slice the body at an offset that means nothing.
  let plain = try {
    ignore(
      decode_header_frame(b"\x80\x01\x00\x01\x00\x00\x00\x07\x00\x01\x00\x00"),
    )
    false
  } catch {
    BadVersion(_) => true
    _ => false
  }
  assert_true(plain)
}

///|
/// A transport that records what it is asked to send and refuses to wait for a reply: a
/// ONEWAY call that went through `round_trip` would abort here.
struct SendOnly {
  sent : Array[Bytes]
}

///|
impl Transport for SendOnly with fn round_trip(_self, _body) {
  abort("a ONEWAY call must not wait for a reply")
}

///|
impl Transport for SendOnly with fn send(self, body) {
  self.sent.push(body)
}

///|
async test "thrift: a ONEWAY call goes out through send and reads nothing back" {
  let transport = { sent: [], }
  let proto : &Protocol = Binary::new(b"")
  oneway_call(transport, proto, "ping", 3, proto => {
    proto.write_field_begin(type_i32, 1)
    proto.write_i32(7)
  })
  assert_eq(transport.sent.length(), 1)
  let reader : &Protocol = Binary::new(transport.sent[0])
  let (name, kind, seqid) = reader.read_message_begin()
  assert_eq(name, "ping")
  assert_eq(kind, message_oneway)
  assert_eq(seqid, 3)
  reader.read_struct_begin()
  let (field_type, field_id) = reader.read_field_begin()
  assert_eq((field_type, field_id), (type_i32, 1))
  assert_eq(reader.read_i32(), 7)
}

///|
test "thrift header: a server answers in the protocol the caller used" {
  let processor = Processor::new()
  processor.add("ping", proto => {
    ignore(proto.read_field_begin())
    let n = proto.read_i32()
    ignore(proto.read_field_begin())
    proto.write_field_begin(type_i32, 0)
    proto.write_i32(n + 1)
  })
  // The caller speaks compact; the server was built with the default, which is binary. The
  // frame it answers with has to name the protocol its payload is actually in — a reader
  // trusts that field, so a server that answered "binary" in compact bytes would be
  // unreadable to the Apache peer that called it.
  let caller = Header::new()
  caller.set_protocol(header_protocol_compact)
  let client : &Protocol = caller
  ping_message(client)
  let server = Header::new()
  let service : &Protocol = server
  let reply = processor.process(service, caller.output())
  let frame = decode_header_frame(reply)
  assert_eq(frame.protocol, header_protocol_compact)
  // And it reads back: the payload behind that field is compact.
  let reader = Header::new()
  let back : &Protocol = reader
  back.reset(reply)
  let (name, kind, _) = back.read_message_begin()
  assert_eq(name, "ping")
  assert_eq(kind, message_reply)
  ignore(back.read_struct_begin())
  let (field_type, _) = back.read_field_begin()
  assert_eq(field_type, type_i32)
  assert_eq(back.read_i32(), 43)
}
