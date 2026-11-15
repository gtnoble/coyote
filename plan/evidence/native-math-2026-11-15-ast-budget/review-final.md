# Final review — AST node-construction accounting continuation

Date: 2026-11-15

## Scope and disposition

Read-only review of the production and focused-test diff, five requested documentation changes (`AGENTS.md`, `design/coyote-design.md`, `plan/native-math-compatibility-tests.md`, `plan/problems.md`, and `sdfs/frontends.md`), and retained evidence under this directory. This review writes only this file.

**No concrete scoped blocker was found in the final `Take_Result` cleanup change.** Findings requiring correction or qualification are listed below; none demonstrates that the empty-vector ownership change is incorrect. This is a scoped developer review, not independent acceptance or product qualification.

## Final cleanup review

In `src/coyote_math/math_syntax.adb`, `Take_Result` copies result metadata and moves `State.Item.Nodes` only when the source vector is nonempty (lines 3342–3355). The `Parse_Failure` handler clears the node vector and resets the root (lines 3492–3495); Ada vector `Clear` retains capacity, so the new guard avoids transferring that empty-but-capacity-bearing vector into an invalid `Document`. `State` is declared after `Node_Reservation` (lines 3326–3331), and therefore finalizes before the reservation owner. On this path, the cleared vector remains with `State` and its storage is released at scope exit; the call-local charge is also released at scope exit. Successful nonempty results still move the vector.

The parser probe has a malformed-input-after-AST case (`test/tools/math_parser_memory_probe.adb`, around lines 659–665) asserting invalid result and zero current charge. The final probe passes 688/688. This does not inject allocation failures or exceptions during controlled-field assignment, vector moves, or finalization; those exceptional paths are not qualified. No evidence found that this gap is a regression introduced by the emptiness guard.

## Evidence verified

- Exact-final full suite: `full-final.log` records 1076/1076, zero failed assertions and unexpected errors, cumulative 145.992924 s, wall 146.26 s, exit 0.
- Earlier `full.log`: 1076/1076, cumulative 145.382510 s, wall 145.50 s. This is the **pre-final** run and must not be presented as the final run.
- Parser probe: `parser-final.log` and `parser-repeat.log` each report 688 checks, zero failures, measured peak 2,443,968 bytes. The fixture assertions check a valid 2,049-node AST with 2,048 glyphs.
- Worker probe: `jobs-final.log` reports 223 assertions, zero failures. Ledger probe: `ledger.log` reports 38 checks passed.
- Required GTK interaction check: `gtk-final.log` reports 9/9. `gtk-runner-final.log` records the runner self-test passing abnormal-exit/timeout containment, continuation, private logs, and argument validation; its injected Unicode/bidi failures/timeouts are expected self-test cases, not a clean 9/9 interaction run.
- Offline HTTP lifecycle check: `http-final.log` reports pass for the Plain/RPC timeout lifecycle and ZERO-disable delayed success, using offline fixtures only.
- Raster: `raster-final.log` records 1116 assertions, zero failures, both normally and under Valgrind. The **strict native Valgrind script still fails**: 2 error contexts, 6,656 bytes definitely lost, 2,183 indirectly lost, and 26 possibly lost. Passing raster assertions do not make the strict check pass.
- Geometry attempt is blocked, not passed: `geometry.log` says `/tmp/coyote-katex-support-check/package` was not found.
- `git diff --check` passes.

## Findings and limitations

### Documentation timing correction

All five documentation additions currently label the full-suite run as 1076/1076 at cumulative 145.382510 s and wall 145.50 s. The retained exact-final artifact is 145.992924 s cumulative and 146.26 s wall. The earlier values are valid only if explicitly labeled pre-final; use the exact-final values for the final run in these five additions. This is a factual evidence-label correction, not a code blocker. No claim here treats the coordinated documentation update as already applied.

### Admission portability and metric scope

1. `math_syntax.adb` precharges old plus requested Node capacity before `Reserve_Capacity`, then reconciles to reported actual capacity afterward (around lines 231–246). If a vector implementation allocates more than requested, the extra overlap has already been allocated before the later reconciliation/possible budget rejection. The admission guarantee therefore relies on requested-capacity behavior and is not an implementation-independent pre-allocation bound. Keep the report's portability limitation explicit.
2. Node record-array bytes are a scoped metric only. Nested unbounded-string and `Array_Rules` payloads, allocator metadata/rounding, and other parser/expander/layout/native/font allocations are excluded. The charge ends when `Parse` returns even though a successful returned `Document` retains its nodes. Do not characterize this as whole-job, total AST, retained-memory, allocator, or RSS accounting.
3. The test's expected peak assumes the current vector growth path from 2,048 to 4,096 records and infers its baseline from a 32-record charge step (`math_parser_memory_probe.adb`, around lines 99–109 and 479–490). It is useful scoped regression evidence, not an independently established portable capacity bound.
4. The probe computes token-record width with `/ 8` (`math_parser_memory_probe.adb`, around lines 139–146), whereas production Node width uses `System.Storage_Unit`. This assumes an eight-bit storage unit and a byte-divisible token size; note this as a probe portability limitation.
5. Semantic coverage is focused: one macro-expansion fixture, selected budget thresholds/cancellation and macro-scope behavior, empty and malformed inputs, returned-AST usability, and the existing dynamic lexical/decomposition checks. It does not qualify all AST node kinds, all growth boundaries or vector implementations, nested payload accounting, allocator failure/controlled finalization failure, retained-document lifetimes under memory instrumentation, whole-job memory, hard deadlines, or user-visible parity/acceptance.

## Conclusion

The final guard prevents a syntax-failed cleared node vector's retained capacity from being moved into an invalid result; the observed finalization ordering and malformed-input probe support that intended behavior. The evidence supports the stated scoped Node record-array development checkpoint only. Correct the five full-suite timing labels to distinguish the pre-final run from the exact-final run; retain the strict Valgrind failure, missing geometry artifact, portability caveats, semantic coverage limits, and open broad qualification gates. No parity, whole-job resource, hard timing, lifecycle, human acceptance, release, installation, or completion claim is supported.
