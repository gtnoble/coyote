#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
out=${MATH_TAGS_ROOT:-${TMPDIR:-/tmp}/coyote-math-tags}
mkdir -p "$out"
cd "$repo"
MATH_TAGS_ROOT="$out" alr exec -- gprbuild -p \
    -P test/native/math_tags_probe.gpr > "$out/build.log" 2>&1 || {
    cat "$out/build.log" >&2
    exit 1
}
"$out/bin/math_tags_probe"
printf 'Build log: %s/build.log\n' "$out"
