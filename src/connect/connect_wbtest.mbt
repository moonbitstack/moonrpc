// The protocol's vocabulary: what a request says about its body, how that body is cut up, and
// what a failure looks like on the way back.

///|
test "connect: the four content types, and what they say" {
  let cases : Array[(String, Codec, Bool)] = [
    ("application/proto", Proto, false),
    ("application/json", Json, false),
    ("application/connect+proto", Proto, true),
    ("application/connect+json", Json, true),
  ]
  for case in cases {
    let parsed = Content::parse(case.0).unwrap()
    assert_eq(parsed.codec, case.1)
    assert_eq(parsed.streaming, case.2)
    assert_eq(parsed.text(), case.0)
  }
  // A parameter after `;` is not part of the type; anything else is not a Connect body.
  assert_eq(
    Content::parse("application/json; charset=utf-8").unwrap().codec,
    Json,
  )
  assert_true(Content::parse("application/grpc") is None)
  assert_true(Content::parse("text/plain") is None)
}

///|
test "connect: an envelope is a flag byte and a big-endian length" {
  let body = encode_envelope(b"hello")
  assert_eq(body.length(), envelope_header_size + 5)
  assert_eq(body[0], b'\x00')
  assert_eq(body[1:5], b"\x00\x00\x00\x05")
  let (envelope, next) = decode_envelope(body[:]).unwrap()
  assert_eq(envelope.payload, b"hello")
  assert_eq(envelope.is_end_stream(), false)
  assert_eq(envelope.is_compressed(), false)
  assert_eq(next, body.length())
}

///|
test "connect: the end-stream envelope carries the flags bit and a JSON payload" {
  let end = encode_envelope(b"{}", flags=flag_end_stream)
  let (envelope, _) = decode_envelope(end[:]).unwrap()
  assert_eq(envelope.is_end_stream(), true)
  assert_eq(envelope.payload, b"{}")
  // The compressed bit is the other flag, and an envelope may carry both.
  let both = encode_envelope(b"x", flags=flag_end_stream.to_int().to_byte())
  ignore(both)
}

///|
test "connect: a run of envelopes splits at the first one that is not whole" {
  let first = encode_envelope(b"one")
  let second = encode_envelope(b"two")
  let both = first + second
  // Cut the second short: what is there is one whole envelope and a partial one.
  let partial = both[0:both.length() - 1].to_owned()
  let (envelopes, at) = split_envelopes(partial)
  assert_eq(envelopes.length(), 1)
  assert_eq(envelopes[0].payload, b"one")
  assert_eq(at, first.length())
  let (whole, at2) = split_envelopes(both)
  assert_eq(whole.length(), 2)
  assert_eq(whole[1].payload, b"two")
  assert_eq(at2, both.length())
}

///|
test "connect: an envelope whose length would slice past the buffer is refused" {
  // The fourth length octet has its high bit set, which decodes negative.
  let hostile = b"\x00\xff\xff\xff\xff"
  assert_true(decode_envelope(hostile[:]) is None)
  // A length past what has arrived is not an error, it is not yet an envelope.
  let partial = encode_envelope(b"hello")[0:4].to_owned()
  assert_true(decode_envelope(partial[:]) is None)
}

///|
test "connect: every status has a word, and the word comes back" {
  let statuses : Array[@wire.Status] = [
    @wire.Status::Ok,
    @wire.Status::Cancelled,
    @wire.Status::Unknown,
    @wire.Status::InvalidArgument,
    @wire.Status::DeadlineExceeded,
    @wire.Status::NotFound,
    @wire.Status::AlreadyExists,
    @wire.Status::PermissionDenied,
    @wire.Status::ResourceExhausted,
    @wire.Status::FailedPrecondition,
    @wire.Status::Aborted,
    @wire.Status::OutOfRange,
    @wire.Status::Unimplemented,
    @wire.Status::Internal,
    @wire.Status::Unavailable,
    @wire.Status::DataLoss,
    @wire.Status::Unauthenticated,
  ]
  for status in statuses {
    assert_eq(status_of_code(code_of_status(status)), status)
  }
  // A word from a later version of the protocol is not a call that succeeded.
  assert_eq(status_of_code("something_new"), @wire.Status::Unknown)
}

///|
test "connect: a failure is an HTTP status and a JSON body" {
  assert_eq(http_status_of(@wire.Status::InvalidArgument), 400)
  assert_eq(http_status_of(@wire.Status::NotFound), 404)
  assert_eq(http_status_of(@wire.Status::Unauthenticated), 401)
  assert_eq(http_status_of(@wire.Status::Unavailable), 503)
  assert_eq(http_status_of(@wire.Status::DeadlineExceeded), 504)
  let body = error_json(@wire.Status::InvalidArgument, "name is required")
  assert_eq(
    body,
    Json::object(
      Map([
        ("code", Json::string("invalid_argument")),
        ("message", Json::string("name is required")),
      ]),
    ),
  )
  let (status, message) = error_of_json(body)
  assert_eq(status, @wire.Status::InvalidArgument)
  assert_eq(message, "name is required")
}

///|
test "connect: a body that is not an error reads as unknown without a message" {
  let (status, message) = error_of_json(Json::string("nonsense"))
  assert_eq(status, @wire.Status::Unknown)
  assert_eq(message, "")
}
