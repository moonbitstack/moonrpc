// The reference `ConformanceService`: six methods, answering whatever a test definition asks for
// — a message, an error, headers and trailers — and echoing the request it saw so the suite can
// check that nothing on the way in or out was mangled.
//
// The service is the same code the gRPC suite drives, minus the framing: a handler takes and
// returns wire bytes here, and the Connect dispatch is what puts them on a socket. That is why
// the same file answers over HTTP/1.1 and HTTP/2 without knowing which one it is on.

///|
/// The service, and the schema a JSON caller's body is read with.
pub struct Service {
  schema : @proto.Schema
}

///|
/// Compile the definitions the service is specified by. The `.proto` sources are the ones in
/// `idl/`, generated into `idl.mbt`; compiling them means the JSON codec and the handlers agree
/// on a field number because both come from the same file.
pub fn Service::new() -> Service raise @proto.PbError {
  { schema: @proto.Schema::compile(sources()), }
}

///|
pub fn Service::schema(self : Service) -> @proto.Schema {
  self.schema
}

///|
/// The six routes, keyed by the path a Connect caller posts to.
pub fn Service::routes(_self : Service) -> Array[(String, @connect.Route)] {
  [
    (
      unary_path,
      {
        input: unary_request,
        output: unary_response,
        handler: @stream.Handler::Unary((ctx, req) => answer_unary(ctx, req)),
      },
    ),
    (
      server_stream_path,
      {
        input: server_stream_request,
        output: server_stream_response,
        handler: @stream.Handler::ServerStreaming((ctx, req) => {
          answer_server_stream(ctx, req)
        }),
      },
    ),
    (
      client_stream_path,
      {
        input: client_stream_request,
        output: client_stream_response,
        handler: @stream.Handler::ClientStreaming((ctx, messages) => {
          answer_client_stream(ctx, messages)
        }),
      },
    ),
    (
      bidi_path,
      {
        input: bidi_request,
        output: bidi_response,
        handler: @stream.Handler::Bidi(ctx => bidi_handler(ctx)),
      },
    ),
    (
      idempotent_path,
      {
        input: idempotent_request,
        output: idempotent_response,
        handler: @stream.Handler::Unary((ctx, req) => {
          answer_idempotent_unary(ctx, req)
        }),
      },
    ),
    (
      unimplemented_path,
      {
        input: unimplemented_request,
        output: unimplemented_response,
        handler: @stream.Handler::Unary((ctx, _req) => {
          ctx.fail(
            @wire.Status::code(@wire.Status::Unimplemented),
            "this method is not implemented",
          )
          b""
        }),
      },
    ),
  ]
}

// -- where each method lives -------------------------------------------------

///|
let service_prefix : String = "/connectrpc.conformance.v1.ConformanceService/"

///|
let unary_path : String = service_prefix + "Unary"

///|
let server_stream_path : String = service_prefix + "ServerStream"

///|
let client_stream_path : String = service_prefix + "ClientStream"

///|
let bidi_path : String = service_prefix + "BidiStream"

///|
let idempotent_path : String = service_prefix + "IdempotentUnary"

///|
let unimplemented_path : String = service_prefix + "Unimplemented"

// -- the message each method takes and gives --------------------------------

///|
let package_prefix : String = ".connectrpc.conformance.v1."

///|
let unary_request : String = package_prefix + "UnaryRequest"

///|
let unary_response : String = package_prefix + "UnaryResponse"

///|
let server_stream_request : String = package_prefix + "ServerStreamRequest"

///|
let server_stream_response : String = package_prefix + "ServerStreamResponse"

///|
let client_stream_request : String = package_prefix + "ClientStreamRequest"

///|
let client_stream_response : String = package_prefix + "ClientStreamResponse"

///|
let bidi_request : String = package_prefix + "BidiStreamRequest"

///|
let bidi_response : String = package_prefix + "BidiStreamResponse"

///|
let idempotent_request : String = package_prefix + "IdempotentUnaryRequest"

///|
let idempotent_response : String = package_prefix + "IdempotentUnaryResponse"

///|
let unimplemented_request : String = package_prefix + "UnimplementedRequest"

///|
let unimplemented_response : String = package_prefix + "UnimplementedResponse"

///|
/// The `type_url` a request is echoed under, which is what a reader uses to decode it again.
fn type_url(message : String) -> String {
  "type.googleapis.com/connectrpc.conformance.v1." + message
}

// -- the handlers ------------------------------------------------------------

///|
/// One message back, or the error the definition named.
fn answer_unary(ctx : @stream.RpcContext, request : Bytes) -> Bytes {
  answer_unary_as(ctx, request, "UnaryRequest")
}

///|
/// The idempotent method echoes its request too, but the `Any` in `request_info` has to name
/// `IdempotentUnaryRequest`: the two messages share a shape on the wire, and a type URL that
/// guessed the more common one would fail the suite's round-trip comparison.
fn answer_idempotent_unary(ctx : @stream.RpcContext, request : Bytes) -> Bytes {
  answer_unary_as(ctx, request, "IdempotentUnaryRequest")
}

///|
fn answer_unary_as(
  ctx : @stream.RpcContext,
  request : Bytes,
  request_name : String,
) -> Bytes {
  let definition = decode_unary_def(definition_of(request))
  apply_headers(ctx, definition.headers)
  apply_trailers(ctx, definition.trailers)
  let info = encode_request_info(
    seen_headers(ctx),
    ctx.deadline_millis,
    [request],
    type_url(request_name),
  )
  if too_late(ctx, definition.delay_ms) {
    ctx.fail(code_deadline_exceeded, "the deadline passed before the response")
    return b""
  }
  match definition.error {
    Some(error) => {
      fail_with(ctx, error, info)
      b""
    }
    None =>
      encode_payload_response(
        encode_payload(definition.data, definition.has_data, info),
      )
  }
}

///|
/// The messages a definition asked for, in order, the first one carrying the request echo.
fn answer_server_stream(
  ctx : @stream.RpcContext,
  request : Bytes,
) -> Array[Bytes] {
  let definition = decode_stream_def(definition_of(request))
  apply_headers(ctx, definition.headers)
  apply_trailers(ctx, definition.trailers)
  let out : Array[Bytes] = []
  if too_late(ctx, definition.delay_ms) {
    ctx.fail(code_deadline_exceeded, "the deadline passed before the response")
    return out
  }
  for i = 0; i < definition.data.length(); i = i + 1 {
    let info = if i == 0 {
      encode_request_info(
        seen_headers(ctx),
        ctx.deadline_millis,
        [request],
        type_url("ServerStreamRequest"),
      )
    } else {
      b""
    }
    out.push(
      encode_payload_response(encode_payload(definition.data[i], true, info)),
    )
  }
  // An error is raised after the messages, which is where the specification puts it. The
  // request echo travels in the error only when the call sent no message: with data, the echo
  // already went out in the first reply, and a second copy is a detail the suite does not
  // expect — it counts them.
  match definition.error {
    Some(error) =>
      fail_with(
        ctx,
        error,
        if definition.data.length() == 0 {
          encode_request_info(
            seen_headers(ctx),
            ctx.deadline_millis,
            [request],
            type_url("ServerStreamRequest"),
          )
        } else {
          b""
        },
      )
    None => ()
  }
  out
}

///|
/// One message back, echoing every request the caller sent.
fn answer_client_stream(
  ctx : @stream.RpcContext,
  messages : Array[Bytes],
) -> Bytes {
  let definition = if messages.length() > 0 {
    decode_unary_def(definition_of(messages[0]))
  } else {
    empty_unary_def()
  }
  apply_headers(ctx, definition.headers)
  apply_trailers(ctx, definition.trailers)
  let info = encode_request_info(
    seen_headers(ctx),
    ctx.deadline_millis,
    messages,
    type_url("ClientStreamRequest"),
  )
  if too_late(ctx, definition.delay_ms) {
    ctx.fail(code_deadline_exceeded, "the deadline passed before the response")
    return b""
  }
  if too_late(ctx, definition.delay_ms) {
    ctx.fail(code_deadline_exceeded, "the deadline passed before the response")
    return b""
  }
  match definition.error {
    Some(error) => {
      fail_with(ctx, error, info)
      b""
    }
    None =>
      encode_payload_response(
        encode_payload(definition.data, definition.has_data, info),
      )
  }
}

///|
/// A bidirectional call: one answer per request when the definition asked for full duplex, and
/// the whole set once the caller has finished when it did not.
fn bidi_handler(ctx : @stream.RpcContext) -> @stream.BidiHandler {
  let definition : Ref[StreamDef?] = Ref(None)
  let duplex : Ref[Bool] = Ref(false)
  let received : Ref[Array[Bytes]] = Ref([])
  let index : Ref[Int32] = Ref(0)
  let set_up : Ref[Bool] = Ref(false)
  // Whether the definition's error has already closed the call, so that the end of the stream
  // does not raise it a second time.
  let raised : Ref[Bool] = Ref(false)
  let echo = fn() -> Bytes {
    encode_request_info(
      seen_headers(ctx),
      ctx.deadline_millis,
      received.val,
      type_url("BidiStreamRequest"),
    )
  }
  // A full-duplex reply echoes the request it answers and nothing else: the headers and the
  // deadline belong to the call, so they travel only in the first reply.
  let echo_one = fn(request : Bytes) -> Bytes {
    encode_request_info([], None, [request], type_url("BidiStreamRequest"))
  }
  @stream.BidiHandler::{
    on_message: request => {
      if !set_up.val {
        set_up.val = true
        let parsed = decode_stream_def(definition_of(request))
        duplex.val = full_duplex_of(request)
        apply_headers(ctx, parsed.headers)
        apply_trailers(ctx, parsed.trailers)
        definition.val = Some(parsed)
      }
      let parsed = match definition.val {
        Some(d) => d
        None => return []
      }
      if duplex.val {
        if too_late(ctx, parsed.delay_ms) {
          ctx.fail(
            code_deadline_exceeded, "the deadline passed before the response",
          )
          return []
        }
        // One request, one answer: this is the case a whole-body dispatch cannot serve.
        received.val = [request]
        let at = index.val
        if at < parsed.data.length() {
          index.val = at + 1
          let info = if at == 0 { echo() } else { echo_one(request) }
          [encode_payload_response(encode_payload(parsed.data[at], true, info))]
        } else {
          // The definition's messages are all answered, so the error it asked for is what is
          // left to send — one message too many is how a full-duplex caller asks for it.
          match parsed.error {
            Some(error) => {
              raised.val = true
              // An echo travels in the error only when no message went out before it.
              fail_with(ctx, error, if at == 0 { echo() } else { b"" })
              []
            }
            None => []
          }
        }
      } else {
        received.val.push(request)
        []
      }
    },
    on_end: () => {
      let parsed = match definition.val {
        Some(d) => d
        None => empty_stream_def()
      }
      let out : Array[Bytes] = []
      if too_late(ctx, parsed.delay_ms) {
        ctx.fail(
          code_deadline_exceeded, "the deadline passed before the response",
        )
        return out
      }
      // Whatever has not been answered yet: for a half-duplex call that is the whole set, and
      // for a full-duplex one whose caller stopped early it is the tail.
      let from = index.val
      index.val = parsed.data.length()
      for i = from; i < parsed.data.length(); i = i + 1 {
        let info = if i == 0 { echo() } else { b"" }
        out.push(
          encode_payload_response(encode_payload(parsed.data[i], true, info)),
        )
      }
      match parsed.error {
        // A half-duplex call raises its error once the caller has finished, whether or not it
        // sent messages first; a full-duplex one has already raised it, or has none to raise.
        Some(error) =>
          if !raised.val {
            raised.val = true
            fail_with(
              ctx,
              error,
              if from == 0 && parsed.data.length() == 0 {
                echo()
              } else {
                b""
              },
            )
          }
        None => ()
      }
      out
    },
  }
}

///|
/// Whether a response that waits `delay_ms` would arrive after the caller's deadline. A server
/// that slept would find out the same way — by waking up too late — and the answer it must give
/// is the same, so the wait is not performed to reach it.
fn too_late(ctx : @stream.RpcContext, delay_ms : Int32) -> Bool {
  if delay_ms <= 0 {
    return false
  }
  match ctx.deadline_millis {
    Some(deadline) => delay_ms > deadline
    None => false
  }
}

///|
/// The code a missed deadline carries: `CODE_DEADLINE_EXCEEDED`.
let code_deadline_exceeded : Int32 = 4

///|
/// Fail the call the way a definition asked, with the request echo attached as a detail: the
/// suite compares that detail against what it sent, so an error without one is an error it
/// cannot check.
fn fail_with(ctx : @stream.RpcContext, error : ErrorSpec, info : Bytes) -> Unit {
  if info.length() > 0 {
    ctx.error_details.push(
      encode_any(type_url("ConformancePayload.RequestInfo"), info),
    )
  }
  ctx.fail(error.code, message_text(error))
}

///|
/// The text an error carries. An error with no message of its own is sent with an empty one,
/// which the suite treats as "do not check".
fn message_text(error : ErrorSpec) -> String {
  match error.message {
    Some(text) => text
    None => ""
  }
}

///|
/// A definition that asks for nothing, which is what a request without one means.
fn empty_unary_def() -> UnaryDef {
  {
    headers: [],
    data: b"",
    has_data: false,
    error: None,
    trailers: [],
    delay_ms: 0,
  }
}

///|
fn empty_stream_def() -> StreamDef {
  { headers: [], data: [], delay_ms: 0, error: None, trailers: [], }
}
