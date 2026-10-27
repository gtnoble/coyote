#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
out=${MATH_FONT_DATA_ROOT:-${TMPDIR:-/tmp}/coyote-parity-font-data}
source=${1:-/tmp/coyote-katex-support-check/package/src/fontMetricsData.js}
mkdir -p "$out"
cd "$repo"
python3 tools/generate_katex_data.py "$source" \
   "$out/math_font_data.ads" "$out/math_font_data.adb" \
   > "$out/generate.log"
cmp "$out/math_font_data.ads" src/coyote_math/math_font_data.ads
cmp "$out/math_font_data.adb" src/coyote_math/math_font_data.adb
cp "$out/math_font_data.ads" "$out/first.ads"
cp "$out/math_font_data.adb" "$out/first.adb"
python3 tools/generate_katex_data.py "$source" \
   "$out/math_font_data.ads" "$out/math_font_data.adb" \
   > "$out/generate-repeat.log"
cmp "$out/first.ads" "$out/math_font_data.ads"
cmp "$out/first.adb" "$out/math_font_data.adb"
if python3 tools/generate_katex_data.py "$0" \
   "$out/rejected.ads" "$out/rejected.adb" > "$out/reject.log" 2>&1; then
   echo "generator accepted an unexpected source hash" >&2
   exit 1
fi
grep -q 'source SHA-256 mismatch' "$out/reject.log"
MATH_FONT_DATA_ROOT="$out/build" alr exec -- gprbuild -p \
   -P test/native/math_font_data.gpr > "$out/build.log" 2>&1 || {
   cat "$out/build.log" >&2
   exit 1
}
"$out/build/bin/math_font_data_probe" > "$out/probe.log" 2>&1 || {
   cat "$out/probe.log" >&2
   exit 1
}
cat "$out/generate.log"
cat "$out/probe.log"
printf 'Build log: %s/build.log\nProbe log: %s/probe.log\n' "$out" "$out"
