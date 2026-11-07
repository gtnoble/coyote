# Measured stretchy-accent width — developer evidence

Date: 2026-11-06. Governing result: `plan/native-math-parity-test-report.md`
§11.6. This archive is scoped regression evidence, not full native-math parity,
resource qualification, release qualification or independent user acceptance.

## Contents and observed results

- `baseline/`: unchanged 29-case image pilot before the correction, **28 pass,
  1 fail**. `utilde-long` fails 0.990 coverage at 0.9851411589895989.
- `after/` and `repeat/`: same pilot and unchanged criteria after the correction,
  **29/29** each; utilde-long coverage is 1.0 in both directions. Original
  omission/origin/baseline negative controls remain successful.
- Each image directory retains `report.json`, input requests, build log,
  native PNGs and browser PNGs. Absolute `/tmp` paths inside reports identify
  the original run; the corresponding files are retained within each phase.
- `coyote-math-continuation-raster-before.log`: initial 48 width regressions
  added before the production fix, **159 assertions / 24 failures**, all
  italic-ending cases. Non-italic controls pass.
- `coyote-math-continuation-raster-after.log`: initial fixed probe, **159/159**.
  `raster-final.log`: final strengthened probe, **207/207**, including 96 added
  width/path/control assertions across four accents, two bases and six sizes.
- `coyote-math-continuation-full.log`: one full Xvfb suite, **1063/1063**,
  zero failed assertions or unexpected errors, cumulative 88.930779 seconds.
  Reported wall time was 89.11 seconds; the suite log itself retains cumulative
  time, not an independent wall-time measurement. An initial command could not
  locate the executable (exit 127); the corrected invocation ran from `test/`.
- Root/test build logs: successful incremental **development** builds; root
  reports executables up to date. No clean-build or warning-free claim.
- Geometry log: **235/235** across 13 groups. Additional probe: **280 PASS
  records**. Structured `differential/` exports/report: **16/16**, no fail,
  gap or blocked. Comparator control harness was not separately rerun.
- `implementation.patch`: exact production/test diff for this increment.
  `manifest.json`: baseline Git revision plus dirty-snapshot designation,
  source, font and executable hashes, platform/toolchain/browser details.
  `SHA256SUMS`: integrity checks for retained files, excluding itself.

The shared branch corrects width fitting for utilde, widetilde, widehat and
widecheck. It includes the trailing italic correction consistently in path
fitting, command/clip width and result width when a measured advance source is
present; normalized unmeasured geometry is unchanged. No reference data,
vertical placement, corpus case or comparison threshold was changed.

## Reproduction

Run from the repository root unless stated otherwise. Use development builds.
The oracle requires Node, Python with Pillow/NumPy/SciPy, browser-ctl with
Chromium, and the exact KaTeX 0.16.22 archive/package. These are development-only
dependencies, not production runtime requirements. Existing fonts are under
`share/coyote/math/fonts/`.

Pinned archive URL: https://registry.npmjs.org/katex/-/katex-0.16.22.tgz

Archive SHA-256:
`e9e0d167db3175481cbadaff38e8d90b130f6a3ddb451a47e43c577fd511f365`.
The harness also verifies the bundle and browser assets; do not install npm
packages or substitute a different oracle. Restore the extracted package at
`/tmp/coyote-katex-support-check/package` and archive at
`/tmp/coyote-katex-support-check/katex.tgz`, or set the documented harness
variables.

```sh
alr build --development
(cd test && alr build --development --profiles=coyote=development)
(cd test && xvfb-run -a ./bin/coyote_test)
MATH_IMAGE_ROOT=/tmp/coyote-math-continuation-after sh test/tools/check-math-images.sh
MATH_IMAGE_ROOT=/tmp/coyote-math-continuation-repeat sh test/tools/check-math-images.sh
MATH_ADDITIONAL_ROOT=/tmp/coyote-math-continuation-additional sh test/tools/check-math-additional-probe.sh
sh test/tools/check-math-geometry.sh
sh test/tools/check-math-differential.sh /tmp/coyote-katex-support-check/package /tmp/coyote-katex-support-check/katex.tgz /tmp/coyote-math-continuation-differential
MATH_RASTER_ROOT=/tmp/coyote-math-continuation-raster-strength alr exec -- gprbuild -p -P test/native/math_raster.gpr
/tmp/coyote-math-continuation-raster-strength/bin/math_raster_probe "$PWD/share/coyote/math/fonts"
```

To reproduce the original image failure, use the baseline Git revision recorded
in `manifest.json` in a separate checkout, with the same oracle and fonts. The
initial regression-before log used only the first 48 added width assertions;
the saved final patch contains the strengthened 96-assertion addition. Do not
apply a reverse patch over unrelated work in a current working tree.

Verify archive integrity from this directory:

```sh
sha256sum -c SHA256SUMS
```

## Limits

The manifest captures a developer machine, not a fully frozen qualification
workstation: desktop theme, fallback-font resolution, display/color policy and
all native-library dependencies are not pinned. Browser user agent and default
viewport were collected separately after execution; the image harness specifies
its own formula sizing and records actual dimensions. Source/executable hashes
identify artifacts but executables and the npm archive are not bundled here.

Valgrind was **not rerun**; the native-library lifecycle failure in report §11.4
remains open. One successful suite does not reconcile earlier non-math failed
repeats. Full accent/skew behavior, the 60 callable comparison gaps, inline GTK
painting, whole-job memory, hard deadlines, cache guarantees and human visual/AT
acceptance remain open. Review was developer/agent review, not independent user
acceptance. No commit or release is implied.
