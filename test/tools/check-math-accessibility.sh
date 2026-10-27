#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
out=${MATH_ACCESSIBILITY_ROOT:-${TMPDIR:-/tmp}/coyote-math-accessibility}
mkdir -p "$out"
cd "$repo"
MATH_ACCESSIBILITY_ROOT="$out" alr exec -- gprbuild -p \
    -P test/native/math_accessibility.gpr > "$out/build.log" 2>&1 || {
    cat "$out/build.log" >&2
    exit 1
}
runner=""
if command -v xvfb-run >/dev/null 2>&1; then
    runner="xvfb-run -a"
fi
if [ -n "$runner" ]; then
    $runner "$out/bin/math_accessibility_probe" > "$out/probe.log" 2>&1 || {
        cat "$out/probe.log" >&2
        exit 1
    }
else
    "$out/bin/math_accessibility_probe" > "$out/probe.log" 2>&1 || {
        cat "$out/probe.log" >&2
        exit 1
    }
fi
cat "$out/probe.log"
printf 'Build log: %s/build.log\nProbe log: %s/probe.log\n' "$out" "$out"
