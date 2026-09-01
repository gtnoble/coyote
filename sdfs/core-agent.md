# Component Development Log — Core Agent

> **Current-baseline note (2026-08-30):** Entries below that mention Acme,
> Nine_P, 9P, or plumber describe superseded pre-PCR-090 architecture. They
> are retained as historical development records and are not current design
> constraints or implementation guidance.

**Components:** `LLM.Agent`, `LLM.Compaction`, `LLM.Session_Store`,
`LLM.System_Prompt`, `LLM.Skills`, `LLM.Types`, `LLM.Events`

**Source files:** `src/llm/llm-agent.ads/.adb`, `src/llm/llm-compaction.*`,
`src/llm/llm-session_store.*`, `src/llm/llm-system_prompt.*`,
`src/llm/llm-skills.*`, `src/llm/llm-types.*`, `src/llm/llm-events.ads`

---

## Design Rationale

## 2026-08-31 — Virtual-agent-window presentation amendment

**Requirement:** Coordinator-launched subagents shall be organized as virtual
windows in the coordinator's agents tree, with the selected live agent as the
prompt and control target, without changing the existing short-lived worker
lifecycle.

**Design direction:** The planned coordinator supplies a headless RPC frontend
to each coordinator-launched `--subagent`. The child continues to process its
initial prompt, accept steering while its agentic turn is active, emit its
final response, and exit. The coordinator retains the child's conversation
and terminal state as a virtual-agent record for the lifetime of the GUI
process. Selecting a completed record is for review only; it does not restart
or make the worker persistent. Runtime agent identity and parent identity are
separate from durable session UUID and session lineage.

**Status:** Implemented in the development build; focused registry, codec,
transport, and service tests pass. Full integration, display-backed, and
real-provider qualification remain pending under DEM-050..053.

## 2026-08-29 — Recursive OpenRouter Broadcast identity (REQ-CORE-219)

**Requirement:** Subagents and recursively spawned subagents must share the
parent's OpenRouter Broadcast session identifier while retaining distinct
coyote session files and durable lineage.

**Design:** `LLM.Agent.Session` stores a dedicated Broadcast identifier. Root
and ordinary sessions initialize it from their own coyote UUID. Subagent
sessions adopt `COYOTE_OPENROUTER_SESSION_ID` when present and fall back to
their own UUID otherwise. Both normal and compaction OpenRouter calls use the
dedicated value; `COYOTE_SESSION_ID` remains the durable per-process lineage
identity.

**Verification:** Added a recursive in-process agent regression covering root,
child, grandchild, and missing-inheritance fallback. Production and test
projects build successfully; full-suite qualification is pending.

## 2026-08-25 — Subagent recursion-depth limit

**Requirement:** REQ-CORE-025 limits nested `--subagent` processes using the
persistent `maxRecursionDepth` setting and inherited `COYOTE_RECURSION_DEPTH`
context.

**Design:** `coyote.adb` initializes an absent depth to zero, increments it
only when `--subagent` is present, rejects an incremented value above the
configured maximum before frontend/session/provider startup, and exports the
successful value for descendants. The setting defaults to 1 and invalid or
out-of-range JSON values fall back to that default. Ordinary processes,
including forks and New Window launches, preserve the inherited value because
they do not use `--subagent`.

**Rationale:** Enforcing the limit in the child process avoids mutating the
parent's process-global environment before parallel shell calls. Environment
inheritance makes the value available through shell commands without changes
to the shell tool or detached-window launcher. This is an accidental-recursion
control, not a security boundary, because a command can explicitly override
its environment.

**Verification:** Added settings and process-level regressions covering valid,
missing, negative, and non-integer settings plus early rejection with a
nonzero exit and stderr error, including malformed inherited depth. Production
and test development builds succeed; the complete suite passes 925/925 with
zero failed assertions and zero unexpected errors.

## 2026-08-08 — Dedicated subagent model preference

`LLM.Settings` now loads and atomically persists optional
`defaultSubagentProvider` and `defaultSubagentModel` fields. `LLM.Agent.Create`
accepts a subagent-mode flag; explicit model arguments remain authoritative,
then the dedicated subagent default is used, followed by the ordinary default
model and registry fallback. Existing settings and agent regressions cover the
new selection path.

## 2026-08-06 — GUI Preferences implementation and verification

**Scope:** The preferences investigation identified a required extension to
`LLM.Settings`: an optional `defaultSandboxProfile` setting alongside the
existing model and thinking defaults. The documented precedence is explicit
model argument, inherited runtime sandbox profile, then persistent sandbox
default for new sessions; resumed or switched session headers remain
authoritative.

**Implementation:** `LLM.Settings` loads and atomically persists the optional
`defaultSandboxProfile` field alongside model and thinking defaults. The GUI
agent task consumes a typed `Set_Preferences` item and reports persistence
failures without terminating the active session. New sessions reload persistent
thinking and sandbox defaults; explicit inherited sandbox state and session
headers retain their documented precedence.

**Tests:** Added settings persistence, typed prompt-queue, and agent sandbox-
default precedence regressions. Focused PCR-047 tests pass; display-backed
DEM-033 and DEM-034 remain pending.

## 2026-08-04 — PCR-044 Sandbox Profile Restoration and Synchronization
**Problem:** Sandbox profiles were persisted in session headers but ignored on
resume and session switching. Frontend-local state could also disagree with
the agent and the child-process environment.

**Design and implementation:** Added `LLM.Session_Store.Session_Sandbox_Profile`
to read the first header record. `LLM.Agent.Create` uses the persisted value
for resumed sessions, and `LLM.Agent.Switch_Session` replaces its active value,
including clearing it when the target has no profile. Both Acme and GUI agent
tasks call a local `Synchronize_Sandbox` operation after creation, new-session
creation, and session switching; it updates the local state, `App_State`, and
`COYOTE_SANDBOX_PROFILE`. Session-info events query the agent directly.

**Tests:** Added one session-store accessor test and two agent tests for resume,
switch/restore, and switch/clear. Focused tests and the complete 821-test suite passed.

### Why `On_Event` is a synchronous callback, not a queue

The agent loop in `LLM.Agent.Run_Prompt` invokes the `On_Event` callback
synchronously in the caller's task for each event. An alternative would be
to enqueue events into a thread-safe queue and have the agent loop post-process
them. The synchronous approach was chosen because:

1. In the Acme path, the agent task can write directly to the 9P window body
   without any additional synchronisation. A queue would introduce unnecessary
   latency and complexity.
2. In the GUI path, the callback (`Dispatch_Event`) immediately enqueues into
   `Coyote_GUI.Updates`, so the queue exists exactly where it is needed (the
   GTK thread boundary) rather than universally.
3. Provider adapters call `On_Event` from within the libcurl write callback,
   which runs in the calling task. A queue at this layer would decouple the
   streaming backpressure from display, potentially allowing the provider to
   outpace the UI with no flow control.

### Why conversation history is a flat `Message_Vectors.Vector`

A tree structure (to model branching from forks) was considered. The flat
vector was chosen because:
- Session forking is implemented by copying the JSONL file at fork time and
  loading it as a new session; the in-memory history of each session is
  always linear. Forking supports both full-turn cut points
  (`coyote-fork+PID/UUID/N`) and step-level cut points within a turn
  (`coyote-fork+PID/UUID/N/S`) that capture the assistant's tool-call
  message and tool results.
- A flat vector makes compaction cut-point calculation straightforward
  (`Find_Cut_Point` walks in reverse from the end).
- The providers' wire formats (OpenAI, Anthropic) expect a flat ordered array.

### Token estimation: 4 bytes per token

The `Estimate_Tokens` function in `LLM.Compaction` uses a simple 4-bytes-per-
token heuristic. The actual ratio varies: English prose is approximately
4 bytes/token; code with long identifiers is higher; minified code is lower.
4 bytes/token is conservative (over-estimates token count), which means
compaction triggers slightly earlier than necessary — a safe bias that avoids
context overflow rather than risking it. A tiktoken binding was considered but
rejected: it would add a C dependency and require per-model tokenizer files.

### Session JSONL: append-per-message, not write-at-turn-end

Each message is appended immediately after it is added to the in-memory
history. This means the JSONL file is always current to the last successfully
completed message, even if the process is killed mid-turn. A partial turn
(user message present, no assistant response yet) is benign on reload:
the agent simply shows the prior context and awaits a new prompt.

### `Compaction_Summary` as a synthetic message role

When compaction replaces a prefix of the history with a summary, the summary
is inserted as a synthetic message with role `compaction_summary`. This role
does not appear in the wire format; `LLM.Agent` maps it to a `user` message
with a structured preamble when building the request JSON. This keeps the
in-memory type system clean (only the values in `LLM.Types.Role`) while
allowing the session store and history replay to distinguish compaction
boundaries from normal user messages.

---

## Key Constraints

- `Run_Prompt` must not be called concurrently with `Compact` on the same
  `Session` value. The `Session` type is `limited private`; callers are
  responsible for sequencing.
- `Abort_Flag` is an atomic boolean that can be set from any task (e.g. the
  `Acme_Event_Task` on a Stop button press). It is checked in the libcurl
  write callback and between tool executions.
- `LLM.Session_Store` opens each file in append mode for each write and
  closes it immediately. This avoids holding a file handle open across the
  lifetime of the agent, which would prevent external tools (e.g. coyote_sqc)
  from reading the session file.

---

## 2026-08-28 — GTK Stop and blocked-provider cancellation

**Problem:** The GTK Stop callback set the agent abort flag but also queued a
Stop command that could not be consumed while the GUI agent task was inside
synchronous `Run_Prompt`. Provider cancellation was checked only from the
response-body write callback, so an idle libcurl transfer could remain blocked.
GTK dispatch also classified completion from delayed application state instead
of the authoritative `Agent_End_Event.Was_Aborted` field.

**Fix:** GTK Stop now calls the protected session abort operation directly
without queueing a Stop item. `LLM.Tools.Abort_Flag` maintains an atomic C
mirror, and `LLM.HTTP.Curl_Binding` installs a native libcurl transfer-info
callback that polls that mirror while the request is blocked. The callback is
forwarded through every provider and compaction route. `Dispatch_Event` now
uses the end-event abort field, and `Run_Prompt` no longer clears a concurrent
abort request at prompt entry.

**Verification:** Added a stalled-response HTTP regression and changed the
Acme dispatch regression to rely on `Was_Aborted` alone. Production and test
development builds succeed; the complete suite passes 928/928 tests with zero
failed assertions and zero unexpected errors.

## Unit Test Coverage Notes

- `LLM.Compaction`: covered by AUnit tests in `test/src/` —
  `Result_Threshold` boundary cases; `Find_Cut_Point` with varying histories.
- `LLM.Session_Store`: covered by AUnit tests — v1/v3 parse round-trips;
  compaction record encoding; cwd-slug encoding.
- `LLM.Skills`: covered by AUnit tests — discovery with mock file trees;
  shadowing; frontmatter missing-field handling.
- `LLM.Agent`: not directly unit-tested (requires a live provider or mock).
  Covered by demonstration tests.

---

## 2026-07-08 — Timeout and Abort Reliability (setsid + SIGKILL)

The shell tool's timeout and manual-abort paths were reworked to guarantee
sub-second abort latency even when the child process is consuming no CPU
(e.g. `sleep 3600`).  The previous design used an Ada `select`/`then abort`
ATC block to attempt to interrupt a blocking `read()` syscall, but GNAT does
not preempt C-level `read()` on Linux, so the ATC loop could not exit until
the child closed the pipe — which only happens when the child exits.

**Root cause:** `close(fd)` from another thread does not unblock `read(fd)`
on Linux (NPTL).  fd tables are per-process, not per-thread, so a sibling
thread closing the fd has no effect on the blocked caller.  Verified

with a standalone C test program (`/tmp/test_tcbr.c`).

**Fix:** three changes to `src/llm/llm-tools-shell.adb`:

1. **Shell invocation wrapped in `setsid(1)`:** the child becomes a session
   leader in its own process group.  `kill(-Handle, SIGKILL)` therefore kills
   the shell and all descendants atomically.

2. **Timer task changed from "flag-setter" to "killer":** the immediate-mode
   `SIGTERM` in the main-task post-loop path is preserved as redundant
   cleanup, but the Timer now sends `SIGKILL` from its own task immediately
   after the delay, then exits.  When the kernel reaps the child it closes
   the write-end of the output pipe, and the blocked `read()` in the main
   task returns EOF (0 bytes).

3. **Manual-abort path uses the same pattern:** an `Abort_Watcher` task
   blocks on `Abort_Flg.Wait_Requested`, then sends `SIGKILL` to the child's
   process group.

**Tests added:** two new elapsed-time tests in
`test/src/llm_tools_tests.adb`:
- `Test_Shell_Timeout_Under_Elapsed` — verifies `Ada.Real_Time.Clock`
  elapsed < 2.0 s when command finishes under timeout
- `Test_Shell_Timeout_Triggers_Elapsed` — verifies elapsed ≥ 1.5 s and
  ≤ 3.0 s when `sleep 10` is killed with a 2 s timeout

## 2026-07-06 — Run-Group Tool Execution

Tool calls now execute **sequentially by default**. The shell tool accepts an
optional integer `run_group` argument (stripped before the command executor
sees it). When every tool call in a turn carries a `run_group > 0`, calls
are grouped and executed in ascending group order, with calls within the same
group running concurrently via the existing `Worker_Task` + `Results_Store`
fork-join pattern. When any call lacks `run_group` (or has `run_group = 0`),
all calls run one at a time in the original call order.

Files changed:
- `src/llm/llm-agent.adb` — `Pending_Tool` gained `Run_Group : Natural`;
  `Extract_Run_Group` and `Strip_Run_Group` helpers added; tool accumulation
  now parses and removes `run_group` from the JSON; execution block
  dispatches between the grouped path (old parallel machinery, scoped per
  group) and the new sequential path (single worker per tool, one at a time).
- `src/llm/llm-tools-shell.adb` — `run_group` added to the shell tool JSON
  schema as an optional integer property.
- `test/src/llm_parallel_tools_tests.adb` — two new tests: sequential default
  (`Test_Tools_Run_Sequentially_By_Default`) and group ordering
  (`Test_Tools_Run_In_Group_Order`); existing concurrency test updated to
  include `run_group:1`.
- Requirements: added REQ-CORE-056.

---

## Open Questions / Future Work

- The `promptFilter` feature runs the filter via `$SHELL -c CMD` synchronously
  in the prompt-reading path. If the filter is slow, this blocks the acme
  event loop. Consider moving it to a separate task if latency becomes an issue.
- The 4-bytes-per-token heuristic should be validated against real session
  data once sufficient sessions are accumulated in coyote_sqc.

---

## PCR-040 — Enhanced System Prompt, Memory, Coordinator, Compaction Improvements (2026-07-12)

### Design Rationale

**New package LLM.Memory:** The memory system is implemented as a separate
package (`LLM.Memory`) rather than being folded into `LLM.System_Prompt`
because it has its own discovery logic (two path roots, content capping,
truncation warnings) that is independent of prompt construction. The
separation also allows future extensions — e.g. programmatic memory query
APIs — without touching the prompt layer.

**Personality definition in Build_System_Prompt:** The personality block is
a constant string embedded at the top of the prompt rather than a separate
file. This keeps the personality always present regardless of filesystem
state and avoids a hidden configuration dependency. The content was derived
from the agent study of Claude Code's communication patterns.

**Conditional tool-use instructions:** The `Has_Editing_Tools` parameter
allows the prompt to adapt to the session's tool set. When the agent has
access to file-editing tools (shell), it is told to prefer them; when it
doesn't, it is told to print code blocks as suggestions. This avoids the
model offering `aged FILE OLD NEW` commands when tools are disabled.

**Nine-section compaction prompt:** The upgrade from 6 to 9 sections came
from the Claude Code study. The key additions are: (1) "Key Technical
Concepts" — domain knowledge the continuation agent needs; (3) "Files and
Code Sections" — with full code snippets, not just filenames; (6) "All User
Messages" — verbatim quotes of every user instruction, which proved critical
for maintaining task continuity across compaction boundaries; (8) "Current
Work" — with verbatim quotes from the last assistant response.

**Analysis-block drafting:** The `<analysis>` block gives the summarisation
model space to reason before writing. It is stripped by `Strip_Analysis_Block`
before storage, keeping context window usage minimal. The stripping logic
handles both well-formed (`<analysis>...</analysis>`) and malformed blocks
(opening tag without closing tag).

**Circuit breaker:** The breaker trips after 3 consecutive failures because
that threshold is high enough to tolerate transient provider errors but low
enough to detect persistent problems (bad model, context overflow loop).
Manual compaction remains available even when tripped — the breaker only
blocks automatic compaction.

**Per-turn reminders:** The reminder block is appended to every user prompt
rather than being in the system prompt, because system-prompt instructions
are easily forgotten over long conversations. Repetition at each turn keeps
the guidance salient.

**Display-math guidance (REQ-CORE-173, 2026-08-12):** `Build_System_Prompt`
now includes a static GUI display-math section requiring Presentation MathML,
a complete `<math>` document, and standalone `$$` delimiters. It is separate
from the compaction summarization prompt because it governs user-facing
assistant output, not internal summaries.
The regression test `Test_Default_Prompt_Contains_Display_Math_Guidance`
verifies the guidance is present.

**Partial compaction design:** The existing cut-point mechanism already
supports partial compaction semantically: `Find_Cut_Point` determines where
to split, and messages from the cut forward are kept verbatim. The
`Is_Partial` flag in `Build_Compact_Prompt` adds a scoping preamble to the
summarisation prompt when the compaction covers only the earlier portion of
a long conversation.

### Files Changed
- `src/llm/llm-memory.ads`, `src/llm/llm-memory.adb` — new package
- `src/llm/llm-system_prompt.ads`, `src/llm/llm-system_prompt.adb` — extended
- `src/llm/llm-compaction.ads`, `src/llm/llm-compaction.adb` — rewritten prompts,
  circuit breaker, analysis stripping, Build_Compact_Prompt
- `src/llm/llm-agent.adb` — memory integration, reminder appending,
  circuit-breaker tracking, analysis-stripping in Compact
- `src/coyote_app.adb` — updated Compact_Settings aggregates
- `test/src/llm_compaction_tests.adb` — updated Compact_Settings aggregates
- `test/src/llm_agent_tests.adb` — updated Compact_Settings aggregate
- `plan/problems.md` — PCR-040 implementation actions recorded
- `sdfs/core-agent.md` — this log entry

## 2026-07-30 — Sandbox Shell Profiles

**Context:** The shell tool previously ran commands with full filesystem access.
There was no way to restrict what paths a shell command could read or write.

**Solution:** A new `LLM.Tools.Sandbox` package discovers sandbox profiles from
`~/.coyote/sandbox/*.json`. Each profile is a JSON object with four optional
rule arrays: `allowWrite`, `denyWrite`, `denyRead`, `allowRead`. When a profile
is active, `LLM.Tools.Shell.Execute` wraps the command with `bwrap`
(bubblewrap), placing the entire root filesystem as read-only and selectively
adding `--bind`, `--ro-bind`, or `--tmpfs` directives per the profile rules.
Paths are resolved relative to CWD; missing paths are silently skipped.

**Files touched:**
- `src/llm/llm-tools-sandbox.ads/.adb` — new package: profile discovery,
  rule loading, bwrap argument construction.
- `src/llm/llm-agent.ads/.adb` — `Sandbox_Profile` field on `Session`;
  `Set_Sandbox_Profile` and `Current_Sandbox` procedures; `COYOTE_SANDBOX_PROFILE`
  inheritance in `Create`; `Worker_Task` gains `Sandbox_Profile` access
  discriminant and passes it to `Shell.Execute`.
- `src/llm/llm-tools-shell.ads/.adb` — `Execute` gains `Sandbox_Profile`
  parameter; when non-empty, starts `setsid` before the `bwrap` arguments so
  timeout and abort signals target the complete sandboxed process group.
- `src/llm/llm-events.ads` — `Session_Info_Event` gains `Sandbox_Profile` field.
- `src/llm/llm-session_store.adb` — writes `sandboxProfile` to JSONL session
  header.
- `src/coyote_app.ads/.adb` — `App_State` gains `Current_Sandbox`/`Set_Sandbox`;
  Acme path gains `Plumb_Sandbox_Task` (port `/coyote-sandbox`,
  token `coyote-sandbox+PID/PROFILE`) and `Set_Sandbox_Command`; GUI path
  dispatches `Set_Sandbox` prompt-queue items; `COYOTE_SANDBOX_PROFILE`
  propagated to child processes; `Status_Label` shows profile name.
- `src/coyote_gui/coyote_gui-prompt_queue.ads` — `Set_Sandbox` item kind with
  `Profile_Name` payload.
- `src/coyote_app-frontend-gui.adb` — `On_Sandbox_Profile_Activate` dialog
  handler; `Sandbox Profile...` menu item under Agent menu.
- `src/coyote_app-dispatch.adb` — handles `Sandbox_Profile` in
  `Session_Info_Event` dispatch.
- `test/src/dispatch_tests.adb` — updated `Session_Info_Event` construction.
- `~/.coyote/sandbox/default.json` — initial profile with `allowWrite` and
  `denyRead` rules.
- `src/llm/llm-tools-shell.adb` — corrected process-group wrapper ordering:
  `setsid` now starts `bwrap` rather than being nested inside it.

**Test coverage (2026-07-30, extended 2026-08-08):** 24 unit tests in
`test/src/sandbox_tests.ads/.adb`
cover `Profiles_Dir`, `Available_Profiles` (empty/found), `Load_Profile` (valid
JSON / missing / bad JSON), `Build_Bwrap_Args` for all four rule types
(allowWrite→`--bind`, denyWrite/allowRead→`--ro-bind`, denyRead→`--tmpfs`),
edge cases (empty/non-existent profile, missing paths skipped, multiple rule
types coexist, depth sorting), path resolution (`.`, `./`, `~/`, absolute
pass-through), and shell+sandbox integration (allowWrite succeeds,
denyRead blocks, empty profile runs unsandboxed).  3 `coyote_app_tests`
cover `App_State.Current_Sandbox`/`Set_Sandbox`; 5 `llm_agent_tests` cover
`Set_Sandbox_Profile`/`Current_Sandbox` round-trip, env-var inheritance on
`Create`, empty default, persisted-profile resume, and profile restore/clear
on session switching; 3 `llm_session_store_tests` cover header write, header
absence, and reading `sandboxProfile` from a JSONL header.

## 2026-08-16 — Inline Unicode math guidance in system prompt

**Requirement:** REQ-CORE-173 now covers both GUI display mathematics and
inline mathematics in assistant messages.

**Implementation:** Extended `Display_Math_Guidance` in
`src/llm/llm-system_prompt.adb` with an `# Inline Math` section. The prompt
requires direct Unicode math symbols in ordinary text and prohibits
LaTeX-style inline delimiters and backslash commands, while retaining the
Presentation MathML rules for standalone display blocks.

**Verification:** Extended the existing system-prompt regression to assert the
inline section and the Unicode-symbol instruction.
The registered test count is unchanged.

**Design rationale:** Display math requires structured Presentation MathML for
reliable GUI rendering; inline math is kept lightweight and readable by using
Unicode symbols directly instead of introducing a second markup syntax.

## 2026-08-22 — Model-bound thinking provenance and failed-turn rollback

**Problem:** PCR-063 showed that a runtime model switch retained encrypted
reasoning produced by the prior model. PCR-064 showed that a non-retryable
provider failure left the unpersisted user prompt in memory but absent from
JSONL.

**Design:** `Thinking_Block` now records `Origin_Provider` and `Origin_Model`.
`LLM.Agent.Compatible_History` derives a temporary provider request view,
omitting foreign or unknown model-bound thinking while preserving durable
history, ordinary assistant text, tool calls, and tool results. Switching back
to the origin model therefore restores its reasoning continuity. Pending
messages are removed from the persistence queue only after each append succeeds;
an escaping provider or persistence exception removes only the remaining
unpersisted history suffix and restores first-prompt submitted state.

**Verification:** Added agent regressions for Grok/Luna-compatible views,
switch-back restoration, durable-history non-mutation, and HTTP 404 rollback
agreement between in-memory and loaded JSONL history. Focused tests pass.

## 2026-08-25 — Test-suite runtime controls

**Problem:** The monolithic 919-test executable used production retry
backoff during mock-provider tests and refreshed provider catalogues during
every `LLM.Agent.Create`. The resulting suite took 149–210+ seconds and
occasionally exceeded its execution timeout.

**Design:** Preserve production behavior by making both optimizations
explicitly test-runner scoped. `test/src/coyote_test.adb` defaults
`COYOTE_TEST_FAST_RETRY` and `COYOTE_TEST_NO_CATALOGUE_REFRESH` to `1`,
without overwriting caller-provided values. `LLM.Agent.Send_With_Retry` uses
50/100/200 ms delays when the first flag is enabled and retains the production
2/4/8 second schedule otherwise. `LLM.Agent.Create` skips startup catalogue
refreshes only when the second flag is enabled. Direct catalogue and model
registry tests remain able to invoke refresh operations explicitly.

**Rationale:** Zero-delay retries were rejected because the serial TCP mock
server could not reliably accept all four requests. Small nonzero delays keep
the retry test's four-attempt assertion deterministic while removing nearly
all artificial wait time. Environment controls avoid adding a production API
solely for test performance.

**Verification:** `cd test && alr build` succeeds. The retry-exhaustion test
passes in 0.49 seconds with all four attempts. With
`COYOTE_TEST_FAST_RETRY=0`, the same test passes in 14.22 seconds, confirming
the production schedule remains available. The historical full-suite runs
passed 917/919 assertions in 31.84–32.26 seconds with zero unexpected errors;
the PCR-073 native-stack fixture-isolation and exchange-reset correction now
brings the current full suite to 921/921.

## 2026-08-29 — GTK subagent recursion-depth preference

**Requirement:** The GTK Preferences dialog shall expose the persistent
maximum subagent recursion depth and save it for subsequently launched
subagents without mutating the active session.

**Design:** The preference is transported as a `Natural` field in the typed
`Coyote_GUI.Prompt_Queue.Preferences_Record` and persisted by
`LLM.Settings.Save_Preferences` as `maxRecursionDepth`. The GUI uses a bounded
integer `Gtk.Spin_Button`; zero retains its documented meaning of disabling
subagent spawning. Enforcement remains in `coyote.adb` before frontend or
session startup.

**Verification:** Extended settings persistence and GTK prompt-queue tests to
cover non-default depth 3 and zero. The focused tests pass; display-backed
DEM-033 remains the qualification procedure for the complete Preferences flow.

## 2026-08-29 — Configurable skill roots

**Requirement:** Persist optional additional skill roots in `settings.json` and
make them available to the shared skill-discovery path.

**Design:** `LLM.Settings` exposes `Skill_Paths` as an ordered string vector,
loaded from the `skillPaths` JSON array and atomically persisted by
`Save_Preferences`. `LLM.Skills.Load_Skills` scans configured roots after the
built-in global/installation roots and before project-local roots. Later roots
replace earlier entries with the same skill name, preserving documented
shadowing semantics. Invalid array elements and unavailable directories are
ignored without aborting startup.

**Verification:** Added settings and skill-discovery regressions for ordered
array loading, malformed elements, serialization/clearing, configured-root
loading, and project-local shadowing. Focused tests and the full development
suite pass.


## 2026-08-30 — SIGTERM shell-process shutdown escalation

**Requirement:** A first SIGTERM must cancel active shell tools, send SIGTERM
to all shell-tool process groups including shell-launched coyote descendants,
retain only records already flushed before shutdown, and escalate to SIGKILL
after a configurable bounded grace period. A second SIGTERM escalates
immediately. Subagents have no implicit execution timeout.

**Implementation:** Added `Coyote_Process_Control` with a protected process-group
registry, launch reservations, persistence freeze gate, and deferred signal
coordination. Added the async-signal-safe C self-pipe bridge and `/proc` descendant
scan for nested `setsid` groups. Shell launches reset the inherited coyote
SIGTERM disposition before executing the user shell or sandbox wrapper. Acme and
GUI runtimes run shutdown monitor tasks; normal UI Stop/close remains separate.
The GTK Preferences dialog persists `shellTerminationGraceSeconds`, bounded to
0..30 seconds with default 2.

**Verification:** Production and test development builds succeed. The complete
AUnit suite passes 937/937 with zero failed assertions and zero unexpected
errors. Settings and typed preference queue regressions cover the new field.
Live OS-signal injection against an interactive coyote process remains a
manual qualification activity because the test environment does not provide a
stable provider/frontend fixture.

## 2026-08-30 — GTK model-picker dB price display (PCR-087)

Added `LLM.Settings.Price_Display_Mode` with SI-prefix and dB choices. The
optional `priceDisplay` setting defaults to SI and is atomically persisted by
`Save_Preferences`. `Coyote_App.Utils.Format_DB_Price` converts stored
$/MTok values to $/tok before applying `10 × log10`; zero is `free` and
negative values are blank. GTK carries the choice through the typed preference
queue and applies it to the next model-picker invocation. Formatter, settings,
and queue regressions cover the behavior.

## 2026-08-30 — Graceful shell timeout escalation

**Requirement:** A positive shell timeout sends SIGTERM first, permits the
configured `shellTerminationGraceSeconds` interval for clean termination, and
sends SIGKILL only when the process group remains active. Manual abort retains
immediate SIGKILL.

**Implementation:** `LLM.Tools.Shell` uses protected termination state and the
descendant-aware `Coyote_Process_Control.Signal_Group` operation. Timeout
supervision sends TERM, waits on an absolute grace deadline, and escalates to
KILL. Direct child reaping is centralized and occurs before registry
unregistration, including the exceptional cleanup path.

**Verification:** Added TERM-aware and TERM-ignoring timeout regressions;
focused tests and the 943-test development suite pass. The current lifecycle
still transfers synchronous stdin before starting timeout supervision, so a
future nonblocking duplex-I/O increment remains necessary to bound pathological
large-input/large-output pipe deadlocks.

## 2026-08-31 — Active executable in subagent prompt

**Requirement:** Subagent shell instructions shall invoke the coyote executable
image that is actively running, rather than assuming that `coyote` is available
on `PATH`.

**Implementation:** Added `Coyote_Utils.Active_Executable_Path`, which resolves
`/proc/self/exe` through `GNAT.OS_Lib.Normalize_Pathname` with link resolution
and falls back to `Ada.Command_Line.Command_Name`. Added `Shell_Quote` for
POSIX-safe prompt rendering. `LLM.System_Prompt.Build_System_Prompt` accepts an
injectable executable path and uses one quoted command in both invocation and
example text. GUI new-window and session-fork launchers use the same active path;
skill installation-prefix discovery reuses the centralized resolver.

**Verification:** Added utility and system-prompt tests for active-path
resolution, repeated command rendering, spaces, and apostrophes. Focused tests
pass in the development test build.
