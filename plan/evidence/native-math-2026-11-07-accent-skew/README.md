# Ordinary-accent skew and span — developer evidence

Date: 2026-11-07. Governing record: `plan/native-math-parity-test-report.md`
§11.7. This is scoped regression evidence, not parity, resource qualification,
release qualification or independent user acceptance.

## Results and artifacts

- `baseline/`: expanded corpus, **31 pass / 22 fail / 0 blocked**. All original
  29 cases already pass. Exporter is the preserved pre-fix executable identified
  by its SHA-256 in `manifest.json`; it was not rebuilt for this baseline.
- `final/`, `final-repeat/`: final restricted-source expanded corpus,
  **49 pass / 4 fail / 0 blocked** each. Failures remain overline at 24/48 px
  (vertical geometry, baseline, mask) and cancel at 24/48 px (mask).
- `pilot-final/`, `pilot-final-repeat/`: unchanged original corpus **29/29** each.
  Reports retain successful omitted-base/origin/baseline negative controls.
- Each image phase retains native/browser PNGs, requests and report. Absolute
  `/tmp` paths inside reports are original retrieval identifiers; use the PNGs
  within the matching archived phase directory instead.
- `unit-before.log`: coordinate regression fails on dot-overline-T. The new
  unmeasured checks pass after skew correction (`unit-after.log`).
- `raster-before.log`: after skew-only correction, before span correction,
  **351 assertions / 132 failures**. `raster-after.log`: **351/351**.
  `raster-final.log`: strengthened **363/363**, with below/full preservation
  guards. The saved final patch contains those 12 additional guards not present
  in the before log.
- `full-final.log`: final **1063/1063**, zero failed assertions/unexpected
  errors, cumulative **82.909971 s**. `full.log` is the earlier intermediate
  broader patch, **1063/1063**, 83.603988 s. Neither reconciles historical failed
  non-math repeats. Root/test final logs are incremental development builds;
  existing warnings remain. No clean or warning-free build claim.
- `geometry-final.log`: **235/235**, 13 groups. `additional.log`: **280 PASS**
  records on the intermediate patch, not rerun after above-only restriction.
- `browser-positions.jsonl`: independently measured pinned-browser body/mark
  origins; supports complete-span centering, rather than advance-only centering.
- `implementation.patch`: exact production/test edits plus supplemental manifest.
  `manifest.json`: Git base, source/font/executable hashes and toolchain details.
  `SHA256SUMS`: integrity checks, excluding itself.

The correction is syntax-sensitive skew plus measured *above*-accent margin
transfer. Below/full and unmeasured behavior is preserved, not newly qualified.
No comparison threshold, reference pin, SVG data or original pilot case changed.
The expanded failures are retained, not waived or normalized away.

## Reproduction

Run from the repository root, with Node, Python Pillow/NumPy/SciPy,
browser-ctl/Chromium and the pinned KaTeX archive available. These are developer
oracle dependencies, not production runtime dependencies. Archive SHA-256:
`e9e0d167db3175481cbadaff38e8d90b130f6a3ddb451a47e43c577fd511f365`.
Use the package/archive paths below or restore them from the pinned npm archive
as documented in the preceding accent-width evidence README.

```sh
alr build --development
(cd test && alr build --development --profiles=coyote=development)
(cd test && xvfb-run -a ./bin/coyote_test)
MATH_RASTER_ROOT=/tmp/accent-skew-raster alr exec -- gprbuild -p -P test/native/math_raster.gpr
/tmp/accent-skew-raster/bin/math_raster_probe "$PWD/share/coyote/math/fonts"
MATH_GEOMETRY_ROOT=/tmp/accent-skew-geometry sh test/tools/check-math-geometry.sh
browser-ctl start
MATH_IMAGE_EXPORT_ROOT=/tmp/accent-skew-images/build alr exec -- gprbuild -p -P test/native/math_image_export.gpr
MATH_IMAGE_EXPORT=/tmp/accent-skew-images/build/bin/math_image_export python3 test/tools/check-math-images.py --manifest test/fixtures/math-compatibility/accent-skew-manifest.json --out /tmp/accent-skew-images --package /tmp/coyote-katex-support-check/package --archive /tmp/coyote-katex-support-check/katex.tgz --fonts share/coyote/math/fonts
MATH_IMAGE_ROOT=/tmp/accent-skew-pilot sh test/tools/check-math-images.sh
```

The expanded comparison intentionally exits **1** while its four real failures
remain. Repeat it with another `--out` directory to retain both runs. Do not
interpret a completed report as a passing test. To reproduce the pre-fix source,
use the Git base in the manifest in a separate checkout; do not reverse patches
across unrelated working-tree changes. The preserved baseline executable is
hashed but not bundled, and its original build was from the preceding increment.

Verify archive integrity from this directory with `sha256sum -c SHA256SUMS`.

## Limits and review

Valgrind was not rerun; its recorded lifecycle failure remains open. Whole-job
allocation/deadlines, GTK/inline/cache work, fallback pins, callable comparison
gaps and independent visual/AT acceptance remain unqualified. This is not a
frozen desktop manifest; executables and npm archive are not bundled.
Developer and read-only agent review are not independent user acceptance.
Review detected an intermediate below/full regression; final above-only gating
and six-size guards resolve that blocker. A separate worker review failed with
an RPC sequencing error and supplied no review; a successful replacement review
was read before finalization. No commit or release is implied.
