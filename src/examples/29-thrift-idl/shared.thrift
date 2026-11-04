// A second file the example includes: a type, a failure, and a service another file can
// build on.
namespace moon greet.shared

struct Stamp {
  1: i64 at
}

exception Missing {
  1: string message
  2: i32 code
}

service Base {
  string ping()
}
