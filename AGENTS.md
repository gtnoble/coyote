# coyote — Agent Instructions

## Project Overview

The project is an acme text editor frontend for a native Ada coding-agent
harness. The frontend opens a `+coyote` acme window, runs the in-process
`LLM.Agent` loop, and renders streaming model/tool output inside acme.

**plan9port** (acme, plumber, 9P utilities) is installed at
`/usr/local/plan9`. The `PLAN9` environment variable should point there;
binaries such as `acmeevent` live in `/usr/local/plan9/bin/`.

Two executables are built:
- `bin/coyote` — the main frontend (opens a `+coyote` acme window)
- `bin/coyote_list_sessions` — lists saved sessions for the current directory

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
  coyote.adb            -- Entry point; parses --session / --model / --agent flags
  coyote_app.ads/.adb   -- App_State, options, acme/plumb tasks, Run procedure
  coyote_app-dispatch.ads/.adb -- Dispatch_Event: native LLM event → acme window
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
    llm-providers-github_copilot.ads/.adb -- Copilot provider adapter
    llm-providers-github_copilot-catalogue.ads/.adb -- Copilot model cache
    llm-tools.ads/.adb          -- Built-in tool descriptors and dispatcher
    llm-tools-bash.ads/.adb     -- bash tool implementation
    llm-tools-file_ops.ads/.adb -- read / write / edit / find / glob tools
    llm-session_store.ads/.adb  -- JSONL session persistence
    llm-agent.ads/.adb          -- Native agentic loop
tools/
  coyote_list_sessions.adb   -- Entry point for the session listing utility
test/src/                -- AUnit-based test suite
```

## Architecture

`Coyote_App.Run` drives the application with five long-lived Ada tasks:

| Task | Responsibility |
|---|---|
| `Agent_Task` | Owns `LLM.Agent.Session`, drives prompts, and calls `Dispatch_Event` to render each `LLM.Events.Agent_Event'Class` value into the acme window |
| `Acme_Event_Task` | Reads the acme window event file via 9P; handles Send/Stop/New/Clear tag commands |
| `Plumb_Model_Task` | Reads the `/pi-model` plumb port; updates the active model via `LLM.Agent.Set_Model` |
| `Plumb_Session_Task` | Reads the `/pi-session` plumb port; switches sessions in-process via `LLM.Agent.Switch_Session` |
| `Plumb_Thinking_Task` | Reads the `/pi-thinking` plumb port; updates the reasoning level via `LLM.Agent.Set_Thinking` |

All shared mutable state lives in `App_State`, a protected object. Each task
opens its own `Nine_P.Client.Fs` connection to avoid cross-task 9P contention.
The `Addr_Mutex` inside `Acme.Window.Win` serialises the addr→data write pair.

`Dispatch_Event` in `Coyote_App.Dispatch` is the rendering core: it maps each
incoming `LLM.Events.Agent_Event'Class` value to the appropriate acme window
mutation (streaming text, tool summaries, status line updates, etc.).

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
