# Native math compatibility test plan and description

**Project:** coyote native math compatibility port
**Document:** Combined Test Plan (STP) and Test Description (STD), approved execution baseline

## Contents

1. Scope and status
2. References, configuration, and environment
3. Test plan and gates
4. Test description and execution conventions
5. Planned test cases
6. Requirements traceability
7. Risks, blockers, and review actions

**Version:** 0.5
**Date:** 2026-10-26
**Status:** Execution baseline updated from approved v0.4; readiness review and approval of this revision remain open
**Authority:** `requirements/native-math-compatibility.md` v1.0, approved 2026-10-24; D01–D15 are approved profile deviations. Native design v0.5 and project execution are approved; `plan/native-math-parity-plan.md` records phased status. This plan does not supersede requirements.
## 1. Scope and status

This document specifies planned cases, preconditions, expected results, procedures
and environments. It records current evidence and remaining work; it is not itself
a complete execution record or parity/acceptance claim. Approved SRS v1.0 remains
normative, including resource/performance targets. Design-proposed RD-CTX limits
and other unapproved admission/ownership/scheduling caps are not SRS limits;
visual thresholds remain provisional pending calibration.

The approved execution/design baseline is not pending approval. Test readiness,
complete scope, matching and qualification remain open. Current checks, failures,
blocked cases and coverage gaps are summarized in §2.2 and
`plan/native-math-parity-test-report.md`; missing inventory items do not become
passes. Full approved SRS scope is retained.
Levels: P1 exploratory baseline/harness readiness; increment-focused verification P2–P5; final component acceptance and integration qualification P6. Separate system acceptance testing is not applicable: this is a software component extension in coyote. Final acceptance includes manual GUI/accessibility protocol in §5. No independent human acceptance has occurred.

## 2. References, configuration, and environment

### 2.1 Governing and supporting references

- `requirements/native-math-compatibility.md` v1.0, approved 2026-10-24, especially §§3–6 and approved D01–D15 profile deviations.
- `plan/native-math-parity-plan.md` v0.5, increments P0–P6 and gates.
- `requirements/coyote-requirements.md` §3.1.4a, REQ-CORE-111/124; authoritative until approved change.
- `plan/native-math-test-report.md`, historical PCR-123 evidence and limitations.
- `plan/native-math-katex-0.16.22-inventory.md` and `.json`; registration census, not native coverage.
- `share/coyote/math/README.md`, supported profile and starting limits.
- `share/coyote/math/PROVENANCE.md`, pinned assets, licenses, hashes, regeneration procedure.
- Existing probe/test sources: `test/tools/math_probe.adb`, `test/tools/check-native-math.sh`, `test/tools/check-math-reference.cjs`, `test/tools/check-math-inventory.cjs`, `test/src/coyote_math_tests.adb`, `test/src/test_core_suite.adb`.

### 2.2 Reference/configuration control

Reference is KaTeX **0.16.22**, npm archive `https://registry.npmjs.org/katex/-/katex-0.16.22.tgz`, SHA-256 `e9e0d167db3175481cbadaff38e8d90b130f6a3ddb451a47e43c577fd511f365`. Pin `dist/katex.js` SHA-256 `8f1f4fb1080439c012bb8fddf424fa253e9144ab4cdd7dc0eae0e92cd04a5e33`; `src/fontMetricsData.js` SHA-256 `1e72fc6b451a565e60b1eb7e89f4738eb74f35edfcf3c9c273015700b42ae04d`; source/font hashes from generated inventory. The current inventory contains 60 font files across 20 faces; verify all bundled font hashes from `share/coyote/math/PROVENANCE.md` and retain MIT notices. Do not install npm packages. Reference/browser is development-only; production binary/dependency inspection must show no JavaScript/browser/KaTeX runtime.

Each qualification snapshot must record archive, bundle/config and corpus hashes; native revision; font hashes; OS/distribution; GNAT/Alire, Node, browser and Cairo/FreeType versions; browser engine/build, viewport/device scale, locale, color profile, display scale; seeds; commands; environment; output hashes. The final3 pilot has a verified 63-member browser asset manifest and identified Chromium version, but the report does not provide a complete frozen workstation/platform/toolchain manifest or broad qualification snapshot corpus. Freeze complete corpus and expected outputs before acceptance.

Current verified commands and report-backed evidence (full qualification outcomes are in `plan/native-math-parity-test-report.md`):

- `alr build --development`; `cd test && alr build --development --profiles=coyote=development`.
- Latest known full suite: 1061/1061 (82.378580 s) in `/tmp/coyote-completion-final2-full.log`, predating subsequent genfrac/mathchoice/color/minRule edits; full integration rerun required. It is regression evidence only. Geometry later passed 145/145 (`/tmp/coyote-fraction-final145-r8.log`), resolving seven prior failures. The frozen structured pilot passed 16/16 and image pilot 3/3 with negative controls; the separate geometry corpus uses em-unit ascent/depth checks. Only the structured path comparison uses normalized units. Full origins, widths and option effects remain unmeasured. No current color pass is claimed: latest candidate validation aborted; prior 40/41 default-color result preceded it. Resource test10 RSS 44,644 KiB is not whole-job memory; display64 is a ledger, not process-inline measurement. See report §8.
- Earlier 113-case geometry worker result (`/tmp/coyote-completion-113-final`) is historical; current geometry evidence is 145/145 as stated above and in report §8.
- Frozen structured and image pilots passed 16/16 and 3/3 with negative controls. Only the structured path comparison uses 0.01 normalized units, not em-unit origins. Full origins, widths and option effects remain unmeasured. The source crosswalk has been regenerated; it is not semantic qualification.
- Macro focused checks passed 499 cases (344 path, 157 semantic, 44 token cases); engine 31 cases; jobs 127 cases. A 2,000-request headless performance corpus measured p95 1 ms, max 1 ms, excluding GUI queueing and rasterization.
- The deterministic 10,000-case fuzz run reported 4,184 parse successes, 5,221 parse errors, 595 policy errors, zero layout failures and no nondeterminism (`/tmp/coyote-completion-final-fuzz.json`); memory was not measured.
- `test/tools/check-math-resources.cjs` via the recorded resource harness (10 isolated cases; not whole-GUI memory qualification).
- Browser/reference export: `test/tools/export-math-browser.cjs`, `test/tools/export-math-reference.cjs`; comparison: `test/tools/compare-math-layout.cjs`, `test/tools/check-math-differential.sh`; image checks: `test/tools/check-math-images.sh`; inventory/accessibility: `test/tools/check-math-inventory.cjs`, `test/tools/check-math-accessibility.sh`.

The report records actual invocations/artifact paths. Existing tooling supports a P1 pilot, not complete matching/readiness or acceptance. These results are evidence, not a substitute for complete corpus and qualification.

Existing asset regeneration (repo root, pinned extracted archive):

```sh
python3 tools/generate_metrics.py \
  /tmp/katex/package/src/fontMetricsData.js /tmp/math_metrics.adb
cmp /tmp/math_metrics.adb src/coyote_math/math_metrics.adb
```

Existing inventory regeneration:

```sh
node tools/inventory_katex.cjs \
  /tmp/coyote-katex-support-check/package \
  /tmp/coyote-katex-support-check/katex.tgz \
  plan/native-math-katex-0.16.22-inventory.json \
  plan/native-math-katex-0.16.22-inventory.md
```

These commands regenerate current assets/inventory, not differential
corpus/snapshots. Development-only reference/browser exporters, comparison,
fixtures and checks exist; the remaining corpus fields, matching, accounting and
readiness evidence are incomplete as described in §3.2.

### 2.3 Environment and support software

Use existing GNAT/Alire development profile, GTK3/Cairo/FreeType, bundled fonts, AUnit, Node oracle, and pinned reference browser. Record hardware/CPU/RAM, OS, display/Xvfb, versions, available memory and background load. Fix one named qualification workstation for timing; isolate processes for peak RSS and cache accounting. GUI automation uses Xvfb where adequate; manual accessibility tests use named desktop/tools.

Development tools and exporters exist for reference/browser output, structured
geometry comparison, image comparison, fuzzing, resource/performance probes,
inventory and accessibility. The final3 findings in the preceding paragraph
are historical. Current scoped evidence and limitations are summarized in §2.2
and report §8; the current source crosswalk has been regenerated.
These snapshots do not establish full P1 readiness or parity.

## 3. Test plan and gates

### 3.1 Classes and progression

Classes: inventory/accounting; parser and state differential; functional/boundary; diagnostic/policy/negative controls; geometry/image differential; GUI/accessibility; resource/performance/stress/cancellation; security/I/O; regression/provenance/reproducibility. Label each result pass, fail, blocked, not run, or approved deviation. Partial, unimplemented and pending are not passes. Log every discrepancy; do not tune thresholds or normalize failures after observing results.

Progression: approved requirements, design and execution baseline are established; (1) complete P1 readiness evidence; (2) focused increments and regression; (3) complete corpus, budgets, security, GUI and manual qualification; (4) separate user acceptance. Failures or changed reference pins return to corrective action and rerun. Test-readiness approval and final qualification remain open.

### 3.2 Minimal P1 harness readiness gate (not final acceptance)

P1 readiness remains open. Browser/reference exporters, structured geometry
comparison, pilot fixtures and browser manifest exist. Current scoped evidence
is summarized in §2.2 and report §8: geometry 145/145; frozen structured pilot
16/16 and image pilot 3/3, with negative controls. Only the structured path
comparison uses normalized units; full origins, widths and option effects remain
unmeasured. Do not report the older
geometry failures or three image failures as current. Color-candidate validation
aborted; trust=false is the enforced default, while trust=true and fleqn
are explicitly rejected. Whole-job memory/deadline/GTK qualification remains open. Matching,
accounting, complete frozen corpus and reviewed reproducibility/readiness remain
incomplete. Changed-input and omission controls do not qualify the full approved
field set. Consult the coordinator-owned coverage map/report; its source crosswalk is
regenerated and remains unqualified. Tool presence or partial checks are not a pass for missing
inventory entries.

P1 does not require full feature parity, calibrated final visual tolerances,
performance compliance, 10,000-case robustness, human accessibility acceptance,
or a passing full inventory. The recorded 10,000-case fuzz run is evidence for
that seed/run, not full qualification. Readiness and review remain incomplete.

### 3.3 Final acceptance targets and evaluation

Denominator: every in-profile item and relevant interaction, mode, option, error and boundary case, plus named approved deviations. Inventory counts (309 function names, 33 environments, 338 built-in macros, 2236 upstream mode-specific symbol registry rows, 14 settings, 60 font files/20 faces) are not independent feature/test counts. The generated native symbol lookup retains 2203 of those upstream keys; lookup presence is not semantic qualification. Every item needs disposition, linked case/evidence and review; registry counts do not imply coverage.

The approved SRS values remain normative. Design v0.3 retains proposed additional context caps and scheduling choices—16 live contexts, 4 MiB committed definitions per context, 64 MiB aggregate context/snapshot/journal retention, two workers/eight pending descriptors, and 256-pixel tiles with specified adoption batching/deadlines. These are unapproved design proposals, not new SRS limits; the cases below characterize proposed behavior only. No test outcome approves these caps.

Approved quantitative REQ-MATH-010/013 budgets:
| Bound | Approved target | Evaluation |
|---|---:|---|
| Source/expression | 65,536 UTF-8 bytes | exact boundary; oversized bounded fallback |
| Emitted lexical/expanded tokens | 131,072/request | exact bound and over-bound rejection |
| Macro expansion | default 1,000; configurable maximum 10,000 | exact counts; termination/cleanup |
| Syntax nodes / argument depth | 32,768 / 128 | boundary and one-over |
| Array rows / columns | 64 / 64 | each and combined bound |
| Layout depth / draw commands | 256 / 131,072 | exact and over-bound |
| Absolute dimensions / user sizing | 16,384 em / 100 em cap | computed and requested policies |
| Final surface incl. padding | inline 2,000×512; display 8,192×4,096 px | reject/fallback safely |
| Additional math-job memory | ≤256 MiB | owned allocations; isolated-process peak RSS separately |
| Retained raster cache | ≤64 MiB/process | cache bytes, eviction; oversized surface not retained |
| Warm representative latency | p95 ≤50 ms | ≥200 cases; one warm-up + 10 timed iterations; queue-inclusive |
| Bounded job / GTK slice | terminate or reject ≤250 ms; synchronous GTK slice ≤50 ms | monotonic clock; queue and cancellation cleanup included |
| Geometry | absolute dimension/glyph-origin/baseline/rule/path error ≤0.01 em | matched constructs/common baseline/em |
| Robustness | ≥10,000 seeded generated/adversarial cases/final run | fixed seeds; not proof of all-input safety |

These are approved SRS targets, not qualified implementation guarantees. The
source/layout code clamps user maxSize to 1..100, but layout depth remains 64
and draw-command count 16,384 versus targets 256 and 131,072. Whole-job memory
has no aggregate allocator instrumentation; the 64 MiB ledger accounts for
GUI display-math Cairo surfaces, not inline rasters or a process-wide cache. The 250 ms deadline check does
not preempt a blocking native call. GTK adoption uses a 5 ms soft quantum and
batches of at most eight operations, not a hard 50 ms bound. These measured or
implemented controls do not establish REQ-MATH-010 budget compliance.

Visual targets in the approved SRS remain **provisional pending calibration**: at 24 px/em, bidirectional foreground-mask distance ≤1 px for ≥99% each direction; alpha ≥0.1; semantic component count matched/reviewed; component bounds ≤0.01 em; interior RGBA channel delta ≤2/255 (>1 px from edge). These are not calibrated or achieved. P1 must calibrate using frozen fixtures and missing/extra/shifted/wrong-color/tiny-accent controls; readiness approval is required before acceptance use.

For ARGB32 use Cairo stride × height. Maximum 8192×4096 surface is 128 MiB before intermediates. Include cached copies during job in 256 MiB; after completion retained rasters count against 64 MiB. Exclude/report separately warmed shared font caches, pre-existing GUI baseline, and session/source retention. Report allocated bytes, peak RSS above warmed baseline, cache growth/high-water/evictions, queue delay, execution and cleanup separately. Visual protocol: transparent background, matched colors, pinned fonts/viewport/device scale, baseline alignment without free rescaling. Compare bidirectional nearest foreground-pixel distances; empty/nonempty fails; both empty passes only if reference semantically empty. Require reviewed component count/bounds. Interior RGBA differences ≤2/255; edge-only tiny components have separate geometry/color checks; no interior pixels is not automatic pass.

Timing: specify workstation, OS, compiler, browser, warm/cold state; p95 from ≥200 cases, 10 iterations after warm-up. Separate hostile cases. Time submission through completion/rejection, including queue wait and cancellation cleanup; measure GTK slices independently. 250 ms watchdog expiry is failure, not compliant behavior. Infeasible approved limits require requirements change, not silent relaxation.

### 3.4 P1–P6 sequence and regression gates

- P0: approved SRS/profile/deviations, design and execution baseline are recorded; no repeat approval gate is pending.
- P1: review existing pilot tools/artifacts and baseline gap report; P1 readiness remains open per §3.2.
- P2: common notation pilot; focused differential/GUI; estimate remaining work.
- P3: parser, macro/state, Unicode, options, diagnostics; adversarial regression.
- P4: fonts/layout/constructs/drawing; geometry and calibrated visual corpus.
- P5: GTK/native semantics, copy/zoom/replay/themes; automated and human accessibility review.
- P6: inventory reconciliation; robustness, safety, resources/runtime dependencies; root/test development builds; full suite; report and separate user acceptance.

At increments, run applicable focused/AUnit checks. Before final acceptance run
qualified development builds and suite from §2.2, Xvfb as required, standalone
probe and inventory check. Historical reports are not reruns. Final3 observed
results and current qualification disposition are recorded in
`plan/native-math-parity-test-report.md`; this plan is not a substitute for that
report or for the remaining acceptance evidence.

## 4. Test description and execution conventions

### 4.1 Common preconditions and steps

Unless overridden: reviewed pinned archive/fonts and frozen corpus; verify hashes; development profile; confirm `katex.version === '0.16.22'`; isolated, network-disabled reference/native processes; clear per-case state/cache when specified; record source bytes, settings/profile, seed, environment, logs, outputs and hashes. Reference defaults are `new Settings({})`, not CLI defaults. Baseline: inline/display as specified, `throwOnError=true`, `maxSize=100`, `maxExpand=1000`, `trust=false`; error-fragment cases use `throwOnError=false`. Compare outcomes, diagnostic category/position mapping, semantic structure and geometry as applicable. Retain raw values.

Steps: verify preconditions; load exact input/state sequence; run reference and native; collect outputs/errors/geometry/visual/resource data; compare; save artifacts/dispositions; rerun determinism/negative controls where specified. Record machine, command, times, result and deviations. Missing harness, interface, design, threshold, assistive tool or target behavior means blocked/not run, never invented evidence.

### 4.2 Evaluation and approved deviations

Pass only when expected outcomes and approved criteria hold, case accounting is complete, and no unreviewed deviation exists. Fail on mismatch, crash, hidden/dropped construct, unintended external effect, budget breach, nondeterminism or absent expected record. Blocked/not run is no evidence. Approved deviation applies only to its specific D disposition and preserves no-side-effect conditions. Final acceptance requires all in-profile cases pass, exclusions individually approved, failures dispositioned under process, and separate human acceptance recorded.

Approved profile deviations: D01 native visual output, no HTML/CSS/SVG byte-serialization claim; D02 native semantics, no MathML XML export; D03 native visual/semantic channels, no DOM/API compatibility. D04 `\href` refusal/visible behavior, no active anchor; D05 `\url`; D06 `\includegraphics` refusal/validation and no formula-triggered image load; D07 `\htmlClass` no arbitrary classes; D08 `\htmlId` no arbitrary identifiers; D09 `\htmlStyle` no arbitrary CSS; D10 `\htmlData` no arbitrary data attributes. D11 test strict/trust scalar and boolean policies, not callable JS callbacks. D12 textual/token caller macros and scope, not function-valued JS macros. D13 finite approved boundaries, no unbounded parity claim. D14 inventory contrib modules separately outside core denominator; test native Markdown extraction independently. D15 no JS render/DOM/parse/extension API or production JS/browser dependency. No deviation excuses security or accounting. D04–D10 forbidden effects remain tested.

## 5. Planned test cases

Planned case families are not all a single registered runnable suite. Some
standalone checks, probes, fixtures and AUnit cases exist; corpus rows still need
expansion to per-inventory IDs, matching, and complete coverage. Tooling presence
does not imply readiness or full parity.

### 5.1 Inventory, reference, provenance

**MATH-INV-001 — pinned reference and accounting** (inspection/test; REQ-MATH-001/013). Verify archive/bundle/source/font hashes; regenerate inventory and byte-compare; reconcile every core registration, implicit/Unicode rule, setting, mode, font/layout behavior and option to case/status/evidence; inspect each D item. Pass: deterministic artifacts and reviewed complete mapping; missing rows are not passes. Planned mapping schema unavailable.

**MATH-INV-002 — provenance and tamper controls** (test; REQ-MATH-001/015). Clean temporary output, no network/npm. Run inventory/metrics regeneration; perturb version, archive, bundle, source, font and contrib copies independently. Pass: clean output byte-identical; altered/missing/extra input rejected; retain logs. Existing tooling covers inventory tampering; broader harness outputs planned.

### 5.2 Parsing, expansion, context

**MATH-CONC-001 — publication barrier and cancellation ordering** (T/A; REQ-MATH-003/010/014; design proposal). With deterministic barriers and a shared context, cancel a request immediately before Publishing, while blocked at the publication gate, and immediately after the atomic publication receipt. Use a source that makes several global definitions with a checkpoint between them. Before-Publishing cancellation must publish only the executed prefix once if epoch still matches; after-Publishing cancellation keeps that committed journal and cancels remaining visual work. Confirm revision, definitions, receipt, cleanup, and subsequent request behavior. Repeat with duplicate completion, retry, and stale view delivery; state/revision must not change twice. Race stress supplements but never replaces barrier assertions. The test's deterministic publication barriers and exact prefix semantics remain
future qualification work; this test plan does not establish their current
implementation or evidence status.

**MATH-CONC-002 — parser resource-prefix publication** (T/A; REQ-MATH-002/003/010). In a shared context, define global `\alpha`, then consume a deterministic token/node/depth budget at a later parse point; separately place another definition after the exhaustion point. Verify bounded resource diagnostic, no later token execution, local-scope unwind, and publication of exactly the eligible executed prefix once; the post-limit definition is absent. Test repeated failure and resource cleanup. This tests native prefix semantics; the SRS specifies budgets, not a reference cancellation contract.

**MATH-CONC-003 — reset epoch atomicity** (T/A; REQ-MATH-003/010/014; design proposal). Pause a request at the publication gate and race reset against entry to Publishing in both serialized orders. If reset wins, epoch increments, old journal is rejected, and new-epoch requests see reset state. If publication wins, its single atomic swap/revision completes before reset clears state; no mixed snapshot is observable. Deliver old completions after reset and verify no old-epoch publish, release exactly once, and no deadlock. Include reset with staged snapshot/journal allocations and capacity pressure.

**MATH-CONC-004 — aggregate contexts and charged staging** (T/A; REQ-MATH-003/010; proposed design caps, not SRS limits). Under the proposed caps, admit up to 16 explicit contexts; verify the 17th is explicitly rejected without evicting live definitions. At each context, exercise 4 MiB committed-definition boundary and one-byte-over; aggregate context/snapshot/journal retention at 64 MiB and one charged-byte-over. Charge actual staging capacities—including vector/container growth while old and new capacities coexist, snapshots, journals, in-flight clones, token/node/request payload and retained committed data—not just logical lengths. Exhaust each stage independently and together: reserve-before-allocation or explicit bounded failure, no hidden eviction/truncation, double charge/release, leak, stale alias, or lost committed definitions. Reset/destruction releases charges only after outstanding handles/tickets drain; assert ledger invariants through teardown. Thresholds remain design proposals until separately approved.

**MATH-CONC-005 — two-worker admission and ordering** (T/A; REQ-MATH-010/011/014; proposed design). Submit independent jobs until both workers are occupied and eight pending descriptors are admitted; the next submission is explicitly rejected with visible source fallback, not syntax error or silent drop. Test descriptor-byte payload charging, expired queue entries, cancellation while pending, same-context serialization versus unrelated contexts using both workers, and shutdown draining/joining. Assert FIFO/context revision rules, queue-inclusive deadline, exactly-once completion/resource release, no worker/GTK ownership crossing. Two/eight are unapproved design values; assess as feasibility evidence only.

**MATH-CONC-006 — worker FT/Cairo/Pango ownership and failure gates** (T/A/I; REQ-MATH-010/011/014). Concurrently load/shape/paint on both workers using worker-local FT_Library/FT_Face, Cairo font faces/image surfaces and `pango_cairo_font_map_new` maps; create Pango contexts/layouts only from each owning local map. Static/dynamic audit rejects `pango_cairo_font_map_get_default`, widget `Get_Pango_Context`, and mutable FT/Pango object transfer to another worker or GTK. Inject font-missing, allocation, shaping/paint exceptions, cancellation/reset and shutdown at every ownership boundary. Verify owning-worker reverse-order finalization, charged cleanup, immutable-only result transfer, no widget access off GTK main task, no callback after shutdown, worker join and shutdown completion even on failure. Existing jobs and native ownership-related focused tests exist. This specific two-worker cross-library stress, exhaustive fault injection and full budget/cleanup qualification remain open.

**MATH-CONC-007 — tile completion, GTK adoption, repaint** (T/A/D; REQ-MATH-005/010/011/014; proposed design values). Use 256×256 maximum tiles and deterministic slow queue/adoption hooks. For a large display, assert successful initial visible completion includes queue wait, tile production, postback and GTK adoption/composition for every required visible tile; no pending tile may coexist with successful completion. Exercise 5 ms soft pump quantum, no more than eight adoption/tile operations per batch, measured ≤50 ms hard GTK slice, and ≤250 ms full initial visible adoption from submission including queue. Record all phases and fail watchdog expiry; deferred batches retain original deadline. Scroll out/in and repaint missing tiles without macro expansion, context journal publication, or any other macro side effect. Repeat repaint/zoom/theme, stale generations, failure fallback and full-image headless qualification; assert source remains visible on incomplete failure and all tile/cache charges release. These batching/deadline values are proposals, not approved SRS limits; the approved SRS 50/250 ms targets remain separately tested by MATH-LIMIT-002.

### 5.3 Symbols, layout, constructs, options

**MATH-PARSE-001 — syntax, modes, normalization** (T/D; REQ-MATH-002). Groups/arguments, optional args, comments/whitespace, infix/implicit syntax, text/math modes, aliases, restricted symbols, nested valid constructs; invalid groups/args, unknown macros, duplicate scripts, malformed UTF-8/NUL boundary. Paired reference/native; capture accept/error, normalized tree and positions. Pass: same in-domain outcome/structure/diagnostic; no partial parse reported as success. Current probe/oracle subset is smoke only.

**MATH-PARSE-002 — reported heat-balance fixture** (T/D; REQ-MATH-002/005/006/013). Normative fixture source, with the line break preserved, is:

```tex
C_a\dot T_a =
H_o(T_o-T_a)+H_m(T_m-T_a)
+Q_{\mathrm{solar}}+Q_{\mathrm{internal}}-Q_{\mathrm{cool,sens}}.
```

Fixture ID `heat-balance-001` is already used by the final3 pilot. The final3
export evidence confirms the original source and display-delimited hashes match
the pinned pilot; native status is `ok`, with 54 draw commands including U+02D9.
This verifies source/provenance preservation for this fixture, not parity: the
corresponding image comparison fails and structured differential evidence remains
blocked. Retain these hashes and artifacts; complete per-entry corpus and
approved geometry/visual evaluation remain future work. Do not substitute a
minimized/invented source; separately derived variants need traceable IDs.

**MATH-PARSE-003 — expansion and budget** (T; REQ-MATH-002/010). Text/token macros, parameters, nested/built-in macros, recursion/explosive expansion; counts 999/1000/1001 and 9999/10000/10001. Fresh context, recorded maxExpand. Compare outcome/count; monitor resources; reject/cancel hostile cases and check cleanup. Pass: in-domain equivalence, bounded visible over-cap failure, no hang/state leak. Macro probes and fuzz tooling exist; the full expansion-boundary corpus and
complete generated/adversarial case set remain to be specified and qualified.

**MATH-STATE-001 — state errors and scope semantics** (T; REQ-MATH-003/007). Compare paired sequences for `\gdef\foo{A}\bogus` and `\def\foo{A}\bogus`, with `globalGroup=true` and `globalGroup=false`, recording parse error and post-error visibility of `\foo` in same/shared context and subsequent render. Assert the reference behavior explicitly: KaTeX global mutations survive parse error, and top-level `\def` with `globalGroup=true` survives; compare native behavior and approved contract. Also test fresh-request isolation, shared-context reuse, local scope restoration, reset, session isolation. Failure cleanup must not assume rollback; record native mutation-publish policy review as a design dependency. Pass only documented behavior match and no unrelated leak. Focused context, macro, semantic and job probes already provide partial evidence; the full cross-product state/error corpus and per-inventory context driver remain to be completed.

**MATH-STATE-002 — zoom/replay repeat-render** (T/D; REQ-MATH-003/011). Commit shared-context formula once; zoom, resize/reflow, replay and realization. Pass: stable visuals and side effect applied once, no unrelated/session leak. Context API/harness requires design review.

**MATH-UNICODE-001 — symbols/modes/accents/scripts** (T/D; REQ-MATH-004). Every in-profile key/alias in text/math; Unicode, combining/accent, scripts, missing glyph and strictness; representative multi-codepoint forms. Record fonts/fallback; compare symbol, face/glyph, diagnostic and geometry. Pass: all rows mapped and approved metrics met; missing glyph follows policy. Focused symbol, font-data and geometry tools exist, and the report includes pilot
results. The full in-profile symbol/font corpus, matching, and approved metric
qualification remain incomplete.

**MATH-LAYOUT-001 — metrics, spacing, styles, scripts, limits** (T/D; REQ-MATH-005). Atom classes/spacing, styles, fraction aliases, script corrections, operators (`lim`, `max`, `min` full word), display/text limits, wide scripts, dimensions/color. Export boxes, glyph origins, baselines, rules, paths; compare structure and ≤0.01 em. Existing three ascent/descent checks are insufficient.

**MATH-LAYOUT-002 — assemblies and fonts** (T/D; REQ-MATH-004/005/006). Each core delimiter/radical/arrow/accent/brace/decoration at natural and extended heights; required faces and missing glyphs. Compare glyph/assembly geometry and visuals. Pass: no truncation where reference extends in domain; hashes/notices verified. Geometry, construct and image pilot fixtures exist; full per-inventory fixtures,
complete reference mapping and qualification coverage remain open.

**MATH-CONSTRUCT-001 — functions, annotations, boxes, color, dimensions** (T/D; REQ-MATH-006). Each core function and combinations; over/under, enclosures, phantom/overlap, color, sizing, strictness. Verify every argument and visible/semantic effect. Pass: equivalent structure/effects, no dropped letters/arguments/decorations; bounds enforced.

**MATH-CONSTRUCT-002 — environments, arrays, rules, tags** (T/D; REQ-MATH-006). Every core environment; alignment, gaps, rules, tags/numbering, malformed rows, zero/max/over-max rows/columns, nesting. Compare outcomes, geometry, labels and command sequence. Pass: every row classified, documented limits exact, no silent truncation.

**MATH-OPTIONS-001 — scalar options and profiles** (T; REQ-MATH-007). `displayMode`, `leqno`, `fleqn`, `throwOnError`, `errorColor`, textual macros, `minRuleThickness`, `colorIsTextColor`, strict warn/ignore/error/boolean, `trust`, `maxSize`, `maxExpand`, `globalGroup`. Test reference defaults and approved variants/combinations. The default trust=false profile is enforced; trust=true and fleqn are explicitly rejected. Full option equivalence remains unqualified. Color-candidate validation aborted, so no current color pass is claimed. Pass: applicable behavior/diagnostic and state match. Callable JS callback modes excluded under D11.

### 5.4 Errors, policy, security, bounds, scheduling

**MATH-ERROR-001 — errors, positions and fallback** (T/D; REQ-MATH-008). Unknown commands, malformed syntax, strictness, refusal, font/layout/resource failures; both throwOnError values. Compare category and UTF-8 position mapping; verify original source retained and GTK fatal fallback shows full source, never partial success. Exception wording/stack not required.

**MATH-TRUST-001 — untrusted policy and effects** (T/I; REQ-MATH-009; D04–D10). `\href`, `\url`, `\includegraphics`, `\htmlClass`, `\htmlId`, `\htmlStyle`, `\htmlData` under trust=false; malformed args and strict variants. Sandbox with filesystem/network/process tracing. Expect policy result, not unknown-command masking; no external I/O, process, active link/image load, arbitrary HTML/CSS. Preserve surrounding Markdown local-image behavior. Pass: zero forbidden effects.

**MATH-LIMIT-001 — exact approved budget matrix** (T/A; REQ-MATH-010/013). For each §3.3 bound below/exact/above and combined interactions: source 65,535/65,536/65,537 bytes; tokens 131,071/131,072/131,073; expansion 999/1000/1001 and 9999/10000/10001; nodes 32,767/32,768/32,769; argument depth 127/128/129; rows/columns 63/64/65 independently/combined; layout depth 255/256/257; commands 131,071/131,072/131,073; dimensions below/at/above 16,384 em and requested size at/above 100 em; surface boundaries and one-pixel exceedance. Expected in-domain support; over-limit bounded rejection/fallback, cleanup, no crash/stall.

**MATH-LIMIT-002 — memory, latency, cancellation** (T/A; REQ-MATH-010/014). Representative/nested/array/macro/hostile jobs, cold/warm, repeated; queued and parse/layout/paint cancellation where supported. Isolate process; record allocations, Cairo stride×height, RSS delta over warmed baseline, transient/retained cache, eviction, queue wait, work and cleanup. Verify 128 MiB max surface accounted in 256 MiB; retained rasters ≤64 MiB; oversize not cached; fonts/session source separately reported. Measure p95 ≥200 cases, one warm-up + 10 iterations; ≤250 ms includes queue/cancel; GTK slice ≤50 ms. Pass only approved budgets; watchdog kill is failure. Instrumentation requires design.

**MATH-SCHED-001 — stale scheduled jobs and queue cancellation** (T/A; REQ-MATH-010/011/014). Schedule a job with generation token, then before execution invalidate by each action independently: clear, teardown, zoom change, session switch. Assert stale generation is rejected, resources/prompts/queues are cleaned, no callback touches dead/replaced state and no second side effect occurs. Exercise full queue and queue-wait cancellation, including 250 ms deadline and just-before/at/after timing; assert bounded completion/cleanup and no duplicate dispatch/render. Record queue wait separately from execution. Define deterministic scheduler/clock and cancellation ownership in design; no rollback assumption for parse mutation—review native mutation-publish policy dependency from MATH-STATE-001. Not qualified until design/harness exists.

**MATH-TRUST-002 — external-I/O/runtime negative controls** (T/I; REQ-MATH-009/011/015). Malicious URL/path/process/HTML/CSS and production executable/probe. Offline sandbox, trace filesystem/network/process and inspect dependency inventory. Pass: zero formula-triggered external effects and no production JS/browser/KaTeX runtime. Test oracle may use local pinned assets in development.

### 5.5 Differential, GUI, semantics, regression

**MATH-DIFF-001 — structural/geometry and controls** (T/I; REQ-MATH-005/013). Geometry later passed 145/145 (`/tmp/coyote-fraction-final145-r8.log`), resolving the seven prior failures. The frozen structured pilot passed 16/16 with negative controls. Its path comparison uses 0.01 normalized units, not em-unit origins. Geometry ascent/depth are measured separately; full origins, widths and option effects remain unqualified/unmeasured. Complete mapping/accounting and frozen corpus remain required. Compare reference/native boxes, glyph positions and paths at the approved ≤0.01 em; missing records/components and real mismatches must remain visible, never omitted. See report §8.

**MATH-DIFF-002 — raster differential/calibration** (T/D; REQ-MATH-005/012/013). Pinned browser/native fixtures at 24 px/em, matched fonts/colors/transparent background. The three-case PNG pilot passes its raster checks and shifted-baseline negative control, separately from the normalized path comparison. This is not calibrated visual acceptance: full component mapping/calibration and option-effect qualification remain open. Retain approved SRS criteria and controls unchanged; no full image or parity qualification is claimed. See report §8.

**MATH-GUI-001 — Markdown/GTK integration** (T/D; REQ-MATH-003/011). Inline `$...$`, `\(...\)`, display `$$...$$`, `\[...\]`, multiline, prose, code spans/fences/indented code, link destinations, ordinary dollars, malformed math, many formulas. Check baseline/display, protected code, exact source copy, selection, zoom/reflow, theme, session replay, resize/repeated render, error/limit fallback. GTK operations on main task; Plain/session compatibility. Automated AUnit/Xvfb and manual desktop where needed.

**MATH-A11Y-001 — semantics and human acceptance** (T/D/I; REQ-MATH-012). Fractions, scripts, operators, arrays, annotations and approved links; exact source. Record named desktop, screen reader/accessibility tool versions, bridge, locale, user role. Inspect discoverability, name/navigation, numerator/denominator, scripts, rows/cells, reading order, links, source copy/delimiters, display/inline and fallback. Bitmap cannot pass. Automated accessibility tooling and focused checks exist;
human assistive-technology/desktop assessment and independent acceptance remain
pending. The report records no such acceptance.

**MATH-REGRESS-001 — build and suite** (T; REQ-MATH-014). Root/test development builds, focused `Coyote.Math`, full `cd test && alr run coyote_test` under Xvfb when needed, existing probe/inventory check. Save commands/logs/status. The latest known full suite passed 1061/1061 in `/tmp/coyote-completion-final2-full.log` before subsequent genfrac/mathchoice/color/minRule edits; this is a regression checkpoint, not current-source integration or parity qualification. Require a full integration rerun before drawing current-source conclusions. Earlier dated suite results remain historical; do not rerun or infer results from this plan update.

**MATH-REGRESS-002 — seeded fuzz and failure paths** (T/A; REQ-MATH-010/014). ≥10,000 fixed-seed generated/adversarial cases per final run: malformed syntax, nesting, macro cycles, dimensions, arrays, Unicode, cancellation/failure injection. Bounded isolated runner. Record seeds, failures, crashes, hangs, leaks. Pass: no unbounded work/resource breach, crash, state leak or unexplained nondeterminism; triage all failures. Existing 40 malformed AUnit samples are insufficient.

**MATH-PROVENANCE-001 — repeatability and maintenance** (I/T; REQ-MATH-001/015). Rerun approved offline generation/export/comparison; hashes; altered-input rejection; notices/provenance/change records. Pass: deterministic output, identified inputs, no npm/runtime dependency; upstream change separately reviewed. The browser asset manifest and pilot output artifacts exist. Broad frozen qualification
snapshots with complete environment, corpus matching and reviewed dispositions
remain to be produced.

## 6. Requirements traceability

| Requirement | Planned verification cases |
|---|---|
| REQ-MATH-001 | MATH-INV-001, MATH-INV-002, MATH-PROVENANCE-001 |
| REQ-MATH-002 | MATH-PARSE-001, MATH-PARSE-002, MATH-PARSE-003 |
| REQ-MATH-003 | MATH-STATE-001, MATH-STATE-002, MATH-CONC-001–004, MATH-GUI-001 |
| REQ-MATH-004 | MATH-UNICODE-001, MATH-LAYOUT-002 |
| REQ-MATH-005 | MATH-LAYOUT-001, MATH-LAYOUT-002, MATH-DIFF-001, MATH-DIFF-002 |
| REQ-MATH-006 | MATH-CONSTRUCT-001, MATH-CONSTRUCT-002, MATH-PARSE-002, MATH-LAYOUT-002 |
| REQ-MATH-007 | MATH-STATE-001, MATH-OPTIONS-001 |
| REQ-MATH-008 | MATH-ERROR-001 |
| REQ-MATH-009 | MATH-TRUST-001, MATH-TRUST-002 |
| REQ-MATH-010 | MATH-PARSE-003, MATH-LIMIT-001, MATH-LIMIT-002, MATH-SCHED-001, MATH-CONC-001–007, MATH-REGRESS-002 |
| REQ-MATH-011 | MATH-GUI-001, MATH-TRUST-002, MATH-SCHED-001, MATH-CONC-005–007, MATH-REGRESS-001 |
| REQ-MATH-012 | MATH-DIFF-002, MATH-GUI-001, MATH-A11Y-001 |
| REQ-MATH-013 | MATH-INV-001, MATH-PARSE-002, MATH-LIMIT-001, MATH-DIFF-001, MATH-DIFF-002 |
| REQ-MATH-014 | MATH-LIMIT-002, MATH-SCHED-001, MATH-CONC-001, MATH-CONC-003, MATH-CONC-005–007, MATH-REGRESS-001, MATH-REGRESS-002 |
| REQ-MATH-015 | MATH-INV-002, MATH-TRUST-002, MATH-PROVENANCE-001 |

Trace source: approved REQ-MATH-001–015 and U1/U2/B1 sources in SRS §6. D01–D15 are approved profile deviations; tests verify their specific boundaries and side-effect conditions. Explicit per-inventory case rows, unit mapping, fixture IDs and source trace remain to be completed against the approved design and pinned inventory. This table does not claim each item already has a concrete fixture.

## 7. Risks, blockers, review actions

1. **Readiness:** execution/design approval is complete; P1 matching/readiness, field coverage, complete corpus, calibration and final qualification remain open.
2. **Harness:** exporters, comparators, pilots, fuzz, resource/performance and accessibility tools exist. Current partial results and gaps are documented in §§2.2–3.2 and the parity report; complete fields, matching/accounting, broad snapshots and qualification evidence remain to be closed. Do not describe existing tools as absent or invent tool paths.
3. **Visual readiness:** visual criteria are provisional pending calibration; no calibration or achievement claimed. Quantitative budgets are approved targets, not evidence of compliance.
4. **Fixture:** `heat-balance-001` source and display-delimited hashes are preserved and match the pinned pilot. Its exact-source native export is valid; the scoped differential/image results do not provide qualified math/origin/width effects or calibrated visual acceptance. Complete per-entry corpus and qualification platform manifest remain pending.
5. **Security/resource:** no broad offline trace, full cancellation/failure, cache/RSS, fuzz or runtime dependency qualification is claimed. Formula input performs no I/O; known bundled-font reads and native runtime housekeeping are allowed and must not be misreported as formula-triggered I/O. Never assert absolute zero filesystem access.
6. **State/cancellation:** KaTeX parse-error mutation behavior is an explicit differential; the approved design specifies publication/ownership rules, but their full implementation and qualification remain open. Do not assume all-error rollback or claim those rules proven by component tests.
7. **Accessibility/independence:** named tools and human reviewer pending. Developer self-evaluation/read-only review is not independent acceptance; user review of readiness/results remains separate.

**Plan status:** This approved execution baseline retains cases where implementation, matching or evidence is incomplete. Current evidence and limitations are summarized in §2.2 and coordinator-owned report §8. The 1061/1061 full-suite checkpoint predates subsequent genfrac/mathchoice/color/minRule edits and requires a full integration rerun; geometry later passed 145/145. The frozen structured pilot passed 16/16 and image pilot 3/3 with negative controls. Only the structured path comparison uses normalized units; full origins, widths and option effects remain unmeasured. The current color-candidate validation aborted. Whole-job memory/deadline/GTK guarantees, P1 readiness, full qualification, visual calibration and independent human/user acceptance remain open. Coverage is regenerated; use the current map/report rather than older totals. Approved targets remain normative; no parity or acceptance claim is made.
