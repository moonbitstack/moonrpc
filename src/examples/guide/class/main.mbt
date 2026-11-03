///|
/// Run the same greeter written as a struct with methods.
///
///     moon run src/examples/guide/class
struct Greeter {
  prefix : String
}

///|
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
fn Greeter::say_hello(self : Greeter, req : Bytes) -> Bytes {
  encode_reply(self.prefix + ", " + decode_name(req))
}

///|
fn Greeter::register(self : Greeter, server : @moonrpc.H2Server) -> Unit {
  server.register_unary("/greet.Greeter/SayHello", (_ctx, req) => {
    self.say_hello(req)
  })
}

///|
fn main {
  let reply = @harness.round_trip(
    server => Greeter::{ prefix: "Hello", }.register(server),
    "/greet.Greeter/SayHello",
    encode_request("Ada"),
  ) catch {
    _ => abort("the call failed")
  }
  println(decode_reply(reply))
}
