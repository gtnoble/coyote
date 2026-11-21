# Native math KaTeX compatibility — test report

**Document:** Combined Software Test Report (STR) for the approved execution baseline; final test readiness open
**Date:** 2026-11-06 (documentation reconciliation; approved work began 2026-10-24)
**Reference:** KaTeX 0.16.22, pinned archive SHA-256 `e9e0d167db3175481cbadaff38e8d90b130f6a3ddb451a47e43c577fd511f365`; bundle SHA-256 `8f1f4fb1080439c012bb8fddf424fa253e9144ab4cdd7dc0eae0e92cd04a5e33`
**Status: NOT COMPLETE — final qualification and product acceptance remain open.**

This report records a substantive implementation and verification checkpoint, not full KaTeX parity. Its current controlling scope is user-authorized SRS-MATH v1.1 (2026-11-15) and unchanged D01–D15; v1.0 resource-scope statements are historical, the execution-baseline STP/STD `plan/native-math-compatibility-tests.md`, and the P0–P6 plan `plan/native-math-parity-plan.md`. The test plan/readiness and visual calibration remain incomplete. No missing inventory row is converted into a pass or an approved exclusion. No user acceptance or independent human visual/accessibility acceptance is recorded.

**Current requirements pointer:** §11.18 records the v1.1 practical resource-abuse scope correction, superseding exhaustive-accounting completion gates without changing historical results. No new runtime verification is claimed. The user-accepted maintenance policy is recorded in §11.20; it does not remove code or approve the optional ownership redesign.

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

**Current continuation:** §11.13 records raster workspace reservations,
in-place worker output and1076/1076 regression; §11.12 records retained-output
preadmission. §11.11 records worker-backed inline rasterization; §11.10 records
origin-aware correction and95/95 expanded images.
The dated §11.2–11.5 snapshot below is historical
where superseded by these continuations; its broader open gates still apply.
§11.7 records ordinary-accent skew/span corrections,
363 raster assertions, 1063/1063 full suite, 29/29 original images and 49/53
expanded images/repeat with four retained failures. §11.6 is the preceding
stretchy-accent correction. Earlier
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


### 11.7 Fresh continuation — ordinary-accent skew and measured span, 2026-11-07

**Scope:** ordinary above-accent placement and width, not full accent parity.
The new supplemental `accent-skew-manifest.json` retains the unchanged original
29 cases and adds 24 cases (12 base forms at 24/48 px per em). Baseline is
**31/53**, zero blocked; the original 29 cases already pass at this baseline.
Do not confuse that subset with the older §11.6 28/29 undertilde baseline.

**Corrections:** the ordinary accent branch inferred character eligibility from
painted glyph count, incorrectly skewing one-glyph overline/smash/cancel bodies.
It now traverses singleton rows and colors to a non-operator glyph, stopping at
other node kinds, with bounded work-control polling. Font arguments are flattened
by the existing parser. The shared script `Is_Character_Box` helper is unchanged.
Measured above accents now consume the trailing body italic margin into width
and centering exactly once, clearing the transferred correction to avoid nested
reapplication. Unmeasured widths and below/full accent branches are unchanged.
Direct pinned-browser DOM measurements establish dot-T origin 7.328125 px and
smashed-T origin 5.328125 px at 24 px/em; an initial review suggestion to center
on the uncorrected width was rejected against these measurements. No path data,
reference pins or comparison threshold changed.

**Regression evidence:** the new unit check fails before correction on
`\dot{\overline{T}}` and passes afterward. The measured probe before span
correction records **351 assertions / 132 failures** (after skew-only correction).
Final strengthened probe passes **363/363**, including 144 added width/position
checks across 12 bases and six sizes and 12 below/full preservation guards.
Read-only review caught an intermediate below/full scope regression; the final
patch restricts margin consumption to above accents and adds those guards.

Final-source results:

- Incremental root/test development builds pass; generated profiles select
  `development`. Existing warnings remain; no clean-build qualification.
- Full Xvfb AUnit suite **1063/1063**, zero failures/errors, cumulative
  **82.909971 s**. An earlier broader intermediate patch also passed 1063/1063
  in 83.603988 s; only the final run qualifies this scoped regression snapshot.
  Neither reconciles historical non-math failed repeats.
- Geometry **235/235** across 13 groups. The additional probe records **280 PASS**
  on the intermediate patch; it was not rerun after the above-only restriction.
- Expanded images and final-source repeat **49/53** each, zero blocked, same four
  failures. Original unchanged pilot separately passes **29/29** twice. Omitted
  base, displaced-origin and shifted-baseline negative controls pass unchanged.
- Remaining image failures are `accent-skew-overline-24/48` (height deltas
  1.91044/3.836505 px, baseline deltas 0.079602/0.079927 em and mask failures)
  and `accent-skew-cancel-24/48` (mask failures). They are retained as failures,
  not waived or removed. Overline vertical clearance and cancel stroke geometry
  remain separate open defects; below/full guards preserve prior behavior,
  not proof of their reference parity.

**Evidence:** `plan/evidence/native-math-2026-11-07-accent-skew/` retains
baseline/final/repeat and separate original-pilot reports and PNGs, logs, browser
positions, exact patch, supplemental manifest, snapshot hashes and checksums.
Reports' absolute `/tmp` paths are original retrieval identifiers; archived PNGs
are in the corresponding phase directories. This is a developer snapshot, not a
frozen desktop/font or whole-product qualification matrix. Valgrind, resource,
GTK, callable-gap and human visual/AT gates were not rerun or closed.

**Disposition:** the scoped skew/span defects are corrected; expanded images
still fail four cases. Developer and read-only agent review are not independent
user acceptance. SRS-MATH v1.0 and D01–D15 unchanged; PCR-125 OPEN and feature
**NOT COMPLETE**. No release or commit.


### 11.8 Fresh continuation — overline rule geometry, 2026-11-10

**Scope:** correct overline rule position, envelope and width against pinned
KaTeX 0.16.22 `overline.js` (TeX Rule 9). The previous fixed 0.08 em placement
and 0.12 em ascent growth omitted the reference's clearance, stroke extent and
upper kern. The rule now clears the cramped body by three style-specific
**default** rule thicknesses, paints at max(default, minimum thickness), and
reserves one further default thickness above the rule. Minimum thickness does
not inflate the kerns. Script/scriptscript default thickness is 0.049 em before
style scaling. Rules span the full body rather than being inset 0.05 em;
measured layouts incorporate and clear the body's trailing italic margin once.
Unmeasured widths/italic propagation, underline and cancel code are unchanged.
No reference pin, image threshold, path data or approved requirement changed.

**Regression evidence:** measured probe before correction reports **423
assertions / 48 failures**, covering all four new overline checks across six
pixel sizes and two minimum-thickness settings. Final strengthened probe passes
**423/423**, including explicit nonzero italic-margin/cleared-result controls
and 12 underline-preservation guards. The existing focused AUnit accent case
passes with nine added configurations: default/minimum thickness, display,
fraction/nested/smashed bases and script/scriptscript scaling. These are local
regressions, not proof of full accent behavior.

Final-source results:

- Incremental root/test **development** builds pass; generated profiles select
  development. Existing warnings remain; no release or warning-free claim.
- Full Xvfb AUnit suite **1074/1074**, zero failed assertions/unexpected errors,
  cumulative **142.762374 s**. This run does not reconcile historical non-math
  failed repeats or constitute an installed-binary/desktop qualification.
- Geometry **235/235** across the unchanged 13 groups.
- Expanded images **51/53**, zero blocked, repeated identically. Both overline
  cases now pass: height deltas 0.009560/0.003495 px and baseline deltas
  0.0003983/0.0000733 em at 24/48 px. Bidirectional mask coverage is
  1.0/0.9935897 at 24 px and 1.0/1.0 at 48 px, against unchanged 0.990 limits.
- Original image pilot **29/29**. Omitted-base/origin/baseline negative controls
  pass in each image report. Only `accent-skew-cancel-24/48` remain failing in
  the expanded corpus; they still fail the mask criterion and were not waived.
- Required post-build GTK interactions **9/9**; interaction-runner containment
  self-test passes (its deliberately killed/timed-out fixtures are expected).
  Offline HTTP timeout lifecycle passes Plain/RPC, zero-disable delayed success
  and 4+4 stalled-request checks. No live-provider checks were run.

**Evidence:** `plan/evidence/native-math-2026-11-10-overline/` retains before/final
probe logs, development/full/geometry/post-build logs, final/repeat/original
image reports and PNGs, exact implementation patch, source/font/executable
hashes and checksums. Absolute `/tmp` paths in reports are original retrieval
identifiers; use archived PNGs in each corresponding phase. Read-only agent
review found no blockers; its suggested nonzero italic control was added and
passes. Developer and agent review are not independent user acceptance.

**Disposition:** scoped overline defect resolved; PCR-125 OPEN and feature
**NOT COMPLETE**. Cancel stroke geometry, broader behavior/callable comparison,
whole-job memory, deadlines, inline GTK/cache, unpinned fallback fonts, existing
native lifecycle failure and independent visual/AT acceptance remain open.
Valgrind and resource characterization were not rerun. SRS-MATH v1.0 and D01–D15
unchanged; no release, installation or commit.


### 11.9 Fresh continuation — cancellation SVG geometry, 2026-11-10

**Scope:** cancellation paths (`cancel`, `bcancel`, `xcancel`), not full enclosure
or raster-origin parity. Pinned KaTeX 0.16.22 `enclose.js`/`stretchy.js` and direct
Chromium DOM measurements establish 0.046 em butt-ended strokes, SVG viewport
clipping, vertical 0.2 em padding for character bodies and horizontal 0.2 em
padding for composite bodies. The old code padded both axes for characters,
neither for composites, used an oversized minimum-clamped stroke and omitted
measured trailing italic width. The cancellation-specific bounded syntax walk
unwraps singleton rows/colors and flattened fonts, but not accents; the shared
script character helper is unchanged. Measured cancellation owns the body
margin once. Unmeasured width/italic behavior, logical vertical metrics and the
strike-through branch remain unchanged. SVG strokes intentionally do not obey
`minRuleThickness`, matching the pinned reference. No threshold/pin changes.

**Regressions:** final measured probe **999/999**, including 576 cancellation
assertions across three modes, four bodies, six sizes and two minimum-rule
settings. Exact final probe against isolated pre-fix production source reports
**999 assertions / 396 failures**. The focused existing AUnit accent case passes
with ten added unmeasured configurations, including grouped/color/accent/smash,
empty and script-style bodies. An intermediate unit failure was a test scoping
error: the unbraced two-glyph style baseline scaled only the first glyph; grouping
the baseline fixes the fixture, not production behavior. Logs are retained.

Final-source verification:

- Incremental root/test development builds pass; generated profiles select
  development. Existing warnings remain; no clean/release qualification.
- Full Xvfb suite **1074/1074**, zero failed assertions/unexpected errors,
  cumulative **146.300164 s**. Geometry unchanged **235/235** across 13 groups.
- Unchanged preceding expanded image corpus improves **51/53 → 53/53**; both
  previously recorded dot-cancel-T failures pass. Original pilot **29/29**.
- Supplemental `cancel-geometry-manifest.json` preserves all preceding 53 cases
  verbatim, adds 24 surrounded/nested cases and 18 isolated cases. Intermediate
  77-case corpus passes **77/77** twice. Final **95-case** corpus improves
  **51 pass / 44 fail → 89 pass / 6 fail**, zero blocked, and repeats **89/95**.
  No passing baseline case regresses; 38 failed cases become passing. Negative
  omitted-base/origin/baseline controls remain passing; thresholds unchanged.
- Required GTK interactions **9/9**, interaction-runner containment self-test
  and offline Plain/RPC HTTP-timeout lifecycle checks pass. Intentional runner
  kill/timeout fixtures are not application failures. No live-provider checks.

**Six retained failures:** isolated single-T cancellation, all three diagonals
at 24/48 px. These exact cases fail before correction too (width plus mask);
corrected dimensions/baselines/origins/colors pass, but masks still fail.
Read-only PNG review localizes unmatched browser pixels above the native logical
origin (7/25 pixels per single diagonal, 14/50 for cross cancellation, at 24/48
px). Native `Math_Raster.Paint` retains right/bottom overflow only and cannot
shift origin for top/left ink; the cancellation viewport extends 0.2 em upward.
This supports top clipping as a contributor, not proof that clipping is the
only cause. Aggregate masks do not establish component attribution; rounding
and subpixel effects remain possible. Keep all six failures in the corpus.
Origin-aware raster/export/jobs/GTK adoption is separate corrective work; do
not inflate logical ascent or crop the reference to hide this limitation.

**Evidence:** `plan/evidence/native-math-2026-11-10-cancel/` retains baseline/final/
repeat reports and PNGs, original pilot, measured before/after, unit/build/full/
geometry/lifecycle logs, direct DOM measurements and reproduction script,
implementation patch, source/font/executable hashes and checksums. Earlier
53/77-case report/log checkpoints are retained separately from the final corpus.
Read-only review found no implementation blockers and prompted inside-accent
image coverage; separate diagnostic review identified the upper-ink mismatch.
Developer/agent review is not independent acceptance.

**Disposition:** scoped cancellation geometry defects corrected; full raster
cancellation parity remains open. PCR-125 OPEN; feature **NOT COMPLETE**.
Whole-job allocation, hard deadlines, inline GTK/cache, fallback-font pins,
callable comparisons, native lifecycle/Valgrind failure and independent visual/
AT acceptance remain open. Valgrind/resources not rerun. Approved SRS-MATH v1.0
and D01–D15 unchanged; no release, installation or commit.


### 11.10 Fresh continuation — origin-aware retained rasters, 2026-11-10

**Scope:** preserve leading path/rule/reference-glyph ink through full/tile
rasterization, worker publication, GTK adoption and inline Pixbuf painting,
without changing mathematical layout metrics. `Math_Raster.Measure` computes
conservative clipped bounds, integer leading padding and trailing extents.
Image origins locate logical top-left inside the pixel canvas; tile origins
are signed relative to tile pixel zero. Tiles index the padded full raster.
Full 8192×4096 and tile 256×256 caps still apply; leading and trailing extents
count together. Existing shadow reservations are preserved with additional
leading glyph-metric/blur bounds. Input validation precedes scaled arithmetic.

Worker results expose origins and a raster-local baseline, and charge the
actual stride×height. GTK keeps logical width separate from physical paint
extent, reserves full raster bounds plus existing padding, and includes leading
Y in its baseline. Centered placement preserves the logical center where the
allocation permits, clamping the raster inside it. Fleqn drawing-area margin
compensates leading X while fallback keeps its full two-em margin; compensation
clamps at the parent boundary. Inline painting uses the same measured bounds
and baseline, but **still runs on GTK**. Larger retained rasters are charged by
the existing ledger; this is not aggregate memory or GTK-slice qualification.

**Oracle correction:** the prior browser fixture positioned formulas at viewport
X=0, so screenshots lost negative-X reference ink. The first origin-aware run
passes the six single-T cases but reports **83/95**, exposing 12 isolated
compound/accent cases whose newly retained native left ink had no reference
pixels. The checker now uses a fixed **32 px horizontal browser margin**, the
same for every formula, not selected from native dimensions or foreground.
It retains the fixed 12 px crop padding and fails crops outside the screenshot;
logical dimensions/origins remain DOM-derived. Native origin metadata drives
union-canvas placement, never foreground fitting. Native/browser raster padding
need not match. Added consistent native-origin displacement and inconsistent
metadata negative controls, retaining prior browser-origin, baseline and
omitted-base controls. No threshold, pin, source case or logical metric changed.

**Comparable image results:** with the corrected oracle, the preserved pre-fix
exporter is **77 pass / 18 fail / 0 blocked**, not the older clipped-oracle
89/95. Final exporter and exact-source repeat are **95/95** each. All 18 isolated
cancellation cases now pass. Original unchanged pilot **29/29**. Historical
89/95 and the intermediate 83/95 remain archived, not rewritten or discarded.
The 95-case manifest is unchanged. Aggregate masks still do not qualify semantic
component mapping or the complete reference domain.

Final-source developer verification:

- Incremental root/test **development** builds pass; profiles select development.
  Existing warnings remain; no release or clean/warning-free qualification.
- Full Xvfb suite **1074/1074**, zero failed assertions/unexpected errors,
  cumulative **147.547471 s**. Earlier intermediate candidate passes at
  146.624884 s and 146.300164 s are distinct snapshots, not substituted for this
  final run or reconciliation of historical failed repeats.
- Raster probe **1108/1108**; worker probe **162/162**, including independent
  measured cancellation origins/baselines and actual retained-byte release.
  Its 2000/2000 warm requests and queue saturation checks are scoped headless
  characterization, not queue-inclusive deadlines or whole-job memory proof.
- Geometry unchanged **235/235** across 13 groups. Added full/tile pixel equality,
  signed tile origins, leading ink, clipping, unchanged layout metrics and exact
  combined dimension-cap tests. Old synthetic zero-ascent glyph boundary fixtures
  legitimately gained leading ink; explicit nonzero rule fixtures now isolate
  fractional rounding, with separate shadow/leading overflow cap checks retained.
- Existing registered GUI core/Fleqn cases each pass with added actual display
  and inline leading-ink snapshots, physical sizing, baseline and logical-anchor
  checks. Registration count remains unchanged. An intermediate snapshot failed
  because GTK allocation was pending; final tests pump a bounded monotonic settle,
  assert allocation and snapshot actual widget dimensions. Earlier test compile/
  scope errors and failed snapshot logs are retained as intermediate evidence.
- Required GTK interactions **9/9**, interaction-runner containment self-test and
  offline Plain/RPC HTTP-timeout lifecycle checks pass. Intentional kill/timeout
  self-test fixtures are not application failures. No live-provider checks.

**Evidence:** `plan/evidence/native-math-2026-11-10-raster-origin/` retains same-
oracle baseline/final/repeat/original PNGs and reports, initial clipped-oracle
report, exact-source probe/build/full/geometry/post-build logs, implementation
patch and source/font/executable hashes/checksums. Read-only review prompted
Fleqn logical-anchor compensation; final review found no concrete blocker.
Developer and agent review are not independent human acceptance.

**Limits and disposition:** scoped negative-origin retention and the 18 isolated
cancellation image cases are corrected. Bounds use reference glyph metrics,
not exact native bearings; shaped-run ink, fallback-font pins and complete font
coverage remain unqualified. Curve control hulls are conservative, not minimal
ink bounds. Fixed browser crop padding is not proof of complete overflow for
arbitrary formulas. Parent/viewport clipping still applies. Inline worker
painting, complete display tiling/cache scheduling, whole-job 256 MiB and all
process cache lifetimes, hard deadlines/GTK slices, callable gaps, native
lifecycle/Valgrind and independent visual/AT acceptance remain open. Valgrind/
resource characterization not rerun. SRS-MATH v1.0 and D01–D15 unchanged;
PCR-125 OPEN and feature **NOT COMPLETE**. No release, installation or commit.


### 11.11 Fresh continuation — worker-backed inline rasterization, 2026-11-15

**Scope and authority:** User authorized the next increment. This implements
inline worker rasterization under existing PCR-125/P5, not the separate whole-
job memory/deadline increment. SRS-MATH v1.0 and D01–D15 are unchanged; no extra
context caps or production browser runtime are authorized.

**Implementation:** Rich_Text now submits text-style raster jobs with trusted
bundled-font directory and GTK-captured font pixel-em/foreground. Font reflow
abandons obsolete jobs and partial adoption, reveals original source and
submits a fresh request; view font sizing already encodes zoom. Parsed/layout
caches are no longer copied onto GTK for synchronous repaint. Queue-busy
requests retry through the existing fair timeout loop; over-limit source is
rejected without permanent retries. Request ID, generation, LaTeX, live marks
and original buffer text gate result adoption; source is rechecked before
commit. Stale paths remove old images and retain visible source.

Math_Element.Adopt_Inline borrows a retained worker result and copies at most
eight padded rows per call with a cooperative5ms target. It allocates a GTK
RGBA Pixbuf, separately leases actual rowstride×height, converts premultiplied
Cairo ARGB to straight RGBA, and initializes the two-pixel transparent border
incrementally. Worker and Pixbuf leases overlap during adoption. Clear, reflow,
source mutation, replacement and view destruction discard partial images and
release results. Pixbuf weak notification releases committed-image leases.
The legacy synchronous helpers remain for component callers/tests; production
Rich_Text no longer invokes them. GTK object allocation and buffer insertion
remain GTK-only. Cooperative per-row checks do not preempt native allocation
or guarantee any50ms GTK/250ms job bound.

Worker pixels preserve fractional-ascent drawing from Math_Raster, rather
than the legacy inline helper's ceiled-ascent paint position. Pango rise uses
the worker's raster-local ceiled baseline plus two padding pixels. Origins and
logical layout metrics are preserved; this is not bit identity with legacy
inline images or full font/baseline qualification.

**Exact-final developer verification:**

- Root/test incremental development builds pass; both profiles select
  development. Existing compiler/style/theme warnings remain; no release,
  warning-free or clean-build qualification.
- Full Xvfb suite **1076/1076**, zero failed assertions/unexpected errors,
  **148.864532s** cumulative, **149.03s** wall. Initial snapshot1076/1076 also
  passed before strengthened tests; this does not reconcile historical repeats.
- Worker probe **170 assertions, zero failures**, including direct measured
  text-style cancellation pixel/origin/baseline comparisons, explicit color
  rendering and retained-byte release. The 2000 warm requests and queue
  saturation remain scoped headless characterization only.
- Two new registered conversation cases test partial/full Pixbuf adoption,
  exact alpha/transparent padding, dimensions/baseline, overlapping leases,
  capacity rejection, injected pre-weak-ref-registration failure, discard and
  release. Independent GDK surface conversion is compared at RGB±1 for integer
  unpremultiplication rounding, exact alpha; browser thresholds are unchanged.
  Production tests observe lease overlap before commit, mutate source, replace,
  destroy and recover baseline;12 formulas exceed the8-slot queue before GTK
  polling and all12 commit after retries. Existing copy/reflow tests check the
  synchronous-render counter stays unchanged; direct legacy control increments
  it. Baseline expectations use measured layout/bounds, not legacy Pixbufs.
  Line-boundary testing waits for each asynchronous reflow before hit tests.
  Conversation registration is57; registration alone is not qualification.
- Required GTK interactions **9/9**, runner crash/timeout containment self-test
  and offline Plain/RPC HTTP-timeout lifecycle checks pass. Runner's intentional
  killed/timed-out fixtures are not production failures. No live providers.

**Evidence:** `plan/evidence/native-math-2026-11-15-inline-worker/` retains
exact-final and initial build/full/focused/post-build logs, probe source/build
logs, implementation patch, source/font/executable hashes and environment
manifest. Initial compile failures (GtkAda buffer conversion/declaration order,
test visibility), unmatched test filters and intermediate test changes remain
recorded. Read-only review prompted permanent-Busy and stale-image corrections;
final review found no concrete blocker. Developer/agent review is not independent
visual/assistive-technology or user acceptance.

**Not rerun / remaining gates:** Browser image pilot/expanded corpus, geometry,
standalone raster, resources and Valgrind were not rerun for this increment;
§11.10 image95/95, geometry235/235 and raster1108/1108 remain historical scoped
evidence, not fresh outcomes. Inline worker implementation is no longer open,
but complete tiling/cache/repaint reuse, whole-job256MiB enforcement, all process
cache lifetimes, queue-inclusive hard deadlines, warm p95 and GTK timing
qualification remain open. Fallback pins, native bearings/shaped ink, parent
clipping,60 callable gaps, full corpus/component mappings, native-library
lifecycle and independent desktop/AT/user acceptance remain open. Native calls
are not preemptible. No full parity, resource qualification, release,
installation or commit. PCR-125 remains OPEN; feature **NOT COMPLETE**.


### 11.12 Fresh continuation — retained worker-output admission, 2026-11-15

**Scope/authority:** User requested the next increment under existing PCR-125.
This bounded resource slice reserves retained worker ARGB32 output before
rendering, rather than allocating first and rejecting retention afterward.
It does not implement whole-job256MiB accounting, introduce a new cap, or
change approved SRS-MATH v1.0/D01–D15.

**Implementation:** Worker measures padded bounds and uses an overflow-safe
width×4×height capacity check before acquiring its existing64MiB ledger lease.
Only accepted requests call Render. Actual stride×height reconciles the lease.
Failed/cancelled/expired worker outcomes free pixel vector capacity and reset
metadata before releasing the lease and publishing diagnostics. Ready results
that lose a deadline/cancellation race at protected publication are discarded
outside that protected operation. `Math_Raster.Clear` moves an empty vector
and finalizes the old capacity, resets dimensions/origins, and is idempotent;
normal result disposal also clears pixels before releasing the charge.

**Developer verification:**

- Root/test incremental development builds pass; both generated profiles select
  development. Existing warnings remain; no release/clean-build qualification.
- Worker probe **193/193**, repeated **193/193**. Added23 assertions cover
  one-byte-short rejection, exact-fit success at capacity, full-ledger rejection,
  no pixels/lease on rejected published results, oversized post-reservation
  raster failure cleanup and successful recovery. The exact new probe against
  pre-change production reports193 assertions with2 failures: rejected results
  exposed pixels. That baseline is retained. Existing queue/lifecycle/pixel
  tests and2000 warm requests pass; timing is characterization, not qualification.
- Full Xvfb suite **1076/1076**, zero failures/unexpected errors,
  **144.235750s** cumulative,144.27s wall. Existing inline-adoption and lifecycle
  cases remain unchanged; no new GUI registration.
- Standalone raster assertions **1108/1108**, also1108/1108 under Valgrind.
  The encompassing `check-math-raster.sh` **FAILS** because Valgrind reports
  **2 error contexts**,6,656 definitely lost,2,183 indirectly lost and26 possibly
  lost bytes. Traces include Pango/Fontconfig initialization; totals match the
  earlier record, but this does not prove all ownership/leak causes or waive
  the lifecycle gate. No suppression or threshold change was made.
- Required GTK interactions **9/9**, containment self-test and offline Plain/RPC
  HTTP-timeout lifecycle checks pass. Intentional killed/timed-out containment
  fixtures are not production failures. Source crosswalk refresh/check passes;
  coverage remains source evidence, not semantic qualification.

**Evidence:** `plan/evidence/native-math-2026-11-15-raster-admission/` retains
baseline/final/repeat probes, builds, full/post-build/raster-Valgrind logs,
implementation patch, source/font/executable hashes and manifest. Read-only
review found no scoped blocker. Publication-race cleanup and exceptions after
pixel allocation lack new deterministic fault-injection tests; existing
lifecycle cases are adjacent coverage, not direct race proof. Developer/agent
self-evaluation is not independent human acceptance.

**Open gates:** Cairo surfaces, return-value/deep copies, vector allocator
metadata and parser/layout/semantic/font/native temporaries are not whole-job
accounted. Direct standalone Render remains unleased. The existing retained
ledger is not a complete process-cache policy. No aggregate256MiB, hard250ms,
GTK50ms, warm-p95 or all-cache-lifetimes qualification is established. Browser
images/geometry and isolated resource characterization were not rerun; prior
results remain historical. Tiling/repaint reuse, font pins/bearings/shaped ink,
parent clipping,60 callable gaps, full corpus, native lifecycle and independent
visual/AT/user acceptance remain open. PCR-125 OPEN; feature **NOT COMPLETE**.
No release, installation or commit.


### 11.13 Fresh continuation — raster workspace reservations, 2026-11-15

**Scope/authority:** User requested implementation after the remaining-work
review. This is the first transient-memory accounting increment under PCR-125,
REQ-MATH-010 / MATH-LIMIT-002, not closure of whole-job256MiB enforcement.
SRS-MATH v1.0 and D01–D15 are unchanged; no additional context caps.

**Implementation:** New `Math_Memory_Budget` has independent protected ledgers,
default256MiB, and limited controlled reservations. Admission/resize arithmetic
uses remaining capacity, rejected resize preserves ownership, and finalization
releases charges. Account lifetime must exceed reservation lifetime; concurrent
operations require independent reservations. Full/tile raster painting reserves
Cairo image plus output-vector bytes before surface allocation, validates
ARGB32 stride and reconciles actual vector capacity. GNAT empty-vector
Reserve_Capacity allocates requested capacity in inspected runtime versions;
post-allocation reconciliation is not portable preadmission of arbitrary
allocator rounding/metadata. `Render_Into` clears prior output and directly
fills worker-owned images, removing the worker's function-result assignment
copy. Failed/cancelled/expired renders clear partial output before scope-exit
release. Worker results report scoped raster-workspace peak bytes separately
from the retained-output lease.

**Developer verification:**

- Root/test incremental development builds pass; generated profiles select
  development. Existing warnings remain; no release/clean-build qualification.
- Final-binary full Xvfb suite1076/1076, zero failed assertions/unexpected
  errors,148.559544s cumulative,148.66s wall. Earlier full1076/1076 passed
 149.597846s cumulative before final comment/test-only updates.
- Memory ledger probe30/30: zero/exact/overflow/rejected resize, shrink/grow,
  independent ledgers, concurrent overlap, rebind rejection and exception
  finalization. This uses logical charges without allocating256MiB buffers.
- Worker194/194, repeated194/194. Existing2000 warm requests and saturation
  pass; scoped peak equals overlapping surface/output bytes in the added check.
  Warm timing remains headless characterization, not hard/GTK qualification.
- Raster1116/1116 normally and1116/1116 under Valgrind. Eight added assertions
  cover exact-fit/one-byte-short workspace, existing charge overlap, recovery,
  unloaded-font drawing failure, cancellation/deadline after pixel-vector
  allocation, and tile-sized workspace. Pixel hash unchanged for scoped control.
  Encompassing raster script FAILS: Valgrind2 contexts,6656 definitely lost,
  2183 indirectly lost,26 possibly lost bytes in native Pango/Fontconfig paths.
  No suppressions or thresholds changed; native lifecycle gate remains OPEN.
- Required GTK interactions9/9, abnormal-exit/timeout containment self-test and
  offline Plain/RPC HTTP lifecycle pass. Intentional containment fixtures are
  not production failures. Coverage refresh/check is source evidence only.

**Evidence:** `plan/evidence/native-math-2026-11-15-workspace-budget/` retains
build/full/focused/post-build logs, patches, source/font/executable hashes and
manifest. Initial missing Count_Type operator visibility compile error retained;
corrected before passing builds. Read-only review found no scoped blocker;
review explicitly checked GNAT capacity behavior and post-allocation polling.
Developer/agent self-review is not independent human acceptance.

**Limits/open gates:** Workspace reservations end at render-call completion;
returned images and caller copies are not covered beyond that point. Retained
worker output remains separately leased. Parser/token/layout/semantic data,
font/native drawing internals, allocator metadata and complete copy/cache
lifetimes are not accounted. This is neither whole-job256MiB enforcement nor
a process RSS bound. Hard250ms, GTK50ms, warm-p95, complete tiling/repaint reuse,
font pins/bearings/shaped ink, parent clipping,60 callable gaps/full corpus,
native lifecycle and independent visual/AT/user acceptance remain open.
Browser/geometry/resource characterization not rerun; prior scoped evidence
remains historical. PCR-125 OPEN; feature NOT COMPLETE. No release/install/commit.


### 11.14 Fresh continuation — parser-vector reservations, 2026-11-15

**Scope/authority:** User requested the next engineering priority after §11.13.
This extends REQ-MATH-010 / MATH-LIMIT-002 accounting to parser-owned source
maps and lexical vector payloads. Approved SRS-MATH v1.0 and D01–D15 are
unchanged. This is not closure of whole-job256MiB enforcement.

**Implementation:** All four Math_Syntax.Parse overloads accept a borrowed
optional Memory account; null selects an independent default ledger. Before
source validation, reserve two byte/UTF16 offset-vector payload arrays. Before
lexing, reserve the copied original maps plus three overlapping raw/expanded/
mark-work token-record arrays. Input-derived capacities are preallocated;
actual surviving capacities reconcile at phase return. Raw tokens are borrowed
instead of copied, and expanded output moves into the result. Reservations
outlive validated-source/token locals and release after those locals finalize,
including error/cancellation/deadline unwinding. Strings/lexemes are not charged.
The eight-times-input-bytes bound (clamped to the existing token cap) covers
current decomposition/script/accent expansion; direct probes check214 nonempty
decomposition entries through U+03FF plus targeted two-mark/combining/script
fixtures. This is scoped table evidence, not full semantic parity.

Workers use one per-job ledger across parser and raster measurement windows.
Reset_Peak preserves current charges and resets maximum to current usage;
callers serialize measurement windows. Results expose parser-vector and
pipeline peaks separately from the unchanged raster-only peak. The pipeline
peak is the maximum of the two sequential scoped peaks, not a sum or total-job
measurement. A review found later font-load exceptions overwrote saved parser
telemetry after reset; all three exception handlers now preserve its maximum.

**Developer verification:**

- Final root/test incremental development builds pass; generated profiles select
  development. Existing compiler/style/theme warnings remain; no release or
  warning-free qualification. Final full Xvfb suite1076/1076, zero failed
  assertions/unexpected errors,148.051229s cumulative,148.10s wall. Earlier
  full1076/1076 is retained separately; an incorrect-cwd invocation ran no tests.
- Parser probe674/674 twice, including measured exact/one-byte-short and held
  charge overlap/recovery, invalid UTF8/lexical/syntax exits, lexical cancellation
  after allocation, deadline propagation, multibyte/max-source inputs, and direct
  count/capacity checks for214 decompositions and3 targeted fixtures. Small
  representative input peak29580 bytes; this is conservative charged capacity,
  not allocator/RSS usage. Macro test rejects before parsing; post-group budget
  rejection rollback is not directly injected.
- Ledger38/38 includes reset with active charges, zero/reset/resize/rejection and
  independent ledgers, alongside existing concurrency/finalization checks.
- Worker215/215 three corrected runs plus final repeat. The same extended probe
  against unfixed peak handling gives215 assertions with1 failure on the
  font-load telemetry assertion. Existing2000 warm requests and saturation pass;
  timing remains headless characterization, not hard/GTK qualification.
- Raster1116/1116 normally and under Valgrind. Encompassing raster script FAILS:
  2 contexts,6656 definitely lost,2183 indirectly lost,26 possibly lost bytes;
  native Fontconfig/Pango paths. No suppressions or threshold changes.
- Required GTK interactions9/9, containment self-test and offline Plain/RPC HTTP
  lifecycle pass. The containment harness intentionally kills/times out child
  fixtures; its synthetic7/9 result is expected, not a product failure.
  Source crosswalk refresh/check passes; mapping is not semantic qualification.

**Native lifecycle diagnostic:** An isolated18-run baseline/measure/draw matrix
uses counts1/10/100 with/without explicit test-only Cairo/Fontconfig teardown.
All6 no-shaping baselines have zero losses. All6 shaped runs without teardown
retain6656 definite/2183 indirect bytes, with378 or730 possible bytes. All6
shaped runs with teardown reduce definite/indirect losses to0 but retain26 or378
possible bytes. All12 shaped runs therefore FAIL strict Valgrind. Variable
possible-loss totals include native thread/language initialization contexts;
fixed definite/indirect totals across counts are not proof that all lifecycle
causes are harmless. Global cleanup occurs only in an isolated test executable
once Cairo/Pango owners are gone; it is not safe per-job production cleanup and
has not been added there. The production raster gate remains unchanged/open.

**Evidence/evaluation:**
`plan/evidence/native-math-2026-11-15-parser-budget/` retains build/full/focused/
post-build logs, lifecycle full stacks and CSV, changes, hashes and manifest.
Read-only review caught the telemetry defect; re-review found no scoped blocker.
Developer/agent self-review is not independent human acceptance. Intermediate
compile visibility errors and overly conservative transformation-array sizing
were corrected before final probes; available intermediate logs are retained.

**Open gates:** Charges cover vector record-array payload capacities and raster
workspace only, and end at the corresponding parser/render call. GNAT requested
Reserve_Capacity behavior is inspected/tested, not portable preadmission of
arbitrary allocator over-allocation. Unbounded strings, token lexemes, expander/
AST/semantic/layout storage, native/font temporaries, allocator metadata and
complete returned-copy/cache lifetimes remain unaccounted. Whole-job256MiB,
process-cache/RSS, hard250ms, GTK50ms, warm-p95, complete tiling/repaint reuse,
font pins/bearings/shaped ink, parent clipping,60 callable gaps/full corpus,
native lifecycle and independent desktop/AT/user acceptance remain OPEN.
Browser/geometry/isolated-resource characterization was not rerun; prior scoped
results remain historical. PCR-125 OPEN; feature NOT COMPLETE. No release,
installation or commit.


### 11.15 Fresh continuation — AST construction reservations, 2026-11-15

**Scope/authority:** User requested continued LaTeX-math work under existing
PCR-125. This advances REQ-MATH-010 / MATH-LIMIT-002 accounting to parser AST
node record-array construction capacity. SRS-MATH v1.0 and D01–D15 are unchanged.
This does not close the whole-job256MiB gate.

**Implementation:** The single node append site pre-admits old plus requested
new array capacity before growth: initial32 records, doubling to the existing
32768-node cap. Actual surviving capacity reconciles after Reserve_Capacity.
Checked byte arithmetic uses node record size and storage unit. GNAT15.2 realizes
requested capacity in the inspected implementation; arbitrary over-allocation,
allocator metadata and nested controlled payloads are not pre-admitted. Polls
before append and after growth remain cooperative, not preemptive.

The reservation owner precedes Parser_State and source/token locals, so charges
outlive cleanup. Every return transfers nonempty node and diagnostic vectors,
avoiding the parser-local node-vector copy. Empty cleared failure capacity stays
with State and is freed before charge release, not retained by invalid documents.
Returned AST storage, wrapper/caller assignment copies and nested node strings/
array-rule vectors remain outside the charge after Parse returns. Existing
worker parser/pipeline peaks include AST construction without a worker-body
change. Pipeline peak remains the maximum of parser and raster windows, not a
whole-job total.

**Developer verification:**

- Root/test incremental development builds pass; generated profiles select
  development. Existing warnings remain; no release/clean-build qualification.
- Exact-final full Xvfb1076/1076, zero failed assertions/unexpected errors,
  145.992924s cumulative,146.26s wall. Pre-final full1076/1076 passes at
  145.382510s cumulative,145.50s wall before empty-failure cleanup correction.
- Parser688/688 repeated and exact-final, also688/688 under Valgrind:0 errors,
  0 definite/indirect/possible losses;113248 bytes reachable. This executable
  does not exercise Pango or whole-application cleanup. The macro fixture
  produces2049 nodes/2048 glyphs, charged peak2443968 bytes matching source/token
  baseline plus2048+4096 overlapping node records. Exact/one-short/held-charge
  tests cover admission/reuse; AST-stage cancel/deadline, post-mutation local
  rollback/Global_Group persistence, invalid/empty returns and AST usability pass.
- Current688-check probe against isolated HEAD syntax builds successfully and
  reports5 expected AST-specific failures; baseline lexical peak250560 bytes.
  Measured exact/short controls alone are not detectors because they derive
  thresholds from the implementation; independent overlap/phase checks detect it.
- Worker223/223, repeated exact-final223/223. Eight added checks compare a
  nonraster macro-expanded job peak with direct parsing, validate retained AST
  and parse-only pipeline, and verify no raster charge. Existing2000 warm
  requests/saturation pass; headless timing is not qualification. Ledger38/38.
- Raster1116/1116 normal and under Valgrind, but strict script FAILS:2 contexts,
  6656 definite/2183 indirect/26 possible lost bytes in native Fontconfig/Pango
  paths. No suppression, threshold change or production-global teardown.
- Required GTK9/9, containment self-test and offline Plain/RPC HTTP lifecycle
  pass after final builds. Containment intentionally produces synthetic7/9
  before its successful self-evaluation. Crosswalk refresh/check passes; this is
  source evidence, not semantic qualification.
- Geometry invocation BLOCKED before cases execute: default KaTeX package
  /tmp/coyote-katex-support-check/package is absent. Browser images, isolated
  resources and shaping lifecycle matrix were not rerun; prior results remain
  historical.

**Evidence/evaluation:** `plan/evidence/native-math-2026-11-15-ast-budget/`
retains builds/probes, isolated HEAD baseline, full suite, Valgrind, post-build
checks, patch, source/font/executable hashes and reviews. Initial accessibility
compile rejection and test-setting mistakes are retained as intermediate logs.
Read-only final review found no scoped blocker. Developer/agent evaluation is
not independent human acceptance. Formula tests intentionally depend on this
growth policy and GNAT capacity behavior; allocator failures, move/finalization
exceptions and all nested AST kinds are not fault-injected/exhaustively covered.

**Open gates:** Expander storage, strings/lexemes, nested AST payloads,
semantics/layout/native/font temporaries, allocator metadata, full return-copy
and retained cache lifetimes remain unaccounted. Charges end at Parse/render
return; this is not aggregate256MiB or RSS enforcement. Hard250ms, GTK50ms,
warm-p95, complete tiling/repaint reuse, font pins/bearings/shaped ink, parent
clipping,60 callable gaps/full corpus, native lifecycle and independent desktop/
AT/user acceptance remain OPEN. PCR-125 OPEN; feature NOT COMPLETE. No release,
installation or commit.


### 11.16 Fresh continuation — array-rule construction reservations, 2026-11-15

**Scope/authority:** User-requested continuation under PCR-125, advancing
REQ-MATH-010 / MATH-LIMIT-002 scoped accounting. SRS-MATH v1.0 and D01–D15
unchanged; no new units or semantic rule-count limits.

**Implementation:** A Parse-local controlled reservation preceding State
aggregates surviving horizontal-rule vector capacities across arrays. Growth
pre-admits aggregate plus requested replacement capacity (seed4, doubling),
then reconciles actual capacity. Checked arithmetic and cooperative polls
bracket growth. Scoped node references avoid copied-node link mutations and
end before polls/outer mutation. Review caught first-row linking compacting
nested vectors while spare capacity remained charged; in-place links fix it.
Outer node growth recomputes surviving rule capacities. GNAT15.2 vector
semantics are inspected, not portable allocator guarantees. Temporary nested
copies during outer node growth are excluded. Charges end at Parse return,
not retained-document/copy lifetime; worker body is unchanged.

**Exact-final developer verification:**

- Root/test incremental development builds pass; both generated profiles select
  development. Existing warnings remain; no release/clean-build qualification.
- Full Xvfb1076/1076, zero failures/errors,142.388395s cumulative,142.48s wall
  (`full-exact.log`). Earlier full logs are intermediate checkpoints.
- Parser706/706 twice and under strict Valgrind: zero errors/lost bytes,
  113248 bytes reachable. Not a native-shaping or full-app lifecycle test.
  Independent live-charge observations cover4/12/8/24/16 slots across first-row
  linking/regrowth and multi-array overlap. Cancellation/deadline fire at rule
  overlap; malformed-suffix cleanup and returned kinds/boundaries pass. Drift
  and outer-growth fixtures have measured exact/short/held/reuse controls;
  measured thresholds alone are not independent detectors. Unchanged2049-node
  macro fixture peak2443968 bytes.
- Final706-check probe against isolated HEAD builds then fails4 rule-specific
  assertions. Isolated final-source mutation reverting only first-row linking
  to copy/Replace_Element fails exactly1 live-charge assertion. This is a
  reconstructed defect control, not an exact historical snapshot. Historical
  prefix695/1-failure evidence is separately retained.
- Worker223/223; ledger38/38. Warm2000 requests/saturation are characterization,
  not hard/GTK timing qualification.
- Geometry235/235 passes using restored test-only KaTeX0.16.22 (writable npm
  cache after default EROFS). This supersedes §11.15's missing-package block
  for this run only. Browser images/resource characterization were not rerun.
- Raster1116/1116 normally/Valgrind, but strict script FAILS:2 contexts,
  6656 definite/2183 indirect/26 possible lost bytes in Fontconfig/Pango.
  No suppression, threshold change or production-global teardown.
- Required post-build GTK9/9, containment self-test and offline Plain/RPC HTTP
  lifecycle pass. Deliberate containment7/9 is a synthetic child result, not a
  clean interaction run or product failure. Source crosswalk refreshed/checks;
  only hashes changed, not coverage counts.

**Lifecycle diagnostic:** Copied-source A/B adds PangoFC map shutdown after
layout/context unref and before map unref. Control and variant retain fixed
6656/2183-byte losses at measure/draw1/10/100; metric hashes match. Possible
losses vary; one control has additional losses, explicitly retained. All strict
runs fail. Per-map shutdown does not establish a fix. FcFini is process-global
and requires all GTK/Pango clients quiescent; it is not safe per-job cleanup.
No production change follows and losses are not declared harmless.

**Evidence/evaluation:**
`plan/evidence/native-math-2026-11-15-array-rule-budget/` retains exact-final
logs, intermediate tests, comparisons, lifecycle A/B, patch and hashes.
Nondetecting initial tests, proposed arbitrary limit and capacity drift were
corrected. Final source removes introduced unused local; read-only review is
pre-polish. Developer/agent self-evaluation is not independent human acceptance.

**Open gates:** Scoped vector construction only, not whole-job256MiB/RSS.
Nested outer-growth copies, strings/lexemes, expander/semantic/layout/native/
font temporaries, allocator overhead and returned/cache lifetimes remain
unaccounted. Hard250ms, GTK50ms, warm-p95, tiling/repaint reuse, font pins/
bearings/shaped ink, parent clipping,60 callable gaps/full corpus, native
lifecycle and independent desktop/AT/user acceptance remain OPEN. PCR-125
OPEN; feature NOT COMPLETE. No release, installation or commit.


**Next design gate:** Retained ownership assessment identifies a dangling-account
hazard if call-borrowed Parse reservations escape into returned Documents.
`design/native-math-retained-budget-proposal.md` is a DRAFT, NOT APPROVED and
NOT IMPLEMENTED. It recommends stable per-job account ownership and explicit
retained clone/transfer leases while preserving the current Document API
initially. User design review is required before that ownership/API migration.
This is not a claim that all other scoped project work is technically blocked.


### 11.17 Fresh continuation — nested rule-copy admission, 2026-11-15

**Scope/authority:** User-requested continued work under PCR-125 and existing
REQ-MATH-010 / MATH-LIMIT-002 execution. SRS-MATH v1.0 and D01–D15 unchanged;
no new unit, API, semantic limit or retained ownership migration.

**Implementation:** Before outer node-vector `Reserve_Capacity`, `Add` charges
existing aggregate rule capacity plus the sum of active rule lengths. Active
GNAT15.2 `Vectors.Adjust` copies length, not spare capacity; old nested buffers
remain live until replacement finishes. Separate node-array admission still
covers old+new record arrays. A cooperative poll follows both admissions and
precedes allocation; post-growth scans reconcile live capacity. Both scans use
explicit, short-lived Constant_Reference objects, ending before polls/mutation.
This is implementation-specific logical payload accounting, not allocator/RSS
measurement. Actual-capacity reconciliation is not a portable pre-admission
guarantee for a different runtime that allocates beyond the requested capacity.

Initial review inferred that ordinary `for ... of` necessarily copied Node
values; final review explicitly withdraws that unsupported inference because
container indexing/reference aspects matter. Explicit references remove that
ambiguity. Current Add callers provide empty rule vectors; a future caller
passing populated rules would require accounting review of `Fresh := Item`.
Parse reservations still end at return, not returned-document lifetime.

**Exact-final developer verification:**

- Root/test incremental development builds pass with both generated profiles
  development; existing warnings remain. Not clean/release qualification.
- Full suite from `test/` passes1076/1076 with zero failed assertions/errors,
  cumulative145.197785s, wall145.30s (`full-final.log`). An earlier incorrect
  root-directory invocation produced955 successes,28 failed assertions and95
  unexpected errors from unresolved relative fixture paths; preserved in
  `full-wrong-cwd.log`, not discarded or reported as a pass.
- Parser719/719 twice and strict Valgrind719/719:0 errors/lost bytes,113248
  reachable. Macro fixture peak2443968 bytes unchanged. Final56-node fixture
  preserves solid boundary0 and dashed boundary1 in order through32-to64 node
  growth. Live ledger delta24586 versus rule-free24576 isolates10 extra bytes
  for two active rule records. This is ledger evidence, not an independent
  allocator oracle. Exact/short/held/reuse budget controls use measured peaks.
- Poll-preserving isolated mutation removes only the nested copy term and
  fails5 of719 checks: live charge detector, cancellation/deadline and both
  shared-scope stop checks. Earlier69c13ff comparison fails2 checks; earlier
  experimental fixture logs are intermediate, not all exact-final source.
  Paired cancellation/deadline inject two exception identities at one shared
  cleanup branch; they do not prove separate timing paths or hard deadlines.
- Worker223/223, ledger38/38, pinned test-only KaTeX0.16.22 geometry235/235.
  Warm2000 requests/saturation remain characterization, not timing acceptance.
- Raster1116/1116 normal and under Valgrind; strict raster script still FAILS
  with2 native contexts:6656 definite/2183 indirect/26 possible lost bytes.
  No suppressions, threshold changes or unsafe process-global teardown.
- Post-build GTK9/9, containment self-test and offline Plain/RPC HTTP lifecycle
  pass. Containment's deliberate synthetic7/9 child is not a clean GTK result.
  Source crosswalk generation/check passes; only source hashes changed.

**Evidence/evaluation:**
`plan/evidence/native-math-2026-11-15-rule-copy-budget/` retains builds, exact
full/focused results, incorrect-CWD failure, intermediate attempts, final
poll-preserving mutation source/project/logs, reviews and hashes. Subordinate
host-dated2026-11-18 paths/logs are preserved as recorded; this project record
uses2026-11-15. Final read-only review checks the actual GNAT15.2 runtime,
references, arithmetic, call sites and test limits; no scoped blocker found.
Developer/agent evaluation is not independent human acceptance.

**Open gates/next decision:** Other nested node payloads, strings/lexemes/
diagnostics, expander/semantics/layout/native/font storage, allocator overhead,
returned/cache lifetime and whole-job256MiB/RSS remain outside accounting.
Hard250ms, GTK50ms, warm-p95, tiling/repaint reuse, font pins/bearings/shaped
ink, parent clipping,60 callable gaps/full corpus, native lifecycle and
independent desktop/AT/user acceptance remain OPEN. Browser/resource probes
were not rerun. `design/native-math-retained-budget-proposal.md` remains DRAFT,
NOT APPROVED and NOT IMPLEMENTED; stable ownership/API migration awaits user
design review. Other scoped work is not claimed technically exhausted.
PCR-125 OPEN; feature NOT COMPLETE. No release, installation or commit.


### 11.18 Requirements correction — practical resource-abuse protection, 2026-11-15

**Authority:** The user clarified that exhaustive memory accounting has limited
benefit and explicitly authorized a requirements update to catch abusive and
pathological LaTeX. SRS-MATH v1.1 revises REQ-MATH-010 and §5 accordingly.

**Current acceptance scope:**256MiB is a coarse per-job admission budget for
tracked major workspace/output buffers and known large overlaps. Coverage,
estimates and exclusions must be documented, and major-buffer allocations
checked before admission. It is not a cap on all allocations or process RSS.
Verification targets recursive/explosive macros, token/output growth, nesting,
arrays/dimensions, costly layout, repetition, cancellation, cleanup, source
fallback and subsequent ordinary-request recovery. Unexplained growth, crashes,
hangs and state leakage remain defects to investigate, not exclusions to hide.

Structural/output limits,64MiB retained-raster process bound, warm-p95≤50ms,
job≤250ms and GTK-slice≤50ms targets remain unchanged. Cooperative native-call
limits are still unqualified. Ownership/lifetime safety remains mandatory.
Exhaustive per-string/native/allocator/retained-copy accounting and storage
pool/retained-account lease migrations are not prerequisites. The ownership
proposal is optional, not approved or implemented, and no longer the next gate.

**Supersession/evidence:** This scope replaces exhaustive-accounting open gates
in §11.17 and earlier dated checkpoints; those logs/results remain historical
facts, not retroactive passes. Existing native leaks remain failures. No runtime
source, tests, source crosswalk or evidence artifacts changed for this revision;
no builds, benchmarks or tests rerun. Plans, test descriptions, SRS-CORE annex
reference, design/SDF and agent guidance now point to the corrected scope.
Practical guard coverage/hostile-input recovery qualification, timing, native
lifecycle, fonts/full compatibility and independent desktop/AT/user acceptance
remain OPEN. Developer self-evaluation checks consistency/traceability, not
independent product acceptance. PCR-125 remains OPEN; no release/install/commit.


### 11.19 Practical abuse rejection and recovery — 2026-11-15

Under SRS-MATH v1.1, two existing standalone probes now exercise deterministic
rejection and subsequent ordinary work. No production source/API or requirement
changed. Evidence: `plan/evidence/native-math-2026-11-15-abuse-guards/README.md`.

Engine174/174 twice covers recursive expansion count, single-pass argument
duplication token growth, depth,65-row/column,AST-node,16385em and65537-byte
rejections, with exact64 row/column and moderate-depth valid controls. Rejections
check diagnostic category, invalid/no geometry, retained source (bounded prefix
for oversized source), scope restoration and same-context ordinary recovery.
Local macro rollback and prior global definition reuse are tested. Early
cancellation/deadline propagate distinctly; poll3 precedes macro mutation, so
unchanged scope is not post-mutation rollback evidence.

Worker279/279 twice adds synchronous invalid/nonfinite-scale rejection and
ordinary raster recovery, identical Busy-request retry after a cancelled slot,
and three repeated token-growth/column-limit rejection/raster-recovery cycles.
Invalid results retain exact source without pixels/retained charges. Binary64
fixtures are representation-gated; GNAT15.2 validity checks already reject
NaN/infinities. The audit hypothesis of a scale bypass was not reproduced.
Review removed a concurrent-raster ledger race and added short-circuit null
guards. Parser719/719 and ledger38/38 remain scoped major-buffer/reuse evidence,
not injected worker256MiB transient admission or all-input coverage.

Development root/test builds pass, profiles development; existing warnings
remain. First full1075/1076 has one unexpected fixed-port18881 bind error in
HTTP retry fixture, zero failed assertions. Focused1/1 and one full repeat
1076/1076 (149.023396s cumulative,149.203s elapsed) pass; initial failure remains
recorded, not waived or causally resolved. GTK9/9, runner containment and offline
HTTP lifecycle checks pass. Engine Valgrind174/174 with max-stackframe4194304
has zero errors/lost bytes,216713 reachable. Default threshold first failed
with a stack-switch warning for the existing2.6MiB semantic frame; both logs
retained, no suppressions/leak criteria changed. This does not rerun or resolve
strict raster native losses.

Open: wider combined/output/layout/exponential/fuzz cases, GTK visible fallback,
major-buffer coverage review, timing, cache/font/native lifecycle, full parity
and independent desktop/AT/user acceptance. Caller-created macro scope-stack
exhaustion is a separate unverified recovery candidate, not a source-only bypass.
No browser/geometry/image/raster qualification rerun; no release/install/commit.
Developer/agent review is not independent acceptance. PCR-125 remains OPEN.


### 11.20 Accepted memory-guard maintenance policy — 2026-11-15

The user accepted the proposal to stop extending fine-grained accounting,
retain working guards rather than remove them wholesale, and simplify specific
paths only when there is a concrete maintenance benefit. The port plan §6 is
the governing maintenance policy; SRS-MATH v1.1 remains unchanged.

Tiny nested array-rule charges and GNAT-specific exact-capacity/copy tests are
candidates for selective simplification, not scheduled removals. Preserve
ownership fixes (scoped references, reduced deep copies, valid borrows and safe
finalization), structural/expansion/work/dimension guards, coarse major-buffer
admission and known large overlaps, the 64 MiB retained-raster bound, and
cancellation/cleanup/source fallback/recovery. Conservative estimates suffice
for major-buffer admission; exact live-byte coverage is not the objective.

Any later simplification must record its benefit and retained protection, with
relevant boundary/rejection/cleanup/recovery regression evidence. Accounting-
specific tests can change with the mechanism; do not weaken safety tests merely
to obtain passes or erase historical evidence. Storage pools/retained-account
leases require demonstrated practical need; the optional proposal has no active
approval request and the user's acceptance does not approve that architecture.

This is a documentation-only decision, not an implementation removal or a new
runtime test result. Numerical budgets, timing targets, compatibility and
D01–D15 are unchanged. Known failures and open qualification gates remain;
developer documentation self-review is not independent product acceptance.
PCR-125 remains OPEN; no release/install/commit.


### 11.21 Scope admission and cancellable macro capture — 2026-11-15

This increment implements practical rejection/recovery, not more memory
accounting. `End_Group` clears `Scope_Limit` only after successful undo/pop;
`Unbalanced_Group` stays sticky. Parser entry and all nested pushes check scope
admission immediately, before empty-input success or further expansion. This
fixes empty Ready and gdef side effects after failed admission. Caller scopes
are preserved; Global_Group still skips the root push, and global definitions
executed before a later genuine parse error retain their specified effects.

`newcommand`/`renewcommand`/`providecommand` capture/copy loops now poll.
Replacement and optional-default token staging precede a final precommit poll,
so cancellation during staging cannot leave a partial new/replacement definition.
This does not make allocation exceptions transactional or preempt native calls.
No budgets, new shared-context admission caps or public signatures changed.

Final engine216/216 twice, macros873/873 twice, worker279/279, parser719/719;
root/test development builds pass, warnings remain. Full Xvfb1076/1076, zero
failures/errors,146.169067s cumulative/146.33s elapsed. GTK9/9, runner containment
and offline HTTP lifecycle pass. Engine Valgrind216 assertions has zero errors/
lost bytes,216713 reachable with documented4MiB frame classification threshold.
Whole-macro Valgrind was terminated by the180s outer batch during an existing
large-definition fixture before new cases; INCOMPLETE, not a pass. No raster/
image/browser/geometry/fuzz qualification rerun; prior native losses remain open.

Evidence:`plan/evidence/native-math-2026-11-15-scope-cancellation/`. Evolving
pre-fix probes record187/4 scope,189/2 entry,800/8 polling and857/2 default-copy
failures; macro counts include a failing final summary check. These are not
byte-identical final-probe baselines. An intermediate211/1 CD assertion wrongly
expected rollback of an already executed leading gdef; final tests distinguish
pre-admission failure from legitimate earlier assignment. Failed log preserved.
Read-only source review finds no blocking defect; developer/agent evaluation is
not independent acceptance. Prior scope-stack candidate is resolved within this
caller-created-stack domain, not claimed as a fresh-source nesting bypass.

Persistent global definitions across a shared context can accumulate tokens
across requests; no new aggregate cap selected. New cap/policy needs requirements
review; RD-CTX-01 remains unauthorized. Wider pathological/GUI/timing coverage,
font/native lifecycle/full compatibility and human acceptance remain OPEN.
PCR-125 OPEN; no release/install/commit.


### 11.22 Cancellable foreground-color application — 2026-11-15

The engine and worker duplicated unpolled command-coloring loops. Both now use
`Math_Layout.Apply_Foreground`, polling before each command including explicit
colors. Scoped mutable references avoid copying path/text payloads merely to
assign fallback color; no reference spans a poll or structural mutation.
Explicit colors and geometry/payload fields remain unchanged. Work is borrowed;
a stop may leave earlier commands colored, and no partial success is implied.
Engine exceptions propagate; worker status is authoritative and non-Valid jobs
clear raster output/lease. The Poll API now documents diagnostic non-null
results and mandatory release; both GUI consumers already gate adoption on Valid.

Final engine255/255 twice, worker300/300 twice; root/test development builds
pass with existing warnings. Exact-final full Xvfb1076/1076,zero failed
assertions/errors,147.932737s cumulative/148.15s elapsed. GTK9/9, runner
containment and offline HTTP lifecycle pass. Engine Valgrind255 assertions,
zero errors/lost bytes,216713 reachable with existing4MiB frame threshold.

Evidence:`plan/evidence/native-math-2026-11-15-foreground-poll/`. Evolving
pre-poll243-assertion probe fails9 assertions; it is not byte-identical final
baseline. Isolated mutation removes only the helper's command poll:exact final
255-assertion probe fails13 assertions,exit1. Direct helper tests establish
partial-stop boundary/reference release and payload preservation; facade tests
calibrate polls per source and distinguish cancel/deadline/recovery. Worker
integration repeats360-command mixed-color jobs, not deterministically injected
active-worker-phase cancellation. Source/binary hashes and validation before/
after hashes are retained; crosswalk counts unchanged.

No numerical caps, requirements or accounting coverage changed. No hard/native
preemption, all-geometry, representative timing, full GTK/fuzz/font/lifecycle/
parity or human acceptance is established. Browser/geometry/image/raster and
whole-macro Valgrind not rerun; existing raster loss failures remain open.
Developer/agent review is not independent acceptance; PCR-125 OPEN.
No release/install/commit.
