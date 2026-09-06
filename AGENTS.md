# coyote — Agent Instructions

## Project Overview

Coyote is a native Ada 2022 LLM coding-agent harness with two frontends:

- **GUI frontend** — GTK3 graphical conversation view, menus, session tools,
  tool-detail windows, Help, and protected GTK update/prompt queues.
- **Plain frontend** — synchronous line-oriented output for pipes, scripts,
  one-shot runs, and no-display environments.

The former Acme frontend, Nine_P 9P stack, plumber integration, and
`coyote_open` utility were removed from the current product baseline on
2026-08-30. Do not add Acme, 9P, `$winid`, `PLAN9`, or plumber assumptions to
current code or documentation. The current registered test baseline is 822.

Executables:

- `bin/coyote` — selects GUI or Plain and runs the native agent loop.
- `bin/coyote_list_sessions` — prints UUID/name/date/snippet rows for the
  current directory.
- `bin/coyote_sqc` — reads session JSONL files and displays SQC charts.

## Documentation and governance

Engineering artifacts use the MIL-STD-498-based structure:

- `plan/` — project plan, test plan, problem/change log, test reports.
- `requirements/` — SRS documents.
- `design/` — SDD documents and software-unit inventory.
- `sdfs/` — component development logs.

Current frontend work is recorded in `sdfs/frontends.md`; core agent work is
recorded in `sdfs/core-agent.md`. Historical Acme migration records remain
factual and are superseded by the 2026-08-30 removal entry.

## Language and build system

- Language: Ada 2022 (GNAT/GCC).
- Build: Alire/GPRbuild (`alr`).
- Development build: `alr build`.
- Tests: `cd test && alr run coyote_test`.
- Release builds are not to be used unless explicitly requested.

The generated configuration must select the `development` profile. Object
files are under `obj/<profile>/`; executables are under `bin/`.

Dependencies include GNATCOLL, GtkAda/GTK3, libcurl, libcmark-gfm,
Lasem 0.6, Computer Modern math fonts, and Yelp for the GUI Help menu.
There is no plan9port dependency.

## Source layout

```text
src/
  coyote.adb                         entry point and frontend selection
  coyote_app.ads/.adb                App_State and GUI runner
  coyote_app-plain.ads/.adb          headless/plain runner
  coyote_app-frontend.ads            abstract frontend contract
  coyote_app-frontend-gui.*          GTK frontend
  coyote_app-frontend-plain.*        line-oriented frontend
  coyote_app-dispatch.*              native event dispatcher
  coyote_app-history.*               session JSONL replay
  coyote_app-utils.*                 formatting and UTF-8 helpers
  coyote_gui/                        GTK queues, conversation, dialogs
  coyote_renderer/                   shared renderer support
  coyote_sqc/                        SQC application
  llm/                               agent, providers, tools, sessions
  session_lister.*                   session listing/fork support
  coyote_utils.*                     CLI and session-prefix helpers
tools/
  coyote_list_sessions.adb           session-listing utility
test/src/                             AUnit tests
```

When adding source files, update `design/coyote-design.md §4.1` and the
relevant SDF.

## Frontend selection

The current executable selects the frontend in this order:

1. Explicit `--frontend gui|plain`.
2. Non-subagent `--one-shot` → Plain.
3. `COYOTE_FRONTEND=gui`, `$DISPLAY`, or `$WAYLAND_DISPLAY` → GUI.
4. Otherwise → Plain.

The accepted virtual-agent-window amendment changes the planned coordinator
path: a coordinator-launched `--subagent` will use a headless RPC presentation
channel instead of opening a GUI window. Ordinary child processes intended to
open their own physical GUI window may still inherit `COYOTE_FRONTEND=gui`.
Plain one-shot presentation goes to standard error so the final JSON result is
the only standard-output record. There is no Acme frontend context. The
amendment is not yet implemented.

## Architecture

The GUI path has the GTK main task plus an agent task. The agent task emits
`LLM.Events.Agent_Event'Class` values synchronously through
`Coyote_App.Dispatch.Dispatch_Event`; GUI updates cross the GTK boundary via
`Coyote_GUI.Updates`, and input crosses back via `Coyote_GUI.Prompt_Queue`.
All GTK widget operations execute on the GTK main task.

The Plain path is synchronous. `Coyote_App.Plain` owns the agent session,
replays requested history, dispatches native events through the same dispatcher,
and reads additional prompts from standard input. It does not initialize GTK,
open desktop windows, or use external integration services.

Session headers persist sandbox profiles, thinking levels, and parent lineage.
Child processes inherit the relevant `COYOTE_*` values. Tool subprocesses are
tracked by `Coyote_Process_Control`; process-wide SIGTERM uses the configured
grace period before escalation.

## Coding conventions

- Use three-space indentation as enforced by the Alire-generated GNAT development profile and `--  double-dash` comments.
- Omit standalone `in` parameter modes as required by GNAT `-gnatyI`; retain `out` and `in out` modes.
- Keep public API documentation in package specifications.
- Use `Ada.Strings.Unbounded.Unbounded_String` for variable-length record data.
- Use `GNATCOLL.JSON` `Read`, `Get_Str`, and `Get_Int` helpers.
- Use `Coyote_App.Utils.UC_*` constants for non-Latin-1 glyphs.
- Keep GTK operations on the GTK main task.
- Catch exceptions at task boundaries, report errors through the appropriate
  frontend, and always signal shutdown.
- Use `aged` for exact replacement edits. Load
  `/home/gtnoble/.alire/share/agents/skills/aged/SKILL.md` before invoking it.

## Testing

The complete development suite currently contains 822 registered tests and
passes 822/822 in approximately 34 seconds on the development host. The
suite is organized as a root AUnit suite with Core, LLM, SQC, GUI,
Integration, and final Process-Control domain suites. Live provider tests
remain opt-in, and real subagent subprocess tests require
`COYOTE_TEST_SUBAGENT=1`.

```sh
cd test && alr build
/usr/bin/time -f 'wall=%e user=%U sys=%S exit=%x' ./bin/coyote_test
```

AUnit filters are literal case-sensitive prefixes, not globs. For example:

```sh
./bin/coyote_test LLM.Compaction
./bin/coyote_test Coyote.GUI.Conversation_Stack
```

An unmatched filter is an error. GUI tests require a display when they create
GTK windows; conversation and queue tests can run without starting a GUI
window. Live provider tests require their documented guard variables and
credentials.

## Subagents

The generated system prompt supplies the absolute, shell-quoted path of the
active coyote executable in its subagent invocation and example. Use that
rendered command rather than assuming that `coyote` is available on `PATH`.

A GUI parent propagates GUI context to ordinary physical-window children. The
implemented virtual-agent-window path launches coordinator `--subagent`
processes through the headless RPC frontend: the main agent and short-lived
subagents appear as virtual windows in an agents tree, and selecting a live
node routes prompts and controls to it. The subagent retains its
initial-prompt, active-steering, final-response, and exit lifecycle; completed
nodes remain reviewable but do not become persistent agents. Session lineage
uses `COYOTE_SESSION_ID` and `COYOTE_PARENT_SESSION`; recursion
is limited by `maxRecursionDepth` and `COYOTE_RECURSION_DEPTH`.
