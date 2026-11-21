# Practical native-math abuse guards — scoped developer evidence

Date: 2026-11-15. PCR-125; SRS-MATH v1.1, REQ-MATH-010/014;
MATH-LIMIT-001/002 and MATH-REGRESS. No production source changed.

## Matrix and observations

| Layer | Deterministic input/control | Expected and observed |
|---|---|---|
| Engine expansion count | Local self-recursive macro, default 1000 expansions | EXPANSION_LIMIT; local definition unwound, prior global macro usable |
| Engine expansion tokens | Single #1 duplication of a 60000-character argument | TOKEN_LIMIT, not exponential-growth qualification |
| Engine depth | 130 nested square roots; eight-level valid control | nesting-depth rejection; moderate control accepted |
| Engine arrays | 65 rows and 65 columns independently; valid 64 controls | corresponding row/column errors; exact-cap controls accepted |
| Engine AST | x+ followed by 32768 glyphs | node-limit error |
| Engine dimension | 16385em kern | bounded-geometry error |
| Engine source | 65537 bytes | source limit; parser retains bounded 65536-byte prefix |
| Engine early stop | poll3 cancellation/deadline | distinct exceptions; unchanged scope, null-Work next request succeeds |
| Worker scales | binary64 qNaN, +/-Inf,0,-1,256.0001,257 | synchronous Invalid,id0,no raster reservation |
| Worker queue | eight paused jobs; ninth Busy; consume cancelled slot, retry identical ninth | retry completes Valid with exact source/timing |
| Worker recovery | duplication-token and 65-column failures, three cycles each | Invalid with specific cause, exact source,no pixels/lease; next x+y raster Valid; release returns ledger to zero |

Engine rejection sequence repeats twice; every rejection checks invalid parsed
output, no successful geometry, source identity/bounded prefix, restored scope
and a following ordinary request in the same context. Existing parser719 and
ledger38 tests cover scoped major-buffer admission/reuse. These are not a new
worker-level transient256MiB-budget injection test or complete allocation oracle.

The IEEE fixtures are gated by size64/radix2/mantissa53/emax1024. GNAT15.2
marks their values invalid; the hypothesized NaN bypass did NOT reproduce.
No unnecessary production guard change was made. A proposed400-digit source
dimension fixture hit the bounded-geometry guard, not an independent nonfinite
branch; it is not claimed as coverage. Early engine stop happens before macro
mutation; it does not prove rollback after mutation. Existing parser stop probes
provide separate scoped phase evidence.

## Execution and retained logs

- Root `alr build --development` and test
  `alr build --development --profiles=coyote=development`: pass; generated
  profiles development; existing warnings remain.
- `MATH_ENGINE_ROOT=/tmp/coyote-math-abuse-engine-final sh test/tools/check-math-engine.sh`:
  exact final174/174 twice (`engine/exact-run*.log`).
- `MATH_JOBS_ROOT=/tmp/coyote-math-abuse-jobs-final sh test/tools/check-math-jobs.sh`:
  exact final279/279 twice (`jobs/exact-run*.log`).
- Parser719/719; ledger38/38 (`parser/`, `ledger/`).
- From `test/`, `timeout 300 xvfb-run -a ./bin/coyote_test`: first1075/1076,
  zero assertion failures, one unexpected socket error; repeat1076/1076,
  cumulative149.023396s, elapsed149.203s. Focused failing case1/1 passes.
  Original failure is preserved, not waived or retrospectively fixed. Fixture
  uses fixed port18881 with SO_REUSEADDR; bind at llm_agent_tests.adb:3525.
  No proof of the specific collision source (`validation/`).
- Required GTK9/9, runner containment and offline HTTP lifecycle checks pass.
  Synthetic killed/timed-out containment children are intentional, not GTK passes.
- `valgrind --max-stackframe=4194304 --error-exitcode=1 --leak-check=full
  /tmp/coyote-math-abuse-engine-final/bin/math_engine_probe`:174 assertions,
  zero errors/lost bytes;216713 reachable. This headless engine does not exercise
  Pango/Cairo rendering teardown. Existing strict raster native losses remain open.
- Initial default Valgrind run failed with3131035 errors/336 contexts and a
  stack-switch warning recommending threshold2622536. Source has a2.6MiB
  semantic projection frame;4MiB stack-frame classification threshold removes
  that instrumentation artifact, without suppression or leak-threshold changes.
  Both initial and corrected logs retained (`additional/`).

No browser/images/geometry/raster/large fuzz qualification rerun. No hard
50/250ms proof, GTK source-fallback demonstration, full cache/font/lifecycle
qualification, parity or independent/user acceptance. AUnit registration count
is unchanged: added assertions are standalone probes, not new suite cases.
No executable/object directories retained; hashes identify local tested binaries.

## Open guard work

- Wider combined boundaries, real exponential expansion, output/layout work,
  repeated saturation and source-retention pressure; seeded adversarial corpus.
- End-to-end GTK fallback/reflow and worker cancellation/failure recovery,
  documented major-buffer guard coverage/estimates, representative timing.
- Public caller-created full macro-scope stack may leave a sticky context
  diagnostic. Read-only audit candidate, not established source-only exploit:
  fresh parser nesting is capped128 below macro scope256. Reproduce separately
  and define diagnostic recovery without erasing caller definitions/status.
- No storage-pool or retained-account migration prerequisite.

Developer/agent self-review is not independent acceptance. PCR-125 OPEN.
