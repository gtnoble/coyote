#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
out=${MATH_PATHS_ROOT:-${TMPDIR:-/tmp}/coyote-math-paths}
mkdir -p "$out"
cd "$repo"
MATH_PATHS_ROOT="$out" alr exec -- gprbuild -p \
    -P test/native/math_paths.gpr > "$out/build.log" 2>&1 || {
    cat "$out/build.log" >&2
    exit 1
}
"$out/bin/math_paths_probe"
printf 'Build log: %s/build.log\n' "$out"
