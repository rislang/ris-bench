#!/usr/bin/env bash
# Goose's algorithmic benchmarks (graph_csr, words, bintrees, from
# github.com/aardappel/goose bench/goose) against their ris ports, on the GC
# heap and on the tape. Checks each output against Goose's, runs ROUNDS
# rounds in a shuffled order and prints the median time and peak memory.
#
#   GOOSE=~/goose/build/goose ./algo.sh
#   ROUNDS=3 RIS=~/ris/bin/ris GOOSE=... ./algo.sh
set -u
cd "$(dirname "$0")"
ROUNDS=${ROUNDS:-9}
RIS=${RIS:-ris}
OUT=build/algo
mkdir -p "$OUT"
: "${GOOSE:?set GOOSE to the goose compiler}"
export GOOSE_STDLIB=${GOOSE_STDLIB:-$(dirname "$GOOSE")/../stdlib}
"$GOOSE" --emit-runtime "$OUT/goose_rt.c" >/dev/null || exit 1
runs=()

for bench in graph_csr words bintrees; do
  (cd goose && "$GOOSE" -o "../$OUT/goose_$bench.c" "$bench.goose") \
    >"$OUT/goose_$bench.log" 2>&1 &&
    cc -O2 "$OUT/goose_$bench.c" "$OUT/goose_rt.c" -o "$OUT/goose_$bench" \
      -lm -pthread || { echo "skip $bench: goose did not build" >&2; continue; }
  "./$OUT/goose_$bench" >"$OUT/$bench.want"
  runs+=("goose_$bench")
  "$RIS" build --release "ris/$bench.ri" -o "$OUT/ris_$bench" \
    >"$OUT/ris_$bench.log" 2>&1 || { echo "skip ris $bench" >&2; continue; }
  for mode in heap tape; do
    if cmp -s "$OUT/$bench.want" <("./$OUT/ris_$bench" "$mode"); then
      runs+=("ris_$bench $mode")
    else
      echo "skip ris $bench $mode: output differs from goose's" >&2
    fi
  done
done

: >"$OUT/times"
for _ in $(seq "$ROUNDS"); do
  printf '%s\n' "${runs[@]}" | shuf | while read -r exe mode; do
    /usr/bin/time -f "$exe${mode:+_$mode} %e %M" "./$OUT/$exe" $mode \
      >/dev/null 2>>"$OUT/times"
  done
done

printf '| %-20s | %8s | %8s |\n|---|---|---|\n' run time RSS
for run in "${runs[@]}"; do
  name=${run/ /_}
  grep "^$name " "$OUT/times" | sort -k2 -n | awk -v n="$name" '
    { t[NR] = $2; m[NR] = $3 }
    END { k = int((NR + 1) / 2); printf "| %-20s | %6.2f s | %5.1f MB |\n", n, t[k], m[k] / 1024 }'
done
