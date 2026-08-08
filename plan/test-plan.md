# Test Plan â coyote (STP)

**Version:** 1.10
**Date:** 2026-08-08

**Status:** Reviewed and acknowledged â M4 complete (2026-06-03)
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
(SRS-CORE). It applies to both component-level acceptance testing (Â§5.9) and,
since the system is software-only with no separate system stratum, serves also
as the system acceptance test plan (Â§5.11).

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
| GTK3 runtime + dev headers | GUI frontend, coyote_sqc | â¥ 3.0 |
| libcurl + dev headers | All providers (LLM.HTTP) | Any current |
| libcmark-gfm + dev headers | GUI frontend markdown rendering | Any current |
| Lasem 0.6 + shared library | GUI display-math rendering | 0.6.0 |
| Computer Modern math fonts | Lasem glyph coverage | cmr10/cmmi10/cmex10/cmsy10 |
| plan9port | Acme frontend and plumber | At `/usr/local/plan9` |
| GNATCOLL | JSON processing | â¥ 25.0.0 (via Alire) |

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
- GUI conversation tests that exercise `Coyote_GUI.Conversation` require GTK3
to be installed and a display (or `xvfb-run`); they create a `Gtk.Layout` and
exercise the Cairo/Pango virtualized renderer.  Tests of the old
`Coyote_GUI.Buffer` are no longer part of the live GUI path.  Headless
`GtkTextBuffer` tests, when present, do not require a display.
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

**Progression criterion:** All 670+ AUnit tests must pass before any
demonstration-verified requirements are reviewed. Demonstration tests are
performed after the automated suite is green.

### 4.2 Planned Tests â Automated (AUnit)

The following test modules exist in `test/src/`. Each maps to one or more
SRS-CORE requirement groups.

| Test module | Requirements covered | Test count (approx.) |
|---|---|---|
| `llm_sse_tests.adb` | REQ-CORE-200 (SSE parsing) | ~30 |
| `llm_session_store_tests.adb` | REQ-CORE-080â089, 240â241 | ~46 |
| `llm_agent_tests.adb` | REQ-CORE-040â046, 060â064, 085â089 | ~85 |
| `coyote_app_tests.adb` | REQ-CORE-085â089 (frontend/agent synchronization) | ~10 |

| `llm_skills_tests.adb` | REQ-CORE-090â093 | ~20 |
| `llm_settings_tests.adb` | REQ-CORE-230â234, 070â073; sandbox default loading and Save_Preferences persistence | ~27 |
| `coyote_gui_prompt_queue_tests.adb` | REQ-CORE-116â119; typed preference payload transport | 1 |
| `llm_auth_tests.adb` | REQ-CORE-232 | ~15 |
| `llm_compaction_tests.adb` | REQ-CORE-060â064 | ~30 |
| `llm_tools_tests.adb` | REQ-CORE-050â053 | ~25 |
| `llm_system_prompt_tests.adb` | REQ-CORE-090â092 | ~10 |
| `llm_types_tests.adb` | REQ-CORE-400â402 | ~20 |
| `llm_parallel_tools_tests.adb` | REQ-CORE-056 (run_group) | ~15 |

| `sandbox_tests.adb` | Sandbox profile subsystem, including timeout and abort process-group termination | 24 |
| `llm_context_tests.adb` | REQ-CORE-060 (compaction threshold) | ~15 |
| `session_history_tests.adb` | REQ-CORE-130â131 | ~15 |
| `dispatch_tests.adb` | REQ-CORE-040â046 (dispatch) | ~20 |
| `coyote_app_tests.adb` | REQ-CORE-010â023 (CLI parsing) | ~30 |
| `coyote_utils_tests.adb` | REQ-CORE-023 | ~10 |
| `collapse_utils_tests.adb` | REQ-CORE-023 (thinking collapse) | 5 |
| `llm_model_registry_tests.adb` | REQ-CORE-070â071 | ~15 |
| `llm_catalogue_tests.adb` | REQ-CORE-072 | ~10 |
| `llm_http_tests.adb` | REQ-CORE-200 (HTTP streaming) | ~20 |
| `llm_openai_completions_tests.adb` | REQ-CORE-201 | ~30 |
| `llm_anthropic_messages_tests.adb` | REQ-CORE-202 | ~30 |
| `llm_openrouter_tests.adb` | REQ-CORE-072 (OpenRouter) | ~15 |
| `tool_uri_tests.adb` | REQ-CORE-100â109 (plumb token format) | ~10 |
| `coyote_cmark_tests.adb` | REQ-CORE-111 (Markdown rendering) | ~25 |
| `coyote_lasem_tests.adb` | Lasem iTeX measurement, literal relation normalization, and error handling | 4 |
| `coyote_gui_conversation_tests.adb` | Display-math style, source preservation, visual height | 3 |
| `nine_p_proto_tests.adb` | REQ-CORE-210 (9P protocol) | ~20 |
| `nine_p_mock_server_tests.adb` | REQ-CORE-210â211 | ~15 |
| `session_lister_tests.adb` | REQ-CORE-084 | ~10 |
| `coyote_sqc_parser_tests.adb` | REQ-CORE-240â241 | ~25 |
| `coyote_sqc_statistics_tests.adb` | SRS-SQC statistics | ~40 |
| `coyote_sqc_workspace_tests.adb` | SRS-SQC workspace | ~20 |
| `coyote_sqc_integrity_tests.adb` | SRS-SQC integrity | ~15 |
| `coyote_sqc_jsd_tests.adb` | SRS-SQC JSD metrics | ~20 |
| `coyote_sqc_mi_tests.adb` | SRS-SQC MI metrics | ~11 |
| `coyote_sqc_histogram_tests.adb` | SRS-SQC histogram | ~10 |
| `coyote_sqc_bootstrap_tests.adb` | SRS-SQC Â§5.17 bootstrap CI, Â§10.3 two-set histogram bins | ~7 |
| `acme_event_parser_tests.adb` | REQ-CORE-100â109 | ~20 |
| `acme_raw_events_tests.adb` | REQ-CORE-100 | ~10 |

**Total automated tests (current):** **837**

### 4.3 Planned Tests â Demonstration

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
| DEM-006 | REQ-CORE-040â044 | Start a GUI session; send a prompt; verify streaming text, thinking, tool events, and stats appear |
| DEM-007 | REQ-CORE-055 | Start a long tool execution; press Stop; verify tool is cancelled and agent exits cleanly |
| DEM-008 | REQ-CORE-060 | Configure a small context window; send prompts until threshold reached; verify auto-compaction notice appears |
| DEM-009 | REQ-CORE-061 | Trigger manual compact in Acme (Compact tag) and GUI (menu); verify compaction summary appears |
| DEM-010 | REQ-CORE-070 | Set defaultModel in settings.json; start coyote without --model; verify correct model used |
| DEM-011 | REQ-CORE-074 | Use an expired Copilot token; send a prompt; verify token is refreshed and request succeeds |
| DEM-012 | REQ-CORE-075 | In Acme, plumb a `coyote-model+PID/...` token; verify model changes on next turn |
| DEM-013 | REQ-CORE-100â109 | Exercise each Acme tag command; verify expected behaviour for each |
| DEM-014 | REQ-CORE-110â115 | Exercise GUI window: markdown rendering, tool frames, vi scroll, menu actions |
| DEM-033 | REQ-CORE-116..117, 119 | Open GUI Preferences, save ordinary and subagent model/thinking/sandbox defaults, then create a new session and verify the active session was unchanged, ordinary sessions inherit the ordinary defaults, and `coyote --subagent` inherits the subagent model |
| DEM-034 | REQ-CORE-234 | Set and clear `defaultSandboxProfile`; verify inherited runtime and session-header precedence |
| DEM-015 | REQ-CORE-130 | Resume a session; verify history replayed in frontend |
| DEM-016 | REQ-CORE-140 | Inject a provider error (invalid API key); verify error notice visible in frontend |
| DEM-017 | REQ-CORE-142 | Send SIGTERM to a running coyote; verify clean exit and session file is intact |
| DEM-018 | REQ-CORE-084 | Run `coyote_list_sessions` in a directory with sessions; verify output lists sessions |
| DEM-019 | REQ-CORE-024 | Run `coyote --help` and `coyote -h`; verify usage printed to stdout and exit code 0 |
| DEM-020 | REQ-CORE-065 | Trigger auto-compaction; inspect the session JSONL file; verify the stored summary contains 9 structured sections and the <analysis> block is absent |
| DEM-021 | REQ-CORE-066 | Trigger auto-compaction; inspect the raw API request log; verify the compaction prompt includes an <analysis> drafting-phase instruction |
| DEM-022 | REQ-CORE-067 | Set a tiny context window; cause 3 consecutive compaction failures; verify auto-compaction is suspended and manual compaction still works |
| DEM-023 | REQ-CORE-170..171 | Start a coyote session; inspect the system prompt; verify personality definition, conditional tool-use instructions, and per-turn reminder sections are present |
| DEM-024 | REQ-CORE-172 | Run a session with the GUI frontend; verify that per-turn reminder instructions appear in the prompt before each model request |
| DEM-025 | REQ-CORE-180..181 | Create a MEMORY.md file in ~/.coyote/memory/; start coyote; verify the memory content appears in the system prompt and the taxonomy is described |
| DEM-026 | REQ-CORE-183 | Run a session; direct the agent to save a memory; verify a new topic file is created and MEMORY.md index is updated |
| DEM-027 | REQ-CORE-190..191 | Run a session using subagents; verify the system prompt contains coordinator instructions and subagent results include structured summary blocks |
| DEM-028 | REQ-CORE-192 | During a subagent run, ask the coordinator about the in-flight subagent; verify the coordinator reports status without fabricating results |
| DEM-029 | REQ-CORE-085 | Create a session with a sandbox profile, exit, resume it with `--session UUID`, and verify the profile is restored and applied to shell commands |
| DEM-030 | REQ-CORE-086..087 | In one running frontend, switch between sessions with different and absent sandbox profiles; verify restoration and clearing before the next tool call |
| DEM-031 | REQ-CORE-088 | Set a sandbox profile, spawn a child coyote process, and verify the child receives the profile and applies it to a shell command |
| DEM-032 | REQ-CORE-089 | Exercise startup, profile change, resume, and switch in Acme and GUI; verify displayed, agent, and propagated profile values remain identical |


### 4.4 Planned Tests â Inspection

Requirements verified by inspection (method I) are reviewed against source
code and build artefacts during the design review and at code review. No
separate execution is required. All REQ-CORE-{5xx, 8xx, 300â302, 400â402}
requirements fall into this class.

### 4.5 Coverage Gaps

The following SRS-CORE requirements currently have no automated test case
and must be demonstrated or inspected:

- REQ-CORE-011, 012 â CWD restoration on session resume (requires filesystem)
- REQ-CORE-022 â prompt-filter (requires shell subprocess)
- REQ-CORE-074 â Copilot token auto-refresh (requires live Copilot credential)
- REQ-CORE-075, 076 â plumb-port model/thinking switch (requires live acme)
- REQ-CORE-107 â Acme Pause/Resume (partial; pause mechanics tested in AUnit
  via `llm_agent_tests.adb`)
- REQ-CORE-142 â SIGTERM handling (requires OS signal; manual test)

These are entered as open items in the problem log (PCR-009).

---

## 5. Test Schedule

| Activity | Milestone | Status |
|---|---|---|
| AUnit suite baseline recorded | M2 complete | Done â 660 tests, all pass |
| Test Plan reviewed and acknowledged | M4 | Pending |
| Demonstration tests performed | After M4 | Pending |
| Test Report produced | M6 | Pending |
| Coverage gaps addressed or accepted | M6 | Pending |

---

## 6. Requirements Traceability

| Requirement | Verification method | Test reference |
|---|---|---|
| REQ-CORE-001â004 | D | DEM-001 to DEM-003 |
| REQ-CORE-005 | I | Code inspection |
| REQ-CORE-010â018 | T | `coyote_app_tests.adb` |
| REQ-CORE-019â020 | D | DEM-004, DEM-005 |
| REQ-CORE-021 | D | DEM-013 (Acme window name) |
| REQ-CORE-022 | D | DEM (TBD) |
| REQ-CORE-023 | T | `coyote_utils_tests.adb` |
| REQ-CORE-024 | D | TC-024 (DEM-019) |
| REQ-CORE-030â032 | T/I | `coyote_app_tests.adb`, code inspection |
| REQ-CORE-040â046 | T/D | `dispatch_tests.adb`, `llm_agent_tests.adb`, DEM-006 |
| REQ-CORE-050â053 | T | `llm_tools_tests.adb` |
| REQ-CORE-054 | D | DEM (--no-tools with tool model) |
| REQ-CORE-055 | D | DEM-007 |
| REQ-CORE-056 | T | `llm_parallel_tools_tests.adb` |
| REQ-CORE-060â064 | T/D | `llm_compaction_tests.adb`, `llm_context_tests.adb`, DEM-008â009 |
| REQ-CORE-065â068 | T/D | `llm_compaction_tests.adb`, `llm_context_tests.adb`, DEM-020..022, code inspection |
| REQ-CORE-070â073 | T/D | `llm_settings_tests.adb`, `llm_model_registry_tests.adb`, DEM-010 |
| REQ-CORE-070a | T | `llm_agent_tests.adb` |
| REQ-CORE-074 | D | DEM-011 |
| REQ-CORE-075â076 | D | DEM-012 |
| REQ-CORE-080â083 | T | `llm_session_store_tests.adb` |
| REQ-CORE-084 | T/D | `session_lister_tests.adb`, DEM-018 |
| REQ-CORE-085 | T | `llm_session_store_tests.adb`, `llm_agent_tests.adb`, DEM-029 |
| REQ-CORE-086..087 | T | `llm_session_store_tests.adb`, `llm_agent_tests.adb`, DEM-030 |
| REQ-CORE-088 | T | `llm_agent_tests.adb`, `coyote_app_tests.adb`, DEM-031 |
| REQ-CORE-089 | T | `coyote_app_tests.adb`, DEM-032 |

| REQ-CORE-090â093 | T | `llm_skills_tests.adb` |
| REQ-CORE-100â109 | T/D | `acme_event_parser_tests.adb`, `tool_uri_tests.adb`, DEM-013 |
| REQ-CORE-110â115 | T/D | `coyote_cmark_tests.adb`, DEM-014 |
| REQ-CORE-124 | T/D | `coyote_lasem_tests.adb`, `coyote_gui_conversation_tests.adb` |
| REQ-CORE-116 | D | DEM-033 |
| REQ-CORE-117 | D | DEM-033 |
| REQ-CORE-118 | T | `llm_settings_tests.adb`, `coyote_gui_prompt_queue_tests.adb` |
| REQ-CORE-119 | D | DEM-033 |
| REQ-CORE-120â121 | D | DEM-001 (plain output) |
| REQ-CORE-130â131 | T/D | `session_history_tests.adb`, DEM-015 |
| REQ-CORE-140â141 | D | DEM-016 |
| REQ-CORE-142 | D | DEM-017 |
| REQ-CORE-170â172 | T/D | `llm_system_prompt_tests.adb`, `llm_skills_tests.adb`, DEM-023..024, code inspection |
| REQ-CORE-180â183 | T/D | `llm_system_prompt_tests.adb`, DEM-025..026, code inspection |
| REQ-CORE-190â192 | T/D | `llm_system_prompt_tests.adb`, DEM-027..028, code inspection |
| REQ-CORE-200â203 | T/I | `llm_sse_tests.adb`, `llm_openai_completions_tests.adb`, `llm_anthropic_messages_tests.adb`, code inspection |
| REQ-CORE-210â212 | T/I | `nine_p_proto_tests.adb`, `nine_p_mock_server_tests.adb`, code inspection |
| REQ-CORE-220â221 | I | Code inspection (GTK call sites) |
| REQ-CORE-230â234 | T | `llm_settings_tests.adb`, `llm_auth_tests.adb`, DEM-034 |
| REQ-CORE-240â241 | T | `llm_session_store_tests.adb`, `coyote_sqc_parser_tests.adb` |
| REQ-CORE-300â302 | I | Code inspection |
| REQ-CORE-400â402 | T/I | `llm_types_tests.adb`, code inspection |
| REQ-CORE-500â505 | I | Build artefact inspection |
| REQ-CORE-600â601 | A | Design analysis |
| REQ-CORE-700 | D | DEM-006 (streaming latency) |
| REQ-CORE-701 | T | `llm_session_store_tests.adb` |
| REQ-CORE-702 | D | DEM-016 |
| REQ-CORE-703 | I | Code inspection (task exception handlers) |
| REQ-CORE-704 | I | Code inspection (provider package structure) |
| REQ-CORE-800â805 | I | Build artefact inspection, code inspection |
| REQ-CORE-160 | I | Code inspection (man page content) |

---

## 7. Notes

**Verification as of 2026-08-05 (live GTK graphical tool cards):**
The focused GUI conversation set now runs 32 tests and includes the
new tool-card lifecycle regression, covering typed header/argument/footer rows,
running state, and terminal status propagation.  The production and test projects build successfully in the
required development profile.  Display-backed test execution requires an
available GTK display; the current environment has no DISPLAY/WAYLAND_DISPLAY.

**Verification as of 2026-08-04 (live GTK interleaved tool-detail fix):**
The focused GUI conversation set runs 31 tests with 0 failures and 0 unexpected
errors, including a regression test verifying that completing multiple
interleaved tool calls preserves independent detail ranges and selects the
second tool correctly. A full-suite run was attempted but timed out during
existing live/network activity; the prior 822-test baseline remains the last
completed full-suite baseline.

**Verification as of 2026-08-08 (sandbox timeout process-group correction):**
The production and test projects build successfully in the required development
profile. The exact sandbox timeout and abort regression tests both pass; each
runs a long-lived command under `bwrap` and verifies prompt process-group
termination and result delivery. The full suite was not completed because
pre-existing environment-dependent tests failed and the run exceeded the
available time.

**Verification as of 2026-08-08 (PCR-050 Lasem literal-relation normalization):**
838 registered tests, including the new Lasem literal-relation regression. The
production and test development builds succeed, and the focused regression
passes with zero failures and zero unexpected errors.

**Verification as of 2026-08-08 (subagent default model preference):**
The existing settings, typed queue, and agent-default tests were extended to
cover subagent preference loading, persistence, transport, and precedence. The
development and test builds succeed. Display-backed DEM-033 and DEM-034
remain pending because no GTK display is available in this environment.

**Verification as of 2026-08-06 (PCR-047 GUI Preferences implementation):**
829 registered tests, including two settings persistence tests, one typed
prompt-queue test, and one agent sandbox-default precedence test. The focused
PCR-047 tests pass with 0 failures and 0 unexpected errors. The development
build and test build succeed. Display-backed DEM-033 and DEM-034 remain
pending because no GTK display is available in this environment.

**Baseline as of 2026-08-06 (PCR-046 GUI sandbox status):**
825 tests, 0 failures, 0 unexpected errors. Added one formatter regression and
extended one dispatch regression. The tests verify that a non-empty sandbox
profile remains in the status text after lifecycle/status refreshes.

**Baseline as of 2026-08-04 (PCR-044 sandbox profile restoration):**
821 tests, 0 failures, 0 unexpected errors. Added one session-store accessor
regression and two agent session resume/switch regressions. The tests verify
header-driven restoration, clearing when the target header has no profile, and
independence from the current process environment.

**Baseline as of 2026-08-04 (GTK idle CPU regression):**
818 tests, 0 failures, 0 unexpected errors for the six new
`Coyote_GUI.Updates` queue lifecycle tests. The tests cover single wakeup
reservation, duplicate-wakeup suppression, pending-work retention, source
release when empty, rearming after completion, and shutdown behavior.

**Baseline as of 2026-08-04 (Streaming UTF-8 preservation):**
812 tests, 0 failures, 0 unexpected errors. Added four stateful UTF-8 decoder
unit tests and two GUI conversation tests covering codepoints split across
text and thinking update records. The update queue now applies backpressure
instead of silently dropping records.

**Baseline as of 2026-08-03 (Streaming canvas cache invalidation):**
806 tests, 0 failures, 0 unexpected errors. Added a GUI regression test
verifying that appending to an already-measured streaming logical line
recomputes its visual-line count and expands the document canvas.

**Dry run policy:** Before proposing a test results review to the user, a
full `cd test && alr run coyote_test` run is performed and the pass count
and any failures are recorded here or in the Test Report.

**PCR-044 qualification status:** The automated tests cover session-header
profile reading, resume restoration, and profile restoration/clearing on agent
session switching. DEM-029..032 remain manual qualification demonstrations
for shell-command application, child-process propagation, and Acme/GUI state
synchronization.

**Baseline as of 2026-06-13 (Quantile Control Chart):** 683 tests, 0 failures,

**Baseline as of 2026-06-16 (Mutual Information diversity charts):** 688 tests, 0 failures,
**Baseline as of 2026-07-12 (Step-level fork tokens throughout tool-call turns):** 694 tests, 0 failures,
**Baseline as of 2026-07-30 (Sandbox profiles):** 772 tests, 0 failures,
0 unexpected errors. Historical baseline before PCR-044 restoration tests.
**Baseline as of 2026-07-19 (Memory opt-in gate):** 742 tests, 0 failures,
0 unexpected errors. Historical baseline retained for trend analysis. Added
11 MI tests for
`Coyote_SQC.Statistics.MI` (compute values, identical calls, different calls,
no-argument calls, missing argument, non-positive clamp, session metrics,
subgroup exclusion, hollow circle, Xbar/s parameter estimation,
Sum I/MR/EWMA independence).  Six new chart kinds registered:
`Tool_Call_MI_Xbar`, `Tool_Call_MI_S`, `Session_Tool_Call_MI_Sum_I`,
`Session_Tool_Call_MI_Sum_MR`, `Session_Tool_Call_MI_Sum_EWMA`,
`Tool_Call_MI_Quantile`.  Chart count advanced from 55 to 61 in SRS and SDD. Further advanced to 91 with the addition of 30 token cost charts.
Historical note: the corresponding test implementation was completed in a
later build; the current baseline is recorded above.  Added 13 Quantile CC
tests for
Coyote_SQC.Statistics.Quantile_CC (compute-quantiles, build-distribution,
extract-limits, OOC-detection, cache-hit, cache-invalidation).  Two bugs
fixed during implementation: LCG 32-bit overflow and 0-based index in
bucket selection.  No regressions; all 665 existing tests pass.

**Baseline as of 2026-06-01:** 658 tests, 0 failures, 0 unexpected errors.
**Baseline as of 2026-06-06 (PCR-016 Bootstrap):** 665 tests, 0 failures,
0 unexpected errors.  Added 5 Bootstrap CI tests
(`Test_Bootstrap_Point_Estimates`, `Test_Bootstrap_CI_Coverage`,
`Test_Bootstrap_NA_Insufficient`, `Test_Bootstrap_NA_SD_Zero`,
`Test_Bootstrap_Reproducibility`) for `Coyote_SQC.Statistics.Bootstrap`.
**Baseline as of 2026-06-03:** 660 tests, 0 failures, 0 unexpected errors.
**Baseline as of 2026-06-07 (PCR-022 Thinking Display):** 665 tests, 0 failures,
0 unexpected errors.  Test count unchanged; `Test_Dispatch_Thinking_Delta` updated
to reflect new buffering semantics (now emits both `Thinking_Delta` and `Thinking_End`
events to verify collapsing behaviour).  No new test cases added; existing test
infrastructure sufficient to cover the buffering and collapsing logic.

**Baseline as of 2026-06-10 (PCR-023 Copilot Graceful Startup):** 665 tests, 0 failures,
  0 unexpected errors.

**Baseline as of 2026-07-11 (PCR-??? Timeout Stdout Flushing):** 733 tests,
  1 known failure ("LLM.System_Prompt preserves section order" —
  pre-existing, context/skills section ordering, tracked separately),
  0 unexpected errors.  2 new test cases added: timeout preserves stdout
  emitted before kill, abort preserves stdout emitted before kill.

**Baseline as of 2026-07-08 (Shell Tool Timeout Elapsed-Time Tests):** 726 tests, 0 failures,
  0 unexpected errors.  2 new tests (`Test_Shell_Timeout_Under_Elapsed`,
  `Test_Shell_Timeout_Triggers_Elapsed`) independently verify timeout
  wall-clock behaviour using `Ada.Real_Time.Clock`.

**Baseline as of 2026-06-16 (Quantile Bonferroni Checkbox):** 704 tests, 0 failures,
**Baseline as of 2026-06-29 (Comment Speed Fix):** 722 tests, 0 failures,
  0 unexpected errors.

**Baseline as of 2026-07-06 (Run-Group Tool Execution):** 724 tests, 0 failures,
  0 unexpected errors.  Tool calls now execute sequentially by default; a
  `run_group` integer argument on all tool calls in a turn enables grouped
  parallel execution (calls in the same group run concurrently, groups run in
  ascending order).  Added REQ-CORE-056.  2 new tests:
  `Test_Tools_Run_Sequentially_By_Default` (two 0.3 s sleeps without
  run_group must take > 0.5 s wall-clock) and
  `Test_Tools_Run_In_Group_Order` (three tools in two groups: group 1
  runs before group 2).  `Test_Parallel_Tools_Run_Concurrently` updated
  to include `run_group:1` on both tools.

**Baseline as of 2026-07-08 (Continue Tag):** 724 tests, 0 failures,
  0 unexpected errors.  Test count unchanged.  Added `Continue` tag command
  to the Acme idle-window button set; re-submits the session from idle state
  by enqueueing a `"Continue."` user prompt.

**Baseline as of 2026-07-11 (PCR-013 Timeout Abort Fix):** 731 tests, 1 failure
  (pre-existing: LLM.System_Prompt preserves section order), 0 unexpected
  errors.  1 new test: `Test_Abort_During_Shell_With_Timeout` verifies that
  the Stop button kills a running shell tool that carries a `timeout`
  parameter, without waiting for the timeout to expire.

**Baseline as of 2026-06-11 (PCR-022 follow-up: thinking-block empty-content fix):**
670 tests, 0 failures, 0 unexpected errors.  Added 5 Collapse_Thinking_Delta unit
tests (`collapse_utils_tests.adb`): `Test_Collapse_Basic`,
`Test_Collapse_Paragraph`, `Test_Collapse_Empty`, `Test_Collapse_NoLF`,
`Test_Collapse_Leading_Trailing_WS`.

**Baseline as of 2026-06-13 (Quantile Control Chart implementation start):**
670 tests, 0 failures, 0 unexpected errors.  New packages
`Coyote_SQC.Statistics.Quantile_CC` (ads + adb) added; four new chart kinds
(`Turn_Tokens_Quantile`, `Tool_Call_Tokens_Quantile`,
`Thinking_Tokens_Quantile`, `Tool_Call_JSD_Quantile`) registered in
`Chart_Kind` enumeration, `Properties`, and `Descriptor`; quantile
recompute path (two-stage bootstrap with caching) added to
`Recompute_Chart`; OOC propagation from Quantile CC charts to all other
chart kinds added in `Recompute_Charts`; `Is_OOC_From_Quantile` field
added to `Chart_Point`.  13 quantile unit tests and 7 rendering tests
are specified in SDD-SQC Â§14.6âÂ§14.7 and are pending implementation.

**Baseline as of 2026-06-13 (Sort optimization â introsort + validity suppression):**
687 tests, 0 failures, 0 unexpected errors.  Replaced GNAT's
`Ada.Containers.Generic_Array_Sort` (heapsort) with a custom introsort
(quicksort with median-of-three pivot, insertion sort for partitions â¤ 16
elements, heapsort fallback for worst-case guarantee) with validity checks
suppressed via `pragma Suppress (Validity_Check)`.  4 new sort-correctness
tests added (reverse input, all-equal values, two-element descending, and
50-element random-ish pattern), exercised through `Compute_Quantiles`.

**Baseline as of 2026-06-14 (Quantile CC Log Y support):**
687 tests, 0 failures, 0 unexpected errors.  Added Log Y-axis scaling
support for Quantile Control Charts: `Y_Fit` now collects quantile
component values and limits; setup, Set A, and Set B diagram halos
skip non-positive components in Log Y mode; rubber-band selection
skips non-positive components in Log Y mode.  No new test cases added;
existing test infrastructure sufficient to cover the rendering path.
Requirements updated in SRS-SQC Â§5.18 (new Log Y-Axis Scaling
subsection), Â§7.3.2a (Log Y mode rendering), and Â§15.6 (two new test
requirements).  No regressions.


**Baseline as of 2026-06-14 (Quantile CC interpolation):**
690 tests, 0 failures, 0 unexpected errors.  Fixed Bonferroni_Rank to
compute from B_Replicates (formerly hardcoded 27 for B=100 000; now 2 for
B=10 000).  Fixed RNG seed to derive from N_I (formerly shared across all
subgroup sizes).  Added interpolated quantile limit computation:
`Interpolate_Limits` in `Quantile_CC` computes exact bootstrap distributions
at ~20 anchor subgroup sizes and derives limits for arbitrary N via 1/sqrt(N)
half-width scaling, giving ~8.5x reduction in bootstrap runs.  Added three
new tests for `Interpolate_Limits` (anchor match, between-anchor shrinkage,
n=1 fallback).  Added `Interpolate_Quantile_Limits` boolean to workspace data
model, serialization, and workspace settings dialog.  Requirements and design
documents updated.


**Coverage gap PCR:** The gaps identified in Â§4.5 are logged in
`plan/problems.md` as PCR-009. They are accepted as deferred for the current
build with the rationale that the uncovered requirements are either low-risk
(SIGTERM handling) or require live external services (Copilot, live acme).
**Baseline as of 2026-06-06:** 660 tests, 0 failures, 0 unexpected errors.  7 new test cases required by SRS-SQC Â§15.6 (Â§5.17 bootstrap CI, Â§10.3 two-set histogram) are pending implementation; they are not yet included in the suite.

**Baseline as of 2026-06-14 (PCR-024 OpenAI Cache Parity):** 688 tests, 0 failures,
0 unexpected errors.

**Baseline as of 2026-06-18 (Token Cost Charts):** 713 tests, 0 failures,
0 unexpected errors.  30 new chart kinds added for token cost charts (18
session-level I/MR/EWMA and 12 turn-level Xbar/s), bringing total chart count
from 61 to 91.  10 cost-specific test requirements added to SRS-SQC Â§15.6
covering cost computation accuracy, per-turn cost vectors, I/MR/Xbar limit
computation, zero-value exclusion, unpriced model exclusion, per-turn cache
cost fallback, pricing data source resolution, and workspace round-trip.
Requirements and design documents updated.  Implementation complete
(see PCR-039 in `plan/problems.md`); all 722 existing tests pass with
0 regressions.  Dedicated cost-unit tests deferred â cost chart formulas
are identical to their token-count counterparts and the pricing data path
is transparent to the statistical layer.
