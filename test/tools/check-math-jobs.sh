#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
out=${MATH_JOBS_ROOT:-${TMPDIR:-/tmp}/coyote-math-jobs}
mkdir -p "$out"
cd "$repo"
MATH_JOBS_ROOT="$out" alr exec -- gprbuild -p \
    -P test/native/math_jobs.gpr > "$out/build.log" 2>&1 || {
    cat "$out/build.log" >&2
    exit 1
}
"$out/bin/math_jobs_probe" "$repo/share/coyote/math/fonts" \
    > "$out/probe.log" 2>&1 || {
    cat "$out/probe.log" >&2
    exit 1
}
cat "$out/probe.log"
printf 'Build log: %s/build.log\nProbe log: %s/probe.log\n' "$out" "$out"
