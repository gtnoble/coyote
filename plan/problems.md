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
  Deferred to milestone M6.
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
