# Test Plan â coyote (STP)

**Version:** 1.26
**Date:** 2026-08-31

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
| libnotify4 + notification daemon | GTK completion notifications | 0.8.3-compatible |
| Computer Modern math fonts | Lasem glyph coverage | cmr10/cmmi10/cmex10/cmsy10 |
| GNATCOLL | JSON processing | â¥ 25.0.0 (via Alire) |

### 3.3 Test Infrastructure

**AUnit automated tests:** `test/src/` contains the full AUnit suite.
The suite is self-contained except for GTK widget tests, which require GTK3
and a display or `xvfb-run`. Non-GUI tests run without a live display or external desktop service.
live LLM provider, or display. Fixtures are in `test/fixtures/`.

**Integration tests:** Tests in the following files require a live environment
and are **opt-in** (guarded by environment variable checks at test startup):

| Test file | Guard variable | Requires |
|---|---|---|
| `llm_github_copilot_tests.adb` | `COYOTE_TEST_COPILOT=1` | Valid Copilot credentials |
| `llm_anthropic_messages_tests.adb` | `COYOTE_TEST_ANTHROPIC=1` | Valid Anthropic API key |
| `llm_agent_tests.adb` (live tests) | `COYOTE_TEST_LIVE=1` | Any live provider |

See `plan/integration-test-guide.md` for full setup instructions.

### 3.4 Known Test Environment Constraints
- GUI conversation coverage targets the qualified
  `Coyote_GUI.Conversation_Stack` implementation with GTK3 and a display (or
  `xvfb-run`). The native tests cover one outer scroller, exchange and step
  widgets, Markdown, MathML, selection, tool flow, lifecycle, reset, and zoom.
  Display-backed native qualification is complete.
- The obsolete `Coyote_GUI.Buffer` unit and legacy conversation renderer were
  removed. Plain frontend tests remain independent and headless where applicable.
Headless `GtkTextBuffer` tests, when present, do not require a display.
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
| `llm_session_store_tests.adb` | REQ-CORE-080â089, 217, 240â241 | ~47 |
| `llm_agent_tests.adb` | REQ-CORE-040â046, 060â064, 075, 085â089, 217, 219 | ~88 |
| `coyote_app_tests.adb` | REQ-CORE-085â089 (frontend/agent synchronization) | ~10 |

| `llm_skills_tests.adb` | REQ-CORE-090, 090a, 091â094 | ~22; configured roots, malformed entries, and shadowing |
| `llm_settings_tests.adb` | REQ-CORE-025, 090a, 230â234, 070â073; skillPaths loading and Save_Preferences persistence | ~29 |
| `subagent_integration_tests.adb` | REQ-CORE-025, 019–020; subprocess startup, one-shot, and steering behavior | 4 |
| Coordinator/RPC implementation tests | REQ-CORE-020a–020c, 115, 115a; registry hierarchy/selection, runtime identity transport, versioned codec, Unix transport, service command/disconnect routing | Focused tests pass; DEM-050..053 remain for GUI/display and real-provider end-to-end qualification |
| `coyote_gui_prompt_queue_tests.adb` | REQ-CORE-116â119; typed preference and skill-path payload, acceptance, and overflow transport | 3 |
| `coyote_gui_navigation_tests.adb` | REQ-CORE-114; clamped keyboard viewport navigation | 3 |
| `llm_auth_tests.adb` | REQ-CORE-232 | ~15 |
| `llm_compaction_tests.adb` | REQ-CORE-060â064 | ~30 |
| `llm_tools_tests.adb` | REQ-CORE-050â053, 057 | ~27; timeout TERM/grace/KILL escalation |
| `llm_system_prompt_tests.adb` | REQ-CORE-090â092, REQ-CORE-173 (display and inline math guidance) | ~11 |
| `llm_types_tests.adb` | REQ-CORE-400â402 | ~20 |
| `llm_parallel_tools_tests.adb` | REQ-CORE-056 (run_group) | ~15 |

| `sandbox_tests.adb` | Sandbox profile subsystem, including timeout and abort process-group termination | 24 |
| `llm_context_tests.adb` | REQ-CORE-060 (compaction threshold) | ~15 |
| `coyote_app_tests.adb` | REQ-CORE-010â023 (CLI parsing) | ~30 |
| `coyote_utils_tests.adb` | REQ-CORE-023 | ~10 |
| `collapse_utils_tests.adb` | REQ-CORE-023 (thinking collapse) | 5 |
| `llm_model_registry_tests.adb` | REQ-CORE-070â071 | ~15 |
| `llm_catalogue_tests.adb` | REQ-CORE-072 | ~10 |
| `llm_http_tests.adb` | REQ-CORE-200 (HTTP streaming) | ~20 |
| `llm_openai_completions_tests.adb` | REQ-CORE-201 | ~30 |
| `llm_anthropic_messages_tests.adb` | REQ-CORE-202 | ~30 |
| `llm_openrouter_tests.adb` | REQ-CORE-072, REQ-CORE-216, REQ-CORE-218, REQ-CORE-219 (OpenRouter) | ~17 |
| `coyote_cmark_tests.adb` | REQ-CORE-111 (Markdown rendering), table metadata/masking, parser-safe display-math code-block protection | ~30 |
| `coyote_lasem_tests.adb` | Lasem Presentation MathML measurement, zoom scaling, relation entities, and error handling | 5 |
| `coyote_gui_conversation_stack_tests.adb` | Native display MathML and Markdown table realization, invalid fallback, code protection, toggle, alignment, and zoom | 19 |
| `llm_session_store_tests.adb` | Session-store header/accessor coverage, including local session creation timestamp | ~48 |
| `coyote_gui_zoom_tests.adb` | REQ-CORE-125 (zoom arithmetic: clamping, step semantics) | 12 |
| `coyote_gui_notification_policy_tests.adb` | REQ-CORE-127 (notification eligibility policy) | 4 |
| `coyote_gui_mode_tests.adb` | REQ-CORE-113 Agent-menu availability by run mode | 1 |
| `coyote_gui_session_stats_window_tests.adb` | REQ-CORE-113d; typed snapshot retention, reset, and idempotent support-window creation | 3 |
| `coyote_gui_conversation_stack_tests.adb` | REQ-CORE-111, 133..139; native stack host, visible per-step frames, responsive per-step tool-card flow, incremental text, native GFM Markdown replacement, Markdown toggle, stable tool IDs, native status-row footers, functional fork buttons, explicit completion lifecycle, and reset | 13 |

| `coyote_gui_prompt_queue_tests.adb` | REQ-CORE-116..119, 128; typed preference payload transport | 1 |
| `coyote_help_tests.adb` | REQ-CORE-113a, REQ-CORE-504a; Yelp URI construction, area mapping, executable detection, Help data path, and Product Information text | 5 |
| `session_lister_tests.adb` | REQ-CORE-084 | ~10 |
| `coyote_sqc_parser_tests.adb` | REQ-CORE-240â241 | ~25 |
| `coyote_sqc_statistics_tests.adb` | SRS-SQC statistics | ~40 |
| `coyote_sqc_workspace_tests.adb` | SRS-SQC workspace | ~20 |
| `coyote_sqc_integrity_tests.adb` | SRS-SQC integrity | ~15 |
| `coyote_sqc_jsd_tests.adb` | SRS-SQC JSD metrics | ~20 |
| `coyote_sqc_mi_tests.adb` | SRS-SQC MI metrics | ~11 |
| `coyote_sqc_histogram_tests.adb` | SRS-SQC histogram | ~10 |
| `coyote_sqc_bootstrap_tests.adb` | SRS-SQC Â§5.17 bootstrap CI, Â§10.3 two-set histogram bins | ~7 |

**Total automated tests (current):** **810**

### 4.3 Planned Tests â Demonstration

Requirements verified by demonstration (method D) are listed below. Each
is performed manually by running the application and observing the stated
behaviour. Results are recorded in a Test Report.

| Test ID | Requirement | Procedure |
|---|---|---|
| DEM-001 | REQ-CORE-001 | Run `coyote --one-shot --prompt "hello"`; verify the Plain frontend is used and the single JSON result is printed to stdout |
| DEM-003 | REQ-CORE-003 | Run coyote with `$DISPLAY` or `$WAYLAND_DISPLAY` set; verify the GUI window opens |
| DEM-004 | REQ-CORE-019 | `coyote --one-shot --prompt "echo hello"` exits after one turn; check exit code 0 and JSON on stdout |
| DEM-005 | REQ-CORE-020 | `coyote --subagent --prompt "hello"` retains one-shot behavior, accepts steering while active, and exits after its final response; without a coordinator channel it uses Plain |
| DEM-045 | REQ-CORE-025 | Set `maxRecursionDepth` to 1; invoke coyote with inherited `COYOTE_RECURSION_DEPTH=1` and `--subagent`; verify it exits non-zero before opening a frontend and reports the limit on stderr |
| DEM-046 | REQ-CORE-111, 125 | In the display-backed GTK GUI, render a fixture containing headings, inline formatting, code, lists, tables, links, strikethrough, and a thematic break. Verify conversion occurs after streaming; GFM tables become native grids with selectable cells, bold headers, and column alignment; local selection exposes plain text; the Render Markdown toggle preserves source text when disabled; and zoom changes native response font size. Native-table execution remains pending virtual-display qualification. |
| DEM-047 | REQ-CORE-111, 131, 137 | Render the same Markdown response live and by session replay in the native GUI. Verify equivalent supported visible content and response-block boundaries, and verify the GUI replay preserves the same semantic blocks. |
| DEM-048 | REQ-CORE-124 | In the display-backed GTK GUI, exercise valid and invalid standalone Presentation MathML blocks. Verify native realization, readable source/fallback on parse failure, local selection, and zoom. Automated native realization, fallback, code-protection, zoom, visual, and local-selection acceptance is complete. |
| DEM-049 | REQ-CORE-110, 113b | In a display-backed GUI, verify that the conversation work area, prompt controls, and status area are separated by visible horizontal rules; verify the prompt and status areas have consistent breathing room and that the conversation remains the sole expanding region. The structural portion is covered by `Coyote.GUI separates conversation, prompt, and status`; visual contrast remains a manual check under the active theme. |
| DEM-006 | REQ-CORE-040â044 | Start a GUI session; send a prompt; verify streaming text, thinking, tool events, and stats appear |
| DEM-007 | REQ-CORE-055 | Start a long tool execution; press Stop; verify tool is cancelled and agent exits cleanly |
| DEM-008 | REQ-CORE-060 | Configure a small context window; send prompts until threshold reached; verify auto-compaction notice appears |
| DEM-009 | REQ-CORE-061 | Trigger manual compact in the GUI (`:compact` command or menu); verify the compaction summary appears |
| DEM-010 | REQ-CORE-070 | Set defaultModel in settings.json; start coyote without --model; verify correct model used |
| DEM-011 | REQ-CORE-074 | Use an expired Copilot token; send a prompt; verify token is refreshed and request succeeds |
| DEM-014 | REQ-CORE-110â115, 125, 132 | In a display-backed GUI, verify Markdown/tool presentation, conversation vi navigation only when a conversation text view has focus (`j`, `k`, `g`, `G`/Shift+`g`, Ctrl+D, Ctrl+U), native wheel scrolling, prompt Return/Ctrl+Return/Shift+Return behavior, focused Edit actions, visible primary accelerators, menu mnemonics, and Ctrl+wheel zoom. Record that current automated navigation tests cover only clamped movement arithmetic; GTK event routing remains manual. |
| DEM-033 | REQ-CORE-116..117, 119, 090a | Open GUI Preferences, verify Default model initial focus, Save as the default response, Escape cancellation, label mnemonics, ordinary and subagent model/thinking/sandbox defaults, recursion depth, termination grace, notifications, price display, and ordered additional skill directories. Verify Add Directory uses a folder chooser, Remove Selected and Move Up/Down change the list, saved paths persist in `skillPaths`, the active session is unchanged, and new sessions inherit the paths. |
| DEM-035 | REQ-CORE-126..128 | Toggle desktop completion notifications in GUI Preferences; verify an unfocused ordinary GUI turn notifies, a focused turn does not, the setting persists, and subagent/one-shot runs remain silent |
| DEM-036 | REQ-CORE-113a..113c | Exercise the GUI menu bar and support windows: verify top-level order `File`, `Edit`, `View`, `Agent`, `Options`, `Help`; activate Overview, Keys & Shortcuts, and Product Information; verify application-prefixed titles for in-process support windows, the prominent coyote application icon above the Product Information name/version/license text, Yelp ownership for Overview/Keys topics, an in-process Product Information dialog, dialog button order, and lifecycle status in the status area rather than the title |
| DEM-037 | REQ-CORE-113a..113b | In a display-backed GUI, press F1 and verify Overview opens; press Shift+F1 and verify the pointer becomes a question mark; click the conversation canvas and verify contextual help opens without activating the clicked control; select and extend conversation text, verify PRIMARY changes independently of CLIPBOARD; middle-click in the prompt and verify PRIMARY text is inserted at the pointer without selecting the result |
| DEM-038 | REQ-CORE-113a, 113b, 115 | In a display-backed GUI, use Help → Click for Help and click one widget in each main area (menu item, prompt, Send/Stop, status, conversation). Verify a contextual Help window opens, the selected action is not activated, Escape cancels the armed mode, the window role changes to `coyote-session-<UUID>` after session bootstrap/switch, and the launcher/icon identity is `coyote`. |
| DEM-039 | REQ-CORE-113a, REQ-CORE-504a | In a display-backed GUI, activate Overview, task entries, Index, and Keys & Shortcuts and verify Yelp opens the corresponding `help:coyote` or `help:coyote/<topic>` document. Verify Product Information opens an in-process dialog that remains available when Yelp is missing. Verify Mallard navigation, Index links, task links, contextual area topics, and the visible error notice when Yelp is unavailable. |
| DEM-040 | REQ-CORE-113d | In a display-backed GUI, open Session Stats repeatedly and verify only one modeless transient `coyote : Session Stats` support window exists. Verify grouped selectable values, system-font sizing, scrollable report area, visible Close, Ctrl+W, live refresh after a completed turn, and clearing after New Session and session switch. |
| DEM-041 | REQ-CORE-113e | In a display-backed GUI, click completed tool cards and verify each opens an independent `coyote : Tool Call Details` transient support window. Verify selectable header metadata, labelled monospace argument views, full selectable results, outer vertical scrolling, visible Close and Help actions, deterministic focus, Ctrl+W, non-color status meaning, image display/fallback, light/dark theme behavior, replay parity, and correct multi-window independence. |
| DEM-042 | REQ-CORE-133..134, 139 | In a display-backed GUI using the native component-stack build, submit a request that produces thinking, assistant text, a tool call, and a final response. Verify one exchange container and one visible step frame are created, each semantic component is a separate native widget, the tool card contains native tool-name and status labels plus individually selectable top-level argument-field labels, raw arguments and full results are absent, the `View Details` button is focusable and opens `coyote : Tool Call Details` after completion, and the request-start, step-footer, final-footer, and terminal lifecycle transitions are explicit. |
| DEM-043 | REQ-CORE-135..137 | In a display-backed GUI using the native component-stack build, submit requests with multiple tool steps and replay the resulting session. Verify exchange widgets are vertically ordered in one outer scroller, each assistant/tool step has a distinct visible frame, intermediate footers remain inside their step frame and exchange, native label/grid summaries are live/replay equivalent, cards update by stable tool-call ID without exposing raw arguments or full results, the `View Details` button opens the correct retained payload, local component selection/copy/PRIMARY works independently for separate components, and clear/session switching removes stale widgets and callbacks. For a step with multiple tool calls, verify cards share a horizontal flow host, occupy multiple columns when space permits, and wrap onto additional rows after narrowing the window. |
| DEM-044 | REQ-CORE-138 | On a development build using the native component stack, qualify first-token latency, widget count, memory, resize, zoom, auto-scroll, replay, and repeated reset behavior, and `View Details`-button activation for histories of 100, 500, and 2,000 exchanges. Confirm that compact tool cards do not create argument/result text widgets per call. Record the native measurements and retain the regression evidence as the production baseline. |
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
| TC-174 | REQ-CORE-174 | Build the development and test projects; run system-prompt regressions; verify the executable-relative share/coyote resource is loaded, all markers are rendered, no-tools and capability branches remove/select the correct sections, and dynamic prompt sections remain present. |
| DEM-025 | REQ-CORE-180..181 | Create a MEMORY.md file in ~/.coyote/memory/; start coyote; verify the memory content appears in the system prompt and the taxonomy is described |
| DEM-026 | REQ-CORE-183 | Run a session; direct the agent to save a memory; verify a new topic file is created and MEMORY.md index is updated |
| DEM-027 | REQ-CORE-190..191 | Run a session using subagents; verify the system prompt contains coordinator instructions and subagent results include structured summary blocks |
| DEM-028 | REQ-CORE-192 | During a subagent run, ask the coordinator about the in-flight subagent; verify the coordinator reports status without fabricating results |
| DEM-029 | REQ-CORE-085 | Create a session with a sandbox profile, exit, resume it with `--session UUID`, and verify the profile is restored and applied to shell commands |
| DEM-030 | REQ-CORE-086..087 | In one running frontend, switch between sessions with different and absent sandbox profiles; verify restoration and clearing before the next tool call |
| DEM-031 | REQ-CORE-088 | Set a sandbox profile, spawn a child coyote process, and verify the child receives the profile and applies it to a shell command |
| DEM-032 | REQ-CORE-089 | Exercise startup, profile change, resume, and switch in the GUI; verify displayed, agent, and propagated profile values remain identical |

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
- REQ-CORE-142 â SIGTERM handling (requires OS signal; manual test)

The native Markdown, MathML, live/replay, local-selection, responsive-flow,
and large-history qualification gates were accepted on 2026-08-31. Remaining
coverage gaps are limited to the unrelated filesystem, live-provider, signal,
and preferences demonstrations listed above.

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
| REQ-CORE-025 | T/D | `subagent_integration_tests.adb`, `llm_settings_tests.adb`, DEM-045 |
| REQ-CORE-020a..020c, 115, 115a | D/T/I | Registry, codec, transport, and service focused tests; DEM-050..053 for GUI/display and real-provider end-to-end qualification; source inspection |
| REQ-CORE-021 | D | GUI window title label demonstration |
| REQ-CORE-022 | D | DEM (TBD) |
| REQ-CORE-023 | T | `coyote_utils_tests.adb` |
| REQ-CORE-024 | D | TC-024 (DEM-019) |
| REQ-CORE-030â032 | T/I | `coyote_app_tests.adb`, code inspection |
| REQ-CORE-219 | T/I | `llm_agent_tests.adb`, code inspection |
| REQ-CORE-040â046 | T/D | `llm_agent_tests.adb`, DEM-006 |
| REQ-CORE-050â053 | T | `llm_tools_tests.adb` |
| REQ-CORE-054 | D | DEM (--no-tools with tool model) |
| REQ-CORE-055 | D | DEM-007 |
| REQ-CORE-056 | T | `llm_parallel_tools_tests.adb` |
| REQ-CORE-057 | T | `llm_tools_tests.adb` (TERM-aware and escalation regressions) |
| REQ-CORE-060â064 | T/D | `llm_compaction_tests.adb`, `llm_context_tests.adb`, DEM-008â009 |
| REQ-CORE-065â068 | T/D | `llm_compaction_tests.adb`, `llm_context_tests.adb`, DEM-020..022, code inspection |
| REQ-CORE-070â073 | T/D | `llm_settings_tests.adb`, `llm_model_registry_tests.adb`, DEM-010 |
| REQ-CORE-070a | T | `llm_agent_tests.adb` |
| REQ-CORE-074 | D | DEM-011 |
| REQ-CORE-075â076 | Historical | Retired Acme/plumber controls; see PCR-090 |
| REQ-CORE-080â083 | T | `llm_session_store_tests.adb` |
| REQ-CORE-084 | T/D | `session_lister_tests.adb`, DEM-018 |
| REQ-CORE-085 | T | `llm_session_store_tests.adb`, `llm_agent_tests.adb`, DEM-029 |
| REQ-CORE-086..087 | T | `llm_session_store_tests.adb`, `llm_agent_tests.adb`, DEM-030 |
| REQ-CORE-088 | T | `llm_agent_tests.adb`, `coyote_app_tests.adb`, DEM-031 |
| REQ-CORE-089 | T | `coyote_app_tests.adb`, DEM-032 |

| REQ-CORE-090â093 | T | `llm_skills_tests.adb` |
| REQ-CORE-100â109 | Historical | Retired Acme/plumber controls; see PCR-090 |
| REQ-CORE-110â115 | T/D | `coyote_cmark_tests.adb`, `coyote_app_frontend_gui_tests.adb`, DEM-014, DEM-036..037, DEM-049 |
| REQ-CORE-111 | T/D | `coyote_cmark_tests.adb`, `coyote_gui_conversation_stack_tests.adb`, DEM-014, DEM-046..047; native table qualification pending |
| REQ-CORE-113a..113c | D/T/I | `coyote_help_tests.adb`, `coyote_gui_mode_tests.adb`, DEM-036..039, Mallard validation, source inspection |
| REQ-CORE-113d | D/T/I | `coyote_gui_session_stats_window_tests.adb`, DEM-040, source inspection |
| REQ-CORE-113e | D/T/I | `coyote_gui_conversation_stack_tests.adb`, `llm_session_store_tests.adb`, DEM-041..043, source inspection |
| REQ-CORE-133..139 | D/T/I/A | `coyote_gui_conversation_stack_tests.adb`, DEM-042..044, source inspection, performance analysis |
| REQ-CORE-504a | I/T | `coyote_help_tests.adb`, `yelp-check`, DEM-039 |
| REQ-CORE-125 | T/D | `coyote_gui_zoom_tests.adb`, DEM-014, DEM-046 |
| REQ-CORE-132 | D/T | `coyote_gui_navigation_tests.adb`, `coyote_gui_prompt_queue_tests.adb`, DEM-014 |
| REQ-CORE-124 | T/D | `coyote_lasem_tests.adb`, `coyote_gui_conversation_stack_tests.adb`, DEM-048 |
| REQ-CORE-116 | D | DEM-033 |
| REQ-CORE-117 | D/T | `llm_settings_tests.adb`, `coyote_gui_prompt_queue_tests.adb`, DEM-033 |
| REQ-CORE-118 | T | `llm_settings_tests.adb`, `coyote_gui_prompt_queue_tests.adb` |
| REQ-CORE-129 | T | `coyote_app_tests.adb`, DEM-033 |
| REQ-CORE-230 | T | `llm_settings_tests.adb` |
| REQ-CORE-119 | D | DEM-033 |
| REQ-CORE-120â121 | D | DEM-001 (plain output) |
| REQ-CORE-130â131 | T/D | `Coyote_App.History`, DEM-015 |
| REQ-CORE-140â141 | D | DEM-016 |
| REQ-CORE-142 | D | DEM-017 |
| REQ-CORE-170â173 | T/D | `llm_system_prompt_tests.adb`, `llm_skills_tests.adb`, DEM-023..024, code inspection |
| REQ-CORE-180â183 | T/D | `llm_system_prompt_tests.adb`, DEM-025..026, code inspection |
| REQ-CORE-190â192 | T/D | `llm_system_prompt_tests.adb`, DEM-027..028, code inspection |
| REQ-CORE-200â203 | T/I | `llm_sse_tests.adb`, `llm_openai_completions_tests.adb`, `llm_anthropic_messages_tests.adb`, code inspection |
| REQ-CORE-205â208, 215â217 | T/I | `llm_openai_responses_tests.adb`, `llm_agent_tests.adb`, `llm_session_store_tests.adb`, code inspection |
| REQ-CORE-210â212 | Historical | Retired 9P interface; see PCR-090 |
| REQ-CORE-220â221 | I | Code inspection (GTK call sites) |
| REQ-CORE-025, 230â234 | T | `llm_settings_tests.adb`, `subagent_integration_tests.adb`, `llm_auth_tests.adb`, DEM-034, DEM-045 |
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

**Verification as of 2026-08-22 (PCR-063/064 model-bound reasoning):**
Production and test development builds succeed. Three new tests cover
cross-model encrypted-thinking filtering with switch-back, legacy provenance
inference from `model_change`, and non-retryable HTTP 404 prompt rollback.
Existing same-model replay and explicit thinking-provenance round-trip tests
were strengthened. The complete 889-test suite passes with 889 successful
tests, 0 failed assertions, and 0 unexpected errors.

**Verification as of 2026-08-22 (PCR-062 GTK Change Model filter):**
Production and test development builds succeed. Eight new
`Model_Row_Matches` / `Format_Model_Picker_Count` unit tests pass
(empty/whitespace query, case-insensitive name/provider/spec substring,
non-match, and count wording). The suite now registers 886 tests. A
bounded full-suite run executed the new tests and the existing core
suite; it then hit pre-existing SQC parser/workspace fixture failures
and two `LLM.Auth` credential-file failures and timed out at five
minutes. Dialog wiring remains display-backed (DEM-033).

**Verification as of 2026-08-22 (PCR-065 OpenRouter Broadcast session tracking):**
The production and test development builds succeed. The focused OpenRouter
regression passes and verifies that a configured coyote session UUID is emitted
as the JSON `session_id` field while `/responses` remains stateless. The complete
891-test AUnit suite passes with 891 successful tests, 0 failed assertions, and
0 unexpected errors.

**Verification as of 2026-08-15 (PCR-059 OpenAI Responses):**
The sibling `LLM.Providers.OpenAI_Responses` adapter is implemented and
registered with 10 focused provider tests covering `/responses`,
`input`/`instructions`, flat tools, typed SSE text/reasoning/function-call
events, Responses usage fields, image output, encrypted reasoning replay,
HTTP errors, and stateless fields. Native `openai` dispatch and registry
fallback/catalogue entries are covered by two additional tests. OpenRouter
now delegates to Responses at `/api/v1/responses`; its four focused tests
cover headers/key fallback, reasoning effort, stale-cache refresh, flat
request fields, and omission of `store`/`previous_response_id`. Text-stream
fixtures also cover `response.output_text.done` followed by
`response.output_item.done` and assert that completed output does not duplicate
streamed text. Existing agent and parallel-tool mock fixtures now consume
Responses events. Production
and test development builds succeed. The complete 878-test AUnit suite passes
with 878 successful tests, 0 failed assertions, and 0 unexpected errors.
Chat Completions tests and compatibility providers remain in place. Live
OpenAI/OpenRouter qualification was not enabled because no live-provider guard
and credentials were configured; the automated qualification uses local HTTP
mock servers.

**Verification as of 2026-08-15 (GTK tool-detail argument sizing):**
Production and test development builds succeed after replacing fixed argument
minimum heights with bounded content-aware sizing, suppressing empty raw
argument views, and making the result view the expanding child. The full AUnit
suite passes with 866 tests, 0 failures, and 0 unexpected errors. Detail-window
visual qualification remains manual.

**Verification as of 2026-08-15 (upward drag-select highlight):**
861 registered tests.  Adds two `Coyote_GUI.Conversation` regressions for
document-ordered selection endpoints and inverted-range text extraction.
Display-backed execution requires a GTK display.

**Verification as of 2026-08-15 (GTK completion notifications):**
Focused settings, queue, and policy tests pass. Display-backed notification delivery and focus behavior remain manual qualification DEM-035; the notification daemon is an environment dependency.

**Verification as of 2026-08-15 (variable-height conversation blocks):**
859 registered tests.  Adds three Coyote_GUI.Conversation regressions
for document-height summation, heading vs body pixel height, and
natural-height display math.  Display-backed execution requires a GTK
display.

**Verification as of 2026-08-15 (Ctrl+mouse-wheel zoom, REQ-CORE-125):**
856 registered tests, 0 failures, 0 unexpected errors (full suite completed).
Adds the pure-logic `Coyote_GUI.Zoom` package (12 new tests covering
effective-size clamping, step semantics, plateau walk-back, and baseline
clamping) and wires Ctrl+wheel zoom into the GUI frontend's conversation
layout (`Scroll_Mask` + `On_Conv_Scroll`).  Production and test development
builds succeed.

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

**Verification as of 2026-08-12 (PCR-052 MathML display-math cutover):**
839 registered tests, including direct MathML and display-math prompt regressions.
Clean production and test development builds succeed. Focused Lasem and prompt
tests pass; display-backed GUI qualification requires a GTK display. The full
suite remains subject to existing live/network-dependent execution limits.

**Verification as of 2026-08-13 (PCR-053 GTK conversation zoom):**
841 registered tests, including the Lasem scaling and conversation font
propagation regressions. Production and test development builds succeed.
The exact Lasem scale and conversation font tests pass; full-suite execution
remains subject to existing environment-dependent test constraints.

**Verification as of 2026-08-13 (PCR-054 nested Markdown lists):**
844 registered tests, including shared-renderer and GTK conversation regressions
for two-space nested-list indentation and ordered-list starting ordinals.
Production and test development builds succeed. All four focused list tests
pass; the full suite remains subject to existing environment-dependent tests.

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
for shell-command application and child-process propagation in the GUI/plain architecture
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
(SIGTERM handling) or require live external services (Copilot).
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

**Baseline as of 2026-08-23 (PCR-071 live GTK Session Stats window):**
910 registered tests. Production and test development builds succeed.
Added three `Coyote_GUI.Session_Stats_Window` tests covering typed snapshot
retention, reset behavior, and idempotent support-window construction. The
first two are display-independent; the construction test passes with the
available GTK display. The full suite passes 910/910 with zero failed
assertions and zero unexpected errors.

**Baseline as of 2026-08-23 (PCR-070 GTK IRIX usability increment):**
907 registered tests. Production and test development builds succeed.
New coverage: Product Information text, Agent-menu availability by run
mode, and conversation Select_All/Clear_Selection. Full suite 907/907.
**Baseline as of 2026-08-23 (Yelp/Mallard Help integration):**
904 registered tests. Production and test development builds succeed. The
Yelp URI, topic-mapping, and executable-detection tests are registered.
`yelp-check validate` and `yelp-check links` pass for all 13 Mallard pages.
Display-backed Help-menu, contextual Yelp launch, navigation, and missing-Yelp
qualification remain manual DEM-036..039 activities.

**Baseline as of 2026-08-23 (PCR-068 GTK GUI IRIX interaction continuation):**
901 registered tests. Production and test development builds succeed. The
contextual Help content regression is registered and display-independent.
On X11 `DISPLAY=:0.0`, live qualification verified the session-specific
`coyote-session-<UUID>` role, F1 Overview, transient support-window parenting,
Shift+F1 conversation contextual help, and Escape cancellation. The explicit
light-theme warning and footer palettes measure 5.98:1 and 5.74:1 against
white; dark-theme warning and footer palettes measure 9.96:1 and 4.57:1.
The desktop file validates successfully. AT-SPI is disabled on this host and
the native desktop session-manager restoration interface is unavailable, so
those platform-specific qualifications remain deferred. DEM-014, DEM-036,
DEM-037, and the complete Help-menu click path remain manual qualification
activities.

**Baseline as of 2026-08-23 (PCR-067 keyboard-driven GTK GUI):**
898 registered tests. The application and test development builds succeed.
The focused GUI qualification passes 45 tests with 0 failures and 0
unexpected errors, covering navigation policy, prompt queue acceptance and
overflow, and custom interactive focus.
The complete suite was executed with a 900-second limit; display-backed
DEM-014, AT-SPI accessibility inspection, and full color-contrast measurement
remain manual qualification activities.

**Baseline as of 2026-08-23 (PCR-072 GTK tool-detail alignment):**
911 registered tests. Production and test development builds succeed. Added
session creation timestamp and Tool_Info metadata/media regressions; live and
replayed tool-detail payloads now preserve metadata and image state. The full
suite passes 911/911 with zero failed assertions and zero unexpected errors.
Display-backed DEM-041 remains manual qualification.

**Historical baseline as of 2026-08-25 (PCR-073 native stack visible step-frame implementation):**
919 registered tests. Production and test development builds succeed. The two
new step-frame regressions and the six existing native-stack tests pass
individually with zero failed assertions and zero unexpected errors. The full
suite was not completed within the execution timeout. Native tool cards render
a structured label/grid summary and a `View Details` action; complete detail
payloads remain available to the existing support window. Native assistant/tool
steps now use visible titled Gtk.Frame containers. DEM-042 and DEM-043 revised
component/replay demonstrations and DEM-044 100/500/2,000-exchange performance
qualification remain deferred pending manual execution; visible border
appearance and large-history frame overhead remain unqualified.

**Runtime optimization verification (PCR-074, 2026-08-25):** The default
`coyote_test` runner enables `COYOTE_TEST_FAST_RETRY=1` and
`COYOTE_TEST_NO_CATALOGUE_REFRESH=1` unless explicitly overridden. Agent
retry delays are 50/100/200 ms in this mode; production 2/4/8 second delays
remain available with `COYOTE_TEST_FAST_RETRY=0`. The retry-exhaustion
regression passes in 0.49 seconds with all four attempts, versus 14.22 seconds
with production delays. Two sequential full-suite runs completed in 32.26 and
31.84 seconds, each with 919 tests, 917 successful assertions, 2 pre-existing
PCR-073 native-stack failures, and 0 unexpected errors.

**Baseline as of 2026-08-25 (native GTK footer status row):** 920 registered
tests. Production and test development builds succeed. The focused native
footer regression passes with zero failed assertions and zero unexpected
errors; it verifies the native separator, non-selectable status label,
terminal-separator removal, stable `Fork` label/focus, and callback
UUID/turn/step propagation. The optimized full suite completes with 918/920
tests; the two failures are the pre-existing PCR-073 step-frame tests, which
pass when run individually. Display-backed qualification remains pending under
DEM-042..044.

**Historical PCR-073 corrective verification (2026-08-25):** The native-stack
fixture now clears its reusable stack between tests, and `Begin_Request`
clears prior step-frame bookkeeping. The 10 native-stack tests pass 10/10,
including a consecutive-request reset regression. The complete development
suite passes 921/921 tests with 0 failed assertions and 0 unexpected errors.
Automated step-frame failures are resolved; display-backed DEM-042 and
DEM-043 plus DEM-044 qualification for 100, 500, and 2,000 exchanges remain
pending.

**Baseline as of 2026-08-25 (GTK footer-summary propagation correction):**
923 registered tests. Added coverage for legacy GtkLayout footer-summary
rendering and preservation of the typed native-footer summary through the
GTK update queue. Display-backed native and legacy GUI qualification remains
pending under DEM-042..044.

**Baseline as of 2026-08-25 (PCR-077 subagent recursion-depth limit):**
925 registered tests. Added settings parsing and process-level early-rejection
coverage for `maxRecursionDepth` and `COYOTE_RECURSION_DEPTH`. Production and
test development builds succeed; the complete suite passes 925/925 with zero
failed assertions and zero unexpected errors. DEM-045 remains the manual
qualification procedure for user-visible startup rejection.

**Baseline as of 2026-08-27 (PCR-078 native GTK Markdown):** 927 registered
tests. Added native response-block Markdown replacement and toggle regressions.
Production and test development builds succeed, and both new native Markdown
tests pass individually with the available GTK display. The user reviewed the
native Markdown demonstration and accepted DEM-046 on 2026-08-28. The user also
confirmed live/replay native Markdown parity and accepted DEM-047 on 2026-08-28.
Full-suite execution was attempted but timed out with unrelated environment-
dependent failures. Native display MathML and large-history qualification
remain pending under DEM-048 and DEM-044.


**Baseline as of 2026-08-28 (PCR-079 GTK Stop cancellation):** 928 registered
tests. Added an HTTP stalled-response cancellation regression and corrected the
Acme dispatch abort regression to use `Agent_End_Event.Was_Aborted` as the
source of truth. Production and test development builds succeed; the complete
development suite passes 928/928 with zero failed assertions and zero
unexpected errors.

**Baseline as of 2026-08-29 (PCR-080 GTK recursion-depth preference):**
928 registered tests. Extended the typed GTK preference and settings persistence
regressions to cover maximum subagent recursion depths 3 and 0. Production and
test development builds succeed; the complete suite passes 928/928 with zero
failed assertions and zero unexpected errors. DEM-033 remains the manual
qualification procedure for display-backed Preferences interaction.

**Baseline as of 2026-08-29 (PCR-081 Yelp Help deployment):**
929 registered tests. Added executable-relative Help data-directory coverage.
Production and test development builds succeed in the development profile; the
complete suite passes 929/929 with zero failed assertions and zero unexpected
errors. The existing GPR `Install` artifact declaration supports installing
`share/help/C/coyote/overview.page` under the selected prefix with
`alr install`, and the checkout-relative Yelp data path resolves
`help:coyote/overview`.

**Baseline as of 2026-08-29 (PCR-082 recursive OpenRouter Broadcast identity):**
930 registered tests. Added recursive subagent Broadcast-ID inheritance and
ordinary-session fallback coverage. Production and test development builds
succeed; the complete suite passes 930/930 with zero failed assertions and zero
unexpected errors.

**Baseline as of 2026-08-29 (PCR-083 configurable skill roots):**
933 registered tests. Added settings, skill-discovery, shadowing, and typed
GTK preference queue coverage for ordered `skillPaths`. Production and test
development builds succeed; the complete suite passes 933/933 with zero failed
assertions and zero unexpected errors. Display-backed Preferences interaction,
including folder selection and list reordering, remains pending under DEM-033.

**Baseline after PCR-084 (2026-08-30):**
932 registered tests after removing the redundant accessibility-transcript test.
The development build and complete test suite pass with zero failed assertions
and zero unexpected errors. Native GTK conversation accessibility and selection
remain covered by the native widget and interaction tests.

**Baseline after PCR-085 (2026-08-30):** 933 registered tests. Added a
full-GUI structural regression for the conversation/prompt/status hierarchy;
the focused test passes 1/1 and the complete development suite passes 933/933
with zero failed assertions and zero unexpected errors. The test verifies the
two native separators, four-pixel prompt/status borders, and child ordering.
Human display review of separator contrast remains part of DEM-049. The
standard `xvfb-run` wrapper is unavailable in the current environment; the
focused test was executed directly against the available `DISPLAY`.

**Baseline after PCR-086 (2026-08-30):** 937 registered tests. Added
`shellTerminationGraceSeconds` settings parsing/clamping coverage, typed GTK
preference queue coverage, and process-controller coverage for grace clamping,
launch rejection, and persistence freeze. Production and test development
builds succeed; the complete suite passes 937/937 with zero failed assertions
and zero unexpected errors. Live OS-signal injection remains pending under
DEM-017; display-backed Preferences interaction remains pending under DEM-033.

**Baseline after PCR-088 (2026-08-30):** 940 registered tests. Extended the
existing GUI fixture regression `Coyote.GUI layout and shutdown lifecycle` to
verify application shutdown stops the process-control monitor and releases a
blocked prompt reader. Production and test development builds succeed; the
focused GUI lifecycle test and complete
suite pass with zero failed assertions and zero unexpected errors. Full
window-manager and active-request close qualification remains display-backed.

**Baseline after responsive native tool-card flow (2026-08-30):** 941 registered
tests. Added the native FlowBox structural regression and per-step responsive
flow implementation. Production and test development builds succeed; the
focused `Coyote.GUI.Conversation_Stack uses responsive tool flow` test passes
1/1 with zero failed assertions and zero unexpected errors. Display-backed
multi-column placement and resize reflow remain part of DEM-043 qualification.

**Baseline after Acme frontend removal (2026-08-30):** 798 registered
tests. Removed the Acme frontend, Nine_P subsystem, `coyote_open`, and their
unit/integration tests; migrated the test suite to the GUI/plain architecture.
Production and test development builds succeed, and the complete suite passes
798/798 with zero failed assertions and zero unexpected errors.

**Baseline after native response rendering correction (2026-08-30):** 806
registered tests. Added display-backed native-stack regressions for removal of
the raw streaming response view, preservation of rendered-text selection,
valid/invalid MathML child visibility through recursive `Show_All`, and shared
response styling. Production and test development builds succeed; the focused
native-stack suite passes 17/17 and the complete suite passes 806/806 with zero
failed assertions and zero unexpected errors. Visual light/dark theme
qualification remains open.

**Historical baseline before PCR-090 (2026-08-30):** 943 registered
tests. Added TERM-aware timeout-exit and TERM-ignoring timeout-escalation
regressions. Production and test development builds succeed; the new focused
tests and the complete suite pass with zero failed assertions and zero
unexpected errors. Timeout supervision still begins after synchronous stdin
transfer; a future nonblocking duplex I/O increment is required to bound that
specific large-input/large-output deadlock class.


**Baseline after native GTK conversation cutover (2026-08-31):** 762 registered
tests. Removed the retired GtkLayout/Cairo/Pango conversation renderer, its
test accessors, and its dedicated test group. The native stack is now the sole
GTK conversation presentation and the `COYOTE_NATIVE_STACK` flag is gone.
Production and test development builds succeed. All 17 native-stack tests pass
17/17, and the GUI lifecycle regression passes 1/1 with zero failed assertions
and zero unexpected errors. Native DEM-042 through DEM-048 qualification is
closed; the Plain frontend remains supported.

**Current baseline after AUnit hierarchy and runner corrections (2026-09-05):**
The flat registration body is now a canonical hierarchy of 54 leaf fixture
suites under six domain suites, with Process-Control last. The development
build succeeds and the complete suite passes 822/822 with zero failed
assertions and zero unexpected errors. Measured execution time is 34.3 seconds
wall time after the test executable is built. AUnit global and per-case timing
are enabled. The recursion-depth subprocess test is opt-in with
`COYOTE_TEST_SUBAGENT=1`; live-provider tests remain separately guarded.
