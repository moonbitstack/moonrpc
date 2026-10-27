///|
/// The descriptor of a `greet` service with one unary method and its two messages,
/// reused across the descriptor and reflection tests.
fn greet_file() -> @proto.FileDescriptor {
  let request = @proto.MessageDescriptor::{
    name: "HelloRequest",
    fields: [@proto.FieldDescriptor::scalar("name", 1, TypeString)],
  }
  let reply = @proto.MessageDescriptor::{
    name: "HelloReply",
    fields: [@proto.FieldDescriptor::scalar("message", 1, TypeString)],
  }
  let greeter = @proto.ServiceDescriptor::{
    name: "Greeter",
    methods: [
      @proto.MethodDescriptor::{
        name: "SayHello",
        input_type: ".greet.HelloRequest",
        output_type: ".greet.HelloReply",
        client_streaming: false,
        server_streaming: false,
      },
    ],
  }
  @proto.FileDescriptor::new(
    "greet.proto",
    "greet",
    messages=[request, reply],
    services=[greeter],
  )
}
