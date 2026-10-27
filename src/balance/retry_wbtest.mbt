///|
fn ms(span : @moondate.Span?) -> Int64? {
  span.map(s => s.nanos / 1_000_000L)
}

///|
fn code(s : @wire.Status) -> Int32 {
  s.code()
}

///|
fn pushback(value : String) -> Array[@header.Header] {
  [@header.Header::of("grpc-retry-pushback-ms", value)]
}

///|
test "the preset is A6's example policy and jitter" {
  assert_eq(retry.backoff.attempts, 4)
  assert_eq(retry.backoff.base.nanos / 1_000_000L, 100L)
  assert_eq(retry.backoff.cap.nanos / 1_000_000L, 1000L)
  assert_eq(retry.backoff.factor, 2.0)
  assert_eq(retry.backoff.jitter, Spread(0.2))
  assert_eq(retry.codes, [Unavailable])
  assert_eq(limit, 5)
}

///|
test "three ways to write a policy are one value" {
  let named = Retry::new(attempts=3)
  let updated = { ..retry, backoff: { ..retry.backoff, attempts: 3, }, }
  assert_eq(named, updated)
  assert_eq(Retry::new(codes=[Aborted]), { ..retry, codes: [Aborted], })
  assert_eq(Retry::new(), retry)
}

///|
test "a retryable status is retried until the attempts run out" {
  let a = Attempts::new(retry~)
  let unavailable = code(Unavailable)
  // The roll sits mid-spread, so each wait is the schedule itself.
  assert_eq(ms(a.next(unavailable, [])), Some(100L))
  assert_eq(ms(a.next(unavailable, [])), Some(200L))
  assert_eq(ms(a.next(unavailable, [])), Some(400L))
  assert_eq(a.made(), 4)
  assert_eq(a.next(unavailable, []), None)
}

///|
test "the jitter spreads a fifth either way" {
  assert_eq(
    ms(Attempts::new(retry~).next(code(Unavailable), [], roll=0.0)),
    Some(80L),
  )
  assert_eq(
    ms(Attempts::new(retry~).next(code(Unavailable), [], roll=0.999)),
    Some(119L),
  )
}

///|
test "OK, a status outside the codes, and no policy all end the call" {
  assert_eq(Attempts::new(retry~).next(0, []), None)
  assert_eq(Attempts::new(retry~).next(code(NotFound), []), None)
  assert_eq(Attempts::new().next(code(Unavailable), []), None)
}

///|
test "the client limit caps a policy that asks for more" {
  let greedy = Retry::new(attempts=9)
  let a = Attempts::new(retry=greedy)
  for _ in 0..<4 {
    assert_true(a.next(code(Unavailable), []) is Some(_))
  }
  assert_eq(a.made(), 5)
  assert_eq(a.next(code(Unavailable), []), None)
  // A lower limit binds the same way.
  let b = Attempts::new(retry=greedy, limit=2)
  assert_true(b.next(code(Unavailable), []) is Some(_))
  assert_eq(b.next(code(Unavailable), []), None)
}

///|
test "a committed call is never retried" {
  let a = Attempts::new(retry~)
  assert_eq(a.next(code(Unavailable), [], committed=true), None)
  // Not even transparently.
  let b = Attempts::new(retry~)
  assert_eq(
    b.next(code(Unavailable), [], committed=true, unprocessed=true),
    None,
  )
}

///|
test "an unprocessed call is retried once at once, policy or not, uncounted" {
  let a = Attempts::new()
  assert_eq(ms(a.next(code(Unavailable), [], unprocessed=true)), Some(0L))
  assert_eq(a.made(), 1)
  // The second refusal goes to the policy, and there is none.
  assert_eq(a.next(code(Unavailable), [], unprocessed=true), None)
  let b = Attempts::new(retry~)
  assert_eq(ms(b.next(code(Unavailable), [], unprocessed=true)), Some(0L))
  assert_eq(ms(b.next(code(Unavailable), [], unprocessed=true)), Some(100L))
  assert_eq(b.made(), 2)
}

///|
test "pushback waits exactly, then the backoff starts over" {
  let a = Attempts::new(retry~)
  let unavailable = code(Unavailable)
  assert_eq(ms(a.next(unavailable, [])), Some(100L))
  assert_eq(ms(a.next(unavailable, pushback("750"))), Some(750L))
  assert_eq(ms(a.next(unavailable, [])), Some(100L))
}

///|
test "pushback to stop ends the call, even with attempts left" {
  assert_eq(Attempts::new(retry~).next(code(Unavailable), pushback("-1")), None)
  assert_eq(
    Attempts::new(retry~).next(code(Unavailable), pushback("soon")),
    None,
  )
}

///|
test "pushback never retries a status the policy does not" {
  assert_eq(Attempts::new(retry~).next(code(NotFound), pushback("10")), None)
}

///|
test "reading the pushback" {
  assert_eq(Pushback::read([]), Absent)
  assert_eq(Pushback::read(pushback("0")), After(@moondate.Span::new()))
  assert_eq(
    Pushback::read(pushback("2147483647")),
    After(@moondate.Span::new(millis=2147483647L)),
  )
  assert_eq(Pushback::read(pushback("2147483648")), Stop)
  assert_eq(Pushback::read(pushback("-5")), Stop)
  assert_eq(Pushback::read(pushback("")), Stop)
  assert_eq(Pushback::read(pushback("1e3")), Stop)
  let two = pushback("10")
  two.push(@header.Header::of("grpc-retry-pushback-ms", "20"))
  assert_eq(Pushback::read(two), Stop)
  // Other trailers are none of its business.
  assert_eq(Pushback::read([@header.Header::of("grpc-status", "14")]), Absent)
}

///|
test "the throttle follows A6's example: ten tokens, a tenth back per success" {
  let t = Throttle::new(Throttling::new(tokens=10, ratio=0.1))
  assert_eq(t.tokens(), 10.0)
  for _ in 0..<4 {
    t.fail()
  }
  // Six left is above the half.
  assert_true(t.allows())
  t.fail()
  // Five is not over it.
  assert_false(t.allows())
  t.pass()
  assert_eq(t.tokens(), 5.1)
  assert_true(t.allows())
  // Never below none, never above the maximum.
  for _ in 0..<20 {
    t.fail()
  }
  assert_eq(t.tokens(), 0.0)
  for _ in 0..<200 {
    t.pass()
  }
  assert_eq(t.tokens(), 10.0)
}

///|
test "a ratio is read to three decimal places" {
  let t = Throttle::new(Throttling::new(tokens=10, ratio=0.5466))
  t.fail()
  t.pass()
  assert_eq(t.tokens(), 9.546)
}

///|
test "a throttled channel stops retrying, and successes earn it back" {
  let t = Throttle::new(Throttling::new(tokens=2, ratio=1.0))
  let a = Attempts::new(retry~, throttle=t)
  // Two tokens, half is one: the first failure leaves one, which throttles.
  assert_eq(a.next(code(Unavailable), []), None)
  assert_eq(t.tokens(), 1.0)
  let b = Attempts::new(retry~, throttle=t)
  assert_eq(b.next(0, []), None)
  assert_eq(t.tokens(), 2.0)
}

///|
test "only retryable failures and a pushback to stop cost a token" {
  let t = Throttle::new(Throttling::new(tokens=10, ratio=0.1))
  let _ = Attempts::new(retry~, throttle=t).next(code(NotFound), [])
  assert_eq(t.tokens(), 10.0)
  let _ = Attempts::new(retry~, throttle=t).next(code(NotFound), pushback("-1"))
  assert_eq(t.tokens(), 9.0)
  let _ = Attempts::new(retry~, throttle=t).next(
    code(Unavailable),
    [],
    unprocessed=true,
  )
  assert_eq(t.tokens(), 9.0)
  let _ = Attempts::new(retry~, throttle=t).next(code(Unavailable), [])
  assert_eq(t.tokens(), 8.0)
}
