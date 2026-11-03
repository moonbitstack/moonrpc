///|
/// Run the annotation-declared service against the pure engines in memory.
///
///     moon run src/examples/guide/annotation
fn main {
  let reply = @harness.round_trip(
    server => Greeter::{ }.register(server),
    "/greet.Greeter/SayHello",
    @moonrpc.Message::encode(HelloRequest::{ name: "Ada", }),
  ) catch {
    _ => abort("the call failed")
  }
  let out : HelloReply = @moonrpc.Message::decode(reply) catch {
    _ => abort("the reply did not decode")
  }
  println(out.message)
}
