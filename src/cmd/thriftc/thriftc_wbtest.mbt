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
test "thriftc: a typedef is substituted where it is used, not emitted" {
  let code = render("t.thrift", "typedef i32 UserId\nstruct A { 1: UserId id }")
  assert_true(code.contains("id : Int32"))
  assert_false(code.contains("UserId"))
}

///|
test "thriftc: an alias of a container keeps the container" {
  let code = render(
    "t.thrift", "typedef map<string, list<i32>> Index\nstruct A { 1: Index rows }",
  )
  assert_true(code.contains("rows : Map[String, Array[Int32]]"))
  // The container helpers take the type they wrap, not the alias.
  assert_true(code.contains("pub fn read_map_string_list_i32"))
}

///|
test "thriftc: an alias chain collapses to the type at the end of it" {
  let code = render(
    "t.thrift", "typedef i32 A\ntypedef A B\nstruct S { 1: B b }",
  )
  assert_true(code.contains("b : Int32"))
}

///|
test "thriftc: an alias may name a type from an included file" {
  let files : Map[String, String] = Map([
    ("shared.thrift", "struct Stamp { 1: i64 at }"),
  ])
  let code = render_with(
    "main.thrift",
    "include \"shared.thrift\"\ntypedef shared.Stamp At\nstruct A { 1: At at }",
    loader(files),
  )
  assert_true(code.contains("at : SharedStamp"))
}

///|
test "thriftc: an included file's alias is reachable under its prefix" {
  let files : Map[String, String] = Map([
    ("shared.thrift", "typedef i32 UserId"),
  ])
  let code = render_with(
    "main.thrift",
    "include \"shared.thrift\"\nstruct A { 1: shared.UserId id }",
    loader(files),
  )
  assert_true(code.contains("id : Int32"))
  assert_false(code.contains("SharedUserId"))
}

///|
test "thriftc: an alias of itself is refused with the chain" {
  let raised = try {
    ignore(render("t.thrift", "typedef B A\ntypedef A B"))
    false
  } catch {
    Bad(msg~, ..) =>
      msg.contains("alias of itself") && msg.contains("A -> B -> A")
  }
  assert_true(raised)
}

///|
test "thriftc: an alias of an exception can be thrown" {
  let code = render(
    "t.thrift", "exception Missing { 1: string message }\ntypedef Missing Gone\nservice S { void go() throws (1: Gone g) }",
  )
  assert_true(code.contains("Missing(Missing)"))
  assert_false(code.contains("Gone"))
}

///|
test "thriftc: an alias does not get a struct past the map-key rule" {
  let raised = try {
    ignore(
      render(
        "t.thrift", "struct K { 1: string s }\ntypedef K Key\nstruct A { 1: map<Key, i32> m }",
      ),
    )
    false
  } catch {
    Bad(msg~, ..) => msg.contains("map key")
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

// ---------------------------------------------------------------- constants

///|
test "thriftc: a scalar constant becomes a let of its type" {
  let code = render(
    "c.thrift", "const i32 MAX = 130\nconst i64 BIG = 9000000000\nconst double PI = 3.14\nconst double WHOLE = 3\nconst string HI = \"hello\"\nconst bool YES = true\nconst binary RAW = \"ab\"",
  )
  assert_true(code.contains("pub let max : Int32 = 130"))
  assert_true(code.contains("pub let big : Int64 = 9000000000L"))
  assert_true(code.contains("pub let pi : Double = 3.14"))
  // An integer given to a double still needs the point MoonBit wants.
  assert_true(code.contains("pub let whole : Double = 3.0"))
  assert_true(code.contains("pub let hi : String = \"hello\""))
  assert_true(code.contains("pub let yes : Bool = true"))
  assert_true(code.contains("pub let raw : Bytes = b\"ab\""))
}

///|
test "thriftc: a double in exponent form still gets its point" {
  // `3e2` reads as 300, which MoonBit would take for an integer without the point.
  let code = render("c.thrift", "const double E = 3e2")
  assert_true(code.contains("pub let e : Double = 300.0"))
}

///|
test "thriftc: a constant's name takes the lower case MoonBit wants for a value" {
  // The three spellings of the same words land on one name, which is what makes a file
  // that uses two of them refused rather than silently different.
  let spelled = s => {
    render("c.thrift", s).contains("pub let maxAge : Int32 = 1")
  }
  assert_true(spelled("const i32 MAX_AGE = 1"))
  assert_true(spelled("const i32 max_age = 1"))
  assert_true(spelled("const i32 MaxAge = 1"))
  // A name that is already a word keeps it.
  assert_true(
    render("c.thrift", "const i32 done = 1").contains(
      "pub let done : Int32 = 1",
    ),
  )
}

///|
test "thriftc: two constants that would share a name are refused" {
  let raised = try {
    ignore(render("c.thrift", "const i32 MAX_AGE = 1\nconst i32 maxAge = 2"))
    false
  } catch {
    Bad(msg~, ..) => msg.contains("both written as `maxAge`")
  }
  assert_true(raised)
}

///|
test "thriftc: a list, a map and their empty forms are literals too" {
  let code = render(
    "c.thrift", "const list<i32> N = [1, 2]\nconst map<string, i32> M = { \"a\": 1 }\nconst list<i32> E = []\nconst map<string, i32> EM = {}",
  )
  assert_true(code.contains("pub let n : Array[Int32] = [1, 2]"))
  assert_true(
    code.contains("pub let m : Map[String, Int32] = Map([(\"a\", 1)])"),
  )
  assert_true(code.contains("pub let e : Array[Int32] = ([] : Array[Int32])"))
  assert_true(
    code.contains(
      "pub let em : Map[String, Int32] = (Map([]) : Map[String, Int32])",
    ),
  )
}

///|
test "thriftc: a struct constant fills what it leaves out" {
  let code = render(
    "c.thrift", "struct P { 1: string name, 2: optional i32 age, 3: bool ok }\nconst P ADA = { \"name\": \"Ada\" }",
  )
  // The field it names is set, the optional one stays None, the rest take defaults.
  assert_true(
    code.contains("pub let ada : P = { name: \"Ada\", age: None, ok: false }"),
  )
}

///|
test "thriftc: an enum constant names one of its values" {
  let code = render(
    "c.thrift", "enum Mood { Calm = 1, Happy = 2 }\nconst Mood D = Mood.Happy",
  )
  assert_true(code.contains("pub let d : Mood = Mood::Happy"))
}

///|
test "thriftc: a value that does not belong to its type is refused" {
  let raised = try {
    ignore(render("c.thrift", "const i32 X = \"text\""))
    false
  } catch {
    Bad(msg~, ..) => msg.contains("and the value it is given is not")
  }
  assert_true(raised)
}

///|
test "thriftc: a number too wide for its type is refused" {
  let raised = try {
    ignore(render("c.thrift", "const byte B = 999"))
    false
  } catch {
    Bad(msg~, ..) => msg.contains("does not fit")
  }
  assert_true(raised)
}

///|
test "thriftc: a field or an enum value that does not exist is refused" {
  let missing_field = try {
    ignore(
      render(
        "c.thrift", "struct P { 1: string name }\nconst P A = { \"age\": 1 }",
      ),
    )
    false
  } catch {
    Bad(msg~, ..) => msg.contains("has no field `age`")
  }
  assert_true(missing_field)
  let missing_value = try {
    ignore(render("c.thrift", "enum M { Calm = 1 }\nconst M D = M.Happy"))
    false
  } catch {
    Bad(msg~, ..) => msg.contains("has no value `Happy`")
  }
  assert_true(missing_value)
}

///|
test "thriftc: a constant cannot name another constant" {
  let raised = try {
    ignore(render("c.thrift", "const i32 A = 1\nconst i32 B = A"))
    false
  } catch {
    Bad(msg~, ..) => msg.contains("cannot name another constant")
  }
  assert_true(raised)
}

///|
test "thriftc: an included constant arrives under its prefix" {
  let files : Map[String, String] = Map([("shared.thrift", "const i32 MAX = 7")])
  let code = render_with(
    "main.thrift",
    "include \"shared.thrift\"",
    loader(files),
  )
  assert_true(code.contains("pub let sharedMax : Int32 = 7"))
}

// ---------------------------------------------------------------- unions

///|
test "thriftc: a union becomes an enum with a variant per field" {
  let code = render("u.thrift", "union C { 1: string email, 2: i64 phone }")
  assert_true(code.contains("pub(all) enum C {"))
  assert_true(code.contains("Email(String)"))
  assert_true(code.contains("Phone(Int64)"))
  assert_true(code.contains("pub fn C::default() -> C {"))
  // The first field's default is what an unset union is built from.
  assert_true(code.contains("Email(\"\")"))
  assert_true(code.contains("pub fn C::encode"))
  assert_true(code.contains("pub fn C::decode"))
  // Each variant writes its own field id, as a struct would.
  assert_true(code.contains("Phone(value) => {"))
  assert_true(code.contains("proto.write_field_begin(@thrift.type_i64, 2)"))
  assert_true(code.contains("2 => out = Some(Phone(proto.read_i64()))"))
}

///|
test "thriftc: a union with no field set is refused when it is read" {
  let code = render("u.thrift", "union C { 1: string email }")
  assert_true(code.contains("\"the union C carried no field\""))
}

///|
test "thriftc: a union with no fields is refused" {
  let raised = try {
    ignore(render("u.thrift", "union C { }"))
    false
  } catch {
    Bad(msg~, ..) => msg.contains("union with no fields")
  }
  assert_true(raised)
}

///|
test "thriftc: two union fields that would share a variant are refused" {
  let raised = try {
    ignore(render("u.thrift", "union C { 1: i32 n, 2: i32 N }"))
    false
  } catch {
    Bad(msg~, ..) => msg.contains("two fields written `N`")
  }
  assert_true(raised)
}

///|
test "thriftc: a struct field of a union type travels as a struct" {
  let code = render(
    "u.thrift", "union C { 1: string email }\nstruct S { 1: C contact }",
  )
  assert_true(code.contains("contact : C"))
  assert_true(code.contains("contact: C::default()"))
  assert_true(code.contains("proto.write_field_begin(@thrift.type_struct, 1)"))
  assert_true(code.contains("self.contact.encode(proto)"))
  assert_true(code.contains("contact = C::decode(proto)"))
}

///|
test "thriftc: `oneway` registers a method that answers nothing" {
  let code = render("o.thrift", "service S { oneway void ping(1: i32 n) }")
  // The processor has to know the method answers nothing, or the reply it writes stays in
  // the socket and every later reply is read by the wrong call.
  assert_true(code.contains("processor.add_oneway(\"ping\""))
  assert_true(
    code.contains(
      "@thrift.oneway_call(transport, proto, \"ping\", 1, proto => {",
    ),
  )
  assert_false(code.contains("@thrift.request(transport, proto, \"ping\""))
}

///|
test "thriftc: `oneway` on a method that returns a value is refused" {
  let raised = try {
    ignore(render("o.thrift", "service S { oneway i32 ping() }"))
    false
  } catch {
    Bad(msg~, ..) => msg.contains("has to return void")
  }
  assert_true(raised)
}

///|
test "thriftc: `oneway` on a method that throws is refused" {
  let raised = try {
    ignore(
      render(
        "o.thrift", "exception E { 1: string why }\nservice S { oneway void ping() throws (1: E e) }",
      ),
    )
    false
  } catch {
    Bad(msg~, ..) => msg.contains("cannot declare exceptions")
  }
  assert_true(raised)
}
