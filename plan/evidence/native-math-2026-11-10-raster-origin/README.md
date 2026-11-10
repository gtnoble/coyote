# Origin-aware retained rasters — developer evidence

Date: 2026-11-10. Governing report: `plan/native-math-parity-test-report.md`
§11.10. Scoped developer evidence, not complete parity, resource qualification,
release qualification or independent user acceptance. PCR-125 remains OPEN.

## Results and artifacts

- `baseline/`: preserved pre-fix exporter under the corrected fixed-margin
  oracle, **77 pass / 18 fail / 0 blocked**. `final/`, `final-repeat/`: exact-final
  source **95/95** each, including all18 isolated cancellations. Manifest,
  reference archive and thresholds unchanged. Each phase retains reports,
  requests and complete native/browser PNGs; absolute `/tmp` paths inside
  reports are original retrieval identifiers, not durable file locations.
- `pilot/`: unchanged original **29/29** on final source. Every report retains
  omitted-base, browser/native-origin, stale-origin-metadata and baseline
  negative controls. Comparison maps declared origins, never foreground fitting.
- `clipped-oracle-intermediate/`: origin-aware native code with old X=0 browser
  viewport, **83/95**, all12 failures from isolated compound/accent left ink.
  `margin-intermediate/`: independent fixed32px horizontal browser safety margin,
  **95/95**, before final arithmetic-validation reorder. The fixed12px crop is
  unchanged and checked against screenshot boundaries. The older89/95 result
  in preceding cancellation evidence used the clipped oracle and is historical;
  it is not the comparable baseline for this correction.
- `root-build-final.log`, `test-build-final.log`: successful incremental
  development builds; existing warnings remain. Generated profiles select
  development. No release/clean/warning-free claim.
- `full-exact-final.log`: **1074/1074**, zero failed assertions/unexpected errors,
  **147.547471s** cumulative. Earlier `full-final.log` is an intermediate source
  snapshot; use the exact-final log. Historical failed repeats are not reconciled.
- `raster-final.log`: **1108/1108**; negative origins, pixel retention, unchanged
  layout metrics, clipping, full/quadrant/tile equivalence, signed tile origins,
  combined dimension caps and independent shadow cap coverage. Old synthetic
  zero-ascent glyph cap fixtures now legitimately retain extra upper ink;
  explicit rule fixtures isolate fractional rounding without weakening caps.
- `jobs-final.log`: **162/162**, independent direct measured layout/origin and
  baseline comparisons, actual storage charging and release. Headless2000/2000
  warm requests and queue saturation checks are characterization only.
- `geometry-final.log`, `geometry/`: unchanged **235/235**, 13 groups.
- `gui-core-final.log`, `gui-fleqn-final.log`: **1/1** each. Existing registered
  cases extend to actual display/inline leading-ink snapshots, physical sizing,
  baseline and Fleqn anchor compensation. No registration count change.
  Initial `gui-core.log` retains failed drawing while GTK allocation was pending;
  final tests pump a bounded monotonic settle and snapshot actual allocations.
  Earlier compile/scope failures remain in their build logs. Theme warnings
  remain; they are not independent desktop visual acceptance.
- `gtk-exact-final.log`: **9/9**; `gtk-runner-exact-final.log`: containment
  self-test passes (intentional killed/timed-out fixtures); `http-exact-final.log`:
  offline Plain/RPC lifecycle and zero-disable checks pass. No live-provider use.
- `implementation.patch`: exact production/test diff. `manifest.json`: base
  revision, source/font/executable hashes and toolchain. Binaries and npm archive
  are not bundled. `SHA256SUMS` covers all files here except itself.

Read-only reviews prompted Fleqn logical-anchor compensation; final review found
no concrete blocker. Developer/agent review is not independent acceptance.

## Coordinate contract

Full image Origin_X/Y locate logical top-left inside its raster. Baseline in
raster pixels includes Origin_Y, but exported comparison baseline remains
relative to the logical envelope. Tiles index the padded full image; their
logical origin offsets are signed. Layout width/ascent/descent are unchanged.
Full8192×4096, tile256×256 and padded GUI/inline caps count leading+trailing
extents. GTK reserves physical paint size while retaining logical width for
centering; Fleqn area margin compensates leading X until the parent boundary.
Inline painting uses measured bounds but still runs synchronously on GTK.

## Reproduction

From repository root with Alire, Node, Python Pillow/NumPy/SciPy and
browser-ctl/Chromium. These are developer oracle dependencies, not product runtime
requirements. Restore pinned KaTeX0.16.22 package/archive as described in preceding
accent-width evidence if absent. Archive SHA-256:
`e9e0d167db3175481cbadaff38e8d90b130f6a3ddb451a47e43c577fd511f365`.

```sh
alr build --development
(cd test && alr build --development --profiles=coyote=development)
(cd test && xvfb-run -a ./bin/coyote_test)
python3 test/tools/check-gtk-interactions.py
python3 test/tools/check-gtk-interaction-runner.py
python3 test/tools/check-http-timeout-lifecycle.py
MATH_RASTER_ROOT=/tmp/coyote-origin/raster alr exec -- gprbuild -p -P test/native/math_raster.gpr
/tmp/coyote-origin/raster/bin/math_raster_probe "$PWD/share/coyote/math/fonts"
MATH_JOBS_ROOT=/tmp/coyote-origin/jobs alr exec -- gprbuild -p -P test/native/math_jobs.gpr
/tmp/coyote-origin/jobs/bin/math_jobs_probe "$PWD/share/coyote/math/fonts"
MATH_GEOMETRY_ROOT=/tmp/coyote-origin/geometry sh test/tools/check-math-geometry.sh
browser-ctl start
MATH_IMAGE_EXPORT_ROOT=/tmp/coyote-origin/images/build alr exec -- gprbuild -p -P test/native/math_image_export.gpr
MATH_IMAGE_EXPORT=/tmp/coyote-origin/images/build/bin/math_image_export python3 test/tools/check-math-images.py --manifest test/fixtures/math-compatibility/cancel-geometry-manifest.json --out /tmp/coyote-origin/fresh --package /tmp/coyote-katex-support-check/package --archive /tmp/coyote-katex-support-check/katex.tgz --fonts share/coyote/math/fonts
```

Repeat with another `--out`; omit `--manifest` for original29. Before-image
reproduction requires a separate checkout at the recorded base revision and its
exporter, using the corrected checker from this patch. Do not reverse patches
over unrelated work. Verify integrity here with `sha256sum -c SHA256SUMS`.

## Open limits

Glyph reference metrics are not exact native ink bearings. Shaped text-run ink,
fallback fonts and full coverage remain unqualified; path control hulls are
conservative, not tight ink bounds. Fixed browser margins/crops do not prove
arbitrary overflow coverage. Parent/viewport clipping remains. Inline workers,
complete display tiling/cache scheduling, aggregate job/process memory, hard
deadlines/GTK slices, callable gaps, native lifecycle/Valgrind and independent
visual/AT acceptance remain open. Valgrind/resources were not rerun. Approved
requirements/deviations unchanged; no release, installation or commit.
