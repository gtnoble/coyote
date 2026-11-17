# Final read-only review — array-rule budget diff

**Scope:** current `git diff` in `src/coyote_math/math_syntax.adb/.ads` and `test/tools/math_parser_memory_probe.adb`. No source edits; no full suite run during this review. Toolchain verified with `alr exec`: GNAT 15.2.0 (`gnat_native_15.2.1`).

## Findings

**No blocking defect found in the reviewed changes.** The earlier first-row-link accounting defect is corrected: `Parse_Array.Append_Row` now sets the array node’s `First` field through a scoped node-vector reference rather than copying/replacing the `Node`. `Append_Rule` similarly scopes node-vector references around rule-vector operations. In `Link`, `Parse_Expression`, and the ordinary/CD array append paths, references are scoped to end before calls to `Add`, `Poll`, or any outer `Nodes` mutation. `Add` itself holds no vector reference while it polls or grows the outer vector.

The aggregate reconciliation after outer node growth is present. `Add` first reserves the old/new node-record overlap, calls outer `Nodes.Reserve_Capacity`, reconciles node-record capacity, then sums the actual `Array_Rules.Capacity` of all stored nodes and updates the aggregate rule reservation before polling. GNAT’s active `a-convec.adb` confirms `Reserve_Capacity` allocates/copies elements before freeing old storage; controlled-vector `Adjust` copies only active elements (`new Elements_Type'(L, EA)`), not spare capacity. Thus copied nested rule vectors can compact to length, and recomputing capacities from the post-growth stored nodes prevents stale aggregate capacity from surviving outer growth. Temporary nested rule storage copied by that outer operation remains explicitly excluded by the API comment; no whole-operation accounting claim should be inferred.

Rule-vector growth follows the same runtime semantics: requested capacity larger than length causes a replacement allocation/copy before old storage is freed; the code pre-admits aggregate old-plus-new capacity, reads actual capacity, then reconciles the aggregate. Checked arithmetic covers byte multiplication/addition and doubling. The edits retain existing array row/column semantic checks; no new rule-count or array semantic cap was introduced. Rule count remains bounded only by existing source/node constraints, not by a new explicit rule limit.

## Regression and evidence

The focused probe now separately checks first-row link followed by later rules (12 rules retained), multiple top-level arrays, outer-node growth, measured rule-charge stages, cancellation/deadline at overlap, cleanup, and rule kind/boundary preservation through a later warning. This is meaningful regression coverage, though it does not add exact-fit/one-byte-short budget assertions specifically for the first-row-link-then-regrow shape.

The historical logs distinguish the regression result: `prefix-probe.log` (2026-11-15 19:06) reports **one failure** in “first-row link then rule growth observes exact old/new overlap”; `focused-probe.log` (19:29) reports **697 checks, 0 failures**, including the new link-preservation assertion and charge stages. This is evidence that the targeted accounting regression failed on the earlier modified implementation and passed after subsequent changes, not merely a comparison against HEAD. `head-probe.log` (19:31) is a separate baseline/control run and reports three rule-charge failures; it is not the evidence for the targeted drift failure. The probe is an instrumented Ada test with assertions, not an independent allocator/RSS measurement.

Source mtimes: `math_syntax.adb` 19:12:50, `math_syntax.ads` 18:04:13, probe 19:29:37. Focused build/probe logs are 19:29:55/19:29:56. Final root and test build logs and full-suite log are timestamped 19:37:21; their contents report successful builds and 1076/1076 with zero failed assertions or unexpected errors. Required GTK interaction log at 19:38:26 reports 9/9. GTK interaction-runner self-test at 19:38:28 reports its harness passed, while its deliberately exercised child run records Unicode exit -9 and bidi timeout (7/9 child scenarios passed); describe this as containment/self-test success, not a clean 9/9 interaction run. `git diff --check` passes at review time. Build warnings remain, including the unused `Rule_Capacity` local and style warnings.

These timestamps and checked-in evidence establish the recorded sequence, not cryptographic source-to-binary identity or a fresh rerun during this review. No release/qualification, allocator-level memory bound, or parity conclusion follows.

## Disposition

The prior blocker is resolved in the current diff, and no new semantic-bound or reference-lifetime blocker was identified. Keep the explicit nested-payload/outer-growth and allocator limitations, and the lack of an exact-fit/one-byte-short regression for the drift-specific fixture, visible in any future accounting claims. No code was changed and no full suite was run for this review.
ənd
