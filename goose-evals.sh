#!/usr/bin/env bash
# The ris ports of goose-evaluations (jq, json, ninja, yaml) against their
# Goose rows. Fetches github.com/calpeyser/goose-evaluations at a pinned
# commit into build/goose-evals, lays goose-evals/ over it, builds goose,
# the four Goose rows and the ris ports, fetches the inputs and prints
# bin/bench-ris's table: median of N runs, ris/Goose = ris time / Goose
# time, lower is faster. Needs git, gcc 11+, make, python3 and curl; no
# cargo. The first run builds goose (about 5 minutes).
#
#   RIS=~/ris/bin/ris ./goose-evals.sh            # small inputs, 5 runs
#   RIS=~/ris/bin/ris ./goose-evals.sh medium 5
set -euo pipefail
cd "$(dirname "$0")"
UPSTREAM=calpeyser/goose-evaluations
COMMIT=59414a8af2c8f2ef39c2b702018765446c7b8602
SRC=build/goose-evals
SIZE=${1:-small}; N=${2:-5}
RIS=$(command -v "${RIS:-ris}") ||
  { echo "set RIS to the ris compiler"; exit 1; }
export RIS

if [ "$(git -C "$SRC" rev-parse HEAD 2>/dev/null)" != "$COMMIT" ]; then
  rm -rf "$SRC"; mkdir -p "$SRC"
  git -C "$SRC" init -q
  git -C "$SRC" remote add origin "https://github.com/$UPSTREAM"
  git -C "$SRC" fetch -q --depth 1 origin "$COMMIT"
  git -C "$SRC" -c advice.detachedHead=false checkout -q FETCH_HEAD
fi
cp -r --preserve=mode goose-evals/. "$SRC/"

# No root needed: a system python3 with PyYAML replaces upstream's venv,
# and a missing cmake is fetched as Kitware's binary release.
if python3 -c 'import yaml' 2>/dev/null; then
  PY=$(command -v python3); export PY
fi
if ! command -v cmake >/dev/null; then
  C=$PWD/$SRC/.deps/cmake; V=3.31.6
  [ -x "$C/bin/cmake" ] || { mkdir -p "$C" && curl -sSfL \
    "https://github.com/Kitware/CMake/releases/download/v$V/cmake-$V-linux-x86_64.tar.gz" |
    tar -xz -C "$C" --strip-components=1; }
  export PATH=$C/bin:$PATH
fi

[ -x "$SRC/.out/jq/bin/jqg" ] || "$SRC/bin/build-goose-rows"
[ -f "$SRC/.inputs/$SIZE" ] ||
  { "$SRC/bin/fetch-inputs" --size "$SIZE" && touch "$SRC/.inputs/$SIZE"; }
for e in jq json ninja yaml; do "$SRC/$e/scripts/build-ris.sh"; done
echo "ris: $("$RIS" --version | head -1)"
"$SRC/bin/bench-ris" "$SIZE" "$N"
