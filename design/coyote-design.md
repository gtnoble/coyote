# coyote Design Description (SDD-CORE)

**Component:** coyote (core agent executable and shared libraries)
**Version:** 1.25
**Date:** 2026-08-31

**Status:** Reviewed — project control (M3 complete 2026-06-02)
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

**Current architecture amendment (2026-08-30):** The supported architecture
contains GTK3 and Plain execution paths. The former Acme frontend, Nine_P
9P stack, plumber tasks, and `coyote_open` utility were removed. Historical
sections that describe those components remain as design history and are not
part of the current build.

**Accepted virtual-agent-window amendment (2026-08-31):** The GUI organizes
coordinator-launched short-lived subagents as virtual windows in an agents tree
rather than mapping one top-level GUI window per subagent. The main agent is the
tree root; selecting an agent displays its independent conversation state in
the shared conversation view and directs prompts and agent controls to that live
agent. This is an organization and presentation change, not a persistent-agent
change: `--subagent` retains its initial-prompt, active-steering, final-response,
and process-exit lifecycle. The development implementation is present; focused
registry/RPC qualification passes, while display-backed and real-provider
end-to-end qualification remain open.


**Component identifier:** coyote

This document describes the software design of the coyote core agent: the
design decisions that govern the component as a whole, the structural
decomposition into software units (Ada packages and tasks), the interfaces
among them, the concept of execution, and the detailed design of each major
unit. It covers the `coyote` executable, `coyote_list_sessions`, and the shared
library packages in `src/llm/`, `src/coyote_gui/`, and the shared renderer.
The former Acme/Nine_P design sections are retained only as historical record.

The `coyote_sqc` application and `coyote_renderer` shared library are covered
by separate design documents (`design/coyote-sqc-design.md`). Historical
Acme/Nine_P sections below are retained for traceability only.

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

The current application has two execution paths with different structures.

**Historical Acme path** — removed from the current baseline:

| Task | Owns |
|---|---|
| `Agent_Task` | `LLM.Agent.Session`; the agentic loop |
| `Acme_Event_Task` | 9P event-file reader; tag command dispatch |
| `Plumb_Model_Task` | `/coyote-model` plumb port reader |
| `Plumb_Thinking_Task` | `/coyote-thinking` plumb port reader |
| `Plumb_Fork_Task` | `/coyote-fork` plumb port reader |
| `Plumb_Sandbox_Task` | `/coyote-sandbox` plumb port reader |

**Current GUI path** — two tasks:

| Task | Owns |
|---|---|
| Main Ada task | GTK event loop (`Gtk.Main.Main`) |
| `Agent_Task` | `LLM.Agent.Session`; the agentic loop |

**Shared-state rule:** All inter-task mutable state is held in the
`App_State` protected object. GUI widgets are accessed only by the GTK main
task; the agent task communicates through protected queues.

**GTK thread safety:** All GTK operations execute on the main Ada task. The
`Agent_Task` communicates with the GTK main loop through two thread-safe
protected queues: `Coyote_GUI.Updates` (agent → GTK, bounded at 8192 items)
and `Coyote_GUI.Prompt_Queue` (GTK → agent, bounded at 64 items). A GLib
idle callback drains `Updates` on the GTK thread.

### 3.4 External Interface Design Decisions

**HTTP and SSE:** The HTTP client is a native libcurl binding
(`LLM.HTTP.Curl_Binding`). Streaming is driven by the libcurl write callback
in the calling task; the SSE parser is called synchronously from that callback.
No additional thread is created for HTTP I/O. The active session's protected
`Abort_Flag` maintains an atomic C mirror. Requests install a native
`CURLOPT_XFERINFOFUNCTION` callback that polls that mirror while libcurl is
blocked, returning nonzero to terminate the transfer promptly.

**GTK3:** All GTK3 calls use Ada bindings from the GtkAda library. `Gtk.Main.Init`
and `Gtk.Main.Main` are called from the main Ada task. Before constructing
windows, `Coyote_App.Frontend.GUI.Create` registers the executable-relative
`$BASE/share/icons` directory with the default GTK icon theme. This makes the
tracked `coyote` SVG available to both the main window and in-process dialogs
without requiring an externally configured `XDG_DATA_DIRS`.

**Markdown rendering:** The GUI frontend renders completed assistant text blocks
using libcmark-gfm (via the `Coyote_Cmark` Ada binding and the `coyote_cmark_c.c`
C shim). Enum constants are resolved once at package elaboration time via the
C shim's getter functions. Raw streamed tokens are inserted as plain text and
replaced with Pango markup when the block completes (`End_Text_Block`).

### 3.5 Output Media and Formats

- **GUI frontend:** GTK3 native widget hierarchy hosted by
  `Coyote_GUI.Conversation_Stack`. Each exchange contains native text views,
  step frames, tool cards, footers, fork controls, notices, and localized
  Lasem-backed display math. Plain UTF-8 text is rendered directly while
  streaming and completed blocks use the shared GFM path. Selection is local
  to semantic components, and one outer scroller hosts the conversation.

- **Plain frontend:** Plain UTF-8 to stdout. No ANSI escape codes.

### 3.6 Reuse of Shared Data and Services

- **Session persistence:** The GUI and Plain paths share `LLM.Session_Store`
  for JSONL read and write.
- **Skill discovery:** Both paths share `LLM.Skills.Load_Skills` and
  `Format_Skills_For_Prompt`.
- **Settings:** Both paths share `LLM.Settings.Load` and `LLM.Auth.Load`.
- **Model registry:** Both paths share `LLM.Model_Registry`.
- **Dispatch:** Both paths share `Coyote_App.Dispatch.Dispatch_Event`. The GUI
  path also calls `Coyote_App.Frontend.GUI.Set_Stats_Summary` on
  `Session_Stats_Event` for the menu-item display; this is a GUI-specific
  extension beyond the abstract interface.

The Plain path is synchronous and does not initialize GTK or use the GUI
queues. It owns its agent session, replays requested history, dispatches native
events, and reads additional prompts from standard input.


---

### 3.7 Memory and Processing Allocation

**Queue bounds:**
- `Coyote_GUI.Updates` — bounded at 8 192 items. Each item is a
  `Coyote_GUI.Update` record (kind discriminant + one Unbounded_String payload).
  The bound was chosen to allow several full streaming turns to be buffered
  without back-pressure while keeping per-session RSS impact below ~1 MB.
- `Coyote_GUI.Prompt_Queue` — bounded at 64 items. Commands are short strings;
  a small bound is sufficient because prompt entry is rate-limited by human
  interaction speed.

**Task stacks:** All tasks use the default GNAT runtime stack size (8 MiB on
Linux x86-64). No task has been observed to approach this limit; no explicit
`Storage_Size` clause is needed.

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
| `Coyote_App.Dispatch` | Event→frontend dispatch | `src/coyote_app-dispatch.ads/.adb` |
| `Coyote_App.History` | Session replay | `src/coyote_app-history.ads/.adb` |
| `Coyote_App.Utils` | Formatting utilities + UC_* glyphs | `src/coyote_app-utils.ads/.adb` |
| `Coyote_App.Frontend` | Abstract frontend interface | `src/coyote_app-frontend.ads` |
| `Coyote_App.Frontend.GUI` | GTK3 frontend implementation, agents tree, and selected virtual-window presentation | `src/coyote_app-frontend-gui.ads/.adb` |
| `Coyote_App.Frontend.Plain` | Plain-text frontend implementation | `src/coyote_app-frontend-plain.ads/.adb` |
| `Coyote_App.Frontend.RPC` | Headless coordinator RPC frontend for short-lived subagents | `src/coyote_app-frontend-rpc.ads/.adb` |
| `Coyote_App.Agent_Registry` | Live agent-node hierarchy, endpoint classification, and selected-agent routing state | `src/coyote_app-agent_registry.ads/.adb` |
| `Coyote_App.Agent_RPC` | Local bidirectional RPC codec, listener, event routing, and control transport | `src/coyote_app-agent_rpc.ads/.adb` |
| `Coyote_GUI` | GUI root (Update_Kind, Update record) | `src/coyote_gui/coyote_gui.ads` |
| `Coyote_GUI.Updates` | Protected agent→GTK queue | `src/coyote_gui/coyote_gui-updates.ads/.adb` |
| `Coyote_GUI.Prompt_Queue` | Protected GTK→agent queue | `src/coyote_gui/coyote_gui-prompt_queue.ads/.adb` |
| `Coyote_GUI.Conversation_Stack` | Native GTK exchange and per-step frame host/update router | `src/coyote_gui/coyote_gui-conversation_stack.ads/.adb` |
| `Coyote_GUI.Exchange_View` | Deferred; exchange realization is owned by `Conversation_Stack` in this build | Not separate in qualification build |
| `Coyote_GUI.Text_Element` | Deferred; native text-element realization is owned by `Conversation_Stack` in this build | Not separate in qualification build |
| `Coyote_GUI.Tool_Card` | Deferred; native tool-card realization is owned by `Conversation_Stack` in this build | Not separate in qualification build |
| `Coyote_GUI.Math_Element` | Native Lasem-backed display-math widget with selectable fallback source | `src/coyote_gui/coyote_gui-math_element.ads/.adb` |
| `Coyote_GUI.Footer_Element` | Deferred; typed footer realization is owned by `Conversation_Stack` in this build | Not separate in qualification build |
| `Coyote_GUI.Tool_Detail_Window` | Structured GTK tool-call detail window | `src/coyote_gui/coyote_gui-tool_detail_window.ads/.adb` |
| `Coyote_GUI.Session_Stats_Window` | Reusable live session-statistics support window | `src/coyote_gui/coyote_gui-session_stats_window.ads/.adb` |
| `Coyote_GUI.Sandbox_Profile_Window` | Reusable modeless GTK sandbox profile manager with browse/edit views and profile CRUD controls | `src/coyote_gui/coyote_gui-sandbox_profile_window.ads/.adb` |
| `Coyote_GUI.Zoom` | Zoom-level ↔ font-size arithmetic (pure logic) | `src/coyote_gui/coyote_gui-zoom.ads/.adb` |
| `Coyote_GUI.Navigation` | Clamped keyboard viewport navigation policy | `src/coyote_gui/coyote_gui-navigation.ads/.adb` |
| `Coyote_Utils` | CLI arg resolution, file reading, session prefix stripping, active executable resolution, and POSIX shell quoting | `src/coyote_utils.ads/.adb` |
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
| `LLM.Providers.OpenAI_Responses` | OpenAI Responses wire | `src/llm/llm-providers-openai_responses.ads/.adb` |
| `LLM.Providers.Anthropic_Messages` | Anthropic Messages wire | `src/llm/llm-providers-anthropic_messages.ads/.adb` |
| `LLM.Providers.OpenRouter` | OpenRouter adapter | `src/llm/llm-providers-openrouter.ads/.adb` |
| `LLM.Providers.GitHub_Copilot` | Copilot routing provider | `src/llm/llm-providers-github_copilot.ads/.adb` |
| `LLM.Providers.OpenCode_Go` | OpenCode Go routing provider | `src/llm/llm-providers-opencode_go.ads/.adb` |
| `LLM.Tools` | Abort_Flag, Pause_Flag, Tool_Descriptor | `src/llm/llm-tools.ads/.adb` |
| `LLM.Tools.Shell` | Built-in shell tool and tracked process-group execution | `src/llm/llm-tools-shell.ads/.adb` |
| `LLM.Tools.Sandbox` | Sandbox profile discovery and bwrap arg construction | `src/llm/llm-tools-sandbox.ads/.adb` |
| `Coyote_Process_Control` | SIGTERM bridge, shell process-group registry, persistence freeze, and escalation | `src/coyote_process_control.ads/.adb`, `src/coyote_signal_bridge.c/.h` |
| `LLM.Tools.Temp_File` | Tool-result size cap and spill | `src/llm/llm-tools-temp_file.ads/.adb` |
| `LLM.Skills` | Skill discovery and system prompt formatting | `src/llm/llm-skills.ads/.adb` |
| `LLM.System_Prompt` | System prompt construction and resource rendering | `src/llm/llm-system_prompt.ads/.adb`, `share/coyote/system-prompt.md` |
| `LLM.Compaction` | Context compaction helpers | `src/llm/llm-compaction.ads/.adb` |
| `LLM.Memory` | Memory taxonomy and MEMORY.md discovery | `src/llm/llm-memory.ads/.adb` |
| `LLM.Session_Store` | JSONL session persistence | `src/llm/llm-session_store.ads/.adb` |
| `LLM.Agent` | Native agentic loop | `src/llm/llm-agent.ads/.adb` |
| `Coyote_Cmark` | Ada binding to libcmark-gfm | `src/coyote_cmark.ads/.adb` |
| `Coyote_Lasem` | Ada/C binding to Lasem Presentation MathML rendering | `src/coyote_lasem.ads/.adb`, `src/coyote_lasem_c.c` |
| `Coyote_Renderer` | Shared GTK text/replay rendering root | `src/coyote_renderer/coyote_renderer.ads` |
| `Coyote_Renderer.Markup` | GFM Markdown to Pango markup converter | `src/coyote_renderer/coyote_renderer-markup.ads/.adb` |
| `Coyote_Renderer.MathML` | Markdown-aware display-math extraction with code-block protection | `src/coyote_renderer/coyote_renderer-mathml.ads/.adb` |
| `Coyote_Renderer.Tables` | GTK-independent GFM table extraction and metadata model | `src/coyote_renderer/coyote_renderer-tables.ads/.adb` |
| `Coyote_Renderer.Session_View` | Read-only session replay renderer | `src/coyote_renderer/coyote_renderer-session_view.ads/.adb` |
| `Coyote_Notify` | Ada/C binding to libnotify desktop notifications | `src/coyote_notify.ads/.adb`, `src/coyote_notify_c.c` |
| `Coyote_GUI.Notification_Policy` | Pure completion-notification eligibility policy | `src/coyote_gui/coyote_gui-notification_policy.ads/.adb` |
| `Session_Lister` | Session listing for coyote_list_sessions | `src/session_lister.ads/.adb` |
| `Test_Suites` | Root AUnit suite composer | `test/src/test_suites.ads/.adb` |
| `Test_Core_Suite` | Core test-domain suite composer | `test/src/test_core_suite.ads/.adb` |
| `Test_LLM_Suite` | LLM/provider test-domain suite composer | `test/src/test_llm_suite.ads/.adb` |
| `Test_SQC_Suite` | SQC test-domain suite composer | `test/src/test_sqc_suite.ads/.adb` |
| `Test_GUI_Suite` | GUI test-domain suite composer | `test/src/test_gui_suite.ads/.adb` |
| `Test_Integration_Suite` | Optional subprocess integration suite composer | `test/src/test_integration_suite.ads/.adb` |
| `Test_Process_Control_Suite` | Final process-control test-domain suite | `test/src/test_process_control_suite.ads/.adb` |
| `*_Tests.Suite` | Leaf AUnit fixture suite functions (54 fixtures) | `test/src/*_tests.ads/.adb` |

### 4.2 Static Relationships

The dependency hierarchy flows from the application entry points down through
three layers:

```
[Entry points]
  Coyote (coyote.adb)
  Coyote_List_Sessions (tools/coyote_list_sessions.adb)
        │
        ▼
[Application orchestration]
  Coyote_App ─────► Coyote_App.Frontend (abstract)
  Coyote_App.Dispatch ──► Coyote_App.Frontend'Class
  Coyote_App.History  ──► LLM.Session_Store, Coyote_App.Frontend'Class
  Coyote_App.Utils
        │
        ├─► Coyote_App.Frontend.GUI ──► Coyote_GUI.Conversation_Stack,
        │                                  Coyote_GUI.Exchange_View,
        │                                  Coyote_GUI.Tool_Detail_Window,
        │                                  Coyote_GUI.Session_Stats_Window,
        │                                  Coyote_GUI.Text_Element,
        │                                  Coyote_GUI.Tool_Card,
        │                                  Coyote_GUI.Math_Element,
        │                                  Coyote_GUI.Footer_Element,
        │                                  Coyote_GUI.Updates,
        │                                  Coyote_GUI.Prompt_Queue
        └─► Coyote_App.Frontend.Plain
        │
        ▼
[Agent layer]
  LLM.Agent ──► LLM.Providers'Class, LLM.Tools, LLM.Compaction,
                LLM.Session_Store, LLM.Model_Registry, LLM.Skills,
                LLM.Memory, LLM.System_Prompt, LLM.Types, LLM.Events
        │
        ▼
[Provider layer]
  LLM.Providers.OpenAI_Completions ──► LLM.HTTP, LLM.SSE, LLM.Types
  LLM.Providers.OpenAI_Responses   ──► LLM.HTTP, LLM.SSE, LLM.Types
  LLM.Providers.Anthropic_Messages ──► LLM.HTTP, LLM.SSE, LLM.Types
  LLM.Providers.OpenRouter         ──► LLM.Providers.OpenAI_Responses
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
  Coyote_Cmark ──► coyote_cmark_c.c (C shim for libcmark-gfm)
  Coyote_Renderer.Tables ──► Coyote_Cmark
  Coyote_GUI.Conversation_Stack ──► Coyote_Renderer.Tables,
                                      Coyote_Renderer.Markup,
                                      Coyote_Renderer.MathML
  Coyote_Notify ──► libnotify, GLib, GDK-Pixbuf
```

### 4.3 Historical Acme Path Concept of Execution (retired)

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
  → spawn Plumb_Model_Task    (reads /coyote-model plumb port)
  → spawn Plumb_Thinking_Task (reads /coyote-thinking plumb port)
  → spawn Plumb_Fork_Task     (reads /coyote-fork plumb port)
  → spawn Plumb_Sandbox_Task  (reads /coyote-sandbox plumb port)
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
  → "Continue" button-2 → enqueues "Continue." prompt, resumes agentic loop
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
  → Frontend.GUI.Create (registers `$BASE/share/icons`, then builds
    GtkApplicationWindow)
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
                → Coyote_App.Frontend.GUI routes updates to
                  Coyote_GUI.Conversation_Stack
                → the native stack performs all GTK operations on the GTK main
                  task

[GTK callbacks]
  → Send button / Return or keypad Enter → Coyote_GUI.Prompt_Queue.Enqueue(prompt_text)
       (Ctrl+Return is an explicit Send accelerator; Shift+Return and
        Alt+Return remain newline-capable text editing)
  → Stop menu → LLM.Tools.Abort_Flag.Set
  → Compact / Pause / Resume menu → Coyote_GUI.Prompt_Queue.Enqueue(":compact" etc.)
  → Options → Preferences... → GTK dialog edits persistent defaults and
      completion-notification preference
      → Coyote_GUI.Prompt_Queue.Enqueue(Set_Preferences payload)
      → Agent_Task persists settings and updates the current GUI on success

[completion]
  → Agent_End_Event (non-aborted interactive GUI run)
  → Session_Stats_Event
  → final turn footer update
  → Completion_Notification update
  → GTK main task checks Gtk.Window.Is_Active
  → Coyote_Notify calls libnotify only when the window is inactive
```

**Implemented virtual-agent-window flow:**

```
[coordinator GUI]
  → create the agents tree and local RPC listener
  → register the main agent as the root virtual window
  → launch a coordinator-launched --subagent with runtime agent identity
  → receive the child's structured events through bidirectional RPC
  → update that agent's retained conversation state and tree-row status
  → when the user selects a live node, route prompts and agent controls to it
  → retain completed, aborted, failed, or disconnected nodes for review

[headless subagent]
  → use the RPC frontend when coordinator channel context is supplied
  → process the initial prompt and active steering messages
  → publish streaming conversation and lifecycle events
  → emit its final response and exit after the existing one-shot lifecycle
```

The planned agents tree is a presentation-level virtual window manager. It
retains independent process and session state for each subagent without
merging conversations or keeping subagent processes alive after completion.
The selected node is the driver's-seat target: prompts and applicable agent
controls are routed to that live process. A completed or exited node remains
selectable for inspection but cannot receive a new prompt.

### 4.5 Design Decisions Affecting Multiple Units

**Decision D-001: Frontend abstraction at event granularity, not text granularity.**
The `Frontend'Class` interface operates at the level of structured events
(Begin_Tool, End_Tool, Begin_Thinking, etc.) rather than raw character
streams. This allows the GUI to maintain typed widget state while the Plain
frontend formats the same event stream as line-oriented UTF-8 text. *Rationale:
A text-only interface would force the GUI to re-parse event semantics from
rendered text, which is fragile and lossy.*

**Decision D-002: On_Event callback invoked synchronously in the agent task.**
`Run_Prompt` calls `On_Event` in the same task that called `Run_Prompt`. The
callback must not block. The GUI agent task uses the protected Updates queue to
cross to the GTK main task; the Plain runner consumes events synchronously.
*Rationale: A single callback path avoids duplicated event translation while
keeping GTK operations on the GTK main task.*
**Decision D-003: Routing providers delegate to wire-format providers.**
GitHub Copilot and OpenCode Go each support multiple wire formats (OpenAI
Chat Completions and Anthropic). These are implemented as *routing
providers* that inspect the model ID, construct the appropriate delegate
(`OpenAI_Completions.Provider` or `Anthropic_Messages.Provider`), and
forward the request. OpenRouter delegates to `OpenAI_Responses.Provider`.
Native OpenAI uses `OpenAI_Responses.Provider` directly. Completions
remains the compatibility wire for Copilot, OpenCode Go, and Ollama.
*Rationale: Avoids duplicating SSE parsing and JSON construction; adds a
new wire format by adding one package, not by modifying all routing
providers. Completions is not replaced in place because existing backends
still speak `/chat/completions`.*

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

**Physical-window launch:** The GUI `Fork` action and `File → New Window`
launches use the active executable with explicit `--frontend gui` and the
internal `--physical-window` marker. Fork adds `--session <UUID>` and a
window label, while New Window starts a fresh session. Both launches pass the
current working directory to the detached-spawn wrapper and omit
`--subagent`, so they create independent interactive GTK processes rather
than coordinator virtual agents. The entry point clears inherited RPC,
agent-runtime, session-lineage, no-session, and recursion-depth variables for
physical windows before frontend and session initialization.

**Purpose:** CLI argument parsing and GUI/Plain frontend selection.

**Inputs:** `Ada.Command_Line.Argument_Count` / `Argument`; environment
variables `$DISPLAY`, `$WAYLAND_DISPLAY`, `COYOTE_FRONTEND`,
`COYOTE_NO_SESSION`, `COYOTE_SESSION_ID`, `COYOTE_PARENT_SESSION`,
`COYOTE_OPENROUTER_SESSION_ID`, `COYOTE_THINKING_LEVEL`,
`COYOTE_RECURSION_DEPTH`.

**Outputs:** `Coyote_App.Options` record passed to `Coyote_App.Plain.Run` or
`Coyote_App.Run_GUI`. Ordinary explicitly separate GUI windows may propagate
`COYOTE_FRONTEND=gui`; coordinator-launched `--subagent` processes use the
planned headless RPC frontend instead.

**Control flow:**
1. Parse arguments sequentially. Each recognised flag sets the corresponding
   field in `Opts`. Unknown arguments trigger `Put_Line (Standard_Error, ...)`.
2. Before frontend, session, or provider startup, load `maxRecursionDepth`
   (default 1) and parse the inherited `COYOTE_RECURSION_DEPTH` (default 0).
   Increment only for `--subagent`; reject an incremented value above the
   maximum, or malformed inherited text, through `Bad_Arg_Error`. Export the
   resulting depth for descendants. Ordinary coyote processes preserve the
   inherited value; forks and New Window processes do not add a level because
   they do not use `--subagent`.
2a. If `$COYOTE_THINKING_LEVEL` is set, `Coyote_App.Run` inherits the
    parent's thinking level, overriding the `defaultThinkingLevel` from
    `settings.json`.
2. If `$COYOTE_NO_SESSION` is set, force `Opts.No_Session := True`.
3. If `--session UUID` was given and the session's working directory exists,
   call `Ada.Directories.Set_Directory`.
4. Evaluate the frontend selection rules: explicit `--frontend gui|plain`
   wins; otherwise select Plain for non-subagent one-shot runs, GUI when a
   display or `COYOTE_FRONTEND=gui` is present, and Plain otherwise.
5. Propagate GUI context only to ordinary child processes that are intended to have their own physical GUI window. Pass the coordinator RPC channel and runtime agent identities to coordinator-launched subagents.
6. Dispatch to `Coyote_App.Plain.Run` for Plain or `Coyote_App.Run_GUI` for GUI.

**Error handling:** `Coyote_Utils.Bad_Arg_Error` is caught at the outermost
level; error message goes to stderr; exit status is set to Failure.

---

### 5.2 `Coyote_App` (App_State and Run_GUI)

**Purpose:** Application lifecycle management; inter-task shared state.

**`App_State` protected type:**
All fields are protected by Ada's monitor semantics. Key fields:
- `Session_Id`, `Current_Model`, `Current_Thinking` — identity and model state
- `Is_Streaming`, `Is_Compacting`, `Was_Aborted` — agent loop phase flags
- `Is_Paused`, `Is_Pause_Armed` — pause/resume handshake
- `Turn_Count`, `Turn_Cost_Dmil`, `Session_Cost_Dmil` — statistics accumulators
- `Context_Window` — set by Model_Select_Event; used for compaction threshold

**`Run_GUI` procedure:** Calls `Gtk.Main.Init`, creates the GUI frontend,
spawns `Agent_Task`, then calls `Gtk.Main.Main`. GUI creation registers the
executable-relative icon search path before assigning the `coyote` themed icon
to any window or dialog.

---

### 5.3 `Coyote_App.Dispatch`

**Purpose:** Maps each `LLM.Events.Agent_Event'Class` value to the appropriate
`Frontend'Class` primitive calls. Shared by the GUI and Plain execution paths.

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
| `Tool_Execution_End_Event` | `End_Tool`; on last tool in batch: `Append_Turn_Footer` (step-level display) then `Append_Fork_Action` (step-level) |
| `Message_End_Event` | record stats in App_State |
| `Session_Stats_Event` | `Append_Turn_Footer` (full-turn display) then `Append_Fork_Action` (full-turn); GUI: typed `Set_Stats_Summary` snapshot |
| `Model_Select_Event` | `Append_Notice (Info, ...)` |
| `Auto_Retry_Start_Event` | `Append_Notice (Warning, ...)` |
| `Auto_Compaction_Start/End_Event` | `Append_Notice (Info/Warning, ...)` |
| `Agent_Paused_Event` | `Set_Mode (Paused)` |
| `Agent_Resumed_Event` | `Set_Mode (Running)` |

**Step-level turn footers:** After the last `Tool_Execution_End_Event` in a
batch, the dispatch layer calls `Append_Turn_Footer` and `Append_Fork_Action`.
The GUI renders the action strip; Plain ignores the action. The step counter is
maintained in `App_State` alongside `Turn_Count`.

---

### 5.3.5 Thinking-text buffering and collapsing

**Problem:** SSE streaming from LLM providers delivers thinking tokens as short
chunks (1–5 words) with leading/trailing newlines and internal line breaks.
Naive per-chunk rendering produces illegible fragmented output:
```
│ The
│  user
│  wants me
```
instead of flowing prose:
```
│ The user wants me to…
```

**Solution (PCR-022 resolution, 2026-06-07; revised PCR-039, 2026-06-27):**
The GUI and Plain frontends buffer thinking deltas between `Begin_Thinking`
and `End_Thinking`, collapse the accumulated text, and emit flowing prose on
flush. This avoids fragmented token-by-token display.

**Collapsing algorithm:**
- Spaces are treated as content, not whitespace — they carry word-boundary
  information from providers like Anthropic that delimit tokens with
  leading spaces (e.g. `" the"`, `" edits"`)
- Single `\n` or `\r` → collapsed to space (restores word boundaries across
  OpenAI-style deltas that terminate each token with trailing `\n`)
- `\n\n` (paragraph breaks) → preserved as blank line
- Leading and trailing LF, CR, HT trimmed; spaces preserved
- Implemented in `Coyote_App.Utils.Collapse_Thinking_Delta` (pure function)

**Frontend implementation:**
- `Begin_Thinking`: Set `Prefix_Emitted` flag to false, mark thinking active
- `Append_Thinking`: Collapse delta via `Collapse_Thinking_Delta`, emit with
  box-drawing prefix on first call; subsequent deltas are concatenated
  directly (no inter-delta separator — spacing is handled by the collapse
  function itself)
- `End_Thinking`: Append final blank line, clear thinking state
- No `Last_Ended_With_LF` tracking — the collapse function produces
  self-contained output with all spacing resolved internally

**Architectural rationale:** Display layer owns rendering semantics. Providers
remain wire-format-neutral and emit raw SSE deltas. Collapsing occurs
per-delta in each frontend's `Append_Thinking`, producing immediate
streaming output without buffering.  The collapse function normalises both
OpenAI-style (trailing-`\n`) and Anthropic-style (leading-space) deltas
into concatenable prose fragments.

**Test coverage:** 8 `Collapse_Thinking_Delta` unit tests in
`test/src/collapse_utils_tests.adb` cover all edge cases: single-LF→space,
paragraph preservation, empty input, no-LF verbatim, space preservation,
OpenAI trailing-LF stripping, OpenAI mid-stream LFs→spaces, and LF/HT-only
whitespace.  `Test_Dispatch_Thinking_Delta` in
`test/src/coyote_app_tests.adb` and the frontend tests verify thinking-delta dispatch.

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
- `Sandbox_Profile: Unbounded_String` — active sandbox profile name
- `Tools: LLM.Tools.Descriptor_Array` (empty when `No_Tools`)
- `Abort_Flg: aliased LLM.Tools.Abort_Flag`

**`Create` procedure:**
1. Load settings from `~/.coyote/settings.json` and `~/.coyote/models.json`.
2. Refresh each configured provider's model catalogue or curated defaults
   (Copilot, OpenRouter, Anthropic, OpenCode Go, native OpenAI, Ollama).
3. Select the model: `--model` arg → settings → first registry entry.
4. Create or resume session via `LLM.Session_Store`.
5. Load conversation history if resuming.
6. Build the system prompt (static preamble + skills + agent arg).
7. For a resumed session, replace the inherited value with the
   `sandboxProfile` value from the session header; an absent field clears the
   profile.
8. Emit `Session_Info_Event` and `Model_Select_Event`.

**`Switch_Session` procedure:**
1. Validate the target session UUID.
2. Read the target header's `sandboxProfile` through
   `LLM.Session_Store.Session_Sandbox_Profile`.
3. Replace the active profile, allowing an absent field to clear it.
4. Load the target history and recalculate context tokens.
5. Clear abort state, release pause state, and stop streaming.

**`Session_Sandbox_Profile` function:** Reads the first JSONL header record,
returns its non-empty `sandboxProfile` string, and returns an empty string for
missing files, malformed headers, or absent fields.

**`Run_Prompt` loop:**
```
append user message to History
loop:
  derive request history, omitting foreign/unknown model-bound thinking
  build request JSON (compatible history + tools + system prompt)
  call provider.Send(request, On_Event callback)
  -- provider invokes On_Event synchronously for each streamed event
  if was_aborted: exit
  append assistant message to History
  if no tool calls in response: exit
  --  Phase 1: emit Tool_Execution_Start_Event for every tool in call order.
  --  Phase 2: execute tools.  If all tools carry a run_group > 0 then
  --    group by run_group value, sort groups ascending, execute each group's
  --    tools concurrently within the group; otherwise execute every tool
  --    sequentially in call order.
  --  Phase 3: emit Tool_Execution_End_Event for every tool in call order;
  --    append each tool result to History.
  --  The run_group field is stripped from arguments JSON before the tool
  --  executor sees it.
  persist the pending user/assistant/tool-result batch
end loop
-- check compaction threshold; compact if needed
emit Session_Stats_Event
```

Pending messages are consumed from the persistence queue only after each JSONL
append succeeds. If a provider or persistence exception escapes, the remaining
unpersisted suffix is removed from in-memory history. Already-persisted tool
calls/results remain intact, preserving external side-effect history.

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
used by GitHub Copilot, OpenCode Go, and Ollama compatibility paths.

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
determine the nested Completions `tools` JSON schema shape. Distinct from
`"openai-responses"` (see §5.6a).

**Cache breakpoints:** `Build_Request_Body` places `cache_control` markers
on (1) the system message, (2) the last message with `role:"user"` or
`role:"tool"`, and (3) the last tool definition.  The user/tool message
breakpoint advances each turn to encompass the entire conversation prefix,
yielding near-zero cache miss rates for legacy Completions providers that
honour the `cache_control` field (for example GitHub Copilot). Responses
providers use `prompt_cache_breakpoint` instead.

**`Customize_Request` (non-overriding):** Maps `Thinking_Level` to the
OpenAI `reasoning.effort` request field (`"low"`, `"medium"`, `"high"`).
When `Thinking` is `Off` this is a no-op.  This base implementation applies
to all providers routing through the OpenAI completions wire format —
GitHub Copilot (OpenAI-wire path) and OpenCode Go (OpenAI-wire path).
Descendants may override to add provider-specific logic.
---

### 5.6a `LLM.Providers.OpenAI_Responses`

**Purpose:** OpenAI Responses wire format implementation. Sibling of
`OpenAI_Completions`, not a replacement. Used by native OpenAI and by
OpenRouter.

**`Send` procedure flow:**
1. Build `input` JSON array from `History`. Role mapping:
   - user / compaction-summary → `{type:"message", role:"user", content:[{type:"input_text", text}]}`
   - assistant text → `{type:"message", role:"assistant", content:[{type:"output_text", text}]}`
   - assistant tool calls → `{type:"function_call", id?, call_id, name, arguments}`
   - assistant thinking → `{type:"reasoning", id, summary, encrypted_content?}`
   - tool results → `{type:"function_call_output", call_id, output}`
     (`output` is a string, or an array of `input_text` / `input_image` parts
     when the result carries an image).
2. Set `instructions` from `System_Prompt` (not a system-role message).
3. Build `tools` as a flat array of `{type:"function", name, description,
   parameters}` objects. `LLM.Agent.Build_Tools_Json` emits this shape when
   `Wire_Format` is `"openai-responses"`.
4. Set `max_output_tokens`, `stream: true`, and `reasoning.effort` from
   `Thinking_Level` (`Off` → omit or `none`; `Minimal` → `minimal`; `Low` →
   `low`; `Medium` → `medium`; `High` → `high`; `X_High` → `xhigh`).
5. Do not send `store: true` or `previous_response_id`. Conversation state
   remains client-owned JSONL. OpenRouter rejects both fields with HTTP 400.
6. POST `{Base_Url}/responses` via `LLM.HTTP.Post`.
7. For each SSE event, dispatch on JSON `type` (the SSE `event:` name
   matches). Map to frontend events:
   - `response.output_text.delta` / `.done` → `Text_Start` / `Text_Delta` / `Text_End`
     Completed message items are suppressed by output-item ID when the same
     item already emitted streamed text; this is independent of frontend block
     state.
   - `response.reasoning_text.delta` / `.done` and
     `response.reasoning_summary_text.delta` / `.done` → `Thinking_*`
   - `response.output_item.added` with `item.type=function_call` → `Tool_Call_Start`
   - `response.function_call_arguments.delta` / `.done` → `Tool_Call_Delta` / `Tool_Call_End`
   - `response.completed` → `Message_End` + usage
   - `response.incomplete` → `Message_End` (`Length` or `Error_Stop` from
     `incomplete_details.reason`)
   - `response.failed` / `error` → `Error_Stop`
   There is no `[DONE]` sentinel. Unused event types (web search, MCP, code
   interpreter, image gen, shell, apply_patch) are ignored.
8. Infer `Stop_Reason`: any `function_call` in `output` → `Tool_Use`;
   `incomplete` + `max_output_tokens` → `Length`; `failed` /
   `content_filter` → `Error_Stop`; otherwise `Stop`.
9. Parse usage from `response.completed.response.usage`: `input_tokens`,
   `output_tokens`, `input_tokens_details.cached_tokens` → `Cache_Read`,
   `input_tokens_details.cache_write_tokens` → `Cache_Write`,
   `output_tokens_details.reasoning_tokens` → `Thinking`.

**Prompt cache breakpoints:** On content parts that support it, emit
`prompt_cache_breakpoint: {mode:"explicit"}` on the last user or
tool-result input item, and on the last tool definition if the provider
documents that extension. Completions-style `cache_control` markers shall
not be sent on this wire.

**Image tool results:** Native `input_image` inside `function_call_output`.
No Completions stub-plus-follow-up-user-message split.

**`Wire_Format` field:** `"openai-responses"`.

**Reasoning replay:** `Thinking_Block` carries `Origin_Provider`,
`Origin_Model`, and a `Signature` encoded object containing `id` and
`encrypted_content`. `LLM.Agent.Compatible_History` derives a non-mutating
request view that retains only thinking blocks owned by the active provider and
model; ordinary text, tool calls, and tool results remain portable. Switching
back therefore restores the originating model's encrypted reasoning. The
Responses adapter emits only recognized encoded signatures and requests
`reasoning.encrypted_content`.

**`Customize_Request`:** Same extension point as Completions so
descendants (OpenRouter) can add provider-specific fields without
forking the parser.

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
1. Load Copilot credentials from `~/.coyote/auth.json` and call
   `Ensure_Valid` to refresh the access token only when a request
   is actually made — no token refresh occurs at startup.
2. Inspect model ID: if it matches a known Claude model pattern → use
   `Anthropic_Messages.Provider`; otherwise → use `OpenAI_Completions.Provider`.
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
5. When an abort flag is supplied, `CURLOPT_XFERINFOFUNCTION` is enabled and
   receives the flag's atomic C mirror as userdata. The native callback returns
   nonzero when the flag is set, causing libcurl to terminate a blocked
   transfer without waiting for response data. The provider callback still
   checks the protected flag before dispatching each event.

---

### 5.10 `LLM.Tools.Shell`

**Purpose:** Executes the shell command provided by the model.

**`Execute` procedure:**
1. Parse `Args_Json`: extract `command`, `stdin` (optional), `media_type`
   (optional).
2. If `Sandbox_Profile` is non-empty, call
   `LLM.Tools.Sandbox.Build_Bwrap_Args` and prepend `bwrap` with base
   isolation (`--ro-bind / / --dev /dev --proc /proc`) and per-rule
   binds/ro-binds/tmpfs before `--`.
3. Reserve a launch in `Coyote_Process_Control`, then spawn a reset-wrapper
   command under `setsid(1)`. The wrapper restores the normal SIGTERM
   disposition before executing either `bwrap` or `$SHELL -lc command`.
4. Register the returned process-group leader before releasing the reservation;
   a shutdown racing `Start` signals the newly registered group immediately.
5. Write `stdin` content to the child's stdin if non-empty and read combined
   stdout/stderr.
6. If `media_type` non-empty: base64-encode the raw bytes; set `Media_Type`.
7. If result exceeds `LLM.Tools.Temp_File.Result_Threshold`: call
   `LLM.Tools.Temp_File.Truncated` before returning.
8. Set `Is_Error := exit_code /= 0`; unregister the group on every cleanup path.

For a positive `timeout`, a local supervisor races the timeout against the
abort flag.  Timeout sends SIGTERM through `Coyote_Process_Control.Signal_Group`,
waits the configured grace interval, and sends SIGKILL to the process group and
nested descendants if the command remains active.  Manual abort retains its
immediate SIGKILL policy.  The direct child is reaped exactly once before the
process group is unregistered.

**Process-wide shutdown:** `Coyote_Process_Control` receives SIGTERM through
an async-signal-safe self-pipe. Its deferred monitor freezes persistence,
rejects new shell launches, requests the agent abort, sends SIGTERM to all
registered groups and nested shell-launched coyote groups, waits the configured
0–30 second grace period, and sends SIGKILL to remaining groups. A second
SIGTERM skips the grace period. Only JSONL records whose writes completed before
persistence freeze are retained.

---

### 5.10a `LLM.Tools.Sandbox`

**Purpose:** Discovers sandbox profiles from `~/.coyote/sandbox/*.json`,
loads their rule sets, and constructs `bwrap` argument lists.

**Profile format:** Each profile is a JSON object with four optional array
fields: `allowWrite`, `denyWrite`, `denyRead`, `allowRead`.  Each array
contains paths; `~` and `./` prefixes are resolved at execution time.

**`Available_Profiles`:** Scans `~/.coyote/sandbox/` for `*.json` files;
returns the stems as profile names.  Returns an empty vector when the
directory is absent or no profiles exist.

**`Load_Profile(Name)`:** Reads and parses `~/.coyote/sandbox/<Name>.json`.
Returns `JSON_Null` when the profile is not found or parse fails.

**`Build_Bwrap_Args(Profile_Name, Cwd)`:** Resolves all paths in the loaded
profile relative to `Cwd`; skips paths that do not exist on disk; sorts
entries by path depth (slash count, shallowest first); produces `bwrap`
arguments: `--bind <path> <path>` for `allowWrite`, `--ro-bind <path> <path>`
for `denyWrite` and `allowRead`, `--tmpfs <path>` for `denyRead`.

**Typed profile management:** `Profile` owns four string vectors for the
allow-write, deny-write, deny-read, and allow-read rule arrays. Profile names
are validated as safe file stems before any path is formed. `Load_Profile_Typed`
parses a regular JSON profile and raises `Sandbox_Error` for invalid names,
missing files, malformed objects, wrong field types, or non-string array
members. `Save_Profile`/`Edit_Profile` replace profiles through an atomic
write; `Create_Profile` and `Copy_Profile` reject target collisions; and
`Rename_Profile` copies the validated definition to the new name without
removing the old file, preserving historical session-header references.
`LLM.Settings.Rename_Default_Sandbox` updates `defaultSandboxProfile` only when
it names the old profile and preserves unrelated settings fields. Session
JSONL headers are not rewritten.

**Profile serialization:** The four rule arrays are always written. Missing
arrays in an existing profile default to empty vectors for compatibility.
`Available_Profiles` filters regular `*.json` files to valid names and returns a
deterministically sorted vector.

**Integration:** Called by `LLM.Tools.Shell.Execute` when `Sandbox_Profile` is
non-empty. A non-empty invalid, missing, malformed, or unreadable profile
raises `Sandbox_Error` before bwrap arguments are generated, failing closed.
Path spelling is retained in stored profiles; at execution time `~`, `.`, and
`./` are resolved relative to the relevant home/CWD, absolute paths pass
through, and missing paths are skipped. `setsid` is the outer process started
by the executor; it executes `bwrap` for sandboxed commands, which then executes
the shell. Consequently the process handle returned by `Start` remains the
process-group leader used by `kill(-pid, SIGKILL)` for the complete tree.

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

**Thinking provenance:** Thinking content blocks persist `originProvider` and
`originModel`; assistant-level `provider` and `model` fields mirror the first
thinking block for compatibility. On load, explicit block fields take
precedence, followed by assistant fields, then the latest preceding
`model_change` record for legacy sessions. Missing provenance remains unknown.

---

### 5.12 `LLM.Compaction`

**Purpose:** Context compaction helpers: token estimation, cut-point
computation, summarisation-prompt construction, and auto-compaction
circuit-breaker control.

**`Estimate_Tokens(text)`:** Returns `text'Length / 4` (conservative
approximation; 4 bytes per token for code and prose).

**`Find_Cut_Point(History, Keep_Recent_Tokens)`:**
Walks the history in reverse; accumulates estimated tokens until the
`Keep_Recent_Tokens` budget is exhausted; returns the index of the oldest
message to retain.

**`Build_Compact_Prompt(History, Partial_Compact)`:** Constructs a nine-section
structured summarisation prompt. If `Partial_Compact` is true, the prompt
scopes to the earlier portion of history only (messages before the cut
point), producing a summary that will serve as a continuation preamble for
the retained verbatim tail. The prompt includes an `<analysis>` drafting
phase instruction; the analysis block is stripped from the summary before
it is stored or injected into context (REQ-CORE-065, REQ-CORE-066,
REQ-CORE-068).

**`Compact_Circuit_Breaker`:**
- `Consecutive_Failures : Natural := 0` — incremented on each failed
  compaction; reset to 0 on success.
- `Tripped : Boolean := False` — when `Consecutive_Failures` reaches 3,
  auto-compaction is suspended for the remaining session. Manual
  compaction is still available (REQ-CORE-067).

**`Compact_Settings`:**
- `Enabled`: whether auto-compaction is active.
- `Reserve_Tokens`: headroom reserved for the model's response (default 16 384).
- `Keep_Recent_Tokens`: minimum recent history to retain verbatim (default 20 000).

---

### 5.13 `LLM.Memory`

**Purpose:** Discovers and loads MEMORY.md index files, formats a four-type
memory taxonomy into the system prompt, and provides guidance for memory
save/retrieval behaviour (REQ-CORE-180..183).

**Opt-in gate:** Memory is disabled by default.  Set
`COYOTE_ENABLE_MEMORY=1` to enable it.  When disabled, no memory index
or taxonomy is injected into the system prompt.

**Discovery paths:** `~/.coyote/memory/MEMORY.md` and
`{CWD}/.coyote/MEMORY.md`. Each file is capped at 200 lines / 25 000 bytes;
excess is truncated with a warning.

**Memory taxonomy:** Four types documented in the system prompt —
`user` (who the user is, role, preferences), `feedback` (corrections and
confirmations with a required "Why:" line), `project` (ongoing work, goals,
bugs — not derivable from code), `reference` (pointers to external systems).
Each type carries `when_to_save` and `how_to_use` guidance.

**`Format_Memory_Taxonomy_For_Prompt`:** Returns the taxonomy description
block for inclusion in the system prompt, with instructions to search
existing memories before writing and to maintain the MEMORY.md index.

---

### 5.14 `LLM.Skills`

**Purpose:** Discovers SKILL.md files from the built-in and configured roots
and formats them for inclusion in the system prompt.

**Discovery order:** `~/.coyote/skills/`, `~/.agents/skills/`,
`$BASE/share/agents/skills/`, configured `skillPaths` roots in saved array
order, `{CWD}/.coyote/skills/`, and `{CWD}/.agents/skills/`. Within each root,
all `*/SKILL.md` paths are enumerated. Later roots replace earlier entries
with the same `name`, so project-local skills retain the highest precedence.

**YAML frontmatter parsing:** Only `name` and `description` fields are
extracted. Skills missing either are silently skipped.

**`Format_Skills_For_Prompt`:** Returns an XML-style `<available_skills>`
block containing `<skill>` entries for each discovered skill, or `""` if none.

---

### 5.15 `Coyote_GUI.Conversation_Stack`

**Purpose:** Sole GTK conversation presentation. The package owns one outer
vertical scroller and realizes each request/response exchange as native GTK
components. It is the only supported GTK conversation renderer; the retired
custom `Gtk.Layout`/Cairo/Pango renderer and `COYOTE_NATIVE_STACK` selection
flag are not part of the product.

**Hierarchy:** Each exchange contains a request element and one or more visible
step frames. Step frames contain thinking, response, tool-flow, footer, and
fork-action elements. Notices are placed at the appropriate exchange or step
level. Tool cards use native labels and argument-field grids, retain complete
`Tool_Info` payloads for the Details window, and update by stable `Tool_Id`.
The single outer scroller avoids nested scrolling regions for ordinary content.

**Content and interaction:** Streaming text is held in native text views and
completed blocks are replaced with shared GFM markup. Completed responses that
contain GFM tables are rebuilt as ordered native `Gtk.Grid` components with
selectable, wrapping cell labels; header cells use bold Pango markup and GFM
column alignment maps to label alignment. Standalone Presentation MathML is
realized through `Coyote_GUI.Math_Element`; invalid input retains selectable
source fallback. Selection and PRIMARY publication are local to one semantic
text component. With prompt focus, Edit commands target the prompt; otherwise
conversation commands resolve the focused conversation text view, then a
retained conversation selection, then the active response view. Native Details
and Fork buttons are focusable and operate on the GTK main task. Live updates
and session replay use the same lifecycle operations and hierarchy. SQC session
replay retains the shared Pango/text fallback.

**Lifecycle and reset:** `Begin_Request` starts an exchange, intermediate
footers close visible step frames, and `Complete_Request` closes the exchange.
Clear removes exchange widgets, retained tool payloads, and callback state
before new content is inserted. All mutation occurs on the GTK main task after
updates cross `Coyote_GUI.Updates`.

**Qualification:** Native Markdown, MathML, selection, zoom, tool-card flow,
replay, reset, and large-history behavior have been qualified under DEM-042
through DEM-048. The 17 native stack tests remain the automated regression
coverage for the presentation package.

### 5.16 `Coyote_Cmark` and `coyote_cmark_c.c`

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
three extensions attached before parsing. `Coyote_Renderer.Tables` obtains
column counts, alignment bytes, header-row state, and copied cell text through
scalar C shims; the extension-owned alignment array never crosses into Ada.
The shared Pango serializer remains the text fallback for SQC replay.

---

### 5.17 `LLM.Types`

**Purpose:** Defines the core data types shared across the agent, providers,
session store, and tools.

**Key types:**
- `Role_Type` — enumeration: `User`, `Assistant`, `Tool_Result`.
- `Content_Block` — discriminated record covering: `Text` (plain string),
  `Thinking` (reasoning block with signature), `Tool_Call` (id, name, arguments
  JSON string), `Tool_Result` (tool_call_id, content string, is_error flag,
  media_type), `Image` (base64 data + media_type).
- `Content_Block_Vectors.Vector` — ordered sequence of content blocks in one message.
- `Message` — record: role, content blocks, optional stop_reason, optional usage
  (input_tokens, output_tokens, cache_read_tokens, cache_creation_tokens).
- `Message_Vectors.Vector` — the conversation history type held by `LLM.Agent`.

**No logic:** `LLM.Types` contains only type definitions and default-initialisation
expressions. No subprograms are declared.

---

### 5.18 `LLM.Events`

**Purpose:** Defines the `Agent_Event'Class` tagged-type hierarchy emitted
by provider adapters and consumed by `Dispatch_Event`.

**Event types:**

| Type | Payload | Meaning |
|---|---|---|
| `Agent_Start_Event` | — | Agent turn beginning |
| `Agent_End_Event` | `Was_Aborted : Boolean` | Agent turn ending |
| `Message_Update_Event` | `Kind : Update_Kind`; `Text : String`; `Tool_Id : String` | Streaming token or tool delta |
| `Message_End_Event` | usage fields | Provider message completed |
| `Tool_Execution_Start_Event` | tool name, call_id, args JSON | Tool call started |
| `Tool_Execution_End_Event` | call_id, result text, is_error, duration | Tool call completed |
| `Session_Stats_Event` | turn count, cost, model info | Post-turn statistics |
| `Session_Info_Event` | session_id, thinking_level, sandbox_profile | Session identity at startup |
| `Model_Select_Event` | provider, model_id, context window | Model selected or changed |
| `Auto_Retry_Start_Event` | attempt number, reason | Transient error retry |
| `Auto_Compaction_Start_Event` | token count | Compaction beginning |
| `Auto_Compaction_End_Event` | tokens saved | Compaction complete |
| `Agent_Paused_Event` | — | Agent pause entered |
| `Agent_Resumed_Event` | — | Agent resumed from pause |

**Design constraint:** All event types are concrete; dispatching uses Ada
classwide (`Agent_Event'Class`). Events are value types (not heap-allocated in
normal use); the `On_Event` callback receives an `Agent_Event'Class` parameter.

---

### 5.19 `LLM.SSE`

**Purpose:** Pure stateless server-sent event parser. Parses raw SSE bytes
into discrete `data:` and `event:` lines.

**Interface:** Single procedure `Feed (Bytes : String; On_Line : access procedure
(Line : String))`. Buffers partial lines across calls using a package-level
internal buffer (one instance per `LLM.HTTP` call context). Calls `On_Line`
for each complete SSE `data:` line, stripping the `data:` prefix.

**No external dependencies.** Pure Ada string processing.

---

### 5.20 `LLM.Settings`

**Purpose:** Loads and exposes user configuration from
`~/.coyote/settings.json` and `~/.coyote/models.json`, and persists changes
made by the GUI Preferences dialog. Plain execution does not persist settings through a frontend command.

**Settings fields:**
- `Default_Provider`, `Default_Model` — model defaults from
  `defaultProvider` and `defaultModel`.
- `Default_Thinking` — the configured thinking level from
  `defaultThinkingLevel`.
- `Default_Sandbox` — optional sandbox profile from
  `defaultSandboxProfile`; empty means no default sandbox.
- `Append_System_Prompt` — additional system-prompt text from
  `appendSystemPrompt`.
- `Prompt_Filter` — interactive prompt filter command from `promptFilter`.
- `Completion_Notifications` — boolean `completionNotifications`; absent or
  malformed values default to True.
- `Price_Display` — `priceDisplay`, either `"si"` or `"db"`; absent, malformed,
  or other values default to SI-prefixed prices.
- `Max_Recursion_Depth` — nonnegative `maxRecursionDepth`; absent, negative,
  non-integer, or out-of-range values default to 1.
- `Shell_Termination_Grace_Seconds` — `shellTerminationGraceSeconds`, an
  integer second count clamped to 0 through 30, default 2.
- `Skill_Paths` — ordered additional absolute skill roots from the optional
  `skillPaths` JSON array; malformed or non-string entries are ignored.
- Raw provider model entries and API-key configuration are read from
  `models.json`.

**`Load_Settings` procedure:** Reads `settings.json`. Missing fields produce
empty/default values. A malformed or absent file does not prevent startup.

**`Save_Preferences` operation:** Updates the model, thinking, sandbox,
optional subagent-model, maximum recursion depth, completion-notification,
`priceDisplay`, and `skillPaths` preference fields while preserving unrelated
JSON fields. The file is written through an atomic same-directory replacement.
`priceDisplay` is `"si"` or `"db"`; missing or invalid values load as SI. In
`"db"` mode, positive stored $/MTok values are converted to $/tok and shown as
`10 × log10 (p / 1,000,000)` dB. Zero is shown as `free`; negative values are
blank. Empty string values clear the corresponding string preference; an empty
skill-path vector removes `skillPaths`. Recursion depth is persisted as a
nonnegative integer, with zero disabling subagent spawning. Write failures are
reported to the caller so the active session can continue.

**Default precedence:** For a newly created session, an explicit model
argument overrides all persistent defaults. For `--subagent`, the configured
subagent model is selected before the ordinary default model; ordinary
sessions ignore the subagent-only preference. An absent or incomplete
subagent preference falls back to the ordinary default-model rules. An
inherited runtime sandbox profile
(`COYOTE_SANDBOX_PROFILE`) overrides `defaultSandboxProfile`. When resuming or
switching sessions, the session header's sandbox profile is authoritative;
an absent profile clears the active value. Persistent preference changes do
not modify the active session. The Sandbox Profiles manager's compatibility
rename creates the new profile, retains the old profile definition for
historical session headers, and updates the persistent
`defaultSandboxProfile` only when it names the old profile; session JSONL
headers are never rewritten.

**`Resolve_Api_Key (Provider : String) → String`:** Checks in order:
(1) literal `apiKey` in models.json entry, (2) `${ENV_VAR}` interpolation,
(3) `Standard_Env_Name` environment variable lookup.

---

### 5.21 `LLM.Auth`

**Purpose:** Loads and caches provider authentication tokens.

**`Auth_Store` record:** Maps provider name to token string. Populated by
`Load` from `~/.coyote/auth.json`.

**`Load` procedure:** Reads `~/.coyote/auth.json`; populates the store.
Missing file is a no-op (not an error; provider may use API-key auth).

**`Save` procedure:** Writes the current store back to `~/.coyote/auth.json`.
Called after token refresh to persist the new token.

---

### 5.22 `LLM.Auth.GitHub_Copilot`

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

### 5.23 `LLM.Model_Registry`

**Purpose:** In-memory catalogue of known models, built at session start.

**`Model_Info` record:** provider, model_id, display_name, context_window,
wire_format (`"openai-completions"` or `"anthropic-messages"`), supports_thinking.

**`Available_Models → Model_Info_Array`:** Returns all registered models from
all providers for which an API key is present.

**`Refresh_GitHub_Copilot`:** Uses the access token already stored in
`~/.coyote/auth.json` when it is present and non-expired (checked via
`LLM.Auth.GitHub_Copilot.Token_Expired`).  No live token refresh is
performed at startup — token refresh is deferred to the provider's `Send`.
The catalogue load (`Load_Catalogue`) is wrapped in an exception handler;
any failure (network error, expired subscription, 401 Unauthorized, JSON
parse error) is silently swallowed, leaving the Copilot portion of the
registry empty.  When the cached token has expired or credentials are
absent, the procedure returns early without touching the registry.

**`Lookup` for `"github-copilot"`:** Returns a `Default_GitHub_Copilot_Model`
with conservative limits and a model-ID-based wire-format heuristic: model
IDs containing `"claude"` → `"anthropic-messages"`, all others →
`"openai-completions"`.  `Not_Found` is no longer raised for unknown
Copilot model IDs, so the agent can start and operate even when the Copilot
catalogue has not been loaded.

---

### 5.24 `LLM.Providers`

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

### 5.25 `LLM.Providers.OpenRouter`

**Purpose:** OpenRouter adapter. Delegates to
`OpenAI_Responses.Provider` (not Completions). OpenRouter's Responses endpoint is a drop-in for
OpenAI Responses and is **stateless**: `store: true` and
`previous_response_id` are rejected with HTTP 400.

**`Create` function:** Sets base URL to `https://openrouter.ai/api/v1`
(overridable via `COYOTE_OPENROUTER_BASE_URL`) and sets the
`HTTP-Referer` and `X-Title` headers required by OpenRouter.

**`Send`:** Resolves the API key (`OPENROUTER_API_KEY` / models.json),
refreshes the catalogue, then forwards to
`OpenAI_Responses.Send_Request`.

**`Customize_Request`:** Delegates first to the Responses provider's
reasoning-effort customization, then adds `session_id` when the provider was
constructed with a non-empty coyote session UUID. The field groups Broadcast
observability traces and does not change the stateless Responses request
semantics. The agent supplies its stable OpenRouter Broadcast identifier to
both normal agent turns and compaction requests. Root and ordinary sessions
default that identifier to their active coyote session UUID; subagents inherit
`COYOTE_OPENROUTER_SESSION_ID` unchanged, recursively. That variable is kept
separate from `COYOTE_SESSION_ID` and `COYOTE_PARENT_SESSION`.

**Catalogue package `OpenRouter.Catalogue`:** Fetches
`https://openrouter.ai/api/v1/models`, caches to
`~/.coyote/openrouter_models_cache.json`. Each entry is parsed into a
`Catalogue_Entry` record (id, display_name, context_length, pricing).
`Catalogue_Entry` record (id, display_name, context_length, pricing).

---

### 5.26 `LLM.Providers.OpenCode_Go`

**Purpose:** Routing provider for OpenCode Go. Selects wire format based on
model ID, in the same pattern as GitHub Copilot.

**`Send` procedure:**
1. Inspect model ID: Claude patterns → `Anthropic_Messages.Provider`; all
   others → `OpenAI_Completions.Provider`.
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
   entry: `context_window` ← `context_length`,
   `max_tokens` ← `top_provider.max_completion_tokens`,
   `Reasoning` ← presence of `"reasoning"` in `supported_parameters`,
   pricing sub-fields from the `pricing` object.
4. When a model is not found on OpenRouter, conservative defaults are used
   (context window 128,000, max tokens 16,384, no reasoning).  The
   `Wire_Format_For` function is still consulted for wire-format routing
   (hardcoded per the Go docs endpoint table).

---
### 5.27 `LLM.Tools`

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

### 5.28 `LLM.Tools.Temp_File`

**Purpose:** Manages tool-result size capping and spill to temporary files.

**`Result_Threshold` constant:** 200 000 bytes. Tool results larger than this
are truncated before being sent to the provider.

**`Truncated (Result : String; Path : out String) → String`:** Writes the
full result to a temp file under `/tmp/coyote_tool_<uuid>`, returns a
truncated string with a notice appended indicating the path where the full
result was written.

**`Cleanup`:** Deletes all temp files created by the current process. Called
at session end.

---

### 5.29 `LLM.System_Prompt`

**Purpose:** Constructs the complete system prompt string from its parts.
Static prose is loaded as one contiguous Markdown resource from
`share/coyote/system-prompt.md`, while capability-dependent sections and
runtime values are rendered by Ada. The resource is found below the
executable-derived `$BASE/share` tree; a nested test executable may use the
parent checkout prefix. Missing or empty resources raise
`LLM.System_Prompt.System_Prompt_Error` rather than silently producing an
incomplete prompt. This covers personality definition, conditional tool-use
instructions, Presentation MathML display-math guidance, memory taxonomy,
coordinator guidance, and subagent delegation (REQ-CORE-170..174,
REQ-CORE-180..183, REQ-CORE-190..192).

**`Build (Cwd, No_Tools, Has_Editing_Tools, Agent, Context_Sections,
Skills_Section, Memory_Block, Executable_Path, Coordinator_Mode) → String`:**
Concatenates:

1. **Static resource** — role description, communication style, math guidance,
   tool guidance, delegation, coordinator, and editing-discipline prose loaded
   from `share/coyote/system-prompt.md`.
2. **Capability rendering** — tool descriptor, tool policy variant, coordinator
   variant, and shell-quoted subagent command are rendered into the resource.
3. **Dynamic session sections** — agent text, settings, memory, project
   context, skills, current date, working directory, and shell are appended by
   Ada in their existing order.
4. **Personality definition** — terse, direct, pragmatic; no cheerleading or
   conversational interjections; guidance on final answers and intermediary
   updates (REQ-CORE-170).
5. **Math-formatting guidance** — for standalone mathematics intended for the
   GUI, require Presentation MathML inside standalone `$$` delimiters, with a
   complete `<math>` document; unsupported expressions remain readable as
   plain text. For inline mathematics, require Unicode math symbols in
   ordinary text rather than LaTeX notation or backslash commands
   (REQ-CORE-173).
4. **Conditional tool-use instructions** — keyed to `Available_Tools`: when
   editing tools exist, prefer them over printing code blocks; when terminal
   tools exist, prefer them over printing commands; when neither exists, print
   code blocks as suggestions (REQ-CORE-171).
5. **Memory taxonomy** — `Memory_Block` from `LLM.Memory`; four-type taxonomy
   with save/retrieval guidance (REQ-CORE-180..183).
6. **Skills_Block** — formatted `<available_skills>` XML from
   `LLM.Skills.Format_Skills_For_Prompt`.
7. **Coordinator guidance** — when `Coordinator_Mode` is true and subagent
   spawning is available: parallel-launch instruction, synthesis-before-
   delegation requirement, structured-result format specification,
   prohibition on fabricating in-flight results (REQ-CORE-190..192).
8. **Subagent command** — the active executable image path is shell-quoted and
   reused in the delegation invocation and example; the path may be injected
   for deterministic testing.
9. **Agent_Text** — content of `--agent` argument.

**`Build_Reminder_Instructions (Available_Tools) → String`:** Returns per-turn
reminder text appended to each user prompt: persist until task is completely
resolved; report progress after 3–5 tool calls with varied one-sentence
updates; avoid repeating verbatim plans; preface each tool batch with a
preamble (REQ-CORE-172).

---

### 5.30 `Coyote_App.History`

**Purpose:** Replays a saved session into the frontend for display.

**`Replay (Store : LLM.Session_Store.Session_File;
            Frontend : Coyote_App.Frontend.Instance'Class)`:**
Reads each record from the JSONL file and calls the appropriate `Frontend`
primitive to render it — text blocks, tool calls, turn footers, model-change
notices — in the order they appear in the file. Skips compaction records
(they have no displayable content).

Used at startup when `--session UUID` is supplied: the user sees the prior
conversation rendered before the first new prompt.

---

### 5.31 `Coyote_App.Utils`

**Purpose:** Formatting helpers and Unicode glyph constants for all frontends.

**`UC_*` constants:** Named constants for multi-byte UTF-8 glyphs used in
the text UI (bullet `•`, gear `⚙`, check `✓`, cross `✗`, hourglass `⏳`,
ellipsis `…`, box-drawing characters, etc.). Defined as `String` values using
`Character'Val` for each byte, because Ada `Character` is Latin-1 and code
points > 255 cannot appear as character literals.

**Formatting helpers:**
- `Format_Cost (Dmil : Natural) → String` — formats deci-millicent cost values
  as `$0.0000` strings.
- `Format_Duration (Seconds : Duration) → String` — humanises durations.
- `Truncate_Middle (S : String; Max_Len : Natural) → String` — truncates long
  strings with a middle ellipsis.
- `Format_Turn_Summary (Input_Tokens, Output_Tokens, Ctx_Window, Model_Text,
  Turn_Cost_Dmil, Session_Cost_Dmil, Stop_Reason_Text) → String` — builds the
  bracketed per-turn summary line (e.g. `[ctx 24k/400k (6%) | ^537 out | stop]`).
  The `Stop_Reason_Text` parameter (added v1.7) displays the provider stop reason
  (`stop`, `length`, `toolUse`, `aborted`, `error`, `unknown`) when non-empty.
- `Format_Turn_Footer_Display (Input_Tokens, Output_Tokens, Ctx_Window,
  Model_Text, Turn_Cost_Dmil, Session_Cost_Dmil, Stop_Reason_Text,
  Is_Step) → String` — builds turn-footer display text: the summary
  line (if any) followed by a separator.  `Is_Step = False` (default)
  uses a double-line separator; `Is_Step = True` uses a single-line
  separator.  Fork tokens are no longer embedded; each frontend
  receives structured fork data via `Append_Fork_Action` instead.
- `Model_Row_Matches (Provider, Name, Spec, Query) → Boolean` — case-insensitive
  substring match used by the GTK Change Model filter. An empty or
  whitespace-only query matches every row.
- `Format_Model_Picker_Count (Visible, Filtered) → String` — status text for
  the Change Model filter label (`N models` unfiltered, `N matches` filtered).

---

### 5.32 Retired `Coyote_App.Frontend.Acme_Win` (historical)

**Purpose:** Acme frontend implementation. Renders agent events as structured
Unicode-glyph-prefixed text in the acme window body.

**State:** Holds a `Nine_P.Client.Fs` connection (opened from `Agent_Task`).
Tracks `Current_Tool_Name` for the `End_Tool` label.

**Key rendering choices:**
- `Append_Text` — writes tokens directly to `/winid/data` via 9P append.
  Sets addr to `$` before each write so text lands at the end.
- `Begin_Tool` — writes a tool-header line with the gear glyph, tool name,
  and a plumb token (`coyote-session+UUID/tool/TOKEN`) for button-3 navigation.
- `End_Tool` — appends check (✓) or cross (✗) and elapsed time.
- `Append_Notice` — prefixes line with `[!]` (error), `[~]` (warning), or `[i]` (info).
- `Append_Fork_Action` — formats and writes the `coyote-fork+PID/UUID/N[/S]`
  plumb token as plain text in the window body.  A button-3 click on the
  token triggers a fork via the plumber.
- `Read_Prompt` — blocks on `App_State.Wait_Prompt` (entry called by
  `Acme_Event_Task` when the user sends a "Send" event).
- `Shutdown` — writes a footer line; calls `App_State.Signal_Shutdown`.

---

### 5.33 `Coyote_App.Frontend.GUI`

**Purpose:** GTK3 frontend implementation. Drives the conversation view via
the `Coyote_GUI.Updates` queue.

**State:** Holds an access to the `GtkApplicationWindow`, the native
`Coyote_GUI.Conversation_Stack`, and a reference to the `Prompt_Queue`. A
menu-bar action map provides Compact, Pause, Resume, New Session, and model
selection commands. The native vertical `Gtk.Box` stack is constructed at
startup and is the sole GTK conversation presentation (see §5.15).

**Key rendering choices:**
- The main window uses one vertical `Gtk.Box` with the expanding conversation
  scroller first, followed by a horizontal `Gtk.Separator`, a padded prompt
  control area, a second horizontal `Gtk.Separator`, and a padded status area.
  This makes the work area, control area, and status area explicit without
  adding nested scrolling regions or changing the conversation's expansion
  policy. The arrangement follows the IRIX guidance for a work area above a
  control area and a status area along the bottom.
- The agents panel is a narrow, resizable left-side tree view within the main
  window. Its root row is the main agent; recursively launched
  subagents appear beneath the agent that launched them. Each row identifies
  the agent label and lifecycle state. Selecting a row switches the shared
  conversation view to that agent's retained conversation state and makes the
  selected live agent the target of typed prompts and applicable agent
  controls. Completed, aborted, failed, and disconnected rows remain
  selectable for review, but cannot receive new prompts after their process
  has ended.
- The agents panel is a virtual window manager for organization only. It does
  not merge agent conversations, make subagents persistent, or map a separate
  desktop window for each coordinator-launched subagent. The child process
  retains the existing initial-prompt, steering-while-active, final-response,
  and exit lifecycle. When a subagent row is inserted, the GTK frontend expands
  that row's ancestor chain so the newly added virtual window is immediately
  visible without expanding unrelated branches.
- All `Append_Text`, `Begin_Tool`, `End_Tool`, etc. calls enqueue a
  `Coyote_GUI.Update` record onto `Coyote_GUI.Updates`. A GLib idle handler
  drains the queue on the GTK main-loop thread and dispatches it to
  `Coyote_GUI.Conversation_Stack`. Markdown parsing and widget mutation occur
  on the GTK main task.
- `Read_Prompt` — blocks on `Coyote_GUI.Prompt_Queue.Dequeue`.
- **Preferences dialog:** `Options → Preferences...` is constructed and operated
  on the GTK main task. It edits persistent defaults for model, thinking level,
  sandbox profile, subagent model, maximum subagent recursion depth,
  completion notifications, price-display mode, and the ordered additional
  skill-directory list without mutating the active `LLM.Agent.Session`. The
  price-display combo offers SI prefixes ($/tok) and dB ($/tok), and the
  selected mode applies when the Change Model dialog is next opened. The
  directory list uses a
  single-selection list, a folder chooser for `Add Directory...`, and explicit
  `Remove Selected`, `Move Up`, and `Move Down` actions. The callback enqueues
  a typed `Set_Preferences` item; the agent task performs
  the atomic settings-file update and sends a success or failure notice back
  through the frontend. On
  successful persistence, the notification setting is applied to the current
  GUI through `Coyote_GUI.Updates`.
- **Menu and window conventions:** The main menu is ordered `File`, `Edit`,
  `View`, `Agent`, `Options`, `Help`, with Help rightmost. The Edit menu
  provides Cut, Copy, Paste, Select All, and Deselect All. Agent Stop, Pause,
  and Resume are disabled when they cannot apply. Support windows close on
  Ctrl+W. The main title identifies
  coyote and an optional instance label without lifecycle status. Dialogs and
  support windows use application-prefixed titles and are transient for the
  main window; the status area carries lifecycle state.
- **Help menu:** Click for Help, Overview, task topics, Index, and Keys &
  Shortcuts launch the corresponding Mallard topic in Yelp. Product
  Information is an in-process dialog built from
  `Coyote_Help.Product_Information_Text` so name, version, and license remain
  available when Yelp is missing. It presents the themed `coyote` application
  icon at a prominent 96-pixel size above that text. The root URI is
  help:coyote; topic URIs use `help:coyote/<topic>`. F1 opens Overview.
  Shift+F1 and Help → Click for Help arm a question-mark cursor on the whole
  main window; a generic GTK event handler consumes the next left click before
  widget activation and opens the mapped contextual topic. If Yelp is
  unavailable, the frontend emits an error notice. Conversation tool/action
  handling remains a separate canvas callback.
- **Sandbox Profiles manager:** `Options → Sandbox Profiles...` opens one
  reusable, modeless co-primary titled `coyote : Sandbox Profiles`. It is
  constructed on the GTK main task, remains transient for the main window, and
  owns no agent task. A left single-selection profile list is paired with a
  right read-only details view. Explicit edit mode exposes New, Edit,
  Duplicate Profile, Rename Profile, Save, Cancel, Refresh, and Use Profile;
  Delete is intentionally absent. The four editable rule lists preserve path
  spelling (`~`, `.`, `./`, absolute, and missing paths). CRUD is synchronous
  local backend access; Use Profile instead enqueues typed `Set_Sandbox` for
  the selected agent. The existing Agent → Sandbox Profile... and
  Ctrl+Shift+S quick chooser remains distinct.
- **Desktop identity and session roles:** The GUI sets the themed `coyote`
  icon name and a stable main-window role. After session creation, resume, or
  switch, the agent queues the session identifier through `Coyote_GUI.Updates`;
  the GTK idle drain sets role `coyote-session-<UUID>`. This uses GTK/GDK
  window-manager identity without sharing GTK widgets across tasks. Native
  session-manager command serialization is not available through the GTK3
  API used by this build and remains a documented qualification limitation.
- **Selection transfer:** The conversation renderer derives one plain-text
  selection value for both Ctrl+C and the desktop PRIMARY selection. Mouse
  selection and Ctrl+A publish PRIMARY without changing CLIPBOARD. A middle
  click in the prompt converts the pointer to a buffer iterator and pastes
  PRIMARY asynchronously at that position without selecting the inserted text.
- **Change Model dialog:** `Agent → Change Model…` (`Ctrl+M`) lists the live
  registry in a sortable `GtkTreeView`. A `GtkSearchEntry` filters rows through
  `GtkTreeModelFilter` + `GtkTreeModelSort` using `Model_Row_Matches` on
  provider, display name, and hidden `provider/id`. Typeahead is disabled.
  A count label shows `N models` or `N matches`. Escape clears a non-empty
  query, then cancels the dialog. Library-level callbacks plus package-level
  picker state avoid `Unrestricted_Access`.
- **Completion notifications:** `Run_GUI` disables the feature for subagents and
  one-shot executions. For eligible runs, the agent task queues a completion
  update after `Session_Stats_Event`; the GTK idle callback checks
  `Gtk.Window.Is_Active` and calls `Coyote_Notify` only for an inactive window.
  Missing notification daemons and delivery failures are non-fatal.
- `Clear_Conversation` — queues a `Clear_Conversation` update; the GTK idle
  callback clears the active conversation renderer. The agent task uses this
  when handling the `New_Session` or `Clear` command.
- `Set_Stats_Summary` — not part of the abstract interface; queues a typed
  `Set_Stats` snapshot so `Coyote_GUI.Session_Stats_Window` refreshes its
  reusable modeless support window on the GTK main-loop thread.  The window
  is transient for the main window, grouped into selectable read-only Session,
  Last Turn, and Session Totals values, uses desktop font settings, keeps the
  report area scrollable, and provides Close and Ctrl+W.  `Clear_Stats` resets
  the report after a new session or session switch; ordinary conversation
  clearing does not alter session totals.
- **Keyboard navigation:** When a conversation text view has focus, the outer
  conversation viewport handles vi-style `j`/`k` line movement, `g` to the
  top, `G`/Shift+`g` to the bottom, Ctrl+D/Ctrl+U page movement, and native
  wheel scrolling. Prompt editing, agent-tree navigation, list navigation, and
  other controls retain their native key behavior. Focusable tool and fork
  controls remain reachable through GTK traversal and activate with Enter,
  keypad Enter, or Space. Escape cancels armed contextual Help; otherwise the
  main-window Escape accelerator performs Stop. Support windows close or hide
  on Escape, and Deselect All is available from Edit and Ctrl+Shift+D.
- **Accessibility:** Send and Stop use text labels as well as icons. Native
  GTK conversation components expose their labels, selectable text, and
  focusable actions through GTK accessibility. Native text components provide
  local selection and the GTK theme supplies the active presentation colors.

- `Shutdown` — calls `Gtk.Main.Quit` from within the idle callback.
- **System font integration** (2026-07-30): On startup the frontend reads the
  system default proportional font family and point size from
  `Gtk.Settings.Get_Default` (`gtk-font-name` property) and uses these
  values as the baseline for the conversation view, prompt area, and status
  bar (all use the same family and size at zoom level 0).  Zoom (+/-)
  adjusts ±1 pt from the system baseline.  The previous hardcoded
  `"sans 11"` baseline is kept as a fallback if the system-font read fails.
- **Auto-scroll toggle** (2026-07-30): The conversation view auto-scrolls to
  the bottom during streaming via an `Auto_Scroll` flag (initially `True`).
  A `View → Auto-scroll` check menu item lets the user toggle this behaviour
  on or off.  When enabled, the `GtkAdjustment::changed` handler snaps the
  viewport to the bottom on every adjustment change (triggered by new content
  arrival).  When disabled, the viewport stays wherever the user has scrolled
  — there is no automatic detection or override of user-initiated scrolling.
- **Menu keyboard accelerators** (2026-09-05): The main GTK window attaches
  visible accelerators through one `Gtk_Accel_Group`. The primary set is
  Ctrl+N (New Window), Ctrl+Shift+N (New Session), Ctrl+O (Open Session),
  Ctrl+Q (Exit), Ctrl+X/C/V/A (Cut, Copy, Paste, Select All),
  Ctrl+Shift+D (Deselect All), Ctrl+, (Preferences), Ctrl+Return (Send),
  Ctrl+L (Clear Conversation), Escape (Stop), Ctrl+Shift+P (Pause), Ctrl+R
  (Resume), Ctrl+M (Models), Ctrl+1 through Ctrl+6 (Thinking Level: Off
  through X-High), Ctrl+Shift+S (Sandbox Profile), Ctrl+Shift+C (Compact
  Context), Ctrl+Shift+I (Session Stats), Ctrl+Shift+M (Render Markdown),
  Ctrl+Shift+A (Auto-scroll), and Ctrl++/Ctrl+-/Ctrl+0 (Zoom In/Out/Reset).
  These primary accelerators use `Accel_Visible`; every menu and menu entry
  also has a mnemonic where GTK supports one. Help task entries and other
  informational Help items have mnemonics but no independent accelerators.
- **Ctrl+mouse-wheel zoom** (2026-08-15): The conversation `GtkLayout`
  enables `Scroll_Mask` in its event mask, and the frontend connects an
  `On_Conv_Scroll` handler to the layout's `scroll-event` signal.  When
  Ctrl is held, wheel up/down steps the zoom level via `Coyote_GUI.Zoom.
  Step_Zoom` and calls `Apply_Zoom`; smooth-scroll (touchpad) deltas are
  accumulated until they reach one wheel notch.  Ctrl+wheel events are
  always consumed (return `True`) so the viewport never scrolls while
  zooming; plain wheel events return `False` and propagate to the
  scrolled window for normal scrolling.  All zoom entry points (menu
  accelerators and wheel) share the `Coyote_GUI.Zoom` arithmetic,
  including the clamp bounds and the no-change short-circuit.

  This replaces the earlier follow-mode implementation that used
  `Programmatic_Scroll_Count` counter guards and `::value-changed` auto-detection
  to distinguish user from programmatic scrolls, along with a "↓ New output"
  scroll-to-bottom button.
---

### 5.34 `Coyote_GUI.Session_Stats_Window`

**Purpose:** Reusable live GTK support window for cumulative and last-turn
session statistics.

**Window model:** The package creates one modeless `GtkWindow`, transient for
`Coyote_App.Frontend.GUI`'s main window, titled `coyote : Session Stats`. It
has a 420×360 minimum and 560×430 default size, keeps the report area in a
vertical `Gtk.Scrolled_Window`, and places a visible Close button below the
scroll strip. Window-manager delete, Close, and Ctrl+W hide the window rather
than destroying it; later Session Stats commands present and reuse it.

**Presentation:** Session, Last Turn, and Session Totals are grouped in
frames. Each value is a selectable, read-only GTK label so users can copy
identifiers and measurements without entering an edit mode. Labels use the
GTK desktop font family and point size. `Update` changes all values in place;
`Clear` resets the retained snapshot and visible values.

**Currency:** `Coyote_GUI.Session_Stats_Record` is carried by `Set_Stats` in
the agent-to-GTK update queue. The record is retained even if the support
window has not yet been shown. `Clear_Stats` is queued after New Session and
Switch Session; ordinary Clear Conversation does not change statistics.

### 5.35 `Coyote_Help`

**Purpose:** Opens the installed Mallard application documentation in Yelp.

**`Help_URI (Topic)`:** Returns `help:coyote` for an empty topic and
`help:coyote/<topic>` otherwise.

**`Topic_For_Area (Area)`:** Maps each main-window contextual-help area to a
stable Mallard topic ID: `menu` to `ui-menu`, `prompt` to `ui-prompt`,
`controls` to `ui-controls`, `status` to `ui-status`, and all other areas to
`ui-conversation`.

**`Yelp_Available`:** Locates the `yelp` executable on `PATH`.

**`Open (Topic)`:** Locates Yelp, prepends the executable-relative
`$BASE/share` directory to `XDG_DATA_DIRS` when the installed Mallard tree is
present, launches Yelp detached with the Help URI, and restores the parent
process environment. It returns False when Yelp cannot be located or the
launch cannot be started. The GUI converts that result into a visible error
notice.

**`Help_Data_Directory (Executable)`:** Returns `$BASE/share`, using the same
`$BASE` derivation as `LLM.Skills.Install_Base`; it returns an empty string for
an executable outside a `bin/` layout.

**`Product_Information_Text`:** Returns the in-process Product Information
body (application name, crate version, and license) so the Help menu entry
works when Yelp is unavailable.

Mallard source files are installed below `share/help/C/coyote/` by the existing
GPR `Install` artifact declaration. Use `alr install` to install the project
under Alire's default prefix. Yelp owns the Help window, so it is not a GTK
transient child of the coyote main window.

---

### 5.35 `Coyote_App.Frontend.Plain`

**Purpose:** Plain-text frontend for `--one-shot` mode and non-TTY output.

**Rendering:** All output goes to `Ada.Text_IO.Standard_Output`. No ANSI
escape codes. Thinking blocks are suppressed (not printed). Tool calls are
rendered as `[tool: <name>]` … `[/tool]` text markers. Notices are prefixed
with `[ERROR]`, `[WARN]`, or `[INFO]`.

**`Read_Prompt`:** In `--one-shot` mode, the prompt is pre-loaded from the
`--prompt` argument or from stdin; `Read_Prompt` returns it on the first call
and returns `""` (signalling shutdown) on all subsequent calls.

---

### 5.35 `Coyote_GUI`

**Purpose:** Root package for the GUI subsystem. Defines the `Update_Kind`
enumeration and the `Update` discriminated record.

**`Update_Kind` values:** `Append_Text`, `End_Text_Block`, `Append_Thinking`,
`Begin_Thinking`, `End_Thinking`, `Begin_Tool`, `End_Tool`, `Append_Notice`,
`Append_Turn_Footer`, `Set_Mode`, `Set_Stats`, `Clear_Stats`,
`Clear_Conversation`, `Set_Completion_Notifications`,
`Completion_Notification`, `Show_Detail`, and `Shutdown`.

**`Update` record:** Discriminant is `Update_Kind`. Each variant carries the
payload fields appropriate to that kind. `Set_Stats` carries a typed
`Session_Stats_Record` containing session/model identity, last-turn values,
and cumulative token/cost totals; `Clear_Stats` carries no payload.

---

### 5.36 `Coyote_GUI.Updates`

**Purpose:** Thread-safe bounded queue from `Agent_Task` to the GTK main loop.

**Protected type `Queue`:** Bounded buffer of `Coyote_GUI.Update` records,
capacity 8 192. Operations: `Enqueue (U : Update; Wake_Needed : out Boolean)`
(blocks when full and atomically reserves the idle source when needed),
`Idle_Done (Keep_Active : out Boolean)` (completes one idle callback and
atomically releases the source when no work remains), `Stop` (closes the queue
and releases blocked producers), `Dequeue (U : out Update; Got : out Boolean)`
(non-blocking; sets `Got := False` if empty), and `Has_Pending`. Updates are
never silently dropped while the queue is open.

**GLib idle handler:** Registered on demand by `Enqueue_Update` when the
queue transitions from empty to non-empty.  On each idle callback, it
drains exactly one item from the queue and dispatches it to the selected
conversation renderer. The callback returns `False` when the
queue is empty, removing the source and allowing the GTK main loop to block
when there is no work.  Processing one item per invocation yields control to
the GLib main loop between updates, allowing pending redraws (priority 120)
to interleave with the drain (priority 200).  The queue-owned source state
prevents duplicate source registration while multiple updates are pending or
a callback is completing.

---

### 5.37 `Coyote_GUI.Prompt_Queue`

**Purpose:** Thread-safe bounded queue from the GTK main loop to `Agent_Task`,
carrying typed command payloads via a discriminated `Item` type.

**Protected type `Queue`:** Bounded buffer of `Item` values, capacity 64.
Operations: `Enqueue (I : Item; Accepted : out Boolean)` (non-blocking;
reports rejection when full), `Enqueue (I : Item)` (compatibility wrapper),
`Dequeue (I : out Item)` (blocking entry; `Agent_Task` waits here between
turns), and `Shutdown` (unblocks any waiting `Dequeue`).

**`Item_Kind` discriminant values:**

| Kind | Payload | Purpose |
|---|---|---|
| `User_Prompt` | `Text` | Forward text to the LLM |
| `Stop` | — | Abort the current response |
| `Pause` | — | Pause after the current tool call |
| `Resume` | — | Resume from pause |
| `Compact` | — | Trigger manual context compaction |
| `New_Window` | — | Spawn a fresh coyote GUI window |
| `New_Session` | — | Replace the in-window session with a fresh one |
| `Set_Model` | `Model_Spec` | Change the active model |
| `Set_Thinking` | `Level` | Change the reasoning level |
| `Set_Sandbox` | `Profile_Name` | Change the sandbox profile |
| `Switch_Session` | `Session_UUID` | Load a different session by UUID |
| `Set_Preferences` | Preferences record | Persist model, thinking, sandbox, recursion-depth, notification, and skill-path defaults without changing the active session |
| `Shutdown_Item` | — | Queue is closing; `Agent_Task` should exit |

The `Preferences record` contains the selected provider/model, thinking level,
sandbox profile, maximum subagent recursion depth, completion-notification,
price-display mode, and the ordered Skill_Paths vector. Empty strings represent
explicit clearing
of string defaults; zero recursion depth disables subagent spawning. An empty
Skill_Paths vector clears `skillPaths`. The GTK task never writes settings
directly; persistence remains owned by the agent task.

---

### 5.37a `Coyote_GUI.Zoom`

**Purpose:** Pure-logic zoom arithmetic shared by the GUI frontend's zoom
entry points (View-menu accelerators and Ctrl+mouse-wheel).  Factored into
a display-independent package so the policy is unit-testable without GTK.

**Public operations:**

- `Zoom_Step_Pt`, `Min_Size_Pt`, `Max_Size_Pt` — step size and hard bounds
  for the effective font point size.
- `Effective_Size_Pt (Level, Base_Pt)` — effective point size for a zoom
  level, clamped to `[Min_Size_Pt, Max_Size_Pt]`.
- `Clamped_Base_Pt (Base_Pt)` — baseline clamped to the same range; used
  as the reference for the display-math scale factor.
- `Step_Zoom (Level, Steps, Base_Pt, Changed)` — advances `Level` by
  `Steps` (positive = zoom in), then walks back out of the clamp plateau
  so a large step request leaves the level at the first level that
  actually maps to the clamped size.  `Changed` reports whether the
  effective point size changed, so callers can skip the (expensive)
  font re-application and redraw when the size is pinned at a bound.

**Design notes:** the plateau walk-back keeps `Zoom_Level` finite even
when a touchpad emits a large accumulated smooth-scroll delta, and lets
zoom-out be immediately responsive after zooming into the clamp.

### 5.38 `Coyote_Utils`

**Purpose:** CLI argument resolution, session prefix stripping, active
executable resolution, and POSIX shell quoting utilities shared by the
entry-point and prompt packages.

**`Active_Executable_Path → String`:** Resolves `/proc/self/exe` with
link resolution on Linux so the running binary path is independent of
`argv[0]`; falls back to the command name when procfs is unavailable.

**`Shell_Quote (Value : String) → String`:** Returns `Value` as one
single-quoted POSIX shell word, escaping embedded apostrophes.

**`Read_Whole_File (Path : String) → String`:** Reads the entire contents
of `Path` as a `String` using `Stream_IO` chunk-based reading (8 KB buffer).
Unlike `Ada.Text_IO.Get_Line` which recurses linearly with line length, this
function handles arbitrarily long lines (including single-line JSON files)
without stack overflow.  Returns `""` when `Path` is empty or does not exist.

**`Read_File_If_Exists (Path : String) → String`:** Thin wrapper that
delegates to `Read_Whole_File`.  Preserved for backward compatibility.

**`Resolve_Prompt_Arg (Arg : String) → String`:** If `Arg` starts with `@`,
reads and returns the content of the named file; otherwise returns `Arg`
as-is.
**`Resolve_Prompt_Arg (Arg : String) → String`:** If `Arg` starts with `@`,
reads and returns the content of the named file; otherwise returns `Arg`
as-is.

**`Strip_Session_Prefix (S : String) → String`:** Removes a
`coyote-session+` prefix and any trailing path components from a plumb token,
returning just the UUID.

**`Bad_Arg_Error` exception:** Raised when a CLI argument is unrecognised or
malformed; caught in `coyote.adb` and printed to stderr.

---

### 5.39 Retired `Acme` subsystem (historical)

**Purpose:** Root package for the acme subsystem. Defines the
`Win_File_Path` helper.

**`Win_File_Path (Win_Id : Natural; File : String) → String`:** Returns the
9P path `"/<Win_Id>/<File>"` (e.g. `"/42/ctl"`, `"/42/data"`). Used by
`Acme.Window` and `Acme.Event_Parser` to construct VFS paths.

---

### 5.40 Retired `Acme.Window` (historical)

**Purpose:** High-level acme window operations over 9P.

**Key subprograms:**
- `Write_Body (Fs; Win_Id; Text)` — sets addr to `$`, writes `Text` to
  `/Win_Id/data`.
- `Write_Ctl (Fs; Win_Id; Cmd)` — writes a control command string to
  `/Win_Id/ctl`.
- `Write_Tag (Fs; Win_Id; Text)` — appends `Text` to the window tag.
- `Clear_Body (Fs; Win_Id)` — sets addr to `,`, writes empty string to data
  (erases the entire body).
- `Set_Name (Fs; Win_Id; Name)` — writes `"name <Name>"` to ctl.

All subprograms take an explicit `Fs : not null access Nine_P.Client.Fs` so
the caller's task-local connection is used; never shares an `Fs` across tasks.

---

### 5.41 Retired `Acme.Event_Parser` (historical)

**Purpose:** Parses acme event-file records into structured `Event` values.

**`Event` record fields:** `C1`, `C2` (origin and type characters), `Q0`,
`Q1` (character range), `Flag`, `Nr`, `Text` (event text).

**`Parse_Event (Raw : String) → Event`:** Parses one line from the acme event
file. Returns a zero-valued `Event` if the line is malformed.

**`Is_Button2_Exec (E : Event) → Boolean`:** Returns `True` when `C1 = 'E'`
and `C2 = 'x'` (button-2 execute in body).

---

### 5.42 Retired `Acme.Raw_Events` (historical)

**Purpose:** Low-level byte accumulator for the acme event file.

**`Feed (Bytes : String; On_Record : access procedure (R : String))`:**
Buffers bytes and calls `On_Record` for each complete newline-terminated
event record. Handles partial reads that split a record across two `Feed`
calls.

---

### 5.43 Retired `Nine_P` subsystem (historical)

**Purpose:** Root package for the 9P2000 protocol implementation. Defines
`Qid`, `Byte_Array`, and protocol constants (`NOTAG`, `NOFID`, version
string `"9P2000"`).

**No subprograms:** All logic lives in child packages.

---

### 5.44 Retired `Nine_P.Proto` (historical)

**Purpose:** Encodes and decodes 9P2000 T-messages and R-messages.

**Key subprograms:**
- `Encode_Tversion`, `Encode_Tattach`, `Encode_Twalk`, `Encode_Topen`,
  `Encode_Tread`, `Encode_Twrite`, `Encode_Tclunk` — build byte arrays for
  each T-message type.
- `Decode_Rversion`, `Decode_Rattach`, `Decode_Rwalk`, `Decode_Ropen`,
  `Decode_Rread`, `Decode_Rwrite` — parse R-message byte arrays into record
  fields.
- `Encode_String (S : String) → Byte_Array` — length-prefixed UTF-8 string
  per 9P2000 wire format.

**Error handling:** `Proto_Error` exception raised on truncated or malformed
R-message bytes.

---

### 5.45 Retired `Nine_P.Client` (historical)

**Purpose:** 9P2000 client; provides mount, open, read, write, and clunk
over a UNIX socket.

**`Fs` type:** Protected object wrapping a socket file descriptor and a fid
allocator. Each public operation acquires the lock, performs the T/R exchange,
and releases the lock.

**Key operations:**
- `Ns_Mount (Ns_Name : String) → Fs` — connects to the named namespace socket
  (e.g. `"/tmp/ns.user.:0/acme"`), performs `Tversion`/`Rattach` handshake.
- `Open (Fs; Path : String; Mode : Open_Mode) → File` — walks and opens a
  9P file; returns a `File` handle.
- `Read (File; Count : Natural) → String` — sends `Tread`; returns data.
- `Write (File; Data : String)` — sends `Twrite`.
- `Clunk (File)` — sends `Tclunk`; closes the fid.

**Critical constraint:** `Fs` instances must never be shared across Ada tasks.
Each task creates its own `Fs` via `Ns_Mount`.

---

### 5.46 `Session_Lister`

**Purpose:** Enumerates saved sessions for the current directory and formats
them for display.

**`List_Sessions (CWD : String) → Session_Info_Array`:** Scans
`~/.coyote/sessions/<cwd-slug>/` for `*.jsonl` files, reads the first record
of each to extract the session header (timestamp, model, first user message
preview), and returns the array sorted by creation time (newest first).

**`Format_For_Display (Info : Session_Info) → String`:** Formats one entry
as a human-readable line: `UUID  YYYY-MM-DD HH:MM  model  preview`.

**`Fork_Session (Source_UUID : String; After_Turn : Positive; After_Step : Natural := 0; Target_Cwd : String) → String`:**
Creates a new session by copying the source JSONL file up to a cut point.
When `After_Step = 0`, the cut point is after `After_Turn` complete turns
(user → assistant-with-text-content pairs). When `After_Step > 0`, the cut
point is after the `After_Step`-th assistant message within turn
`After_Turn`, including all tool results from that message's batch. Returns
the new session UUID, or "" on failure.

Used by `coyote_list_sessions` and by the GUI frontend's session-picker
menu.

---

### 5.47 `LLM.Agent` — `Request_Abort`, `Request_Pause`, and `Resume`

*(Supplement to §5.5, which covers `Create` and `Run_Prompt`.)*

**`Request_Abort (S : in out Session)`:** Sets `S.Abort_Flg`. The libcurl
transfer-info callback and the tool executor both poll this flag; a blocked
provider request is interrupted by libcurl and a running tool is terminated
by its process-group watcher. `Run_Prompt` detects the flag at the top of its
outer loop and exits cleanly. The GUI Stop callback requests the abort directly
through its protected session reference rather than queueing a stale Stop item.
`Dispatch_Event` treats `Agent_End_Event.Was_Aborted` as authoritative when
classifying completion.

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
| REQ-CORE-001–005 | `Coyote` (entry point) |
| REQ-CORE-010–023 | `Coyote` (entry point), `Coyote_Utils` |
| REQ-CORE-020a–020c, 115, 115a | Planned `Coyote_App.Frontend.RPC`, `Coyote_App.Agent_Registry`, `Coyote_App.Agent_RPC`, and `Coyote_App.Frontend.GUI` agents-panel presentation |
| REQ-CORE-030–032 | `Coyote` (entry point), `LLM.Session_Store` |
| REQ-CORE-219 | `Coyote_App`, `LLM.Agent`, OpenRouter provider |
| REQ-CORE-040–046 | `LLM.Agent`, `Coyote_App.Dispatch`, all frontends |
| REQ-CORE-050–055 | `LLM.Tools.Shell`, `LLM.Tools.Temp_File`, `LLM.Agent` |
| REQ-CORE-060–064 | `LLM.Agent`, `LLM.Compaction`, `LLM.Session_Store` |
| REQ-CORE-065–068 | `LLM.Agent`, `LLM.Compaction` |
| REQ-CORE-070–076 | `LLM.Agent`, `LLM.Settings`, `LLM.Model_Registry`, all providers |
| REQ-CORE-080–089 | `LLM.Session_Store`, `LLM.Agent`, `Coyote_App`, `Session_Lister` |
| REQ-CORE-113f–113i | `Coyote_App.Frontend.GUI`, `Coyote_GUI.Sandbox_Profile_Window`, `Coyote_GUI.Prompt_Queue`, `LLM.Tools.Sandbox` |
| REQ-CORE-235 | `LLM.Tools.Sandbox`, `LLM.Settings`, `LLM.Tools.Shell` |

**PCR-044 synchronization design:** `Coyote_App` calls its local
`Synchronize_Sandbox` operation after agent creation and after every session
switch. The operation copies `LLM.Agent.Current_Sandbox` into the frontend
local state and `App_State`, and republishes the same value as
`COYOTE_SANDBOX_PROFILE` before bootstrap or the next tool call. Session-info
emission queries the agent directly rather than trusting stale frontend-local
state. The GUI agent task performs this synchronization before bootstrap and
before the next tool call; the Plain runner applies the same environment and
session-header rules synchronously.

| REQ-CORE-090, 090a–094 | `LLM.Skills`, `LLM.Settings`, `LLM.System_Prompt` |
| REQ-CORE-100–107 | Historical retired Acme frontend requirements; see PCR-090 |
| REQ-CORE-108–108b | `Coyote_App`, `Coyote_App.Dispatch`, `Coyote_App.Utils`, `Session_Lister` |
| REQ-CORE-109 | Historical retired Acme frontend requirement; see PCR-090 |
| REQ-CORE-110–119, 125, 129, 132, 230 | `Coyote_App.Frontend.GUI`, `Coyote_GUI.Conversation_Stack`, `Coyote_GUI.Prompt_Queue`, `Coyote_GUI.Zoom`, `Coyote_Cmark`, `Coyote_Renderer.Markup`, `Coyote_App.Utils`, `LLM.Settings` |
| REQ-CORE-124 | `Coyote_GUI.Conversation_Stack`, `Coyote_Lasem` |
| REQ-CORE-120–121 | `Coyote_App.Frontend.Plain` |
| REQ-CORE-130–131, 137 | `Coyote_App.History`, `Coyote_GUI.Conversation_Stack`, `Coyote_Renderer.Markup`, `Coyote_Renderer.Session_View` |
| REQ-CORE-140–142 | `LLM.Agent`, `Coyote_App.Dispatch`, all frontends |
| REQ-CORE-170–174 | `LLM.System_Prompt`, `LLM.Agent`, `share/coyote/system-prompt.md` |
| REQ-CORE-180–183 | `LLM.Memory`, `LLM.System_Prompt` |
| REQ-CORE-190–192 | `LLM.System_Prompt`, `LLM.Agent`, `LLM.Tools.Shell` |
| REQ-CORE-200–208, REQ-CORE-215–219 | `LLM.Providers.*`, `LLM.HTTP`, `LLM.SSE`, `LLM.Agent` |
| REQ-CORE-210–212 | Historical retired Acme 9P VFS requirements; see PCR-090 |
| REQ-CORE-220–221, 133–139 | `Coyote_App.Frontend.GUI`, `Coyote_GUI.Conversation_Stack`, `Coyote_GUI.Exchange_View`, `Coyote_GUI.*` |
| REQ-CORE-504a | `Coyote_Help`, `share/help/C/coyote/` Mallard documentation |
| REQ-CORE-025, 230–234 | `Coyote`, `LLM.Settings`, `LLM.Auth`, `LLM.Auth.GitHub_Copilot` |
| REQ-CORE-240–241 | `LLM.Session_Store` |
| REQ-CORE-300–302 | `Coyote_App.Frontend`, `LLM.Events`, `LLM.Tools.Temp_File` |
| REQ-CORE-400–402 | `LLM.Types`, `LLM.Compaction`, `LLM.Agent` |
| REQ-CORE-500–505 | Build system (Alire/GPRbuild); runtime dependencies |
| REQ-CORE-600–601, 135, 138 | `LLM.Compaction` (unbounded growth prevention); `Coyote_App` (GTK threading); `Coyote_GUI.Conversation_Stack` |
| REQ-CORE-700–704, 138 | `LLM.HTTP` (streaming latency); `LLM.Session_Store` (persistence); `Coyote_GUI.Conversation_Stack`, `Coyote_GUI.Exchange_View` |
| REQ-CORE-800–805 | Build system; `Coyote_App.Utils` (UC_* constants); all packages (.ads/.adb split) |
| REQ-CORE-160 | `share/man/man1/coyote.1` (static man page) |

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
- `coyote_sqc` design: see `design/coyote-sqc-design.md`.
- Detailed design for catalogue packages (`OpenRouter.Catalogue`, etc.):
  deferred; covered adequately by AGENTS.md §Adding a New LLM Provider.


### 5.10b `Coyote_Process_Control` — SIGTERM shutdown

`Coyote_Process_Control` owns a protected registry of shell-tool process-group
leaders and launch reservations. `Begin_Launch` closes the Start/register race;
`Complete_Launch` registers the `setsid` group and signals it immediately if
shutdown began during spawning. A native self-pipe receives SIGTERM using an
async-signal-safe handler; deferred Ada monitor tasks perform all protected
operations, process-tree signalling, persistence freezing, and frontend wakeup.

The first SIGTERM freezes new JSONL writes, requests agent cancellation, sends
SIGTERM to all registered groups and nested shell-launched coyote groups, waits
0 through 30 configured seconds, then sends SIGKILL and waits for group cleanup.
A second SIGTERM bypasses the grace interval. GUI Stop requests direct agent
cancellation. GUI window-close and File → Exit use the frontend shutdown
operation, which requests direct cancellation, stops the monitor, wakes the
prompt queue, and stops update producers. The callbacks then quit GTK.

The GTK Preferences dialog persists `shellTerminationGraceSeconds` as an
integer number of seconds. The active process applies a saved value immediately;
new coyote children inherit the setting through normal environment/settings
startup. Only session records whose writes completed before the persistence
freeze are retained.
