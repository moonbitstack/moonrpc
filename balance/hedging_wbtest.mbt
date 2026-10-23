///|
test "the preset is A6's example hedging policy" {
  assert_eq(hedging.attempts, 4)
  assert_eq(hedging.delay.nanos / 1_000_000L, 500L)
  assert_eq(hedging.codes, [Unavailable, Internal, Aborted])
  assert_eq(Hedging::new(), hedging)
  assert_eq(Hedging::new(attempts=2), { ..hedging, attempts: 2, })
}

///|
test "attempts start up to the policy and the client limit" {
  assert_true(hedging.more(3))
  assert_false(hedging.more(4))
  let greedy = Hedging::new(attempts=8)
  assert_true(greedy.more(4))
  assert_false(greedy.more(5))
  assert_false(greedy.more(2, limit=2))
}

///|
test "OK and fatal statuses settle the call, non-fatal ones do not" {
  assert_true(hedging.commits(0))
  assert_false(hedging.commits(@wire.Status::code(Unavailable)))
  assert_false(hedging.commits(@wire.Status::code(Internal)))
  assert_true(hedging.commits(@wire.Status::code(InvalidArgument)))
  assert_true(hedging.commits(@wire.Status::code(DeadlineExceeded)))
}
