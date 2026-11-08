<div align="center">

# moonrpc

**Real gRPC for MoonBit — `← gRPC`.**

[![Check and Test](https://github.com/moonbitstack/moonrpc/actions/workflows/ci.yml/badge.svg)](https://github.com/moonbitstack/moonrpc/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](./LICENSE)
[![mooncakes](https://img.shields.io/badge/mooncakes-moonbitstack%2Fmoonrpc-brightgreen)](https://mooncakes.io/docs/moonbitstack/moonrpc)

</div>

> Moved on mooncakes from `Lfan-ke/moonrpc` to `moonbitstack/moonrpc`.

`moonrpc` is gRPC over HTTP/2, not gRPC-Web. HTTP/2 framing (RFC 9113) and HPACK (RFC 7541) come from moonhttp; this module is everything gRPC puts on top: all four call kinds, metadata, deadlines, status and rich errors, flow control, TLS with ALPN, message compression, interceptors on both ends, concurrent dispatch on one connection, health checking, server reflection, retries, hedging, backoff and load balancing, a stats observable and a channelz registry, and service-config driven retries with WaitForReady. Beside it sits a Thrift stack of its own: the binary, compact and header transports, a processor, a client, and an IDL compiler. The client and server engines are pure functions over frames and run on every backend; only the socket drivers in `net` are native.

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

A gRPC implementation is only gRPC if a foreign one agrees on the bytes. CI runs the wire
against independent peers in plaintext and over TLS:

| Partner | Direction | Calls | Compression | Interceptors | TLS | Result |
|:--|:--|:--|:--|:--|:--|:--|
| `grpcurl` (grpc-go) | client | reflection `list`／`describe`, all four | `gzip` | — | yes | pass |
| grpc-go | client | all four | `gzip` | client chain | yes | pass |
| grpc-go | server | all four, through the generated `GreeterClient` | identity | server chain | yes | pass |
| Apache Thrift (Go) | client | `ping`, `add`, `double`, binary and compact | identity | — | no | pass |
| Apache Thrift (Go) | server | `ping`, `add`, `double`, through `thriftd check` | identity | — | no | pass |
| Apache Thrift cross test | client | `ThriftTest`: all 23 methods, binary and compact | identity | — | no | pass |
| Apache Thrift cross test | server | `ThriftTest`: all 23 methods, driven from this side | identity | — | no | pass |

`cmd/greetd` is the server the first two call; the third runs the same generated client
against a grpc-go server and requires the two answers to match byte for byte. The
grpc-go side lives in `scripts/interop`, generated from the same `greet.proto` shape the
annotations declare. The Thrift rows are the protocol stack, below.

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
| Apache Thrift cross test, client | `ThriftTest` as served here: 23 methods, binary and compact, framed | pass |
| Apache Thrift cross test, server | the same 23 methods as this client calls them, both protocols | pass |

`scripts/interop/build_thrift_peers.sh` builds the reference client and server;
`scripts/interop/thrift_cross_test.sh` runs both directions; `src/cmd/thriftcrosstest` is
this side of each. The Thrift rows cover the strict message header, every primitive, structs
nested two deep, maps of maps, sets, a uuid, a `oneway` method, and the two ways a call can
fail: an exception in the field its `throws` clause numbers, and the application exception a
processor builds when a handler raises something else.

What none of them covers: Thrift transports other than `TFramedTransport` (unframed,
buffered, zlib, HTTP), the header and JSON protocols, and the IDL's `SecondService`;
`testOneway` is answered without the reference servers' sleep. This stack speaks framed
Thrift in the binary and compact protocols, which is what those rows exercise.

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

A second protocol stack sits beside the gRPC one and shares only the socket layer:
TFramedTransport, a processor that dispatches by method name, and a client that sends a
CALL and reads a REPLY. Nothing in `thrift/` imports HTTP/2, HPACK or protobuf.

The wire format is a choice rather than a copy. `Protocol` is the contract; `Binary` and
`Compact` are two implementations of it — fixed-width big-endian numbers with fixed field
ids, or zigzag varints with field-id deltas and a double written little-endian. The
processor, the client request and a service's handlers are written once, against the
trait, so a service answers either protocol without knowing which one it got.

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

[`cmd/thriftd`](src/cmd/thriftd/) serves `ping`, `add`, `double` and `fail`; `thriftd check`
calls them, and a `compact` argument picks the protocol on either side. CI runs an Apache
Thrift Go client against it and the moonrpc client against an Apache Thrift Go server, in
the binary and in the compact protocol. Both cover the strict message header, `bool`,
`byte`, `i16`, `i32`, `i64`, `double`, `string`, structs, lists, sets and maps, with a
depth guard on `skip`. `fail` answers a value in field 0 or an exception in field 1, so
the shape a `throws` clause gives a reply is checked against Apache's client and server
as well.

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
client, so the whole reference suite — all 23 methods, both protocols — runs against this
stack in both directions; see [Conformance](#conformance).

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
is the configuration it runs under. CI starts `cmd/conformance`, which reports the port it bound
on standard output the way the suite expects, and runs `connectconformance --mode server` against
it over both HTTP versions.

That job gates the build: the suite is clean — 724 of 724 cases pass, over both HTTP versions, both
codecs, and identity and gzip. Every failure it drove out along the way was a disagreement
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

The client is the same protocol from the other side, written against one method rather than a
socket, so a transport is forty lines:

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
- Thrift: the JSON protocol, and an unframed (`TBufferedTransport`) peer — this reader takes a
  body that arrives whole, so an unframed message, which has no length in front of it, has
  nothing to read to. The binary, compact and header transports and both directions of the
  reference cross test are in place.
- Connect: not declared to the conformance suite, and therefore not tested by it — Connect over
  `GET` (an idempotent call with its message in query parameters), a message receive limit, TLS,
  and compressions other than gzip. `scripts/conformance/connect.yaml` is the statement of scope
  the runner reads.

## Licence

Apache-2.0. See [LICENSE](LICENSE).
