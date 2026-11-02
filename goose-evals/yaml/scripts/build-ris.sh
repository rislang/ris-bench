#!/bin/bash
# Build the ris YAML row into $OUT/yaml/bin.
set -euo pipefail
source "$(dirname "$0")/../../bin/env.sh"
mkdir -p "$OUT/yaml/bin"
"${RIS:-ris}" check "$ROOT/yaml/ris/yaml.ri"
flags=(--release)
"${RIS:-ris}" build "${flags[@]}" "$ROOT/yaml/ris/yaml.ri" \
  -o "$OUT/yaml/bin/yaml_ris"
