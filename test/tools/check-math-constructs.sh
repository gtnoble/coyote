#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
out=${MATH_CONSTRUCTS_ROOT:-${TMPDIR:-/tmp}/coyote-math-constructs}
mkdir -p "$out"
cd "$repo"
MATH_CONSTRUCTS_ROOT="$out" alr exec -- gprbuild -p \
    -P test/native/math_constructs.gpr > "$out/build.log" 2>&1 || {
    cat "$out/build.log" >&2
    exit 1
}
"$out/bin/math_constructs_probe"
printf 'Build log: %s/build.log\n' "$out"
