<div align="center">

# moonrpc

**Real gRPC for MoonBit — `← gRPC`.**

[![Check and Test](https://github.com/moonbitstack/moonrpc/actions/workflows/ci.yml/badge.svg)](https://github.com/moonbitstack/moonrpc/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](./LICENSE)
[![mooncakes](https://img.shields.io/badge/mooncakes-moonbitstack%2Fmoonrpc-brightgreen)](https://mooncakes.io/docs/moonbitstack/moonrpc)

</div>

> Moved on mooncakes from `Lfan-ke/moonrpc` to `moonbitstack/moonrpc`.

`moonrpc` is gRPC over HTTP/2, not gRPC-Web. HTTP/2 framing (RFC 9113) and HPACK (RFC 7541) come from moonhttp; this module is everything gRPC puts on top: all four call kinds, metadata, deadlines, status and rich errors, flow control, health checking, server reflection, retries, hedging and load balancing. The client and server engines are pure functions over frames and run on every backend; only the socket driver in `net` is native.

```moonbit
let server = @net.GrpcServer::new()

// unary: one request, one reply.
server.register("/greet.Greeter/SayHello", req => handle(req))

// server-streaming: one request, an ordered run of replies.
server.register_server_streaming("/count.C/Up", (ctx, req) => [
  first(req), second(req), third(req),
])

// client-streaming: many requests collected, one reply at half-close.
server.register_client_streaming("/sum.S/Add", (ctx, msgs) => fold(msgs))

// bidi: each request answered as it arrives, a farewell at half-close.
server.register_bidi("/chat.C/Echo", ctx => @moonrpc.BidiHandler::{
  on_message: m => [reply_to(m)],
  on_end: () => [b"bye"],
})

server.serve()             // listens on 12000
```

The handler sees the call's `RpcContext`: the request metadata, the `grpc-timeout` deadline in milliseconds, and slots for response initial and trailing metadata.

**Documentation:** the [five-piece doc site](docs/index.html) — a home page, a [guide](docs/guide.html), the full [API reference](docs/api.html), and a [live in-browser showcase](docs/showcase.html) that runs the real engine.

## The four call kinds

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
| `moonrpc/net` | `GrpcServer`, `Channel`, `MuxChannel`, `ManagedChannel` over TCP (native) | the root, moonbitlang/async |

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

`MuxChannel` carries many concurrent calls and interactive bidirectional streams over one connection; `ManagedChannel` dials several backends, tracks each through the gRPC connectivity states and picks one per call (`pick_first` or `round_robin`).

## Health and interceptors

The standard `grpc.health.v1.Health` service registers in one call, and server interceptors wrap unary and server-streaming handlers:

```moonbit
let health = @moonrpc.HealthService::new()
health.set_status("greet.Greeter", Serving)
server.register_health(health)      // Check + Watch on /grpc.health.v1.Health/*

engine.add_unary_interceptor((ctx, req, next) => {
  // inspect, then proceed — or return without calling next to short-circuit.
  next(ctx, req)
})
```

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

On top of it, a descriptor model builds and parses `FileDescriptorProto` and `FileDescriptorSet`, and `grpc.reflection.v1.ServerReflection` (with its `v1alpha` alias) answers `ListServices`, `FileContainingSymbol` and `FileByFilename`, so `grpcurl` can list and describe a service. CI runs exactly that against `cmd/greetd`.

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

## Annotations

`#rpc` annotations write the protobuf codec of each message, the registration of
each service, and the file descriptor reflection serves:

```moonbit
#rpc.message
pub struct HelloRequest {
  name : String               // 1
  #rpc.field(number="4")
  tags : Array[String]        // 4
  nickname : String?          // 5, proto3 optional
}

#rpc.service(name="greet.Greeter")
pub struct Greeter { greeting : String }

#rpc.method
fn Greeter::say_hello(self : Greeter, req : HelloRequest) -> HelloReply raise { ... }

#rpc.method
fn Greeter::count_to(self : Greeter, req : Upto) -> Array[Number] { ... }
```

```moonbit
Greeter::{ greeting: "hello" }.register(server)   // an H2Server or a GrpcServer
reflection.add_file(descriptor())
```

Fields are numbered in declaration order from 1; `number=` sets one, written as a
string because the attribute grammar has no integers, and the count carries on
from it. `#rpc.skip` leaves a field out. A method's name is the function's in
PascalCase, `name=` overriding it; returning an array streams the replies, taking
one receives a client stream, and a parameter of type `RpcContext` receives the
call's context. A `StatusError` raised by a method answers with its status, any
other error with `UNKNOWN`, and a request that does not decode with `INTERNAL`,
as grpc-go does.

| MoonBit | protobuf |
|:--:|:--:|
| `String`, `Bytes`, `Bool` | `string`, `bytes`, `bool` |
| `Int`, `Int64`, `UInt`, `UInt64` | `int32`, `int64`, `uint32`, `uint64` |
| `Double`, `Float` | `double`, `float` |
| a `#rpc.message` | that message |
| `Array[T]` | `repeated T`, packed for the integers and `bool` |
| `T?` | `optional T` |

[`21-annotations`](src/examples/21-annotations/) checks the generated codec,
service and descriptor against the same ones written by hand, byte for byte.

Wire the generator into the build once. In `moon.mod`:

```
rule(name: "rpc", command: "moonx moonbitstack/moonrpc/cmd/rpc@0.21.1 -C \"$mod_dir\" \"$input\" -o \"$output\"")
```

and in the `moon.pkg` of the package holding the declarations:

```
dev_build(rule: "rpc", input: "service.mbt", output: "service.g.mbt")
formatter(ignore: [ "service.g.mbt" ])
```

## Not yet

- TLS. `moonbitlang/async`'s TLS exposes no ALPN, so HTTP/2 runs as h2c until moontls carries it over TCP.
- Response and request compression; incoming gzip is decompressed, outgoing messages are not compressed.
- Concurrent dispatch on one connection: a slow handler holds up the other streams, which is also why health `Watch` sends once and server-side deadlines are not preemptive.
- Connection backoff, client interceptors, channelz and service config.
- Descriptor fidelity for enums, nested types, imports and options, and transitive dependencies in reflection; `#rpc` waits on the same for enums and maps.
- Bidirectional streaming and client stubs from `#rpc`.

## Licence

Apache-2.0. See [LICENSE](LICENSE).
