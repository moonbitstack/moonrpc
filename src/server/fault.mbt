///|
/// The frames that report a fault to the peer: RST_STREAM on the offending stream, or
/// a GOAWAY naming `last_stream` — the highest stream the sender actually processed —
/// with the reason as debug data.
fn fault_frames(fault : @h2.Fault, last_stream : Int32) -> Array[@http2.Frame] {
  match fault {
    StreamFault(id~, code~, ..) => [RstStream(stream_id=id, error_code=code)]
    ConnFault(code~, why~) =>
      [
        GoAway(
          last_stream_id=last_stream,
          error_code=code,
          debug=@utf8.encode(why),
        ),
      ]
  }
}

///|
/// Whether adding `inc` would push a flow-control window past the 2^31-1 ceiling of
/// RFC 9113 §6.9.1. `add_window` saturates there so our own arithmetic stays sane, but
/// a peer that sends us over it has made an error we have to report, not absorb.
fn window_overflows(cur : Int32, inc : Int32) -> Bool {
  cur.to_int64() + inc.to_int64() > 0x7FFFFFFFL
}

///|
/// The fault a refused §5.1 transition amounts to. A frame arriving on a stream still
/// `Idle` is one that cannot open a stream at all, which §5.1 makes a connection error;
/// on a stream that has already finished receiving it is a stream error of type
/// STREAM_CLOSED and the rest of the connection is unaffected.
fn transition_fault(
  id : Int32,
  state : @stream.StreamState,
  why : String,
) -> @h2.Fault {
  match state {
    Idle => ConnFault(code=@http2.error_protocol_error, why~)
    _ => StreamFault(id~, code=@http2.error_stream_closed, why~)
  }
}
