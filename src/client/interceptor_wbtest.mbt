// The client chain on its own, with no socket: what an interceptor may change on the way
// in, what it sees on the way back, and the order the chain runs in.

///|
/// A reply carrying `grpc_status` and one message, so a test can tell replies apart.
fn reply_of(status : Int32, message : Bytes) -> CallReply {
  {
    status: b"200",
    grpc_status: status,
    grpc_message: "",
    headers: [],
    messages: [message],
    trailers: [],
    committed: true,
    unprocessed: false,
  }
}

///|
async test "client interceptors: an empty chain is the call unchanged" {
  let called : Array[String] = []
  let base : async (Invocation) -> CallReply = invocation => {
    called.push(invocation.path)
    reply_of(0, invocation.requests[0])
  }
  let chain = intercepted([], base)
  let reply = chain({
    path: "/echo.Echo/Say",
    requests: [b"hi"],
    metadata: [],
    timeout_millis: None,
    retry: None,
    wait_for_ready: false,
  })
  assert_eq(reply.grpc_status, 0)
  assert_eq(reply.messages, [b"hi"])
  assert_eq(called, ["/echo.Echo/Say"])
}

///|
async test "client interceptors: the first registered is the outermost" {
  let order : Array[String] = []
  let base : async (Invocation) -> CallReply = invocation => {
    reply_of(0, invocation.requests[0])
  }
  let outer : Interceptor = (invocation, next) => {
    order.push("outer-in")
    let reply = next(invocation)
    order.push("outer-out")
    reply
  }
  let inner : Interceptor = (invocation, next) => {
    order.push("inner-in")
    let reply = next(invocation)
    order.push("inner-out")
    reply
  }
  let chain = intercepted([outer, inner], base)
  ignore(
    chain({
      path: "/echo.Echo/Say",
      requests: [b"x"],
      metadata: [],
      timeout_millis: None,
      retry: None,
      wait_for_ready: false,
    }),
  )
  assert_eq(order, ["outer-in", "inner-in", "inner-out", "outer-out"])
}

///|
async test "client interceptors: the invocation can be changed on the way in" {
  let seen : Array[String] = []
  let base : async (Invocation) -> CallReply = invocation => {
    seen.push(@utf8.decode_lossy(invocation.metadata[0].value[:]))
    seen.push(invocation.timeout_millis.unwrap_or(-1).to_string())
    reply_of(0, invocation.requests[0])
  }
  let adder : Interceptor = (invocation, next) => {
    let metadata = invocation.metadata.copy()
    metadata.push({ name: b"authorization", value: b"Bearer t", })
    next({ ..invocation, metadata, timeout_millis: Some(250), })
  }
  let chain = intercepted([adder], base)
  ignore(
    chain({
      path: "/echo.Echo/Say",
      requests: [b"x"],
      metadata: [],
      timeout_millis: None,
      retry: None,
      wait_for_ready: false,
    }),
  )
  assert_eq(seen, ["Bearer t", "250"])
}

///|
async test "client interceptors: an interceptor may answer without calling next" {
  let reached = []
  let base : async (Invocation) -> CallReply = invocation => {
    reached.push(invocation.path)
    reply_of(0, b"never")
  }
  let refuse : Interceptor = (_invocation, _next) => reply_of(16, b"denied")
  let chain = intercepted([refuse], base)
  let reply = chain({
    path: "/echo.Echo/Say",
    requests: [b"x"],
    metadata: [],
    timeout_millis: None,
    retry: None,
    wait_for_ready: false,
  })
  assert_eq(reply.grpc_status, 16)
  assert_eq(reply.messages, [b"denied"])
  assert_eq(reached.length(), 0)
}

///|
async test "client interceptors: the reply can be changed on the way back" {
  let base : async (Invocation) -> CallReply = invocation => {
    reply_of(0, invocation.requests[0])
  }
  let doubler : Interceptor = (invocation, next) => {
    let reply = next(invocation)
    { ..reply, messages: reply.messages.map(m => m + m), }
  }
  let chain = intercepted([doubler], base)
  let reply = chain({
    path: "/echo.Echo/Say",
    requests: [b"ab"],
    metadata: [],
    timeout_millis: None,
    retry: None,
    wait_for_ready: false,
  })
  assert_eq(reply.messages, [b"abab"])
}
