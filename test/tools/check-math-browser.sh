#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
katex=${KATEX_PACKAGE:-/tmp/coyote-katex-support-check/package}
archive=${KATEX_ARCHIVE:-/tmp/coyote-katex-support-check/katex.tgz}
out=${MATH_BROWSER_ROOT:-${TMPDIR:-/tmp}/coyote-math-browser}
node=${NODE:-node}
[ -f "$katex/dist/katex.js" ] && [ -f "$archive" ] || {
    echo "pinned KaTeX package/archive missing (KATEX_PACKAGE=$katex KATEX_ARCHIVE=$archive)" >&2
    exit 2
}
command -v "$node" >/dev/null 2>&1 || { echo 'node not found' >&2; exit 2; }
command -v "${BROWSER_CTL:-browser-ctl}" >/dev/null 2>&1 || { echo 'browser-ctl not found; browser measurements unavailable' >&2; exit 2; }
mkdir -p "$out"
out=$(CDPATH= cd -- "$out" && pwd)
cd "$repo"
cat > "$out/requests.jsonl" <<'JSON'
{"id":"x","source":"x","displayMode":false}
{"id":"frac-x-y","source":"\\frac{x}{y}","displayMode":false}
{"id":"heatbalance-first-term","source":"\\dot{Q}_{\\mathrm{in}}","displayMode":false}
JSON
MATH_BROWSER_SCREENSHOT="$out/browser.png" "$node" test/tools/export-math-browser.cjs "$archive" "$katex" < "$out/requests.jsonl" > "$out/browser.jsonl"
"$node" - "$out/browser.jsonl" <<'NODE'
const assert = require('node:assert/strict');
const fs = require('node:fs');
const rows = fs.readFileSync(process.argv[2], 'utf8').trim().split('\n').map(JSON.parse);
assert.deepEqual(rows.map(x => x.id), ['x', 'frac-x-y', 'heatbalance-first-term']);
for (const row of rows) {
  assert.equal(row.schema, 'coyote.math-browser.v1');
  assert.equal(row.status, 'ok', `${row.id}: ${row.error}`);
  assert.equal(row.provenance.version, '0.16.22');
  assert(row.box.width > 0 && row.box.height > 0, `${row.id}: positive browser box`);
  assert(row.glyphs.length > 0, `${row.id}: measured leaf glyph boxes`);
  assert.equal(row.viewport.contentWidth, 800);
  assert.equal(row.fontSizePx, 24, `${row.id}: computed KaTeX font size`);
  assert.equal(row.capabilities.pixels, false);
  assert.equal(row.screenshot, `${process.env.MATH_BROWSER_ROOT || '/tmp/coyote-math-browser'}/browser.png`);
}
const frac = rows.find(x => x.id === 'frac-x-y');
process.stdout.write(`Chromium ${rows[0].provenance.browser}: ${rows.length} KaTeX browser DOM cases passed; x=${rows[0].box.width.toFixed(3)}×${rows[0].box.height.toFixed(3)}px fraction=${frac.box.width.toFixed(3)}×${frac.box.height.toFixed(3)}px; local-font browser geometry only (no pixel/native parity claim).\n`);
NODE
[ -s "$out/browser.png" ] || { echo 'browser screenshot missing' >&2; exit 1; }
negative=$(mktemp -d "${TMPDIR:-/tmp}/coyote-katex-mutable-negative.XXXXXX")
trap 'rm -rf "$negative"' EXIT HUP INT TERM
cp -a "$katex/." "$negative/package"
printf '/* mutable-package negative control */\n' >> "$negative/package/dist/katex.css"
printf 'mutated-font' >> "$negative/package/dist/fonts/KaTeX_Main-Regular.woff2"
MATH_BROWSER_SCREENSHOT="$out/browser.png" "$node" test/tools/export-math-browser.cjs "$archive" "$negative/package" < "$out/requests.jsonl" > "$negative/browser.jsonl"
cmp "$out/browser.jsonl" "$negative/browser.jsonl"
"$node" - "$out/browser.jsonl" "$negative/browser.jsonl" <<'NODE'
const fs = require('node:fs');
const a = fs.readFileSync(process.argv[2], 'utf8').trim().split('\n').map(JSON.parse);
const b = fs.readFileSync(process.argv[3], 'utf8').trim().split('\n').map(JSON.parse);
if (a[0].provenance.verifiedFilesHash !== b[0].provenance.verifiedFilesHash) throw Error('archive asset provenance changed after mutable package mutation');
process.stdout.write('Mutable package CSS/font negative control passed: archive-driven output and verified manifest remained identical.\n');
NODE
printf 'JSONL geometry: %s/browser.jsonl\nPNG: %s/browser.png (visual artifact; no pixel parity claimed)\n' "$out" "$out"
