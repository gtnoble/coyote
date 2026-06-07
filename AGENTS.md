# coyote — Agent Instructions

## Project Overview

The project is a multi-frontend Ada coding-agent harness.  Three frontends are
available and selected automatically at startup:

- **Acme frontend** — opens a `+coyote` acme window and renders streaming
  output there (selected when `$winid` is set, i.e. when running inside acme).
- **GUI frontend — GTK3 graphical window with conversation view,
  vi-style scroll navigation, and `$EDITOR`/`$PAGER` integration (selected
  when stdout is a TTY and `$winid` is not set).
- **Plain frontend — line-oriented text output with no ANSI (selected for text output with no ANSI (selected for
  `--one-shot` mode and when stdout is not a TTY, e.g. piped output).

All frontends implement the abstract `Coyote_App.Frontend.Instance` interface
and drive the same `LLM.Agent` agentic loop.

**plan9port** (acme, plumber, 9P utilities) is installed at
`/usr/local/plan9`. The `PLAN9` environment variable should point there;
binaries such as `acmeevent` live in `/usr/local/plan9/bin/`.

Three executables are built:
- `bin/coyote` — the main entry point; selects the appropriate frontend
  (`Acme_Frontend`, `GUI_Frontend`, or `Plain_Frontend`) based on `$winid` and
  display detection, then calls `Coyote_App.Run` or `Coyote_App.Run_GUI`
- `bin/coyote_list_sessions` — lists saved sessions for the current directory
- `bin/coyote_open` — opens a tool-call detail window; launched by the plumber
- `bin/coyote_sqc` — Statistical Quality Control application; reads Coyote session JSONL files and displays SPC control charts in a GTK3 GUI
  for `coyote-session+UUID/tool/TOKEN` links

## Documentation

The project uses a MIL-STD-498-based governance structure.  Engineering
artifacts live in `plan/`, `requirements/`, `design/`, and `sdfs/`.

### Structured Engineering Documents

| ID | Title | Path |
|---|---|---|
| PLAN | Project Plan | `plan/project-plan.md` |
| PCR-LOG | Problem/Change Log | `plan/problems.md` |
| TEST-PLAN | Test Plan | `plan/test-plan.md` |
| SRS-CORE | coyote Requirements Specification | `requirements/coyote-requirements.md` |
| SDD-CORE | coyote Design Description | `design/coyote-design.md` |
| SRS-SQC | coyote_sqc Requirements Specification | `requirements/coyote-sqc-requirements.md` |
| SDD-SQC | coyote_sqc Design Specification | `design/coyote-sqc-design.md` |
| REVIEW-PLAN | Native Agent Review Plan | `plan/review-plan.md` |

### Component Development Logs

| Log | Covers |
|---|---|
| `sdfs/core-agent.md` | LLM.Agent, Compaction, Session_Store, Skills, Types |
| `sdfs/providers.md` | LLM.Providers.*, HTTP, SSE, Auth, Tools, Settings |
| `sdfs/frontends.md` | Coyote_App.*, Coyote_GUI.*, Acme.*, Nine_P.* |
| `sdfs/coyote-sqc.md` | Coyote_SQC.*, Coyote_Renderer.* |

### Operational References

- `docs/skills.md` — full reference for the `SKILL.md` file format
  (frontmatter fields, discovery roots, shadowing, writing effective
  descriptions and bodies)
- `plan/integration-test-guide.md` — opt-in live-provider and acme
  integration tests: guard variables, setup, and procedure

When authoring or editing a `SKILL.md` for this project, load
the `coyote-skill-author` skill for a condensed quick-reference.
## Language & Build System

- **Language:** Ada 2022 (GNAT/GCC)
- **Build system:** [Alire](https://alire.ada.dev/) (`alr`) with a GPRbuild
  project (`coyote.gpr`)
- **Dependencies:**
  - `gnatcoll` ≥ 25.0.0 (JSON, OS, process utilities)
  - system `libcurl` development headers (`libcurl4-openssl-dev` on Debian /
    Ubuntu) for the native HTTP/SSE client
  - system `libcmark-gfm` development headers (`libcmark-gfm-dev` and
    `libcmark-gfm-extensions-dev` on Debian / Ubuntu) for GFM Markdown
    rendering in the GUI frontend

### Build commands

```sh
# Build (development profile, default)
alr build

# Build release — DO NOT USE unless explicitly requested by the user
# alr build --release

# Run tests
cd test && alr run coyote_test
```

Object files go to `obj/<profile>/`, binaries to `bin/`.

**Build profile discipline — always use development:**

- Always build with plain `alr build` (no `--release` or `--validation` flag).
- The config in `config/coyote_config.*` must always reflect the `development`
  profile. If it ever shows `release` or `validation`, treat that as a bug and
  revert it before proceeding.
- Never deviate from either rule without an explicit instruction from the user.

## Source Layout

The full software unit inventory (38 units with source files and descriptions)
is in `design/coyote-design.md §4.1`.  Directory structure:

```
src/
  coyote.adb            -- Entry point (CLI parsing, frontend selection)
  coyote_app.ads/.adb   -- App_State (protected), Run, Run_GUI
  coyote_app-dispatch.ads/.adb  -- Dispatch_Event: LLM event → Frontend'Class
  coyote_app-frontend.ads       -- Abstract Frontend interface
  coyote_app-frontend-*.ads/.adb -- Concrete frontends (Acme_Win, GUI, Plain)
  coyote_app-history.ads/.adb   -- Session JSONL replay
  coyote_app-utils.ads/.adb     -- Formatting helpers; UC_* Unicode constants
  coyote_gui/           -- GTK3 GUI subsystem (Updates queue, Buffer, Prompt_Queue)
  llm/                  -- LLM agent, providers, HTTP/SSE, settings, tools, skills
  acme.ads/.adb         -- Acme window helpers
  acme-window.ads/.adb  -- Acme window operations (9P)
  acme-event_parser.ads/.adb  -- Acme event-file parser
  nine_p*.ads/.adb      -- 9P2000 client
  coyote_cmark.ads/.adb -- Ada binding to libcmark-gfm (+ coyote_cmark_c.c shim)
  coyote_renderer/      -- Shared Pango markup + session-view rendering
  coyote_sqc/           -- SQC companion application packages
  coyote_sqc_main.adb   -- Entry point for coyote_sqc
  session_lister.ads/.adb -- Session listing for coyote_list_sessions
  coyote_utils.ads/.adb -- CLI arg resolution, session-prefix stripping
tools/
  coyote_list_sessions.adb  -- Entry point for session listing utility
  coyote_open.adb           -- Entry point for tool-call detail window
test/                   -- AUnit test suite (see plan/test-plan.md)
plan/                   -- Project Plan, Test Plan, problem log, review records
requirements/           -- SRS-CORE (coyote), SRS-SQC (coyote_sqc)
design/                 -- SDD-CORE (coyote), SDD-SQC (coyote_sqc)
sdfs/                   -- Component development logs
docs/                   -- Operational references (skills.md)
```

Key roles for the most-frequently-touched packages:

- `src/llm/llm-agent.ads/.adb` — Agentic loop: `Create`, `Run_Prompt`,
  `Compact`, `Request_Abort`, `Request_Pause`, `Resume`
- `src/llm/llm-events.ads` — `Agent_Event'Class` hierarchy
- `src/llm/llm-providers-*.ads/.adb` — Provider wire formats (OpenAI, Ollama,
  Anthropic, Copilot, OpenRouter, OpenCode Go)
- `src/llm/llm-session_store.ads/.adb` — JSONL session persistence
- `src/llm/llm-compaction.ads/.adb` — Token estimation and cut-point logic
- `src/llm/llm-skills.ads/.adb` — Skill discovery and prompt formatting
- `src/coyote_gui/coyote_gui-buffer.ads/.adb` — GtkTextBuffer + markdown

**When adding new source files:** add them to `design/coyote-design.md §4.1`
and record the key design decisions in the relevant `sdfs/` log.
## Frontend Selection

`coyote.adb` selects the frontend before calling `Run` or `Run_GUI`:

```
1. --one-shot flag set (non-subagent)          → Plain_Frontend  (Coyote_App.Run)
2. $winid non-zero (set by acme exec.c per window launch) → Acme_Frontend   (Coyote_App.Run)
3. $DISPLAY or $WAYLAND_DISPLAY set            → GUI_Frontend    (Coyote_App.Run_GUI)
4. COYOTE_FRONTEND=gui                         → GUI_Frontend    (Coyote_App.Run_GUI)
5. otherwise (piped / no display)              → Plain_Frontend  (Coyote_App.Run)
```

The selected kind is stored in `Options.Frontend : Frontend_Kind`.

### `COYOTE_FRONTEND` environment variable

When the GUI frontend is selected, `coyote.adb` immediately sets
`COYOTE_FRONTEND=gui` in the process environment.  All child processes
(shell tool subprocesses, `:new` spawns, subagent invocations) inherit this
and trigger step 4, selecting the GUI frontend automatically.  This mirrors
how the acme frontend propagates via `$winid`: in both cases the "headful
context" is ambient and inherited.

Unlike the old TUI approach, there is no PTY relay or `openpty` machinery.
The GUI frontend calls `Gtk.Main.Init` directly on the main Ada task and
opens a `GtkApplicationWindow` in-process.  No separate terminal emulator
process is needed.

## Architecture

The full architectural design — static dependencies, concepts of execution for
the Acme and GUI paths, and the five key design decisions — is in
`design/coyote-design.md §4`.

### Summary: concurrency model

**Acme path** (5 tasks): `Agent_Task`, `Acme_Event_Task`, `Plumb_Model_Task`,
`Plumb_Thinking_Task`, `Plumb_Fork_Task`.  All shared mutable state lives in
the `App_State` protected object.  Each task holds its own
`Nine_P.Client.Fs`; connections are never shared between tasks.

**GUI path** (2 tasks): Main Ada task (GTK event loop) + `Agent_Task`.  The
agent communicates with GTK via the `Coyote_GUI.Updates` protected queue
(8 192 items); GTK communicates back via `Coyote_GUI.Prompt_Queue` (64 items).

**Critical rule:** Never share a `Nine_P.Client.Fs` or `Nine_P.Client.File`
between tasks.  All GTK widget operations must execute on the main Ada task.

### Dispatch

`Dispatch_Event` in `Coyote_App.Dispatch` maps each incoming
`LLM.Events.Agent_Event'Class` value to the appropriate `Frontend'Class`
calls.  Both the Acme and GUI paths share the same dispatcher.  See
`design/coyote-design.md §5.3` for the full dispatch table.
## Plumb Token Schema

Coyote uses its own family of plumb tokens. All token strings begin with a
`coyote-` prefix so they are distinct from the `model+`, `thinking+`, and
`llm-chat+` tokens used by pi-acme.

| Token | Plumb port | Purpose |
|---|---|---|
| `coyote-model+PID/PROVIDER/ID` | `/coyote-model` | Switch the active model in the running instance identified by PID |
| `coyote-session+UUID` | launches `coyote --session UUID` | Load a session; the plumber spawns a new `coyote` process |
| `coyote-session+UUID/tool/TOKEN` | launches `bin/coyote_open` | Open a tool-call detail window; TOKEN is the first 16 hex chars of SHA-256(tool_call_id) |
| `coyote-thinking+PID/LEVEL` | `/coyote-thinking` | Set the reasoning level in the running instance identified by PID |
| `coyote-fork+PID/UUID/N` | `/coyote-fork` | Fork the session at turn N in the running instance identified by PID |

**Design notes:**

- Session tokens (`coyote-session+UUID`) carry **no PID**. The plumber always
  launches a fresh `coyote --session UUID` process rather than routing to a
  running instance. Consequently, there is no `Plumb_Session_Task` in coyote.
- Model, thinking, and fork tokens are PID-tagged because they must target a
  specific running window.
- `bin/coyote_open` is a native Ada binary, not a shell script.
- Plumb tokens are only meaningful in the acme frontend path; the GUI frontend
  does not read plumb ports.


## Environment Variables

Coyote uses the following `COYOTE_*` environment variables for inter-process
communication and context propagation:

| Variable | Set by | Consumed by | Purpose |
|---|---|---|---|
| `COYOTE_SESSION_ID` | `coyote.adb` after session creation | child processes | Session lineage: child coyotes promote this to `COYOTE_PARENT_SESSION` so their sessions record a parent link |
| `COYOTE_PARENT_SESSION` | child coyote at startup | `LLM.Session_Store` | Written into the new session's JSONL header as `parentSession` |
| `COYOTE_NO_SESSION` | `coyote.adb` when `--no-session` is active | child coyote at startup | Propagates `--no-session` to all descendant coyote processes |
| `COYOTE_FRONTEND` | GUI `coyote.adb` after selecting GUI frontend | child coyote at startup | When set to `gui`, a child selects the GUI frontend and opens its own GTK window. Mirrors how `$winid` propagates the acme context. |

## Subagent invocation (shell-based)

The dedicated built-in spawn_subagent tool has been removed. Instead, subagents should be launched by invoking the coyote binary itself via the shell tool or a shell pipeline. This preserves session lineage and makes prompt passing robust for long or preprocessed prompts.

Key points:

- Canonical invocation: pipe the prompt to stdin and use `--subagent --prompt -`:

  ```
  printf 'Review the following code...\n' | coyote --subagent --prompt -
  ```

  `--subagent` opens a new terminal/acme window (inheriting `COYOTE_FRONTEND=gui`
  or `$winid`) and exits after one turn.  The shell tool call returns quickly with
  empty output; the work happens in the new window.

  You may also pass `--model PROVIDER/ID`, `--agent TEXT|@PATH`, and `--name LABEL`
  to control the spawned instance.

- Prompt preprocessing: use standard filters or macro preprocessors before piping
  to coyote. For example, with m4:

  ```
  printf 'include(tmpl.m4)' | m4 | coyote --subagent --prompt -
  ```

  Or with environment substitution:

  ```
  envsubst < tmpl.txt | coyote --subagent --prompt -
  ```

- Session lineage: on startup coyote will auto-promote an inherited
  `COYOTE_SESSION_ID` to `COYOTE_PARENT_SESSION` when `COYOTE_PARENT_SESSION` is
  not already set.  This ensures child sessions record their `parentSession`
  automatically when launched from a parent coyote process.

- Abort semantics: the shell tool implementation sends SIGTERM (signal 15) to the
  child process group on abort (via `kill(-pid, SIGTERM)`), so spawned coyotes and
  their descendants are given a chance to terminate gracefully.  Note: SIGTERM can
  be caught or ignored; it is not SIGKILL.

## 9P / Acme VFS Conventions

- The acme namespace is mounted with `Ns_Mount ("acme")`.
- The plumb namespace is mounted with `Ns_Mount ("plumb")`.
- Window control is done by writing to `/N/ctl`, body via addr=$ + `/N/data`,
  tag via `/N/tag`, and events are read from `/N/event`.
- `Acme.Window` operations take an explicit `not null access Nine_P.Client.Fs`
  so each task can pass its own connection — **never share an `Fs` across
  tasks**.

## Native Agent Event Flow

`LLM.Agent` drives the in-process agentic loop, emitting
`LLM.Events.Agent_Event'Class` values synchronously to the `On_Event`
callback (`Dispatch_Event` in `Coyote_App.Dispatch`), which maps them to
`Frontend'Class` primitives.

The full event hierarchy is in `src/llm/llm-events.ads`.  The dispatch table
(event type → frontend calls) is in `design/coyote-design.md §5.3`.
## Adding a New LLM Provider

To add a new provider (e.g. `my-provider`), touch these files in order:

1. **`src/llm/llm-settings.adb`** — Add the provider name to
   `Standard_Env_Name` so `Resolve_Api_Key ("my-provider")` checks the right
   env var. (If the provider needs config beyond an API key, extend
   `Find_Provider_Config` or add a dedicated resolution function.)

2. **`src/llm/llm-providers-my_provider.ads/.adb`** — Provider package. Either:
   - A thin routing provider that delegates to `OpenAI_Completions` and/or
     `Anthropic_Messages` (like `GitHub_Copilot` or `OpenCode_Go` does), **or**
   - A direct subclass of `OpenAI_Completions.Provider` with `Create` and
     `Customize_Request` overrides (like `OpenRouter`), **or**
   - A standalone `Provider` descendant with its own wire format.

3. **`src/llm/llm-providers-my_provider-catalogue.ads/.adb`** (optional) — If
   the provider has a `/models` endpoint, build a catalogue package modelled on
   `OpenRouter.Catalogue`: fetch from the live API, cache to
   `~/.coyote/my_provider_models_cache.json`, parse into a
   `Catalogue_Vectors.Vector`.

4. **`src/llm/llm-model_registry.ads/.adb`** — Add `Refresh_My_Provider`,
   `Has_My_Provider_Key`, and a `To_Model_Info` conversion from the catalogue
   type.  Update `Available_Models` to include the provider when keyed, and
   update `Lookup` to provide a default fallback for unknown model IDs of this
   provider.

5. **`src/llm/llm-agent.adb`** — Three changes:
   - Add `with LLM.Providers.My_Provider;`
   - Add `LLM.Model_Registry.Refresh_My_Provider;` in `Create` (around line
     1098, next to the other Refresh calls)
   - Add an `elsif` branch in **two places**: the agentic loop dispatch
     (≈line 1490) and the summarisation dispatch (≈line 1282). Both follow
     the same pattern — create the provider, call `Send` or `Send_With_Retry`.

6. **`coyote.gpr`** — No changes needed; `for Source_Dirs` already includes
   `src/llm/`, so new files there are picked up automatically.

### Wire format routing

Providers that serve models on both OpenAI and Anthropic wire formats (like
GitHub Copilot and OpenCode Go) use a routing pattern: the provider's `Send`
checks the model ID against a known set, constructs the appropriate delegate
(`OpenAI_Completions.Provider` or `Anthropic_Messages.Provider`), and forwards
the request. See `LLM.Providers.GitHub_Copilot.Send` for the reference
implementation.

### Model_Info fields

`LLM.Model_Registry.Model_Info` records carry a `Wire_Format` field
(`"openai-completions"` or `"anthropic-messages"`) that determines tool JSON
shape in `Build_Tools_Json` (llm-agent.adb ≈line 497). Catalogue packages
must set this field; routing providers set it dynamically.

### API key resolution

`Resolve_Api_Key` checks in order: (1) literal `apiKey` in
`~/.coyote/models.json`, (2) `${ENV_VAR}` interpolation in models.json, (3)
the `Standard_Env_Name` fallback. Add the provider to `Standard_Env_Name` so
step 3 works out of the box.

## Structured Software Developer

**Always load the `structured-sw-developer` skill at the start of any software
development engagement on this project.** The skill is located at
`/home/gtnoble/.coyote/skills/structured-sw-developer/SKILL.md`. It defines
the MIL-STD-498-based process framework used throughout this project — planning,
requirements, design, implementation, testing, configuration management, and
quality assurance obligations — and must be loaded before undertaking any
non-trivial development task.

## Throwaway Scripts

**Always load the `throwaway-scripts` skill before issuing the first shell
tool call on any data-exploration, scripting, or investigation task.** The
skill is located at
`/home/gtnoble/.coyote/skills/throwaway-scripts/SKILL.md`. Skipping it is
the primary cause of repetitive exploratory call loops that waste 3–5 tool
calls.

## Ada Style Guide

**Always load the `ada-style-guide` skill before reading, writing, or reviewing
any Ada source in this project.** The skill is located at
`/home/gtnoble/.pi/agent/skills/ada-style-guide/SKILL.md`. All code must
conform to the guidelines it defines.

## Coding Conventions

- Follow existing Ada style: two-space indentation, `--  double-dash`
  comments, package specs fully document the public API.
- New packages should mirror the existing split: `.ads` holds the spec with
  complete comments, `.adb` holds the body.
- Prefer `Ada.Strings.Unbounded.Unbounded_String` for variable-length strings
  stored in records; use plain `String` for transient values.
- Protected objects and task types should be declared as `type`s (not
  singletons) so they can be tested in isolation.
- Never share a `Nine_P.Client.Fs` or `Nine_P.Client.File` between tasks.
- Error handling: catch exceptions at task boundaries; in the acme path append
  a `[!] ...` line to the window, in the GUI path call
  `My_Frontend.Append_Notice (Error, ...)`.  Always signal shutdown.
- `GNATCOLL.JSON` is the JSON library; use `Read` / `Get_Str` / `Get_Int`
  helpers.
- **UC_* glyph constants** (bullet, box-drawing, gear, check, cross, arrow,
  ellipsis, etc.) must always be taken from `Coyote_App.Utils`, not defined
  locally and never expressed as raw Unicode string literals in Ada `String`
  values (Ada's `Character` type is Latin-1; code points > 255 require UTF-8
  multi-byte encoding via `Character'Val` sequences, which is what the `UC_*`
  constants provide).
- **GUI frontend** uses `Coyote_App.Frontend.GUI.Instance` which is initialised
  by calling `Coyote_App.Frontend.GUI.Create` from the GTK main task.  The GTK
  main loop (`Gtk.Main.Main`) blocks the main Ada task; the agent runs in
  `Agent_Task`.  No `entry Start` / select-terminate pattern is needed.

## Shell Tool Usage

- **Never use inline code mode** when a tool or command supports a `stdin`
  parameter. Always pass code via `stdin` instead.
- **Perl specifically:** never use `perl -e '...'` or `perl -E '...'` to run
  inline code. Always invoke `perl` (or `perl -0777 -i -pe`, etc.) without
  inline code arguments and supply the script body through the `stdin` field.
- The same principle applies to any other interpreter or tool that accepts
  code via standard input (e.g. `python`, `awk`, `sed` scripts): prefer
  `stdin` over embedding code in the command string.
- **Always load the `hed` skill before editing or writing any file.** The skill is at `/home/gtnoble/.coyote/skills/hed-tools/SKILL.md`. `hed` is a portable `ed(1)` with agent-oriented extensions; always invoke it as `hed -M` for deferred-write, transactional, machine-mode edits.

## Testing

The Test Plan (`plan/test-plan.md`) is the governing document for test scope,
environment, traceability, and the current test baseline (665 tests, all green).

Tests live in `test/src/` and use AUnit. Run the full suite:
```sh
cd test && alr run coyote_test
```

Integration tests that need a live acme/9P server or live LLM provider are
opt-in via environment-variable guards. See `plan/integration-test-guide.md`
for setup instructions.

When adding new functionality, add unit tests first (TDD preferred).
Integration tests that require live external services must be guarded and
clearly marked.

**GUI frontend test note:** `Coyote_App.Frontend.GUI.Instance` has no
background task; it is driven entirely by the GTK main loop.  Unit tests that
exercise `Coyote_GUI.Buffer` can create a `GtkTextBuffer` directly (or mock
it) without starting a GTK window.

When a test is added or changed, update the test-count baseline in
`plan/test-plan.md §7`.
## Definition of Done

A feature is **not complete** until all of the following are satisfied:

1. **Tests written and passing** — every new public subprogram or behaviour
   must have corresponding AUnit tests in `test/src/`. Run the full test suite
   (`cd test && alr run coyote_test`) and confirm all tests pass before
   declaring the work done.
2. **Existing tests still pass** — no regressions. The full suite must remain
   green after the change.
3. **Documentation updated** — any user-visible behaviour, CLI flag, plumb
   token, event type, or public API change must be reflected in the relevant
   structured documents: SRS-CORE for capability changes, SDD-CORE for design
   changes, SDD-SQC/SRS-SQC for coyote_sqc changes, `plan/test-plan.md` for
   test-scope changes, and `AGENTS.md` for agent operational guidance. New
   source files must be added to `design/coyote-design.md §4.1`.

## Editing Discipline

Before making any code edits:
**Before making any edits, load the `hed` skill** (`/home/gtnoble/.coyote/skills/hed-tools/SKILL.md`) to ensure the correct file-editing tool is selected. Always invoke `hed` with `-M` (machine/agent mode) for safe, transactional edits.


1. **Map every affected site first.** Identify all call sites, declaration
   sites, and test files that will need changing. Read enough context at each
   site to confirm the surrounding scope (which procedure, which package, what
   indentation) before writing a single edit.

2. **Verify structural assumptions explicitly.** Never assume a variable
   declared in one procedure is visible at a call site in another. Grep for the
   containing procedure of each call site and confirm it matches expectations.

3. **Watch for irregular formatting.** Source files may contain mis-indented or
   otherwise non-standard constructs that defeat pattern-matching greps (e.g.
   `^   procedure` missing a call site indented with 6 spaces). If a grep
   returns fewer hits than expected, investigate before proceeding.

4. **Plan all changes before executing any.** Collect the full list of edits —
   including every call site, declaration, spec, and test — then execute them
   in one coherent pass (bottom-to-top when inserting lines to keep line
   numbers stable), rather than making incremental edits that shift line
   numbers and require re-greps.
