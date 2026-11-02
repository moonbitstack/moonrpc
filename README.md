<div align="center">

# moonrpc

**Real gRPC for MoonBit — `← gRPC`.**

[![Check and Test](https://github.com/moonbitstack/moonrpc/actions/workflows/ci.yml/badge.svg)](https://github.com/moonbitstack/moonrpc/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](./LICENSE)
[![mooncakes](https://img.shields.io/badge/mooncakes-moonbitstack%2Fmoonrpc-brightgreen)](https://mooncakes.io/docs/moonbitstack/moonrpc)

</div>

> Moved on mooncakes from `Lfan-ke/moonrpc` to `moonbitstack/moonrpc`.

`moonrpc` is gRPC over HTTP/2, not gRPC-Web. HTTP/2 framing (RFC 9113) and HPACK (RFC 7541) come from moonhttp; this module is everything gRPC puts on top: all four call kinds, metadata, deadlines, status and rich errors, flow control, TLS with ALPN, message compression, interceptors on both ends, concurrent dispatch on one connection, health checking, server reflection, retries, hedging, backoff and load balancing. The client and server engines are pure functions over frames and run on every backend; only the socket driver in `net` is native.

```moonbit
#rpc.message
pub struct HelloRequest {
  name : String
}

#rpc.message
pub struct HelloReply {
  message : String
}

#rpc.service(name="greet.Greeter")
pub struct Greeter {
  greeting : String
}

#rpc.method
fn Greeter::say_hello(self : Greeter, req : HelloRequest) -> HelloReply {
  { message: self.greeting + ", " + req.name }
}

let server = @net.GrpcServer::new()
Greeter::{ greeting: "hello" }.register(server)
server.serve()             // listens on 12000
```

Annotations give the protobuf codec of each message, the registration of each service,
and the descriptor reflection serves; see [Annotations](#annotations). A method's
shape says which of gRPC's four call kinds it is.

The handler sees the call's `RpcContext`: the request metadata, the `grpc-timeout` deadline in milliseconds, and slots for response initial and trailing metadata.

**Documentation:** the [five-piece doc site](docs/index.html) — a home page, a [guide](docs/guide.html), the full [API reference](docs/api.html), and a [live in-browser showcase](docs/showcase.html) that runs the real engine.

## Annotations

`#rpc` annotations write the protobuf codec of each message, the registration of
each service, and the file descriptor reflection serves:

```moonbit
#rpc.enum
pub enum Mood { Calm = 0; Glad = 1; Grumpy = 5 }   // MOOD_CALM, MOOD_GLAD, MOOD_GRUMPY

#rpc.message
pub struct HelloRequest {
  name : String               // 1
  #rpc.field(number="4")
  tags : Array[String]        // 4
  nickname : String?          // 5, proto3 optional
  mood : Mood                 // 6
  extras : Map[String, Int64] // 7, map<string, int64>
}

#rpc.message(name="HelloReply.Badge")   // nested: .greet.HelloReply.Badge
pub struct Badge { label : String }

#rpc.service(name="greet.Greeter")
pub struct Greeter { greeting : String }

#rpc.method
fn Greeter::say_hello(self : Greeter, req : HelloRequest) -> HelloReply raise { ... }

#rpc.method
fn Greeter::count_to(self : Greeter, req : Upto) -> Array[Number] { ... }

#rpc.method
fn Greeter::echo(self : Greeter, req : Array[Number]) -> Array[Number] { ... }
```

```moonbit
Greeter::{ greeting: "hello" }.register(server)   // an H2Server or a GrpcServer
reflection.add_file(descriptor())
print(descriptor().source())                      // the .proto

let client = GreeterClient::new(@net.Channel::connect("127.0.0.1", @net.port))
let reply = client.say_hello({ name: "Leo", tags: [], nickname: None, mood: Glad, extras: {} })
let numbers = client.count_to({ n: 3 }, timeout_millis=500)
```

Fields are numbered in declaration order from 1; `number=` sets one, written as a
string because the attribute grammar has no integers, and the count carries on
from it. `#rpc.skip` leaves a field out. A method's name is the function's in
PascalCase, `name=` overriding it; returning an array streams the replies, taking
one receives a client stream, both is a bidirectional stream answered once the
client half-closes, and a parameter of type `RpcContext` receives the call's
context. A `StatusError` raised by a method answers with its status, any other
error with `UNKNOWN`, and a request that does not decode with `INTERNAL`, as
grpc-go does. A dotted `name=` nests a message or an enum inside another message
of the same file.

An enum without payloads takes `#rpc.enum`. Its values are numbered by MoonBit's
own tags (`Glad = 1`), or by `#rpc.value(number="N")`, or one past the previous,
the first being 0 as proto3 requires; each is named after the enum and itself in
upper snake case, `#rpc.value(name="...")` overriding it, as Google's style
guide and buf's `ENUM_VALUE_PREFIX` ask. A number the enum does not know reads as
its first value, or into a constructor holding one `Int` when there is one, as
Java's and Swift's `UNRECOGNIZED` keep it.

Each service also gets a client, `GreeterClient[C]` over any `Caller`: one
`async` method per RPC, taking the request and `metadata?`, `timeout_millis?` and
`retry?`, returning the decoded reply and raising a non-`OK` status as a
`StatusError`. [`cmd/greetd`](src/cmd/greetd/) calls itself through it in CI.

| MoonBit | protobuf |
|:--:|:--:|
| `String`, `Bytes`, `Bool` | `string`, `bytes`, `bool` |
| `Int`, `Int64`, `UInt`, `UInt64` | `int32`, `int64`, `uint32`, `uint64` |
| `Double`, `Float` | `double`, `float` |
| a `#rpc.message`, a `#rpc.enum` | that message, that enum |
| `Array[T]` | `repeated T`, packed for the integers, `bool` and enums |
| `T?` | `optional T` |
| `Map[K, V]` | `map<K, V>`, `K` a string, an integer or a `bool` |

[`21-annotations`](src/examples/21-annotations/) checks the generated codec,
service and descriptor against the same ones written by hand, byte for byte, and
against protoc and Python's protobuf runtime (`scripts/gen_protoc_vectors.py`).

Wire the generator into the build once. In `moon.mod`:

```
rule(name: "rpc", command: "moonx moonbitstack/moonrpc/cmd/rpc@0.21.8 -C \"$mod_dir\" \"$input\" -o \"$output\"")
```

and in the `moon.pkg` of the package holding the declarations:

```
dev_build(rule: "rpc", input: "service.mbt", output: "service.g.mbt")
formatter(ignore: [ "service.g.mbt" ])
```

## The four call kinds by hand

Annotations generate these calls, and a handler registered at run time is written the same way.

gRPC defines four shapes of a call. moonrpc implements all of them as the same frame machinery — only how many messages each side sends differs. Register the one that matches your handler, or let `#rpc` infer it from the method's type.

| Call kind | How to register | Handler shape | Typed wrapper |
|:--|:--|:--|:--|
| Unary | `server.register(path, (Bytes) -> Bytes)` | one request, one reply | `@moonrpc.unary` |
| Server streaming | `server.register_server_streaming(path, (ctx, req) -> Array[Bytes])` | one request, many replies | `@moonrpc.server_streaming` |
| Client streaming | `server.register_client_streaming(path, (ctx, msgs) -> Bytes)` | many requests, one reply | `@moonrpc.client_streaming` |
| Bidi streaming | `server.register_bidi(path, ctx => BidiHandler::{ on_message: m => [...], on_end: () => [...] })` | many both ways | `BidiHandler` |

```moonbit
// unary: one request, one reply.
server.register("/greet.Greeter/SayHello", req => handle(req))

// server-streaming: one request, an ordered run of replies.
server.register_server_streaming("/count.C/Up", (ctx, req) => [
  first(req), second(req), third(req),
])

// client-streaming: many requests collected, one reply.
server.register_client_streaming("/sum.S/Add", (ctx, msgs) => fold(msgs))

// bidi: each request answered as it arrives, a farewell at half-close.
server.register_bidi("/chat.C/Echo", ctx => @moonrpc.BidiHandler::{
  on_message: m => [reply_to(m)],
  on_end: () => [b"bye"],
})
```

## Packages

Each layer is its own subpackage, so a program links the layers it uses and no others. The root re-exports all of them, so `@moonrpc.H2Server` and `@moonrpc.encode_message` work as they always did.

|  Package  | What it holds | Depends on |
|:--:|:--|:--|
| `moonrpc/wire` | message framing, `Status`, `Method`, metadata rules, keepalive, HTTP/2 defaults | moonhttp, moonvar, moonbase |
| `moonrpc/proto` | `PbWriter`／`PbReader`, `Message`, the descriptor model and its codec | moonvar |
| `moonrpc/stream` | the stream state machine, `RpcContext`, the four handler kinds, `Registrar` | moonhttp |
| `moonrpc/balance` | retry, hedging and throttling after gRPC A6, connectivity states, balancers, DNS, the channel pool | `wire`, moonhttp, moonward, moondate, moonvar |
| `moonrpc/client` | `H2Client`, `CallReply` | `wire`, moonhttp, moonzip |
| `moonrpc/server` | `H2Server`, interceptors | `wire`, `proto`, `stream`, moonhttp, moonzip, moonbase |
| `moonrpc/service` | health checking, server reflection, and `unary`／`server_streaming`／`client_streaming` over message types | `server`, `stream`, `proto`, `wire`, moonvar |
| `moonrpc/cmd/rpc` | the generator behind the `#rpc` annotations | moonast |
| `moonrpc/net` | `GrpcServer`, `Channel`, `MuxChannel`, `ManagedChannel` over TCP and TLS (native) | the root, moonnet, moontls, moonbitlang/async |

A client links nothing of the server and a server nothing of the client; protobuf alone is `proto`.

**Constructors are written without the package.** `pub using` re-exports types but not their constructors, so `@moonrpc.Serving` does not resolve. Write the bare constructor and let the expected type pick it: `health.set_status("greet.Greeter", Serving)`. Where nothing gives the type, name the subpackage: `@wire.Status::NotFound`.

## The Channel client

A `Channel` is one long-lived h2c connection; every call multiplexes over it on its own client-allocated stream id, sharing the connection's HPACK and flow-control state.

```moonbit
let chan = @net.Channel::connect("127.0.0.1", @net.port)

// unary.
let reply = chan.unary("/greet.Greeter/SayHello", request)
reply.messages[0]   // the reply message; reply.grpc_status is 0 on success

// server-streaming: one request, every framed reply reassembled in order.
let out = chan.server_streaming("/count.C/Up", request)   // out.messages

// client-streaming: many requests, one reply.
let sum = chan.client_streaming("/sum.S/Add", [a, b, c])

// a deadline: sent as grpc-timeout and enforced locally — if it elapses the
// stream is reset and grpc_status comes back DEADLINE_EXCEEDED (4).
let bounded = chan.unary("/slow.S/Wait", request, timeout_millis=200)
```

`MuxChannel` carries many concurrent calls and interactive bidirectional streams over one connection; `ManagedChannel` dials several backends, tracks each through the gRPC connectivity states and picks one per call (`pick_first` or `round_robin`). A failed dial puts the channel on a backoff clock — one second, times 1.6, capped at two minutes, jittered ±20% — so a backend that is down costs one dial per wait rather than one per call; re-dialling resolves the name again when the channel was given one.

Both ends cap message size per engine (`set_max_message_size(recv~, send~)`); an incoming message over the cap ends its call with `RESOURCE_EXHAUSTED` rather than pinning the memory its length prefix declares, and a reply over the send cap ends it the same way. The client sends `user-agent`, `moonrpc/<version>` unless a caller sets its own.

All three implement `Caller`, the trait the clients `#rpc` generates call through; a test double or an interceptor chain implements it to stand in their place. `reply.ok()` gives the messages of a call that ended `OK` and raises any other status as a `StatusError`; `one()` also wants exactly one message, and `reply()`／`replies()` decode them into a `Message` type, `INTERNAL` when they do not decode, as grpc-go reports.

## Health

The standard `grpc.health.v1.Health` service registers in one call. `Check` answers the status of a name — `SERVING`, `NOT_SERVING`, or `NOT_FOUND` for a service the server does not know — and `Watch` keeps one stream open, sending the status at subscribe time and again on every change:

```moonbit
let health = @moonrpc.HealthService::new()
health.set_status("greet.Greeter", Serving)
server.register_health(health)      // Check + Watch on /grpc.health.v1.Health/*
health.set_status("greet.Greeter", NotServing)   // every live Watch is told
```

`Watch` is a *pushed* handler: it owns its response stream and answers over time rather than once. Any method can be written that way — `Handler::Pushed` is handed the request messages and a `Responder` with `send` and `finish` — which is what a subscription of any kind needs.

## Interceptors

One shape covers all four call kinds, on both ends. A call is the request messages it carries and the replies they produce, so a unary method is simply one message each way:

```moonbit
// server: (info, ctx, requests, next) -> replies. `add_interceptor` is on the server a
// program serves with — `GrpcServer` — and on the engine, when there is no socket.
server.add_interceptor((info, ctx, requests, next) => {
  let started = @async.now()
  let replies = next(requests)      // or answer here, without calling it
  println("{info.path} took {now - started} ms")
  replies
})

// client: (invocation, next) -> reply
chan.add_interceptor((invocation, next) => {
  let metadata = invocation.metadata.copy()
  metadata.push(@header.Header::of("authorization", "Bearer ..."))
  next({ ..invocation, metadata })
})
```

`CallInfo` carries the path and which of the two sides streams, so an interceptor that only wants unary calls reads it and passes the rest through — which is what `add_unary_interceptor` and `add_stream_interceptor` do. The client chain wraps a call once, outside the retry loop: a retry is one invocation to an interceptor, and `Invocation` holds the path, every request message, the metadata, the deadline and the retry policy.

## TLS

HTTP/2 over TLS is chosen by ALPN, so both ends offer `h2` and check what the handshake settled on before a frame is exchanged. `client_tls` and `server_tls` build the two configurations with `h2` alone:

```moonbit
// server: a certificate chain, leaf first, and its key
server.serve(port=12000, tls=@net.server_tls(@x509.pems(cert_text), @x509.PrivateKey::pem(key_text)))

// client: the roots to verify against
let chan = @net.Channel::connect("api.example.com", 12000, tls=@net.client_tls(roots))
```

`MuxChannel::connect`, `ManagedChannel::connect` and `ManagedChannel::dns_connect` take the same `tls`. A peer that offers no `h2` is closed rather than spoken to in a version it did not agree to (RFC 9113 §3.2), and a failed handshake on `serve` is a refused client, not a broken server.

## Compression

gRPC names three encodings — `identity`, `gzip` and `deflate`, the last of which is the raw DEFLATE stream rather than the zlib format — and negotiates them with `grpc-encoding` and `grpc-accept-encoding`:

```moonbit
let server = @net.GrpcServer::new()
server.set_encoding(@moonrpc.Encoding::Gzip)     // replies, for a caller that accepts it
greeter.register(server)

let chan = @net.Channel::connect("127.0.0.1", 12000, encoding=@moonrpc.Encoding::Gzip)
```

A server only compresses for a caller whose `grpc-accept-encoding` lists the encoding; a caller that accepts nothing but `identity` gets identity, because sending a body the far end cannot read is not compression. A message whose flag is set under `identity` — compressed and not compressed at once — is refused on both ends, and a body that will not inflate fails the call rather than reaching the handler as bytes. `wire.Encoding` carries the codecs and the list this library advertises.

## Concurrency on a connection

A finished call is not run inside the frame loop. The server hands it to the driver, which runs it on a task of its own, so a handler that is waiting on something holds up nothing else on the connection:

```moonbit
engine.register_handler("/slow.S/Wait", @moonrpc.Handler::Pushed((_ctx, requests, out) => {
  @async.sleep(400)                  // a slow handler, on its own task
  (out.send)(requests)
  (out.finish)()
}))
```

Deadlines are preemptive: when a call's `grpc-timeout` passes, the engine ends the stream with `DEADLINE_EXCEEDED` and the driver stops the task behind it, so a handler that would have taken half a second stops at the deadline. One lock per connection serializes writes, since calls, the reader and a shutdown GOAWAY all write the same socket.

The server also holds peers to a keepalive policy when one is set — PINGs closer together than the policy allows are strikes, and a peer that runs out of them is answered `GOAWAY(ENHANCE_YOUR_CALM)` — and refuses the frames RFC 9113 calls a protocol violation: PUSH_PROMISE, DATA or HEADERS on stream 0, a zero-increment WINDOW_UPDATE, a frame over the advertised `SETTINGS_MAX_FRAME_SIZE`, and a SETTINGS nobody acknowledges.

## Protobuf and Server Reflection

`PbWriter` and `PbReader` carry the proto3 binary format: varint, zigzag, `fixed32`／`fixed64` and length-delimited fields. The base-128 varint and the zigzag fold are moonvar's, since DWARF writes the same integer; what is here is the field structure built over it.

```moonbit
let w = @moonrpc.PbWriter::new()
w.string_(1, "testing")          // field 1, a length-delimited string
w.int32(2, -1)                   // field 2, a varint (negative -> ten octets)
let r = @moonrpc.PbReader::new(w.to_bytes())
let (field, wire) = r.read_tag() // (1, LengthDelim)
let text = r.read_string()                  // "testing"
```

On top of it, a descriptor model builds and parses `FileDescriptorProto` and `FileDescriptorSet`: imports, messages with their nested messages, enums, oneofs and `map` entries, and services. `grpc.reflection.v1.ServerReflection` (with its `v1alpha` alias) answers `ListServices`, `FileContainingSymbol` (a service, a method, a message, a nested type or an enum) and `FileByFilename`, so `grpcurl` can list and describe a service. CI runs exactly that against `cmd/greetd`. `FileDescriptor::source()` prints the `.proto` a descriptor describes; protoc compiles it back to the same descriptor, which `21-annotations` checks.

```moonbit
let greeter : @moonrpc.ServiceDescriptor = {
  name: "Greeter",
  methods: [
    { name: "SayHello", input_type: ".greet.HelloRequest",
      output_type: ".greet.HelloReply",
      client_streaming: false, server_streaming: false },
  ],
}
let refl = @moonrpc.ReflectionService::new()
refl.add_file(@moonrpc.FileDescriptor::new("greet.proto", "greet", services=[greeter]))
server.register_reflection(refl)
```

## The engines

Everything below `serve` is a pure engine: `feed` turns a decoded frame into the frames to write back, so the whole server path (HPACK, flow control, dispatch, HEADERS + DATA + `grpc-status` trailers) runs in memory on every backend. `H2Client` is the same on the other side, and the root package's tests drive the two against each other with no socket.

```moonbit
let engine = @moonrpc.H2Server::new()
engine.register("/echo.Echo/Say", req => req)
let out = engine.feed(frame)   // -> [HEADERS(:status 200), DATA(reply), HEADERS(grpc-status:0)]
```

What the server refuses: a request line that is not gRPC's (`:method` other than POST, a `content-type` not starting `application/grpc`, no `te: trailers`) gets an HTTP status instead of 200; `SETTINGS_MAX_CONCURRENT_STREAMS` is advertised and enforced with REFUSED_STREAM; overrunning a flow-control window is FLOW_CONTROL_ERROR; a field block must arrive contiguously (RFC 9113 §6.10); a call already past its `grpc-timeout` never reaches its handler.

## Framing and status

```moonbit
let frame = @moonrpc.encode_message(b"hello grpc")
// [0x00][0x00 0x00 0x00 0x0A]["hello grpc"]  — 1-byte flag + 4-byte big-endian length + payload

let (compressed, payload) = @moonrpc.decode_message(frame).unwrap()
// (false, b"hello grpc")

let code = @moonrpc.Status::code(NotFound)          // 5
let name = @moonrpc.Status::name(Unauthenticated)   // "UNAUTHENTICATED", one of the 17 codes

let m : @moonrpc.Method = { service: "greet.Greeter", name: "SayHello" }
let path = m.path()                                 // "/greet.Greeter/SayHello"
```

## Retries and hedging

Retries follow gRPC proposal A6, checked against grpc-go and grpc-java. Every call kind takes `retry`; a channel takes `throttling` once, for the server name it reaches.

```moonbit
let chan = @net.Channel::connect(
  "127.0.0.1",
  @net.port,
  throttling=@moonrpc.Throttling::new(tokens=10, ratio=0.1),
)
let reply = chan.unary(
  "/greet.Greeter/SayHello",
  b"Ada",
  timeout_millis=2000,
  retry=@moonrpc.retry,
)
```

| Rule | What happens |
|:--:|:--|
| Backoff | `min(base × factor^(n−1), cap)` times `random(0.8, 1.2)`; the preset is A6's example, four attempts from 100 ms doubling to 1 s |
| Status | only a status in `codes` is retried; OK and anything else go back to the caller |
| Committed | once response headers arrive, the call is never retried |
| Pushback | `grpc-retry-pushback-ms` sets the next wait exactly and restarts the backoff; a negative or unreadable value stops |
| Throttle | a retryable failure takes a token, a success gives back `ratio`; at half the tokens or fewer nothing is retried or hedged |
| Transparent | a stream the server refused, or one a GOAWAY shows it never handled, goes again at once, without a policy and without counting |
| Limit | at most five attempts whatever a policy asks, the client-side limit A6 sets |
| Metadata | each retry carries `grpc-previous-rpc-attempts` |
| Deadline | one deadline for the whole call; each attempt's `grpc-timeout` is what is left of it |

`ManagedChannel` picks a backend for every attempt, so a retry can land elsewhere, and `unary_hedged` takes `hedging`: the next attempt every `delay` or at once after a non-fatal status, the pushback and the throttle applying as for retries.

## Not yet

- `channelz`, `WaitForReady`, `stats.Handler` and service config (gRPC A14); no client-side keepalive policy beyond `MuxChannel::run_keepalive`.
- Descriptor options other than `map_entry`; `oneof` and imports from `#rpc`; extensions anywhere in the descriptor model — the reflection queries are answered, but there is nothing to report.
- HPACK `never-indexed` literals: the encoder indexes what it is given, and sends the dynamic table size update the peer asks for.
- `-bin` metadata goes out base64-padded. Receivers accept both forms (and `metadata_value_from_wire` reads unpadded), and the suite pins the padded form.

## Licence

Apache-2.0. See [LICENSE](LICENSE).
