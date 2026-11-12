<div align="center">

# moonrpc

**Real gRPC for MoonBit — `← gRPC`.**

[![Check and Test](https://github.com/moonbitstack/moonrpc/actions/workflows/ci.yml/badge.svg)](https://github.com/moonbitstack/moonrpc/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](./LICENSE)
[![mooncakes](https://img.shields.io/badge/mooncakes-moonbitstack%2Fmoonrpc-brightgreen)](https://mooncakes.io/docs/moonbitstack/moonrpc)

</div>

> Moved on mooncakes from `Lfan-ke/moonrpc` to `moonbitstack/moonrpc`.

`moonrpc` is gRPC over HTTP/2, not gRPC-Web. HTTP/2 framing (RFC 9113) and HPACK (RFC 7541) come from moonhttp; this module is everything gRPC puts on top: all four call kinds, metadata, deadlines, status and rich errors, flow control, TLS with ALPN, message compression, interceptors on both ends, concurrent dispatch on one connection, health checking, server reflection, retries, hedging, backoff and load balancing, a stats observable and a channelz registry, and service-config driven retries with WaitForReady. Beside it sit four more protocol stacks: Thrift (framed, buffered, zlib, HTTP and header transports; binary, compact and JSON protocols; a processor, a client and an IDL compiler), trpc.group's tRPC (all four call kinds, interoperating with tRPC-Go and tRPC-Python), tRPC for TypeScript (JSON over HTTP with its batching envelope, interoperating with `@trpc/client` and `@trpc/server`), and Connect over HTTP/1.1 and HTTP/2 (the same four call kinds in protobuf or JSON, driven by the official conformance suite from both sides). The client and server engines are pure functions over frames and run on every backend; only the socket drivers in `net` are native.

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

test {
  let greeter = Greeter::{ greeting: "hello" }
  assert_eq(greeter.say_hello({ name: "Leo" }).message, "hello, Leo")
}
```

Annotations give the protobuf codec of each message, the registration of each service,
and the descriptor reflection serves; see [Annotations](#annotations). A method's
shape says which of gRPC's four call kinds it is.

The handler sees the call's `RpcContext`: the request metadata, the `grpc-timeout` deadline in milliseconds, and slots for response initial and trailing metadata.

A server reports the port it actually bound: `GrpcServer::bind` opens the socket and hands
back its address, and `bind_thrift` does the same for the Thrift driver, so `port=0` asks the
system for a free one. Both are what the test suite uses — `moon test` runs tests in parallel,
and a test that names a port is a test that collides with another one.

**Documentation:** the [five-piece doc site](docs/index.html) — a home page, a [guide](docs/guide.html), the full [API reference](docs/api.html), and a [live in-browser showcase](docs/showcase.html) that runs the real engine.

## Annotations

`#rpc` annotations write the protobuf codec of each message, the registration of
each service, and the file descriptor reflection serves:

```moonbit
#rpc.enum
pub enum Mood { Calm = 0; Glad = 1; Grumpy = 5 }   // MOOD_CALM, MOOD_GLAD, MOOD_GRUMPY

#rpc.message
pub struct Profile {
  name : String               // 1
  #rpc.field(number="4")
  tags : Array[String]        // 4
  nickname : String?          // 5, proto3 optional
  mood : Mood                 // 6
  extras : Map[String, Int64] // 7, map<string, int64>
}

#rpc.message(name="HelloReply.Badge")   // nested: .greet.HelloReply.Badge
pub struct Badge { label : String }

#rpc.message
pub struct Upto { n : Int }

#rpc.message
pub struct Number { value : Int }

#rpc.method
fn Greeter::count_to(_self : Greeter, req : Upto) -> Array[Number] {
  let out = []
  for i = 1; i <= req.n; i = i + 1 {
    out.push({ value: i })
  }
  out
}

#rpc.method
fn Greeter::echo(_self : Greeter, req : Array[Number]) -> Array[Number] {
  req
}
```

```moonbit native
// From the declarations above the generator writes a `Message` impl per message, and
// `Greeter::register(server)` plus `Greeter::descriptor()` per service. Written out by
// hand, registration is one line per method:
fn wire_greeter(server : @net.GrpcServer) -> Unit {
  server.register_unary("/greet.Greeter/SayHello", (_ctx, req) => req)
}

// The descriptor is what reflection serves, and it can be printed back as a .proto.
fn print_descriptor() -> Unit raise {
  let file = @moonrpc.FileDescriptor::new("greet.proto", "greet")
  println(file.source())
}

// A generated client takes a channel and returns typed replies:
//   let client = GreeterClient::new(@net.Channel::connect("127.0.0.1", @net.port))
//   let reply = client.say_hello({ name: "Leo" })
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
rule(name: "rpc", command: "moonx moonbitstack/moonrpc/cmd/rpc@0.21.12 -C \"$mod_dir\" \"$input\" -o \"$output\"")
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
fn register_four_kinds(server : @moonrpc.H2Server) -> Unit {
  // unary: one request, one reply.
  server.register("/greet.Greeter/SayHello", req => b"hello:" + req)

  // server-streaming: one request, an ordered run of replies.
  server.register_server_streaming("/count.C/Up", (_ctx, req) => [req, req, req])

  // client-streaming: every request is collected, then one reply.
  server.register_client_streaming("/sum.S/Add", (_ctx, msgs) => msgs[0])

  // bidi: each request answered as it arrives, a farewell at half-close.
  server.register_bidi("/chat.C/Echo", _ctx => @stream.BidiHandler::{
    on_message: m => [m],
    on_end: () => [b"bye"],
  })
}
```

## Packages

Each layer is its own subpackage, so a program links the layers it uses and no others. The root re-exports all of them, so `@moonrpc.H2Server` and `@moonrpc.encode_message` work as they always did.

|  Package  | What it holds | Depends on |
|:--:|:--|:--|
| `moonrpc/wire` | message framing, `Status`, `Method`, metadata rules, keepalive, HTTP/2 defaults | moonhttp, moonvar, moonbase |
| `moonrpc/proto` | `PbWriter`／`PbReader`, `Message`, the descriptor model and its codec | moonvar |
| `moonrpc/stream` | the stream state machine, `RpcContext`, the four handler kinds, `Registrar` | moonhttp |
| `moonrpc/balance` | retry, hedging and throttling after gRPC A6, the service config, connectivity states, balancers, DNS, the channel pool | `wire`, moonhttp, moonward, moondate, moonvar, json |
| `moonrpc/client` | `H2Client`, `CallReply` | `wire`, moonhttp, moonzip |
| `moonrpc/server` | `H2Server`, interceptors | `wire`, `proto`, `stream`, moonhttp, moonzip, moonbase |
| `moonrpc/service` | health checking, server reflection, a channelz registry, and `unary`／`server_streaming`／`client_streaming` over message types | `server`, `stream`, `proto`, `wire`, moonvar |
| `moonrpc/channelz` | the canonical `grpc.channelz.v1.Channelz` descriptor and its seven RPCs | `service`, `stream`, `proto`, `wire` |
| `moonrpc/thrift` | the `Protocol` contract, TBinaryProtocol and TCompactProtocol, TFramedTransport, the processor and the client, independent of gRPC | core |
| `moonrpc/trpc` | the tRPC frame and its two unary headers, the four streaming frames, a server over `Registrar` and a client over a byte link | `stream`, `client`, `proto`, `wire` |
| `moonrpc/connect` | the Connect protocol: content types, the streaming envelope, the error body, and the dispatch that turns a request into a response | `wire`, `proto`, `stream`, moonhttp, moonjson, moonzip |
| `moonrpc/trpcio` | tRPC for TypeScript: the JSON body, the batching envelope, a procedure table and a client, independent of gRPC | moonjson |
| `moonrpc/cmd/rpc` | the generator behind the `#rpc` annotations | moonast |
| `moonrpc/cmd/thriftc` | the `.thrift` IDL compiler: types, codecs, service registration and client | core |
| `moonrpc/net` | `GrpcServer`, `Channel`, `MuxChannel`, `ManagedChannel` over TCP and TLS (native) | the root, moonnet, moontls, moonbitlang/async |

A client links nothing of the server and a server nothing of the client; protobuf alone is `proto`.

**Constructors are written without the package.** `pub using` re-exports types but not their constructors, so `@moonrpc.Serving` does not resolve. Write the bare constructor and let the expected type pick it: `health.set_status("greet.Greeter", Serving)`. Where nothing gives the type, name the subpackage: `@wire.Status::NotFound`.

## The Channel client

A `Channel` is one long-lived h2c connection; every call multiplexes over it on its own client-allocated stream id, sharing the connection's HPACK and flow-control state.

```moonbit native
async fn channel_calls(chan : @net.Channel) -> Unit raise {
  // unary: the reply messages, in order, and the status that ended the call.
  let reply = chan.unary("/greet.Greeter/SayHello", b"Leo")
  assert_eq(reply.grpc_status, 0)
  assert_eq(reply.messages.length(), 1)

  // server-streaming: one request, every framed reply reassembled in order.
  let out = chan.server_streaming("/count.C/Up", b"3")
  assert_eq(out.messages.length(), 3)

  // client-streaming: many requests, one reply.
  let sum = chan.client_streaming("/sum.S/Add", [b"a", b"b", b"c"])
  assert_eq(sum.messages.length(), 1)

  // a deadline: sent as grpc-timeout and enforced locally — if it elapses the stream is
  // reset and grpc_status comes back DEADLINE_EXCEEDED (4).
  let bounded = chan.unary("/slow.S/Wait", b"x", timeout_millis=200)
  assert_eq(bounded.grpc_status is 4 || bounded.grpc_status is 0, true)
}
```

`MuxChannel` carries many concurrent calls and interactive bidirectional streams over one connection; `ManagedChannel` dials several backends, tracks each through the gRPC connectivity states and picks one per call (`pick_first` or `round_robin`). A failed dial puts the channel on a backoff clock — one second, times 1.6, capped at two minutes, jittered ±20% — so a backend that is down costs one dial per wait rather than one per call; re-dialling resolves the name again when the channel was given one.

Both ends cap message size per engine (`set_max_message_size(recv~, send~)`); an incoming message over the cap ends its call with `RESOURCE_EXHAUSTED` rather than pinning the memory its length prefix declares, and a reply over the send cap ends it the same way. The client sends `user-agent`, `moonrpc/<version>` unless a caller sets its own.

All three implement `Caller`, the trait the clients `#rpc` generates call through; a test double or an interceptor chain implements it to stand in their place. `reply.ok()` gives the messages of a call that ended `OK` and raises any other status as a `StatusError`; `one()` also wants exactly one message, and `reply()`／`replies()` decode them into a `Message` type, `INTERNAL` when they do not decode, as grpc-go reports.

## Health

The standard `grpc.health.v1.Health` service registers in one call. `Check` answers the status of a name — `SERVING`, `NOT_SERVING`, or `NOT_FOUND` for a service the server does not know — and `Watch` keeps one stream open, sending the status at subscribe time and again on every change:

```moonbit
fn health_service() -> @moonrpc.HealthService {
  let health = @moonrpc.HealthService::new()
  health.set_status("greet.Greeter", @service.ServingStatus::Serving)
  // Check and Watch answer on /grpc.health.v1.Health/*; a status change is pushed to
  // every live Watch.
  health.set_status("greet.Greeter", @service.ServingStatus::NotServing)
  health
}
```

`Watch` is a *pushed* handler: it owns its response stream and answers over time rather than once. Any method can be written that way — `Handler::Pushed` is handed the request messages and a `Responder` with `send` and `finish` — which is what a subscription of any kind needs.

## Interceptors

One shape covers all four call kinds, on both ends. A call is the request messages it carries and the replies they produce, so a unary method is simply one message each way:

```moonbit
fn logging_interceptor() -> @server.Interceptor {
  (info, _ctx, requests, next) => {
    // Answer here without calling `next` to serve the call yourself.
    let replies = next(requests)
    println("{info.path} answered {replies.length()}")
    replies
  }
}

fn authorize() -> @client.Interceptor {
  // A client interceptor sees the invocation and may change what goes out.
  async fn(invocation, next) {
    let metadata = invocation.metadata
    metadata.push(@header.Header::of("authorization", "Bearer ..."))
    next({ ..invocation, metadata })
  }
}
```

`CallInfo` carries the path and which of the two sides streams, so an interceptor that only wants unary calls reads it and passes the rest through — which is what `add_unary_interceptor` and `add_stream_interceptor` do. The client chain wraps a call once, outside the retry loop: a retry is one invocation to an interceptor, and `Invocation` holds the path, every request message, the metadata, the deadline and the retry policy.

## TLS

HTTP/2 over TLS is chosen by ALPN, so both ends offer `h2` and check what the handshake settled on before a frame is exchanged. `client_tls` and `server_tls` build the two configurations with `h2` alone:

```moonbit native
async fn serve_over_tls(cert_text : String, key_text : String) -> Unit raise {
  let server = @net.GrpcServer::new()
  server.register("/echo.Echo/Say", req => req)
  // leaf certificate first, then the chain; ALPN settles on `h2`.
  server.serve(
    port=12000,
    tls=@net.server_tls(@x509.pems(cert_text), @x509.PrivateKey::pem(key_text)),
  )
}

async fn call_over_tls(roots : @x509.Roots) -> Unit raise {
  let chan = @net.Channel::connect(
    "api.example.com",
    12000,
    tls=@net.client_tls(roots),
  )
  chan.close()
}
```

`MuxChannel::connect`, `ManagedChannel::connect` and `ManagedChannel::dns_connect` take the same `tls`. A peer that offers no `h2` is closed rather than spoken to in a version it did not agree to (RFC 9113 §3.2), and a failed handshake on `serve` is a refused client, not a broken server.

## Compression

gRPC names three encodings — `identity`, `gzip` and `deflate`, the last of which is the raw DEFLATE stream rather than the zlib format — and negotiates them with `grpc-encoding` and `grpc-accept-encoding`:

```moonbit native
async fn compressed_traffic(server : @net.GrpcServer, host : String) -> Unit raise {
  // The server compresses a reply when the caller says it accepts the encoding.
  server.set_encoding(@moonrpc.Encoding::Gzip)
  let chan = @net.Channel::connect(
    host,
    12000,
    encoding=@moonrpc.Encoding::Gzip,
  )
  chan.close()
}
```

A server only compresses for a caller whose `grpc-accept-encoding` lists the encoding; a caller that accepts nothing but `identity` gets identity, because sending a body the far end cannot read is not compression. A message whose flag is set under `identity` — compressed and not compressed at once — is refused on both ends, and a body that will not inflate fails the call rather than reaching the handler as bytes. `wire.Encoding` carries the codecs and the list this library advertises.

## Interoperability

A gRPC implementation is only gRPC if a foreign one agrees on the bytes, and an implementation
is only self-consistent if its own two halves do. CI runs all three pairings — grpc-go against
this stack, Apache Thrift against this stack, and this stack against itself — in plaintext and
over TLS:

| Partner | Direction | Calls | Compression | Interceptors | TLS | Result |
|:--|:--|:--|:--|:--|:--|:--|
| `grpcurl` (grpc-go) | client | reflection `list`／`describe`, all four | `gzip` | — | yes | pass |
| grpc-go | client | all four, plus `x-test-*` metadata, a deadline, a rich error detail and a 160 KB message | `gzip` | client chain | yes | pass |
| grpc-go | server | the same calls, through the generated `GreeterClient` | `gzip` | server chain | yes | pass |
| Apache Thrift (Go) | client | `ping`, `add`, `double`, `fail`, `note` (ONEWAY) — framed, buffered, zlib, HTTP and header transports; binary, compact and JSON protocols; the header zlib transform | identity | — | no | pass |
| Apache Thrift (Go) | server | the same calls, through `thriftd check` | identity | — | no | pass |
| Apache Thrift cross test | client | `ThriftTest`: all 23 methods, framed／buffered／zlib／HTTP × binary／compact／json | identity | — | no | pass |
| Apache Thrift cross test | server | the same 23 methods, driven from this side | identity | — | no | pass |
| moonrpc | client and server | `greetd check` against `greetd`: all four, metadata, deadline, detail, 160 KB batch | `gzip` | both halves | yes | pass |
| moonrpc | client and server | `thriftd check` against `thriftd`: `ping`, `add`, `double`, `fail`, `note`; six transports × three protocols | `zlib` on header | — | no | pass |
| tRPC-Go | client | `SayHello` (unary), `Count` (server streaming), `Sum` (client streaming), `Chat` (bidirectional), with metadata and a timeout | identity | — | no | pass |
| tRPC-Go | server | the same four calls, through `trpcd check` | identity | — | no | pass |
| tRPC-Python | client | the same four calls | identity | — | no | pass |
| tRPC-Python | server | the same four calls, through `trpcd check` | identity | — | no | pass |
| tRPC for TypeScript (`@trpc/client`) | client | `greet.hello`, `math.add`, `greet.remember` (a mutation), `greet.fail`, and a three-call batch through `httpBatchLink` | identity | — | no | pass |
| tRPC for TypeScript (`@trpc/server`) | server | the same calls, through `trpciod check` | identity | — | no | pass |
| moonrpc | client and server | `trpcd check` against `trpcd` | identity | — | no | pass |
| moonrpc | client and server | `trpciod check` against `trpciod` | identity | — | no | pass |

`cmd/greetd` is the server the first two call; the third runs the same generated client
against a grpc-go server and requires the two answers to match byte for byte. The
grpc-go side lives in `scripts/interop`, generated from the same `greet.proto` shape the
annotations declare.

What each of those calls carries is part of the matrix, not beside it: a message alone would
exercise the framing and nothing else. `SayHello` answers with the `x-test-*` metadata the
caller attached and the deadline it was given, so a header the far end dropped, or a
`grpc-timeout` that never arrived, fails the job. An empty name comes back `INVALID_ARGUMENT`
with a `google.protobuf.StringValue` in `grpc-status-details-bin` — the detail is what grpc-go's
`status.Details()` decodes, and one direction checks it with grpc-go's runtime and the other
with this library's reader. `BatchEcho` carries 40000 `int32`s, which is 160 KB: both
directions need more than one HTTP/2 frame and a window update in the middle of the message,
which a call that fits in a frame never asks for.

The Thrift rows are the protocol stack below: framed, buffered, zlib, HTTP and header transports,
with binary, compact or JSON inside each, and the header transport's zlib transform. `note` is a
ONEWAY method — it must leave no reply on the wire, which the call that follows would otherwise
read as its own. The tRPC rows run one method per cardinality, the bidirectional one message at
a time: a server that waited for the send side to close before answering would deadlock against it.
The tRPC-for-TypeScript rows are not the same protocol as those: they are JSON over HTTP, and
what they check is the batching envelope — three calls in one request, answered in the order
they were asked, each either a result or an error — through the peer's real `httpLink` and
`httpBatchLink`.

The two `moonrpc` rows are the third pairing, this stack against itself, and they cover what
no foreign job can: one transport on **both** sides at once. A peer picks its own settings, so
`grpc-go` over TLS only ever says this server speaks TLS to someone else; `greetd check` says
this client and this server agree in each of the four configurations, and `thriftd check` says
the same for every Thrift combination. `scripts/interop/self_test.sh` is that run, one case per
configuration. Connect's two halves meet in `connect_wbtest.mbt` over a real socket; the official
suite drives the server half with a foreign client (3556 cases) and this client against the
runner's reference server (4292 cases).

## Conformance

The suites below are other people's programs, not ours, and each runs in CI on
`ubuntu-26.04`: a failing one fails the build. The Thrift rows are Apache's own cross test,
built from a pinned tag with bindings generated by that release's compiler.

| Suite | What it checks | Result |
|:--|:--|:--|
| `grpcurl` (grpc-go) | reflection `list` and `describe`, all four call kinds, gzip, a non-OK status | pass |
| grpc-go client | the same server over plaintext and TLS, with an interceptor chain | pass |
| grpc-go server | this client against it, all four call kinds; both answers byte for byte | pass |
| `grpc.channelz.v1.Channelz` through `grpcurl` | the seven RPCs, the oneofs, the well-known imports | pass |
| Apache Thrift cross test, client | `ThriftTest` as served here: 23 methods × framed／buffered／zlib／HTTP × binary／compact／json | pass |
| Apache Thrift cross test, server | the same 23 methods as this client calls them, in the same twelve pairings | pass |
| tRPC-Go, both directions | `scripts/interop/trpc_interop.sh`: their codec's frames to this server and this client's frames to their server, one method per cardinality | pass |
| tRPC-Python, both directions | the same pairings, with `TrpcClientCodec`/`TrpcServerCodec` | pass |
| tRPC differential | five requests and three response headers encoded by tRPC-Python 1.0.0, reproduced octet for octet | pass |
| tRPC for TypeScript, both directions | `scripts/interop/trpcio_interop.sh`: their client's links to this server and this client to their server, four procedures plus the batch envelope | pass |
| `connectrpc/conformance`, server | 3556 cases: this reference service against the runner's reference client, both HTTP versions, both codecs, TLS and plaintext, five compressions | no unexpected failure; 70 flaky |
| `connectrpc/conformance`, client | 4292 cases: this client against the runner's reference server, the same matrix including all 76 cancellation cases | pass |

`scripts/interop/build_thrift_peers.sh` builds the reference client and server;
`scripts/interop/thrift_cross_test.sh` runs both directions; `src/cmd/thriftcrosstest` is
this side of each. The Thrift rows cover the strict message header, every primitive, structs
nested two deep, maps of maps, sets, a uuid, a `oneway` method, and the two ways a call can
fail: an exception in the field its `throws` clause numbers, and the application exception a
processor builds when a handler raises something else.

What the cross test cannot reach is the header transport — its binaries spell that one
`-protocol header`, and the pair in `scripts/interop/thriftclient` / `thriftserver` is what
covers it, alongside the self-interop matrix. The IDL's `SecondService` is still outside the
cross test, and `testOneway` is answered without the reference servers' sleep.

The two Connect rows are the same runner in opposite modes, and both are gated directly — no
declared failures. The cancellation cases are driven over an incremental exchange: the request
head goes out first, each message is its own write, and the caller closes or aborts the send
side at the point the case names. HTTP/1.1 drops the socket mid-chunk; HTTP/2 sends
`RST_STREAM` with `CANCEL`.

## Stats and channelz

Both engines report each RPC's life to a `StatsHandler` — begin, every header and payload
that moves, and the status it ended with — and the same event order on each side:

```moonbit
fn stats_handler() -> @moonrpc.StatsHandler {
  @moonrpc.StatsHandler::new(rpc=event => {
    match event {
      @wire.RpcStats::Begin(path~, name~) => println("begin {path} {name}")
      @wire.RpcStats::End(status~, message~) => println("end {status} {message}")
      _ => ()
    }
  })
}
```

A native `Channel`, `ManagedChannel` and `GrpcServer` forward the handler to every
connection. A `Registry` turns those events into channelz-style counters: calls started,
succeeded and failed, messages each way, and a connectivity state that follows the
connection events.

```moonbit
fn channelz_registry() -> @moonrpc.Registry {
  let registry = @moonrpc.Registry::new()
  // The handler a channel reports its calls through.
  let id = registry.add_channel("127.0.0.1:12000")
  registry.channel_handler(id) |> ignore
  registry
}
```

The same registry backs the canonical `grpc.channelz.v1.Channelz` service.
`ChannelzService` registers its seven RPCs on any server and adds `channelz.proto` and
the four well-known files it imports to reflection, so `grpcurl` can list, describe and
call it — oneofs, nested messages and all:

```moonbit native
fn install_channelz(server : @net.GrpcServer) -> Unit {
  let registry = @moonrpc.Registry::new()
  let server_id = registry.add_server()
  ignore(registry.add_server_socket(server_id, "127.0.0.1:12000"))
  let channelz = @moonrpc.ChannelzService::new(registry)
  channelz.install(server)
  let reflection = @moonrpc.ReflectionService::new()
  channelz.add_to_reflection(reflection)
  server.register_reflection(reflection)
}
```

[`cmd/channelzd`](src/cmd/channelzd/) is the runnable form; CI calls `GetServers`,
`GetServer`, `GetServerSockets`, `GetSocket`, `GetTopChannels`, `GetChannel` and
`GetSubchannel` with `grpcurl` and checks the answers.

## Service configuration and WaitForReady

A channel parses gRPC's service-config JSON and applies each method's `retryPolicy`,
`timeout` and `waitForReady`, leaving a setting the caller gave explicitly alone:

```moonbit native
async fn configured_call(host : String) -> Unit raise {
  let text =
    #|{
    #|  "methodConfig": [{
    #|    "name": [{"service": "greet.Greeter", "method": "SayHello"}],
    #|    "timeout": "1.5s",
    #|    "waitForReady": true,
    #|    "retryPolicy": {
    #|      "maxAttempts": 4, "initialBackoff": "0.1s", "maxBackoff": "1s",
    #|      "backoffMultiplier": 2, "retryableStatusCodes": ["UNAVAILABLE"]
    #|    }
    #|  }]
    #|}
  let config = @moonrpc.ServiceConfig::parse(text) catch {
    _ => @moonrpc.ServiceConfig::empty()
  }
  let chan = @net.ManagedChannel::connect(
    [("127.0.0.1", 12000)],
    config=config,
  )
  chan.close()
}
```

With wait-for-ready, a `ManagedChannel` whose backends are all down holds the call and
redials until one comes up or the call's deadline passes, instead of failing fast with
`UNAVAILABLE`. It is on by default for a method whose config says `waitForReady`, and a
call can turn it on with `wait_for_ready~` whether or not a config names it.

## Thrift

A second protocol stack sits beside the gRPC one and shares only the socket layer: a
processor that dispatches by method name, a client that sends a CALL and reads a REPLY, and
six ways to put the bytes on the wire. Nothing in `thrift/` imports HTTP/2, HPACK or protobuf.

The wire format is a choice rather than a copy. `Protocol` is the contract; `Binary`,
`Compact` and `Json` are three implementations of it — fixed-width big-endian numbers with
fixed field ids, zigzag varints with field-id deltas and a double written little-endian, or
TJSONProtocol's arrays and objects keyed by field id. A text format ends a message with a
bracket rather than with its last field, so the contract also carries `read_message_end`,
`write_message_end` and `consumed`: the octets a reader has taken. `message_len` uses them to
find where a message ends when no length was written in front of it.

The processor, the client request and a service's handlers are written once, against the
trait, so a service answers any of the three without knowing which one it got. The JSON
implementation is checked against Apache Thrift's own Go encoder: `scripts/interop/thriftjson`
writes the vectors, and the test reads each with this package and writes it back byte for byte.

`ThriftWire` in `net` picks the transport: `Framed` puts a four-octet length in front of each
message; `Buffered` writes messages back to back and the reader grows a buffer until
`message_len` finds a whole one; `Zlib` is one DEFLATE stream in each direction, split at the
`00 00 ff ff` a synchronising flush leaves — the only marker in DEFLATE that says a message
ends there, and one decoder must live for the whole connection because the compressor may
refer back into an earlier message; `Http` is one POST per call. The header transport frames
its own messages and can carry its zlib transform on top.

```moonbit native
async fn serve_and_call_thrift() -> Unit raise {
  let processor = @thrift.Processor::new()
  processor.add("ping", proto => {
    ignore(proto.read_field_begin())                 // field 1: the argument
    let text = proto.read_string()
    ignore(proto.read_field_begin())                 // STOP
    proto.write_field_begin(@thrift.type_string, 0)  // field 0: the result
    proto.write_string("pong:" + text)
  })
  let listener = @net.bind_thrift(host="127.0.0.1", port=0)
  let port = listener.addr().port()
  // Serve on a socket that is already bound, so the port is known before the loop starts.
  let serving = @async.with_task_group(group => {
    group.spawn_bg(() => {
      @net.serve_thrift_on(listener, processor, () => @thrift.Binary::new(b""))
    })
    let proto : &@thrift.Protocol = @thrift.Compact::new(b"")
    let client = @net.ThriftClient::connect("127.0.0.1", port, proto)
    let pong = @thrift.call(client, proto, "ping", 1, proto => {
      proto.write_field_begin(@thrift.type_string, 1)
      proto.write_string("moonrpc")
    }, proto => proto.read_string())
    client.close()
    assert_eq(pong, "pong:moonrpc")
  })
  ignore(serving)
}
```

[`cmd/thriftd`](src/cmd/thriftd/) serves `ping`, `add`, `double`, `fail` and a ONEWAY `note`;
`thriftd check` calls them, and words after the port pick the bytes on either side —
`framed`｜`buffered`｜`zlib`｜`http`｜`header`｜`header-zlib` for the transport and
`binary`｜`compact`｜`json` for the protocol. CI runs an Apache Thrift Go client against it
and the moonrpc client against an Apache Thrift Go server in sixteen combinations, and
Apache's own cross test drives all 23 methods of `ThriftTest` in both directions over twelve
transport/protocol pairings. Between them they cover the strict message header, `bool`,
`byte`, `i16`, `i32`, `i64`, `double`, `string`, structs, lists, sets and maps, with a depth
guard on `skip`. `fail` answers a value in field 0 or an exception in field 1, so the shape a
`throws` clause gives a reply is checked against Apache's client and server as well.

The header transport is the row that only a foreign peer can settle. Its frame names the inner
protocol, so a server that wrote compact bytes under a `binary` label would be unreadable to
every Apache client, and a peer that trusted the label is the only thing that notices — its
read of our reply fails, where our own two halves would agree with each other. `note` is the
other: a ONEWAY call must leave nothing behind, and the call after it is what would read a
stray reply frame if the server wrote one.

The three pieces of Thrift that a hand-written service trips over are settled here.
A `uuid` is sixteen raw bytes with no length in front — a type of its own, not a `binary`.
A `set` carries its own field type, and in the compact protocol its own collection header,
so a reader can tell it from a `list`; `write_set_begin` exists for that reason. And a
handler that raises answers a `TApplicationException` carrying the message instead of
dropping the connection, which is what an Apache Thrift processor does with an exception
raised out of a handler:

```moonbit
fn thrift_failures() -> @thrift.Processor {
  let processor = @thrift.Processor::new()
  processor.add("find", proto => {
    ignore(proto.read_field_begin())
    ignore(proto.read_string())
    raise @thrift.Application("no such key")   // the caller reads this as a Thrift error
  })
  // A method the IDL declares `oneway`: it runs and no REPLY goes back. The flag belongs to
  // the method — Apache's Go client sends a oneway call as a plain CALL and never reads an
  // answer, so a server that replies to one desynchronises the connection.
  processor.add_oneway("notify", proto => {
    ignore(proto.read_field_begin())
    ignore(proto.read_string())
  })
  processor
}
```

The other transport shape is the header frame: the body sits inside a frame whose meta block
names the inner protocol and the transforms, and whose info section carries key/value headers
beside the call. One endpoint reads binary and compact frames on the same socket, which is
what the reference implementations negotiate.

```moonbit
fn header_endpoint() -> @thrift.Header {
  let header = @thrift.Header::new()
  header.set_protocol(@thrift.header_protocol_compact)   // or header_protocol_binary
  header.add_header("tenant", "acme")                    // beside the call, not in it
  header.add_transform(@thrift.header_transform_zlib)    // the payload travels compressed
  header
}
```

`thrift.encode_header_frame` and `thrift.decode_header_frame` are the framing on its own, for
a caller that moves frames itself. The test that covers them compares bytes with Apache
Thrift's Go bindings, frame for frame.

A `oneway` method is sent through `Transport::send` rather than `round_trip`, so the client
does not wait for a reply that will never come:

```moonbit native
async fn fire_and_forget(client : @net.ThriftClient) -> Unit raise {
  let proto : &@thrift.Protocol = @thrift.Binary::new(b"")
  @thrift.oneway_call(client, proto, "notify", 1, proto => {
    proto.write_field_begin(@thrift.type_string, 1)
    proto.write_string("done")
  })
}
```

[`cmd/thriftcrosstest`](src/cmd/thriftcrosstest/) is Apache's `ThriftTest` service and its
client, so the whole reference suite — all 23 methods, four transports and three protocols —
runs against this stack in both directions; see [Conformance](#conformance).

[`cmd/thriftc`](src/cmd/thriftc/) compiles a `.thrift` file to MoonBit: enums with their
numbers, structs with a codec and a `default()`, and each service's `register_*` and
client functions. `optional` becomes `Option`, `binary` becomes `Bytes`, and a struct
that contains itself by value is refused rather than generating a codec that cannot
end. [`29-thrift-idl`](src/examples/29-thrift-idl/) is its output, and CI reruns the
compiler with `--check` so the two cannot drift:

```sh
moon run src/cmd/thriftc -- greet.thrift -o greet.g.mbt
```

The compiler reads `struct`, `enum`, `exception`, `union`, `typedef`, `const` and
`service` over the primitive types, `list`, `set` and `map`. A `typedef` is substituted
where it is used — `typedef i64 Timestamp` leaves `Int64` behind, since the wire carries
no name for it either — and an alias that loops back to itself is refused with the chain.

A `union` carries exactly one of its fields, so it becomes an enum with a variant each;
on the wire it is a struct with that one field set. Reading a union that carries none is
refused rather than defaulted, and `default()` — what a struct field of a union type
starts from — is its first field's default:

```thrift
union Contact {
  1: string email
  2: i64 phone
}
```

```moonbit
pub(all) enum Contact { Email(String); Phone(Int64) }
```

A `const` is a `pub let` of its type. Scalar, list, map, struct and enum values are read,
the type checks the value, and the name takes the shape MoonBit wants for a value, so
`MAX_AGE` is written `maxAge`:

```thrift
const i32 MAX_AGE = 130
const Person ADA = { "name": "Ada", "age": 37 }
```

```moonbit
// `const i32 MAX_AGE = 130` in the IDL, with the name MoonBit wants for a value.
pub let max_age : Int32 = 130

test {
  assert_eq(max_age, 130)
}
```

A value that does not fit its type, a field or enum value that does not exist, and a
constant that names another constant are refused with the line they came from.

An `exception` is a struct on the wire; a method whose IDL declares `throws` answers a
`Result`, one variant per declared failure, instead of raising it:

```thrift
exception Missing {
  1: string message
  2: i32 code
}

service Greeter {
  string find(1: string key) throws (1: Missing missing)
}
```

```moonbit
// `find(1: string key) throws (1: Missing m)` becomes a `Result`, not an exception:
// the error enum names the declared exception, the handler returns
// `Result[String, GreeterFindError]`, and the client gets the same type back.
pub(all) enum GreeterFindError {
  Missing(Missing)
}

#derive(Debug)
pub struct Missing {
  message : String
}

fn found_or_missing(found : Result[String, GreeterFindError]) -> String {
  match found {
    Ok(value) => value
    Err(Missing(missing)) => missing.message
  }
}

test {
  assert_eq(found_or_missing(Ok("found ada")), "found ada")
  assert_eq(found_or_missing(Err(Missing({ message: "no ada" }))), "no ada")
}
```

On the wire this is what Apache Thrift does: the success value in field 0, the exception
in the field its clause numbers. A failure field the IDL does not declare is skipped and
raised as `@thrift.Application`, so nothing is swallowed as if it were a value.

`include "shared.thrift"` folds that file's types into the output, under the name the
include gives them: `shared.Person` becomes `SharedPerson`, so one package holds both
without a clash. Nested includes are read once each, and two included files with the
same basename are refused rather than merged silently. `service Child extends Base`
carries the base's methods into `register_child` and the child's client — the base's
own registration stays with the base's file.

## tRPC

tRPC is the protocol the `trpc.group` stack speaks: a 16-octet fixed head, then either a
unary call — a protobuf request header, the message, and an optional attachment — or one of
four streaming frames. It carries more of a call than gRPC does in-band: the caller and
callee names, the interface path, a timeout in milliseconds, the serialization and
compression codes, and a map of transparent key-value pairs that every hop forwards.

A service is written once. `@trpc.Server` implements the same `Registrar` the gRPC engines
do, so the generated `Greeter::register` fills either, and the handlers are the same
`Unary`/`ServerStreaming`/`ClientStreaming`/`Bidi` shapes.

```moonbit native
async fn trpc_call(port : Int32) -> Unit raise {
  let channel = @net.TrpcChannel::connect("127.0.0.1", port)
  let client = @trpc.Client::new(channel, caller="trpc.app.client.service")
  let request = @proto.PbWriter::new()
  request.string_(1, "world")
  // A unary call: one request frame out, one reply frame back.
  let reply = client.unary(
    "/trpc.test.Greeter/SayHello",
    request.to_bytes(),
    metadata=[{ name: b"x-test", value: b"moonrpc" }],
    timeout_millis=5000,
  )
  println(reply.length().to_string())
  channel.close()
}
```

A server registers the same way a gRPC one does, and answers unary and streaming calls
from the same table:

```moonbit native
fn trpc_server() -> @trpc.Server {
  let server = @trpc.Server::new()
  server.register("/greet.Greeter/SayHello", @stream.Handler::Unary((ctx, req) => {
    // The caller's `x-test` metadata arrives as a header, because `trans_info` is where the
    // protocol puts it.
    match ctx.metadata_get(b"x-test") {
      Some(_) => req
      None => req
    }
  }))
  server.register("/greet.Greeter/Count", @stream.Handler::ServerStreaming((_ctx, req) => [req]))
  server
}
```

Streaming is the four frames the protocol names: `INIT` opens a stream and hands the far
end the window it may send, `DATA` carries a message, `FEEDBACK` returns window as messages
are consumed, and `CLOSE` ends a direction — or resets the stream. `Session` holds one
connection's streams, so a test drives the server half without a socket.

The client has all four call kinds. `Client::open` returns an `Exchange` the caller drives
message by message — `send`, `next`, `close` — because a bidirectional call whose server
answers as it reads deadlocks against a caller that sends everything before reading anything.
`client_stream` and `bidi` are the two shapes that do not need to interleave, and `stream` is
one line over `bidi`. `cmd/trpcd` serves one method per cardinality, and its two peers do the
same against tRPC-Go's and tRPC-Python's own codecs.

| tRPC-Python feature | How this library answers it |
|:--|:--|
| Filters (client, server, per-service) | `@client.Interceptor` and the server's interceptor chain, shared with gRPC |
| Serialization kinds — proto, JSON, JCE, flatbuffers, XML, thrift | proto (0) and JSON (2) are built in; the code is carried in the header and a caller may send any of them |
| Compression kinds — none, gzip, snappy, zlib, lz4, snappy-stream | identity, gzip (1) and zlib (3) both ways; snappy and lz4 are refused with a decode error rather than misread |
| Per-call timeout, and the full-link deadline | `timeout` in the header, in milliseconds, surfaced as `deadline_millis` on the context; a full-link deadline is the caller's own deadline less what has been spent, written into each hop |
| Transparent information (`trans_info`), dyeing key, environment | `metadata` on a call maps to `trans_info` both ways; `dyeing_key` and `env_key` are the framework's names, and `message_type` carries the dyeing flag |
| ONE-WAY calls | `call_oneway` in the header; a server that answers one would leave an unread frame, so the flag comes from the method |
| Transports — TCP, UDP, HTTP | TCP; the protocol is transport-agnostic and a link is any `write`/`read` pair |
| Multiplexed streams on one connection | stream ids in the head; `Session` keeps one table per connection |
| Streaming back-pressure | `INIT`'s window and `FEEDBACK` increments, granted per frame consumed |

## tRPC for TypeScript

The `trpc.io` protocol is not the `trpc.group` one above. It is JSON over HTTP, one call per
request or several in a batch, with no frame and no session: the call names its own path in the
URL, and the body carries only its input. It is what a `@trpc/server` router speaks, and its
envelope borrows JSON-RPC's shape without its method dispatch.

`@trpcio.Server` is a table of procedures, and `handle` is one request in, one answer out — a
pure function, so a test drives the server half without a socket, and `net::serve_trpcio` is the
HTTP/1.1 driver over it:

```moonbit native
fn trpcio_service() -> @trpcio.Server {
  let server = @trpcio.Server::new()
  // A query answers a value and may be asked for with GET; a mutation may not.
  server.query("greet.hello", input => Ok({ "greeting": Json::string("hello") }))
  server.mutation("greet.remember", input => {
    let name = match input {
      Some(value) => value
      None => Json::null()
    }
    Ok({ "name": name })
  })
  // A failure names its tRPC code, and the code carries the HTTP status.
  server.query("greet.fail", _input => {
    Failed(@trpcio.failure_of("FORBIDDEN", "not for you", path="greet.fail"))
  })
  server
}
```

The verb follows the kind, and `@trpc/server` enforces it in both directions: a query is a GET
with its input in `?input=`, a mutation is a POST with its input as the body, and a POST to a
query or a GET to a mutation is a `405`. A batch carries one verb for all of its calls, so one
batch is one kind — `{"0":<input>,"1":<input>}`, keyed by position, with a call that has no input
left out rather than written as `null` — and a batch with both kinds in it is two requests whose
answers are merged back into the order the calls were given, which is what tRPC's own link does.
The reply to one request is an array in the same order, each element either
`{"result":{"data":...}}` or `{"error":{...}}`; a failure in one call does not disturb its
neighbours:

```moonbit native
async fn trpcio_calls(port : Int32) -> Unit raise {
  let client = @net.trpcio_client("127.0.0.1", port, base="/trpc")
  let greeting = client.query("greet.hello", input=Json::string("moon"))
  // One request, three answers, in the order they were asked for.
  let outcomes = client.batch([
    @trpcio.Call::new("greet.hello", input=Json::string("batch")),
    @trpcio.Call::new("math.add", input={ "a": Json::number(1), "b": Json::number(2) }),
    @trpcio.Call::new("greet.fail"),
  ])
  println(greeting.to_string() + outcomes.length().to_string())
}
```

`scripts/interop/trpcio_peers` is the other implementation: `@trpc/server` behind `createHTTPServer`
with the same four procedures, and a client that goes through the real `httpLink` and
`httpBatchLink`. `cmd/trpciod` is this side of each — it serves, and `trpciod check` calls a server
and verifies every answer, including a batch that mixes a query with a mutation — so CI runs their
client against this server, this client against their server, and this stack against itself.

## Connect

Beside gRPC sits the Connect protocol: the same four call kinds and the same handlers, over
either HTTP version, with the body in protobuf or in JSON. A unary call is one message in the
body and the outcome in the HTTP status; a streaming call is a run of five-octet envelopes
closed by an end-stream envelope that carries the outcome and the trailing metadata.

```moonbit native
async fn serve_echo(server : @net.ConnectServer) -> Unit raise {
  server.add("/connect.Echo/Say", {
    input: ".connect.EchoRequest",   // the message a JSON body is read as
    output: ".connect.EchoReply",
    handler: @stream.Handler::Unary((_ctx, req) => req),
  })
  // One listener for both versions: a connection that opens with the HTTP/2 preface is
  // served over HTTP/2, any other over HTTP/1.1.
  server.serve(port=12000)
}
```

A JSON caller needs no second service: the request is read into wire bytes through the
schema a server was built with, and the reply is written back the same way, so the handler
below is the same code either codec reaches. `command: moon run src/cmd/connectd -- 12000`
runs the example — `curl -d '{"text":"hi"}' -H 'content-type: application/json'
http://127.0.0.1:12000/connect.Echo/Say` answers `{"text":"hi"}`.

The dispatch is a pure function: `connect.Server::serve` takes a path, headers and a body and
returns a status, headers and a body, which is what makes it testable without a socket and
what lets the two drivers — `net` over HTTP/1.1, and its HTTP/2 half — share it.

A call is dispatched as it arrives, not after it has finished. `Server::start` opens a call,
`Session::feed` takes the next piece of the body and hands back the envelopes that may be written
now, and `finish` closes it — so a bidirectional caller that sends a message and waits for its
answer before sending the next one gets one. `Server::serve` is those three steps over a request
that already arrived whole, which is what a driver does when it has the body in hand.

`src/conformance` is the reference service the official suite drives, and `scripts/conformance`
holds both halves' configurations. CI starts `cmd/conformance`, which reports the port it bound on
standard output the way the suite expects, and runs `connectconformance --mode server` against it
over both HTTP versions. The same binary with a `client` argument is the other half: it reads one
length-delimited `ClientCompatRequest` per case on stdin, drives the call with `connect.Client`,
and writes the result back in the runner's terms.

That job gates the build, and the scope is deliberate: 3556 cases over both HTTP versions, both
codecs, TLS and plaintext, and five compressions — the widest matrix the runner can express for
Connect, so that a regression in any one of those dimensions shows up rather than hiding in a
configuration that was never asked for. At least 3486 of them pass on every run — the two runs
of this configuration so far saw 3486 and 3504 — and the count moves only inside one class of
seventy, every `Deadline Propagation` permutation over TLS, declared flaky in
`scripts/conformance/connect_server_known_flaky.txt` rather than dropped from the configuration.
Each needs a TLS handshake inside a two-second deadline while the suite drives forty-eight RPCs
at once, and a handshake here costs one RSA-2048 private-key operation in pure MoonBit, measured
at 0.49 s: forty-eight of those interleaved on one event loop cannot meet the deadline. The same
cases pass with the suite run one at a time (`-p 1`: 140 of 140 TLS cases), and every other TLS
case passes at full parallelism, so what falls short is the crypto stack's throughput, not this
server's TLS. `--known-flaky` is the runner's word for a race: all seventy still run and a
failing one is still named in the output, but the outcome of a timing race does not decide the
build — `--known-failing` would fail it in the other direction, on a machine fast enough to pass
them. Every failure it drove out along the way was a disagreement
between this encoder and the protocol rather than a missing feature: `metadata` as a map of
lists, the `connect-timeout-ms` header, error details as `Any` in unpadded base64, a gzip'd unary
body, a reply head sent before the request was read, `415` for a content type the server does not
read, and an enum field compiled as a message — that last one alone accounted for 260 cases,
because a dropped enum value turned every error into a success.

The rest were about the parts of the protocol a call shape has rather than a body does. A unary
reply carries trailing metadata as `Trailer-`-prefixed headers, since a one-message body has no
other trailer channel. A path the server does not serve is a `404` that reads back as
`unimplemented`, and a verb that is not `POST` is a `405`. A full-duplex reply echoes the request
it answers, and only its first reply carries the call's headers and deadline. A streaming reply
whose handler fails is closed at that moment rather than when the caller stops sending, which is
what a full-duplex caller waiting for the error needs. And HTTP/2 field names are lowercased on
the way out: a capital in one is a connection error the peer answers with `RST_STREAM`.

The client suite is gated too, at 4292 of 4292. `connect.Exchange` is the incremental shape a
cancellation needs: `send`, `close_send`, `next`, `cancel` and `finish` over a
`StreamTransport` that keeps the request body open. The suite's 76 cancellation cases all
pass, including `cancel.before_close_send` — which a one-shot POST cannot express — and the
full-duplex cases that report the answers that arrived before the caller gave up.

The one-shot shape is still there for a caller that has everything up front:
`net::Http1Transport` is the HTTP/1.1 one and
`net::Http2Transport` speaks the preface, SETTINGS, HPACK headers and flow-controlled DATA over
HTTP/2; the latter advertises a large window on the connection and the stream up front, or a
reply past 65535 octets waits for a WINDOW_UPDATE that a read-to-the-end client never sends:

```moonbit native
async fn call_echo(transport : @net.Http1Transport) -> Unit raise {
  let client : @connect.Client[@net.Http1Transport] = @connect.Client::new(transport)
  let reply = client.unary("/connect.Echo/Say", b"hi")
  assert_eq(reply.messages[0], b"hi")
}
```

## Concurrency on a connection

A finished call is not run inside the frame loop. The server hands it to the driver, which runs it on a task of its own, so a handler that is waiting on something holds up nothing else on the connection:

```moonbit
fn slow_method(engine : @moonrpc.H2Server) -> Unit {
  engine.register_handler("/slow.S/Wait", @stream.Handler::Pushed((_ctx, requests, out) => {
    @async.sleep(400)               // a slow handler, on its own task
    (out.send)(requests)
    (out.finish)()
  }))
}
```

Deadlines are preemptive: when a call's `grpc-timeout` passes, the engine ends the stream with `DEADLINE_EXCEEDED` and the driver stops the task behind it, so a handler that would have taken half a second stops at the deadline. One lock per connection serializes writes, since calls, the reader and a shutdown GOAWAY all write the same socket.

The server also holds peers to a keepalive policy when one is set — PINGs closer together than the policy allows are strikes, and a peer that runs out of them is answered `GOAWAY(ENHANCE_YOUR_CALM)` — and refuses the frames RFC 9113 calls a protocol violation: PUSH_PROMISE, DATA or HEADERS on stream 0, a zero-increment WINDOW_UPDATE, a frame over the advertised `SETTINGS_MAX_FRAME_SIZE`, and a SETTINGS nobody acknowledges.

## Protobuf and Server Reflection

A message is bytes on the wire; JSON is a second way to say the same thing, and the mapping
between them is driven by the descriptor rather than by generated code. `proto.Schema` is the
set of files a value may use, and it maps a message to JSON and back:

```moonbit
pub fn message_as_json(schema : @moonrpc.Schema) -> Json raise {
  // `Profile` is a message whose descriptor the schema holds; `bytes` is its wire form.
  let bytes = b""
  let value = schema.to_json(".test.Profile", bytes)
  // The same value back on the wire, so the two directions are checked against each other.
  ignore(schema.to_bytes(".test.Profile", value))
  value
}
```

A schema also compiles from the `.proto` files themselves, so a service definition written by
hand is a schema without a code generator in between:

```moonbit
fn load_schema() -> @moonrpc.Schema raise {
  @moonrpc.Schema::compile([
    (
      "greet.proto",
      #|syntax = "proto3";
      #|package greet.v1;
      #|message Hello { string name = 1; }
      #|service Greeter { rpc Say(Hello) returns (Hello); }
    ),
  ])
}
```

The parser is `moonbitstack/moonproto`'s, which covers proto2, proto3 and the editions; what this
module does with the result is resolve every type name to its absolute spelling, add the synthetic
oneof a proto3 `optional` field needs, and wrap the file in the descriptor model the rest of the
library passes around. Imports resolve across the files given, in any order.

The shapes are proto3's: lowerCamelCase names, `int64` as a string, `bytes` as base64, enums
by name, a map as an object, and the well-known types as the specification spells them — a
`Timestamp` is an RFC 3339 string, a `Duration` ends in `s`, a wrapper is the value it wraps.

`PbWriter` and `PbReader` carry the proto3 binary format: varint, zigzag, `fixed32`／`fixed64` and length-delimited fields. The base-128 varint and the zigzag fold are moonvar's, since DWARF writes the same integer; what is here is the field structure built over it.

```moonbit
fn protobuf_bytes() -> Unit raise {
  let w = @moonrpc.PbWriter::new()
  w.string_(1, "testing")          // field 1, a length-delimited string
  w.int32(2, -1)                   // field 2, a varint (negative -> ten octets)
  let r = @moonrpc.PbReader::new(w.to_bytes())
  let (field, _wire) = r.read_tag() // (1, LengthDelim)
  assert_eq(field, 1)
  assert_eq(r.read_string(), "testing")
}
```

On top of it, a descriptor model builds and parses `FileDescriptorProto` and `FileDescriptorSet`: imports, messages with their nested messages, enums, oneofs and `map` entries, and services. `grpc.reflection.v1.ServerReflection` (with its `v1alpha` alias) answers `ListServices`, `FileContainingSymbol` (a service, a method, a message, a nested type or an enum) and `FileByFilename`, so `grpcurl` can list and describe a service. CI runs exactly that against `cmd/greetd`. `FileDescriptor::source()` prints the `.proto` a descriptor describes; protoc compiles it back to the same descriptor, which `21-annotations` checks.

```moonbit
fn describe_service() -> @moonrpc.FileDescriptor {
  let greeter : @moonrpc.ServiceDescriptor = {
    name: "Greeter",
    methods: [
      {
        name: "SayHello",
        input_type: ".greet.HelloRequest",
        output_type: ".greet.HelloReply",
        client_streaming: false,
        server_streaming: false,
      },
    ],
  }
  @moonrpc.FileDescriptor::new("greet.proto", "greet", services=[greeter])
}
```

## The engines

Everything below `serve` is a pure engine: `feed` turns a decoded frame into the frames to write back, so the whole server path (HPACK, flow control, dispatch, HEADERS + DATA + `grpc-status` trailers) runs in memory on every backend. `H2Client` is the same on the other side, and the root package's tests drive the two against each other with no socket.

```moonbit
fn engine_reply(engine : @moonrpc.H2Server, frame : @http2.Frame) -> Unit raise {
  engine.register("/echo.Echo/Say", req => req)
  // [HEADERS(:status 200), DATA(reply), HEADERS(grpc-status:0)]
  let out = engine.feed(frame)
  assert_eq(out.length() > 0, true)
}
```

What the server refuses: a request line that is not gRPC's (`:method` other than POST, a `content-type` not starting `application/grpc`, no `te: trailers`) gets an HTTP status instead of 200; `SETTINGS_MAX_CONCURRENT_STREAMS` is advertised and enforced with REFUSED_STREAM; overrunning a flow-control window is FLOW_CONTROL_ERROR; a field block must arrive contiguously (RFC 9113 §6.10); a call already past its `grpc-timeout` never reaches its handler.

## Framing and status

```moonbit
test {
  let frame = @moonrpc.encode_message(b"hello grpc")
  // [0x00][0x00 0x00 0x00 0x0A]["hello grpc"]
  assert_eq(frame.length(), 5 + 10)

  let (compressed, payload) = @moonrpc.decode_message(frame).unwrap()
  assert_eq(compressed, false)
  assert_eq(payload, b"hello grpc")

  assert_eq(@wire.Status::code(@wire.Status::NotFound), 5)
  assert_eq(@wire.Status::name(@wire.Status::Unauthenticated), "UNAUTHENTICATED")

  let m : @moonrpc.Method = { service: "greet.Greeter", name: "SayHello" }
  assert_eq(m.path(), "/greet.Greeter/SayHello")
}
```

## Retries and hedging

Retries follow gRPC proposal A6, checked against grpc-go and grpc-java. Every call kind takes `retry`; a channel takes `throttling` once, for the server name it reaches.

```moonbit native
async fn throttled_call(host : String) -> Unit raise {
  let chan = @net.Channel::connect(
    host,
    12000,
    throttling=@moonrpc.Throttling::new(tokens=10, ratio=0.1),
  )
  let reply = chan.unary(
    "/greet.Greeter/SayHello",
    b"Ada",
    timeout_millis=2000,
    retry=@moonrpc.retry,
  )
  ignore(reply)
  chan.close()
}
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

- Descriptor options other than `map_entry`; `oneof` and imports from `#rpc`; extensions
  anywhere in the descriptor model — the reflection queries are answered, but there is
  nothing to report.
- HPACK `never-indexed` literals: the encoder indexes what it is given, and sends the
  dynamic table size update the peer asks for.
- `-bin` metadata goes out base64-padded. Receivers accept both forms (and
  `metadata_value_from_wire` reads unpadded), and the suite pins the padded form.
- Thrift: the IDL's `SecondService` is outside Apache's cross test. TJSONProtocol writes a
  million as `1000000` where Apache's Go encoder writes `1e+06`; both decode to the same
  double, so the generated vectors avoid that spelling and the corner values have a test of
  their own.
- Connect: `zstd` is the one compression neither configuration declares — the decoder here
  reads raw and RLE blocks where the reference encoder emits entropy-coded ones, so a zstd
  request this library writes would come back unreadable. `GET`, TLS, the other four
  compressions and the message receive limit are declared; the client half sets the limit and
  the server half does not, and `scripts/conformance/connect.yaml` and `connect_client.yaml`
  are the two statements of scope the runner reads.
- tRPC: both directions of back-pressure are tracked now — the client waits for credit before
  writing past the peer's window and hands credit back as it consumes, and the server holds
  frames that do not fit in `pending` until a `FEEDBACK` releases them in order. What is not
  there: a bidirectional call answers each `DATA` on the connection's own task, so one slow
  handler holds the frames behind it.
- tRPC for TypeScript: no subscriptions — the protocol's WebSocket link — and the transformer is
  identity, so a `superjson`-transformed body is the caller's to serialise and the reply's to
  read back; `Server::new` bounds a batch at 32 calls, where tRPC's own server leaves it open.

## Licence

Apache-2.0. See [LICENSE](LICENSE).
