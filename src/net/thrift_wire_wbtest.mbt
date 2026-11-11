// The four transports, each driven the way its peer drives it: one message at a time over
// framed, buffered, zlib and http. A listener is bound before the accept loop starts, so the
// client may dial at once — the connection queues.

///|
/// A small service: `ping` answers `pong:<text>`, `add` sums two numbers, and `note` is a
/// ONEWAY call that answers nothing.
fn transport_processor() -> @thrift.Processor {
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
  processor.add_oneway("note", proto => {
    ignore(proto.read_field_begin())
    ignore(proto.read_string())
    ignore(proto.read_field_begin())
  })
  processor
}

///|
async test "thrift transports: a framed connection answers every protocol" {
  let protocols : Array[() -> &@thrift.Protocol] = [
    () => (@thrift.Binary::new(b"") : &@thrift.Protocol),
    () => (@thrift.Compact::new(b"") : &@thrift.Protocol),
    () => (@thrift.Json::new(b"") : &@thrift.Protocol),
  ]
  for make in protocols {
    @async.with_task_group(g => {
      let listener = bind_thrift(host="127.0.0.1", port=0)
      let port = listener.addr().port()
      let task = g.spawn(() => {
        serve_thrift_wire_on(listener, wire=Framed, transport_processor(), make)
      })
      let proto = make()
      let client = ThriftClient::connect("127.0.0.1", port, proto)
      let answer = @thrift.call(
        client,
        proto,
        "ping",
        1,
        proto => {
          proto.write_field_begin(@thrift.type_string, 1)
          proto.write_string("hi")
        },
        proto => proto.read_string(),
      ) catch {
        e => abort("framed call: \{e.to_string()}")
      }
      client.close()
      assert_eq(answer, "pong:hi")
      task.cancel()
    })
  }
}

///|
async test "thrift transports: a buffered connection finds the end of a message it has to parse" {
  @async.with_task_group(g => {
    let listener = bind_thrift(host="127.0.0.1", port=0)
    let port = listener.addr().port()
    let make = () => (@thrift.Json::new(b"") : &@thrift.Protocol)
    let task = g.spawn(() => {
      serve_thrift_wire_on(listener, wire=Buffered, transport_processor(), make)
    })
    let proto = make()
    let client = ThriftClient::connect("127.0.0.1", port, proto, wire=Buffered)
    // Three calls on one connection: the octets a reply left behind have to be dropped, or the
    // third call reads the tail of the first.
    let mut last = ""
    for seq in 1..<4 {
      last = @thrift.call(
        client,
        proto,
        "ping",
        seq,
        proto => {
          proto.write_field_begin(@thrift.type_string, 1)
          proto.write_string("call" + seq.to_string())
        },
        proto => proto.read_string(),
      ) catch {
        e => abort("buffered call \{seq}: \{e.to_string()}")
      }
    }
    client.close()
    assert_eq(last, "pong:call3")
    task.cancel()
  })
}

///|
async test "thrift transports: a zlib connection carries several messages on one stream" {
  @async.with_task_group(g => {
    let listener = bind_thrift(host="127.0.0.1", port=0)
    let port = listener.addr().port()
    let make = () => (@thrift.Json::new(b"") : &@thrift.Protocol)
    let task = g.spawn(() => {
      serve_thrift_wire_on(listener, wire=Zlib, transport_processor(), make)
    })
    let proto = make()
    let client = ThriftClient::connect("127.0.0.1", port, proto, wire=Zlib)
    let mut last = ""
    for seq in 1..<4 {
      last = @thrift.call(
        client,
        proto,
        "ping",
        seq,
        proto => {
          proto.write_field_begin(@thrift.type_string, 1)
          proto.write_string("zlib" + seq.to_string())
        },
        proto => proto.read_string(),
      ) catch {
        e => abort("zlib call \{seq}: \{e.to_string()}")
      }
    }
    client.close()
    assert_eq(last, "pong:zlib3")
    task.cancel()
  })
}

///|
async test "thrift transports: an http connection carries one POST per call" {
  @async.with_task_group(g => {
    let listener = bind_thrift(host="127.0.0.1", port=0)
    let port = listener.addr().port()
    let make = () => (@thrift.Binary::new(b"") : &@thrift.Protocol)
    let task = g.spawn(() => {
      serve_thrift_wire_on(listener, wire=Http, transport_processor(), make)
    })
    let proto = make()
    let client = ThriftClient::connect("127.0.0.1", port, proto, wire=Http)
    let sum = @thrift.call(
      client,
      proto,
      "add",
      1,
      proto => {
        proto.write_field_begin(@thrift.type_i32, 1)
        proto.write_i32(20)
        proto.write_field_begin(@thrift.type_i32, 2)
        proto.write_i32(22)
      },
      proto => proto.read_i32(),
    ) catch {
      e => abort("http call: \{e.to_string()}")
    }
    client.close()
    assert_eq(sum, 42)
    task.cancel()
  })
}

///|
test "thrift transports: the zlib pair carries several messages and a message cut in two" {
  let out = ZlibOut::new()
  let inn = ZlibIn::new()
  let first = out.write(@utf8.encode("the first message"))
  let second = out.write(@utf8.encode("the second message"))
  let cut = first.length() / 2
  let seen : Array[String] = []
  // The first message is handed over in two pieces, as a socket may deliver it.
  for piece in [first[:cut].to_owned(), first[cut:].to_owned(), second] {
    for message in inn.feed(piece) {
      seen.push(@utf8.decode_lossy(message))
    }
  }
  assert_eq(seen.length(), 2)
  assert_eq(seen[0], "the first message")
  assert_eq(seen[1], "the second message")
}

///|
async test "thrift transports: a ONEWAY call leaves nothing in front of the next reply" {
  @async.with_task_group(g => {
    let listener = bind_thrift(host="127.0.0.1", port=0)
    let port = listener.addr().port()
    let make = () => (@thrift.Binary::new(b"") : &@thrift.Protocol)
    let task = g.spawn(() => {
      serve_thrift_wire_on(listener, wire=Buffered, transport_processor(), make)
    })
    let proto = make()
    let client = ThriftClient::connect("127.0.0.1", port, proto, wire=Buffered)
    @thrift.oneway_call(client, proto, "note", 1, proto => {
      proto.write_field_begin(@thrift.type_string, 1)
      proto.write_string("seen")
    }) catch {
      e => abort("oneway: \{e.to_string()}")
    }
    // The next reply has to be this call's, not a frame the oneway never should have sent.
    let seen = @thrift.call(
      client,
      proto,
      "ping",
      2,
      proto => {
        proto.write_field_begin(@thrift.type_string, 1)
        proto.write_string("after")
      },
      proto => proto.read_string(),
    ) catch {
      e => abort("ping after oneway: \{e.to_string()}")
    }
    client.close()
    assert_eq(seen, "pong:after")
    task.cancel()
  })
}
