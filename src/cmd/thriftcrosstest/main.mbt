// Apache Thrift's cross test, both halves.
//
//     thriftcrosstest serve [port] [compact]   serve `ThriftTest` on 127.0.0.1 (default 9100)
//     thriftcrosstest check [port] [compact]   run the cross-test calls against a server
//
// CI points each half at the reference implementation in the other direction: the Apache
// Thrift `testclient` at `serve`, and `check` at the Apache Thrift `testserver`.

///|
fn protocol_of(compact : Bool) -> &@thrift.Protocol {
  if compact {
    let proto : &@thrift.Protocol = @thrift.Compact::new(b"")
    proto
  } else {
    let proto : &@thrift.Protocol = @thrift.Binary::new(b"")
    proto
  }
}

///|
fn main {
  let mut port = 9100
  let mut compact = false
  let mut checking = false
  let args = @env.args()
  for i in 1..<args.length() {
    let arg = args[i]
    if arg == "check" {
      checking = true
    } else if arg == "compact" {
      compact = true
    } else {
      port = @string.parse_int(arg[:]) catch { _ => port }
    }
  }
  let kind = if compact { "compact" } else { "binary" }
  @async.run_async_main(() => {
    if checking {
      // One protocol object for the whole conversation: it carries the read cursor and,
      // in the compact protocol, the field id a delta counts from.
      let proto = protocol_of(compact)
      let client = @net.ThriftClient::connect("127.0.0.1", port, proto)
      defer client.close()
      check(client, proto) catch {
        e => abort("the cross test failed: \{e.to_string()}")
      }
      println("cross test passed (\{kind})")
    } else {
      println("ThriftTest on 127.0.0.1:\{port} (\{kind})")
      if compact {
        @net.serve_thrift(host="127.0.0.1", port~, processor(), () => {
          @thrift.Compact::new(b"")
        })
      } else {
        @net.serve_thrift(host="127.0.0.1", port~, processor(), () => {
          @thrift.Binary::new(b"")
        })
      }
    }
  })
}
