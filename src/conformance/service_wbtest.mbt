// The reference service, driven through the Connect dispatch but without a socket: a request
// message in, the message it answers with out.

///|
fn test_service() -> Service raise {
  Service::new()
}

///|
/// A server answering the six routes with `service`'s schema.
fn test_server(service : Service) -> @connect.Server {
  let server = @connect.Server::new(schema=service.schema())
  for route in service.routes() {
    server.add(route.0, route.1)
  }
  server
}

///|
fn header(name : String, value : String) -> @header.Header {
  { name: @utf8.encode(name), value: @utf8.encode(value), }
}

///|
/// A `Header` message for a definition.
fn header_message(name : String, value : String) -> Bytes {
  let w = @proto.PbWriter::new()
  w.string_(1, name)
  w.string_(2, value)
  w.to_bytes()
}

///|
/// A `UnaryResponseDefinition` asking for `data`, a header and a trailer.
fn unary_definition(data : Bytes) -> Bytes {
  let w = @proto.PbWriter::new()
  w.message_(1, header_message("x-answer", "yes"))
  w.bytes_(2, data)
  w.message_(4, header_message("x-trailer", "done"))
  w.to_bytes()
}

///|
/// A `UnaryRequest` carrying `definition`.
fn wrap_unary_request(definition : Bytes) -> Bytes {
  let w = @proto.PbWriter::new()
  w.message_(1, definition)
  w.to_bytes()
}

///|
/// The payload of a `UnaryResponse`: its data and the headers the request echo carries.
fn payload_of(response : Bytes) -> (Bytes, Array[(String, String)]) {
  let payload = match field_bytes(response, 1) {
    Some(b) => b
    None => b""
  }
  let data = match field_bytes(payload, 1) {
    Some(b) => b
    None => b""
  }
  let info = match field_bytes(payload, 2) {
    Some(b) => b
    None => b""
  }
  let headers : Array[(String, String)] = []
  let reader = @proto.PbReader::new(info)
  while !reader.eof() {
    let tag = reader.read_tag() catch { _ => break }
    match tag {
      (1, @proto.LengthDelim) => {
        let entry = reader.read_bytes() catch { _ => b"" }
        let name = match field_bytes(entry, 1) {
          Some(b) => @utf8.decode_lossy(b)
          None => ""
        }
        let value = match field_bytes(entry, 2) {
          Some(b) => @utf8.decode_lossy(b)
          None => ""
        }
        headers.push((name, value))
      }
      (_, wire) => reader.skip(wire) catch { _ => break }
    }
  }
  (data, headers)
}

///|
/// The first length-delimited field numbered `number`.
fn field_bytes(body : Bytes, number : Int32) -> Bytes? {
  let reader = @proto.PbReader::new(body)
  while !reader.eof() {
    let tag = reader.read_tag() catch { _ => break }
    let (at, wire) = tag
    if at == number && wire == @proto.LengthDelim {
      return Some(reader.read_bytes() catch { _ => b"" })
    }
    reader.skip(wire) catch {
      _ => break
    }
  }
  None
}

///|
test "conformance: a unary call answers the data it was asked for, beside the request echo" {
  let server = test_server(test_service())
  let answer = server.serve({
    path: "/connectrpc.conformance.v1.ConformanceService/Unary",
    headers: [
      header("content-type", "application/proto"),
      header("x-probe", "abc"),
    ],
    body: wrap_unary_request(unary_definition(b"the data")),
  })
  assert_eq(answer.status, 200)
  let (data, echoed) = payload_of(answer.body)
  assert_eq(data, b"the data")
  // The caller's own header comes back in the payload, which is how the suite checks that the
  // request arrived unmangled.
  let mut saw_probe = false
  let mut saw_answer = false
  for entry in echoed {
    if entry.0 == "x-probe" && entry.1 == "abc" {
      saw_probe = true
    }
  }
  assert_true(saw_probe)
  for h in answer.headers {
    if @utf8.decode_lossy(h.name) == "x-answer" {
      assert_eq(@utf8.decode_lossy(h.value), "yes")
      saw_answer = true
    }
  }
  assert_true(saw_answer)
}

///|
test "conformance: an error definition fails the call with the code it named" {
  let server = test_server(test_service())
  let definition = {
    let w = @proto.PbWriter::new()
    let error = @proto.PbWriter::new()
    error.int32(1, 7) // CODE_PERMISSION_DENIED
    error.string_(2, "not allowed")
    w.message_(3, error.to_bytes())
    w.to_bytes()
  }
  let answer = server.serve({
    path: "/connectrpc.conformance.v1.ConformanceService/Unary",
    headers: [header("content-type", "application/proto")],
    body: wrap_unary_request(definition),
  })
  // A unary failure is an HTTP status and an error body, and permission denied is a 403.
  assert_eq(answer.status, 403)
  let text = @utf8.decode_lossy(answer.body)
  assert_true(text.contains("permission_denied"))
  assert_true(text.contains("not allowed"))
}

///|
test "conformance: unimplemented says so" {
  let server = test_server(test_service())
  let answer = server.serve({
    path: "/connectrpc.conformance.v1.ConformanceService/Unimplemented",
    headers: [header("content-type", "application/proto")],
    body: b"",
  })
  assert_eq(answer.status, 501)
}

///|
test "conformance: a server stream answers one envelope per message it was asked for" {
  let server = test_server(test_service())
  let definition = {
    let w = @proto.PbWriter::new()
    w.bytes_(2, b"one")
    w.bytes_(2, b"two")
    w.to_bytes()
  }
  let request = {
    let w = @proto.PbWriter::new()
    w.message_(1, definition)
    w.to_bytes()
  }
  let body = @connect.encode_envelope(request) +
    @connect.encode_envelope(b"", flags=@connect.flag_end_stream)
  let answer = server.serve({
    path: "/connectrpc.conformance.v1.ConformanceService/ServerStream",
    headers: [header("content-type", "application/connect+proto")],
    body,
  })
  let (envelopes, _) = @connect.split_envelopes(answer.body)
  // Two messages and the end marker.
  assert_eq(envelopes.length(), 3)
  let (first, _) = payload_of(envelopes[0].payload)
  let (second, _) = payload_of(envelopes[1].payload)
  assert_eq(first, b"one")
  assert_eq(second, b"two")
  assert_eq(envelopes[2].is_end_stream(), true)
}

///|
/// A body read as JSON, or null when it is not JSON at all.
fn parse_json(body : Bytes) -> Json {
  @moonjson.loads(@utf8.decode_lossy(body)[:], @moonjson.strict) catch {
    _ => Json::null()
  }
}

///|
/// A `StreamResponseDefinition` carrying only an error.
fn stream_error_definition(code : Int32, message : String) -> Bytes {
  let w = @proto.PbWriter::new()
  let error = @proto.PbWriter::new()
  error.int32(1, code)
  error.string_(2, message)
  w.message_(4, error.to_bytes())
  w.to_bytes()
}

///|
/// A `BidiStreamRequest` carrying `definition` and no response data.
fn wrap_bidi_request(definition : Bytes, full_duplex : Bool) -> Bytes {
  let w = @proto.PbWriter::new()
  w.message_(1, definition)
  if full_duplex {
    w.bool_(2, true)
  }
  w.to_bytes()
}

///|
test "conformance: a half-duplex bidi call fails with the error its definition named" {
  let server = test_server(test_service())
  let body = @connect.encode_envelope(
      wrap_bidi_request(stream_error_definition(7, "half duplex failed"), false),
    ) +
    @connect.encode_envelope(b"", flags=@connect.flag_end_stream)
  let answer = server.serve({
    path: "/connectrpc.conformance.v1.ConformanceService/BidiStream",
    headers: [header("content-type", "application/connect+proto")],
    body,
  })
  let (envelopes, _) = @connect.split_envelopes(answer.body)
  assert_eq(envelopes.length(), 1)
  assert_eq(envelopes[0].is_end_stream(), true)
  let end = parse_json(envelopes[0].payload)
  let error = match end {
    Object(members) =>
      match members.get("error") {
        Some(value) => value
        None => Json::null()
      }
    _ => Json::null()
  }
  let (status, message) = @connect.error_of_json(error)
  assert_eq(status, @wire.Status::PermissionDenied)
  assert_eq(message, "half duplex failed")
}

///|
test "conformance: a full-duplex bidi call with no responses fails too" {
  let server = test_server(test_service())
  let body = @connect.encode_envelope(
      wrap_bidi_request(stream_error_definition(7, "full duplex failed"), true),
    ) +
    @connect.encode_envelope(b"", flags=@connect.flag_end_stream)
  let answer = server.serve({
    path: "/connectrpc.conformance.v1.ConformanceService/BidiStream",
    headers: [header("content-type", "application/connect+proto")],
    body,
  })
  let (envelopes, _) = @connect.split_envelopes(answer.body)
  let end = parse_json(envelopes[envelopes.length() - 1].payload)
  let error = match end {
    Object(members) =>
      match members.get("error") {
        Some(value) => value
        None => Json::null()
      }
    _ => Json::null()
  }
  assert_eq(@connect.error_of_json(error).0, @wire.Status::PermissionDenied)
}

///|
test "conformance: a JSON unary call with an error definition fails" {
  let server = test_server(test_service())
  let body = @utf8.encode(
    "{\"responseDefinition\":{\"error\":{\"code\":\"CODE_PERMISSION_DENIED\",\"message\":\"nope\"}}}",
  )
  let answer = server.serve({
    path: "/connectrpc.conformance.v1.ConformanceService/Unary",
    headers: [header("content-type", "application/json")],
    body,
  })
  assert_eq(answer.status, 403)
  assert_true(@utf8.decode_lossy(answer.body).contains("nope"))
}
