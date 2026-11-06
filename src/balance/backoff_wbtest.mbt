// The backoff schedule gRPC's connection-backoff document specifies, and the clock a
// channel uses to decide when a dial may be made again.

///|
test "backoff: the wait grows by the factor and stops at the cap" {
  let policy = Backoff::new()
  // No spread, so the numbers are the document's.
  let first = policy.delay(1, roll=0.5).nanos / 1_000_000L
  assert_eq(first, 1000L)
  let second = policy.delay(2, roll=0.5).nanos / 1_000_000L
  assert_eq(second, 1600L)
  let third = policy.delay(3, roll=0.5).nanos / 1_000_000L
  assert_eq(third, 2560L)
  // 1.6 grows past two minutes after a dozen failures, and then stays there.
  let far = policy.delay(20, roll=0.5).nanos / 1_000_000L
  assert_eq(far, 120_000L)
  assert_eq(policy.delay(60, roll=0.5).nanos / 1_000_000L, 120_000L)
}

///|
test "backoff: the jitter is the twenty percent either way the document asks for" {
  let policy = Backoff::new()
  // roll 0 is the bottom of the spread, 1 the top.
  let low = policy.delay(1, roll=0.0).nanos / 1_000_000L
  let high = policy.delay(1, roll=0.99).nanos / 1_000_000L
  assert_eq(low, 800L)
  assert_true(high <= 1200L)
  assert_true(high > 1190L)
}

///|
test "backoff: the preset is the document's numbers" {
  assert_eq(backoff.initial.nanos, 1_000_000_000L)
  assert_eq(backoff.max.nanos, 120_000_000_000L)
  assert_eq(backoff.factor, 1.6)
  assert_eq(backoff.jitter, 0.2)
  assert_eq(min_connect_timeout.nanos, 20_000_000_000L)
}

///|
test "backoff: the wait is the one moonward computes from the same four numbers" {
  let policy = Backoff::new(
    initial=@moondate.Span::new(millis=7L),
    max=@moondate.Span::new(millis=900L),
    factor=1.4,
    jitter=0.35,
  )
  let schedule = @moonward.Backoff::new(
    base=@moondate.Span::new(millis=7L),
    cap=@moondate.Span::new(millis=900L),
    factor=1.4,
    jitter=@moonward.Spread(0.35),
  )
  for attempt in [1, 2, 3, 8] {
    for roll in [0.0, 0.25, 0.5, 0.99] {
      assert_eq(
        policy.delay(attempt, roll~).nanos,
        schedule.delay(attempt, random=roll).nanos,
      )
    }
  }
}

///|
test "backoff: a dial that worked starts the schedule over" {
  let clock = Reconnect::new(now=1000L)
  assert_eq(clock.due(1000L), true)
  clock.failed(1000L, roll=0.5)
  // One second out, from the failure.
  assert_eq(clock.due(1500L), false)
  assert_eq(clock.wait_millis(1500L), 500L)
  assert_eq(clock.due(2000L), true)
  clock.failed(2000L, roll=0.5)
  // The second wait is longer, and measured from the second failure.
  assert_eq(clock.wait_millis(2000L), 1600L)
  clock.succeeded()
  assert_eq(clock.failures, 0)
  assert_eq(clock.due(2000L), true)
}
