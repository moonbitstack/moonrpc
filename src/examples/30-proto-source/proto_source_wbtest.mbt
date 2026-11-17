// What the `.proto` and the declarations have to agree on: one check per thing
// that can drift — a tag, a type, an enum's numbers, a method's name — and one
// that the descriptor still prints a `.proto` this compiler can read back.

///|
test "the .proto and the declarations describe the same file" {
  let (name, text) = proto_source()
  let compiled = @proto.compile_proto([(name, text)])
  assert_eq(compiled.length(), 1)
  assert_eq(compiled[0].package_, "greet.v1")
  assert_true(compiled[0] == descriptor())
}

///|
test "every field of HelloRequest, with the tag and the type greet.proto gives it" {
  let expected = [
    @moonrpc.FieldDescriptor::new("name", 1, TypeString),
    @moonrpc.FieldDescriptor::new("tags", 4, TypeString, label=LabelRepeated),
    @moonrpc.FieldDescriptor::new(
      "nickname",
      5,
      TypeString,
      oneof_index=0,
      proto3_optional=true,
    ),
    @moonrpc.FieldDescriptor::new(
      "mood",
      6,
      TypeEnum,
      type_name=".greet.v1.Mood",
    ),
    @moonrpc.FieldDescriptor::new(
      "extras",
      7,
      TypeMessage,
      type_name=".greet.v1.HelloRequest.ExtrasEntry",
      label=LabelRepeated,
    ),
    @moonrpc.FieldDescriptor::new(
      "badge",
      8,
      TypeMessage,
      type_name=".greet.v1.HelloReply.Badge",
    ),
  ]
  // A descriptor compares equal field by field; the octets of each field's
  // `descriptor.proto` form say which one differs when they do not.
  let actual = descriptor().messages[0].fields
  assert_eq(actual.length(), expected.length())
  for i, want in expected {
    assert_eq(@base16.encode(actual[i].encode()), @base16.encode(want.encode()))
  }
}

///|
test "the enum keeps the .proto's numbers, the gap at 3 and 4 included" {
  let values = descriptor().enums[0].values.map(v => "\{v.name}=\{v.number}")
  assert_eq(values, [
    "MOOD_UNSPECIFIED=0", "MOOD_CALM=1", "MOOD_GLAD=2", "MOOD_GRUMPY=5",
  ])
}

///|
test "the four rpc shapes, as the .proto writes them" {
  let methods = descriptor().services[0].methods.map(m => {
    "\{m.name}:\{m.client_streaming}/\{m.server_streaming}"
  })
  assert_eq(methods, [
    "SayHello:false/false", "CountTo:false/true", "Sum:true/false", "Echo:true/true",
  ])
}

///|
/// The `.proto` itself, compiled: what a peer written in another language reads
/// a message through. Comparing against this rather than against the descriptor
/// the declarations produce is the point — the two are independent accounts of
/// the same file.
fn schema_of_the_file() -> @moonrpc.Schema raise {
  let (name, text) = proto_source()
  @moonrpc.Schema::of(@proto.compile_proto([(name, text)]))
}

///|
test "the octets the generated codec writes are the ones the .proto describes" {
  let request : HelloRequest = {
    name: "Leo",
    tags: ["a", "bcd"],
    nickname: Some("Leo"),
    mood: Grumpy,
    extras: { "calls": 42L, "zero": 0L },
    badge: { label: "chief", },
  }
  let bytes = @moonrpc.Message::encode(request)
  let schema = schema_of_the_file()
  let json = schema.to_json(".greet.v1.HelloRequest", bytes)
  assert_eq(
    @base16.encode(schema.to_bytes(".greet.v1.HelloRequest", json)),
    @base16.encode(bytes),
  )
}

///|
test "protobuf's JSON spelling: lowerCamelCase, enums by name, int64 as a string" {
  let reply : HelloReply = {
    message: "hello, Leo",
    call_count: 42L,
    scores: [1, 3],
    ratio: 0.5,
    badges: [{ label: "grumpy", }],
    portrait: b"chief",
    cached: false,
  }
  let schema = schema_of_the_file()
  let json = schema.to_json(
    ".greet.v1.HelloReply",
    @moonrpc.Message::encode(reply),
  )
  assert_eq(
    @moonjson.dumps(json),
    "{\"message\":\"hello, Leo\",\"callCount\":\"42\",\"scores\":[1,3],\"ratio\":0.5,\"badges\":[{\"label\":\"grumpy\"}],\"portrait\":\"Y2hpZWY=\"}",
  )
}

///|
/// The printed source with the absolute-name marker dropped. A type is written
/// `.greet.v1.Mood` — a leading dot says the name is absolute, which `protoc`
/// reads and moonproto's field parser does not: it reads a field's type as an
/// identifier when the type starts one. The name means the same either way,
/// because the file declares the package it is written in.
fn relative_names(text : String) -> String {
  text.replace_all(old="(.", new="(").replace_all(old=" .", new=" ")
}

///|
test "the descriptor prints a .proto that compiles back to itself" {
  let printed = descriptor().source()
  let again = @proto.compile_proto([("greet.proto", relative_names(printed))])
  assert_true(again[0] == descriptor())
}

///|
test "one call on the generated service, under the name the .proto gives" {
  let request : HelloRequest = {
    name: "Leo",
    tags: ["a", "bcd"],
    nickname: None,
    mood: Calm,
    extras: { "calls": 42L },
    badge: { label: "chief", },
  }
  let reply = call(
    "/greet.v1.Greeter/SayHello",
    @moonrpc.Message::encode(request),
  ) catch {
    e => abort("the call failed: \{e}")
  }
  assert_eq(reply.grpc_status, 0)
  let back : HelloReply = @moonrpc.Message::decode(reply.messages[0])
  assert_eq(back.message, "hello, Leo")
  assert_eq(back.call_count, 42L)
  assert_eq(back.cached, true)
}

///|
/// A `Caller` over the two pure engines, so the client `cmd/rpc` generated can be driven with
/// no socket: the service registers on a fresh server, the stream opens, the requests go out,
/// the send side half-closes, and the frames are carried across until the client has its reply.
struct InMemory {
  greeting : String
}

///|
pub impl @moonrpc.Caller for InMemory with fn invoke(
  self,
  path,
  requests,
  metadata,
  timeout_millis,
  retry,
) {
  ignore(metadata)
  ignore(timeout_millis)
  ignore(retry)
  let server = @moonrpc.H2Server::new()
  Greeter::{ greeting: self.greeting, }.register(server)
  let client = @moonrpc.H2Client::new()
  let id = client.open(path)
  let to_server : Array[@http2.Frame] = [..client.preface()]
  for request in requests {
    to_server.append(client.send(id, request))
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
// The generated client, one method per rpc, each returning what the .proto says the reply is:
// a message for the unary call, an array for the stream out, a message folded from the stream
// in, and an array for both directions.
async test "the generated client calls all four kinds, typed" {
  let client = GreeterClient::new(InMemory::{ greeting: "hello", })
  let request : HelloRequest = {
    name: "Leo",
    tags: ["a"],
    nickname: None,
    mood: Calm,
    extras: { "calls": 42L },
    badge: { label: "chief", },
  }
  let said = client.say_hello(request) catch { e => abort("say_hello: \{e}") }
  assert_eq(said.message, "hello, Leo")
  assert_eq(said.call_count, 42L)
  assert_eq(said.badges[0].label, "calm")
  let counted = client.count_to({ n: 3, }) catch {
    e => abort("count_to: \{e}")
  }
  assert_eq(counted.map(n => n.value), [1, 2, 3])
  let summed = client.add_up([{ value: 2, }, { value: 5, }]) catch {
    e => abort("sum: \{e}")
  }
  assert_eq(summed.value, 7)
  let echoed = client.echo([{ value: 1, }, { value: 2, }]) catch {
    e => abort("echo: \{e}")
  }
  assert_eq(echoed.map(n => n.value), [2, 1])
}
