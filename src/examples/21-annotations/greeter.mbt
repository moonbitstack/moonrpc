///|
/// Fields are numbered in declaration order; `number=` sets one, and the
/// count carries on from there. `T?` is proto3 `optional`.
#rpc.message
pub struct HelloRequest {
  name : String
  #rpc.field(number="4")
  tags : Array[String]
  nickname : String?
}

///|
#rpc.message
pub struct HelloReply {
  message : String
  calls : Int64
  scores : Array[Int32]
  ratio : Double
  #rpc.skip
  cached : Bool
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
/// A service is a struct, so it carries state; its `#rpc.method`s are the RPCs,
/// named in PascalCase. `name` is the full name, its package before the last dot.
#rpc.service(name="greet.Greeter")
pub struct Greeter {
  greeting : String
}

///|
/// A `StatusError` answers with that status; a parameter of type `RpcContext`
/// receives the call's context.
#rpc.method
fn Greeter::say_hello(
  self : Greeter,
  ctx : @moonrpc.RpcContext,
  req : HelloRequest,
) -> HelloReply raise {
  if req.name == "" {
    raise @wire.StatusError(InvalidArgument, "a name, please")
  }
  ctx.add_header(b"x-greeter", b"annotated")
  let who = req.nickname.unwrap_or(req.name)
  {
    message: "\{self.greeting}, \{who}",
    calls: 9000000000,
    scores: req.tags.map(t => t.length()),
    ratio: 0.5,
    cached: false,
  }
}

///|
/// Returning an array streams the replies.
#rpc.method
fn Greeter::count_to(self : Greeter, req : Upto) -> Array[Number] {
  ignore(self)
  Array::makei(req.n, i => { value: i + 1, })
}

///|
/// Taking an array receives a client stream.
#rpc.method(name="Sum")
fn Greeter::add_up(self : Greeter, req : Array[Number]) -> Number {
  ignore(self)
  { value: req.fold(init=0, (acc, x) => acc + x.value), }
}
