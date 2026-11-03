// The well-known files channelz.proto imports, as descriptors. channelz only
// carries a timestamp, a duration, a 64-bit wrapper and an Any, so these are the
// four messages reflection has to be able to resolve for grpcurl to describe the
// service; they are not a general well-known-type library.

///|
/// `google/protobuf/timestamp.proto`.
pub fn timestamp_file() -> @proto.FileDescriptor {
  @proto.FileDescriptor::new(
    "google/protobuf/timestamp.proto",
    "google.protobuf",
    messages=[
      @proto.MessageDescriptor::new("Timestamp", [
        @proto.FieldDescriptor::new("seconds", 1, @proto.TypeInt64),
        @proto.FieldDescriptor::new("nanos", 2, @proto.TypeInt32),
      ]),
    ],
  )
}

///|
/// `google/protobuf/duration.proto`.
pub fn duration_file() -> @proto.FileDescriptor {
  @proto.FileDescriptor::new(
    "google/protobuf/duration.proto",
    "google.protobuf",
    messages=[
      @proto.MessageDescriptor::new("Duration", [
        @proto.FieldDescriptor::new("seconds", 1, @proto.TypeInt64),
        @proto.FieldDescriptor::new("nanos", 2, @proto.TypeInt32),
      ]),
    ],
  )
}

///|
/// `google/protobuf/any.proto`.
pub fn any_file() -> @proto.FileDescriptor {
  @proto.FileDescriptor::new("google/protobuf/any.proto", "google.protobuf", messages=[
    @proto.MessageDescriptor::new("Any", [
      @proto.FieldDescriptor::new("type_url", 1, @proto.TypeString),
      @proto.FieldDescriptor::new("value", 2, @proto.TypeBytes),
    ]),
  ])
}

///|
/// `google/protobuf/wrappers.proto`, with the two wrappers channelz uses.
pub fn wrappers_file() -> @proto.FileDescriptor {
  @proto.FileDescriptor::new(
    "google/protobuf/wrappers.proto",
    "google.protobuf",
    messages=[
      @proto.MessageDescriptor::new("Int64Value", [
        @proto.FieldDescriptor::new("value", 1, @proto.TypeInt64),
      ]),
      @proto.MessageDescriptor::new("UInt32Value", [
        @proto.FieldDescriptor::new("value", 1, @proto.TypeUint32),
      ]),
    ],
  )
}

///|
/// Every dependency file, in the order channelz.proto imports them.
pub fn well_known_files() -> Array[@proto.FileDescriptor] {
  [any_file(), duration_file(), timestamp_file(), wrappers_file()]
}
