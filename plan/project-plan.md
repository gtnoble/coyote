# Project Plan — coyote

**Version:** 1.27
**Date:** 2026-08-31
**Status:** Active

---

## Table of Contents

1. [Overview](#1-overview)
2. [Referenced Documents](#2-referenced-documents)
3. [Required Work Overview](#3-required-work-overview)
4. [Plans for Each Active Activity](#4-plans-for-each-active-activity)
   - 4.1 Development Process
   - 4.2 Development Environment
   - 4.3 Requirements Analysis
   - 4.4 Software Design
   - 4.5 Implementation and Unit Testing
   - 4.6 Integration and Testing
   - 4.7 Acceptance Testing
   - 4.8 Configuration Management
   - 4.9 Product Evaluation
   - 4.10 Quality Assurance
   - 4.11 Corrective Action
   - 4.12 Joint Reviews
   - 4.13 Risk Management
   - 4.14 Management Indicators
   - 4.15 Process Improvement
5. [Schedules and Milestones](#5-schedules-and-milestones)
6. [Resources](#6-resources)
7. [Risk Register](#7-risk-register)
8. [Management Indicator History](#8-management-indicator-history)
9. [Artifact Version Table](#9-artifact-version-table)

---

## 1. Overview

**Project:** coyote — a native Ada LLM coding agent.

**Purpose:** Develop and maintain a self-contained multi-frontend LLM coding
agent with GTK3 and Plain frontends. The agent
streams thinking, tool output, and assistant responses in real time; supports
multiple LLM providers; and includes a companion
Statistical Quality Control application (coyote_sqc) for process monitoring.

**Scope:** This plan covers all active development activities for the coyote
executable, the coyote_sqc executable, and their shared libraries. It does not
cover deployment to third-party end-users; §5.12 (prepare for use) and §5.13
(prepare for handover) are waived until a deployment or maintenance-handover
scenario arises.

**System type:** Software-only. §5.3 (system requirements analysis) and §5.4
(system design) are collapsed into §5.5 and §5.6 respectively — there is no
separate system-level stratum.

**Waived activities:**
- §5.10 (HW/SW integration testing) — permanently off; no hardware components.
- §5.12 (prepare for use) — deferred; no formal deployment sites at present.
- §5.13 (prepare for handover) — deferred; no maintenance team at present.
- §5.19.3 (security and privacy) — deferred; no sensitive user data handled
  beyond API keys stored in user-controlled files.

---

## 2. Referenced Documents

| ID | Title | Location |
|---|---|---|
| SRS-CORE | coyote Requirements Specification | `requirements/coyote-requirements.md` | 1.16 (2026-08-25) | Client |
| SDD-CORE | coyote Design Description | `design/coyote-design.md` |
| SRS-SQC | coyote_sqc Requirements Specification | `requirements/coyote-sqc-requirements.md` |
| SDD-SQC | coyote_sqc Design Specification | `design/coyote-sqc-design.md` |
| PCR-LOG | Problem/Change Log | `plan/problems.md` |
| TEST-GUIDE | Integration Test Guide | `plan/integration-test-guide.md` |
| AGENTS | Agent Working Instructions (secondary) | `AGENTS.md` |

---

## 3. Required Work Overview

Two software components are developed within this project:

### Component: coyote (core agent)

The primary executable. Provides GTK3 and Plain frontends; drives
an in-process LLM agentic loop; streams events to the active frontend; persists
sessions; executes the built-in shell tool; manages provider selection and
context compaction.

**Current state:** Implemented and in active development. SRS-CORE (`requirements/coyote-requirements.md`) is the governing requirements document.

### Component: coyote_sqc (SQC companion)

A standalone GTK3 executable that reads coyote session data, computes
SPC/SQC control chart statistics, and presents an interactive analysis GUI.

**Current state:** Implemented and in active development. Requirements documented
in `requirements/coyote-sqc-requirements.md`; design documented in `design/coyote-sqc-design.md`.

### Shared libraries

- `coyote_renderer` — shared Pango markup and session-view rendering
- `coyote_cmark` — thin Ada binding to libcmark-gfm

---

## 4. Plans for Each Active Activity

### 4.1 Development Process

**Lifecycle model:** Evolutionary builds. Requirements and design are refined
as each build proceeds; there is no big-bang requirements freeze.

**Build definition:** A build is a coherent set of capabilities brought through
requirements analysis → design → implementation → unit testing → integration
testing → acceptance review. Builds do not have fixed durations; they are
closed when the planned capability set has been implemented and tested.

**Current build:** Build N (ongoing). Scope: formalise process artifacts
(this Project Plan, SRS-CORE, SDD-CORE, Test Plan) while continuing active
development on both components. The native GTK component-stack conversation
migration is documented for the next implementation build; no production
source changes are included in this documentation update. PCR-059 Responses
implementation and OpenRouter cutover are complete and verified; the Chat
Completions compatibility path remains available.

**Approach to rationale:** Key design decisions — architecture choices,
algorithm selections, interface conventions, provider wire-format decisions —
are recorded in component development logs (`sdfs/`). Rationale is noted at
the point of decision, not reconstructed post-hoc.

**Standards:**
- Requirements: stated as what the system must do, not how; each requirement
  has a unique ID and a stated verification method.
- Design: Ada 2022 package structure mirrors the source layout in `src/`.
  Concurrency design documented explicitly (task types, protected objects,
  shared-state rules).
- Code: Ada 2022, GNAT/GCC. Style per the Ada Quality and Style Guide
  (see `AGENTS.md §Ada Style Guide`).
- Test cases: AUnit for unit and integration tests; test fixtures in
  `test/fixtures/`.

### 4.2 Development Environment

**Compiler / build:** GNAT (Ada 2022), Alire (`alr build`), GPRbuild.
Profiling builds: `alr build -- -XCOYOTE_PROFILE=true` (adds `-pg` for gprof).
Object files: `obj/development/`. Binaries: `bin/`.

**Test environment:** AUnit test suite in `test/`. Run with
`cd test && alr run coyote_test`. Integration tests (live providers) are
opt-in via environment variable guards; see `plan/integration-test-guide.md`.

**Project library:** The git repository at the project root. All source,
documentation, and intermediate work products are version-controlled here.
Commit policy: at minimum at the end of each build; whenever a work product
advances to project-level or client control.

**Component development logs:** One file per logical component group in
`sdfs/`. Each records design rationale, constraints, unit test notes, and
status throughout development.

**Non-deliverable tools:** GTK3 dev headers,
libcurl dev headers, libcmark-gfm dev headers, Lasem 0.6 dev headers, and Computer Modern math fonts. Operation of delivered
binaries does not depend on any of these tools at runtime except GTK3
(which must be present on the user's system; this is a known dependency).

### 4.3 Requirements Analysis

**Approach:** For coyote core (SRS-CORE): governing document is
`requirements/coyote-requirements.md`. Requirements are derived from observed
system behaviour and user-agreed changes; each is stated as a testable
capability requirement with a unique ID
(`REQ-CORE-NNN`) and a verification method. Add interface, environment,
quality-factor, and constraint requirements. Produce traceability from each
requirement to the project objective it serves.

For coyote_sqc: SRS-SQC (`requirements/coyote-sqc-requirements.md`) is the governing document.
It is maintained as requirements evolve.

**Traceability strategy:** Each requirement ID appears in: the SRS, the SDD
(unit traceability), and the Test Plan (test-case traceability). Maintained
manually; updated whenever requirements or design change.

### 4.4 Software Design

**Approach:** Component-wide design decisions first (behavioral model, error
handling, concurrency model), then architectural design (package/task
decomposition, interfaces, concept of execution), then detailed design
(per-package descriptions sufficient to implement and maintain).

For coyote core: SDD-CORE (`design/coyote-design.md`) is the primary design
artifact. AGENTS.md serves as secondary operational guidance for the agent;
where they diverge, SDD-CORE takes precedence.

For coyote_sqc: SDD-SQC (`design/coyote-sqc-design.md`) is the governing document.

**Design methods:** Ada packages map directly to software units. Concurrency
design uses Ada task types and protected objects as described in SDD-CORE.
Provider additions follow the approach described in SDD-CORE §5 (Detailed Design).

### 4.5 Implementation and Unit Testing

**Coding standards:** Ada 2022; two-space indentation; `--  double-dash`
comments; `Unbounded_String` for variable-length strings in records; plain
`String` for transient values; `GNATCOLL.JSON` for JSON; no raw Unicode
literals (use `UC_*` constants from `Coyote_App.Utils`).

**Unit test approach:** AUnit tests in `test/src/`. New public subprograms
require corresponding AUnit tests. Test fixtures in `test/fixtures/`. Tests
are run with `cd test && alr run coyote_test`.

**Definition of done for a unit:** Requirements complete, designed, coded,
unit-tested (all AUnit assertions pass), and the full test suite remains
green.

### 4.6 Integration and Testing

**Integration sequence:** Build Ada packages in dependency order (enforced by
GPRbuild). Integration testing is performed by the AUnit suite. Live-provider
integration tests are in `test/src/` guarded by environment variables.

**Test approach:** Unit tests exercise individual packages in isolation (with
stubs where necessary). Integration tests exercise interactions between
packages — e.g. session store + agent loop, provider + SSE parser + event
dispatch.

### 4.7 Acceptance Testing

**Approach:** Acceptance testing demonstrates that all SRS requirements have
been met. The AUnit suite constitutes the primary test vehicle. For
capabilities not directly testable with AUnit (streaming frontend output,
GUI rendering) the test method is demonstration or
inspection as stated in the SRS.

**Independence limitation:** The developer is evaluating their own work.
This limitation is declared at each acceptance review. The user (product
owner) is invited to independently review work products before they are
considered accepted.

**Test environment:** Development workstation running GNAT, Alire,
GTK3. Live-provider tests require valid API credentials (opt-in).

**Dry run policy:** Before proposing an acceptance review to the user, a full
`cd test && alr run coyote_test` run is performed and the result recorded.

### 4.8 Configuration Management

**Identification scheme:** Software components are identified by their git
commit hash and the tag (if any) at the point of release. Work product
documents are identified by the version field in their header and the git
commit at which they were last substantively changed.

**Control levels:**

| Level | Entities | Change procedure |
|---|---|---|
| Author control | Working drafts, uncommitted files | Developer changes freely |
| Project-level control | Committed, versioned artifacts | Developer changes with a PCR entry in `plan/problems.md` |
| Client control | User-reviewed and acknowledged artifacts | Developer changes only after user agreement; PCR entry required |

**Change procedure:** Any change to a project-level or client-controlled
artifact is preceded by a PCR entry describing the change and its rationale.
The git commit message references the PCR ID.

**Configuration status accounting:** The Artifact Version Table in §9 of this
document tracks each controlled artifact, its current version/commit, and its
control level.

**Version control tooling:** Git. Remote backup at developer's discretion.

### 4.9 Product Evaluation

**Products evaluated:** Every work product listed in §9 (artifact version
table) is subject to in-process and final evaluation before being presented
to the user.

**Criteria:** Per `documents.md Part 2` of the structured-sw-developer skill.
Universal criteria apply to all products; additional type-specific criteria
apply as relevant.

**Evaluation timing:** In-process evaluation at each major phase transition.
Final evaluation before presenting any product to the user at a joint review.

**Independence limitation:** Developer evaluates own work. Declared at each
evaluation; user invited to review independently.

**Records:** Evaluation outcomes are noted in the relevant component
development log (`sdfs/`) or in the PCR log if a deficiency is found.

### 4.10 Quality Assurance

**Approach:** Inline QA — each activity is checked against this Project Plan
as it proceeds. At each joint review, the developer confirms that:
- All required work products for the phase exist and have been evaluated.
- All AUnit tests pass.
- All open PCRs have been triaged with a priority and a plan.

**Independence limitation:** Developer performs QA on own work. Declared at
each joint review. User is invited to audit independently.

**Records:** QA findings are entered into `plan/problems.md` with category
"Plans" or "Other".

### 4.11 Corrective Action

**Problem tracking system:** `plan/problems.md`. Every detected problem in a
project-level or client-controlled work product gets a PCR entry. Each entry
carries a unique ID, date, category, priority, description, affected products,
corrective action, actions taken, and status.

**Category scheme:** Plans | Requirements | Design | Code | Test | Manuals |
Other (per `documents.md Part 3`).

**Priority scheme:** 1-Critical | 2-Serious | 3-Moderate | 4-Minor |
5-Negligible (per `documents.md Part 3`).

**Trend analysis:** At each joint review, open PCRs are reviewed for trends
(recurring category, cluster of new opens, stale high-priority items).

### 4.12 Joint Reviews

**Review types planned:**

| Review | Trigger | Type |
|---|---|---|
| Plan review | This Project Plan is complete | Plan review |
| Requirements review | SRS-CORE is complete | Software requirements review |
| Design review | SDD-CORE is complete | Software design review |
| Test readiness review | Test Plan + Test Description are complete | Test readiness review |
| Test results review | Acceptance test run complete | Test results review |
| Periodic management review | After each build closes | Management review |

**Preparation:** Developer presents work products at the review. User may
critique and raise issues. Issues are entered into `plan/problems.md`. The
review is considered closed when all raised issues have been triaged.

**Management indicators** are reported at every management review (see §4.14).

### 4.13 Risk Management

**Approach:** Risks are identified throughout the project, not only at start.
At each joint review the risk register (§7) is updated: new risks added, old
risks re-assessed, mitigated risks closed.

**Risk register structure:** ID, description, likelihood (Low/Med/High),
impact (Low/Med/High), mitigation strategy, status (Open/Mitigated/Closed).

### 4.14 Management Indicators

**Indicator set:** The six standard indicators defined in the
structured-sw-developer skill:

1. Requirements volatility — additions, changes, deletions since last review
2. Component progress — per component: requirements complete / designed /
   implemented / unit-tested / integrated
3. Open problems — count by priority from `plan/problems.md`
4. Milestone status — planned vs. actual for major phase milestones
5. Scope changes — count of agreed amendments to the project brief
6. Test results trend — pass/fail/deferred from most recent test run

**Reporting:** Appended to §8 (Management Indicator History) after each joint
review.

### 4.15 Process Improvement

**Retrospective cadence:** After each build closes, the developer assesses
the process for suitability and effectiveness. Proposed improvements are
written up as Project Plan amendments and presented to the user before being
adopted.

---

## 5. Schedules and Milestones

| Milestone | Description | Status |
|---|---|---|
| M1 | Project Plan acknowledged by user | Complete (2026-06-02) |
| M2 | SRS-CORE (coyote requirements) complete and reviewed | Complete (2026-06-02) |
| M3 | SDD-CORE (coyote design) complete and reviewed | Complete (2026-06-02) |
| M4 | Test Plan complete and reviewed | Complete (2026-06-03) |
| M5 | All SRS-CORE requirements have test coverage | Complete (2026-06-03) |
| M6 | First full acceptance test run with recorded results | Complete (2026-06-03) |

These milestones apply to the current build (process formalisation build).
Subsequent builds will define their own milestone sets.

---

## 6. Resources

| Resource | Role | Notes |
|---|---|---|
| GNAT (Ada 2022) | Compiler | GCC-based; installed system-wide |
| Alire (`alr`) | Build system / package manager | coyote.gpr + alire.toml |
| GPRbuild | Build orchestration | Invoked via `alr build` |
| AUnit | Unit and integration test framework | In `test/` crate |
| GTK3 + dev headers | GUI frontend | System package |
| libcurl + dev headers | HTTP/SSE client | System package |
| libcmark-gfm + dev headers | Markdown rendering | System package |
| Lasem 0.6 + dev headers | Display math rendering | System package/custom install |
| Computer Modern math fonts | Lasem glyph coverage | System font package |

| Git | Version control / project library | Project root |

---

## 7. Risk Register

| ID | Description | Likelihood | Impact | Mitigation | Status |
|---|---|---|---|---|---|
| R1 | Upstream library API changes (libcurl, GTK3, cmark-gfm) break the build | Low | Moderate | Pin Alire dependency versions; monitor library release notes | Open |
| R2 | Provider wire-format changes (Anthropic, OpenAI, Copilot) break streaming | Medium | High | Opt-in provider integration tests (guarded by env vars); review R1–R10 review records after provider releases; isolate wire-format code in dedicated provider packages | Open |
| R5 | OpenRouter Responses API rejects Completions-shaped payloads or `store`/`previous_response_id` after cutover | Medium | High | Keep Completions adapter intact as rollback; OpenRouter adapter omits `store` and `previous_response_id`; mock-server tests assert `/responses` path and stateless fields; live test remains guarded | Mitigated; monitor live use |
| R6 | Reasoning items not replayed on later Responses turns degrade o-series / GPT-5 quality | Medium | Moderate | Pack reasoning `id` + `encrypted_content` in the existing signature field; unit-test history encoding; request `include: reasoning.encrypted_content` | Mitigated; monitor live use |
| R3 | SDD-CORE drifts from actual implementation, misleading future development | Medium | Moderate | Treat SDD-CORE as the primary controlled design artifact; include SDD-CORE review in the Definition of Done for each build; update AGENTS.md to match SDD-CORE when it diverges; PCR raised when drift is detected | Open |
| R4 | Process artifact maintenance overhead crowds out feature work | Low | Low | Keep all process artifacts in Markdown co-located with the code; lightweight tooling (no external tracking systems); tailor to minimum viable coverage | Open |
| R7 | Native GTK component-stack migration, including visible per-step frames, regresses streaming latency, memory, resize, or session-reset correctness, or frames are not visually distinct under a theme | Medium | High | Native stack qualified for frame visibility, live/replay behavior, zoom, reset, responsive tool flow, and 100/500/2,000-exchange histories; retain automated regression coverage | Closed |

---

## 8. Management Indicator History

*(Appended at each joint review.)*

### Review 1 — M1 Plan Review (2026-06-02)

**Review type:** Plan review
**Trigger:** Project Plan presented for M1 acknowledgement

| Indicator | Value |
|---|---|
| Requirements volatility | SRS-CORE v1.0 (2026-06-01): 101 requirements. No additions, changes, or deletions since creation. |
| Component progress | coyote core: requirements complete, designed, implemented, unit-tested, integrated. coyote_sqc: requirements complete, designed, implemented, unit-tested, integrated. |
| Open problems | 1 Open (PCR-009, priority 4-Minor); 1 In Progress (PCR-008, priority 4-Minor); 10 Resolved. |
| Milestone status | M1 Complete 2026-06-02. M2–M6 Pending. |
| Scope changes | 0 agreed amendments to project brief since project start. |
| Test results trend | 658 AUnit tests passing; 0 failures; 6 requirements deferred to demonstration (PCR-009). |

**Issues raised at review:** PCR-010 (purpose over-specifies session storage
format), PCR-011 (AGENTS.md treated as primary design source), PCR-012
(coyote_sqc overview over-specifies session storage format). All three resolved
before acknowledgement.

**Independence limitation:** Developer evaluated own work. User reviewed and
acknowledged the plan independently.

---

### Review 2 — M2 Requirements Review (2026-06-02)

**Review type:** Software requirements review
**Trigger:** M2 — SRS-CORE v1.1 presented for review

| Indicator | Value |
|---|---|
| Requirements volatility | SRS-CORE v1.1 (2026-06-02): 101 requirements. 1 requirement revised (REQ-CORE-704); 0 additions or deletions since v1.0. |
| Component progress | coyote core: requirements complete, designed, implemented, unit-tested, integrated. coyote_sqc: same. |
| Open problems | PCR-009 Open (4-Minor). PCR-013 and PCR-014 raised and resolved at this review. |
| Milestone status | M1 Complete 2026-06-02. M2 Complete 2026-06-02. M3–M6 Pending. |
| Scope changes | 0 agreed amendments since project start. |
| Test results trend | 658 AUnit tests passing; 0 failures (no new test run since M1). |

**Issues raised at review:** PCR-013 (missing N/A stubs in SRS §3),
PCR-014 (REQ-CORE-704 referenced AGENTS.md normatively). Both resolved
before acknowledgement.

**Independence limitation:** Developer evaluated own work. User reviewed and
acknowledged the specification independently.

### Review 2 — M3 Design Review (2026-06-02)

**Review type:** Software design review
**Trigger:** SDD-CORE v1.1 presented for M3 acknowledgement

| Indicator | Value |
|---|---|
| Requirements volatility | SRS-CORE v1.1: 101 requirements. No additions, changes, or deletions since M2. |
| Component progress | coyote core: requirements complete, designed, implemented, unit-tested, integrated. coyote_sqc: unchanged. |
| Open problems | 1 Open (PCR-009, priority 4-Minor); 1 In Progress (PCR-008, priority 4-Minor); 12 Resolved. |
| Milestone status | M1 Complete 2026-06-02. M2 Complete 2026-06-02. M3 Complete 2026-06-02. M4–M6 Pending. |
| Scope changes | 0 agreed amendments since project start. |
| Test results trend | 658 AUnit tests passing; 0 failures (no new test run since M2). |

**Issues raised at review:** None.

**Independence limitation:** Developer evaluated own work. User reviewed and
acknowledged the design without comment.

---

### Review 3 — M4 Test Readiness Review (2026-06-03)

**Review type:** Test readiness review
**Trigger:** M4 — Test Plan v1.0 presented for acknowledgement

| Indicator | Value |
|---|---|
| Requirements volatility | SRS-CORE v1.1: 101 requirements. No additions, changes, or deletions since M3. |
| Component progress | coyote core: requirements complete, designed, implemented, unit-tested, integrated. coyote_sqc: same. |
| Open problems | 1 Open (PCR-009, priority 4-Minor — coverage gaps accepted/deferred); all other PCRs resolved. |
| Milestone status | M1–M3 Complete (2026-06-02). M4 Complete 2026-06-03. M5–M6 Pending. |
| Scope changes | 0 agreed amendments since project start. |
| Test results trend | 658 tests passing; 0 failures (confirmed pre-review dry run). |

**Issues raised at review:** None.

**Independence limitation:** Developer evaluated own work. User acknowledged the plan independently.

---

### Review 4 — M5 Requirements Coverage Review (2026-06-03)

**Review type:** Requirements traceability review
**Trigger:** M5 — All SRS-CORE requirements confirmed to have assigned verification methods

| Indicator | Value |
|---|---|
| Requirements volatility | SRS-CORE v1.1: 118 requirements. No changes since M4. |
| Component progress | coyote core: requirements complete, designed, implemented, unit-tested, integrated. coyote_sqc: same. |
| Open problems | 1 Open (PCR-009, priority 4-Minor — demonstration tests pending M6); all other PCRs resolved. |
| Milestone status | M1–M5 Complete (M5: 2026-06-03). M6 Pending. |
| Scope changes | 0 agreed amendments since project start. |
| Test results trend | 658 tests passing; 0 failures (confirmed pre-review dry run). |

**Coverage verification:** All 118 SRS-CORE requirements (REQ-CORE-001 through REQ-CORE-805) appear in the Test Plan §6 traceability table with an assigned verification method (T, D, I, or A). Six requirements (REQ-CORE-011/012, 022, 074, 075/076, 107, 142) use Demonstration as their method; these are formally accepted per Test Plan §4.5 and PCR-009. Automated AUnit baseline: 658 tests, 0 failures.

**Issues raised at review:** None.

**Independence limitation:** Developer evaluated own work. User invited to review traceability table independently.

### Review 5 — M6 Acceptance Test Results Review (2026-06-03)

**Review type:** Test results review
**Trigger:** M6 — First full acceptance test run with recorded results

| Indicator | Value |
|---|---|
| Requirements volatility | SRS-CORE v1.1: 118 requirements. No changes since M5. |
| Component progress | coyote core: requirements complete, designed, implemented, unit-tested, integrated. coyote_sqc: same. |
| Open problems | 1 Open (PCR-009, priority 4-Minor — 14 demonstration tests deferred to future build). All other PCRs resolved. |
| Milestone status | M1–M6 Complete (M6: 2026-06-03). |
| Scope changes | 0 agreed amendments since project start. |
| Test results trend | 658 AUnit tests passing; 0 failures; 4 demonstrations PASS; 14 demonstrations deferred (PCR-009); 21 inspection/analysis items PASS. |

**Test Report:** `plan/test-report-m6.md` v1.0 — 658/658 automated tests pass, zero failures. DEM-001, DEM-002, DEM-004, and DEM-018 executed and passed. DEM-003 and DEM-005–DEM-017 deferred under PCR-009.

**Issues raised at review:** None new. PCR-009 remains open (accepted deferral for this build).

**Independence limitation:** Developer evaluated own work. User invited to review test report and results independently before accepting M6.

---

---

### Review 6 — SRS-CORE v1.2 Requirements Review (2026-06-06)

**Review type:** Software requirements review
**Trigger:** User-requested Ollama Cloud provider requirements (PCR-020) — SRS-CORE v1.2 presented for acknowledgement

| Indicator | Value |
|---|---|
| Requirements volatility | SRS-CORE v1.2 (2026-06-06): 126 requirements. 8 additions (REQ-CORE-150–156, REQ-CORE-204); 1 revision (REQ-CORE-072 extended provider list to six). No deletions since v1.1. |
| Component progress | coyote core: requirements updated (Ollama Cloud); design and implementation pending for new provider. coyote_sqc: unchanged. |
| Open problems | PCR-020 Open (priority 3-Moderate — Ollama Cloud requirements added; implementation pending). PCR-009 Open (priority 4-Minor — deferred demonstration tests). |
| Milestone status | M1–M6 Complete. Ollama Cloud implementation not yet scheduled. |
| Scope changes | 1 agreed amendment since project start: Ollama Cloud provider added to SRS-CORE. |
| Test results trend | 665 AUnit tests passing; 0 failures. No test changes for this review. |

**Issues raised at review:** None.

**Independence limitation:** Developer evaluated own work. User acknowledged SRS-CORE v1.2 explicitly.

---

### Review 7 — SRS-CORE v1.6 Requirements Review (2026-07-12)

**Review type:** Software requirements review
**Trigger:** Agent capability study — Claude Code and GitHub Copilot Chat codebase survey (PCR-040) identified six feature areas for improvement: enhanced system prompt, structured memory system, coordinator subagent orchestration, and three compaction-quality improvements. SRS-CORE v1.6 presented for acknowledgement.

| Indicator | Value |
|---|---|
| Requirements volatility | SRS-CORE v1.6 (2026-07-12): 140 requirements. 14 additions (REQ-CORE-065..068, REQ-CORE-170..172, REQ-CORE-180..183, REQ-CORE-190..192); 0 revisions; 0 deletions since v1.5. |
| Component progress | coyote core: requirements updated (6 feature areas). Design and implementation pending for all new requirements. coyote_sqc: unchanged. |
| Open problems | PCR-040 Open (priority 3-Moderate — new requirements added; implementation pending). PCR-009 Open (priority 4-Minor — deferred demonstration tests). |
| Milestone status | M1–M6 Complete. New requirements not yet scheduled for implementation. |
| Scope changes | 2 agreed amendments since project start: (1) Ollama Cloud provider (PCR-020), (2) Agent capability enhancements — system prompt, memory, coordinator, compaction quality (PCR-040). |
| Test results trend | 688 AUnit tests passing; 0 failures. No test changes for this review (tests will be added during implementation). |

**Issues raised at review:** None.

**Independence limitation:** Developer evaluated own work. User acknowledged SRS-CORE v1.6 explicitly.

---

### Review 8 — SRS-CORE v1.8 Sandbox Persistence Requirements Review (2026-08-04)

**Review type:** Software requirements review
**Trigger:** Investigation recorded in PCR-044 found that sandbox profiles were not restored on session resume or switching and could diverge across frontend, agent, and child-process state. The user requested five requirements covering persistence, clearing, propagation, and synchronization; SRS-CORE v1.8 was updated accordingly.

| Indicator | Value |
|---|---|
| Requirements volatility | SRS-CORE v1.8 (2026-08-04): 145 requirements. 5 additions (REQ-CORE-085..089); 0 revisions; 0 deletions since v1.7. |
| Component progress | coyote core: REQ-CORE-085..089 implemented and verified; qualification demonstrations remain planned. |
| Open problems | PCR-044 Resolved (priority 2-Serious — implementation, tests, and full-suite verification complete). |
| Milestone status | Implementation, focused qualification tests, and full-suite verification complete; qualification demonstrations remain planned. |
| Scope changes | 3 agreed amendments since project start. |
| Test results trend | 821 AUnit tests pass; 0 failures and 0 unexpected errors. |

**Issues raised at review:** None

**Independence limitation:** Developer evaluated own work. User authorized the requirements update; independent review remains invited.

---

### Review 11 — PCR-047 GUI Preferences Implementation Verification Review (2026-08-06)

**Review type:** Software design and test-results review
**Trigger:** PCR-047 runtime implementation completed for settings persistence, typed GUI preference transport, new-session inheritance, and sandbox-default precedence.

| Indicator | Value |
|---|---|
| Requirements volatility | No change since SRS-CORE v1.9; 150 requirements. |
| Component progress | GUI preferences implemented and unit-tested; display-backed qualification remains pending. |
| Open problems | PCR-047 implementation resolved; DEM-033/034 remain planned. PCR-009 remains open for unrelated demonstrations. |
| Milestone status | Development and test builds pass; focused PCR-047 tests pass; full suite not completed because existing live/network activity timed out. |
| Scope changes | No change since Review 10. |
| Test results trend | 829 registered tests; focused PCR-047 tests pass with 0 failures and 0 unexpected errors. |

**Issues raised at review:** Display-backed DEM-033 and DEM-034 remain pending because no GTK display is available.

**Independence limitation:** The developer evaluated their own implementation and test results. Independent user review and manual qualification remain invited.

### Review 10 — SRS-CORE v1.9 GUI Preferences Requirements Review (2026-08-06)

**Review type:** Software requirements and design review
**Trigger:** User-requested GTK GUI Preferences capability. The investigation found existing runtime model, thinking, and sandbox selectors but no unified persistent-preferences workflow or documented sandbox default. SRS-CORE v1.9, SDD-CORE v1.9, and Test Plan v1.9 record the implemented capability and its remaining display-backed qualification.

| Indicator | Value |
|---|---|
| Requirements volatility | SRS-CORE v1.9 (2026-08-06): 150 requirements. 5 additions (REQ-CORE-116..119 and REQ-CORE-234); 0 revisions; 0 deletions since v1.8. |
| Component progress | GUI preferences: requirements, design, implementation, and automated tests complete; display-backed qualification planned. Existing GUI runtime controls remain implemented. |
| Open problems | PCR-047 implementation resolved; DEM-033/034 remain pending; PCR-009 remains open for unrelated deferred demonstrations. |
| Milestone status | Implementation, focused qualification tests, and development/test builds complete; DEM-033/034 remain pending. |
| Scope changes | 1 agreed amendment since the previous review: persistent GTK GUI preferences. |
| Test results trend | 829 registered tests; focused PCR-047 tests pass with 0 failures and 0 unexpected errors; full suite not completed due existing live/network timeout. |

**Issues raised at review:** Display-backed DEM-033 and DEM-034 remain pending because no GTK display is available.

**Independence limitation:** The developer evaluated the developer-authored requirements, design, and test-plan updates. Independent user review and acknowledgement remain invited.

---

### Review 9 — PCR-044 Implementation Verification Review (2026-08-04)

**Review type:** Software design and test-results review
**Trigger:** PCR-044 implementation completed; the session-store accessor,
agent restoration paths, frontend synchronization paths, regression tests, and
full development-profile test run were reviewed against REQ-CORE-085..089.

| Indicator | Value |
|---|---|
| Requirements volatility | No change since SRS-CORE v1.8; 145 requirements. |
| Component progress | REQ-CORE-085..089 implemented; focused regression tests and full AUnit suite complete. |
| Open problems | PCR-044 Resolved; PCR-009 remains open for unrelated deferred demonstrations. |
| Milestone status | Implementation verification complete; DEM-029..032 remain manual qualification demonstrations. |
| Scope changes | 3 agreed amendments since project start. |
| Test results trend | 821 AUnit tests pass; 0 failures and 0 unexpected errors. |

**Issues raised at review:** None.

**Independence limitation:** The developer evaluated the developer's own design
and implementation. Independent user review of the code, documentation, and
manual demonstrations remains invited.

---

### Review 12 — PCR-059 Responses Implementation and Closure Review (2026-08-15)

**Review type:** Software design, test-readiness, and test-results review
**Trigger:** PCR-059 implementation and verification completed.

| Indicator | Value |
|---|---|
| Requirements volatility | SRS-CORE v1.12: 157 requirements. 9 new/changed Responses and provider-interface requirements (REQ-CORE-205–208, 215–217 plus amendments to 072, 201, and 203); 0 deletions. |
| Component progress | `LLM.Providers.OpenAI_Responses`: designed, implemented, unit-tested, and integrated. Native `openai` dispatch and registry defaults: implemented and tested. OpenRouter Responses cutover: implemented and tested. Chat Completions compatibility path: retained. |
| Open problems | PCR-059 resolved (priority 4-Minor). R5/R6 mitigated by mock assertions and focused tests; live-provider qualification remains optional and guarded. PCR-009 and previously deferred manual demonstrations remain open as recorded. |
| Milestone status | Build N+1 and N+2 implementation and verification complete. |
| Scope changes | 1 acknowledged amendment: OpenAI Responses sibling adapter and OpenRouter Responses cutover. |
| Test results trend | 878 registered tests; 878 successful, 0 failed assertions, and 0 unexpected errors. Production and test development builds succeed. |

**Issues raised at review:** Live OpenAI/OpenRouter qualification was not enabled because no live-provider guard and credentials were configured. Automated qualification used local HTTP mock servers.

**Independence limitation:** The developer evaluated their own implementation, documentation, and test results. Independent user review of the changed source and documentation remains invited.

**Disposition:** PCR-059 is resolved. Guarded live-provider qualification and manual demonstrations remain optional follow-up activities.

### Review 13 — PCR-073 Native GTK component-stack documentation review (2026-08-23)

**Review type:** Software requirements, design, and test-plan review
**Trigger:** The approved migration direction replaces the current single
`Gtk.Layout`/Cairo/Pango conversation renderer with vertically stacked native
GTK exchange containers and separate semantic component widgets. This review
records the requirements, design, qualification, risk, and implementation
preparation artifacts before source changes begin.

| Indicator | Value |
|---|---|
| Requirements volatility | SRS-CORE v1.14: 164 requirements; 7 additions (REQ-CORE-133..139), 0 deletions. |
| Component progress | Native component-stack: implementation slice complete and unit-tested; full display-backed qualification pending. GtkLayout renderer remains implemented as the default fallback. |
| Open problems | PCR-073 open for DEM-042..044 and R7 open; automated regression suite is green. |
| Milestone status | Implementation slice and unit-test build complete; native-stack test readiness and manual performance qualification remain pending. |
| Scope changes | 1 documented GUI presentation architecture change; additive lifecycle protocol and opt-in native stack implemented. |
| Test results trend | Production and test development builds succeed; full suite passes 916/916 with zero failed assertions and zero unexpected errors. |

**Issues raised at review:** Native widget realization performance, local component
selection semantics, explicit request/footer lifecycle, and live/replay parity must
be qualified before the current renderer is retired.

**Independence limitation:** The developer evaluated their own requirements, design,
test-plan, and project-plan updates. Independent user review and acknowledgement
remain invited.

**Disposition:** PCR-073 remains open pending implementation and qualification.

### Review 14 — PCR-073 native tool-card summary amendment (2026-08-24)

**Review type:** Requirements, design, implementation, and test-plan review
**Trigger:** User-confirmed native-stack live demonstration established that
native tool cards should match the compact legacy Pango summary while full
arguments/results remain available through the existing detail window.

| Indicator | Value |
|---|---|
| Requirements volatility | SRS-CORE v1.15: revised REQ-CORE-113e, 134, 137, and 138; no requirement IDs added or removed. |
| Component progress | Native summary/detail implementation complete and unit-tested; legacy GtkLayout renderer remains the default fallback. |
| Open problems | PCR-073 remains open for revised DEM-042..044 qualification; R7 remains open. |
| Milestone status | Requirements/design/test-plan amendment, implementation, and regression testing complete; display-backed replay/performance qualification remains pending. |
| Scope changes | 1 presentation refinement within the PCR-073 GUI architecture change; no change to Plain semantics. |
| Test results trend | Production and test development builds succeed; full suite passes 917/917 with zero failed assertions and zero unexpected errors. |

**Disposition:** The requirements/design amendment and implementation are
complete behind `COYOTE_NATIVE_STACK=1`. The user-confirmed live demonstration
and the 917-test regression baseline are recorded; revised replay and
performance qualification remain pending. The developer is evaluating their own
work, so independent user review remains invited.

### Review 15 — PCR-073 visible per-step frame implementation (2026-08-25)

**Trigger:** User-requested refinement to make the assistant/tool steps that
are currently delineated by footers visibly distinct in the native GTK stack.
The SRS, SDD, SDF, Test Plan, and PCR-073 records were amended; the native
stack implementation and focused tests were started.

| Requirements volatility | SRS-CORE v1.16: no new requirement ID; REQ-CORE-134 amended to require a visible native frame per assistant/tool step. |
| Component progress | Step-frame implementation compiles; focused frame lifecycle tests added; replay step boundaries amended; display-backed qualification pending. |
| Open problems | PCR-073 and R7 remain open for visual, replay, and 100/500/2,000-exchange qualification. |
| Scope changes | One refinement within the existing native GTK presentation change; Plain semantics unchanged. |
| Test results trend | Production/test development builds succeed; full regression run was interrupted by command timeout during the existing long-running suite; focused native-stack result is recorded separately. |

**Independence limitation:** Developer evaluated own implementation; the user is
invited to independently review the visible frame behavior and acceptance results.

### Review 16 — PCR-073 automated regression correction (2026-08-25)

**Review type:** Test results and corrective-action review
**Trigger:** Investigation of the two native-stack step-frame failures
reported in the combined test suite.

| Indicator | Value |
|---|---|
| Requirements volatility | No requirement changes; PCR-073 corrective implementation and test-isolation change only. |
| Component progress | Native stack implementation and automated regression complete; display-backed qualification remains pending. |
| Open problems | PCR-073 remains open only for DEM-042..044 visual, replay, and large-history qualification; R7 remains open. |
| Milestone status | Automated corrective action complete and verified on 2026-08-25. |
| Scope changes | No scope change; fixture isolation and exchange bookkeeping correction within PCR-073. |
| Test results trend | Production and test development builds succeed; native-stack group passes 10/10 and full suite passes 921/921 with 0 failed assertions and 0 unexpected errors. |

**Finding:** AUnit reused the native-stack fixture object between test methods.
The fixture did not clear the stack, and `Begin_Request` did not clear the
prior exchange's `Step_Frames` vector. The resulting failures were test-order
dependent and did not indicate failure to create or realize GTK frames.

**Disposition:** The production exchange reset and fixture cleanup are
implemented. Automated PCR-073 failures are resolved. DEM-042 and DEM-043
component/replay demonstrations and DEM-044 qualification for 100, 500, and
2,000 exchanges remain pending. The developer evaluated their own corrective
work; independent user review remains invited.

### Review 17 — PCR-077 Subagent Recursion-Depth Limit (2026-08-25)

**Review type:** Software requirements, design, implementation, and test-results review
**Trigger:** User-approved implementation of a configurable maximum recursion
limit for shell-launched `--subagent` processes.

| Indicator | Value |
|---|---|
| Requirements volatility | SRS-CORE v1.17: one new requirement (REQ-CORE-025); configuration requirement amended. |
| Component progress | Recursion-depth setting, startup enforcement, regression tests, and documentation complete. |
| Open problems | PCR-077 resolved; DEM-045 remains for manual user-visible qualification. |
| Milestone status | Implementation and automated qualification complete. |
| Scope changes | One approved subagent recursion-control enhancement. |
| Test results trend | Production and test development builds succeed; full suite passes 925/925 with zero failed assertions and zero unexpected errors. |

**Disposition:** `maxRecursionDepth` defaults to 1. `COYOTE_RECURSION_DEPTH`
is inherited through shell-launched processes and incremented only by
`--subagent`. Over-limit children are rejected before frontend/session startup.
Fork and New Window launches do not add recursion depth. The developer
performed the self-evaluation; independent user review and DEM-045 remain
invited.

### Review 18 — PCR-078 DEM-046 Native Markdown Acceptance (2026-08-28)

**Review type:** Test-results and user-acceptance review
**Trigger:** User review of the native GTK Markdown demonstration fixture

| Indicator | Value |
|---|---|
| Requirements volatility | No requirement changes; DEM-046 acceptance recorded for REQ-CORE-111 and REQ-CORE-125. |
| Component progress | Native response-block Markdown conversion, toggle routing, zoom routing, and focused regressions complete; DEM-046 accepted. |
| Open problems | PCR-078 remains in progress for DEM-047 native live/replay parity, DEM-048 native MathML, and DEM-044 large-history qualification. |
| Milestone status | DEM-046 accepted on 2026-08-28; remaining native qualification gates pending. |
| Scope changes | No scope change. |
| Test results trend | 927 tests registered; focused native Markdown tests pass individually; full-suite run remains unaccepted because the prior execution timed out with unrelated environment-dependent failures. |

**Disposition:** The user reviewed the sample native Markdown rendering and
accepted DEM-046. This closes the DEM-046 acceptance gate for supported GFM
content, post-stream conversion, source-preserving toggle behavior, selection,
and zoom. It does not close PCR-078. DEM-047, DEM-048, and DEM-044 remain open.
The developer recorded and evaluated the result; independent review remains
invited.

### Review 19 — PCR-078 DEM-047 Native Live/Replay Markdown Acceptance (2026-08-28)

**Review type:** Test-results and user-acceptance review
**Trigger:** User confirmation of native live/replay Markdown parity

| Indicator | Value |
|---|---|
| Requirements volatility | No requirement changes; DEM-047 acceptance recorded for REQ-CORE-111, REQ-CORE-131, and REQ-CORE-137. |
| Component progress | Native live/replay Markdown content and component-hierarchy parity accepted; DEM-046 and DEM-047 complete. |
| Open problems | PCR-078 remains in progress for DEM-048 native MathML and DEM-044 large-history qualification. |
| Milestone status | DEM-047 accepted on 2026-08-28; remaining native qualification gates pending. |
| Scope changes | No scope change. |
| Test results trend | 927 tests registered; focused native Markdown tests pass individually; full-suite run remains unaccepted because the prior execution timed out with unrelated environment-dependent failures. |

**Disposition:** The user confirmed equivalent native live and replayed Markdown
content and response boundaries and accepted DEM-047. This closes the DEM-047
acceptance gate for native live/replay Markdown parity. It does not close
PCR-078. DEM-048 and DEM-044 remain open. The developer recorded and evaluated
the result; independent review remains invited.

### Review 20 — PCR-087 GTK model-picker dB price display (2026-08-30)

**Review type:** Requirements, design, implementation, and test-results review
**Trigger:** User-approved implementation of configurable dB `$ / tok` display
in the GTK model picker.

| Indicator | Value |
|---|---|
| Requirements volatility | SRS-CORE v1.19: amended REQ-CORE-116, 117, 129, and 230; no requirement IDs added or removed. |
| Component progress | Price formatter, GTK Preferences control, settings persistence, typed queue transport, tests, and documentation complete. |
| Open problems | PCR-087 remains open for display-backed qualification under DEM-033. |
| Milestone status | Implementation and automated verification complete on 2026-08-30; display-backed review pending. |
| Scope changes | One approved GTK presentation preference enhancement; provider pricing and Plain output unchanged. |
| Test results trend | 940 registered tests; production and test development builds succeed; full suite passes 940/940 with zero failed assertions and zero unexpected errors. |

**Disposition:** SI prefixes remain the default. The Preferences combo selects
SI or dB mode; dB uses `10 × log10 (p / 1,000,000)` for stored $/MTok `p`,
with zero shown as `free` and negative values blank. The developer performed
self-evaluation; independent user review and display-backed DEM-033 remain
invited.

### Review 21 — PCR-090 Acme frontend removal (2026-08-30)

**Review type:** Scope, requirements, design, implementation, and test-results review
**Trigger:** Approved removal of the Acme UI frontend and associated desktop integration.

| Indicator | Value |
|---|---|
| Scope change | Retired the Acme UI, Nine_P 9P stack, plumber integration, `coyote_open`, and associated tests. Current frontends are GTK and Plain. |
| Architectural result | Added the synchronous Plain runner and reduced shared frontend APIs to GUI/plain needs. |
| Verification | Development production build succeeds; the complete test suite passes 798/798 with zero failed assertions and zero unexpected errors. |
| Documentation | README, man page, SRS, SDD, SDF, Test Plan, Integration Guide, AGENTS, and this Project Plan updated. |
| Disposition | Implemented. Historical Acme requirements and review records remain retained as superseded records. |


### Review 22 — Native GTK conversation cutover (2026-08-31)

**Review type:** Scope, requirements, design, implementation, and
qualification review
**Trigger:** User-approved retirement of the qualified legacy GTK conversation
renderer.

| Indicator | Value |
|---|---|
| Scope change | Removed the custom GtkLayout/Cairo/Pango conversation renderer, its test accessors and tests, and the `COYOTE_NATIVE_STACK` runtime switch. The native component stack is the sole GTK conversation presentation; Plain remains supported. |
| Component progress | Native exchange/step hierarchy, Markdown, MathML, selection, zoom, responsive tool cards, replay, reset, and large-history behavior qualified and integrated unconditionally. |
| Verification | Production and test development builds succeed. The 17-test native-stack group passes 17/17; the GUI lifecycle regression passes 1/1 with zero failed assertions and zero unexpected errors. The post-cutover suite registers 762 tests. |
| Risk disposition | R7 closed. Native qualification gates DEM-042 through DEM-048 are closed. |
| Documentation | SRS-CORE 1.21, SDD-CORE 1.24, TEST-PLAN 1.25, frontend SDF, and PCR-092 record the cutover. This historical review predates PCR-093. |
| Disposition | Implemented and qualified. Historical migration records remain retained as superseded records. |

### Review 23 — PCR-093 Virtual-agent-window organization amendment (2026-08-31)

**Review type:** Joint scope, requirements, design, and documentation review
**Trigger:** User acceptance of the virtual-agent-window organization plan to
remove desktop pollution while preserving independent short-lived subagent
execution and active steering semantics.

| Indicator | Value |
|---|---|
| Scope change | Add an agents tree and coordinator RPC presentation path; no change to subagent persistence or one-shot termination semantics. |
| Requirements | Added REQ-CORE-020a..020c, revised REQ-CORE-020 and REQ-CORE-005, and revised REQ-CORE-115/115a for selected-agent routing and virtual windows. |
| Design | Implemented `Coyote_App.Frontend.RPC`, `Coyote_App.Agent_Registry`, and `Coyote_App.Agent_RPC` boundaries, plus shared selected-agent conversation presentation. |
| Test planning | Added DEM-050..053 for tree registration, selected-agent prompt/control routing, retained terminal records, and bidirectional RPC. |
| Verification | Production and test builds pass. Focused registry, codec, transport, and service tests pass sequentially; full-suite execution remains sensitive to fixed endpoint contamination. Display-backed and real-provider end-to-end qualification remain open. |
| Open problem | PCR-093 In Progress, priority 2-Serious, pending DEM-050..053 completion. |
| Disposition | Implementation slice complete; focused qualification passed; remaining GUI/display and provider-backed qualification is tracked under DEM-050..053. |

## 9. Artifact Version Table


| Artifact | ID | Location | Current Version | Control Level |
|---|---|---|---|---|
| Project Plan | PLAN | `plan/project-plan.md` | 1.27 (2026-08-31) | Project |
| Problem/Change Log | PCR-LOG | `plan/problems.md` | active | Project |
| coyote Requirements Spec | SRS-CORE | `requirements/coyote-requirements.md` | 1.22 (2026-08-31) | Client |
| coyote Design Description | SDD-CORE | `design/coyote-design.md` | 1.25 (2026-08-31) | Project |
| coyote_sqc Requirements Spec | SRS-SQC | `requirements/coyote-sqc-requirements.md` | 0.2 (2026-06-21) | Project |
| coyote_sqc Design Spec | SDD-SQC | `design/coyote-sqc-design.md` | 0.2 (2026-06-21) | Project |
| Test Plan | TEST-PLAN | `plan/test-plan.md` | 1.26 (2026-08-31) | Project |
| Agent Working Instructions (secondary) | AGENTS | `AGENTS.md` | active | Project |