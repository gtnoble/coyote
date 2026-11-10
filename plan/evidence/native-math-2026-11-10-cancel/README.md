# Cancellation SVG geometry — developer evidence

Date: 2026-11-10. Governing report: `plan/native-math-parity-test-report.md`
§11.9. Scoped developer regression evidence, not parity, resource/release
qualification or independent acceptance. PCR-125 remains OPEN.

## Results and artifacts

- `baseline/`: final 95-case corpus with preserved pre-fix exporter, **51 pass,
  44 fail, 0 blocked**. `final/`, `final-repeat/`: **89 pass, 6 fail, 0 blocked**
  each. No passing baseline regressions; 38 failed cases become passing.
- Remaining six failures: isolated single-T cancel/bcancel/xcancel at24/48px.
  Pre-fix: width and mask failures. Final: only mask failures. Unmatched browser
  pixels lie above native logical origin; native rasters retain only right/
  bottom overflow. This supports a top-clipping contributor, not complete
  component causation. No case was removed or threshold relaxed.
- `preceding53/`: preceding unchanged accent-skew corpus **53/53** (previously
  51/53); `intermediate77/` and `intermediate77-repeat/`: additive surrounded/
  nested corpus **77/77** each. These are intermediate manifests, not the final
  denominator. `pilot/`: unchanged original **29/29**. Image reports retain
  passing omitted-base/origin/baseline negative controls. Each phase contains
  requests, reports and native/browser PNGs; absolute paths are run identifiers.
- `raster-baseline.log`: exact final probe against isolated pre-fix layout,
  **999 assertions / 396 failures**. `raster-before.log`: earlier probe before
  perpendicular assertion repair, same totals; prefer the exact-final baseline.
  `raster-final.log`: **999/999**, 576 added cancellation checks across six
  sizes/two minimum-rule settings/four bodies/three modes. Existing overline,
  stretchy and below/full guards remain passing.
- `unit-final.log`: focused existing AUnit case **1/1**, with ten added
  configurations. Earlier `unit.log`/`unit-debug.log` retain a test-only scoping
  failure: unbraced compound style baseline was not equivalent; grouped final
  baseline fixes it. No production style change was made.
- Development build logs pass with existing warnings. `full.log`: Xvfb suite
  **1074/1074**, zero failures/errors, **146.300164 s** cumulative.
  `geometry.log`, `geometry/`: unchanged **235/235**, 13 groups.
- GTK interactions **9/9**, containment runner and offline Plain/RPC HTTP
  lifecycle pass. Runner's killed/timed-out fixtures are intentional self-tests.
- `reference-dom.json`, `reference-dom.py`: direct pinned Chromium measurements
  of body margins, SVG viewport, overflow:hidden, 0.046em stroke and butt caps.
  Script serves local pinned package only; no live-provider or remote web calls.
- `implementation.patch`: production/test diff; supplemental 95-case manifest
  is archived separately and in test fixtures. `manifest.json`: source/font/
  executable hashes, base revision and toolchain. Binaries and npm archive are
  not bundled. `SHA256SUMS` covers every file here except itself.

Read-only implementation review found no blockers and recommended accent-inside
image coverage, which was added. Diagnostic review localized remaining upper
ink. Developer/agent review is not independent user acceptance.

## Reproduction

From repository root; requires Alire, Node, Python Pillow/NumPy/SciPy and
browser-ctl/Chromium. These are developer oracle dependencies, not product
runtime requirements. Pinned KaTeX0.16.22 archive hash:
`e9e0d167db3175481cbadaff38e8d90b130f6a3ddb451a47e43c577fd511f365`.
Restore `/tmp/coyote-katex-support-check/package` and `katex.tgz` as described
in the preceding accent-width evidence README if absent.

```sh
alr build --development
(cd test && alr build --development --profiles=coyote=development)
(cd test && ./bin/coyote_test 'Coyote.Math lays out accents and operator limits')
(cd test && xvfb-run -a ./bin/coyote_test)
python3 test/tools/check-gtk-interactions.py
python3 test/tools/check-gtk-interaction-runner.py
python3 test/tools/check-http-timeout-lifecycle.py
MATH_RASTER_ROOT=/tmp/coyote-cancel/raster alr exec -- gprbuild -p -P test/native/math_raster.gpr
/tmp/coyote-cancel/raster/bin/math_raster_probe "$PWD/share/coyote/math/fonts"
MATH_GEOMETRY_ROOT=/tmp/coyote-cancel/geometry sh test/tools/check-math-geometry.sh
browser-ctl start
MATH_IMAGE_EXPORT_ROOT=/tmp/coyote-cancel/images/build alr exec -- gprbuild -p -P test/native/math_image_export.gpr
MATH_IMAGE_EXPORT=/tmp/coyote-cancel/images/build/bin/math_image_export python3 test/tools/check-math-images.py --manifest test/fixtures/math-compatibility/cancel-geometry-manifest.json --out /tmp/coyote-cancel/fresh --package /tmp/coyote-katex-support-check/package --archive /tmp/coyote-katex-support-check/katex.tgz --fonts share/coyote/math/fonts
```

The final supplemental image command exits **1** for the six retained failures.
Repeat with another `--out`; report creation does not imply passing. The existing
53-case corpus uses `--manifest test/fixtures/math-compatibility/accent-skew-manifest.json`;
omit `--manifest` for the unchanged original29. Use a separate checkout at the
recorded base revision plus only the test portion of the patch for before-probe
reproduction; do not reverse patches over unrelated work. Final supplemental
manifest is identical across baseline/final/repeat. Verify integrity from this
directory with `sha256sum -c SHA256SUMS`.

## Limits and disposition

Geometry correction does not solve negative-origin raster/adoption behavior.
Do not inflate logical ascent or crop the browser to conceal overflow. Six
newly exposed existing isolated failures remain open. Whole-job memory, hard
deadlines, inline GTK/cache, fallback font pins, callable comparison, native
lifecycle/Valgrind and independent human visual/AT acceptance remain open.
Valgrind/resources were not rerun. Approved requirements/deviations unchanged;
no release, installation or commit.
