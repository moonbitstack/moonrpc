// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The HTTP/2 default flow-control window and initial `SETTINGS_INITIAL_WINDOW_SIZE`
/// (RFC 7540 §6.9.2): 65 535 octets.
pub let default_window_size : Int32 = 65535

///|
/// The HTTP/2 default (and minimum) `SETTINGS_MAX_FRAME_SIZE` (RFC 7540 §6.5.2).
pub let default_max_frame_size : Int32 = 16384
