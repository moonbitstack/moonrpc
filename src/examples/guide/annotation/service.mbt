///|
/// The guide's annotation variant: a message, a service and its method, all
/// declared with `#rpc`. `cmd/rpc` writes `service.g.mbt` from this file.
#rpc.message
pub struct HelloRequest {
  name : String
}

///|
#rpc.message
pub struct HelloReply {
  message : String
}

///|
#rpc.service(name="greet.Greeter")
pub struct Greeter {}

///|
#rpc.method
fn Greeter::say_hello(self : Greeter, req : HelloRequest) -> HelloReply {
  ignore(self)
  { message: "Hello, " + req.name, }
}
