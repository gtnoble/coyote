# Native math human acceptance checklist

**Document:** Operator checklist for approved manual component-acceptance checks
**Version:** 0.7
**Date:** 2026-11-15
**Status:** Procedure drafted; readiness review, execution, qualification, and human acceptance remain **PENDING**
**Authority:** [SRS-MATH v1.2](../requirements/native-math-compatibility.md), especially REQ-MATH-012; updated [STP/STD-MATH v0.12](native-math-compatibility-tests.md), especially §§2.2, 3, 4, 5.5 (`MATH-GUI-001`, `MATH-SOURCE-001`); current [parity test report](native-math-parity-test-report.md). This checklist supplements, and does not change or supersede, those documents.

**2026-11-15 status pointer:** Use report §11.11 for current developer evidence.
Earlier image counts and synchronous-inline descriptions below are historical:
§11.10 recorded corrected expanded images95/95; §11.11 records worker-backed
inline rasterization and full suite1076/1076. This checklist is still unexecuted;
readiness, broad qualification and human acceptance remain PENDING.

## 1. Purpose and limits

Use this checklist to collect **actual operator and human-review evidence** for the approved manual GUI cases. It is not a full product test plan, complete REQ-MATH-013 corpus, automated acceptance harness, readiness approval, or a claim that native math is equivalent to KaTeX. Record each step as **PASS**, **FAIL**, **BLOCKED**, or **NOT RUN** with evidence; blank is not pass. Do not infer an outcome from the presence of a widget, test, or PNG.

REQ-MATH-012 requires exact delimited display-formula source in a collapsed, read-only, selectable LaTeX-source view, available during pending, invalid/unsupported and valid states and updated on replacement. Verify exact source including delimiters and line breaks. Raw LaTeX is not semantic math and does not establish screen-reader math accessibility. This checklist makes no complete accessibility claim. Unrelated GUI/manual qualification and exact-source copy behavior under REQ-MATH-011 remain in force.

**No product acceptance may be declared from this checklist while the approved STP readiness/final-qualification gates are open or known fatal acceptance gaps remain.** Coordinator report §11, “Current implementation and qualification reconciliation — 2026-11-06”, is the latest recorded status; §10 and earlier sections are historical. It records 28/29 image cases (long-tilde mask 0.9851 < 0.99), 278/338 scoped semantic matches with 60 explicit gaps (strict comparison failed), and 235/235 geometry matches. This is not qualification or calibrated visual acceptance. Temporary logs are unavailable for this documentation-only update; tests were not rerun. Whole-job memory/deadline/GTK/cache qualification, full behavior/corpus readiness and independent human visual acceptance remain open. No human acceptance has occurred.
## 2. Gate and evidence status at issue

STP/STD-MATH v0.9 records the current planning baseline; readiness,
qualification and acceptance remain open. Coordinator report §11, “Current
implementation and qualification reconciliation — 2026-11-06”, is the latest
recorded evidence; §10 and earlier sections are historical. The latest recorded
image comparison is 28/29 (long-tilde mask 0.9851 < 0.99); geometry is 235/235,
and structured comparison has 278/338 scoped semantic matches with 60 explicit
gaps and strict-mode failure. These results do not constitute qualification.
Temporary logs are unavailable for this documentation-only update; no tests
were rerun. Capture fresh evidence against the exact tested source before
execution. This checklist remains unexecuted; no human acceptance has occurred.
There is **no end-to-end product GUI acceptance harness** that drives and records this human protocol. Available standalone commands generate component evidence; they do not launch the conversation stack with this checklist's controlled formula set or establish whole-product behavior:

```sh
alr build --development
cd test && alr build --development --profiles=coyote=development
cd test && xvfb-run -a ./bin/coyote_test
cd .. && sh test/tools/check-native-math.sh
```

Run from the repository root for the first, second command as indicated, and the focused shell probes. The AUnit command assumes the test executable is built; if running it directly from `test/`, use `xvfb-run -a ./bin/coyote_test`. `check-native-math.sh` writes a standalone probe log and `production.png` under `/tmp/coyote-native-math-qualification` by default. It is a useful reproducible component check, **not product-window human acceptance**. There is no dedicated accessibility probe; conversation-source behavior has AUnit component coverage, not assistive-technology acceptance evidence. Record failures/blockers; do not represent a probe artifact as a screenshot of the product conversation view. No external provider, network, or real-model response is needed for these local checks. If the tested product UI cannot be populated with controlled local content without a provider, mark the affected product interaction blocked and arrange a provider-free fixture path; do not substitute generated model output.

The scoped image3 and negative-control results are not calibrated visual
acceptance; math/origins/width option effects remain unmeasured. They do not
substitute for desktop review. If intentionally rerun, see
`sh test/tools/check-math-images.sh` and its requirements in STP §2.2; do not
install packages or fetch assets as part of this checklist. No browser/KaTeX
runtime is part of product acceptance.

## 3. Execution record — fill in before testing

Do not prefill operator outcomes. Attach command output, screenshots only where approved, and notes with this record.

| Field | Operator entry |
|---|---|
| Acceptance session ID / date / start-end time / time zone | ______________________________ |
| Operator name and role; human reviewer name and role (identify user/product-owner separately) | ______________________________ |
| Independent reviewer (if any); relationship to implementation | ______________________________ |
| Source revision (`git rev-parse HEAD`), dirty/clean status, changed-path list, source/build artifact hashes | ______________________________ |
| Root/test build commands, profile, exit codes, logs; full-suite command, count and log | ______________________________ |
| Executable path/version/build identity and build date | ______________________________ |
| OS/distribution/version, desktop environment/window manager, GTK version | ______________________________ |
| Display server (Wayland/X11/Xvfb), monitor, resolution, refresh rate, display scale / device scale | ______________________________ |
| Locale, language, keyboard layout, timezone, text direction | ______________________________ |
| Theme, foreground/background colors, contrast settings | ______________________________ |
| Font configuration and bundled math-font provenance/hash | ______________________________ |
| Browser/accessibility bridge only if actually used; version and purpose | ______________________________ |
| Zoom/text scale and window size at each test point | ______________________________ |
| Fixture/session identity, how prepared locally, exact source hash, and replay/session provenance | ______________________________ |
| Commands actually run and their exit status; artifacts/log paths and hashes | ______________________________ |
| Deviations, interruptions, known defects, and environmental limitations | ______________________________ |

**Configuration validity:** ☐ recorded enough to reproduce  ☐ incomplete (BLOCKED)
**Readiness review against current STP/report:** ☐ open/not approved (BLOCKED for acceptance) ☐ separately approved; evidence/reference: ____________________

## 4. Controlled local formula set

Keep the dedicated test session isolated from user data. Use literal text below as the controlled source; do not retype, normalize whitespace, or substitute a model-generated variant. For the reported display case, preserve both LF line breaks. The approved pilot identifies it as `heat-balance-001` and records source SHA-256 `7c0b054ddefe208304f4a8829a71ea04b82f0b5130a2aa999dbc2a50f68c68cc` and display-delimited source SHA-256 `5b73b894f35e36a42d6fe34a4dbf9dc3f888a8066fe2c2b2712181cac5a8c1ac`.

**Exact reported formula source (display math):**

```tex
C_a\dot T_a =
H_o(T_o-T_a)+H_m(T_m-T_a)
+Q_{\mathrm{solar}}+Q_{\mathrm{internal}}-Q_{\mathrm{cool,sens}}.
```

Enter it using the app's approved math-delimiter interaction, with `$$` on its own line before and after the three source lines. Preserve those line breaks. Expected copied content is exactly the opening `$$`, newline, source above, newline, closing `$$` (including the final period and original LF line breaks). Verify against the hashes from the pinned pilot or compute and retain a hash of the copied byte sequence; be explicit whether a platform clipboard API changed line endings.

Use the following additional local controls, each in a separate fixture/message and with mode noted:

| ID | Exact formula source | Mode / purpose |
|---|---|---|
| F-01 | `\frac{a+b}{c}` | Inline fraction; structure and reading order |
| F-02 | `x^2_3` | Inline superscript and subscript |
| F-03 | `\sqrt{\frac{x}{y}}` | Nested radical/fraction |
| F-04 | `\lim_{x\to 0}\max(x)+\min(y)+\sin(z)+\log(t)` | Operators, limit, arrow and scripts |
| F-05 | `\begin{matrix}a&b\\c&d\end{matrix}` | Display array; rows, columns and cell order |
| F-06 | `\text{heat loss}+\mathrm{solar}` | Text/roman distinction |
| F-07 | `\hat{x}+\overrightarrow{xy}` | Accent/arrow; visible and structural handling |
| F-08 | `$x^2$` inside a fenced code block and `\frac{a}{b}` in ordinary prose | Markdown/code protection; only intended math delimiters render |
| F-09 | `\frac{a}` | Invalid input; visible, bounded, non-crashing fallback; exact source remains recoverable |
| F-10 | Exact reported formula above | Original reported display fixture; source/copy/replay |

For every formula compare the actual submitted source against the literal row. For F-08, enter the surrounding Markdown/code as literal text in the local fixture. If the app offers no provider-free way to load controlled assistant content, do not prompt a live provider just to obtain a test response: mark product-window steps blocked, attach only honestly labeled component-probe artifacts, and request a fixture-enabled rerun.

## 5. Operator procedure and results

Perform in a fresh, dedicated test session, with no real-provider dependency. For each row, record PASS/FAIL/BLOCKED/NOT RUN, what was observed, formula ID, artifact or log reference, and defect/action ID. A checkbox is a prompt, not evidence by itself.

### A. Baseline and visual behavior — `MATH-GUI-001`

| Step | Action and observable criterion | Result / evidence |
|---|---|---|
| A1 | Open the actual product conversation window at the recorded baseline size/theme. Confirm the controlled fixture and session identity. Do not use the standalone PNG as product UI. | ____________________ |
| A2 | Render F-10 as display math and F-01–F-07 in inline/display modes as applicable. Inspect symbols, scripts, fraction bars, radical, accents, arrows, braces/delimiters where exercised, array alignment, text-vs-math, baseline, clipping, and surrounding text. Record each discrepancy; visual similarity is not assumed by rendering success. | ____________________ |
| A3 | Use a known Markdown/code sample containing F-08. Confirm code remains literal/protected, only intended math is rendered, and surrounding text is intact. | ____________________ |
| A4 | Copy the rendered F-10 formula using the product's user-visible selection/copy action. Compare byte-for-byte to the expected display-delimited input; record clipboard text, encoding/line endings, and hash (redact unrelated clipboard data). Repeat F-01. No visual selection or accessible label substitutes for exact copied source. | ____________________ |
| A5 | Resize narrower and wider; change supported zoom/text scale and theme/foreground, then restore baseline. Check formula/text reflow, clipping, selection, contrast, and baseline. Record exact sizes/scales and before/after. Do not rescale comparison images to hide a mismatch. | ____________________ |
| A6 | Replay/reopen the same dedicated session. Confirm the formula still renders and its original source, delimiters, and line breaks remain recoverable. Compare against captured pre-replay source/hash. | ____________________ |
| A7 | Render F-09 and any deterministic invalid/unsupported fixture. Confirm error/fallback is visible, bounded and non-crashing; no content silently disappears; source can be copied. Record exact diagnostic and do not call fallback a successful render. | ____________________ |
| A8 | Repeat render/resize/replay at least once. Record any stale output, flicker, delay, missing glyph, or changed content. A single successful frame is not a timing or scheduling qualification. | ____________________ |

### B. Display LaTeX source access — `MATH-SOURCE-001`, REQ-MATH-012

Use the real product conversation window with controlled display fixtures. These
checks verify source access and ordinary GUI behavior only; they do not evaluate
semantic screen-reader math or establish complete accessibility.

| Step | Action and observable criterion | Result / evidence |
|---|---|---|
| B1 | While a display formula is pending, expand **LaTeX source**. Verify the text is read-only, selectable and byte-for-byte equal to the exact delimited input, including opening/closing delimiters, line breaks and whitespace. Record source and displayed-text hashes. | ____________________ |
| B2 | Repeat for a successfully rendered display formula and for invalid/unsupported input. The source remains available and exact in each state, regardless of rendering outcome. Record observed state and any mismatch. | ____________________ |
| B3 | Replace a display formula with a different controlled source. Verify the expander updates to the replacement's exact delimited source and does not retain stale prior text. | ____________________ |
| B4 | Use keyboard navigation/selection and the focused component's copy action as available. Record actual behavior and verify copied source. Keep inline exact-source copy checks separate under A4/MATH-GUI-001. | ____________________ |
| B5 | Repeat at the recorded enlarged scale, narrower window and after session replay. Confirm source remains readable/selectable and exact. Record layout or focus problems without treating this as a screen-reader semantics test. | ____________________ |

**Do not mark B complete** if the real product window could not be loaded with controlled content, any state or replacement was not checked, or source fidelity was inferred only from a bitmap/internal semantic probe. Record BLOCKED/NOT RUN rather than pass. This procedure makes no claim that raw LaTeX is semantic math or screen-reader accessible.

## 6. Evidence capture and discrepancy handling

For each step retain only appropriately approved test artifacts: timestamped operator notes; exact input and computed hash; build/source identity; command and exit status; relevant application observations; and screenshot/log paths and hashes where permitted. Do not include credentials, unrelated conversation content, personal clipboard contents, or private user data. A screenshot does not prove exact selectable-source fidelity; verify the actual text and copied bytes separately.

Report every discrepancy against the governing case/requirement and exact configuration. Assign PASS only when the observed criterion is met and evidence is retained; FAIL for an observed adverse result; BLOCKED when preconditions, readiness, tooling, product fixture, or approved criterion prevent judgment; NOT RUN when deliberately not executed. Do not mark a known STP defect as accepted without an individually authorized disposition in the governing change process. Reruns after source changes require new build/revision identifiers and fresh evidence. A correction does not erase prior failures.

| Case/step | Status (PASS/FAIL/BLOCKED/NOT RUN) | Evidence reference/hash | Deviation/defect ID and owner/action | Retest revision/result |
|---|---|---|---|---|
| Build/regression gate |  |  |  |  |
| MATH-GUI-001 A1–A8 |  |  |  |  |
| MATH-SOURCE-001 B1–B5 |  |  |  |  |
| Exact-source copy |  |  |  |  |
| Replay/source persistence |  |  |  |  |

## 7. Human review disposition — leave blank until performed

**Operator's conclusion and evidence basis:**
______________________________________________________________________________

**Human reviewer conclusion; observed behavior, limitations, and rationale:**
______________________________________________________________________________

**Known open failures/blockers consulted in current report; why readiness permits or prevents acceptance:**
______________________________________________________________________________

**Overall manual protocol status (choose one):** ☐ PASS ☐ FAIL ☐ BLOCKED ☐ NOT RUN
**Overall REQ-MATH-012 source-access status (choose one):** ☐ PASS ☐ FAIL ☐ BLOCKED ☐ NOT RUN
**Component acceptance:** ☐ NOT ACCEPTED / PENDING ☐ separately accepted by authorized user; evidence/change record: ____________________

A PASS for these manual checks means only that the recorded checks passed for the recorded build, environment, fixtures and reviewer. It does **not** close final qualification, the full product test denominator, known failures, P1 readiness, or separate user acceptance. Until outstanding approved gates are resolved and an authorized human decision is recorded, the overall project result remains **NOT COMPLETE / ACCEPTANCE PENDING**.

**Review limitation:** This checklist was prepared by an agent working in the project and has not received independent QA or user/human acceptance review. No execution, human visual acceptance or complete accessibility acceptance is claimed by this document.

## 8. Traceability and controlled references

- [SRS-MATH v1.2](../requirements/native-math-compatibility.md): REQ-MATH-011, REQ-MATH-012, REQ-MATH-013 and REQ-MATH-014.
- [STP/STD-MATH v0.12](native-math-compatibility-tests.md): §§2.2, 3.2–3.4, 4.1–4.2, `MATH-GUI-001`, `MATH-SOURCE-001`, §6 traceability, §7 blockers.
- [Native math parity test report](native-math-parity-test-report.md): current observed regression, geometry, image, differential, coverage and open-qualification evidence. Recheck for updates before every execution; older dated snapshots are historical.
- Pilot source: `test/fixtures/math-compatibility/pilot.json`, case `heat-balance-001`. The pilot is not the full approved corpus.
- Focused local probe: `test/tools/check-native-math.sh`. Conversation source behavior has AUnit coverage; no dedicated accessibility probe exists. These do not establish whole-product manual acceptance.

**Execution record is intentionally unfilled.**
