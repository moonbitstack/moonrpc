///|
/// `#rpc.message`, `#rpc.enum` and `#rpc.service` on types, `#rpc.field`／
/// `#rpc.skip` on fields, `#rpc.value` on enum constructors, `#rpc.method` on a
/// service's methods, turned into each message's `Message`, each enum's `Enum`,
/// each service's `register` and client, and the file's `descriptor()`.
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
let enum_spec : @attr.Spec = @attr.Spec::new("rpc.enum").optional("name", Str)

///|
let value_spec : @attr.Spec = @attr.Spec::new("rpc.value")
  .optional("number", Str)
  .optional("name", Str)

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
/// A service: its full proto name, whether its struct is public, and what the
/// generator writes for it.
priv struct Service {
  name : String
  public : Bool
  register : Array[String]
  methods : Array[String]
  calls : Array[String]
}

///|
/// What a message's descriptor is made of. It is assembled once every message
/// is known, so a nested one can go inside its parent.
priv struct Described {
  fields : Array[String]
  entries : Array[String]
  oneofs : Array[String]
}

///|
/// The generated file, built up declaration by declaration. `messages` and
/// `enums` map MoonBit names to proto names; `described` and `enum_descs` are
/// keyed by proto name, in the order of `message_order` and `enum_order`.
priv struct Out {
  messages : Map[String, String]
  enums : Map[String, String]
  services : Map[String, Service]
  order : Array[String]
  mut pkg : String?
  impls : Array[String]
  described : Map[String, Described]
  message_order : Array[String]
  enum_descs : Map[String, String]
  enum_order : Array[String]
}

///|
/// A message's or enum's fully qualified name, as descriptors write it.
fn full_name(out : Out, proto : String) -> String {
  match out.pkg {
    Some(p) if p != "" => "." + p + "." + proto
    _ => "." + proto
  }
}

///|
/// The fully qualified name of the message or enum a base refers to; empty for
/// a scalar.
fn composite_name(out : Out, base : Base) -> String {
  match base {
    Message(m) => full_name(out, out.messages[m])
    Enum(e) => full_name(out, out.enums[e])
    Scalar(_) => ""
  }
}

///|
/// `Outer` out of `Outer.Inner`, or `None` at the top of the file.
fn parent_of(proto : String) -> String? {
  match proto.rev_find(".") {
    Some(i) => Some(proto.view(end_offset=i).to_owned())
    None => None
  }
}

///|
fn simple_of(proto : String) -> String {
  match proto.rev_find(".") {
    Some(i) => proto.view(start_offset=i + 1).to_owned()
    None => proto
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
/// The `FieldDescriptor::new(...)` call for one field.
fn field_desc(
  name : String,
  number : Int32,
  base : Base,
  type_name : String,
  extra : Array[String],
) -> String {
  let parts = [quoted(name), "\{number}", field_type(base)]
  if type_name != "" {
    parts.push("type_name=\{quoted(type_name)}")
  }
  parts.append(extra)
  "@moonrpc.FieldDescriptor::new(\{parts.join(", ")})"
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
  let proto_name = out.messages[name]
  let writes = []
  let locals = []
  let arms = []
  let builds = []
  let described : Described = { fields: [], entries: [], oneofs: [], }
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
    guard field_of(field.ty, out.messages, out.enums)
      is Some((base, card, elem)) else {
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
    let type_name = composite_name(out, base)
    match card {
      Single => {
        writes.push(
          match nonzero(base, f) {
            Some(cond) => "if \{cond} { \{write_call(base, n, f)} }"
            None => write_call(base, n, f)
          },
        )
        locals.push("let \{v} : Ref[\{elem}] = Ref(\{zero_of(base)})")
        arms.push("(\{n}, \{wire}) => \{v}.val = \{read}")
        described.fields.push(field_desc(proto, n, base, type_name, []))
      }
      Optional => {
        writes.push("if \{f} is Some(x) { \{write_call(base, n, "x")} }")
        locals.push("let \{v} : Ref[\{elem}?] = Ref(None)")
        arms.push("(\{n}, \{wire}) => \{v}.val = Some(\{read})")
        described.fields.push(
          field_desc(proto, n, base, type_name, [
            "oneof_index=\{described.oneofs.length()}",
            "proto3_optional=true",
          ]),
        )
        described.oneofs.push(quoted("_" + proto))
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
        described.fields.push(
          field_desc(proto, n, base, type_name, ["label=LabelRepeated"]),
        )
      }
      Keyed(key, key_ty) => {
        let k = Base::Scalar(key)
        // Both halves of an entry are written even when zero, as protoc's
        // runtimes write them.
        writes.push(
          (
            $|for k, x in \{f} {
            $|  let entry = {
            $|    let w = @moonrpc.PbWriter::new()
            $|    \{write_call(k, 1, "k")}
            $|    \{write_call(base, 2, "x")}
            $|    w.to_bytes()
            $|  }
            $|  w.message_(\{n}, entry)
            $|}
          ),
        )
        locals.push("let \{v} : Map[\{key_ty}, \{elem}] = Map([])")
        arms.push(
          "(\{n}, LengthDelim) => { let e = @moonrpc.PbReader::new(r.read_len_delim()); let k : Ref[\{key_ty}] = Ref(\{zero_of(k)}); let x : Ref[\{elem}] = Ref(\{zero_of(base)}); while !e.eof() { match e.read_tag() { (1, \{wire_of(k)}) => k.val = \{read_call(k, "e")}; (2, \{wire}) => x.val = \{read_call(base, "e")}; (_, wire) => e.skip(wire) } }; \{v}[k.val] = x.val }",
        )
        let entry = pascal(proto) + "Entry"
        described.entries.push(
          "@moonrpc.MessageDescriptor::new(\{quoted(entry)}, [\{field_desc("key", 1, k, "", [])}, \{field_desc("value", 2, base, type_name, [])}], map_entry=true)",
        )
        described.fields.push(
          field_desc(
            proto,
            n,
            Message(""),
            full_name(out, proto_name) + "." + entry,
            ["label=LabelRepeated"],
          ),
        )
      }
    }
    // `quote` renders through moonbitlang/parser's printer, which drops `mut`
    // from `let mut`, so the single fields are held in `Ref`s.
    builds.push(
      if card is (Repeated | Keyed(_, _)) {
        "\{field.name}: \{v}"
      } else {
        "\{field.name}: \{v}.val"
      },
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
  out.described[proto_name] = described
}

///|
/// The number `#rpc.value(number=...)` or a MoonBit tag gives a constructor.
fn enum_number(text : String, where_ : String) -> Int32 raise {
  @string.parse_int(text) catch {
    _ => fail("\{where_}: `\{text}` is not an enum number")
  }
}

///|
/// An enum's `Enum` and descriptor. A constructor without payload is a value;
/// one holding an `Int` takes the numbers the enum does not know.
fn enumeration(
  out : Out,
  name : String,
  raw : @syntax.Impl,
  public : Bool,
  where_ : String,
  file : String,
) -> Unit raise {
  let proto_name = out.enums[name]
  guard raw is TopTypeDef({ components: Variant(constrs), .. }) else {
    fail("\{where_}: `#rpc.enum` goes on an enum")
  }
  let values = []
  let mut carrier = None
  let numbers : Map[Int32, String] = Map([])
  let mut next = 0
  for c in constrs {
    let ctor = c.name.name
    let attr = single(
      rpc_attrs(c.attrs, file),
      ["rpc.value"],
      "a constructor",
      file,
    )
    if c.args is Some(params) {
      guard params.to_array()
        is [
          {
            ty: Name(constr_id={ id: Ident(name="Int" | "Int32"), .. }, ..),
            ..
          },
        ] &&
        attr is None &&
        carrier is None else {
        fail(
          "\{where_}: `\{name}::\{ctor}` carries a payload; one constructor may, holding an `Int` for the numbers the enum does not know",
        )
      }
      carrier = Some(ctor)
      continue
    }
    let here = match attr {
      Some(a) => at(a, file)
      None => where_
    }
    let args = match attr {
      Some(a) => Some(value_spec.bind(a))
      None => None
    }
    let given = match args.bind(a => a.str("number")) {
      Some(t) => Some(enum_number(t, here))
      None => None
    }
    let tagged = match c.tag {
      Some((t, _)) => Some(enum_number(t, here))
      None => None
    }
    let n = match (tagged, given) {
      (Some(t), Some(g)) if t != g =>
        fail("\{here}: `\{ctor}` is tagged \{t} but numbered \{g}")
      (Some(t), _) => t
      (None, Some(g)) => g
      (None, None) => next
    }
    if values.is_empty() && n != 0 {
      fail("\{here}: a proto3 enum's first value is 0; `\{ctor}` is \{n}")
    }
    if numbers.get(n) is Some(other) {
      fail("\{here}: `\{ctor}` takes number \{n}, already `\{other}`'s")
    }
    numbers[n] = ctor
    next = n + 1
    let value_name = args
      .bind(a => a.str("name"))
      .unwrap_or(upper_snake(simple_of(proto_name)) + "_" + upper_snake(ctor))
    values.push((ctor, value_name, n))
  }
  guard values is [(first, _, _), ..] else {
    fail("\{where_}: `\{name}` has no value")
  }
  let codes = values.map(v => "\{v.0} => \{v.2}")
  let ofs = values.map(v => "\{v.2} => \{v.0}")
  match carrier {
    Some(k) => {
      codes.push("\{k}(n) => n")
      ofs.push("n => \{k}(n)")
    }
    None => ofs.push("_ => \{first}")
  }
  let vis = if public { "pub " } else { "" }
  out.impls.push(
    (
      $|\{vis}impl @moonrpc.Enum for \{name} with fn code(self) {
      $|  match self {
      $|    \{codes.join("\n")}
      $|  }
      $|}
      $|
      $|\{vis}impl @moonrpc.Enum for \{name} with fn of(n) {
      $|  match n {
      $|    \{ofs.join("\n")}
      $|  }
      $|}
    ),
  )
  let described = values.map(v => "{ name: \{quoted(v.1)}, number: \{v.2} }")
  out.enum_descs[proto_name] = "@moonrpc.EnumDescriptor::{ name: \{quoted(simple_of(proto_name))}, values: [\{described.join(", ")}] }"
}

///|
fn is_context(ty : String) -> Bool {
  ty is ("RpcContext" | "@moonrpc.RpcContext" | "@stream.RpcContext")
}

///|
/// One method of a service: its registration, its descriptor, and its call on
/// the service's client.
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
      request = Some((p, ty))
      call.push("req")
    } else {
      fail("\{where_}: an RPC method takes one request, `\{p}` is a second")
    }
  }
  guard request is Some((req_name, req_ty)) else {
    fail("\{where_}: an RPC method takes a request message")
  }
  guard field_of(req_ty, out.messages, out.enums)
    is Some((Message(req), req_card, _)) &&
    req_card is (Single | Repeated) else {
    fail(
      "\{where_}: the request `\{req_ty}` is not a `#rpc.message` or an array of one",
    )
  }
  guard returns is Some(rep_ty) &&
    field_of(rep_ty, out.messages, out.enums)
    is Some((Message(rep), rep_card, _)) &&
    rep_card is (Single | Repeated) else {
    fail("\{where_}: the reply is not a `#rpc.message` or an array of one")
  }
  let client_streaming = req_card == Repeated
  let server_streaming = rep_card == Repeated
  let builder = match (client_streaming, server_streaming) {
    (false, false) => "unary"
    (false, true) => "server_streaming"
    (true, false) => "client_streaming"
    (true, true) => "bidi"
  }
  let path = "/\{service.name}/\{rpc_name}"
  let ctx = if injected { "ctx" } else { "_ctx" }
  service.register.push(
    "server.register_handler(\{quoted(path)}, @moonrpc.\{builder}((\{ctx}, req : \{req_ty}) => \{owner}::\{name}(\{call.join(", ")})))",
  )
  service.methods.push(
    "{ name: \{quoted(rpc_name)}, input_type: \{quoted(full_name(out, out.messages[req]))}, output_type: \{quoted(full_name(out, out.messages[rep]))}, client_streaming: \{client_streaming}, server_streaming: \{server_streaming} }",
  )
  let requests = if client_streaming {
    "\{req_name}.map(m => @moonrpc.Message::encode(m))"
  } else {
    "[@moonrpc.Message::encode(\{req_name})]"
  }
  let take = if server_streaming { "replies" } else { "reply" }
  let vis = if service.public { "pub " } else { "" }
  service.calls.push(
    (
      $|\{vis}async fn[C : @moonrpc.Caller] \{owner}Client::\{name}(
      $|  self : \{owner}Client[C],
      $|  \{req_name} : \{req_ty},
      $|  metadata? : Array[@moonrpc.Header],
      $|  timeout_millis? : Int32,
      $|  retry? : @moonrpc.Retry,
      $|) -> \{rep_ty} {
      $|  self.channel.invoke(\{quoted(path)}, \{requests}, metadata.unwrap_or([]), timeout_millis, retry).\{take}()
      $|}
    ),
  )
}

///|
/// First pass: the messages, enums and services, and the package they share.
/// A dotted `name=` must nest in a message of the same file.
fn collect(decls : Array[@gen.Decl], out : Out) -> Unit raise {
  let places : Map[String, String] = Map([])
  let claim = (proto : String, where_ : String) => {
    if places.get(proto) is Some(first) {
      fail("\{where_}: `\{proto}` is declared already, at \{first}")
    }
    places[proto] = where_
  }
  for decl in decls {
    match decl {
      Struct(name~, attrs~, public~, file~, ..) => {
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
          let proto = message_spec.bind(attr).str("name").unwrap_or(name)
          claim(proto, at(attr, file))
          out.messages.set(name, proto)
          out.message_order.push(proto)
        } else {
          let full = service_spec.bind(attr).str("name").unwrap_or(name)
          let pkg = parent_of(full).unwrap_or("")
          match out.pkg {
            Some(p) if p != pkg =>
              fail(
                "\{at(attr, file)}: services in one file share a package; `\{pkg}` differs from `\{p}`",
              )
            _ => out.pkg = Some(pkg)
          }
          out.services.set(name, {
            name: full,
            public,
            register: [],
            methods: [],
            calls: [],
          })
          out.order.push(name)
        }
      }
      Enum(name~, attrs~, file~, ..) => {
        guard single(rpc_attrs(attrs, file), ["rpc.enum"], "an enum", file)
          is Some(attr) else {
          continue
        }
        let proto = enum_spec.bind(attr).str("name").unwrap_or(name)
        claim(proto, at(attr, file))
        out.enums.set(name, proto)
        out.enum_order.push(proto)
      }
      _ => ()
    }
  }
  for proto, where_ in places {
    if parent_of(proto) is Some(parent) && !out.message_order.contains(parent) {
      fail(
        "\{where_}: `\{proto}` nests in `\{parent}`, which is no `#rpc.message` here",
      )
    }
  }
}

///|
/// A message's descriptor, with the map entries, messages and enums nested in
/// it.
fn described(out : Out, proto : String) -> String {
  let d = out.described[proto]
  let nested = d.entries.copy()
  for m in out.message_order {
    if parent_of(m) == Some(proto) {
      nested.push(described(out, m))
    }
  }
  let enums = []
  for e in out.enum_order {
    if parent_of(e) == Some(proto) {
      enums.push(out.enum_descs[e])
    }
  }
  let parts = [quoted(simple_of(proto)), "[\{d.fields.join(", ")}]"]
  if !nested.is_empty() {
    parts.push("nested=[\{nested.join(", ")}]")
  }
  if !enums.is_empty() {
    parts.push("enums=[\{enums.join(", ")}]")
  }
  if !d.oneofs.is_empty() {
    parts.push("oneofs=[\{d.oneofs.join(", ")}]")
  }
  "@moonrpc.MessageDescriptor::new(\{parts.join(", ")})"
}

///|
impl @gen.Generator for Rpc with fn generate(_, decls) {
  let out : Out = {
    messages: Map([]),
    enums: Map([]),
    services: Map([]),
    order: [],
    pkg: None,
    impls: [],
    described: Map([]),
    message_order: [],
    enum_descs: Map([]),
    enum_order: [],
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
      Enum(name~, attrs~, public~, file~, raw~, ..) =>
        if out.enums.contains(name) {
          source_file = file
          let attr = rpc_attrs(attrs, file)[0]
          enumeration(out, name, raw, public, at(attr, file), file)
        } else if raw is TopTypeDef({ components: Variant(constrs), .. }) {
          for c in constrs {
            if rpc_attrs(c.attrs, file) is [first, ..] {
              fail(
                "\{at(first, file)}: `\{name}` has no `#rpc.enum`, so its constructors take no `#rpc.*`",
              )
            }
          }
        }
      Other(..) => ()
    }
  }
  if out.messages.is_empty() && out.enums.is_empty() && out.services.is_empty() {
    return @quote.join([])
  }
  let items = []
  let services = []
  for ty in out.order {
    let s = out.services[ty]
    let vis = if s.public { "pub " } else { "" }
    items.push(
      (
        $|\{vis}fn[R : @moonrpc.Registrar] \{ty}::register(self : \{ty}, server : R) -> Unit {
        $|  \{s.register.join("\n")}
        $|}
        $|
        $|\{vis}struct \{ty}Client[C] {
        $|  channel : C
        $|}
        $|
        $|\{vis}fn[C] \{ty}Client::new(channel : C) -> \{ty}Client[C] {
        $|  { channel, }
        $|}
      ),
    )
    items.append(s.calls)
    services.push(
      "{ name: \{quoted(simple_of(s.name))}, methods: [\{s.methods.join(", ")}] }",
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
  let messages = out.message_order
    .filter(m => parent_of(m) is None)
    .map(m => described(out, m))
  let enums = out.enum_order
    .filter(e => parent_of(e) is None)
    .map(e => out.enum_descs[e])
  let parts = [quoted(stem + ".proto"), quoted(out.pkg.unwrap_or(""))]
  if !messages.is_empty() {
    parts.push("messages=[\{messages.join(", ")}]")
  }
  if !enums.is_empty() {
    parts.push("enums=[\{enums.join(", ")}]")
  }
  if !services.is_empty() {
    parts.push("services=[\{services.join(", ")}]")
  }
  items.push(
    (
      $|pub fn descriptor() -> @moonrpc.FileDescriptor {
      $|  @moonrpc.FileDescriptor::new(\{parts.join(", ")})
      $|}
    ),
  )
  items.append(out.impls)
  @quote.items(items.join("\n\n")).render()
}
