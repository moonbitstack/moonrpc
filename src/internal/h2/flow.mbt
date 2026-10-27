// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Add a flow-control increment to a window, saturating at the ±2^31-1 range RFC 7540
/// §6.9.1 allows instead of wrapping. A wrap to a large negative window would stall
/// every send on that stream/connection (a WINDOW_UPDATE-driven deadlock), and a wrap
/// to a bogus positive one would over-send; the sum is taken in 64 bits and clamped.
pub fn add_window(cur : Int32, inc : Int32) -> Int32 {
  let sum = cur.to_int64() + inc.to_int64()
  if sum > 0x7FFFFFFFL {
    0x7FFFFFFF
  } else if sum < -0x7FFFFFFFL {
    -0x7FFFFFFF
  } else {
    sum.to_int()
  }
}
