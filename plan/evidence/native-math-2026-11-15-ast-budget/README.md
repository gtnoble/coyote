# AST construction budget — developer evidence

Date: 2026-11-15. Governing report: native-math-parity-test-report.md §11.15.
PCR-125 OPEN; feature NOT COMPLETE. No requirements/deviation changes.

## Results and artifacts

- `root-build-final.log`, `test-build-final.log`: development builds pass.
- `full-final.log`:1076/1076, zero failures/errors;145.992924s cumulative,
  146.26s wall. `full.log` is pre-final, before empty-failure cleanup correction.
- `parser-final.log`, `parser-repeat.log`, `final-probe.log`:688/688 each;
  fixture2049nodes/2048glyphs,2443968-byte scoped charged peak. `final-probe.log`
  was named by a worker before the last cleanup correction; `parser-final.log`
  is exact-final. `parser-valgrind.log`:688/688,0 errors, no lost bytes;
  113248 bytes reachable. Not a Pango or whole-application lifecycle test.
- `baseline-head-build.log`, `baseline-head-probe.log`: isolated HEAD parser
  builds, then current688-check probe reports5 expected AST-specific failures.
  Reconstruction is documented in `review.md` and retained project file.
- `jobs-final.log`, `jobs/probe.log`:223/223 twice, including8 added integration
  assertions and existing2000 warm requests. `jobs-final.log` is exact-final;
  headless timings are characterization, not qualification.
- `ledger.log`:38/38. `raster-final.log`:1116/1116 normal and under Valgrind;
  strict script exits1 with2 contexts and6656/2183/26-byte losses. No suppression
  or threshold change. `raster.log` is an earlier same-result run.
- `gtk-final.log`:9/9; `gtk-runner-final.log`: containment self-test passes after
  deliberate killed/timed-out fixtures; `http-final.log`:offline lifecycle pass.
  Matching `*-raw` directories retain referenced GTK worker logs.
- `geometry.log`:BLOCKED missing default KaTeX package; no cases executed.
- `coverage*.log`: source crosswalk only. `review.md`, `review-final.md` retain
  read-only reviews; developer/agent evaluation is not independent acceptance.
  Stale timing labels noted in review-final were subsequently updated to the
  exact-final values above. Final invalid documents do not take empty capacity.
- `intermediate/`: compile/accessibility and test-setting failures, not baseline
  or passing evidence. `implementation.patch`, `manifest.json`, `SHA256SUMS`
  identify code/tests, environment and artifacts. Executables hashed, not bundled.

## Reproduce from repository root

```sh
alr build --development
(cd test && alr build --development --profiles=coyote=development)
(cd test && xvfb-run -a ./bin/coyote_test)
sh test/tools/check-math-parser-memory.sh
valgrind --error-exitcode=1 --leak-check=full /tmp/coyote-math-parser-memory/bin/math_parser_memory_probe
sh test/tools/check-math-memory-budget.sh
sh test/tools/check-math-jobs.sh
sh test/tools/check-math-raster.sh
python3 test/tools/check-gtk-interactions.py
python3 test/tools/check-gtk-interaction-runner.py
python3 test/tools/check-http-timeout-lifecycle.py
python3 tools/map_math_coverage.py --check
```

## Scope limits

Old/new AST record arrays are charged during construction, not returned-document
lifetime. GNAT exact requested capacity is inspected/tested, not portable allocator
or RSS accounting. Nested controlled payloads, expander/semantic/layout/native/
font storage and complete copy/cache lifetimes remain outside accounting. Hard
timing, full parity, font/lifecycle and human acceptance gates remain open.
No release, installation or commit.
