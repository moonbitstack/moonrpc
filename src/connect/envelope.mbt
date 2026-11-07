// Connect's wire vocabulary: the content types it names, the envelope its streaming bodies are
// cut into, and the error body it answers with. These are the parts of the protocol that do
// not depend on how the bytes travel, so they are here, pure, and a driver on either HTTP
// version only has to move them.
//
// The protocol is one document: https://connectrpc.com/docs/protocol

///|
/// The codec a request or reply body is in. The protocol names two, and a service answers in
/// whichever the caller asked for.
#derive(Eq, Debug)
pub(all) enum Codec {
  Proto
  Json
}

///|
/// What a `content-type` says: which codec, and whether the body is one message or a run of
/// envelopes.
#derive(Eq, Debug)
pub(all) struct Content {
  codec : Codec
  streaming : Bool
}

///|
/// The `content-type` a request of this shape carries.
pub fn Content::text(self : Content) -> String {
  match (self.codec, self.streaming) {
    (Proto, false) => "application/proto"
    (Json, false) => "application/json"
    (Proto, true) => "application/connect+proto"
    (Json, true) => "application/connect+json"
  }
}

///|
/// Read a `content-type`. A parameter after `;` — `charset=utf-8` — is ignored, as the
/// protocol says a server should; anything else is not a Connect body.
pub fn Content::parse(text : String) -> Content? {
  let mut base = text
  match text.find(";") {
    Some(at) => base = text.exact_view(start=0, end=at).to_owned()
    None => ()
  }
  let trimmed = base.trim(chars=" \t").to_owned()
  if trimmed == "application/proto" {
    Some({ codec: Proto, streaming: false, })
  } else if trimmed == "application/json" {
    Some({ codec: Json, streaming: false, })
  } else if trimmed == "application/connect+proto" {
    Some({ codec: Proto, streaming: true, })
  } else if trimmed == "application/connect+json" {
    Some({ codec: Json, streaming: true, })
  } else {
    None
  }
}

///|
/// The bit set in an envelope's flag byte when its payload is compressed.
pub let flag_compressed : Byte = b'\x01'

///|
/// The bit set in the flag byte of the envelope that ends a stream. Its payload is a JSON
/// object: `{}` when the call ended cleanly, or one with an `error` member.
pub let flag_end_stream : Byte = b'\x02'

///|
/// The header in front of every envelope: one octet of flags, then the payload length as four
/// big-endian octets. A whole message for a unary call is the payload alone, with no envelope
/// around it — the two framing modes are what `Content::streaming` chooses between.
pub let envelope_header_size : Int32 = 5

///|
/// One envelope off the wire.
pub(all) struct Envelope {
  flags : Byte
  payload : Bytes
}

///|
/// Whether this envelope ends the stream rather than carrying a message.
pub fn Envelope::is_end_stream(self : Envelope) -> Bool {
  (self.flags.to_int() & flag_end_stream.to_int()) != 0
}

///|
/// Whether this envelope's payload is compressed with the stream's `connect-content-encoding`.
pub fn Envelope::is_compressed(self : Envelope) -> Bool {
  (self.flags.to_int() & flag_compressed.to_int()) != 0
}

///|
/// Wrap `payload` in an envelope with `flags`.
pub fn encode_envelope(payload : Bytes, flags~ : Byte = b'\x00') -> Bytes {
  let buf = Buffer()
  buf.write_byte(flags)
  @fixed.write_u32(buf, payload.length().reinterpret_as_uint())
  buf.write_bytes(payload)
  buf.to_bytes()
}

///|
/// The envelope at `at` in `data`, and the offset just past it, or `None` when fewer octets
/// than one whole envelope are buffered. A length that decodes negative — the high bit of the
/// fourth octet — is refused rather than trusted with a slice.
pub fn decode_envelope(data : BytesView, at~ : Int32 = 0) -> (Envelope, Int32)? {
  if data.length() - at < envelope_header_size {
    return None
  }
  let flags = data[at]
  guard @fixed.read_u32(data, at=at + 1) is Some(length) else { return None }
  let len = length.reinterpret_as_int()
  if len < 0 || data.length() - at - envelope_header_size < len {
    return None
  }
  let stop = at + envelope_header_size + len
  Some(
    ({ flags, payload: data[at + envelope_header_size:stop].to_owned(), }, stop),
  )
}

///|
/// Split a run of concatenated envelopes into the ones that are whole, with the offset of the
/// first byte that is not. A partial trailing envelope stays for the caller to complete.
pub fn split_envelopes(data : Bytes) -> (Array[Envelope], Int32) {
  let out : Array[Envelope] = []
  let mut at = 0
  while decode_envelope(data[:], at~) is Some((envelope, next)) {
    out.push(envelope)
    at = next
  }
  (out, at)
}

///|
pub extend Codec with Eq::{not_equal, equal}

///|
pub extend Codec with Debug::{to_repr}

///|
pub extend Content with Eq::{not_equal, equal}

///|
pub extend Content with Debug::{to_repr}
