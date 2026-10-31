// Typed handlers over the two pure engines: `unary`, `server_streaming` and
// `client_streaming` decode the request, encode the reply, and answer an error
// with the status grpc-go would.

///|
priv struct Word {
  text : String
}

///|
impl @proto.Message for Word with fn encode(self) {
  let w = @proto.PbWriter::new()
  if self.text != "" {
    w.string_(1, self.text)
  }
  w.to_bytes()
}

///|
impl @proto.Message for Word with fn decode(b) {
  let r = @proto.PbReader::new(b)
  let mut text = ""
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => text = r.read_string()
      (_, wire) => r.skip(wire)
    }
  }
  { text, }
}

///|
fn word(text : String) -> Bytes {
  @proto.Message::encode(Word::{ text, })
}

///|
fn text_of(b : Bytes) -> String raise {
  let w : Word = @proto.Message::decode(b)
  w.text
}

///|
/// One unary call on `path` against a server holding `handler` there.
fn call(handler : @stream.Handler, body : Bytes) -> @client.CallReply raise {
  let server = @server.H2Server::new()
  mount(server, "/w.W/M", handler)
  let client = @client.H2Client::new()
  let (id, frames) = client.unary("/w.W/M", body)
  drive_pair(server, client, id, frames)
  client.reply(id)
}

///|
fn[R : @stream.Registrar] mount(
  registrar : R,
  path : String,
  handler : @stream.Handler,
) -> Unit {
  registrar.register_handler(path, handler)
}

///|
test "unary decodes the request and encodes the reply" {
  let reply = call(
    @service.unary((_ctx, w : Word) => Word::{ text: w.text.to_upper(), }),
    word("hi"),
  )
  assert_eq(reply.grpc_status, 0)
  assert_eq(text_of(reply.messages[0]), "HI")
}

///|
test "a StatusError is answered with its status, anything else with UNKNOWN" {
  let reply = call(
    @service.unary(fn(_ctx, w : Word) -> Word raise {
      raise @wire.StatusError(NotFound, "no word \{w.text}")
    }),
    word("x"),
  )
  assert_eq((reply.grpc_status, reply.grpc_message), (5, "no word x"))
  let reply = call(
    @service.unary(fn(_ctx, _w : Word) -> Word raise { fail("broke") }),
    word("x"),
  )
  assert_eq(reply.grpc_status, 2)
  assert_true(reply.grpc_message.contains("broke"))
  assert_eq(reply.messages.length(), 0)
}

///|
test "a request that does not decode is INTERNAL and never reaches the handler" {
  let mut reached = false
  let reply = call(
    @service.unary((_ctx, w : Word) => {
      reached = true
      w
    }),
    b"\x0a\x05ab",
  )
  assert_eq(reply.grpc_status, 13)
  assert_true(
    reply.grpc_message.has_prefix("grpc: error unmarshalling request"),
  )
  assert_false(reached)
}

///|
test "server_streaming encodes each reply in turn" {
  let server = @server.H2Server::new()
  mount(
    server,
    "/w.W/Up",
    @service.server_streaming((_ctx, w : Word) => {
      [Word::{ text: w.text + "1", }, Word::{ text: w.text + "2", }]
    }),
  )
  let client = @client.H2Client::new()
  let id = client.open("/w.W/Up")
  let frames = client.send(id, word("n"), end=true)
  drive_pair(server, client, id, frames)
  let reply = client.reply(id)
  assert_eq(reply.grpc_status, 0)
  assert_eq(reply.messages.map(text_of), ["n1", "n2"])
}

///|
test "client_streaming decodes every request for one reply" {
  let server = @server.H2Server::new()
  mount(
    server,
    "/w.W/Join",
    @service.client_streaming((_ctx, ws : Array[Word]) => Word::{
      text: ws.map(w => w.text).join("+"),
    }),
  )
  let client = @client.H2Client::new()
  let id = client.open("/w.W/Join")
  let all : Array[@http2.Frame] = []
  for t in ["a", "b", "c"] {
    all.append(client.send(id, word(t)))
  }
  all.append(client.close_send(id))
  drive_pair(server, client, id, all)
  let reply = client.reply(id)
  assert_eq(reply.grpc_status, 0)
  assert_eq(text_of(reply.messages[0]), "a+b+c")
}

///|
test "double and float fields carry their IEEE 754 bits" {
  let w = @proto.PbWriter::new()
  w.double_(1, -2.5)
  w.float_(2, (1.5 : Float))
  let r = @proto.PbReader::new(w.to_bytes())
  assert_true(r.read_tag() == (1, Fixed64))
  assert_eq(r.read_double(), -2.5)
  assert_true(r.read_tag() == (2, Fixed32))
  assert_eq(r.read_float(), (1.5 : Float))
  assert_true(r.eof())
}

///|
/// Pass frames back and forth, in order, until neither engine has more to say,
/// without waiting for the call to end: an open stream stops here too.
fn settle(
  server : @server.H2Server,
  client : @client.H2Client,
  to_server : Array[@http2.Frame],
  to_client : Array[@http2.Frame],
) -> Unit raise {
  let mut si = 0
  let mut ci = 0
  while si < to_server.length() || ci < to_client.length() {
    if si < to_server.length() {
      to_client.append(server.feed(to_server[si]))
      si += 1
    } else {
      to_server.append(client.feed(to_client[ci]))
      ci += 1
    }
  }
}

///|
test "bidi answers once the client half-closes" {
  let server = @server.H2Server::new()
  mount(
    server,
    "/w.W/Back",
    @service.bidi((_ctx, ws : Array[Word]) => ws.rev()),
  )
  let client = @client.H2Client::new()
  let id = client.open("/w.W/Back")
  let all : Array[@http2.Frame] = []
  for t in ["a", "b", "c"] {
    all.append(client.send(id, word(t)))
  }
  all.append(client.close_send(id))
  drive_pair(server, client, id, all)
  let reply = client.reply(id)
  assert_eq(reply.grpc_status, 0)
  assert_eq(reply.messages.map(text_of), ["c", "b", "a"])
}

///|
test "bidi_each answers each request as it arrives, then at the end" {
  let server = @server.H2Server::new()
  mount(
    server,
    "/w.W/Echo",
    @service.bidi_each(
      (_ctx, w : Word) => [Word::{ text: w.text.to_upper(), }],
      end=_ctx => [Word::{ text: "bye", }],
    ),
  )
  let client = @client.H2Client::new()
  let id = client.open("/w.W/Echo")
  settle(
    server,
    client,
    client.preface() + client.send(id, word("hi")),
    server.preface(),
  )
  assert_false(client.is_done(id))
  assert_eq(client.take_messages(id).map(text_of), ["HI"])
  settle(server, client, client.close_send(id), [])
  assert_true(client.is_done(id))
  let reply = client.reply(id)
  assert_eq(reply.grpc_status, 0)
  assert_eq(reply.messages.map(text_of), ["bye"])
}

///|
test "bidi_each answers an error with its status and stops answering" {
  let server = @server.H2Server::new()
  let seen = []
  mount(
    server,
    "/w.W/Fail",
    @service.bidi_each(fn(_ctx, w : Word) -> Array[Word] raise {
      seen.push(w.text)
      raise @wire.StatusError(InvalidArgument, "no \{w.text}")
    }),
  )
  let client = @client.H2Client::new()
  let id = client.open("/w.W/Fail")
  let all = client.send(id, word("x"))
  all.append(client.close_send(id))
  drive_pair(server, client, id, all)
  let reply = client.reply(id)
  assert_eq(reply.grpc_status, @wire.Status::InvalidArgument.code())
  assert_eq(reply.grpc_message, "no x")
  assert_eq(seen, ["x"])
}

///|
test "bidi never reaches the handler when a request does not decode" {
  let server = @server.H2Server::new()
  let mut reached = false
  mount(
    server,
    "/w.W/Back",
    @service.bidi((_ctx, ws : Array[Word]) => {
      reached = true
      ws
    }),
  )
  let client = @client.H2Client::new()
  let id = client.open("/w.W/Back")
  let all = client.send(id, b"\xff")
  all.append(client.close_send(id))
  drive_pair(server, client, id, all)
  assert_eq(client.reply(id).grpc_status, @wire.Status::Internal.code())
  assert_false(reached)
}

///|
fn reply_of(grpc_status : Int32, messages : Array[Bytes]) -> @client.CallReply {
  {
    status: b"200",
    grpc_status,
    grpc_message: "why",
    headers: [],
    messages,
    trailers: [],
    committed: true,
    unprocessed: false,
  }
}

///|
fn status_raised(f : () -> Unit raise) -> (@wire.Status, String)? {
  try {
    f()
    None
  } catch {
    @wire.StatusError(s, m) => Some((s, m))
    _ => None
  }
}

///|
test "CallReply::ok gives the messages of an OK call and raises any other status" {
  assert_eq(reply_of(0, [b"a", b"b"]).ok(), [b"a", b"b"])
  assert_eq(
    status_raised(() => ignore(reply_of(5, []).ok())),
    Some((NotFound, "why")),
  )
  assert_eq(
    status_raised(() => ignore(reply_of(-1, []).ok())),
    Some((Internal, "server closed the stream without sending trailers")),
  )
  assert_eq(
    status_raised(() => ignore(reply_of(99, []).ok())),
    Some((Unknown, "why")),
  )
}

///|
test "CallReply::one wants exactly one message" {
  assert_eq(reply_of(0, [b"a"]).one(), b"a")
  assert_eq(
    status_raised(() => ignore(reply_of(0, []).one())).map(p => p.0),
    Some(Internal),
  )
  assert_eq(
    status_raised(() => ignore(reply_of(0, [b"a", b"b"]).one())).map(p => p.0),
    Some(Internal),
  )
  assert_eq(
    status_raised(() => ignore(reply_of(14, [b"a"]).one())).map(p => p.0),
    Some(Unavailable),
  )
}
