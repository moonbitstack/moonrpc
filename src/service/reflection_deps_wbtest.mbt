// Reflection answers a descriptor set whole: the file a client asked for and everything it
// imports, so the types in it resolve without a second round trip — and it answers the two
// extension queries, which a server that declares no extensions answers honestly.

///|
/// Two files, the second importing the first: `app.proto` declares a service whose methods
/// use a message `base.proto` defines.
fn two_files() -> (
  ReflectionService,
  @proto.FileDescriptor,
  @proto.FileDescriptor,
) {
  let base = @proto.FileDescriptor::new("base.proto", "base", messages=[
    @proto.MessageDescriptor::new("Id", [
      @proto.FieldDescriptor::new("value", 1, TypeString),
    ]),
  ])
  let app = @proto.FileDescriptor::new(
    "app.proto",
    "app",
    dependencies=["base.proto"],
    services=[
      @proto.ServiceDescriptor::{
        name: "App",
        methods: [
          @proto.MethodDescriptor::{
            name: "Lookup",
            input_type: ".base.Id",
            output_type: ".base.Id",
            client_streaming: false,
            server_streaming: false,
          },
        ],
      },
    ],
  )
  let refl = ReflectionService::new()
  refl.add_file(base)
  refl.add_file(app)
  (refl, base, app)
}

///|
test "reflection: a symbol brings its file and every file it imports" {
  let (refl, _base, app) = two_files()
  let answer = refl.handle(
    encode_reflection_request(FileContainingSymbol("app.App")),
  )
  match decode_reflection_response(answer) {
    FileDescriptors(protos) => {
      // The file asked about comes first, then its import: a client that only got the
      // first could not resolve `.base.Id` in it.
      assert_eq(protos.length(), 2)
      assert_eq(@proto.FileDescriptor::decode(protos[0]).name, "app.proto")
      assert_eq(@proto.FileDescriptor::decode(protos[1]).name, "base.proto")
      // The pair is a closed set: protoc can compile it on its own.
      assert_eq(@proto.FileDescriptor::decode(protos[0]).name, app.name)
    }
    _ => abort("no descriptors for app.App")
  }
}

///|
test "reflection: a file by name brings its imports too" {
  let (refl, _base, _app) = two_files()
  let answer = refl.handle(
    encode_reflection_request(FileByFilename("app.proto")),
  )
  match decode_reflection_response(answer) {
    FileDescriptors(protos) => assert_eq(protos.length(), 2)
    _ => abort("no descriptors for app.proto")
  }
}

///|
test "reflection: a file with no imports is answered alone" {
  let (refl, _base, _app) = two_files()
  let answer = refl.handle(
    encode_reflection_request(FileByFilename("base.proto")),
  )
  match decode_reflection_response(answer) {
    FileDescriptors(protos) => assert_eq(protos.length(), 1)
    _ => abort("no descriptors for base.proto")
  }
}

///|
test "reflection: a known type declares no extensions, which is an empty list" {
  let (refl, _base, _app) = two_files()
  let answer = refl.handle(
    encode_reflection_request(AllExtensionNumbers("app.App")),
  )
  match decode_reflection_response(answer) {
    ExtensionNumbers(base, numbers) => {
      assert_eq(base, "app.App")
      assert_eq(numbers.length(), 0)
    }
    _ => abort("no extension numbers for app.App")
  }
}

///|
test "reflection: an extension query for something that is not there is NOT_FOUND" {
  let (refl, _base, _app) = two_files()
  for
    request in [
      FileContainingExtension("app.App", 100),
      AllExtensionNumbers("app.Missing"),
    ] {
    match
      decode_reflection_response(
        refl.handle(encode_reflection_request(request)),
      ) {
      ReflectionError(code, message) => {
        assert_eq(code, 5)
        assert_true(message.length() > 0)
      }
      _ => abort("an extension query answered as if it were found")
    }
  }
}

///|
test "reflection: the extension queries round-trip through the codec" {
  for
    request in [
      FileContainingExtension("app.App", 100),
      AllExtensionNumbers("app.App"),
    ] {
    let back = decode_reflection_request(encode_reflection_request(request))
    assert_eq(back == request, true)
  }
}
