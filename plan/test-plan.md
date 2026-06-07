# Test Plan — coyote (STP)

**Version:** 1.1
**Date:** 2026-06-03
**Status:** Reviewed and acknowledged — M4 complete (2026-06-03)
**Requirements:** `requirements/coyote-requirements.md` (SRS-CORE)
**Project Plan:** `plan/project-plan.md`

---

## Table of Contents

1. [Scope](#1-scope)
2. [Referenced Documents](#2-referenced-documents)
3. [Test Environment](#3-test-environment)
4. [Test Identification](#4-test-identification)
5. [Test Schedule](#5-test-schedule)
6. [Requirements Traceability](#6-requirements-traceability)
7. [Notes](#7-notes)

---

## 1. Scope

This Test Plan covers acceptance testing for the coyote core agent component
(SRS-CORE). It applies to both component-level acceptance testing (§5.9) and,
since the system is software-only with no separate system stratum, serves also
as the system acceptance test plan (§5.11).

The plan covers the AUnit automated test suite and identifies which requirements
are verified by demonstration or inspection rather than automated tests.

The coyote_sqc component has its own test suite and is partially covered by
this plan where it exercises shared code (`coyote_renderer`,
`coyote-session-format` parsing); its full acceptance criteria are governed
by SRS-SQC (`requirements/coyote-sqc-requirements.md`).

**Independence limitation:** The developer is evaluating their own work. This
limitation is declared here and at each test results review. The user (product
owner) is invited to independently review test results before accepting them.

---

## 2. Referenced Documents

| ID | Title | Location |
|---|---|---|
| SRS-CORE | coyote Requirements Specification | `requirements/coyote-requirements.md` |
| SDD-CORE | coyote Design Description | `design/coyote-design.md` |
| PLAN | Project Plan | `plan/project-plan.md` |
| TEST-GUIDE | Integration Test Guide | `plan/integration-test-guide.md` |

---

## 3. Test Environment

### 3.1 Build Environment

- **Compiler:** GNAT (Ada 2022), GCC-based
- **Build system:** Alire (`alr build`), GPRbuild
- **Build command:** `alr build` (development profile)
- **Test build:** `cd test && alr build`
- **Test run:** `cd test && alr run coyote_test`

### 3.2 Runtime Dependencies

| Dependency | Required by | Version constraint |
|---|---|---|
| GTK3 runtime + dev headers | GUI frontend, coyote_sqc | ≥ 3.0 |
| libcurl + dev headers | All providers (LLM.HTTP) | Any current |
| libcmark-gfm + dev headers | GUI frontend markdown rendering | Any current |
| plan9port | Acme frontend and plumber | At `/usr/local/plan9` |
| GNATCOLL | JSON processing | ≥ 25.0.0 (via Alire) |

### 3.3 Test Infrastructure

**AUnit automated tests:** `test/src/` contains the full AUnit suite.
The suite is self-contained: all non-integration tests run without a live
acme instance, live LLM provider, or display. Fixtures are in `test/fixtures/`.

**Integration tests:** Tests in the following files require a live environment
and are **opt-in** (guarded by environment variable checks at test startup):

| Test file | Guard variable | Requires |
|---|---|---|
| `acme_integration_tests.adb` | `COYOTE_TEST_ACME=1` | Running acme instance |
| `nine_p_integration_tests.adb` | `COYOTE_TEST_9P=1` | 9P server |
| `llm_github_copilot_tests.adb` | `COYOTE_TEST_COPILOT=1` | Valid Copilot credentials |
| `llm_anthropic_messages_tests.adb` | `COYOTE_TEST_ANTHROPIC=1` | Valid Anthropic API key |
| `llm_agent_tests.adb` (live tests) | `COYOTE_TEST_LIVE=1` | Any live provider |

See `plan/integration-test-guide.md` for full setup instructions.

### 3.4 Known Test Environment Constraints

- GUI frontend tests that exercise `Coyote_GUI.Buffer` require GTK3 to be
  installed, but do not require a display (GtkTextBuffer can be created
  headlessly).
- Tests that require `$DISPLAY` or `$WAYLAND_DISPLAY` for window creation
  are not part of the standard automated suite.

---

## 4. Test Identification

### 4.1 General Information

**Testing levels covered:** Component acceptance testing (all requirements
in SRS-CORE). No separate hardware integration testing (software-only system).

**Classes of tests:**
- **Functional:** Verifies that each stated capability operates correctly under
  normal inputs and conditions.
- **Boundary:** Verifies behaviour at boundary conditions (empty prompt, maximum
  result size, zero-length session, missing config file).
- **Error / negative:** Verifies correct error handling for invalid inputs,
  missing files, provider failures, and abort conditions.
- **Regression:** Re-runs the full AUnit suite after each code change to confirm
  no previously passing test has been broken.

**Qualification methods used:**
- **T (Test):** AUnit automated test case.
- **D (Demonstration):** Manual demonstration by running the application.
- **I (Inspection):** Code review.
- **A (Analysis):** Build artefact or design document analysis.

**Progression criterion:** All 665+ AUnit tests must pass before any
demonstration-verified requirements are reviewed. Demonstration tests are
performed after the automated suite is green.

### 4.2 Planned Tests — Automated (AUnit)

The following test modules exist in `test/src/`. Each maps to one or more
SRS-CORE requirement groups.

| Test module | Requirements covered | Test count (approx.) |
|---|---|---|
| `llm_sse_tests.adb` | REQ-CORE-200 (SSE parsing) | ~30 |
| `llm_session_store_tests.adb` | REQ-CORE-080–083, 240–241 | ~40 |
| `llm_skills_tests.adb` | REQ-CORE-090–093 | ~20 |
| `llm_settings_tests.adb` | REQ-CORE-230–233, 070–073 | ~25 |
| `llm_auth_tests.adb` | REQ-CORE-232 | ~15 |
| `llm_compaction_tests.adb` | REQ-CORE-060–064 | ~30 |
| `llm_tools_tests.adb` | REQ-CORE-050–053 | ~25 |
| `llm_system_prompt_tests.adb` | REQ-CORE-090–092 | ~10 |
| `llm_types_tests.adb` | REQ-CORE-400–402 | ~20 |
| `llm_agent_tests.adb` | REQ-CORE-040–046, 060–064 | ~80 |
| `llm_parallel_tools_tests.adb` | REQ-CORE-050 (parallel tools) | ~10 |
| `llm_context_tests.adb` | REQ-CORE-060 (compaction threshold) | ~15 |
| `session_history_tests.adb` | REQ-CORE-130–131 | ~15 |
| `dispatch_tests.adb` | REQ-CORE-040–046 (dispatch) | ~20 |
| `coyote_app_tests.adb` | REQ-CORE-010–023 (CLI parsing) | ~30 |
| `coyote_utils_tests.adb` | REQ-CORE-023 | ~10 |
| `llm_model_registry_tests.adb` | REQ-CORE-070–071 | ~15 |
| `llm_catalogue_tests.adb` | REQ-CORE-072 | ~10 |
| `llm_http_tests.adb` | REQ-CORE-200 (HTTP streaming) | ~20 |
| `llm_openai_completions_tests.adb` | REQ-CORE-201 | ~30 |
| `llm_anthropic_messages_tests.adb` | REQ-CORE-202 | ~30 |
| `llm_openrouter_tests.adb` | REQ-CORE-072 (OpenRouter) | ~15 |
| `tool_uri_tests.adb` | REQ-CORE-100–108 (plumb token format) | ~10 |
| `coyote_cmark_tests.adb` | REQ-CORE-111 (Markdown rendering) | ~25 |
| `nine_p_proto_tests.adb` | REQ-CORE-210 (9P protocol) | ~20 |
| `nine_p_mock_server_tests.adb` | REQ-CORE-210–211 | ~15 |
| `session_lister_tests.adb` | REQ-CORE-084 | ~10 |
| `coyote_sqc_parser_tests.adb` | REQ-CORE-240–241 | ~25 |
| `coyote_sqc_statistics_tests.adb` | SRS-SQC statistics | ~40 |
| `coyote_sqc_workspace_tests.adb` | SRS-SQC workspace | ~20 |
| `coyote_sqc_integrity_tests.adb` | SRS-SQC integrity | ~15 |
| `coyote_sqc_jsd_tests.adb` | SRS-SQC JSD metrics | ~20 |
| `coyote_sqc_histogram_tests.adb` | SRS-SQC histogram | ~10 |
| `coyote_sqc_bootstrap_tests.adb` | SRS-SQC §5.17 bootstrap CI, §10.3 two-set histogram bins | ~7 |
| `acme_event_parser_tests.adb` | REQ-CORE-100–108 | ~20 |
| `acme_raw_events_tests.adb` | REQ-CORE-100 | ~10 |

**Total automated tests (current):** **660** (+ 7 pending: bootstrap CI and two-set histogram tests required by SRS-SQC §15.6, added 2026-06-06)

### 4.3 Planned Tests — Demonstration

Requirements verified by demonstration (method D) are listed below. Each
is performed manually by running the application and observing the stated
behaviour. Results are recorded in a Test Report.

| Test ID | Requirement | Procedure |
|---|---|---|
| DEM-001 | REQ-CORE-001 | Run `coyote --one-shot --prompt "hello"` without $winid set; verify Plain frontend used and JSON printed to stdout |
| DEM-002 | REQ-CORE-002 | Run coyote from inside an acme window ($winid set); verify Acme frontend opens a window |
| DEM-003 | REQ-CORE-003 | Run coyote with $DISPLAY set, no $winid; verify GUI window opens |
| DEM-004 | REQ-CORE-019 | `coyote --one-shot --prompt "echo hello"` exits after one turn; check exit code 0 and JSON on stdout |
| DEM-005 | REQ-CORE-020 | `coyote --subagent --prompt "hello"` opens a window (does not force Plain) |
| DEM-006 | REQ-CORE-040–044 | Start a GUI session; send a prompt; verify streaming text, thinking, tool events, and stats appear |
| DEM-007 | REQ-CORE-055 | Start a long tool execution; press Stop; verify tool is cancelled and agent exits cleanly |
| DEM-008 | REQ-CORE-060 | Configure a small context window; send prompts until threshold reached; verify auto-compaction notice appears |
| DEM-009 | REQ-CORE-061 | Trigger manual compact in Acme (Compact tag) and GUI (menu); verify compaction summary appears |
| DEM-010 | REQ-CORE-070 | Set defaultModel in settings.json; start coyote without --model; verify correct model used |
| DEM-011 | REQ-CORE-074 | Use an expired Copilot token; send a prompt; verify token is refreshed and request succeeds |
| DEM-012 | REQ-CORE-075 | In Acme, plumb a `coyote-model+PID/...` token; verify model changes on next turn |
| DEM-013 | REQ-CORE-100–107 | Exercise each Acme tag command; verify expected behaviour for each |
| DEM-014 | REQ-CORE-110–114 | Exercise GUI window: markdown rendering, tool frames, vi scroll, menu actions |
| DEM-015 | REQ-CORE-130 | Resume a session; verify history replayed in frontend |
| DEM-016 | REQ-CORE-140 | Inject a provider error (invalid API key); verify error notice visible in frontend |
| DEM-017 | REQ-CORE-142 | Send SIGTERM to a running coyote; verify clean exit and session file is intact |
| DEM-018 | REQ-CORE-084 | Run `coyote_list_sessions` in a directory with sessions; verify output lists sessions |

### 4.4 Planned Tests — Inspection

Requirements verified by inspection (method I) are reviewed against source
code and build artefacts during the design review and at code review. No
separate execution is required. All REQ-CORE-{5xx, 8xx, 300–302, 400–402}
requirements fall into this class.

### 4.5 Coverage Gaps

The following SRS-CORE requirements currently have no automated test case
and must be demonstrated or inspected:

- REQ-CORE-011, 012 — CWD restoration on session resume (requires filesystem)
- REQ-CORE-022 — prompt-filter (requires shell subprocess)
- REQ-CORE-074 — Copilot token auto-refresh (requires live Copilot credential)
- REQ-CORE-075, 076 — plumb-port model/thinking switch (requires live acme)
- REQ-CORE-107 — Acme Pause/Resume (partial; pause mechanics tested in AUnit
  via `llm_agent_tests.adb`)
- REQ-CORE-142 — SIGTERM handling (requires OS signal; manual test)

These are entered as open items in the problem log (PCR-009).

---

## 5. Test Schedule

| Activity | Milestone | Status |
|---|---|---|
| AUnit suite baseline recorded | M2 complete | Done — 660 tests, all pass |
| Test Plan reviewed and acknowledged | M4 | Pending |
| Demonstration tests performed | After M4 | Pending |
| Test Report produced | M6 | Pending |
| Coverage gaps addressed or accepted | M6 | Pending |

---

## 6. Requirements Traceability

| Requirement | Verification method | Test reference |
|---|---|---|
| REQ-CORE-001–004 | D | DEM-001 to DEM-003 |
| REQ-CORE-005 | I | Code inspection |
| REQ-CORE-010–018 | T | `coyote_app_tests.adb` |
| REQ-CORE-019–020 | D | DEM-004, DEM-005 |
| REQ-CORE-021 | D | DEM-013 (Acme window name) |
| REQ-CORE-022 | D | DEM (TBD) |
| REQ-CORE-023 | T | `coyote_utils_tests.adb` |
| REQ-CORE-030–032 | T/I | `coyote_app_tests.adb`, code inspection |
| REQ-CORE-040–046 | T/D | `dispatch_tests.adb`, `llm_agent_tests.adb`, DEM-006 |
| REQ-CORE-050–053 | T | `llm_tools_tests.adb` |
| REQ-CORE-054 | D | DEM (--no-tools with tool model) |
| REQ-CORE-055 | D | DEM-007 |
| REQ-CORE-060–064 | T/D | `llm_compaction_tests.adb`, `llm_context_tests.adb`, DEM-008–009 |
| REQ-CORE-070–073 | T/D | `llm_settings_tests.adb`, `llm_model_registry_tests.adb`, DEM-010 |
| REQ-CORE-074 | D | DEM-011 |
| REQ-CORE-075–076 | D | DEM-012 |
| REQ-CORE-080–083 | T | `llm_session_store_tests.adb` |
| REQ-CORE-084 | T/D | `session_lister_tests.adb`, DEM-018 |
| REQ-CORE-090–093 | T | `llm_skills_tests.adb` |
| REQ-CORE-100–108 | T/D | `acme_event_parser_tests.adb`, `tool_uri_tests.adb`, DEM-013 |
| REQ-CORE-110–115 | T/D | `coyote_cmark_tests.adb`, DEM-014 |
| REQ-CORE-120–121 | D | DEM-001 (plain output) |
| REQ-CORE-130–131 | T/D | `session_history_tests.adb`, DEM-015 |
| REQ-CORE-140–141 | D | DEM-016 |
| REQ-CORE-142 | D | DEM-017 |
| REQ-CORE-200–203 | T/I | `llm_sse_tests.adb`, `llm_openai_completions_tests.adb`, `llm_anthropic_messages_tests.adb`, code inspection |
| REQ-CORE-210–212 | T/I | `nine_p_proto_tests.adb`, `nine_p_mock_server_tests.adb`, code inspection |
| REQ-CORE-220–221 | I | Code inspection (GTK call sites) |
| REQ-CORE-230–233 | T | `llm_settings_tests.adb`, `llm_auth_tests.adb` |
| REQ-CORE-240–241 | T | `llm_session_store_tests.adb`, `coyote_sqc_parser_tests.adb` |
| REQ-CORE-300–302 | I | Code inspection |
| REQ-CORE-400–402 | T/I | `llm_types_tests.adb`, code inspection |
| REQ-CORE-500–505 | I | Build artefact inspection |
| REQ-CORE-600–601 | A | Design analysis |
| REQ-CORE-700 | D | DEM-006 (streaming latency) |
| REQ-CORE-701 | T | `llm_session_store_tests.adb` |
| REQ-CORE-702 | D | DEM-016 |
| REQ-CORE-703 | I | Code inspection (task exception handlers) |
| REQ-CORE-704 | I | Code inspection (provider package structure) |
| REQ-CORE-800–805 | I | Build artefact inspection, code inspection |

---

## 7. Notes

**Dry run policy:** Before proposing a test results review to the user, a
full `cd test && alr run coyote_test` run is performed and the pass count
and any failures are recorded here or in the Test Report.

**Baseline as of 2026-06-01:** 658 tests, 0 failures, 0 unexpected errors.
**Baseline as of 2026-06-06 (PCR-016 Bootstrap):** 665 tests, 0 failures,
0 unexpected errors.  Added 5 Bootstrap CI tests
(`Test_Bootstrap_Point_Estimates`, `Test_Bootstrap_CI_Coverage`,
**Baseline as of 2026-06-07 (PCR-022 Thinking Display):** 665 tests, 0 failures,
0 unexpected errors.  Test count unchanged; `Test_Dispatch_Thinking_Delta` updated
to reflect new buffering semantics (now emits both `Thinking_Delta` and `Thinking_End`
events to verify collapsing behaviour).  No new test cases added; existing test
infrastructure sufficient to cover the buffering and collapsing logic.
`Test_Bootstrap_NA_Insufficient`, `Test_Bootstrap_NA_SD_Zero`,
`Test_Bootstrap_Reproducibility`) for `Coyote_SQC.Statistics.Bootstrap`.
**Baseline as of 2026-06-03:** 660 tests, 0 failures, 0 unexpected errors.
(+2 tests: Test_Parse_File_Sets_File_Path, Test_Parse_File_Sets_File_Mtime
for PCR-015 incremental reload fix.)

**Coverage gap PCR:** The gaps identified in §4.5 are logged in
`plan/problems.md` as PCR-009. They are accepted as deferred for the current
build with the rationale that the uncovered requirements are either low-risk
(SIGTERM handling) or require live external services (Copilot, live acme).
**Baseline as of 2026-06-06:** 660 tests, 0 failures, 0 unexpected errors.  7 new test cases required by SRS-SQC §15.6 (§5.17 bootstrap CI, §10.3 two-set histogram) are pending implementation; they are not yet included in the suite.
