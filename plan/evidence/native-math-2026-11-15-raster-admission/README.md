# Retained worker-output admission — developer evidence

Date:2026-11-15. Governing report: native-math-parity-test-report.md §11.12.
PCR-125 remains OPEN; no parity/resource/timing/human acceptance or release.

## Results and artifacts

- `probe.log`, `build.log`: new193-assertion probe against pre-change production;
 2 failures (budget-rejected results expose pixels).
- `jobs-final.log`, `jobs-repeat.log`, `jobs-build.log`:193/193 twice; warm and
 saturation numbers are characterization only.
- `root-build.log`, `test-build.log`: incremental development builds pass.
- `full.log`:1076/1076; zero failures/errors;144.235750s cumulative,144.27s wall.
- `gtk.log`:9/9 with retained raw GTK logs. `gtk-runner.log`: containment PASS,
 intentional kill/timeout fixtures yield7/9 synthetic successes; temporary
 fixture logs removed by harness. `http.log`: offline lifecycle PASS.
- `raster.log`:1108/1108 normally and under Valgrind, but SCRIPT FAILS with
 2 Valgrind contexts,6656 definitely/2183 indirectly/26 possibly lost bytes.
 No suppression; existing native lifecycle gate remains open.
- `coverage.log`, `coverage-check.log`: source crosswalk refresh/check only.
- `manifest.json`, `implementation.patch`, `SHA256SUMS`: snapshot identity.
 Binaries hashed, not bundled. Review is developer/agent, not independent
 acceptance. No new browser, geometry or isolated resource measurement.

## Reproduction from repository root

```sh
alr build --development
(cd test && alr build --development --profiles=coyote=development)
(cd test && xvfb-run -a ./bin/coyote_test)
sh test/tools/check-math-jobs.sh
sh test/tools/check-math-raster.sh
python3 test/tools/check-gtk-interactions.py
python3 test/tools/check-gtk-interaction-runner.py
python3 test/tools/check-http-timeout-lifecycle.py
python3 tools/map_math_coverage.py --check
```

Raster script exit1 is expected from the recorded unresolved Valgrind failure,
not a passing command. Output admission covers one retained vector only;
Cairo/deep copies/parser/layout/font/native temporaries remain unaccounted.
Late publication races and post-pixel exceptions lack deterministic injected
coverage. See report §11.12 for full scope and limits.
