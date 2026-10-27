# Native math provenance

## Primary reference

KaTeX **0.16.22**, fixed npm distribution:

- URL: <https://registry.npmjs.org/katex/-/katex-0.16.22.tgz>
- Archive SHA-256 (verified): `e9e0d167db3175481cbadaff38e8d90b130f6a3ddb451a47e43c577fd511f365`
- `src/fontMetricsData.js` SHA-256: `1e72fc6b451a565e60b1eb7e89f4738eb74f35edfcf3c9c273015700b42ae04d`
- Source reference: <https://github.com/KaTeX/KaTeX/tree/v0.16.22/src>
- Copyright (c) 2013-2020 Khan Academy and other contributors. Notice: `licenses/KaTeX-MIT.txt`.

`math_font_data.ads/.adb` are generated from the full font metrics source. It contains 18 nonempty tables and 2,038 glyph records for 20 named faces. `Caligraphic-Bold` and `Fraktur-Bold` have no source table; their generated lookup returns `Found = False` for every code point. This does not claim all faces have usable metrics, nor that metric fallback is implemented. Per-face metric/render qualification is not implied.

The syntax parser and layout are bounded native implementations, not an exact KaTeX port. Static path geometry includes selected widehat/tilde variants, right/left and under-arrows, vec, brace constructs, and parameterized tall radicals. Native delimiters also use pinned font-piece metrics. This is not broad SVG, delimiter, accent, or KaTeX geometry parity. The profile is not full TeX compatibility. No MathJax or Lasem source is incorporated; no JavaScript engine runs in production rendering.

`tools/generate_math_radical_paths.py` extracts the five pinned radical path templates from `svgGeometry.js` and writes `src/coyote_math/math_radical_paths.ads/.adb`. It verifies the same pinned source SHA-256 documented for stretchy geometry. It is a dedicated generator; the JSON inventory generator does not generate Ada source.

## Bundled fonts

Every TTF below was SHA-256 checked byte-for-byte against `package/dist/fonts/` in the pinned archive. Identity does not imply usable metrics or qualified rendering.

| File under `fonts/` | SHA-256 |
|---|---|
| `KaTeX_AMS-Regular.ttf` | `68534840bcfdd2bffb6f0e8deb48684dd01e7f04ea2813267577afb906de1d13` |
| `KaTeX_Caligraphic-Bold.ttf` | `07d8e303ce4fc12b4bb54f1004170dd190a1f3db45d400fe68060df3e0897268` |
| `KaTeX_Caligraphic-Regular.ttf` | `ed0b74372feefcbb9c0666b2e210da37b7e49fa7fbbf3eeb11db5f693dacfbb7` |
| `KaTeX_Fraktur-Bold.ttf` | `9163df9c7122432e6495b4229fa9071cf9ae86a758ae5efc4924ec2e1a6dbce1` |
| `KaTeX_Fraktur-Regular.ttf` | `1e6f9579e90e2cac37f8f60a597c436e075c114385652b7cbeb0dec0421291b3` |
| `KaTeX_Main-Bold.ttf` | `138ac28d1663b3037e9c5f52371fa5c63d8324f4a38d22cd573e6ea3a3fd0cf8` |
| `KaTeX_Main-BoldItalic.ttf` | `70ee1f64a20f2048c21940ef46d0144fd215baa953ca69afd1e31e98544f708f` |
| `KaTeX_Main-Italic.ttf` | `0d85ae7cc30f23790a7f1a58c4a112fdca8aae769b6ba11429af1d98b1b6cb3a` |
| `KaTeX_Main-Regular.ttf` | `d0332f52868370fd83ae7fa46470f90c8f2eab2fcf12bc4f88080b340c95a830` |
| `KaTeX_Math-BoldItalic.ttf` | `f9377ab0271cda59af24bcffbd46a4d0c8a3572ffafdbb38de2ad5ea7b0d5ee5` |
| `KaTeX_Math-Italic.ttf` | `08ce98e51b04d58945a301e639e02b6998af29fdfd61a7b8afdd07bbfc479d4a` |
| `KaTeX_SansSerif-Bold.ttf` | `1ece03f79f95277d57dc7f6b435a74e1379b0d46104a8530286b60ff49369ea0` |
| `KaTeX_SansSerif-Italic.ttf` | `3931dd81faed86ba021bb2bbdc36f5bed9a38d6b4f4077aca59b265aa1b02083` |
| `KaTeX_SansSerif-Regular.ttf` | `f36ea897e19f4a2e571d1e900e4e3710e438deb05a842486045ba0a3e616a4ad` |
| `KaTeX_Script-Regular.ttf` | `1c67f068fea8bb09bf099c088b1cf64bd27516a6e07f4684344873564bb66a67` |
| `KaTeX_Size1-Regular.ttf` | `95b6d2f1a50173bfedb8c63e1d1c99b10427d0a4df4201cb44513b226951a22b` |
| `KaTeX_Size2-Regular.ttf` | `a6b2099fb555c60e3a0db3a08842ebf1d732c6eb4e4bf44913613bed4fc4e39b` |
| `KaTeX_Size3-Regular.ttf` | `500e04d54f0d51666332c9d2089aa803be22aa878eca539e59fa53c6e522b082` |
| `KaTeX_Size4-Regular.ttf` | `c647367d1dd4e162468717d020e1fc0f1dc5c26ebfdffbe55261713bf88c5877` |
| `KaTeX_Typewriter-Regular.ttf` | `f01f3e87d9c6a61c0c081ceb577abd864eb00a612f7ac1620dd6915fad2ef5aa` |

Font notice: `licenses/KaTeX-Fonts-MIT.txt`, copyright (c) 2018 Khan Academy; source <https://github.com/KaTeX/katex-fonts/blob/56e79c93c88c9054b017cc92e496b383e0bf82d7/LICENSE>. The source-code MIT notice is `licenses/KaTeX-MIT.txt`. These retained notices record provenance, not legal advice.

## Reproduction

Obtain and extract the fixed archive into `/tmp/katex`; do not install it as a runtime dependency. The generator checks source SHA-256 and parses its data-only export as JSON, with no JS evaluation:

```sh
python3 tools/generate_katex_data.py \
  /tmp/katex/package/src/fontMetricsData.js \
  /tmp/math_font_data.ads /tmp/math_font_data.adb
cmp /tmp/math_font_data.ads src/coyote_math/math_font_data.ads
cmp /tmp/math_font_data.adb src/coyote_math/math_font_data.adb

python3 tools/generate_metrics.py \
  /tmp/katex/package/src/fontMetricsData.js /tmp/math_metrics.adb
cmp /tmp/math_metrics.adb src/coyote_math/math_metrics.adb

python3 tools/generate_math_stretchy.py \
  /tmp/katex/package/src/svgGeometry.js /tmp/math_stretchy.adb
cmp /tmp/math_stretchy.adb src/coyote_math/math_stretchy.adb
```

The stretchy generator verifies `svgGeometry.js` SHA-256 `e7bb196633f23cab95da9d010ffbbdad37d2c942c2f96a33f8094f260ecfd892`; it extracts only its selected paths. The optional reference check uses Node and archive `dist/katex.js`, without npm installation. Run `test/tools/check-native-math.sh` with `NATIVE_MATH_ROOT` set to a persistent output directory; reference regeneration is separate from production build and qualification.

## Current evidence and browser-reference assets

The current evidence and qualification status are maintained in the
[coordinator-owned completion report](../../../plan/native-math-parity-test-report.md),
§8. The frozen final2 full suite passed 1061/1061 in 82.378580 seconds before
subsequent candidate changes; it is not current-source qualification. Latest
scoped geometry evidence is 145/145, but does not establish full compatibility.
Resource/timing qualification and human visual/accessibility acceptance remain
open. The [PCR-123 report](../../../plan/native-math-test-report.md), including
its 1042/1042 result, is historical.

Browser exporters use JS, CSS, package metadata and all 60 font-format files
extracted from the SHA-256-verified archive, not mutable package-directory CSS
or fonts. The 63-member browser-asset manifest SHA-256 is
`3e71d9db460b0d544a2aba0302db7aeee592ba88a08d457ec6e7860cf302cffc`.
This reference asset identity does not establish native pixel equivalence.

Generated symbol, built-in macro and Unicode tables use the pinned inventory
in `plan/native-math-katex-0.16.22-inventory.json`. Regeneration tools are
`tools/generate_math_symbols.py`, `tools/generate_math_macros.py`, and
`tools/generate_math_unicode.py`; each takes that inventory followed by output
specification/body paths and verifies its pin before writing. The inventory
itself is regenerated by `tools/inventory_katex.cjs` with the extraction and
verified archive as explicit inputs.

See the [coverage map](../../../plan/native-math-coverage.md),
[requirements](../../../requirements/native-math-compatibility.md),
[port plan](../../../plan/native-math-parity-plan.md), and
[test plan](../../../plan/native-math-compatibility-tests.md). These records do
not promote name/table correspondence or bounded probe results to full parity.
