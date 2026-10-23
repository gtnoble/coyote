#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
: "${ALR:=alr}"
if [ -n "${NATIVE_MATH_ROOT:-}" ]; then
   out=$NATIVE_MATH_ROOT
else
   out=${TMPDIR:-/tmp}/coyote-native-math-qualification
   mkdir -p "$out"
fi
mkdir -p "$out"
cd "$repo"
NATIVE_MATH_ROOT="$out" "$ALR" exec -- gprbuild -p \
   -P test/native/native_math.gpr
"$out/bin/math_probe" "$repo/share/coyote/math/fonts" \
   "$out/production.png" > "$out/math-probe.log"
cat "$out/math-probe.log"
printf 'PNG: %s/production.png\nLog: %s/math-probe.log\n' "$out" "$out"
