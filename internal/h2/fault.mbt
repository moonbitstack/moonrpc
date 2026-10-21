// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// RFC 9113 §5.4 error handling. A protocol fault has a scope: a stream error kills one
// stream with RST_STREAM and leaves the connection running (§5.4.2), a connection error
// ends the connection after a GOAWAY that names the last stream the peer can count on
// (§5.4.1). The engine classifies a fault where it detects it and hands the driver the
// frames that say so, instead of raising into a driver whose only move is to drop the
// socket and leave the peer guessing.

///|
/// A protocol fault and the scope RFC 9113 §5.4 gives it. `code` is the §7 error code
/// that goes on the wire; `why` is the human half, carried in the GOAWAY debug data.
pub(all) suberror Fault {
  StreamFault(id~ : Int32, code~ : Int32, why~ : String)
  ConnFault(code~ : Int32, why~ : String)
}
