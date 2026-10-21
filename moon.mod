name = "moonbitstack/moonrpc"

version = "0.20.1"

readme = "README.md"

repository = "https://github.com/moonbitstack/moonrpc"

license = "Apache-2.0"

keywords = [ "grpc", "rpc", "protobuf", "http2", "moonbit" ]

description = "Real gRPC for MoonBit over HTTP/2: all four call kinds, metadata, deadlines, rich errors, health checking, server reflection, retries, hedging and load balancing, with pure client and server engines that run on every backend."

import {
  "moonbitlang/async@0.22.5",
  "moonbitstack/moonbase@0.4.0",
  "moonbitstack/moonzip@0.3.0",
  "moonbitstack/moonhttp@0.12.1",
  "moonbitstack/moonvar@0.2.0",
  "moonbitstack/moondate@0.1.0",
  "moonbitstack/moonpool@0.2.0",
}
