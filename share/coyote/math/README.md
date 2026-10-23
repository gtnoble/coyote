# Native mathematical notation

Coyote parses and lays out mathematical expressions in Ada and paints glyphs
and rules through Cairo/FreeType. There is no JavaScript, browser, MathJax,
KaTeX, or Lasem runtime dependency. KaTeX 0.16.22 is a pinned development
reference and the source of bundled font metrics/assets; see PROVENANCE.md
and the retained MIT notices in `licenses/`.

## Delimiters and presentation

- Inline: `$x^2$` or `\(x^2\)`.
- Display: `$$...$$` or `\[...\]`, including standalone multiline blocks.
- Code spans, fenced/indented code, and link destinations are protected.
- Ordinary dollar amounts are not intended as math; escape an ambiguous dollar
  as `\$`. Dollar opening/closing whitespace and following-digit rules apply.
- Typesetting occurs when a response block completes. Streaming remains text.
- Unsupported input, missing fonts, and exceeded limits leave source visible.
- Inline clipboard copying reconstructs the original delimited LaTeX rather
  than copying the raster image or losing the hidden source.
- Zoom rerenders inline formulas using stable text marks; foreground colour
  follows the text view. Display formulas use native Cairo drawing.

## Supported common-math profile

The parser accepts brace groups, ASCII letters/digits/punctuation and ordinary
math whitespace; lowercase/uppercase Greek commands; named relations, arrows,
set operators, and common symbols. Layout includes:

- `\frac`, `\dfrac`, `\tfrac`.
- Superscripts/subscripts, including both attached to one base.
- `\sqrt` and `\sqrt[index]`.
- `\sin`, `\cos`, `\tan`, `\log`, `\ln`, `\exp`, `\lim`, `\max`, `\min`.
- `\sum`, `\prod`, `\int`, display sum/product limits and `\limits`.
- `\text`, `\mathrm`, `\mathbf`, `\mathbb`, `\mathcal` within available fonts.
- `\left...\right` parentheses, brackets, braces, bars, double bars and invisible
  delimiters. Natural font variants are used; oversized delimiters fail visibly.
- `\hat`, `\bar`, `\vec`, and composed `\ne`/`\neq`.
- `matrix`, `pmatrix`, `bmatrix`, `Bmatrix`, `vmatrix`, `Vmatrix`, `cases`,
  `aligned`, `align`, and `gathered` environments, with bounded rows/columns.
- Explicit `\,`, `\;`, `\!`, and `\quad` spacing.

This is **not full TeX or complete KaTeX compatibility**. Arbitrary macros,
package/file inclusion, general Unicode text shaping, arbitrary math fonts,
all AMS/package commands, and unrestricted delimiter/radical assemblies are
not implemented. Unsupported commands are errors, not literal command-name
substitutions. Text handling is a bounded roman math-text facility, not a
replacement for Pango's multilingual prose shaping. Font/style and accent
geometry are not asserted to be pixel-identical to a browser engine.

The MathML extractor, binding, C bridge, tests and runtime dependency have
been removed. Old XML-shaped formulas are not typeset by a compatibility
engine. Source remains available as text; historical development logs describe
superseded behaviour rather than a supported legacy path.

## Bounds

Each parsed expression is limited to 4096 source bytes, 2048 syntax nodes,
32 argument levels, and arrays of at most 32 rows/columns. Oversized parser
input retains only a bounded prefix; the presentation layer retains the full
original source for fallback. Layout has command-count and geometry bounds.
Markdown extraction limits display formulas to 64 per response extraction;
inline realization tracks at most 64 formulas per text view. Excess content
remains source text. Raster dimensions and zoom are independently bounded.
Native rendering is performed on the GTK main task; no worker touches GTK.

## Verification and maintenance

The registered suite contains headless `Coyote.Math`, Markdown extraction and
GUI render/copy/reflow tests. Standalone checked native qualification:

```sh
sh test/tools/check-native-math.sh
```

It produces a twenty-sample review sheet and counted checks under
`/tmp/coyote-native-math-qualification/` by default. Optional reference and
metric-regeneration commands are in PROVENANCE.md. The developer's recorded
results are in `plan/native-math-test-report.md`. Development reference tools
are not installed as runtime requirements.
