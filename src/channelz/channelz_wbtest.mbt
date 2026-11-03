// The channelz descriptor and the service over the two pure engines.

///|
fn drive(
  server : @server.H2Server,
  client : @client.H2Client,
  id : Int32,
  initial : Array[@http2.Frame],
) -> Unit raise {
  let to_server : Array[@http2.Frame] = []
  let to_client : Array[@http2.Frame] = []
  to_server.append(client.preface())
  to_client.append(server.preface())
  to_server.append(initial)
  let mut si = 0
  let mut ci = 0
  let mut steps = 0
  while !client.is_done(id) && steps < 100000 {
    steps = steps + 1
    if si < to_server.length() {
      let f = to_server[si]
      si = si + 1
      to_client.append(server.feed(f))
    } else if ci < to_client.length() {
      let f = to_client[ci]
      ci = ci + 1
      to_server.append(client.feed(f))
    } else {
      break
    }
  }
}

///|
fn response_end(body : Bytes) -> Bool raise {
  let r = @proto.PbReader::new(body)
  let mut end = false
  while !r.eof() {
    match r.read_tag() {
      (2, Varint) => end = r.read_bool()
      (_, wire) => r.skip(wire)
    }
  }
  end
}

///|
fn message_named(
  file : @proto.FileDescriptor,
  name : String,
) -> @proto.MessageDescriptor? {
  for message in file.messages {
    if message.name == name {
      return Some(message)
    }
  }
  None
}

///|
test "channelz: the descriptor carries the canonical messages, oneofs and methods" {
  let file = descriptor()
  assert_eq(file.name, "grpc/channelz/v1/channelz.proto")
  assert_eq(file.package_, "grpc.channelz.v1")
  assert_eq(file.services.length(), 1)
  assert_eq(file.services[0].name, "Channelz")
  assert_eq(file.services[0].methods.length(), 7)
  assert_true(file.symbols().contains("grpc.channelz.v1.Channelz"))
  assert_true(file.symbols().contains("grpc.channelz.v1.Channel"))
  // The three oneofs the canonical file declares.
  for
    pair in [
      ("ChannelTraceEvent", "child_ref"),
      ("Address", "address"),
      ("Security", "model"),
    ] {
    let (name, oneof) = pair
    match message_named(file, name) {
      Some(message) => assert_eq(message.oneofs, [oneof])
      None => abort("\{name} is missing from the descriptor")
    }
  }
  // Canonical field numbers, including the refs' deliberately different ones.
  match message_named(file, "SubchannelRef") {
    Some(message) => assert_eq(message.fields[0].number, 7)
    None => abort("SubchannelRef is missing")
  }
  match message_named(file, "SocketRef") {
    Some(message) => assert_eq(message.fields[0].number, 3)
    None => abort("SocketRef is missing")
  }
}

///|
test "channelz: a request round-trips through its codec" {
  let request = GetServerSocketsRequest::{
    server_id: 7L,
    start_socket_id: 3L,
    max_results: 10L,
  }
  let body = @proto.Message::encode(request)
  let back : GetServerSocketsRequest = @proto.Message::decode(body)
  assert_eq(back.server_id, 7L)
  assert_eq(back.start_socket_id, 3L)
  assert_eq(back.max_results, 10L)
}

///|
test "channelz: GetServers and GetServer answer over the two engines" {
  let registry = @service.Registry::new()
  let server_id = registry.add_server()
  ignore(registry.add_server_socket(server_id, "127.0.0.1:12010"))
  let server = @server.H2Server::new()
  let channelz = ChannelzService::new(registry)
  channelz.install(server)
  let client = @client.H2Client::new()

  let (id, frames) = client.unary(
    servers_path,
    @proto.Message::encode(GetServersRequest::{
      start_server_id: 0L,
      max_results: 0L,
    }),
  )
  drive(server, client, id, frames)
  let reply = client.reply(id)
  assert_eq(reply.grpc_status, 0)
  assert_eq(reply.messages.length(), 1)
  assert_true(response_end(reply.messages[0]))

  let (id2, frames2) = client.unary(
    server_path,
    @proto.Message::encode(GetServerRequest::{
      server_id: server_id.to_int64(),
    }),
  )
  drive(server, client, id2, frames2)
  assert_eq(client.reply(id2).grpc_status, 0)

  let (id3, frames3) = client.unary(
    server_path,
    @proto.Message::encode(GetServerRequest::{ server_id: 999L, }),
  )
  drive(server, client, id3, frames3)
  assert_eq(client.reply(id3).grpc_status, 5)
}

///|
test "channelz: a channel's socket is listed and answers GetSocket" {
  let registry = @service.Registry::new()
  let channel_id = registry.add_channel("127.0.0.1:12010")
  let server = @server.H2Server::new()
  ChannelzService::new(registry).install(server)
  let client = @client.H2Client::new()
  let (id, frames) = client.unary(
    channel_path,
    @proto.Message::encode(GetChannelRequest::{
      channel_id: channel_id.to_int64(),
    }),
  )
  drive(server, client, id, frames)
  assert_eq(client.reply(id).grpc_status, 0)
  // The channel node's socket id is the next registry id.
  let socket_id = match registry.sockets_of(channel_id).get(0) {
    Some(socket) => socket.id
    None => abort("the channel has a socket")
  }
  let (id2, frames2) = client.unary(
    socket_path,
    @proto.Message::encode(GetSocketRequest::{
      socket_id: socket_id.to_int64(),
      summary: true,
    }),
  )
  drive(server, client, id2, frames2)
  assert_eq(client.reply(id2).grpc_status, 0)
}
