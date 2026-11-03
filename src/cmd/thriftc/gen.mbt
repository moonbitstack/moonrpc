// Code generation: one pair of read/write functions per container type, the codecs of
// every struct, and each service's registration and client. A field is then a single
// line, whatever its type — the nesting lives in the helper, once.

///|
fn moon_type(ty : TType) -> String {
  match ty {
    Bool => "Bool"
    Byte | I16 | I32 => "Int32"
    I64 => "Int64"
    Double => "Double"
    Str => "String"
    Binary => "Bytes"
    List(inner) => "Array[\{moon_type(inner)}]"
    Set(inner) => "Array[\{moon_type(inner)}]"
    Map(key, value) => "Map[\{moon_type(key)}, \{moon_type(value)}]"
    Named(name) => name
  }
}

///|
fn wire_type(ty : TType, enums : Array[String]) -> String {
  match ty {
    Bool => "@thrift.type_bool"
    Byte => "@thrift.type_byte"
    I16 => "@thrift.type_i16"
    I32 => "@thrift.type_i32"
    I64 => "@thrift.type_i64"
    Double => "@thrift.type_double"
    Str | Binary => "@thrift.type_string"
    List(_) => "@thrift.type_list"
    Set(_) => "@thrift.type_set"
    Map(_, _) => "@thrift.type_map"
    Named(name) =>
      if enums.contains(name) {
        "@thrift.type_i32"
      } else {
        "@thrift.type_struct"
      }
  }
}

///|
fn mangle(ty : TType) -> String {
  match ty {
    Bool => "bool"
    Byte => "byte"
    I16 => "i16"
    I32 => "i32"
    I64 => "i64"
    Double => "double"
    Str => "string"
    Binary => "binary"
    List(inner) => "list_" + mangle(inner)
    Set(inner) => "set_" + mangle(inner)
    Map(key, value) => "map_" + mangle(key) + "_" + mangle(value)
    Named(name) => name
  }
}

///|
/// The statement that writes `expr`, whose type is `ty`, to `proto`.
fn write_of(ty : TType, expr : String, enums : Array[String]) -> String {
  match ty {
    Bool => "proto.write_bool(\{expr})"
    Byte => "proto.write_byte(\{expr})"
    I16 => "proto.write_i16(\{expr})"
    I32 => "proto.write_i32(\{expr})"
    I64 => "proto.write_i64(\{expr})"
    Double => "proto.write_double(\{expr})"
    Str => "proto.write_string(\{expr})"
    Binary => "proto.write_bytes(\{expr})"
    Named(name) =>
      if enums.contains(name) {
        "proto.write_i32(\{expr}.to_i32())"
      } else {
        "\{expr}.encode(proto)"
      }
    _ => "write_\{mangle(ty)}(proto, \{expr})"
  }
}

///|
/// The expression that reads one value of `ty` from `proto`.
fn read_of(ty : TType, enums : Array[String]) -> String {
  match ty {
    Bool => "proto.read_bool()"
    Byte => "proto.read_byte()"
    I16 => "proto.read_i16()"
    I32 => "proto.read_i32()"
    I64 => "proto.read_i64()"
    Double => "proto.read_double()"
    Str => "proto.read_string()"
    Binary => "proto.read_bytes()"
    Named(name) =>
      if enums.contains(name) {
        "\{name}::from_i32(proto.read_i32())"
      } else {
        "\{name}::decode(proto)"
      }
    _ => "read_\{mangle(ty)}(proto)"
  }
}

///|
fn default_of(ty : TType, enums : Array[Enum]) -> String {
  match ty {
    Bool => "false"
    Byte | I16 | I32 => "0"
    I64 => "0L"
    Double => "0.0"
    Str => "\"\""
    Binary => "b\"\""
    List(inner) => "([] : Array[\{moon_type(inner)}])"
    Set(inner) => "([] : Array[\{moon_type(inner)}])"
    Map(key, value) => "(Map([]) : Map[\{moon_type(key)}, \{moon_type(value)}])"
    Named(name) =>
      match find_enum(enums, name) {
        Some(e) =>
          if e.values.length() > 0 {
            "\{name}::\{e.values[0].0}"
          } else {
            "\{name}::from_i32(0)"
          }
        None => "\{name}::default()"
      }
  }
}

///|
fn find_enum(enums : Array[Enum], name : String) -> Enum? {
  for item in enums {
    if item.name == name {
      return Some(item)
    }
  }
  None
}

///|
/// The empty array or map a reader starts from.
fn empty_of(ty : TType) -> String {
  match ty {
    List(inner) => "([] : Array[\{moon_type(inner)}])"
    Set(inner) => "([] : Array[\{moon_type(inner)}])"
    Map(key, value) => "(Map([]) : Map[\{moon_type(key)}, \{moon_type(value)}])"
    _ => "?"
  }
}

///|
struct Emitter {
  out : Array[String]
}

///|
fn Emitter::line(self : Emitter, indent : Int32, text : String) -> Unit {
  let mut pad = ""
  for _ in 0..<indent {
    pad = pad + "  "
  }
  self.out.push(pad + text + "\n")
}

///|
fn Emitter::blank(self : Emitter) -> Unit {
  self.out.push("\n")
}

///|
fn Emitter::text(self : Emitter) -> String {
  self.out.join("")
}

// ---------------------------------------------------------------- containers

///|
fn walk_types(
  ty : TType,
  seen : Map[String, TType],
  order : Array[String],
) -> Unit {
  let add = () => {
    let key = mangle(ty)
    if seen.get(key) is None {
      seen[key] = ty
      order.push(key)
    }
  }
  match ty {
    List(inner) | Set(inner) => {
      walk_types(inner, seen, order)
      add()
    }
    Map(key, value) => {
      walk_types(key, seen, order)
      walk_types(value, seen, order)
      add()
    }
    _ => ()
  }
}

///|
/// Every container type reachable from the document, once each, sorted so the output
/// does not depend on the order the file happened to mention them in.
fn collect_containers(doc : Linked) -> Array[TType] {
  let seen : Map[String, TType] = Map([])
  let order : Array[String] = []
  for s in doc.structs {
    for f in s.fields {
      walk_types(f.ty, seen, order)
    }
  }
  for service in doc.services {
    for func in service.functions {
      for param in func.params {
        walk_types(param.ty, seen, order)
      }
      match func.ret {
        Some(ty) => walk_types(ty, seen, order)
        None => ()
      }
    }
  }
  order.sort()
  order.map(key => seen.get(key).unwrap())
}

///|
fn emit_container(e : Emitter, ty : TType, enums : Array[String]) -> Unit {
  let name = mangle(ty)
  let moon = moon_type(ty)
  match ty {
    List(inner) | Set(inner) => {
      e.line(
        0,
        "pub fn write_\{name}(proto : &@thrift.Protocol, value : \{moon}) -> Unit {",
      )
      e.line(
        1,
        "proto.write_list_begin(\{wire_type(ty, enums)}, value.length())",
      )
      e.line(1, "for item in value {")
      e.line(2, write_of(inner, "item", enums))
      e.line(1, "}")
      e.line(0, "}")
      e.blank()
      e.line(
        0,
        "pub fn read_\{name}(proto : &@thrift.Protocol) -> \{moon} raise @thrift.ThriftError {",
      )
      e.line(1, "let (elem_type, size) = proto.read_list_begin()")
      e.line(1, "ignore(elem_type)")
      e.line(1, "let out : \{moon} = \{empty_of(ty)}")
      e.line(1, "for _ in 0..<size {")
      e.line(2, "out.push(\{read_of(inner, enums)})")
      e.line(1, "}")
      e.line(1, "out")
      e.line(0, "}")
      e.blank()
    }
    Map(key, value) => {
      e.line(
        0,
        "pub fn write_\{name}(proto : &@thrift.Protocol, value : \{moon}) -> Unit {",
      )
      e.line(
        1,
        "proto.write_map_begin(\{wire_type(key, enums)}, \{wire_type(value, enums)}, value.length())",
      )
      e.line(1, "for key, item in value {")
      e.line(2, write_of(key, "key", enums))
      e.line(2, write_of(value, "item", enums))
      e.line(1, "}")
      e.line(0, "}")
      e.blank()
      e.line(
        0,
        "pub fn read_\{name}(proto : &@thrift.Protocol) -> \{moon} raise @thrift.ThriftError {",
      )
      e.line(1, "let (key_type, value_type, size) = proto.read_map_begin()")
      e.line(1, "ignore(key_type)")
      e.line(1, "ignore(value_type)")
      e.line(1, "let out : \{moon} = \{empty_of(ty)}")
      e.line(1, "for _ in 0..<size {")
      e.line(2, "let key = \{read_of(key, enums)}")
      e.line(2, "out[key] = \{read_of(value, enums)}")
      e.line(1, "}")
      e.line(1, "out")
      e.line(0, "}")
      e.blank()
    }
    _ => ()
  }
}

// ---------------------------------------------------------------- declarations

///|
fn emit_enum(e : Emitter, item : Enum) -> Unit {
  e.line(0, "pub(all) enum \{item.name} {")
  for value in item.values {
    e.line(1, "\{value.0}")
  }
  e.line(0, "}")
  e.blank()
  e.line(
    0,
    "pub impl Eq for \{item.name} with fn equal(self : \{item.name}, other : \{item.name}) -> Bool {",
  )
  e.line(1, "self.to_i32() == other.to_i32()")
  e.line(0, "}")
  e.blank()
  e.line(
    0,
    "pub impl Eq for \{item.name} with fn not_equal(self : \{item.name}, other : \{item.name}) -> Bool {",
  )
  e.line(1, "self.to_i32() != other.to_i32()")
  e.line(0, "}")
  e.blank()
  e.line(0, "pub fn \{item.name}::to_i32(self : \{item.name}) -> Int32 {")
  e.line(1, "match self {")
  for value in item.values {
    e.line(2, "\{value.0} => \{value.1}")
  }
  e.line(1, "}")
  e.line(0, "}")
  e.blank()
  e.line(
    0,
    "pub fn \{item.name}::from_i32(value : Int32) -> \{item.name} raise @thrift.ThriftError {",
  )
  e.line(1, "match value {")
  for value in item.values {
    e.line(2, "\{value.1} => \{value.0}")
  }
  e.line(2, "other => raise @thrift.BadType(other)")
  e.line(1, "}")
  e.line(0, "}")
  e.blank()
}

///|
fn emit_struct(e : Emitter, item : Struct, enums : Array[Enum]) -> Unit {
  let names = enums.map(x => x.name)
  e.line(0, "pub(all) struct \{item.name} {")
  for f in item.fields {
    let ty = if f.optional {
      "Option[\{moon_type(f.ty)}]"
    } else {
      moon_type(f.ty)
    }
    e.line(1, "\{f.name} : \{ty}")
  }
  e.line(0, "}")
  e.blank()

  e.line(0, "pub fn \{item.name}::default() -> \{item.name} {")
  e.line(1, "{")
  for f in item.fields {
    let value = if f.optional { "None" } else { default_of(f.ty, enums) }
    e.line(2, "\{f.name}: \{value},")
  }
  e.line(1, "}")
  e.line(0, "}")
  e.blank()

  e.line(
    0,
    "pub fn \{item.name}::encode(self : \{item.name}, proto : &@thrift.Protocol) -> Unit {",
  )
  e.line(1, "proto.write_struct_begin(\"\{item.name}\")")
  for f in item.fields {
    if f.optional {
      e.line(1, "match self.\{f.name} {")
      e.line(2, "Some(value) => {")
      e.line(3, "proto.write_field_begin(\{wire_type(f.ty, names)}, \{f.id})")
      e.line(3, write_of(f.ty, "value", names))
      e.line(2, "}")
      e.line(2, "None => ()")
      e.line(1, "}")
    } else {
      e.line(1, "proto.write_field_begin(\{wire_type(f.ty, names)}, \{f.id})")
      e.line(1, write_of(f.ty, "self.\{f.name}", names))
    }
  }
  e.line(1, "proto.write_field_stop()")
  e.line(1, "proto.write_struct_end()")
  e.line(0, "}")
  e.blank()

  e.line(
    0,
    "pub fn \{item.name}::decode(proto : &@thrift.Protocol) -> \{item.name} raise @thrift.ThriftError {",
  )
  for f in item.fields {
    let ty = if f.optional {
      "Option[\{moon_type(f.ty)}]"
    } else {
      moon_type(f.ty)
    }
    let value = if f.optional { "None" } else { default_of(f.ty, enums) }
    e.line(1, "let mut \{f.name} : \{ty} = \{value}")
  }
  e.line(1, "proto.read_struct_begin()")
  e.line(1, "for ;; {")
  e.line(2, "let (field_type, field_id) = proto.read_field_begin()")
  e.line(2, "if field_type == @thrift.type_stop {")
  e.line(3, "break")
  e.line(2, "}")
  e.line(2, "match field_id {")
  for f in item.fields {
    let value = if f.optional {
      "Some(\{read_of(f.ty, names)})"
    } else {
      read_of(f.ty, names)
    }
    e.line(3, "\{f.id} => \{f.name} = \{value}")
  }
  e.line(3, "_ => @thrift.skip(proto, field_type)")
  e.line(2, "}")
  e.line(1, "}")
  e.line(1, "proto.read_struct_end()")
  let fields = item.fields.map(f => f.name).join(", ")
  e.line(1, "{ \{fields}, }")
  e.line(0, "}")
  e.blank()
}

///|
fn has_method(methods : Array[Function], name : String) -> Bool {
  for func in methods {
    if func.name == name {
      return true
    }
  }
  false
}

///|
/// A service's methods, its own first and then its base's, so an overriding method
/// shadows the inherited one.
fn service_methods(
  service : Service,
  by_service : Map[String, Service],
  seen : Array[String],
  file : String,
) -> Array[Function] raise Refused {
  if seen.contains(service.name) {
    refuse(
      file,
      0,
      "`\{service.name}` extends itself through its bases (\{seen.join(" -> ")})",
    )
  }
  seen.push(service.name)
  let out : Array[Function] = []
  for func in service.functions {
    out.push(func)
  }
  match service.base {
    Some(base) =>
      match by_service.get(base) {
        Some(parent) =>
          for func in service_methods(parent, by_service, seen, file) {
            if !has_method(out, func.name) {
              out.push(func)
            }
          }
        None =>
          refuse(
            file,
            0,
            "`\{service.name}` extends `\{base}`, which this file does not declare or include",
          )
      }
    None => ()
  }
  ignore(seen.pop())
  out
}

///|
fn emit_service(
  e : Emitter,
  service : Service,
  enums : Array[Enum],
  methods : Array[Function],
) -> Unit {
  let prefix = lower_first(service.name)
  let names = enums.map(x => x.name)

  // The server side: one handler per method, registered under its wire name.
  e.line(0, "pub fn register_\{prefix}(")
  e.line(1, "processor : @thrift.Processor,")
  for func in methods {
    let params = func.params.map(p => moon_type(p.ty)).join(", ")
    let ret = match func.ret {
      Some(ty) => moon_type(ty)
      None => "Unit"
    }
    e.line(1, "\{func.name} : (\{params}) -> \{ret},")
  }
  e.line(0, ") -> Unit {")
  for func in methods {
    e.line(1, "processor.add(\"\{func.name}\", proto => {")
    for param in func.params {
      e.line(
        2,
        "let mut arg_\{param.name} : \{moon_type(param.ty)} = \{default_of(param.ty, enums)}",
      )
    }
    e.line(2, "for ;; {")
    if func.params.length() > 0 {
      e.line(3, "let (field_type, field_id) = proto.read_field_begin()")
    } else {
      e.line(3, "let (field_type, _) = proto.read_field_begin()")
    }
    e.line(3, "if field_type == @thrift.type_stop {")
    e.line(4, "break")
    e.line(3, "}")
    if func.params.length() > 0 {
      e.line(3, "match field_id {")
      for param in func.params {
        e.line(
          4,
          "\{param.id} => arg_\{param.name} = \{read_of(param.ty, names)}",
        )
      }
      e.line(4, "_ => @thrift.skip(proto, field_type)")
      e.line(3, "}")
    } else {
      e.line(3, "@thrift.skip(proto, field_type)")
    }
    e.line(2, "}")
    let args = func.params.map(p => "arg_" + p.name).join(", ")
    match func.ret {
      Some(ty) => {
        e.line(2, "let result = \{func.name}(\{args})")
        e.line(2, "proto.write_field_begin(\{wire_type(ty, names)}, 0)")
        e.line(2, write_of(ty, "result", names))
      }
      None => e.line(2, "\{func.name}(\{args})")
    }
    e.line(1, "})")
  }
  e.line(0, "}")
  e.blank()

  // The client side: one function per method, over any transport.
  for func in methods {
    let name = "\{prefix}_\{func.name}"
    let ret = match func.ret {
      Some(ty) => " -> \{moon_type(ty)}"
      None => " -> Unit"
    }
    e.line(0, "pub async fn[T : @thrift.Transport] \{name}(")
    e.line(1, "transport : T,")
    e.line(1, "proto : &@thrift.Protocol,")
    for param in func.params {
      e.line(1, "\{param.name} : \{moon_type(param.ty)},")
    }
    e.line(0, ")\{ret} raise @thrift.ThriftError {")
    let mut call = "@thrift"
    if func.ret is Some(_) {
      call = call + ".call"
    } else {
      call = call + ".request"
    }
    if func.params.length() == 0 {
      e.line(
        1,
        "\{call}(transport, proto, \"\{func.name}\", 1, _ => ()\{read_tail(func.ret, names)})",
      )
    } else {
      e.line(1, "\{call}(transport, proto, \"\{func.name}\", 1, proto => {")
      for param in func.params {
        e.line(
          2,
          "proto.write_field_begin(\{wire_type(param.ty, names)}, \{param.id})",
        )
        e.line(2, write_of(param.ty, param.name, names))
      }
      e.line(1, "}\{read_tail(func.ret, names)})")
    }
    e.line(0, "}")
    e.blank()
  }
}

///|
/// The `, proto => <read>` that closes a `@thrift.call`, empty for a method that returns
/// nothing.
fn read_tail(ret : TType?, enums : Array[String]) -> String {
  match ret {
    Some(ty) => ", proto => \{read_of(ty, enums)}"
    None => ""
  }
}

///|
fn lower_first(name : String) -> String {
  if name.length() == 0 {
    return name
  }
  let first = name.get_char(0).unwrap_or('a')
  first.to_ascii_lowercase().to_string() + name[1:].to_owned()
}

// ---------------------------------------------------------------- validation

///|
fn owner_of(doc : Linked) -> Map[String, Struct] {
  let owner : Map[String, Struct] = Map([])
  for s in doc.structs {
    owner[s.name] = s
  }
  owner
}

///|
/// A struct that contains itself by value has no default and no end to its codec.
/// Containers and `optional` fields break the chain, because their default is empty.
fn visit_cycle(
  name : String,
  owner : Map[String, Struct],
  done : Map[String, Bool],
  path : Array[String],
  file : String,
) -> Unit raise Refused {
  if done.get(name) is Some(_) {
    return
  }
  if path.contains(name) {
    let chain = path.join(" -> ")
    refuse(
      file,
      0,
      "`\{name}` contains itself by value (\{chain} -> \{name}); make the field optional or put it in a list",
    )
  }
  path.push(name)
  match owner.get(name) {
    Some(s) =>
      for f in s.fields {
        if !f.optional {
          if f.ty is Named(inner) && owner.get(inner) is Some(_) {
            visit_cycle(inner, owner, done, path, file)
          }
        }
      }
    None => ()
  }
  ignore(path.pop())
  done[name] = true
}

///|
fn check_cycles(doc : Linked, file : String) -> Unit raise Refused {
  let owner = owner_of(doc)
  let done : Map[String, Bool] = Map([])
  for s in doc.structs {
    visit_cycle(s.name, owner, done, [], file)
  }
}

///|
fn check_type(
  ty : TType,
  enums : Array[String],
  structs : Array[String],
  file : String,
) -> Unit raise Refused {
  match ty {
    Named(name) =>
      if !enums.contains(name) && !structs.contains(name) {
        refuse(
          file,
          0,
          "`\{name}` is not declared in this file or in anything it includes",
        )
      }
    List(inner) | Set(inner) => check_type(inner, enums, structs, file)
    Map(key, value) => {
      if key is Named(_) {
        refuse(
          file,
          0,
          "a map key must be a primitive or a string; `\{moon_type(key)}` is not",
        )
      }
      check_type(key, enums, structs, file)
      check_type(value, enums, structs, file)
    }
    _ => ()
  }
}

///|
fn check_names(doc : Linked, file : String) -> Unit raise Refused {
  let enums = doc.enums.map(e => e.name)
  let structs = doc.structs.map(s => s.name)
  for s in doc.structs {
    for f in s.fields {
      check_type(f.ty, enums, structs, file)
    }
  }
  for service in doc.services {
    for func in service.functions {
      for param in func.params {
        check_type(param.ty, enums, structs, file)
      }
      match func.ret {
        Some(ty) => check_type(ty, enums, structs, file)
        None => ()
      }
    }
  }
}

// ---------------------------------------------------------------- the file

///|
/// Render one .thrift file as MoonBit. A file with no includes needs no file system.
pub fn render(file : String, source : String) -> String raise Refused {
  render_with(file, source, _ => None)
}

///|
/// Render one .thrift file with its includes folded in. `load` reads an included file;
/// a loader that always answers `None` compiles a file that has no includes.
pub fn render_with(
  file : String,
  source : String,
  load : Loader,
) -> String raise Refused {
  let doc = link(file, source, load)
  check_names(doc, file)
  check_cycles(doc, file)
  let e : Emitter = { out: [], }
  e.line(0, "// Generated from \{base_name(file)} by thriftc. Do not edit.")
  e.line(
    0, "// The package importing this file needs `moonbitstack/moonrpc/thrift`.",
  )
  e.blank()
  for item in doc.enums {
    emit_enum(e, item)
  }
  for item in doc.structs {
    emit_struct(e, item, doc.enums)
  }
  for ty in collect_containers(doc) {
    emit_container(e, ty, doc.enums.map(x => x.name))
  }
  for service in doc.services {
    emit_service(
      e,
      service,
      doc.enums,
      service_methods(service, doc.by_service, [], file),
    )
  }
  e.text()
}

///|
fn base_name(path : String) -> String {
  let mut start = 0
  for i in 0..<path.length() {
    if path.get_char(i) is Some(c) && (c == '/' || c == '\\') {
      start = i + 1
    }
  }
  path[start:path.length()].to_owned()
}
