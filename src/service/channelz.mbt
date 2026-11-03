// A channelz-style registry: what a channel and a server have carried, as counters
// and a connectivity state, fed from the stats events the engines already emit.
// gRPC's channelz service answers over protobuf; this is the in-process data model
// behind it, so a program can watch its own connections without a wire service.

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
/// One channel as channelz sees it: its target, connectivity state, call counts and
/// how many messages each way it has carried.
pub(all) struct ChannelNode {
  id : Int32
  target : String
  calls : Counters
  mut state : String
  mut messages_sent : Int64
  mut messages_received : Int64
}

///|
/// One server as channelz sees it: its call counts.
pub(all) struct ServerNode {
  id : Int32
  calls : Counters
}

///|
/// A registry of the channels and servers a program wants to watch. `handler` builds a
/// stats handler bound to one node, so a caller attaches it to the channel or server
/// that node describes.
pub(all) struct Registry {
  channels : Map[Int32, ChannelNode]
  servers : Map[Int32, ServerNode]
  mut next : Int32
}

///|
/// An empty registry; ids start at 1, as channelz's do.
pub fn Registry::new() -> Registry {
  { channels: Map([]), servers: Map([]), next: 1, }
}

///|
/// Register a channel with `target` and return its id.
pub fn Registry::add_channel(self : Registry, target : String) -> Int32 {
  let id = self.next
  self.next = self.next + 1
  self.channels[id] = {
    id,
    target,
    calls: Counters::new(),
    state: "IDLE",
    messages_sent: 0L,
    messages_received: 0L,
  }
  id
}

///|
/// Register a server and return its id.
pub fn Registry::add_server(self : Registry) -> Int32 {
  let id = self.next
  self.next = self.next + 1
  self.servers[id] = { id, calls: Counters::new(), }
  id
}

///|
/// The channel a registry knows by `id`.
pub fn Registry::channel(self : Registry, id : Int32) -> ChannelNode? {
  self.channels.get(id)
}

///|
/// The server a registry knows by `id`.
pub fn Registry::server(self : Registry, id : Int32) -> ServerNode? {
  self.servers.get(id)
}

///|
/// A stats handler that folds a channel's events into node `id`.
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
        }
        None => ()
      }
    },
    conn=event => {
      match self.channels.get(id) {
        Some(node) =>
          match event {
            @wire.ConnStats::ConnBegin => node.state = "READY"
            @wire.ConnStats::ConnEnd => node.state = "SHUTDOWN"
          }
        None => ()
      }
    },
  )
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
