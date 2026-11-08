///|
#rpc.enum
pub enum Mood {
  Calm = 0
  Glad = 1
}

///|
#rpc.message
pub struct HelloRequest {
  name : String
  mood : Mood
  extras : Map[String, Int64]
}

///|
#rpc.message
pub struct HelloReply {
  message : String
  mood : Mood
  total : Int64
  // What the server saw arrive with the call: the `x-test-*` metadata as `name=value`, and
  // how much of the caller's deadline was left when the handler ran.
  echo_headers : Array[String]
  deadline_ms : Int64
}

///|
#rpc.message
pub struct Upto {
  n : Int32
}

///|
#rpc.message
pub struct Number {
  value : Int32
}

///|
/// A message big enough to need more than one HTTP/2 frame in each direction.
#rpc.message
pub struct Batch {
  values : Array[Int32]
}

///|
/// The greeter grpcurl lists, describes and calls through Server Reflection,
/// one method of each cardinality.
#rpc.service(name="greet.Greeter")
pub struct Greeter {}

///|
/// The `google.protobuf.Any` a rich error carries: a `google.protobuf.StringValue` holding
/// `text`, which is a message every gRPC client's runtime already knows.
fn string_value_any(text : String) -> Bytes {
  let inner = @moonrpc.PbWriter::new()
  inner.string_(1, text)
  let any = @moonrpc.PbWriter::new()
  any.string_(1, "type.googleapis.com/google.protobuf.StringValue")
  any.bytes_(2, inner.to_bytes())
  any.to_bytes()
}

///|
/// An empty name ends the call with `INVALID_ARGUMENT` — and with a detail, so a caller reads
/// the `grpc-status-details-bin` trailer rather than only the code. The reply also echoes the
/// `x-test-*` metadata it was called with and the deadline it was given, which is how a
/// foreign client checks that headers and the timeout survived the trip.
#rpc.method
fn Greeter::say_hello(
  self : Greeter,
  ctx : @moonrpc.RpcContext,
  req : HelloRequest,
) -> HelloReply raise {
  ignore(self)
  if req.name == "" {
    ctx.add_error_detail(string_value_any("name is required"))
    raise @wire.StatusError(InvalidArgument, "name is required")
  }
  let echoed : Array[String] = []
  for h in ctx.metadata {
    let name = @utf8.decode_lossy(h.name)
    if name.has_prefix("x-test-") {
      echoed.push(name + "=" + @utf8.decode_lossy(h.value))
    }
  }
  {
    message: "Hello, \{req.name}",
    mood: req.mood,
    total: req.extras.values().fold(init=0L, (a, b) => a + b),
    echo_headers: echoed,
    deadline_ms: match ctx.deadline_millis {
      Some(ms) => ms.to_int64()
      None => -1L
    },
  }
}

///|
#rpc.method
fn Greeter::count_to(self : Greeter, req : Upto) -> Array[Number] {
  ignore(self)
  Array::makei(req.n, i => { value: i + 1, })
}

///|
#rpc.method
fn Greeter::sum(self : Greeter, req : Array[Number]) -> Number {
  ignore(self)
  { value: req.fold(init=0, (a, x) => a + x.value), }
}

///|
#rpc.method
fn Greeter::echo(self : Greeter, req : Array[Number]) -> Array[Number] {
  ignore(self)
  req.rev()
}

///|
/// One message in, the same message back. The batch is large enough that both directions need
/// more than one HTTP/2 frame and a window update, which is what a small echo never tests.
#rpc.method
fn Greeter::batch_echo(self : Greeter, req : Batch) -> Batch {
  ignore(self)
  req
}
