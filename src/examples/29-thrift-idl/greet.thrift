// The IDL the example compiles: a person, a mood, and a service that greets one. It
// includes `shared.thrift` for a type, and extends the service declared there.
namespace moon greet

include "shared.thrift"

enum Mood {
  Calm = 1,
  Happy = 2,
}

struct Person {
  1: required string name
  2: optional i32 age
  3: list<string> tags
  4: map<string, i32> scores
  5: binary portrait
  6: Mood mood
  7: shared.Stamp stamped
}

service Greeter extends shared.Base {
  string hello(1: Person who)
  i32 add(1: i32 a, 2: i32 b)
  void notify(1: string text)
}
