#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
out=${MATH_TOKENS_ROOT:-${TMPDIR:-/tmp}/coyote-parity-tokens}
mkdir -p "$out"
cd "$repo"
python3 tools/generate_math_unicode.py \
    plan/native-math-katex-0.16.22-inventory.json \
    src/coyote_math/math_unicode.ads src/coyote_math/math_unicode.adb
MATH_TOKENS_ROOT="$out" alr exec -- gprbuild -p -P test/native/math_tokens.gpr \
    > "$out/build.log" 2>&1 || {
    cat "$out/build.log" >&2
    exit 1
}
"$out/bin/math_tokens_probe" > "$out/probe.log" 2>&1 || {
    cat "$out/probe.log" >&2
    exit 1
}
cat "$out/probe.log"
printf 'Build log: %s/build.log\nProbe log: %s/probe.log\n' "$out" "$out"
