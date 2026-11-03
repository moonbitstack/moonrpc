// The channelz messages the service reads and writes. Each response is encoded from
// the registry's snapshot; each request decodes only the fields the service uses.
// The field numbers are the canonical channelz ones (see `descriptor.mbt`).

///|
pub(all) struct ChannelRef {
  id : Int64
  name : String
}

///|
pub(all) struct SubchannelRef {
  id : Int64
  name : String
}

///|
pub(all) struct SocketRef {
  id : Int64
  name : String
}

///|
pub(all) struct ServerRef {
  id : Int64
  name : String
}

///|
pub(all) struct Channel {
  reference : ChannelRef
  state : Int32
  target : String
  calls_started : Int64
  calls_succeeded : Int64
  calls_failed : Int64
  last_call_ms : Int64?
  channel_refs : Array[ChannelRef]
  subchannel_refs : Array[SubchannelRef]
  socket_refs : Array[SocketRef]
}

///|
pub fn Channel::empty() -> Channel {
  {
    reference: { id: 0L, name: "", },
    state: 0,
    target: "",
    calls_started: 0L,
    calls_succeeded: 0L,
    calls_failed: 0L,
    last_call_ms: None,
    channel_refs: [],
    subchannel_refs: [],
    socket_refs: [],
  }
}

///|
pub(all) struct Subchannel {
  reference : SubchannelRef
  state : Int32
  target : String
  calls_started : Int64
  calls_succeeded : Int64
  calls_failed : Int64
  channel_refs : Array[ChannelRef]
  subchannel_refs : Array[SubchannelRef]
  socket_refs : Array[SocketRef]
}

///|
pub fn Subchannel::empty() -> Subchannel {
  {
    reference: { id: 0L, name: "", },
    state: 0,
    target: "",
    calls_started: 0L,
    calls_succeeded: 0L,
    calls_failed: 0L,
    channel_refs: [],
    subchannel_refs: [],
    socket_refs: [],
  }
}

///|
pub(all) struct Server {
  reference : ServerRef
  calls_started : Int64
  calls_succeeded : Int64
  calls_failed : Int64
  last_call_ms : Int64?
  listen_sockets : Array[SocketRef]
}

///|
pub fn Server::empty() -> Server {
  {
    reference: { id: 0L, name: "", },
    calls_started: 0L,
    calls_succeeded: 0L,
    calls_failed: 0L,
    last_call_ms: None,
    listen_sockets: [],
  }
}

///|
pub(all) struct Socket {
  reference : SocketRef
  address : String
  streams_started : Int64
  streams_succeeded : Int64
  streams_failed : Int64
  messages_sent : Int64
  messages_received : Int64
}

///|
pub fn Socket::empty() -> Socket {
  {
    reference: { id: 0L, name: "", },
    address: "",
    streams_started: 0L,
    streams_succeeded: 0L,
    streams_failed: 0L,
    messages_sent: 0L,
    messages_received: 0L,
  }
}

///|
fn ChannelRef::to_bytes(self : ChannelRef) -> Bytes {
  let w = @proto.PbWriter::new()
  w.int64(1, self.id)
  if self.name != "" {
    w.string_(2, self.name)
  }
  w.to_bytes()
}

///|
fn SubchannelRef::to_bytes(self : SubchannelRef) -> Bytes {
  let w = @proto.PbWriter::new()
  w.int64(7, self.id)
  if self.name != "" {
    w.string_(8, self.name)
  }
  w.to_bytes()
}

///|
fn SocketRef::to_bytes(self : SocketRef) -> Bytes {
  let w = @proto.PbWriter::new()
  w.int64(3, self.id)
  if self.name != "" {
    w.string_(4, self.name)
  }
  w.to_bytes()
}

///|
fn ServerRef::to_bytes(self : ServerRef) -> Bytes {
  let w = @proto.PbWriter::new()
  w.int64(5, self.id)
  if self.name != "" {
    w.string_(6, self.name)
  }
  w.to_bytes()
}

///|
fn timestamp_to_bytes(ms : Int64) -> Bytes {
  let w = @proto.PbWriter::new()
  w.int64(1, ms / 1000L)
  w.int32(2, (ms % 1000L).to_int() * 1_000_000)
  w.to_bytes()
}

///|
fn Channel::to_bytes(self : Channel) -> Bytes {
  let w = @proto.PbWriter::new()
  w.message_(1, self.reference.to_bytes())
  w.message_(2, self.data_to_bytes())
  for r in self.channel_refs {
    w.message_(3, r.to_bytes())
  }
  for r in self.subchannel_refs {
    w.message_(4, r.to_bytes())
  }
  for r in self.socket_refs {
    w.message_(5, r.to_bytes())
  }
  w.to_bytes()
}

///|
fn Channel::data_to_bytes(self : Channel) -> Bytes {
  let w = @proto.PbWriter::new()
  let state = @proto.PbWriter::new()
  state.enum_(1, self.state)
  w.message_(1, state.to_bytes())
  if self.target != "" {
    w.string_(2, self.target)
  }
  if self.calls_started != 0L {
    w.int64(4, self.calls_started)
  }
  if self.calls_succeeded != 0L {
    w.int64(5, self.calls_succeeded)
  }
  if self.calls_failed != 0L {
    w.int64(6, self.calls_failed)
  }
  match self.last_call_ms {
    Some(ms) => w.message_(7, timestamp_to_bytes(ms))
    None => ()
  }
  w.to_bytes()
}

///|
fn Subchannel::to_bytes(self : Subchannel) -> Bytes {
  let w = @proto.PbWriter::new()
  w.message_(1, self.reference.to_bytes())
  let data = @proto.PbWriter::new()
  let state = @proto.PbWriter::new()
  state.enum_(1, self.state)
  data.message_(1, state.to_bytes())
  if self.target != "" {
    data.string_(2, self.target)
  }
  if self.calls_started != 0L {
    data.int64(4, self.calls_started)
  }
  if self.calls_succeeded != 0L {
    data.int64(5, self.calls_succeeded)
  }
  if self.calls_failed != 0L {
    data.int64(6, self.calls_failed)
  }
  w.message_(2, data.to_bytes())
  for r in self.channel_refs {
    w.message_(3, r.to_bytes())
  }
  for r in self.subchannel_refs {
    w.message_(4, r.to_bytes())
  }
  for r in self.socket_refs {
    w.message_(5, r.to_bytes())
  }
  w.to_bytes()
}

///|
fn Server::to_bytes(self : Server) -> Bytes {
  let w = @proto.PbWriter::new()
  w.message_(1, self.reference.to_bytes())
  let data = @proto.PbWriter::new()
  if self.calls_started != 0L {
    data.int64(2, self.calls_started)
  }
  if self.calls_succeeded != 0L {
    data.int64(3, self.calls_succeeded)
  }
  if self.calls_failed != 0L {
    data.int64(4, self.calls_failed)
  }
  match self.last_call_ms {
    Some(ms) => data.message_(5, timestamp_to_bytes(ms))
    None => ()
  }
  w.message_(2, data.to_bytes())
  for s in self.listen_sockets {
    w.message_(3, s.to_bytes())
  }
  w.to_bytes()
}

///|
fn Socket::to_bytes(self : Socket) -> Bytes {
  let w = @proto.PbWriter::new()
  w.message_(1, self.reference.to_bytes())
  let data = @proto.PbWriter::new()
  if self.streams_started != 0L {
    data.int64(1, self.streams_started)
  }
  if self.streams_succeeded != 0L {
    data.int64(2, self.streams_succeeded)
  }
  if self.streams_failed != 0L {
    data.int64(3, self.streams_failed)
  }
  if self.messages_sent != 0L {
    data.int64(4, self.messages_sent)
  }
  if self.messages_received != 0L {
    data.int64(5, self.messages_received)
  }
  w.message_(2, data.to_bytes())
  if self.address != "" {
    w.message_(3, address_to_bytes(self.address))
  }
  w.to_bytes()
}

///|
/// An `Address` with a `tcpip_address`: the host as four octets when it is a dotted
/// quad, and the port. A host that is not an IPv4 literal keeps an empty address and
/// the port, which is what a name-resolved target looks like.
fn address_to_bytes(address : String) -> Bytes {
  let (host, port) = split_host_port(address)
  let tcp = @proto.PbWriter::new()
  match ipv4(host) {
    Some(ip) => tcp.bytes_(1, ip)
    None => ()
  }
  tcp.int32(2, port)
  let w = @proto.PbWriter::new()
  w.message_(1, tcp.to_bytes())
  w.to_bytes()
}

///|
fn split_host_port(address : String) -> (String, Int32) {
  let mut cut = -1
  let mut i = 0
  for ch in address {
    if ch == ':' {
      cut = i
    }
    i = i + 1
  }
  if cut < 0 {
    return (address, 0)
  }
  let host = address.exact_view(end=cut).to_owned()
  let port_text = address.exact_view(start=cut + 1).to_owned()
  let port = @string.parse_int(port_text[:]) catch { _ => 0 }
  (host, port)
}

///|
fn ipv4(host : String) -> Bytes? {
  let out = @buffer.Buffer()
  let mut value = 0
  let mut digits = 0
  for ch in host {
    if ch == '.' {
      if digits == 0 || value > 255 {
        return None
      }
      out.write_byte(value.to_byte())
      value = 0
      digits = 0
    } else {
      let d = ch.to_int() - '0'.to_int()
      if d < 0 || d > 9 {
        return None
      }
      value = value * 10 + d
      digits = digits + 1
      if value > 255 {
        return None
      }
    }
  }
  if digits == 0 || value > 255 {
    return None
  }
  out.write_byte(value.to_byte())
  if out.length() == 4 {
    Some(out.to_bytes())
  } else {
    None
  }
}

// -- requests ---------------------------------------------------------------

///|
pub(all) struct GetTopChannelsRequest {
  start_channel_id : Int64
  max_results : Int64
}

///|
pub impl @proto.Message for GetTopChannelsRequest with fn encode(self) {
  let w = @proto.PbWriter::new()
  if self.start_channel_id != 0L {
    w.int64(1, self.start_channel_id)
  }
  if self.max_results != 0L {
    w.int64(2, self.max_results)
  }
  w.to_bytes()
}

///|
pub impl @proto.Message for GetTopChannelsRequest with fn decode(b) {
  let r = @proto.PbReader::new(b)
  let start : Ref[Int64] = Ref(0L)
  let max : Ref[Int64] = Ref(0L)
  while !r.eof() {
    match r.read_tag() {
      (1, Varint) => start.val = r.read_int64()
      (2, Varint) => max.val = r.read_int64()
      (_, wire) => r.skip(wire)
    }
  }
  { start_channel_id: start.val, max_results: max.val, }
}

///|
pub(all) struct GetServersRequest {
  start_server_id : Int64
  max_results : Int64
}

///|
pub impl @proto.Message for GetServersRequest with fn encode(self) {
  let w = @proto.PbWriter::new()
  if self.start_server_id != 0L {
    w.int64(1, self.start_server_id)
  }
  if self.max_results != 0L {
    w.int64(2, self.max_results)
  }
  w.to_bytes()
}

///|
pub impl @proto.Message for GetServersRequest with fn decode(b) {
  let r = @proto.PbReader::new(b)
  let start : Ref[Int64] = Ref(0L)
  let max : Ref[Int64] = Ref(0L)
  while !r.eof() {
    match r.read_tag() {
      (1, Varint) => start.val = r.read_int64()
      (2, Varint) => max.val = r.read_int64()
      (_, wire) => r.skip(wire)
    }
  }
  { start_server_id: start.val, max_results: max.val, }
}

///|
pub(all) struct GetServerRequest {
  server_id : Int64
}

///|
pub impl @proto.Message for GetServerRequest with fn encode(self) {
  let w = @proto.PbWriter::new()
  if self.server_id != 0L {
    w.int64(1, self.server_id)
  }
  w.to_bytes()
}

///|
pub impl @proto.Message for GetServerRequest with fn decode(b) {
  let r = @proto.PbReader::new(b)
  let id : Ref[Int64] = Ref(0L)
  while !r.eof() {
    match r.read_tag() {
      (1, Varint) => id.val = r.read_int64()
      (_, wire) => r.skip(wire)
    }
  }
  { server_id: id.val, }
}

///|
pub(all) struct GetServerSocketsRequest {
  server_id : Int64
  start_socket_id : Int64
  max_results : Int64
}

///|
pub impl @proto.Message for GetServerSocketsRequest with fn encode(self) {
  let w = @proto.PbWriter::new()
  if self.server_id != 0L {
    w.int64(1, self.server_id)
  }
  if self.start_socket_id != 0L {
    w.int64(2, self.start_socket_id)
  }
  if self.max_results != 0L {
    w.int64(3, self.max_results)
  }
  w.to_bytes()
}

///|
pub impl @proto.Message for GetServerSocketsRequest with fn decode(b) {
  let r = @proto.PbReader::new(b)
  let server : Ref[Int64] = Ref(0L)
  let start : Ref[Int64] = Ref(0L)
  let max : Ref[Int64] = Ref(0L)
  while !r.eof() {
    match r.read_tag() {
      (1, Varint) => server.val = r.read_int64()
      (2, Varint) => start.val = r.read_int64()
      (3, Varint) => max.val = r.read_int64()
      (_, wire) => r.skip(wire)
    }
  }
  { server_id: server.val, start_socket_id: start.val, max_results: max.val, }
}

///|
pub(all) struct GetChannelRequest {
  channel_id : Int64
}

///|
pub impl @proto.Message for GetChannelRequest with fn encode(self) {
  let w = @proto.PbWriter::new()
  if self.channel_id != 0L {
    w.int64(1, self.channel_id)
  }
  w.to_bytes()
}

///|
pub impl @proto.Message for GetChannelRequest with fn decode(b) {
  let r = @proto.PbReader::new(b)
  let id : Ref[Int64] = Ref(0L)
  while !r.eof() {
    match r.read_tag() {
      (1, Varint) => id.val = r.read_int64()
      (_, wire) => r.skip(wire)
    }
  }
  { channel_id: id.val, }
}

///|
pub(all) struct GetSubchannelRequest {
  subchannel_id : Int64
}

///|
pub impl @proto.Message for GetSubchannelRequest with fn encode(self) {
  let w = @proto.PbWriter::new()
  if self.subchannel_id != 0L {
    w.int64(1, self.subchannel_id)
  }
  w.to_bytes()
}

///|
pub impl @proto.Message for GetSubchannelRequest with fn decode(b) {
  let r = @proto.PbReader::new(b)
  let id : Ref[Int64] = Ref(0L)
  while !r.eof() {
    match r.read_tag() {
      (1, Varint) => id.val = r.read_int64()
      (_, wire) => r.skip(wire)
    }
  }
  { subchannel_id: id.val, }
}

///|
pub(all) struct GetSocketRequest {
  socket_id : Int64
  summary : Bool
}

///|
pub impl @proto.Message for GetSocketRequest with fn encode(self) {
  let w = @proto.PbWriter::new()
  if self.socket_id != 0L {
    w.int64(1, self.socket_id)
  }
  if self.summary {
    w.bool_(2, true)
  }
  w.to_bytes()
}

///|
pub impl @proto.Message for GetSocketRequest with fn decode(b) {
  let r = @proto.PbReader::new(b)
  let id : Ref[Int64] = Ref(0L)
  let summary : Ref[Bool] = Ref(false)
  while !r.eof() {
    match r.read_tag() {
      (1, Varint) => id.val = r.read_int64()
      (2, Varint) => summary.val = r.read_bool()
      (_, wire) => r.skip(wire)
    }
  }
  { socket_id: id.val, summary: summary.val, }
}

// -- responses --------------------------------------------------------------

///|
pub(all) struct GetTopChannelsResponse {
  channel : Array[Channel]
  is_end : Bool
}

///|
pub impl @proto.Message for GetTopChannelsResponse with fn encode(self) {
  let w = @proto.PbWriter::new()
  for c in self.channel {
    w.message_(1, c.to_bytes())
  }
  if self.is_end {
    w.bool_(2, true)
  }
  w.to_bytes()
}

///|
pub impl @proto.Message for GetTopChannelsResponse with fn decode(_b) {
  { channel: [], is_end: false, }
}

///|
pub(all) struct GetServersResponse {
  server : Array[Server]
  is_end : Bool
}

///|
pub impl @proto.Message for GetServersResponse with fn encode(self) {
  let w = @proto.PbWriter::new()
  for s in self.server {
    w.message_(1, s.to_bytes())
  }
  if self.is_end {
    w.bool_(2, true)
  }
  w.to_bytes()
}

///|
pub impl @proto.Message for GetServersResponse with fn decode(_b) {
  { server: [], is_end: false, }
}

///|
pub(all) struct GetServerResponse {
  server : Server
}

///|
pub impl @proto.Message for GetServerResponse with fn encode(self) {
  let w = @proto.PbWriter::new()
  w.message_(1, self.server.to_bytes())
  w.to_bytes()
}

///|
pub impl @proto.Message for GetServerResponse with fn decode(_b) {
  { server: Server::empty(), }
}

///|
pub(all) struct GetServerSocketsResponse {
  socket_ref : Array[SocketRef]
  is_end : Bool
}

///|
pub impl @proto.Message for GetServerSocketsResponse with fn encode(self) {
  let w = @proto.PbWriter::new()
  for s in self.socket_ref {
    w.message_(1, s.to_bytes())
  }
  if self.is_end {
    w.bool_(2, true)
  }
  w.to_bytes()
}

///|
pub impl @proto.Message for GetServerSocketsResponse with fn decode(_b) {
  { socket_ref: [], is_end: false, }
}

///|
pub(all) struct GetChannelResponse {
  channel : Channel
}

///|
pub impl @proto.Message for GetChannelResponse with fn encode(self) {
  let w = @proto.PbWriter::new()
  w.message_(1, self.channel.to_bytes())
  w.to_bytes()
}

///|
pub impl @proto.Message for GetChannelResponse with fn decode(_b) {
  { channel: Channel::empty(), }
}

///|
pub(all) struct GetSubchannelResponse {
  subchannel : Subchannel
}

///|
pub impl @proto.Message for GetSubchannelResponse with fn encode(self) {
  let w = @proto.PbWriter::new()
  w.message_(1, self.subchannel.to_bytes())
  w.to_bytes()
}

///|
pub impl @proto.Message for GetSubchannelResponse with fn decode(_b) {
  { subchannel: Subchannel::empty(), }
}

///|
pub(all) struct GetSocketResponse {
  socket : Socket
}

///|
pub impl @proto.Message for GetSocketResponse with fn encode(self) {
  let w = @proto.PbWriter::new()
  w.message_(1, self.socket.to_bytes())
  w.to_bytes()
}

///|
pub impl @proto.Message for GetSocketResponse with fn decode(_b) {
  { socket: Socket::empty(), }
}

///|
pub extend GetTopChannelsRequest with @proto.Message::{encode, decode}

///|
pub extend GetServersRequest with @proto.Message::{encode, decode}

///|
pub extend GetServerRequest with @proto.Message::{encode, decode}

///|
pub extend GetServerSocketsRequest with @proto.Message::{encode, decode}

///|
pub extend GetChannelRequest with @proto.Message::{encode, decode}

///|
pub extend GetSubchannelRequest with @proto.Message::{encode, decode}

///|
pub extend GetSocketRequest with @proto.Message::{encode, decode}

///|
pub extend GetTopChannelsResponse with @proto.Message::{encode, decode}

///|
pub extend GetServersResponse with @proto.Message::{encode, decode}

///|
pub extend GetServerResponse with @proto.Message::{encode, decode}

///|
pub extend GetServerSocketsResponse with @proto.Message::{encode, decode}

///|
pub extend GetChannelResponse with @proto.Message::{encode, decode}

///|
pub extend GetSubchannelResponse with @proto.Message::{encode, decode}

///|
pub extend GetSocketResponse with @proto.Message::{encode, decode}
