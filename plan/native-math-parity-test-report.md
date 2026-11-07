# Native math KaTeX compatibility — test report

**Document:** Combined Software Test Report (STR) for the approved execution baseline; final test readiness open
**Date:** 2026-11-06 (documentation reconciliation; approved work began 2026-10-24)
**Reference:** KaTeX 0.16.22, pinned archive SHA-256 `e9e0d167db3175481cbadaff38e8d90b130f6a3ddb451a47e43c577fd511f365`; bundle SHA-256 `8f1f4fb1080439c012bb8fddf424fa253e9144ab4cdd7dc0eae0e92cd04a5e33`
**Status: NOT COMPLETE — final qualification and product acceptance remain open.**

This report records a substantive implementation and verification checkpoint, not full KaTeX parity. Its controlling scope is approved SRS-MATH v1.0 and D01–D15, the execution-baseline STP/STD `plan/native-math-compatibility-tests.md`, and the P0–P6 plan `plan/native-math-parity-plan.md`. The test plan/readiness and visual calibration remain incomplete. No missing inventory row is converted into a pass or an approved exclusion. No user acceptance or independent human visual/accessibility acceptance is recorded.

**Current-results pointer:** §11, “Current implementation and qualification reconciliation — 2026-11-06”, controls the present status. §§1–10 preserve historical checkpoints. §11 distinguishes the earlier documentation reconciliation from the fresh, archived accent-width implementation evidence in §11.6. Sections 11.1–11.5 retain the prior checkpoint and its unavailable-artifact limits; §11.6 supersedes the undertilde pixel disposition only within the unchanged pilot scope.

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

**Historical checkpoint:** Superseded as current-source evidence by §9. Its
recorded outcomes and open issues describe the 2026-10-26 snapshot only.

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


## 9. Native implementation increment — 2026-10-27

**Historical checkpoint:** Superseded as current-source evidence by §10. The
following results describe the prior committed increment.

**Status: NOT COMPLETE.** Approved SRS-MATH v1.0 and D01–D15 are unchanged.
This section supersedes earlier current-state assertions, not their historical
run evidence. Production remains native Ada/GTK/Cairo/FreeType; KaTeX and the
browser are development-only references. Changes are uncommitted at this
checkpoint; this is not a release or human acceptance record.

### 9.1 Implemented and reviewed changes

- **Color scope:** default `\color` consumes the following expression, stopping
  before the enclosing right delimiter, array cell/row separator, or group end.
  `colorIsTextColor=true` and `\textcolor` remain argument-scoped. Focused
  assertions cover AST ownership, actual draw-command colors, nested groups,
  arrays, delimiters, scripts/fractions and malformed input. The empty previous
  validation log and earlier 40/41 result are historical, not current failures.
- **Fleqn:** explicit display requests carry left-alignment and **2 em** indent
  metadata through engine and immutable jobs into GTK. Formula width and draw
  coordinates are unchanged; inline math is unaffected. The default remains
  centered with no added indent. GTK uses 48 px at 24 px/em, scales to 96 px at
  48 px/em, and preserves indentation during pending and invalid-source fallback.
  One new widget test brings `Conversation_Stack` to **48 total registrations**;
  it does not add 48 tests or constitute human visual acceptance.
- **Macro arguments:** definitions own literal prefixes and per-parameter
  delimiters. Raw balanced argument scanning uses linear-time prefix matching,
  cannot match across groups, and strips outer braces only for a whole-group
  argument. Prefix/delimiter metadata survives local/global definitions, copies,
  let, edef and xdef. Special opening-brace terminators cover both `#1#{` and
  multi-token `#1END#{` forms. Review fixed quadratic front deletion,
  cross-group partial matches and incorrect maxExpand charges for prefix tokens.
  This is focused pinned-KaTeX compatibility, not complete TeX argument semantics.
- **Layout admission:** depth **256** and **131072 draw commands** now match the
  approved finite-domain targets. All command appends pass a checked helper;
  the final count is checked too. Calculated geometry remains limited to
  16384 em, syntax depth 128 and nodes 32768. Cases with 100 nested groups and
  17000 glyphs demonstrate support beyond the former limits; exact maximum and
  combined budget boundaries remain unqualified. Raising these admission bounds
  does not create an aggregate memory or timing guarantee.
- **Reference/state tooling:** native export includes fleqn presentation fields
  separately from formula width, and actual prefix/delimiter state. Reference
  snapshots derive from real KaTeX definitions. Controls mutate those fields
  and require disagreement with the reference projection. The harness builds
  its exporter locally when no explicit executable is supplied; it no longer
  relies on a previous scratch build. Option effects remain marked unmeasured.

### 9.2 Builds, full regression and intermediate failures

Development commands were `alr build --development`, followed by
`cd test && alr build --development --profiles=coyote=development` and
`xvfb-run -a ./bin/coyote_test` from `test/`.

| Check | Recorded result | Artifact |
|---|---|---|
| Root development build | Pass; existing compiler/style warnings remain | `/tmp/coyote-next-frozen-build.log` |
| Test development build | Pass | `/tmp/coyote-next-frozen-testbuild.log` |
| Frozen full suite | **1062/1062**, zero failed assertions/unexpected errors, **82.228506 s** cumulative | `/tmp/coyote-next-frozen-full.log` |
| Same-binary full repeat | **1062/1062**, zero failed assertions/unexpected errors, **82.167636 s** cumulative | `/tmp/coyote-next-frozen-full-repeat.log` |

Earlier runs at `/tmp/coyote-next-full.log` (82.499529 s) and
`/tmp/coyote-next-final-full.log` (82.415849 s) also passed 1062/1062, before the
last brace-scanner correction. Two intervening latest-source runs failed
**1061/1062**, both at the tool-detail window's exact mapped-size assertion:
`/tmp/coyote-next-brace-full.log` and `...-full-retry.log`. They are retained as
failures, not reclassified as successful runs. The focused test passed three
isolated attempts; the precise initial allocation was not logged, so the
original discrepancy cannot be attributed conclusively to a specific cause.

The test fixture previously relied on six fixed 20 ms frame delays. It now
pumps GTK and polls allocation against a one-second monotonic deadline, still
requiring **exactly 760×600**, with observed dimensions in the failure message.
It does not resize the window, alter production sizing, skip the assertion or
relax its dimensions. Both frozen full passes above include this test-only
synchronization correction. Two passes are regression evidence, not proof that
all display/environment timing interactions are qualified.

### 9.3 Focused and reference evidence

| Evidence | Recorded outcome | Artifact |
|---|---|---|
| Macro probe | **622 checks, zero failures** | `/tmp/coyote-next-brace-final/probe.log` |
| Engine probe | **57 assertions, zero failures** | `/tmp/coyote-next-final-engine/probe.log` |
| Jobs/raster lifecycle | **133 assertions, zero failures**; 2000/2000 warm requests valid; saturation eight accepted/two Busy | `/tmp/coyote-next-final-jobs/probe.log` |
| Native probe | **156 assertions**, including one 100-group case and one 17000-glyph case | `/tmp/coyote-next-frozen-native/math-probe.log` |
| Geometry | **145/145** aggregate ascent/depth cases; unchanged 0.01 em tolerance | `/tmp/coyote-next-frozen-geometry.log` |
| Structured pilot | **16 pass, zero fail/gap/blocked** | `/tmp/coyote-next-frozen-differential/report.json` |
| Comparator and state controls | Pass, including changed prefix/delimiter fields | `/tmp/coyote-next-frozen-controls.log` |
| Browser/native PNG pilot | **3 pass, zero fail/blocked**; shifted-baseline control retained | `/tmp/coyote-next-final-images/report.json` |
| Deterministic fuzz | **10000 cases**: 4184 ok, 5221 parse errors, 595 policy-visible commands, zero layout errors; identical 32-case replay | `/tmp/coyote-next-frozen-fuzz.json` |

The native 156-assertion probe was rebuilt against the frozen source. It remains
a focused rendering/admission check, not full-product qualification. The structured pilot compares normalized
paths at **0.01 normalized units**, not em-unit origins or full placement.
Origins, widths, complete component mapping and independently measured option
effects remain unqualified. The three PNGs are a pilot, not full visual corpus
qualification. No tolerance or acceptance denominator was relaxed.

### 9.4 Characterization, coverage and remaining gates

Ten isolated exporter cases completed the resource harness with peak child RSS
**46184 KiB** (`/tmp/coyote-next-frozen-resources.json`). A 2000-request headless
exporter benchmark recorded p95 **0.750889 ms**, maximum **1.186076 ms**
(`/tmp/coyote-next-frozen-performance.json`), excluding GTK/job-worker scheduling.
The actual job probe separately observed submit-through-poll p95 **1 ms**,
maximum **2 ms**, at millisecond resolution. These bounded corpora are not hard
queue-inclusive completion, cooperative cancellation or whole-job memory proof.

The regenerated [source crosswalk](native-math-coverage.md) records **2930 core
rows: 115 missing, 2814 partial/unqualified, one approved deviation, zero
qualified**. All scalar setting rows now have partial paths or an approved
serialization deviation; that does not mean complete option equivalence.
Missing rows remain 106 functions, one environment (`CD`) and eight symbols;
seven supplemental scriptData ranges remain missing. Generated template and
handler presence is not per-entry semantic qualification.

Whole-job additional memory ≤256 MiB still lacks aggregate allocation
accounting/enforcement. Retained source accounting is not all transient memory;
the separate 64 MiB display-surface ledger is not a process-wide inline/cache
bound. Hard queue-inclusive 250 ms completion/rejection, representative GUI
p95, preemptible parser/layout/native calls, GTK ≤50 ms slices, full cache/
tiling behavior, failure injection and approved exact-limit testing remain open.
RD-CTX-01 proposed additional context caps remain unauthorized. Core primitives,
Unicode/font behavior, full reference mapping and per-entry traceability still
need implementation or qualification. True long/short argument behavior is not
claimed from the accepted long-prefix path.

The [manual acceptance checklist](native-math-acceptance-checklist.md) remains
unexecuted. Developer/agent evaluation is not independent human visual or
assistive-technology acceptance. No release build, automatic approval or
completion claim follows from this increment. **Exit decision: NOT COMPLETE;
continue the already-approved native implementation and qualification.**


## 10. Core primitives and phase cancellation — 2026-10-27

**Exit status: NOT COMPLETE.** The native implementation now includes typed
verbatim, vertical centering and poor-man-bold nodes, but full parity, resource
qualification and human acceptance remain open. SRS-MATH v1.0 and D01–D15 are
unchanged. This working-tree increment is not committed or released.

### 10.1 Implementation and corrections

- **Verbatim:** the lexer captures `\verb` and `\verb*` payloads as owned raw
  tokens before comments, substitutions or expansion. Full command byte/scalar/
  UTF-16 spans and starred state are retained. Typed syntax and semantic nodes
  preserve literal text; layout uses pinned Typewriter metrics, NBSP for ordinary
  spaces and U+2423 for starred spaces. `@` is a valid delimiter. Parser lookahead
  treats the token atomically rather than interpreting payload-leading braces,
  dollars, scripts or alignment characters as syntax. Malformed commands remain
  explicit failures; missing glyph metrics are not invented as Unicode fallback.
- **Vcenter:** native layout shifts boxed content to the pinned math-axis
  centering formula while preserving its semantic child role.
- **Poor-man-bold:** the pinned 0.02 em/0.01 em shadow offset and 0.04 CSS-pixel
  blur are represented in typed layout/export metadata and painted for glyphs.
  The native bounded Gaussian-tap mask is an **approximation**, not demonstrated
  exact browser CSS blur. Rules and SVG paths are not themselves text-shadowed.
  Color/alpha and group cleanup have focused tests. Full raster dimensions retain
  right/bottom shadow overflow without changing logical formula metrics; display
  adoption sizes its area from the raster. Integer allocation dimensions, after
  rounding the combined extent, are checked against 8192×4096; tile limits remain
  256×256. Exact and one-over fractional-extent cases exercise these checks.
- **Jobs:** cancellation/deadline checks bracket parsing, semantic projection,
  layout, font loading, rasterization and publication. Expired queued jobs skip
  source/font-input copying and parsing. Successful-result assertions were kept
  separate from new paused-queue expiry cases; changing successful cases into
  expired jobs is not counted as equivalent coverage. These are **phase-boundary
  cooperative checks**, not interruption inside a parser/layout loop or native
  call and not a hard queue-inclusive 250 ms guarantee.
- **Presentation and evidence:** accessibility labels and JSON exports preserve
  raw payloads and distinct content roles. One new display-backed primitive case
  brings `Conversation_Stack` to **49 registered cases**. The image oracle now
  measures all direct reference bases, separates logical dimensions from padded
  rasters, and compares with independently recorded origins. Omitted-base,
  wrong-origin and shifted-baseline controls must reject.

An intermediate verbatim change replaced the 0.525 em font advance with 13/24 em
to match the 24 px pilot. Review found this was a pixel-size-specific fit, not
pinned font data; it was **reverted**, and regressions now check font-derived
advances at multiple native sizing scales. The intermediate 9/9 image result
with that override is not current qualification. TTF/WOFF2 metrics both report
525/1000 em; successful font loads do not yet explain or resolve the image
setup's 13 px versus native 12.6 px per-character advance at 24 px/em.

### 10.2 Frozen development and focused evidence

Root and test builds use development profiles. Full suites run from `test/`
under Xvfb. Existing compiler/style and GTK theme warnings remain; no warning-
free or release qualification is claimed.

| Evidence | Recorded result | Artifact |
|---|---|---|
| Root development build | Pass | `/tmp/coyote-core-frozen-build.log` |
| Test development build | Pass | `/tmp/coyote-core-frozen-testbuild.log` |
| Full suite | **1063/1063**, zero failed assertions/unexpected errors; **82.418882 s** | `/tmp/coyote-core-frozen-full.log` |
| Same-binary full repeat | **1063/1063**, zero failed assertions/unexpected errors; **83.167815 s** | `/tmp/coyote-core-frozen-full-repeat.log` |
| Geometry | **157/157**, original 145 plus 12 primitive/style cases; unchanged 0.01 em ascent/depth tolerance | `/tmp/coyote-core-frozen-geometry.log` |
| Additional runtime cases | **211 PASS records** | `/tmp/coyote-core-frozen-additional.log` |
| Tokens | **56 assertions**, zero failures | `/tmp/coyote-core-frozen-tokens/probe.log` |
| Macros | **622 checks**, zero failures | `/tmp/coyote-core-frozen-macros/probe.log` |
| Engine | **57 assertions**, zero failures | `/tmp/coyote-core-frozen-engine/probe.log` |
| Jobs | **137 assertions**, zero failures; 2000/2000 warm requests valid | `/tmp/coyote-core-frozen-jobs/probe.log` |
| Native rendering/admission | **156 assertions**, zero failures | `/tmp/coyote-core-frozen-native/math-probe.log` |
| Accessibility | **67 assertions**, zero failures | `/tmp/coyote-core-frozen-accessibility/probe.log` |
| Raster/Valgrind | **54 focused checks**; zero Valgrind errors, zero definitely/indirectly/possibly lost bytes; reachable allocations remain | `/tmp/coyote-core-frozen-raster.log` |
| Structured pilot | **16 pass**, zero fail/gap/blocked | `/tmp/coyote-core-frozen-differential/report.json` |
| Comparator controls | Pass | `/tmp/coyote-core-frozen-controls.log` |

The full suite includes the new literal/box primitive widget case. These checks
are distinct from end-user or assistive-technology acceptance. Structured path
comparison remains at 0.01 **normalized units**, not full em-unit glyph origins
or complete placement. The expanded geometry corpus is aggregate ascent/depth,
not comprehensive width, ink or option-effect qualification.

### 10.3 Expanded raster pilot — two unresolved failures

The original three IDs and sources are unchanged; six new cases exercise
vcenter, raw punctuation, visible spaces and poor-bold glyph/relation/fraction
content. The final **nine-case pilot is 7 pass / 2 fail / 0 blocked** at
`/tmp/coyote-core-frozen-images/report.json`. The runner exits nonzero for these
mismatches. Approved comparison criteria were not loosened, and failing cases
were not removed from the denominator.

| Case | Current failure |
|---|---|
| `verb-punctuation` | Logical width delta **4.0 px** exceeds 1 px; bidirectional foreground-mask coverage below 99% at 1 px tolerance |
| `verb-star-spaces` | Logical width delta **1.2 px** exceeds 1 px; mask and baseline checks pass |

The original three cases and the vcenter/poor-bold cases pass within this pilot.
Pmb relation initially appeared too wide because the reference measured only its
first `.base`; measuring the union of direct bases corrected the oracle without
changing native relation spacing. The omitted-last-base negative control still
rejects a 9.6738 px discrepancy. Wrong-origin and shifted-baseline controls also
reject. These controls and the bounded cases do not establish full component
mapping, exact blur/color parity, arbitrary overflow handling or calibrated
visual acceptance. Browser/native Typewriter advance behavior still needs a
reference-guided fix across sizes, not another pilot-specific constant.

### 10.4 Characterization and remaining gates

- Fuzz: **10000 cases**, 4184 ok, 5221 parse errors, 595 policy-visible commands,
  zero layout errors; identical 32-case replay.
  `/tmp/coyote-core-frozen-fuzz.json`.
- Ten isolated exporter resource cases: peak child RSS **49256 KiB**.
  `/tmp/coyote-core-frozen-resources.json`. This is not whole-job allocation
  enforcement or process-global GUI/cache accounting.
- Headless exporter: **2000 requests**, p95 **0.784945 ms**, maximum
  **0.944486 ms**, excluding GTK/job scheduling.
  `/tmp/coyote-core-frozen-performance.json`.
- Job API characterization: 2000 valid requests, submit-through-poll p95 **1 ms**,
  maximum **2 ms**; saturation eight accepted/two Busy. This bounded corpus is
  not a hard deadline or adversarial cancellation-latency guarantee.

The regenerated [coverage map](native-math-coverage.md) has **2930 core rows:
112 missing, 2817 partial/unqualified, one approved deviation, zero qualified**.
Three new primitive paths moved from missing to partial, not to qualified.
Seven supplemental Unicode script-range predicates are generated but unused;
their runtime shaping paths remain missing. The range data itself is not absent.
General Unicode/font fallback, remaining core commands/environments including
CD, full per-entry behavior, reference widths/origins/options, complete corpus
and traceability remain open.

Whole-job ≤256 MiB allocation accounting/enforcement, process-wide ≤64 MiB cache,
inline off-thread painting, hard queue-inclusive completion/rejection ≤250 ms,
GTK ≤50 ms slices, complete tiling/cache behavior and failure injection are not
qualified. Phase checks improve cancellation but do not close these gates.
RD-CTX-01 additional context caps remain unauthorized. The manual visual and
accessibility checklist remains unexecuted. Developer/agent self-review is not
independent acceptance. **Project remains NOT COMPLETE; continue approved
implementation and qualification with both raster failures visible.**


## 11. Current implementation and qualification reconciliation — 2026-11-06

**Exit status: NOT COMPLETE.** Approved SRS-MATH v1.0 and D01–D15 remain
unchanged. The native implementation has advanced beyond §10, but source-path
coverage, scoped regression passes, and outcome agreement are not full KaTeX
parity, resource qualification, or product acceptance. PCR-125 remains open.
This reconciliation does not authorize additional RD-CTX-01 context caps.

**Current continuation:** §11.6 records a fresh accent-width correction, 29/29 image
pilot and repeat, 207 raster assertions and a 1063/1063 full suite. Earlier
checkpoint results below remain historical; all other exit gates remain open.

### 11.1 Evidence authority and availability

This section reconciles the implementation work recorded during the preceding
continuation with current source inspection. The implementation chronology
includes checkpoints dated 2026-10-27–28. **No application build, math probe,
full suite, browser comparison, or live-provider test was rerun for this
2026-11-06 documentation update.** Documentation validation and deterministic
coverage regeneration are separate from runtime testing.

The temporary `/tmp` logs and JSON reports cited during that continuation are
not available in this workspace at reconciliation. Results below are therefore
**recorded execution results**, not newly inspected raw evidence or a freshly
qualified snapshot. Former artifact names are retained as retrieval identifiers,
not links to files asserted to exist. Reproduce and archive the required runs,
with source/executable hashes and workstation/font manifests, before using them
for a qualification decision. The working-tree increment is uncommitted; no
release build, push, or product acceptance is recorded.

### 11.2 Current native implementation

Source inspection identifies these paths, without establishing complete
per-command behavior or reference equivalence:

- Dedicated CD parsing and typed arrows/labels, including the separate final
  ghost row and admission of 64 visible rows; angled, floor, ceiling and middle
  delimiters; contour double/triple integrals composed from pinned glyphs and
  SVG paths; and solid/dashed horizontal array rules.
- Text cedilla and circled accents, widecheck/undertilde, phase and actuarial
  enclosures, colorbox/framed-colorbox, stack/annotation and internal fraction
  helpers. CD/helper argument contracts and parent-relative behavior remain
  subject to per-entry qualification, not completion by name recognition.
- Raw Unicode builtin expansion, command-definition namespace checks, scoped
  `\long`/global-prefix behavior, preserved conditional lookahead, and valid
  empty mathematical outcomes. KaTeX compatibility does not imply full TeX
  paragraph/long-argument semantics.
- Native glyph advances measured from loaded Cairo/FreeType fonts at the target
  pixel size, plus fragment font extents and CSS-leading line-box construction.
  The pinned normalized Typewriter advance remains 0.525 em. Pixel-specific
  13/24 em and browser-line-height fits were rejected; successful intermediate
  runs using those fits are not evidence for the retained implementation.
- Typed UTF-8 text runs gated by the seven `scriptData` ranges, with native
  Pango-Cairo shaping, semantic payloads and source preservation. Runtime
  shaping now exists; the old predicate-only description is historical.
  System font families are selected at runtime and are **not pinned fallback
  fixtures**. Glyph coverage, strict-policy behavior and shaping equivalence
  remain unqualified.
- Borrowed `Math_Work_Control` contexts polled in source validation, lexing,
  expansion, syntax, semantics, layout, paths, font/shaping and raster work.
  Nested cursors inherit the context. Cooperative polling does not interrupt
  an individual native call or establish a hard deadline.
- Shared `Math_Raster_Budget` noncopyable leases with a 64 MiB capacity for
  tracked completed job raster vectors, display Cairo surfaces and inline
  Pixbuf lifetimes. This is retained-raster accounting, not aggregate job
  allocation accounting or qualification of every process cache.

The production renderer remains native Ada with Cairo/FreeType/Pango; KaTeX,
Node and Chromium are development oracles, not production dependencies.
Poor-man-bold shadow rendering remains an approximation, not exact CSS blur.

**Inline integration is unfinished:** `Rich_Text.Render_Formula` still calls
`Math_Element.Render_Layout_Inline` on GTK; its math-job submission does not
request a raster. Worker-backed display output does not close inline off-thread
painting, complete tiling/cache/repaint reuse, or GTK time-slice requirements.
The aborted inline-worker attempt supplied no completed implementation.

### 11.3 Latest recorded regression and comparison results

| Evidence class | Latest recorded result | Interpretation |
|---|---|---|
| Development builds and full AUnit suite | Root/test development builds passed; full runs passed **1063/1063**, zero unexpected errors | Historical regression evidence; later renderer/test edits and unavailable logs prevent current-snapshot qualification |
| Full-suite repeat exceptions | Some intermediate/repeat runs failed one GTK allocation assertion or a prompt-filter trimming assertion | Retain as failures; isolated reruns do not establish the original cause or waive them |
| Geometry corpus | **235/235**, across 13 groups | Aggregate ascent/depth at unchanged 0.01 em tolerance; not complete widths, origins, placement or raster equivalence |
| Structured reference pilot | **16/16**, zero fail/gap/blocked; comparator controls passed | Scoped role/path evidence; path tolerance is 0.01 normalized units, not 0.01 em placement |
| Expanded image pilot | **28/29**, one failure, zero blocked | Original nine cases retained; includes actual 12/16/20/24/32/48 pixel-em sizing, new primitives, CD and explicit newlines |
| Builtin callable audit | **338/338 outcome matches; 278 scoped semantic matches; 60 explicit comparison gaps; zero outcome deviations/blocked probes** | Strict audit remains nonzero and `NOT_QUALIFIED`; the 60 gaps are not passes |
| Native rendering/admission probe | **161 assertions**; accompanying reference checks 19 valid and 8 invalid cases | Scoped probe, not complete approved-domain boundary qualification |
| Raster functional probe | **111/111** | Does not override the failing strict Valgrind result below |
| Seeded fuzz | **10000 cases**: 4184 ok, 5221 parse errors, 595 policy-visible, zero layout errors; identical 32-case replay | Fixed seeded corpus only |
| Resource characterization | **10 isolated exporter cases passed**, peak child RSS **66752 KiB** | Not aggregate additional job-memory enforcement; source-limit comment-only input is reference-valid empty output |
| Headless performance | **2000 requests**, recorded p95 about **0.93 ms** | Excludes GTK, queue-inclusive completion and representative whole-product latency |

The final callable comparator records 44 projection differences, seven
out-of-scope font/script-style cases, three unsupported `mspace` attribute
cases, three accent-marker cases, two stretchy nodes and one tagged node among
the 60 gaps. This is a comparison-readiness classification, not proof that all
60 are renderer defects. Complete the mappings and adjudicate the resulting
comparisons without silently normalizing away unsupported behavior.

At the reconciliation checkpoint, the pixel failure was **`utilde-long`**
(`\utilde{abcdef}`): recorded
native-to-browser foreground-mask coverage is approximately **0.9851**, below
**0.990**; logical dimensions and baseline pass in that pilot. The parsed cubic
path/control-point checks did not establish a source-data/parser discrepancy.
That checkpoint failure was not waived; §11.6 records its fresh reproduction
and scoped correction.
The 1 px mask tolerance, 1 px logical-dimension limit and 0.01 em baseline limit
were not relaxed. These pilot criteria remain distinct from final calibration
and human visual acceptance.

Recorded corrections include obsolete negative cedilla and comment-only-source
fixtures, rejected width/line-height fits, source-specific parser shortcuts,
macro-context pollution, single-part arrow clipping, vertical-piece/shaft
placement and centered array-column stride. Passing corrected tests do not
retroactively turn their earlier failures into passes.

Former retrieval identifiers include `/tmp/coyote-native-closure-full.log`,
`/tmp/coyote-native-closure-full-repeat.log`,
`/tmp/coyote-native-closure-images/report.json`,
`/tmp/coyote-native-closure-differential/report.json`,
`/tmp/math-callables-final2.json`, and
`/tmp/coyote-math-shaping-lifecycle/`. They are **unavailable at this
reconciliation**. In particular, the closure repeat recorded 1062/1063 with a
prompt-filter assertion; it must not be described as a successful repeat.
Earlier recorded pairs of 1063/1063 passes predate some later changes.

### 11.4 Native-library lifecycle failure

Strict Valgrind remains failing. The recorded raster run reports **6656 bytes
definitely lost, 2183 bytes indirectly lost and 26 bytes possibly lost**, with
two unsuppressed error contexts. Isolated shaping lifecycle runs reported the
same definite/indirect totals at 1, 10, 100 and 1000 measure calls; drawing runs
at 1, 10 and 100 had the same definite/indirect totals. Possible-loss and
reachable-cache totals varied with Pango/GLib thread-local and native cache
state. The fixed definite/indirect trace points into Fontconfig initialization.

This supports a fixed initialization-loss observation in that isolated test,
not zero leaks, proof of all ownership paths, or a process-wide memory bound.
No blanket suppression, unsafe per-job global Fontconfig shutdown, or passing
lifecycle qualification is justified. Resolve or formally adjudicate the
native-library lifecycle evidence with reproducible platform-specific tests.

### 11.5 Source crosswalk and open exit gates

The generated map contains **2930 core rows: 2929 partial/unqualified, one
approved deviation, zero missing and zero qualified**. All 309 function names,
33 environments and 338 builtin names have source-path entries. Supplemental
script-range rows now identify conditional runtime shaping paths. Zero missing
rows means no remaining unmapped source-path row under the crosswalk method;
it does **not** establish complete arguments, mode behavior, glyph coverage,
semantics, rendering, diagnostics, options or combinations.

The remaining exit work is:

1. Extend the scoped undertilde closure in §11.6 to complete accent behavior
   and resolve the 60 callable comparison gaps; finish full
   component mapping, widths/origins, independently measured option effects,
   complete per-entry/interaction/invalid/boundary traceability and readiness.
2. Enforce **at most 256 MiB additional memory per job**, including overlapping
   transient allocations. Source/vector/surface limits and measured child RSS
   do not substitute for aggregate enforcement. Qualify all retained-cache
   lifetimes against the process target, not only the tracked lease counter.
3. Establish bounded cleanup and queue-inclusive completion/rejection within
   **250 ms**, representative warm p95 at most **50 ms**, and GTK math slices
   at most **50 ms**. Polling and fast headless probes are not those guarantees.
4. Complete inline worker rasterization and approved display tiling/cache/
   repaint reuse; qualify cancellation, stale results, allocation failures,
   ownership and exact/combined resource boundaries.
5. Pin fallback-font files/licenses and workstation/browser/font manifests;
   qualify Unicode/font behavior and resolve the native-library lifecycle gate.
6. Execute the named-desktop visual and assistive-technology checklist and obtain
   independent/user acceptance. Automated widgets, source review and this
   developer self-evaluation are not human acceptance.
7. Reproduce and archive a coherent final-source regression/oracle matrix,
   reconcile failed repeats, and complete configuration/handover records.

**Disposition:** continue approved P0–P6 execution. There is no new approval-wait
loop and no authorization to narrow the approved domain, waive failures, or add
RD-CTX-01 caps. This documentation update changes no requirements or comparison
thresholds. **Project remains NOT COMPLETE.**


### 11.6 Fresh continuation — measured stretchy-accent width, 2026-11-06

**Scope:** one shared layout defect, not full accent parity or qualification.
The exact pinned KaTeX 0.16.22 archive was restored from npm and its SHA-256
verified against the existing pin. The unchanged 29-case image pilot reproduced
**28 pass / 1 fail**, including `utilde-long` native coverage
**0.9851411589895989** and browser coverage **0.9967159277504105**. The baseline
failure is retained, not replaced by the later pass.

**Root cause and correction:** measured body layout preserves the final glyph's
italic correction separately from its advance width. The stretchy accent branch
added that correction to the result box only after fitting the path and clip to
the smaller uncorrected body. A final italic `f` therefore left the tilde too
short. `Math_Layout.Compose` now uses one corrected width for horizontal path
fitting, command width, clip width and result width. The shared branch covers
`utilde`, `widetilde`, `widehat` and `widecheck`; layouts without a measured
advance source retain their prior width. SVG path data, vertical placement,
reference pins, corpus and comparison thresholds were not changed.

**Regression design:** the raster probe adds 96 assertions over four accents,
`abcdef` (italic-ending) and `abcde` (non-italic control), and 12/16/20/24/32/48
pixel-em sizes. Checks cover corrected command/clip/result widths, transformed
path endpoints/control points and preserved unmeasured geometry. Before the
production correction, the initial 48 added width checks failed exactly the
24 italic-ending combinations (159 total assertions, 24 failures). The final
strengthened probe passes **207/207**, zero failures. This is functional raster
and layout evidence; Valgrind was not rerun and §11.4 remains an open failure.

Fresh execution results:

- Root `alr build --development` and test
  `alr build --development --profiles=coyote=development` pass. Generated root
  and test profiles select `development`; root build reported executables up
  to date. These were incremental builds, not clean-build qualification.
- Full suite from `test/` under Xvfb: **1063/1063**, zero failed assertions and
  unexpected errors, cumulative **88.930779 s**, wall **89.11 s**. An initial
  invocation could not locate the test executable (exit 127); the corrected
  working-directory invocation produced the retained suite log. This one
  successful suite run does not reconcile earlier non-math repeat failures.
- Unchanged image pilot and same-source repeat: **29/29** each, zero failures
  or blocked cases. `utilde-long` bidirectional coverage is **1.0 / 1.0**;
  logical width/height deltas remain about **0.005235 / 0.013745 px**, baseline
  delta **0.000532 em**. Original 0.990 mask, 1 px dimension and 0.01 em baseline
  criteria and omission/origin/baseline negative controls remain unchanged.
- Geometry: **235/235** in 13 groups at the existing tolerance; additional
  probe: **280 PASS records**; structured pilot: **16/16**, no fail/gap/blocked.
  The standalone comparator control harness was not separately rerun.

**Durable evidence:**
`plan/evidence/native-math-2026-11-06-accent-width/` retains baseline/after/repeat
reports and PNGs, full-suite/build/focused logs, structured exports, the exact
implementation patch, platform/toolchain/font/source/executable hashes and
`SHA256SUMS`. Original absolute `/tmp` paths inside reports are retrieval
identifiers; corresponding images are archived under each phase directory.
See its README for commands, provenance and limits. This is a developer snapshot,
not a complete frozen workstation/desktop qualification matrix.

**Evaluation/disposition:** developer self-review and read-only agent review
found the width correction consistent with KaTeX's body-wide SVG contract;
neither is independent user acceptance. The narrow `utilde-long` pilot failure
is resolved without threshold fitting. Single-character skew placement, full
accent combinations, the 60 callable gaps, inline off-thread rasterization,
whole-job memory, hard deadlines, GTK/cache guarantees, fallback pins, native
library lifecycle and independent visual/AT acceptance remain open. Approved
SRS-MATH v1.0 and D01–D15 are unchanged. PCR-125 remains OPEN and the feature
**NOT COMPLETE**; no release or commit is made by this continuation.
