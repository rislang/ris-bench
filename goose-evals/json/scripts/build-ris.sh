#!/bin/bash
# Build the ris JSON benchmark into $OUT/json/bin.
set -euo pipefail
source "$(dirname "$0")/../../bin/env.sh"
mkdir -p "$OUT/json/bin"
"${RIS:-ris}" check "$ROOT/json/ris/json.ri"
flags=(--release)
"${RIS:-ris}" build "${flags[@]}" "$ROOT/json/ris/json.ri" \
  -o "$OUT/json/bin/bench_ris"
