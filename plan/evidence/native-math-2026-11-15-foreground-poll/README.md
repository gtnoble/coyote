# Cancellable foreground application — developer evidence

Project checkpoint:2026-11-15; baseline1c4952f. PCR-125;
REQ-MATH-010/014, MATH-LIMIT-002/MATH-REGRESS-001. No requirements,
numerical caps, memory accounting, font policy or storage ownership changed.
Host dates in original logs are preserved and can differ from checkpoint date.

## Implementation and contract

Engine and worker foreground passes formerly walked output commands without a
work poll. They now call `Math_Layout.Apply_Foreground`, which polls before every
command, including commands already explicitly colored. Only missing colors
are assigned. A scoped mutable vector reference changes color fields in place;
path/text payloads are not deep-copied just to update color. No reference spans
a poll, survives the helper, or overlaps container structural mutation.

Work is borrowed only for the call. A stop propagates with earlier commands
possibly colored; this is intentionally not a transactional box mutation.
Engine callers must not use an out result after an exception. Worker handlers
set Cancelled/Expired and clear raster output/lease before completion. Poll's
API now states that status is authoritative: a non-null non-Valid result may
retain source/diagnostics but geometry must not be adopted/painted. Always
release returned results. Both existing GUI consumers check Valid before
adoption; no GUI source change was needed.

## Deterministic tests

- Per-source calibration measures engine polls with Foreground_Set=False, then
  checks the enabled pass adds one poll per command. Sources include mixed
  scoped explicit-blue, all-blue and512-glyph output. Baseline+2 forces cancel
  and deadline in the foreground pass, distinct exceptions, preserved caller
  scope and next-request recovery. Output after exception is not inspected.
- Direct helper:empty box/zero polls, null Work, idempotence/explicit colors,
  path/text/clip/shadow/geometry payload preservation. Fresh first/third commands
  need fallback; cancellation at poll2 colors first only, leaving third untouched.
  Deadline at poll1 leaves fresh box unchanged. Append/delete after interruption
  proves no outstanding reference blocks later container mutation.
- Three completed non-raster worker jobs each have360 glyphs:240 fallback color,
  120 explicit blue. Alternate red/green fallback; exact source, command/color
  counts, no uncolored commands, zero raster charge/dimensions, Release nulls.
  This is worker integration, NOT deterministic active-worker color-phase stop
  injection. Existing worker cancellation/recovery runs remain general evidence.

## Results and provenance

| Check | Result |
|---|---|
| Untouched baseline probe |216/216; unchanged-baseline/ |
| Evolving pre-poll facade probe |243 assertions/9 expected failures; before-poll/ |
| Final engine |255/255 twice; engine/exact-run1.log and exact-run2.log |
| Exact final probe, no-poll mutant |255 assertions/13 failures, exit1; mutation/ |
| Final worker |300/300 twice; jobs/exact-run1.log and exact-run2.log |
| Root/test development builds |pass; existing warnings remain |
| Full Xvfb suite |1076/1076,zero failed assertions/errors;147.932737s cumulative,148.15s wall |
| Required GTK |9/9; synthetic runner7/9 child cases with expected kill/timeout and passing containment |
| Offline HTTP lifecycle |pass,loopback only |
| Engine Valgrind |255 assertions,zero errors/lost bytes;216713 bytes reachable |

The pre-poll243 probe was an evolving fixture (its mixed-source control was
then all blue); it is NOT a byte-identical final-probe baseline. Mutation is
stronger:all copied Ada sources except one poll removal match final source,
and the exact255-assertion probe is shared byte-for-byte. The single removed
poll is inside Apply_Foreground; other layout polls remain. Temporary project
and mutation manifests/logs are retained, not generated binaries/objects.

Validation records before/after production hashes and binary hashes. The final
spec documentation and production code were built together. Standalone probe
mains are not included in the AUnit full suite. Final manifest records exact
source/binary identity; implementation.patch excludes documentation changes.

Commands:root `alr build --development`; test `alr build --development
--profiles=coyote=development`; from test `timeout 300 xvfb-run -a
./bin/coyote_test`. Standalone `MATH_ENGINE_ROOT=/tmp/coyote-color-engine-final
sh test/tools/check-math-engine.sh` and
`MATH_JOBS_ROOT=/tmp/coyote-color-jobs-final sh test/tools/check-math-jobs.sh`.
Engine native check:`valgrind --max-stackframe=4194304 --error-exitcode=1
--leak-check=full /tmp/coyote-color-engine-final/bin/math_engine_probe`.
The4MiB frame classification threshold is the previously documented handling of
an existing2.6MiB semantic frame, not a suppression or relaxed leak criterion.
Mandatory Python checks and timing records are retained under validation/.
The worker warm2000-request sample is a small existing corpus, not overall
latency/resource qualification; full GTK adoption latency is not measured here.

## Limits and open work

No deterministic active-worker foreground-phase interruption, native-call
preemption or hard deadline guarantee is claimed. The engine and worker use the
same tested helper, but helper/facade evidence does not replace end-to-end
phase-controlled worker/GTK qualification. No browser/geometry/image/raster or
whole-macro Valgrind rerun. Prior strict raster losses remain open. Wider
explosive/combined-output seeded adversarial coverage, major-buffer guard
coverage, timing/font/lifecycle/parity/human acceptance remain open.
No new persistent shared-context admission cap or accounting redesign.
Developer/agent self-review is not independent acceptance. No release/install/
commit. Source crosswalk fingerprints refreshed; qualification counts unchanged.
