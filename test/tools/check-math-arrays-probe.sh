#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
out=${MATH_ARRAYS_ROOT:-${TMPDIR:-/tmp}/coyote-math-arrays}
mkdir -p "$out"
cd "$repo"
MATH_ARRAYS_ROOT="$out" alr exec -- gprbuild -p \
    -P test/native/math_arrays_probe.gpr > "$out/build.log" 2>&1 || {
    cat "$out/build.log" >&2
    exit 1
}
"$out/bin/math_arrays_probe"
