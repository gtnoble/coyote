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
