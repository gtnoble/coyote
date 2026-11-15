# Inline worker rasterization — developer evidence

Date: 2026-11-15. Governing report: `plan/native-math-parity-test-report.md`
§11.11. Scoped PCR-125 developer evidence; feature remains NOT COMPLETE.
No complete parity, resource/timing qualification, human acceptance or release.

## Final results

- `root-build-exact-final.log`, `test-build-exact-final.log`: incremental
  development builds pass. Profiles select development; existing warnings remain.
- `full-exact-final.log`:1076/1076, zero failures/errors,148.864532s cumulative,
  149.03s wall. Two new GUI cases bring Conversation_Stack registration to57.
- `jobs.log`, `jobs-build.log`, `jobs-probe.log`:170 assertions, zero failures.
  Direct text-style reference pixel/origin/baseline comparisons and actual lease
  release. 2000 warm requests and saturation are headless characterization only.
- `gui-adoption-final.log`, `gui-partial-enhanced.log`: strengthened focused
  tests before the final test-only removal of global worker shutdown; the exact
  final full suite includes the final forms. `gui-inline-copy.log` and
  `gui-hit-test.log` record earlier focused regression passes.
- `gtk-exact-final.log`:9/9, raw logs in `gtk-interactions-3ck88zho/`.
- `gtk-runner-exact-final.log`: containment check exits0; intentional SIGKILL
  and timeout produce7/9 synthetic fixture successes. Temporary fixture logs
  are deleted by that harness; its stdout is retained, not those raw files.
- `http-exact-final.log`: offline Plain/RPC timeout and zero-disable checks pass.
- `coverage.log`, `coverage-check.log`: deterministic source crosswalk refresh
  and check. 2929 partial/unqualified core rows, one deviation; zero qualified.
  Hash refresh also captures source from prior increments; no new math-engine
  implementation changes are part of this increment.

The first full snapshot also passed1076/1076; it preceded strengthened tests.
Initial root/test compilation errors and unmatched filters remain in their
original logs; they are not passes. No runtime assertion failure occurred in
this increment. Read-only review caught permanent-Busy retry and stale-image
cleanup before final verification. Reviews are developer/agent evidence, not
independent acceptance. Comment-only API clarification and documentation were
added after the final full run; executable code and tests did not change.

## Implementation and limits

Rich_Text requests text-style worker rasterization at the view pixel-em/color.
GTK incrementally copies padded Pixbufs in eight-row/cooperative5ms steps with
separate actual-stride leases. Source remains visible until fresh-result commit.
Font reflow resubmits; mutation/clear/replacement/destruction discard partial
state. Twelve formulas exceed the eight-slot queue before GTK polling and all
commit through transient-Busy retries. No GTK synchronous-render helper call
occurs in the production insert/reflow regression; a direct legacy control
increments its counter.

Adoption pixels are compared to independent GDK conversion of a Cairo surface
populated from worker raster bytes: RGB tolerance1 for integer division, exact
alpha/padding. Worker probe reference comparisons are exact. Browser image
thresholds are unchanged. Worker fractional painting replaces legacy inline
ceiled paint positioning; rise uses the worker ceiled baseline plus padding.

No browser corpus, geometry, standalone raster, whole-job resource or Valgrind
run was performed here. Earlier image95/95, geometry235/235 and raster1108/1108
are historical §11.10 evidence. Whole-job256MiB, all process caches, hard250ms,
warm p95/GTK50ms, complete tiling/repaint reuse, font pins/bearings/shaped ink,
parent clipping,60 callable gaps, lifecycle and human acceptance remain open.

## Reproduction

From repository root, using existing local development dependencies:

```sh
alr build --development
(cd test && alr build --development --profiles=coyote=development)
(cd test && xvfb-run -a ./bin/coyote_test)
sh test/tools/check-math-jobs.sh
python3 test/tools/check-gtk-interactions.py
python3 test/tools/check-gtk-interaction-runner.py
python3 test/tools/check-http-timeout-lifecycle.py
python3 tools/map_math_coverage.py --check
```

Focused test prefixes:

- `Coyote.GUI.Conversation_Stack adopts inline worker rasters`
- `Coyote.GUI.Conversation_Stack tests partial adoption cleanup`
- `Coyote.GUI.Conversation_Stack renders and copies inline LaTeX`
- `Coyote.GUI.Conversation_Stack hit-tests inline math line`

`manifest.json` records the base revision, working changes, source/test/font/
executable hashes, build profiles and tool versions. `implementation.patch`
contains production/test changes relative to that base. `SHA256SUMS` covers all
retained files here except itself. Binaries are hashed, not bundled. No browser,
provider credentials, user sessions or production installation were used.
