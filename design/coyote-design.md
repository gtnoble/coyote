# coyote Design Description (SDD-CORE)

**Component:** coyote (core agent executable and shared libraries)
**Version:** 1.0
**Date:** 2026-06-01
**Status:** Draft — awaiting design review
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
by separate design documents (`docs/sqc-spec.md`).

---

## 2. Referenced Documents

| ID | Title | Location |
|---|---|---|
| SRS-CORE | coyote Requirements Specification | `requirements/coyote-requirements.md` |
| PLAN | Project Plan | `plan/project-plan.md` |
| AGENTS | Agent Working Instructions | `AGENTS.md` |
| SRS-SQC | coyote_sqc Requirements Specification | `docs/sqc-requirements.md` |

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

1. **Recoverable provider errors** (transient HTTP failures, rate limits) —
   the agent loop retries up to three times with exponential backoff. Each
   retry emits an `Auto_Retry_Start_Event` visible to the user.

2. **Non-recoverable turn errors** (malformed JSON, authentication failure,
   context overflow) — the agent loop terminates the current turn, records
   the error in the `App_State` protected object, and emits an error notice
   to the frontend via `Dispatch_Event`.

3. **Task boundary exceptions** — any unhandled exception in `Agent_Task`
   is caught at the task body boundary, logged to stderr, appended as an
   error notice to the frontend, and triggers a graceful shutdown sequence.

### 3.3 Concurrency Model

The application has two execution paths with different task structures.

**Acme path** — five long-lived Ada tasks:

| Task | Owns |
|---|---|
| `Agent_Task` | `LLM.Agent.Session`; the agentic loop |
| `Acme_Event_Task` | 9P event-file reader; tag command dispatch |
| `Plumb_Model_Task` | `/coyote-model` plumb port reader |
| `Plumb_Thinking_Task` | `/coyote-thinking` plumb port reader |
| `Plumb_Fork_Task` | `/coyote-fork` plumb port reader |

**GUI path** — two tasks:

| Task | Owns |
|---|---|
| Main Ada task | GTK event loop (`Gtk.Main.Main`) |
| `Agent_Task` | `LLM.Agent.Session`; the agentic loop |

**Shared-state rule:** All inter-task mutable state is held in the
`App_State` protected object. Tasks never share `Nine_P.Client.Fs` instances
(each task that accesses the 9P VFS creates its own connection).

**GTK thread safety:** All GTK operations execute on the main Ada task. The
`Agent_Task` communicates with the GTK main loop through two thread-safe
protected queues: `Coyote_GUI.Updates` (agent → GTK, bounded at 8192 items)
and `Coyote_GUI.Prompt_Queue` (GTK → agent, bounded at 64 items). A GLib
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
  libcmark-gfm → Pango markup → `Insert_Markup`.

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

## 4. Architectural Design

### 4.1 Software Unit Inventory

| Unit | Type | Source files |
|---|---|---|
| `Coyote` | Entry point | `src/coyote.adb` |
| `Coyote_App` | App state + entry procedures | `src/coyote_app.ads/.adb` |
| `Coyote_App.Dispatch` | Event→frontend dispatch | `src/coyote_app-dispatch.ads/.adb` |
| `Coyote_App.History` | Session replay | `src/coyote_app-history.ads/.adb` |
| `Coyote_App.Utils` | Formatting utilities + UC_* glyphs | `src/coyote_app-utils.ads/.adb` |
| `Coyote_App.Frontend` | Abstract frontend interface | `src/coyote_app-frontend.ads` |
| `Coyote_App.Frontend.Acme_Win` | Acme frontend implementation | `src/coyote_app-frontend-acme_win.ads/.adb` |
| `Coyote_App.Frontend.GUI` | GTK3 frontend implementation | `src/coyote_app-frontend-gui.ads/.adb` |
| `Coyote_App.Frontend.Plain` | Plain-text frontend implementation | `src/coyote_app-frontend-plain.ads/.adb` |
| `Coyote_GUI` | GUI root (Update_Kind, Update record) | `src/coyote_gui/coyote_gui.ads` |
| `Coyote_GUI.Updates` | Protected agent→GTK queue | `src/coyote_gui/coyote_gui-updates.ads/.adb` |
| `Coyote_GUI.Prompt_Queue` | Protected GTK→agent queue | `src/coyote_gui/coyote_gui-prompt_queue.ads/.adb` |
| `Coyote_GUI.Buffer` | GtkTextBuffer wrapper + markdown rendering | `src/coyote_gui/coyote_gui-buffer.ads/.adb` |
| `Coyote_Utils` | CLI arg resolution, session prefix stripping | `src/coyote_utils.ads/.adb` |
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
        │
        ▼
[Application orchestration]
  Coyote_App ─────► Coyote_App.Frontend (abstract)
  Coyote_App.Dispatch ──► Coyote_App.Frontend'Class
  Coyote_App.History  ──► LLM.Session_Store, Coyote_App.Frontend'Class
  Coyote_App.Utils
        │
        ├─► Coyote_App.Frontend.Acme_Win ──► Acme.Window, Nine_P.Client
        ├─► Coyote_App.Frontend.GUI ──► Coyote_GUI.Buffer, Coyote_GUI.Updates,
        │                                  Coyote_GUI.Prompt_Queue
        └─► Coyote_App.Frontend.Plain
        │
        ▼
[Agent layer]
  LLM.Agent ──► LLM.Providers'Class, LLM.Tools, LLM.Compaction,
                LLM.Session_Store, LLM.Model_Registry, LLM.Skills,
                LLM.System_Prompt, LLM.Types, LLM.Events
        │
        ▼
[Provider layer]
  LLM.Providers.OpenAI_Completions ──► LLM.HTTP, LLM.SSE, LLM.Types
  LLM.Providers.Anthropic_Messages ──► LLM.HTTP, LLM.SSE, LLM.Types
  LLM.Providers.OpenRouter         ──► LLM.Providers.OpenAI_Completions
  LLM.Providers.GitHub_Copilot     ──► LLM.Providers.OpenAI_Completions,
                                        LLM.Providers.Anthropic_Messages,
                                        LLM.Auth.GitHub_Copilot
  LLM.Providers.OpenCode_Go        ──► LLM.Providers.OpenAI_Completions,
                                        LLM.Providers.Anthropic_Messages
        │
        ▼
[Infrastructure layer]
  LLM.HTTP ──► LLM.HTTP.Curl_Binding (libcurl C binding)
  LLM.SSE  (pure parser, no external dependencies)
  Nine_P.Client ──► Nine_P.Proto
  Coyote_Cmark ──► coyote_cmark_c.c (C shim for libcmark-gfm)
```

### 4.3 Dynamic Relationships — Acme Path Concept of Execution

```
[startup]
  Coyote.main
    → parse CLI args
    → detect frontend (Acme)
    → Coyote_App.Run(Opts)

[Coyote_App.Run]
  → create App_State (protected)
  → create Acme_Win frontend
  → spawn Agent_Task
  → spawn Acme_Event_Task   (reads /winid/event via 9P)
  → spawn Plumb_Model_Task  (reads /coyote-model plumb port)
  → spawn Plumb_Thinking_Task
  → spawn Plumb_Fork_Task
  → main task blocks on App_State.Wait_Shutdown

[Agent_Task loop]
  → LLM.Agent.Create(S, ...)   ; load settings, populate model registry
  → loop:
      prompt ← Frontend.Read_Prompt    ; blocks on Acme_Event_Task signal
      LLM.Agent.Run_Prompt(S, prompt, On_Event => Dispatch_Event'Access)
        → build system prompt (skills, settings)
        → build request JSON
        → LLM.HTTP.Post_Stream → SSE → provider events
        → On_Event called for each event (synchronous)
        → if tool_use: execute tool, append result, repeat LLM call
        → persist each turn to JSONL
      if App_State.Was_Aborted: exit loop

[Acme_Event_Task]
  → reads event file in /winid/event
  → "Send" button-2 → writes prompt to App_State, signals Agent_Task
  → "Stop" button-2 → sets Abort_Flag in LLM.Tools
  → other commands → handled inline or forwarded to Agent_Task via App_State
```

### 4.4 Dynamic Relationships — GUI Path Concept of Execution

```
[startup]
  Coyote.main
    → parse CLI args
    → detect frontend (GUI)
    → Coyote_App.Run_GUI(Opts)

[Coyote_App.Run_GUI]
  → Gtk.Main.Init
  → Frontend.GUI.Create (builds GtkApplicationWindow)
  → spawn Agent_Task
  → Gtk.Main.Main (blocks main task on GTK event loop)

[Agent_Task loop]
  → LLM.Agent.Create(S, ...)
  → loop:
      prompt ← Frontend.Read_Prompt
           → blocks on Coyote_GUI.Prompt_Queue.Dequeue
      if prompt starts with ':' → Execute_GUI_Command
      else LLM.Agent.Run_Prompt(S, prompt, On_Event => Dispatch_Event'Access)
           → On_Event → Dispatch_Event
                → Coyote_GUI.Updates.Enqueue(update)
           → GTK idle callback drains Updates queue
                → Coyote_GUI.Buffer operations on GtkTextBuffer

[GTK callbacks]
  → Send button / Enter key → Coyote_GUI.Prompt_Queue.Enqueue(prompt_text)
  → Stop menu → LLM.Tools.Abort_Flag.Set
  → Compact / Pause / Resume menu → Coyote_GUI.Prompt_Queue.Enqueue(":compact" etc.)
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
`COYOTE_NO_SESSION`, `COYOTE_SESSION_ID`, `COYOTE_PARENT_SESSION`.

**Outputs:** `Coyote_App.Options` record passed to `Run` or `Run_GUI`;
environment variable `COYOTE_FRONTEND` set when GUI is selected.

**Control flow:**
1. Parse arguments sequentially. Each recognised flag sets the corresponding
   field in `Opts`. Unknown arguments trigger `Put_Line (Standard_Error, ...)`.
2. If `$COYOTE_NO_SESSION` is set, force `Opts.No_Session := True`.
3. If `--session UUID` was given and the session's working directory exists,
   call `Ada.Directories.Set_Directory`.
4. Evaluate frontend selection rules in priority order; set `Opts.Frontend`.
5. If GUI selected, call `Ada.Environment_Variables.Set ("COYOTE_FRONTEND", "gui")`.
6. Dispatch to `Coyote_App.Run` (Acme/Plain) or `Coyote_App.Run_GUI` (GUI).

**Error handling:** `Coyote_Utils.Bad_Arg_Error` is caught at the outermost
level; error message goes to stderr; exit status is set to Failure.

---

### 5.2 `Coyote_App` (App_State and Run/Run_GUI)

**Purpose:** Application lifecycle management; inter-task shared state.

**`App_State` protected type:**
All fields are protected by Ada's monitor semantics. Key fields:
- `Session_Id`, `Current_Model`, `Current_Thinking` — identity and model state
- `Is_Streaming`, `Is_Compacting`, `Was_Aborted` — agent loop phase flags
- `Is_Paused`, `Is_Pause_Armed` — pause/resume handshake
- `Turn_Count`, `Turn_Cost_Dmil`, `Session_Cost_Dmil` — statistics accumulators
- `Context_Window` — set by Model_Select_Event; used for compaction threshold

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
- `History: LLM.Types.Message_Vectors.Vector` — in-memory conversation
- `Session_Id: Unbounded_String`
- `Model_Info: LLM.Model_Registry.Model_Info`
- `Settings: LLM.Settings.Config`
- `Compact_Settings: LLM.Compaction.Compact_Settings`
- `Tools: LLM.Tools.Descriptor_Array` (empty when `No_Tools`)
- `Abort_Flg: aliased LLM.Tools.Abort_Flag`

**`Create` procedure:**
1. Load settings from `~/.coyote/settings.json` and `~/.coyote/models.json`.
2. Refresh each provider's model catalogue (Copilot, OpenRouter, OpenCode).
3. Select the model: `--model` arg → settings → first registry entry.
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
    result ← execute tool (LLM.Tools.Shell.Execute or error if No_Tools)
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
   - `content_delta` → `Message_Update_Event (Text_Delta)`
   - `tool_call delta` → `Message_Update_Event (Tool_Call_Delta)`
   - `[DONE]` → `Message_End_Event`
6. Special case for image tool results: split into text stub + follow-up
   user message with `image_url` (OAI does not accept vision in role=tool).

**`Wire_Format` field:** `"openai-completions"` — used by `LLM.Agent` to
determine the `tools` JSON schema shape.

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
   - `content_block_start` with `type=thinking` → `Thinking_Start`
   - `content_block_delta` with `thinking_delta` → `Thinking_Delta`
   - `content_block_start` with `type=text` → `Text_Start`
   - `content_block_delta` with `text_delta` → `Text_Delta`
   - `content_block_stop` → `Text_End` or `Thinking_End`
   - `message_delta` with `stop_reason` → `Message_End_Event`

---

### 5.8 `LLM.Providers.GitHub_Copilot`

**Purpose:** Routing provider; selects wire format based on model ID.

**`Send` procedure:**
1. Call `LLM.Auth.GitHub_Copilot.Ensure_Valid_Token` (refreshes if needed).
2. Inspect model ID: if it matches a known Claude model pattern → use
   `Anthropic_Messages.Provider`; otherwise → use `OpenAI_Completions.Provider`.
3. Construct the appropriate delegate with Copilot's base URL and token.
4. Forward the call.

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

**Purpose:** Discovers SKILL.md files from four roots and formats them for
inclusion in the system prompt.

**Discovery order:** `~/.coyote/skills/`, `~/.agents/skills/`,
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
- `thinking` — dim/italic left-gutter style for thinking blocks
- `notice_info`, `notice_warning`, `notice_error` — coloured inline notices
- `turn_footer` — smaller/dimmer turn statistics line
- `code` — monospace for inline code and fenced blocks
- `bold`, `italic`, `strikethrough`, `link` — standard GFM formatting
- `blockquote` — reduced opacity

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
  ⏳ pending indicator.
- `End_Tool` locates the frame by `Tool_Id` (stored in a lookup table), updates
  the label icon (✓ / ✗ / ✕) and optionally shows an error preview.

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

## 6. Requirements Traceability

| Requirement ID | Implementing unit(s) |
|---|---|
| REQ-CORE-001–005 | `Coyote` (entry point) |
| REQ-CORE-010–023 | `Coyote` (entry point), `Coyote_Utils` |
| REQ-CORE-030–032 | `Coyote` (entry point), `LLM.Session_Store` |
| REQ-CORE-040–046 | `LLM.Agent`, `Coyote_App.Dispatch`, all frontends |
| REQ-CORE-050–055 | `LLM.Tools.Shell`, `LLM.Tools.Temp_File`, `LLM.Agent` |
| REQ-CORE-060–064 | `LLM.Agent`, `LLM.Compaction`, `LLM.Session_Store` |
| REQ-CORE-070–076 | `LLM.Agent`, `LLM.Settings`, `LLM.Model_Registry`, all providers |
| REQ-CORE-080–084 | `LLM.Session_Store`, `Session_Lister` |
| REQ-CORE-090–093 | `LLM.Skills`, `LLM.System_Prompt` |
| REQ-CORE-100–108 | `Coyote_App.Frontend.Acme_Win`, `Coyote_App`, `Acme.Window`, `Nine_P.Client` |
| REQ-CORE-110–115 | `Coyote_App.Frontend.GUI`, `Coyote_GUI.Buffer`, `Coyote_Cmark` |
| REQ-CORE-120–121 | `Coyote_App.Frontend.Plain` |
| REQ-CORE-130–131 | `Coyote_App.History`, all frontends |
| REQ-CORE-140–142 | `LLM.Agent`, `Coyote_App.Dispatch`, all frontends |
| REQ-CORE-200–203 | `LLM.Providers.*`, `LLM.HTTP`, `LLM.SSE` |
| REQ-CORE-210–212 | `Nine_P.Client`, `Acme.Window`, `Coyote_App.Frontend.Acme_Win` |
| REQ-CORE-220–221 | `Coyote_App.Frontend.GUI`, `Coyote_GUI.*` |
| REQ-CORE-230–233 | `LLM.Settings`, `LLM.Auth`, `LLM.Auth.GitHub_Copilot` |
| REQ-CORE-240–241 | `LLM.Session_Store` |
| REQ-CORE-300–302 | `Coyote_App.Frontend`, `LLM.Events`, `LLM.Tools.Temp_File` |
| REQ-CORE-400–402 | `LLM.Types`, `LLM.Compaction`, `LLM.Agent` |
| REQ-CORE-500–505 | Build system (Alire/GPRbuild); runtime dependencies |
| REQ-CORE-600–601 | `LLM.Compaction` (unbounded growth prevention); `Coyote_App` (GTK threading) |
| REQ-CORE-700–704 | `LLM.HTTP` (streaming latency); `LLM.Session_Store` (persistence); all frontends (error visibility) |
| REQ-CORE-800–805 | Build system; `Coyote_App.Utils` (UC_* constants); all packages (.ads/.adb split) |

---

## 7. Notes

**Relationship to AGENTS.md:**
`AGENTS.md` contains the authoritative agent working instructions — coding
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
- `coyote_sqc` design: see `docs/sqc-spec.md`.
- `coyote_renderer` design: covered implicitly in `docs/sqc-spec.md §10`.
- Detailed design for catalogue packages (`OpenRouter.Catalogue`, etc.):
  deferred; covered adequately by AGENTS.md §Adding a New LLM Provider.
