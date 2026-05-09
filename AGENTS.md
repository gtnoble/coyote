# coyote — Agent Instructions

## Project Overview

The project is an acme text editor frontend for a native Ada coding-agent
harness. The frontend opens a `+coyote` acme window, runs the in-process
`LLM.Agent` loop, and renders streaming model/tool output inside acme.

**plan9port** (acme, plumber, 9P utilities) is installed at
`/usr/local/plan9`. The `PLAN9` environment variable should point there;
binaries such as `acmeevent` live in `/usr/local/plan9/bin/`.

Three executables are built:
- `bin/coyote` — the main frontend (opens a `+coyote` acme window)
- `bin/coyote_list_sessions` — lists saved sessions for the current directory
- `bin/coyote_open` — opens a tool-call detail window; launched by the plumber
  for `coyote-session+UUID/tool/TOKEN` links

## Documentation

- `docs/agent-definitions.md` — full reference for the `AGENT.md` file format
  (frontmatter fields, body, discovery roots, shadowing, usage with `--agent`
  and `spawn_subagent`)
- `docs/skills.md` — full reference for the `SKILL.md` file format
  (frontmatter fields, discovery roots, shadowing, writing effective
  descriptions and bodies)

When authoring or editing a `SKILL.md` or `AGENT.md` for this project, load
the `coyote-skill-author` skill for a condensed quick-reference.

## Language & Build System

- **Language:** Ada 2022 (GNAT/GCC)
- **Build system:** [Alire](https://alire.ada.dev/) (`alr`) with a GPRbuild
  project (`coyote.gpr`)
- **Dependencies:**
  - `gnatcoll` ≥ 25.0.0 (JSON, OS, process utilities)
  - system `libcurl` development headers (`libcurl4-openssl-dev` on Debian /
    Ubuntu) for the native HTTP/SSE client

### Build commands

```sh
# Build (development profile, default)
alr build

# Build release
alr build --release

# Run tests
cd test && alr run coyote_test
```

Object files go to `obj/<profile>/`, binaries to `bin/`.

## Source Layout

```
src/
  coyote.adb            -- Entry point; parses --session / --model / --agent /
                        --   --custom-prompt / --no-tools / --no-session /
                        --   --prompt / --one-shot / --name / --prompt-filter flags
  coyote_app.ads/.adb   -- App_State, options, acme/plumb tasks, Run procedure
  coyote_app-dispatch.ads/.adb -- Dispatch_Event: native LLM event → acme window
  coyote_app-history.ads/.adb  -- Session JSONL replay into the acme window
  coyote_app-utils.ads/.adb    -- Pure utility functions (formatting, token
                        --   helpers, turn footer builders, JSON helpers,
                        --   Apply_Prompt_Filter)
  coyote_utils.ads/.adb -- Small utilities shared across entry points
                        --   (CLI arg resolution, session prefix stripping)
  acme.ads/.adb          -- Root package; Win_File_Path helper
  acme-window.ads/.adb   -- Acme window operations over Nine_P (Append, Ctl, etc.)
  acme-event_parser.ads/.adb  -- Parses acme event-file records
  acme-raw_events.ads/.adb    -- Low-level raw event byte feeding / Next_Event
  nine_p.ads             -- 9P2000 constants, Qid, Byte_Array, Byte_Vectors
  nine_p-proto.ads/.adb  -- 9P message encode/decode
  nine_p-client.ads/.adb -- 9P client: Ns_Mount, Open, Read_Once, Write, Clunk
  session_lister.ads/.adb -- Reads ~/.coyote/sessions/ for coyote_list_sessions
  llm/
    llm.ads                     -- Root package
    llm-types.ads/.adb          -- Messages, content blocks, usage, model costs
    llm-events.ads              -- Native event hierarchy (Agent_Event hierarchy)
    llm-sse.ads/.adb            -- Server-Sent Events parser
    llm-settings.ads/.adb       -- ~/.coyote/settings.json and models.json
    llm-auth.ads/.adb           -- auth.json loading and saving
    llm-auth-github_copilot.ads/.adb -- Copilot token refresh helpers
    llm-model_registry.ads/.adb -- In-memory model catalogue registry
    llm-providers.ads           -- Abstract provider interface
    llm-http.ads/.adb           -- libcurl-backed streaming HTTP client
    llm-http-curl_binding.ads/.adb -- thin libcurl binding + callback shim
    llm-providers-openai_completions.ads/.adb -- OpenAI chat-completions wire
    llm-providers-anthropic_messages.ads/.adb -- Anthropic messages wire
    llm-providers-openrouter.ads/.adb -- OpenRouter adapter
    llm-providers-openrouter-catalogue.ads/.adb -- OpenRouter model cache
    llm-providers-opencode_go.ads/.adb -- OpenCode Go provider adapter
    llm-providers-opencode_go-catalogue.ads/.adb -- OpenCode Go model cache
    llm-providers-github_copilot.ads/.adb -- Copilot provider adapter
    llm-providers-github_copilot-catalogue.ads/.adb -- Copilot model cache
    llm-tools.ads/.adb          -- Built-in tool descriptors and dispatcher
    llm-tools-bash.ads/.adb     -- bash tool implementation
    llm-tools-file_ops.ads/.adb -- read / write / edit / find / glob tools
    llm-tools-internal.ads      -- Private POSIX bindings for tool implementations
    llm-tools-spawn_subagent.ads/.adb -- spawn_subagent tool implementation
    llm-skills.ads/.adb         -- Skill discovery and system-prompt formatting
    llm-system_prompt.ads/.adb  -- System prompt construction; context loading
    llm-compaction.ads/.adb     -- Context compaction helpers (threshold,
                        --   cut-point, serialisation, file-op tracking)
    llm-session_store.ads/.adb  -- JSONL session persistence
    llm-agent.ads/.adb          -- Native agentic loop
    llm-agent_defs.ads/.adb     -- Agent definition discovery, resolution, formatting
tools/
  coyote_list_sessions.adb   -- Entry point for the session listing utility
  coyote_open.adb            -- Entry point for the tool-call detail window utility
test/src/                -- AUnit-based test suite
```

## Architecture

`Coyote_App.Run` drives the application with five long-lived Ada tasks:

| Task | Responsibility |
|---|---|
| `Agent_Task` | Owns `LLM.Agent.Session`, drives prompts, and calls `Dispatch_Event` to render each `LLM.Events.Agent_Event'Class` value into the acme window |
| `Acme_Event_Task` | Reads the acme window event file via 9P; handles Send/Stop/New/Clear/Models/Sessions/Thinking/Stats tag commands |
| `Plumb_Model_Task` | Reads the `/coyote-model` plumb port; updates the active model via `LLM.Agent.Set_Model` |
| `Plumb_Thinking_Task` | Reads the `/coyote-thinking` plumb port; updates the reasoning level via `LLM.Agent.Set_Thinking` |
| `Plumb_Fork_Task` | Reads the `/coyote-fork` plumb port; forks the session at the requested turn and spawns a new `coyote` window |

All shared mutable state lives in `App_State`, a protected object. Each task
opens its own `Nine_P.Client.Fs` connection to avoid cross-task 9P contention.
The `Addr_Mutex` inside `Acme.Window.Win` serialises the addr→data write pair.

`Dispatch_Event` in `Coyote_App.Dispatch` is the rendering core: it maps each
incoming `LLM.Events.Agent_Event'Class` value to the appropriate acme window
mutation (streaming text, tool summaries, status line updates, etc.).

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

## 9P / Acme VFS Conventions

- The acme namespace is mounted with `Ns_Mount ("acme")`.
- The plumb namespace is mounted with `Ns_Mount ("plumb")`.
- Window control is done by writing to `/N/ctl`, body via addr=$ + `/N/data`,
  tag via `/N/tag`, and events are read from `/N/event`.
- `Acme.Window` operations take an explicit `not null access Nine_P.Client.Fs`
  so each task can pass its own connection — **never share an `Fs` across
  tasks**.

## Native Agent Event Flow

`LLM.Agent` drives the in-process agentic loop. As it runs, it emits
`LLM.Events.Agent_Event'Class` values directly to a callback in `Agent_Task`,
which calls `Dispatch_Event` to render them into the acme window. The full
event hierarchy is defined in `src/llm/llm-events.ads`; key types include
`Agent_Start_Event`, `Agent_End_Event`, `Message_Update_Event`,
`Tool_Execution_Start_Event`, `Tool_Execution_End_Event`, `Message_End_Event`,
`Model_Select_Event`, `Auto_Retry_Start_Event`, `Auto_Compaction_Start_Event`,
and `Session_Stats_Event`.

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
- Error handling: catch exceptions at task boundaries, append a `[!] ...` line
  to the acme window, and signal shutdown where appropriate.
- `GNATCOLL.JSON` is the JSON library; use `Read` / `Get_Str` / `Get_Int`
  helpers.

## Testing

Tests live in `test/src/` and use AUnit. Integration tests that need a live
acme/9P server are in `acme_integration_tests.adb` and
`nine_p_integration_tests.adb`. Future live LLM-provider integration tests are
documented in `docs/integration-test-guide.md` and must remain opt-in via
explicit environment-variable guards.

Run the full suite:
```sh
cd test && alr run coyote_test
```

When adding new functionality, add unit tests first (TDD preferred).
Integration tests that require live external services should be guarded and
clearly marked.

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
   `docs/` file(s) and, where appropriate, in this `AGENTS.md` (e.g. new
   source files added to the Source Layout table, new tasks added to the
   Architecture table).
