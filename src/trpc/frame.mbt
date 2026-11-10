// The tRPC wire format: a 16-byte fixed head in front of either a unary request or
// response (a protobuf header, then the body, then any attachment) or one streaming
// frame. Pure: bytes in, a record out, and no socket.

///|
/// `TrpcMagic_TRPC_MAGIC_VALUE`: the two octets every frame starts with, big-endian.
pub let magic : UInt32 = 0x930

///|
/// The fixed head every frame starts with.
pub let head_len : Int32 = 16

///|
/// The largest frame this library will build or accept, in octets. The reference
/// implementations use the same ceiling.
pub let max_frame : Int32 = 16 * 1024 * 1024

///|
/// What a frame carries. The unary kinds put a `RequestProtocol` / `ResponseProtocol`
/// in the header; the four streaming kinds put one of the stream metas in the body.
/// On the wire the first four octets are a data-frame type and — for a stream frame —
/// a second type, so this is one concept with five values rather than two enums whose
/// combinations have to be kept in step.
#derive(Eq, Debug)
pub(all) enum FrameKind {
  Unary
  Init
  Data
  Feedback
  Close
}

///|
/// Structural equality, so a caller compares frame kinds rather than their codes.
pub extend FrameKind with Eq::{not_equal, equal}

///|
pub extend FrameKind with Debug::{to_repr}

///|
/// The data-frame type octet: unary, or streaming for every streaming kind.
pub fn FrameKind::data_type(self : FrameKind) -> Int32 {
  match self {
    Unary => 0x00
    _ => 0x01
  }
}

///|
/// The stream-frame type octet, which only a streaming kind has a meaning for.
pub fn FrameKind::stream_type(self : FrameKind) -> Int32 {
  match self {
    Unary => 0x00
    Init => 0x01
    Data => 0x02
    Feedback => 0x03
    Close => 0x04
  }
}

///|
/// Back from the two type octets. An unknown streaming type is a malformed frame, not a
/// value this library invents a meaning for.
pub fn FrameKind::of(data_type : Int32, stream_type : Int32) -> FrameKind? {
  match data_type {
    0x00 => if stream_type == 0 { Some(Unary) } else { None }
    0x01 =>
      match stream_type {
        0x01 => Some(Init)
        0x02 => Some(Data)
        0x03 => Some(Feedback)
        0x04 => Some(Close)
        _ => None
      }
    _ => None
  }
}

///|
pub(all) suberror TrpcError {
  /// The two magic octets were not `0x09 0x30`.
  BadMagic(Int32)
  /// A frame ended in the middle of a field, or before its announced length.
  Truncated
  /// A frame announcing more octets than [`max_frame`].
  TooLarge(Int32)
  /// A frame that decodes to something no legal call has: an unknown frame kind, a
  /// unary header longer than its frame, a header that is not the message it claims.
  Malformed(String)
  /// The peer answered with a non-zero return code: `ret` is a `TrpcRetCode`, and the
  /// message is what it sent.
  Refused(Int32, String)
}

///|
pub impl Show for TrpcError with fn output(self, logger) {
  match self {
    BadMagic(m) => logger.write_string("BadMagic(\{m})")
    Truncated => logger.write_string("Truncated")
    TooLarge(n) => logger.write_string("TooLarge(\{n})")
    Malformed(why) => logger.write_string("Malformed(\{why})")
    Refused(code, message) =>
      logger.write_string("Refused(\{code}, \{message})")
  }
}

///|
pub extend TrpcError with Show::{to_string, output}

///|
fn be16(bytes : Bytes, at : Int32) -> Int32 {
  (bytes[at].to_int() << 8) | bytes[at + 1].to_int()
}

///|
fn be32(bytes : Bytes, at : Int32) -> Int32 {
  (bytes[at].to_int() << 24) |
  (bytes[at + 1].to_int() << 16) |
  (bytes[at + 2].to_int() << 8) |
  bytes[at + 3].to_int()
}

///|
fn put_be16(out : @buffer.Buffer, value : Int32) -> Unit {
  out.write_byte((value >> 8).to_byte())
  out.write_byte(value.to_byte())
}

///|
fn put_be32(out : @buffer.Buffer, value : Int32) -> Unit {
  out.write_byte((value >> 24).to_byte())
  out.write_byte((value >> 16).to_byte())
  out.write_byte((value >> 8).to_byte())
  out.write_byte(value.to_byte())
}

///|
/// One frame: the fixed head's remaining fields, and everything after it. For a unary
/// frame `header_len` marks where the protobuf header ends and the message begins; for a
/// streaming frame the whole payload is the frame's meta or data.
pub(all) struct Frame {
  kind : FrameKind
  stream_id : Int64
  version : Int32
  reserved : Int32
  header_len : Int32
  payload : Bytes
}

///|
pub fn Frame::new(
  kind : FrameKind,
  stream_id : Int64,
  payload : Bytes,
  header_len~ : Int32 = 0,
  version~ : Int32 = 1,
  reserved~ : Int32 = 0,
) -> Frame {
  { kind, stream_id, version, reserved, header_len, payload, }
}

///|
/// The total length a frame occupies on the wire.
pub fn Frame::total_len(self : Frame) -> Int32 {
  head_len + self.payload.length()
}

///|
/// The unary header's bytes, and the body plus attachment after it.
pub fn Frame::header(self : Frame) -> Bytes {
  self.payload[:self.header_len].to_owned()
}

///|
/// The body of a unary frame: the message and, at its tail, the attachment.
pub fn Frame::body(self : Frame) -> Bytes {
  self.payload[self.header_len:].to_owned()
}

///|
/// The bytes of one frame, head included.
pub fn Frame::encode(self : Frame) -> Bytes {
  let out = @buffer.Buffer()
  put_be16(out, magic.reinterpret_as_int())
  out.write_byte(self.kind.data_type().to_byte())
  out.write_byte(self.kind.stream_type().to_byte())
  put_be32(out, self.total_len())
  put_be16(out, self.header_len)
  put_be32(out, self.stream_id.to_int())
  out.write_byte(self.version.to_byte())
  out.write_byte(self.reserved.to_byte())
  out.write_bytes(self.payload)
  out.to_bytes()
}

///|
/// The total length a frame head announces, so a reader can take the rest of the frame
/// in one go. Raises before reading anything else, so a peer that sent nonsense costs a
/// connection rather than the process.
pub fn Frame::announced_len(head : Bytes) -> Int32 raise TrpcError {
  if head.length() < head_len {
    raise Truncated
  }
  let got = be16(head, 0)
  if got != magic.reinterpret_as_int() {
    raise BadMagic(got)
  }
  let total = be32(head, 4)
  if total < head_len {
    raise Malformed("a frame shorter than its own head: \{total}")
  }
  if total > max_frame {
    raise TooLarge(total)
  }
  total
}

///|
/// Decode one frame from the front of `bytes`. Returns the frame and how many octets it
/// used, so a caller with several frames in one buffer can keep going.
pub fn Frame::decode(bytes : Bytes) -> (Frame, Int32) raise TrpcError {
  let total = Frame::announced_len(bytes)
  if bytes.length() < total {
    raise Truncated
  }
  let kind = match FrameKind::of(bytes[2].to_int(), bytes[3].to_int()) {
    Some(kind) => kind
    None =>
      raise Malformed(
        "unknown frame kind \{bytes[2].to_int()}/\{bytes[3].to_int()}",
      )
  }
  let header_len = be16(bytes, 8)
  if header_len > total - head_len {
    raise Malformed("a header longer than its frame: \{header_len}")
  }
  let frame : Frame = {
    kind,
    stream_id: be32(bytes, 10).to_int64(),
    version: bytes[14].to_int(),
    reserved: bytes[15].to_int(),
    header_len,
    payload: bytes[head_len:total].to_owned(),
  }
  (frame, total)
}
