# Array-rule construction budget — developer evidence

Date: 2026-11-15. Controlling report §11.16, PCR-125 OPEN.
No requirements/deviation changes, acceptance, release, installation or commit.

## Exact-final results

- `root-build-exact.log`, `test-build-exact.log`: development builds pass.
- `full-exact.log`:1076/1076, zero failures/errors;142.388395s cumulative,
  142.48s wall.
- `parser-final.log`, `parser-repeat.log`, `parser-valgrind.log`:706/706 each;
  strict parser Valgrind0 errors and0 lost bytes,113248 reachable. This does
  not exercise Pango. Macro fixture peak2443968 bytes remains unchanged.
- `comparisons/head/`: final probe against HEAD syntax, builds then706 checks
  with4 expected accounting failures. `comparisons/drift-before/`: final
  syntax with only first-row link reverted to copy/Replace_Element,706 checks
  with1 expected failure. This is a reconstructed mutation, not history.
- `jobs-final.log`:223/223; `ledger.log`:38/38; `geometry-final.log`:235/235
  using KaTeX0.16.22 restored outside product. npm EROFS/retry logs retained.
- `raster-final.log`:1116/1116 normal and Valgrind, strict script exits1:
  2 contexts,6656/2183/26-byte native losses. No suppressions/threshold changes.
- `gtk-exact.log`:9/9; `gtk-runner-exact.log`: containment self-test passes
  after deliberate killed/timed-out children; `http-exact.log`:offline pass.
- `coverage-final.log`: source crosswalk only, not qualification.
- `lifecycle-experiment/`: isolated PangoFC shutdown A/B fails strict Valgrind;
  no safe production fix established, possible losses vary. README's host
  date is later than controlling project date; raw logs remain unmodified.
- `review.md`, `review-final.md`: agent reviews; not independent acceptance.
  Earlier parser-worker/focused/full-final/prefix/head logs are intermediate;
  only exact/final706 logs above describe the final source. Failed polish
  experiments were abandoned; successful final controls are retained.

## Reproduction

From repository root: `alr build --development`, then
`(cd test && alr build --development --profiles=coyote=development)` and
`(cd test && xvfb-run -a ./bin/coyote_test)`. Focused runners:
`sh test/tools/check-math-parser-memory.sh`,
`sh test/tools/check-math-jobs.sh`, `sh test/tools/check-math-memory-budget.sh`,
`sh test/tools/check-math-geometry.sh`, `sh test/tools/check-math-raster.sh`.
Use runner-specific MATH_*_ROOT variables to retain output directories.
Run required Python GTK/containment/offline HTTP lifecycle tools after builds.
The comparisons retain their GPR, source and build/probe logs.

## Limits

Rule capacity charged through Parse return, not returned-node lifetime.
Nested temporary outer-growth copies, other strings/payloads, expander/layout/
semantic/native/font storage, allocator metadata, complete copies/cache and
whole-job/RSS remain outside accounting. Timing, font, parity, native lifecycle
and human acceptance gates remain OPEN. Self-review is not user acceptance.


## Next design gate

`ownership-assessment.md` maps the borrowed-account lifetime hazard and copy
sites. `design/native-math-retained-budget-proposal.md` is an unapproved design
proposal, not a product change. Approval is requested before retained ownership
migration; other scoped tasks are not claimed technically exhausted.
