#!/usr/bin/env bash
# Builds respond in every language whose tool is on PATH, each in its own
# release build, checks the checksum, runs ROUNDS rounds in a shuffled
# order and prints the median time and peak memory.
#
#   ./run.sh                 # 9 rounds
#   ROUNDS=3 ./run.sh
#   GOOSE=~/goose/build/goose SPINEL=~/spinel/spinel ./run.sh
#
# Ruby is run once (about two minutes); RUBY=0 skips it.
set -u
cd "$(dirname "$0")"
ROUNDS=${ROUNDS:-9}
OUT=build
mkdir -p "$OUT"
WANT=7480137599999527189
built=()

have() { command -v "$1" >/dev/null 2>&1; }

add() { # name, then the build command
  local name=$1; shift
  if "$@" >"$OUT/$name.log" 2>&1 && [ "$("./$OUT/$name" | tail -1)" = "$WANT" ]; then
    built+=("$name")
  else
    echo "skip $name: see $OUT/$name.log" >&2
  fi
}

have ris && add ris ris build --release ris/respond.ri -o "$OUT/ris"
if [ -n "${GOOSE:-}" ]; then
  export GOOSE_STDLIB=${GOOSE_STDLIB:-$(dirname "$GOOSE")/../stdlib}
  "$GOOSE" --emit-runtime "$OUT/goose_rt.c" >/dev/null &&
    (cd goose && "$GOOSE" -o "../$OUT/goose.c" respond.goose) >/dev/null &&
    add goose cc -O2 "$OUT/goose.c" "$OUT/goose_rt.c" -o "$OUT/goose" -lm -pthread
fi
have g++ && add cpp g++ -O3 -DNDEBUG -DVARIANT=0 -DBENCH_N=1600000 -Icpp cpp/respond.cpp -o "$OUT/cpp"
have cc && add c cc -O3 -DNDEBUG c/respond_dto.c -o "$OUT/c"
have rustc && add rust rustc -C opt-level=3 --edition 2021 rust/respond_dto.rs -o "$OUT/rust"
have cargo && add rust_bump sh -c "cargo build --release --manifest-path rust/bump/Cargo.toml && cp rust/bump/target/release/respond_bump $OUT/rust_bump"
have iyi && add iyi iyi build --release iyi/respond_dto.iyi -o "$OUT/iyi"
have go && add go sh -c "cd go/respond_dto && GO111MODULE=off go build -o ../../$OUT/go main.go"
have crystal && add crystal crystal build --release crystal/respond_dto.cr -o "$OUT/crystal"
[ -n "${SPINEL:-}" ] && add spinel "$SPINEL" ruby/respond_dto.rb -o "$OUT/spinel"

: >"$OUT/times"
for _ in $(seq "$ROUNDS"); do
  for name in $(printf '%s\n' "${built[@]}" | shuf); do
    /usr/bin/time -f "$name %e %M" "./$OUT/$name" >/dev/null 2>>"$OUT/times"
  done
done
if [ "${RUBY:-1}" != 0 ] && have ruby; then
  if [ "$(ruby --yjit ruby/respond_dto.rb | tail -1)" = "$WANT" ]; then
    /usr/bin/time -f "ruby %e %M" ruby --yjit ruby/respond_dto.rb >/dev/null 2>>"$OUT/times"
    built+=(ruby)
  fi
fi

printf '| %-10s | %8s | %8s |\n|---|---|---|\n' language time RSS
for name in "${built[@]}"; do
  grep "^$name " "$OUT/times" | sort -k2 -n | awk -v n="$name" '
    { t[NR] = $2; m[NR] = $3 }
    END { k = int((NR + 1) / 2); printf "| %-10s | %6.2f s | %5.1f MB |\n", n, t[k], m[k] / 1024 }'
done
