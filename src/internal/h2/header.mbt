// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Raise once an accumulated field block has grown past `@wire.max_header_list_size` — the
/// backstop against a CONTINUATION flood pinning unbounded memory. RFC 9113 §4.2 makes
/// a block over a limit the endpoint will hold a FRAME_SIZE_ERROR, and it is fatal to
/// the connection: the block never reaches the decoder, so the HPACK context stops
/// matching the peer's.
pub fn guard_header_size(buf : Buffer) -> Unit raise Fault {
  if buf.length() > @wire.max_header_list_size {
    raise ConnFault(
      code=@http2.error_frame_size_error,
      why="field block over " +
        @wire.max_header_list_size.to_string() +
        " octets",
    )
  }
}

///|
/// Whether a request header is a pseudo-header (`:`-prefixed) or a reserved gRPC/
/// HTTP header, and so is *not* surfaced as call metadata (RFC 7540 §8.1.2.1 plus
/// the gRPC HTTP/2 mapping).
pub fn is_reserved_header(name : Bytes) -> Bool {
  (name.length() > 0 && name[0] == b':') ||
  name == b"content-type" ||
  name == b"te" ||
  name == b"grpc-timeout" ||
  name == b"grpc-encoding" ||
  name == b"grpc-accept-encoding" ||
  name == b"user-agent"
}
