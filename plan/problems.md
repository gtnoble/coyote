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
- **Status:** Open
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
