// thriftc: a .thrift file in, MoonBit out.
//
//     thriftc [-C dir] file.thrift -o out.g.mbt [--check]
//
// `--check` writes nothing and fails when `out.g.mbt` is not what the input would
// produce, which is how CI keeps a generated file honest.

///|
fn usage(msg : String) -> Unit {
  println("thriftc: \{msg}")
  println("usage: [-C <dir>] <input.thrift> -o <output.g.mbt> [--check]")
  @env.exit(1)
}

///|
fn resolve(dir : String, path : String) -> String {
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
/// Read the file and everything it includes, once each. The link step is pure, so the
/// file system is read here instead, before it runs; a file that cannot be read is left
/// out and the link step names it.
async fn collect_sources(root : String, text : String) -> Map[String, String] {
  let sources : Map[String, String] = Map([])
  sources[root] = text
  let pending : Array[String] = [root]
  while pending.length() > 0 {
    let file = pending.pop().unwrap()
    let doc = parse(file, sources[file])
    for path in doc.includes {
      let resolved = join(dir_of(file), path)
      if sources.get(resolved) is None {
        match (Some(@fs.read_file(resolved)) catch { _ => None }) {
          Some(opened) => {
            sources[resolved] = opened.text()
            pending.push(resolved)
          }
          None => ()
        }
      }
    }
  }
  sources
}

///|
async fn main {
  let args = @env.args()
  let mut input = ""
  let mut output = ""
  let mut check = false
  let mut dir = ""
  let mut i = 1
  while i < args.length() {
    let arg = args[i]
    if arg == "-o" {
      if i + 1 >= args.length() {
        usage("-o needs a path")
      }
      output = args[i + 1]
      i = i + 2
    } else if arg == "-C" {
      if i + 1 >= args.length() {
        usage("-C needs a directory")
      }
      dir = args[i + 1]
      i = i + 2
    } else if arg == "--check" {
      check = true
      i = i + 1
    } else if arg.has_prefix("-") {
      usage("there is no option \{arg}")
    } else {
      if input != "" {
        usage("one input file at a time")
      }
      input = arg
      i = i + 1
    }
  }
  if input == "" {
    usage("no input file")
  }
  if output == "" {
    usage("-o is required")
  }
  let source_path = resolve(dir, input)
  let output_path = resolve(dir, output)
  let source = @fs.read_file(source_path) catch {
    _ => {
      println("thriftc: cannot read \{source_path}")
      @env.exit(1)
    }
  }
  let sources = collect_sources(source_path, source.text()) catch {
    e => {
      println("thriftc: \{e}")
      @env.exit(1)
    }
  }
  let rendered = render_with(source_path, source.text(), path => {
    sources.get(path)
  }) catch {
    e => {
      println("thriftc: \{e}")
      @env.exit(1)
    }
  }
  if check {
    let mut current = ""
    if @fs.exists(output_path) {
      let file = @fs.read_file(output_path)
      current = file.text()
    }
    let lf : (String) -> String = s => s.replace_all(old="\r\n", new="\n")
    if lf(current) != lf(rendered) {
      println("thriftc: \{output_path} is out of date with \{source_path}")
      @env.exit(1)
    }
  } else {
    @fs.write_file(output_path, rendered) catch {
      _ => {
        println("thriftc: cannot write \{output_path}")
        @env.exit(1)
      }
    }
    println("thriftc: wrote \{output_path}")
  }
}
