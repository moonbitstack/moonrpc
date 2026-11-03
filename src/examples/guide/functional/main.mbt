///|
/// Run the same greeter registered as functions on the server.
///
///     moon run src/examples/guide/functional
fn encode_request(name : String) -> Bytes {
  let w = @moonrpc.PbWriter::new()
  w.string_(1, name)
  w.to_bytes()
}

///|
fn decode_name(msg : Bytes) -> String {
  try {
    let r = @moonrpc.PbReader::new(msg)
    let _ = r.read_tag()
    r.read_string()
  } catch {
    _ => ""
  }
}

///|
fn encode_reply(message : String) -> Bytes {
  let w = @moonrpc.PbWriter::new()
  w.string_(1, message)
  w.to_bytes()
}

///|
fn decode_reply(msg : Bytes) -> String {
  try {
    let r = @moonrpc.PbReader::new(msg)
    let _ = r.read_tag()
    r.read_string()
  } catch {
    _ => ""
  }
}

///|
fn main {
  let reply = @harness.round_trip(
    server => {
      server.register_unary("/greet.Greeter/SayHello", (_ctx, req) => {
        encode_reply("Hello, " + decode_name(req))
      })
    },
    "/greet.Greeter/SayHello",
    encode_request("Ada"),
  ) catch {
    _ => abort("the call failed")
  }
  println(decode_reply(reply))
}
