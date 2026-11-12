---
name: moonrpc
description: "gRPC over HTTP/2, Apache Thrift, tRPC and Connect for MoonBit: serve or call a typed method, stream in either direction, add metadata, deadlines, retries, TLS or compression, and compile .proto or .thrift into MoonBit. Use when a task involves an RPC service, a gRPC client or server, server reflection, health checking, a Connect endpoint, a trpc.group or trpc.io peer, or binary RPC between programs."
---

# moonrpc

`moon add moonbitstack/moonrpc`, then import the layers the task needs: `@moonrpc` is the
façade (message framing, status, metadata, the pure client and server engines, health,
reflection, channelz), `@net` is the socket driver and is native only, and `@thrift` is the
separate Thrift stack.

```moon.pkg
import {
  "moonbitstack/moonrpc",
  "moonbitstack/moonrpc/net",
  "moonbitstack/moonrpc/thrift",
}
```

## Serve a method and call it

A handler is registered under its gRPC path — `/package.Service/Method` — and takes and
returns encoded messages. Annotations write the codecs and the registration for you; this is
the same thing by hand, which is what to reach for when the messages are already bytes.

```moonbit native
async fn serve_and_call() -> Unit raise {
  // The server takes the port the system gives it, so a test never collides with another.
  let server = @net.GrpcServer::new()
  server.register_unary("/greet.Greeter/SayHello", (_ctx, req) => b"hello:" + req)
  let port = server.bind(port=0).port()

  @async.with_task_group(group => {
    group.spawn_bg(() => server.serve())
    let chan = @net.Channel::connect("127.0.0.1", port)
    let reply = chan.unary("/greet.Greeter/SayHello", b"Leo")
    assert_eq(reply.grpc_status, 0)
    assert_eq(reply.messages[0], b"hello:Leo")
    chan.close()
  })
}
```

The four call kinds are `register_unary`, `register_server_streaming`,
`register_client_streaming` and `register_bidi`; on the client they are `unary`,
`server_streaming`, `client_streaming` and `bidi`. A failing handler calls
`ctx.fail(code, message)` and the call ends with that status instead of a reply.

## Thrift, when the peer is not gRPC

The Thrift stack shares only the socket layer with gRPC: a `Processor` dispatches by method
name, a `Protocol` chooses the bytes, and `Transport` moves a frame.

```moonbit
fn thrift_processor() -> @thrift.Processor {
  let processor = @thrift.Processor::new()
  processor.add("ping", proto => {
    ignore(proto.read_field_begin())                // field 1: the argument
    let text = proto.read_string()
    ignore(proto.read_field_begin())                // STOP
    proto.write_field_begin(@thrift.type_string, 0) // field 0: the result
    proto.write_string("pong:" + text)
  })
  processor
}
```

`@thrift.Binary` and `@thrift.Compact` are the two protocols; `@thrift.Header` wraps a body
in the header frame, which names its inner protocol and can carry headers and the zlib
transform. A method the IDL declares `oneway` is registered with `add_oneway` and called
through `@thrift.oneway_call`, which sends and reads nothing back.

## Serve Connect beside gRPC

The Connect protocol answers the same handlers over either HTTP version, with the body in
protobuf or JSON. Register the method with the message names a JSON caller is read through,
and serve: one listener takes both versions, deciding from a connection's first octets.

```moonbit native
async fn serve_connect(server : @net.ConnectServer) -> Unit raise {
  server.add("/connect.Echo/Say", {
    input: ".connect.EchoRequest",
    output: ".connect.EchoReply",
    handler: @stream.Handler::Unary((_ctx, req) => req),
  })
  server.serve(port=12000)
}
```

## Compile a .proto instead of building descriptors by hand

`Schema::compile` reads `.proto` source into the descriptor model, so a service defined in IDL
needs no descriptors written out:

```moonbit
fn schema_from_idl() -> @moonrpc.Schema raise {
  @moonrpc.Schema::compile([
    (
      "greet.proto",
      #|syntax = "proto3";
      #|package greet.v1;
      #|message Hello { string name = 1; }
    ),
  ])
}
```

Pass every file that is imported, in any order; type names resolve across the whole set.

## tRPC, when the peer is a trpc.group service

The same handlers answer over tRPC: `@trpc.Server` is a `Registrar`, so a generated
service registers on it exactly as it does on a gRPC server. What changes is the frame, not
the service.

```moonbit native
async fn call_over_trpc(port : Int32) -> Unit raise {
  let channel = @net.TrpcChannel::connect("127.0.0.1", port)
  let client = @trpc.Client::new(channel, caller="trpc.app.client.service")
  // The timeout travels in the header, in milliseconds, and the caller's metadata as
  // `trans_info` — which is what the far end reads as headers.
  let reply = client.unary(
    "/greet.Greeter/SayHello",
    b"\x0a\x05world",
    metadata=[{ name: b"x-test", value: b"moonrpc" }],
    timeout_millis=2000,
  )
  println(reply.length().to_string())
  channel.close()
}
```

A streaming method takes the four frames the protocol names. `client.stream` sends `INIT`,
one `DATA` per request and `CLOSE`, then returns every reply until the far end closes:

```moonbit native
async fn stream_over_trpc(port : Int32) -> Unit raise {
  let channel = @net.TrpcChannel::connect("127.0.0.1", port)
  let client = @trpc.Client::new(channel)
  let request = @proto.PbWriter::new()
  request.int32(1, 3)
  let replies = client.stream("/greet.Greeter/Count", [request.to_bytes()])
  println(replies.length().to_string())
  channel.close()
}
```

Two things to remember about the protocol: the total length in the head counts the head
itself, and a frame whose header length is zero is a streaming frame rather than a unary one
without a header.

## Connect, when the peer is a Connect client

The Connect protocol runs beside gRPC on the same handlers: one message in the body, the
outcome in the HTTP status, or a run of five-octet envelopes for a stream. A route names the
message types a JSON body is read as, so one handler answers a protobuf caller and a JSON one.

```moonbit native
async fn connect_echo_server() -> Unit {
  let server = @net.ConnectServer::new()
  server.add("/connect.Echo/Say", {
    input: ".connect.EchoRequest",
    output: ".connect.EchoReply",
    handler: @stream.Handler::Unary((_ctx, req) => req),
  })
  // One listener for both HTTP versions: the HTTP/2 preface decides which driver takes it.
  server.serve(port=12000)
}
```

A caller picks its transport — `net::Http1Transport` or `net::Http2Transport` — and the same
`Client` drives either:

```moonbit native
async fn call_connect(transport : @net.Http1Transport) -> Unit raise {
  let client : @connect.Client[@net.Http1Transport] = @connect.Client::new(transport)
  let reply = client.unary("/connect.Echo/Say", b"hi")
  assert_eq(reply.messages[0], b"hi")
}
```

## tRPC for TypeScript, when the peer is a `@trpc/server` app

This is a different protocol from the `trpc.group` one above: JSON over HTTP, the call's path
in the URL, and the input either as the body or in `?input=`. A query must be a GET — the
TypeScript server answers a POST to one with `405` — and a mutation must be a POST.

```moonbit native
fn trpcio_service() -> @trpcio.Server {
  let server = @trpcio.Server::new()
  server.query("greet.hello", input => Ok({ "greeting": Json::string("hello") }))
  server.mutation("greet.remember", input => {
    let name = match input {
      Some(value) => value
      None => Json::null()
    }
    Ok({ "name": name })
  })
  server
}
```

`net::serve_trpcio` puts it on a socket, and `net::trpcio_client` calls one; a batch travels
as one request per kind, the queries as a GET and the mutations as a POST.

```moonbit native
async fn call_trpcio(port : Int32) -> Unit raise {
  let client = @net.trpcio_client("127.0.0.1", port, base="/trpc")
  let greeting = client.query("greet.hello", input=Json::string("moon"))
  // One request, three answers, in the order they were asked for.
  let outcomes = client.batch([
    @trpcio.Call::new("greet.hello", input=Json::string("batch")),
    @trpcio.Call::new("greet.remember", input={ "name": Json::string("moon") }, mutation=true),
  ])
  println(greeting.to_string() + outcomes.length().to_string())
}
```

## Rules that catch people out

- `@net` is native only. A package that imports it is native only too, and the same goes for
  anything holding a socket.
- A server that is asked for port 0 reports the real one only through `bind`/`addr`; the
  number in the call is not the number it got.
- One `RpcContext` belongs to one call: read metadata from it inside the handler, and set
  response headers and trailers before returning.
- `CallReply::one()` demands exactly one message and `CallReply::ok()` demands status OK —
  both raise `StatusError`, which is the error type to catch around a call.
- The engines (`@moonrpc.H2Server`, `@moonrpc.H2Client`) are pure: they take frames and
  return frames, so a test of protocol behaviour needs no socket at all.
- A tRPC client decides unary or streaming from the path: `Client::declare_streams` with a
  generated `descriptor()` is what teaches it which methods are streaming, and a path it was
  not told about is sent as a unary call.
