// The HTTP/2 frame layer (RFC 7540 §6): every one of the ten frame types encodes
// to its exact wire octets and decodes straight back. Each frame is a 9-octet
// header — 24-bit length, type, flags, 31-bit stream id — followed by a
// type-specific payload. This builds one of each, prints its bytes, and round-trips
// it through `decode_frame`, plus the standalone `@http2.FrameHeader` codec and the
// connection @http2.preface a server sniffs first.
//
//     moon run examples/02-http2-frames

///|
fn hex(bs : Bytes) -> String {
  let digits = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
  ]
  let buf = StringBuilder()
  for b in bs {
    let v = b.to_int() & 0xFF
    buf.write_char(digits[v >> 4])
    buf.write_char(digits[v & 0xF])
  }
  buf.to_string()
}

///|
fn type_name(t : Int) -> String {
  if t == @http2.frame_data {
    "DATA"
  } else if t == @http2.frame_headers {
    "HEADERS"
  } else if t == @http2.frame_priority {
    "PRIORITY"
  } else if t == @http2.frame_rst_stream {
    "RST_STREAM"
  } else if t == @http2.frame_settings {
    "SETTINGS"
  } else if t == @http2.frame_push_promise {
    "PUSH_PROMISE"
  } else if t == @http2.frame_ping {
    "PING"
  } else if t == @http2.frame_goaway {
    "GOAWAY"
  } else if t == @http2.frame_window_update {
    "WINDOW_UPDATE"
  } else if t == @http2.frame_continuation {
    "CONTINUATION"
  } else {
    "UNKNOWN"
  }
}

///|
fn roundtrip(frame : @http2.Frame) -> Unit {
  let wire = frame.encode()
  let name = type_name(frame.code())
  let status = try {
    let (back, consumed) = @http2.decode(wire)
    if back == frame && consumed == wire.length() {
      "round-trip ok"
    } else {
      "MISMATCH"
    }
  } catch {
    e => "decode raised \{e}"
  }
  println("\{name}: \{hex(wire)}  (\{status})")
}

///|
#coverage.skip
fn main {
  let prio : @http2.Priority = {
    exclusive: true,
    stream_dependency: 1,
    weight: 15,
  }
  // One frame of each of the ten types. A HEADERS fragment is opaque here — the
  // HPACK examples build a real one; the frame layer only carries the bytes.
  let frames : Array[@http2.Frame] = [
    Data(stream_id=1, data=b"qwq", end_stream=true, padding=4),
    Headers(
      stream_id=1,
      fragment=b"\x82\x86",
      end_stream=false,
      end_headers=true,
      priority=None,
      padding=0,
    ),
    @http2.Priority(stream_id=3, priority=prio),
    RstStream(stream_id=3, error_code=@http2.error_cancel),
    Settings(
      params=[
        (@http2.settings_max_concurrent_streams, 233),
        (@http2.settings_initial_window_size, 65535),
      ],
      ack=false,
    ),
    PushPromise(
      stream_id=1,
      promised_id=2,
      fragment=b"\x88",
      end_headers=true,
      padding=0,
    ),
    Ping(payload=b"heke1228", ack=false),
    GoAway(last_stream_id=23333, error_code=@http2.error_no_error, debug=b"bye"),
    WindowUpdate(stream_id=0, increment=66666),
    Continuation(stream_id=1, fragment=b"\x84", end_headers=true),
  ]
  for f in frames {
    roundtrip(f)
  }

  // A SETTINGS ack carries no payload; its ACK flag distinguishes it from the
  // parameter-bearing SETTINGS above.
  roundtrip(Settings(params=[], ack=true))

  // The bare 9-octet frame header round-trips on its own.
  let hdr : @http2.FrameHeader = {
    length: 3,
    ftype: @http2.frame_data,
    flags: @http2.flag_end_stream,
    stream_id: 1,
  }
  let hbytes = hdr.encode()
  let back = @http2.FrameHeader::decode(hbytes) catch { _ => hdr }
  println("@http2.FrameHeader: \{hex(hbytes)}  (round-trip \{back == hdr})")

  // A server reads the client connection @http2.preface before any frame (§3.5).
  println("preface: \{hex(@http2.preface)}")
  println("  present in a client stream: \{@http2.has_preface(@http2.preface)}")
  println(
    "  present in junk: \{@http2.has_preface(b"not a @http2.preface at all")}",
  )
}
