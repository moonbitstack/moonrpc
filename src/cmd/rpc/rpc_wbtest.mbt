///|
/// Code without spaces, line breaks or the trailing commas the printer adds when
/// it wraps a call, so a test can look for one call written on one line.
fn flat(code : String) -> String {
  let out = StringBuilder()
  for c in code {
    if c != ' ' && c != '\n' {
      out.write_char(c)
    }
  }
  out
  .to_string()
  .replace_all(old=",)", new=")")
  .replace_all(old=",]", new="]")
  .replace_all(old=",}", new="}")
}

///|
fn generate(source : String) -> String raise {
  flat(@gen.render(Rpc::{ }, [("svc.mbt", source)]))
}

///|
fn refused(source : String) -> String {
  try {
    ignore(generate(source))
    ""
  } catch {
    e => "\{e}"
  }
}

///|
test "fields are numbered in order, number= sets one and the count carries on" {
  let code = generate(
    (
      #|#rpc.message(name="Req")
      #|pub struct Request {
      #|  a : String
      #|  #rpc.field(number="10", name="bee")
      #|  b : Int64
      #|  c : Array[UInt]
      #|  d : Bytes?
      #|  #rpc.skip
      #|  e : Bool
      #|  f : Array[Request]
      #|}
    ),
  )
  assert_true(code.contains(flat("if self.a != \"\" { w.string_(1, self.a) }")))
  assert_true(code.contains(flat("if self.b != 0L { w.int64(10, self.b) }")))
  assert_true(code.contains(flat("p.write_varint(x.to_uint64())")))
  assert_true(code.contains(flat("w.write_tag(11, LengthDelim)")))
  assert_true(code.contains(flat("if self.d is Some(x) { w.bytes_(12, x) }")))
  assert_true(
    code.contains(
      flat("for x in self.f { w.message_(13, @moonrpc.Message::encode(x)) }"),
    ),
  )
  assert_true(code.contains(flat("(11, Varint) => v_c.push(r.read_uint32())")))
  assert_true(
    code.contains(flat("(12, LengthDelim) => v_d.val = Some(r.read_bytes())")),
  )
  assert_true(code.contains(flat("e: Default::default()")))
  assert_true(
    code.contains(flat("@moonrpc.FieldDescriptor::new(\"bee\", 10, TypeInt64)")),
  )
  assert_true(
    code.contains(
      flat(
        "@moonrpc.FieldDescriptor::new(\"d\", 12, TypeBytes, oneof_index=0, proto3_optional=true)",
      ),
    ),
  )
  assert_true(code.contains(flat("oneofs=[\"_d\"]")))
  assert_true(
    code.contains(
      flat(
        "@moonrpc.FieldDescriptor::new(\"f\", 13, TypeMessage, type_name=\".Req\", label=LabelRepeated)",
      ),
    ),
  )
  assert_true(code.contains(flat("pub impl @moonrpc.Message for Request")))
}

///|
test "a service registers each method by the shape of its types" {
  let code = generate(
    (
      #|#rpc.message
      #|struct A { x : Int }
      #|
      #|#rpc.service(name="pkg.sub.Svc")
      #|struct Svc {}
      #|
      #|#rpc.method
      #|fn Svc::get_one(self : Svc, ctx : RpcContext, req : A) -> A { ignore((self, ctx)); req }
      #|
      #|#rpc.method(name="Many")
      #|fn Svc::many(self : Svc, req : A) -> Array[A] { ignore(self); [req] }
      #|
      #|#rpc.method
      #|fn Svc::gather(self : Svc, req : Array[A]) -> A raise { ignore(self); req[0] }
    ),
  )
  assert_true(
    code.contains(
      flat(
        "server.register_handler(\"/pkg.sub.Svc/GetOne\", @moonrpc.unary((ctx, req : A) => Svc::get_one(self, ctx, req)))",
      ),
    ),
  )
  assert_true(
    code.contains(
      flat("@moonrpc.server_streaming((_ctx, req : A) => Svc::many(self, req))"),
    ),
  )
  assert_true(
    code.contains(flat("@moonrpc.client_streaming((_ctx, req : Array[A])")),
  )
  assert_true(
    code.contains(
      flat("fn[R : @moonrpc.Registrar] Svc::register(self : Svc, server : R)"),
    ),
  )
  assert_true(!code.contains(flat("pub fn[R")))
  assert_true(code.contains(flat("\"svc.proto\", \"pkg.sub\"")))
  assert_true(code.contains(flat("input_type: \".pkg.sub.A\"")))
  assert_true(code.contains(flat("{ name: \"Svc\", methods: [")))
  assert_true(
    code.contains(flat("client_streaming: true, server_streaming: false")),
  )
}

///|
test "names" {
  assert_eq(pascal("say_hello"), "SayHello")
  assert_eq(pascal("get"), "Get")
  assert_true(!generate("struct Plain { x : Int }").contains("descriptor"))
}

///|
test "mistakes are reported where they are written" {
  let cases = [
    (
      "#rpc.message\nstruct S {\n  #rpc.field(number=\"2\")\n  a : Int\n  #rpc.field(number=\"2\")\n  b : Int\n}",
      "field `b` takes number 2, already `a`'s",
    ),
    (
      "#rpc.message\nstruct S {\n  #rpc.field(number=\"19500\")\n  a : Int\n}", "reserved by protobuf",
    ),
    (
      "#rpc.message\nstruct S {\n  #rpc.field(number=\"x\")\n  a : Int\n}", "is not a number",
    ),
    (
      "#rpc.message\nstruct S {\n  #rpc.field(number=\"0\")\n  a : Int\n}", "outside 1 to 536870911",
    ),
    (
      "#rpc.message\nstruct S {\n  a : Map[Double, Int]\n}", "has no protobuf type",
    ),
    (
      "#rpc.message\nstruct S {\n  a : Map[String, Array[Int]]\n}", "has no protobuf type",
    ),
    (
      "#rpc.message\nstruct S {\n  #rpc.field(type=\"int\")\n  a : Int\n}", "does not parse",
    ),
    (
      "#rpc.service\nstruct S {}\n#rpc.method\nfn S::m(self : S, req : Int) -> Int { ignore(self); req }",
      "is not a `#rpc.message`",
    ),
    (
      "#rpc.message\nstruct A { x : Int }\n#rpc.service\nstruct S {}\n#rpc.method\nfn S::m(self : S) -> A { ignore(self); { x: 1 } }",
      "takes a request message",
    ),
    (
      "#rpc.message\nstruct A { x : Int }\n#rpc.service(name=\"a.S\")\nstruct S {}\n#rpc.service(name=\"b.T\")\nstruct T {}",
      "share a package",
    ),
    (
      "#rpc.message\nstruct A { x : Int }\n#rpc.method\nfn f(req : A) -> A { req }",
      "goes on a method of a `#rpc.service`",
    ),
    ("#rpc.message\nenum E { A }", "`#rpc.message` does not go on an enum"),
    ("#rpc.enum\nenum E { A = 1; B }", "first value is 0; `A` is 1"),
    (
      "#rpc.enum\nenum E {\n  A\n  #rpc.value(number=\"0\")\n  B\n}", "`B` takes number 0, already `A`'s",
    ),
    ("#rpc.enum\nenum E { A; B(String) }", "`E::B` carries a payload"),
    ("#rpc.enum\nenum E { A; B(Int); C(Int) }", "`E::C` carries a payload"),
    (
      "#rpc.enum\nenum E {\n  A = 0\n  #rpc.value(number=\"2\")\n  B = 1\n}", "`B` is tagged 1 but numbered 2",
    ),
    ("enum E {\n  #rpc.value(name=\"X\")\n  A\n}", "has no `#rpc.enum`"),
    (
      "#rpc.message(name=\"Outer.Inner\")\nstruct S { a : Int }", "`Outer.Inner` nests in `Outer`, which is no `#rpc.message` here",
    ),
    (
      "#rpc.message(name=\"X\")\nstruct A { a : Int }\n#rpc.enum(name=\"X\")\nenum B { Z }",
      "`X` is declared already",
    ),
    ("struct S {\n  #rpc.skip\n  a : Int\n}", "has no `#rpc.message`"),
  ]
  for c in cases {
    let (source, expected) = c
    let got = refused(source)
    if !got.contains(expected) {
      fail("\{expected} not in: \{got}")
    }
  }
}

///|
test "an enum is numbered by its tags, by number= or in order, and named after itself" {
  let code = generate(
    (
      #|#rpc.enum
      #|pub enum Status {
      #|  Draft = 0
      #|  InReview = 4
      #|  Done
      #|}
      #|
      #|#rpc.enum(name="Grade")
      #|enum Mark {
      #|  #rpc.value(name="UNMARKED")
      #|  None_
      #|  #rpc.value(number="10")
      #|  Top
      #|  Other(Int)
      #|}
      #|
      #|#rpc.message
      #|struct Paper {
      #|  status : Status
      #|  marks : Array[Mark]
      #|}
    ),
  )
  assert_true(
    code.contains(
      flat(
        "pub impl @moonrpc.Enum for Status with fn code(self) { match self { Draft => 0 InReview => 4 Done => 5 } }",
      ),
    ),
  )
  assert_true(code.contains(flat("4 => InReview 5 => Done _ => Draft")))
  assert_true(code.contains(flat("Other(n) => n")))
  assert_true(code.contains(flat("10 => Top n => Other(n)")))
  assert_true(
    code.contains(
      flat(
        "@moonrpc.EnumDescriptor::{ name: \"Status\", values: [{ name: \"STATUS_DRAFT\", number: 0 }, { name: \"STATUS_IN_REVIEW\", number: 4 }, { name: \"STATUS_DONE\", number: 5 }] }",
      ),
    ),
  )
  assert_true(code.contains(flat("{ name: \"UNMARKED\", number: 0 }")))
  assert_true(code.contains(flat("{ name: \"GRADE_TOP\", number: 10 }")))
  assert_true(
    code.contains(
      flat(
        "if @moonrpc.Enum::code(self.status) != 0 { w.enum_(1, @moonrpc.Enum::code(self.status)) }",
      ),
    ),
  )
  assert_true(
    code.contains(
      flat("@moonrpc.Enum::code(x).to_int64().reinterpret_as_uint64()"),
    ),
  )
  assert_true(
    code.contains(
      flat(
        "@moonrpc.FieldDescriptor::new(\"status\", 1, TypeEnum, type_name=\".Status\")",
      ),
    ),
  )
  assert_true(
    code.contains(flat("enums=[@moonrpc.EnumDescriptor::{ name: \"Status\"")),
  )
}

///|
test "a map field is written entry by entry and described with its entry type" {
  let code = generate(
    (
      #|#rpc.message
      #|struct Tally {
      #|  word_counts : Map[String, Int64]
      #|}
    ),
  )
  assert_true(
    code.contains(
      flat(
        "for k, x in self.word_counts { let entry = { let w = @moonrpc.PbWriter::new() w.string_(1, k) w.int64(2, x) w.to_bytes() } w.message_(1, entry) }",
      ),
    ),
  )
  assert_true(
    code.contains(flat("let v_word_counts : Map[String, Int64] = Map([])")),
  )
  assert_true(code.contains(flat("v_word_counts[k.val] = x.val")))
  assert_true(
    code.contains(
      flat(
        "nested=[@moonrpc.MessageDescriptor::new(\"WordCountsEntry\", [@moonrpc.FieldDescriptor::new(\"key\", 1, TypeString), @moonrpc.FieldDescriptor::new(\"value\", 2, TypeInt64)], map_entry=true)]",
      ),
    ),
  )
  assert_true(
    code.contains(
      flat(
        "@moonrpc.FieldDescriptor::new(\"word_counts\", 1, TypeMessage, type_name=\".Tally.WordCountsEntry\", label=LabelRepeated)",
      ),
    ),
  )
}

///|
test "a dotted name nests a message or an enum inside its parent" {
  let code = generate(
    (
      #|#rpc.message
      #|struct Book { page : Page; kind : Kind }
      #|
      #|#rpc.message(name="Book.Page")
      #|struct Page { n : Int }
      #|
      #|#rpc.enum(name="Book.Kind")
      #|enum Kind { Novel }
      #|
      #|#rpc.service(name="lib.Shelf")
      #|struct Shelf {}
    ),
  )
  assert_true(
    code.contains(
      flat(
        "messages=[@moonrpc.MessageDescriptor::new(\"Book\", [@moonrpc.FieldDescriptor::new(\"page\", 1, TypeMessage, type_name=\".lib.Book.Page\"), @moonrpc.FieldDescriptor::new(\"kind\", 2, TypeEnum, type_name=\".lib.Book.Kind\")], nested=[@moonrpc.MessageDescriptor::new(\"Page\"",
      ),
    ),
  )
  assert_true(
    code.contains(
      flat(
        "enums=[@moonrpc.EnumDescriptor::{ name: \"Kind\", values: [{ name: \"KIND_NOVEL\", number: 0 }] }]",
      ),
    ),
  )
  assert_true(
    !code.contains(
      flat(
        "enums=[@moonrpc.EnumDescriptor::{ name: \"Kind\", values: [{ name: \"KIND_NOVEL\", number: 0 }] }], services",
      ),
    ),
  )
}

///|
test "a bidirectional method and the client the service gets" {
  let code = generate(
    (
      #|#rpc.message
      #|pub struct A { x : Int }
      #|
      #|#rpc.service(name="p.Svc")
      #|pub struct Svc {}
      #|
      #|#rpc.method
      #|fn Svc::chat(self : Svc, lines : Array[A]) -> Array[A] { ignore(self); lines }
      #|
      #|#rpc.method
      #|fn Svc::get(self : Svc, one : A) -> A { ignore(self); one }
    ),
  )
  assert_true(
    code.contains(
      flat("@moonrpc.bidi((_ctx, req : Array[A]) => Svc::chat(self, req))"),
    ),
  )
  assert_true(
    code.contains(flat("client_streaming: true, server_streaming: true")),
  )
  assert_true(code.contains(flat("pub struct SvcClient[C] { channel : C }")))
  assert_true(
    code.contains(
      flat(
        "pub fn[C] SvcClient::new(channel : C) -> SvcClient[C] { { channel, } }",
      ),
    ),
  )
  assert_true(
    code.contains(
      flat(
        "pub async fn[C : @moonrpc.Caller] SvcClient::chat(self : SvcClient[C], lines : Array[A], metadata? : Array[@moonrpc.Header], timeout_millis? : Int32, retry? : @moonrpc.Retry) -> Array[A] { self.channel.invoke(\"/p.Svc/Chat\", lines.map(m => @moonrpc.Message::encode(m)), metadata.unwrap_or([]), timeout_millis, retry).replies() }",
      ),
    ),
  )
  assert_true(
    code.contains(
      flat(
        "self.channel.invoke(\"/p.Svc/Get\", [@moonrpc.Message::encode(one)], metadata.unwrap_or([]), timeout_millis, retry).reply()",
      ),
    ),
  )
}

///|
test "upper_snake splits words and acronyms" {
  assert_eq(upper_snake("Draft"), "DRAFT")
  assert_eq(upper_snake("InReview"), "IN_REVIEW")
  assert_eq(upper_snake("HTTPError"), "HTTP_ERROR")
  assert_eq(upper_snake("V2Beta"), "V2_BETA")
}
