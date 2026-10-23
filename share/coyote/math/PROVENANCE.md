# Native math provenance

## Primary reference

KaTeX **0.16.22**, fixed npm distribution:

- URL: <https://registry.npmjs.org/katex/-/katex-0.16.22.tgz>
- Archive SHA-256:
  `e9e0d167db3175481cbadaff38e8d90b130f6a3ddb451a47e43c577fd511f365`
- `src/fontMetricsData.js` SHA-256:
  `1e72fc6b451a565e60b1eb7e89f4738eb74f35edfcf3c9c273015700b42ae04d`
- Source reference: <https://github.com/KaTeX/KaTeX/tree/v0.16.22/src>
- Copyright (c) 2013-2020 Khan Academy and other contributors.
  MIT notice retained in `licenses/KaTeX-MIT.txt`.

`src/coyote_math/math_metrics.adb` is generated from all nine font tables used
by the native engine: Main Regular/Bold, AMS Regular, Caligraphic Regular,
Math Italic, and Size 1 through Size 4. It preserves widths, signed
heights/depths and italic corrections; skew is not yet consumed. The syntax
parser is an independently written bounded subset, not a translated KaTeX
parser. Layout adapts selected algorithms/data from `functions/genfrac.js`,
`functions/supsub.js`, `functions/sqrt.js`, `spacingData.js`, `Style.js`, and
`fontMetrics.js`; it is not an exact port. The MIT notice applies to derived
algorithms/data as appropriate.

No MathJax or Lasem source is incorporated. No JavaScript engine runs in the
native math renderer or its standalone qualification probe.

## Fonts

Nine TTFs are used by the native engine and copied unchanged from the same
KaTeX 0.16.22 distribution:

| File under `fonts/` | SHA-256 |
|---|---|
| `KaTeX_AMS-Regular.ttf` | `68534840bcfdd2bffb6f0e8deb48684dd01e7f04ea2813267577afb906de1d13` |
| `KaTeX_Caligraphic-Regular.ttf` | `ed0b74372feefcbb9c0666b2e210da37b7e49fa7fbbf3eeb11db5f693dacfbb7` |
| `KaTeX_Main-Bold.ttf` | `138ac28d1663b3037e9c5f52371fa5c63d8324f4a38d22cd573e6ea3a3fd0cf8` |
| `KaTeX_Main-Regular.ttf` | `d0332f52868370fd83ae7fa46470f90c8f2eab2fcf12bc4f88080b340c95a830` |
| `KaTeX_Math-Italic.ttf` | `08ce98e51b04d58945a301e639e02b6998af29fdfd61a7b8afdd07bbfc479d4a` |
| `KaTeX_Size1-Regular.ttf` | `95b6d2f1a50173bfedb8c63e1d1c99b10427d0a4df4201cb44513b226951a22b` |
| `KaTeX_Size2-Regular.ttf` | `a6b2099fb555c60e3a0db3a08842ebf1d732c6eb4e4bf44913613bed4fc4e39b` |
| `KaTeX_Size3-Regular.ttf` | `500e04d54f0d51666332c9d2089aa803be22aa878eca539e59fa53c6e522b082` |
| `KaTeX_Size4-Regular.ttf` | `c647367d1dd4e162468717d020e1fc0f1dc5c26ebfdffbe55261713bf88c5877` |

The font project's MIT notice is retained separately as
`licenses/KaTeX-Fonts-MIT.txt`, copyright (c) 2018 Khan Academy. Notice source:
<https://github.com/KaTeX/katex-fonts/blob/56e79c93c88c9054b017cc92e496b383e0bf82d7/LICENSE>.
This records reference provenance, not a legal opinion on future additions.

## Reproduction

Extract the fixed archive to a temporary directory; do not install it as a
runtime dependency. The production generator verifies the source-file
SHA-256 before parsing its data-only export as JSON (no JS evaluation):

```sh
python3 tools/generate_metrics.py \
  /tmp/katex/package/src/fontMetricsData.js /tmp/math_metrics.adb
cmp /tmp/math_metrics.adb src/coyote_math/math_metrics.adb
```

The optional development reference check requires Node and that archive's
`dist/katex.js`, but no npm dependency installation. Run
`test/tools/check-native-math.sh` with `NATIVE_MATH_ROOT` set to a persistent
output directory, then run
`node test/tools/check-math-reference.cjs \
  /tmp/katex/package/dist/katex.js \
  "$NATIVE_MATH_ROOT/math-probe.log"`. Reference regeneration remains separate
from building or executing the native qualification probe.
