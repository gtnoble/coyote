#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
out=${MATH_RASTER_ROOT:-${TMPDIR:-/tmp}/coyote-math-raster}
fonts=${COYOTE_MATH_FONTS:-$repo/share/coyote/math/fonts}
mkdir -p "$out"
cd "$repo"
MATH_RASTER_ROOT="$out" alr exec -- gprbuild -p \
    -P test/native/math_raster.gpr > "$out/build.log" 2>&1 || {
    cat "$out/build.log" >&2
    exit 1
}
"$out/bin/math_raster_probe" "$fonts"
if command -v valgrind >/dev/null 2>&1; then
    valgrind --error-exitcode=1 --leak-check=full \
        "$out/bin/math_raster_probe" "$fonts"
else
    printf '%s\n' 'valgrind unavailable; skipped'
fi
