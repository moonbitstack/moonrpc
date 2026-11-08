// THeaderTransport and THeaderProtocol: the frame Apache Thrift's header transport puts
// around a body, its per-connection protocol choice, and the zlib transform it can apply.
//
// The format: a 4-octet big-endian length (the reader's framing already carries it), then a
// ten-octet meta block, a header block padded to four octets, and the payload. The meta names
// the inner protocol, so one port serves binary and compact callers at once, and it carries
// key/value headers beside the call — the transport's own metadata channel.
//
//   magic | flags     uint32, the high half 0x0fff
//   sequence id       int32, the message's
//   header length     uint16, in four-octet words
//
// The header block is itself compact-protocol encoded: the protocol id, the transforms, and
// then an info section of key/value pairs. Nothing inside the payload changes, so a body
// written for the binary protocol travels here byte for byte.

///|
/// The high half of the header frame's first four octets: what tells a header frame from a
/// plain binary message, whose first octet is a version and a type.
pub let header_magic : Int32 = 0x0fff0000

///|
/// The meta block in front of every header frame: magic and flags, then the sequence id, then
/// the header block's length in four-octet words.
pub let header_meta_size : Int32 = 10

///|
/// The inner protocol ids a header frame may name.
pub let header_protocol_binary : Int32 = 0

///|
pub let header_protocol_compact : Int32 = 2

///|
/// A transform id, applied to the payload after the header block. Zero is "none", which is
/// the only one written; `header_transform_zlib` is read and written, and anything else is
/// refused rather than passed through as if it were plain.
pub let header_transform_none : Int32 = 0

///|
pub let header_transform_zlib : Int32 = 1

///|
/// The info section's only defined kind: a block of key/value pairs.
let info_key_value : Int32 = 1

///|
/// One decoded header frame: which protocol the payload is in, the message's sequence id, the
/// transforms that were undone to get it, the headers the sender attached, and the payload.
pub(all) struct HeaderFrame {
  protocol : Int32
  seqid : Int32
  flags : Int32
  transforms : Array[Int32]
  headers : Array[(String, String)]
  payload : Bytes
}

///|
/// Apply the transforms a header frame names, in order, to a payload.
fn apply_transforms(
  body : Bytes,
  transforms : Array[Int32],
) -> Bytes raise ThriftError {
  let mut out = body
  for t in transforms {
    out = match t {
      t if t == header_transform_zlib => @zlib.zlib(out[:], level=6)
      t if t == header_transform_none => out
      other => raise Unsupported("transform " + other.to_string())
    }
  }
  out
}

///|
/// Undo the transforms a header frame names. A sender applies them in the order it names, so a
/// reader removes them from the last one back.
fn undo_transforms(
  body : Bytes,
  transforms : Array[Int32],
) -> Bytes raise ThriftError {
  let mut out = body
  let mut i = transforms.length() - 1
  while i >= 0 {
    let t = transforms[i]
    out = match t {
      t if t == header_transform_zlib =>
        @zlib.unzlib(out[:]) catch {
          _ => raise Truncated
        }
      t if t == header_transform_none => out
      other => raise Unsupported("transform " + other.to_string())
    }
    i = i - 1
  }
  out
}

///|
/// A header frame without its length prefix, which the transport's own framing carries: the
/// meta block, the header block, and the payload.
pub fn encode_header_frame(
  body : Bytes,
  protocol~ : Int32 = header_protocol_binary,
  seqid~ : Int32 = 0,
  flags~ : Int32 = 0,
  transforms~ : Array[Int32] = [],
  headers~ : Array[(String, String)] = [],
) -> Bytes raise ThriftError {
  // The header block is compact-protocol encoded, so its varints and strings are the ones
  // every reader of this frame already knows how to read.
  let fields = Compact::new(b"")
  fields.write_varint(protocol.to_int64())
  fields.write_varint(transforms.length().to_int64())
  for t in transforms {
    fields.write_varint(t.to_int64())
  }
  if headers.length() > 0 {
    fields.write_varint(info_key_value.to_int64())
    fields.write_varint(headers.length().to_int64())
    for pair in headers {
      fields.write_string(pair.0)
      fields.write_string(pair.1)
    }
  }
  let raw = fields.output()
  // Four-octet alignment, so the payload behind it starts on a word boundary. A block that is
  // already aligned is left alone rather than given a whole extra word.
  let mut block = raw
  let pad = (4 - raw.length() % 4) % 4
  if pad > 0 {
    let buf = @buffer.Buffer()
    buf.write_bytes(raw)
    for _ in 0..<pad {
      buf.write_byte(b'\x00')
    }
    block = buf.to_bytes()
  }
  let payload = apply_transforms(body, transforms)
  let out = @buffer.Buffer()
  // The meta block: magic and flags as one word, the sequence id, the header length in words.
  @fixed.write_u32(out, (header_magic | (flags & 0xFFFF)).reinterpret_as_uint())
  @fixed.write_u32(out, seqid.reinterpret_as_uint())
  out.write_byte(((block.length() / 4) >> 8).to_byte())
  out.write_byte(((block.length() / 4) & 0xFF).to_byte())
  out.write_bytes(block)
  out.write_bytes(payload)
  out.to_bytes()
}

///|
/// Decode a header frame that has already had its length prefix removed.
pub fn decode_header_frame(frame : Bytes) -> HeaderFrame raise ThriftError {
  if frame.length() < header_meta_size {
    raise Truncated
  }
  let head = @fixed.read_u32(frame[:], at=0).unwrap().reinterpret_as_int()
  if (head & 0xFFFF0000) != header_magic {
    raise BadVersion(head)
  }
  let flags = head & 0xFFFF
  let seqid = @fixed.read_u32(frame[:], at=4).unwrap().reinterpret_as_int()
  let words = (frame[8].to_int() << 8) | frame[9].to_int()
  let header_len = words * 4
  if header_meta_size + header_len > frame.length() {
    raise Truncated
  }
  let block = frame[header_meta_size:header_meta_size + header_len]
  let payload = frame[header_meta_size + header_len:frame.length()].to_owned()
  let reader = Compact::new(block.to_owned())
  let protocol = reader.read_varint().to_int()
  let count = reader.read_varint().to_int()
  if count < 0 {
    raise Truncated
  }
  let transforms : Array[Int32] = []
  for _ in 0..<count {
    transforms.push(reader.read_varint().to_int())
  }
  let headers : Array[(String, String)] = []
  while !reader.eof() {
    // An info section this build does not know ends the header block, as the reference
    // implementation reads it: skipping an unknown kind would need its length, which the
    // format does not give.
    if reader.read_varint().to_int() != info_key_value {
      break
    }
    let pairs = reader.read_varint().to_int()
    if pairs < 0 {
      raise Truncated
    }
    for _ in 0..<pairs {
      headers.push((reader.read_string(), reader.read_string()))
    }
    // The padding that follows is not a field: stop once it is all that is left.
    if reader.eof() {
      break
    }
  }
  {
    protocol,
    seqid,
    flags,
    transforms,
    headers,
    payload: undo_transforms(payload, transforms),
  }
}

///|
/// A protocol that speaks inside a header frame: the inner protocol (binary or compact, chosen
/// per frame by what the frame says) reads and writes the body, and this puts the meta block,
/// the headers and the transforms around it.
///
/// One object serves a whole connection the way the plain protocols do, and a caller may
/// switch the inner protocol between calls on the same connection, which is what the header
/// transport negotiates.
pub struct Header {
  binary : Binary
  compact : Compact
  mut use_compact : Bool
  // The protocol this side writes with, and the headers and transforms it applies.
  mut write_protocol : Int32
  write_headers : Array[(String, String)]
  mut transforms : Array[Int32]
  mut seqid : Int32
  // What the last frame read carried, so a service can answer with the caller's headers in
  // view and a client can read what the server attached.
  mut frame_headers : Array[(String, String)]
  mut frame_protocol : Int32
  // A frame that would not decode. `reset` cannot raise — the trait's shape is the same one
  // the plain protocols use — so the failure surfaces on the next read, as a truncated frame.
  mut broken : Bool
}

///|
/// A header-protocol endpoint that writes the binary protocol inside the header frame, and
/// reads whichever inner protocol a frame names.
pub fn Header::new() -> Header {
  {
    binary: Binary::new(b""),
    compact: Compact::new(b""),
    use_compact: false,
    write_protocol: header_protocol_binary,
    write_headers: [],
    transforms: [],
    seqid: 0,
    frame_headers: [],
    frame_protocol: header_protocol_binary,
    broken: false,
  }
}

///|
/// Write the compact protocol inside the header frame instead of the binary one.
pub fn Header::set_protocol(self : Header, protocol : Int32) -> Unit {
  self.write_protocol = protocol
  self.use_compact = protocol == header_protocol_compact
}

///|
/// Attach a key/value header to every frame this side writes.
pub fn Header::add_header(self : Header, key : String, value : String) -> Unit {
  self.write_headers.push((key, value))
}

///|
/// Compress every frame this side writes with the zlib transform. A reader that did not ask
/// for it still reads the frame: the transform is named in the frame itself.
pub fn Header::add_transform(self : Header, transform : Int32) -> Unit {
  self.transforms.push(transform)
}

///|
/// The headers the last frame read carried.
pub fn Header::read_headers(self : Header) -> Array[(String, String)] {
  self.frame_headers
}

///|
/// The inner protocol the last frame read named.
pub fn Header::read_protocol(self : Header) -> Int32 {
  self.frame_protocol
}

///|
/// The sequence id of the message this side last wrote.
pub fn Header::sequence_id(self : Header) -> Int32 {
  self.seqid
}

///|
/// The protocol the body of this frame is written and read with.
fn Header::inner(self : Header) -> &Protocol {
  if self.use_compact {
    (self.compact : &Protocol)
  } else {
    (self.binary : &Protocol)
  }
}

///|
/// The protocol id that names the inner encoder `inner` returns.
fn Header::out_protocol(self : Header) -> Int32 {
  if self.use_compact {
    header_protocol_compact
  } else {
    header_protocol_binary
  }
}

///|
pub impl Protocol for Header with fn reset(self, input) {
  self.broken = false
  if input.length() == 0 {
    self.use_compact = self.write_protocol == header_protocol_compact
    self.inner().reset(b"")
    return
  }
  let frame = decode_header_frame(input) catch {
    _ => {
      self.broken = true
      return
    }
  }
  self.frame_protocol = frame.protocol
  self.frame_headers = frame.headers
  self.use_compact = frame.protocol == header_protocol_compact
  // A server that read a compressed request answers the same way, so a caller that asked for
  // zlib keeps getting it without saying so on every call.
  if frame.transforms.length() > 0 && self.transforms.length() == 0 {
    self.transforms = []
    for t in frame.transforms {
      self.transforms.push(t)
    }
  }
  self.inner().reset(frame.payload)
}

///|
pub impl Protocol for Header with fn output(self) {
  encode_header_frame(
    self.inner().output(),
    // The id names the protocol the payload behind it is in, and `inner` picks that from
    // `use_compact` — set by this side's own choice before it writes, or, for a server, by the
    // frame it just read. Naming `write_protocol` here instead answered a compact caller with
    // compact bytes under a "binary" label.
    protocol=self.out_protocol(),
    seqid=self.seqid,
    transforms=self.transforms,
    headers=self.write_headers,
  ) catch {
    _ => b""
  }
}

///|
/// A read on a frame that would not decode reports the frame as truncated, which is what a
/// caller can act on: the bytes never arrived intact.
fn Header::check(self : Header) -> Unit raise ThriftError {
  if self.broken {
    raise Truncated
  }
}

///|
/// The same, for the two reads the trait declares without a raise: they do nothing on a
/// frame that would not decode, and the field read that follows is the one that reports it.
fn Header::check_quiet(self : Header) -> Bool {
  !self.broken
}

///|
pub impl Protocol for Header with fn read_message_begin(self) {
  self.check()
  self.inner().read_message_begin()
}

///|
pub impl Protocol for Header with fn write_message_begin(
  self,
  name,
  kind,
  seqid,
) {
  self.seqid = seqid
  self.inner().write_message_begin(name, kind, seqid)
}

///|
pub impl Protocol for Header with fn read_struct_begin(self) {
  if self.check_quiet() {
    self.inner().read_struct_begin()
  }
}

///|
pub impl Protocol for Header with fn read_struct_end(self) {
  if self.check_quiet() {
    self.inner().read_struct_end()
  }
}

///|
pub impl Protocol for Header with fn write_struct_begin(self, name) {
  self.inner().write_struct_begin(name)
}

///|
pub impl Protocol for Header with fn write_struct_end(self) {
  self.inner().write_struct_end()
}

///|
pub impl Protocol for Header with fn read_field_begin(self) {
  self.check()
  self.inner().read_field_begin()
}

///|
pub impl Protocol for Header with fn write_field_begin(self, type_, id) {
  self.inner().write_field_begin(type_, id)
}

///|
pub impl Protocol for Header with fn write_field_stop(self) {
  self.inner().write_field_stop()
}

///|
pub impl Protocol for Header with fn read_bool(self) {
  self.check()
  self.inner().read_bool()
}

///|
pub impl Protocol for Header with fn read_byte(self) {
  self.check()
  self.inner().read_byte()
}

///|
pub impl Protocol for Header with fn read_i16(self) {
  self.check()
  self.inner().read_i16()
}

///|
pub impl Protocol for Header with fn read_i32(self) {
  self.check()
  self.inner().read_i32()
}

///|
pub impl Protocol for Header with fn read_i64(self) {
  self.check()
  self.inner().read_i64()
}

///|
pub impl Protocol for Header with fn read_double(self) {
  self.check()
  self.inner().read_double()
}

///|
pub impl Protocol for Header with fn read_string(self) {
  self.check()
  self.inner().read_string()
}

///|
pub impl Protocol for Header with fn read_bytes(self) {
  self.check()
  self.inner().read_bytes()
}

///|
pub impl Protocol for Header with fn read_uuid(self) {
  self.check()
  self.inner().read_uuid()
}

///|
pub impl Protocol for Header with fn read_list_begin(self) {
  self.check()
  self.inner().read_list_begin()
}

///|
pub impl Protocol for Header with fn read_set_begin(self) {
  self.check()
  self.inner().read_set_begin()
}

///|
pub impl Protocol for Header with fn read_map_begin(self) {
  self.check()
  self.inner().read_map_begin()
}

///|
pub impl Protocol for Header with fn write_bool(self, value) {
  self.inner().write_bool(value)
}

///|
pub impl Protocol for Header with fn write_byte(self, value) {
  self.inner().write_byte(value)
}

///|
pub impl Protocol for Header with fn write_i16(self, value) {
  self.inner().write_i16(value)
}

///|
pub impl Protocol for Header with fn write_i32(self, value) {
  self.inner().write_i32(value)
}

///|
pub impl Protocol for Header with fn write_i64(self, value) {
  self.inner().write_i64(value)
}

///|
pub impl Protocol for Header with fn write_double(self, value) {
  self.inner().write_double(value)
}

///|
pub impl Protocol for Header with fn write_string(self, value) {
  self.inner().write_string(value)
}

///|
pub impl Protocol for Header with fn write_bytes(self, value) {
  self.inner().write_bytes(value)
}

///|
pub impl Protocol for Header with fn write_uuid(self, value) {
  self.inner().write_uuid(value)
}

///|
pub impl Protocol for Header with fn write_list_begin(self, elem, size) {
  self.inner().write_list_begin(elem, size)
}

///|
pub impl Protocol for Header with fn write_set_begin(self, elem, size) {
  self.inner().write_set_begin(elem, size)
}

///|
pub impl Protocol for Header with fn write_map_begin(self, key, value, size) {
  self.inner().write_map_begin(key, value, size)
}

///|
/// The promoted forms, so a caller holding a `Header` uses it the way it uses a `Binary`.
pub extend Header with Protocol::{
  reset,
  output,
  read_message_begin,
  write_message_begin,
  read_struct_begin,
  read_struct_end,
  write_struct_begin,
  write_struct_end,
  read_field_begin,
  write_field_begin,
  write_field_stop,
  read_bool,
  read_byte,
  read_i16,
  read_i32,
  read_i64,
  read_double,
  read_string,
  read_bytes,
  read_uuid,
  read_list_begin,
  read_set_begin,
  read_map_begin,
  write_bool,
  write_byte,
  write_i16,
  write_i32,
  write_i64,
  write_double,
  write_string,
  write_bytes,
  write_uuid,
  write_list_begin,
  write_set_begin,
  write_map_begin,
}
