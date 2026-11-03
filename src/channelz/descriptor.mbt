// The descriptor of grpc/channelz/v1/channelz.proto, field for field with the
// canonical file, so reflection lists and describes the service exactly as a
// channelz client expects. The message codecs are in `messages.mbt`; this file is
// the schema alone.

///|
fn f(
  name : String,
  number : Int32,
  type_ : @proto.FieldType,
  label~ : @proto.FieldLabel = @proto.LabelOptional,
  type_name~ : String = "",
  oneof? : Int32,
  optional~ : Bool = false,
) -> @proto.FieldDescriptor {
  @proto.FieldDescriptor::new(
    name,
    number,
    type_,
    label~,
    type_name~,
    oneof_index?=oneof,
    proto3_optional=optional,
  )
}

///|
fn m(
  name : String,
  fields : Array[@proto.FieldDescriptor],
  nested~ : Array[@proto.MessageDescriptor] = [],
  enums~ : Array[@proto.EnumDescriptor] = [],
  oneofs~ : Array[String] = [],
) -> @proto.MessageDescriptor {
  @proto.MessageDescriptor::new(name, fields, nested~, enums~, oneofs~)
}

///|
fn e(
  name : String,
  values : Array[@proto.EnumValueDescriptor],
) -> @proto.EnumDescriptor {
  { name, values, }
}

///|
fn v(name : String, number : Int32) -> @proto.EnumValueDescriptor {
  { name, number, }
}

///|
fn channel_ref() -> @proto.MessageDescriptor {
  m("ChannelRef", [
    f("channel_id", 1, @proto.TypeInt64),
    f("name", 2, @proto.TypeString),
  ])
}

///|
fn subchannel_ref() -> @proto.MessageDescriptor {
  m("SubchannelRef", [
    f("subchannel_id", 7, @proto.TypeInt64),
    f("name", 8, @proto.TypeString),
  ])
}

///|
fn socket_ref() -> @proto.MessageDescriptor {
  m("SocketRef", [
    f("socket_id", 3, @proto.TypeInt64),
    f("name", 4, @proto.TypeString),
  ])
}

///|
fn server_ref() -> @proto.MessageDescriptor {
  m("ServerRef", [
    f("server_id", 5, @proto.TypeInt64),
    f("name", 6, @proto.TypeString),
  ])
}

///|
fn connectivity_state() -> @proto.MessageDescriptor {
  m(
    "ChannelConnectivityState",
    [
      f(
        "state",
        1,
        @proto.TypeEnum,
        type_name=".grpc.channelz.v1.ChannelConnectivityState.State",
      ),
    ],
    enums=[
      e("State", [
        v("UNKNOWN", 0),
        v("IDLE", 1),
        v("CONNECTING", 2),
        v("READY", 3),
        v("TRANSIENT_FAILURE", 4),
        v("SHUTDOWN", 5),
      ]),
    ],
  )
}

///|
fn trace_event() -> @proto.MessageDescriptor {
  m(
    "ChannelTraceEvent",
    [
      f("description", 1, @proto.TypeString),
      f(
        "severity",
        2,
        @proto.TypeEnum,
        type_name=".grpc.channelz.v1.ChannelTraceEvent.Severity",
      ),
      f(
        "timestamp",
        3,
        @proto.TypeMessage,
        type_name=".google.protobuf.Timestamp",
      ),
      f(
        "channel_ref",
        4,
        @proto.TypeMessage,
        type_name=".grpc.channelz.v1.ChannelRef",
        oneof=0,
      ),
      f(
        "subchannel_ref",
        5,
        @proto.TypeMessage,
        type_name=".grpc.channelz.v1.SubchannelRef",
        oneof=0,
      ),
    ],
    enums=[
      e("Severity", [
        v("CT_UNKNOWN", 0),
        v("CT_INFO", 1),
        v("CT_WARNING", 2),
        v("CT_ERROR", 3),
      ]),
    ],
    oneofs=["child_ref"],
  )
}

///|
fn channel_trace() -> @proto.MessageDescriptor {
  m("ChannelTrace", [
    f("num_events_logged", 1, @proto.TypeInt64),
    f(
      "creation_timestamp",
      2,
      @proto.TypeMessage,
      type_name=".google.protobuf.Timestamp",
    ),
    f(
      "events",
      3,
      @proto.TypeMessage,
      label=@proto.LabelRepeated,
      type_name=".grpc.channelz.v1.ChannelTraceEvent",
    ),
  ])
}

///|
fn channel_data() -> @proto.MessageDescriptor {
  m("ChannelData", [
    f(
      "state",
      1,
      @proto.TypeMessage,
      type_name=".grpc.channelz.v1.ChannelConnectivityState",
    ),
    f("target", 2, @proto.TypeString),
    f(
      "trace",
      3,
      @proto.TypeMessage,
      type_name=".grpc.channelz.v1.ChannelTrace",
    ),
    f("calls_started", 4, @proto.TypeInt64),
    f("calls_succeeded", 5, @proto.TypeInt64),
    f("calls_failed", 6, @proto.TypeInt64),
    f(
      "last_call_started_timestamp",
      7,
      @proto.TypeMessage,
      type_name=".google.protobuf.Timestamp",
    ),
    f("max_connections_per_subchannel", 8, @proto.TypeUint32),
  ])
}

///|
fn channel() -> @proto.MessageDescriptor {
  m("Channel", [
    f("ref", 1, @proto.TypeMessage, type_name=".grpc.channelz.v1.ChannelRef"),
    f("data", 2, @proto.TypeMessage, type_name=".grpc.channelz.v1.ChannelData"),
    f(
      "channel_ref",
      3,
      @proto.TypeMessage,
      label=@proto.LabelRepeated,
      type_name=".grpc.channelz.v1.ChannelRef",
    ),
    f(
      "subchannel_ref",
      4,
      @proto.TypeMessage,
      label=@proto.LabelRepeated,
      type_name=".grpc.channelz.v1.SubchannelRef",
    ),
    f(
      "socket_ref",
      5,
      @proto.TypeMessage,
      label=@proto.LabelRepeated,
      type_name=".grpc.channelz.v1.SocketRef",
    ),
  ])
}

///|
fn subchannel() -> @proto.MessageDescriptor {
  m("Subchannel", [
    f("ref", 1, @proto.TypeMessage, type_name=".grpc.channelz.v1.SubchannelRef"),
    f("data", 2, @proto.TypeMessage, type_name=".grpc.channelz.v1.ChannelData"),
    f(
      "channel_ref",
      3,
      @proto.TypeMessage,
      label=@proto.LabelRepeated,
      type_name=".grpc.channelz.v1.ChannelRef",
    ),
    f(
      "subchannel_ref",
      4,
      @proto.TypeMessage,
      label=@proto.LabelRepeated,
      type_name=".grpc.channelz.v1.SubchannelRef",
    ),
    f(
      "socket_ref",
      5,
      @proto.TypeMessage,
      label=@proto.LabelRepeated,
      type_name=".grpc.channelz.v1.SocketRef",
    ),
  ])
}

///|
fn server_data() -> @proto.MessageDescriptor {
  m("ServerData", [
    f(
      "trace",
      1,
      @proto.TypeMessage,
      type_name=".grpc.channelz.v1.ChannelTrace",
    ),
    f("calls_started", 2, @proto.TypeInt64),
    f("calls_succeeded", 3, @proto.TypeInt64),
    f("calls_failed", 4, @proto.TypeInt64),
    f(
      "last_call_started_timestamp",
      5,
      @proto.TypeMessage,
      type_name=".google.protobuf.Timestamp",
    ),
  ])
}

///|
fn server() -> @proto.MessageDescriptor {
  m("Server", [
    f("ref", 1, @proto.TypeMessage, type_name=".grpc.channelz.v1.ServerRef"),
    f("data", 2, @proto.TypeMessage, type_name=".grpc.channelz.v1.ServerData"),
    f(
      "listen_socket",
      3,
      @proto.TypeMessage,
      label=@proto.LabelRepeated,
      type_name=".grpc.channelz.v1.SocketRef",
    ),
  ])
}

///|
fn socket_data() -> @proto.MessageDescriptor {
  let ts = ".google.protobuf.Timestamp"
  m("SocketData", [
    f("streams_started", 1, @proto.TypeInt64),
    f("streams_succeeded", 2, @proto.TypeInt64),
    f("streams_failed", 3, @proto.TypeInt64),
    f("messages_sent", 4, @proto.TypeInt64),
    f("messages_received", 5, @proto.TypeInt64),
    f("keep_alives_sent", 6, @proto.TypeInt64),
    f(
      "last_local_stream_created_timestamp",
      7,
      @proto.TypeMessage,
      type_name=ts,
    ),
    f(
      "last_remote_stream_created_timestamp",
      8,
      @proto.TypeMessage,
      type_name=ts,
    ),
    f("last_message_sent_timestamp", 9, @proto.TypeMessage, type_name=ts),
    f("last_message_received_timestamp", 10, @proto.TypeMessage, type_name=ts),
    f(
      "local_flow_control_window",
      11,
      @proto.TypeMessage,
      type_name=".google.protobuf.Int64Value",
    ),
    f(
      "remote_flow_control_window",
      12,
      @proto.TypeMessage,
      type_name=".google.protobuf.Int64Value",
    ),
    f(
      "option",
      13,
      @proto.TypeMessage,
      label=@proto.LabelRepeated,
      type_name=".grpc.channelz.v1.SocketOption",
    ),
    f(
      "received_goaway_error",
      14,
      @proto.TypeMessage,
      type_name=".google.protobuf.UInt32Value",
    ),
    f("peer_max_concurrent_streams", 15, @proto.TypeUint32),
  ])
}

///|
fn address() -> @proto.MessageDescriptor {
  m(
    "Address",
    [
      f(
        "tcpip_address",
        1,
        @proto.TypeMessage,
        type_name=".grpc.channelz.v1.Address.TcpIpAddress",
        oneof=0,
      ),
      f(
        "uds_address",
        2,
        @proto.TypeMessage,
        type_name=".grpc.channelz.v1.Address.UdsAddress",
        oneof=0,
      ),
      f(
        "other_address",
        3,
        @proto.TypeMessage,
        type_name=".grpc.channelz.v1.Address.OtherAddress",
        oneof=0,
      ),
    ],
    nested=[
      m("TcpIpAddress", [
        f("ip_address", 1, @proto.TypeBytes),
        f("port", 2, @proto.TypeInt32),
      ]),
      m("UdsAddress", [f("filename", 1, @proto.TypeString)]),
      m("OtherAddress", [
        f("name", 1, @proto.TypeString),
        f("value", 2, @proto.TypeMessage, type_name=".google.protobuf.Any"),
      ]),
    ],
    oneofs=["address"],
  )
}

///|
fn security() -> @proto.MessageDescriptor {
  m(
    "Security",
    [
      f(
        "tls",
        1,
        @proto.TypeMessage,
        type_name=".grpc.channelz.v1.Security.Tls",
        oneof=0,
      ),
      f(
        "other",
        2,
        @proto.TypeMessage,
        type_name=".grpc.channelz.v1.Security.OtherSecurity",
        oneof=0,
      ),
    ],
    nested=[
      m(
        "Tls",
        [
          f("standard_name", 1, @proto.TypeString, oneof=0),
          f("other_name", 2, @proto.TypeString, oneof=0),
          f("local_certificate", 3, @proto.TypeBytes),
          f("remote_certificate", 4, @proto.TypeBytes),
        ],
        oneofs=["cipher_suite"],
      ),
      m("OtherSecurity", [
        f("name", 1, @proto.TypeString),
        f("value", 2, @proto.TypeMessage, type_name=".google.protobuf.Any"),
      ]),
    ],
    oneofs=["model"],
  )
}

///|
fn socket_option() -> @proto.MessageDescriptor {
  m("SocketOption", [
    f("name", 1, @proto.TypeString),
    f("value", 2, @proto.TypeString),
    f("additional", 3, @proto.TypeMessage, type_name=".google.protobuf.Any"),
  ])
}

///|
fn socket_option_timeout() -> @proto.MessageDescriptor {
  m("SocketOptionTimeout", [
    f("duration", 1, @proto.TypeMessage, type_name=".google.protobuf.Duration"),
  ])
}

///|
fn socket_option_linger() -> @proto.MessageDescriptor {
  m("SocketOptionLinger", [
    f("active", 1, @proto.TypeBool),
    f("duration", 2, @proto.TypeMessage, type_name=".google.protobuf.Duration"),
  ])
}

///|
fn socket_option_tcp_info() -> @proto.MessageDescriptor {
  let names = [
    "tcpi_state", "tcpi_ca_state", "tcpi_retransmits", "tcpi_probes", "tcpi_backoff",
    "tcpi_options", "tcpi_snd_wscale", "tcpi_rcv_wscale", "tcpi_rto", "tcpi_ato",
    "tcpi_snd_mss", "tcpi_rcv_mss", "tcpi_unacked", "tcpi_sacked", "tcpi_lost", "tcpi_retrans",
    "tcpi_fackets", "tcpi_last_data_sent", "tcpi_last_ack_sent", "tcpi_last_data_recv",
    "tcpi_last_ack_recv", "tcpi_pmtu", "tcpi_rcv_ssthresh", "tcpi_rtt", "tcpi_rttvar",
    "tcpi_snd_ssthresh", "tcpi_snd_cwnd", "tcpi_advmss", "tcpi_reordering",
  ]
  let fields : Array[@proto.FieldDescriptor] = []
  let mut number = 1
  for name in names {
    fields.push(f(name, number, @proto.TypeUint32))
    number = number + 1
  }
  m("SocketOptionTcpInfo", fields)
}

///|
fn socket() -> @proto.MessageDescriptor {
  m("Socket", [
    f("ref", 1, @proto.TypeMessage, type_name=".grpc.channelz.v1.SocketRef"),
    f("data", 2, @proto.TypeMessage, type_name=".grpc.channelz.v1.SocketData"),
    f("local", 3, @proto.TypeMessage, type_name=".grpc.channelz.v1.Address"),
    f("remote", 4, @proto.TypeMessage, type_name=".grpc.channelz.v1.Address"),
    f("security", 5, @proto.TypeMessage, type_name=".grpc.channelz.v1.Security"),
    f("remote_name", 6, @proto.TypeString),
  ])
}

///|
fn top_channels_request() -> @proto.MessageDescriptor {
  m("GetTopChannelsRequest", [
    f("start_channel_id", 1, @proto.TypeInt64),
    f("max_results", 2, @proto.TypeInt64),
  ])
}

///|
fn top_channels_response() -> @proto.MessageDescriptor {
  m("GetTopChannelsResponse", [
    f(
      "channel",
      1,
      @proto.TypeMessage,
      label=@proto.LabelRepeated,
      type_name=".grpc.channelz.v1.Channel",
    ),
    f("end", 2, @proto.TypeBool),
  ])
}

///|
fn servers_request() -> @proto.MessageDescriptor {
  m("GetServersRequest", [
    f("start_server_id", 1, @proto.TypeInt64),
    f("max_results", 2, @proto.TypeInt64),
  ])
}

///|
fn servers_response() -> @proto.MessageDescriptor {
  m("GetServersResponse", [
    f(
      "server",
      1,
      @proto.TypeMessage,
      label=@proto.LabelRepeated,
      type_name=".grpc.channelz.v1.Server",
    ),
    f("end", 2, @proto.TypeBool),
  ])
}

///|
fn server_request() -> @proto.MessageDescriptor {
  m("GetServerRequest", [f("server_id", 1, @proto.TypeInt64)])
}

///|
fn server_response() -> @proto.MessageDescriptor {
  m("GetServerResponse", [
    f("server", 1, @proto.TypeMessage, type_name=".grpc.channelz.v1.Server"),
  ])
}

///|
fn server_sockets_request() -> @proto.MessageDescriptor {
  m("GetServerSocketsRequest", [
    f("server_id", 1, @proto.TypeInt64),
    f("start_socket_id", 2, @proto.TypeInt64),
    f("max_results", 3, @proto.TypeInt64),
  ])
}

///|
fn server_sockets_response() -> @proto.MessageDescriptor {
  m("GetServerSocketsResponse", [
    f(
      "socket_ref",
      1,
      @proto.TypeMessage,
      label=@proto.LabelRepeated,
      type_name=".grpc.channelz.v1.SocketRef",
    ),
    f("end", 2, @proto.TypeBool),
  ])
}

///|
fn channel_request() -> @proto.MessageDescriptor {
  m("GetChannelRequest", [f("channel_id", 1, @proto.TypeInt64)])
}

///|
fn channel_response() -> @proto.MessageDescriptor {
  m("GetChannelResponse", [
    f("channel", 1, @proto.TypeMessage, type_name=".grpc.channelz.v1.Channel"),
  ])
}

///|
fn subchannel_request() -> @proto.MessageDescriptor {
  m("GetSubchannelRequest", [f("subchannel_id", 1, @proto.TypeInt64)])
}

///|
fn subchannel_response() -> @proto.MessageDescriptor {
  m("GetSubchannelResponse", [
    f(
      "subchannel",
      1,
      @proto.TypeMessage,
      type_name=".grpc.channelz.v1.Subchannel",
    ),
  ])
}

///|
fn socket_request() -> @proto.MessageDescriptor {
  m("GetSocketRequest", [
    f("socket_id", 1, @proto.TypeInt64),
    f("summary", 2, @proto.TypeBool),
  ])
}

///|
fn socket_response() -> @proto.MessageDescriptor {
  m("GetSocketResponse", [
    f("socket", 1, @proto.TypeMessage, type_name=".grpc.channelz.v1.Socket"),
  ])
}

///|
fn channelz_service() -> @proto.ServiceDescriptor {
  let methods : Array[@proto.MethodDescriptor] = [
    {
      name: "GetTopChannels",
      input_type: ".grpc.channelz.v1.GetTopChannelsRequest",
      output_type: ".grpc.channelz.v1.GetTopChannelsResponse",
      client_streaming: false,
      server_streaming: false,
    },
    {
      name: "GetServers",
      input_type: ".grpc.channelz.v1.GetServersRequest",
      output_type: ".grpc.channelz.v1.GetServersResponse",
      client_streaming: false,
      server_streaming: false,
    },
    {
      name: "GetServer",
      input_type: ".grpc.channelz.v1.GetServerRequest",
      output_type: ".grpc.channelz.v1.GetServerResponse",
      client_streaming: false,
      server_streaming: false,
    },
    {
      name: "GetServerSockets",
      input_type: ".grpc.channelz.v1.GetServerSocketsRequest",
      output_type: ".grpc.channelz.v1.GetServerSocketsResponse",
      client_streaming: false,
      server_streaming: false,
    },
    {
      name: "GetChannel",
      input_type: ".grpc.channelz.v1.GetChannelRequest",
      output_type: ".grpc.channelz.v1.GetChannelResponse",
      client_streaming: false,
      server_streaming: false,
    },
    {
      name: "GetSubchannel",
      input_type: ".grpc.channelz.v1.GetSubchannelRequest",
      output_type: ".grpc.channelz.v1.GetSubchannelResponse",
      client_streaming: false,
      server_streaming: false,
    },
    {
      name: "GetSocket",
      input_type: ".grpc.channelz.v1.GetSocketRequest",
      output_type: ".grpc.channelz.v1.GetSocketResponse",
      client_streaming: false,
      server_streaming: false,
    },
  ]
  { name: "Channelz", methods, }
}

///|
/// The `grpc/channelz/v1/channelz.proto` descriptor: every message, the two nested
/// enums, the three oneofs, and the seven methods of `Channelz`.
pub fn descriptor() -> @proto.FileDescriptor {
  @proto.FileDescriptor::new(
    "grpc/channelz/v1/channelz.proto",
    "grpc.channelz.v1",
    dependencies=[
      "google/protobuf/any.proto", "google/protobuf/duration.proto", "google/protobuf/timestamp.proto",
      "google/protobuf/wrappers.proto",
    ],
    messages=[
      channel(),
      subchannel(),
      connectivity_state(),
      channel_data(),
      trace_event(),
      channel_trace(),
      channel_ref(),
      subchannel_ref(),
      socket_ref(),
      server_ref(),
      server(),
      server_data(),
      socket(),
      socket_data(),
      address(),
      security(),
      socket_option(),
      socket_option_timeout(),
      socket_option_linger(),
      socket_option_tcp_info(),
      top_channels_request(),
      top_channels_response(),
      servers_request(),
      servers_response(),
      server_request(),
      server_response(),
      server_sockets_request(),
      server_sockets_response(),
      channel_request(),
      channel_response(),
      subchannel_request(),
      subchannel_response(),
      socket_request(),
      socket_response(),
    ],
    services=[channelz_service()],
  )
}
