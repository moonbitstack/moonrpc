// `.proto` source in, descriptors out. The parsing is `moonbitstack/moonproto`'s — a language
// with editions, groups, reserved ranges and custom options is not something to write twice —
// and what happens here is the conversion into the descriptor model the rest of this library
// carries, plus the name resolution a parser cannot do on its own: a field writes the type it
// holds as a name relative to where it stands, and only the set of all declared names says which
// one that is.
//
// Every name in the model is absolute — written with the leading dot — so that a lookup never
// has to ask which convention the writer of a descriptor used.

///|
/// The files `sources` describe, one per entry: the name the file is known by — which is what an
/// `import` in another file writes — and its text. Order does not matter: a name resolves against
/// every file given, not against the ones already read.
pub fn compile_proto(
  sources : Array[(String, String)],
) -> Array[FileDescriptor] raise PbError {
  let parsed = []
  for source in sources {
    let proto = @mpparser.parse(source.0, source.1) catch {
      e => raise BadSchema(e.to_string())
    }
    parsed.push(proto)
  }
  // Every name any file declares, which is what a relative reference is resolved against.
  let symbols = []
  for proto in parsed {
    let prefix = proto_prefix(proto.package_name)
    for message in proto.message_type {
      proto_collect_symbols(prefix, message.name, message, symbols)
    }
    for e in proto.enum_type {
      symbols.push(prefix + "." + e.name)
    }
  }
  let files = []
  for proto in parsed {
    files.push(proto_file_of(proto, symbols))
  }
  files
}

///|
/// The scope a file's declarations stand in, with the leading dot, or the empty string for a
/// file with no package.
fn proto_prefix(package_name : String) -> String {
  if package_name.length() > 0 {
    "." + package_name
  } else {
    ""
  }
}

///|
fn proto_collect_symbols(
  prefix : String,
  name : String,
  message : @mpdesc.DescriptorProto,
  out : Array[String],
) -> Unit {
  let full = prefix + "." + name
  out.push(full)
  for nested in message.nested_type {
    proto_collect_symbols(full, nested.name, nested, out)
  }
  for e in message.enum_type {
    out.push(full + "." + e.name)
  }
}

///|
/// One file, its type names resolved.
pub fn proto_file_of(
  proto : @mpdesc.FileDescriptorProto,
  symbols : Array[String],
) -> FileDescriptor {
  let prefix = proto_prefix(proto.package_name)
  let messages = []
  for message in proto.message_type {
    messages.push(
      proto_message_of(prefix, proto.package_name, message, symbols),
    )
  }
  let enums = []
  for e in proto.enum_type {
    enums.push(proto_enum_of(e))
  }
  let services = []
  for s in proto.service {
    services.push(proto_service_of(s, prefix, proto.package_name, symbols))
  }
  {
    name: proto.name,
    package_: proto.package_name,
    dependencies: proto.dependency,
    messages,
    enums,
    services,
    syntax: if proto.syntax.length() > 0 {
      proto.syntax
    } else {
      "proto3"
    },
  }
}

///|
fn proto_message_of(
  prefix : String,
  package_ : String,
  proto : @mpdesc.DescriptorProto,
  symbols : Array[String],
) -> MessageDescriptor {
  let full = prefix + "." + proto.name
  let fields = []
  for f in proto.field {
    fields.push(proto_field_of(f, full, package_, symbols))
  }
  let nested = []
  for inner in proto.nested_type {
    nested.push(proto_message_of(full, package_, inner, symbols))
  }
  let enums = []
  for e in proto.enum_type {
    enums.push(proto_enum_of(e))
  }
  let oneofs = []
  for oneof in proto.oneof_decl {
    oneofs.push(oneof.name)
  }
  // A proto3 `optional` field is only marked present if it sits in a oneof of its own, which
  // protoc writes and a parser may leave out. If it is missing, it is added here: a descriptor
  // that says `proto3_optional` without a oneof is one a strict reader refuses.
  for i = 0; i < fields.length(); i = i + 1 {
    let f = fields[i]
    if f.proto3_optional && f.oneof_index is None {
      fields[i] = {
        name: f.name,
        number: f.number,
        label: f.label,
        type_: f.type_,
        type_name: f.type_name,
        oneof_index: Some(oneofs.length()),
        proto3_optional: true,
      }
      oneofs.push("_" + f.name)
    }
  }
  {
    name: proto.name,
    fields,
    nested,
    enums,
    oneofs,
    map_entry: proto.map_entry,
  }
}

///|
fn proto_enum_of(proto : @mpdesc.EnumDescriptorProto) -> EnumDescriptor {
  let values = []
  for v in proto.value {
    values.push({ name: v.name, number: v.number, })
  }
  { name: proto.name, values, }
}

///|
fn proto_service_of(
  proto : @mpdesc.ServiceDescriptorProto,
  scope : String,
  package_ : String,
  symbols : Array[String],
) -> ServiceDescriptor {
  let methods = []
  for m in proto.methods {
    methods.push({
      name: m.name,
      // A method names its request and response the same way a field names its type: relative
      // to the file it is declared in.
      input_type: proto_resolve(m.input_type, scope, package_, symbols),
      output_type: proto_resolve(m.output_type, scope, package_, symbols),
      client_streaming: m.client_streaming,
      server_streaming: m.server_streaming,
    })
  }
  { name: proto.name, methods, }
}

///|
fn proto_field_of(
  proto : @mpdesc.FieldDescriptorProto,
  scope : String,
  package_ : String,
  symbols : Array[String],
) -> FieldDescriptor {
  let type_name = match proto.type_name {
    Some(name) => proto_resolve(name, scope, package_, symbols)
    None => ""
  }
  {
    name: proto.name,
    number: proto.number,
    label: FieldLabel::of(proto.label),
    type_: FieldType::of(proto.type_code),
    type_name,
    oneof_index: proto.oneof_index,
    proto3_optional: proto.proto3_optional,
  }
}

///|
/// The absolute spelling of a name a field holds. A name that starts with a dot is absolute
/// already; anything else is tried against the scope it stands in and then against each enclosing
/// scope outward, which is how the language resolves a relative name.
fn proto_resolve(
  name : String,
  scope : String,
  package_ : String,
  symbols : Array[String],
) -> String {
  if name.length() == 0 {
    return ""
  }
  if name[0] == '.' {
    return name
  }
  let mut at = scope
  while true {
    let candidate = at + "." + name
    if symbols.contains(candidate) {
      return candidate
    }
    if !at.contains(".") {
      break
    }
    at = proto_parent(at)
  }
  // Nothing here declares it, so the file it names was not passed in: keep the name as written,
  // anchored to its own package rather than to the file that refers to it.
  if name.contains(".") || package_.length() == 0 {
    "." + name
  } else {
    "." + package_ + "." + name
  }
}

///|
/// The scope a name declared inside `name` stands in once you step out of it: `.a.b.C` is `.a.b`,
/// and `.a` is the root.
fn proto_parent(name : String) -> String {
  let mut cut = 0
  let mut at = 0
  for ch in name {
    if ch == '.' {
      cut = at
    }
    at = at + 1
  }
  name.exact_view(start=0, end=cut).to_owned()
}

///|
/// A schema compiled from `.proto` source.
pub fn Schema::compile(
  sources : Array[(String, String)],
) -> Schema raise PbError {
  Schema::of(compile_proto(sources))
}
