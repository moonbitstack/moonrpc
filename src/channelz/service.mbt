// The seven channelz RPCs over the registry: top channels, servers, server sockets,
// and one channel, subchannel or socket by id. The descriptor is the canonical
// channelz one, so a real channelz client can describe and call this service.

///|
pub let top_channels_path : String = "/grpc.channelz.v1.Channelz/GetTopChannels"

///|
pub let servers_path : String = "/grpc.channelz.v1.Channelz/GetServers"

///|
pub let server_path : String = "/grpc.channelz.v1.Channelz/GetServer"

///|
pub let server_sockets_path : String = "/grpc.channelz.v1.Channelz/GetServerSockets"

///|
pub let channel_path : String = "/grpc.channelz.v1.Channelz/GetChannel"

///|
pub let subchannel_path : String = "/grpc.channelz.v1.Channelz/GetSubchannel"

///|
pub let socket_path : String = "/grpc.channelz.v1.Channelz/GetSocket"

///|
/// The channelz service over one registry.
pub(all) struct ChannelzService {
  registry : @service.Registry
}

///|
/// A channelz service reading `registry`.
pub fn ChannelzService::new(registry : @service.Registry) -> ChannelzService {
  { registry, }
}

///|
/// Register the seven RPCs on a server, in the clear or over TLS.
pub fn[R : @stream.Registrar] ChannelzService::install(
  self : ChannelzService,
  server : R,
) -> Unit {
  server.register_handler(
    top_channels_path,
    @service.unary(fn(
      ctx : @stream.RpcContext,
      req : GetTopChannelsRequest,
    ) -> GetTopChannelsResponse {
      self.top_channels(ctx, req)
    }),
  )
  server.register_handler(
    servers_path,
    @service.unary(fn(
      ctx : @stream.RpcContext,
      req : GetServersRequest,
    ) -> GetServersResponse {
      self.get_servers(ctx, req)
    }),
  )
  server.register_handler(
    server_path,
    @service.unary(fn(
      ctx : @stream.RpcContext,
      req : GetServerRequest,
    ) -> GetServerResponse {
      self.get_server(ctx, req)
    }),
  )
  server.register_handler(
    server_sockets_path,
    @service.unary(fn(
      ctx : @stream.RpcContext,
      req : GetServerSocketsRequest,
    ) -> GetServerSocketsResponse {
      self.get_server_sockets(ctx, req)
    }),
  )
  server.register_handler(
    channel_path,
    @service.unary(fn(
      ctx : @stream.RpcContext,
      req : GetChannelRequest,
    ) -> GetChannelResponse {
      self.get_channel(ctx, req)
    }),
  )
  server.register_handler(
    subchannel_path,
    @service.unary(fn(
      ctx : @stream.RpcContext,
      req : GetSubchannelRequest,
    ) -> GetSubchannelResponse {
      self.get_subchannel(ctx, req)
    }),
  )
  server.register_handler(
    socket_path,
    @service.unary(fn(
      ctx : @stream.RpcContext,
      req : GetSocketRequest,
    ) -> GetSocketResponse {
      self.get_socket(ctx, req)
    }),
  )
}

///|
/// Add channelz.proto and the well-known files it imports to a reflection service.
pub fn ChannelzService::add_to_reflection(
  self : ChannelzService,
  reflection : @service.ReflectionService,
) -> Unit {
  ignore(self)
  for file in well_known_files() {
    reflection.add_file(file)
  }
  reflection.add_file(descriptor())
}

///|
fn ChannelzService::top_channels(
  self : ChannelzService,
  ctx : @stream.RpcContext,
  req : GetTopChannelsRequest,
) -> GetTopChannelsResponse {
  ignore(ctx)
  let limit = if req.max_results > 0L { req.max_results } else { 100L }
  let out : Array[Channel] = []
  let mut n = 0L
  for node in self.registry.channels() {
    if node.id.to_int64() >= req.start_channel_id && n < limit {
      out.push(self.channel_message(node))
      n = n + 1L
    }
  }
  { channel: out, is_end: n < limit, }
}

///|
fn ChannelzService::get_servers(
  self : ChannelzService,
  ctx : @stream.RpcContext,
  req : GetServersRequest,
) -> GetServersResponse {
  ignore(ctx)
  let limit = if req.max_results > 0L { req.max_results } else { 100L }
  let out : Array[Server] = []
  let mut n = 0L
  for node in self.registry.servers() {
    if node.id.to_int64() >= req.start_server_id && n < limit {
      out.push(self.server_message(node))
      n = n + 1L
    }
  }
  { server: out, is_end: n < limit, }
}

///|
fn ChannelzService::get_server(
  self : ChannelzService,
  ctx : @stream.RpcContext,
  req : GetServerRequest,
) -> GetServerResponse {
  match self.registry.server(req.server_id.to_int()) {
    Some(node) => { server: self.server_message(node), }
    None => {
      ctx.fail(
        @wire.Status::NotFound.code(),
        "server \{req.server_id} not found",
      )
      { server: Server::empty(), }
    }
  }
}

///|
fn ChannelzService::get_server_sockets(
  self : ChannelzService,
  ctx : @stream.RpcContext,
  req : GetServerSocketsRequest,
) -> GetServerSocketsResponse {
  let limit = if req.max_results > 0L { req.max_results } else { 100L }
  match self.registry.server(req.server_id.to_int()) {
    Some(node) => {
      let out : Array[SocketRef] = []
      let mut n = 0L
      for id in node.listen_sockets {
        if id.to_int64() >= req.start_socket_id && n < limit {
          out.push(self.socket_ref(id))
          n = n + 1L
        }
      }
      { socket_ref: out, is_end: n < limit, }
    }
    None => {
      ctx.fail(
        @wire.Status::NotFound.code(),
        "server \{req.server_id} not found",
      )
      { socket_ref: [], is_end: true, }
    }
  }
}

///|
fn ChannelzService::get_channel(
  self : ChannelzService,
  ctx : @stream.RpcContext,
  req : GetChannelRequest,
) -> GetChannelResponse {
  match self.registry.channel(req.channel_id.to_int()) {
    Some(node) => { channel: self.channel_message(node), }
    None => {
      ctx.fail(
        @wire.Status::NotFound.code(),
        "channel \{req.channel_id} not found",
      )
      { channel: Channel::empty(), }
    }
  }
}

///|
fn ChannelzService::get_subchannel(
  self : ChannelzService,
  ctx : @stream.RpcContext,
  req : GetSubchannelRequest,
) -> GetSubchannelResponse {
  match self.registry.subchannel(req.subchannel_id.to_int()) {
    Some(node) =>
      {
        subchannel: {
          reference: { id: node.id.to_int64(), name: node.address, },
          state: state_code(node.state),
          target: node.address,
          calls_started: node.calls.started,
          calls_succeeded: node.calls.succeeded,
          calls_failed: node.calls.failed,
          channel_refs: [],
          subchannel_refs: [],
          socket_refs: node.sockets.map(id => self.socket_ref(id)),
        },
      }
    None => {
      ctx.fail(
        @wire.Status::NotFound.code(),
        "subchannel \{req.subchannel_id} not found",
      )
      { subchannel: Subchannel::empty(), }
    }
  }
}

///|
fn ChannelzService::get_socket(
  self : ChannelzService,
  ctx : @stream.RpcContext,
  req : GetSocketRequest,
) -> GetSocketResponse {
  match self.registry.socket(req.socket_id.to_int()) {
    Some(node) =>
      {
        socket: {
          reference: { id: node.id.to_int64(), name: node.address, },
          address: node.address,
          streams_started: node.streams.started,
          streams_succeeded: node.streams.succeeded,
          streams_failed: node.streams.failed,
          messages_sent: node.messages_sent,
          messages_received: node.messages_received,
        },
      }
    None => {
      ctx.fail(
        @wire.Status::NotFound.code(),
        "socket \{req.socket_id} not found",
      )
      { socket: Socket::empty(), }
    }
  }
}

///|
fn ChannelzService::channel_message(
  self : ChannelzService,
  node : @service.ChannelNode,
) -> Channel {
  {
    reference: { id: node.id.to_int64(), name: node.target, },
    state: state_code(node.state),
    target: node.target,
    calls_started: node.calls.started,
    calls_succeeded: node.calls.succeeded,
    calls_failed: node.calls.failed,
    last_call_ms: None,
    channel_refs: [],
    subchannel_refs: [],
    socket_refs: node.sockets.map(id => self.socket_ref(id)),
  }
}

///|
fn ChannelzService::server_message(
  self : ChannelzService,
  node : @service.ServerNode,
) -> Server {
  {
    reference: { id: node.id.to_int64(), name: "moonrpc", },
    calls_started: node.calls.started,
    calls_succeeded: node.calls.succeeded,
    calls_failed: node.calls.failed,
    last_call_ms: None,
    listen_sockets: node.listen_sockets.map(id => self.socket_ref(id)),
  }
}

///|
fn ChannelzService::socket_ref(self : ChannelzService, id : Int32) -> SocketRef {
  match self.registry.socket(id) {
    Some(node) => { id: node.id.to_int64(), name: node.address, }
    None => { id: id.to_int64(), name: "", }
  }
}

///|
fn state_code(state : String) -> Int32 {
  match state {
    "IDLE" => 1
    "CONNECTING" => 2
    "READY" => 3
    "TRANSIENT_FAILURE" => 4
    "SHUTDOWN" => 5
    _ => 0
  }
}
