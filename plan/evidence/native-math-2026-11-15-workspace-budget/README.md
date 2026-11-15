# Raster workspace reservations — developer evidence

Date: 2026-11-15. Governing report: native-math-parity-test-report.md §11.13.
PCR-125 OPEN; feature NOT COMPLETE. No requirements/deviations changed.

## Results

- `root-build-final.log`, `test-build-final.log`: incremental development builds
  pass. Existing warnings remain; generated profiles select development.
- `full-final.log`: final binaries pass1076/1076, zero failed assertions or
  unexpected errors;148.559544s cumulative,148.66s wall. Earlier `full.log`
  passes1076/1076,149.597846s cumulative before final comment/test-only updates.
- `memory-budget-final.log`, `memory-build-final.log`:30/30 ledger assertions.
  Earlier `memory-budget.log` is29/29 before explicit nonzero-shrink assertion.
- `jobs-initial.log`, `jobs-repeat.log`, `jobs-build.log`:194/194 twice; warm
 2000 requests and saturation pass. Timing is headless characterization only.
- `raster-initial.log`, `raster-build.log`:1116/1116 normally and under Valgrind,
  but encompassing script FAILS because Valgrind reports2 unsuppressed contexts,
 6656 definitely lost,2183 indirectly lost and26 possibly lost bytes. Native
 Pango/Fontconfig traces match earlier totals, not proof of all leak causes.
- `gtk-final.log`:9/9; `gtk-final-raw/` retains individual logs.
  `gtk-runner-final.log`: abnormal-exit/timeout containment self-test passes;
  its intentional killed/timed-out fixtures yield7/9 synthetic successes.
  `http-final.log`: offline Plain/RPC lifecycle pass; no live-provider tests.
- `image-export-build.log`: image-export consumer compiles; no browser/oracle
  images were run. `coverage.log`, `coverage-check.log`: source crosswalk only.
- `root-build-initial.log`: initial compile failure due to missing Count_Type
  operator visibility. Corrected before successful builds/tests.
- `implementation.patch`, `manifest.json`, `SHA256SUMS`, `review.md`: code/test
  changes, identities, environment and scoped developer/agent review. This is
  not independent human acceptance. Binaries hashed, not bundled.

## Reproduction

From repository root:

```sh
alr build --development
(cd test && alr build --development --profiles=coyote=development)
(cd test && xvfb-run -a ./bin/coyote_test)
sh test/tools/check-math-memory-budget.sh
MATH_JOBS_ROOT=/tmp/coyote-math-workspace-jobs sh test/tools/check-math-jobs.sh
MATH_RASTER_ROOT=/tmp/coyote-math-workspace-raster sh test/tools/check-math-raster.sh
python3 test/tools/check-gtk-interactions.py
python3 test/tools/check-gtk-interaction-runner.py
python3 test/tools/check-http-timeout-lifecycle.py
python3 tools/map_math_coverage.py --check
```

The raster script exits1 for the recorded unresolved Valgrind failure; do not
label the script passing because its functional assertions pass.

## Scope and exclusions

Independent256MiB-default ledgers admit overlapping Cairo image/output-vector
bytes for full/tile render calls. Render_Into clears output on entry/failure
and removes the worker function-result assignment copy. Controlled reservations
release on exception. Native-font failure and post-vector-allocation cancellation
and deadline cleanup are directly tested. Exact/one-byte-short tests operate on
small buffers, not a physical256MiB whole-job allocation stress case.

Reservations end at render completion. Returned image/caller copies, owned
parser/tokens/layout/semantic data, font/native drawing internals and allocator
metadata are excluded. GNAT empty-vector requested-capacity allocation was
inspected; post-allocation capacity reconciliation is not portable preadmission
of arbitrary allocator over-allocation. This is not aggregate whole-job256MiB
or process RSS enforcement, all-cache qualification, hard timing, full corpus/
font/lifecycle qualification or visual/AT/user acceptance. Browser/geometry and
isolated resource characterization were not rerun. No release/install/commit.
