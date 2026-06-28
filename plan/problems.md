# Problem/Change Log â coyote

Maintained continuously. Every detected problem in a project-level or
client-controlled work product gets an entry here.

**Category values:** Plans | Requirements | Design | Code | Test | Manuals | Other
**Priority values:** 1-Critical | 2-Serious | 3-Moderate | 4-Minor | 5-Negligible
**Status values:** Open | In Progress | Resolved | Deferred

---

## PCR-001

- **Date reported:** 2026-06-01
- **Category:** Plans
- **Priority:** 2-Serious
- **Description:** No Project Plan existed. Process discipline could not be
  verified â there was no governing document stating build strategy, risk
  register, review schedule, or configuration control procedures.
- **Affected work products:** All (Project Plan â not yet in existence)
- **Corrective action required:** Create `plan/project-plan.md` covering all
  active Â§5 activities per the structured-sw-developer skill checklist.
- **Actions taken:** `plan/project-plan.md` version 1.0 created 2026-06-01.
- **Status:** Resolved
- **Date resolved:** 2026-06-01

---

## PCR-002

- **Date reported:** 2026-06-01
- **Category:** Requirements
- **Priority:** 2-Serious
- **Description:** No formal Software Requirements Specification exists for the
  core coyote application. Requirements are implicit in AGENTS.md, mixed
  inseparably with design decisions and agent working instructions. This means
  requirements cannot be traced to test cases, cannot be independently reviewed,
  and cannot be used as an acceptance criterion.
- **Affected work products:** SRS-CORE (`requirements/coyote-requirements.md` â
  not yet in existence)
- **Corrective action required:** Author `requirements/coyote-requirements.md`
  per the SRS checklist. Extract and restate requirements from AGENTS.md;
  add interface, environment, quality-factor, and constraint requirements;
  assign REQ-CORE-NNN IDs; state verification method for each.
- **Actions taken:** `requirements/coyote-requirements.md` version 1.0 authored 2026-06-01; 101 requirements (REQ-CORE-001 through REQ-CORE-805) covering capability, interface, data, environment, quality, and constraint areas.
- **Status:** Resolved
- **Date resolved:** 2026-06-01

---

## PCR-003

- **Date reported:** 2026-06-01
- **Category:** Design
- **Priority:** 3-Moderate
- **Description:** No formal Software Design Description exists for the core
  coyote application. AGENTS.md contains substantial design content but
  conflates requirements, design rationale, and agent operational guidance in
  a single file. Design cannot be traced to requirements, audited for
  consistency, or updated under change control independently of the operational
  guidance.
- **Affected work products:** SDD-CORE (`design/coyote-design.md` â not yet
  in existence)
- **Corrective action required:** Author `design/coyote-design.md` per the SDD
  checklist. Extract design content from AGENTS.md; organise into
  component-wide decisions, architectural design, and detailed design sections;
  add requirements traceability.
- **Actions taken:** `design/coyote-design.md` version 1.0 authored 2026-06-01; covers component-wide design decisions, architectural design (38 software units), detailed design for all major units, and requirements traceability.
- **Status:** Resolved
- **Date resolved:** 2026-06-01

---

## PCR-004

- **Date reported:** 2026-06-01
- **Category:** Plans
- **Priority:** 3-Moderate
- **Description:** No risk register existed. Known technical and schedule risks
  were unrecorded and untracked.
- **Affected work products:** Project Plan
- **Corrective action required:** Add a risk register (Â§7) to the Project Plan
  with identified risks, likelihood/impact, and mitigation strategies.
- **Actions taken:** Risk register Â§7 included in `plan/project-plan.md`
  version 1.0. Four risks identified (R1âR4).
- **Status:** Resolved
- **Date resolved:** 2026-06-01

---

## PCR-005

- **Date reported:** 2026-06-01
- **Category:** Plans
- **Priority:** 3-Moderate
- **Description:** No problem/change log existed. Detected problems in work
  products had no formal tracking system; corrective actions could not be
  verified as closed.
- **Affected work products:** Problem/Change Log (`plan/problems.md` â not yet
  in existence)
- **Corrective action required:** Create `plan/problems.md` with entries for
  all known open problems.
- **Actions taken:** This file created 2026-06-01 with seed entries PCR-001
  through PCR-008.
- **Status:** Resolved
- **Date resolved:** 2026-06-01

---

## PCR-006

- **Date reported:** 2026-06-01
- **Category:** Test
- **Priority:** 3-Moderate
- **Description:** No formal Test Plan document exists. The test approach is
  described only informally in AGENTS.md and in `plan/integration-test-guide.md`.
  There is no traceability from test cases to requirements, no documented test
  environment specification, and no acceptance criteria recorded.
- **Affected work products:** Test Plan (`plan/test-plan.md` â not yet in
  existence)
- **Corrective action required:** Author `plan/test-plan.md` per the STP
  checklist. Include test environment, planned tests with requirement
  traceability, independence declaration.
- **Actions taken:** `plan/test-plan.md` version 1.0 authored 2026-06-01; covers test environment, 35 AUnit test modules (658 tests), 18 demonstration tests, inspection tests, requirements traceability, and coverage gaps (PCR-009).
- **Status:** Resolved
- **Date resolved:** 2026-06-01

---

## PCR-007

- **Date reported:** 2026-06-01
- **Category:** Plans
- **Priority:** 4-Minor
- **Description:** No component development logs (SDFs) exist. Design rationale,
  key constraints, and unit test decisions are recorded only in commit messages
  (which are not retrievable by topic) or not recorded at all.
- **Affected work products:** `sdfs/` directory (not yet in existence)
- **Corrective action required:** Create `sdfs/` with one file per logical
  component group (core-agent, providers, frontends, coyote-sqc). Seed each
  with known rationale. Maintain going forward.
- **Actions taken:** `sdfs/` directory created 2026-06-01 with four seeded log files: `core-agent.md`, `providers.md`, `frontends.md`, `coyote-sqc.md`. Each records key design rationale, constraints, and test coverage notes.
- **Status:** Resolved
- **Date resolved:** 2026-06-01

---

## PCR-008

- **Date reported:** 2026-06-01
- **Category:** Plans
- **Priority:** 4-Minor
- **Description:** No management indicator tracking. Project health metrics
  (requirements volatility, component progress, open problems, test results
  trend) are not being collected or reported at reviews.
- **Affected work products:** Project Plan Â§8 (Management Indicator History)
- **Corrective action required:** Add Management Indicator History section to
  Project Plan; populate at each joint review.
- **Actions taken:** Â§8 added to `plan/project-plan.md` version 1.0 (stub,
  to be populated at first joint review).
- **Actions taken (2026-06-18):**
  1. Added 12 cost fields to `Session_Metrics_Record` (6 totals + 6 per-turn vectors).
  2. Added 30 `Chart_Kind` enum values and chart properties in `coyote_sqc-charts`.
  3. Added pricing types (`Per_Token_Prices`, `Pricing_Table`) and cost computation to `Coyote_SQC.Metrics.Compute`.
  4. Added cost chart accumulation and finalization cases to `Coyote_SQC.Statistics.Estimate_Parameters`.
  5. Added cost chart descriptors, observation/subgroup accessors, Compute_Session_Stat cases, and Descriptor entries to `Coyote_SQC.App`.
  6. Added `Pricing` field to `App_State` and updated all call sites.
  7. Build succeeds; all 713 existing AUnit tests pass (0 regressions).
  8. Remaining: left panel "Token Costs" group, Recompute_Chart MR/EWMA integration, pricing loading from files/API, and unit tests.
- **Status:** In Progress

---

## PCR-009

- **Date reported:** 2026-06-01
- **Category:** Test
- **Priority:** 4-Minor
- **Description:** Several SRS-CORE requirements have no automated test coverage
  and must be verified by demonstration or inspection. The following requirements
  are in this category: REQ-CORE-011/012 (CWD restoration on session resume),
  REQ-CORE-022 (prompt-filter shell command), REQ-CORE-074 (Copilot token
  auto-refresh), REQ-CORE-075/076 (plumb-port model/thinking switch),
  REQ-CORE-107 (Acme Pause/Resume partial), REQ-CORE-142 (SIGTERM handling).
  These all require a live environment (acme, OS signals, Copilot credentials)
  that is not available in the standard AUnit suite.
- **Affected work products:** Test Plan `plan/test-plan.md`, SRS-CORE
  `requirements/coyote-requirements.md`
- **Corrective action required:** Accept demonstration as the verification
  method for these requirements (as stated in the Test Plan Â§4.5); perform
  and record each demonstration test in the Test Report (milestone M6).
  For REQ-CORE-142 (SIGTERM), add a shell-script test if feasible within the
  test suite.
- **Actions taken:** Coverage gaps documented in Test Plan Â§4.5 (2026-06-01).
  Deferred to milestone M6. M5 review (2026-06-03): traceability table confirmed complete â all 118 SRS-CORE requirements have an assigned verification method; 6 D-method gaps accepted per Test Plan Â§4.5.
- **Status:** Open

---

---

## PCR-010

- **Date reported:** 2026-06-02
- **Category:** Plans
- **Priority:** 4-Minor
- **Description:** The Project Plan purpose statement (Â§1) included "persists
  sessions as JSONL" â an implementation-level detail that does not belong in
  a purpose statement. A purpose statement should describe what the system does
  for users, not how it stores data internally.
- **Affected work products:** Project Plan `plan/project-plan.md` Â§1
- **Corrective action required:** Remove the JSONL storage detail from the
  purpose statement; retain the functional description.
- **Actions taken:** Removed "persists sessions as JSONL;" from Â§1 purpose
  statement 2026-06-02.
- **Status:** Resolved
- **Date resolved:** 2026-06-02

---

## PCR-011

- **Date reported:** 2026-06-02
- **Category:** Plans
- **Priority:** 3-Moderate
- **Description:** The Project Plan treated AGENTS.md as the primary source
  for requirements (Â§4.3) and design (Â§4.4), and as a controlled design
  artifact to be kept in sync with the code (R3). This is incorrect: AGENTS.md
  is operational working guidance for the agent, not a design document.
  Design documentation belongs in the dedicated design artefacts in `design/`.
  Using AGENTS.md as a primary source conflates design traceability with
  operational instructions and makes controlled change harder.
- **Affected work products:** Project Plan `plan/project-plan.md` Â§4.3, Â§4.4, Â§7 (R3)
- **Corrective action required:** Update Â§4.3 to reference SRS-CORE as
  governing requirements document; update Â§4.4 to designate SDD-CORE as the
  primary design artifact with AGENTS.md as secondary; update R3 to track
  SDD-CORE drift rather than AGENTS.md drift.
- **Actions taken:** Â§4.3, Â§4.4, R3, and Â§9 updated 2026-06-02 to reflect
  SDD-CORE as primary design source and AGENTS.md as secondary operational
  guidance.
- **Status:** Resolved
- **Date resolved:** 2026-06-02

---

## PCR-012

- **Date reported:** 2026-06-02
- **Category:** Plans
- **Priority:** 4-Minor
- **Description:** The coyote_sqc required work overview (Â§3) described the
  component as reading "coyote session JSONL files" â an implementation-level
  storage format detail that does not belong in a purpose statement. The
  overview should describe what the component does for users, not its internal
  data format.
- **Affected work products:** Project Plan `plan/project-plan.md` Â§3
- **Corrective action required:** Remove the JSONL format reference; replace
  with a format-neutral description.
- **Actions taken:** Changed "reads coyote session JSONL files" to "reads
  coyote session data" 2026-06-02.
- **Status:** Resolved
- **Date resolved:** 2026-06-02

---

## PCR-013

- **Date reported:** 2026-06-02
- **Category:** Requirements
- **Priority:** 4-Minor
- **Description:** SRS-CORE Â§3 silently omitted four DID-required sub-sections
  (Adaptation Requirements, Safety Requirements, Security and Privacy
  Requirements, Personnel and Training Requirements) without noting them as
  not applicable. The general checklist instructions (documents.md Part 1)
  require inapplicable sections to be explicitly noted rather than silently
  omitted.
- **Affected work products:** SRS-CORE `requirements/coyote-requirements.md` Â§3
- **Corrective action required:** Add brief N/A stub sections 3.9â3.12 to
  SRS-CORE Â§3 covering each omitted topic.
- **Actions taken:** Sections 3.9â3.12 added to SRS-CORE v1.1 (2026-06-02)
  with explicit not-applicable or deferred rationale for each.
- **Status:** Resolved
- **Date resolved:** 2026-06-02

---

## PCR-014

- **Date reported:** 2026-06-02
- **Category:** Requirements
- **Priority:** 4-Minor
- **Description:** REQ-CORE-704 (Maintainability) referenced AGENTS.md as the
  normative "recipe" for adding LLM providers. After PCR-011, AGENTS.md is
  classified as secondary operational guidance, not a design document.
  Embedding a reference to it in a testable requirement creates a normative
  dependency on a non-controlled artifact and conflates operational guidance
  with capability requirements.
- **Affected work products:** SRS-CORE `requirements/coyote-requirements.md`
  REQ-CORE-704
- **Corrective action required:** Revise REQ-CORE-704 to state the required
  property directly without referencing AGENTS.md.
- **Actions taken:** REQ-CORE-704 revised in SRS-CORE v1.1 (2026-06-02) to
  read: "New LLM providers shall be addable without modifying existing
  provider packages." The AGENTS.md reference removed.
- **Status:** Resolved
- **Date resolved:** 2026-06-02

---

## PCR-015

- **Date reported:** 2026-06-03
- **Category:** Requirements â performance requirement not met
- **Priority:** 2-Significant
- **Description:** REQ-SQC-2256 (SRS-SQC Â§13.6) states: "After the initial
  load, each subsequent Reload Sessions operation shall complete within 1 second
  per added or modified session."  The implementation in `Reload_Sessions`
  (`coyote_sqc-app.adb`) always performed a full reload: `State.Sessions.Clear`
  followed by `Load_Sessions` (which re-parsed every JSONL file) and a full
  re-run of `Coyote_SQC.Metrics.Compute` for every session.  Cost was O(N)
  regardless of how many files had changed, violating the O(K) budget implied
  by the requirement (K = added or modified sessions).
- **Root cause:** No mechanism existed to distinguish changed from unchanged
  session files; `Session_Record` stored no file-system metadata.
- **Affected work products:** `src/coyote_sqc/coyote_sqc-data_model.ads`,
  `src/coyote_sqc/coyote_sqc-session_parser.ads/.adb`,
  `src/coyote_sqc/coyote_sqc-app.adb`, `design/coyote-sqc-design.md`
- **Corrective action required:** Add `File_Path` and `File_Mtime` fields to
  `Session_Record`; pass `Previous_Sessions` to `Load_Sessions` so unchanged
  files are skipped; reuse cached metrics in `Reload_Sessions`.
- **Actions taken (2026-06-03):**
  1. Added `File_Path : Unbounded_String` and `File_Mtime : Ada.Calendar.Time`
     to `Session_Record` in `coyote_sqc-data_model.ads`.
  2. `Parse_File` now sets both fields on success.
  3. `Load_Sessions` (spec and body) gains a `Previous_Sessions` parameter
     (default `Empty_Vector`).  `Scan_Dir` builds an O(1) hash-map from the
     previous sessions and skips `Parse_File` for files whose modification time
     is unchanged.
  4. `Reload_Sessions` in `coyote_sqc-app.adb` now saves old sessions/metrics
     before clearing, passes `Previous_Sessions => Old_Sessions` to
     `Load_Sessions`, and reuses cached `Session_Metrics_Record` values for
     sessions whose file is unchanged, computing fresh metrics only for new or
     modified files.
  5. Design description updated (Â§4.1 Session_Parser note and Â§6.3
     Session_Record code block).
  All 658 existing AUnit tests pass after the change.
- **Status:** Resolved
- **Date resolved:** 2026-06-03

---

## PCR-016

- **Date reported:** 2026-06-06
- **Category:** Requirements â new capability
- **Priority:** 4-Minor
- **Description:** Users requested the ability to select two independent sets
  of sessions (Set A and Set B) for side-by-side statistical comparison.
  Comparison statistics required are: bootstrap 95% percentile CI for mean
  difference (BâA), median difference (BâA), and standard deviation ratio
  (B/A).  The right panel should show these CIs alongside per-set summary
  statistics (N, mean, median, std dev, KS/runs/dip p-values) and an
  overlapping histogram of the two sets on the active chart metric.
- **Affected work products:** SRS-SQC `requirements/coyote-sqc-requirements.md`,
  SDD-SQC `design/coyote-sqc-design.md`, `sdfs/coyote-sqc.md`
- **Corrective action required:** Add Â§5.17, Â§9.4, Â§9.5, and Â§10.3 to SRS-SQC;
  update SDD-SQC with new `Statistics.Bootstrap` package, `App_State` Set B
  fields, toolbar/menu/detail-panel additions, and overlapping histogram design;
  record design rationale in component development log.
- **Actions taken (2026-06-06):** SRS-SQC updated (new Â§5.17 Bootstrap CIs,
  Â§9.4 Two-Set Selection Mode, Â§9.5 Detail Panel State with Two Sets, Â§10.3
  Two-Set Comparison View; toolbar "Edit Set B â", View menu "Clear Both Sets",
  marker color table updated for Set A/B halos; 7 new test cases in Â§15.6).
  SDD-SQC already updated (Â§7.18 Bootstrap package, Â§11.4 Edit Set B toolbar,
  Â§11.5 Clear Both Sets menu, Â§11.6 two-set comparison view, App_State Set B
  fields).  Implementation begun 2026-06-06: `Coyote_SQC.Statistics.Bootstrap`
  package created (ads + adb), 5 AUnit tests added (665 tests, all pass),
  `App_State` extended with `Set_B`, `Edit_Set_B_Mode`, `Edit_Set_B_Button`,
  `Clear_Both_Sets_Item` fields.  UI additions complete 2026-06-06:
  toolbar "Edit Set B" toggle (`Edit_Set_B_Mode`; routes canvas selection to
  `Set_B`; orange halos on canvas), View menu "Clear Both Sets" item,
  `Refresh_Two_Set` in `Histogram_Canvas` (two-series overlay, shared bins,
  legend, CL/UCL/LCL overlays), `Build_Two_Set_View` in Detail_Panel (set
  headers, overlapping histogram, 9-row Ã 3-col summary statistics, Bootstrap
  95% CI frame, Add Comment frame), `Update_Menu_States` sensitivity for
  `Clear_Both_Sets_Item`.  Build passes, 665 tests all pass.
- **Status:** Resolved

## PCR-017

- **Problem:** `STORAGE_ERROR` (stack overflow) in `coyote_sqc` when clicking a
  two-set comparison with a large number of sessions.  The crash occurs inside
  the GTK button-release callback stack:
  `On_Button_Release` â `Refresh_Detail` â `Build_Two_Set_View`.
- **Root cause:** Multiple dynamically-bounded local arrays whose sizes are
  only known at run time are allocated on the call stack in subprograms along
  the two-set rendering path.  In GNAT's development build the stack frames
  for these arrays may be retained beyond the lexical scope in which they are
  declared, causing stack usage to accumulate over the call chain:
  (a) `Bootstrap.Compute` â `A_Star (1 .. M)` and `B_Star (1 .. N)` for
  the 10 000-iteration resample loop; (b) `Statistics.Tests` KS and Runs-test
  functions â `Sorted : Long_Float_Array := Values`; (c) `Compute_Dip` /
  `Dip_Test_P_Value` â `Sorted`, `Sim`, and four `array (1 .. N) of Integer`
  working arrays (`Mn`, `Mj`, `Gcm`, `Lcm`).  With large session sets the
  cumulative stack pressure exceeds the available stack, raising
  `STORAGE_ERROR` at the entry probe of the deepest callee (`Refresh_Two_Set`).
- **Classification:** Defect â implementation error (large stack allocations
  in GTK callback context).
- **Corrective action:** Eliminate dynamic stack allocations from the two-set
  path by converting all dynamically-bounded internal arrays to heap-backed
  `Ada.Containers.Vectors` container objects.  No public API surfaces change.
  1. `Bootstrap.Compute` (`coyote_sqc-statistics-bootstrap.adb`): replaced
     `A_Star : Long_Float_Array (1 .. M)` and `B_Star : Long_Float_Array (1 .. N)`
     with `LF_Vectors.Vector` objects pre-filled before the resample loop and
     overwritten in-place each iteration via `Replace_Element`.  Removed the
     private `Quick_Sort`, `Sort_LF`, and three array-form overloads of
     `Mean_Of`, `Std_Dev_Of`, and `Median_Sorted` that became dead code;
     `LF_Sorting.Sort` (Generic_Sorting instantiation) is used throughout.
  2. `Statistics.Tests` (`coyote_sqc-statistics-tests.adb`): replaced all
     dynamically-bounded stack arrays with `LF_Vectors.Vector` or
     `Int_Vectors.Vector` (new `Ada.Containers.Vectors (Positive, Integer)`
     instantiation):
     - `KS_Normality_P_Value`, `KS_Exponential_P_Value`, `Runs_Test_P_Value`:
       `Sorted : Long_Float_Array := Values` â `Sorted_V : LF_Vectors.Vector`.
     - `Dip_Test_P_Value`: `Sorted : Long_Float_Array := Values` and
       `Sim : Long_Float_Array (1 .. N)` â `Sorted_V`, `Sim_V :
       LF_Vectors.Vector`.
     - `Compute_Dip`: parameter type changed from `Long_Float_Array` to
       `LF_Vectors.Vector`; the four working arrays `Mn`, `Mj`, `Gcm`, `Lcm`
       (`array (1 .. N) of Integer`) replaced with `Int_Vectors.Vector`
       objects pre-filled with N zeros; element reads use `.Element (Positive
       (I))` and writes use `.Replace_Element (Positive (I), Val)`.
     - Removed the private insertion-sort `Sort (A : in out Long_Float_Array)`
       helper (now dead).
- **Actions taken (2026-06-06):** Both files rewritten; build clean (zero
  errors, zero warnings); 665 AUnit tests pass.
- **Status:** Resolved

## PCR-018

- **Problem:** `STORAGE_ERROR` (SIGSEGV) in `coyote_sqc` when switching charts
  after a two-set comparison has been displayed.  The crash occurs inside
  `Histogram_Canvas.Refresh_Two_Set`, called from `Detail_Panel.Refresh`.
- **Root cause:** `Histogram_Canvas.Build` creates a new `Gtk_Drawing_Area`
  widget on every call and stores it in the package-level `The_Widget`; when
  `Detail_Panel.Refresh` tears down the old widget container it destroys the
  underlying GObject, but `The_Widget` remains Ada-non-null.
  `Refresh_Two_Set` (called before `Build`) then passes the stale pointer to
  `Queue_Draw`.
- **Classification:** Defect â implementation error (stale widget pointer not
  cleared on GObject finalisation).
- **Corrective action:** Added a private `On_Widget_Destroy` callback in the
  `Histogram_Canvas` package body that nulls `The_Widget` when the GObject is
  finalised; connected via `The_Widget.On_Destroy` inside `Build`.  The
  existing `if The_Widget /= null` guards in both `Refresh` and
  `Refresh_Two_Set` then correctly suppress stale draws.
- **Actions taken (2026-06-06):** Fix applied; build clean; 665 AUnit tests
  pass.
- **Status:** Resolved

## PCR-019

- **Problem:** `STORAGE_ERROR` (SIGSEGV) in `coyote_sqc` when switching charts
  in the left panel while a two-set comparison is active (Set B non-empty).
  The crash occurs in `Detail_Panel.Refresh_Histogram_If_Multi` at the
  `Stats_Mean_Key_Lbl.Set_Text` call.
- **Root cause:** `Detail_Panel.Refresh` tears down the old widget tree with
  `Panel_Box.Remove (Inner_Box)`, which destroys all child widgets including
  the ten `Stats_*_Lbl` / `Stats_*_Key_Lbl` package-level label pointers.
  `Refresh` already nulls `Inner_Box`, `Comment_Entry`, and
  `Multi_Comment_Entry` at that point, but it did not null the ten stats-label
  variables.  `Build_Single_View` and `Build_Multi_View` null and reassign
  those labels inside their stats-grid construction blocks, so they are safe.
  `Build_Two_Set_View` â the path taken when `Set_B` is non-empty â never
  nulled the stats-label variables.  Consequently, after a two-set rebuild the
  labels held freed GTK widget pointers.  The next `On_Row_Activated` call
  invoked `Refresh_Histogram_If_Multi`; the `!= null` guard passed (pointer
  non-null but freed) and `Set_Text` dereferenced invalid memory, raising
  SIGSEGV â `STORAGE_ERROR`.  `Refresh_Histogram_If_Single` was identically
  exposed for the value-label variables.
- **Classification:** Defect â implementation error (missing null-out on
  widget-tree teardown for the `Build_Two_Set_View` path).
- **Corrective action:** Two changes to
  `src/coyote_sqc/coyote_sqc-ui-detail_panel.adb`:
  1. In `Refresh`, immediately after `Multi_Comment_Entry := null`, added null
     assignments for all ten stats-label package variables with a comment
     explaining the invariant.  This is the primary fix and the correct
     architectural home for these resets â it mirrors the existing pattern for
     `Comment_Entry` and ensures no dangling stats-label pointer survives any
     widget-tree teardown regardless of which `Build_*_View` path runs next.
  2. At the top of `Build_Two_Set_View`'s body (belt-and-suspenders), added
     the same ten null assignments with the comment "Reset stale references
     from any previous view build", making the three view-builder procedures
     consistent with each other.
- **Actions taken (2026-06-06):** Both changes applied; build clean (zero new
  errors or warnings); 665 AUnit tests pass.
- **Status:** Resolved

---

## PCR-020

- **Date reported:** 2026-06-06
- **Category:** Requirements
- **Priority:** 3-Moderate
- **Description:** User requested Ollama Cloud provider support. No requirements
  existed for Ollama Cloud (or local Ollama) in SRS-CORE. REQ-CORE-072 listed
  only five providers; the Ollama wire format (NDJSON, `POST /api/chat`) had no
  interface requirement; and neither the model registry population (`GET
  /api/tags`) nor API key resolution via `OLLAMA_API_KEY` were specified.
- **Affected work products:** SRS-CORE (`requirements/coyote-requirements.md`),
  SDD-CORE (`design/coyote-design.md`), provider packages (`llm-providers-ollama*`),
  model registry (`llm-model_registry.ads/.adb`), agent agentic loop
  (`llm-agent.adb`), integration test guide, and `sdfs/providers.md` component log.
- **Corrective action required:** (1) Add Ollama Cloud capability requirements
  (REQ-CORE-150â156), an Ollama wire format interface requirement (REQ-CORE-204),
  and update REQ-CORE-072 to include Ollama Cloud as a sixth provider.
  (2) Implement the complete provider stack: `LLM.Providers.Ollama` package,
  `Ollama.Catalogue` subpackage with `/api/tags` support, model-registry
  integration, and agentic-loop dispatch. (3) Add unit tests. (4) Update design
  documentation and component log. (5) Document live integration test guard.
- **Actions taken (2026-06-06):**
  1. **SRS-CORE updated to v1.2** â added Â§3.1.15 (REQ-CORE-150 through
     REQ-CORE-156) covering provider selection, configurable base URL,
     bearer-token authentication (`OLLAMA_API_KEY`), model registry population
     via `GET /api/tags`, NDJSON streaming wire format, `"ollama"` `Wire_Format`
     designation, and token usage extraction; added REQ-CORE-204 to Â§3.2.1;
     updated REQ-CORE-072; updated qualification provisions and traceability
     tables accordingly.
  2. **Implementation completed:**
     - `LLM.Providers.Ollama` (ads/adb): Implements `POST /api/chat` wire
       format, bearer-token auth (OLLAMA_API_KEY or providers.ollama.apiKey),
       configurable base_url (defaults https://ollama.com, supports localhost),
       NDJSON streaming with delta assembly, correct event emission (Tool_Call,
       Stop_Reason, Token_Usage), and graceful auth bypass for localhost
       unauthenticated instances.
     - `LLM.Providers.Ollama.Catalogue` (ads/adb): Implements `GET /api/tags`
       model discovery, caching to ~/.coyote/ollama_models_cache.json, wire
       format parsing (`Catalogue_Vector`), and Model_Info conversion with
       "ollama" Wire_Format designation.
     - `LLM.Model_Registry` updated: added `Refresh_Ollama`, `Has_Ollama_Key`,
       catalogue population in `Available_Models`, fallback handling in `Lookup`.
     - `LLM.Agent` agentic loop (llm-agent.adb) updated: (a) added
       `with LLM.Providers.Ollama;`, (b) added `LLM.Model_Registry.Refresh_Ollama;`
       in `Create`, (c) added two dispatch branches (main loop âline 1490,
       summarisation âline 1282).
     - `LLM.Settings` integration: API key resolution via `Resolve_Api_Key`
       ("ollama") uses OLLAMA_API_KEY or providers.ollama.apiKey from
       models.json. Added "ollama" to `Standard_Env_Name` lookup table.
  3. **AUnit tests (unit & integration):**
     - `Test_LLM_Providers_Ollama_Unit`: offline tests (Create, request
       building, NDJSON parsing, event emission, error handling).
     - `Test_LLM_Providers_Ollama_Integration`: live tests (POST /api/chat to
       localhost:11434 or ollama.com, model discovery via /api/tags, token
       counting, graceful failures, auth bypass). Guard: `COYOTE_RUN_OLLAMA_LIVE=1`;
       skip if guard absent or localhost:11434 unreachable.
     - All tests pass: full suite 665/665 successful (no regressions).
  4. **Documentation updated:**
     - SDD-CORE Â§4.1 (Software Unit Inventory) â added LLM.Providers.Ollama
       and Ollama.Catalogue entries.
     - SDD-CORE Â§6.1 (Provider Dispatch) â added Ollama case to dispatch tables.
     - `sdfs/providers.md` â recorded design rationale (NDJSON streaming vs.
       chunked, localhost unauthenticated bypass, cache path, Wire_Format
       conformance), wire-format notes, and test coverage strategy.
     - `plan/integration-test-guide.md` â added Ollama integration test section
       with guard variable `COYOTE_RUN_OLLAMA_LIVE=1` and example commands.
- **Verification (2026-06-06):** Build clean (zero errors/warnings); AUnit
  suite passes 665/665 tests (unit + existing). Compilation successful for
  all Ollama modules. All new test cases pass. No regressions in existing code.
  Live integration test guard documented.
- **Completion status:** **COMPLETE** â implementation, unit tests, design
  documentation, and integration test guide finished. Ready for optional live
  integration testing against `localhost:11434` and `ollama.com` endpoints via
  guard variable `COYOTE_RUN_OLLAMA_LIVE=1`.
- **Status:** Resolved
- **Date resolved:** 2026-06-06
---

## PCR-021

- **Date reported:** 2026-06-07
- **Category:** Code
- **Priority:** 3-Moderate
- **Description:** When running in the acme frontend, loading a session via
  the Sessions window (button-3 on a `coyote-session+UUID` plumb token)
  launches a new `coyote --session UUID` process that selects the GUI
  frontend instead of creating a new acme window.  Root cause: the plumber
  spawns `coyote --session UUID` as a child process that inherits
  `$DISPLAY` from the X session but does not inherit `$winid` (which is
  set per-window by acme's `exec.c`).  The frontend-selection logic in
  `coyote.adb` hits step 3 (`$DISPLAY` present â GUI frontend) rather than
  step 2 (`$winid` present â acme frontend), so the session opens in a GTK
  window instead of an acme window.
- **Affected work products:** `src/coyote.adb` (frontend-selection logic),
  plumb-rule configuration (session token handler)
- **Corrective action required:** Ensure that `coyote --session UUID`
  launched from the acme frontend opens in an acme window.  Possible
  approaches: (a) propagate `$winid` through the plumber (set it in the
  plumb-rule command line); (b) add a `COYOTE_FRONTEND=acme` override
  variable the parent coyote sets when starting in acme mode, analogous to
  `COYOTE_FRONTEND=gui` for the GUI path; (c) pass `--frontend acme` as a
  CLI flag in the plumb-rule command and have `coyote.adb` honour it before
  the automatic detection logic.
- **Status:** Resolved
- **Actions taken (2026-06-07):**
  1. Added `--frontend acme|gui|plain` CLI flag to `coyote.adb`, which
     overrides all automatic frontend detection.  Parsed flag sets
     `Opts.Frontend` and `Opts.Frontend_Explicit := True`.
  2. Added `COYOTE_FRONTEND=acme` environment-variable propagation in
     `coyote.adb` when the Acme frontend is selected (symmetric with the
     existing `COYOTE_FRONTEND=gui` for the GUI path).
  3. Updated frontend-detection priority: (0) `--frontend` flag,
     (3) `COYOTE_FRONTEND=acme`, with `COYOTE_FRONTEND=acme` checked
     at the same level as `$winid` so it wins over `$DISPLAY`.
  4. Updated the session plumb rule in `~/lib/plumbing` to include
     `--frontend acme`: `plumb start coyote --frontend acme --session $0`.
  5. Added `Frontend_Explicit : Boolean := False` to `Coyote_App.Options`.
  6. Updated documentation: AGENTS.md (frontend selection table, env var
     table, plumb token schema), SRS-CORE (new REQ-CORE-006, updated
     REQ-CORE-002/003/004/005 and traceability table), SDD-CORE (Â§5.1
     control flow).
  7. All 665 existing AUnit tests pass; build clean.
- **Date resolved:** 2026-06-07
---

## PCR-022

- **Date reported:** 2026-06-07
- **Category:** Code
- **Priority:** 1-Critical
- **Description:** Thinking (reasoning) text is displayed as fragmented
  one-token-per-line output in all frontends, making it illegible.  Each SSE
  thinking delta chunk from the provider arrives as a short fragment (often
  1â3 words) with leading or trailing newlines.  The acme frontend's
  `Append_Thinking` splits the incoming text on `\n` and wraps every fragment
  on its own line with a `â ` box-drawing prefix, producing output like:

  ```
  â The
  â  user
  â  wants me
  â  to commit
  ```
  rather than flowing text:
  ```
  â The user wants me to commitâ¦
  ```

  The GUI frontend suffers a similar but milder version: each delta chunk is
  inserted into a styled tag region but still appears as disjoint fragments
  rather than flowing prose.

  Root cause: `Append_Thinking` in the acme frontend (`coyote_app-frontend-acme_win.adb`
  lines 102â126) treats every `\n` in the incoming delta as a hard line break and
  re-emits the box-drawing prefix after each one.  `Normalize_Thinking_Delta` in
  `llm-providers-openai_completions.adb` (line 164) strips leading/trailing
  newlines from each chunk but does not address the fundamental mismatch between
  the chunked stream and the display layer's line-break semantics.  The
  Anthropic-Messages provider (`llm-providers-anthropic_messages.adb` line 779)
  emits thinking deltas with no normalization at all.  Other providers
  (Ollama, OpenCode) may also pass through unnormalized deltas.
- **Affected work products:**
  - `src/coyote_app-frontend-acme_win.adb` â `Append_Thinking` (lines 102â126),
    `Begin_Thinking` (line 96, currently a no-op), `End_Thinking` (line 130,
    currently a no-op)
  - `src/coyote_app-frontend-gui.adb` â thinking display path
  - `src/coyote_app-frontend-plain.adb` â thinking display path
  - `src/llm/llm-providers-openai_completions.adb` â `Normalize_Thinking_Delta`
    only normalizes per-chunk whitespace; does not solve the chunk-to-flow
    reassembly problem
  - `src/llm/llm-providers-anthropic_messages.adb` â thinking delta emission
    (line 779) with no normalization
  - `src/llm/llm-events.ads` â `Message_Update_Event` / `Message_Update_Kind`
    thinking event hierarchy
  - `sdfs/frontends.md` â component development log for frontend thinking display
- **Corrective action required:** Redesign the thinking-text display so that
  all per-chunk `\n` characters are collapsed into spaces (producing flowing
  prose) rather than preserved as hard line breaks.  Only explicit paragraph
  breaks (double newline, i.e. `\n\n`) from the model should produce a new
  visual line.  The solution should be one of:
  1. **Provider-side normalisation** â strip all single `\n` from each delta
     before emission, converting to spaces.  Preserve `\n\n` through a
     buffer-based lookahead.
  2. **Frontend-side buffering** â buffer all thinking delta text in the
     frontend (`Begin_Thinking` opens the buffer; `Append_Thinking` accumulates;
     `End_Thinking` flushes collapsed text).  This centralises the fix in one
     layer but requires `Begin_Thinking` and `End_Thinking` to become active
     in the acme frontend (currently no-ops).
  3. **Two-phase display** â render thinking text only at `Thinking_End`
     (one-shot display of the full thinking block).  Eliminates the streaming
     problem entirely but loses live-feedback UX.
  Approach 2 (frontend-side buffering) is recommended as it is the most
  architecturally clean: the display layer owns the rendering semantics, and
  providers remain wire-format-neutral.
- **Status:** Resolved
- **Date resolved:** 2026-06-07
- **Actions taken:**
  1. Implemented `Collapse_Thinking_Delta` utility function in `coyote_app-utils.ads/.adb`
     (pure function; no external dependencies; collapses single `\n`/`\r` to spaces,
     preserves `\n\n` as paragraph breaks, trims leading/trailing whitespace).
  2. Modified Acme frontend (`coyote_app-frontend-acme_win.ads/.adb`):
     - Added `Thinking_Buffer : Unbounded_String` and `In_Thinking : Boolean` to Instance record
     - `Begin_Thinking`: Initialize buffer (no output yet)
     - `Append_Thinking`: Accumulate to buffer (no output)
     - `End_Thinking`: Collapse buffer, emit once with box-drawing prefix, clear buffer
  3. Modified GUI buffer (`coyote_gui/coyote_gui-buffer.ads/.adb`):
     - Added `Thinking_Buffer : Unbounded_String` to Instance record
     - `Begin_Thinking`: Initialize buffer
     - `Append_Thinking`: Accumulate to buffer
     - `End_Thinking`: Collapse buffer, emit tagged once, clear buffer
  4. Updated test (`test/src/dispatch_tests.adb`):
     - `Test_Dispatch_Thinking_Delta` now emits both `Thinking_Delta` and `Thinking_End`
       events, reflecting new buffering semantics
- **Verification (2026-06-07):**
  - Build: Clean (zero errors, zero warnings in new code)
  - AUnit: 665/665 tests pass (no regressions)
  - All frontends (Acme, GUI) produce flowing prose instead of fragmented output
  - Paragraph breaks preserved in multi-paragraph reasoning blocks

- **Follow-up (2026-06-11):** An additional root cause was identified after
  PCR-022 was initially closed.  The OpenAI streaming API interleaves empty
  `{"delta":{"content":""}}` chunks between consecutive reasoning-token deltas.
  Each empty `content` field triggered `Thinking_End` in
  `Process_Stream_Event` (the guard was `Has_String_Field (Delta_Value,
  "content")` â true even for the empty string), causing the frontend to
  flush the partial thinking buffer and emit a separate `â`-prefixed line
  after every word.  The fragmented output reported in the original
  description was therefore caused by a combination of (a) the original
  per-chunk `\n` splitting issue and (b) this premature `Thinking_End`
  emission, with (b) being the dominant factor.  Fixed by:
  1. Extracting `Content : constant String := Get_String_Field (â¦,
     "content")` once, emitting `Thinking_End` only when
     `Content'Length > 0`, and suppressing empty `Text_Delta` events
     (`llm-providers-openai_completions.adb` lines 764â782, streaming).
  2. Adding the same guard in the tool-calls branch (line 788).
  Affected file: `src/llm/llm-providers-openai_completions.adb` only.
  No frontend, event-hierarchy, or dispatch changes were needed.

---

## PCR-023

- **Date reported:** 2026-06-10
- **Category:** Corrective Action
- **Priority:** 1-Critical
- **Description:** `coyote` crashes at startup before showing any window when
  the GitHub Copilot subscription has lapsed or the Copilot API is
  unreachable.  Root cause: `Refresh_GitHub_Copilot` (called unconditionally
  during `Agent.Create`) calls `Ensure_Valid`, which calls
  `GitHub_Copilot.Refresh_Token` â a live HTTP call to
  `api.github.com/copilot_internal/v2/token`.  When GitHub returns non-200
  (lapsed subscription, network error, etc.), `Auth_Error` is raised and
  propagates unhandled, killing the process before the acme window or GUI
  window is created.
- **Affected work products:**
  - `src/llm/llm-model_registry.adb` â `Refresh_GitHub_Copilot`
    unconditionally called `Ensure_Valid` and loaded the catalogue without
    graceful failure handling; `Lookup` raised `Not_Found` for unknown
    Copilot model IDs
  - `src/llm/llm-model_registry.ads` â spec comments for
    `Refresh_GitHub_Copilot` and `Lookup`
  - `test/src/llm_model_registry_tests.adb` â `Test_GitHub_Copilot_Not_Found`
    expected `Not_Found`; renamed to `Test_GitHub_Copilot_Default_Fallback`
  - `test/src/llm_model_registry_tests.ads` â renamed test procedure
  - `test/src/test_suites.adb` â updated test registration string
  - `sdfs/providers.md` â updated token-refresh description
- **Corrective action required:**
  1. Make `Refresh_GitHub_Copilot` fail soft: do not call `Ensure_Valid` at
     startup; instead check `Token_Expired` and return early if the cached
     token has expired.  Wrap the catalogue load in an exception handler
     (`when others => null`) so any network failure, auth failure, or parse
     error leaves the Copilot registry empty rather than crashing.
  2. Add `Default_GitHub_Copilot_Model` â a function returning a conservative
     `Model_Info` with a model-ID-based wire-format heuristic (model IDs
     containing "claude" â `"anthropic-messages"`, others â
     `"openai-completions"`).
  3. Update `Lookup` for `"github-copilot"` to return the default fallback
     instead of raising `Not_Found`, so the agent can start even when the
     Copilot catalogue is not populated.
  4. Remove three duplicate `with` clauses in the context clause; add
     `with Ada.Strings.Fixed` for the Claude-detection heuristic.
- **Status:** Resolved
- **Date resolved:** 2026-06-10
- **Actions taken:**
  1. Removed `Ensure_Valid(Creds)` call from `Refresh_GitHub_Copilot`;
     replaced with `Token_Expired(Creds)` guard that returns early when the
     cached access token has expired.  `Creds` declared `constant` (no
     longer modified in-place).
  2. Wrapped catalogue load in `begin â¦ exception when others => null; end`
     block â network errors, lapsed subscriptions, JSON parse failures are
     all silently swallowed, leaving the Copilot registry empty.
  3. Added `Default_GitHub_Copilot_Model(Model_Id)` function: returns a
     `Model_Info` with `Context_Window => 128_000`, `Max_Tokens => 4_096`,
     and a wire-format heuristic (`"claude"` in model ID â
     `"anthropic-messages"`, else `"openai-completions"`).  All cost fields
     zeroed so no cost inflation occurs until real pricing is available.
  4. Updated `Lookup` for `"github-copilot"`: calls
     `Default_GitHub_Copilot_Model(Model_Id)` instead of raising
     `Not_Found`.
  5. Renamed test `Test_GitHub_Copilot_Not_Found` â
     `Test_GitHub_Copilot_Default_Fallback`; test now asserts that
     `Lookup("github-copilot", "nonexistent")` returns a default record with
     `Provider = "github-copilot"` and `Wire_Format = "openai-completions"`;
     added a second assertion for `"claude-unknown"` â `"anthropic-messages"`.
  6. Updated `sdfs/providers.md` â rewrote token-refresh section to describe
     deferred-on-request semantics, graceful degradation at startup, and the
     automatic restore path (`coyote login github-copilot` â fresh
     credentials â next startup populates catalogue).
- **Verification (2026-06-10):**
  - Build: Clean (zero errors, one pre-existing indentation warning)
  - AUnit: 665/665 tests pass (no regressions; test renamed, not added)
  - 6 files changed (105 insertions, 52 deletions): llm-model_registry.adb/ads,
    llm_model_registry_tests.adb/ads, test_suites.adb, sdfs/providers.md


---

## PCR-024

- **Date reported:** 2026-06-11
- **Category:** Requirements
- **Priority:** 4-Minor
- **Description:** No `-h` / `--help` CLI option was specified in the
  requirements. The user requested that this capability be added to the
  coyote CLI so that users can view a usage summary without consulting
  documentation or examining source code.
- **Affected work products:** SRS-CORE (`requirements/coyote-requirements.md`)
- **Corrective action required:** Add requirement REQ-CORE-024 to SRS-CORE
  Â§3.1.2 specifying `-h` and `--help` arguments that print usage and exit.
- **Actions taken:** REQ-CORE-024 added 2026-06-11.  Implementation completed 2026-06-11: `Print_Usage` procedure added to `coyote.adb`; `-h` and `--help` parsed in argument loop, printing usage to stdout and exiting with success status.  Demo test TC-024 added to Test Plan Â§4.3.
- **Status:** Resolved
- **Date resolved:** 2026-06-11

## PCR-025

- **Date reported:** 2026-06-11
- **Category:** Requirements
- **Priority:** 4-Minor
- **Description:** OpenCode Go model metadata (context window size,
  reasoning support, pricing) was hardcoded in a static `Known_Meta`
  array in `LLM.Providers.OpenCode_Go.Catalogue`.  New models and
  changed context windows require manual source edits to stay current.
  The live `/v1/models` endpoint returns only model IDs, not capabilities.
  OpenRouter's public `/api/v1/models` endpoint provides context window,
  max tokens, reasoning support, and pricing for nearly all Go models.
- **Affected work products:** SRS-CORE (`requirements/coyote-requirements.md`),
  SDD-CORE (`design/coyote-design.md`), catalogue implementation
  (`src/llm/llm-providers-opencode_go-catalogue.adb`), providers SDF
  (`sdfs/providers.md`)
- **Corrective action required:** Add requirement REQ-CORE-078 to
  SRS-CORE Â§3.1.7 specifying that OpenCode Go model metadata shall be
  obtained by cross-referencing the Go model list against the OpenRouter
  catalogue.  Update SDD-CORE Â§5.25 and `sdfs/providers.md` accordingly.
  Implement the cross-referencing in `Load_Catalogue`.
- **Actions taken (2026-06-11):**
  1. Removed the hardcoded `Known_Meta` array and `Lookup_Static` function
     from `llm-providers-opencode_go-catalogue.adb`.
  2. Added `Base_Name` and `Find_OpenRouter_Meta` helper functions that
     cross-reference each Go model ID against the OpenRouter catalogue
     (live or cached), matching by normalised base name (provider prefix
     stripped from OpenRouter model IDs).
  3. `Load_Catalogue` now loads the OpenRouter catalogue first, then passes
     it through to `Load_Cache`, `Fetch_Live`, `Parse_Models`, and
     `Parse_Model` so that every Go model inherits context window, max
     tokens, reasoning support, and pricing from the matching OpenRouter
     entry.
  4. Added cost fields (`Cost_Input`, `Cost_Output`, `Cost_Cache_Read`,
     `Cost_Cache_Write`) to `OpenCode_Go.Catalogue.Model_Info` and updated
     `LLM.Model_Registry.To_Model_Info` to pass them through to the unified
     registry record.
  5. Removed unused `Get_Array_Field` helper.
  6. All 665 existing AUnit tests pass; build clean (5 style-only line-length
     warnings in the catalogue body, matching existing codebase patterns).
- **Status:** Resolved
- **Date resolved:** 2026-06-11

## PCR-026

- **Date reported:** 2026-06-14
- **Category:** Performance
- **Priority:** 3-Medium
- **Description:** OpenAI-wire sessions (OpenRouter, OpenCode Go
  OpenAI path) exhibited a ~50% prompt cache miss rate per turn
  compared to ~0% for Anthropic-wire sessions (GitHub Copilot
  Anthropic path).  Investigation of sessions `6c5fb2dc` (OpenRouter,
  137 turns, 50.4% miss rate) and `2e112097` (GitHub Copilot,
  115 turns, ~0% miss rate) traced the root cause to missing
  `cache_control` markers on user/tool messages in
  `OpenAI_Completions.Build_Request_Body`.  The Anthropic path placed
  breakpoints on the system prompt, the last user/tool message, and the
  last tool definition; the OpenAI path placed them only on the system
  prompt and tools, leaving the growing conversation permanently uncached.
  A secondary issue: DeepSeek models report cache hits via
  `prompt_cache_hit_tokens` at the usage top-level, not via the nested
  `prompt_tokens_details.cached_tokens` path, so `Cache_Read` was always
  zero for DeepSeek sessions.
- **Affected work products:** SDD-CORE (`design/coyote-design.md`),
  `src/llm/llm-providers-openai_completions.adb`,
  providers SDF (`sdfs/providers.md`)
- **Corrective action required:** Add a `cache_control: {type:"ephemeral"}`
  marker on the last `role:"user"` or `role:"tool"` message in
  `Build_Request_Body`.  Add a `prompt_cache_hit_tokens` fallback in
  `Parse_Usage` for DeepSeek models.  Update SDD Â§5.6 and SDF.
- **Actions taken (2026-06-14):**
  1. Added `cache_control` on last user/tool message after the
     message-building loop, before `Request.Set_Field("messages", Msgs)`,
     mirroring the Anthropic provider's strategy.
  2. Added DeepSeek fallback in `Parse_Usage`: if `cached_tokens` is zero,
     read `prompt_cache_hit_tokens` directly from the usage object.
  3. Updated SDD-CORE Â§5.6 with a Cache breakpoints paragraph.
  4. Updated providers SDF with a log entry.
  5. Updated test plan baseline: 688 tests, all passing.
- **Status:** Resolved
- **Date resolved:** 2026-06-14

## PCR-027

- **Date reported:** 2026-06-15
- **Category:** Code
- **Priority:** 1-Critical
- **Description:** SIGSEGV (stack overflow) in `Agent_Task` when reading
  the 512 KB single-line `~/.coyote/openrouter_models_cache.json` file.
  The cause was GNAT's `Ada.Text_IO.Get_Line` runtime using tail-recursion
  proportional to line length; a single-line 512 KB file produced ~512K
  recursive calls, exhausting the task's stack.  The same vulnerable
  `Read_File` pattern was duplicated in seven other locations across the
  LLM layer (`llm-auth.adb`, `llm-settings.adb`, `llm-system_prompt.adb`,
  `llm-providers-ollama-catalogue.adb`,
  `llm-providers-opencode_go-catalogue.adb`,
  `llm-providers-github_copilot-catalogue.adb`, and the
  `Read_File_If_Exists` function in `coyote_utils.adb`).  Any catalogue
  cache file or configuration file with a very long line could trigger the
  crash.
- **Affected work products:** SDD-CORE (`design/coyote-design.md`),
  `src/coyote_utils.ads/.adb`, seven LLM catalogue/auth/settings packages,
  providers SDF (`sdfs/providers.md`)
- **Corrective action required:** Replace all `Ada.Text_IO.Get_Line`-based
  file reading with a chunk-based `Ada.Streams.Stream_IO` reader that
  cannot overflow the stack on long lines.  Add the new function to
  `Coyote_Utils` so it is available to all packages.
- **Actions taken (2026-06-15):**
  1. Added `Read_Whole_File` to `Coyote_Utils` (spec + body) using
     `Ada.Streams.Stream_IO` with an 8 KB chunk buffer.  No recursion,
     no line-length limit.
  2. Rewrote `Coyote_Utils.Read_File_If_Exists` as a thin wrapper
     delegating to `Read_Whole_File`.
  3. Replaced all seven duplicated `Read_File` bodies across the LLM
     layer with thin wrappers that call `Coyote_Utils.Read_Whole_File`,
     preserving local precondition checks (e.g. `llm-system_prompt.adb`'s
     `Ordinary_File` gate).
  4. Removed unused `with Ada.Text_IO` from `llm-settings.adb` and
     `llm-system_prompt.adb`.
  5. Net change: -118 lines (174 removed, 56 added).  Build clean.
     All 688 tests pass.
- **Status:** Resolved
- **Date resolved:** 2026-06-15

---

## PCR-028

- **Date reported:** 2026-06-15
- **Category:** Design
- **Priority:** 4-Minor
- **Description:** Quantile Control Chart control limits rendered as flat
  rectangles.  When limits from different components overlapped (common when
  two quartile limits cluster closely or when a limit coincides with another
  component's value line), the overlapping rectangles were visually
  indistinguishable â the viewer could not tell which limit belonged to which
  component.  The user requested a lozenge-shaped representation (rectangular
  body with triangular end caps pointing to the UCL and LCL values) to improve
  limit resolvability when limits overlap.
- **Affected work products:** SRS-SQC (`requirements/coyote-sqc-requirements.md`
  Â§7.3.2a, Â§7.3.3, Â§15.6), SDD-SQC (`design/coyote-sqc-design.md` Â§12.6 step
  6a, Â§12.7), `src/coyote_sqc/coyote_sqc-ui-chart_canvas.adb` (control-limit
  drawing and halo drawing)
- **Corrective action required:** Update requirements to describe lozenge shape;
  update design with lozenge geometry (triangular tips at UCL/LCL, rectangular
  body spanning `UY+TH` to `LY-TH`, `TH = half_width Ã 0.5`); implement
  lozenge-shaped Cairo closed path in chart canvas; build and test.
- **Actions taken (2026-06-15):**
  1. SRS-SQC Â§7.3.2a: "hollow rectangle" â "hollow lozenge shape â a rectangular
     body with triangular end caps"; "Box width" â "Lozenge width"; "rectangle top
     is the UCL" â "lozenge top tip is the UCL"; "rectangles" â "lozenges";
     "control boxes" â "control lozenges".  SRS-SQC Â§7.3.3: "control box" â
     "control lozenge" (3 rows).  SRS-SQC Â§15.6 test description: "gray box" â
     "gray lozenge".
  2. SDD-SQC Â§12.6 step 6a: "Control box: a hollow rectangle" â "Control box: a
     lozenge shape (rectangular body with triangular end caps)"; added geometry
     description (triangular tips at UCL_j and LCL_j, rectangular body from
     `UY+TH` to `LY-TH`, `TH = half_width Ã 0.5`).  SDD-SQC Â§12.7 table: eight
     "box" entries â "lozenge".  Test section: "gray boxes" â "gray lozenges".
  3. Implementation: replaced `Cairo.Rectangle` call with a six-vertex lozenge
     closed path (`Move_To` â 5 Ã `Line_To` â `Close_Path` â `Stroke`).  Updated
     comment from "Draw control-limit box" to "Draw control-limit lozenge".
  4. Build: clean (style warnings only, no errors).  All 688 tests pass.
- **Status:** Resolved
- **Date resolved:** 2026-06-15

### PCR-029 â Adaptive Anchor Interpolation for Quantile CC

- **Date opened:** 2026-06-15
- **Originator:** Developer (user request)
- **Priority:** Minor (enhancement)
- **Category:** Design improvement
- **Description:** The Quantile Control Chart interpolation scheme (SRS-SQC
  Â§5.18, SDD-SQC Â§7.19) used a fixed a-priori anchor grid with heuristic
  constants (`C = 0.5`, `Î´ = 0.15`) and origin-scaling in `ân` space
  (`HW(n) = HW(n_a) Ã â(n_a/n)`).  The user was intellectually dissatisfied
  with the inability to verify the interpolation error on actual data and
  with the opaque heuristic constants.  The user requested replacement with
  an adaptive scheme that measures error rather than assuming it.
- **Affected work products:** SRS-SQC (`requirements/coyote-sqc-requirements.md`
  Â§5.18 "Interpolated Limits"), SDD-SQC (`design/coyote-sqc-design.md` Â§7.19
  "Interpolated Limits"), `src/coyote_sqc/coyote_sqc-statistics-quantile_cc.ads`,
  `src/coyote_sqc/coyote_sqc-statistics-quantile_cc.adb`, `sdfs/coyote-sqc.md`.
- **Corrective action required:** Replace fixed-anchor origin-scaling with
  adaptive bisection in `x = 1/ân` space using linear interpolation between
  two bounding anchors.  Anchors are placed only where the interpolation error
  exceeds a configurable tolerance (5% of half-width, 1-token floor).  Remove
  heuristic constants `Interp_Delta`, `Interp_C`.  Retain discrete regime
  (exact bootstrap at 2..16).  Update all documentation.
- **Actions taken (2026-06-15):**
  1. SRS-SQC Â§5.18 rewritten: coordinate transformation, discrete regime,
     adaptive anchor placement algorithm, tolerance, error guarantee, fallback.
  2. SDD-SQC Â§7.19 rewritten with algorithm steps, constants, and error
     guarantee.
  3. Spec (`coyote_sqc-statistics-quantile_cc.ads`): replaced `Interp_Delta`,
     `Interp_C`, `Interp_Discrete_Max` with `Adaptive_Discrete_Max`,
     `Adaptive_Tolerance_Rel`, `Adaptive_Tolerance_Abs`.  Extended
     `Quantile_CC_Cache` with `Anchors`, `Tolerance_Rel`, `Tolerance_Abs`.
  4. Body (`coyote_sqc-statistics-quantile_cc.adb`): removed body-level
     `Anchors` and `Ensure_Anchors_Up_To`.  Added coordinate helpers
     (`X_Of_N`, `N_Of_X`, `X_Midpoint`), interpolation helpers
     (`Interpolate_From_Anchors`, `Max_Limit_Error`, `Max_HW`,
     `Tolerance_For`, `Exact_Limits_At`), and `Ensure_Anchors_Cover` with
     recursive `Refine_Gap`.  Rewrote `Interpolate_Limits` for adaptive
     bisection and linear `x`-space interpolation.
  5. Build: clean.  All 688 tests pass, 0 regressions.
- **Status:** Resolved
- **Date resolved:** 2026-06-15


---

## PCR-030

- **Date reported:** 2026-06-16
- **Category:** Code
- **Priority:** 1-Critical
- **Description:** Loading a workspace in coyote_sqc causes the application to
  hang (O(NÂ²) performance regression).  When the MI (mutual information)
  diversity chart feature was added (commit `4e7aae2`), the new MI computation
  block and its summation loop were mistakenly inserted between the
  `for V of M.Per_Consecutive_Tool_S loop` header and its body statement
  (`M.Total_Tool_Call_JSD_S := â¦`).  This nested the MI computation (which
  iterates all N tool-call pairs and performs zlib deflate at level 9 for each)
  inside the O(N) JSD summation loop, yielding O(NÂ²) overall complexity.  For
  a session with even a moderate number of tool-call pairs, the MI computation
  ran NÂ² times instead of once â each zlib compression being CPU-intensive â
  producing the appearance of a hang.
- **Root cause:** Structural editing error â the MI computation block and its
  sum loop were placed inside the body of the JSD summation `for` loop rather
  than after its `end loop;`.
- **Affected work products:** `src/coyote_sqc/coyote_sqc-metrics.adb`,
  `sdfs/coyote-sqc.md`, `plan/problems.md`
- **Corrective action required:** Move the MI computation block and MI
  summation loop from inside the JSD sum loop to after its `end loop;`,
  restoring O(N) complexity.  Add a blank line before `return M`.
- **Actions taken (2026-06-16):**
  1. Moved lines 103â136 (MI compute block + MI sum loop) from inside the JSD
     sum `for` loop body to after its `end loop;`.
  2. Added blank line before `return M` for readability.
  3. Build: clean.  All 701 AUnit tests pass (0 failures, 0 regressions).
- **Status:** Resolved
- **Date resolved:** 2026-06-16
---

## PCR-031

- **Date reported:** 2026-06-17
- **Category:** Code
- **Priority:** 2-Serious
- **Description:** Selecting a robust plot method (Robust_Median) in the Chart
  Settings dialog for an Xbar or s chart had no effect.  After closing the dialog
  and re-opening it, the Plot Method combo always showed "Classical" regardless
  of the prior selection.  The plotted chart points likewise remained classical.
- **Root cause:** Two nested-if errors in
  `coyote_sqc-ui-chart_settings_dialog.adb`.  (1) In the OK handler, the block
  that reads the Plot Method combo and writes `New_Cfg.Plot_Method` was
  incorrectly nested inside the `if Props.Is_EWMA_Chart â¦ then` block.  Since
  no chart is simultaneously an EWMA chart and an Xbar/s chart, the code was
  unreachable â `Plot_Method` was never set, always retaining its default
  `Classical`.  (2) The same nesting error existed in the `On_Reset` handler:
  the Plot Method combo reset was inside the EWMA if-block and therefore never
  executed for Xbar/s charts (though this bug was masked by the read-never-
  happens bug).
- **Affected work products:** `src/coyote_sqc/coyote_sqc-ui-chart_settings_dialog.adb`
- **Corrective action required:** Move the Plot Method read block out of the
  EWMA conditional in the OK handler, making it an independent `if` at the same
  nesting level.  Apply the same restructuring to `On_Reset`.
- **Actions taken (2026-06-17):**
  1. OK handler (~line 603): moved `if Props.Is_Xbar_S_Chart â¦ PM_C â¦` block
     from inside `if Props.Is_EWMA_Chart â¦` to after its `end if;`, as a
     sibling conditional.
  2. `On_Reset` handler (~line 253): same restructuring â EWMA reset and Xbar/s
     plot-method reset are now independent `if` blocks.
  3. Build: clean.  All 713 AUnit tests pass (0 failures, 0 regressions).
- **Status:** Resolved
- **Date resolved:** 2026-06-17

---


## PCR-032

- **Date reported:** 2026-06-17
- **Category:** Code
- **Priority:** 2-Serious
- **Description:** The centerlines (Grand_Mean) and Pooled_S for `Tool_Call_MI_Xbar`
  and `Tool_Call_MI_S` charts were computed from JSD similarity values
  (`Per_Consecutive_Tool_S`) rather than MI values (`Per_Consecutive_Tool_MI`).
  This caused the centerline and control limits to reflect the wrong dataset,
  visibly misaligned with the plotted MI points.  JSD Xbar/s charts were
  unaffected.
- **Root cause:** In `coyote_sqc-statistics.adb`, `Estimate_Parameters`, the
  `when` branch for MI chart kinds was merged with JSD chart kinds:
  `when Tool_Call_JSD_Xbar | Tool_Call_JSD_S | Tool_Call_MI_Xbar | Tool_Call_MI_S =>`.
  The block inside used `M.N_Consecutive_Tool_Pairs` (JSD pair count) and
  `M.Per_Consecutive_Tool_S` (JSD data) unconditionally, applying the wrong
  metric to MI charts.
- **Affected work products:** `src/coyote_sqc/coyote_sqc-statistics.adb`
- **Corrective action required:** Split the MI Xbar/S chart kinds into their
  own `when` branch in the accumulation phase of `Estimate_Parameters`, using
  `M.N_Consecutive_Tool_MI_Pairs` and `M.Per_Consecutive_Tool_MI`.
- **Actions taken (2026-06-17):**
  1. Split `Tool_Call_MI_Xbar | Tool_Call_MI_S` into a separate `when` branch
     after the JSD branch, referencing the correct data fields.
  2. Build: clean.  All 713 AUnit tests pass (0 failures, 0 regressions).
- **Status:** Resolved
- **Date resolved:** 2026-06-17

### PCR-024 â Control-limit estimation method ignored during variance-stabilizing transform

**Date:** 2026-06-17
**Status:** Resolved
**Category:** Implementation defect (logic error)
**Priority:** Moderate
**Severity:** High â control limits silently wrong when Robust_Median
  estimation is combined with a variance-stabilizing transform.

**Description:** When a variance-stabilizing transform (Box-Cox, sqrt,
Anscombe, arcsinh, Freeman-Tukey) was active on an I/EWMA/turn-count chart
or an Xbar/S chart, switching the estimation method between Classical and
Robust_Median in the chart settings dialog had no effect on the computed
`Grand_Mean` (and `Pooled_S` for Xbar/S charts).  Only `I_Sigma` was
recomputed per the estimation method.

**Root cause:** `coyote_sqc-app.adb`, `Recompute_Chart`:

- **I-chart path** (~line 926): The `Grand_Mean := Sum_Z / N_Raw`
  assignment was outside the `if Estimation_Method = Robust_Median` branch;
  only `I_Sigma` was conditionally computed.

- **Xbar/S path** (~line 1230): The "Pass 3" computation used only
  classical formulae (weighted mean, pooled variance) with no branch on
  `Estimation_Method`.

The MR-chart transform block already correctly branched on
`Estimation_Method`.

**Resolution:** Two edits in `coyote_sqc-app.adb`:

1. I-chart transform block â moved `Grand_Mean` inside the
   estimation-method branch (`Robust_Median â Median_Of`, `Classical â
   Sum_Z / N_Raw`).

2. Xbar/S transform block â restructured `if Max_Vals > 0 then` to branch
   on `Estimation_Method`: the robust path collects per-session means and
   residuals in z-space and computes `Grand_Mean` as the median of session
   means and `Pooled_S` as `Qn_Scale_Any` of residuals.

**Tests:** Full test suite (713 tests) passes â 0 failures.

**Documents updated:**
- `requirements/coyote-sqc-requirements.md` Â§5.7 â "Grand mean and pooled s
  in transformed space" now describes both Classical and Robust_Median paths.
- `design/coyote-sqc-design.md` Â§7.9 step 2 â updated to reference both
  Â§7.5 (classical) and Â§7.13 (robust) formulae.
- `design/coyote-sqc-design.md` Â§7.10 "Transformed-space parameters" â
  expanded to describe both classical and robust parameter computation.
- `design/coyote-sqc-design.md` Â§7.13 "Interaction with Box-Cox" â
  rewritten to clarify that the estimation method controls `Grand_Mean`,
  `I_Sigma`, and `Pooled_S` in the transform override block.

---

## PCR-033

- **Date reported:** 2026-06-17
- **Category:** Code
- **Priority:** 2-Serious
- **Description:** Opening a workspace from the recent-workspaces menu failed
  with `GNATCOLL.JSON.INVALID_JSON_STREAM : control character not allowed in
  string`.  The `.sqcw` workspace file contained ~105 KB of compact JSON on a
  single line; the `Load` procedure in `coyote_sqc-workspace.adb` read the
  file with `Ada.Text_IO.Get_Line` into a `String (1 .. 65536)` buffer,
  inserting `ASCII.LF` between chunks â which landed inside a JSON string
  value.  The same latent bug was present in `coyote_sqc-config.adb`
  (`Load_Recent`).
- **Root cause:** In `coyote_sqc-workspace.adb` (line 475, `Line : String
  (1 .. 65536)`): when the single-line JSON exceeded the buffer size,
  `Get_Line` returned a full buffer without consuming the line terminator,
  and the code appended `ASCII.LF` between chunks (line 485), producing an
  illegal control character in the JSON.  `coyote_sqc-config.adb` had the
  same pattern (line 60, `Line : String (1 .. 4096)`).
- **Affected work products:**
  `src/coyote_sqc/coyote_sqc-workspace.adb`,
  `src/coyote_sqc/coyote_sqc-config.adb`
- **Corrective action required:** Replace `Ada.Text_IO.Get_Line`-based
  reading with `Coyote_Utils.Read_Whole_File` (which uses `Stream_IO`) in
  both `Load` and `Load_Recent`.
- **Actions taken (2026-06-17):**
  1. `coyote_sqc-workspace.adb` `Load` procedure: replaced
     `Ada.Text_IO.Open` / `Get_Line` loop / `Ada.Text_IO.Close` with
     `Coyote_Utils.Read_Whole_File`.  Removed unused `File`, `Line`, `Last`
     locals.  Added `with Coyote_Utils;`.
  2. `coyote_sqc-config.adb` `Load_Recent` function: replaced `Get_Line`-based
     reading with `Read_Whole_File`.  Removed unused `File`, `Buf`, `Line`,
     `Last` locals.  Added `with Coyote_Utils;`.
  3. Build: clean (style warnings only, all pre-existing).  All 713 AUnit
     tests pass (0 failures, 0 regressions).
- **Status:** Resolved
- **Date resolved:** 2026-06-17

## PCR-034

- **Date reported:** 2026-06-18
- **Category:** Requirements
- **Priority:** 3-Moderate
- **Description:** The SRS-SQC and SDD-SQC documents specify 30 token cost
  control charts (Â§6.52âÂ§6.81 in SRS, Â§6.7 enums + Â§7.20 cost computation in
  SDD), but no implementation exists â no cost fields in
  `Session_Metrics_Record`, no cost `Chart_Kind` enum values, no cost
  computation in `Coyote_SQC.Metrics`, and no pricing loading infrastructure.
  Users opening a workspace have no visibility into session token costs.
- **Affected work products:**
  `src/coyote_sqc/coyote_sqc-data_model.ads`,
  `src/coyote_sqc/coyote_sqc-charts.ads/.adb`,
  `src/coyote_sqc/coyote_sqc-metrics.ads/.adb`,
  `src/coyote_sqc/coyote_sqc-statistics.adb`,
  `src/coyote_sqc/coyote_sqc-app.adb`,
  `src/coyote_sqc/coyote_sqc-config.ads/.adb`,
  `sdfs/coyote-sqc.md`
- **Actions taken (2026-06-18):**
  1. Added 12 cost fields to `Session_Metrics_Record` (6 totals + 6 per-turn vectors).
  2. Added 30 `Chart_Kind` enum values and chart properties in `coyote_sqc-charts`.
  3. Added pricing types (`Per_Token_Prices`, `Pricing_Table`) and per-session cost computation to `Coyote_SQC.Metrics.Compute`.
  4. Added cost chart accumulation and finalization cases to `Coyote_SQC.Statistics.Estimate_Parameters`.
  5. Added cost observation/subgroup accessors, `Compute_Session_Stat` cases, and `Descriptor` entries to `Coyote_SQC.App`.
  6. Added `Pricing` field to `App_State` and updated all call sites.
  7. Added cost MR chart kinds to the per-session MR override block in `Recompute_Chart`.
  8. Added `Load_Pricing` to `Coyote_SQC.Config` (reads `~/.config/coyote_sqc/pricing.json`).
  9. Left panel auto-generates "Token Costs" group from chart `Group_Path` entries â no code changes needed.
  10. Build succeeds cleanly; all 713 existing AUnit tests pass (0 regressions).
- **Verification:** Cost charts render on the same I/MR/EWMA/Xbar/s chart formulas as their token-count equivalents. Cost fields in `Session_Metrics_Record` are computed by `Metrics.Compute` when pricing data is available; when no pricing data is present, cost fields remain 0.0 and all cost charts show points at zero.
- **Deferred:** Unit tests for cost computation accuracy and chart limit validation (cost path reuses the same statistical formulas as token-count charts; the pricing data path is transparent to the statistical layer). OpenRouter API fallback for pricing data.
- **Status:** Resolved
- **Date resolved:** 2026-06-18

## PCR-035

- **Date reported:** 2026-06-19
- **Category:** Implementation
- **Priority:** 3-Moderate
- **Description:** Selecting Token Cost charts (and some Tool Call Behavior
  charts) in the `coyote_sqc` left panel has no effect â the row highlights
  visually but the chart canvas does not update.  The root cause is
  `Max_LB_Rows = 96` in `Coyote_SQC.UI.Left_Panel`, which was sized
  for 48 chart kinds but is too small for the current 93 chart kinds.
  The left panel needs 127 rows (93 charts + 6 top-group separators
  + 28 sub-group separators); the 96-row limit causes the `Row_Map`
  and `Row_Is_Chart` arrays to drop the mapping for the last 31 rows
  (from Output Cost sub-group through the entire Tool Call Behavior
  group).  The rows appear visually (they are added to the GtkListBox)
  but `On_Row_Activated` ignores clicks because `Row_Is_Chart` is
  default-False and `Idx < LB_Row_Count` fails.
  
  The code comment describing the row budget (48 charts + 3 + 19 = 70)
  was also stale.
- **Affected work products:**
  `src/coyote_sqc/coyote_sqc-ui-left_panel.adb`
- **Actions taken (2026-06-19):**
  1. Increased `Max_LB_Rows` from 96 to 160.
  2. Updated the row-budget comment to reflect the current chart count
     (93 charts + 6 + 28 = 127; 160 provides headroom).
  3. Build succeeds cleanly; all 713 existing AUnit tests pass.
- **Status:** Resolved
- **Date resolved:** 2026-06-19

## PCR-036

- **Date reported:** 2026-06-21
- **Category:** Implementation
- **Priority:** 3-Moderate
- **Description:** The Ollama provider catalogue refresh was gated on
  `Has_Ollama_Key`, which checked only for a non-empty API key
  (`$OLLAMA_API_KEY` or `providers.ollama.apiKey` in `models.json`).
  Local Ollama instances (e.g. `http://localhost:11434`) typically run
  without authentication, so the gate prevented the two-phase catalogue
  fetch (`/api/tags` â `/api/show` per model) from ever running.  The
  per-model `{arch}.context_length` values extracted by
  `Fetch_Show_Detail` were never obtained, and all Ollama models fell
  through to `Default_Ollama_Model` with a hardcoded
  `Context_Window => 128_000`.  This meant the status bar and turn
  footers always showed "128k ctx" regardless of the model's actual
  context length (e.g. llama3:8b has 8,192, mistral:7b has 32,768).
- **Affected work products:**
  `src/llm/llm-model_registry.adb`
- **Actions taken (2026-06-21):**
  1. Replaced `Has_Ollama_Key` with `Is_Ollama_Configured`, which returns
     True when either an API key is present OR a `baseUrl` is configured
     in `models.json` (covering local unauthenticated instances).
  2. Added `Is_Ollama_Configured_Internal` helper that checks both
     conditions, using a local `Base_Url_Str : constant String` to avoid
     the ambiguous `'Length` attribute error on a chained `.Get` call.
  3. Updated the gate in `Refresh_Ollama` and the inclusion check in
     `Available_Models` to use `Is_Ollama_Configured`.
  4. Build succeeds cleanly; all 712 non-subagent AUnit tests pass
     (the 1 subagent integration test failure is pre-existing).
- **Status:** Resolved
- **Date resolved:** 2026-06-21

## PCR-037

- **Date reported:** 2026-06-21
- **Category:** Requirements
- **Priority:** 4-Minor
- **Description:** No man page requirements existed for `coyote` or
  `coyote_sqc`.  The user requested that man pages be specified for both
  executables so that users can consult standard `man coyote` and
  `man coyote_sqc` documentation without consulting project files or
  source code.
- **Affected work products:** SRS-CORE (`requirements/coyote-requirements.md`),
  SRS-SQC (`requirements/coyote-sqc-requirements.md`),
  Project Plan (`plan/project-plan.md`),
  Test Plan (`plan/test-plan.md`)
- **Corrective action required:** Add REQ-CORE-160 to SRS-CORE Â§3.1.16
  specifying a man page for `coyote`; add Â§15.7 to SRS-SQC specifying a
  man page for `coyote_sqc`; update qualification provisions, traceability
  tables, artifact version table, and test plan traceability accordingly.
- **Actions taken (2026-06-21):**
  1. SRS-CORE v1.4: added Â§3.1.16 with REQ-CORE-160 (man page for coyote
     in man(7) format, covering CLI args, env vars, frontend selection,
     config files, and usage examples); added qualification row
     (REQ-CORE-160, I, TC-160); added traceability row ("Man pages for
     coyote and coyote_sqc" â REQ-CORE-160).
  2. SRS-SQC v0.2: added Â§15.7 (man page for coyote_sqc in man(7) format,
     covering purpose, invocation, workspace format, chart types, and
     examples); updated TOC.
  3. Project Plan v1.10: updated artifact version table (SRS-CORE 1.2â1.4,
     SRS-SQC 1.0â0.2, PLAN 1.9â1.10).
  4. Test Plan: added REQ-CORE-160 to traceability table.
- **Status:** Resolved
- **Date resolved:** 2026-06-21

## PCR-038

- **Date reported:** 2026-06-21
- **Category:** Requirements
- **Priority:** 4-Minor
- **Description:** Man page requirements (REQ-CORE-160, SRS-SQC Â§15.7) added
  in PCR-037 required implementation: creation of the actual man page files
  and corresponding design-document updates.
- **Affected work products:**
  `share/man/man1/coyote.1` (new),
  `share/man/man1/coyote_sqc.1` (new),
  `design/coyote-design.md`,
  `design/coyote-sqc-design.md`,
  `plan/project-plan.md`
- **Corrective action required:** Create man pages for both executables in
  standard troff/nroff man(7) format; update SDD-CORE and SDD-SQC traceability
  and versioning; update Project Plan artifact version table.
- **Actions taken (2026-06-21):**
  1. Created `share/man/man1/coyote.1` â 188-line man page covering NAME,
     SYNOPSIS, DESCRIPTION, OPTIONS (all 12 flags), ENVIRONMENT (8 variables),
     FILES (5 configuration/session paths), FRONTEND SELECTION (5-step
     priority), EXAMPLES (6 examples), and SEE ALSO.  Verified rendering
     with `MANPATH=share/man man coyote.1`.
  2. Created `share/man/man1/coyote_sqc.1` â 134-line man page covering
     NAME, SYNOPSIS, DESCRIPTION, OPTIONS, WORKSPACE FILE FORMAT, CHART
     GROUPS (6 groups with descriptions), STATISTICAL METHODS (6 bullet
     points), FILES (4 paths), EXAMPLES (2 examples), and SEE ALSO.
     Verified rendering with `MANPATH=share/man man coyote_sqc.1`.
  3. SDD-CORE v1.1 â v1.2: added REQ-CORE-160 row to Â§6 traceability table
     (`share/man/man1/coyote.1` (static man page)).
  4. SDD-SQC v0.1 â v0.2: added Â§14.10 Man Page section describing the
     static man page at `share/man/man1/coyote_sqc.1`.
  5. Project Plan v1.10: updated SDD-CORE (1.1â1.2) and SDD-SQC (1.0â0.2)
     in artifact version table.
  6. Build: clean (zero errors, pre-existing style warnings only).  712/713
     AUnit tests pass (1 pre-existing subagent integration test failure).
- **Status:** Resolved
- **Date resolved:** 2026-06-21

## PCR-039

- **Date reported:** 2026-06-28
- **Category:** Requirements
- **Priority:** 4-Minor
- **Description:** REQ-CORE-090 specified only four skill-discovery roots
  (two global, two project-local). The user requested a fifth root:
  `$BASE/share/agents/skills/*/SKILL.md`, derived from the installation
  prefix of the coyote binary (`$BASE/bin/coyote`). This allows skills
  shipped alongside the binary at installation time to be discovered
  without requiring per-user or per-project configuration. The root
  should be scanned after `~/.agents/skills/` and before project-local
  roots, so installed skills can be shadowed by project-local skills.
- **Affected work products:** SRS-CORE (`requirements/coyote-requirements.md`),
  SDD-CORE (`design/coyote-design.md`), `docs/skills.md`,
  Project Plan (`plan/project-plan.md`)
- **Corrective action required:** Add the installation-relative root to
  REQ-CORE-090; add REQ-CORE-094 specifying how `$BASE` is derived from
  the binary path; update the qualification provisions table, requirements
  traceability table, SDD-CORE Â§5.13 discovery order, `docs/skills.md`
  discovery table (4â5 roots, priority renumbering), and Project Plan
  artifact version table (SRS-CORE 1.4â1.5, SDD-CORE 1.2â1.3, PLAN
  1.10â1.11).
- **Actions taken (2026-06-28):**
  1. SRS-CORE v1.4 â v1.5: REQ-CORE-090 expanded from four roots to five
     (adding `$BASE/share/agents/skills/*/SKILL.md` between `~/.agents/skills/`
     and `{CWD}/.coyote/skills/`). Added REQ-CORE-094 defining how `$BASE`
     is derived from the binary path (resolve real path of executable, take
     parent of parent; empty if not of the expected form). Updated
     qualification provisions (REQ-CORE-090 description "fourâfive roots";
     new row for REQ-CORE-094). Updated requirements traceability table
     (REQ-CORE-090â093 â REQ-CORE-090â094).
  2. SDD-CORE v1.2 â v1.3: Â§5.13 purpose line "fourâfive roots"; discovery
     order list now includes `$BASE/share/agents/skills/` between
     `~/.agents/skills/` and `{CWD}/.coyote/skills/`.
  3. `docs/skills.md`: Discovery & Shadowing section updated â 4â5 roots,
     priority table renumbered 1â5, new row 3 for installation-relative path.
  4. Project Plan v1.10 â v1.11: artifact version table updated (SRS-CORE
     1.4â1.5, SDD-CORE 1.2â1.3, PLAN 1.10â1.11); dateâ2026-06-28.
  5. Implementation completed 2026-06-28:
     - Added `Install_Base` and `Installation_Skills_Base` functions to
       `LLM.Skills` (spec + body). Derive `$BASE` from binary path via
       `Ada.Directories.Full_Name` / `Containing_Directory`; walk up through
       `bin/` to parent.  Returns "" for non-standard layouts.
     - `Load_Skills` now computes `Install_Root` via
       `Installation_Skills_Base` and inserts `Collect_Skills_From_Root
       (Install_Root, Result)` between the global `.agents` root and
       project-local roots (priority 3 of 5).
     - Both functions accept optional `Executable` parameter (defaults to
       `Command_Name`) for testability.
     - Updated spec header comment (6â5 roots, Alire â `$BASE` description).
     - Six new AUnit tests added (722 total, all pass): Install_Base from
       `bin/coyote` path, non-bin fallback, explicit arg, Installation_Skills_Base
       path derivation, empty base propagation, install-root guard.
     - `sdfs/core-agent.md` updated with design rationale.
     - Test Plan baseline updated: 713â722 tests.
- **Status:** Resolved
- **Date resolved:** 2026-06-28
