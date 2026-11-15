# Parser-vector reservations — developer evidence

Date: 2026-11-15. Governing report: native-math-parity-test-report.md §11.14.
PCR-125 OPEN; feature NOT COMPLETE. Requirements/deviations unchanged.

## Results and artifacts

- `root-build-final.log`, `test-build-final.log`: incremental development builds
  pass. Generated profiles select development; existing warnings remain.
- `full-final.log`:1076/1076, zero failed assertions/unexpected errors;
  148.051229s cumulative,148.10s wall. Earlier `full.log` passes1076/1076.
- `parser-final.log`, `parser-repeat.log`, `parser-final-build.log`:674/674
  checks twice. Includes exact/one-short/held-charge/reuse, failure/cancel/deadline
  cleanup, max-size source and count/capacity controls for214 nonempty Unicode
  decomposition entries through U+03FF and3 targeted fixtures. Representative
  small-input charged peak29580 bytes, not measured allocator/RSS usage.
- `ledger-final.log`, `ledger-build.log`:38/38, including protected peak reset
  without changing current charges.
- `jobs-font-regression-final-{1,2,3}.log`, `jobs-final-repeat*.log`:215/215
  three corrected runs plus repeat. `jobs-initial-baseline-probe.log` preserves
  the extended215-assertion probe's1 failure before the telemetry fix. The
  similarly named `jobs-baseline-before-font-regression.log` is the earlier
  207-assertion passing probe BEFORE the regression was added, not the failing
  baseline. Existing2000 warm requests/saturation pass; not timing qualification.
- `raster-final.log`, `raster-build.log`:1116/1116 normally and under Valgrind;
  script exits1:2 contexts,6656 definitely/2183 indirectly/26 possibly lost
  native Fontconfig/Pango bytes. Functional assertions do not waive the gate.
- `gtk-final.log`, `gtk-final-raw/`:9/9. `gtk-runner-final.log`: containment
  self-test passes (expected synthetic7/9 after deliberate kill/timeout).
  `http-final.log`:offline Plain/RPC HTTP lifecycle passes; no live providers.
- `lifecycle/summary.csv` and18 full Valgrind logs: all6 no-shaping baselines
  have zero losses; all12 shaped runs FAIL strict checks. Without teardown,
  definite/indirect6656/2183 fixed across counts; possible378/730. With test-only
  teardown, definite/indirect0, possible26/378 remain. No suppression/threshold
  changes or production-global teardown. See report §11.14 for interpretation.
- `coverage.log`, `coverage-check.log`:source crosswalk only, not parity.
- `parser-memory-baseline*`, `parser-memory-fixed*`:intermediate conservative
  bound results, not final numbers. Initial missing Count_Type visibility build
  failure corrected; its original overwritten build transcript is unavailable.
- `implementation.patch`, `manifest.json`, `SHA256SUMS`, `review.md`:changed
  code/test identities, environment and scoped review. Binaries hashed, not
  bundled. Some duplicate logs retain worker naming/provenance.

## Reproduce

Run from repository root; the full suite must run with `test/` as working directory.

```sh
alr build --development
(cd test && alr build --development --profiles=coyote=development)
(cd test && xvfb-run -a ./bin/coyote_test)
sh test/tools/check-math-parser-memory.sh
sh test/tools/check-math-memory-budget.sh
sh test/tools/check-math-jobs.sh
sh test/tools/check-math-raster.sh
sh test/tools/check-math-shaping-lifecycle.sh
python3 test/tools/check-gtk-interactions.py
python3 test/tools/check-gtk-interaction-runner.py
python3 test/tools/check-http-timeout-lifecycle.py
python3 tools/map_math_coverage.py --check
```

The raster and shaping-lifecycle scripts FAIL for the retained unsuppressed
native lifecycle contexts. Do not relabel them as passes.

## Accounting boundary

Parser source offset maps and lexical raw/transformed/mark-work token record
arrays are preadmitted; copied original maps are included. Preallocation, raw
borrowing and expanded-vector Move avoid unmanaged record-array growth/copies
in these paths. Actual surviving capacity reconciles afterward. The default
ledger is256MiB; workers share one account across parser/raster phases and
reset phase peaks without changing charges. Parser temporaries release at
return; the sequential pipeline peak is their maximum, not a whole-job sum.

Strings/lexemes, expander/AST/semantic/layout data, native/font internals,
allocator metadata and full return-copy/cache lifetimes remain outside this
scope. GNAT requested capacity is not portable allocator/RSS accounting.
Direct Source.Create/Lex callers do not receive parser-ledger enforcement.
Macro rejection is injected before group mutation, not after. No whole-job
memory, hard timing, full parity, lifecycle or human acceptance claim. Browser/
geometry/isolated-resource characterization not rerun. No release/install/commit.
