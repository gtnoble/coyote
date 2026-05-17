# coyote — Agent Instructions

## Project Overview

The project is a multi-frontend Ada coding-agent harness.  Three frontends are
available and selected automatically at startup:

- **Acme frontend** — opens a `+coyote` acme window and renders streaming
  output there (selected when `$ACME` is set, i.e. when running inside acme).
- **TUI frontend** — ANSI/VT100 terminal UI with a typed conversation buffer,
  vi-style scroll navigation, and `$EDITOR`/`$PAGER` integration (selected
  when stdout is a TTY and `$ACME` is not set).
- **Plain frontend** — line-oriented text output with no ANSI (selected for
  `--one-shot` mode and when stdout is not a TTY, e.g. piped output).

All frontends implement the abstract `Coyote_App.Frontend.Instance` interface
and drive the same `LLM.Agent` agentic loop.

**plan9port** (acme, plumber, 9P utilities) is installed at
`/usr/local/plan9`. The `PLAN9` environment variable should point there;
binaries such as `acmeevent` live in `/usr/local/plan9/bin/`.

Three executables are built:
- `bin/coyote` — the main entry point; selects the appropriate frontend
  (`Acme_Frontend`, `TUI_Frontend`, or `Plain_Frontend`) based on `$ACME` and
  TTY detection, then calls `Coyote_App.Run` or `Coyote_App.Run_TUI`
- `bin/coyote_list_sessions` — lists saved sessions for the current directory
- `bin/coyote_open` — opens a tool-call detail window; launched by the plumber
  for `coyote-session+UUID/tool/TOKEN` links

## Documentation

- `docs/skills.md` — full reference for the `SKILL.md` file format
  (frontmatter fields, discovery roots, shadowing, writing effective
  descriptions and bodies)

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
    rendering in the TUI frontend

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

```
src/
  coyote.adb            -- Entry point; parses --session / --model / --agent /
                        --   --no-tools / --no-session /
                        --   --prompt / --one-shot / --name / --prompt-filter flags;
                        --   detects frontend (Acme/TUI/Plain) and dispatches
                        --   to Coyote_App.Run or Coyote_App.Run_TUI
  coyote_app.ads/.adb   -- App_State, Options (including Frontend_Kind),
                        --   Run (acme path) and Run_TUI (TUI path) procedures;
                        --   inner tasks: Agent_Task, Acme_Event_Task, Plumb_*
  coyote_app-dispatch.ads/.adb -- Dispatch_Event: native LLM event → Frontend'Class
  coyote_app-history.ads/.adb  -- Session JSONL replay via Frontend'Class;
  coyote_app-utils.ads/.adb    -- Pure utility functions (formatting, token
                        --   helpers, turn footer builders, JSON helpers,
                        --   Apply_Prompt_Filter); UC_* Unicode glyph constants
  coyote_app-frontend.ads      -- Abstract Frontend interface (Instance tagged
                        --   limited type): Append_Text, Begin/End_Thinking,
                        --   Begin/End_Tool, Append_Notice, Set_Status,
                        --   Read_Prompt, Shutdown, etc.
  coyote_app-frontend-acme_win.ads/.adb
                        -- Concrete acme window frontend; routes all calls to
                        --   Acme.Window.Win via a per-instance Nine_P.Client.Fs
  coyote_app-frontend-tui.ads/.adb
                        -- Concrete TUI frontend; maintains a typed Segment
                        --   buffer, drives a single ncurses UI_Task for all
                        --   rendering and input; $EDITOR/$PAGER/$fzf integration;
                        --   vi-style navigation; `/` search with `n`/`N` cycling;
                        --   `NO_COLOR` support; Set_Stats_Summary (TUI-specific)
  coyote_tui_terminal.ads/.adb -- Ada bindings to C terminal primitives
                        --   (termios save/restore/raw, TIOCGWINSZ, wcwidth,
                        --   mkstemp, isatty, close fd)
  coyote_tui_terminal_c.c      -- C implementations of all tui_* functions;
                        --   no Ada-accessible symbols; linked into libcoyote.a
  coyote_cmark_c.c     -- C shim for libcmark-gfm: one getter per enum
                        --   constant (`cmark_shim_node_*`, `cmark_shim_list_*`,
                        --   `cmark_shim_event_*`) plus `cmark_shim_get_literal`
                        --   (null-safe literal accessor),
                        --   `cmark_shim_parse_document_gfm` (creates a parser
                        --   with the table / strikethrough / autolink extensions
                        --   attached), `cmark_shim_node_get_type_string` (safe
                        --   wrapper for cmark_node_get_type_string), and
                        --   `cmark_shim_table_row_is_header`; all standard
                        --   enum constants resolved at package elaboration time
                        --   by `Coyote_Cmark`
  coyote_cmark.ads/.adb -- Thin Ada binding to libcmark-gfm: opaque Node_Ptr /
                        --   Iter_Ptr (System.Address), integer enum-constant
                        --   variables initialised from C shim getters, and
                        --   Import bindings to Parse_Document (GFM-extended),
                        --   Node_Free, Node_Get_Type/Literal/Heading_Level/
                        --   List_Type/List_Start, Node_Get_Type_String,
                        --   Table_Row_Is_Header, Node_First_Child, Node_Next,
                        --   Iter_New/Next/Get_Node/Free
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
                        --   image tool results are split: a plain-text stub
                        --   in the tool message + a follow-up user message
                        --   carrying the image_url (OpenAI does not support
                        --   vision content inside role=tool messages)
    llm-providers-anthropic_messages.ads/.adb -- Anthropic messages wire
    llm-providers-openrouter.ads/.adb -- OpenRouter adapter
    llm-providers-openrouter-catalogue.ads/.adb -- OpenRouter model cache
    llm-providers-opencode_go.ads/.adb -- OpenCode Go provider adapter
    llm-providers-opencode_go-catalogue.ads/.adb -- OpenCode Go model cache
    llm-providers-github_copilot.ads/.adb -- Copilot provider adapter
    llm-providers-github_copilot-catalogue.ads/.adb -- Copilot model cache
    llm-tools.ads/.adb          -- Abort_Flag and Pause_Flag control
                        --   primitives; Tool_Descriptor record type
    llm-tools-shell.ads/.adb    -- The shell tool: Descriptor and Execute;
                        --   optional "media_type" arg base64-encodes stdout
                        --   and returns an image content block of that MIME
                        --   type
    llm-tools-temp_file.ads/.adb -- tool-result size cap and threshold policy;
                        --   Truncated writes excess bytes to a temp file
                        --   under /tmp/ and returns an excerpt with a path
                        --   trailer; image results (Media_Type non-empty)
                        --   bypass the cap entirely
    llm-skills.ads/.adb         -- Skill discovery and system-prompt formatting
    llm-system_prompt.ads/.adb  -- System prompt construction; context loading
    llm-compaction.ads/.adb     -- Context compaction helpers (threshold,
                        --   cut-point, serialisation)
    llm-session_store.ads/.adb  -- JSONL session persistence
    llm-agent.ads/.adb          -- Native agentic loop (Session, Run_Prompt,
                        --   Request_Pause, Resume, Is_Paused)
tools/
  coyote_list_sessions.adb   -- Entry point for the session listing utility
  coyote_open.adb            -- Entry point for the tool-call detail window utility
test/src/                -- AUnit-based test suite
```

## Frontend Selection

`coyote.adb` selects the frontend before calling `Run` or `Run_TUI`:

```
--one-shot flag set           → Plain_Frontend  (Coyote_App.Run)
$ACME env var non-empty       → Acme_Frontend   (Coyote_App.Run)
stdout is a TTY               → TUI_Frontend    (Coyote_App.Run_TUI)
otherwise (piped / no TTY)    → Plain_Frontend  (Coyote_App.Run)
```

The selected kind is stored in `Options.Frontend : Frontend_Kind`.
TTY detection is provided by `Coyote_TUI_Terminal.Is_TTY` (calls POSIX
`isatty(STDOUT_FILENO)` via `coyote_tui_terminal_c.c`).

## Architecture

### Acme path — `Coyote_App.Run`

Drives the application with five long-lived Ada tasks:

| Task | Responsibility |
|---|---|
| `Agent_Task` | Owns `LLM.Agent.Session`, drives prompts, calls `Dispatch_Event` to render each `LLM.Events.Agent_Event'Class` value via `Frontend'Class` |
| `Acme_Event_Task` | Reads the acme window event file via 9P; handles Send/Stop/New/Clear/Models/Sessions/Thinking/Stats/Pause/Resume tag commands |
| `Plumb_Model_Task` | Reads the `/coyote-model` plumb port; updates the active model via `LLM.Agent.Set_Model` |
| `Plumb_Thinking_Task` | Reads the `/coyote-thinking` plumb port; updates the reasoning level via `LLM.Agent.Set_Thinking` |
| `Plumb_Fork_Task` | Reads the `/coyote-fork` plumb port; forks the session at the requested turn and spawns a new `coyote` window |

All shared mutable state lives in `App_State`, a protected object. Each task
opens its own `Nine_P.Client.Fs` connection to avoid cross-task 9P contention.
The `Addr_Mutex` inside `Acme.Window.Win` serialises the addr→data write pair.

### TUI path — `Coyote_App.Run_TUI`

A simpler task structure — no acme window, no 9P, no plumb tasks:

| Task | Responsibility |
|---|---|
| `Agent_Task` | Same agent loop as the acme path, but reads prompts via `My_Frontend.Read_Prompt` (blocking on `Prompt_Queue`) instead of `Commands.Dequeue`; receives `:command` strings forwarded from `UI_Task` via `Prompt_Queue`; dispatches them to `LLM.Agent` operations; calls `My_Frontend.Set_Stats_Summary` on `Session_Stats_Event` |
| `UI_Task` (inside `Frontend.TUI`) | Single ncurses task owning all terminal I/O: polls `Wget_Wch`, dispatches vi-style key events, runs `Execute_Command`, launches `$EDITOR`/`$PAGER`/`fzf`, re-renders the segment buffer when `TUI_State.Render_Needed` is set |

`UI_Task` is a package-level task object in `Coyote_App.Frontend.TUI`.  It
declares `entry Start` and uses `select accept Start; or terminate; end select;`
before its main loop so it terminates cleanly when `Create` is never called
(e.g. in the test suite).  `Create` calls `UI_Task.Start` after ncurses init.

### TUI command protocol

When the user types `:verb [args]` in the TUI, `Execute_Command` either handles
the command directly or forwards it to `Prompt_Queue` prefixed with `:`.

Commands handled directly by `Execute_Command`:

| Command | Behaviour |
|---|---|
| `:send [text]` | Send text as prompt (no arg → `$EDITOR`); steers if agent is running |
| `:help` | Open keybinding reference in `$PAGER` |
| `:stats` | Format session stats from the last `Session_Stats_Event` and open in `$PAGER` |
| `:models` | List available models via `LLM.Model_Registry.Available_Models`, pipe through `fzf`; selection enqueues `:model provider/id` |
| `:sessions` | List sessions via `Session_Lister.List_Sessions`, pipe through `fzf`; selection enqueues `:session UUID` |
| `:clear` | Signal re-render |
| `:q` | Shut down |

Commands forwarded to `Prompt_Queue` (handled by `Run_TUI`'s `Agent_Task`):
`:stop`, `:pause`, `:resume`, `:compact`, `:model`, `:thinking`, `:new`, `:session`.

`Run_TUI`'s `Agent_Task` also watches for `Session_Stats_Event` in its
`Track_Event` hook and calls `My_Frontend.Set_Stats_Summary(formatted_text)` —
a TUI-specific (non-overriding) method — so that `:stats` always reflects the
most recent session totals.

### Dispatch

`Dispatch_Event` in `Coyote_App.Dispatch` is the rendering core: it maps each
incoming `LLM.Events.Agent_Event'Class` value to the appropriate
**1. Markdown rendering via `libcmark-gfm`** *(implemented)*
turn footers, notices, etc.).  Both the acme and TUI paths share the same
`Render_Markdown` in `coyote_app-frontend-tui.adb`.  The renderer calls
`Coyote_Cmark.Parse_Document` (which uses `libcmark-gfm` with the GFM
`table`, `strikethrough`, and `autolink` extensions enabled), walks the AST
with `cmark_iter`, and emits ncurses attributes:

- `A_Bold` for `**strong**` and headings (with `#`×level prefix)
- `A_Dim` for `*emphasis*`, fenced code blocks, block quotes, and
  `~~strikethrough~~`
- `A_Reverse` for `` `inline code` ``
- `UC_BULLET / N.` prefixes for unordered / ordered lists
- `UC_HORIZ`×cols for thematic breaks (`---`)
- GFM pipe tables rendered as box-drawn ASCII tables (bold header row,
  `┌─┬─┐` / `├─┼─┤` / `└─┴─┘` borders, column-width auto-fit capped to
  terminal width with `UC_ELLIP` truncation)
- `A_Dim` for `*emphasis*`, fenced code blocks, and block quotes
`Coyote_Cmark` is a thin Ada binding backed by a C shim
(`src/coyote_cmark_c.c`) whose getter functions resolve all
`cmark_node_type`, `cmark_list_type`, and `cmark_event_type` enum values at
package elaboration time — ensuring the values always agree with the installed
`<cmark-gfm.h>` regardless of library version.  Extension node types (table,
table_row, table_cell, strikethrough) are identified by the string returned
by `cmark_node_get_type_string` since their integer IDs are allocated
dynamically.
Streaming segments (`Complete = False`) continue to render via `Wrap_And_Put`
(raw text), preserving live output.

`Coyote_Cmark` is a thin Ada binding backed by a C shim
(`src/coyote_cmark_c.c`) whose trivial getter functions resolve all
`cmark_node_type`, `cmark_list_type`, and `cmark_event_type` enum values at
package elaboration time — ensuring the values always agree with the installed
`<cmark.h>` regardless of library version.

**2. Search — inline character-level match highlighting** *(implemented)*

`/` search, `n`/`N` navigation, viewport jumping, and inline `A_Reverse`
highlighting of the matched substring are all implemented.  `Match_Record`
stores `Byte_Offset` and `Match_Len`; `Wrap_And_Put` accepts `Match_Start`
and `Match_Len` optional parameters and brackets the matching bytes with
`Wattron`/`Wattroff (A_Reverse)`.

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
- Plumb tokens are only meaningful in the acme frontend path; the TUI frontend
  does not read plumb ports.

## Subagent invocation (shell-based)

The dedicated built-in spawn_subagent tool has been removed. Instead, subagents should be launched by invoking the coyote binary itself via the shell tool or a shell pipeline. This preserves session lineage and makes prompt passing robust for long or preprocessed prompts.

Key points:

- Canonical invocation: pipe the prompt to stdin and call coyote with --one-shot and --prompt -

  Example:

  printf 'Review the following code...\n' | coyote --one-shot --prompt -

  You may also pass --model PROVIDER/ID, --agent NAME, and --name LABEL to control the spawned instance.

- Prompt preprocessing: use standard filters or macro preprocessors before piping to coyote. For example, with m4:

  printf 'include(tmpl.m4)' | m4 | coyote --one-shot --prompt -

  Or with environment substitution:

  envsubst < tmpl.txt | coyote --one-shot --prompt -

- Session lineage: on startup coyote will auto-promote an inherited COYOTE_SESSION_ID to COYOTE_PARENT_SESSION when COYOTE_PARENT_SESSION is not already set. This ensures child sessions record their parentSession automatically when launched from a parent coyote process.

- Abort semantics: the shell tool implementation kills the child process group on abort (uses a negative PID kill), so spawned coyotes and their descendants are terminated cleanly if an abort is requested.

- Subagent invocations always select the **Plain** frontend because stdout is a
  pipe, not a TTY, and `--one-shot` is set.

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
which calls `Dispatch_Event` to render them via the active `Frontend'Class`.
The full event hierarchy is defined in `src/llm/llm-events.ads`; key types
include `Agent_Start_Event`, `Agent_End_Event`, `Message_Update_Event`,
`Tool_Execution_Start_Event`, `Tool_Execution_End_Event`, `Message_End_Event`,
`Model_Select_Event`, `Auto_Retry_Start_Event`, `Auto_Compaction_Start_Event`,
`Agent_Paused_Event`, `Agent_Resumed_Event`,
and `Session_Stats_Event`.

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
  a `[!] ...` line to the window, in the TUI path call
  `My_Frontend.Append_Notice (Error, ...)`.  Always signal shutdown.
- `GNATCOLL.JSON` is the JSON library; use `Read` / `Get_Str` / `Get_Int`
  helpers.
- **UC_* glyph constants** (bullet, box-drawing, gear, check, cross, arrow,
  ellipsis, etc.) must always be taken from `Coyote_App.Utils`, not defined
  locally and never expressed as raw Unicode string literals in Ada `String`
  values (Ada's `Character` type is Latin-1; code points > 255 require UTF-8
  multi-byte encoding via `Character'Val` sequences, which is what the `UC_*`
  constants provide).
- **Package-level task objects** that may not be started in every execution
  context (e.g. `UI_Task` in `Coyote_App.Frontend.TUI`)
  must declare `entry Start` and use
  `select accept Start; or terminate; end select;` before their main loop.
  This allows Ada's tasking runtime to terminate them cleanly when `Start` is
  never called — for example in the test suite, which does not instantiate the
  TUI frontend.

## Shell Tool Usage

- **Never use inline code mode** when a tool or command supports a `stdin`
  parameter. Always pass code via `stdin` instead.
- **Perl specifically:** never use `perl -e '...'` or `perl -E '...'` to run
  inline code. Always invoke `perl` (or `perl -0777 -i -pe`, etc.) without
  inline code arguments and supply the script body through the `stdin` field.
- The same principle applies to any other interpreter or tool that accepts
  code via standard input (e.g. `python`, `awk`, `sed` scripts): prefer
  `stdin` over embedding code in the command string.
- **Always load the `oed` skill before editing or writing any file.** The skill is at `/home/gtnoble/.coyote/skills/oed/SKILL.md`. `oed` is a portable `ed(1)` with agent-oriented extensions; always invoke it as `oed -M` for deferred-write, transactional, machine-mode edits.

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

**TUI-specific test note:** The `Coyote_App.Frontend.TUI` package contains
package-level task object (`UI_Task`).  It must not block the test process.
The `select accept Start; or terminate; end select;` pattern (see Coding
Conventions above) is required to keep the test suite from hanging.

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

## Editing Discipline

Before making any code edits:
**Before making any edits, load the `oed` skill** (`/home/gtnoble/.coyote/skills/oed/SKILL.md`) to ensure the correct file-editing tool is selected. Always invoke `oed` with `-M` (machine/agent mode) for safe, transactional edits.


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
