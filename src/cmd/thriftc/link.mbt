// Linking: a file plus everything it includes, folded into one set of declarations.
//
// Thrift names a type from an included file by that file's basename — `shared.Person`.
// MoonBit has one namespace per package, so the link step gives each included file's
// types a prefix: `shared.Person` becomes `SharedPerson`. Names stay stable whatever
// order the includes are read in, and the wire format does not care either way.

///|
/// How an include is read: the path as written, resolved by the caller.
pub type Loader = (String) -> String?

///|
/// A document with its includes folded in.
pub(all) struct Linked {
  structs : Array[Struct]
  enums : Array[Enum]
  // The root file's services, with their base resolved.
  services : Array[Service]
  // Every service, the included ones too, by the name the output uses.
  by_service : Map[String, Service]
}

///|
fn split_dot(name : String) -> (String, String)? {
  for i in 0..<name.length() {
    if name.get_char(i) is Some('.') {
      return Some((name[0:i].to_owned(), name[i + 1:name.length()].to_owned()))
    }
  }
  None
}

///|
fn dir_of(path : String) -> String {
  let mut cut = -1
  for i in 0..<path.length() {
    if path.get_char(i) is Some(c) && (c == '/' || c == '\\') {
      cut = i
    }
  }
  if cut < 0 {
    ""
  } else {
    path[0:cut].to_owned()
  }
}

///|
fn basename(path : String) -> String {
  let dir = dir_of(path)
  if dir == "" {
    path
  } else {
    path[dir.length() + 1:path.length()].to_owned()
  }
}

///|
/// `shared.thrift` → `shared`, the prefix its types take.
fn include_prefix(path : String) -> String {
  let name = basename(path)
  match name.has_suffix(".thrift") {
    true => name[0:name.length() - 7].to_owned()
    false => name
  }
}

///|
fn join(dir : String, path : String) -> String {
  let absolute = path.has_prefix("/") ||
    path.has_prefix("\\") ||
    (path.length() > 1 && path.get_char(1) is Some(':'))
  if dir == "" || absolute {
    path
  } else {
    dir + "/" + path
  }
}

///|
fn capitalise(name : String) -> String {
  if name.length() == 0 {
    return name
  }
  let first = name.get_char(0).unwrap_or('a')
  first.to_ascii_uppercase().to_string() + name[1:name.length()].to_owned()
}

///|
/// The name a declaration takes in the output: prefixed files get `SharedPerson`, the
/// root file keeps `Person`.
fn global_name(prefix : String, name : String) -> String {
  if prefix == "" {
    name
  } else {
    capitalise(prefix) + capitalise(name)
  }
}

///|
struct Linker {
  load : Loader
  // Resolved path → prefix, so a file included twice is read once.
  seen : Map[String, String]
  // Prefix → resolved path, so two files with the same basename are refused.
  prefix_path : Map[String, String]
  structs : Array[Struct]
  enums : Array[Enum]
  // Every `typedef`, by the name the output would give it.
  aliases : Map[String, TType]
  // Their names in the order the files declare them, so a broken one is named the same
  // way on every run.
  alias_order : Array[String]
  // Every service, by the name the output uses, so `extends` can find its base.
  all : Map[String, Service]
  // The services of the file being compiled — the ones that get emitted.
  root : Array[Service]
}

///|
fn Linker::rename_type(
  self : Linker,
  ty : TType,
  file : String,
  prefix : String,
  locals : Array[String],
  includes : Array[String],
) -> TType raise Refused {
  ignore(self)
  match ty {
    Named(name) =>
      if locals.contains(name) {
        Named(global_name(prefix, name))
      } else {
        match split_dot(name) {
          Some((qualifier, rest)) =>
            if includes.contains(qualifier) {
              Named(global_name(qualifier, rest))
            } else {
              refuse(
                file,
                0,
                "`\{name}`: no `include` in this file brings in `\{qualifier}`",
              )
            }
          None => Named(name)
        }
      }
    List(inner) => List(self.rename_type(inner, file, prefix, locals, includes))
    Set(inner) => Set(self.rename_type(inner, file, prefix, locals, includes))
    Map(key, value) =>
      Map(
        self.rename_type(key, file, prefix, locals, includes),
        self.rename_type(value, file, prefix, locals, includes),
      )
    _ => ty
  }
}

///|
fn Linker::read(
  self : Linker,
  file : String,
  source : String,
  prefix : String,
) -> Unit raise Refused {
  let doc = parse(file, source)
  let locals = doc.structs.map(s => s.name)
  let names = doc.enums.map(e => e.name)
  let aliases = doc.typedefs.map(t => t.name)
  let declared = locals + names + aliases
  let includes = doc.includes.map(p => include_prefix(p))

  // Read the includes first: a reference into one needs that file to have been given
  // its prefix already.
  for path in doc.includes {
    let resolved = join(dir_of(file), path)
    let inc_prefix = include_prefix(path)
    let known = self.prefix_path.get(inc_prefix)
    match known {
      Some(other) if other != resolved =>
        refuse(
          file,
          0,
          "two included files are both named `\{basename(path)}`; rename one of them",
        )
      _ => ()
    }
    match self.seen.get(resolved) {
      Some(existing) if existing != inc_prefix =>
        refuse(file, 0, "`\{path}` is included twice under different names")
      Some(_) => ()
      None => {
        self.seen[resolved] = inc_prefix
        self.prefix_path[inc_prefix] = resolved
        match (self.load)(resolved) {
          Some(text) => self.read(resolved, text, inc_prefix)
          None =>
            refuse(
              file,
              0,
              "cannot read the included file `\{path}` (looked for \{resolved})",
            )
        }
      }
    }
  }

  for item in doc.structs {
    let fields = item.fields.map(f => {
      let ty = self.rename_type(f.ty, file, prefix, declared, includes)
      { id: f.id, name: f.name, ty, optional: f.optional, }
    })
    self.structs.push({
      name: global_name(prefix, item.name),
      fields,
      kind: item.kind,
    })
  }
  for item in doc.enums {
    self.enums.push({
      name: global_name(prefix, item.name),
      values: item.values,
    })
  }
  // An alias keeps a name here so a reference to it can be resolved later; the name is
  // substituted away before anything is generated.
  for item in doc.typedefs {
    let ty = self.rename_type(item.ty, file, prefix, declared, includes)
    let name = global_name(prefix, item.name)
    self.aliases[name] = ty
    self.alias_order.push(name)
  }
  for service in doc.services {
    let base = match service.base {
      Some(name) =>
        match split_dot(name) {
          Some((qualifier, rest)) =>
            if includes.contains(qualifier) {
              Some(global_name(qualifier, rest))
            } else {
              refuse(
                file,
                0,
                "`\{service.name}` extends `\{name}`, but no include brings in `\{qualifier}`",
              )
            }
          None => Some(global_name(prefix, name))
        }
      None => None
    }
    let functions = service.functions.map(f => {
      let params = f.params.map(p => {
        let ty = self.rename_type(p.ty, file, prefix, declared, includes)
        { id: p.id, name: p.name, ty, }
      })
      let ret = match f.ret {
        Some(ty) => Some(self.rename_type(ty, file, prefix, declared, includes))
        None => None
      }
      let exceptions = f.exceptions.map(x => {
        let ty = self.rename_type(x.ty, file, prefix, declared, includes)
        { id: x.id, name: x.name, ty, }
      })
      { name: f.name, ret, params, exceptions, }
    })
    let named = { name: global_name(prefix, service.name), base, functions, }
    self.all[named.name] = named
    if prefix == "" {
      self.root.push(named)
    }
  }
}

///|
/// Substitute aliases until a real type is reached. `stack` is the chain being expanded,
/// which is how an alias of itself is caught instead of looping.
fn expand(
  ty : TType,
  aliases : Map[String, TType],
  stack : Array[String],
  file : String,
) -> TType raise Refused {
  match ty {
    Named(name) =>
      match aliases.get(name) {
        Some(target) => {
          if stack.contains(name) {
            refuse(
              file,
              0,
              "`\{name}` is an alias of itself (\{stack.join(" -> ")} -> \{name})",
            )
          }
          stack.push(name)
          let out = expand(target, aliases, stack, file)
          ignore(stack.pop())
          out
        }
        None => Named(name)
      }
    List(inner) => List(expand(inner, aliases, stack, file))
    Set(inner) => Set(expand(inner, aliases, stack, file))
    Map(key, value) =>
      Map(
        expand(key, aliases, stack, file),
        expand(value, aliases, stack, file),
      )
    _ => ty
  }
}

///|
fn expand_function(
  func : Function,
  aliases : Map[String, TType],
  file : String,
) -> Function raise Refused {
  let params = func.params.map(p => {
    let ty = expand(p.ty, aliases, [], file)
    ({ id: p.id, name: p.name, ty, } : Param)
  })
  let ret = match func.ret {
    Some(ty) => Some(expand(ty, aliases, [], file))
    None => None
  }
  let exceptions = func.exceptions.map(x => {
    let ty = expand(x.ty, aliases, [], file)
    ({ id: x.id, name: x.name, ty, } : Param)
  })
  ({ name: func.name, ret, params, exceptions, } : Function)
}

///|
fn expand_service(
  service : Service,
  aliases : Map[String, TType],
  file : String,
) -> Service raise Refused {
  let functions = service.functions.map(f => expand_function(f, aliases, file))
  ({ name: service.name, base: service.base, functions, } : Service)
}

///|
/// Fold `file`'s includes into it. `load` is what reads an included file, so the
/// compiler itself stays free of a file system and a test can hand in a map.
pub fn link(
  file : String,
  source : String,
  load : Loader,
) -> Linked raise Refused {
  let linker : Linker = {
    load,
    seen: Map([]),
    prefix_path: Map([]),
    structs: [],
    enums: [],
    aliases: Map([]),
    alias_order: [],
    all: Map([]),
    root: [],
  }
  linker.seen[file] = ""
  linker.read(file, source, "")
  let aliases = linker.aliases
  // Expand every alias once, so one that loops is refused even if nothing uses it yet.
  for name in linker.alias_order {
    ignore(expand(Named(name), aliases, [], file))
  }
  let structs = linker.structs.map(s => {
    let fields = s.fields.map(f => {
      let ty = expand(f.ty, aliases, [], file)
      ({ id: f.id, name: f.name, ty, optional: f.optional, } : Field)
    })
    ({ name: s.name, kind: s.kind, fields, } : Struct)
  })
  let by_service : Map[String, Service] = Map([])
  for name, service in linker.all {
    by_service[name] = expand_service(service, aliases, file)
  }
  let services = linker.root.map(s => expand_service(s, aliases, file))
  { structs, enums: linker.enums, services, by_service, }
}
