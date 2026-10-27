# Native math KaTeX compatibility — test report

**Document:** Combined Software Test Report (STR) for the approved execution baseline; final test readiness open
**Date:** 2026-10-26 (PCR-125; approved work began 2026-10-24)
**Reference:** KaTeX 0.16.22, pinned archive SHA-256 `e9e0d167db3175481cbadaff38e8d90b130f6a3ddb451a47e43c577fd511f365`; bundle SHA-256 `8f1f4fb1080439c012bb8fddf424fa253e9144ab4cdd7dc0eae0e92cd04a5e33`
**Status: NOT COMPLETE — final qualification and product acceptance remain open.**

This report records a substantive implementation and verification checkpoint, not full KaTeX parity. Its controlling scope is approved SRS-MATH v1.0 and D01–D15, the execution-baseline STP/STD `plan/native-math-compatibility-tests.md`, and the P0–P6 plan `plan/native-math-parity-plan.md`. The test plan/readiness and visual calibration remain incomplete. No missing inventory row is converted into a pass or an approved exclusion. No user acceptance or independent human visual/accessibility acceptance is recorded.

**Current-results pointer:** §1–7 preserve historical checkpoints and narrative. The latest completion attempt and controlling status are in [§8](#8-latest-completion-attempt--not-complete); earlier final2/final3 full-suite results are historical and superseded as latest-source evidence.


## 1. Test scope and environment

The run covered root and test development builds, the registered AUnit suite, native focused probes, a 24-case geometry probe, a 16-case structured differential pilot, three browser/native image comparisons, browser DOM sanity cases, resource/performance probes, seeded fuzzing, and provenance/inventory checks. These are distinct evidence classes; none alone establishes parity. The pinned reference and browser are development-only. Builds selected the development profile; no release build was used or requested.

Environment/artifact record is the `/tmp/coyote-parity-final2-*` run set. The browser log records Chromium 147.0.0.0; the reference/browser manifests identify KaTeX 0.16.22. The logs do not constitute a complete frozen workstation/platform/toolchain manifest for qualification. Commands represented by the logs include:

- `alr build --development` (`/tmp/coyote-parity-final2-build.log`)
- `cd test && alr build --development --profiles=coyote=development` (`...-testbuild.log`)
- `cd test && xvfb-run -a ./bin/coyote_test` (suite output `...-full.log`)
- `sh test/tools/check-math-geometry.sh` (rerun output `...-geometry2.log`)
- `sh test/tools/check-math-differential.sh /tmp/coyote-katex-support-check/package /tmp/coyote-katex-support-check/katex.tgz /tmp/coyote-parity-final2-differential`
- `sh test/tools/check-math-images.sh` with output root `/tmp/coyote-parity-final2-images`
- Focused runners under `test/tools/check-math-{tokens,macros,semantics,jobs,raster,accessibility,font-data,paths,engine,primitives,arrays,constructs,delimiters,tags-probe,additional-probe}.sh`; outputs are named `...-tokens.log`, etc.

The exact output and per-probe build/probe logs are listed by these paths; focused scripts write subdirectories beneath `/tmp/coyote-parity-final2-*`. The fuzz harness uses seed `0x6d617468`. No release configuration or live provider was part of this scope.

## 2. Results

| Verification | Observed result | Disposition |
|---|---|---|
| Root development build | Success | Pass for this build only; compiler/style warnings remain. |
| Test development build | Success | Pass for this build only; compiler/style warnings remain. |
| Full registered AUnit suite | **1060 run, 1060 successful, 0 failed assertions, 0 unexpected errors**; cumulative 81.076234 s, wall 81.11 s | Regression checkpoint pass; not parity qualification. Log: `/tmp/coyote-parity-final2-full.log`. |
| Native standalone probe | **151 assertions, 0 failures** | Pass for its listed samples/bounds only. `/tmp/coyote-parity-final2-native.log`; image `/tmp/coyote-native-math-qualification/production.png`. |
| Tokens / macros / semantics / jobs | 44 / 313 / 157 / 115 assertions or checks; each 0 failures | Focused passes only. Logs `...-tokens.log`, `...-macros.log`, `...-semantics.log`, `...-jobs.log`. |
| Raster / accessibility / font / paths / engine | 42 / 63 / 49 / 69 / 23 assertions or checks; each 0 failures | Focused passes only. Raster was repeated under Valgrind: 0 errors and 0 definitely, indirectly, or possibly lost bytes; still-reachable allocations remain. GTK theme CSS warnings occurred in accessibility test. |
| Primitives | 37 checks, 0 failures | Focused pass. Other construct, array, delimiter, tag, and additional probes recorded their listed sample outcomes in their logs; they are not complete inventory coverage. |
| Geometry | **22/24 cases within the probe's 0.01 em ascent/descent tolerance; 2/24 fail.** | Failures remain open; exact differences below. Log: `/tmp/coyote-parity-final2-geometry2.log`. |
| Structured differential | **0 pass, 0 fail, 0 gap, 16 blocked** | Incomplete/blocked; no full reference geometry/field comparison. Report: `/tmp/coyote-parity-final2-differential/report.json`. |
| PNG comparison | **0 pass, 3 fail, 0 blocked** | Failed comparisons; raw differences are not accepted as calibrated visual parity. Report: `/tmp/coyote-parity-final2-images/report.json`. |
| Browser DOM sanity | 3 KaTeX cases passed | Local-font browser geometry only; no native/pixel parity. `/tmp/coyote-parity-final2-browser.log`. |
| Seeded fuzz | 10,000 cases, 4,779 `ok`, 5,221 `parse-error`, 0 `layout-error`; 32-case determinism check identical; 2,970 ms | Recorded bounded run; memory was not measured. Not proof of complete robustness. `/tmp/coyote-parity-final2-fuzz.log`. |
| Headless performance | 2,000 measured requests, p95 1.033796 ms against 50 ms target | Headless exporter only; excludes GUI scheduling and does not qualify the queue-inclusive budget. `/tmp/coyote-parity-final2-performance.log`. |
| Resource probe | 10 isolated exporter cases; maximum observed child peak RSS 41,888 KiB; max tested individual case 209 ms | Evidence for these cases only; not whole-job/API/browser memory or approved budget compliance. See §4 and JSON log. |
| Registry/inventory controls | Deterministic inventory/provenance check passed; comparator strict and negative controls passed | Control mechanics only; do not fill blocked comparison fields. `/tmp/coyote-parity-final2-inventory.log`, `...-strict-report.log`, `...-strict-comparator.log`, `...-negative-comparator.log`. |

Build logs report style and compiler warnings (including redundant/unused clauses, unused assignment, and Ada style-rule findings); test build also reports unused/redundant test clauses. These warnings are not failures hidden by this report. GTK theme parser warnings also remain. Do not characterize either build as warning-free.

### 2.1 Geometry failures

The 24 rows in `...-geometry2.log` include 22 within 0.01 em and two outside it:

- `frac-x-squared-text`: ascent delta **−0.047600 em**, descent delta 0.000000 em (KaTeX ascent 1.017920; native 0.970320).
- `script-cascade`: ascent delta **+0.118637 em**, descent delta **+0.020262 em** (KaTeX 0.848733/0.446088; native 0.967370/0.466350).

Other rows, including `widehat-abcdef` and `wideaccent-pilot`, differ by −0.000514 em in ascent and remain within this geometry probe's tolerance. A geometry-row pass does not establish semantic mapping or raster similarity.

### 2.2 Raster pilot failures

All three image cases failed. The report used dimension tolerance 1 px, baseline tolerance 0.01 em, mask coverage threshold 0.99 and channel tolerance 2. `x` failed baseline (0.027773 em) and mask coverage; `frac-x-y` failed width by 6 px, baseline by 0.012941 em and mask coverage; `heatbalance-first-term` failed dimensions by (2,1) px, baseline by 0.038143 em and mask coverage. A shifted-baseline negative control was rejected as expected. Component correspondence is explicitly blocked; the harness states acceptance is blocked pending semantic native-to-KaTeX component mapping. Thus the pilot demonstrates real observed failures, not calibrated or accepted product visual behavior; separate physical desktop visual acceptance remains pending.

## 3. Implementation checkpoint (not acceptance)

The native production path has advanced substantially: source/token handling and Unicode mappings; lazy built-in/user macro expansion; parser, syntax/model, semantics and layout; font metrics/data; native symbol/path/stretchy-construct support; engine/resource boundaries; raster generation and asynchronous jobs; GTK integration, accessibility-tree support, inline painting and display raster presentation. The implementation includes 20 named font faces, 18 metric tables and 2,038 glyph records; this is data availability, not qualification of every face/glyph. Tests exercise arrays/columns, tags, limits, roots, styles, colors, paths, macros and error fallback in bounded samples.

The GUI integration has asynchronous math jobs, native raster drawing for display math, inline painting through GTK, and an expandable native accessibility tree. These are partial implementations: GTK main-thread time/scheduling and full async/display behavior are not qualified; the tree is not human assistive-technology acceptance. Do not infer full semantic, selection, navigation, or visual parity from presence of these components.

## 4. Coverage, limits, and unresolved requirements

The generated current crosswalk `plan/native-math-coverage.json` reports **2,930 core registry rows: 277 missing, 2,652 partial-implemented-unqualified, and one approved-deviation-not-applicable**. This is a row-count status map, not a compatibility percentage or independent test count. Within its current registries it reports 205/309 functions missing, 17/33 environments missing, 17/338 built-in macro rows missing, 33/2,236 symbol rows missing, and five/14 settings missing. Some missing core built-ins are callable; **17 callable KaTeX core built-ins remain missing and are not covered by D11/D12 exemptions**. D11 and D12 apply only to function-valued strict/trust callbacks and caller-supplied function-valued JavaScript macros. The missing setting list includes `maxSize`, `leqno`, and `fleqn`; the coverage map also marks `trust` and `colorIsTextColor` missing. The map and its partial rows require per-entry cases, implementation/evidence links, and qualification; key totals do not prove coverage.

The differential pilot has no complete reference origin/width/path/color/browser-pixel fields; native options are recorded as requested baselines, not measured option effects. It therefore cannot adjudicate the full geometry/semantic/policy contract. All 16 rows are blocked, not passes. P1 matching/readiness and complete per-entry corpus remain open. The 24-case geometry probe and three image pilot cases are useful discrepancy evidence, not substitutes for the approved complete corpus.

The resource JSON declares targets of 65,536 source bytes, 32,768 nodes, depth 128, 64 rows, 131,072 draw commands, default macro expansion 1,000, isolated process timeout 15 s and exporter RSS ceiling 262,144 KiB. Ten cases report child peak RSS values up to 41,888 KiB; the 11,000-byte macro-repeat case completed in 209 ms. Boundary/error statuses in this exporter can be produced by parse/syntax/node errors before source-limit validation. These checks do not demonstrate every exact/one-over approved SRS boundary, allocations for the full GUI/API job, retained raster cache, or the approved ≤256 MiB additional job memory. The resource report explicitly excludes whole-job, API and browser memory claims.

Performance JSON reports persistent synchronous headless exporter p95 1.033796 ms on 2,000 measured requests. It expressly excludes GUI and GTK scheduling. Queue-inclusive p95 ≤50 ms, completion/rejection ≤250 ms, GTK synchronous slice ≤50 ms, cancellation/cleanup timing, and GUI raster adoption are **not qualified**. The 10,000 fuzz run reports memory not measured; it does not qualify cancellation, lifetime/state behavior, all hostile inputs, or all resource ceilings. Do not equate the isolated exporter timeout or RSS ceiling with product-level compliance. Design-proposed context/worker/adoption caps, including RD-CTX-01, are not authorized SRS limits and are not acceptance criteria here.

Also outstanding: complete settings/mode/interaction and error-policy matching; full arrays/environments and function/builtin behavior; semantic/reference mapping; complete Unicode shaping and font use; source/error-fragment behavior; forbidden-effect tracing; full requirement traceability and reproducibility metadata; human desktop and accessibility review. The physical GUI was not accepted by a user. No live-provider qualification was attempted. The 1060-test full suite does not close these requirements.

## 5. Failure disposition and history

Current parity failures are the two geometry rows and all three PNG cases above. The 16 differential comparisons are blocked, not reclassified as failures or passes. There is no full reference corpus result. No claim is made that all crashes or failure paths were injected; none of these logs reports a qualification crash, but that is not evidence that crash/failure-path qualification is complete. The raster Valgrind result applies only to its standalone probe and reports still-reachable process allocations separately.

The earlier PCR-123 native cutover report (`plan/native-math-test-report.md`, dated 2026-10-22) records 1042/1042 at that checkpoint. The previously qualified 1057/1057 run is historical in `/tmp/coyote-parity-final-full.log`; it was not this run and does not establish parity. This report records the later actual **1060/1060** final2 suite, which supersedes those counts as the current regression result only. Older failures/fixes in prior records are historical; this run’s logs do not establish that all previous issues or all open compatibility defects are fixed. No full-product acceptance or qualification is implied by a green suite.

## 6. Required corrective work and exit decision

Qualification remains **NOT COMPLETE**. Continue in this order, without schedule estimates:

1. Correct and rerun the two geometry discrepancies (`frac-x-squared-text`, `script-cascade`); preserve the agreed tolerance and input corpus.
2. Complete semantic reference/native component mapping and pixel-comparison calibration/negative controls; then rerun all image cases. Do not tune criteria to mask observed deltas.
3. Resolve remaining callable built-ins, option behavior (including `maxSize`, `leqno`, `fleqn`), missing inventory rows, and per-entry case/evidence mapping under approved profile/deviations.
4. Complete resource, memory, queue-inclusive latency, GTK-slice, cancellation, and failure-path evidence against approved SRS values; keep unapproved context caps out of the acceptance denominator.
5. Close P1 field/matching/readiness and P6 traceability/regression; run the agreed full corpus and full development regression.
6. Obtain separate human desktop visual and accessibility review and user acceptance; record results and deviations before marking complete.

No commit was made for this report. The existing worktree already contained numerous modified and untracked implementation/planning files before the report was created; those edits were not reverted or otherwise changed here. This report is the only file created/edited for this request.

**Final evaluation:** substantial implementation, focused tests, resource experiments and a passing full regression checkpoint are recorded; measured geometry and raster discrepancies remain, most differential evidence is blocked, coverage has material missing/unqualified rows, and system-level GUI/resource/human gates remain open. The requested full completion condition is **NOT COMPLETE**.

## 7. Final source checkpoint — final3

After the isolated style-metric experiment was reverted, cramped radical
composition and the exact display-script condition were restored. The geometry
runner was reconciled to its original 24 compared cases. No tolerance was relaxed.
Current source was rebuilt and rechecked:

- Root development build: `/tmp/coyote-parity-final3-build.log`, pass.
- Test development build: `/tmp/coyote-parity-final3-testbuild.log`, pass.
- Full Xvfb suite from `test/`: **1060/1060**, zero failed assertions and
  unexpected errors; cumulative **81.260278 s**.
  Log: `/tmp/coyote-parity-final3-full.log`.
- Fresh exporter: `/tmp/coyote-parity-final3-export/bin/math_export`.
  The original `heat-balance-001` source and display-delimited hashes match the
  pinned pilot; native status is `ok`, with 54 draw commands including an actual
  U+02D9 dot glyph. Evidence: `...-export/heat-balance.jsonl`.
- Focused probes pass: macros 313, tokens 44, semantics 157, jobs 115, raster 42,
  engine 23, accessibility 63, additional forms/fallback 17, and native probe 151.
  Raster Valgrind reports zero errors/lost bytes for its scope.
- Final source geometry remains **22/24**, with the same two failures and deltas
  in §2.1. Log: `/tmp/coyote-parity-final3-geometry.log`.
- Structured differential remains **16 blocked**, not qualified successes:
  `/tmp/coyote-parity-final3-differential/report.json`.
- Final source fuzz: 10000 cases, 4779 `ok`, 5221 parse errors, zero layout errors;
  deterministic repeat identical. `/tmp/coyote-parity-final3-fuzz.json`.
- Ten isolated resource cases pass the harness checks, peak RSS **41756 KiB**.
  This is not a whole-GUI job-memory qualification.
  `/tmp/coyote-parity-final3-resources.json`.
- Headless benchmark: 2000 measured requests, p95 **0.655 ms** (rounded), excluding
  GUI scheduling. `/tmp/coyote-parity-final3-performance.json`.

Browser tools now consume JS, CSS, package metadata and all 60 font-format files
from the verified archive rather than mutable extracted assets. The 63-member
asset manifest SHA-256 is
`3e71d9db460b0d544a2aba0302db7aeee592ba88a08d457ec6e7860cf302cffc`.
Mutation controls confirm package-directory CSS/WOFF2 changes do not affect the
browser output. The three image cases still fail; their outcome is not promoted
to acceptance after the oracle provenance fix. Final visual calibration and
component matching remain open.

The final coverage map still records 277 missing core rows and no qualified
rows. Source/generator hashes have been regenerated; inventory presence is not
semantic coverage. Implementation remains **NOT COMPLETE**. No commit or release
build was made. All original user changes were preserved. Developer evaluation
and read-only agent reviews are not independent human acceptance.



## 8. Latest completion attempt — NOT COMPLETE

**Documentation checkpoint: 2026-10-26.** This section supersedes the current-state
claims in §§1–7, which retain earlier run results as history. The source tree
contains further implementation beyond the last full-suite checkpoint. No
current-source full qualification or product acceptance is recorded.

### 8.1 Latest full-suite checkpoint and frozen comparison evidence

The last completed root/test development builds and full Xvfb suite are:

| Evidence | Recorded outcome | Artifact |
|---|---|---|
| Root development build | Pass | `/tmp/coyote-completion-final2-build.log` |
| Test development build | Pass | `/tmp/coyote-completion-final2-testbuild.log` |
| Full suite, run from `test/` | **1061/1061**, zero failed assertions/unexpected errors; cumulative **82.378580 s** | `/tmp/coyote-completion-final2-full.log` |
| Geometry at that freeze | **113/113** at unchanged 0.01 em ascent/depth tolerance | `/tmp/coyote-completion-final2-geometry.log` |
| Structured pilot, strict comparator | **16 pass, 0 fail, 0 gap, 0 blocked**; negative controls pass | `/tmp/coyote-completion-final2-differential/report.json`; `/tmp/coyote-completion-final2-differential-negative-control.log` |
| Browser/native image pilot | **3 pass, 0 fail, 0 blocked**; shifted-baseline control rejected | `/tmp/coyote-completion-final2-images/report.json` |

These checks resolve the original two geometry discrepancies and three image
pilot failures for their tested snapshots. The structured pilot no longer has
16 blocked cases. However, its path comparison is at **0.01 normalized units**,
not 0.01 em. Reference origins, widths, complete component geometry and visual
calibration remain unqualified; `optionsMeasured` is false. A pilot pass is not
full per-entry coverage or a substitute for the approved acceptance corpus.

This full-suite freeze **predates generalized/infix fractions, mathchoice,
subsequent minimum-rule changes, and the latest color-scope candidate**. Do not
present 1061/1061 as a full regression result for those later edits.

### 8.2 Later implementation and focused evidence

Added or expanded native functionality includes scoped definitions and optional
defaults, bounded edef/xdef expansion, futurelet/global-let/long-prefix paths,
mode-dependent and bra-ket callable helpers, owned diagnostics, font/text
commands, large operators, starred arrays and cases variants, explicit delimiter
sizes, generated arrows/braces/radical outlines, rules, sizing, raised content,
cancellation/strike/smash, generalized/continued/infix fractions, mathchoice,
and hbox. These paths are implemented to varying degrees; none is promoted to
complete behavioral qualification merely by being present.

- The later tracked geometry corpus passed **145/145**: 37 legacy, 52 added
  construct/delimiter cases, 24 arrows/accents, eight mathchoice cases, and
  24 generalized/infix fraction cases. All seven intermediate fraction
  failures were corrected without relaxing the 0.01 em tolerance.
  Evidence: `/tmp/coyote-fraction-final145-r8.log`; build/native records under
  `/tmp/coyote-fraction-final145-r8/`. This is aggregate ascent/depth evidence,
  not full width, glyph-origin, clip, or raster qualification.
- Per-build rule parameters now separate the configured minimum from font
  defaults. Focused geometry remained 145/145 in the subsequent worker check;
  added engine assertions exercised custom-rule/minimum interaction. The last
  reported engine run was **40/41**, with default color scope failing
  (`/tmp/coyote-math-engine/probe.log`: 41 assertions, one failure).
- A subsequent parser edit makes default `\color` consume the following
  expression and leaves `colorIsTextColor=true` argument-scoped. Its validation
  command was **interrupted**; `/tmp/coyote-completion-color.log` is empty.
  The earlier color failure is not a measured result for this new candidate,
  and no later color pass is claimed. The candidate needs focused and full
  regression reruns, including group, array, and delimiter boundaries.
- Later macro probe: **511 checks**, not 511 macro definitions or registry
  entries. Additional parser/semantic probe: **187 runtime cases**. Earlier
  scoped checks passed tokens 44, semantics 157, paths 344, jobs 127, raster 42,
  accessibility 63, and native probe 152. Their executable/source snapshots
  differ from the latest candidate; they do not replace its integration rerun.
- Raster Valgrind reported zero errors/lost bytes for its standalone scope,
  with still-reachable allocations. This does not qualify all GUI ownership
  or failure paths.

The engine accepts bounded maxSize and left-tag behavior; trust defaults to
false and explicitly rejects trusted effects. A colorIsTextColor option and
parser candidate exist. `fleqn` remains explicitly unsupported in the source
at this checkpoint; attempted presentation work did not deliver a validated
alignment contract. No approved requirement or deviation was changed.

### 8.3 Resources, timing, and robustness — characterization only

Frozen final2 artifacts record:

- Seeded fuzz: **10000 cases**, 4184 `ok`, 5221 `parse-error`,
  595 `policy-visible-command`, zero layout errors; 32-case replay identical.
  Memory was not measured. `/tmp/coyote-completion-final2-fuzz.json`.
- Ten isolated exporter resource cases completed without process failure or
  timeout, peak RSS **44644 KiB**. The harness's 15 s process timeout and RSS
  ceiling are not the approved whole-job memory or 250 ms budget.
  `/tmp/coyote-completion-final2-resources.json`.
- Headless exporter: **2000 measured requests**, p95 **0.730159 ms**, maximum
  **1.460607 ms**. Excludes GUI/job-worker scheduling and raster adoption.
  `/tmp/coyote-completion-final2-performance.json`.
- Actual job-API characterization: **2000/2000 valid**, 127 assertions,
  zero failures; submit-through-poll p95 **1 ms**, maximum **2 ms** in the
  recorded focused run. Saturation accepted eight and returned Busy for two.
  `/tmp/coyote-completion-final-probes/jobs/probe.log`. Millisecond-resolution
  phase values and this bounded sequential corpus do not prove the general
  queue-inclusive deadline, cancellation, or adversarial latency guarantee.

Whole-job additional memory ≤256 MiB is **not enforced by aggregate allocation
accounting**. The 256 MiB source ledger covers retained request source, not all
containers, strings, intermediates, fonts, or rasters. The separate 64 MiB
retained-surface ledger covers GUI display-math Cairo surfaces, not inline
rasters or the process-wide cache target. Eight-row adoption with a cooperative
5 ms time check is not a hard GTK ≤50 ms guarantee. Deadline checks classify
expired work but do not interrupt parser/layout/raster loops or blocking calls.
Layout still uses depth 64 and 16384 draw commands, below approved targets 256
and 131072. Full resource, cache, cancellation, failure-path and GUI-slice
qualification remains open; RD-CTX-01 proposed context caps remain unauthorized.

### 8.4 Current coverage, remaining work, and exit decision

The regenerated [coverage map](native-math-coverage.md) records **2930 core
registry rows: 116 missing, 2813 partial/unqualified, one approved deviation,
and zero qualified rows**. Breakdown: 106 missing function rows, one environment
(`CD`), one setting (`fleqn`), and eight mode-specific symbol rows. All 338
built-in macro rows have some native path evidence, not full semantics or
per-template success proof. Seven supplemental scriptData rows remain missing.
This is a conservative source crosswalk; counts do not measure parity.

Remaining core work includes CD/diagram handling, verbatim and other primitives,
complete definition/argument semantics, remaining accent/enclosure/symbol and
Unicode/font behavior, option and policy interactions, and per-entry tests.
Complete the latest-source build/regression and comparison reruns before
claiming the new candidate is qualified. Finish full reference/component
mapping, option-effect measurements, approved resource/timing enforcement,
complete corpus/traceability, and reproducibility/readiness evidence.

The [human acceptance checklist](native-math-acceptance-checklist.md) is a
procedure, not an executed result. Named-desktop visual and assistive-technology
review and user acceptance remain pending. Developer/agent review is not
independent human acceptance. No release build or commit was made for this
documentation update; no runtime changes or new test runs were made in it.

**Current exit decision: NOT COMPLETE.** Earlier pilot failures have been
resolved within their scopes, but missing/unqualified core behavior, the
unvalidated latest candidate, system-level budgets and human acceptance remain.
