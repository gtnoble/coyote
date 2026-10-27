#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
out=${MATH_SEMANTICS_ROOT:-${TMPDIR:-/tmp}/coyote-math-semantics}
mkdir -p "$out"
cd "$repo"
MATH_SEMANTICS_ROOT="$out" alr exec -- gprbuild -p \
    -P test/native/math_semantics.gpr > "$out/build.log" 2>&1 || {
    cat "$out/build.log" >&2
    exit 1
}
"$out/bin/math_semantics_probe" > "$out/probe.log" 2>&1 || {
    cat "$out/probe.log" >&2
    exit 1
}
cat "$out/probe.log"
printf 'Build log: %s/build.log\nProbe log: %s/probe.log\n' "$out" "$out"
