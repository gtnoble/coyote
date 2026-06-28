# coyote Design Description (SDD-CORE)

**Component:** coyote (core agent executable and shared libraries)
**Version:** 1.3
**Date:** 2026-06-28
**Status:** Reviewed ÃÂ¢ÃÂÃÂ project control (M3 complete 2026-06-02)
**Requirements:** `requirements/coyote-requirements.md` (SRS-CORE)
**Project Plan:** `plan/project-plan.md`

---

## Table of Contents

1. [Scope](#1-scope)
2. [Referenced Documents](#2-referenced-documents)
3. [Component-Wide Design Decisions](#3-component-wide-design-decisions)
4. [Architectural Design](#4-architectural-design)
5. [Detailed Design](#5-detailed-design)
6. [Requirements Traceability](#6-requirements-traceability)
7. [Notes](#7-notes)

---

## 1. Scope

**Component identifier:** coyote

This document describes the software design of the coyote core agent: the
design decisions that govern the component as a whole, the structural
decomposition into software units (Ada packages and tasks), the interfaces
among them, the concept of execution, and the detailed design of each major
unit. It covers the `coyote` executable, `coyote_list_sessions`,
`coyote_open`, and the shared library packages in `src/llm/`,
`src/coyote_gui/`, `src/acme*`, and `src/nine_p*`.

The `coyote_sqc` application and `coyote_renderer` shared library are covered
by separate design documents (`design/coyote-sqc-design.md`).

---

## 2. Referenced Documents

| ID | Title | Location |
|---|---|---|
| SRS-CORE | coyote Requirements Specification | `requirements/coyote-requirements.md` |
| PLAN | Project Plan | `plan/project-plan.md` |
| AGENTS | Agent Working Instructions | `AGENTS.md` |
| SRS-SQC | coyote_sqc Requirements Specification | `requirements/coyote-sqc-requirements.md` |

---

## 3. Component-Wide Design Decisions

### 3.1 Behavioral Design

coyote is an event-driven streaming agent. The central behavioral model is:

1. The user supplies a prompt.
2. The agent loop (`LLM.Agent.Run_Prompt`) sends the prompt plus conversation
   history to the active LLM provider.
3. The provider response arrives as a server-sent event stream. The HTTP
   layer (`LLM.HTTP`) feeds raw bytes to the SSE parser (`LLM.SSE`), which
   produces structured events.
4. The provider adapter (e.g. `LLM.Providers.Anthropic_Messages`) maps SSE
   events to `LLM.Events.Agent_Event'Class` values and invokes the `On_Event`
   callback.
5. The callback is `Dispatch_Event` in `Coyote_App.Dispatch`, which maps
   each event type to the appropriate `Frontend'Class` primitive calls.
6. If the model requests a tool call, the agent loop executes the tool and
   sends a new request with the tool result appended to the history.
7. The loop continues until the model produces a final response with no
   further tool calls, or until the user aborts.

This model has two key properties:
- **Streaming is the primary path.** Display of text does not wait for the
  full response; tokens appear as they arrive.
- **The frontend is a pure sink.** No LLM-specific logic appears in any
  frontend implementation. `LLM.Agent` emits typed events; `Dispatch_Event`
  translates them to frontend primitives; each frontend renders them.

### 3.2 Error and Exception Handling

Errors are classified into three handling tiers:

1. **Recoverable provider errors** (transient HTTP failures, rate limits) ÃÂ¢ÃÂÃÂ
   the agent loop retries up to three times with exponential backoff. Each
   retry emits an `Auto_Retry_Start_Event` visible to the user.

2. **Non-recoverable turn errors** (malformed JSON, authentication failure,
   context overflow) ÃÂ¢ÃÂÃÂ the agent loop terminates the current turn, records
   the error in the `App_State` protected object, and emits an error notice
   to the frontend via `Dispatch_Event`.

3. **Task boundary exceptions** ÃÂ¢ÃÂÃÂ any unhandled exception in `Agent_Task`
   is caught at the task body boundary, logged to stderr, appended as an
   error notice to the frontend, and triggers a graceful shutdown sequence.

### 3.3 Concurrency Model

The application has two execution paths with different task structures.

**Acme path** ÃÂ¢ÃÂÃÂ five long-lived Ada tasks:

| Task | Owns |
|---|---|
| `Agent_Task` | `LLM.Agent.Session`; the agentic loop |
| `Acme_Event_Task` | 9P event-file reader; tag command dispatch |
| `Plumb_Model_Task` | `/coyote-model` plumb port reader |
| `Plumb_Thinking_Task` | `/coyote-thinking` plumb port reader |
| `Plumb_Fork_Task` | `/coyote-fork` plumb port reader |

**GUI path** ÃÂ¢ÃÂÃÂ two tasks:

| Task | Owns |
|---|---|
| Main Ada task | GTK event loop (`Gtk.Main.Main`) |
| `Agent_Task` | `LLM.Agent.Session`; the agentic loop |

**Shared-state rule:** All inter-task mutable state is held in the
`App_State` protected object. Tasks never share `Nine_P.Client.Fs` instances
(each task that accesses the 9P VFS creates its own connection).

**GTK thread safety:** All GTK operations execute on the main Ada task. The
`Agent_Task` communicates with the GTK main loop through two thread-safe
protected queues: `Coyote_GUI.Updates` (agent ÃÂ¢ÃÂÃÂ GTK, bounded at 8192 items)
and `Coyote_GUI.Prompt_Queue` (GTK ÃÂ¢ÃÂÃÂ agent, bounded at 64 items). A GLib
idle callback drains `Updates` on the GTK thread.

### 3.4 External Interface Design Decisions

**HTTP and SSE:** The HTTP client is a native libcurl binding
(`LLM.HTTP.Curl_Binding`). Streaming is driven by the libcurl write callback
in the calling task; the SSE parser is called synchronously from that callback.
No additional thread is created for HTTP I/O.

**9P (acme):** The acme window and plumb ports are accessed via the plan9port
9P client (`Nine_P.Client`). Each connection is established by calling
`Ns_Mount ("acme")` or `Ns_Mount ("plumb")` from the task that will use it.

**GTK3:** All GTK3 calls use Ada bindings from the GtkAda library. `Gtk.Main.Init`
and `Gtk.Main.Main` are called from the main Ada task.

**Markdown rendering:** The GUI frontend renders completed assistant text blocks
using libcmark-gfm (via the `Coyote_Cmark` Ada binding and the `coyote_cmark_c.c`
C shim). Enum constants are resolved once at package elaboration time via the
C shim's getter functions. Raw streamed tokens are inserted as plain text and
replaced with Pango markup when the block completes (`End_Text_Block`).

### 3.5 Output Media and Formats

- **Acme frontend:** Plain UTF-8 text written to the acme window body via
  9P. Box-drawing and other glyphs use the `UC_*` constants defined in
  `Coyote_App.Utils`. Tool-call plumb tokens (`coyote-session+UUID/tool/TOKEN`)
  are embedded in the window body for button-3 navigation.

- **GUI frontend:** GTK3 `GtkTextBuffer` with text tags for emphasis,
  code, thinking, notices, and footers. Tool calls are embedded as
  `GtkTextChildAnchor` widgets (GTK frames). Markdown is rendered via
  libcmark-gfm ÃÂ¢ÃÂÃÂ Pango markup ÃÂ¢ÃÂÃÂ `Insert_Markup`.

- **Plain frontend:** Plain UTF-8 to stdout. No ANSI escape codes.

### 3.6 Reuse of Shared Data and Services

- **Session persistence:** All three execution paths share `LLM.Session_Store`
  for JSONL read and write.
- **Skill discovery:** All three paths share `LLM.Skills.Load_Skills` and
  `Format_Skills_For_Prompt`.
- **Settings:** All three paths share `LLM.Settings.Load` and
  `LLM.Auth.Load`.
- **Model registry:** All three paths share `LLM.Model_Registry`.
- **Dispatch:** All three paths share `Coyote_App.Dispatch.Dispatch_Event`.
  The GUI path also calls `Coyote_App.Frontend.GUI.Set_Stats_Summary` on
  `Session_Stats_Event` for the menu-item display; this is a GUI-specific
  extension beyond the abstract interface.

---


### 3.7 Memory and Processing Allocation

**Queue bounds:**
- `Coyote_GUI.Updates` ÃÂ¢ÃÂÃÂ bounded at 8 192 items. Each item is a
  `Coyote_GUI.Update` record (kind discriminant + one Unbounded_String payload).
  The bound was chosen to allow several full streaming turns to be buffered
  without back-pressure while keeping per-session RSS impact below ~1 MB.
- `Coyote_GUI.Prompt_Queue` ÃÂ¢ÃÂÃÂ bounded at 64 items. Commands are short strings;
  a small bound is sufficient because prompt entry is rate-limited by human
  interaction speed.

**Task stacks:** All tasks use the default GNAT runtime stack size (8 MiB on
Linux x86-64). No task has been observed to approach this limit; no explicit
`Storage_Size` clause is needed.

**9P connection per task:** Each task that accesses the acme or plumb 9P
namespace holds one `Nine_P.Client.Fs` instance. On the Acme path, five tasks
each hold one `Fs`; each `Fs` requires one UNIX socket file descriptor and an
internal 8 KiB message buffer.

**libcurl handle per request:** `LLM.HTTP.Post_Stream` creates and destroys
one `CURL` handle per HTTP request. No handle pool is maintained. This avoids
connection-reuse state across retries while keeping the implementation simple.

**Session JSONL file:** Held open for append throughout the session lifetime.
One file descriptor per running `coyote` process. File size is bounded only
by conversation length; no rotation or size cap is applied.

**In-memory history:** `LLM.Types.Message_Vectors.Vector` grows unboundedly
until compaction. Compaction (`LLM.Compaction.Find_Cut_Point`) is triggered
when the estimated token count of the history approaches the model's context
window minus the `Reserve_Tokens` margin (default 16 384).

## 4. Architectural Design

### 4.1 Software Unit Inventory

| Unit | Type | Source files |
|---|---|---|
| `Coyote` | Entry point | `src/coyote.adb` |
| `Coyote_App` | App state + entry procedures | `src/coyote_app.ads/.adb` |
| `Coyote_App.Dispatch` | EventÃÂ¢ÃÂÃÂfrontend dispatch | `src/coyote_app-dispatch.ads/.adb` |
| `Coyote_App.History` | Session replay | `src/coyote_app-history.ads/.adb` |
| `Coyote_App.Utils` | Formatting utilities + UC_* glyphs | `src/coyote_app-utils.ads/.adb` |
| `Coyote_App.Frontend` | Abstract frontend interface | `src/coyote_app-frontend.ads` |
| `Coyote_App.Frontend.Acme_Win` | Acme frontend implementation | `src/coyote_app-frontend-acme_win.ads/.adb` |
| `Coyote_App.Frontend.GUI` | GTK3 frontend implementation | `src/coyote_app-frontend-gui.ads/.adb` |
| `Coyote_App.Frontend.Plain` | Plain-text frontend implementation | `src/coyote_app-frontend-plain.ads/.adb` |
| `Coyote_GUI` | GUI root (Update_Kind, Update record) | `src/coyote_gui/coyote_gui.ads` |
| `Coyote_GUI.Updates` | Protected agentÃÂ¢ÃÂÃÂGTK queue | `src/coyote_gui/coyote_gui-updates.ads/.adb` |
| `Coyote_GUI.Prompt_Queue` | Protected GTKÃÂ¢ÃÂÃÂagent queue | `src/coyote_gui/coyote_gui-prompt_queue.ads/.adb` |
| `Coyote_GUI.Buffer` | GtkTextBuffer wrapper + markdown rendering | `src/coyote_gui/coyote_gui-buffer.ads/.adb` |
| `Coyote_Utils` | CLI arg resolution, file reading, session prefix stripping | `src/coyote_utils.ads/.adb` |
| `LLM` | Root package | `src/llm/llm.ads` |
| `LLM.Types` | Message, content block, usage types | `src/llm/llm-types.ads/.adb` |
| `LLM.Events` | Agent event hierarchy | `src/llm/llm-events.ads` |
| `LLM.SSE` | Server-sent event parser | `src/llm/llm-sse.ads/.adb` |
| `LLM.Settings` | Configuration file loading | `src/llm/llm-settings.ads/.adb` |
| `LLM.Auth` | Auth token loading and saving | `src/llm/llm-auth.ads/.adb` |
| `LLM.Auth.GitHub_Copilot` | Copilot token refresh | `src/llm/llm-auth-github_copilot.ads/.adb` |
| `LLM.Model_Registry` | In-memory model catalogue | `src/llm/llm-model_registry.ads/.adb` |
| `LLM.Providers` | Abstract provider interface | `src/llm/llm-providers.ads` |
| `LLM.HTTP` | libcurl-backed streaming HTTP client | `src/llm/llm-http.ads/.adb` |
| `LLM.HTTP.Curl_Binding` | Thin libcurl binding | `src/llm/llm-http-curl_binding.ads/.adb` |
| `LLM.Providers.OpenAI_Completions` | OpenAI Chat Completions wire | `src/llm/llm-providers-openai_completions.ads/.adb` |
| `LLM.Providers.Anthropic_Messages` | Anthropic Messages wire | `src/llm/llm-providers-anthropic_messages.ads/.adb` |
| `LLM.Providers.OpenRouter` | OpenRouter adapter | `src/llm/llm-providers-openrouter.ads/.adb` |
| `LLM.Providers.GitHub_Copilot` | Copilot routing provider | `src/llm/llm-providers-github_copilot.ads/.adb` |
| `LLM.Providers.OpenCode_Go` | OpenCode Go routing provider | `src/llm/llm-providers-opencode_go.ads/.adb` |
| `LLM.Tools` | Abort_Flag, Pause_Flag, Tool_Descriptor | `src/llm/llm-tools.ads/.adb` |
| `LLM.Tools.Shell` | Built-in shell tool | `src/llm/llm-tools-shell.ads/.adb` |
| `LLM.Tools.Temp_File` | Tool-result size cap and spill | `src/llm/llm-tools-temp_file.ads/.adb` |
| `LLM.Skills` | Skill discovery and system prompt formatting | `src/llm/llm-skills.ads/.adb` |
| `LLM.System_Prompt` | System prompt construction | `src/llm/llm-system_prompt.ads/.adb` |
| `LLM.Compaction` | Context compaction helpers | `src/llm/llm-compaction.ads/.adb` |
| `LLM.Session_Store` | JSONL session persistence | `src/llm/llm-session_store.ads/.adb` |
| `LLM.Agent` | Native agentic loop | `src/llm/llm-agent.ads/.adb` |
| `Acme` | Root; Win_File_Path helper | `src/acme.ads/.adb` |
| `Acme.Window` | Acme window operations | `src/acme-window.ads/.adb` |
| `Acme.Event_Parser` | Acme event-file record parser | `src/acme-event_parser.ads/.adb` |
| `Acme.Raw_Events` | Low-level raw event byte feeding | `src/acme-raw_events.ads/.adb` |
| `Nine_P` | 9P2000 constants, Qid, Byte_Array | `src/nine_p.ads` |
| `Nine_P.Proto` | 9P message encode/decode | `src/nine_p-proto.ads/.adb` |
| `Nine_P.Client` | 9P client: mount, open, read, write | `src/nine_p-client.ads/.adb` |
| `Coyote_Cmark` | Ada binding to libcmark-gfm | `src/coyote_cmark.ads/.adb` |
| `Session_Lister` | Session listing for coyote_list_sessions | `src/session_lister.ads/.adb` |

### 4.2 Static Relationships

The dependency hierarchy flows from the application entry points down through
three layers:

```
[Entry points]
  Coyote (coyote.adb)
  Coyote_List_Sessions (tools/coyote_list_sessions.adb)
  Coyote_Open (tools/coyote_open.adb)
        ÃÂ¢ÃÂÃÂ
        ÃÂ¢ÃÂÃÂ¼
[Application orchestration]
  Coyote_App ÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂº Coyote_App.Frontend (abstract)
  Coyote_App.Dispatch ÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂº Coyote_App.Frontend'Class
  Coyote_App.History  ÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂº LLM.Session_Store, Coyote_App.Frontend'Class
  Coyote_App.Utils
        ÃÂ¢ÃÂÃÂ
        ÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂº Coyote_App.Frontend.Acme_Win ÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂº Acme.Window, Nine_P.Client
        ÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂº Coyote_App.Frontend.GUI ÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂº Coyote_GUI.Buffer, Coyote_GUI.Updates,
        ÃÂ¢ÃÂÃÂ                                  Coyote_GUI.Prompt_Queue
        ÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂº Coyote_App.Frontend.Plain
        ÃÂ¢ÃÂÃÂ
        ÃÂ¢ÃÂÃÂ¼
[Agent layer]
  LLM.Agent ÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂº LLM.Providers'Class, LLM.Tools, LLM.Compaction,
                LLM.Session_Store, LLM.Model_Registry, LLM.Skills,
                LLM.System_Prompt, LLM.Types, LLM.Events
        ÃÂ¢ÃÂÃÂ
        ÃÂ¢ÃÂÃÂ¼
[Provider layer]
  LLM.Providers.OpenAI_Completions ÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂº LLM.HTTP, LLM.SSE, LLM.Types
  LLM.Providers.Anthropic_Messages ÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂº LLM.HTTP, LLM.SSE, LLM.Types
  LLM.Providers.OpenRouter         ÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂº LLM.Providers.OpenAI_Completions
  LLM.Providers.GitHub_Copilot     ÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂº LLM.Providers.OpenAI_Completions,
                                        LLM.Providers.Anthropic_Messages,
                                        LLM.Auth.GitHub_Copilot
  LLM.Providers.OpenCode_Go        ÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂº LLM.Providers.OpenAI_Completions,
                                        LLM.Providers.Anthropic_Messages
        ÃÂ¢ÃÂÃÂ
        ÃÂ¢ÃÂÃÂ¼
[Infrastructure layer]
  LLM.HTTP ÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂº LLM.HTTP.Curl_Binding (libcurl C binding)
  LLM.SSE  (pure parser, no external dependencies)
  Nine_P.Client ÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂº Nine_P.Proto
  Coyote_Cmark ÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂº coyote_cmark_c.c (C shim for libcmark-gfm)
```

### 4.3 Dynamic Relationships ÃÂ¢ÃÂÃÂ Acme Path Concept of Execution

```
[startup]
  Coyote.main
    ÃÂ¢ÃÂÃÂ parse CLI args
    ÃÂ¢ÃÂÃÂ detect frontend (Acme)
    ÃÂ¢ÃÂÃÂ Coyote_App.Run(Opts)

[Coyote_App.Run]
  ÃÂ¢ÃÂÃÂ create App_State (protected)
  ÃÂ¢ÃÂÃÂ create Acme_Win frontend
  ÃÂ¢ÃÂÃÂ spawn Agent_Task
  ÃÂ¢ÃÂÃÂ spawn Acme_Event_Task   (reads /winid/event via 9P)
  ÃÂ¢ÃÂÃÂ spawn Plumb_Model_Task  (reads /coyote-model plumb port)
  ÃÂ¢ÃÂÃÂ spawn Plumb_Thinking_Task
  ÃÂ¢ÃÂÃÂ spawn Plumb_Fork_Task
  ÃÂ¢ÃÂÃÂ main task blocks on App_State.Wait_Shutdown

[Agent_Task loop]
  ÃÂ¢ÃÂÃÂ LLM.Agent.Create(S, ...)   ; load settings, populate model registry
  ÃÂ¢ÃÂÃÂ loop:
      prompt ÃÂ¢ÃÂÃÂ Frontend.Read_Prompt    ; blocks on Acme_Event_Task signal
      LLM.Agent.Run_Prompt(S, prompt, On_Event => Dispatch_Event'Access)
        ÃÂ¢ÃÂÃÂ build system prompt (skills, settings)
        ÃÂ¢ÃÂÃÂ build request JSON
        ÃÂ¢ÃÂÃÂ LLM.HTTP.Post_Stream ÃÂ¢ÃÂÃÂ SSE ÃÂ¢ÃÂÃÂ provider events
        ÃÂ¢ÃÂÃÂ On_Event called for each event (synchronous)
        ÃÂ¢ÃÂÃÂ if tool_use: execute tool, append result, repeat LLM call
        ÃÂ¢ÃÂÃÂ persist each turn to JSONL
      if App_State.Was_Aborted: exit loop

[Acme_Event_Task]
  ÃÂ¢ÃÂÃÂ reads event file in /winid/event
  ÃÂ¢ÃÂÃÂ "Send" button-2 ÃÂ¢ÃÂÃÂ writes prompt to App_State, signals Agent_Task
  ÃÂ¢ÃÂÃÂ "Stop" button-2 ÃÂ¢ÃÂÃÂ sets Abort_Flag in LLM.Tools
  ÃÂ¢ÃÂÃÂ other commands ÃÂ¢ÃÂÃÂ handled inline or forwarded to Agent_Task via App_State
```

### 4.4 Dynamic Relationships ÃÂ¢ÃÂÃÂ GUI Path Concept of Execution

```
[startup]
  Coyote.main
    ÃÂ¢ÃÂÃÂ parse CLI args
    ÃÂ¢ÃÂÃÂ detect frontend (GUI)
    ÃÂ¢ÃÂÃÂ Coyote_App.Run_GUI(Opts)

[Coyote_App.Run_GUI]
  ÃÂ¢ÃÂÃÂ Gtk.Main.Init
  ÃÂ¢ÃÂÃÂ Frontend.GUI.Create (builds GtkApplicationWindow)
  ÃÂ¢ÃÂÃÂ spawn Agent_Task
  ÃÂ¢ÃÂÃÂ Gtk.Main.Main (blocks main task on GTK event loop)

[Agent_Task loop]
  ÃÂ¢ÃÂÃÂ LLM.Agent.Create(S, ...)
  ÃÂ¢ÃÂÃÂ loop:
      prompt ÃÂ¢ÃÂÃÂ Frontend.Read_Prompt
           ÃÂ¢ÃÂÃÂ blocks on Coyote_GUI.Prompt_Queue.Dequeue
      if prompt starts with ':' ÃÂ¢ÃÂÃÂ Execute_GUI_Command
      else LLM.Agent.Run_Prompt(S, prompt, On_Event => Dispatch_Event'Access)
           ÃÂ¢ÃÂÃÂ On_Event ÃÂ¢ÃÂÃÂ Dispatch_Event
                ÃÂ¢ÃÂÃÂ Coyote_GUI.Updates.Enqueue(update)
           ÃÂ¢ÃÂÃÂ GTK idle callback drains Updates queue
                ÃÂ¢ÃÂÃÂ Coyote_GUI.Buffer operations on GtkTextBuffer

[GTK callbacks]
  ÃÂ¢ÃÂÃÂ Send button / Enter key ÃÂ¢ÃÂÃÂ Coyote_GUI.Prompt_Queue.Enqueue(prompt_text)
  ÃÂ¢ÃÂÃÂ Stop menu ÃÂ¢ÃÂÃÂ LLM.Tools.Abort_Flag.Set
  ÃÂ¢ÃÂÃÂ Compact / Pause / Resume menu ÃÂ¢ÃÂÃÂ Coyote_GUI.Prompt_Queue.Enqueue(":compact" etc.)
```

### 4.5 Design Decisions Affecting Multiple Units

**Decision D-001: Frontend abstraction at event granularity, not text granularity.**
The `Frontend'Class` interface operates at the level of structured events
(Begin_Tool, End_Tool, Begin_Thinking, etc.) rather than raw character
streams. This allows the GUI to maintain typed widget state (tool frames,
text tags) while the Acme frontend simply formats the same information as
Unicode-glyph-prefixed text. *Rationale: A text-only interface would force
the GUI to re-parse event semantics from rendered text, which is fragile and
lossy.*

**Decision D-002: On_Event callback invoked synchronously in the agent task.**
`Run_Prompt` calls `On_Event` in the same task that called `Run_Prompt`. In
the Acme path this is `Agent_Task`; in the GUI path this is also `Agent_Task`.
The callback must not block. *Rationale: Avoids an extra queue and synchronisation
for the Acme path, which can update the 9P window synchronously from
Agent_Task. The GUI path uses the Updates queue to cross to the GTK thread.*

**Decision D-003: Routing providers delegate to wire-format providers.**
GitHub Copilot and OpenCode Go each support multiple wire formats (OpenAI
and Anthropic). These are implemented as *routing providers* that inspect the
model ID, construct the appropriate delegate (`OpenAI_Completions.Provider`
or `Anthropic_Messages.Provider`), and forward the request. *Rationale:
Avoids duplicating SSE parsing and JSON construction; adds a new wire format
by adding one package, not by modifying all routing providers.*

**Decision D-004: Session JSONL appended per message, not written at turn end.**
Each message (user, assistant, tool result) is appended to the JSONL file
immediately after it is added to the in-memory history, not batched at turn
end. *Rationale: Minimises data loss if the process is killed mid-turn; the
session file always contains the most recently completed state.*

**Decision D-005: Compaction implemented as a one-shot summarisation request.**
The in-memory history is replaced atomically: a single LLM call returns a
structured summary, then `Run_Prompt` splices it into the history in one
operation. *Rationale: A streaming compaction would require synchronising
partial history states; a one-shot call keeps the history-replacement logic
simple and auditable.*

---

## 5. Detailed Design

### 5.1 `Coyote` (entry point)

**Purpose:** CLI argument parsing and frontend selection.

**Inputs:** `Ada.Command_Line.Argument_Count` / `Argument`; environment
variables `$winid`, `$DISPLAY`, `$WAYLAND_DISPLAY`, `COYOTE_FRONTEND`,
`COYOTE_NO_SESSION`, `COYOTE_SESSION_ID`, `COYOTE_PARENT_SESSION`, `COYOTE_THINKING_LEVEL`.

**Outputs:** `Coyote_App.Options` record passed to `Run` or `Run_GUI`;
environment variable `COYOTE_FRONTEND` set when the frontend is a windowing kind (Acme or GUI).

**Control flow:**
1. Parse arguments sequentially. Each recognised flag sets the corresponding
   field in `Opts`. Unknown arguments trigger `Put_Line (Standard_Error, ...)`.
2a. If `$COYOTE_THINKING_LEVEL` is set, `Coyote_App.Run` inherits the
    parent's thinking level, overriding the `defaultThinkingLevel` from
    `settings.json`.
2. If `$COYOTE_NO_SESSION` is set, force `Opts.No_Session := True`.
3. If `--session UUID` was given and the session's working directory exists,
   call `Ada.Directories.Set_Directory`.
4. Evaluate the frontend selection rules listed below (the `--frontend` flag wins over all); set `Opts.Frontend`.
5. Propagate the selected frontend to child processes via
   `COYOTE_FRONTEND`.  If Acme: set `COYOTE_FRONTEND=acme`.  If GUI:
   set `COYOTE_FRONTEND=gui`.  Plain frontend does not set this variable.
6. Dispatch to `Coyote_App.Run` (Acme/Plain) or `Coyote_App.Run_GUI` (GUI).

**Error handling:** `Coyote_Utils.Bad_Arg_Error` is caught at the outermost
level; error message goes to stderr; exit status is set to Failure.

---

### 5.2 `Coyote_App` (App_State and Run/Run_GUI)

**Purpose:** Application lifecycle management; inter-task shared state.

**`App_State` protected type:**
All fields are protected by Ada's monitor semantics. Key fields:
- `Session_Id`, `Current_Model`, `Current_Thinking` ÃÂ¢ÃÂÃÂ identity and model state
- `Is_Streaming`, `Is_Compacting`, `Was_Aborted` ÃÂ¢ÃÂÃÂ agent loop phase flags
- `Is_Paused`, `Is_Pause_Armed` ÃÂ¢ÃÂÃÂ pause/resume handshake
- `Turn_Count`, `Turn_Cost_Dmil`, `Session_Cost_Dmil` ÃÂ¢ÃÂÃÂ statistics accumulators
- `Context_Window` ÃÂ¢ÃÂÃÂ set by Model_Select_Event; used for compaction threshold

**`Run` procedure:** Creates the `Acme_Win` frontend, spawns the five tasks,
then blocks on `App_State.Wait_Shutdown`.

**`Run_GUI` procedure:** Calls `Gtk.Main.Init`, creates the GUI frontend,
spawns `Agent_Task`, then calls `Gtk.Main.Main`.

---

### 5.3 `Coyote_App.Dispatch`

**Purpose:** Maps each `LLM.Events.Agent_Event'Class` value to the appropriate
`Frontend'Class` primitive calls. Shared by all three execution paths.

**Interface:** Single public procedure `Dispatch_Event` taking an
`Agent_Event'Class` value and an `Instance'Class` access.

**Dispatch table (abridged):**

| Event type | Frontend calls |
|---|---|
| `Agent_Start_Event` | `Set_Mode (Running)` |
| `Agent_End_Event` | `Set_Mode (Idle)`; `Append_Notice` if aborted |
| `Message_Update_Event` / `Text_Delta` | `Append_Text` |
| `Message_Update_Event` / `Text_End` | `End_Text_Block` |
| `Message_Update_Event` / `Thinking_Delta` | `Append_Thinking` |
| `Tool_Execution_Start_Event` | `Begin_Tool` |
| `Tool_Execution_End_Event` | `End_Tool` |
| `Message_End_Event` | record stats in App_State |
| `Session_Stats_Event` | `Append_Turn_Footer`; GUI: `Set_Stats_Summary` |
| `Model_Select_Event` | `Append_Notice (Info, ...)` |
| `Auto_Retry_Start_Event` | `Append_Notice (Warning, ...)` |
| `Auto_Compaction_Start/End_Event` | `Append_Notice (Info/Warning, ...)` |
| `Agent_Paused_Event` | `Set_Mode (Paused)` |
| `Agent_Resumed_Event` | `Set_Mode (Running)` |

---

---

### 5.3.5 Thinking-text buffering and collapsing

**Problem:** SSE streaming from LLM providers delivers thinking tokens as short
chunks (1ÃÂ¢ÃÂÃÂ5 words) with leading/trailing newlines and internal line breaks.
Naive per-chunk rendering produces illegible fragmented output:
```
ÃÂ¢ÃÂÃÂ The
ÃÂ¢ÃÂÃÂ  user
ÃÂ¢ÃÂÃÂ  wants me
```
instead of flowing prose:
```
ÃÂ¢ÃÂÃÂ The user wants me toÃÂ¢ÃÂÃÂ¦
```

**Solution (PCR-022 resolution, 2026-06-07; revised PCR-039, 2026-06-27):**
Each frontend (Acme and GUI) collapses each thinking delta as it arrives
and emits it immediately, producing flowing prose without buffering.

**Collapsing algorithm:**
- Spaces are treated as content, not whitespace ÃÂ¢ÃÂÃÂ they carry word-boundary
  information from providers like Anthropic that delimit tokens with
  leading spaces (e.g. `" the"`, `" edits"`)
- Single `\n` or `\r` ÃÂ¢ÃÂÃÂ collapsed to space (restores word boundaries across
  OpenAI-style deltas that terminate each token with trailing `\n`)
- `\n\n` (paragraph breaks) ÃÂ¢ÃÂÃÂ preserved as blank line
- Leading and trailing LF, CR, HT trimmed; spaces preserved
- Implemented in `Coyote_App.Utils.Collapse_Thinking_Delta` (pure function)

**Frontend implementation (Acme and GUI identical pattern):**
- `Begin_Thinking`: Set `Prefix_Emitted` flag to false, mark thinking active
- `Append_Thinking`: Collapse delta via `Collapse_Thinking_Delta`, emit with
  box-drawing prefix on first call; subsequent deltas are concatenated
  directly (no inter-delta separator ÃÂ¢ÃÂÃÂ spacing is handled by the collapse
  function itself)
- `End_Thinking`: Append final blank line, clear thinking state
- No `Last_Ended_With_LF` tracking ÃÂ¢ÃÂÃÂ the collapse function produces
  self-contained output with all spacing resolved internally

**Architectural rationale:** Display layer owns rendering semantics. Providers
remain wire-format-neutral and emit raw SSE deltas. Collapsing occurs
per-delta in each frontend's `Append_Thinking`, producing immediate
streaming output without buffering.  The collapse function normalises both
OpenAI-style (trailing-`\n`) and Anthropic-style (leading-space) deltas
into concatenable prose fragments.

**Test coverage:** 8 `Collapse_Thinking_Delta` unit tests in
`test/src/collapse_utils_tests.adb` cover all edge cases: single-LFÃÂ¢ÃÂÃÂspace,
paragraph preservation, empty input, no-LF verbatim, space preservation,
OpenAI trailing-LF stripping, OpenAI mid-stream LFsÃÂ¢ÃÂÃÂspaces, and LF/HT-only
whitespace.  `Test_Dispatch_Thinking_Delta` in
`test/src/dispatch_tests.adb` verifies end-to-end thinking-delta dispatch.

### 5.4 `Coyote_App.Frontend` (abstract interface)

**Purpose:** Defines the contract between `Dispatch_Event` and all concrete
frontend implementations.

**Primitives:** `Set_Status`, `Set_Mode`, `Append_Text`, `End_Text_Block`,
`Begin_Thinking`, `Append_Thinking`, `End_Thinking`, `Begin_Tool`, `End_Tool`,
`Append_Turn_Footer`, `Append_Notice`, `Show_Detail`, `Read_Prompt`,
`Shutdown`.

**Design constraint:** All primitives are called from a single task
(Agent_Task). Implementations need not be internally re-entrant with respect
to these primitives, though they may have their own internal concurrency (e.g.
the GUI frontend uses the Updates queue to cross to the GTK thread).

---

### 5.5 `LLM.Agent`

**Purpose:** Owns the conversation `Session` record and drives the complete
agentic loop for one prompt.

**`Session` record fields (private):**
- `History: LLM.Types.Message_Vectors.Vector` ÃÂ¢ÃÂÃÂ in-memory conversation
- `Session_Id: Unbounded_String`
- `Model_Info: LLM.Model_Registry.Model_Info`
- `Settings: LLM.Settings.Config`
- `Compact_Settings: LLM.Compaction.Compact_Settings`
- `Tools: LLM.Tools.Descriptor_Array` (empty when `No_Tools`)
- `Abort_Flg: aliased LLM.Tools.Abort_Flag`

**`Create` procedure:**
1. Load settings from `~/.coyote/settings.json` and `~/.coyote/models.json`.
2. Refresh each provider's model catalogue (Copilot, OpenRouter, OpenCode).
3. Select the model: `--model` arg ÃÂ¢ÃÂÃÂ settings ÃÂ¢ÃÂÃÂ first registry entry.
4. Create or resume session via `LLM.Session_Store`.
5. Load conversation history if resuming.
6. Build the system prompt (static preamble + skills + agent arg).
7. Emit `Session_Info_Event` and `Model_Select_Event`.

**`Run_Prompt` loop:**
```
append user message to History
persist user message
loop:
  build request JSON (History + tools + system prompt)
  call provider.Send(request, On_Event callback)
  -- provider invokes On_Event synchronously for each streamed event
  if was_aborted: exit
  append assistant message to History
  persist assistant message
  if no tool calls in response: exit
  for each tool call:
    On_Event(Tool_Execution_Start_Event)
    result ÃÂ¢ÃÂÃÂ execute tool (LLM.Tools.Shell.Execute or error if No_Tools)
    On_Event(Tool_Execution_End_Event)
    append tool result to History
    persist tool result
  end for
end loop
-- check compaction threshold; compact if needed
emit Session_Stats_Event
```

**`Compact` procedure:**
1. Compute cut-point using `LLM.Compaction.Find_Cut_Point`.
2. Serialise history up to cut-point as text.
3. Call provider once with `Summarization_System_Prompt`.
4. Replace `History[0..cut]` with one synthetic compaction-summary message.
5. Append compaction record to JSONL.
6. Emit `Auto_Compaction_End_Event`.

---

### 5.6 `LLM.Providers.OpenAI_Completions`

**Purpose:** OpenAI Chat Completions wire format implementation. Base class
extended by `OpenRouter`.

**`Send` procedure flow:**
1. Build `messages` JSON array from `History` (role mapping: user/assistant/tool).
2. Build `tools` JSON array from tool descriptors (function schema per OAI spec).
3. Set provider-specific headers (Authorization, Content-Type, model ID).
4. POST via `LLM.HTTP.Post_Stream`.
5. For each SSE `data:` line: parse JSON delta; dispatch to `On_Event`:
   - `content_delta` ÃÂ¢ÃÂÃÂ `Message_Update_Event (Text_Delta)`
   - `tool_call delta` ÃÂ¢ÃÂÃÂ `Message_Update_Event (Tool_Call_Delta)`
   - `[DONE]` ÃÂ¢ÃÂÃÂ `Message_End_Event`
6. Special case for image tool results: split into text stub + follow-up
   user message with `image_url` (OAI does not accept vision in role=tool).


**`Wire_Format` field:** `"openai-completions"` ÃÂ¢ÃÂÃÂ used by `LLM.Agent` to
determine the `tools` JSON schema shape.

**Cache breakpoints:** `Build_Request_Body` places `cache_control` markers
on (1) the system message, (2) the last message with `role:"user"` or
`role:"tool"`, and (3) the last tool definition.  The user/tool message
breakpoint advances each turn to encompass the entire conversation prefix,
yielding near-zero cache miss rates for providers that honour the
`cache_control` field (OpenRouter routing to Anthropic backends, GitHub
Copilot).  Providers that do not support `cache_control` retain automatic
prefix caching with no change in behaviour.

**`Customize_Request` (non-overriding):** Maps `Thinking_Level` to the
OpenAI `reasoning.effort` request field (`"low"`, `"medium"`, `"high"`).
When `Thinking` is `Off` this is a no-op.  This base implementation applies
to all providers routing through the OpenAI completions wire format ÃÂ¢ÃÂÃÂ
OpenRouter, GitHub Copilot (OpenAI-wire path), and OpenCode Go (OpenAI-wire
path).  Descendants may override to add provider-specific logic.
---

### 5.7 `LLM.Providers.Anthropic_Messages`

**Purpose:** Anthropic Messages wire format implementation.

**`Send` procedure flow:**
1. Build `messages` JSON array (role: user/assistant; content blocks for
   text, thinking, tool_use, tool_result, image).
2. Build `tools` JSON array (Anthropic function schema).
3. Set Anthropic headers (`x-api-key`, `anthropic-version`,
   `anthropic-beta: interleaved-thinking-2025-05-14` when thinking enabled).
4. POST via `LLM.HTTP.Post_Stream`.
5. For each SSE event type:
   - `content_block_start` with `type=thinking` ÃÂ¢ÃÂÃÂ `Thinking_Start`
   - `content_block_delta` with `thinking_delta` ÃÂ¢ÃÂÃÂ `Thinking_Delta`
   - `content_block_start` with `type=text` ÃÂ¢ÃÂÃÂ `Text_Start`
   - `content_block_delta` with `text_delta` ÃÂ¢ÃÂÃÂ `Text_Delta`
   - `content_block_stop` ÃÂ¢ÃÂÃÂ `Text_End` or `Thinking_End`
   - `message_delta` with `stop_reason` ÃÂ¢ÃÂÃÂ `Message_End_Event`

---

### 5.8 `LLM.Providers.GitHub_Copilot`

**Purpose:** Routing provider; selects wire format based on model ID.

**`Send` procedure:**
1. Load Copilot credentials from `~/.coyote/auth.json` and call
   `Ensure_Valid` to refresh the access token only when a request
   is actually made ÃÂ¢ÃÂÃÂ no token refresh occurs at startup.
2. Inspect model ID: if it matches a known Claude model pattern ÃÂ¢ÃÂÃÂ use
   `Anthropic_Messages.Provider`; otherwise ÃÂ¢ÃÂÃÂ use `OpenAI_Completions.Provider`.
3. Load the model catalogue (`Load_Catalogue`) and construct the
   appropriate delegate with Copilot's base URL and token.
4. Forward the call.  If the completions API returns HTTP 401 despite
   a token that appeared valid, force a token refresh via the GitHub
   token-exchange endpoint and retry exactly once.

---

### 5.9 `LLM.HTTP` and `LLM.HTTP.Curl_Binding`

**Purpose:** HTTPS client with streaming SSE support via libcurl.

**`Post_Stream` procedure:**
1. Initialise a `CURL` handle via `curl_easy_init`.
2. Set URL, headers, body, write callback, and timeout options.
3. Call `curl_easy_perform` (blocks until stream is complete or aborted).
4. The write callback is called for each chunk; it feeds bytes to the SSE
   parser, which calls the provider's event callback synchronously.
5. Abort is checked in the write callback; if `Abort_Flg` is set, the
   callback returns 0 (libcurl interprets this as `CURLE_WRITE_ERROR`
   and terminates the transfer).

---

### 5.10 `LLM.Tools.Shell`

**Purpose:** Executes the shell command provided by the model.

**`Execute` procedure:**
1. Parse `Args_Json`: extract `command`, `stdin` (optional), `media_type`
   (optional).
2. Spawn `$SHELL -c command` via `GNAT.OS_Lib.Spawn_Pipe` (or equivalent).
3. Write `stdin` content to the child's stdin if non-empty.
4. Read combined stdout/stderr.
5. If `media_type` non-empty: base64-encode the raw bytes; set `Media_Type`.
6. If result exceeds `LLM.Tools.Temp_File.Result_Threshold`: call
   `LLM.Tools.Temp_File.Truncated` before returning.
7. Set `Is_Error := exit_code /= 0`.

---

### 5.11 `LLM.Session_Store`

**Purpose:** JSONL session file creation, append, and reload.

**File layout:** `~/.coyote/sessions/<cwd-slug>/<uuid>.jsonl`

**`cwd-slug` encoding:** The current working directory path is URL-encoded,
replacing `/` with `%2F` and other non-ASCII-safe characters with `%XX` hex
escapes. The encoded string becomes the directory name.

**v3 envelope format:** Each record is written as
`{"type":"message","message":{...}}\n` where the inner `message` object uses
role, content blocks, usage, stop_reason, etc. per the session-format skill.

**Compaction record format:** `{"type":"compaction","summary":"...","firstKeptIndex":N,"tokensBefore":N}\n`

**Model-change record format:** `{"type":"model_change","provider":"...","modelId":"..."}\n`

---

### 5.12 `LLM.Compaction`

**Purpose:** Pure helpers for compaction decisions; no side effects.

**`Estimate_Tokens(text)`:** Returns `text'Length / 4` (conservative
approximation; 4 bytes per token for code and prose).

**`Find_Cut_Point(History, Keep_Recent_Tokens)`:**
Walks the history in reverse; accumulates estimated tokens until the
`Keep_Recent_Tokens` budget is exhausted; returns the index of the oldest
message to retain.

**`Compact_Settings`:**
- `Enabled`: whether auto-compaction is active.
- `Reserve_Tokens`: headroom reserved for the model's response (default 16 384).
- `Keep_Recent_Tokens`: minimum recent history to retain verbatim (default 20 000).

---

### 5.13 `LLM.Skills`

**Purpose:** Discovers SKILL.md files from five roots and formats them for
inclusion in the system prompt.

**Discovery order:** `~/.coyote/skills/`, `~/.agents/skills/`,
`$BASE/share/agents/skills/`,
`{CWD}/.coyote/skills/`, `{CWD}/.agents/skills/`. Within each root, all
`*/SKILL.md` paths are enumerated. Project-local skills shadow global skills
of the same `name` field.

**YAML frontmatter parsing:** Only `name` and `description` fields are
extracted. Skills missing either are silently skipped.

**`Format_Skills_For_Prompt`:** Returns an XML-style `<available_skills>`
block containing `<skill>` entries for each discovered skill, or `""` if none.

---

### 5.14 `Coyote_GUI.Buffer`

**Purpose:** Wraps `GtkTextBuffer`; manages all text insertion, tagging, and
tool-frame embedding in the GUI conversation view.

**Text tags defined:**
- `thinking` ÃÂ¢ÃÂÃÂ dim/italic left-gutter style for thinking blocks
- `notice_info`, `notice_warning`, `notice_error` ÃÂ¢ÃÂÃÂ coloured inline notices
- `turn_footer` ÃÂ¢ÃÂÃÂ smaller/dimmer turn statistics line
- `code` ÃÂ¢ÃÂÃÂ monospace for inline code and fenced blocks
- `bold`, `italic`, `strikethrough`, `link` ÃÂ¢ÃÂÃÂ standard GFM formatting
- `blockquote` ÃÂ¢ÃÂÃÂ reduced opacity

**Markdown rendering pipeline (`Insert_Markup`):**
1. Raw streamed text is appended as plain text by `Append_Text`.
2. On `End_Text_Block`: delete the plain-text range; re-insert the same text
   as Pango markup via `Gtk.Text_Buffer.Insert_Markup`.
3. Markup is generated by walking the libcmark-gfm AST produced by
   `Coyote_Cmark.Parse_Document`; each node type maps to Pango markup tags.
4. A `GtkTextMark` is maintained at the start of the current text block to
   delimit the range for deletion on `End_Text_Block`.

**Tool-frame embedding:**
- `Begin_Tool` creates a `GtkTextChildAnchor` at the current insert position;
  inserts a `GtkFrame` containing a `GtkLabel` with the tool name and a
  ÃÂ¢ÃÂÃÂ³ pending indicator.
- `End_Tool` locates the frame by `Tool_Id` (stored in a lookup table), updates
  the label icon (ÃÂ¢ÃÂÃÂ / ÃÂ¢ÃÂÃÂ / ÃÂ¢ÃÂÃÂ) and optionally shows an error preview.

---

### 5.15 `Coyote_Cmark` and `coyote_cmark_c.c`

**Purpose:** Ada binding to libcmark-gfm with a C shim for enum resolution.

**C shim pattern:** libcmark-gfm exposes node-type and event-type constants
as C `enum` values whose numeric values may differ across library versions.
`coyote_cmark_c.c` exports one getter function per constant (e.g.
`cmark_shim_node_paragraph()` returns `CMARK_NODE_PARAGRAPH`). The Ada package
`Coyote_Cmark` calls these getters at package elaboration time and stores the
results in integer variables. All subsequent comparisons use these variables,
never hard-coded integer literals. *Rationale: Ensures correctness regardless
of the installed library version.*

**GFM extensions enabled:** `table`, `strikethrough`, `autolink`.
Enabled by `cmark_shim_parse_document_gfm`, which creates a parser with all
three extensions attached before parsing.

---


### 5.16 `LLM.Types`

**Purpose:** Defines the core data types shared across the agent, providers,
session store, and tools.

**Key types:**
- `Role_Type` ÃÂ¢ÃÂÃÂ enumeration: `User`, `Assistant`, `Tool_Result`.
- `Content_Block` ÃÂ¢ÃÂÃÂ discriminated record covering: `Text` (plain string),
  `Thinking` (reasoning block with signature), `Tool_Call` (id, name, arguments
  JSON string), `Tool_Result` (tool_call_id, content string, is_error flag,
  media_type), `Image` (base64 data + media_type).
- `Content_Block_Vectors.Vector` ÃÂ¢ÃÂÃÂ ordered sequence of content blocks in one message.
- `Message` ÃÂ¢ÃÂÃÂ record: role, content blocks, optional stop_reason, optional usage
  (input_tokens, output_tokens, cache_read_tokens, cache_creation_tokens).
- `Message_Vectors.Vector` ÃÂ¢ÃÂÃÂ the conversation history type held by `LLM.Agent`.

**No logic:** `LLM.Types` contains only type definitions and default-initialisation
expressions. No subprograms are declared.

---

### 5.17 `LLM.Events`

**Purpose:** Defines the `Agent_Event'Class` tagged-type hierarchy emitted
by provider adapters and consumed by `Dispatch_Event`.

**Event types:**

| Type | Payload | Meaning |
|---|---|---|
| `Agent_Start_Event` | ÃÂ¢ÃÂÃÂ | Agent turn beginning |
| `Agent_End_Event` | `Was_Aborted : Boolean` | Agent turn ending |
| `Message_Update_Event` | `Kind : Update_Kind`; `Text : String`; `Tool_Id : String` | Streaming token or tool delta |
| `Message_End_Event` | usage fields | Provider message completed |
| `Tool_Execution_Start_Event` | tool name, call_id, args JSON | Tool call started |
| `Tool_Execution_End_Event` | call_id, result text, is_error, duration | Tool call completed |
| `Session_Stats_Event` | turn count, cost, model info | Post-turn statistics |
| `Session_Info_Event` | session_id, resuming flag | Session identity at startup |
| `Model_Select_Event` | provider, model_id, context window | Model selected or changed |
| `Auto_Retry_Start_Event` | attempt number, reason | Transient error retry |
| `Auto_Compaction_Start_Event` | token count | Compaction beginning |
| `Auto_Compaction_End_Event` | tokens saved | Compaction complete |
| `Agent_Paused_Event` | ÃÂ¢ÃÂÃÂ | Agent pause entered |
| `Agent_Resumed_Event` | ÃÂ¢ÃÂÃÂ | Agent resumed from pause |

**Design constraint:** All event types are concrete; dispatching uses Ada
classwide (`Agent_Event'Class`). Events are value types (not heap-allocated in
normal use); the `On_Event` callback receives an `Agent_Event'Class` parameter.

---

### 5.18 `LLM.SSE`

**Purpose:** Pure stateless server-sent event parser. Parses raw SSE bytes
into discrete `data:` and `event:` lines.

**Interface:** Single procedure `Feed (Bytes : String; On_Line : access procedure
(Line : String))`. Buffers partial lines across calls using a package-level
internal buffer (one instance per `LLM.HTTP` call context). Calls `On_Line`
for each complete SSE `data:` line, stripping the `data:` prefix.

**No external dependencies.** Pure Ada string processing.

---

### 5.19 `LLM.Settings`

**Purpose:** Loads and exposes the user configuration from
`~/.coyote/settings.json` and `~/.coyote/models.json`.

**`Config` record fields:**
- `Default_Model_Provider`, `Default_Model_Id` ÃÂ¢ÃÂÃÂ from `settings.json`
  `"model"` field.
- `Thinking_Level` ÃÂ¢ÃÂÃÂ `"auto"`, `"none"`, or a budget string; from settings.
- `No_Tools` ÃÂ¢ÃÂÃÂ boolean; from `--no-tools` flag or settings.
- `Compact_Settings` ÃÂ¢ÃÂÃÂ `LLM.Compaction.Compact_Settings`; from settings.
- Raw model entries list from `models.json`.

**`Load` procedure:** Reads and parses both JSON files. Missing files produce
default values; malformed JSON is logged to stderr and defaults are used.

**`Resolve_Api_Key (Provider : String) ÃÂ¢ÃÂÃÂ String`:** Checks in order:
(1) literal `apiKey` in models.json entry, (2) `${ENV_VAR}` interpolation,
(3) `Standard_Env_Name` environment variable lookup.

---

### 5.20 `LLM.Auth`

**Purpose:** Loads and caches provider authentication tokens.

**`Auth_Store` record:** Maps provider name to token string. Populated by
`Load` from `~/.coyote/auth.json`.

**`Load` procedure:** Reads `~/.coyote/auth.json`; populates the store.
Missing file is a no-op (not an error; provider may use API-key auth).

**`Save` procedure:** Writes the current store back to `~/.coyote/auth.json`.
Called after token refresh to persist the new token.

---

### 5.21 `LLM.Auth.GitHub_Copilot`

**Purpose:** Manages GitHub Copilot OAuth token lifecycle.

**`Ensure_Valid_Token (Store : in out Auth_Store; Token : out String)`:**
1. Read current token and expiry from `Store`.
2. If token is absent or within 60 seconds of expiry: call Copilot's
   `/copilot_internal/v2/token` endpoint with the device-flow access token
   from `Store`.
3. Parse `token` and `expires_at` from the JSON response.
4. Update `Store` and call `LLM.Auth.Save`.
5. Return the valid token.

**Error handling:** HTTP failure or JSON parse error raises
`Auth_Error`; caught in `LLM.Providers.GitHub_Copilot.Send` and converted to
a non-recoverable turn error.

---

### 5.22 `LLM.Model_Registry`

**Purpose:** In-memory catalogue of known models, built at session start.

**`Model_Info` record:** provider, model_id, display_name, context_window,
wire_format (`"openai-completions"` or `"anthropic-messages"`), supports_thinking.

**`Available_Models ÃÂ¢ÃÂÃÂ Model_Info_Array`:** Returns all registered models from
all providers for which an API key is present.

**`Refresh_GitHub_Copilot`:** Uses the access token already stored in
`~/.coyote/auth.json` when it is present and non-expired (checked via
`LLM.Auth.GitHub_Copilot.Token_Expired`).  No live token refresh is
performed at startup ÃÂ¢ÃÂÃÂ token refresh is deferred to the provider's `Send`.
The catalogue load (`Load_Catalogue`) is wrapped in an exception handler;
any failure (network error, expired subscription, 401 Unauthorized, JSON
parse error) is silently swallowed, leaving the Copilot portion of the
registry empty.  When the cached token has expired or credentials are
absent, the procedure returns early without touching the registry.

**`Lookup` for `"github-copilot"`:** Returns a `Default_GitHub_Copilot_Model`
with conservative limits and a model-ID-based wire-format heuristic: model
IDs containing `"claude"` ÃÂ¢ÃÂÃÂ `"anthropic-messages"`, all others ÃÂ¢ÃÂÃÂ
`"openai-completions"`.  `Not_Found` is no longer raised for unknown
Copilot model IDs, so the agent can start and operate even when the Copilot
catalogue has not been loaded.

---

### 5.23 `LLM.Providers`

**Purpose:** Defines the abstract `Provider` tagged type and the `Send`
interface.

**`Send` primitive:**
```
procedure Send
  (P        : in out Provider;
   History  : LLM.Types.Message_Vectors.Vector;
   Tools    : LLM.Tools.Descriptor_Array;
   Settings : LLM.Settings.Config;
   On_Event : not null access procedure (E : LLM.Events.Agent_Event'Class));
```

All concrete providers override this primitive. No other primitives are
defined in the abstract package.

---

### 5.24 `LLM.Providers.OpenRouter`

**Purpose:** OpenRouter adapter. Extends `OpenAI_Completions.Provider` with
OpenRouter-specific base URL and request customisation.

**`Create` function:** Sets base URL to `https://openrouter.ai/api/v1` and
sets the `HTTP-Referer` and `X-Title` headers required by OpenRouter.

**`Customize_Request` (inherited):** Reasoning-effort configuration is
inherited from the base `OpenAI_Completions` provider (ÃÂÃÂ§5.6).  OpenRouter
no longer overrides `Customize_Request`; the base implementation maps
`Thinking_Level` to `reasoning.effort` for all OpenAI-compatible providers.

**Catalogue package `OpenRouter.Catalogue`:** Fetches
`https://openrouter.ai/api/v1/models`, caches to
`~/.coyote/openrouter_models_cache.json`. Each entry is parsed into a
`Catalogue_Entry` record (id, display_name, context_length, pricing).
`Catalogue_Entry` record (id, display_name, context_length, pricing).

---

### 5.25 `LLM.Providers.OpenCode_Go`

**Purpose:** Routing provider for OpenCode Go. Selects wire format based on
model ID, in the same pattern as GitHub Copilot.

**`Send` procedure:**
1. Inspect model ID: Claude patterns ÃÂ¢ÃÂÃÂ `Anthropic_Messages.Provider`; all
   others ÃÂ¢ÃÂÃÂ `OpenAI_Completions.Provider`.
2. Construct the delegate with OpenCode Go's base URL (read from settings or
   default `http://localhost:2710`).
3. Forward the call.

**No authentication:** OpenCode Go is a local proxy; no token header is set.

**Catalogue package `OpenCode_Go.Catalogue`:**
1. Fetches the model-ID list from `https://opencode.ai/zen/go/v1/models`,
   caches to `~/.coyote/opencode_go_models_cache.json`.
2. Cross-references each model ID against the OpenRouter model catalogue
   (using either the live API response or the on-disk cache at
   `~/.coyote/openrouter_models_cache.json`).  Matching is by normalised
   model-ID base name (provider prefix stripped).
3. Populates per-model `Model_Info` records from the matching OpenRouter
   entry: `context_window` ÃÂ¢ÃÂÃÂ `context_length`,
   `max_tokens` ÃÂ¢ÃÂÃÂ `top_provider.max_completion_tokens`,
   `Reasoning` ÃÂ¢ÃÂÃÂ presence of `"reasoning"` in `supported_parameters`,
   pricing sub-fields from the `pricing` object.
4. When a model is not found on OpenRouter, conservative defaults are used
   (context window 128,000, max tokens 16,384, no reasoning).  The
   `Wire_Format_For` function is still consulted for wire-format routing
   (hardcoded per the Go docs endpoint table).

---
### 5.26 `LLM.Tools`

**Purpose:** Defines tool-control flags and the tool descriptor type.

**`Abort_Flag` protected type:** Single boolean with `Set`, `Clear`, and
`Is_Set` operations. One instance lives in `LLM.Agent.Session`; a pointer
to it is passed into the shell tool executor. The libcurl write callback also
holds this pointer and checks it on each chunk.

**`Pause_Flag` protected type:** Similar to `Abort_Flag`; additionally
provides a `Wait_If_Set` entry that blocks until the flag is cleared (used
by `Agent_Task` to implement the pause/resume handshake).

**`Tool_Descriptor` record:** name, description, parameters JSON schema string.
Tools are described in JSON Schema; `LLM.Agent` serialises them into the
request's `tools` array using the wire format appropriate for the active
provider.

**`Descriptor_Array`:** Unconstrained array of `Tool_Descriptor`. The built-in
shell tool is assembled into a single-element array by `LLM.Agent.Create`
unless `No_Tools` is true.

---

### 5.27 `LLM.Tools.Temp_File`

**Purpose:** Manages tool-result size capping and spill to temporary files.

**`Result_Threshold` constant:** 200 000 bytes. Tool results larger than this
are truncated before being sent to the provider.

**`Truncated (Result : String; Path : out String) ÃÂ¢ÃÂÃÂ String`:** Writes the
full result to a temp file under `/tmp/coyote_tool_<uuid>`, returns a
truncated string with a notice appended indicating the path where the full
result was written.

**`Cleanup`:** Deletes all temp files created by the current process. Called
at session end.

---

### 5.28 `LLM.System_Prompt`

**Purpose:** Constructs the complete system prompt string from its parts.

**`Build (Settings, Skills_Block, Agent_Text) ÃÂ¢ÃÂÃÂ String`:** Concatenates:
1. Static preamble (role description, tool usage instructions, date, CWD).
2. `Skills_Block` ÃÂ¢ÃÂÃÂ formatted `<available_skills>` XML block from
   `LLM.Skills.Format_Skills_For_Prompt`.
3. `Agent_Text` ÃÂ¢ÃÂÃÂ content of `--agent` argument (raw text or file content).

Returns the concatenated string. All parts are optional; absent parts contribute
empty strings.

---

### 5.29 `Coyote_App.History`

**Purpose:** Replays a saved session into the frontend for display.

**`Replay (Store : LLM.Session_Store.Session_File;
            Frontend : Coyote_App.Frontend.Instance'Class)`:**
Reads each record from the JSONL file and calls the appropriate `Frontend`
primitive to render it ÃÂ¢ÃÂÃÂ text blocks, tool calls, turn footers, model-change
notices ÃÂ¢ÃÂÃÂ in the order they appear in the file. Skips compaction records
(they have no displayable content).

Used at startup when `--session UUID` is supplied: the user sees the prior
conversation rendered before the first new prompt.

---

### 5.30 `Coyote_App.Utils`

**Purpose:** Formatting helpers and Unicode glyph constants for all frontends.

**`UC_*` constants:** Named constants for multi-byte UTF-8 glyphs used in
the text UI (bullet `ÃÂ¢ÃÂÃÂ¢`, gear `ÃÂ¢ÃÂÃÂ`, check `ÃÂ¢ÃÂÃÂ`, cross `ÃÂ¢ÃÂÃÂ`, hourglass `ÃÂ¢ÃÂÃÂ³`,
ellipsis `ÃÂ¢ÃÂÃÂ¦`, box-drawing characters, etc.). Defined as `String` values using
`Character'Val` for each byte, because Ada `Character` is Latin-1 and code
points > 255 cannot appear as character literals.

**Formatting helpers:**
- `Format_Cost (Dmil : Natural) ÃÂ¢ÃÂÃÂ String` ÃÂ¢ÃÂÃÂ formats deci-millicent cost values
  as `$0.0000` strings.
- `Format_Duration (Seconds : Duration) ÃÂ¢ÃÂÃÂ String` ÃÂ¢ÃÂÃÂ humanises durations.
- `Truncate_Middle (S : String; Max_Len : Natural) ÃÂ¢ÃÂÃÂ String` ÃÂ¢ÃÂÃÂ truncates long
  strings with a middle ellipsis.
- `Format_Turn_Summary (Input_Tokens, Output_Tokens, Ctx_Window, Model_Text,
  Turn_Cost_Dmil, Session_Cost_Dmil, Stop_Reason_Text) ÃÂ¢ÃÂÃÂ String` ÃÂ¢ÃÂÃÂ builds the
  bracketed per-turn summary line (e.g. `[ctx 24k/400k (6%) | ^537 out | stop]`).
  The `Stop_Reason_Text` parameter (added v1.7) displays the provider stop reason
  (`stop`, `length`, `toolUse`, `aborted`, `error`, `unknown`) when non-empty.
- `Format_Turn_Footer (Turn_N, UUID, PID, ...) ÃÂ¢ÃÂÃÂ String` ÃÂ¢ÃÂÃÂ wraps the summary
  with a `coyote-fork+` plumb token and a double-line separator.

---

### 5.31 `Coyote_App.Frontend.Acme_Win`

**Purpose:** Acme frontend implementation. Renders agent events as structured
Unicode-glyph-prefixed text in the acme window body.

**State:** Holds a `Nine_P.Client.Fs` connection (opened from `Agent_Task`).
Tracks `Current_Tool_Name` for the `End_Tool` label.

**Key rendering choices:**
- `Append_Text` ÃÂ¢ÃÂÃÂ writes tokens directly to `/winid/data` via 9P append.
  Sets addr to `$` before each write so text lands at the end.
- `Begin_Tool` ÃÂ¢ÃÂÃÂ writes a tool-header line with the gear glyph, tool name,
  and a plumb token (`coyote-session+UUID/tool/TOKEN`) for button-3 navigation.
- `End_Tool` ÃÂ¢ÃÂÃÂ appends check (ÃÂ¢ÃÂÃÂ) or cross (ÃÂ¢ÃÂÃÂ) and elapsed time.
- `Append_Notice` ÃÂ¢ÃÂÃÂ prefixes line with `[!]` (error), `[~]` (warning), or `[i]` (info).
- `Read_Prompt` ÃÂ¢ÃÂÃÂ blocks on `App_State.Wait_Prompt` (entry called by
  `Acme_Event_Task` when the user sends a "Send" event).
- `Shutdown` ÃÂ¢ÃÂÃÂ writes a footer line; calls `App_State.Signal_Shutdown`.

---

### 5.32 `Coyote_App.Frontend.GUI`

**Purpose:** GTK3 frontend implementation. Drives the conversation view via
the `Coyote_GUI.Updates` queue.

**State:** Holds an access to the `GtkApplicationWindow`, the
`Coyote_GUI.Buffer.Instance`, and a reference to the `Prompt_Queue`. A
menu-bar action map provides Compact, Pause, Resume, New Session, and model
selection commands.

**Key rendering choices:**
- All `Append_Text`, `Begin_Tool`, `End_Tool`, etc. calls enqueue a
  `Coyote_GUI.Update` record onto `Coyote_GUI.Updates`. A GLib idle handler
  drains the queue on the GTK main-loop thread and calls the corresponding
  `Coyote_GUI.Buffer` operations.
- `Read_Prompt` ÃÂ¢ÃÂÃÂ blocks on `Coyote_GUI.Prompt_Queue.Dequeue`.
- `Set_Stats_Summary` ÃÂ¢ÃÂÃÂ not part of the abstract interface; called directly
  from `Dispatch_Event` via a classwide `if P in GUI.Instance'Class` check
  to set the status-bar model/cost summary.
- `Shutdown` ÃÂ¢ÃÂÃÂ calls `Gtk.Main.Quit` from within the idle callback.

---

### 5.33 `Coyote_App.Frontend.Plain`

**Purpose:** Plain-text frontend for `--one-shot` mode and non-TTY output.

**Rendering:** All output goes to `Ada.Text_IO.Standard_Output`. No ANSI
escape codes. Thinking blocks are suppressed (not printed). Tool calls are
rendered as `[tool: <name>]` ÃÂ¢ÃÂÃÂ¦ `[/tool]` text markers. Notices are prefixed
with `[ERROR]`, `[WARN]`, or `[INFO]`.

**`Read_Prompt`:** In `--one-shot` mode, the prompt is pre-loaded from the
`--prompt` argument or from stdin; `Read_Prompt` returns it on the first call
and returns `""` (signalling shutdown) on all subsequent calls.

---

### 5.34 `Coyote_GUI`

**Purpose:** Root package for the GUI subsystem. Defines the `Update_Kind`
enumeration and the `Update` discriminated record.

**`Update_Kind` values:** `Append_Text`, `End_Text_Block`, `Append_Thinking`,
`Begin_Thinking`, `End_Thinking`, `Begin_Tool`, `End_Tool`, `Append_Notice`,
`Append_Turn_Footer`, `Set_Mode`, `Shutdown`, `Set_Stats`.

**`Update` record:** Discriminant is `Update_Kind`. Each variant carries the
payload fields appropriate to that kind (e.g. `Append_Text` carries a
`Text : Unbounded_String`; `Begin_Tool` carries `Tool_Id`, `Tool_Name`).

---

### 5.35 `Coyote_GUI.Updates`

**Purpose:** Thread-safe bounded queue from `Agent_Task` to the GTK main loop.

**Protected type `Queue`:** Bounded buffer of `Coyote_GUI.Update` records,
capacity 8 192. Operations: `Enqueue (U : Update)` (blocks when full;
`Agent_Task` may block briefly if GTK is slow), `Dequeue (U : out Update;
Got : out Boolean)` (non-blocking; sets `Got := False` if empty), `Is_Empty`.

**GLib idle handler:** Registered once by `Coyote_App.Frontend.GUI.Create`.
On each idle callback, drains up to 64 items from the queue and calls the
corresponding `Coyote_GUI.Buffer` operations, then returns `True` to remain
registered (or `False` if a `Shutdown` item was dequeued).

---

### 5.36 `Coyote_GUI.Prompt_Queue`

**Purpose:** Thread-safe bounded queue from the GTK main loop to `Agent_Task`.

**Protected type `Queue`:** Bounded buffer of `Unbounded_String`, capacity 64.
Operations: `Enqueue (S : String)` (non-blocking; drops if full, which is
impossible under normal use), `Dequeue (S : out Unbounded_String)` (blocking
entry; `Agent_Task` waits here between turns).

---

### 5.37 `Coyote_Utils`

**Purpose:** CLI argument resolution and session prefix stripping utilities
shared by the entry-point packages.


**`Read_Whole_File (Path : String) ÃÂ¢ÃÂÃÂ String`:** Reads the entire contents
of `Path` as a `String` using `Stream_IO` chunk-based reading (8 KB buffer).
Unlike `Ada.Text_IO.Get_Line` which recurses linearly with line length, this
function handles arbitrarily long lines (including single-line JSON files)
without stack overflow.  Returns `""` when `Path` is empty or does not exist.

**`Read_File_If_Exists (Path : String) ÃÂ¢ÃÂÃÂ String`:** Thin wrapper that
delegates to `Read_Whole_File`.  Preserved for backward compatibility.

**`Resolve_Prompt_Arg (Arg : String) ÃÂ¢ÃÂÃÂ String`:** If `Arg` starts with `@`,
reads and returns the content of the named file; otherwise returns `Arg`
as-is.
**`Resolve_Prompt_Arg (Arg : String) ÃÂ¢ÃÂÃÂ String`:** If `Arg` starts with `@`,
reads and returns the content of the named file; otherwise returns `Arg`
as-is.

**`Strip_Session_Prefix (S : String) ÃÂ¢ÃÂÃÂ String`:** Removes a
`coyote-session+` prefix and any trailing path components from a plumb token,
returning just the UUID.

**`Bad_Arg_Error` exception:** Raised when a CLI argument is unrecognised or
malformed; caught in `coyote.adb` and printed to stderr.

---

### 5.38 `Acme`

**Purpose:** Root package for the acme subsystem. Defines the
`Win_File_Path` helper.

**`Win_File_Path (Win_Id : Natural; File : String) ÃÂ¢ÃÂÃÂ String`:** Returns the
9P path `"/<Win_Id>/<File>"` (e.g. `"/42/ctl"`, `"/42/data"`). Used by
`Acme.Window` and `Acme.Event_Parser` to construct VFS paths.

---

### 5.39 `Acme.Window`

**Purpose:** High-level acme window operations over 9P.

**Key subprograms:**
- `Write_Body (Fs; Win_Id; Text)` ÃÂ¢ÃÂÃÂ sets addr to `$`, writes `Text` to
  `/Win_Id/data`.
- `Write_Ctl (Fs; Win_Id; Cmd)` ÃÂ¢ÃÂÃÂ writes a control command string to
  `/Win_Id/ctl`.
- `Write_Tag (Fs; Win_Id; Text)` ÃÂ¢ÃÂÃÂ appends `Text` to the window tag.
- `Clear_Body (Fs; Win_Id)` ÃÂ¢ÃÂÃÂ sets addr to `,`, writes empty string to data
  (erases the entire body).
- `Set_Name (Fs; Win_Id; Name)` ÃÂ¢ÃÂÃÂ writes `"name <Name>"` to ctl.

All subprograms take an explicit `Fs : not null access Nine_P.Client.Fs` so
the caller's task-local connection is used; never shares an `Fs` across tasks.

---

### 5.40 `Acme.Event_Parser`

**Purpose:** Parses acme event-file records into structured `Event` values.

**`Event` record fields:** `C1`, `C2` (origin and type characters), `Q0`,
`Q1` (character range), `Flag`, `Nr`, `Text` (event text).

**`Parse_Event (Raw : String) ÃÂ¢ÃÂÃÂ Event`:** Parses one line from the acme event
file. Returns a zero-valued `Event` if the line is malformed.

**`Is_Button2_Exec (E : Event) ÃÂ¢ÃÂÃÂ Boolean`:** Returns `True` when `C1 = 'E'`
and `C2 = 'x'` (button-2 execute in body).

---

### 5.41 `Acme.Raw_Events`

**Purpose:** Low-level byte accumulator for the acme event file.

**`Feed (Bytes : String; On_Record : access procedure (R : String))`:**
Buffers bytes and calls `On_Record` for each complete newline-terminated
event record. Handles partial reads that split a record across two `Feed`
calls.

---

### 5.42 `Nine_P`

**Purpose:** Root package for the 9P2000 protocol implementation. Defines
`Qid`, `Byte_Array`, and protocol constants (`NOTAG`, `NOFID`, version
string `"9P2000"`).

**No subprograms:** All logic lives in child packages.

---

### 5.43 `Nine_P.Proto`

**Purpose:** Encodes and decodes 9P2000 T-messages and R-messages.

**Key subprograms:**
- `Encode_Tversion`, `Encode_Tattach`, `Encode_Twalk`, `Encode_Topen`,
  `Encode_Tread`, `Encode_Twrite`, `Encode_Tclunk` ÃÂ¢ÃÂÃÂ build byte arrays for
  each T-message type.
- `Decode_Rversion`, `Decode_Rattach`, `Decode_Rwalk`, `Decode_Ropen`,
  `Decode_Rread`, `Decode_Rwrite` ÃÂ¢ÃÂÃÂ parse R-message byte arrays into record
  fields.
- `Encode_String (S : String) ÃÂ¢ÃÂÃÂ Byte_Array` ÃÂ¢ÃÂÃÂ length-prefixed UTF-8 string
  per 9P2000 wire format.

**Error handling:** `Proto_Error` exception raised on truncated or malformed
R-message bytes.

---

### 5.44 `Nine_P.Client`

**Purpose:** 9P2000 client; provides mount, open, read, write, and clunk
over a UNIX socket.

**`Fs` type:** Protected object wrapping a socket file descriptor and a fid
allocator. Each public operation acquires the lock, performs the T/R exchange,
and releases the lock.

**Key operations:**
- `Ns_Mount (Ns_Name : String) ÃÂ¢ÃÂÃÂ Fs` ÃÂ¢ÃÂÃÂ connects to the named namespace socket
  (e.g. `"/tmp/ns.user.:0/acme"`), performs `Tversion`/`Rattach` handshake.
- `Open (Fs; Path : String; Mode : Open_Mode) ÃÂ¢ÃÂÃÂ File` ÃÂ¢ÃÂÃÂ walks and opens a
  9P file; returns a `File` handle.
- `Read (File; Count : Natural) ÃÂ¢ÃÂÃÂ String` ÃÂ¢ÃÂÃÂ sends `Tread`; returns data.
- `Write (File; Data : String)` ÃÂ¢ÃÂÃÂ sends `Twrite`.
- `Clunk (File)` ÃÂ¢ÃÂÃÂ sends `Tclunk`; closes the fid.

**Critical constraint:** `Fs` instances must never be shared across Ada tasks.
Each task creates its own `Fs` via `Ns_Mount`.

---

### 5.45 `Session_Lister`

**Purpose:** Enumerates saved sessions for the current directory and formats
them for display.

**`List_Sessions (CWD : String) ÃÂ¢ÃÂÃÂ Session_Info_Array`:** Scans
`~/.coyote/sessions/<cwd-slug>/` for `*.jsonl` files, reads the first record
of each to extract the session header (timestamp, model, first user message
preview), and returns the array sorted by creation time (newest first).

**`Format_For_Display (Info : Session_Info) ÃÂ¢ÃÂÃÂ String`:** Formats one entry
as a human-readable line: `UUID  YYYY-MM-DD HH:MM  model  preview`.

Used by `coyote_list_sessions` and by the GUI frontend's session-picker
menu.

---

### 5.46 `LLM.Agent` ÃÂ¢ÃÂÃÂ `Request_Abort`, `Request_Pause`, and `Resume`

*(Supplement to ÃÂÃÂ§5.5, which covers `Create` and `Run_Prompt`.)*

**`Request_Abort (S : in out Session)`:** Sets `S.Abort_Flg`. The libcurl
write callback and the tool executor both poll this flag; the current
operation terminates at the next check point. `Run_Prompt` detects the flag
at the top of its outer loop and exits cleanly.

**`Request_Pause (S : in out Session)`:** Sets `S.Pause_Flg`. After the
current tool call completes (or immediately if no tool call is active),
`Run_Prompt` enters a `S.Pause_Flg.Wait_If_Cleared` entry call that blocks
`Agent_Task` until `Resume` is called. `Agent_Paused_Event` is emitted before
blocking; `Agent_Resumed_Event` is emitted after unblocking.

**`Resume (S : in out Session)`:** Clears `S.Pause_Flg`, unblocking the
`Wait_If_Cleared` entry.

## 6. Requirements Traceability

| Requirement ID | Implementing unit(s) |
|---|---|
| REQ-CORE-001ÃÂ¢ÃÂÃÂ005 | `Coyote` (entry point) |
| REQ-CORE-010ÃÂ¢ÃÂÃÂ023 | `Coyote` (entry point), `Coyote_Utils` |
| REQ-CORE-030ÃÂ¢ÃÂÃÂ032 | `Coyote` (entry point), `LLM.Session_Store` |
| REQ-CORE-040ÃÂ¢ÃÂÃÂ046 | `LLM.Agent`, `Coyote_App.Dispatch`, all frontends |
| REQ-CORE-050ÃÂ¢ÃÂÃÂ055 | `LLM.Tools.Shell`, `LLM.Tools.Temp_File`, `LLM.Agent` |
| REQ-CORE-060ÃÂ¢ÃÂÃÂ064 | `LLM.Agent`, `LLM.Compaction`, `LLM.Session_Store` |
| REQ-CORE-070ÃÂ¢ÃÂÃÂ076 | `LLM.Agent`, `LLM.Settings`, `LLM.Model_Registry`, all providers |
| REQ-CORE-080ÃÂ¢ÃÂÃÂ084 | `LLM.Session_Store`, `Session_Lister` |
| REQ-CORE-090ÃÂ¢ÃÂÃÂ093 | `LLM.Skills`, `LLM.System_Prompt` |
| REQ-CORE-100ÃÂ¢ÃÂÃÂ109 | `Coyote_App.Frontend.Acme_Win`, `Coyote_App`, `Acme.Window`, `Nine_P.Client`, `LLM.Settings` |
| REQ-CORE-110ÃÂ¢ÃÂÃÂ115 | `Coyote_App.Frontend.GUI`, `Coyote_GUI.Buffer`, `Coyote_Cmark` |
| REQ-CORE-120ÃÂ¢ÃÂÃÂ121 | `Coyote_App.Frontend.Plain` |
| REQ-CORE-130ÃÂ¢ÃÂÃÂ131 | `Coyote_App.History`, all frontends |
| REQ-CORE-140ÃÂ¢ÃÂÃÂ142 | `LLM.Agent`, `Coyote_App.Dispatch`, all frontends |
| REQ-CORE-200ÃÂ¢ÃÂÃÂ203 | `LLM.Providers.*`, `LLM.HTTP`, `LLM.SSE` |
| REQ-CORE-210ÃÂ¢ÃÂÃÂ212 | `Nine_P.Client`, `Acme.Window`, `Coyote_App.Frontend.Acme_Win` |
| REQ-CORE-220ÃÂ¢ÃÂÃÂ221 | `Coyote_App.Frontend.GUI`, `Coyote_GUI.*` |
| REQ-CORE-230ÃÂ¢ÃÂÃÂ233 | `LLM.Settings`, `LLM.Auth`, `LLM.Auth.GitHub_Copilot` |
| REQ-CORE-240ÃÂ¢ÃÂÃÂ241 | `LLM.Session_Store` |
| REQ-CORE-300ÃÂ¢ÃÂÃÂ302 | `Coyote_App.Frontend`, `LLM.Events`, `LLM.Tools.Temp_File` |
| REQ-CORE-400ÃÂ¢ÃÂÃÂ402 | `LLM.Types`, `LLM.Compaction`, `LLM.Agent` |
| REQ-CORE-500ÃÂ¢ÃÂÃÂ505 | Build system (Alire/GPRbuild); runtime dependencies |
| REQ-CORE-600ÃÂ¢ÃÂÃÂ601 | `LLM.Compaction` (unbounded growth prevention); `Coyote_App` (GTK threading) |
| REQ-CORE-700ÃÂ¢ÃÂÃÂ704 | `LLM.HTTP` (streaming latency); `LLM.Session_Store` (persistence); all frontends (error visibility) |
| REQ-CORE-800ÃÂ¢ÃÂÃÂ805 | Build system; `Coyote_App.Utils` (UC_* constants); all packages (.ads/.adb split) |
| REQ-CORE-160 | `share/man/man1/coyote.1` (static man page) |

---

## 7. Notes

**Relationship to AGENTS.md:**
`AGENTS.md` contains the authoritative agent working instructions ÃÂ¢ÃÂÃÂ coding
standards, build commands, skill-loading discipline, and source layout
reference. This SDD extracts the design content from AGENTS.md and organises
it under the structured SDD checklist. The two documents are complementary:
AGENTS.md for day-to-day development guidance; this document for structured
design traceability and review. When they conflict, this document (as a
controlled artifact) takes precedence; AGENTS.md should be updated to match.

**Independence limitation:**
This design description was authored by the developer. The user (product
owner) is invited to review it before it advances to client-control status.

**Excluded scope:**
- `coyote_sqc` design: see `design/coyote-sqc-design.md`.
- `coyote_renderer` design: covered implicitly in `design/coyote-sqc-design.md ÃÂÃÂ§10`.
- Detailed design for catalogue packages (`OpenRouter.Catalogue`, etc.):
  deferred; covered adequately by AGENTS.md ÃÂÃÂ§Adding a New LLM Provider.
