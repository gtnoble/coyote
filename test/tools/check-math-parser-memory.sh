#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
out=${MATH_PARSER_MEMORY_ROOT:-${TMPDIR:-/tmp}/coyote-math-parser-memory}
mkdir -p "$out"
cd "$repo"
MATH_PARSER_MEMORY_ROOT="$out" alr exec -- gprbuild -p \
    -P test/native/math_parser_memory.gpr > "$out/build.log" 2>&1 || {
    cat "$out/build.log" >&2
    exit 1
}
"$out/bin/math_parser_memory_probe" > "$out/probe.log" 2>&1 || {
    cat "$out/probe.log" >&2
    exit 1
}
cat "$out/probe.log"
printf 'Build log: %s/build.log\nProbe log: %s/probe.log\n' "$out" "$out"
