// The Thrift IDL compiler: a .thrift file in, the MoonBit types, their codecs, and
// the service's registration and client out. The subset it reads is the one this
// library can carry — struct, enum and service over the primitive types, lists, sets
// and maps. Anything else is refused with the line it came from, rather than silently
// dropped.

///|
pub(all) suberror Refused {
  Bad(file~ : String, line~ : Int32, msg~ : String)
}

///|
pub impl Show for Refused with fn output(self, logger) {
  match self {
    Bad(file~, line~, msg~) => logger.write_string("\{file}:\{line}: \{msg}")
  }
}

///|
pub extend Refused with Show::{to_string, output}

///|
fn[T] refuse(file : String, line : Int32, msg : String) -> T raise Refused {
  raise Bad(file~, line~, msg~)
}

// ---------------------------------------------------------------- the types

///|
/// One Thrift value type, as the IDL spells it.
pub(all) enum TType {
  Bool
  Byte
  I16
  I32
  I64
  Double
  Str
  Binary
  List(TType)
  Set(TType)
  Map(TType, TType)
  Named(String)
}

///|
pub(all) struct Field {
  id : Int32
  name : String
  ty : TType
  optional : Bool
}

///|
pub(all) struct Struct {
  name : String
  fields : Array[Field]
}

///|
pub(all) struct Enum {
  name : String
  values : Array[(String, Int32)]
}

///|
pub(all) struct Param {
  id : Int32
  name : String
  ty : TType
}

///|
pub(all) struct Function {
  name : String
  ret : TType?
  params : Array[Param]
}

///|
pub(all) struct Service {
  name : String
  base : String?
  functions : Array[Function]
}

///|
pub(all) struct Document {
  structs : Array[Struct]
  enums : Array[Enum]
  services : Array[Service]
  // The files this one includes, as written.
  includes : Array[String]
}

// ---------------------------------------------------------------- the lexer

///|
pub(all) enum Token {
  TIdent(String)
  TStr(String)
  TNum(Int32)
  TSym(Char)
  TEof
}

///|
fn is_ident_start(c : Char) -> Bool {
  c.is_ascii_alphabetic() || c == '_'
}

///|
fn is_ident_body(c : Char) -> Bool {
  c.is_ascii_alphabetic() || c.is_ascii_digit() || c == '_' || c == '.'
}

///|
fn lex(file : String, source : String) -> Array[(Token, Int32)] raise Refused {
  let out : Array[(Token, Int32)] = []
  let n = source.length()
  let mut i = 0
  let mut line = 1
  while i < n {
    let c = source.get_char(i).unwrap_or(' ')
    let next = source.get_char(i + 1)
    if c == '\n' {
      line = line + 1
      i = i + 1
    } else if c.is_ascii_whitespace() {
      i = i + 1
    } else if c == '/' && next == Some('/') {
      while i < n && source.get_char(i) != Some('\n') {
        i = i + 1
      }
    } else if c == '#' {
      while i < n && source.get_char(i) != Some('\n') {
        i = i + 1
      }
    } else if c == '/' && next == Some('*') {
      i = i + 2
      while i < n &&
            !(source.get_char(i) == Some('*') &&
            source.get_char(i + 1) == Some('/')) {
        if source.get_char(i) == Some('\n') {
          line = line + 1
        }
        i = i + 1
      }
      i = i + 2
    } else if is_ident_start(c) {
      let start = i
      while i < n && source.get_char(i) is Some(d) && is_ident_body(d) {
        i = i + 1
      }
      out.push((TIdent(source[start:i].to_owned()), line))
    } else if c.is_ascii_digit() || c == '-' {
      let start = i
      if c == '-' {
        i = i + 1
      }
      while i < n && source.get_char(i) is Some(d) && d.is_ascii_digit() {
        i = i + 1
      }
      let text = source[start:i].to_owned()
      let value = @string.parse_int(text[:]) catch {
        _ => refuse(file, line, "`\{text}` is not a number")
      }
      out.push((TNum(value), line))
    } else if c == '"' || c == '\'' {
      let quote = c
      let mut text = ""
      i = i + 1
      while i < n && source.get_char(i) != Some(quote) {
        text = text + source.get_char(i).unwrap_or(' ').to_string()
        i = i + 1
      }
      i = i + 1
      out.push((TStr(text), line))
    } else if c == '<' || c == '>' {
      out.push((TSym(c), line))
      i = i + 1
    } else if c.is_ascii_graphic() {
      out.push((TSym(c), line))
      i = i + 1
    } else {
      refuse(file, line, "unexpected character in the file")
    }
  }
  out.push((TEof, line))
  out
}

// ---------------------------------------------------------------- the parser

///|
struct Parser {
  file : String
  tokens : Array[(Token, Int32)]
  mut pos : Int32
}

///|
fn Parser::peek(self : Parser) -> Token {
  self.tokens[self.pos].0
}

///|
fn Parser::line(self : Parser) -> Int32 {
  self.tokens[self.pos].1
}

///|
fn Parser::at_end(self : Parser) -> Bool {
  self.peek() is TEof
}

///|
fn Parser::advance(self : Parser) -> Token {
  let token = self.peek()
  if self.pos < self.tokens.length() - 1 {
    self.pos = self.pos + 1
  }
  token
}

///|
fn Parser::eat(self : Parser, symbol : Char) -> Bool {
  if self.peek() is TSym(c) && c == symbol {
    ignore(self.advance())
    true
  } else {
    false
  }
}

///|
fn Parser::expect(self : Parser, symbol : Char) -> Unit raise Refused {
  if self.eat(symbol) {
    return
  }
  refuse(self.file, self.line(), "expected `\{symbol}`")
}

///|
fn Parser::expect_ident(self : Parser, what : String) -> String raise Refused {
  if self.peek() is TIdent(name) {
    ignore(self.advance())
    name
  } else {
    refuse(self.file, self.line(), "expected \{what}")
  }
}

///|
fn Parser::expect_num(self : Parser) -> Int32 raise Refused {
  if self.peek() is TNum(value) {
    ignore(self.advance())
    value
  } else {
    refuse(self.file, self.line(), "expected a number")
  }
}

///|
/// Skip a `( ... )` annotation without reading it: key-value hints for other
/// generators do not change the code this one writes.
fn Parser::skip_annotation(self : Parser) -> Unit raise Refused {
  if !self.eat('(') {
    return
  }
  let mut depth = 1
  while depth > 0 {
    match self.advance() {
      TSym(c) =>
        if c == '(' {
          depth = depth + 1
        } else if c == ')' {
          depth = depth - 1
        }
      TEof => refuse(self.file, self.line(), "an annotation is not closed")
      _ => ()
    }
  }
}

///|
fn Parser::parse_type(self : Parser) -> TType raise Refused {
  let name = match self.peek() {
    TIdent(name) => {
      ignore(self.advance())
      name
    }
    _ => refuse(self.file, self.line(), "expected a type")
  }
  let ty = match name {
    "bool" => Bool
    "byte" | "i8" => Byte
    "i16" => I16
    "i32" => I32
    "i64" => I64
    "double" => Double
    "string" => Str
    "binary" => Binary
    "list" => {
      self.expect('<')
      let inner = self.parse_type()
      self.expect('>')
      List(inner)
    }
    "set" => {
      self.expect('<')
      let inner = self.parse_type()
      self.expect('>')
      Set(inner)
    }
    "map" => {
      self.expect('<')
      let key = self.parse_type()
      self.expect(',')
      let value = self.parse_type()
      self.expect('>')
      Map(key, value)
    }
    "void" => refuse(self.file, self.line(), "`void` is only a return type")
    other => Named(other)
  }
  self.skip_annotation()
  ty
}

///|
fn Parser::parse_struct(self : Parser) -> Struct raise Refused {
  let name = self.expect_ident("a struct name")
  self.expect('{')
  let fields : Array[Field] = []
  while !self.eat('}') {
    if self.peek() is TEof {
      refuse(self.file, self.line(), "`struct \{name}` is not closed")
    }
    let id = self.expect_num()
    self.expect(':')
    let mut optional = false
    if self.peek() is TIdent("optional") {
      optional = true
      ignore(self.advance())
    } else if self.peek() is TIdent("required") {
      ignore(self.advance())
    }
    let ty = self.parse_type()
    let field_name = self.expect_ident("a field name")
    self.skip_annotation()
    if self.eat('=') {
      refuse(
        self.file,
        self.line(),
        "a field default is not supported; `\{field_name}` has one",
      )
    }
    ignore(self.eat(',') || self.eat(';'))
    fields.push({ id, name: field_name, ty, optional, })
  }
  self.skip_annotation()
  { name, fields, }
}

///|
fn Parser::parse_enum(self : Parser) -> Enum raise Refused {
  let name = self.expect_ident("an enum name")
  self.expect('{')
  let values : Array[(String, Int32)] = []
  let mut next = 0
  while !self.eat('}') {
    if self.peek() is TEof {
      refuse(self.file, self.line(), "`enum \{name}` is not closed")
    }
    let label = self.expect_ident("a value name")
    let value = if self.eat('=') { self.expect_num() } else { next }
    next = value + 1
    ignore(self.eat(',') || self.eat(';'))
    values.push((label, value))
  }
  self.skip_annotation()
  { name, values, }
}

///|
fn Parser::parse_function(self : Parser) -> Function raise Refused {
  let ret = if self.peek() is TIdent("void") {
    ignore(self.advance())
    None
  } else {
    Some(self.parse_type())
  }
  let name = self.expect_ident("a method name")
  self.expect('(')
  let params : Array[Param] = []
  while !self.eat(')') {
    if self.peek() is TEof {
      refuse(self.file, self.line(), "`\{name}` is not closed")
    }
    let id = self.expect_num()
    self.expect(':')
    let ty = self.parse_type()
    let param_name = self.expect_ident("a parameter name")
    ignore(self.eat(',') || self.eat(';'))
    params.push({ id, name: param_name, ty, })
  }
  if self.peek() is TIdent("throws") {
    refuse(
      self.file,
      self.line(),
      "`throws` is not supported; `\{name}` declares one",
    )
  }
  ignore(self.eat(',') || self.eat(';'))
  { name, ret, params, }
}

///|
fn Parser::parse_service(self : Parser) -> Service raise Refused {
  let name = self.expect_ident("a service name")
  let mut base = None
  if self.peek() is TIdent("extends") {
    ignore(self.advance())
    base = Some(self.expect_ident("the service it extends"))
  }
  self.expect('{')
  let functions : Array[Function] = []
  while !self.eat('}') {
    if self.peek() is TEof {
      refuse(self.file, self.line(), "`service \{name}` is not closed")
    }
    functions.push(self.parse_function())
  }
  self.skip_annotation()
  { name, base, functions, }
}

///|
fn Parser::parse_document(self : Parser) -> Document raise Refused {
  let structs : Array[Struct] = []
  let enums : Array[Enum] = []
  let services : Array[Service] = []
  let includes : Array[String] = []
  while !self.at_end() {
    match self.peek() {
      TIdent("namespace") => {
        ignore(self.advance())
        ignore(self.expect_ident("a namespace scope"))
        if self.peek() is TStr(_) {
          ignore(self.advance())
        } else if self.peek() is TIdent(_) {
          ignore(self.advance())
        }
        ignore(self.eat(';'))
      }
      TIdent("include") => {
        ignore(self.advance())
        if self.peek() is TStr(path) {
          ignore(self.advance())
          includes.push(path)
        } else {
          refuse(self.file, self.line(), "`include` needs a quoted file")
        }
        ignore(self.eat(';'))
      }
      TIdent("cpp_include") => {
        ignore(self.advance())
        if self.peek() is TStr(_) {
          ignore(self.advance())
        }
        ignore(self.eat(';'))
      }
      TIdent("struct") => {
        ignore(self.advance())
        structs.push(self.parse_struct())
      }
      TIdent("enum") => {
        ignore(self.advance())
        enums.push(self.parse_enum())
      }
      TIdent("service") => {
        ignore(self.advance())
        services.push(self.parse_service())
      }
      TIdent("typedef") =>
        refuse(
          self.file,
          self.line(),
          "`typedef` is not supported; spell the type out",
        )
      TIdent("const") =>
        refuse(self.file, self.line(), "`const` is not supported")
      TIdent("union") =>
        refuse(
          self.file,
          self.line(),
          "`union` is not supported; use a struct with optional fields",
        )
      TIdent("exception") =>
        refuse(
          self.file,
          self.line(),
          "`exception` is not supported; return a status instead",
        )
      TIdent(other) =>
        refuse(
          self.file,
          self.line(),
          "`\{other}` is not something this compiler reads",
        )
      TSym(c) =>
        refuse(
          self.file,
          self.line(),
          "unexpected `\{c}` at the top level of the file",
        )
      _ =>
        refuse(
          self.file,
          self.line(),
          "unexpected end of an item at the top level",
        )
    }
  }
  { structs, enums, services, includes, }
}

///|
/// Parse one file. The includes it names are collected, not read: folding them in is
/// `link`, which is where a `shared.Person` gets its name in the output.
pub fn parse(file : String, source : String) -> Document raise Refused {
  let parser : Parser = { file, tokens: lex(file, source), pos: 0, }
  parser.parse_document()
}
