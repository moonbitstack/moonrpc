// A Thrift service over TBinaryProtocol and TFramedTransport.
//
//     thriftd [port]          serve on 127.0.0.1 (default 9090)
//     thriftd check [port]    call it with the same library and print the answers

///|
fn processor() -> @thrift.Processor {
  let processor = @thrift.Processor::new()
  processor.add("ping", (reader, writer) => {
    let (_, _) = reader.read_field_begin()
    let text = reader.read_string()
    ignore(reader.read_field_begin())
    writer.write_field_begin(@thrift.type_string, 0)
    writer.write_string("pong:" + text)
  })
  processor.add("add", (reader, writer) => {
    ignore(reader.read_field_begin())
    let a = reader.read_i32()
    ignore(reader.read_field_begin())
    let b = reader.read_i32()
    ignore(reader.read_field_begin())
    writer.write_field_begin(@thrift.type_i32, 0)
    writer.write_i32(a + b)
  })
  processor
}

///|
async fn check(port : Int32) -> Unit {
  let client = @net.ThriftClient::connect("127.0.0.1", port)
  defer client.close()
  let pong = @thrift.call(
    client,
    "ping",
    1,
    writer => {
      writer.write_field_begin(@thrift.type_string, 1)
      writer.write_string("moonrpc")
    },
    reader => reader.read_string(),
  ) catch {
    e => abort("ping failed: \{e}")
  }
  println("ping  \{pong}")
  let sum = @thrift.call(
    client,
    "add",
    2,
    writer => {
      writer.write_field_begin(@thrift.type_i32, 1)
      writer.write_i32(20)
      writer.write_field_begin(@thrift.type_i32, 2)
      writer.write_i32(22)
    },
    reader => reader.read_i32(),
  ) catch {
    e => abort("add failed: \{e}")
  }
  println("add   \{sum}")
}

///|
fn main {
  let (checking, port_text) = match @env.args() {
    [_, "check", p, ..] => (true, Some(p))
    [_, p, ..] => (false, Some(p))
    _ => (false, None)
  }
  let port = match port_text {
    Some(text) => @string.parse_int(text[:]) catch { _ => 9090 }
    None => 9090
  }
  @async.run_async_main(() => {
    if checking {
      check(port)
    } else {
      println("thrift serving on 127.0.0.1:\{port}")
      @net.serve_thrift(host="127.0.0.1", port~, processor())
    }
  })
}
