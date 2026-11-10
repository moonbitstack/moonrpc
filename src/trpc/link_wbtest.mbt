// The protocol against itself: frames round-trip, a unary call is answered, and the four
// streaming shapes go through one session as they would over a socket.

///|
/// A link that answers from a `Session` in the same process, so a test exercises the
/// client and the server halves without a socket.
struct MemoryLink {
  session : Session
  replies : Array[Bytes]
  mut at : Int32
}

///|
fn MemoryLink::new(session : Session) -> MemoryLink {
  { session, replies: [], at: 0, }
}

///|
impl Link for MemoryLink with fn write(self, bytes) {
  let (frame, _) = Frame::decode(bytes)
  for reply in self.session.handle(frame) {
    self.replies.push(reply)
  }
}

///|
impl Link for MemoryLink with fn read(self) {
  if self.at >= self.replies.length() {
    raise Truncated
  }
  let (frame, _) = Frame::decode(self.replies[self.at])
  self.at = self.at + 1
  frame
}

///|
pub extend MemoryLink with Link::{read, write}
