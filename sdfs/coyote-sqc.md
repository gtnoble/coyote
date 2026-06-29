# Component Development Log — coyote_sqc

**Components:** All `Coyote_SQC.*` packages, `Coyote_Renderer.*`

**Source files:** `src/coyote_sqc/*.ads/.adb`, `src/coyote_sqc_main.adb`,
`src/coyote_renderer/*.ads/.adb`

---

## Design Rationale

### Why coyote_sqc is a separate executable

coyote_sqc reads coyote session JSONL files but does not interact with the
LLM agent runtime at all. Separating it as a standalone executable means:
- It can be run without plan9port or an acme instance.
- It cannot accidentally write to session files (the session store is not
  linked into the sqc binary).
- The GTK event loop in coyote_sqc is simpler than in the main coyote GUI:
  it has no agent task, no streaming callbacks, and no prompt queue.

### Workspace file (.sqcw) as the source of chart configuration

All user-defined configuration (date range, chart visibility, per-chart
settings, setup interval, comments) is stored in a `.sqcw` JSON file separate
from the session data. Session JSONL files are treated as read-only input.
This separation means:
- Multiple `.sqcw` files can reference the same session directory with
  different chart configurations.
- Upgrading the session format does not invalidate existing workspace files
  (the parser handles both v1 and v3).
- The user can share or version-control their `.sqcw` file independently
  of their session data.

### Control chart parameter estimation from the setup interval

All control limits (UCL, LCL, center line) are estimated from the *setup
interval* — a user-defined contiguous range of sessions. This matches
standard SPC practice: the process is assumed to be in statistical control
during the setup interval; limits computed from it are used to judge
subsequent observations. Points within the setup interval are always plotted;
only points outside it are judged against the limits.

### Box-Cox transform for I/MR charts

I charts (Individual Value charts) assume approximate normality. Many LLM
session metrics (token counts, cost) are right-skewed. The per-chart settings
dialog allows the user to select a variance-stabilising transform (log, sqrt,
Anscombe, arcsinh, Freeman-Tukey, Box-Cox). Box-Cox λ can be estimated via
MLE from the setup interval data or fixed manually. The transform is applied
to the data before computing control limits; the chart Y-axis shows
back-transformed values so the scale is interpretable.

### Shared `Coyote_Renderer` library

`Coyote_Renderer.Markup` (Pango markup generation) and
`Coyote_Renderer.Session_View` (session replay rendering) are shared between
the main coyote GUI frontend and coyote_sqc's detail panel. This avoids
duplicating the libcmark-gfm integration and the session JSONL replay logic.


### Percentile bootstrap for two-set CI

The requirements specify the percentile bootstrap (B = 10 000, seed 12 345)
rather than the bias-corrected and accelerated (BCa) bootstrap.  The BCa
bootstrap requires computing an influence function for each statistic, which
is non-trivial to implement correctly for the median and adds a dependency on
jackknife resampling.  For typical session counts (tens to hundreds of points
per set), the percentile bootstrap produces CIs that are accurate enough for
the intended exploratory use case.  The fixed seed and B = 10 000 ensure
reproducible, deterministic output — the same selection always produces the
same CI bounds.  Computation is synchronous on the GTK main loop thread
because the typical dataset is small (< 500 data points total); no
asynchronous machinery is needed.

### Two-set selection model

Set A is the existing single selection (unchanged interaction model from §9.1).
Set B is added as a parallel UUID set in `App_State`.  An "Edit Set B ☐"
toolbar toggle redirects all selection actions (click, shift+click,
shift+drag) to Set B when active.  This avoids introducing new modifier keys
or multi-step workflows; the user's existing selection habits transfer directly
to both sets.  Set A continues to serve as the authoritative selection for all
non-comparison operations (setup interval, bulk comments, Y-Fit).

### Overlapping histogram bin unification

When two sets are compared in §10.3, bins are computed from the *combined*
range of both sets using the Freedman-Diaconis rule applied to the pooled
sample.  Both sets use identical bin boundaries.  This ensures the two bar
series are visually comparable: bars in the same bin represent the same value
range.  Using per-set bin boundaries would make the bars incommensurable and
defeat the purpose of the overlap.

---

## Key Constraints

- `Coyote_SQC.Session_Parser` must never write to session JSONL files.
  It is strictly read-only.
- All GTK operations in coyote_sqc execute on the main Ada task (the GTK main
  loop). The application is single-threaded; there is no agent task.
- The workspace file is written atomically: the new content is written to a
  `.sqcw.tmp` file and then renamed to the final `.sqcw` path. This prevents
  a partial write from corrupting the workspace.

---

## Unit Test Coverage Notes

- `Coyote_SQC.Session_Parser`: covered by AUnit tests using JSONL fixtures
  in `test/fixtures/sqc/` — v1 format, v3 format, thinking sessions,
  compaction sessions.
- `Coyote_SQC.Statistics.*`: covered by AUnit tests — c4(n) table values,
  Xbar/s/p/I/MR limit calculations, bootstrap CI computation (point estimates,
  CI coverage, N/A cases, reproducibility).
- `Coyote_SQC.Workspace`: covered by AUnit tests — load/save round-trip,
  version migration.

---

## Open Questions / Future Work

- The Hartigan dip test implementation uses a direct O(n²) algorithm.
  For session counts > 1000 this may be slow. Consider an approximate
  version or an O(n log n) algorithm.
- Workspace version 10 (`analyzeAllDirectories`) is the current version.
  Future schema changes should increment the version and add migration logic
  in `Coyote_SQC.Workspace.Load`.
- Two-set comparison (PCR-016): complete.  `Coyote_SQC.Statistics.Bootstrap`
  (ads + adb, 5 AUnit tests), `App_State` Set B fields, toolbar "Edit Set B"
  toggle (`Edit_Set_B_Mode`; canvas selection routed to `Set_B` when active;
  orange halos on canvas for Set B points), View menu "Clear Both Sets" item
  (clears both sets, resets toggle, refreshes panel), `Histogram_Canvas.Refresh_Two_Set`
  (two-series overlay histogram: shared FD bins, blue Set A / orange Set B bars
  at 0.5 opacity, CL/UCL/LCL overlays, legend), `Build_Two_Set_View` in
  Detail_Panel (set headers, overlapping histogram, 9-row × 3-col summary
  statistics including N/mean/median/std dev/KS/runs/dip for each set,
  Bootstrap 95% CI frame for mean diff, median diff, SD ratio, Add Comment
  frame), `Update_Menu_States` sensitivity for `Clear_Both_Sets_Item`.
  Build passes, 665 tests all pass.
- **PCR-017 (stack-overflow fix, 2026-06-06):** All dynamically-bounded
  internal arrays in `Bootstrap.Compute` (`A_Star`, `B_Star`) and
  `Statistics.Tests` (`Sorted` copies in KS/Runs functions; `Sorted_V`,
  `Sim_V` in dip test; `Mn`, `Mj`, `Gcm`, `Lcm` in `Compute_Dip`) converted
  from stack-allocated `Long_Float_Array` / `array (1..N) of Integer` to
  heap-backed `Ada.Containers.Vectors` container objects.  Public API surfaces
  (`Long_Float_Array` parameter types) are unchanged.  Dead private code
  removed: `Quick_Sort`, `Sort_LF`, three array-form stat helpers from
  bootstrap body; insertion-sort `Sort` from tests body.  `LF_Sorting.Sort`
  (Generic_Sorting instantiation) used throughout both files.  Build clean;
  665 tests pass.
- **PCR-018 (stale-widget Queue_Draw fix, 2026-06-06):** `STORAGE_ERROR`
  (SIGSEGV) in `Histogram_Canvas.Refresh_Two_Set` caused by calling
  `Queue_Draw` on a destroyed `Gtk_Drawing_Area`.  Root cause: `Build`
  creates a new widget each call and stores it in the package-level
  `The_Widget`; when `Detail_Panel.Refresh` tears down the old widget
  container it destroys the underlying GObject, but `The_Widget` remains
  Ada-non-null.  `Refresh_Two_Set` (called before `Build`) then passed
  the stale pointer to `Queue_Draw`.  Fix: added private
  `On_Widget_Destroy` callback in the package body that nulls `The_Widget`
  when the GObject is finalised; connected via `The_Widget.On_Destroy`
  inside `Build`.  The existing `if The_Widget /= null` guards in both
  `Refresh` and `Refresh_Two_Set` then correctly suppress stale draws.
  No test changes (no new public API).  Build clean; 665 tests pass.
- **PCR-019 (dangling stats-label fix, 2026-06-06):** `STORAGE_ERROR` (SIGSEGV)
  in `Refresh_Histogram_If_Multi` at `Stats_Mean_Key_Lbl.Set_Text` when switching
  charts while Set B is non-empty.  Root cause: `Refresh` nulls `Inner_Box`,
  `Comment_Entry`, and `Multi_Comment_Entry` after `Panel_Box.Remove`, but the
  ten `Stats_*_Lbl` / `Stats_*_Key_Lbl` package variables were not nulled.
  `Build_Single_View` and `Build_Multi_View` reset them inside their stats-grid
  blocks; `Build_Two_Set_View` did not.  After a two-set rebuild the labels held
  freed GTK widget pointers; the `!= null` guard in `Refresh_Histogram_If_Multi`
  passed and `Set_Text` dereferenced freed memory.  `Refresh_Histogram_If_Single`
  was identically exposed.  Fix (two sites in
  `coyote_sqc-ui-detail_panel.adb`): (1) in `Refresh`, null all ten stats-label
  variables immediately after `Multi_Comment_Entry := null` — the primary fix,
  correct architectural home; (2) at the top of `Build_Two_Set_View`'s body,
  add the same ten null assignments — belt-and-suspenders, makes the three
  view-builder procedures consistent.  No test changes (no new public API).
  Build clean; 665 tests pass.

### Quantile Control Chart — SRS and SDD (2026-06-13)

### Quantile Control Chart — Implementation start (2026-06-13)

**New files created:**
- `src/coyote_sqc/coyote_sqc-statistics-quantile_cc.ads` — public spec: two-stage
  bootstrap (B=100 000), five R-type-7 quantile computation, per-component
  Bonferroni-corrected limit extraction (rank 27/99 974 at α=0.0027 family-wise),
  OOC detection, lazy caching by subgroup size `n_i`
- `src/coyote_sqc/coyote_sqc-statistics-quantile_cc.adb` — full body: 31-bit LCG
  (glibc parameters) for reproducible RNG with fixed seed 54 321, generic array
  sort for quantile ordering, vector sort for bootstrap distribution ordering,
  `Build_Distribution` with two-stage resampling (random session → n_i draws with
  replacement → five quantiles), cache vector with linear lookup by n_i

**Enumeration and metadata (`coyote_sqc-charts.ads/.adb`):**
- Four new `Chart_Kind` values appended: `Turn_Tokens_Quantile`,
  `Tool_Call_Tokens_Quantile`, `Thinking_Tokens_Quantile`, `Tool_Call_JSD_Quantile`
- `Is_Quantile_CC_Chart : Boolean` field added to `Chart_Properties`; every existing
  chart kind gets `False` via Perl batch insertion; four new kinds get `True`
- Left-panel group `"Quantile Profiles" / "Quantile Profiles"` with four chart
  labels; comment updated from "forty-eight" to "fifty-five charts"

**Application state (`coyote_sqc-app.ads/.adb`):**
- `Quantile_Point` record added: `Session_Id`, `Session_Index`, `Session_Time`,
  `N` (subgroup size), `Excluded`, `In_Setup`, `Has_Comment`, `Values`
  (`Quantile_Array`), `Limits` (`Quantile_Limits_Array`), `OOC_Comps`
  (`Quantile_Component_Set`), `Has_OOC`
- `Quantile_Point_Vectors` container instantiation added
- `Chart_Data` extended: `Quantile_Points : Quantile_Point_Vectors.Vector`,
  `Quantile_Cache : Quantile_CC_Cache`
- `Chart_Point` extended: `Is_OOC_From_Quantile : Boolean` — set when any
  Quantile CC flag a session as out-of-control
- `with Coyote_SQC.Statistics.Quantile_CC` added to spec
- `Compute_Session_Stat`: stub for all four Quantile CC kinds (`Excluded := True`)
- `Descriptor`: four new entries mapping subgroup accessors (`Sub_Output_Tokens`,
  `Sub_Tool_Tokens`, `Sub_Thinking_Tokens`, `Sub_JSD_S`) and exclusion rules
  (`No_Exclusion`, `Zero_Tool_Call_Turns`, `Zero_Thinking`, `Zero_Tool_Call_Turns`)
- `Recompute_Chart`: ~170-line Quantile CC path (gated by
  `Props.Is_Quantile_CC_Chart`) that:
  - Builds a reference pool by flattening subgroup vectors from eligible
    setup-interval sessions into a single `Long_Float_Array` (1 MiB max) with
    per-session offset/length index vectors
  - Applies per-chart exclusion rules (`Zero_Thinking`, `Zero_Tool_Call_Turns`)
  - For each session: extracts subgroup values, sorts and computes five quantiles
    via `Compute_Quantiles`, looks up cached bootstrap distribution by `n_i`,
    extracts Bonferroni-corrected limits via `Extract_Limits`, flags OOC
    components and session status
  - Returns early from normal `Chart_Point` loop
  - `Clear_Cache (CD.Quantile_Cache)` called at start to flush stale distributions
- `Recompute_Charts`: OOC propagation block after `Update_Menu_States` — collects
  all session UUIDs flagged `Has_OOC` on any Quantile CC chart, then sets
  `Is_OOC_From_Quantile` on matching `Chart_Point` entries in every non-Quantile
  chart kind
- `Chart_Point` aggregate extended with `Is_OOC_From_Quantile => False`
- `Has_Comment` call restructured to inline call with comma for new field

**Statistics (`coyote_sqc-statistics.adb`):**
- Two `Estimate_Parameters` case statements updated with null handlers for the
  four Quantile CC chart kinds (`null; -- Quantile CC uses bootstrap` and
  `Parameters.Parameters_Valid := False;`)

**Build status:** Clean build with no errors.  All 670 existing AUnit tests
pass (zero regressions).

### Quantile Control Chart — Implementation complete (2026-06-13)

All remaining work from the 2026-06-13 start log is now complete:

**Canvas rendering** (`coyote_sqc-ui-chart_canvas.adb`):
- Quantile helpers (`Quantile_Point_X`, `Vis_Quantile`) at package level
  for x-coordinate and date-range visibility checks
- On_Draw: `Vis_Quantile` inlined at the Hit_Test and Rubberband_Select
  call sites (local scope issue)
- Step 2b: Quantile-specific setup-interval yellow band (parallel to
  regular Points band, keyed on `Quantile_Points`)
- Step 5b (replaces steps 3–6 for Quantile CC): renders 5 horizontal
  component lines (min/Q1/med/Q3/max) at half-widths 6/10/14/10/6 px,
  each inside a hollow control-limit box; drawn in order median→Q1/Q3→
  min/max so narrower bars overdraw wider ones
- Color selection per §12.7: black/gray (in-control/no-comment),
  green (in-control/comment), red (OOC/no-comment), orange (OOC/comment)
- Log Y guard: components with non-positive values skipped
- Step 6a: setup-interval yellow ring, Set A blue halo, Set B orange
  halo — each drawn as a Cairo rectangle around the bounding box of the
  full diagram (3 px outside, 2 px stroke)
- Hit testing: checks vertical extent of each diagram's components;
  returns the session UUID on overlap
- Rubber-band selection: analogously checks diagram bounding-box
  intersection with the selection rectangle

**Quantile CC `with` added:** `Coyote_SQC.Statistics.Quantile_CC` imported
in chart_canvas.adb after the Toolbar import.

**Hover tooltip** (`coyote_sqc-ui-hover_tooltip.adb`):
- `Build_Stats_Line` function replaces the old `Limits_Line` constant;
  dual-mode logic: when `QP_Found` is True (Quantile CC chart), shows
  `n = N turns` plus per-component values with UCL/LCL and a `← out-of-control`
  annotation for components flagged OOC; when `Pt_Found` (regular chart),
  shows CL/UCL/LCL as before
- `Quantile_CC` import added; `QP_Found`/`QP` declarations inserted
  after the existing `Pt`/`Pt_Found` declarations
- Quantile-Point lookup block inserted after the Chart-Point lookup block

**Bug fixes during implementation:**
- LCG overflow: `LC_State.X` changed from `Integer` to `Long_Long_Integer`,
  `Modulus` likewise; multiplication now uses `Long_Long_Integer(1_103_515_245)`
  to avoid intermediate overflow on 32-bit `Integer`
- 0-based index: `Random_Natural(K)` → `Random_Natural(K) + 1` so the
  session bucket index is 1-based as `Pool_Offsets.Element` expects

**Unit tests** (13 new, all passing):
- `test/src/coyote_sqc_quantile_cc_tests.ads` — test suite spec using
  `AUnit.Test_Fixtures.Test_Fixture`
- `test/src/coyote_sqc_quantile_cc_tests.adb` — 13 tests using a
  `Build_Small_Dist` helper with `Small_B = 200` to keep bootstrap
  computation fast (≈ 2 ms per test)
- `test/src/test_suites.adb` — `with` clause and `SQC_Quantile_CC_Caller`
  instantiation added; 13 test registrations appended after the
  integrity-test block

**Build status:** Clean build; all 683 AUnit tests pass (0 failures,
0 unexpected errors).  No regressions.
adaptation for quantile points, unit tests (13 statistical + 7 rendering
tests per §14.6–§14.7).


Added SRS-SQC §5.18 (Quantile Control Chart — Bootstrap Methodology), four
new chart definitions (§6.42–6.45: Turn Tokens, Tool Call Tokens, Thinking
Tokens, and Tool Call JSD Quantile Control Charts), §7.3.2a (Quantile CC
Rendering), §7.3.3 (per-component coloring rows), and §8.3a (Quantile CC
Hover tooltip). Chart count increased from 51 to 55. Left-panel group
layout updated with new "Quantile Profiles" top-level group.

Bootstrap methodology: two-stage resampling — sample a random setup-interval
session, then sample n_i observations with replacement from that session's
per-turn values, compute five R type 7 quantiles. B = 100 000 replicates
per unique n_i, cached. Bonferroni correction for 5 simultaneous
comparisons (α_B = α/5, tail rank 27 of 100 000). Fixed seed 54 321.
Box-Cox and estimation method not applicable. Session-level OOC flag
propagates to all other charts.

SDD-SQC updated: added `Coyote_SQC.Statistics.Quantile_CC` package to
architecture (§4), four new `Chart_Kind` enum values (§6.7),
`Is_MR_Chart` and `Is_Quantile_CC_Chart` fields to `Chart_Properties`
(§6.7a), `Coyote_SQC.Statistics.Quantile_CC` package specification with
`Compute_Quantiles`, `Build_Distribution`, `Extract_Limits`, `Is_OOC`,
`Session_Is_OOC`, `OOC_Components`, caching strategy, and OOC propagation
(§7.19), rendering pipeline step 6a for quantile diagram rendering (§12.6),
color rows in §12.7, and two new test suites in §14.6–§14.7.

12 new test requirements added to SRS-SQC §15.6; 16 new test cases specified
in SDD-SQC §14.6–§14.7.

### 2026-06-14 — Quantile CC Log Y Support

**Changes:**
- `coyote_sqc-app.adb` — `Y_Fit`: added Quantile CC path that collects
  component values (min, Q1, median, Q3, max) and UCL/LCL limits from
  `Chart_Data.Quantile_Points`. In Log Y mode, ≤0 values are skipped.
- `coyote_sqc-ui-chart_canvas.adb` — Setup/Selection/Set B diagram halos:
  added Log Y guards to component iteration so that non-positive UCL/LCL
  values (which `Data_To_Screen_Y` maps to an off-screen sentinel in Log Y
  mode) are skipped when computing the bounding box.
- `coyote_sqc-ui-chart_canvas.adb` — Rubber-band selection for Quantile CC:
  added Log Y guards to component iteration.

**Requirements:** SRS-SQC §5.18 (new §5.18a "Log Y-Axis Scaling"),
§7.3.2a (Log Y mode rendering paragraph), §15.6 (two new test requirements).
**Design:** SDD-SQC §12.4 (Y-Fit updated to note Quantile CC support).
**Tests:** 687 tests, 0 failures, 0 unexpected errors. No regressions.

### 2026-06-15 — Quantile CC Lozenge Control Limits

**Design decision:** Changed quantile control-limit box shape from a flat
rectangle to a lozenge (rectangular body with triangular end caps).  The
triangular tips point to the UCL and LCL values, making it unambiguous which
limit belongs to which component when limits overlap.  The rectangular body
spans from `UY + TH` to `LY - TH` where `TH = half_width × 0.5`.

**Rationale:** The prior flat-rectangle shape was visually ambiguous when two
component limits overlaid (e.g. Q3's UCL coinciding with median's LCL).  The
lozenge's triangular end caps give each limit a distinct visual identity at
its exact numeric position, improving resolvability without requiring colour
or pattern changes.

**Implementation:** Replaced `Cairo.Rectangle` with a six-vertex closed path
(`Move_To` → 5× `Line_To` → `Close_Path` → `Stroke`) in the Quantile CC
rendering pipeline.  No changes to statistical computation, limit estimation,
or the bootstrap procedure.

**Files changed:**
- `src/coyote_sqc/coyote_sqc-ui-chart_canvas.adb` — control-limit drawing
- `requirements/coyote-sqc-requirements.md` — §7.3.2a, §7.3.3, §15.6
- `design/coyote-sqc-design.md` — §12.6 step 6a, §12.7
- `plan/problems.md` — PCR-028

### 2026-06-15 — Adaptive Anchor Interpolation for Quantile CC

**Changes:**
- `coyote_sqc-statistics-quantile_cc.ads` — Replaced `Interp_Delta`, `Interp_C`,
  `Interp_Discrete_Max` with `Adaptive_Discrete_Max`, `Adaptive_Tolerance_Rel`,
  `Adaptive_Tolerance_Abs`.  Extended `Quantile_CC_Cache` with `Anchors`,
  `Tolerance_Rel`, `Tolerance_Abs` fields.  Rewrote `Interpolate_Limits`
  documentation.
- `coyote_sqc-statistics-quantile_cc.adb` — Removed body-level `Anchors`
  variable and `Ensure_Anchors_Up_To` procedure with its fixed-grid logic.
  Added `X_Of_N`, `N_Of_X`, `X_Midpoint` coordinate helpers,
  `Interpolate_From_Anchors` (linear interpolation in `x = 1/√n` space
  between two anchors), `Max_Limit_Error`, `Max_HW`, `Tolerance_For`,
  `Exact_Limits_At` helpers, `Ensure_Anchors_Cover` with recursive
  `Refine_Gap` procedure.  Rewrote `Interpolate_Limits` to use adaptive
  bisection: for `n ≤ 16`, exact bootstrap at every integer; for `n > 16`,
  anchors are placed by bisecting gaps in `x`-space and testing the
  x-midpoint for error against tolerance, subdividing when exceeded.
  Bounding anchors are used for linear interpolation.

**Design decision:** Replaced the a-priori fixed-anchor scheme (heuristic
constants C=0.5, δ=0.15) with adaptive bisection in `x = 1/√n` space.
Anchors are placed only where the data demands them; the interpolation
error is measured, not assumed.  Tolerance is 5% of half-width with a
1-token absolute floor.  The algorithm guarantees no interpolated limit
differs from its exact bootstrap counterpart by more than the tolerance.
Linear interpolation in `x`-space replaces origin-scaling; centre-line
limits are now interpolated rather than held piecewise-constant.

**Requirements:** SRS-SQC §5.18 "Interpolated Limits" rewritten.
**Design:** SDD-SQC §7.19 "Interpolated Limits" rewritten.
**Tests:** 688 tests, 0 failures, 0 unexpected errors.  No regressions.


---

### 2026-06-16 — Mutual Information diversity charts (requirements & design)

**Motivation:** Added a second measure of consecutive tool-call diversity based on
compression-based mutual information.  The MI statistic uses zlib streaming
deflate at maximum compression (level 9) with dictionary pre-loading to
approximate the mutual information between argument strings of successive
tool calls:
  MI_k = (|compress(C, dict=∅)| − |compress(C, dict=Q)|
          + |compress(Q, dict=∅)| − |compress(Q, dict=C)|) / 2
where |compress(X, dict=D)| is the compressed size of X with dictionary D
pre-loaded into the compressor.  This complements the existing JSD-based
diversity charts by providing an entropy-based measure that scales naturally
with string length and does not require tokenization.
with string length and does not require tokenization.

**Requirements:** SRS-SQC §5.19 (MI statistics), §5.20 (session total MI scalar),
§6.46–6.51 (six new chart definitions).  Chart count advanced from 55 to 61.
§5.8 Box-Cox chart list updated to include MI Xbar/S pair.

**Design:** SDD-SQC §7.14b (compression-based MI), §7.14c (session total MI scalar).
New package `Coyote_SQC.Statistics.MI` with `Compute_MI_Values` procedure.
Six new `Chart_Kind` enum values: `Tool_Call_MI_Xbar`, `Tool_Call_MI_S`,
`Session_Tool_Call_MI_Sum_I`, `Session_Tool_Call_MI_Sum_MR`,
`Session_Tool_Call_MI_Sum_EWMA`, `Tool_Call_MI_Quantile`.
Three new `Session_Metrics_Record` fields: `Per_Consecutive_Tool_MI`,
`N_Consecutive_Tool_MI_Pairs`, `Total_Tool_Call_MI`.

**Tests:** 11 MI unit tests added to SRS-SQC §15.6.  No implementation yet.

**Chart layout:**

| Chart kind | Group | Chart type |
|---|---|---|
| `Tool_Call_MI_Xbar` | Tool Call Behavior / Mutual Information Diversity | Xbar |
| `Tool_Call_MI_S` | Tool Call Behavior / Mutual Information Diversity | s |
| `Session_Tool_Call_MI_Sum_I` | Tool Call Behavior / Mutual Information Diversity | I |
| `Session_Tool_Call_MI_Sum_MR` | Tool Call Behavior / Mutual Information Diversity | MR |
| `Session_Tool_Call_MI_Sum_EWMA` | Tool Call Behavior / Mutual Information Diversity | EWMA |
| `Tool_Call_MI_Quantile` | Quantile Profiles | Quantile CC |

**Files changed:**
- `requirements/coyote-sqc-requirements.md` — added §5.19, §5.20, §6.46–6.51; 11 test entries; "55" → "61" (6 occurrences); updated §5.8, §5.18, §7.2 left panel
- `design/coyote-sqc-design.md` — added §7.14b, §7.14c; 6 enum values; 3 metrics fields; 6 chart table rows; "55" → "61"; updated §7.10, Quantile CC exclusion rules
- `plan/test-plan.md` — added `coyote_sqc_mi_tests.adb` inventory row; baseline entry

---

### 2026-06-16 — MI Diversity Charts Implementation

**Status:** Implemented.

**Packages added:**
- `src/coyote_sqc/coyote_sqc-statistics-mi.ads` — `Compute_MI_Values` procedure spec
- `src/coyote_sqc/coyote_sqc-statistics-mi.adb` — compression-based MI per-argument
  computation using zlib streaming deflate (level 9) with dictionary
  pre-loading.  Implements the same per-key argument extraction pattern as
  the JSD package.  Negative MI_k values are retained (not clamped);
  both-empty keys skipped.  Supports the same JSON object and fallback
  extraction paths as the JSD companion.
- `src/coyote_sqc/coyote_sqc-zlib.ads` / `.adb` — thin binding: streaming deflate
  with dictionary support (`Init_Stream`, `Set_Dict`, `Compress_Stream`,
  `Free_Stream`, `Compress_With_Dict`) plus `compressBound` and `compress2`
  from system zlib via `Interfaces.C`.
- `test/src/coyote_sqc_mi_tests.ads` / `.adb` — 13 unit tests

**Packages modified:**
- `coyote_sqc-data_model.ads` — added `Per_Consecutive_Tool_MI`,
  `N_Consecutive_Tool_MI_Pairs`, `Total_Tool_Call_MI` fields to
  `Session_Metrics_Record`
- `coyote_sqc-charts.ads` / `.adb` — 6 new `Chart_Kind` enum values;
  6 new `Properties` entries; "fifty-five" → "sixty-one"
- `coyote_sqc-metrics.adb` — MI pair computation loop and sum accumulator
- `coyote_sqc-statistics.adb` — MI chart cases in `Estimate_Parameters`
  (accumulation + finalization phases)
- `coyote_sqc-app.adb` — `Obs_Tool_MI_Sum` and `Sub_MI_LF` accessors;
  `Compute_Session_Stat` MI Xbar/S cases; `Descriptor` MI entries;
  `Recompute_Chart` MR/EWMA list entries and Box-Cox Xbar/S transform list
- `test/src/test_suites.adb` — `Coyote_SQC_MI_Tests` registration and
  `SQC_MI_Caller` instantiation; 13 test procedures registered

**Test baseline:** 701 tests, 0 failures.

### 2026-06-16 — PCR-030: MI Nested-Loop Hang Fix

**Problem:** Loading a workspace hung with the MI chart feature active (commit
`4e7aae2`).  The MI computation block and its summation loop were mistakenly
placed inside the body of the JSD sum `for` loop, causing O(N²) complexity:
each of the N iterations of the JSD sum loop walked all N tool-call pairs and
performed zlib deflate (level 9) compressions.  For a moderate number of tool
calls this saturated the CPU with N² compress2 calls.

**Fix:** Moved the MI compute block and MI sum loop from inside the JSD sum
`for` loop's body to after its `end loop;`, restoring O(N) complexity.  Added
a blank line before `return M` for readability.  See PCR-030 in
`plan/problems.md` for full details.

**Files changed:** `src/coyote_sqc/coyote_sqc-metrics.adb`
**Build:** Clean.  **Tests:** 701 tests, 0 failures, 0 regressions.


### 2026-06-17 — PCR-032: MI Xbar/S Centerline Used Wrong Data Source

**Problem:** The centerlines (Grand_Mean) and Pooled_S for `Tool_Call_MI_Xbar`
and `Tool_Call_MI_S` charts were computed from JSD similarity values
(`Per_Consecutive_Tool_S`) rather than MI values (`Per_Consecutive_Tool_MI`).
The `when` branch in `Estimate_Parameters` (accumulation phase) merged MI chart
kinds with JSD chart kinds, applying the wrong dataset to MI charts.  JSD charts
were unaffected.

**Fix:** Split `Tool_Call_MI_Xbar | Tool_Call_MI_S` into a separate `when`
branch in the accumulation phase, using `M.N_Consecutive_Tool_MI_Pairs` and
`M.Per_Consecutive_Tool_MI`.

**Files changed:** `src/coyote_sqc/coyote_sqc-statistics.adb`
**Build:** Clean.  **Tests:** 713 tests, 0 failures, 0 regressions.

### 2026-06-17 — Quantile CC Bonferroni Checkbox (SRS/SDD)

**Feature:** Added a workspace-level `Quantile_Bonferroni` checkbox
(boolean, default `true`) that controls whether Bonferroni multiplicity
correction is applied to quantile control chart limits.  When unchecked,
each of the five quantile components is tested at the unadjusted
α = 0.0027, widening limits and increasing detection sensitivity at the
cost of a higher family-wise false-alarm rate.

**SRS changes** (`requirements/coyote-sqc-requirements.md`):
- §4.6 Workspace Record: added `Quantile_Bonferroni` field
- §5.18: rewrote Bonferroni correction section with enabled/disabled
  subsections and limit formulas for both modes
- §13.5: added checkbox description to Workspace Settings Dialog
- §15.6: added 3 test requirements (disabled mode, workspace round-trip,
  backward compatibility)

**SDD changes** (`design/coyote-sqc-design.md`):
- §6.9 Workspace_Record: added `Quantile_Bonferroni : Boolean := True`
- §7.19: added `Bonferroni_Enabled` parameter to `Extract_Limits`
  (default `True`) and supporting comment
- §9.2: added `quantileBonferroni` to JSON schema
- §9.3: added version-migration note (absent → default `true`)
- §11.11: added checkbox description to Workspace Settings Dialog

**Backward compatibility:** No workspace version bump.  Workspace files
lacking the `quantileBonferroni` field load with the default `true`
(Bonferroni enabled), preserving the behaviour of all existing saved
**Implementation complete** as of 2026-06-17.  9 new tests pass, all 713 existing tests green.  No workspace version bump (backward compatible — absent `"plotMethod"` defaults to `"classical"`).


### 2026-06-17 — Robust Plot Method for Plotted Points (SRS/SDD)

**Feature:** Added a per-chart `Plot_Method` setting that controls whether
plotted session statistics on Xbar and s charts use classical (mean /
sample s) or robust (median / Qₙ) within-session estimators.  This is
independent of the `Estimation_Method` setting, which controls the control
limits.  The four combinations (classical/classical, classical/robust,
robust/classical, robust/robust) are all valid.

**SRS changes** (`requirements/coyote-sqc-requirements.md`):
- §4.7a Chart Settings Record: added `Plot_Method` field to the table
- §5.11a: new section "Robust Per-Session Statistics for Plotted Points"
  describing the two plot methods, their independence from
  Estimation_Method, Box-Cox interaction, and the four valid combinations
- §13.6 Chart Settings Dialog: new "Plot Method" expander section
  (Xbar/s charts only) with drop-down selector and independence note
- §15.6: added 9 test requirements (Xbar median-vs-mean, s chart Qₙ,
  workspace round-trip, I/MR/EWMA/p/Quantile CC non-effect,
  single-turn edge cases, Box-Cox interaction)

**SDD changes** (`design/coyote-sqc-design.md`):
- §6.8b: added `Plot_Method_Kind` enumerated type (Classical, Robust_Median)
- §6.8c Chart_Settings_Record: added `Plot_Method` field
- §7.13a: new section detailing implementation in `Compute_Session_Stat`
  and `Recompute_Chart`, with per-chart behaviour for Xbar and s charts,
  Box-Cox interaction, and a four-combination validity table
- §11.12 Chart Settings Dialog: added "Plot Method" expander to widget
  tree and full widget specification
- §11.12 Reset to Defaults button: updated to include `Plot_Method`
- §14.1: added 9 robust plot method test entries

**Backward compatibility:** No workspace version bump.  Workspace files
lacking a `"plotMethod"` field in a `chartSettings` entry load with the default "classical".

### 2026-06-17 — Plot Method dialog fix (PCR-031)

**Defect:** The Chart Settings dialog never read or persisted the `Plot_Method`
combo selection for Xbar/s charts.  The code blocks that wrote
`New_Cfg.Plot_Method` and reset the combo were nested inside the EWMA-chart
conditional (`if Props.Is_EWMA_Chart … then`).  Since no chart is both EWMA
and Xbar/s, both blocks were dead code.

**Fix:** Moved the Plot Method read/reset blocks out of the EWMA `if` to
standalone sibling conditionals.  Two locations in
`coyote_sqc-ui-chart_settings_dialog.adb`: the OK handler and `On_Reset`.

**Impact:** Xbar/s chart `plotMethod` workspace entries now persist correctly;
the dialog displays the current (non-default) value on re-open.

### 2026-06-17 — Fix: control-limit estimation method ignored during transform

**Problem:** When a variance-stabilizing transform (Box-Cox, sqrt, etc.)
was active on an I/EWMA/turn-count chart or an Xbar/S chart, switching
the estimation method between Classical and Robust_Median had no effect
on the `Grand_Mean` (and `Pooled_S` for Xbar/S charts).  The transform
override block in `Recompute_Chart` was always using the arithmetic mean
regardless of `Chart_Cfg.Estimation_Method`, only branching on
`Estimation_Method` for `I_Sigma`.

**Root cause:** `coyote_sqc-app.adb`:

- **I-chart path** (~line 926): `Grand_Mean := Sum_Z / N_Raw` was outside
  the `if Estimation_Method = Robust_Median` branch — only `I_Sigma` was
  conditionally computed.

- **Xbar/S path** (~line 1230): The `Grand_Mean` and `Pooled_S`
  assignments used only classical formulae with no branch on
  `Estimation_Method`.

**Fix (two edits in `coyote_sqc-app.adb`):**

1. **I-chart transform block** — moved `Grand_Mean` inside the
   estimation-method branch: `Robust_Median → Median_Of(Z_Vals)`;
   `Classical → Sum_Z / N_Raw` (unchanged).  This is the block that
   recomputes `CD.Params.Grand_Mean` and `CD.Params.I_Sigma` in the
   transformed space (after `Estimate_Parameters`).

2. **Xbar/S transform block** — restructured the "Pass 3" computation
   (`if Max_Vals > 0 then`) to branch on `Estimation_Method`:
   - `Robust_Median`: collects per-session means and per-observation
     residuals in z-space, then computes `Grand_Mean` as the median of
     session means and `Pooled_S` as `Qn_Scale_Any` of all residuals.
   - `Classical`: unchanged weighted mean and pooled variance path.

The MR-chart transform block already correctly branched on
`Estimation_Method` for its centre line.

**Tests:** Full test suite (713 tests) passes — 0 failures.

**Documents updated:**
- `requirements/coyote-sqc-requirements.md` §5.7: "Grand mean and pooled s
  in transformed space" now describes both Classical and Robust_Median.
- `design/coyote-sqc-design.md` §7.9 step 2: references both §7.5 and §7.13.
- `design/coyote-sqc-design.md` §7.10 "Transformed-space parameters": now
  covers classical and robust parameter computation paths.
- `design/coyote-sqc-design.md` §7.13 "Interaction with Box-Cox": clarified
  that estimation method controls Grand_Mean, I_Sigma, and Pooled_S in the
  transform override block.
- `plan/problems.md`: PCR-024 logged.

### 2026-06-17 — Fix: workspace file load fails on single-line JSON exceeding 65536 bytes

**Problem:** Opening a workspace from the recent-workspaces menu failed with
`GNATCOLL.JSON.INVALID_JSON_STREAM : control character not allowed in string`.
The error occurred when the `.sqcw` workspace file exceeded the 65,536-byte
`Get_Line` buffer (the file was a single-line JSON blob of ~105 KB).

**Root cause:** Both `coyote_sqc-workspace.adb` (`Load`) and
`coyote_sqc-config.adb` (`Load_Recent`) read JSON files with
`Ada.Text_IO.Get_Line` into a fixed `String (1 .. 65536)` buffer, appending
chunks with `ASCII.LF` appended.  When line length exceeded the buffer,
`Get_Line` returned a full buffer without consuming the line terminator; the
inserted `ASCII.LF` landed inside a JSON string value, producing an illegal
control character.

The same latent bug existed in `Load_Recent` (`coyote_sqc-config.adb`) but
hadn't triggered because `recent_workspaces.json` was only 195 bytes.

**Fix:** Both procedures now use `Coyote_Utils.Read_Whole_File`, which reads
the entire file via `Stream_IO` without line-boundary interpretation:

- **`coyote_sqc-workspace.adb` (Load):** Replaced the `Ada.Text_IO.Open` /
  `Get_Line` / `Close` block with a single `Read_Whole_File` call.  Removed
  the now-unused `File`, `Line`, and `Last` local variables.  Added
  `with Coyote_Utils;` to the context clause.

- **`coyote_sqc-config.adb` (Load_Recent):** Replaced the `Get_Line`-based
  reading with `Read_Whole_File`.  Removed the `File`, `Buf`, `Line`, and
  `Last` declarations.  Added `with Coyote_Utils;` to the context clause.

**Tests:** Full test suite (713 tests) passes — 0 failures.

**Documents updated:**
- `plan/problems.md`: PCR-033 logged.

### 2026-06-17 — Consolidation: merge duplicate Xbar/S accumulation code and simplify chart-kind membership

**Rationale:** Investigation revealed three forms of duplication across the
Xbar/S chart code paths:

1. Two near-identical accumulate procedures — `Accumulate_Xbar_S` (operating
  on `Natural_Vectors.Vector`) and `Accumulate_Xbar_S_LF` (operating on
  `Long_Float_Vectors.Vector`) — duplicated the same classical mean/variance
  accumulation and robust residual collection logic (~40 lines each).

2. An 8-chart-kind explicit membership test (`Kind in Turn_Tokens_Xbar |
  Turn_Tokens_S | Tool_Call_Tokens_Xbar | ... | Tool_Call_MI_S`) was used
  in `coyote_sqc-app.adb` where the existing `Properties.Is_Xbar_S_Chart`
  predicate already encoded the same set.

3. Three helper functions (`Mean_Of`, `Sum_Of`, `Sample_Variance`) that only
  existed to serve the old `Accumulate_Xbar_S` body became dead code after
  consolidation and were removed.

**Changes:**

- **`coyote_sqc-statistics.adb`:**
  - `Accumulate_Xbar_S_LF` is now the canonical accumulation procedure.
  - `Accumulate_Xbar_S` is a 10-line wrapper that converts `Natural` values
    to `Long_Float` and delegates to `Accumulate_Xbar_S_LF`.
  - Removed dead `Mean_Of`, `Sum_Of`, and `Sample_Variance` (~48 lines).
  - Reordered procedures so `Accumulate_Xbar_S_LF` appears before its caller.

- **`coyote_sqc-app.adb`:**
  - Replaced the explicit 8-chart-kind membership test with
    `Dsc.Properties.Is_Xbar_S_Chart` (6 lines → 1 line).

**Tests:** Full test suite (713 tests) passes — 0 failures.

**Documents updated:**
- `sdfs/coyote-sqc.md`: this entry.



### 2026-06-18 — Token Cost Charts (SRS/SDD)

**Feature:** Added 30 new token cost control charts to `coyote_sqc`:
18 session-level (I/MR/EWMA for Total, Input, Output, Cache Read, Cache
Write, and Uncached Input cost) and 12 turn-level (Xbar/s for each of the
same six cost categories). Charts use the same statistical formulas as their
token-count counterparts (§5.6, §5.9, §5.2 of SRS). Box-Cox transformation is
available for both families.

Costs are computed from token counts and a per-model pricing table. Pricing
resolution is two-tier: (1) local `pricing.json` (USD per token), (2)
OpenRouter `/api/v1/models` fallback (no auth required, per-token prices in
`pricing.prompt`, `pricing.completion`, `pricing.input_cache_read`, and
`pricing.input_cache_write` fields as string values). The OpenRouter response
is cached to `~/.config/coyote_sqc/openrouter_models_cache.json` with 24-hour
expiry. Sessions whose model has no pricing from either source are excluded
from all cost charts.

**Chart layout (6th left-panel group, "Token Costs"):**
- Cache Read Cost: I / MR / EWMA / Xbar / s
- Cache Write Cost: I / MR / EWMA / Xbar / s
- Input Cost: I / MR / EWMA / Xbar / s
- Output Cost: I / MR / EWMA / Xbar / s
- Total Cost: I / MR / EWMA / Xbar / s
- Uncached Input Cost: I / MR / EWMA / Xbar / s

**Chart count:** 61 → 91.

**Session_Metrics_Record additions:** `Total_Cost`, `Total_Input_Cost`,
`Total_Output_Cost`, `Total_Cache_Read_Cost`, `Total_Cache_Write_Cost`,
`Total_Uncached_Input_Cost` (all `Long_Float`) plus six `Long_Float_Vectors`
for per-turn costs.

**SRS changes** (`requirements/coyote-sqc-requirements.md`):
- §4.4: 12 cost fields added to Session Metrics Record
- §4.9: new pricing section with two-tier resolution
- §5.21: I/MR/EWMA cost chart formulas
- §5.22: Xbar/s cost chart formulas
- §6.52–§6.81: 30 new chart definitions
- §7.2 left panel: "Token Costs" group (6th group)
- §15.6: 10 cost-specific test requirements
- All "sixty-one" → "ninety-one" (7 occurrences)
- "five visually separated groups" → "six"

**SDD changes** (`design/coyote-sqc-design.md`):
- §6.5: 12 cost fields added to `Session_Metrics_Record`
- §6.7: 30 new `Chart_Kind` enum values
- §7.20: new cost computation section
- §8: 30 new chart property rows; chart count updated
- §13.3–§13.4: pricing.json and OpenRouter cache config
- §14.8–§14.9: cost computation and chart test entries

**Test plan:** Entry added for cost chart feature.


### 2026-06-18 — Token Cost Charts Implementation Complete (PCR-034)

**Status:** Resolved.

30 new token cost charts added: 18 session-level (I/MR/EWMA for Total, Input,
Output, Cache Read, Cache Write, Uncached Input cost) and 12 turn-level (Xbar/s
for each of the same 6 cost categories). Chart count: 61 → 91.

**Packages modified:**
- `coyote_sqc-data_model.ads` — 12 cost fields in `Session_Metrics_Record`
- `coyote_sqc-charts.ads/.adb` — 30 `Chart_Kind` enum values + properties
- `coyote_sqc-metrics.ads/.adb` — `Per_Token_Prices`, `Pricing_Table`, cost computation
- `coyote_sqc-statistics.adb` — accumulation + finalization cases
- `coyote_sqc-app.adb/.ads` — accessors, `Compute_Session_Stat` cases, `Descriptor`
  entries, MR override, `Pricing` field in `App_State`
- `coyote_sqc-config.ads/.adb` — `Load_Pricing` (reads `~/.config/coyote_sqc/pricing.json`)
- `coyote_sqc-ui-detail_panel.adb` — updated `Metrics.Compute` call

**Pricing loading:** Reads `~/.config/coyote_sqc/pricing.json` at session-load time.
File format: `{"models": {"model-id": {"input_price": ..., "output_price": ...,
"cache_read_price": ..., "cache_write_price": ...}}}`. All prices in USD per token.
OpenRouter API fallback deferred to future iteration.

**Design decision:** Cost charts reuse the same I/MR/EWMA/Xbar/s formulas as their
token-count counterparts. The pricing data path is transparent to the statistical
layer — `Metrics.Compute` populates cost fields when pricing is available, and
chart descriptors drive the same `Estimate_Parameters`/`Recompute_Chart` pipeline.

**Tests:** 713/713 pass (0 regressions). Unit tests for cost accuracy deferred
(cost path reuses existing statistical formulas).


### Comment Speed Fix — 2026-06-29

Adding a comment previously called `Recompute_Charts`, which recomputed
all 71 chart kinds — Box-Cox estimation, EWMA recursion, control-limit
derivation — plus per-session `Has_Comment` linear scans across the full
comment vector (O(S × C × 71) string comparisons).  None of that work was
necessary; only the `Has_Comment` boolean on existing chart points changes.

**Changes:**

- `Coyote_SQC.Data_Model.Workspace_Record` now includes `Commented_Session_Ids : UUID_Set` alongside the existing `Comments` vector.
- `Coyote_SQC.Workspace.Load` populates `Commented_Session_Ids` during deserialization.
- `Coyote_SQC.App.Has_Comment` is now an O(1) `UUID_Set.Contains` lookup (was linear scan).
- New `Coyote_SQC.App.Refresh_Comment_State` procedure: iterates all `Chart_Point` and `Quantile_Point` records across all 71 chart kinds, sets `Has_Comment` from the UUID set in-place, and calls `Queue_Redraw`.  No statistics recomputation.
- `On_Add_Comment_Clicked` and `On_Add_Multi_Comment_Clicked` in `Detail_Panel` now populate `Commented_Session_Ids` and call `Refresh_Comment_State` instead of `Recompute_Charts`.

**Result:** Adding a comment now takes milliseconds regardless of workspace size.
`Has_Comment` remains available within the full `Recompute_Chart` path for initial
point construction, benefiting from the O(1) speedup there too.

**Build:** Clean.  **Tests:** 722/722 pass (0 regressions).
