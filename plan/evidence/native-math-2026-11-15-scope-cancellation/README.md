# Scope admission and cooperative macro capture — developer checkpoint

Project date:2026-11-15. PCR-125; SRS-MATH v1.1 REQ-MATH-003/010/014.
Source changes:math_macros.ads/.adb,math_syntax.adb,math_expander.adb;
existing engine and macro standalone probes extended. No new limits, storage
pools, retained-budget architecture or fine-grained accounting were introduced.
Host dates inside logs remain verbatim and can differ from this checkpoint date.

## Fixes and deterministic fixtures

- A successful caller/cleanup `End_Group` clears only `Scope_Limit` after replaying
  undo records and popping a real frame. `Unbalanced_Group` remains sticky until
  Reset; failed pushes do not create frames or trigger phantom caller pops.
- Parser entry checks pending diagnostics and scope admission before empty-input
  handling or expansion. All nested argument/environment/CD-row pushes check
  admission immediately. Failure retains source/no successful geometry.
- Full256 caller scopes reject a default empty/nonempty request. Caller pop to255
  permits default and Global_Group recovery without losing scoped/global values.
  Global_Group at full256 without pending diagnostic succeeds without a rootpush.
- Nested failure fixtures:caller255+root256 then sqrt argument/environment push;
  caller254+root255+environment256 then CD-row push. Cleanup restores caller depth,
  and subsequent ordinary request succeeds. These caller-created stacks are not
  a fresh-source nesting exploit: ordinary parser depth limit is128.
- `newcommand`, `renewcommand`, `providecommand` poll during default/replacement
  capture, parameter-count whitespace skip and replacement sequence staging.
  Stage optional-default and replacement tokens before a final precommit poll;
  no cancellation poll occurs between committing body and optional default.
  Stops during capture/staging cannot publish partial definitions; renewal keeps
  old body/default. This is not all-exception transactionality or native-call
  preemption; allocation exceptions inside macro mutation remain outside this
  cooperative-stop guarantee.
- 10000-token complete default/replacement fixtures exercise distinct cancellation
  and deadline exceptions, fresh-cursor same-context recovery, prior definition
  content and successful small controls. Poll thresholds32/10050 are cooperative
  test hooks, not wallclock bounds; partially consumed cursors are not reused.

Global definitions executed before a later genuine parser error still persist.
An intermediate CD test wrongly expected rollback of a leading gdef that had
already expanded; its211/1 failure is retained. Final CD blocked-body fixture
puts visible x before gdef to reach row admission first, with a separate leading
assignment persistence test. It does not weaken global assignment semantics.

## Baselines and verification

| Check | Result and log |
|---|---|
| Scope recovery before fix |187 assertions/4 expected failures; baseline-scope/ |
| Empty/admission ordering before fix |189/2 expected failures; scope-entry-before.log |
| Capture polling before fix |800 checks/8 failures including summary; baseline-poll/ |
| Default-copy ordering before fix |857/2 failures including summary; default-copy-before.log |
| Final engine |216/216 twice; engine/exact-run1.log,exact-run2.log |
| Final macros |873/873 twice; macros/exact-run1.log,exact-run2.log |
| Worker/parser regression |279/279 and719/719; focused/ |
| Root/test development builds |pass; profiles development; existing warnings remain |
| Full Xvfb suite from test cwd |1076/1076,zero failed assertions/errors;146.169067s cumulative,146.33s elapsed |
| GTK |9/9; synthetic runner7/9 expected kill/timeout containment passes separately |
| Offline HTTP lifecycle |pass; loopback only |
| Engine Valgrind |216 assertions;zero errors/lost bytes;216713 reachable;max-stackframe4194304 |
| Whole macro Valgrind |INCOMPLETE:outer180s batch timed out in existing32768-definition fixture before new capture cases;not a pass |

Pre-fix probes evolved; counts differ and these are NOT byte-identical final
probe baseline runs. Logs retain actual intermediate assertions and outcomes.
The complete production source was built before final standalone label/test-only
refinements; root AUnit binaries do not include these standalone probe mains.
The macro Valgrind termination log reports SIGTERM in Find/Define_Tokens and no
Memcheck errors up to termination, not a completed lifecycle qualification.
The existing O(n) context name lookup under that large fixture is not optimized
here. No Valgrind suppressions or leak criteria changes. Engine uses the already
documented4MiB stackframe-classification threshold for its2.6MiB semantic frame.

Commands:root `alr build --development`; test `alr build --development
--profiles=coyote=development`; from test `timeout 300 xvfb-run -a
./bin/coyote_test`. Standalone runners `check-math-engine.sh`,
`check-math-macros.sh`, `check-math-jobs.sh`, `check-math-parser-memory.sh`
under test/tools with MATH_ENGINE_ROOT/MATH_MACROS_ROOT/MATH_JOBS_ROOT/
MATH_PARSER_MEMORY_ROOT pointing to the manifest's /tmp roots. Engine native
check:`valgrind --max-stackframe=4194304 --error-exitcode=1 --leak-check=full
/tmp/coyote-math-scope-final-exact/bin/math_engine_probe`. Mandatory GTK and HTTP
Python runner names and timings are retained under validation/.

Source crosswalk hashes regenerated with tools/map_math_coverage.py;2930 core
rows remain2929 partial/unqualified+one deviation, not new qualified behaviors.
No browser/geometry/image/raster/large-fuzz qualification rerun. Existing strict
raster native losses remain open; headless engine result does not close them.

## Remaining scope

Shared-context persistent global definitions can accumulate tokens across
requests up to the definition-count cap; no separate aggregate token/byte cap
is introduced. Selecting a new cross-request admission policy requires a
requirements disposition (RD-CTX-01 remains unauthorized), not exact allocation
accounting. Wider adversarial/layout/output/GUI fallback, major-buffer coverage,
representative timing, native lifecycle/font/parity and human acceptance remain
open. No hard deadline or all-input resource guarantee. Developer/agent review
is not independent acceptance; no release/install/commit.
