#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
out=${MATH_OPERATORS_ROOT:-${TMPDIR:-/tmp}/coyote-math-operators}
mkdir -p "$out"
cd "$repo"
MATH_OPERATORS_ROOT="$out" alr exec -- gprbuild -p \
    -P test/native/math_operators.gpr > "$out/build.log" 2>&1 || {
    cat "$out/build.log" >&2
    exit 1
}
"$out/bin/math_operators_probe" | tee "$out/operators.txt"
grep -q 'checks= 155 failures= 0' "$out/operators.txt"
printf 'Build log: %s/build.log\nOperator probe: %s/operators.txt\n' "$out" "$out"
