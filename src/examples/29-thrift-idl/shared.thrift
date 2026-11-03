// A second file the example includes: a type and a service another file can build on.
namespace moon greet.shared

struct Stamp {
  1: i64 at
}

service Base {
  string ping()
}
