# Parser AST budget review and isolated HEAD baseline

Date: 2026-11-15

## Scope and result

Read-only review of the current parser AST-accounting/finalization diff and `test/tools/math_parser_memory_probe.adb`; no production, test, or project documentation edits were made. The only repository writes for this review are this file and the baseline artifacts listed below.

The current recorded focused probe passes **688/688** (`final-probe.log`). The isolated HEAD baseline built and linked successfully, then ran the current extended probe: **688 checks, 5 failures** (`baseline-head-probe.log`). These are expected baseline failures, not build errors. All pre-existing Unicode/lexical/source/syntax controls pass in the baseline. The five failures are: AST-stage deadline observation; AST peak equality; live AST charge cancellation; local macro rollback on AST-budget failure; and Global_Group persistence on AST-budget failure. The AST fixture still returns the expected 2,049 nodes / 2,048 glyphs on HEAD, but there is no AST reservation/charge for the probe's threshold/callback assertions to observe. Baseline measured peak is 250,560 bytes, versus current final probe's 2,443,968 bytes.

## Baseline reproduction

The isolated tree is `/tmp/coyote-math-parser-ast-budget-head`. It contains a copy of `src/coyote_math/`, with only `math_syntax.adb` and `.ads` overwritten by `git show HEAD:src/coyote_math/math_syntax.{adb,ads}`, the current `math_parser_memory_probe.adb`, and an adjusted copy of `test/native/math_parser_memory.gpr`. Object files and executable are isolated under `/tmp/coyote-math-parser-ast-budget-head/obj` and `/bin`; source files in the worktree were not changed.

Build command, run from the repository root:

```sh
MATH_PARSER_MEMORY_ROOT=/tmp/coyote-math-parser-ast-budget-head \
  alr exec -- gprbuild -p \
  -P /tmp/coyote-math-parser-ast-budget-head/math_parser_memory.gpr
/tmp/coyote-math-parser-ast-budget-head/bin/math_parser_memory_probe
```

The exact GPR used is retained as `baseline-head-math_parser_memory.gpr`; it names `src` and `tools` relative to the isolated tree. Build output is `baseline-head-build.log` and probe output is `baseline-head-probe.log`.

## Review findings

### Production accounting and lifecycle

1. **Capacity reconciliation occurs after allocation.** In `src/coyote_math/math_syntax.adb:231-246`, the code precharges old plus requested capacity, calls `Reserve_Capacity`, then adjusts the reservation to actual capacity. If a vector implementation allocates more than requested, the excess old/new record-array overlap exists before it is charged; the later budget failure cannot make that allocation pre-admitted. This relies on exact requested capacity realization, an implementation assumption not stated as a portability guarantee.
2. **The metric is deliberately partial and transient.** `math_syntax.ads:133-139` explicitly excludes strings, nested payloads, expander storage, allocator metadata, and process memory, and releases charges at Parse return although the returned document retains its AST vectors. `Math_Syntax.Node` contains unbounded strings and an `Array_Rules` vector (`math_syntax.ads:72-87`), so this is not a bound on total AST allocation or retained-document memory. The declaration in `src/coyote_math/coyote_math_jobs.ads:84-89` correctly limits job metrics to parser-construction/raster workspace phases, not whole-job memory.
3. **Finalization ordering is structurally sound on inspected paths.** `Node_Reservation` precedes `State` in the declarative part (`math_syntax.adb:3326-3331`), so `State` and its source/token locals finalize before reservations. `Take_Result` copies scalar/text fields and moves node and diagnostic vectors (`3342-3351`); all early and normal returns call it (`3368-3370`, `3393-3395`, `3415-3417`, `3451-3453`, `3497-3499`). This avoids copying the node vector on successful returns. The probe does not inject allocation failures or controlled-component exceptions during text assignment/vector move/finalization, so exceptional ownership transfer is not directly qualified.
4. `Add` polls before node construction and after capacity growth (`227`, `247`), and the probe checks cancellation via a budget-observing callback. It does not establish a hard deadline or bounded interruption latency; no individual allocator/container operation is preemptible.

### Probe coverage, assumptions, and mistakes

- The `688` count is dynamic: `Check_Decomposition_Table` emits checks for every discovered Unicode decomposition (`test/tools/math_parser_memory_probe.adb:171-198`). It is not a stable count of 688 distinct static scenarios.
- AST coverage exercises one doubling-macro fixture, expecting 2,049 nodes and 2,048 glyphs (`454-490`); later usability coverage checks glyph count and presence of `x` (`555-578`). This tests one returned AST and one large growth path, not varied AST node kinds, nested payloads, repeated growth boundaries, or retained-memory lifetime.
- The AST baseline detector treats a charge increase of exactly `32 * Node_Record_Width` as evidence of the first node-array allocation (`99-109`); the predicted peak assumes capacity growth from 2,048 to 4,096 (`479-490`). This couples a test to current vector capacity and growth policy. It is not independently derived from the vector's actual capacity. Exact-fit and one-byte-short tests then use the measured peak as their threshold (`494-508`), so those establish threshold behavior for the implementation, not an independent proof that the peak formula is correct.
- The two “AST budget rejection” macro-state checks use `Expansion_Lexical_Bound + 32 * Node_Record_Width` as the budget (`580-624`). This depends on this input's lexical charge exactly and assumes budget rejection happens at first node capacity admission. It exercises local rollback and `Global_Group` persistence only if parsing reaches AST allocation and fails there; the baseline's 2 failures confirm that the failure location is specifically absent AST accounting in HEAD.
- **Portability defect in probe arithmetic:** token record byte width is calculated with `/ 8` (`139-146`, also `181-183`), unlike production node width's `System.Storage_Unit` computation. This assumes an eight-bit storage unit and a token size divisible by eight.
- The probe does not test vector allocator over-allocation, allocator failure, `Node` nested controlled-payload accounting, document copies surviving owner release under memory instrumentation, or exceptions during move/finalization. It does not independently verify total bytes allocated or RSS.

## Evidence inventory

- `baseline-head-build.log` — isolated GPR build and link output; successful.
- `baseline-head-probe.log` — 688 checks, 5 expected AST-feature failures.
- `baseline-head-math_parser_memory.gpr` — adjusted project file used by the isolated build.
- `final-probe.log` — current focused probe result, 688 checks and 0 failures.

## Unresolved limits

This review and probe do not qualify whole-job memory, allocator/RSS usage, controlled nested node payloads, returned-document retained lifetime, behavior under allocator failure, hard timing/deadline bounds, all AST kinds or capacity implementations, cross-platform `Storage_Unit`, or user acceptance. The baseline is a regression comparison for the current extended probe, not a full parser suite or product qualification.
