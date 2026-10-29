///|
/// `#rpc.message` and `#rpc.service` on structs, `#rpc.field`／`#rpc.skip` on
/// fields, `#rpc.method` on a service's methods, turned into each message's
/// `Message`, each service's `register`, and the file's `descriptor()`.
priv struct Rpc {}

///|
impl @gen.Generator for Rpc with fn name(_) {
  "moonrpc"
}

///|
let message_spec : @attr.Spec = @attr.Spec::new("rpc.message").optional(
  "name",
  Str,
)

///|
let field_spec : @attr.Spec = @attr.Spec::new("rpc.field")
  .optional("number", Str)
  .optional("name", Str)

///|
let skip_spec : @attr.Spec = @attr.Spec::new("rpc.skip")

///|
let service_spec : @attr.Spec = @attr.Spec::new("rpc.service").optional(
  "name",
  Str,
)

///|
let method_spec : @attr.Spec = @attr.Spec::new("rpc.method").optional(
  "name",
  Str,
)

///|
fn at(attr : @attribute.Attribute, file : String) -> String {
  "\{file}:\{attr.loc.start.lnum}:\{attr.loc.start.column()}"
}

///|
/// The `#rpc.*` attributes among `attrs`, refusing one that does not parse.
fn rpc_attrs(
  attrs : @list.List[@attribute.Attribute],
  file : String,
) -> Array[@attribute.Attribute] raise {
  for attr in attrs {
    if @attr.name_of(attr) is None && attr.raw.has_prefix("#rpc.") {
      fail("\{at(attr, file)}: `\{attr.raw}` does not parse as an annotation")
    }
  }
  @attr.under(attrs, "rpc")
}

///|
/// The one attribute among `found`, which must be one of `names`.
fn single(
  found : Array[@attribute.Attribute],
  names : Array[String],
  what : String,
  file : String,
) -> @attribute.Attribute? raise {
  for attr in found {
    guard @attr.name_of(attr) is Some(n) && names.contains(n) else {
      let n = @attr.name_of(attr).unwrap_or("?")
      fail("\{at(attr, file)}: `#\{n}` does not go on \{what}")
    }
  }
  match found {
    [] => None
    [one] => Some(one)
    [_, second, ..] => fail("\{at(second, file)}: one `#rpc.*` per declaration")
  }
}

///|
/// A service: its proto name and the struct's attribute.
priv struct Service {
  name : String
  register : Array[String]
  methods : Array[String]
}

///|
/// The generated file, built up declaration by declaration.
priv struct Out {
  messages : Map[String, String]
  services : Map[String, Service]
  order : Array[String]
  mut pkg : String?
  impls : Array[String]
  descriptors : Array[String]
}

///|
/// A message's fully qualified name, as descriptors write it.
fn full_name(out : Out, proto : String) -> String {
  match out.pkg {
    Some(p) if p != "" => "." + p + "." + proto
    _ => "." + proto
  }
}

///|
/// A field number given as text, checked against the protobuf range.
fn number_of(text : String, where_ : String) -> Int32 raise {
  let n = @string.parse_int(text) catch {
    _ => fail("\{where_}: `number=\{quoted(text)}` is not a number")
  }
  if n < 1 || n > 536870911 {
    fail("\{where_}: field number \{n} is outside 1 to 536870911")
  }
  if n >= 19000 && n <= 19999 {
    fail("\{where_}: field numbers 19000 to 19999 are reserved by protobuf")
  }
  n
}

///|
/// A message's codec and descriptor.
fn message(
  out : Out,
  name : String,
  fields : Array[@gen.Field],
  public : Bool,
  where_ : String,
  file : String,
) -> Unit raise {
  let writes = []
  let locals = []
  let arms = []
  let builds = []
  let descriptors = []
  let numbers : Map[Int32, String] = Map([])
  let mut next = 1
  for field in fields {
    let attr = single(
      rpc_attrs(field.attrs, file),
      ["rpc.field", "rpc.skip"],
      "a field",
      file,
    )
    let at_field = match attr {
      Some(a) => at(a, file)
      None => where_
    }
    if attr is Some(a) && @attr.name_of(a) is Some("rpc.skip") {
      ignore(skip_spec.bind(a))
      builds.push("\{field.name}: Default::default()")
      continue
    }
    let args = match attr {
      Some(a) => Some(field_spec.bind(a))
      None => None
    }
    let n = match args {
      Some(a) =>
        match a.str("number") {
          Some(t) => number_of(t, at_field)
          None => next
        }
      None => next
    }
    if numbers.get(n) is Some(other) {
      fail(
        "\{at_field}: field `\{field.name}` takes number \{n}, already `\{other}`'s",
      )
    }
    numbers.set(n, field.name)
    next = n + 1
    guard field_of(field.ty, out.messages) is Some((base, card, elem)) else {
      fail(
        "\{at_field}: field `\{field.name}`: `\{field.ty}` has no protobuf type",
      )
    }
    let proto = match args {
      Some(a) => a.str("name").unwrap_or(field.name)
      None => field.name
    }
    let f = "self.\{field.name}"
    let v = "v_\{field.name}"
    let read = read_call(base, "r")
    let wire = wire_of(base)
    match card {
      Single => {
        writes.push(
          match base {
            Message(_) => write_call(base, n, f)
            _ => "if \{f} != \{zero_of(base)} { \{write_call(base, n, f)} }"
          },
        )
        locals.push("let \{v} : Ref[\{elem}] = Ref(\{zero_of(base)})")
        arms.push("(\{n}, \{wire}) => \{v}.val = \{read}")
      }
      Optional => {
        writes.push("if \{f} is Some(x) { \{write_call(base, n, "x")} }")
        locals.push("let \{v} : Ref[\{elem}?] = Ref(None)")
        arms.push("(\{n}, \{wire}) => \{v}.val = Some(\{read})")
      }
      Repeated => {
        if packed(base) {
          writes.push(
            (
              $|if !\{f}.is_empty() {
              $|  let p = @moonrpc.PbWriter::new()
              $|  for x in \{f} { \{packed_write(base, "x")} }
              $|  w.write_tag(\{n}, LengthDelim)
              $|  w.write_len_delim(p.to_bytes())
              $|}
            ),
          )
          arms.push(
            "(\{n}, LengthDelim) => { let sub = @moonrpc.PbReader::new(r.read_len_delim()); while !sub.eof() { \{v}.push(\{read_call(base, "sub")}) } }",
          )
        } else {
          writes.push("for x in \{f} { \{write_call(base, n, "x")} }")
        }
        locals.push("let \{v} : Array[\{elem}] = []")
        arms.push("(\{n}, \{wire}) => \{v}.push(\{read})")
      }
    }
    // `quote` renders through moonbitlang/parser's printer, which drops `mut`
    // from `let mut`, so the single fields are held in `Ref`s.
    builds.push(
      if card == Repeated {
        "\{field.name}: \{v}"
      } else {
        "\{field.name}: \{v}.val"
      },
    )
    let type_name = match base {
      Message(m) => full_name(out, out.messages[m])
      Scalar(_) => ""
    }
    let label = if card == Repeated { "LabelRepeated" } else { "LabelOptional" }
    descriptors.push(
      "{ name: \{quoted(proto)}, number: \{n}, label: \{label}, type_: \{field_type(base)}, type_name: \{quoted(type_name)} }",
    )
  }
  arms.push("(_, wire) => r.skip(wire)")
  let vis = if public { "pub " } else { "" }
  out.impls.push(
    (
      $|\{vis}impl @moonrpc.Message for \{name} with fn encode(self) {
      $|  let w = @moonrpc.PbWriter::new()
      $|  \{writes.join("\n")}
      $|  w.to_bytes()
      $|}
      $|
      $|\{vis}impl @moonrpc.Message for \{name} with fn decode(b) {
      $|  let r = @moonrpc.PbReader::new(b)
      $|  \{locals.join("\n")}
      $|  while !r.eof() {
      $|    match r.read_tag() {
      $|      \{arms.join("\n")}
      $|    }
      $|  }
      $|  \{name}::{ \{builds.join(", ")} }
      $|}
    ),
  )
  out.descriptors.push(
    "{ name: \{quoted(out.messages[name])}, fields: [\{descriptors.join(", ")}] }",
  )
}

///|
fn is_context(ty : String) -> Bool {
  ty is ("RpcContext" | "@moonrpc.RpcContext" | "@stream.RpcContext")
}

///|
/// One method of a service: its registration and its descriptor.
fn rpc_method(
  out : Out,
  service : Service,
  owner : String,
  attr : @attribute.Attribute,
  name : String,
  params : ArrayView[@gen.Param],
  returns : String?,
  file : String,
) -> Unit raise {
  let where_ = at(attr, file)
  let args = method_spec.bind(attr)
  let rpc_name = args.str("name").unwrap_or(pascal(name))
  guard params is [{ name: Some("self"), .. }, .. rest] else {
    fail("\{where_}: an RPC method takes `self` first")
  }
  let call = ["self"]
  let mut injected = false
  let mut request = None
  for param in rest {
    guard param.name is Some(p) &&
      param.ty is Some(ty) &&
      param.pass is Positional else {
      fail(
        "\{where_}: parameters after `self` are positional, with a name and a type",
      )
    }
    if is_context(ty) {
      injected = true
      call.push("ctx")
    } else if request is None {
      request = Some(ty)
      call.push("req")
    } else {
      fail("\{where_}: an RPC method takes one request, `\{p}` is a second")
    }
  }
  guard request is Some(req_ty) else {
    fail("\{where_}: an RPC method takes a request message")
  }
  guard field_of(req_ty, out.messages) is Some((Message(req), req_card, _)) &&
    req_card != Optional else {
    fail(
      "\{where_}: the request `\{req_ty}` is not a `#rpc.message` or an array of one",
    )
  }
  guard returns is Some(rep_ty) &&
    field_of(rep_ty, out.messages) is Some((Message(rep), rep_card, _)) &&
    rep_card != Optional else {
    fail("\{where_}: the reply is not a `#rpc.message` or an array of one")
  }
  let client_streaming = req_card == Repeated
  let server_streaming = rep_card == Repeated
  let builder = match (client_streaming, server_streaming) {
    (false, false) => "unary"
    (false, true) => "server_streaming"
    (true, false) => "client_streaming"
    (true, true) =>
      fail("\{where_}: bidirectional streaming is not generated yet")
  }
  let path = "/\{service.name}/\{rpc_name}"
  let ctx = if injected { "ctx" } else { "_ctx" }
  service.register.push(
    "server.register_handler(\{quoted(path)}, @moonrpc.\{builder}((\{ctx}, req : \{req_ty}) => \{owner}::\{name}(\{call.join(", ")})))",
  )
  service.methods.push(
    "{ name: \{quoted(rpc_name)}, input_type: \{quoted(full_name(out, out.messages[req]))}, output_type: \{quoted(full_name(out, out.messages[rep]))}, client_streaming: \{client_streaming}, server_streaming: \{server_streaming} }",
  )
}

///|
/// First pass: the messages and services, and the pkg they share.
fn collect(decls : Array[@gen.Decl], out : Out) -> Unit raise {
  for decl in decls {
    guard decl is Struct(name~, attrs~, file~, ..) else { continue }
    guard single(
        rpc_attrs(attrs, file),
        ["rpc.message", "rpc.service"],
        "a struct",
        file,
      )
      is Some(attr) else {
      continue
    }
    if @attr.name_of(attr) is Some("rpc.message") {
      let args = message_spec.bind(attr)
      out.messages.set(name, args.str("name").unwrap_or(name))
    } else {
      let args = service_spec.bind(attr)
      let full = args.str("name").unwrap_or(name)
      let pkg = match full.rev_find(".") {
        Some(i) => full.view(end_offset=i).to_owned()
        None => ""
      }
      match out.pkg {
        Some(p) if p != pkg =>
          fail(
            "\{at(attr, file)}: services in one file share a package; `\{pkg}` differs from `\{p}`",
          )
        _ => out.pkg = Some(pkg)
      }
      out.services.set(name, { name: full, register: [], methods: [], })
      out.order.push(name)
    }
  }
}

///|
impl @gen.Generator for Rpc with fn generate(_, decls) {
  let out : Out = {
    messages: Map([]),
    services: Map([]),
    order: [],
    pkg: None,
    impls: [],
    descriptors: [],
  }
  collect(decls, out)
  let mut source_file = "rpc.mbt"
  for decl in decls {
    match decl {
      Struct(name~, fields~, attrs~, public~, file~, ..) =>
        if out.messages.contains(name) {
          source_file = file
          let attr = rpc_attrs(attrs, file)[0]
          message(out, name, fields, public, at(attr, file), file)
        } else if out.services.contains(name) {
          source_file = file
        } else {
          for field in fields {
            if rpc_attrs(field.attrs, file) is [first, ..] {
              fail(
                "\{at(first, file)}: `\{name}` has no `#rpc.message`, so its fields take no `#rpc.*`",
              )
            }
          }
        }
      Func(owner~, name~, params~, returns~, attrs~, file~, ..) => {
        guard single(rpc_attrs(attrs, file), ["rpc.method"], "a function", file)
          is Some(attr) else {
          continue
        }
        guard owner is Some(ty) && out.services.get(ty) is Some(service) else {
          fail(
            "\{at(attr, file)}: `#rpc.method` goes on a method of a `#rpc.service`",
          )
        }
        rpc_method(out, service, ty, attr, name, params, returns, file)
      }
      Enum(attrs~, file~, ..) =>
        if rpc_attrs(attrs, file) is [first, ..] {
          fail("\{at(first, file)}: protobuf enums are not generated yet")
        }
      Other(..) => ()
    }
  }
  if out.messages.is_empty() && out.services.is_empty() {
    return @quote.join([])
  }
  let items = []
  let services = []
  for ty in out.order {
    let s = out.services[ty]
    let vis = if public_service(decls, ty) { "pub " } else { "" }
    items.push(
      (
        $|\{vis}fn[R : @moonrpc.Registrar] \{ty}::register(self : \{ty}, server : R) -> Unit {
        $|  \{s.register.join("\n")}
        $|}
      ),
    )
    let short = match s.name.rev_find(".") {
      Some(i) => s.name.view(start_offset=i + 1).to_owned()
      None => s.name
    }
    services.push(
      "{ name: \{quoted(short)}, methods: [\{s.methods.join(", ")}] }",
    )
  }
  let stem = source_file
    .view(
      end_offset=if source_file.has_suffix(".mbt") {
        source_file.length() - 4
      } else {
        source_file.length()
      },
    )
    .to_owned()
  let stem = match stem.rev_find("/") {
    Some(i) => stem.view(start_offset=i + 1).to_owned()
    None => stem
  }
  let pkg = out.pkg.unwrap_or("")
  items.push(
    (
      $|pub fn descriptor() -> @moonrpc.FileDescriptor {
      $|  @moonrpc.FileDescriptor::new(
      $|    \{quoted(stem + ".proto")},
      $|    \{quoted(pkg)},
      $|    messages=[\{out.descriptors.join(", ")}],
      $|    services=[\{services.join(", ")}],
      $|  )
      $|}
    ),
  )
  items.append(out.impls)
  @quote.items(items.join("\n\n")).render()
}

///|
fn public_service(decls : Array[@gen.Decl], ty : String) -> Bool {
  for decl in decls {
    if decl is Struct(name~, public~, ..) && name == ty {
      return public
    }
  }
  false
}
