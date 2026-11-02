#!/bin/bash
# Build the ris Ninja manifest loader into $OUT/ninja/bin.
set -euo pipefail
source "$(dirname "$0")/../../bin/env.sh"
mkdir -p "$OUT/ninja/bin"
"${RIS:-ris}" check "$ROOT/ninja/ris/ninja_load.ri"
flags=(--release)
"${RIS:-ris}" build "${flags[@]}" "$ROOT/ninja/ris/ninja_load.ri" \
  -o "$OUT/ninja/bin/ris_load"
