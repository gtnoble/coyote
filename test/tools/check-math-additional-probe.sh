#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
out=${MATH_ADDITIONAL_ROOT:-${TMPDIR:-/tmp}/coyote-math-additional}
mkdir -p "$out"
cd "$repo"
MATH_ADDITIONAL_ROOT="$out" alr exec -- gprbuild -p \
    -P test/native/math_additional_probe.gpr > "$out/build.log" 2>&1 || {
    cat "$out/build.log" >&2
    exit 1
}
"$out/bin/math_additional_probe"
printf 'Build log: %s/build.log\n' "$out"
