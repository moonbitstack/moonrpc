// The IDL the example compiles: a person, a mood, and a service that greets one. It
// includes `shared.thrift` for a type, and extends the service declared there.
namespace moon greet

include "shared.thrift"

// Two aliases: they name a type, and the generated code only ever sees the type.
typedef map<string, i32> Scores
typedef string Key

enum Mood {
  Calm = 1,
  Happy = 2,
}

struct Person {
  1: required string name
  2: optional i32 age
  3: list<string> tags
  4: Scores scores
  5: binary portrait
  6: Mood mood
  7: shared.Stamp stamped
}

// Constants: a value written once in the IDL, emitted as a `pub let` of its type.
const i32 MAX_AGE = 130
const list<string> TAGS = ["math", "music"]
const map<string, i32> SCORES = { "math": 10, "art": 7 }
const Mood DEFAULT_MOOD = Mood.Calm
const Person ADA = {
  "name": "Ada",
  "age": 37,
  "tags": ["math"],
  "scores": { "math": 10 },
  "portrait": "ab",
  "mood": Mood.Happy,
  "stamped": { "at": 9 },
}

// A union carries one of its fields; on the wire it is a struct with one field set.
union Contact {
  1: string email
  2: i64 phone
  3: shared.Stamp at
}

service Greeter extends shared.Base {
  string hello(1: Person who)
  i32 add(1: i32 a, 2: i32 b)
  void notify(1: string text)
  string find(1: Key key) throws (1: shared.Missing missing)
  void shout(1: string text) throws (1: shared.Missing missing)
}
