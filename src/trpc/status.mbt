// `TrpcRetCode`: the framework's own return codes, and how each reads as a gRPC status so
// a caller of either protocol can be told the same thing.

///|
/// `TRPC_INVOKE_SUCCESS`.
pub let ret_success : Int32 = 0

///|
/// `TRPC_SERVER_DECODE_ERR`: the server could not read the request.
pub let ret_server_decode : Int32 = 1

///|
/// `TRPC_SERVER_ENCODE_ERR`: the server could not write the reply.
pub let ret_server_encode : Int32 = 2

///|
/// `TRPC_SERVER_NOSERVICE_ERR`: no service answers on the path.
pub let ret_server_noservice : Int32 = 11

///|
/// `TRPC_SERVER_NOFUNC_ERR`: the service is there, the method is not.
pub let ret_server_nofunc : Int32 = 12

///|
/// `TRPC_SERVER_TIMEOUT_ERR`.
pub let ret_server_timeout : Int32 = 21

///|
/// `TRPC_SERVER_OVERLOAD_ERR`.
pub let ret_server_overload : Int32 = 22

///|
/// `TRPC_SERVER_LIMITED_ERR`.
pub let ret_server_limited : Int32 = 23

///|
/// `TRPC_SERVER_SYSTEM_ERR`.
pub let ret_server_system : Int32 = 31

///|
/// `TRPC_SERVER_AUTH_ERR`.
pub let ret_server_auth : Int32 = 41

///|
/// `TRPC_SERVER_VALIDATE_ERR`.
pub let ret_server_validate : Int32 = 51

///|
/// `TRPC_CLIENT_INVOKE_TIMEOUT_ERR`.
pub let ret_client_timeout : Int32 = 101

///|
/// `TRPC_CLIENT_CONNECT_ERR`.
pub let ret_client_connect : Int32 = 111

///|
/// `TRPC_CLIENT_CANCELED_ERR`.
pub let ret_client_canceled : Int32 = 161

///|
/// `TRPC_INVOKE_UNKNOWN_ERR`.
pub let ret_unknown : Int32 = 999

///|
/// The gRPC status a `ret` code corresponds to, so a caller that speaks both protocols
/// gets one reason for one failure. Codes with no closer counterpart are `Unknown`, which
/// is what gRPC reserves for exactly that.
pub fn ret_status(ret : Int32) -> @wire.Status {
  match ret {
    0 => @wire.Status::Ok
    1 => @wire.Status::Internal
    2 => @wire.Status::Internal
    11 => @wire.Status::Unimplemented
    12 => @wire.Status::Unimplemented
    21 => @wire.Status::DeadlineExceeded
    22 => @wire.Status::ResourceExhausted
    23 => @wire.Status::ResourceExhausted
    31 => @wire.Status::Internal
    41 => @wire.Status::Unauthenticated
    51 => @wire.Status::InvalidArgument
    101 => @wire.Status::DeadlineExceeded
    111 => @wire.Status::Unavailable
    161 => @wire.Status::Cancelled
    _ => @wire.Status::Unknown
  }
}

///|
/// The `ret` code a gRPC status becomes when a handler ends a call with it. A failure a
/// handler chose is a business failure, so it travels in `func_ret`; this is the code the
/// framework itself reports when it cannot deliver the call at all.
pub fn status_ret(status : @wire.Status) -> Int32 {
  match status {
    @wire.Status::Ok => ret_success
    @wire.Status::Cancelled => ret_client_canceled
    @wire.Status::InvalidArgument => ret_server_validate
    @wire.Status::DeadlineExceeded => ret_server_timeout
    @wire.Status::ResourceExhausted => ret_server_limited
    @wire.Status::Unauthenticated => ret_server_auth
    @wire.Status::Unimplemented => ret_server_nofunc
    @wire.Status::Unavailable => ret_client_connect
    _ => ret_server_system
  }
}
