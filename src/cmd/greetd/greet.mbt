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
/// The greeter grpcurl lists, describes and calls through Server Reflection,
/// one method of each cardinality.
#rpc.service(name="greet.Greeter")
pub struct Greeter {}

///|
/// An empty name ends the call with `INVALID_ARGUMENT`, the non-OK path a real
/// client has to read from the trailers.
#rpc.method
fn Greeter::say_hello(self : Greeter, req : HelloRequest) -> HelloReply raise {
  ignore(self)
  if req.name == "" {
    raise @wire.StatusError(InvalidArgument, "name is required")
  }
  {
    message: "Hello, \{req.name}",
    mood: req.mood,
    total: req.extras.values().fold(init=0L, (a, b) => a + b),
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
