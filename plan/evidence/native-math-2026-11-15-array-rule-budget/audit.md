# Read-only final audit — array-rule construction accounting

Date: 2026-11-16. Scope: current repository state and PCR-125 §11.16 evidence. No test suite was run for this audit. No files were changed except this audit record.

## Outcome

The scoped implementation and the material §11.16 claims are supported by source and preserved exact-final evidence. No discrepancy requiring a code or documentation correction was found in the requested scope. This is a read-only evidence audit, not qualification or acceptance; PCR-125 remains OPEN and the feature NOT COMPLETE.

## Implementation review

- `src/coyote_math/math_syntax.adb` owns a Parse-local rule reservation alongside the node reservation. On array-rule growth it admits aggregate currently charged capacity plus the replacement capacity before `Reserve_Capacity`, polls around the growth, then reconciles to actual capacity. Checked arithmetic is used for byte/capacity calculations.
- `Add` recalculates surviving rule-vector capacities after outer node-vector growth. This does not account for nested vectors temporarily copied during that reallocation; that exclusion is correctly stated in the spec/report.
- Rule charges are call-local and end when `Parse` returns. The spec correctly excludes retained document/copy lifetimes, nested payloads, strings, allocator overhead and process memory. No new rule-count semantic limit was introduced; existing parser/source bounds remain separate.
- Link changes use scoped node references; the references end before later polls or mutation/growth. First-row linking now mutates the existing array node in place rather than replacing a copied node, avoiding the capacity drift described in the report.
- The test probe exercises multi-array aggregation, first-row regrowth, outer node growth, rule kinds/boundaries, cleanup, and cancellation/deadline at measured overlap. Exact-fit/one-byte-short and held-charge cases verify admission and cleanup but are not by themselves independent defect detectors; the live charge-stage test supplies that observation.

## Evidence and chronology

- `comparisons/head/probe.log` reports 706 checks with four expected accounting failures. `comparisons/drift-before/probe.log` reports 706 checks with exactly one failure: the live 4/12/8/24/16 charge-stage assertion. The retained mutation changes only first-row linking back to copy/`Replace_Element`; its README explicitly identifies this as a reconstructed defect, not a historical snapshot. Thus the observer does detect the reconstructed first-row defect, without conflating it with historical behavior.
- Exact-final `parser-final.log` and `parser-repeat.log` each report 706/706. `parser-valgrind.log` reports 706/706, zero errors and zero lost bytes (113248 bytes reachable). This parser probe is not evidence about Pango/native-shaping lifecycle.
- `full-exact.log` reports 1076 successful tests, zero unexpected errors; the documented 142.388395-second cumulative and 142.48-second wall values are consistent with the checkpoint. No full-suite rerun was made here. Earlier full/parser logs are correctly identified as intermediate in the evidence README/report.
- `geometry-final.log` reports 235/235, with the README identifying restored test-only KaTeX 0.16.22. `raster-final.log` records 1116 assertions passing in normal and Valgrind runs, but Valgrind exits with two error contexts and 6656 definite, 2183 indirect, and 26 possible lost bytes. The README/report correctly call the strict raster run a FAIL; the assertion pass is not represented as a clean memory check.
- `gtk-exact.log` reports 9/9. The containment self-test log intentionally shows its synthetic child run as 7/9 (one killed child and one timeout), then reports the containment self-test itself PASS. This is not a clean 9/9 GTK interaction run; §11.16 describes it as a containment self-test and explicitly explains the synthetic result. Offline HTTP lifecycle log reports its offline fixture pass.
- Build logs show successful development builds and existing warnings. No release/clean-build claim is made.

## Documentation synchronization and open items

The current continuation is recorded consistently in report §11.16, `AGENTS.md`, `design/coyote-design.md`, `sdfs/frontends.md`, `plan/native-math-compatibility-tests.md`, and the current PCR-125 entry in `plan/problems.md`. These references agree on scope, exact-final totals, the strict raster failure, the reconstructed mutation-control status, exclusions, and open gates. The README/manifest identify the exact evidence set and distinguish intermediate results. The coverage artifact is characterized as a source crosswalk, not qualification.

The explicit blockers/gaps remain those documented: strict raster-Valgrind native losses; incomplete whole-job memory/RSS accounting, including nested copies and other parser/expander/layout/native/font/cache lifetimes; timing and font/rendering gates; broader parity/corpus gaps; native lifecycle; and independent desktop/accessibility/user acceptance. These remain open, not inferred resolved by this audit. No acceptance conclusion is offered.

No further edits are recommended from this audit. No code, design, test, report, SDF, or AGENTS file was edited.
