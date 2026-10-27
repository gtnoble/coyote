#!/bin/sh
set -eu
usage() { echo 'usage: check-math-differential.sh <package-root> <archive.tgz> [output-root]' >&2; exit 2; }
[ "$#" -ge 2 ] && [ "$#" -le 3 ] || usage
REPO=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$REPO"
PACKAGE=$(CDPATH= cd -- "$1" && pwd)
ARCHIVE=$(CDPATH= cd -- "$(dirname -- "$2")" && pwd)/$(basename -- "$2")
OUT=${3:-/tmp/coyote-math-differential}
mkdir -p "$OUT" || exit 1
OUT=$(CDPATH= cd -- "$OUT" && pwd)
NODE=${NODE:-node}
ALR=${ALR:-alr}
command -v "$NODE" >/dev/null 2>&1 || { echo 'node not found' >&2; exit 2; }
command -v "$ALR" >/dev/null 2>&1 || { echo 'alr not found' >&2; exit 2; }
[ -f "$PACKAGE/dist/katex.js" ] && [ -f "$ARCHIVE" ] || { echo 'package bundle or pinned archive missing' >&2; exit 2; }
FIXTURE="$REPO/test/fixtures/math-compatibility/pilot.json"
"$NODE" "$REPO/test/tools/check-math-differential.cjs" --emit-requests "$FIXTURE" > "$OUT/requests.jsonl"
"$NODE" "$REPO/test/tools/export-math-reference.cjs" "$ARCHIVE" "$PACKAGE" < "$OUT/requests.jsonl" > "$OUT/reference.jsonl"
MATH_EXPORT_ROOT="$OUT/native-build" "$ALR" exec -- gprbuild -P "$REPO/test/native/math_export.gpr" -XMATH_EXPORT_ROOT="$OUT/native-build"
NATIVE="$OUT/native-build/bin/math_export"
[ -x "$NATIVE" ] || { echo "native exporter missing: $NATIVE" >&2; exit 2; }
"$NATIVE" < "$OUT/requests.jsonl" > "$OUT/native-raw.jsonl"
"$NODE" "$REPO/test/tools/check-math-differential.cjs" --annotate-native "$FIXTURE" "$OUT/native-raw.jsonl" "$OUT/native.jsonl"
"$NODE" "$REPO/test/tools/compare-math-layout.cjs" "$FIXTURE" "$OUT/reference.jsonl" "$OUT/native.jsonl" "$OUT/report.json" --allow-unsupported
printf 'Artifacts: %s\n' "$OUT"
