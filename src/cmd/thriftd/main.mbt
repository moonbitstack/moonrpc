// A Thrift service over TBinaryProtocol or TCompactProtocol, framed or behind the header
// transport, on one socket.
//
//     thriftd [port] [framed|header] [binary|compact]          serve on 127.0.0.1 (9090)
//     thriftd check [port] [framed|header] [binary|compact]    call it with this library
//
// The handlers below only see `Protocol`, so the same service answers in either protocol and
// either transport; the words pick the bytes on the wire, not the service. The header
// transport carries the inner protocol in each frame, so it can answer both at once.

///|
fn processor() -> @thrift.Processor {
  let processor = @thrift.Processor::new()
  // What the last ONEWAY call said. A oneway method answers nothing, so the only way to see
  // that it arrived is to ask a later call what it saw — which is also what makes the test a
  // test of the transport rather than of the handler.
  let last_note = Ref("")
  processor.add("ping", proto => {
    ignore(proto.read_field_begin())
    let text = proto.read_string()
    ignore(proto.read_field_begin())
    proto.write_field_begin(@thrift.type_string, 0)
    proto.write_string("pong:" + text)
  })
  processor.add("add", proto => {
    ignore(proto.read_field_begin())
    let a = proto.read_i32()
    ignore(proto.read_field_begin())
    let b = proto.read_i32()
    ignore(proto.read_field_begin())
    proto.write_field_begin(@thrift.type_i32, 0)
    proto.write_i32(a + b)
  })
  // A double is the one value the two protocols spell differently: eight bytes
  // big-endian in binary, little-endian in compact.
  processor.add("double", proto => {
    ignore(proto.read_field_begin())
    let x = proto.read_double()
    ignore(proto.read_field_begin())
    proto.write_field_begin(@thrift.type_double, 0)
    proto.write_double(x * 2.0)
  })
  // A method that may answer an exception instead of a value: field 0 for success,
  // field 1 for the failure its `throws` clause numbers.
  // A method the IDL would declare `oneway`: it runs, and no reply goes back. Over a framed
  // transport that means no frame at all, so a server that answered would put a stray frame in
  // front of the caller's next reply.
  processor.add_oneway("note", proto => {
    ignore(proto.read_field_begin())
    last_note.val = proto.read_string()
    ignore(proto.read_field_begin())
  })
  processor.add("last_note", proto => {
    ignore(proto.read_field_begin())
    proto.write_field_begin(@thrift.type_string, 0)
    proto.write_string(last_note.val)
  })
  processor.add("fail", proto => {
    ignore(proto.read_field_begin())
    let text = proto.read_string()
    ignore(proto.read_field_begin())
    if text == "ok" {
      proto.write_field_begin(@thrift.type_string, 0)
      proto.write_string("fine:" + text)
    } else {
      proto.write_field_begin(@thrift.type_struct, 1)
      write_boom(proto, "boom:" + text)
    }
  })
  processor
}

///|
/// The `Boom` exception as a struct on the wire: one string field, as the IDL declares.
fn write_boom(proto : &@thrift.Protocol, message : String) -> Unit {
  proto.write_struct_begin("Boom")
  proto.write_field_begin(@thrift.type_string, 1)
  proto.write_string(message)
  proto.write_field_stop()
  proto.write_struct_end()
}

///|
/// Decode that struct when it arrives in field 1, and leave any other field to the
/// caller.
fn read_boom(
  proto : &@thrift.Protocol,
  field_id : Int32,
) -> String? raise @thrift.ThriftError {
  if field_id != 1 {
    return None
  }
  proto.read_struct_begin()
  let mut message = ""
  for ;; {
    let (field_type, id) = proto.read_field_begin()
    if field_type == @thrift.type_stop {
      break
    }
    if id == 1 && field_type == @thrift.type_string {
      message = proto.read_string()
    } else {
      @thrift.skip(proto, field_type)
    }
  }
  proto.read_struct_end()
  Some(message)
}

///|
/// The transport a run speaks: a length in front of every message, or the header transport's
/// frame — which carries its own length, the inner protocol's name, and optional headers.
priv enum Wire {
  Framed
  Header
}

///|
/// The protocol for one call: the plain one, or the header transport with `protocol` inside.
/// `zlib` asks the header transport to compress every frame with its zlib transform, which is
/// the one transform this build reads and writes.
fn protocol_of(wire : Wire, compact : Bool, zlib : Bool) -> &@thrift.Protocol {
  match wire {
    Framed =>
      if compact {
        (@thrift.Compact::new(b"") : &@thrift.Protocol)
      } else {
        (@thrift.Binary::new(b"") : &@thrift.Protocol)
      }
    Header => {
      let header = header_protocol(compact)
      if zlib {
        header.add_transform(@thrift.header_transform_zlib)
      }
      (header : &@thrift.Protocol)
    }
  }
}

///|
/// A fresh header-protocol endpoint, which is what the accept loop asks for once per
/// connection: a protocol object carries the connection's state.
fn header_protocol(compact : Bool) -> @thrift.Header {
  let header = @thrift.Header::new()
  header.set_protocol(
    if compact {
      @thrift.header_protocol_compact
    } else {
      @thrift.header_protocol_binary
    },
  )
  header
}

///|
async fn check(port : Int32, wire : Wire, compact : Bool, zlib : Bool) -> Unit {
  let proto = protocol_of(wire, compact, zlib)
  let client = @net.ThriftClient::connect("127.0.0.1", port, proto)
  defer client.close()
  let pong = @thrift.call(
    client,
    proto,
    "ping",
    1,
    proto => {
      proto.write_field_begin(@thrift.type_string, 1)
      proto.write_string("moonrpc")
    },
    proto => proto.read_string(),
  ) catch {
    e => abort("ping failed: \{e}")
  }
  println("ping  \{pong}")
  let sum = @thrift.call(
    client,
    proto,
    "add",
    2,
    proto => {
      proto.write_field_begin(@thrift.type_i32, 1)
      proto.write_i32(20)
      proto.write_field_begin(@thrift.type_i32, 2)
      proto.write_i32(22)
    },
    proto => proto.read_i32(),
  ) catch {
    e => abort("add failed: \{e}")
  }
  println("add   \{sum}")
  let scaled = @thrift.call(
    client,
    proto,
    "double",
    3,
    proto => {
      proto.write_field_begin(@thrift.type_double, 1)
      proto.write_double(1.5)
    },
    proto => proto.read_double(),
  ) catch {
    e => abort("double failed: \{e}")
  }
  println("double \{scaled}")
  let fine = @thrift.call_result(
    client,
    proto,
    "fail",
    4,
    proto => {
      proto.write_field_begin(@thrift.type_string, 1)
      proto.write_string("ok")
    },
    proto => proto.read_string(),
    read_boom,
  ) catch {
    e => abort("fail failed: \{e}")
  }
  match fine {
    Ok(value) => println("fail  \{value}")
    Err(_) => abort("fail with `ok` answered an exception")
  }
  let boom = @thrift.call_result(
    client,
    proto,
    "fail",
    5,
    proto => {
      proto.write_field_begin(@thrift.type_string, 1)
      proto.write_string("no")
    },
    proto => proto.read_string(),
    read_boom,
  ) catch {
    e => abort("fail failed: \{e}")
  }
  match boom {
    Ok(_) => abort("fail with `no` answered a value")
    Err(message) => println("fail  \{message}")
  }
  // A oneway call answers nothing, so nothing may be left in front of the next reply; the
  // observation call that follows is what would read a stray frame if the server answered one.
  @thrift.oneway_call(client, proto, "note", 6, proto => {
    proto.write_field_begin(@thrift.type_string, 1)
    proto.write_string("moonrpc")
  }) catch {
    e => abort("note failed: \{e}")
  }
  let seen = @thrift.call(
    client,
    proto,
    "last_note",
    7,
    proto => {
      proto.write_field_begin(@thrift.type_string, 1)
      proto.write_string("")
    },
    proto => proto.read_string(),
  ) catch {
    e => abort("last_note failed: \{e}")
  }
  if seen != "moonrpc" {
    abort("oneway note was not seen: \{seen}")
  }
  println("note  \{seen}")
}

///|
fn main {
  let mut checking = false
  let mut compact = false
  let mut wire = Framed
  let mut zlib = false
  let mut port = 9090
  let args = @env.args()
  for i = 1; i < args.length(); i = i + 1 {
    let arg = args[i]
    // Every word is optional and order-free: a port, a transport, a protocol, and `check` to
    // turn the same command into a client.
    match arg {
      "check" => checking = true
      "framed" => wire = Framed
      "header" => wire = Header
      "compact" => compact = true
      "binary" => compact = false
      "zlib" => zlib = true
      _ => port = @string.parse_int(arg[:]) catch { _ => port }
    }
  }
  let protocol_word = if compact { "compact" } else { "binary" }
  let wire_word = match wire {
    Framed => "framed"
    Header => "header"
  }
  @async.run_async_main(() => {
    if checking {
      check(port, wire, compact, zlib)
    } else {
      println(
        "thrift serving on 127.0.0.1:\{port} (\{wire_word}, \{protocol_word})",
      )
      match (wire, compact) {
        (Framed, true) =>
          @net.serve_thrift(host="127.0.0.1", port~, processor(), () => {
            @thrift.Compact::new(b"")
          })
        (Framed, false) =>
          @net.serve_thrift(host="127.0.0.1", port~, processor(), () => {
            @thrift.Binary::new(b"")
          })
        (Header, true) =>
          @net.serve_thrift(host="127.0.0.1", port~, processor(), () => {
            header_protocol(true)
          })
        (Header, false) =>
          @net.serve_thrift(host="127.0.0.1", port~, processor(), () => {
            header_protocol(false)
          })
      }
    }
  })
}
