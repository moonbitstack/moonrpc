// A `.proto` file is the schema of a service; in another language the code for
// it is generated from that file, and this directory is what that code looks
// like here. `greet.proto` is the schema, `greet.mbt` holds the same
// declarations with the tags and the types written out, and `cmd/rpc` derives
// the codec, the registration and the client from them (`greet.g.mbt`).
//
// Two descriptions of one service is one description too many unless they are
// held together, so this program compiles the `.proto` at run time and checks
// the two against each other: the descriptor each produces, the octets each
// writes for one message, and a call on the generated service. The generated
// client — one typed method per rpc — is driven in `proto_source_wbtest.mbt`.
//
//     moon run src/examples/30-proto-source

///|
fn same(what : String, left : String, right : String) -> Unit {
  if left != right {
    abort(
      "\{what} differs\n--- the .proto ---\n\{left}\n--- the declarations ---\n\{right}",
    )
  }
}

///|
/// One unary call over the two pure engines: the client's frames to the server,
/// the server's back, until the client has its reply.
fn call(path : String, request : Bytes) -> @moonrpc.CallReply raise {
  let server = @moonrpc.H2Server::new()
  Greeter::{ greeting: "hello", }.register(server)
  let client = @moonrpc.H2Client::new()
  let id = client.open(path)
  let to_server : Array[@http2.Frame] = [..client.preface()]
  to_server.append(client.send(id, request))
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
#coverage.skip
fn main raise {
  // The file, compiled: `moonproto` parses it, and the names a field writes —
  // `Mood`, `HelloReply.Badge` — are resolved against every declaration in it.
  let (name, text) = proto_source()
  let from_proto = @proto.compile_proto([(name, text)])[0]
  // The declarations, through the descriptor the generator wrote from them.
  let from_declarations = descriptor()
  println(
    "compiled      \{from_proto.name}  package \{from_proto.package_}  syntax \{from_proto.syntax}  \{from_proto.symbols().length()} symbols",
  )
  println(
    "declared      \{from_declarations.name}  package \{from_declarations.package_}  syntax \{from_declarations.syntax}  \{from_declarations.symbols().length()} symbols",
  )
  same("the descriptor", from_proto.source(), from_declarations.source())
  println("the two describe the same file")
  println("")

  // The same value on the wire, written twice: once by the codec the generator
  // derived, once by the schema the `.proto` compiled to. A tag or a type that
  // differs between the two descriptions shows up here as different octets.
  let request : HelloRequest = {
    name: "Leo",
    tags: ["a", "bcd"],
    nickname: Some("Leo"),
    mood: Grumpy,
    extras: { "calls": 42L, "zero": 0L },
    badge: { label: "chief", },
  }
  let schema = @moonrpc.Schema::of([from_proto])
  let bytes = @moonrpc.Message::encode(request)
  let json = schema.to_json(".greet.v1.HelloRequest", bytes)
  println("generated     \{@base16.encode(bytes)}")
  println("protobuf JSON \{@moonjson.dumps(json)}")
  let written = schema.to_bytes(".greet.v1.HelloRequest", json)
  println("via .proto    \{@base16.encode(written)}")
  same("the octets", @base16.encode(written), @base16.encode(bytes))
  println("the two write the same octets, field by field")
  println("")

  // And the reply of a real call, on the service the declarations register.
  let reply = call("/greet.v1.Greeter/SayHello", bytes)
  let back : HelloReply = @moonrpc.Message::decode(reply.messages[0])
  println(
    "SayHello      \{@moonrpc.Status::of(reply.grpc_status).name()}  \{@base16.encode(reply.messages[0])}",
  )
  println(
    "              \"\{back.message}\", \{back.call_count} call(s), \{back.scores.length()} score(s), \{back.badges[0].label}",
  )
  println(
    "              \{@moonjson.dumps(schema.to_json(".greet.v1.HelloReply", reply.messages[0]))}",
  )
}
