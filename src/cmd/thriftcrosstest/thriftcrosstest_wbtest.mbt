// The cross test against itself: the service here answering the client here, over a real
// socket, in both protocols. CI points the same two halves at Apache Thrift's programs;
// this is the fast check that the pair agrees before that runs, and it fails with the same
// message when a call is answered wrongly.

///|
async test "cross: the service passes its own client, binary" {
  @async.with_task_group(g => {
    let listener = @net.bind_thrift(host="127.0.0.1", port=0)
    let port_18310 = listener.addr().port()
    let task = g.spawn(() => {
      @net.serve_thrift_on(listener, processor(), () => @thrift.Binary::new(b""))
    })
    let proto : &@thrift.Protocol = @thrift.Binary::new(b"")
    let client = @net.ThriftClient::connect("127.0.0.1", port_18310, proto)
    defer client.close()
    check(client, proto)
    task.cancel()
  })
}

///|
async test "cross: the service passes its own client, compact" {
  @async.with_task_group(g => {
    let listener = @net.bind_thrift(host="127.0.0.1", port=0)
    let port_18311 = listener.addr().port()
    let task = g.spawn(() => {
      @net.serve_thrift_on(listener, processor(), () => {
        @thrift.Compact::new(b"")
      })
    })
    let proto : &@thrift.Protocol = @thrift.Compact::new(b"")
    let client = @net.ThriftClient::connect("127.0.0.1", port_18311, proto)
    defer client.close()
    check(client, proto)
    task.cancel()
  })
}

///|
/// A CALL frame for `name` whose only argument is the i32 in field 1.
fn call_frame(name : String, kind : Int32, seqid : Int32) -> Bytes {
  let proto : &@thrift.Protocol = @thrift.Binary::new(b"")
  proto.write_message_begin(name, kind, seqid)
  proto.write_struct_begin(name + "_args")
  proto.write_field_begin(@thrift.type_i32, 1)
  proto.write_i32(2)
  proto.write_field_stop()
  proto.write_struct_end()
  proto.output()
}

///|
test "cross: a oneway method answers no bytes at all" {
  let proto : &@thrift.Protocol = @thrift.Binary::new(b"")
  // Apache Thrift's Go client sends a oneway call as a CALL and never reads an answer, so
  // the reply must be empty for that kind as well as for ONEWAY.
  for kind in [@thrift.message_call, @thrift.message_oneway] {
    let reply = processor().process(proto, call_frame("testOneway", kind, 1)) catch {
      e => abort("testOneway failed: \{e.to_string()}")
    }
    assert_eq(reply.length(), 0)
  }
}

///|
test "cross: a handler that fails answers an application exception, not silence" {
  let proto : &@thrift.Protocol = @thrift.Binary::new(b"")
  let writer : &@thrift.Protocol = @thrift.Binary::new(b"")
  writer.write_message_begin("testException", @thrift.message_call, 7)
  writer.write_struct_begin("testException_args")
  writer.write_field_begin(@thrift.type_string, 1)
  writer.write_string("TException")
  writer.write_field_stop()
  writer.write_struct_end()
  let frame = writer.output()
  let reply = processor().process(proto, frame) catch {
    e => abort("testException failed: \{e.to_string()}")
  }
  let reader : &@thrift.Protocol = @thrift.Binary::new(reply)
  let (name, kind, seqid) = reader.read_message_begin() catch {
    e => abort("the reply is not a message: \{e.to_string()}")
  }
  assert_eq(
    (name, kind, seqid),
    ("testException", @thrift.message_exception, 7),
  )
  reader.read_struct_begin()
  let (field_type, _) = reader.read_field_begin()
  assert_eq(field_type, @thrift.type_string)
  assert_eq(reader.read_string(), "Just TException")
}
