#!/bin/bash
# Build the ris jq core into $OUT/jq/bin.
set -euo pipefail
source "$(dirname "$0")/../../bin/env.sh"
mkdir -p "$OUT/jq/bin"
"${RIS:-ris}" check "$ROOT/jq/ris/jqg.ri"
flags=(--release)
"${RIS:-ris}" build "${flags[@]}" "$ROOT/jq/ris/jqg.ri" \
  -o "$OUT/jq/bin/jqg_ris"
