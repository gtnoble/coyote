# Native Ada math cutover — verification report

**Date:** 2026-10-22
**Change:** PCR-123
**Status:** Implemented; automated qualification passed. Human desktop visual
acceptance and live-provider qualification were not performed.

## Authorized scope and result

User authorized production completion of the reference-guided native Ada math
engine and complete retirement of MathML/Lasem, rather than retention of a
legacy renderer. Implemented the bounded common-math profile, completed-message
inline/display Markdown presentation, source fallback/copy and zoom reflow.
The production prompt now requests LaTeX. Scope is documented in
`share/coyote/math/README.md`; it is not a claim of full TeX compatibility.

Removed `Coyote_Lasem` spec/body/C bridge, `Coyote_Renderer.MathML`, five Lasem
tests and registration, Lasem include/link flags, current dependency guidance,
and prototype duplicate source/assets. Historical records remain superseded
facts. The shared engine is `src/coyote_math/`; installed data and MIT notices
are `share/coyote/math/`. Test tools use the same production engine.

## Automated evidence

| Check | Result |
|---|---|
| `alr build --development` | Pass; development profile |
| `cd test && alr build --development --profiles=coyote=development` | Pass; development profile |
| Full registered suite under Xvfb from `test/` | **1042/1042**, zero failures/unexpected errors, 76.446748 seconds cumulative |
| Focused `Coyote.Math` | **18/18** |
| Focused conversation-stack GUI | **40/40** under Xvfb |
| Markdown math extraction | **8/8** |
| Inline markup math | **5/5** |
| Standalone native qualification | **151 assertions**, zero failures; twenty rendered samples |
| KaTeX reference sanity corpus | 19 accepted / eight rejected expressions |
| Direct Ada/KaTeX layout comparisons | Three cases / six ascent-descent comparisons within 0.000001 em |
| Hash-checked metric regeneration | Byte-identical production table |
| Standalone Valgrind | Zero errors; zero definitely/indirectly/possibly lost bytes; no suppressions |
| Help workflow | Core and display-backed Help tests, Mallard validation/links, CLI checks pass |
| Runtime dependency inspection | `bin/coyote` and `bin/coyote_sqc` do not link Lasem |
| Whitespace | `git diff --check` passes |

Existing GTK theme CSS warnings occur under Xvfb. The signal/process-control
tests print `Terminated` as part of their isolated subprocess checks; the suite
still exits successfully. An initial full run passed 1040/1041: its invalid-math
fixture used the valid relation `<`. Replacing that fixture with an unknown
command resolved the failure; the final full run is recorded above.

Final logs:

- `/tmp/coyote-native-math-build-final.log`
- `/tmp/coyote-native-math-test-build-final.log`
- `/tmp/coyote-native-math-full-final.log`
- `/tmp/coyote-native-math-help.log`
- `/tmp/coyote-native-math-qualification/math-probe.log`
- `/tmp/coyote-native-math-qualification/production.png`
- `/tmp/coyote-native-math-valgrind-final.log`

Run standalone qualification with `sh test/tools/check-native-math.sh`. Exact
reference URLs/hashes, bundled font hashes and generator instructions are in
`share/coyote/math/PROVENANCE.md`. Valgrind's standalone probe tears down
Cairo/Fontconfig caches only after all owned objects finalize; this teardown is
never used in the running application. Still-reachable runtime allocations
are not reported as lost memory.

## Evaluation and limitations

Developer self-evaluation and read-only agent review found and corrected
coalesced Markdown-token restoration, signed glyph metrics, indexed radical
handling, double-bar output, fraction-rule direction, command whitespace,
style sizing, resource caps, Cairo/FreeType ownership, and inline mark/reflow
issues. A generated review sheet was inspected by the developer agent; it is
not a human visual acceptance result or pixel-equivalence fixture.

Tests qualify the listed cases and bounds, not the whole TeX dialect. The
reference comparisons are intentionally narrow, not a compatibility percentage.
General macro expansion, multilingual text shaping, arbitrary packages/fonts,
complete TeX typography and arbitrary extensible glyph assemblies remain outside
the documented profile. Missing-font and basic painter-error recovery are tested;
all native allocation failures and concurrent initialization are not injected.
Physical desktop interaction, PRIMARY selection semantics across inline objects,
assistive-technology behaviour, large-corpus differential/fuzz qualification and
live-provider output are not independently accepted. No compatibility engine
is retained for historical MathML.

Unrelated pre-existing process/signal-control working-tree changes were preserved.
No release build was requested or used.

Final audit regressions cover wide numerical operator limits, copying a
rendered formula alone, and preserving escaped raw XML tags in mixed prose.
The final full run passed 1042/1042; the strengthened numerical-limit assertion
was then rerun in the focused engine suite (18/18).
