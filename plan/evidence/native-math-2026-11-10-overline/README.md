# Overline rule geometry — developer evidence

Date: 2026-11-10. Governing record: `plan/native-math-parity-test-report.md`
§11.8. Scoped regression evidence, not parity, release/resource qualification
or independent user acceptance. PCR-125 remains OPEN.

## Results and artifacts

- `raster-before.log`: new regressions against old production code,
  **423 assertions / 48 failures**. The four overline checks fail at six sizes
  and two thickness settings; underline guards pass.
- `raster-final.log`: **423/423**, including strengthened nonzero italic-margin
  and cleared-result controls, plus unchanged below/full/stretchy tests.
- `unit.log`: existing accent AUnit case **1/1**, with nine new overline
  configurations. This is one registered case, not nine new registered cases.
- `root-build.log`, `test-build.log`: successful incremental development builds,
  existing warnings retained. Both generated profiles select development.
- `full.log`: Xvfb suite **1074/1074**, zero failed assertions/unexpected errors,
  **142.762374 s** cumulative. Historical non-math failures are not reconciled.
- `geometry.log`, `geometry/`: unchanged **235/235** across 13 groups.
- `final/`, `final-repeat/`: expanded images **51 pass / 2 fail / 0 blocked**
  each, up from the preceding **49/53** in §11.7. Only cancel24/48 mask failures
  remain. Overline24/48 now pass dimensions, baseline and masks. No thresholds,
  manifest, reference pin or SVG path data were changed.
- `pilot/`: unchanged original images **29/29**. Each image report retains
  successful omitted-base/origin/baseline negative controls. PNGs and requests
  are archived alongside reports; absolute `/tmp` paths identify original runs.
- `gtk-interactions.log`: **9/9**; `gtk-interaction-runner.log`: containment
  self-test passes (its killed Unicode and timed-out bidi fixtures are expected,
  not application failures). `http-timeout.log`: offline Plain/RPC lifecycle,
  zero-disable delayed success and 4+4 stalled requests pass.
- `implementation.patch`: exact production/test diff. `manifest.json`: base
  revision, source/font/executable hashes, oracle archive hash and toolchain.
  Executables and npm archive are not bundled. `SHA256SUMS` covers all files
  here except itself.

Read-only agent review found no blockers; its request for an explicit nonzero
italic-margin control was implemented and verified in the final raster run.
Developer/agent review is not independent acceptance.

## Reproduction

From repository root; requires Alire, the pinned npm archive/package, Node,
Python Pillow/NumPy/SciPy and browser-ctl/Chromium. These are developer-oracle
dependencies, not product runtime dependencies. KaTeX 0.16.22 archive SHA-256:
`e9e0d167db3175481cbadaff38e8d90b130f6a3ddb451a47e43c577fd511f365`.
Restore the package/archive as described in the preceding accent-width evidence
README if absent. Do not reverse the patch over unrelated changes; reproduce
old code in a separate checkout at the recorded Git base with the test portion
of `implementation.patch` applied.

```sh
alr build --development
(cd test && alr build --development --profiles=coyote=development)
(cd test && ./bin/coyote_test 'Coyote.Math lays out accents and operator limits')
(cd test && xvfb-run -a ./bin/coyote_test)
python3 test/tools/check-gtk-interactions.py
python3 test/tools/check-gtk-interaction-runner.py
python3 test/tools/check-http-timeout-lifecycle.py
MATH_RASTER_ROOT=/tmp/coyote-overline/raster alr exec -- gprbuild -p -P test/native/math_raster.gpr
/tmp/coyote-overline/raster/bin/math_raster_probe "$PWD/share/coyote/math/fonts"
MATH_GEOMETRY_ROOT=/tmp/coyote-overline/geometry sh test/tools/check-math-geometry.sh
browser-ctl start
MATH_IMAGE_EXPORT_ROOT=/tmp/coyote-overline/images/build alr exec -- gprbuild -p -P test/native/math_image_export.gpr
MATH_IMAGE_EXPORT=/tmp/coyote-overline/images/build/bin/math_image_export python3 test/tools/check-math-images.py --manifest test/fixtures/math-compatibility/accent-skew-manifest.json --out /tmp/coyote-overline/images --package /tmp/coyote-katex-support-check/package --archive /tmp/coyote-katex-support-check/katex.tgz --fonts share/coyote/math/fonts
MATH_IMAGE_EXPORT=/tmp/coyote-overline/images/build/bin/math_image_export python3 test/tools/check-math-images.py --out /tmp/coyote-overline/pilot --package /tmp/coyote-katex-support-check/package --archive /tmp/coyote-katex-support-check/katex.tgz --fonts share/coyote/math/fonts
```

The expanded check intentionally exits **1** while cancel24/48 fail. Repeat it
with another `--out` directory; no passing status is implied by report creation.
Check archive integrity from this directory with `sha256sum -c SHA256SUMS`.

## Limits

This corrects overline Rule 9 metrics/span, not complete accent/reference parity.
Unmeasured widths/italic propagation and underline/cancel branches are unchanged.
Remaining cancel masks, callable comparisons, whole-job memory, hard deadlines,
inline GTK/cache behavior, fallback font pins, native lifecycle/Valgrind failure
and independent visual/AT acceptance remain open. Valgrind/resources were not
rerun. No release, installation or commit; approved requirements unchanged.
