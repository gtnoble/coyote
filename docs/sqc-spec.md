# coyote_sqc — Design Specification

**Project:** Coyote Session Quality Control  
**Version:** 0.1 (draft)  
**Date:** 2026-05-21  
**Status:** In progress  
**Requirements:** `docs/sqc-requirements.md`

---

## Table of Contents

1. [Overview](#1-overview)
2. [Coyote Prerequisites](#2-coyote-prerequisites)
3. [Build System](#3-build-system)
4. [Package Architecture](#4-package-architecture)
5. [Session JSONL Parser](#5-session-jsonl-parser)
6. [Data Model](#6-data-model)
7. [Statistical Computation](#7-statistical-computation)
8. [Chart Definitions](#8-chart-definitions)
9. [Workspace File Format](#9-workspace-file-format)
10. [Shared Renderer Package](#10-shared-renderer-package)
11. [UI Architecture](#11-ui-architecture)
12. [Chart Canvas Implementation](#12-chart-canvas-implementation)
13. [Configuration Files](#13-configuration-files)
14. [Testing](#14-testing)

---

## 1. Overview

`coyote_sqc` is a standalone GTK3/Ada executable built within the existing `coyote`
Alire crate. It reads Coyote session JSONL files, computes SPC/SQC control chart
statistics, and presents an interactive GUI for process monitoring and annotation.

The application is architecturally decoupled from the Coyote runtime: it never calls
`LLM.Agent`, never connects to an LLM provider, and never writes to session files.
All application state lives in a workspace file (`.sqcw`) separate from session data.

### 1.1 Scope of This Document

This document specifies:
- Prerequisite changes to the `coyote` main application (§2)
- The build system integration (§3)
- Ada package hierarchy and public interfaces (§4)
- Session file parsing and field mapping (§5)
- Internal data model Ada types (§6)
- Statistical formula implementations (§7)
- Chart type enumeration and properties (§8)
- Workspace file JSON schema (§9)
- The shared `Coyote_Renderer` package (§10)
- GTK3 widget hierarchy and UI behaviour (§11)
- Chart canvas rendering and interaction (§12)
- Per-user configuration file format (§13)
- Test plan (§14)

---

## 2. Coyote Prerequisites

The following changes to the main `coyote` application must be completed before
`coyote_sqc` development begins. They are independent of each other and can be
implemented in parallel.

### 2.1 Add Thinking Token Count to `LLM.Types.Usage`

**File:** `src/llm/llm-types.ads`

Add a `Thinking : Natural := 0` field to the `Usage` record:

```ada
type Usage is record
   Input       : Natural := 0;
   Output      : Natural := 0;
   Cache_Read  : Natural := 0;
   Cache_Write : Natural := 0;
   Thinking    : Natural := 0;  -- NEW
end record;
```

Default zero ensures backward compatibility at all existing call sites.

### 2.2 Populate Thinking Tokens — Anthropic Provider

**File:** `src/llm/llm-providers-anthropic_messages.adb`

The Anthropic API does not report thinking tokens as a distinct field in the usage
object; thinking tokens are folded into `output_tokens`. At `content_block_stop` for
a `thinking` block, the accumulated `Thinking_Text` length is available. Apply the
heuristic `Thinking_Tokens ≈ Length(Thinking_Text) / 4` and accumulate into
`State.Tok_Usage.Thinking`. This is an approximation; the field description in the
session JSONL should document it as an estimate for Anthropic sessions.

Concretely, in `Process_Content_Block_Stop` (or wherever a thinking block is
finalised), after appending the block to the content vector:

```ada
State.Tok_Usage.Thinking := State.Tok_Usage.Thinking
  + Natural (Ada.Strings.Unbounded.Length (Block.Thinking_Text)) / 4;
```

### 2.3 Populate Thinking Tokens — OpenAI Provider

**File:** `src/llm/llm-providers-openai_completions.adb`

OpenAI reports reasoning tokens in
`usage.completion_tokens_details.reasoning_tokens` for o1/o3/o4 models. Update
`Parse_Usage` to read this field:

```ada
function Parse_Usage
   (Value : GNATCOLL.JSON.JSON_Value) return LLM.Types.Usage
is
   Details  : constant GNATCOLL.JSON.JSON_Value :=
      Get_Object_Field (Value, "prompt_tokens_details");
   Comp_Det : constant GNATCOLL.JSON.JSON_Value :=
      Get_Object_Field (Value, "completion_tokens_details");
begin
   return
      (Input       => Get_Natural_Field (Value, "prompt_tokens"),
       Output      => Get_Natural_Field (Value, "completion_tokens"),
       Cache_Read  => Get_Natural_Field (Details, "cached_tokens"),
       Cache_Write => 0,
       Thinking    => Get_Natural_Field (Comp_Det, "reasoning_tokens"));
end Parse_Usage;
```

For models that do not return `completion_tokens_details`, `Get_Object_Field`
returns `JSON_Null` and `Get_Natural_Field` returns the default 0.

### 2.4 Persist Thinking Tokens in Session JSONL

**File:** `src/llm/llm-session_store.adb`

In `Message_To_Json`, within the `LLM.Types.Assistant` branch, add `"thinking"` to
the `Usage` object:

```ada
Usage.Set_Field ("thinking", Integer (Msg.Tok_Usage.Thinking));
```

In `Parse_Assistant_Message`, read it back:

```ada
Tok_Usage =>
  (Input       => Get_Natural_Field (Usage, "input"),
   Output      => Get_Natural_Field (Usage, "output"),
   Cache_Read  => Get_Natural_Field (Usage, "cacheRead"),
   Cache_Write => Get_Natural_Field (Usage, "cacheWrite"),
   Thinking    => Get_Natural_Field (Usage, "thinking")),
```

`Get_Natural_Field` returns 0 when the field is absent, so existing session files
without a `"thinking"` key are parsed correctly with a zero thinking token count.

### 2.5 Shared Renderer Extraction

**Files affected:** `src/coyote_gui/coyote_gui-buffer.ads/.adb`,
`src/coyote_app/coyote_app-frontend-gui.adb`, new `src/coyote_renderer/`.

The markdown-to-Pango-markup function `To_Pango_Markup` and its helpers (`Xml_Escape`,
the cmark tree-walk, and table rendering) shall be extracted from `Coyote_GUI.Buffer`
into a new package `Coyote_Renderer.Markup` (see §10). The existing
`Coyote_GUI.Buffer` package is updated to call `Coyote_Renderer.Markup.To_Pango_Markup`
rather than providing its own copy. No change in external behaviour.

### 2.6 Persist Model Information in Session JSONL

**Files affected:** `src/llm/llm-session_store.ads`, `src/llm/llm-session_store.adb`,
`src/llm/llm-agent.adb`.

Currently `coyote` writes `"model": ""` and `"provider": ""` as empty strings in
every assistant message and never writes a `model_change` record to the session JSONL.
As a result `Coyote_SQC.Session_Parser` finds no `model_change` record and leaves
`Session_Record.Model` empty for all sessions created by the current `coyote` build.

**`src/llm/llm-session_store.ads`** — add a new procedure:

```ada
--  Append a model-change record to the session JSONL.
--  Writes: {"type":"model_change","provider":Provider,"modelId":Model_Id}
--  Should be called once per Run_Prompt invocation, before the first
--  assistant message, whenever the active model is known.
procedure Append_Model_Change
  (Session_Id : String;
   Provider   : String;
   Model_Id   : String);
```

**`src/llm/llm-session_store.adb`** — implement `Append_Model_Change`:

```ada
procedure Append_Model_Change
  (Session_Id : String;
   Provider   : String;
   Model_Id   : String)
is
   Obj : GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
begin
   Obj.Set_Field ("type",    "model_change");
   Obj.Set_Field ("provider", Provider);
   Obj.Set_Field ("modelId",  Model_Id);
   Write_Raw_Line
     (Path => Session_File_Path (Session_Id),
      Line => GNATCOLL.JSON.Write (Obj),
      Mode => Ada.Streams.Stream_IO.Append_File);
end Append_Model_Change;
```

**`src/llm/llm-agent.adb`** — in `Run_Prompt`, at the point where
`Model_Select_Event` is emitted (immediately after `Append_Message` for the
prompt message), add:

```ada
LLM.Session_Store.Append_Model_Change
  (Session_Id => To_String (S.Session_UUID),
   Provider   => To_String (S.Model_Info.Provider),
   Model_Id   => To_String (S.Model_Info.Model_Id));
```

This writes the `model_change` record once per prompt, before any assistant
message, matching the format that `Coyote_SQC.Session_Parser` already reads in
both the v1 and v3 code paths.  Sessions recorded before this fix will continue
to show an empty model string in `coyote_sqc`; no migration of existing files
is required.

---

## 3. Build System

### 3.1 Alire Crate

`coyote_sqc` is built as a second executable target within the existing `coyote`
Alire crate. No separate `alire.toml` is created. A single `alr build` from the
project root builds both `bin/coyote` and `bin/coyote_sqc`.

### 3.2 GPRbuild Project File

Add a new executable source to `coyote.gpr`:

```
for Main use ("coyote.adb", "coyote_sqc.adb");
```

All `coyote_sqc` source files live under `src/coyote_sqc/` and
`src/coyote_renderer/`. These directories are added to `for Source_Dirs`. Object
files for `coyote_sqc` share the same `obj/<profile>/` directory.

### 3.3 Executable Name

The entry point is `src/coyote_sqc.adb`. The resulting binary is `bin/coyote_sqc`.

---

## 4. Package Architecture

```
Coyote_SQC                           -- root; application entry point
Coyote_SQC.App                       -- App_State, Run procedure (GTK main loop)
Coyote_SQC.Session_Parser            -- sole package that reads Coyote JSONL files
Coyote_SQC.Data_Model                -- Ada type definitions (Session/Turn/Tool records)
Coyote_SQC.Metrics                   -- computes Session_Metrics_Record from Session_Record
Coyote_SQC.Statistics                -- c4 table; Xbar/s/p limit computation
Coyote_SQC.Statistics.C4             -- c4(n) lookup table and approximation
Coyote_SQC.Statistics.Xbar           -- Xbar chart center line and limit formulas
Coyote_SQC.Statistics.S_Chart        -- s chart center line and limit formulas
Coyote_SQC.Statistics.P_Chart        -- p chart center line and limit formulas
Coyote_SQC.Statistics.I_Chart        -- I chart and MR chart limit formulas
Coyote_SQC.Charts                    -- Chart_Kind enum; Chart_State per chart
Coyote_SQC.Workspace                 -- Workspace_Record; load/save .sqcw files
Coyote_SQC.Workspace.Integrity       -- setup interval integrity checks on filter change
Coyote_SQC.Config                    -- ~/.config/coyote_sqc/ reader/writer
Coyote_SQC.UI                        -- top-level window builder; ties all widgets together
Coyote_SQC.UI.Left_Panel             -- GtkListBox chart selector
Coyote_SQC.UI.Chart_Canvas           -- GtkDrawingArea + Cairo chart renderer
Coyote_SQC.UI.Detail_Panel           -- right-side detail / session replay panel
Coyote_SQC.UI.Toolbar                -- date range pickers, Show All, Y-Fit
Coyote_SQC.UI.Datetime_Picker        -- composite GtkEntry + GtkPopover datetime widget
Coyote_SQC.UI.Workspace_Settings     -- Workspace Settings dialog
Coyote_SQC.UI.Hover_Tooltip          -- GtkPopover point hover tooltip
Coyote_SQC.UI.Dialogs                -- confirmation dialogs, unsaved-changes prompt
Coyote_SQC.UI.Tool_Detail_Window     -- non-modal tool call detail window

Coyote_Renderer                      -- shared root
Coyote_Renderer.Markup               -- To_Pango_Markup (extracted from Coyote_GUI.Buffer)
Coyote_Renderer.Session_View         -- Render_Session: Session_Record → GtkTextBuffer
```

All packages under `Coyote_SQC.*` reside in `src/coyote_sqc/`.  
All packages under `Coyote_Renderer.*` reside in `src/coyote_renderer/`.

### 4.1 Package Responsibility Boundaries

- **`Coyote_SQC.Session_Parser`** is the only package that imports `GNATCOLL.JSON`
  to parse session JSONL. No other package references raw session file fields.
- **`Coyote_SQC.Statistics.*`** packages operate on `Float` arrays and scalars.
  They have no dependencies on data model types or GTK.
- **`Coyote_SQC.UI.*`** packages may depend on `Coyote_SQC.Data_Model`,
  `Coyote_SQC.Charts`, and `Coyote_SQC.Workspace`, but not on
  `Coyote_SQC.Session_Parser` directly.

---

## 5. Session JSONL Parser

### 5.1 File Format Versions

The parser (`Coyote_SQC.Session_Parser`) must handle two wire formats:

**Legacy format (version 1):**  
Header line: `{"createdAt": <ms-since-epoch>, "id": "UUID", "workDir": "..."}`  
Messages are bare role/content objects (no outer envelope).

**Current format (version 3):**  
Header line: `{"type": "session", "version": 3, "id": "UUID", "timestamp": "ISO8601",
"cwd": "..."}`  
Subsequent lines use a typed envelope: `{"type": "message", "message": {...}}`,
`{"type": "model_change", ...}`, `{"type": "thinking_level_change", ...}`, etc.

The parser detects the format from the header line. If the header has
`"type": "session"`, it is the current format; otherwise it is the legacy format.
Both formats can coexist across different session files in the same source directory.

### 5.2 Session Start Time

| Format | Field | Type | Conversion |
|---|---|---|---|
| Legacy (v1) | `createdAt` | Integer (ms since epoch) | Divide by 1000; add to Unix epoch |
| Current (v3) | `timestamp` | String (ISO 8601, UTC) | Parse `YYYY-MM-DDThh:mm:ss.sssZ` |

`Ada.Calendar.Time` is used for all internal timestamps. The parser converts to local
time on ingestion.

### 5.3 Source Directory

| Format | Field |
|---|---|
| Legacy (v1) | `workDir` |
| Current (v3) | `cwd` (header line) |

### 5.4 Model

The model is taken from the **last** `model_change` record in the file before any
message content. Concretely: scan lines in order; whenever a `model_change` record is
seen, record `provider & "/" & modelId` as the current model. The value at the end
of this scan is `Session_Record.Model`.

If no `model_change` record is present (possible for very old sessions), `Model` is
left as an empty string.

### 5.5 Turn Boundary Algorithm

A **turn** corresponds to a single LLM completion, represented in the JSONL as one
`role: "assistant"` message. The parser identifies turns as follows:

1. Read lines sequentially. Maintain a `Current_Turn` accumulator.
2. When a `role: "assistant"` message is seen: finalise the current turn and append a
   new `Turn_Record` to the session's `Turns` vector.
3. `role: "toolResult"` messages are **not** turns; they are consumed to populate the
   `Tool_Calls` vector of the most recently completed turn (matched by `toolCallId`).
4. `role: "user"` messages are not turns and are stored only to extract the first user
   message text.
5. Compaction records (`"type": "compaction"`) are skipped. The parser reads all
   messages in the file, both pre- and post-compaction, giving the full turn sequence
   regardless of what the agent currently sees.

### 5.6 Per-Turn Field Mapping

For each `role: "assistant"` message:

| Session field | JSONL source |
|---|---|
| `Input_Tokens` | `usage.input` (integer) |
| `Output_Tokens` | `usage.output` (integer) |
| `Thinking_Tokens` | `usage.thinking` (integer); when absent or zero and the turn contains one or more `"thinking"` content blocks, estimated as total thinking-block character count ÷ 4 |
| `Thinking_Enabled` | True if any content block has `"type": "thinking"` |
| `Tool_Calls` | Content blocks with `"type": "toolCall"` (see §5.7) |

### 5.7 Tool Call Field Mapping

For each `"type": "toolCall"` content block in an assistant message:

| Record field | JSONL source |
|---|---|
| `Tool_Name` | `name` string |
| `Input_Tokens` | Estimated from the serialised `arguments` JSON string length ÷ 4; set during assistant message parsing (0 if arguments are absent) |
| `Output_Tokens` | Estimated from the result text length ÷ 4; set when the matching `toolResult` record is processed (see §5.8) |
| `Failed` | See §5.8 |

Token counts for individual tool calls are not present in the session file; both
`Input_Tokens` and `Output_Tokens` on `Tool_Call_Record` are text-length estimates
using the 4-characters-per-token heuristic. `Input_Tokens` is set during assistant
message parsing; `Output_Tokens` is set when the matching `toolResult` record is
processed in §5.8.

### 5.8 Tool Call Failure Detection

A tool call with ID `id` is marked `Failed = True` if the corresponding
`role: "toolResult"` record (matched by `toolCallId = id`) has `"isError": true`.

Failure cases not recorded in `isError` (e.g. parsing errors on the model-generated
input) cannot be detected from the session file. The `Failed` field reflects only
what the JSONL records.

In addition to recording the failure flag, every `toolResult` record is consumed
to populate `Output_Tokens` on the matching `Tool_Call_Record`: the result text
length is divided by 4 using the 4-characters-per-token heuristic.

### 5.9 First User Message Extraction

`Session_Record.First_User_Message` is the text of the first `role: "user"` content
block of type `"text"`. Before storing, the following cleanup is applied:

1. Strip any leading `[Model → provider/id]` prefix (produced by Coyote when a model
   change notification is prepended to the message). Pattern:
   `^\[Model → [^\]]+\]\n?`.
2. Collapse interior whitespace runs to a single space.
3. Store the full cleaned text (no truncation; truncation is applied at display time).

### 5.10 Source Directory → Session File Path

The session files for a given source directory (project working directory) are stored
in:

```
~/.coyote/sessions/<slug>/
```

where the slug is produced by `Encode_Cwd`:

```
slug = "--" + cwd_with_leading_slash_stripped
              + cwd_with_each_forward_slash_replaced_by_dash
              + "--"
```

For example, `/home/gtnoble/Projects/myapp` → `--home-gtnoble-Projects-myapp--`.

The parser scans every `*.jsonl` file in the slug directory. Subdirectories are not
scanned.

---

## 6. Data Model

All types below are declared in `Coyote_SQC.Data_Model`. Ada 2022 style; two-space
indentation; `Unbounded_String` for variable-length stored strings.

### 6.1 Tool_Call_Record

```ada
type Tool_Call_Record is record
   Tool_Name    : Ada.Strings.Unbounded.Unbounded_String;
   Input_Tokens : Natural := 0;
   Output_Tokens: Natural := 0;
   Failed       : Boolean := False;
end record;

package Tool_Call_Vectors is new Ada.Containers.Vectors
  (Index_Type   => Positive,
   Element_Type => Tool_Call_Record);
```

### 6.2 Turn_Record

```ada
type Turn_Record is record
   Turn_Index      : Positive;
   Input_Tokens    : Natural := 0;
   Output_Tokens   : Natural := 0;
   Thinking_Tokens : Natural := 0;
   Thinking_Enabled: Boolean := False;
   Tool_Calls      : Tool_Call_Vectors.Vector;
end record;

package Turn_Vectors is new Ada.Containers.Vectors
  (Index_Type   => Positive,
   Element_Type => Turn_Record);
```

### 6.3 Session_Record

```ada
type Session_Record is record
   Session_Id          : Ada.Strings.Unbounded.Unbounded_String;
   Start_Time          : Ada.Calendar.Time;
   Source_Directory    : Ada.Strings.Unbounded.Unbounded_String;
   Model               : Ada.Strings.Unbounded.Unbounded_String;
   First_User_Message  : Ada.Strings.Unbounded.Unbounded_String;
   Total_Input_Tokens  : Natural := 0;
   Total_Output_Tokens : Natural := 0;
   Turns               : Turn_Vectors.Vector;
end record;

package Session_Vectors is new Ada.Containers.Vectors
  (Index_Type   => Positive,
   Element_Type => Session_Record);
```

### 6.4 Natural_Vectors

```ada
package Natural_Vectors is new Ada.Containers.Vectors
  (Index_Type   => Positive,
   Element_Type => Natural);
```

### 6.5 Session_Metrics_Record

Derived from `Session_Record` by `Coyote_SQC.Metrics.Compute`. Computed once at
load time and stored alongside the session.

```ada
type Session_Metrics_Record is record
   Session_Id               : Ada.Strings.Unbounded.Unbounded_String;
   N_Turns                  : Positive;
   N_Tool_Call_Turns        : Natural := 0;
   N_Thinking_Turns         : Natural := 0;
   N_Tool_Calls             : Natural := 0;
   N_Failed_Tool_Calls      : Natural := 0;
   Any_Thinking             : Boolean := False;
   Per_Turn_Input_Tokens    : Natural_Vectors.Vector;
   Per_Turn_Output_Tokens   : Natural_Vectors.Vector;
   Per_Turn_Tool_Tokens     : Natural_Vectors.Vector;
   Per_Turn_Thinking_Tokens : Natural_Vectors.Vector;
   N_Thinking_Turns_For_Chart : Natural := 0;
   N_Tool_Call_Turns_For_Chart : Natural := 0;
   Total_Input_Tokens         : Natural := 0;
   Total_Output_Tokens        : Natural := 0;
end record;
```

`Per_Turn_Tool_Tokens(i)` = sum of estimated `Input_Tokens + Output_Tokens` over all
tool calls in turn `i`. Only tool-call turns contribute an entry; the vector length
equals `N_Tool_Call_Turns_For_Chart`.

`Per_Turn_Thinking_Tokens` has one entry per thinking-enabled turn (not per total
turn). Its length equals `N_Thinking_Turns_For_Chart`.

### 6.6 Comment_Record

```ada
type Comment_Record is record
   Comment_Id : Ada.Strings.Unbounded.Unbounded_String;
   Session_Id : Ada.Strings.Unbounded.Unbounded_String;
   Timestamp  : Ada.Calendar.Time;
   Text       : Ada.Strings.Unbounded.Unbounded_String;
end record;

package Comment_Vectors is new Ada.Containers.Vectors
  (Index_Type   => Positive,
   Element_Type => Comment_Record);
```

### 6.7 Chart_Definition_Record

```ada
type Chart_Kind is
  (Turn_Tokens_Xbar,
   Turn_Tokens_S,
   Tool_Call_Tokens_Xbar,
   Tool_Call_Tokens_S,
   Thinking_Tokens_Xbar,
   Thinking_Tokens_S,
   Tool_Call_Failure_Rate,
   Fraction_Tool_Call_Turns,
   Fraction_Thinking_Turns,
   Session_Input_Tokens_I,
   Session_Input_Tokens_MR,
   Session_Output_Tokens_I,
   Session_Output_Tokens_MR);

type Chart_Definition_Record is record
   Chart  : Chart_Kind;
end record;
```

`Chart_Definition_Record` is minimal by design: chart-level state that changes at
runtime (computed limits, filtered point sets) is held in `Coyote_SQC.Charts.Chart_State`,
not in the persistent workspace record.

### 6.8 UUID_Sets

```ada
package UUID_Sets is new Ada.Containers.Hashed_Sets
  (Element_Type        => Ada.Strings.Unbounded.Unbounded_String,
   Hash                => Ada.Strings.Unbounded.Hash,
   Equivalent_Elements => Ada.Strings.Unbounded."=");

subtype UUID_Set is UUID_Sets.Set;
```

### 6.9 Workspace_Record

```ada
package String_Vectors is new Ada.Containers.Vectors
  (Index_Type   => Positive,
   Element_Type => Ada.Strings.Unbounded.Unbounded_String,
   "="          => Ada.Strings.Unbounded."=");

type Workspace_Record is record
   Workspace_Id      : Ada.Strings.Unbounded.Unbounded_String;
   Name              : Ada.Strings.Unbounded.Unbounded_String;
   Source_Directories: String_Vectors.Vector;
   Model_Filter      : String_Vectors.Vector;
   Setup_Session_Ids : UUID_Set;
   Comments          : Comment_Vectors.Vector;
end record;
```

---

## 7. Statistical Computation

All statistical packages (`Coyote_SQC.Statistics.*`) operate on `Long_Float` to
match `Ada.Numerics.Long_Elementary_Functions`.

### 7.1 c4 Constant — `Coyote_SQC.Statistics.C4`

```ada
function C4 (N : Positive) return Long_Float;
```

**Implementation:**

- For `N = 1`: raises `Constraint_Error` with message "c4 undefined for n=1".
  This precondition must never be violated by callers (§7.2, §7.3).
- For `2 ≤ N ≤ 100`: return from a precomputed `Long_Float` array, populated at
  package elaboration using the exact formula:

      c4(n) = sqrt(2 / (n-1)) * Γ(n/2) / Γ((n-1)/2)

  `Γ` is computed using `Ada.Numerics.Long_Elementary_Functions.Log` and the
  log-gamma recurrence: `log Γ(x) = log Γ(x+1) - log(x)`, seeding from
  `log Γ(0.5) = 0.5 * log(π)` and `log Γ(1.0) = 0.0`.

- For `N > 100`: return the approximation `1.0 - 1.0 / (4.0 * Long_Float(N - 1))`.

The lookup table is a `constant array (2 .. 100) of Long_Float` declared in the
package body.

### 7.2 Xbar Chart — `Coyote_SQC.Statistics.Xbar`

Inputs (all computed from the setup interval sessions):
- `Grand_Mean` : Long_Float  — grand mean x̄̄ (§5.2 of requirements)
- `Pooled_S`   : Long_Float  — pooled s̄ (§5.2)
- `N`          : Positive    — subgroup size for the point being evaluated

Output: `UCL`, `Center_Line`, `LCL` as Long_Float.

```
UCL = Grand_Mean + 3 * Pooled_S / (C4(N) * sqrt(N))
CL  = Grand_Mean
LCL = Grand_Mean - 3 * Pooled_S / (C4(N) * sqrt(N))
```

Single-turn sessions (`N = 1`) are plotted with `CL = session_mean` and no
control limits (`Has_UCL = False`, `Has_LCL = False`). `C4` is never called
for `N = 1`.

### 7.3 s Chart — `Coyote_SQC.Statistics.S_Chart`

Inputs: `Pooled_S`, `N`.  
Output: `UCL`, `Center_Line`, `LCL`.

```
CL  = C4(N) * Pooled_S
UCL = Pooled_S * (C4(N) + 3 * sqrt(1 - C4(N)**2))
LCL = Long_Float'Max(0.0,
        Pooled_S * (C4(N) - 3 * sqrt(1 - C4(N)**2)))
```

Sessions with `N = 1` have no s statistic and are not plotted on s charts.

### 7.4 p Chart — `Coyote_SQC.Statistics.P_Chart`

Inputs: `Grand_P` (p̄ from setup interval), `N` (subgroup size for this point).  
Output: `UCL`, `Center_Line`, `LCL`.

```
CL  = Grand_P
UCL = Grand_P + 3 * sqrt(Grand_P * (1 - Grand_P) / Long_Float(N))
LCL = Long_Float'Max(0.0,
        Grand_P - 3 * sqrt(Grand_P * (1 - Grand_P) / Long_Float(N)))
```

Sessions with `N = 0` are excluded entirely (no point plotted).

### 7.5 Setup Interval Parameter Estimation

`Coyote_SQC.Statistics` provides a procedure `Estimate_Parameters` that, given the
setup interval session metrics and a `Chart_Kind`, computes and returns:

For Xbar/s charts:
- `Grand_Mean` : Long_Float
- `Pooled_S`   : Long_Float

For p charts:
- `Grand_P`    : Long_Float

The pooled standard deviation estimate excludes single-turn sessions:

```
Pooled_S = sqrt(
  sum_i{(n_i - 1) * s_i^2 | n_i > 1}
  /
  sum_i{n_i - 1           | n_i > 1}
)
```

If all setup sessions have `N = 1` (denominator is zero), `Pooled_S` is set to 0.0
and the chart displays only the grand mean line with no limits.

For the **Thinking Tokens charts**, sessions where `Any_Thinking = False` are excluded
from parameter estimation. The subgroup is `Per_Turn_Thinking_Tokens`; subgroup size
`n_i = N_Thinking_Turns_For_Chart`.

For the **Tool Call Token charts**, sessions where `N_Tool_Call_Turns_For_Chart = 0`
(no tool-call turns) are excluded from parameter estimation. The subgroup is
`Per_Turn_Tool_Tokens`; subgroup size `n_i = N_Tool_Call_Turns_For_Chart`.

For the **Session Input/Output Token charts** (I and MR kinds), the observation is the
session-level scalar (`Total_Input_Tokens` or `Total_Output_Tokens` from
`Session_Metrics_Record`). `Estimate_Parameters` computes:
- `Grand_Mean` : Long_Float -- mean of setup-interval session totals
- `Mean_MR`    : Long_Float -- mean moving range between consecutive setup sessions

The metrics vector is iterated in chronological session order (the sort order
guaranteed by `Reload_Sessions`). A setup interval of one session produces
`Mean_MR = 0.0` (no limits drawn).

### 7.6 Retrospective Limits

When `Setup_Session_Ids` is empty, retrospective limits are computed from **all
sessions currently loaded in the workspace** (all source directories, subject to the
active model filter, regardless of the current date range shown on screen). The date
range toolbar affects only which points are *rendered*, not the limit computation.

Retrospective limit series are drawn in gray (RGB `0.5, 0.5, 0.5`) rather than red.

### 7.7 Out-of-Control Detection

A point is out-of-control if its statistic is strictly greater than `UCL` or strictly
less than `LCL` (only when `Has_LCL = True`). Only the 3-sigma rule is
negative). Only the 3-sigma rule is applied; no runs rules.

---


### 7.8 I Chart and MR Chart — `Coyote_SQC.Statistics.I_Chart`

Session-level totals (`Total_Input_Tokens`, `Total_Output_Tokens`) are single
scalar observations; there is no within-session subgroup. An Individuals (I) chart
plots each value directly; its companion Moving-Range (MR) chart monitors process
variation through consecutive differences.

```ada
--  Compute I-chart (Individuals) control limits.
--  Grand_Mean = x̄ of setup-interval session totals.
--  Mean_MR    = MR̄ (mean moving range between consecutive setup sessions).
--  When Mean_MR = 0.0, Has_UCL and Has_LCL are both False.
--  The LCL is clamped to 0 when the formula yields a negative value.
function Compute_I_Limits
  (Grand_Mean : Long_Float;
   Mean_MR    : Long_Float) return Limits_Record;

--  Compute MR-chart (Moving Range) control limits.
--  UCL = D4 * Mean_MR = 3.267 * Mean_MR.
--  LCL = 0 always; Has_LCL is always False.
--  When Mean_MR = 0.0, Has_UCL is False.
function Compute_MR_Limits (Mean_MR : Long_Float) return Limits_Record;
```

Constants: `d2 = 1.128`, `D4 = 3.267` (span-2 moving range).

Formulas:

```
I-chart: UCL/LCL = Grand_Mean ± 3 × Mean_MR / d2
MR-chart: UCL    = D4 × Mean_MR;  LCL = 0 always
```

The first session in the visible range has no predecessor and is excluded from the
MR chart (no marker, gap in connecting line). This is handled in
`Coyote_SQC.App.Recompute_Chart` using a `Prev_Total` / `Has_Prev_Total` state
variable that tracks the previous session's total across loop iterations.

## 8. Chart Definitions

`Coyote_SQC.Charts` declares the `Chart_Kind` enumeration (§6.7) and a
`Chart_Properties` record providing display metadata:

```ada
type Chart_Properties is record
   Label       : Ada.Strings.Unbounded.Unbounded_String;
   Group       : Ada.Strings.Unbounded.Unbounded_String;
   Y_Axis_Label: Ada.Strings.Unbounded.Unbounded_String;
   Is_P_Chart  : Boolean;
   Is_I_Chart  : Boolean;
end record;

function Properties (Kind : Chart_Kind) return Chart_Properties;
```

The thirteen charts and their properties:

| `Chart_Kind` | Label | Group | Y-Axis Label |
|---|---|---|---|
| `Turn_Tokens_Xbar` | `Turn Tokens — Xbar` | `Token Consumption` | `Mean output tokens/turn` |
| `Turn_Tokens_S` | `Turn Tokens — s` | `Token Consumption` | `Std dev output tokens/turn` |
| `Tool_Call_Tokens_Xbar` | `Tool Call Tokens — Xbar` | `Token Consumption` | `Mean tool-call tokens/turn` |
| `Tool_Call_Tokens_S` | `Tool Call Tokens — s` | `Token Consumption` | `Std dev tool-call tokens/turn` |
| `Thinking_Tokens_Xbar` | `Thinking Tokens — Xbar` | `Token Consumption` | `Mean thinking tokens/turn` |
| `Thinking_Tokens_S` | `Thinking Tokens — s` | `Token Consumption` | `Std dev thinking tokens/turn` |
| `Tool_Call_Failure_Rate` | `Tool Call Failure Rate` | `Rates` | `Failure proportion` |
| `Fraction_Tool_Call_Turns` | `Fraction: Tool-Call Turns` | `Rates` | `Fraction of turns` |
| `Fraction_Thinking_Turns` | `Fraction: Thinking Turns` | `Rates` | `Fraction of turns` |
| `Session_Input_Tokens_I`   | `Session Input Tokens -- I`   | `Session Totals` | `Total input tokens` |
| `Session_Input_Tokens_MR`  | `Session Input Tokens -- MR`  | `Session Totals` | `Moving range (input tokens)` |
| `Session_Output_Tokens_I`  | `Session Output Tokens -- I`  | `Session Totals` | `Total output tokens` |
| `Session_Output_Tokens_MR` | `Session Output Tokens -- MR` | `Session Totals` | `Moving range (output tokens)` |

The `Chart_Kind` iteration order matches the left-panel display order.

---

## 9. Workspace File Format

### 9.1 Extension and Location

Workspace files use the `.sqcw` extension. Location is user-chosen via file chooser.

### 9.2 JSON Schema (version 1)

```json
{
  "version": 1,
  "workspaceId": "uuid-string",
  "name": "string",
  "sourceDirectories": ["string", ...],
  "modelFilter": ["string", ...],
  "setupSessionIds": ["uuid-string", ...],
  "comments": [
    {
      "commentId": "uuid-string",
      "sessionId": "uuid-string",
      "timestamp": <unix-milliseconds>,
      "text": "string"
    },
    ...
  ]
}
```

All field names use `camelCase`. The `comments` array is ordered by ascending
`timestamp`. The `setupSessionIds` array is unordered; duplicate UUIDs are ignored
on load.

### 9.3 Version Migration

The application reads the `"version"` field first:

- `version = 1`: load normally using the schema above.
- `version > 1`: refuse to open; show a dialog: "This workspace was created by a
  newer version of coyote_sqc and cannot be opened."
- `version < 1` or absent: attempt load with best-effort field mapping; show a
  warning: "Workspace file has no version field; some data may be missing."

### 9.4 Unsaved Changes

`Coyote_SQC.Workspace` maintains a boolean `Modified` flag. It is set whenever
comments are added, the setup interval is changed, workspace settings are modified,
or the workspace is renamed. On quit, if `Modified = True`, a dialog is shown:

```
"Save changes to workspace '[Name]'?"
  [Save]  [Discard]  [Cancel]
```

`[Cancel]` aborts the quit. `[Discard]` quits without saving. `[Save]` saves and
quits.

The window title shows an asterisk suffix when `Modified = True`:
`coyote_sqc — WorkspaceName *`.

### 9.5 UUID Generation

New UUIDs (for workspace ID, comment IDs) are generated as UUIDv4 random values
using the same byte-random approach as `LLM.Session_Store.New_UUID`.

---

## 10. Shared Renderer Package

### 10.1 Package `Coyote_Renderer.Markup`

Extracted from `Coyote_GUI.Buffer.To_Pango_Markup`. Public interface:

```ada
--  Convert a Markdown string (GFM extensions: table, strikethrough, autolink)
--  to a Pango markup string suitable for Gtk.Text_Buffer.Insert_Markup.
--  Returns the input XML-escaped if libcmark-gfm is unavailable.
function To_Pango_Markup (MD_Text : String) return String;
```

Dependencies: `Coyote_Cmark`, `Glib`, standard Ada. No GTK widget types.

### 10.2 Package `Coyote_Renderer.Session_View`

Populates a `Gtk.Text_Buffer.Gtk_Text_Buffer` with a rendered session. Public
interface:

```ada
type Tool_End_Status is (Success, Error, Cancelled);

--  Callback invoked when the user clicks a tool call widget in the session
--  replay.  All parameters are captured in the widget closure at render time;
--  no re-parsing of the session file occurs at click time.
type Tool_Click_Callback is access procedure
  (Tool_Name    : String;
   Arguments    : String;
   Result_Text  : String;
   Is_Image     : Boolean;
   Status       : Tool_End_Status;
   Turn_Index   : Positive;
   Call_In_Turn : Positive;
   Session      : Coyote_SQC.Data_Model.Session_Record);

--  Render a session into Buffer in read-only mode.
--  Buffer is cleared before rendering.
--  When On_Tool_Click is non-null, each tool call is rendered as a GtkButton
--  widget embedded via GtkTextChildAnchor; clicking it invokes the callback
--  with the closure data captured at render time.
--  When On_Tool_Click is null, tool calls are rendered as plain tagged text
--  (non-interactive); View may be null in this case.
procedure Render_Session
  (Session       : Coyote_SQC.Data_Model.Session_Record;
   Buffer        : not null access Gtk.Text_Buffer.Gtk_Text_Buffer_Record'Class;
   View          : not null access Gtk.Text_View.Gtk_Text_View_Record'Class;
   On_Tool_Click : Tool_Click_Callback := null);

--  Return the JSONL file path for the given session UUID and source
--  directory, or empty string if not found.
function Find_Session_File
  (Session_Id       : String;
   Source_Directory : String) return String;
```

The `View` parameter is used to attach `GtkButton` widgets via
`Gtk.Text_View.Add_Child_At_Anchor` when `On_Tool_Click` is non-null.  Each
button captures the following data in its `clicked` signal closure: tool name,
raw arguments JSON string, result text, image flag (`Is_Image`), resolved status,
1-based turn index within the session, 1-based call position within the turn,
and the full `Session_Record`.  No re-parsing of the session file occurs when a
button is clicked.
The label of each `GtkButton` shall be prefixed with a status-dependent icon
using the same substitution rule as the detail window title: `✓` for `Success`,
`✗` for `Error`, and `-` for `Cancelled`.  A tool call for which no matching
tool result record is found in the session file (e.g. the session was truncated
before the tool completed) shall be assigned `Cancelled` status.

`Tool_End_Status` is declared in this package so that both
`Coyote_SQC.UI.Tool_Detail_Window` and `Coyote_GUI.Buffer` can reference it
without a circular dependency.  `Coyote_GUI.Buffer` retains its own
`Tool_End_Status` declaration for backward compatibility; the two types have
identical enumerators.

The procedure reads the raw session JSONL to obtain the full message content
needed for rendering (assistant text, thinking blocks, tool call frames), using
`Coyote_SQC.Session_Parser` to locate and parse the file by session UUID.

Scroll position is preserved across re-renders of the same session UUID. It is
reset to the top when a new (different) session UUID is rendered.


---

## 11. UI Architecture

### 11.1 Main Window

`Coyote_SQC.UI.Build_Main_Window` constructs the GTK widget tree. Entry point
`Coyote_SQC.App.Run` calls `Gtk.Main.Init`, calls `Build_Main_Window`, then calls
`Gtk.Main.Main`.

Widget tree (top-level):

```
GtkWindow "coyote_sqc — <name>"
└── GtkBox (vertical)
    ├── GtkMenuBar                          (§11.5)
    ├── GtkBox (horizontal, toolbar)        (§11.4)
    └── GtkPaned (horizontal, main content)
        ├── GtkScrolledWindow               (left panel)
        │   └── GtkListBox                  (chart selector, §11.2)
        ├── GtkDrawingArea                  (chart canvas, §12)
        └── GtkScrolledWindow               (detail panel, §11.6)
            └── GtkBox (vertical)
                └── [detail panel contents]
```

The three panels are separated by `GtkPaned` splitters. Default widths: left panel
180px, detail panel 380px. Both are user-resizable.

### 11.2 Left Panel — `Coyote_SQC.UI.Left_Panel`

A `GtkListBox` with visual group separators. Each row is a `GtkListBoxRow`
containing a `GtkLabel`. The three groups ("Token Consumption", "Rates", "Session Totals") are separated
by a `GtkSeparator` row styled with a group label above it.

Clicking a row:
1. Calls `App_State.Set_Active_Chart (Kind)`.
2. Triggers a canvas redraw.
3. Does not change the current selection.

### 11.3 App_State

`Coyote_SQC.App.App_State` is a `limited record` (not a protected object; the GTK
single-thread model means all mutations happen on the GTK main loop thread):

```ada
type App_State is limited record
   Workspace        : Coyote_SQC.Workspace.Workspace_Record;
   Sessions         : Coyote_SQC.Data_Model.Session_Vectors.Vector;
   Metrics          : array (Chart_Kind) of ...;  -- per-session metrics cache
   Active_Chart     : Chart_Kind := Turn_Tokens_Xbar;
   Selection        : UUID_Set;   -- selected session UUIDs
   Date_From        : Ada.Calendar.Time;
   Date_To          : Ada.Calendar.Time;
   Run_Sequence_Mode : Boolean := False;  -- True = equal-spacing run-sequence x-axis
   --  Global run indices: Sessions(I).Run_Index = I (1-based, chronological order).
   --  Populated by Reload_Sessions; never renumbered when the date filter changes.
   Run_Index_Map    : Coyote_SQC.Data_Model.Natural_Vectors.Vector;
   --  GTK widget handles
   Canvas           : Gtk.Drawing_Area.Gtk_Drawing_Area;
   Detail_Panel_Box : Gtk.Box.Gtk_Box;
   ...
end record;
```

A single `App_State_Access` global (package-level in `Coyote_SQC.App`) is
acceptable, mirroring the pattern used in `Digiplot.App` and consistent with
GTK's single-threaded callback model.

### 11.4 Toolbar — `Coyote_SQC.UI.Toolbar`

```
[From: YYYY-MM-DD HH:MM ▼]  [To: YYYY-MM-DD HH:MM ▼]  [Show All]  [Y-Fit]  [Run Sequence ☐]
```

- **From / To:** `Coyote_SQC.UI.Datetime_Picker` instances (§11.7).
- **Show All:** sets `Date_From` / `Date_To` to the minimum and maximum session start
  times; triggers canvas redraw.
- **Y-Fit:** calls `Canvas.Y_Fit` (§12.5).
- **Run Sequence ☐:** a `GtkCheckButton` (or `GtkToggleButton`) that toggles
  `App_State.Run_Sequence_Mode`. On toggle, calls `Switch_X_Scale_Mode` (§12.2.1),
  which re-maps `X_Min`/`X_Max` to the new coordinate space and redraws the canvas.
  The corresponding View menu item is kept in sync.

The toolbar pickers update live as the chart is panned (§12.3).

### 11.5 Menu Bar

**File**

| Item | Accelerator | Action |
|---|---|---|
| New Workspace… | — | `Workspace.New_Workspace_Dialog` |
| Open Workspace… | — | File chooser, filter `*.sqcw` |
| Recent Workspaces ▶ | — | Submenu from `Config.Recent_Workspaces` |
| Save Workspace | Ctrl+S | `Workspace.Save` |
| Save Workspace As… | — | File chooser save dialog |
| *(separator)* | | |
| Quit | Ctrl+Q | `Gtk.Main.Main_Quit` (with unsaved-changes check) |

**Workspace**

| Item | Action |
|---|---|
| Workspace Settings… | `UI.Workspace_Settings.Show_Dialog` |
| Reload Sessions | Re-scan all source directories; update session list |

**View**

| Item | Action |
|---|---|
| Show All | Reset date range to full extent |
| Y-Fit | Refit y-axis to visible points |
| *(separator)* | |
| Clear Selection | `App_State.Selection.Clear`; hide detail panel |
| Clear Setup Interval | `Workspace.Clear_Setup_Interval` with confirmation; grayed out if `Setup_Session_Ids` is empty |
| *(separator)* | |
| X-Axis: Run Sequence | Toggle `App_State.Run_Sequence_Mode`; checkmark shown when active; triggers `Switch_X_Scale_Mode` (§12.2.1) and canvas redraw; kept in sync with the toolbar checkbox |

### 11.6 Detail Panel — `Coyote_SQC.UI.Detail_Panel`

The detail panel is hidden (zero width, `GtkPaned` position collapsed) when
`App_State.Selection` is empty. It is shown whenever the selection becomes non-empty.

**Single-session view** (exactly one UUID in selection):

```
GtkBox (vertical)
├── GtkFrame "Session"
│   └── GtkGrid
│       ├── [datetime]  [model]
│       ├── [source dir]
│       └── [input tokens / output tokens]
├── GtkFrame "Prompt"
│   └── GtkTextView (read-only, word-wrap, non-editable)
├── GtkFrame "Session Replay"
│   └── GtkScrolledWindow
│       └── GtkTextView (read-only; populated by Coyote_Renderer.Session_View)
└── GtkFrame "Comments"
    ├── GtkListBox (existing comments, chronological)
    ├── GtkTextView (new comment entry)
    └── GtkButton "Add Comment"
```

Scroll position in the Session Replay `GtkTextView` is saved in a
`Hash_Map<UUID → Gtk.Adjustment.Gtk_Adjustment>` and restored when the same session
is re-selected.

**Multi-select view** (two or more UUIDs in selection):

```
GtkBox (vertical)
├── GtkLabel "N sessions selected"
├── GtkLabel "YYYY-MM-DD – YYYY-MM-DD"
├── GtkButton "Set as Setup Interval"
├── GtkFrame "Add Comment to All Selected"
│   ├── GtkTextView (entry)
│   └── GtkButton "Add Comment to All"
└── GtkFrame "Selected Sessions"
    └── GtkScrolledWindow
        └── GtkListBox (rows: datetime, model, source dir)
```

Clicking a row in the Selected Sessions list switches the detail panel to the
single-session view for that session without clearing the overall multi-selection.

### 11.7 Datetime Picker — `Coyote_SQC.UI.Datetime_Picker`

A custom composite widget:

```
GtkEntry (displays "YYYY-MM-DD HH:MM")
  └── [on icon-press or focus] → GtkPopover
          └── GtkBox (vertical)
              ├── GtkCalendar
              └── GtkBox (horizontal)
                  ├── GtkSpinButton (hours, 0–23)
                  ├── GtkLabel ":"
                  └── GtkSpinButton (minutes, 0–59)
```

Public Ada interface:

```ada
type Instance is tagged limited private;

procedure Create (Self : out Instance; Parent : Gtk.Widget.Gtk_Widget);
function  Get_Time (Self : Instance) return Ada.Calendar.Time;
procedure Set_Time (Self : in out Instance; T : Ada.Calendar.Time);

type Changed_Callback is access procedure (T : Ada.Calendar.Time);
procedure On_Changed (Self : in out Instance; CB : Changed_Callback);
```

### 11.8 Hover Tooltip — `Coyote_SQC.UI.Hover_Tooltip`

Implemented as a `GtkPopover` anchored to the chart `GtkDrawingArea`. It is shown
when the cursor is within 6 pixels of a point marker and dismissed when the cursor
moves beyond 12 pixels.

The popover contains a `GtkLabel` with markup-formatted content (see requirements
§8.3). Content is rebuilt each time a different point is hovered.

### 11.9 Tool Call Detail Window — `Coyote_SQC.UI.Tool_Detail_Window`

The tool call detail window is opened when the user clicks a tool call button
in the Session Replay `GtkTextView` of the single-session detail panel.
`Coyote_SQC.UI.Detail_Panel` registers a `Tool_Click_Callback` with
`Render_Session` that invokes `Tool_Detail_Window.Show`, forwarding the closure
parameters and the main `GtkWindow`.

#### Public Interface

```ada
--  Open a new non-modal tool call detail window transient for Main_Window.
--  Multiple windows may be open simultaneously; each is independent.
procedure Show
  (Tool_Name    : String;
   Arguments    : String;
   Result_Text  : String;
   Is_Image     : Boolean;
   Status       : Coyote_Renderer.Session_View.Tool_End_Status;
   Turn_Index   : Positive;
   Call_In_Turn : Positive;
   Session      : Coyote_SQC.Data_Model.Session_Record;
   Main_Window  : not null access Gtk.Window.Gtk_Window_Record'Class);
```

#### Widget Tree

```
GtkWindow (non-modal, transient for main window; min size 600 × 400 px)
└── GtkBox (vertical, spacing 6, border 8)
    ├── GtkGrid (header section, 4 rows × 2 columns)
    │   ├── [row 0] GtkLabel "Datetime:"  GtkLabel <datetime>
    │   ├── [row 1] GtkLabel "Model:"     GtkLabel <model>
    │   ├── [row 2] GtkLabel "Directory:" GtkLabel <source_dir>
    │   └── [row 3] GtkLabel "Turn:"      GtkLabel "Turn N, call M"
    ├── GtkFrame "Arguments"
    │   └── GtkBox (vertical, spacing 4)
    │       └── [per field, repeated]
    │           ├── GtkLabel (bold field name)
    │           └── GtkScrolledWindow
    │               └── GtkTextView (read-only, monospace, selectable)
    └── GtkFrame "Result"
        ├── GtkLabel (status banner, CSS-coloured background)
        └── GtkScrolledWindow
            └── GtkTextView (read-only, monospace, selectable)
                or GtkImage (when Is_Image = True)
```

#### Window Title

```
⚙ tool_name — Turn N — YYYY-MM-DD HH:MM
```

where `tool_name` is the name of the tool, `N` is `Turn_Index`, and the datetime
is `Session.Start_Time` formatted as `YYYY-MM-DD HH:MM` in local time.  The
leading gear icon `⚙` is replaced by `✓` (Success), `✗` (Error), or `-`
(Cancelled) according to `Status`.

#### Header Section

A `GtkGrid` (4 rows × 2 columns) with bold-key `GtkLabel`s in column 0 and
plain-text value `GtkLabel`s in column 1:

- **Datetime:** `Session.Start_Time` in local time, formatted `YYYY-MM-DD HH:MM:SS`
- **Model:** `Session.Model`
- **Directory:** `Session.Source_Directory` with leading `$HOME` replaced by `~`
- **Turn:** `"Turn N, call M"` where N = `Turn_Index`, M = `Call_In_Turn`

#### Arguments Section

`Arguments` is the raw JSON string captured at render time.  The section is
built as follows:

1. Attempt to parse `Arguments` as a JSON object (`GNATCOLL.JSON.Read`).
2. If parsing succeeds and the value is a JSON object: iterate its top-level keys
   in JSON-source order (the order they appear in the string, as returned by
   `GNATCOLL.JSON.JSON_Value.Map_JSON_Object`).  For each key, append:
   - A `GtkLabel` with `<b>key</b>` markup.
   - A `GtkScrolledWindow` wrapping a read-only, selectable, monospace
     `GtkTextView` containing the field value: raw string content for JSON
     strings; `JSON_Value.Write` output for all other JSON types.
3. If parsing fails or the value is not a JSON object: render a single unlabelled
   `GtkTextView` containing the raw `Arguments` string.

All `GtkTextView` widgets in the arguments section use a monospace font
(`Pango.Font_Description` set to `"Monospace"`).

#### Result Section

The result section opens with a `GtkLabel` status banner whose background is set
via a CSS provider applied to that label's `GtkStyleContext`:

| `Status` | Background colour | Text |
|---|---|---|
| `Success` | `#d4edda` (green) | `✓ success` |
| `Error` | `#f8d7da` (red) | `✗ error` |
| `Cancelled` | `#e2e3e5` (gray) | `- cancelled` |

**Text result** (`Is_Image = False`): a `GtkScrolledWindow` wrapping a
read-only, selectable, monospace `GtkTextView` populated with the full
`Result_Text` string.  No truncation is applied.

**Image result** (`Is_Image = True`): `Result_Text` is a base64-encoded image.
A `GdkPixbuf` is constructed by decoding the base64 data into a byte buffer and
loading it via `Gdk.Pixbuf.Gdk_New_From_Data`.  A `GtkImage` is constructed from
the pixbuf and placed inside a `GtkScrolledWindow`.

#### Lifecycle

`Show` creates a new `GtkWindow` on each call.  The window is set transient for
`Main_Window` and destroyed when the user clicks the window manager close button
(the GTK `"destroy"` signal).  No reference to the window is retained by the
application after `Show` returns; GTK reference counting manages the window
lifetime.  Multiple detail windows for different tool calls may be open
simultaneously.


---

## 12. Chart Canvas Implementation

### 12.1 Package `Coyote_SQC.UI.Chart_Canvas`

The chart is rendered on a `GtkDrawingArea`. All drawing uses Cairo.

```ada
type Canvas_State is limited record
   --  Coordinate transform
   X_Min, X_Max : Long_Float;  -- x range: Unix seconds in Time Scale mode; 1-based run index in Run Sequence mode
   Y_Min, Y_Max : Long_Float;  -- data-space y range
   Width, Height: Glib.Gint;   -- widget size in pixels
   --  Interaction state
   Drag_Active  : Boolean := False;
   Drag_Start   : Screen_Point;
   Drag_X_Min_At_Start, Drag_X_Max_At_Start : Long_Float;
   Drag_Y_Min_At_Start, Drag_Y_Max_At_Start : Long_Float;
   --  Rubber-band selection
   Rubberband_Active : Boolean := False;
   Rubberband_Start, Rubberband_End : Screen_Point;
   --  Hovered point
   Hovered_Session_Id : Ada.Strings.Unbounded.Unbounded_String;
end record;
```

### 12.2 Coordinate System

**Data space — Time Scale mode:** x is `Ada.Calendar.Time` expressed as `Long_Float`
seconds since the Unix epoch (produced by `Time_To_LF`). y is the chart statistic
(Long_Float).

**Data space — Run Sequence mode:** x is the 1-based integer run index of the session
(stored as `Long_Float`). Run index 1.0 is the chronologically first session in the
workspace; each subsequent session in time order receives the next integer. y is
unchanged. The `X_Min`/`X_Max` in `Canvas_State` hold index values (e.g. `1.0` to
`47.0`) rather than Unix timestamps.

**Screen space:** `(0, 0)` is the top-left of the `GtkDrawingArea` widget; `(Width, Height)`
is the bottom-right. A fixed margin of 60px on the left (for y-axis labels), 40px on
the right, 30px on top, 50px on the bottom (for x-axis labels) defines the **plot
area**.

Transform functions:

```ada
function Data_To_Screen (CS : Canvas_State; DX, DY : Long_Float)
   return Screen_Point;

function Screen_To_Data (CS : Canvas_State; SP : Screen_Point)
   return Data_Point;
```

#### 12.2.1 Run-Sequence Index Mapping

`Session_Run_Index` assigns global, non-renumbering run indices to every session in
`App_State.Sessions` (sorted chronologically). It is computed once by `Reload_Sessions`
and stored in `App_State.Run_Index_Map` (`Natural_Vectors.Vector`), which is a
parallel vector to `App_State.Sessions`
mapping each session's vector position to its 1-based run index.

Because sessions are always stored in chronological order, `Run_Index_Map(I) = I`
for all `I`. The indirection is kept explicit so that a future revision can assign
non-contiguous indices without touching the rendering code.

Two helper functions are provided in `Coyote_SQC.UI.Chart_Canvas`:

```ada
--  Return the Ada.Calendar.Time of the session whose run index is nearest to Idx.
--  For non-integer Idx, rounds to the nearest integer index.
--  Returns the epoch if Sessions is empty.
function Run_Index_To_Time
  (Sessions : Coyote_SQC.Data_Model.Session_Vectors.Vector;
   Idx      : Long_Float) return Ada.Calendar.Time;

--  Return the run index (1-based Long_Float) of the session in Sessions
--  whose Start_Time is nearest to T.  Returns 1.0 if Sessions is empty.
function Time_To_Run_Index
  (Sessions : Coyote_SQC.Data_Model.Session_Vectors.Vector;
   T        : Ada.Calendar.Time) return Long_Float;
```

**Mode-switch coordinate translation (`Switch_X_Scale_Mode`):**  
When the user toggles between Time Scale and Run Sequence mode, the current
`X_Min`/`X_Max` viewport must be re-expressed in the new coordinate space so the
same sessions remain visible:

- *Time Scale → Run Sequence:* call `Time_To_Run_Index` on both `X_Min` and `X_Max`
  (treated as Unix-second times via `LF_To_Time`) to obtain the new index bounds.
- *Run Sequence → Time Scale:* call `Run_Index_To_Time` on both `X_Min` and `X_Max`
  and convert the resulting times to Unix seconds via `Time_To_LF`.

`Sync_Pickers` (the procedure that copies the current viewport to the From/To toolbar
pickers) always works in datetimes. In Time Scale mode it calls `LF_To_Time(X_Min/X_Max)`;
in Run Sequence mode it calls `Run_Index_To_Time(X_Min/X_Max)`.

`Point_X` (the helper that computes the x-coordinate for a session when building the
draw list) returns `Time_To_LF(Session.Start_Time)` in Time Scale mode and
`Long_Float(Session_Run_Index)` in Run Sequence mode.

### 12.3 Zoom and Pan

**X-zoom (mouse wheel on plot area):**

```
factor = 1.15 (scroll up) or 1/1.15 (scroll down)
cursor_data_x = Screen_To_Data(cursor_screen_x).X
X_Min' = cursor_data_x + (X_Min - cursor_data_x) / factor
X_Max' = cursor_data_x + (X_Max - cursor_data_x) / factor
```

The toolbar From/To pickers are updated after every zoom via `Sync_Pickers`. In Run
Sequence mode, `Sync_Pickers` calls `Run_Index_To_Time` to convert `X_Min`/`X_Max`
to datetimes before setting the picker values.

**Y-zoom (mouse wheel on y-axis margin):**  
Same formula applied to `Y_Min` / `Y_Max`, centered on `cursor_data_y`.

**Pan (click-drag on plot background, no modifier):**  
On button-press: record `Drag_Start` in screen coordinates and snapshot
`X_Min/X_Max/Y_Min/Y_Max` into `Drag_*_At_Start`.  
On motion:

```
dx_screen = cursor_x - Drag_Start.X
dy_screen = cursor_y - Drag_Start.Y
dx_data   = dx_screen * (X_Max_At_Start - X_Min_At_Start) / plot_width
dy_data   = dy_screen * (Y_Max_At_Start - Y_Min_At_Start) / plot_height
X_Min = X_Min_At_Start - dx_data
X_Max = X_Max_At_Start - dx_data
Y_Min = Y_Min_At_Start + dy_data   -- y screen is inverted
Y_Max = Y_Max_At_Start + dy_data
```

Both x and y move together in one drag (rigid canvas). Toolbar pickers update live
via `Sync_Pickers` (Run Sequence mode: `Run_Index_To_Time` used as above).

**Rubber-band selection (Shift + click-drag on plot background):**  
Holding Shift while clicking and dragging on an empty plot area activates the
rubber-band rectangle instead of panning. On mouse-button release, all points whose
screen coordinates fall within the rectangle are added to the current selection.
The modifier state is read directly from the GDK button event (`Event.State and
Shift_Mask`), not from keyboard focus tracking, so Shift does not need to be pressed
while the canvas already holds keyboard focus.

### 12.4 Y-Fit

Collects the y-values of all points within `[X_Min, X_Max]` (plus UCL/LCL series
within that range). Sets `Y_Min` and `Y_Max` to the minimum and maximum of those
values, expanded by 10% margin on each side. If no points are in range, no-op.

### 12.5 Hit Testing

A point at screen position `(px, py)` is "hit" if the Euclidean distance from the
cursor to `(px, py)` is ≤ 6 pixels. Hit testing iterates over all rendered points
in chronological order; the first hit within radius wins.

For rubber-band selection: all points whose screen coordinates fall within the
rubber-band rectangle (after normalising the rectangle to have positive width/height)
are added to the selection.

Individual points can be added to or removed from the current selection with
Shift+click; a plain click on a point replaces the selection with that single point.
Both interactions read `Shift_Mask` from the GDK button event, mirroring the
rubber-band activation described in §12.3.

### 12.6 Rendering Pipeline

The `On_Draw` callback executes these steps in order:

1. **Clear:** fill plot area with white; fill margins with the window background.
2. **Setup interval band:** if `Setup_Session_Ids` non-empty, fill a faint yellow
   rectangle (`RGBA(1.0, 0.97, 0.6, 0.4)`). In **Time Scale** mode the rectangle
   spans the time extent of the setup sessions (x-coordinates are Unix seconds). In
   **Run Sequence** mode the rectangle spans the run-index extent of the setup
   sessions (x-coordinates are run indices). In both modes the band is clipped to
   the current `X_Min`/`X_Max` viewport.
3. **Connecting line:** thin black polyline through all non-excluded,
   non-hollow-gray points in chronological order, clipped to the plot area by
   a Cairo `cairo_clip` region. Because the clip is used rather than skipping
   off-screen points, lines that connect an in-viewport point to an
   out-of-viewport neighbour extend continuously to the viewport boundary
   instead of terminating at the last visible point. Hollow-gray points (n=1 on
   s chart, zero-thinking on thinking chart) are omitted and break the line.
   Excluded (non-hollow-gray) points are skipped silently — the line connects
   across them without a gap.
4. **Control limit series:** red dashed polyline for UCL through all
   non-excluded points that have a `Has_UCL` value; second polyline for LCL
   through all non-excluded points that have `Has_LCL = True`. When the formula
   yields a negative LCL it is clamped to 0.0 (`Has_LCL` remains `True`); the
   line is drawn at y = 0. Both series are also clipped to the plot area. Under
   retrospective limits, use gray instead of red and draw the "retrospective
   limits" label.
5. **Center line:** solid blue polyline through all non-excluded points,
   clipped to the plot area.
6. **Point markers:** filled/hollow circles per §7.3.3 of the requirements.
   Radius: 5px.
7. **Rubber-band rectangle:** if `Rubberband_Active`, draw a dashed rectangle
   in dark gray (`RGBA(0.3, 0.3, 0.3, 0.8)`) with a semi-transparent fill
   (`RGBA(0.7, 0.7, 1.0, 0.15)`).
8. **Selection halos:** for each selected point, draw a 2px blue ring 3px outside
   the marker radius.
9. **Axis tick marks and labels:** y-axis ticks with numeric labels. X-axis tick
   label generation depends on the scale mode:
   - *Time Scale:* tick values are Unix-second Long_Floats; labels are produced by
     `Format_Tick_Label` which calls `LF_To_Time` and formats as `YYYY-MM-DD HH:MM`.
     Tick density scales with available pixel space.
   - *Run Sequence:* tick values are run-index Long_Floats; labels are produced by
     calling `Run_Index_To_Time` on the tick value and formatting the result as
     `YYYY-MM-DD HH:MM`. Tick positions are placed at integer run indices within the
     visible range, with density thinned when the visible index span is large.
10. **Axis labels:** y-axis label rotated 90° on the left margin; x-axis label below.

### 12.7 Point Marker Colors (Cairo RGB)

| Condition | Fill | Stroke | Hollow? |
|---|---|---|---|
| In-control, no comment | `(0, 0, 0)` | `(0, 0, 0)` | No |
| In-control, comment present | `(0.1, 0.7, 0.2)` | `(0.05, 0.5, 0.1)` | No |
| Out-of-control, no comment | `(0.9, 0.1, 0.1)` | `(0.9, 0.1, 0.1)` | No |
| In setup interval | `(1.0, 0.85, 0.0)` | `(0.7, 0.6, 0.0)` | No |
| Out-of-control, comment present | `(0.95, 0.5, 0.0)` | `(0.7, 0.35, 0.0)` | No |
| Zero-thinking excluded | `(0, 0, 0)` | `(0.6, 0.6, 0.6)` | Yes |
| Single-turn on Xbar chart | `(0, 0, 0)` | `(0, 0, 0)` | Yes |
| Selected halo | — | `(0.1, 0.3, 0.9)` 2px ring | Additive |

Yellow (setup interval) takes precedence over all fill colors when a session is in
the setup interval. Green (in-control with comment) takes precedence over black but
not over yellow.

---

## 13. Configuration Files

All per-user configuration lives under `~/.config/coyote_sqc/`.

### 13.1 Recent Workspaces — `recent_workspaces.json`

```json
{
  "version": 1,
  "recent": [
    {
      "name": "string",
      "path": "/absolute/path/to/file.sqcw",
      "lastOpened": <unix-milliseconds>
    },
    ...
  ]
}
```

Maximum 5 entries, ordered by descending `lastOpened`. On each workspace open or
save, the entry for that path is upserted at the top and any entry beyond position 5
is dropped. The file is written atomically (write to `.tmp`, then rename).

---

## 14. Testing

### 14.1 Statistical Tests — `Coyote_SQC.Tests.Statistics`

AUnit test suite covering:

- **c4 accuracy:** `C4(n)` for n = 2..25 against a reference table (values taken
  from ASTM E2587 Table 1). Maximum absolute error ≤ 1×10⁻⁶.
- **c4 approximation:** `C4(n)` for n = 101 and n = 500; confirm approximation
  is within 0.1% of the exact value.
- **Xbar limits (known dataset):** a hand-computed 5-session dataset with varying
  subgroup sizes; verify UCL, CL, LCL to 4 decimal places.
- **s chart limits (known dataset):** same dataset; verify UCL, CL, LCL.
- **p chart limits (known dataset):** a hand-computed 4-session dataset; verify
  UCL, CL, LCL.
- **Special cases:**
  - n=1 session contributes to grand mean but not pooled s.
  - n=0 session on p-chart produces no limits and no point.
  - All setup sessions have n=1 → Pooled_S = 0, only grand mean line drawn.
  - Zero-thinking sessions excluded from thinking chart estimation.
  - Single-session setup interval produces `Mean_MR = 0.0`; no limits drawn.
  - `Mean_MR = 0.0` (all session totals equal) produces no limits.
  - I-chart LCL clamped to 0 when formula yields negative.
  - I-chart LCL positive when grand mean is large relative to `Mean_MR`.
  - MR-chart `Has_LCL` always False.

### 14.2 Parser Tests — `Coyote_SQC.Tests.Parser`

Using fixture JSONL files committed to `test/fixtures/sqc/`:

- **Legacy format (v1):** parse a synthetic v1 file; verify UUID, start time,
  model, first user message, turn count, tool call failure flags.
- **Current format (v3):** parse a synthetic v3 file; verify same fields.
- **Thinking tokens:** a file with `"usage": {"thinking": 42}` on an assistant
  message; verify `Turn.Thinking_Tokens = 42`.
- **Thinking estimation absent:** a file with no `"thinking"` field in usage;
  verify `Turn.Thinking_Tokens = 0` (backward compatibility).
- **Compaction:** a file with a compaction record; verify all turns (pre- and
  post-compaction) are counted.
- **Model change:** a file with two `model_change` records; verify the last model
  is stored.
- **Prompt prefix stripping:** a file whose first user message starts with
  `[Model → provider/id]`; verify the prefix is absent from `First_User_Message`.
- **Multi-tool turn:** a turn with two tool calls, one with `isError: true`; verify
  `N_Failed_Tool_Calls = 1` and `N_Tool_Calls = 2`.

### 14.3 Workspace Serialisation Tests — `Coyote_SQC.Tests.Workspace`

- Round-trip: create a `Workspace_Record`, save to a temp file, reload; verify all
  fields are identical.
- Version check: a file with `"version": 99` is refused with an appropriate error.
- Missing version: a file with no `"version"` field loads with a warning.
- UUID deduplication: a `setupSessionIds` array with a repeated UUID results in a
  set of size 1.

### 14.4 Test Runner

Tests live in `test/src/` alongside existing Coyote tests, registered in the
existing AUnit test suite. Fixture files live in `test/fixtures/sqc/`.

### 14.5 Tool Call Detail Window Tests — `Coyote_SQC.Tests.Tool_Detail`

- **Widget embedding:** call `Render_Session` with a non-null `On_Tool_Click`
  callback on a fixture session containing at least one tool call; verify that
  the `GtkTextBuffer` contains at least one `GtkTextChildAnchor` rather than a
  plain text entry for the tool call.
- **Closure data:** using a fixture session with known tool call content, verify
  that the callback receives the correct `Tool_Name`, `Arguments`, `Result_Text`,
  `Status`, `Turn_Index`, and `Call_In_Turn` values.
- **Null callback fallback:** call `Render_Session` with `On_Tool_Click => null`;
  verify that no `GtkTextChildAnchor` is created and the tool call name appears
  as plain text in the buffer.
- **Window title — all statuses:** call `Show` with each `Tool_End_Status` value
  (`Success`, `Error`, `Cancelled`); verify the window title begins with `✓`, `✗`,
  and `-` respectively and contains `"Turn N"` and the session datetime.
- **Arguments JSON key order:** call `Show` with a multi-field JSON arguments
  string whose keys are in a known non-alphabetical order; verify the argument
  field labels in the widget tree appear in the same order as the source JSON.
- **Non-object arguments fallback:** call `Show` with an `Arguments` string that
  is not a valid JSON object; verify that a single unlabelled `GtkTextView` is
  present in the Arguments frame rather than per-field sections.
- **Image result path:** call `Show` with `Is_Image => True` and a small
  base64-encoded PNG; verify the result section contains a `GtkImage` widget
  rather than a `GtkTextView`.

- **Replay button icon — all statuses:** render a fixture session whose tool
  calls include at least one `Success`, one `Error`, and one with no matching
  result record (`Cancelled`); verify that the `GtkButton` labels for those
  tool calls begin with `✓`, `✗`, and `-` respectively.
- **Cancelled status for missing result:** render a fixture session containing
  a tool call whose `id` has no corresponding `toolResult` record in the file;
  verify that the closure captured for that button has `Status = Cancelled`
  and that the button label prefix is `-`.


---

*End of document.*
