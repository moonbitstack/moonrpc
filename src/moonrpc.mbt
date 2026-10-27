// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The façade: every subpackage's public surface re-exported as it was, so
// `@moonrpc.X` is still the X it was before the split. A program that wants only
// one layer imports that subpackage and links nothing else. Enum constructors
// do not travel through `pub using`, so a match on one names its subpackage:
// `@wire.Status::Ok`, not `@moonrpc.Status::Ok`.

///|
pub using @wire {
  type Keepalive,
  type Method,
  type Status,
  decode_message,
  default_max_frame_size,
  default_window_size,
  encode_message,
  is_binary_metadata,
  max_header_list_size,
  max_message_size,
  message_len,
  metadata_value_from_wire,
  metadata_value_to_wire,
  split_messages,
}

///|
pub using @proto {
  type FieldDescriptor,
  type FieldLabel,
  type FieldType,
  type FileDescriptor,
  type MessageDescriptor,
  type MethodDescriptor,
  type PbError,
  type PbReader,
  type PbWriter,
  type ServiceDescriptor,
  type WireType,
  decode_file_descriptor_set,
  encode_file_descriptor_set,
}

///|
pub using @stream {
  type BidiHandler,
  type Handler,
  type RpcContext,
  type Stream,
  type StreamError,
  type StreamEvent,
  type StreamState,
  parse_grpc_timeout,
  stream_id_valid_for_initiator,
  stream_is_client_initiated,
  stream_is_server_initiated,
}

///|
pub using @balance {
  type ConnectionPool,
  type ConnectivityState,
  type DnsRecord,
  type DnsResponse,
  type Attempts,
  type Hedging,
  type LbPolicy,
  type LoadBalancer,
  type Pushback,
  type Retry,
  type SubConn,
  type Throttle,
  type Throttling,
  dns_decode_response,
  dns_encode_query,
  dns_type_a,
  dns_type_aaaa,
  hedging,
  limit,
  retry,
}

///|
pub using @client {
  type CallReply,
  type ClientCall,
  type H2Client,
  encode_grpc_timeout,
  percent_decode,
}

///|
pub using @server {
  type H2Server,
  type SrvStream,
  type StreamInterceptor,
  type UnaryInterceptor,
  default_max_streams,
}

///|
pub using @service {
  type HealthService,
  type ReflectionRequest,
  type ReflectionResponse,
  type ReflectionService,
  type ServingStatus,
  decode_health_request,
  decode_health_response,
  decode_reflection_request,
  decode_reflection_response,
  encode_health_request,
  encode_health_response,
  encode_reflection_request,
  health_check_path,
  health_watch_path,
  reflection_v1_path,
  reflection_v1alpha_path,
}
