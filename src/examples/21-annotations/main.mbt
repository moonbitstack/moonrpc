///|
/// A gRPC service declared with `#rpc` annotations. `greeter.g.mbt` is generated
/// from `greeter.mbt` by `cmd/rpc`; a project wires the generator as a dev_build
/// rule (see the README). The program checks the generated codec, service and
/// descriptor against the same ones written by hand in `hand.mbt`, byte for
/// byte, then shows the calls.
///
///     moon run src/examples/21-annotations
fn same(what : String, generated : String, hand : String) -> Unit {
  if generated != hand {
    abort("\{what} differs:\n  generated: \{generated}\n  by hand:   \{hand}")
  }
}

///|
fn hex(b : Bytes) -> String {
  let out = StringBuilder()
  for x in b {
    let n = x.to_int()
    out.write_char("0123456789abcdef"[n >> 4].unsafe_to_char())
    out.write_char("0123456789abcdef"[n & 15].unsafe_to_char())
  }
  out.to_string()
}

///|
/// One call on a fresh server, the frames shuttled until it completes.
fn call(
  register : (@moonrpc.H2Server) -> Unit,
  path : String,
  requests : Array[Bytes],
) -> @moonrpc.CallReply raise {
  let server = @moonrpc.H2Server::new()
  register(server)
  let client = @moonrpc.H2Client::new()
  let id = client.open(path)
  let to_server : Array[@http2.Frame] = [..client.preface()]
  for m in requests {
    to_server.append(client.send(id, m))
  }
  to_server.append(client.close_send(id))
  let to_client : Array[@http2.Frame] = [..server.preface()]
  let mut si = 0
  let mut ci = 0
  while !client.is_done(id) {
    if si < to_server.length() {
      to_client.append(server.feed(to_server[si]))
      si += 1
    } else if ci < to_client.length() {
      to_server.append(client.feed(to_client[ci]))
      ci += 1
    } else {
      break
    }
  }
  client.reply(id)
}

///|
fn shown(r : @moonrpc.CallReply) -> String {
  "status \{r.grpc_status} \{r.grpc_message} [\{r.messages.map(hex).join(", ")}]"
}

///|
#coverage.skip
fn main {
  let request : HelloRequest = {
    name: "Leo",
    tags: ["a", "bcd"],
    nickname: Some(""),
  }
  let bytes = @moonrpc.Message::encode(request)
  same("encoding", hex(bytes), hex(hand_request(request)))
  println("HelloRequest  \{hex(bytes)}")
  let back : HelloRequest = @moonrpc.Message::decode(bytes) catch {
    e => abort("decode: \{e}")
  }
  same("round trip", hex(@moonrpc.Message::encode(back)), hex(bytes))
  let greeter = Greeter::{ greeting: "hello", }
  let generated = (s : @moonrpc.H2Server) => greeter.register(s)
  let by_hand = (s : @moonrpc.H2Server) => hand_register(s, greeter)
  let calls = [
    ("/greet.Greeter/SayHello", [bytes]),
    ("/greet.Greeter/SayHello", [hand_request({ ..request, name: "", })]),
    ("/greet.Greeter/SayHello", [b"\x0a\x09short"]),
    ("/greet.Greeter/CountTo", [hand_int(1, 3)]),
    ("/greet.Greeter/Sum", [hand_int(1, 2), hand_int(1, 5), b""]),
  ]
  for c in calls {
    let (path, requests) = c
    let (g, h) = (
      call(generated, path, requests),
      call(by_hand, path, requests),
    ) catch {
      e => abort("call: \{e}")
    }
    same(path, shown(g), shown(h))
    println("\{path}  \{shown(g)}")
  }
  same(
    "descriptor",
    hex(descriptor().encode()),
    hex(hand_descriptor().encode()),
  )
  println("descriptor   \{descriptor().symbols().join(" ")}")
  println("")
  println("generated and hand-written services agree")
}
