#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
out=${MATH_DELIMITER_ROOT:-${TMPDIR:-/tmp}/coyote-math-delimiters}
mkdir -p "$out"
cd "$repo"
MATH_DELIMITER_ROOT="$out" alr exec -- gprbuild -p \
    -P test/native/math_delimiter.gpr > "$out/build.log" 2>&1 || {
    cat "$out/build.log" >&2
    exit 1
}
"$out/bin/math_delimiter_probe"
printf 'Build log: %s/build.log\n' "$out"
