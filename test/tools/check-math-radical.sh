#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
out=${MATH_RADICAL_ROOT:-${TMPDIR:-/tmp}/coyote-math-radical}
mkdir -p "$out"
cd "$repo"
MATH_RADICAL_ROOT="$out" alr exec -- gprbuild -p -P test/native/math_radical.gpr > "$out/build.log" 2>&1 || { cat "$out/build.log" >&2; exit 1; }
"$out/bin/math_radical_probe" | tee "$out/probe.txt"
awk 'NR == 1 { if ($2 != "TRUE" || $5 != 1 || $6 < 20 || $3 < 0.90 || $3 > 0.92 || $4 < 0.13 || $4 > 0.14) exit 1 } NR > 1 { if ($2 != "TRUE" || $5 != 1 || $6 < 20 || $3 < 0.5 || $4 < 3.5) exit 1 } END { if (NR != 3) exit 1 }' "$out/probe.txt"
