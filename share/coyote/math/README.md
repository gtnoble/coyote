# Native mathematical notation

Coyote tokenizes, expands, parses and lays out mathematical expressions in Ada,
and paints glyphs, rules and paths through Cairo/FreeType. There is no
JavaScript, browser, MathJax, KaTeX or Lasem production runtime dependency.
KaTeX 0.16.22 is the pinned development reference and source of bundled data
and font assets; see [PROVENANCE.md](PROVENANCE.md) and `licenses/`.

**The native compatibility project is not complete.** The implementation below
is broader than the original common-math subset, but is not full TeX or KaTeX
compatibility. The approved target and current results are separate documents:

- [Requirements](../../../requirements/native-math-compatibility.md).
- [Implementation checkpoint report](../../../plan/native-math-parity-test-report.md),
  especially coordinator-owned latest-status §9; §8 is a dated prior checkpoint.
- [Per-entry coverage map](../../../plan/native-math-coverage.md), which records
  missing and partial/unqualified entries, not a compatibility percentage.

## Delimiters and presentation

- Inline: `$x^2$` or `\(x^2\)`.
- Display: `$$...$$` or `\[...\]`, including standalone multiline blocks.
- Code spans, fenced/indented code and link destinations are protected.
- Escape ambiguous dollar amounts as `\$`; math delimiter whitespace and
  following-digit rules also apply.
- Streaming remains text. Completed response blocks submit math jobs; source
  stays visible while a formula is pending or if processing fails.
- Inline Copy reconstructs the original delimited input rather than copying
  the raster image or exposing internal markup.
- Two native workers compute syntax, semantics and layout. Display formulas
  are rasterized off-thread and adopted in batches on the GTK main task;
  inline raster painting still runs on that task. Workers never mutate widgets.
- Zoom/reflow uses cached inline syntax/layout. Display scale changes currently
  submit a fresh independent request; cached-AST-only display repaint is not
  implemented.
- Display formulas have a collapsed **Math structure** expander. It presents
  source-linked semantic nodes in a native keyboard-navigable tree, populated
  incrementally. This is not completed human screen-reader qualification.

## Implemented feature families

Support is bounded and uneven within each family. A recognized name or an
available table is not proof that all mode, argument, layout and error behavior
matches KaTeX.

- Fractions (`\frac`, `\dfrac`, `\tfrac`), binomials, scripts, roots and indexed
  roots; selected natural and extensible radical/delimiter geometry.
- Named functions and full-word operators, including `\lim`, `\max`, `\min`,
  common trigonometric/logarithmic functions and operator-name forms; sums,
  products, integrals and script-placement controls.
- Common accents including `\dot`, `\ddot`, `\hat`, `\tilde`, `\widehat`,
  `\widetilde`, `\bar`, `\overline`, `\underline` and selected arrows/vectors.
  The originally reported heat-balance equation now produces native output
  including its dot glyph.
- Over/under annotations, boxes, phantoms, overlaps, explicit math styles and
  selected color commands. Font commands use bundled faces where metrics exist.
- Matrix/cases/aligned families, `array`/`subarray` column specifications,
  `alignat`/`alignedat`, and limited display equation/tag handling. Not all
  registered environments, numbering rules or column constructs are implemented.
- Explicit spacing and selected dimension/atom-class primitives.
- Scoped textual definitions, including `\def`, `\gdef`, `\newcommand`,
  `\renewcommand`, `\providecommand`, `\let` and selected expansion controls.
  The engine defaults to fresh macro state per formula; explicit shared native
  contexts are available to callers. General optional-argument/default and
  definition semantics remain incomplete.
- Generated tables contain 318 built-in string templates and 2,203 retained
  mode-specific symbol keys. These include aliases/internal entries; templates
  may still expand to unsupported primitives. All 20 native callable core
  built-ins have source paths; this is not comprehensive semantic qualification.
- Registered Unicode symbols, selected precomposed/combining accent mappings,
  and Unicode subscript/superscript substitutions. This is not general Unicode
  text shaping or full text/math mode compatibility.

Twenty TTF faces are bundled. Upstream supplies 18 metric tables containing
2,038 glyph records; two named faces have no source metrics. Font-file identity
and table presence do not establish renderability for every character.

## Unsupported behavior and fallback

Feature-family coverage has expanded: brace annotations, bidirectional and
under-arrows, cancellation/strike-through forms, sizing, and left equation
tags have implementations. Their presence is not evidence that all syntax,
geometry, clipping, labeling or option interactions match the reference.
Other missing commands, missing fonts and exceeded bounds retain visible source
on failure.

Formula input cannot load files/packages, fetch images or URLs, execute
processes, or apply arbitrary HTML/CSS. Recognized trust-gated commands have
bounded refusal/diagnostic handling, not active trusted effects; full refusal
and error-color equivalence is unqualified. Surrounding Markdown images follow
the application's separate local-image policy.

The approved native profile excludes browser markup serialization, the
JavaScript API, caller JavaScript callbacks/macros, trusted browser effects,
unbounded expansion/sizing, and optional contrib extensions. These exclusions
do not excuse missing core mathematical behavior. `maxSize` is clamped to the
implemented bounded range 1..100; `leqno` is implemented. Fleqn has focused
GUI-option coverage, not full option-equivalence qualification; fleqn affects
display math only, adding a 2 em left margin (48 px at 24 px/em; 96 px
at 48 px/em). The default remains centered with no indent, and inline math is
unaffected. `trust=true` is unsupported; `trust=false` is the
explicit untrusted profile. A scoped engine probe passes for
`colorIsTextColor`, but broad color behavior and interactions remain
unqualified.

Legacy MathML-shaped source remains text-only. The retired MathML/Lasem
extractor, bridge and renderer have not been restored.

## Current implementation limits versus requirements

| Area | Current implementation | Approved target / qualification gap |
|---|---|---|
| Source | 65,536 UTF-8 bytes | Boundary checks exist; original presentation source retained for fallback |
| Syntax | 32,768 nodes, argument depth 128 | Same numerical target; complete interaction/resource qualification open |
| Arrays | At most 64 rows and 64 columns | All other budgets apply too |
| Macro expansion | Default 1,000; configurable through 10,000 | Token ceiling 131,072; complete expansion semantics unqualified |
| Layout | Depth 256; 131,072 draw commands; 16,384 em geometry | Numerical depth/command targets match; exact-boundary and broader budget qualification remain open |
| Presentation | At most 64 display formulas per extraction and 64 inline formulas per text view | Excess remains source text |
| Raster dimensions | Inline 2,000×512 including padding; display bounded by 8,192×4,096 | Scale, workspace and GUI adoption checks also apply |
| Job service | Two workers, eight pending descriptors; 250 ms deadline and retained-source ledger | Deadline checks do not prove cooperative preemption or queue-inclusive latency compliance |
| Memory/cache | Raster workspace checks and retained-source accounting exist | Whole-job 256 MiB and process-wide 64 MiB raster-cache targets are not qualified |

Do not read the source-ledger cap as a bound on all parser/layout/font/raster
allocations. `REQ-MATH-010` whole-job memory is not bounded by allocator
instrumentation. The separate 64 MiB retained-raster ledger accounts for GUI display-math
Cairo surfaces, not inline rasters or the process-wide cache target. The 250 ms deadline check does not interrupt a
blocking native call. GTK adoption has a 5 ms soft quantum/eight-operation
batch, not a hard 50 ms bound; none of these qualify the approved targets.

## Verification and maintenance

The coordinator-owned [completion report](../../../plan/native-math-parity-test-report.md)
§9 is the latest status; §8 remains a dated prior checkpoint. The latest
supplied development suite passed 1062/1062 with zero failed assertions or
unexpected errors in 82.228506 s
(`/tmp/coyote-next-frozen-full.log`), which is regression evidence only. Scoped
evidence includes engine 57 pass, macro assertion count as recorded in §9, 133
jobs checks with 2,000 valid warm requests (p95 1 ms, maximum 2 ms), geometry
145/145, structured pilot 16/16, image pilot 3/3, and 156 native assertions in
aggregate, including one case with 100 nested groups and one with 17,000 glyphs.
One added fleqn widget test brings `Conversation_Stack` to 48 total registrations.
Fleqn affects display math only, adding a 2 em left margin (48 px at 24 px/em;
96 px at 48 px/em); default display stays centered with no indent, and
inline math is unaffected. None of these establishes full parity. In particular, the
structured path pilot uses 0.01 normalized units, not image geometry; full
origins, widths, and option effects remain unmeasured. `colorIsTextColor` has a
scoped passing engine probe, but broad color qualification is not established.

The deterministic 10,000-case fuzz run reported 4,184 successful parses, 5,221
parse errors, 595 policy errors, zero layout failures and deterministic
repetition. This bounded corpus is not memory or whole-job budget qualification.
Coverage totals are coordinator-generated and may be stale; consult the current
report and regenerated map rather than hardcoding totals. Native callable-path
presence is not complete semantic qualification. Human visual/accessibility
acceptance remains pending.

Run bounded native smoke checks from the repository root:

```sh
sh test/tools/check-native-math.sh
sh test/tools/check-math-tokens.sh
sh test/tools/check-math-macros.sh
sh test/tools/check-math-jobs.sh
```

Pinned-reference checks require the verified KaTeX archive/extraction. The
browser/image checks also require the documented development browser tools;
image comparison additionally uses Python with Pillow, NumPy and SciPy.
No reference tool is a production dependency.

```sh
sh test/tools/check-math-differential.sh \
  /tmp/coyote-katex-support-check/package \
  /tmp/coyote-katex-support-check/katex.tgz
sh test/tools/check-math-geometry.sh
sh test/tools/check-math-browser.sh
sh test/tools/check-math-images.sh
```

The recent focused geometry corpus passed 145/145; this does not establish full
origins, widths, option effects, or all reference geometry. Frozen structured
and image pilots passed 16/16 and 3/3, but the structured path comparison uses
normalized units and the image pilot is not calibrated visual acceptance.
Do not interpret smoke checks or pilot passes as full qualification. See the
coordinator-owned report for exact commands, scope, log paths, resource limits,
and open acceptance gates. The older
[PCR-123 report](../../../plan/native-math-test-report.md) is historical.
