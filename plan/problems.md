# Problem/Change Log — coyote

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
  verified — there was no governing document stating build strategy, risk
  register, review schedule, or configuration control procedures.
- **Affected work products:** All (Project Plan — not yet in existence)
- **Corrective action required:** Create `plan/project-plan.md` covering all
  active §5 activities per the structured-sw-developer skill checklist.
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
- **Affected work products:** SRS-CORE (`requirements/coyote-requirements.md` —
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
- **Affected work products:** SDD-CORE (`design/coyote-design.md` — not yet
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
- **Corrective action required:** Add a risk register (§7) to the Project Plan
  with identified risks, likelihood/impact, and mitigation strategies.
- **Actions taken:** Risk register §7 included in `plan/project-plan.md`
  version 1.0. Four risks identified (R1–R4).
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
- **Affected work products:** Problem/Change Log (`plan/problems.md` — not yet
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
- **Affected work products:** Test Plan (`plan/test-plan.md` — not yet in
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
- **Affected work products:** Project Plan §8 (Management Indicator History)
- **Corrective action required:** Add Management Indicator History section to
  Project Plan; populate at each joint review.
- **Actions taken:** §8 added to `plan/project-plan.md` version 1.0 (stub,
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
  method for these requirements (as stated in the Test Plan §4.5); perform
  and record each demonstration test in the Test Report (milestone M6).
  For REQ-CORE-142 (SIGTERM), add a shell-script test if feasible within the
  test suite.
- **Actions taken:** Coverage gaps documented in Test Plan §4.5 (2026-06-01).
  Deferred to milestone M6. M5 review (2026-06-03): traceability table confirmed complete — all 118 SRS-CORE requirements have an assigned verification method; 6 D-method gaps accepted per Test Plan §4.5.
- **Status:** Open

---

---

## PCR-010

- **Date reported:** 2026-06-02
- **Category:** Plans
- **Priority:** 4-Minor
- **Description:** The Project Plan purpose statement (§1) included "persists
  sessions as JSONL" — an implementation-level detail that does not belong in
  a purpose statement. A purpose statement should describe what the system does
  for users, not how it stores data internally.
- **Affected work products:** Project Plan `plan/project-plan.md` §1
- **Corrective action required:** Remove the JSONL storage detail from the
  purpose statement; retain the functional description.
- **Actions taken:** Removed "persists sessions as JSONL;" from §1 purpose
  statement 2026-06-02.
- **Status:** Resolved
- **Date resolved:** 2026-06-02

---

## PCR-011

- **Date reported:** 2026-06-02
- **Category:** Plans
- **Priority:** 3-Moderate
- **Description:** The Project Plan treated AGENTS.md as the primary source
  for requirements (§4.3) and design (§4.4), and as a controlled design
  artifact to be kept in sync with the code (R3). This is incorrect: AGENTS.md
  is operational working guidance for the agent, not a design document.
  Design documentation belongs in the dedicated design artefacts in `design/`.
  Using AGENTS.md as a primary source conflates design traceability with
  operational instructions and makes controlled change harder.
- **Affected work products:** Project Plan `plan/project-plan.md` §4.3, §4.4, §7 (R3)
- **Corrective action required:** Update §4.3 to reference SRS-CORE as
  governing requirements document; update §4.4 to designate SDD-CORE as the
  primary design artifact with AGENTS.md as secondary; update R3 to track
  SDD-CORE drift rather than AGENTS.md drift.
- **Actions taken:** §4.3, §4.4, R3, and §9 updated 2026-06-02 to reflect
  SDD-CORE as primary design source and AGENTS.md as secondary operational
  guidance.
- **Status:** Resolved
- **Date resolved:** 2026-06-02

---

## PCR-012

- **Date reported:** 2026-06-02
- **Category:** Plans
- **Priority:** 4-Minor
- **Description:** The coyote_sqc required work overview (§3) described the
  component as reading "coyote session JSONL files" — an implementation-level
  storage format detail that does not belong in a purpose statement. The
  overview should describe what the component does for users, not its internal
  data format.
- **Affected work products:** Project Plan `plan/project-plan.md` §3
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
- **Description:** SRS-CORE §3 silently omitted four DID-required sub-sections
  (Adaptation Requirements, Safety Requirements, Security and Privacy
  Requirements, Personnel and Training Requirements) without noting them as
  not applicable. The general checklist instructions (documents.md Part 1)
  require inapplicable sections to be explicitly noted rather than silently
  omitted.
- **Affected work products:** SRS-CORE `requirements/coyote-requirements.md` §3
- **Corrective action required:** Add brief N/A stub sections 3.9–3.12 to
  SRS-CORE §3 covering each omitted topic.
- **Actions taken:** Sections 3.9–3.12 added to SRS-CORE v1.1 (2026-06-02)
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
- **Category:** Requirements — performance requirement not met
- **Priority:** 2-Significant
- **Description:** REQ-SQC-2256 (SRS-SQC §13.6) states: "After the initial
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
  5. Design description updated (§4.1 Session_Parser note and §6.3
     Session_Record code block).
  All 658 existing AUnit tests pass after the change.
- **Status:** Resolved
- **Date resolved:** 2026-06-03

---

## PCR-016

- **Date reported:** 2026-06-06
- **Category:** Requirements — new capability
- **Priority:** 4-Minor
- **Description:** Users requested the ability to select two independent sets
  of sessions (Set A and Set B) for side-by-side statistical comparison.
  Comparison statistics required are: bootstrap 95% percentile CI for mean
  difference (B−A), median difference (B−A), and standard deviation ratio
  (B/A).  The right panel should show these CIs alongside per-set summary
  statistics (N, mean, median, std dev, KS/runs/dip p-values) and an
  overlapping histogram of the two sets on the active chart metric.
- **Affected work products:** SRS-SQC `requirements/coyote-sqc-requirements.md`,
  SDD-SQC `design/coyote-sqc-design.md`, `sdfs/coyote-sqc.md`
- **Corrective action required:** Add §5.17, §9.4, §9.5, and §10.3 to SRS-SQC;
  update SDD-SQC with new `Statistics.Bootstrap` package, `App_State` Set B
  fields, toolbar/menu/detail-panel additions, and overlapping histogram design;
  record design rationale in component development log.
- **Actions taken (2026-06-06):** SRS-SQC updated (new §5.17 Bootstrap CIs,
  §9.4 Two-Set Selection Mode, §9.5 Detail Panel State with Two Sets, §10.3
  Two-Set Comparison View; toolbar "Edit Set B ☐", View menu "Clear Both Sets",
  marker color table updated for Set A/B halos; 7 new test cases in §15.6).
  SDD-SQC already updated (§7.18 Bootstrap package, §11.4 Edit Set B toolbar,
  §11.5 Clear Both Sets menu, §11.6 two-set comparison view, App_State Set B
  fields).  Implementation begun 2026-06-06: `Coyote_SQC.Statistics.Bootstrap`
  package created (ads + adb), 5 AUnit tests added (665 tests, all pass),
  `App_State` extended with `Set_B`, `Edit_Set_B_Mode`, `Edit_Set_B_Button`,
  `Clear_Both_Sets_Item` fields.  UI additions complete 2026-06-06:
  toolbar "Edit Set B" toggle (`Edit_Set_B_Mode`; routes canvas selection to
  `Set_B`; orange halos on canvas), View menu "Clear Both Sets" item,
  `Refresh_Two_Set` in `Histogram_Canvas` (two-series overlay, shared bins,
  legend, CL/UCL/LCL overlays), `Build_Two_Set_View` in Detail_Panel (set
  headers, overlapping histogram, 9-row × 3-col summary statistics, Bootstrap
  95% CI frame, Add Comment frame), `Update_Menu_States` sensitivity for
  `Clear_Both_Sets_Item`.  Build passes, 665 tests all pass.
- **Status:** Resolved

## PCR-017

- **Problem:** `STORAGE_ERROR` (stack overflow) in `coyote_sqc` when clicking a
  two-set comparison with a large number of sessions.  The crash occurs inside
  the GTK button-release callback stack:
  `On_Button_Release` → `Refresh_Detail` → `Build_Two_Set_View`.
- **Root cause:** Multiple dynamically-bounded local arrays whose sizes are
  only known at run time are allocated on the call stack in subprograms along
  the two-set rendering path.  In GNAT's development build the stack frames
  for these arrays may be retained beyond the lexical scope in which they are
  declared, causing stack usage to accumulate over the call chain:
  (a) `Bootstrap.Compute` — `A_Star (1 .. M)` and `B_Star (1 .. N)` for
  the 10 000-iteration resample loop; (b) `Statistics.Tests` KS and Runs-test
  functions — `Sorted : Long_Float_Array := Values`; (c) `Compute_Dip` /
  `Dip_Test_P_Value` — `Sorted`, `Sim`, and four `array (1 .. N) of Integer`
  working arrays (`Mn`, `Mj`, `Gcm`, `Lcm`).  With large session sets the
  cumulative stack pressure exceeds the available stack, raising
  `STORAGE_ERROR` at the entry probe of the deepest callee (`Refresh_Two_Set`).
- **Classification:** Defect — implementation error (large stack allocations
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
       `Sorted : Long_Float_Array := Values` → `Sorted_V : LF_Vectors.Vector`.
     - `Dip_Test_P_Value`: `Sorted : Long_Float_Array := Values` and
       `Sim : Long_Float_Array (1 .. N)` → `Sorted_V`, `Sim_V :
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
- **Classification:** Defect — implementation error (stale widget pointer not
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
  `Build_Two_Set_View` — the path taken when `Set_B` is non-empty — never
  nulled the stats-label variables.  Consequently, after a two-set rebuild the
  labels held freed GTK widget pointers.  The next `On_Row_Activated` call
  invoked `Refresh_Histogram_If_Multi`; the `!= null` guard passed (pointer
  non-null but freed) and `Set_Text` dereferenced invalid memory, raising
  SIGSEGV → `STORAGE_ERROR`.  `Refresh_Histogram_If_Single` was identically
  exposed for the value-label variables.
- **Classification:** Defect — implementation error (missing null-out on
  widget-tree teardown for the `Build_Two_Set_View` path).
- **Corrective action:** Two changes to
  `src/coyote_sqc/coyote_sqc-ui-detail_panel.adb`:
  1. In `Refresh`, immediately after `Multi_Comment_Entry := null`, added null
     assignments for all ten stats-label package variables with a comment
     explaining the invariant.  This is the primary fix and the correct
     architectural home for these resets — it mirrors the existing pattern for
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
  (REQ-CORE-150–156), an Ollama wire format interface requirement (REQ-CORE-204),
  and update REQ-CORE-072 to include Ollama Cloud as a sixth provider.
  (2) Implement the complete provider stack: `LLM.Providers.Ollama` package,
  `Ollama.Catalogue` subpackage with `/api/tags` support, model-registry
  integration, and agentic-loop dispatch. (3) Add unit tests. (4) Update design
  documentation and component log. (5) Document live integration test guard.
- **Actions taken (2026-06-06):**
  1. **SRS-CORE updated to v1.2** — added §3.1.15 (REQ-CORE-150 through
     REQ-CORE-156) covering provider selection, configurable base URL,
     bearer-token authentication (`OLLAMA_API_KEY`), model registry population
     via `GET /api/tags`, NDJSON streaming wire format, `"ollama"` `Wire_Format`
     designation, and token usage extraction; added REQ-CORE-204 to §3.2.1;
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
       in `Create`, (c) added two dispatch branches (main loop ≈line 1490,
       summarisation ≈line 1282).
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
     - SDD-CORE §4.1 (Software Unit Inventory) — added LLM.Providers.Ollama
       and Ollama.Catalogue entries.
     - SDD-CORE §6.1 (Provider Dispatch) — added Ollama case to dispatch tables.
     - `sdfs/providers.md` — recorded design rationale (NDJSON streaming vs.
       chunked, localhost unauthenticated bypass, cache path, Wire_Format
       conformance), wire-format notes, and test coverage strategy.
     - `plan/integration-test-guide.md` — added Ollama integration test section
       with guard variable `COYOTE_RUN_OLLAMA_LIVE=1` and example commands.
- **Verification (2026-06-06):** Build clean (zero errors/warnings); AUnit
  suite passes 665/665 tests (unit + existing). Compilation successful for
  all Ollama modules. All new test cases pass. No regressions in existing code.
  Live integration test guard documented.
- **Completion status:** **COMPLETE** — implementation, unit tests, design
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
  `coyote.adb` hits step 3 (`$DISPLAY` present → GUI frontend) rather than
  step 2 (`$winid` present → acme frontend), so the session opens in a GTK
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
     REQ-CORE-002/003/004/005 and traceability table), SDD-CORE (§5.1
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
  1–3 words) with leading or trailing newlines.  The acme frontend's
  `Append_Thinking` splits the incoming text on `\n` and wraps every fragment
  on its own line with a `│ ` box-drawing prefix, producing output like:

  ```
  │ The
  │  user
  │  wants me
  │  to commit
  ```
  rather than flowing text:
  ```
  │ The user wants me to commit…
  ```

  The GUI frontend suffers a similar but milder version: each delta chunk is
  inserted into a styled tag region but still appears as disjoint fragments
  rather than flowing prose.

  Root cause: `Append_Thinking` in the acme frontend (`coyote_app-frontend-acme_win.adb`
  lines 102–126) treats every `\n` in the incoming delta as a hard line break and
  re-emits the box-drawing prefix after each one.  `Normalize_Thinking_Delta` in
  `llm-providers-openai_completions.adb` (line 164) strips leading/trailing
  newlines from each chunk but does not address the fundamental mismatch between
  the chunked stream and the display layer's line-break semantics.  The
  Anthropic-Messages provider (`llm-providers-anthropic_messages.adb` line 779)
  emits thinking deltas with no normalization at all.  Other providers
  (Ollama, OpenCode) may also pass through unnormalized deltas.
- **Affected work products:**
  - `src/coyote_app-frontend-acme_win.adb` — `Append_Thinking` (lines 102–126),
    `Begin_Thinking` (line 96, currently a no-op), `End_Thinking` (line 130,
    currently a no-op)
  - `src/coyote_app-frontend-gui.adb` — thinking display path
  - `src/coyote_app-frontend-plain.adb` — thinking display path
  - `src/llm/llm-providers-openai_completions.adb` — `Normalize_Thinking_Delta`
    only normalizes per-chunk whitespace; does not solve the chunk-to-flow
    reassembly problem
  - `src/llm/llm-providers-anthropic_messages.adb` — thinking delta emission
    (line 779) with no normalization
  - `src/llm/llm-events.ads` — `Message_Update_Event` / `Message_Update_Kind`
    thinking event hierarchy
  - `sdfs/frontends.md` — component development log for frontend thinking display
- **Corrective action required:** Redesign the thinking-text display so that
  all per-chunk `\n` characters are collapsed into spaces (producing flowing
  prose) rather than preserved as hard line breaks.  Only explicit paragraph
  breaks (double newline, i.e. `\n\n`) from the model should produce a new
  visual line.  The solution should be one of:
  1. **Provider-side normalisation** — strip all single `\n` from each delta
     before emission, converting to spaces.  Preserve `\n\n` through a
     buffer-based lookahead.
  2. **Frontend-side buffering** — buffer all thinking delta text in the
     frontend (`Begin_Thinking` opens the buffer; `Append_Thinking` accumulates;
     `End_Thinking` flushes collapsed text).  This centralises the fix in one
     layer but requires `Begin_Thinking` and `End_Thinking` to become active
     in the acme frontend (currently no-ops).
  3. **Two-phase display** — render thinking text only at `Thinking_End`
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
  "content")` — true even for the empty string), causing the frontend to
  flush the partial thinking buffer and emit a separate `│`-prefixed line
  after every word.  The fragmented output reported in the original
  description was therefore caused by a combination of (a) the original
  per-chunk `\n` splitting issue and (b) this premature `Thinking_End`
  emission, with (b) being the dominant factor.  Fixed by:
  1. Extracting `Content : constant String := Get_String_Field (…,
     "content")` once, emitting `Thinking_End` only when
     `Content'Length > 0`, and suppressing empty `Text_Delta` events
     (`llm-providers-openai_completions.adb` lines 764–782, streaming).
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
  `GitHub_Copilot.Refresh_Token` — a live HTTP call to
  `api.github.com/copilot_internal/v2/token`.  When GitHub returns non-200
  (lapsed subscription, network error, etc.), `Auth_Error` is raised and
  propagates unhandled, killing the process before the acme window or GUI
  window is created.
- **Affected work products:**
  - `src/llm/llm-model_registry.adb` — `Refresh_GitHub_Copilot`
    unconditionally called `Ensure_Valid` and loaded the catalogue without
    graceful failure handling; `Lookup` raised `Not_Found` for unknown
    Copilot model IDs
  - `src/llm/llm-model_registry.ads` — spec comments for
    `Refresh_GitHub_Copilot` and `Lookup`
  - `test/src/llm_model_registry_tests.adb` — `Test_GitHub_Copilot_Not_Found`
    expected `Not_Found`; renamed to `Test_GitHub_Copilot_Default_Fallback`
  - `test/src/llm_model_registry_tests.ads` — renamed test procedure
  - `test/src/test_suites.adb` — updated test registration string
  - `sdfs/providers.md` — updated token-refresh description
- **Corrective action required:**
  1. Make `Refresh_GitHub_Copilot` fail soft: do not call `Ensure_Valid` at
     startup; instead check `Token_Expired` and return early if the cached
     token has expired.  Wrap the catalogue load in an exception handler
     (`when others => null`) so any network failure, auth failure, or parse
     error leaves the Copilot registry empty rather than crashing.
  2. Add `Default_GitHub_Copilot_Model` — a function returning a conservative
     `Model_Info` with a model-ID-based wire-format heuristic (model IDs
     containing "claude" → `"anthropic-messages"`, others →
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
  2. Wrapped catalogue load in `begin … exception when others => null; end`
     block — network errors, lapsed subscriptions, JSON parse failures are
     all silently swallowed, leaving the Copilot registry empty.
  3. Added `Default_GitHub_Copilot_Model(Model_Id)` function: returns a
     `Model_Info` with `Context_Window => 128_000`, `Max_Tokens => 4_096`,
     and a wire-format heuristic (`"claude"` in model ID →
     `"anthropic-messages"`, else `"openai-completions"`).  All cost fields
     zeroed so no cost inflation occurs until real pricing is available.
  4. Updated `Lookup` for `"github-copilot"`: calls
     `Default_GitHub_Copilot_Model(Model_Id)` instead of raising
     `Not_Found`.
  5. Renamed test `Test_GitHub_Copilot_Not_Found` →
     `Test_GitHub_Copilot_Default_Fallback`; test now asserts that
     `Lookup("github-copilot", "nonexistent")` returns a default record with
     `Provider = "github-copilot"` and `Wire_Format = "openai-completions"`;
     added a second assertion for `"claude-unknown"` → `"anthropic-messages"`.
  6. Updated `sdfs/providers.md` — rewrote token-refresh section to describe
     deferred-on-request semantics, graceful degradation at startup, and the
     automatic restore path (`coyote login github-copilot` → fresh
     credentials → next startup populates catalogue).
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
  §3.1.2 specifying `-h` and `--help` arguments that print usage and exit.
- **Actions taken:** REQ-CORE-024 added 2026-06-11.  Implementation completed 2026-06-11: `Print_Usage` procedure added to `coyote.adb`; `-h` and `--help` parsed in argument loop, printing usage to stdout and exiting with success status.  Demo test TC-024 added to Test Plan §4.3.
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
  SRS-CORE §3.1.7 specifying that OpenCode Go model metadata shall be
  obtained by cross-referencing the Go model list against the OpenRouter
  catalogue.  Update SDD-CORE §5.25 and `sdfs/providers.md` accordingly.
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
  `Parse_Usage` for DeepSeek models.  Update SDD §5.6 and SDF.
- **Actions taken (2026-06-14):**
  1. Added `cache_control` on last user/tool message after the
     message-building loop, before `Request.Set_Field("messages", Msgs)`,
     mirroring the Anthropic provider's strategy.
  2. Added DeepSeek fallback in `Parse_Usage`: if `cached_tokens` is zero,
     read `prompt_cache_hit_tokens` directly from the usage object.
  3. Updated SDD-CORE §5.6 with a Cache breakpoints paragraph.
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
  indistinguishable — the viewer could not tell which limit belonged to which
  component.  The user requested a lozenge-shaped representation (rectangular
  body with triangular end caps pointing to the UCL and LCL values) to improve
  limit resolvability when limits overlap.
- **Affected work products:** SRS-SQC (`requirements/coyote-sqc-requirements.md`
  §7.3.2a, §7.3.3, §15.6), SDD-SQC (`design/coyote-sqc-design.md` §12.6 step
  6a, §12.7), `src/coyote_sqc/coyote_sqc-ui-chart_canvas.adb` (control-limit
  drawing and halo drawing)
- **Corrective action required:** Update requirements to describe lozenge shape;
  update design with lozenge geometry (triangular tips at UCL/LCL, rectangular
  body spanning `UY+TH` to `LY-TH`, `TH = half_width × 0.5`); implement
  lozenge-shaped Cairo closed path in chart canvas; build and test.
- **Actions taken (2026-06-15):**
  1. SRS-SQC §7.3.2a: "hollow rectangle" → "hollow lozenge shape — a rectangular
     body with triangular end caps"; "Box width" → "Lozenge width"; "rectangle top
     is the UCL" → "lozenge top tip is the UCL"; "rectangles" → "lozenges";
     "control boxes" → "control lozenges".  SRS-SQC §7.3.3: "control box" →
     "control lozenge" (3 rows).  SRS-SQC §15.6 test description: "gray box" →
     "gray lozenge".
  2. SDD-SQC §12.6 step 6a: "Control box: a hollow rectangle" → "Control box: a
     lozenge shape (rectangular body with triangular end caps)"; added geometry
     description (triangular tips at UCL_j and LCL_j, rectangular body from
     `UY+TH` to `LY-TH`, `TH = half_width × 0.5`).  SDD-SQC §12.7 table: eight
     "box" entries → "lozenge".  Test section: "gray boxes" → "gray lozenges".
  3. Implementation: replaced `Cairo.Rectangle` call with a six-vertex lozenge
     closed path (`Move_To` → 5 × `Line_To` → `Close_Path` → `Stroke`).  Updated
     comment from "Draw control-limit box" to "Draw control-limit lozenge".
  4. Build: clean (style warnings only, no errors).  All 688 tests pass.
- **Status:** Resolved
- **Date resolved:** 2026-06-15

### PCR-029 — Adaptive Anchor Interpolation for Quantile CC

- **Date opened:** 2026-06-15
- **Originator:** Developer (user request)
- **Priority:** Minor (enhancement)
- **Category:** Design improvement
- **Description:** The Quantile Control Chart interpolation scheme (SRS-SQC
  §5.18, SDD-SQC §7.19) used a fixed a-priori anchor grid with heuristic
  constants (`C = 0.5`, `δ = 0.15`) and origin-scaling in `√n` space
  (`HW(n) = HW(n_a) × √(n_a/n)`).  The user was intellectually dissatisfied
  with the inability to verify the interpolation error on actual data and
  with the opaque heuristic constants.  The user requested replacement with
  an adaptive scheme that measures error rather than assuming it.
- **Affected work products:** SRS-SQC (`requirements/coyote-sqc-requirements.md`
  §5.18 "Interpolated Limits"), SDD-SQC (`design/coyote-sqc-design.md` §7.19
  "Interpolated Limits"), `src/coyote_sqc/coyote_sqc-statistics-quantile_cc.ads`,
  `src/coyote_sqc/coyote_sqc-statistics-quantile_cc.adb`, `sdfs/coyote-sqc.md`.
- **Corrective action required:** Replace fixed-anchor origin-scaling with
  adaptive bisection in `x = 1/√n` space using linear interpolation between
  two bounding anchors.  Anchors are placed only where the interpolation error
  exceeds a configurable tolerance (5% of half-width, 1-token floor).  Remove
  heuristic constants `Interp_Delta`, `Interp_C`.  Retain discrete regime
  (exact bootstrap at 2..16).  Update all documentation.
- **Actions taken (2026-06-15):**
  1. SRS-SQC §5.18 rewritten: coordinate transformation, discrete regime,
     adaptive anchor placement algorithm, tolerance, error guarantee, fallback.
  2. SDD-SQC §7.19 rewritten with algorithm steps, constants, and error
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
  hang (O(N²) performance regression).  When the MI (mutual information)
  diversity chart feature was added (commit `4e7aae2`), the new MI computation
  block and its summation loop were mistakenly inserted between the
  `for V of M.Per_Consecutive_Tool_S loop` header and its body statement
  (`M.Total_Tool_Call_JSD_S := …`).  This nested the MI computation (which
  iterates all N tool-call pairs and performs zlib deflate at level 9 for each)
  inside the O(N) JSD summation loop, yielding O(N²) overall complexity.  For
  a session with even a moderate number of tool-call pairs, the MI computation
  ran N² times instead of once — each zlib compression being CPU-intensive —
  producing the appearance of a hang.
- **Root cause:** Structural editing error — the MI computation block and its
  sum loop were placed inside the body of the JSD summation `for` loop rather
  than after its `end loop;`.
- **Affected work products:** `src/coyote_sqc/coyote_sqc-metrics.adb`,
  `sdfs/coyote-sqc.md`, `plan/problems.md`
- **Corrective action required:** Move the MI computation block and MI
  summation loop from inside the JSD sum loop to after its `end loop;`,
  restoring O(N) complexity.  Add a blank line before `return M`.
- **Actions taken (2026-06-16):**
  1. Moved lines 103–136 (MI compute block + MI sum loop) from inside the JSD
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
  incorrectly nested inside the `if Props.Is_EWMA_Chart … then` block.  Since
  no chart is simultaneously an EWMA chart and an Xbar/s chart, the code was
  unreachable — `Plot_Method` was never set, always retaining its default
  `Classical`.  (2) The same nesting error existed in the `On_Reset` handler:
  the Plot Method combo reset was inside the EWMA if-block and therefore never
  executed for Xbar/s charts (though this bug was masked by the read-never-
  happens bug).
- **Affected work products:** `src/coyote_sqc/coyote_sqc-ui-chart_settings_dialog.adb`
- **Corrective action required:** Move the Plot Method read block out of the
  EWMA conditional in the OK handler, making it an independent `if` at the same
  nesting level.  Apply the same restructuring to `On_Reset`.
- **Actions taken (2026-06-17):**
  1. OK handler (~line 603): moved `if Props.Is_Xbar_S_Chart … PM_C …` block
     from inside `if Props.Is_EWMA_Chart …` to after its `end if;`, as a
     sibling conditional.
  2. `On_Reset` handler (~line 253): same restructuring — EWMA reset and Xbar/s
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

### PCR-024 — Control-limit estimation method ignored during variance-stabilizing transform

**Date:** 2026-06-17
**Status:** Resolved
**Category:** Implementation defect (logic error)
**Priority:** Moderate
**Severity:** High — control limits silently wrong when Robust_Median
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

1. I-chart transform block — moved `Grand_Mean` inside the
   estimation-method branch (`Robust_Median → Median_Of`, `Classical →
   Sum_Z / N_Raw`).

2. Xbar/S transform block — restructured `if Max_Vals > 0 then` to branch
   on `Estimation_Method`: the robust path collects per-session means and
   residuals in z-space and computes `Grand_Mean` as the median of session
   means and `Pooled_S` as `Qn_Scale_Any` of residuals.

**Tests:** Full test suite (713 tests) passes — 0 failures.

**Documents updated:**
- `requirements/coyote-sqc-requirements.md` §5.7 — "Grand mean and pooled s
  in transformed space" now describes both Classical and Robust_Median paths.
- `design/coyote-sqc-design.md` §7.9 step 2 — updated to reference both
  §7.5 (classical) and §7.13 (robust) formulae.
- `design/coyote-sqc-design.md` §7.10 "Transformed-space parameters" —
  expanded to describe both classical and robust parameter computation.
- `design/coyote-sqc-design.md` §7.13 "Interaction with Box-Cox" —
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
  inserting `ASCII.LF` between chunks — which landed inside a JSON string
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
  control charts (§6.52–§6.81 in SRS, §6.7 enums + §7.20 cost computation in
  SDD), but no implementation exists — no cost fields in
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
  9. Left panel auto-generates "Token Costs" group from chart `Group_Path` entries — no code changes needed.
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
  charts) in the `coyote_sqc` left panel has no effect — the row highlights
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
  fetch (`/api/tags` → `/api/show` per model) from ever running.  The
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
- **Corrective action required:** Add REQ-CORE-160 to SRS-CORE §3.1.16
  specifying a man page for `coyote`; add §15.7 to SRS-SQC specifying a
  man page for `coyote_sqc`; update qualification provisions, traceability
  tables, artifact version table, and test plan traceability accordingly.
- **Actions taken (2026-06-21):**
  1. SRS-CORE v1.4: added §3.1.16 with REQ-CORE-160 (man page for coyote
     in man(7) format, covering CLI args, env vars, frontend selection,
     config files, and usage examples); added qualification row
     (REQ-CORE-160, I, TC-160); added traceability row ("Man pages for
     coyote and coyote_sqc" → REQ-CORE-160).
  2. SRS-SQC v0.2: added §15.7 (man page for coyote_sqc in man(7) format,
     covering purpose, invocation, workspace format, chart types, and
     examples); updated TOC.
  3. Project Plan v1.10: updated artifact version table (SRS-CORE 1.2→1.4,
     SRS-SQC 1.0→0.2, PLAN 1.9→1.10).
  4. Test Plan: added REQ-CORE-160 to traceability table.
- **Status:** Resolved
- **Date resolved:** 2026-06-21

## PCR-038

- **Date reported:** 2026-06-21
- **Category:** Requirements
- **Priority:** 4-Minor
- **Description:** Man page requirements (REQ-CORE-160, SRS-SQC §15.7) added
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
  1. Created `share/man/man1/coyote.1` — 188-line man page covering NAME,
     SYNOPSIS, DESCRIPTION, OPTIONS (all 12 flags), ENVIRONMENT (8 variables),
     FILES (5 configuration/session paths), FRONTEND SELECTION (5-step
     priority), EXAMPLES (6 examples), and SEE ALSO.  Verified rendering
     with `MANPATH=share/man man coyote.1`.
  2. Created `share/man/man1/coyote_sqc.1` — 134-line man page covering
     NAME, SYNOPSIS, DESCRIPTION, OPTIONS, WORKSPACE FILE FORMAT, CHART
     GROUPS (6 groups with descriptions), STATISTICAL METHODS (6 bullet
     points), FILES (4 paths), EXAMPLES (2 examples), and SEE ALSO.
     Verified rendering with `MANPATH=share/man man coyote_sqc.1`.
  3. SDD-CORE v1.1 → v1.2: added REQ-CORE-160 row to §6 traceability table
     (`share/man/man1/coyote.1` (static man page)).
  4. SDD-SQC v0.1 → v0.2: added §14.10 Man Page section describing the
     static man page at `share/man/man1/coyote_sqc.1`.
  5. Project Plan v1.10: updated SDD-CORE (1.1→1.2) and SDD-SQC (1.0→0.2)
     in artifact version table.
  6. Build: clean (zero errors, pre-existing style warnings only).  712/713
     AUnit tests pass (1 pre-existing subagent integration test failure).
- **Status:** Resolved
- **Date resolved:** 2026-06-21

## PCR-039

- **Date reported:** 2026-07-02
- **Category:** Code
- **Priority:** 2-Serious
- **Description:** Aborting during a retry sequence leaves `Is_Retrying`
  permanently `True`. After the user clicks Stop, the agentic loop aborts
  and `Agent_End_Event` resets `Streaming`, `Paused`, `Pause_Armed`, and
  `Aborted` — but not `Is_Retrying`. The next Send is blocked with
  *"Agent is running (retrying) — use Steer to redirect or Stop first"*
  because `Is_Retrying` is still set.
- **Root cause:** The `Agent_End_Event` handler in
  `src/coyote_app-dispatch.adb` (line 175) resets three state flags but
  omits `Is_Retrying`. The `Auto_Retry_End_Event` handler is the only
  code path that clears `Is_Retrying`, and it is only reached on retry
  success or retry exhaustion — not on abort.
- **Affected work products:** `src/coyote_app-dispatch.adb`
- **Corrective action required:** Add `State.Set_Is_Retrying (False)` to
  the `Agent_End_Event` handler alongside the other state-clearing calls.
- **Actions taken (2026-07-02):**
  1. Added `State.Set_Is_Retrying (False);` after
     `State.Set_Pause_Armed (False);` in `Dispatch_Event`
     (`coyote_app-dispatch.adb` line 178).
- **Status:** Resolved
- **Date resolved:** 2026-07-02

---

## PCR-013: Stop button doesn't abort tool calls with timeout

- **Date discovered:** 2026-07-11
- **Severity:** High
- **Category:** Defect — abort mechanism ignores timeout-bearing shell commands
- **Description:** Clicking `Stop` during a tool call that includes a
  `timeout` parameter has no effect on the running child process. The
  `Timer` task in `LLM.Tools.Shell.Execute` only watches the timeout
  delay; it never checks `Abort_Flg`. The abort-aware `Abort_Watcher`
  lives in a separate `else` branch that is only reached when
  `Timeout_Seconds = 0`.
- **Root cause:** In `src/llm/llm-tools-shell.adb` the `if Timeout_Seconds >
  0` branch spawned a `Timer` task with a simple `delay` statement that
  never polled `Abort_Flg`. The `select or delay` abort-watching
  construct was only present in the `else` / `Abort_Flg /= null` branch.
- **Affected work products:** `src/llm/llm-tools-shell.adb`
- **Corrective action required:** Modify the `Timer` task in the timeout
  branch to race the timeout delay against `Abort_Flg.Wait_Requested`
  using an Ada timed-entry-call `select … or delay` construct.
- **Actions taken (2026-07-11):**
  1. Replaced the plain `delay Duration (Timeout_Seconds)` in `Timer`
     with a `select or delay` construct that waits for either the
     timeout to expire or `Abort_Flg.Wait_Requested` to complete.
  2. Added `Killed : Boolean` flag to track kill completion for the
     exception handler.
  3. `Timer_Fired` is only set when the timeout fires first, preserving
     the correct post-loop message ("timed out" vs "aborted").
  4. Updated leading comment block to document the dual-watch behavior.
- **Status:** Resolved
- **Date resolved:** 2026-07-11
- **Test baseline:** All 729 previously-passing tests remain green.
  Pre-existing failure (LLM.System_Prompt preserves section order)
  is unrelated.

---

## PCR-040

- **Date reported:** 2026-07-12
- **Category:** Requirements
- **Priority:** 3-Moderate
- **Description:** Agent capability study of Claude Code (vscode-copilot-chat
  extension) and GitHub Copilot Chat source code identified six feature areas
  where coyote's problem-solving capabilities could be improved. No existing
  coyote functionality is broken; these are forward-looking enhancements.
- **Feature areas identified:**
  1. **Enhanced system prompt** — personality definition, conditional tool-use
     instructions, per-turn reminder instructions (REQ-CORE-170..172).
  2. **Structured memory system** — four-type taxonomy (user/feedback/project/
     reference) with MEMORY.md index files (REQ-CORE-180..183).
  3. **Coordinator subagent orchestration** — synthesis-before-delegation
     prompt guidance, structured subagent result reporting (REQ-CORE-190..192).
  4. **Nine-section compaction prompt** — structured summary format with
     analysis-block drafting (REQ-CORE-065, REQ-CORE-066).
  5. **Auto-compact circuit breaker** — suspend after 3 consecutive failures
     (REQ-CORE-067).
  6. **Partial compaction** — keep N most recent turns verbatim, summarise
     only the earlier portion (REQ-CORE-068).
- **Affected work products:** SRS-CORE (14 new requirements added, v1.5→v1.6);
  SDD-CORE (design updated for compaction, memory, system prompt, coordinator);
  Test Plan (demonstration tests added for new requirements); Project Plan
  (Review 7 recorded).
- **Corrective action required:** Implement the 14 new requirements in
  `LLM.Compaction`, `LLM.System_Prompt`, `LLM.Memory` (new package), and
  `LLM.Agent`. Add AUnit tests for each implemented requirement.
- **Actions taken (2026-07-12):**
  1. Requirements added to SRS-CORE v1.6.
  2. Design sections updated in SDD-CORE v1.4.
  3. Demonstration tests added to Test Plan v1.4.
  4. Project Plan updated with Review 7.
- **Implementation actions (2026-07-12):**
  1. Created `LLM.Memory` package (ads + adb) with MEMORY.md discovery from
     `~/.coyote/memory/` and `{CWD}/.coyote/`, content capping at 200 lines /
     25 000 bytes, and four-type memory taxonomy formatting
     (REQ-CORE-180..183).
  2. Extended `LLM.System_Prompt.Build_System_Prompt` with: personality
     definition (terse/direct/pragmatic, no cheerleading — REQ-CORE-170),
     conditional tool-use instructions keyed to `Has_Editing_Tools`
     (REQ-CORE-171), coordinator subagent-orchestration guidance when
     `Coordinator_Mode` is true (REQ-CORE-190..192), and `Memory_Block`
     integration (REQ-CORE-180..183).
  3. Added `Build_Reminder_Instructions` function returning per-turn
     reminder text (persist until resolved, progress updates, varied
     phrasing — REQ-CORE-172).
  4. Rewrote `LLM.Compaction.Summarization_Prompt` and
     `Update_Summarization_Prompt` with nine-section format and
     `<analysis>` drafting-block instruction (REQ-CORE-065, REQ-CORE-066).
  5. Added `Strip_Analysis_Block` function to strip `<analysis>` from
     stored summaries before injecting into context (REQ-CORE-066).
  6. Added `Build_Compact_Prompt` function consolidating prompt assembly
     with optional previous-summary and partial-compact preamble.
  7. Added circuit breaker to `Compact_Settings`: `Consecutive_Failures`
     counter and `Tripped` flag; `Should_Compact` returns False when
     tripped; `Max_Consecutive_Failures = 3` (REQ-CORE-067).
  8. Integrated per-turn reminder into `LLM.Agent.Run_Prompt`: each user
     prompt carries the reminder block appended after the user's text.
  9. Integrated circuit-breaker logic in `LLM.Agent.Run_Prompt`: reset
     `Consecutive_Failures` on success; increment on failure; set `Tripped`
     when threshold reached.
  10. Integrated analysis-block stripping in `LLM.Agent.Compact`: summary
      stored in session JSONL and in-memory history has `<analysis>`
      removed.
  11. Updated all `Compact_Settings` aggregate initializations in
      `coyote_app.adb` and test files to include new fields.
  12. All 560 existing AUnit tests pass (0 regressions in compaction,
      system prompt, or agent areas).
- **Status:** Resolved
- **Date resolved:** 2026-07-12


### PCR-041 — GUI conversation view cramped layout (2026-07-29)

- **Problem:** The GTK conversation view had no visual separation
  between content blocks — turns ran together with no separators,
  paragraphs and headings were flat, tool frames had minimal padding,
  and code blocks/blockquotes were visually indistinguishable from
  surrounding text.  This made long conversations hard to scan.
- **Fix:**
  1. **Turn separators:** `Append_Turn_Footer` re-enabled in GUI
     frontend; now renders a dim horizontal rule (60 × `UC_HORIZ`)
     between turns via the `footer` tag.
  2. **Inter-block spacing:** Blank lines (`LF LF`) added at every
     content-section transition (`End_Text_Block`, `End_Thinking`,
     `Begin_Tool`, `Append_Notice`).
  3. **Tool-call frame styling:** Added 6 px border width, etched-in
     shadow, increased inner spacing from 2 → 6 px.
  4. **Markdown rendering improvements** (in `Coyote_Renderer.Markup`):
     headings sized by level (larger/medium/bold), paragraphs separated
     by blank lines, code blocks given a `#f4f4f4` background,
     blockquotes prefixed with `╎` vertical bar and rendered with a
     single `<span>` instead of nested `<i>`/`<span>`.
  5. **Conversation view margins** increased from 8/6 px to 16/12 px.
- **Files changed:**
  - `src/coyote_gui/coyote_gui-buffer.adb` — all block transitions,
    tool frame styling, turn separators
  - `src/coyote_app-frontend-gui.adb` — un-suppressed
    `Append_Turn_Footer`, increased margins
  - `src/coyote_renderer/coyote_renderer-markup.adb` — heading sizing,
    paragraph spacing, code-block background, blockquote prefix
- **Status:** Resolved
- **Date resolved:** 2026-07-29


## PCR-042 — GUI streaming UTF-8 codepoint fragmentation (2026-08-04)

- **Category:** Code
- **Priority:** 3-Moderate
- **Description:** The GTK conversation renderer sanitized each text and thinking
  update independently. A valid UTF-8 codepoint split across update records was
  therefore replaced by multiple U+FFFD characters. The GUI update queue also
  silently discarded records at capacity.
- **Affected work products:** `Coyote_GUI.Conversation`, `Coyote_App.Utils`,
  `Coyote_GUI.Updates`, GUI test suite, frontend design records.
- **Corrective action:** Added stateful UTF-8 decoders for assistant text and
  thinking streams; retained raw assistant text for final rendering; made the
  update queue block while full and added shutdown release semantics; added
  regression tests for two-, three-, and four-byte split sequences and GUI
  text/thinking streams.
- **Verification:** Development build succeeds; full AUnit suite passes with
  812 tests, 0 failures, and 0 unexpected errors.
- **Status:** Resolved
- **Date resolved:** 2026-08-04


## PCR-043 — GTK idle callback CPU spin (2026-08-04)

- **Category:** Code
- **Priority:** 2-High
- **Description:** The GTK frontend kept a GLib idle source registered for the
  frontend lifetime. Its callback returned `True` even when the protected
  update queue was empty, causing the GTK main loop to spin at approximately
  100% CPU while idle.
- **Affected work products:** `Coyote_App.Frontend.GUI`, `Coyote_GUI.Updates`,
  GUI design and frontend development records, GUI regression tests.
- **Corrective action:** Changed idle-source registration to be edge-triggered.
  The protected update queue atomically reserves the source on the first
  enqueue, keeps it active while updates remain, and releases the reservation
  when the callback observes an empty queue. This prevents both idle spinning
  and competing source registration during concurrent enqueue/callback
  activity.
- **Verification:** Development build succeeds; six focused queue lifecycle
  tests pass. Idle runtime measurement changed from 100% CPU (`4.68s` user and
  `3.33s` system over 8 seconds) to approximately 1% CPU (`0.10s` user and
  `0.02s` system over 8 seconds). The complete suite was not completed because
  provider catalogue/network activity caused the test process to stall in the
  current environment.
- **Status:** Resolved
- **Date resolved:** 2026-08-04


## PCR-044 — Sandbox profile session persistence requirements (2026-08-04)

- **Category:** Requirements
- **Priority:** 2-Serious
- **Description:** Investigation found that sandbox profiles were active only
  in the in-memory agent, were not restored from saved sessions, were not
  changed when switching sessions, and could become inconsistent across the
  frontend, agent, and child-process environment. The SRS did not define the
  required persistence, restoration, propagation, or synchronization behavior.
- **Affected work products:** SRS-CORE, SDD-CORE, Test Plan, Project Plan.
- **Corrective action required:** Add requirements for save/resume restoration,
  profile restoration on session switching, clearing on switching to a session
  without a profile, end-to-end child propagation, and synchronization between
  frontend and agent state. Add traceability and planned tests.
- **Actions taken (2026-08-04):**
  1. Added REQ-CORE-085 through REQ-CORE-089 to
     `requirements/coyote-requirements.md` and advanced SRS-CORE to v1.8.
  2. Added qualification and objective traceability for the new requirements.
  3. Updated SDD-CORE traceability to REQ-CORE-080–089 and advanced it to
     v1.7.
  4. Updated Test Plan v1.7 with automated and demonstration coverage
     references TC-085..089 and DEM-029..032.
  5. Updated the Project Plan artifact table for SRS-CORE, SDD-CORE, and the
     Test Plan.
  6. Added `Session_Sandbox_Profile` and restored profile state in
     `LLM.Agent.Create` and `LLM.Agent.Switch_Session`.
  7. Added Acme and GUI `Synchronize_Sandbox` orchestration for startup,
     new-session creation, and session switching.
  8. Added one session-store test and two agent restoration/switch tests;
     focused tests passed.
  9. Development build succeeded and the complete AUnit suite passed with
     821 tests, 0 failures, and 0 unexpected errors.
- **Status:** Resolved
- **Date resolved:** 2026-08-04

**Documentation follow-up (2026-08-04):** Updated `AGENTS.md`, the Project
Plan, Test Plan, integration-test guide, frontend/core SDFs, review-plan notes,
and review reports to reflect the implemented restoration and synchronization
behavior, current test baseline, and remaining manual qualification scope.


## PCR-046 — GTK status omits active sandbox after prompt start (2026-08-06)

- **Category:** Code
- **Priority:** 2-Serious
- **Description:** The GTK status line displayed the active sandbox profile
  after a profile selection, but the first `Agent_Start_Event` replaced it
  with a status string from `Format_Status` that omitted sandbox state.
  Subsequent lifecycle events repeated the omission.
- **Affected work products:** `Coyote_App.Dispatch`, `Coyote_App`, status
  formatter tests, dispatch tests, Test Plan.
- **Corrective action:** Made `Format_Status` the single status composition
  path for sandbox text. Removed duplicate sandbox suffixing from the Acme and
  GUI `Status_Label` helpers so explicit status updates cannot duplicate the
  profile. Added formatter and session-info dispatch regressions.
- **Verification:** Development build and focused/full AUnit tests.
- **Status:** Resolved
- **Date resolved:** 2026-08-06


## PCR-045 — GUI interleaved tool-call detail selection (2026-08-04)

- **Category:** Code
- **Priority:** 2-Serious
- **Description:** The GTK conversation renderer assigned every completed
  tool block a range extending to the current document end and replaced the
  document's last footer. When a turn contained multiple tool calls, all
  completion events therefore overlapped the displayed ranges and clicking
  later tool calls returned the first tool's detail.
- **Affected work products:** `Coyote_GUI.Conversation`, GUI conversation
  tests, core design description, frontend development log, Test Plan.
- **Corrective action:** `Tool_Start_Info` now stores the exact footer line
  when `Begin_Tool` appends a block. `End_Tool` updates that stored footer and
  records a block range ending at the tool's own footer. Added a regression
  test covering two starts followed by two completions and selection of the
  second tool.
- **Verification:** Development build succeeds. The focused GUI
  conversation tests pass, including the new interleaved-tool regression.
  A full-suite run was attempted but timed out during existing live/network
  activity; no failure was attributed to this change.
- **Status:** Resolved
- **Date resolved:** 2026-08-04


## PCR-048 — Dedicated GTK subagent model preference (2026-08-08)

- **Category:** Requirements, Design, Implementation, Test
- **Priority:** 3-Moderate
- **Description:** The GTK Preferences dialog exposed only the ordinary
  session default model. Subagent invocations therefore used the ordinary
  default unless callers supplied `--model` explicitly.
- **Affected work products:** SRS-CORE, SDD-CORE, Test Plan, README,
  `LLM.Settings`, `LLM.Agent`, GTK Preferences, prompt queue, and regression
  tests.
- **Actions taken:** Added optional `defaultSubagentProvider` and
  `defaultSubagentModel` settings, a GTK selector with an explicit fallback to
  the ordinary default, typed queue transport, and subagent-only model
  precedence. Explicit model arguments remain authoritative.
- **Verification:** Development and test builds pass. Exact settings,
  persistence, queue, and model-precedence tests pass. Display-backed DEM-033
  and DEM-034 remain pending because no GTK display is available.
- **Status:** Resolved for implementation; manual qualification pending.

## PCR-049 — Sandboxed shell timeout leaves GTK agent turn hung (2026-08-08)

- **Category:** Code, Test
- **Priority:** 1-Critical
- **Description:** A shell command with a timeout could hang the GTK agent
  indefinitely when a sandbox profile was active. The timeout task signalled
  the PID returned by `Start` as a process-group ID, but that PID belonged to
  the outer `bwrap` process while `setsid` created a different process group.
- **Affected work products:** `LLM.Tools.Shell`, sandbox integration tests,
  SDD-CORE, Test Plan, provider/core component logs.
- **Corrective action:** Place `setsid` outside the optional `bwrap` wrapper so
  the process handle returned by `Start` remains the process-group leader.
  Add sandboxed timeout and abort tests that verify result delivery after
  terminating a long-running process tree.
- **Actions taken (2026-08-08):** Moved the wrapper ordering, corrected the
  design description, added two registered AUnit regressions, and updated
  sandbox test inventory and component logs.
- **Verification:** Production and test development builds succeed. The exact
  timeout and abort regressions pass. A full-suite run remains incomplete due
  to pre-existing environment-dependent failures and time limits.
- **Status:** Resolved
- **Date resolved:** 2026-08-08


## PCR-047 — GTK GUI Preferences implementation and verification (2026-08-06)
- **Category:** Requirements, Design, Test
- **Priority:** 3-Moderate
- **Description:** The requested GTK Preferences capability was not represented
  in the controlled requirements, design, or test-plan artifacts. Existing GUI
  runtime selectors and the Acme SetDefault command did not define a unified
  persistent-preferences workflow or a persistent sandbox default field.
- **Affected work products:** SRS-CORE, SDD-CORE, Test Plan, frontend/core/
  provider development logs, Project Plan artifact table.
- **Corrective action required:** Record the proposed GUI Preferences dialog,
  settings schema, precedence rules, queue interaction, and qualification
  coverage. Implement and verify the capability in a subsequent build.
- **Actions taken (2026-08-06):** Added REQ-CORE-116..119 and
  REQ-CORE-234; updated SDD-CORE v1.9, Test Plan v1.9, and component logs.
  Implemented `LLM.Settings.Save_Preferences`, the persistent sandbox
  default, the typed `Set_Preferences` queue item, the GTK Preferences dialog,
  and GUI new-session preference inheritance. Added settings, queue, and agent
  regressions; 829 tests are registered and the focused PCR-047 tests pass.
- **Verification:** Development and test builds pass. Display-backed DEM-033
  and DEM-034 remain pending because no GTK display is available; a full-suite
  run was not completed because existing live/network activity timed out.
- **Status:** Resolved for implementation; manual qualification pending

## PCR-050 — Lasem rejects literal LaTeX relation characters (2026-08-08)

- **Category:** Code, Test
- **Priority:** 2-Serious
- **Description:** The GTK display-math renderer passed valid LaTeX/MathJax
  literal `<` and `>` relation characters directly to Lasem. Lasem's iTeX
  lexer treats those characters as unknown tokens and renders the literal
  text `Unknown Character` inside an otherwise valid math document.
- **Affected work products:** `Coyote_Lasem`, GTK display-math rendering,
  Lasem tests, design description, frontend SDF, and Test Plan.
- **Corrective action:** Normalize a temporary copy of the source before
  Lasem measurement and Cairo rendering, converting only literal relation
  characters inside math delimiters to Lasem's supported `\lt` and `\gt`
  commands. Preserve the original source in the GUI line model for display
  and selection.
- **Actions taken (2026-08-08):** Added delimiter- and `\text{...}`-aware
  normalization in `src/coyote_lasem_c.c`. Added and registered a regression
  test comparing the original example with its Lasem-command equivalent.
  Updated the design description, frontend SDF, and test inventory.
- **Verification:** Production and test development builds succeed. The new
  focused regression passes with zero failures and zero unexpected errors.
- **Status:** Resolved
- **Date resolved:** 2026-08-08

## PCR-052 — Cut over GUI display math from iTeX to Presentation MathML (2026-08-12)

- **Category:** Requirements, Design, Code, Test
- **Priority:** 3-Moderate
- **Description:** The GUI display-math path depended on Lasem's limited iTeX
  parser. The agreed interface is now Presentation MathML inside standalone
  `$$` blocks.
- **Affected work products:** SRS-CORE, SDD-CORE, `Coyote_Lasem`, GTK
  conversation rendering, system-prompt guidance, tests, and development logs.
- **Corrective action:** Replace direct iTeX parsing and relation normalization
  with Lasem's native `lsm_dom_document_new_from_memory` path. Strip only the
  delimiter lines before measurement/rendering while preserving the original
  MathML source for selection and fallback. MathML element whitelisting is
  intentionally deferred until a concrete compatibility problem emerges.
- **Verification:** Production and test development builds succeed. Focused
  Lasem and system-prompt tests pass; display-backed GUI qualification requires
  a GTK display.
- **Status:** Resolved
- **Date resolved:** 2026-08-12

## PCR-051 — Add Lasem-compatible display-math guidance to system prompt (2026-08-12)

- **Category:** Requirements, Design, Code, Test
- **Priority:** 3-Moderate
- **Description:** The GUI display-math renderer uses Lasem 0.6, whose iTeX
  subset rejects some common LaTeX forms such as unbraced `\mathbb Z`.
  The default system prompt did not tell the agent how to produce compatible
  standalone display mathematics.
- **Affected work products:** SRS-CORE, SDD-CORE, `LLM.System_Prompt`, core
  agent SDF, system-prompt tests, and Test Plan.
- **Corrective action:** Add static system-prompt guidance scoped to GUI
  display mathematics. Require braced command arguments, standalone display
  delimiters, supported relation commands, and readable plain text for
  expressions outside the supported subset. Keep renderer-side fallback
  behavior unchanged because prompt instructions cannot constrain user input,
  custom agent instructions, or other frontends.
- **Actions taken (2026-08-12):** Added `Display_Math_Guidance` to
  `src/llm/llm-system_prompt.adb`, added and registered
  `Test_Default_Prompt_Contains_Display_Math_Guidance`, and updated the
  requirements, design, development log, and test-plan traceability.
- **Verification:** Clean production and test development builds succeed.
  The new focused system-prompt test passes with zero failures and zero
  unexpected errors. The full-suite run reached the system-prompt tests and
  later live/network-dependent tests without failures before exceeding the
  300-second execution limit.
- **Status:** Resolved
- **Date resolved:** 2026-08-12

## PCR-053 — GTK conversation zoom did not propagate to custom renderer (2026-08-13)

- **Category:** Code, Design, Test
- **Priority:** 2-Serious
- **Description:** The GTK View zoom actions updated the prompt `GtkTextView`,
  but the virtualized `Coyote_GUI.Conversation` renderer retained its default
  Pango font. Display math rendered by Lasem also retained its original size.
- **Affected work products:** GUI frontend, conversation renderer, Lasem binding,
  frontend design log, design description, and GUI test coverage.
- **Corrective action:** Added `Coyote_GUI.Conversation.Set_Font`, applied the
  font to both reusable Pango layouts, invalidated wrapping/line-height caches,
  and added a Lasem resolution scale used consistently for math measurement and
  Cairo rendering. The frontend derives the math scale from the effective
  clamped zoom font size.
- **Verification:** Production and test development builds succeed. The exact
  conversation font regression passes with the available GTK display, and the
  exact Lasem scaling regression passes without a display. Full-suite execution
  remains subject to the existing environment-dependent test constraints.
- **Status:** Resolved
- **Date resolved:** 2026-08-13


## PCR-054 — Nested Markdown lists rendered without indentation (2026-08-13)

- **Category:** Code, Design, Test
- **Priority:** 2-Serious
- **Description:** Libcmark preserved nested list nodes, but both Markdown
  renderers emitted only the list marker and discarded the nesting depth. The
  GTK conversation view and shared Pango/session renderer therefore displayed
  nested lists as flat lists.
- **Affected work products:** `Coyote_GUI.Conversation`,
  `Coyote_Renderer.Markup`, GUI and cmark tests, SDD-CORE, SDD-SQC, frontend
  SDF, and Test Plan.
- **Corrective action:** Convert list depth into two leading spaces per level
  below the top-level list in both renderers. Initialize ordered-list counters
  from libcmark's declared starting ordinal. Add shared-renderer and live GUI
  regressions for nested and mixed bullet/ordered lists.
- **Verification:** Production and test development builds succeed. The shared
  renderer, GUI nested-list, and GUI mixed-list focused regressions pass. The
  full suite remains subject to existing environment-dependent test constraints.
- **Status:** Resolved
- **Date resolved:** 2026-08-13


## PCR-056 — GTK completion desktop notifications and persisted preference (2026-08-15)

- **Category:** Requirements, Design, Code, Build, Test
- **Priority:** 4-Minor (enhancement)
- **Description:** The GTK GUI did not notify the user when an interactive
  agentic loop completed while its window was unfocused, and it had no persisted
  preference for enabling or disabling that behavior.
- **Affected work products:** SRS-CORE, SDD-CORE, `Coyote_App.Frontend.GUI`,
  `Coyote_GUI`, `LLM.Settings`, libnotify build configuration, frontend SDF,
  Test Plan, and AUnit tests.
- **Corrective action:** Added a native libnotify binding, a pure notification
  policy, GTK update-queue notification handling, active-window detection,
  and a Preferences checkbox persisted as `completionNotifications`. The
  feature is hard-disabled for subagents and one-shot executions, and native
  notification failures are non-fatal.
- **Verification:** Production and test development builds succeed. Focused
  settings, queue, and notification-policy tests pass. Display-backed delivery
  remains manual qualification DEM-035.
- **Status:** Implementation complete; manual qualification pending

## PCR-055 — Ctrl+mouse-wheel zoom in the GTK GUI (2026-08-15)

- **Category:** Requirements, Code, Design, Test
- **Priority:** 4-Minor (enhancement)
- **Description:** The GTK GUI supported zoom only through the View menu
  accelerators (Ctrl++/Ctrl+-/Ctrl+0).  Users expect the common
  Ctrl+mouse-wheel gesture to zoom the conversation view as well.
- **Affected work products:** SRS-CORE (new REQ-CORE-125), SDD-CORE
  (§4.1 unit table, §5.33, new §5.37a, requirements traceability),
  `Coyote_App.Frontend.GUI`, `Coyote_GUI.Conversation` (event mask),
  new unit `Coyote_GUI.Zoom`, new test module `coyote_gui_zoom_tests`,
  Test Plan, frontend SDF.
- **Corrective action:** Added REQ-CORE-125.  Enabled
  `Gdk.Event.Scroll_Mask` on the conversation `GtkLayout` and connected a
  new `On_Conv_Scroll` handler in the GUI frontend: with Ctrl held, wheel
  up/down steps the zoom level and calls `Apply_Zoom`; smooth-scroll
  deltas are accumulated to whole notches; Ctrl+wheel events are consumed
  so the viewport never scrolls mid-zoom, while plain wheel events
  propagate to the scrolled window unchanged.  Zoom arithmetic (step
  size, 6–32 pt clamping, plateau walk-back, no-change short-circuit) was
  factored into the new display-independent package `Coyote_GUI.Zoom`,
  shared by the menu accelerators and the wheel handler.
- **Verification:** Production and test development builds succeed.  The
  12 new `Coyote_GUI.Zoom` unit tests pass; the full suite completed with
  856 tests, 0 failures, 0 unexpected errors.  Live Ctrl+wheel behaviour
  over the conversation view is covered by DEM-014.
- **Status:** Resolved
- **Date resolved:** 2026-08-15


## PCR-057 — GTK conversation upward drag-select invisible (2026-08-15)

- **Category:** Code, Design, Test
- **Priority:** 3-Moderate
- **Description:** The GTK conversation view highlighted a click-drag
  downward, but an upward or leftward drag painted no selection.  Draw and
  copy treated `Sel_Start_*` as the earlier endpoint, while motion only
  updated `Sel_End_*`.  Button-release swapped the inverted pair but did
  not queue a redraw.
- **Affected work products:** `Coyote_GUI.Conversation`, conversation
  tests, SDD-CORE, frontend SDF, Test Plan.
- **Corrective action:** Added `Ordered_Selection` and used it for
  highlight drawing and clipboard extraction.  Button-release now writes
  the ordered pair back and queues a redraw.  Added two AUnit regressions
  for inverted endpoint ordering and inverted-range extraction.
- **Verification:** Production and test development builds succeed.
  The two new inverted-selection conversation regressions pass with a
  GTK display.
- **Status:** Resolved
- **Date resolved:** 2026-08-15
