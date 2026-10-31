///|
/// The status and message an error a typed handler raised is answered with:
/// a `StatusError` keeps its own, anything else is `UNKNOWN`, as in grpc-go.
fn status_of(e : Error) -> (Int32, String) {
  match e {
    @wire.StatusError(status, message) => (status.code(), message)
    e => (@wire.Status::Unknown.code(), e.to_string())
  }
}

///|
/// The request, or `None` once the call has been failed with `INTERNAL` because
/// it does not decode, as grpc-go answers an unmarshalling error.
fn[I : @proto.Message] request(ctx : @stream.RpcContext, body : Bytes) -> I? {
  Some(I::decode(body)) catch {
    e => {
      ctx.fail(
        @wire.Status::Internal.code(),
        "grpc: error unmarshalling request: \{e}",
      )
      None
    }
  }
}

///|
/// A unary handler over message types: the request decoded, the reply encoded,
/// an error raised by `f` answered with its status.
pub fn[I : @proto.Message, O : @proto.Message] unary(
  f : (@stream.RpcContext, I) -> O raise,
) -> @stream.Handler {
  Unary((ctx, body) => {
    guard request(ctx, body) is Some(input) else { return b"" }
    O::encode(f(ctx, input)) catch {
      e => {
        let (code, message) = status_of(e)
        ctx.fail(code, message)
        b""
      }
    }
  })
}

///|
/// A server-streaming handler over message types: each reply encoded in turn.
pub fn[I : @proto.Message, O : @proto.Message] server_streaming(
  f : (@stream.RpcContext, I) -> Array[O] raise,
) -> @stream.Handler {
  ServerStreaming((ctx, body) => {
    guard request(ctx, body) is Some(input) else { return [] }
    f(ctx, input).map(O::encode) catch {
      e => {
        let (code, message) = status_of(e)
        ctx.fail(code, message)
        []
      }
    }
  })
}

///|
/// A client-streaming handler over message types: every request decoded, one
/// reply encoded.
pub fn[I : @proto.Message, O : @proto.Message] client_streaming(
  f : (@stream.RpcContext, Array[I]) -> O raise,
) -> @stream.Handler {
  ClientStreaming((ctx, bodies) => {
    let inputs = []
    for body in bodies {
      guard request(ctx, body) is Some(input) else { return b"" }
      inputs.push(input)
    }
    O::encode(f(ctx, inputs)) catch {
      e => {
        let (code, message) = status_of(e)
        ctx.fail(code, message)
        b""
      }
    }
  })
}

///|
/// A bidirectional-streaming handler over message types that answers once the
/// client half-closes: every request decoded, the replies encoded in order.
pub fn[I : @proto.Message, O : @proto.Message] bidi(
  f : (@stream.RpcContext, Array[I]) -> Array[O] raise,
) -> @stream.Handler {
  Bidi(ctx => {
    let inputs = []
    let mut broken = false
    {
      on_message: body => {
        if !broken {
          match request(ctx, body) {
            Some(input) => inputs.push(input)
            None => broken = true
          }
        }
        []
      },
      on_end: () => {
        if broken {
          return []
        }
        f(ctx, inputs).map(O::encode) catch {
          e => {
            let (code, message) = status_of(e)
            ctx.fail(code, message)
            []
          }
        }
      },
    }
  })
}

///|
/// A bidirectional-streaming handler over message types that answers as each
/// request arrives: `f` gives the replies to one request, sent at once, and
/// `end` the replies to send when the client half-closes.
pub fn[I : @proto.Message, O : @proto.Message] bidi_each(
  f : (@stream.RpcContext, I) -> Array[O] raise,
  end? : (@stream.RpcContext) -> Array[O] raise,
) -> @stream.Handler {
  Bidi(ctx => {
    let mut broken = false
    let answer = (replies : () -> Array[O] raise) => {
      if broken {
        return []
      }
      replies().map(O::encode) catch {
        e => {
          broken = true
          let (code, message) = status_of(e)
          ctx.fail(code, message)
          []
        }
      }
    }
    {
      on_message: body => {
        if broken {
          return []
        }
        match request(ctx, body) {
          Some(input) => answer(() => f(ctx, input))
          None => {
            broken = true
            []
          }
        }
      },
      on_end: () => {
        match end {
          Some(g) => answer(() => g(ctx))
          None => []
        }
      },
    }
  })
}
