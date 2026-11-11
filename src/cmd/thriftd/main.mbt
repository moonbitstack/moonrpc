// A Thrift service on one socket, in whichever transport and protocol the words pick.
//
//     thriftd [port] [transport] [protocol]        serve on 127.0.0.1 (9090)
//     thriftd check [port] [transport] [protocol]  call it with this library
//
//   transport: framed | buffered | zlib | http | header | header-zlib
//   protocol:  binary | compact | json
//
// The handlers below only see `Protocol`, so the same service answers in every protocol and
// every transport; the words pick the bytes on the wire, not the service. The header
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
/// The transport a run speaks. `Header` is the header transport over a plain frame;
/// `HeaderZlib` is the same frames through its zlib transform.
priv enum Wire {
  Framed
  Buffered
  Zlib
  Http
  Header
  HeaderZlib
}

///|
/// The protocol for one call: one of the three this package implements, or one of them inside
/// the header transport, which carries the inner protocol's name in each frame.
priv enum Coded {
  Binary
  Compact
  Json
}

///|
fn protocol_of(wire : Wire, codec : Coded) -> &@thrift.Protocol {
  match wire {
    Header | HeaderZlib => {
      let header = header_protocol(codec)
      if wire is HeaderZlib {
        header.add_transform(@thrift.header_transform_zlib)
      }
      (header : &@thrift.Protocol)
    }
    _ =>
      match codec {
        Binary => (@thrift.Binary::new(b"") : &@thrift.Protocol)
        Compact => (@thrift.Compact::new(b"") : &@thrift.Protocol)
        Json => (@thrift.Json::new(b"") : &@thrift.Protocol)
      }
  }
}

///|
/// A fresh header-protocol endpoint, which is what the accept loop asks for once per
/// connection: a protocol object carries the connection's state.
fn header_protocol(codec : Coded) -> @thrift.Header {
  let header = @thrift.Header::new()
  header.set_protocol(
    match codec {
      Compact => @thrift.header_protocol_compact
      _ => @thrift.header_protocol_binary
    },
  )
  header
}

///|
async fn check(port : Int32, wire : Wire, codec : Coded) -> Unit {
  let proto = protocol_of(wire, codec)
  let client = @net.ThriftClient::connect(
    "127.0.0.1",
    port,
    proto,
    wire=wire_of(wire),
  )
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
/// The driver's name for a transport.
fn wire_of(wire : Wire) -> @net.ThriftWire {
  match wire {
    Framed => @net.ThriftWire::Framed
    Buffered => @net.ThriftWire::Buffered
    Zlib => @net.ThriftWire::Zlib
    Http => @net.ThriftWire::Http
    // The header transport frames its own messages, so the driver sees ordinary frames.
    Header | HeaderZlib => @net.ThriftWire::Framed
  }
}

///|
fn main {
  let mut checking = false
  let mut codec = Binary
  let mut wire = Framed
  let mut port = 9090
  let args = @env.args()
  for i = 1; i < args.length(); i = i + 1 {
    let arg = args[i]
    // Every word is optional and order-free: a port, a transport, a protocol, and `check` to
    // turn the same command into a client.
    match arg {
      "check" => checking = true
      "framed" => wire = Framed
      "buffered" => wire = Buffered
      "zlib" => wire = Zlib
      "http" => wire = Http
      "header" => wire = Header
      "header-zlib" => wire = HeaderZlib
      "binary" => codec = Binary
      "compact" => codec = Compact
      "json" => codec = Json
      _ => port = @string.parse_int(arg[:]) catch { _ => port }
    }
  }
  let protocol_word = match codec {
    Binary => "binary"
    Compact => "compact"
    Json => "json"
  }
  let wire_word = match wire {
    Framed => "framed"
    Buffered => "buffered"
    Zlib => "zlib"
    Http => "http"
    Header => "header"
    HeaderZlib => "header-zlib"
  }
  @async.run_async_main(() => {
    if checking {
      check(port, wire, codec)
    } else {
      println(
        "thrift serving on 127.0.0.1:\{port} (\{wire_word}, \{protocol_word})",
      )
      serve(wire, codec, port)
    }
  })
}

///|
/// Serve the same service over any of the transports and protocols. The dispatch is in `net/`,
/// which takes a closure for the protocol because a connection owns a protocol object of its
/// own — a compact reader's field-id deltas and a text reader's cursor are its state.
async fn serve(wire : Wire, codec : Coded, port : Int32) -> Unit {
  @net.serve_thrift_wire(
    host="127.0.0.1",
    port~,
    wire=wire_of(wire),
    processor(),
    () => protocol_of(wire, codec),
  )
}
