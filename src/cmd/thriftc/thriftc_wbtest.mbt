// The compiler's own tests: what it reads, and what it refuses.

///|
let sample : String =
  #|// a comment
  #|namespace moon greet
  #|
  #|enum Mood { Calm = 1, Happy = 2 }
  #|
  #|struct Person {
  #|  1: required string name
  #|  2: optional i32 age
  #|  3: list<string> tags
  #|} (go.tag = "x")
  #|
  #|service Greeter {
  #|  string hello(1: Person who)
  #|  void notify(1: string text)
  #|}
  #|

///|
test "thriftc: a struct, an enum and a service come out as MoonBit" {
  let code = render("greet.thrift", sample)
  assert_true(code.contains("pub(all) enum Mood"))
  assert_true(code.contains("pub(all) struct Person"))
  assert_true(code.contains("name : String"))
  assert_true(code.contains("age : Option[Int32]"))
  assert_true(code.contains("tags : Array[String]"))
  assert_true(code.contains("pub fn Person::encode"))
  assert_true(code.contains("pub fn Person::decode"))
  assert_true(code.contains("pub fn register_greeter"))
  assert_true(
    code.contains("pub async fn[T : @thrift.Transport] greeter_hello"),
  )
}

///|
test "thriftc: a field id becomes the wire number, in both directions" {
  let code = render("greet.thrift", sample)
  assert_true(code.contains("proto.write_field_begin(@thrift.type_string, 1)"))
  assert_true(code.contains("1 => name = proto.read_string()"))
  assert_true(code.contains("2 => age = Some(proto.read_i32())"))
}

///|
test "thriftc: an unknown type is refused with the file name" {
  let raised = try {
    ignore(render("bad.thrift", "struct A { 1: Missing m }"))
    false
  } catch {
    Bad(file~, ..) => file.has_suffix("bad.thrift")
  }
  assert_true(raised)
}

///|
test "thriftc: a struct that contains itself by value is refused" {
  let raised = try {
    ignore(render("loop.thrift", "struct A { 1: A inner }"))
    false
  } catch {
    Bad(msg~, ..) => msg.contains("contains itself by value")
  }
  assert_true(raised)
}

///|
test "thriftc: the same struct in a list or an optional field is accepted" {
  let code = render(
    "ok.thrift", "struct A { 1: optional A parent, 2: list<A> children }",
  )
  assert_true(code.contains("parent : Option[A]"))
  assert_true(code.contains("children : Array[A]"))
}

///|
test "thriftc: `typedef` is refused, not silently dropped" {
  let raised = try {
    ignore(render("t.thrift", "typedef i32 UserId"))
    false
  } catch {
    Bad(msg~, ..) => msg.contains("typedef")
  }
  assert_true(raised)
}

///|
test "thriftc: a map keyed by a struct is refused" {
  let raised = try {
    ignore(
      render(
        "m.thrift", "struct K { 1: string s }\nstruct V { 1: map<K, i32> m }",
      ),
    )
    false
  } catch {
    Bad(msg~, ..) => msg.contains("map key")
  }
  assert_true(raised)
}

///|
test "thriftc: an annotation after a type is skipped, not read as a type" {
  let code = render("a.thrift", "struct A { 1: string (go.tag = \"x\") s }")
  assert_true(code.contains("s : String"))
}

///|
test "thriftc: a struct field of an enum type travels as a number" {
  let code = render(
    "e.thrift", "enum Mood { Calm = 1 }\nstruct A { 1: Mood mood }",
  )
  assert_true(code.contains("proto.write_field_begin(@thrift.type_i32, 1)"))
  assert_true(code.contains("mood = Mood::from_i32(proto.read_i32())"))
}

///|
test "thriftc: an enum keeps the numbers the file gives it" {
  let code = render("e.thrift", "enum Mood { Calm = 5, Happy }")
  assert_true(code.contains("Calm => 5"))
  // The next value follows the one before it, as Thrift does.
  assert_true(code.contains("Happy => 6"))
}

// ---------------------------------------------------------------- includes

///|
/// How many times `needle` occurs in `haystack`.
fn count_of(haystack : String, needle : String) -> Int32 {
  let mut count = 0
  let mut at = 0
  while at + needle.length() <= haystack.length() {
    if haystack[at:at + needle.length()].to_owned() == needle {
      count = count + 1
      at = at + needle.length()
    } else {
      at = at + 1
    }
  }
  count
}

///|
fn loader(files : Map[String, String]) -> Loader {
  path => files.get(path)
}

///|
test "thriftc: an included file's types are folded in under a prefix" {
  let files : Map[String, String] = Map([
    ("shared.thrift", "struct Stamp { 1: i64 at }"),
  ])
  let code = render_with(
    "main.thrift",
    "include \"shared.thrift\"\nstruct A { 1: shared.Stamp s }",
    loader(files),
  )
  assert_true(code.contains("pub(all) struct SharedStamp"))
  assert_true(code.contains("s : SharedStamp"))
  assert_true(code.contains("proto.write_field_begin(@thrift.type_struct, 1)"))
}

///|
test "thriftc: an include that cannot be read is refused with its path" {
  let raised = try {
    ignore(render("main.thrift", "include \"gone.thrift\""))
    false
  } catch {
    Bad(msg~, ..) => msg.contains("cannot read the included file")
  }
  assert_true(raised)
}

///|
test "thriftc: two included files with the same name are refused" {
  let files : Map[String, String] = Map([
    ("a/shared.thrift", "struct A { 1: i32 x }"),
    ("b/shared.thrift", "struct B { 1: i32 y }"),
  ])
  let raised = try {
    ignore(
      render_with(
        "main.thrift",
        "include \"a/shared.thrift\"\ninclude \"b/shared.thrift\"",
        loader(files),
      ),
    )
    false
  } catch {
    Bad(msg~, ..) => msg.contains("both named")
  }
  assert_true(raised)
}

///|
test "thriftc: a qualified name with no include is refused" {
  let raised = try {
    ignore(render("main.thrift", "struct A { 1: other.Thing t }"))
    false
  } catch {
    Bad(msg~, ..) => msg.contains("no `include` in this file brings in `other`")
  }
  assert_true(raised)
}

///|
test "thriftc: the same file included twice is read once" {
  let files : Map[String, String] = Map([
    ("shared.thrift", "struct Stamp { 1: i64 at }"),
  ])
  let code = render_with(
    "main.thrift",
    "include \"shared.thrift\"\ninclude \"shared.thrift\"\nstruct A { 1: shared.Stamp s }",
    loader(files),
  )
  assert_eq(count_of(code, "pub(all) struct SharedStamp"), 1)
}

// ---------------------------------------------------------------- extends

///|
test "thriftc: a derived service carries its base's methods" {
  let code = render(
    "s.thrift", "service Base { void ping() }\nservice Child extends Base { i32 add(1: i32 a, 2: i32 b) }",
  )
  // The child's registration takes its own method first, then the inherited one.
  assert_true(code.contains("  add : (Int32, Int32) -> Int32,"))
  assert_true(code.contains("  ping : () -> Unit,"))
  assert_true(code.contains("processor.add(\"ping\""))
  assert_true(code.contains("pub async fn[T : @thrift.Transport] child_ping"))
}

///|
test "thriftc: an inherited method is answered once, even if the child overrides it" {
  // The base lives in the include, so only the child is emitted and a doubled `ping`
  // would be the child registering it twice.
  let files : Map[String, String] = Map([
    ("base.thrift", "service Base { void ping() }"),
  ])
  let code = render_with(
    "main.thrift",
    "include \"base.thrift\"\nservice Child extends base.Base { void ping() }",
    loader(files),
  )
  assert_eq(count_of(code, "processor.add(\"ping\""), 1)
}

///|
test "thriftc: extending a service nobody declares is refused" {
  let raised = try {
    ignore(render("s.thrift", "service Child extends Missing { void ping() }"))
    false
  } catch {
    Bad(msg~, ..) => msg.contains("does not declare or include")
  }
  assert_true(raised)
}

///|
test "thriftc: a service can extend one from an included file" {
  let files : Map[String, String] = Map([
    ("base.thrift", "service Base { void ping() }"),
  ])
  let code = render_with(
    "main.thrift",
    "include \"base.thrift\"\nservice Child extends base.Base { void go() }",
    loader(files),
  )
  assert_true(code.contains("processor.add(\"go\""))
  assert_true(code.contains("processor.add(\"ping\""))
}

// ---------------------------------------------------------------- exceptions

///|
test "thriftc: an exception is a struct, named by a throws clause" {
  let code = render(
    "t.thrift", "exception Missing { 1: string message, 2: i32 code }\nservice S { string find(1: string key) throws (1: Missing missing) }",
  )
  assert_true(code.contains("pub(all) struct Missing"))
  assert_true(code.contains("pub(all) enum SFindError"))
  assert_true(code.contains("Missing(Missing)"))
  assert_true(code.contains("find : (String) -> Result[String, SFindError],"))
  // The failure goes out as a struct in the field its throws clause numbers.
  assert_true(code.contains("proto.write_field_begin(@thrift.type_struct, 1)"))
}

///|
test "thriftc: the client of a throwing method returns a Result, not a value" {
  let code = render(
    "t.thrift", "exception Missing { 1: string message }\nservice S { string find(1: string key) throws (1: Missing missing) }",
  )
  assert_true(code.contains("@thrift.call_result(transport, proto, \"find\""))
  assert_true(
    code.contains(") -> Result[String, SFindError] raise @thrift.ThriftError {"),
  )
  assert_true(code.contains("1 => Some(Missing(Missing::decode(proto)))"))
}

///|
test "thriftc: a void method that throws reads its empty result as success" {
  let code = render(
    "t.thrift", "exception Boom { 1: string message }\nservice S { void go(1: i32 n) throws (1: Boom boom) }",
  )
  assert_true(code.contains("@thrift.call_result_unit"))
  assert_true(code.contains("go : (Int32) -> Result[Unit, SGoError],"))
  assert_true(code.contains("Ok(_) => ()"))
}

///|
test "thriftc: a method without throws keeps its plain signature" {
  let code = render(
    "t.thrift", "exception Boom { 1: string message }\nservice S { i32 add(1: i32 a, 2: i32 b) }",
  )
  assert_true(code.contains("add : (Int32, Int32) -> Int32,"))
  assert_false(code.contains("SAddError"))
  assert_false(code.contains("call_result"))
}

///|
test "thriftc: throwing a struct is refused, and says why" {
  let raised = try {
    ignore(
      render(
        "t.thrift", "struct Plain { 1: string s }\nservice S { void go() throws (1: Plain p) }",
      ),
    )
    false
  } catch {
    Bad(msg~, ..) => msg.contains("which is a struct")
  }
  assert_true(raised)
}

///|
test "thriftc: throwing a name nobody declares is refused" {
  let raised = try {
    ignore(render("t.thrift", "service S { void go() throws (1: Gone g) }"))
    false
  } catch {
    Bad(msg~, ..) => msg.contains("not declared in this file")
  }
  assert_true(raised)
}

///|
test "thriftc: an exception from an included file is thrown under its prefix" {
  let files : Map[String, String] = Map([
    ("shared.thrift", "exception Missing { 1: string message }"),
  ])
  let code = render_with(
    "main.thrift",
    "include \"shared.thrift\"\nservice S { void go() throws (1: shared.Missing m) }",
    loader(files),
  )
  assert_true(code.contains("pub(all) enum SGoError"))
  assert_true(code.contains("SharedMissing(SharedMissing)"))
  assert_true(
    code.contains("1 => Some(SharedMissing(SharedMissing::decode(proto)))"),
  )
}
