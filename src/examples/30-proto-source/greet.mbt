// `greet.proto`, as declarations. In another language this file would be what
// protoc writes; here it is written by hand, because the declarations are what
// the generator reads: `cmd/rpc` turns `#rpc.*` into the protobuf codec of each
// message, the registration of the service, its client, and the descriptor
// reflection serves.
//
// Every field carries what the .proto says — its tag through
// `#rpc.field(number=...)`, and the MoonBit type that holds what the .proto
// type holds. `main.mbt` compiles `greet.proto` and holds the descriptor the
// declarations produce against the one the file produces.

///|
/// The values are named after the enum and themselves, so `Calm` is written
/// `MOOD_CALM`. Their numbers are the .proto's, gaps included: a number a
/// removed value held is not given to another one.
#rpc.enum
pub enum Mood {
  Unspecified = 0
  Calm = 1
  Glad = 2
  Grumpy = 5
}

///|
/// A message nested in another is named with a dot, `.greet.v1.HelloReply.Badge`
/// being where this one lands.
#rpc.message(name="HelloReply.Badge")
pub struct Badge {
  label : String
}

///|
/// Fields are numbered in declaration order from 1, so only the field that skips
/// a number says one. `String?` is `optional`, `Map[K, V]` is `map<K, V>`, and a
/// field holding a message names its type.
#rpc.message
pub struct HelloRequest {
  name : String
  #rpc.field(number="4")
  tags : Array[String]
  nickname : String?
  mood : Mood
  extras : Map[String, Int64]
  badge : Badge
}

///|
#rpc.message
pub struct HelloReply {
  message : String
  call_count : Int64
  scores : Array[Int32]
  ratio : Double
  badges : Array[Badge]
  portrait : Bytes
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
/// A service is a struct, so it holds state; `name` is its full name, the
/// package in front. Its `#rpc.method`s are the RPCs of `greet.proto`, each in
/// PascalCase — which is the .proto's spelling already.
#rpc.service(name="greet.v1.Greeter")
pub struct Greeter {
  greeting : String
}

///|
/// One request, one reply: `rpc SayHello(HelloRequest) returns (HelloReply)`.
#rpc.method
fn Greeter::say_hello(self : Greeter, req : HelloRequest) -> HelloReply {
  {
    message: "\{self.greeting}, \{req.nickname.unwrap_or(req.name)}",
    call_count: req.extras.get("calls").unwrap_or(0L),
    scores: req.tags.map(t => t.length()),
    ratio: 0.5,
    badges: [{ label: if req.mood is Grumpy { "grumpy" } else { "calm" }, }],
    portrait: @utf8.encode(req.badge.label),
    cached: req.mood is Calm,
  }
}

///|
/// Returning an array streams the replies: `returns (stream Number)`.
#rpc.method
fn Greeter::count_to(self : Greeter, req : Upto) -> Array[Number] {
  ignore(self)
  Array::makei(req.n, i => { value: i + 1, })
}

///|
/// Taking an array receives a client stream, and the name says `Sum` rather than
/// `AddUp`, which is what the .proto calls the method.
#rpc.method(name="Sum")
fn Greeter::add_up(self : Greeter, req : Array[Number]) -> Number {
  ignore(self)
  { value: req.fold(init=0, (acc, x) => acc + x.value), }
}

///|
/// Taking and returning arrays is a bidirectional stream, answered once the
/// client half-closes.
#rpc.method
fn Greeter::echo(self : Greeter, req : Array[Number]) -> Array[Number] {
  ignore(self)
  req.rev()
}
