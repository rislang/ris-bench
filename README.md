# ris-bench

Cross-language versions of the "respond" benchmark: a web service's hot loop.
Per request it builds a response (an id, a user name, a list of line items),
renders it as JSON, checksums the bytes with FNV-1a and throws everything away.
One name in eight contains a quote or a backslash, so the escaping path runs
too.

Every implementation uses the same xorshift64 PRNG, so all of them generate
byte-identical input and must print identical checksums.

Two shapes:

- **DTO** (`respond_dto`, `respond`): build the typed response object, then
  render it. This is the idiomatic version, with an allocation per string and
  per list.
- **Stream** (`respond_stream`): skip the object and write the JSON straight
  into a reused buffer. This is the expert version.

## Run

    ./run.sh                 # every language whose tool is on PATH
    GOOSE=~/goose/build/goose SPINEL=~/spinel/spinel ./run.sh

Each is built the way its own docs release it: ris and iyi `--release`,
Goose's default inlining then `cc -O2`, C and C++ `-O3 -DNDEBUG`, Rust
`opt-level=3`, `go build`, Crystal `--release`, Ruby with YJIT. A wrong
checksum skips a language. Heap traffic: `tools/count_malloc.c` for C,
C++ and Rust; `GC.stats` in ris, iyi and Crystal; `runtime.MemStats` in Go.

## Layout

| Dir | Contents |
|---|---|
| `ris/` | `respond.ri`, a copy of ris's `samples/ris/respond.ri` (tape) |
| `goose/` | Goose: `respond.goose`, `respond_stream.goose`, `rng.goose` |
| `iyi/` | iyi: DTO, stream, region and tape variants; tape-checker cases |
| `cpp/` | C++: `respond.cpp`, VARIANT 0 = DTO, 1 = stream |
| `c/` | C: `respond_dto.c`, malloc and free per string and list |
| `rust/` | Rust: DTO and stream; `bump/` the DTO in a bumpalo arena |
| `go/` | Go: `respond_dto/`, `respond_stream/` |
| `crystal/` | Crystal: `respond_dto.cr`, the iyi DTO without its imports |
| `ruby/` | Ruby: `respond_dto.rb`, also compiles with Spinel |
| `json/` | `jnest.ri`: a JSON tree in six layouts, tape and heap |
| `tools/` | `count_malloc.c`: malloc bytes and calls, as LD_PRELOAD |
| `share/` | `index.html`: an earlier results page |

Ruby's 64-bit hash and PRNG run as Bignum (Bigint in Spinel), most of its
time. Results: ris's README.md and TAPE_DESIGN.md.
