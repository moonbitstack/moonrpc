// A Thrift service over TBinaryProtocol or TCompactProtocol, framed, on one socket.
//
//     thriftd [port] [compact]          serve on 127.0.0.1 (default 9090)
//     thriftd check [port] [compact]    call it with the same library
//
// The handlers below only see `Protocol`, so the same service answers in either
// protocol; the flag picks the bytes on the wire, not the service.

///|
fn processor() -> @thrift.Processor {
  let processor = @thrift.Processor::new()
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
fn binary_protocol() -> &@thrift.Protocol {
  @thrift.Binary::new(b"")
}

///|
fn compact_protocol() -> &@thrift.Protocol {
  @thrift.Compact::new(b"")
}

///|
fn protocol_of(compact : Bool) -> &@thrift.Protocol {
  if compact {
    compact_protocol()
  } else {
    binary_protocol()
  }
}

///|
async fn check(port : Int32, compact : Bool) -> Unit {
  let proto = protocol_of(compact)
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
}

///|
fn main {
  let mut checking = false
  let mut compact = false
  let mut port = 9090
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
  @async.run_async_main(() => {
    if checking {
      check(port, compact)
    } else {
      println(
        "thrift serving on 127.0.0.1:\{port} (\{if compact { "compact" } else { "binary" }})",
      )
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
