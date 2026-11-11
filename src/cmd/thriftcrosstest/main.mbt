// Apache Thrift's cross test, both halves.
//
//     thriftcrosstest serve [port] [transport] [protocol]   serve `ThriftTest` (default 9100)
//     thriftcrosstest check [port] [transport] [protocol]   run the cross-test calls
//
//   transport: framed | buffered | zlib | http
//   protocol:  binary | compact | json
//
// CI points each half at the reference implementation in the other direction: the Apache
// Thrift `testclient` at `serve`, and `check` at the Apache Thrift `testserver`.

///|
/// The protocol a run speaks. The three are Apache's own, and the service below only ever sees
/// `Protocol`, so the same calls cross every combination.
priv enum Coded {
  Binary
  Compact
  Json
}

///|
fn protocol_of(codec : Coded) -> &@thrift.Protocol {
  match codec {
    Binary => (@thrift.Binary::new(b"") : &@thrift.Protocol)
    Compact => (@thrift.Compact::new(b"") : &@thrift.Protocol)
    Json => (@thrift.Json::new(b"") : &@thrift.Protocol)
  }
}

///|
fn main {
  let mut port = 9100
  let mut codec = Binary
  let mut wire = @net.ThriftWire::Framed
  let mut checking = false
  let args = @env.args()
  for i in 1..<args.length() {
    let arg = args[i]
    match arg {
      "check" => checking = true
      "binary" => codec = Binary
      "compact" => codec = Compact
      "json" => codec = Json
      "framed" => wire = @net.ThriftWire::Framed
      "buffered" => wire = @net.ThriftWire::Buffered
      "zlib" => wire = @net.ThriftWire::Zlib
      "http" => wire = @net.ThriftWire::Http
      _ => port = @string.parse_int(arg[:]) catch { _ => port }
    }
  }
  let kind = match codec {
    Binary => "binary"
    Compact => "compact"
    Json => "json"
  }
  @async.run_async_main(() => {
    if checking {
      // One protocol object for the whole conversation: it carries the read cursor and,
      // in the compact protocol, the field id a delta counts from.
      let proto = protocol_of(codec)
      let client = @net.ThriftClient::connect("127.0.0.1", port, proto, wire~)
      defer client.close()
      check(client, proto) catch {
        e => abort("the cross test failed: \{e.to_string()}")
      }
      println("cross test passed (\{kind})")
    } else {
      println("ThriftTest on 127.0.0.1:\{port} (\{kind})")
      @net.serve_thrift_wire(host="127.0.0.1", port~, wire~, processor(), () => {
        protocol_of(codec)
      })
    }
  })
}
