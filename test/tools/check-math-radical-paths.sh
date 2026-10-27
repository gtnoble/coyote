#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
out=${MATH_RADICAL_PATHS_ROOT:-${TMPDIR:-/tmp}/coyote-math-radical-paths}
mkdir -p "$out"
cd "$repo"
source=${KATEX_SVG_GEOMETRY:-/tmp/coyote-katex-reference/package/src/svgGeometry.js}
python3 tools/generate_math_radical_paths.py "$source" "$out/generated-1.json"
python3 tools/generate_math_radical_paths.py "$source" "$out/generated-2.json"
cmp "$out/generated-1.json" "$out/generated-2.json"
node - "$out/generated-1.json" <<'NODE'
const fs = require("fs");
const generated = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const source = fs.readFileSync(process.env.KATEX_SVG_GEOMETRY || "/tmp/coyote-katex-reference/package/src/svgGeometry.js", "utf8");
const paths = {};
for (const key of ["sqrtMain", "sqrtSize1", "sqrtSize2", "sqrtSize3", "sqrtSize4"]) {
  const match = source.match(new RegExp("const " + key + " = function\\(([^)]*)\\): string \\{([\\s\\S]*?)\\n\\};"));
  if (!match) throw new Error("missing source function " + key);
  const body = match[2].replace(/return `([\\s\\S]*?)`;/, "return `\\$1`;");
  paths[key] = new Function("extraVinculum", "hLinePad", body);
}
for (const extra of [0, 100]) {
  for (const key of ["sqrtMain", "sqrtSize1", "sqrtSize2", "sqrtSize3", "sqrtSize4"]) {
    const expected = paths[key](extra, 80).replace(/\s+/g, " ").trim();
    const actual = generated.paths[String(extra)][key];
    if (actual !== expected) throw new Error(`oracle mismatch ${key} extra=${extra}`);
  }
}
NODE
MATH_RADICAL_PATHS_ROOT="$out" alr exec -- gprbuild -p \
    -P test/native/math_radical_paths.gpr > "$out/build.log" 2>&1 || {
    cat "$out/build.log" >&2
    exit 1
}
"$out/bin/math_radical_path_probe" | tee "$out/probe.txt"
grep -q 'checks= 74 failures= 0' "$out/probe.txt"
printf '%s\n' 'KaTeX 0.16.22 src/svgGeometry.js SHA-256 verified by generator'
printf 'Build log: %s/build.log\n' "$out"
