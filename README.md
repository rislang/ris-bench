# ris-bench

Cross-language versions of the "respond" benchmark: a web service's hot loop.
Per request it builds a response (an id, a user name, a list of line items),
renders it as JSON, checksums the bytes with FNV-1a and throws everything away.
One name in eight contains a quote or a backslash, so the escaping path runs too.

Every implementation uses the same xorshift64 PRNG, so all of them generate
byte-identical input and must print identical checksums.

Two shapes:

- **DTO** (`respond_dto`, `respond`): build the typed response object, then
  render it. This is the idiomatic version, with an allocation per string and
  per list.
- **Stream** (`respond_stream`): skip the object and write the JSON straight
  into a reused buffer. This is the expert version.

## Layout

| Dir      | Contents |
|----------|----------|
| `goose/` | Goose reference versions (`respond.goose`, `respond_stream.goose`, `rng.goose`) |
| `iyi/`   | iyi ports: DTO, stream, region, and tape variants; `tape_errors/` and `tape_fibers/` hold tape-checker test cases |
| `cpp/`   | C++ (`respond.cpp` with VARIANT 0 = DTO, 1 = stream; `bench.h` shared scaffolding) |
| `rust/`  | Rust (`respond_dto.rs`, `respond_stream.rs`, `bench.rs` shared scaffolding) |
| `go/`    | Go (`respond_dto/main.go`, `respond_stream/main.go`) |
| `share/` | `index.html`: results page with charts and a paste-ready summary |

These files were moved out of `rispacks/`, which now holds only Ris packages.
