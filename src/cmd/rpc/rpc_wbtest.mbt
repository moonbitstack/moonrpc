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
    code.contains(
      flat(
        "{ name: \"bee\", number: 10, label: LabelOptional, type_: TypeInt64, type_name: \"\" }",
      ),
    ),
  )
  assert_true(code.contains(flat("type_: TypeMessage, type_name: \".Req\"")))
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
      "#rpc.message\nstruct S {\n  a : Map[String, Int]\n}", "has no protobuf type",
    ),
    (
      "#rpc.message\nstruct S {\n  #rpc.field(type=\"int\")\n  a : Int\n}", "does not parse",
    ),
    (
      "#rpc.message\nstruct A { x : Int }\n#rpc.service\nstruct S {}\n#rpc.method\nfn S::m(self : S, req : Array[A]) -> Array[A] { ignore(self); req }",
      "bidirectional streaming is not generated yet",
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
    ("#rpc.message\nenum E { A }", "enums are not generated yet"),
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
