// Browser glue for the moonrpc documentation site. Every function here is pure and
// runs on the JS backend: it exercises the real, shipped library — the protobuf
// writer and the two in-memory engines — so the showcase page demonstrates the
// library itself, not a reimplementation in JavaScript. The two entry points are
// `pub` functions; the JS backend exports them, and the page imports the module
// and calls them with plain strings, parsing the JSON they return.

///|
fn ascii(bs : Bytes) -> String {
  let buf = StringBuilder()
  for b in bs {
    buf.write_char((b.to_int() & 0xFF).unsafe_to_char())
  }
  buf.to_string()
}

///|
fn to_hex(bs : Bytes) -> String {
  let buf = StringBuilder()
  for b in bs {
    buf.write_string(hex2(b))
  }
  buf.to_string()
}

///|
fn hex2(b : Byte) -> String {
  let n = b.to_int() & 0xFF
  digits((n >> 4) & 0xF) + digits(n & 0xF)
}

///|
fn digits(n : Int32) -> String {
  match n {
    0 => "0"
    1 => "1"
    2 => "2"
    3 => "3"
    4 => "4"
    5 => "5"
    6 => "6"
    7 => "7"
    8 => "8"
    9 => "9"
    10 => "a"
    11 => "b"
    12 => "c"
    13 => "d"
    14 => "e"
    _ => "f"
  }
}

///|
fn from_hex(s : String) -> Bytes {
  let buf = Buffer()
  let arr = s.to_array()
  let mut i = 0
  while i + 1 < arr.length() {
    let hi = hexval(arr[i])
    let lo = hexval(arr[i + 1])
    buf.write_byte(((hi << 4) | lo).to_byte())
    i = i + 2
  }
  buf.to_bytes()
}

///|
fn hexval(c : Char) -> Int32 {
  if c >= '0' && c <= '9' {
    c.to_int() - '0'.to_int()
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 'a'.to_int() + 10
  } else if c >= 'A' && c <= 'F' {
    c.to_int() - 'A'.to_int() + 10
  } else {
    0
  }
}

///|
fn split_bar(s : String) -> Array[String] {
  let out : Array[String] = []
  let mut buf = StringBuilder()
  for c in s {
    if c == '|' {
      out.push(buf.to_string())
      buf = StringBuilder()
    } else {
      buf.write_char(c)
    }
  }
  out.push(buf.to_string())
  out
}

///|
fn split_comma(s : String) -> Array[String] {
  let out : Array[String] = []
  let mut buf = StringBuilder()
  for c in s {
    if c == ',' {
      out.push(buf.to_string())
      buf = StringBuilder()
    } else {
      buf.write_char(c)
    }
  }
  out.push(buf.to_string())
  out
}

///|
fn parse_int(s : String) -> Int32 {
  let mut n = 0
  let mut neg = false
  let mut started = false
  for c in s {
    if c == '-' && !started {
      neg = true
    } else if c >= '0' && c <= '9' {
      started = true
      n = n * 10 + (c.to_int() - '0'.to_int())
    } else {
      break
    }
  }
  if neg {
    -n
  } else {
    n
  }
}

///|
fn json_escape(s : String) -> String {
  let buf = StringBuilder()
  for c in s {
    if c == '"' {
      buf.write_string("\\\"")
    } else if c == '\\' {
      buf.write_string("\\\\")
    } else if c == '\n' {
      buf.write_string("\\n")
    } else if c == '\r' {
      buf.write_string("\\r")
    } else if c == '\t' {
      buf.write_string("\\t")
    } else if c.to_int() < 0x20 {
      // Raw protobuf reply bytes can contain control characters (the field
      // tag/length prefix); escape every control char so the result is valid JSON.
      buf.write_string("\\u00")
      buf.write_string(hex2((c.to_int() & 0xFF).to_byte()))
    } else {
      buf.write_char(c)
    }
  }
  buf.to_string()
}

// -- message encode demo ----------------------------------------------------

///|
/// A demo message with four fields of different kinds, used by the showcase's
/// encoder panel: `name` (string 1), `count` (int32 2), `blob` (bytes 3),
/// `tags` (repeated string 4). Arguments arrive joined by `|`.
pub fn demo_encode_message(arg : String) -> String {
  let parts = split_bar(arg)
  let name = if parts.length() > 0 { parts[0] } else { "" }
  let count_s = if parts.length() > 1 { parts[1] } else { "0" }
  let blob_h = if parts.length() > 2 { parts[2] } else { "" }
  let tags_c = if parts.length() > 3 { parts[3] } else { "" }
  let count = parse_int(count_s)
  let blob = from_hex(blob_h)
  let tags = split_comma(tags_c)
  let w = @moonrpc.PbWriter::new()
  if name != "" {
    w.string_(1, name)
  }
  if count != 0 {
    w.int32(2, count)
  }
  if blob.length() > 0 {
    w.bytes_(3, blob)
  }
  for t in tags {
    if t != "" {
      w.string_(4, t)
    }
  }
  let bytes = w.to_bytes()
  let fields : StringBuilder = StringBuilder()
  fields.write_string("[")
  let mut first = true
  let emit = fn(
    f : Int32,
    wire : String,
    tag : Int32,
    label : String,
    value : String,
  ) {
    if !first {
      fields.write_string(",")
    }
    first = false
    fields.write_string(
      "{\"f\":" +
      f.to_string() +
      ",\"wire\":\"" +
      wire +
      "\",\"tag\":" +
      tag.to_string() +
      ",\"name\":\"" +
      label +
      "\",\"value\":\"" +
      value +
      "\"}",
    )
  }
  if name != "" {
    emit(1, "LengthDelim", 10, "name", name)
  }
  if count != 0 {
    emit(2, "Varint", 16, "count", count_s)
  }
  if blob.length() > 0 {
    emit(3, "LengthDelim", 26, "blob", blob_h)
  }
  for t in tags {
    if t != "" {
      emit(4, "LengthDelim", 34, "tags", t)
    }
  }
  fields.write_string("]")
  "{\"hex\":\"" + to_hex(bytes) + "\",\"fields\":" + fields.to_string() + "}"
}

// -- in-memory engine run ---------------------------------------------------

///|
priv struct Greet {
  text : String
}

///|
impl @proto.Message for Greet with fn encode(self) {
  let w = @moonrpc.PbWriter::new()
  if self.text != "" {
    w.string_(1, self.text)
  }
  w.to_bytes()
}

///|
impl @proto.Message for Greet with fn decode(b) {
  let r = @moonrpc.PbReader::new(b)
  let mut text = ""
  while !r.eof() {
    match r.read_tag() {
      (1, @proto.LengthDelim) => text = r.read_string()
      (_, wire) => r.skip(wire)
    }
  }
  { text, }
}

///|
fn hello_req(name : String) -> Bytes {
  let w = @moonrpc.PbWriter::new()
  w.string_(1, name)
  w.to_bytes()
}

///|
fn read_field1(msg : Bytes) -> String {
  let r = @moonrpc.PbReader::new(msg)
  try {
    let _ = r.read_tag()
    r.read_string()
  } catch {
    _ => ""
  }
}

///|
fn fail_handler(_ctx : @moonrpc.RpcContext, _req : Greet) -> Greet raise {
  raise @wire.StatusError(@wire.Status::NotFound, "no such word")
}

///|
fn frame_info(f : @http2.Frame) -> (Int32, Bool) {
  match f {
    @http2.Headers(stream_id~, end_stream~, ..) => (stream_id, end_stream)
    @http2.Data(stream_id~, end_stream~, ..) => (stream_id, end_stream)
    @http2.Priority(stream_id~, ..) => (stream_id, false)
    @http2.RstStream(stream_id~, ..) => (stream_id, false)
    @http2.PushPromise(stream_id~, ..) => (stream_id, false)
    @http2.WindowUpdate(stream_id~, ..) => (stream_id, false)
    @http2.Continuation(stream_id~, ..) => (stream_id, false)
    _ => (0, false)
  }
}

///|
fn frame_json(f : @http2.Frame, dir : String) -> String {
  let (sid, es) = frame_info(f)
  "{\"d\":\"" +
  dir +
  "\",\"c\":" +
  f.code().to_string() +
  ",\"s\":" +
  sid.to_string() +
  ",\"es\":" +
  (if es { "true" } else { "false" }) +
  ",\"h\":\"" +
  to_hex(f.encode()) +
  "\"}"
}

///|
/// Drive a call of the given `kind` through the two pure engines in memory and
/// return the full, time-ordered frame list (HEADERS, DATA, trailing grpc-status
/// trailers) as JSON. `kind` is one of `unary`, `server`, `client`, `bidi`, `error`.
pub fn demo_run(kind : String) -> String {
  let server = @moonrpc.H2Server::new()
  server.register("/demo.Greeter/SayHello", req => {
    let w = @moonrpc.PbWriter::new()
    w.string_(1, "hello, " + read_field1(req))
    w.to_bytes()
  })
  server.register_handler("/demo.Greeter/Fail", @moonrpc.unary(fail_handler))
  server.register_server_streaming("/demo.Counter/Up", (_ctx, _req) => {
    [b"1", b"2", b"3"]
  })
  server.register_client_streaming("/demo.Sum/Add", (_ctx, msgs) => {
    let buf = Buffer()
    buf.write_bytes(b"got")
    for m in msgs {
      buf.write_byte(b'/')
      buf.write_bytes(m)
    }
    buf.to_bytes()
  })
  server.register_bidi("/demo.Chat/Talk", _ctx => @moonrpc.BidiHandler::{
    on_message: fn(m : Bytes) -> Array[Bytes] { [m + b"!"] },
    on_end: fn() -> Array[Bytes] { [] },
  })
  let client = @moonrpc.H2Client::new()
  let to_server : Array[@http2.Frame] = []
  let to_client : Array[@http2.Frame] = []
  let fj : Array[String] = []
  for f in client.preface() {
    to_server.push(f)
    fj.push(frame_json(f, "C"))
  }
  for f in server.preface() {
    to_client.push(f)
    fj.push(frame_json(f, "S"))
  }
  let mut id = 0
  if kind == "server" {
    id = client.open("/demo.Counter/Up")
    for f in client.send(id, b"go", end=true) {
      to_server.push(f)
      fj.push(frame_json(f, "C"))
    }
  } else if kind == "client" {
    id = client.open("/demo.Sum/Add")
    for f in client.send(id, b"a") {
      to_server.push(f)
      fj.push(frame_json(f, "C"))
    }
    for f in client.send(id, b"b") {
      to_server.push(f)
      fj.push(frame_json(f, "C"))
    }
    for f in client.close_send(id) {
      to_server.push(f)
      fj.push(frame_json(f, "C"))
    }
  } else if kind == "bidi" {
    id = client.open("/demo.Chat/Talk")
    for f in client.send(id, b"hi") {
      to_server.push(f)
      fj.push(frame_json(f, "C"))
    }
    for f in client.send(id, b"yo") {
      to_server.push(f)
      fj.push(frame_json(f, "C"))
    }
    for f in client.close_send(id) {
      to_server.push(f)
      fj.push(frame_json(f, "C"))
    }
  } else {
    let path = if kind == "error" {
      "/demo.Greeter/Fail"
    } else {
      "/demo.Greeter/SayHello"
    }
    let (i, frames) = client.unary(path, hello_req("world"))
    id = i
    for f in frames {
      to_server.push(f)
      fj.push(frame_json(f, "C"))
    }
  }
  let mut si = 0
  let mut ci = 0
  let mut steps = 0
  while !client.is_done(id) && steps < 100000 {
    steps = steps + 1
    if si < to_server.length() {
      let f = to_server[si]
      si = si + 1
      for r in server.feed(f) {
        to_client.push(r)
        fj.push(frame_json(r, "S"))
      }
    } else if ci < to_client.length() {
      let f = to_client[ci]
      ci = ci + 1
      try {
        for r in client.feed(f) {
          to_server.push(r)
          fj.push(frame_json(r, "C"))
        }
      } catch {
        _ => ()
      }
    } else {
      break
    }
  }
  let reply = client.reply(id)
  let rb : StringBuilder = StringBuilder()
  rb.write_string("[")
  for i = 0; i < reply.messages.length(); i = i + 1 {
    if i > 0 {
      rb.write_string(",")
    }
    rb.write_string("\"" + json_escape(ascii(reply.messages[i])) + "\"")
  }
  rb.write_string("]")
  "{\"kind\":\"" +
  kind +
  "\",\"frames\":[" +
  fj.join(",") +
  "],\"grpc_status\":" +
  reply.grpc_status.to_string() +
  ",\"grpc_message\":\"" +
  json_escape(reply.grpc_message) +
  "\",\"replies\":" +
  rb.to_string() +
  "}"
}

// -- browser bootstrap -------------------------------------------------------
// The executable form is JS-only (`supported_targets = "js"` in moon.pkg), so the
// `extern "js"` bridge below is never compiled for the native/wasm backends and the
// workspace-wide `--target all` gate stays green. On load, `main` exposes the two
// public demo functions on `globalThis` so the documentation showcase can call the
// real, shipped library from the page.

///|
extern "js" fn js_set_global(name : String, f : (String) -> String) = "(name, f) => { globalThis[name] = f; }"

///|
#coverage.skip
fn main {
  js_set_global("moonrpcEncodeMessage", demo_encode_message)
  js_set_global("moonrpcRun", demo_run)
  ignore(demo_encode_message("alice|3|deadbeef|"))
  ignore(demo_run("unary"))
}
