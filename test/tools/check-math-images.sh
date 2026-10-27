#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
out=${MATH_IMAGE_ROOT:-${TMPDIR:-/tmp}/coyote-math-images}
fonts=${COYOTE_MATH_FONTS:-$repo/share/coyote/math/fonts}
package=${KATEX_PACKAGE:-/tmp/coyote-katex-support-check/package}
archive=${KATEX_ARCHIVE:-/tmp/coyote-katex-support-check/katex.tgz}
node=${NODE:-node}
alr=${ALR:-alr}
browser=${BROWSER_CTL:-browser-ctl}
mkdir -p "$out"
out=$(CDPATH= cd -- "$out" && pwd)
cd "$repo"
[ -d "$fonts" ] || { echo "native fonts missing: $fonts" >&2; exit 2; }
[ -f "$package/dist/katex.js" ] && [ -f "$package/dist/katex.css" ] && [ -f "$archive" ] || {
    echo "pinned KaTeX package/archive missing" >&2
    exit 2
}
command -v "$node" >/dev/null 2>&1 || { echo 'node not found' >&2; exit 2; }
command -v "$alr" >/dev/null 2>&1 || { echo 'alr not found' >&2; exit 2; }
command -v "$browser" >/dev/null 2>&1 || { echo 'browser-ctl not found' >&2; exit 2; }
python3 -c 'import PIL, scipy, numpy' || {
    echo 'requires Python 3 with Pillow, SciPy, and NumPy; no packages installed' >&2
    exit 2
}
"$browser" start >/dev/null
MATH_IMAGE_EXPORT_ROOT="$out/build" "$alr" exec -- gprbuild -p \
    -P test/native/math_image_export.gpr \
    -XMATH_IMAGE_EXPORT_ROOT="$out/build" > "$out/build.log" 2>&1 || {
    cat "$out/build.log" >&2
    exit 1
}
MATH_IMAGE_EXPORT="$out/build/bin/math_image_export" \
    BROWSER_CTL="$browser" python3 test/tools/check-math-images.py \
    --out "$out" --package "$package" --archive "$archive" \
    --fonts "$fonts" --browser-ctl "$browser"
printf 'Image report and PNG artifacts: %s\n' "$out"
