// A channelz-style registry: what a channel, a subchannel, a socket and a server
// have carried, as counters and a connectivity state, fed from the stats events the
// engines already emit. The wire service that exposes it lives in the `channelz`
// package, so this stays a data model a program can also read in process.

///|
/// The call counters channelz keeps for one scope: how many began, and how they ended.
pub(all) struct Counters {
  mut started : Int64
  mut succeeded : Int64
  mut failed : Int64
}

///|
/// A zeroed counter triple.
pub fn Counters::new() -> Counters {
  { started: 0L, succeeded: 0L, failed: 0L, }
}

///|
/// Fold one RPC event into the counters: a begin counts as started, an end as a
/// success or a failure by its status. Other events leave the call counts alone.
pub fn Counters::record(self : Counters, event : @wire.RpcStats) -> Unit {
  match event {
    @wire.RpcStats::Begin(..) => self.started = self.started + 1L
    @wire.RpcStats::End(status~, ..) =>
      if status is @wire.Status::Ok {
        self.succeeded = self.succeeded + 1L
      } else {
        self.failed = self.failed + 1L
      }
    _ => ()
  }
}

///|
/// One channel as channelz sees it: its target, connectivity state, call counts,
/// how many messages each way it has carried, and the sockets under it.
pub(all) struct ChannelNode {
  id : Int32
  target : String
  calls : Counters
  mut state : String
  mut messages_sent : Int64
  mut messages_received : Int64
  sockets : Array[Int32]
}

///|
/// One subchannel: a resolved address under a channel, with its own connectivity and
/// counters.
pub(all) struct SubchannelNode {
  id : Int32
  address : String
  parent : Int32
  calls : Counters
  mut state : String
  mut messages_sent : Int64
  mut messages_received : Int64
  sockets : Array[Int32]
}

///|
/// One socket: the connection a channel or a server holds, with stream and message
/// counters. `parent` is the channel or server it belongs to.
pub(all) struct SocketNode {
  id : Int32
  address : String
  parent : Int32
  streams : Counters
  mut messages_sent : Int64
  mut messages_received : Int64
}

///|
/// One server as channelz sees it: its call counts and the sockets it listens on.
pub(all) struct ServerNode {
  id : Int32
  calls : Counters
  listen_sockets : Array[Int32]
}

///|
/// A registry of the channels, subchannels, sockets and servers a program wants to
/// watch. `handler` builds a stats handler bound to one node, so a caller attaches it
/// to the channel or server that node describes.
pub(all) struct Registry {
  channels : Map[Int32, ChannelNode]
  subchannels : Map[Int32, SubchannelNode]
  sockets : Map[Int32, SocketNode]
  servers : Map[Int32, ServerNode]
  mut next : Int32
}

///|
/// An empty registry; ids start at 1, as channelz's do.
pub fn Registry::new() -> Registry {
  {
    channels: Map([]),
    subchannels: Map([]),
    sockets: Map([]),
    servers: Map([]),
    next: 1,
  }
}

///|
/// Register a channel with `target`, give it one socket, and return the channel id.
pub fn Registry::add_channel(self : Registry, target : String) -> Int32 {
  let id = self.next
  self.next = self.next + 1
  let socket_id = self.next
  self.next = self.next + 1
  self.sockets[socket_id] = {
    id: socket_id,
    address: target,
    parent: id,
    streams: Counters::new(),
    messages_sent: 0L,
    messages_received: 0L,
  }
  self.channels[id] = {
    id,
    target,
    calls: Counters::new(),
    state: "IDLE",
    messages_sent: 0L,
    messages_received: 0L,
    sockets: [socket_id],
  }
  id
}

///|
/// Register a subchannel under `parent` for `address`, give it one socket, and return
/// the subchannel id.
pub fn Registry::add_subchannel(
  self : Registry,
  parent : Int32,
  address : String,
) -> Int32 {
  let id = self.next
  self.next = self.next + 1
  let socket_id = self.next
  self.next = self.next + 1
  self.sockets[socket_id] = {
    id: socket_id,
    address,
    parent: id,
    streams: Counters::new(),
    messages_sent: 0L,
    messages_received: 0L,
  }
  self.subchannels[id] = {
    id,
    address,
    parent,
    calls: Counters::new(),
    state: "IDLE",
    messages_sent: 0L,
    messages_received: 0L,
    sockets: [socket_id],
  }
  id
}

///|
/// Register a server and return its id.
pub fn Registry::add_server(self : Registry) -> Int32 {
  let id = self.next
  self.next = self.next + 1
  self.servers[id] = { id, calls: Counters::new(), listen_sockets: [], }
  id
}

///|
/// Give server `id` a listening socket at `address` and return the socket id.
pub fn Registry::add_server_socket(
  self : Registry,
  id : Int32,
  address : String,
) -> Int32 {
  let socket_id = self.next
  self.next = self.next + 1
  self.sockets[socket_id] = {
    id: socket_id,
    address,
    parent: id,
    streams: Counters::new(),
    messages_sent: 0L,
    messages_received: 0L,
  }
  match self.servers.get(id) {
    Some(server) => server.listen_sockets.push(socket_id)
    None => ()
  }
  socket_id
}

///|
/// The channel a registry knows by `id`.
pub fn Registry::channel(self : Registry, id : Int32) -> ChannelNode? {
  self.channels.get(id)
}

///|
/// The subchannel a registry knows by `id`.
pub fn Registry::subchannel(self : Registry, id : Int32) -> SubchannelNode? {
  self.subchannels.get(id)
}

///|
/// The socket a registry knows by `id`.
pub fn Registry::socket(self : Registry, id : Int32) -> SocketNode? {
  self.sockets.get(id)
}

///|
/// The server a registry knows by `id`.
pub fn Registry::server(self : Registry, id : Int32) -> ServerNode? {
  self.servers.get(id)
}

///|
/// The sockets whose `parent` is `id`, in id order.
pub fn Registry::sockets_of(self : Registry, id : Int32) -> Array[SocketNode] {
  let out : Array[SocketNode] = []
  let mut i = 1
  while i < self.next {
    match self.sockets.get(i) {
      Some(node) => if node.parent == id { out.push(node) }
      None => ()
    }
    i = i + 1
  }
  out
}

///|
/// A stats handler that folds a channel's events into node `id` and its socket.
pub fn Registry::channel_handler(
  self : Registry,
  id : Int32,
) -> @wire.StatsHandler {
  @wire.StatsHandler::new(
    rpc=event => {
      match self.channels.get(id) {
        Some(node) => {
          node.calls.record(event)
          match event {
            @wire.RpcStats::OutPayload(..) =>
              node.messages_sent = node.messages_sent + 1L
            @wire.RpcStats::InPayload(..) =>
              node.messages_received = node.messages_received + 1L
            _ => ()
          }
          if node.sockets.length() > 0 {
            self.record_socket(node.sockets[0], event)
          }
        }
        None => ()
      }
    },
    conn=event => {
      match self.channels.get(id) {
        Some(node) =>
          node.state = match event {
            @wire.ConnStats::ConnBegin => "READY"
            @wire.ConnStats::ConnEnd => "SHUTDOWN"
          }
        None => ()
      }
    },
  )
}

///|
/// Fold one event into socket `id`'s stream and message counters.
fn Registry::record_socket(
  self : Registry,
  id : Int32,
  event : @wire.RpcStats,
) -> Unit {
  match self.sockets.get(id) {
    Some(socket) => {
      socket.streams.record(event)
      match event {
        @wire.RpcStats::OutPayload(..) =>
          socket.messages_sent = socket.messages_sent + 1L
        @wire.RpcStats::InPayload(..) =>
          socket.messages_received = socket.messages_received + 1L
        _ => ()
      }
    }
    None => ()
  }
}

///|
/// A stats handler that folds a server's events into node `id`.
pub fn Registry::server_handler(
  self : Registry,
  id : Int32,
) -> @wire.StatsHandler {
  @wire.StatsHandler::new(rpc=event => {
    match self.servers.get(id) {
      Some(node) => node.calls.record(event)
      None => ()
    }
  })
}

///|
/// A stats handler that folds a socket's events into node `id`.
pub fn Registry::socket_handler(
  self : Registry,
  id : Int32,
) -> @wire.StatsHandler {
  @wire.StatsHandler::new(rpc=event => self.record_socket(id, event))
}

///|
/// Every channel the registry holds, in id order — the snapshot a channelz reader sees.
pub fn Registry::channels(self : Registry) -> Array[ChannelNode] {
  let out : Array[ChannelNode] = []
  let mut id = 1
  while id < self.next {
    match self.channels.get(id) {
      Some(node) => out.push(node)
      None => ()
    }
    id = id + 1
  }
  out
}

///|
/// Every subchannel, in id order.
pub fn Registry::subchannels(self : Registry) -> Array[SubchannelNode] {
  let out : Array[SubchannelNode] = []
  let mut id = 1
  while id < self.next {
    match self.subchannels.get(id) {
      Some(node) => out.push(node)
      None => ()
    }
    id = id + 1
  }
  out
}

///|
/// Every socket, in id order.
pub fn Registry::sockets(self : Registry) -> Array[SocketNode] {
  let out : Array[SocketNode] = []
  let mut id = 1
  while id < self.next {
    match self.sockets.get(id) {
      Some(node) => out.push(node)
      None => ()
    }
    id = id + 1
  }
  out
}

///|
/// Every server the registry holds, in id order.
pub fn Registry::servers(self : Registry) -> Array[ServerNode] {
  let out : Array[ServerNode] = []
  let mut id = 1
  while id < self.next {
    match self.servers.get(id) {
      Some(node) => out.push(node)
      None => ()
    }
    id = id + 1
  }
  out
}
