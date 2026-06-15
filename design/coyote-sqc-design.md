# coyote_sqc — Design Specification

**Project:** Coyote Session Quality Control  
**Version:** 0.1 (draft)  
**Date:** 2026-06-13  
**Status:** In progress  
**Requirements:** `requirements/coyote-sqc-requirements.md`

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
Coyote_SQC.Statistics.Tests          -- descriptive statistics (Mean_Of,
                        --   Std_Dev_Of) and goodness-of-fit tests
                        --   (KS_Normality_P_Value, KS_Exponential_P_Value,
                        --   Runs_Test_P_Value) for the multi-select panel
Coyote_SQC.Statistics.Bootstrap      -- percentile bootstrap 95% CI for two-set
                        --   comparison (§5.17): Compute_CI for mean diff,
                        --   median diff, and SD ratio; fixed seed 12345
Coyote_SQC.Statistics.Quantile_CC    -- two-stage bootstrap quantile profile limits
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
Coyote_SQC.UI.Histogram_Canvas      -- Cairo histogram for multi-select detail panel;
                        --   Compute_Bins (exposed for unit testing), Build,
                        --   Refresh; fixed 160px GtkDrawingArea
Coyote_SQC.UI.Dialogs                -- confirmation dialogs, unsaved-changes prompt
Coyote_SQC.UI.Chart_Settings_Dialog  -- per-chart Box-Cox, estimation method, EWMA params dialog
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
  `Load_Sessions` accepts an optional `Previous_Sessions` vector.  When
  provided, `Scan_Dir` checks each file's modification time against the
  corresponding cached `Session_Record.File_Mtime`; unchanged files are
  reused without re-parsing.  `Reload_Sessions` (in `Coyote_SQC.App`) passes
  the current `App_State.Sessions` as `Previous_Sessions` and similarly
  reuses cached `Session_Metrics_Record` values for unchanged sessions,
  computing fresh metrics only for new or modified files.  This satisfies the
  requirement that subsequent Reload Sessions operations complete within
  1 second per added or modified session.
- **`Coyote_SQC.Statistics.*`** packages operate on `Float` arrays and scalars.
  They have no dependencies on data model types or GTK.
- **`Coyote_SQC.UI.*`** packages may depend on `Coyote_SQC.Data_Model`,
  `Coyote_SQC.Charts`, and `Coyote_SQC.Workspace`, but not on
  `Coyote_SQC.Session_Parser` directly.
- **Self-contained chart computation:** `Recompute_Chart (Kind)` looks up a
  `Chart_Descriptor` (§6.7a) and extracts all required setup-interval
  observations using the chart's `Get_Observation` or `Get_Subgroup` accessor,
  then estimates parameters and computes limits without reading cached state
  from any other chart's `Chart_Data` slot.  I, MR, and EWMA charts for the
  same session metric each independently extract the same observation series
  and arrive at identical parameter values through deterministic computation.

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
| `Input_Tokens` | `usage.input` (integer; normalized to total context window tokens — see §5.11) |
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

### 5.11 Token Accounting Normalization

Different LLM providers use incompatible conventions for the `input_tokens`
field in their usage records:

- **Anthropic:** `input_tokens` is the *non-cached* portion of the prompt only.
  Cache-hit tokens (`cache_read_input_tokens`) and cache-fill tokens
  (`cache_creation_input_tokens`) are reported separately.
- **OpenAI:** `prompt_tokens` is the *total* prompt token count, which already
  includes any cached subset (`prompt_tokens_details.cached_tokens`).

The parser normalises all sessions to a common `Input_Tokens` definition:
**total tokens submitted to the model's context window**.

| Provider (detected from `Last_Model` prefix) | `Input_Tokens` stored |
|---|---|
| `"anthropic/"` | `usage.input + usage.cacheRead + usage.cacheWrite` |
| All others (OpenAI, etc.) | `usage.input` unchanged |

`cacheRead` and `cacheWrite` values in the JSONL are **not** altered.
`Total_Uncached_Input_Tokens` for the session is accumulated as the sum over
turns of `(normalized_input − turn_cache_read − turn_cache_write)`, which
equals the raw `usage.input` for Anthropic turns and
`prompt_tokens − cached_tokens` for OpenAI turns.

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
   Arguments    : Ada.Strings.Unbounded.Unbounded_String;
   --  Raw JSON argument string; populated at parse time for JSD computation.
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
   Total_Cache_Read_Tokens  : Natural := 0;
   Total_Cache_Write_Tokens : Natural := 0;
   Total_Uncached_Input_Tokens : Natural := 0;
   Turns               : Turn_Vectors.Vector;
   File_Path           : Ada.Strings.Unbounded.Unbounded_String;
   File_Mtime          : Ada.Calendar.Time;
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

```ada
package Long_Float_Vectors is new Ada.Containers.Vectors
  (Index_Type   => Positive,
   Element_Type => Long_Float);
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
   Total_Cache_Read_Tokens    : Natural := 0;
   Total_Cache_Write_Tokens   : Natural := 0;
   Total_Thinking_Tokens        : Natural := 0;
   Total_Tool_Call_Input_Tokens  : Natural := 0;
   Total_Tool_Call_Result_Tokens : Natural := 0;
   Total_Uncached_Input_Tokens   : Natural := 0;
   --  JSD consecutive tool-call similarity.
   --  Per_Consecutive_Tool_S holds one Sᵢ value per eligible consecutive
   --  pair in session order.  N_Consecutive_Tool_Pairs = T−1 for a
   --  session with T non-empty tool calls (0 when T ≤ 1).
   Per_Consecutive_Tool_S  : Long_Float_Vectors.Vector;
   N_Consecutive_Tool_Pairs : Natural := 0;
   Total_Tool_Call_JSD_S    : Long_Float := 0.0;
   --  Sum of all Per_Consecutive_Tool_S values across every consecutive
   --  tool call pair in the session.  0.0 when N_Consecutive_Tool_Pairs = 0.
   --  Used as the scalar observation for I/MR/EWMA charts (§7.14a).
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
   Fraction_Thinking_Tokens_I,
   Fraction_Thinking_Tokens_MR,
   Fraction_Thinking_Tokens_EWMA,
   Fraction_Tool_Call_Tokens_I,
   Fraction_Tool_Call_Tokens_MR,
   Fraction_Tool_Call_Tokens_EWMA,
   Session_Input_Tokens_I,
   Session_Input_Tokens_MR,
   Session_Output_Tokens_I,
   Session_Output_Tokens_MR,
   Session_Cache_Read_Tokens_I,
   Session_Cache_Read_Tokens_MR,
   Session_Cache_Write_Tokens_I,
   Session_Cache_Write_Tokens_MR,
   --  Additional session-total I/MR chart pairs:
   Session_Thinking_Tokens_I,
   Session_Thinking_Tokens_MR,
   Session_Tool_Call_Tokens_I,
   Session_Tool_Call_Tokens_MR,
   Session_Tool_Call_Result_Tokens_I,
   Session_Tool_Call_Result_Tokens_MR,
   --  EWMA charts for session totals:
   Session_Input_Tokens_EWMA,
   Session_Output_Tokens_EWMA,
   Session_Cache_Read_Tokens_EWMA,
   Session_Cache_Write_Tokens_EWMA,
   Session_Thinking_Tokens_EWMA,
   Session_Tool_Call_Tokens_EWMA,
   Session_Tool_Call_Result_Tokens_EWMA,
   --  Session Turn Count I/MR/EWMA charts:
   Session_Turn_Count_I,
   Session_Turn_Count_MR,
   Session_Turn_Count_EWMA,
   --  Uncached Session Input Token I/MR/EWMA charts:
   Session_Uncached_Input_Tokens_I,
   Session_Uncached_Input_Tokens_MR,
   Session_Uncached_Input_Tokens_EWMA,
   --  Thinking tokens per tool-call token I/MR/EWMA rate charts:
   Fraction_Thinking_Per_Tool_Call_I,
   Fraction_Thinking_Per_Tool_Call_MR,
   Fraction_Thinking_Per_Tool_Call_EWMA,
   --  Uncached input tokens per total input token I/MR/EWMA rate charts:
   Fraction_Uncached_Input_I,
   Fraction_Uncached_Input_MR,
   Fraction_Uncached_Input_EWMA,
   --  Tool call consecutive diversity Xbar/s charts:
   Tool_Call_JSD_Xbar,
   Tool_Call_JSD_S,
   --  Session-level I/MR/EWMA charts for total consecutive tool-call
   --  similarity per session (sum of all Per_Consecutive_Tool_S values).
   Session_Tool_Call_JSD_Sum_I,
   Session_Tool_Call_JSD_Sum_MR,
   Session_Tool_Call_JSD_Sum_EWMA,
   --  Quantile Control Charts:
   Turn_Tokens_Quantile,
   Tool_Call_Tokens_Quantile,
   Thinking_Tokens_Quantile,
   Tool_Call_JSD_Quantile)

type Chart_Definition_Record is record
   Chart  : Chart_Kind;
end record;
```

`Chart_Definition_Record` is minimal by design: chart-level state that changes at
runtime (computed limits, filtered point sets) is held in `Coyote_SQC.Charts.Chart_State`,
not in the persistent workspace record.

### 6.7a Chart_Descriptor

A `Chart_Descriptor` fully specifies how to compute one chart kind at runtime.
It is a compile-time constant indexed by `Chart_Kind` that drives
`Recompute_Chart` without any chart-kind case dispatch beyond the initial
`Descriptor (Kind)` lookup.  Adding a new chart kind requires only:
(1) adding an enum value to `Chart_Kind`,
(2) registering a new `Chart_Descriptor` in the `Descriptor` function, and
optionally (3) adding a field to `Session_Metrics_Record` and updating
`Coyote_SQC.Metrics.Compute`.  No other package needs to change.

```ada

--  Per-session exclusion rules for parameter estimation and chart display.
type Exclusion_Kind is
  (No_Exclusion,            --  All sessions contribute
   Zero_Observation,        --  Exclude when the scalar observation = 0.0
   Zero_Output_Tokens,      --  Exclude when Total_Output_Tokens = 0
   Zero_Tool_Call_Tokens,   --  Exclude when Total_Tool_Call_Input_Tokens = 0
   Zero_Input_Tokens,       --  Exclude when Total_Input_Tokens = 0
   Zero_Thinking,           --  Exclude when Any_Thinking = False (Xbar/s)
   Zero_Tool_Call_Turns);   --  Exclude when N_Tool_Call_Turns_For_Chart = 0

--  Extracts a single Long_Float scalar observation from a
--  Session_Metrics_Record.  Returns Long_Float'First to signal that the
--  session must be excluded (e.g. zero denominator for a ratio chart).
type Metric_Accessor is access function
  (M : Coyote_SQC.Data_Model.Session_Metrics_Record) return Long_Float;

--  Extracts the per-turn subgroup vector from a Session_Metrics_Record.
--  Returns an empty vector for sessions excluded from the chart
--  (e.g. zero tool-call turns for tool-call token charts).
type Subgroup_Accessor is access function
  (M : Coyote_SQC.Data_Model.Session_Metrics_Record)
   return Coyote_SQC.Data_Model.Natural_Vectors.Vector;
--  Extracts a Long_Float subgroup vector from a Session_Metrics_Record.
--  Used for charts whose subgroup observations are natively Long_Float (JSD).
type LF_Subgroup_Accessor is access function
  (M : Coyote_SQC.Data_Model.Session_Metrics_Record) return
  Coyote_SQC.Data_Model.Long_Float_Vectors.Vector;

--  A self-contained runtime chart descriptor.  Recompute_Chart (Kind)
--  looks up the descriptor once via Descriptor (Kind) and then proceeds
--  without any further chart-kind case dispatch. Box-Cox config, estimation method, and EWMA params are read from Chart_Settings (Kind).
type Chart_Descriptor is record
   Kind           : Chart_Kind;
   Properties     : Chart_Properties;      --  label, group, axis label
   Get_Observation: Metric_Accessor;       --  scalar; null for Xbar/s charts
   Get_Subgroup   : Subgroup_Accessor;     --  per-turn vector; null otherwise
   LF_Get_Subgroup : LF_Subgroup_Accessor := null;
   --  When non-null, used in place of Get_Subgroup for charts whose
   --  subgroup values are Long_Float (e.g. JSD similarity charts).
   Exclusion_Rule : Exclusion_Kind;        --  when to skip a session
end record;

--  Return the self-contained descriptor for Kind.
function Descriptor (Kind : Chart_Kind) return Chart_Descriptor;
```

### 6.8 UUID_Sets

```ada
package UUID_Sets is new Ada.Containers.Hashed_Sets
  (Element_Type        => Ada.Strings.Unbounded.Unbounded_String,
   Hash                => Ada.Strings.Unbounded.Hash,
   Equivalent_Elements => Ada.Strings.Unbounded."=");

subtype UUID_Set is UUID_Sets.Set;
```

### 6.8a Box_Cox_Config

```ada
--  Box-Cox transformation configuration for a single chart.
--  Stored per-chart in Workspace_Record.Chart_Settings; see §6.8c.
type Box_Cox_Lambda_Source is (Auto, Robust_Auto, Fixed);

type Box_Cox_Config is record
   Enabled       : Boolean                := False;
   Lambda_Source : Box_Cox_Lambda_Source  := Auto;
   Fixed_Lambda  : Long_Float             := 0.0;
   --  Lambda_Source = Auto: lambda is estimated at runtime from the
   --  setup interval by MLE (profile log-likelihood); not persisted.
   --  Lambda_Source = Robust_Auto: lambda is estimated at runtime using
   --  the Qₙ robust scale estimator in place of the sample variance;
   --  50% breakdown point, 82% Gaussian efficiency; not persisted.
   --  Lambda_Source = Fixed: Fixed_Lambda is used directly.
   --  Common Fixed_Lambda values: 0.0 (ln), 0.5 (sqrt), 1.0 (identity).
end record;
```


### 6.8b Estimation_Method_Kind

```ada
--  Controls which statistical estimators are used when computing
--  center lines and process sigma for a single chart.  Stored
--  per-chart in Workspace_Record.Chart_Settings; see §6.8c.
--  Classical uses the arithmetic mean and pooled sample standard
--  deviation (traditional SPC).  Robust_Median uses the median
--  for location and resistant scale estimators (Q_n / 2.2219 for I chart
--  sigma; D4 × median(w_i) UCL for MR charts; Qₙ of pooled residuals for
--  Xbar/s charts).  p-charts always use the classical grand proportion
--  regardless of this setting.  See §7.13 for the full specification.
type Estimation_Method_Kind is (Classical, Robust_Median);
```

### 6.8c Chart_Settings_Record

Per-chart configuration stored in `Workspace_Record.Chart_Settings`.
Charts whose settings are entirely at default values need not appear
in the map; absent entries are treated as all-default.

```ada
--  Per-chart configuration: Box-Cox transformation, estimation method,
--  and (for EWMA charts) smoothing weight and sigma multiplier.
type Chart_Settings_Record is record
   Box_Cox           : Box_Cox_Config;
   Estimation_Method : Estimation_Method_Kind := Classical;
   --  EWMA_Weight and EWMA_L are consulted only for EWMA chart kinds;
   --  they are ignored for all other chart kinds.
   EWMA_Weight       : Long_Float := 0.2;
   EWMA_L            : Long_Float := 3.0;
end record;

--  Map from Chart_Kind to per-chart settings.
--  Ada.Containers.Ordered_Maps is used because Chart_Kind is an
--  enumeration type, making the implicit "<" ordering well-defined.
package Chart_Settings_Maps is new Ada.Containers.Ordered_Maps
  (Key_Type     => Coyote_SQC.Charts.Chart_Kind,
   Element_Type => Chart_Settings_Record);
```

The helper function:

```ada
--  Return the Chart_Settings_Record for Kind, falling back to the
--  all-default record when Kind is absent from the map.
function Chart_Settings
  (W    : Workspace_Record;
   Kind : Coyote_SQC.Charts.Chart_Kind) return Chart_Settings_Record;
```

is implemented in `Coyote_SQC.Workspace` as a one-liner:
`return (if W.Chart_Settings.Contains (Kind) then W.Chart_Settings (Kind) else (others => <>))`.

### 6.9 Workspace_Record

```ada
package String_Vectors is new Ada.Containers.Vectors
  (Index_Type   => Positive,
   Element_Type => Ada.Strings.Unbounded.Unbounded_String,
   "="          => Ada.Strings.Unbounded."=");

type Workspace_Record is record
   Workspace_Id       : Ada.Strings.Unbounded.Unbounded_String;
   Name               : Ada.Strings.Unbounded.Unbounded_String;
   Source_Directories : String_Vectors.Vector;
   Model_Filter       : String_Vectors.Vector;
   Setup_Session_Ids  : UUID_Set;
   Comments           : Comment_Vectors.Vector;
   --  Per-chart Box-Cox, estimation method, and EWMA parameter settings.
   --  Charts at default settings (Box-Cox disabled, Classical estimation,
   --  EWMA_Weight = 0.2, EWMA_L = 3.0) are omitted from the map to keep
   --  the workspace file compact.  See §6.8c for the record type.
   Chart_Settings     : Chart_Settings_Maps.Map;
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

For the **Session Token I/MR charts** (all eight I/MR chart pairs), the observation is the session-level scalar from `Session_Metrics_Record`: `Total_Input_Tokens`, `Total_Output_Tokens`, `Total_Cache_Read_Tokens`, `Total_Cache_Write_Tokens`, `Total_Thinking_Tokens`, `Total_Tool_Call_Input_Tokens`, `Total_Uncached_Input_Tokens`, or `Total_Tool_Call_Result_Tokens`, as appropriate for the chart kind. `Estimate_Parameters` computes:
- `Grand_Mean` : Long_Float -- mean of setup-interval session totals
- `Mean_MR`    : Long_Float -- mean moving range between consecutive setup sessions

The metrics vector is iterated in chronological session order (the sort order
guaranteed by `Reload_Sessions`). A setup interval of one session produces
`Mean_MR = 0.0` (no limits drawn).

For the **Session Turn Count I/MR/EWMA charts**, the observation is `N_Turns`
(from `Session_Metrics_Record`). `Estimate_Parameters` computes the same
`Grand_Mean` and `Mean_MR` fields using the same §5.6 formulas. The Turn Count
charts use their own per-chart `Box_Cox` configuration (§7.12)
See §7.12 and §6.8c.

`Estimate_Parameters` accepts an additional `Estimation_Method :
Estimation_Method_Kind` parameter (default `Classical`). When
`Robust_Median` is passed, the classical accumulators are replaced by
the resistant estimators specified in §7.13. The `Chart_Kind` routing
and exclusion rules (single-turn sessions, zero-thinking sessions, etc.)
are unchanged. The `Grand_P` estimator for p-charts is always the
classical grand proportion regardless of this parameter.

Each chart independently estimates its parameters from the setup interval
using its own `Get_Observation` or `Get_Subgroup` accessor and `Exclusion_Rule`
(§6.7a). No chart reads cached parameter values from another chart's
`Chart_Data` slot.  For families of charts sharing the same underlying metric
(e.g. `Session_Input_Tokens_I`, `Session_Input_Tokens_MR`, and
`Session_Input_Tokens_EWMA`), all three independently extract the same
observation series and arrive at identical estimates through deterministic
computation.

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


### 7.9 Box-Cox Transformation — `Coyote_SQC.Statistics.I_Chart`

The Box-Cox transformation and its inverse are applied to I/MR chart data when
the chart's `Box_Cox.Enabled` is `True` (from `Chart_Settings (Kind)`).

#### Transform and inverse

```ada
--  Apply the Box-Cox transform to a single positive observation.
--  Raises Constraint_Error if X <= 0.0.
--  For Lambda = 0.0 returns Ada.Numerics.Long_Elementary_Functions.Log (X).
--  For Lambda /= 0.0 returns (X ** Lambda - 1.0) / Lambda.
function Box_Cox (X : Long_Float; Lambda : Long_Float) return Long_Float;

--  Recover the original value from a transformed value Z.
--  For Lambda = 0.0 returns Ada.Numerics.Long_Elementary_Functions.Exp (Z).
--  For Lambda /= 0.0 returns (Z * Lambda + 1.0) ** (1.0 / Lambda).
function Box_Cox_Inverse (Z : Long_Float; Lambda : Long_Float) return Long_Float;
```

#### Lambda estimation

```ada
--  Compute the Qₙ scale estimate of a sample (Rousseeuw & Croux 1993).
--  Returns 2.2219 * d_{(h)}, where d_{(h)} is the h-th order statistic
--  of all C(N,2) pairwise |y_i − y_j| distances,
--  h = C(⌊N/2⌋+1, 2), and finite-sample correction factors from
--  Rousseeuw & Croux (1993) Table 1 are applied for N ≤ 9.
--  Requires Values'Length >= 2; raises Constraint_Error if N < 2.
function Qn_Scale (Values : Long_Float_Array) return Long_Float;

--  Estimate the Box-Cox lambda that maximises the profile log-likelihood
--  under the normality assumption (Source = Auto) or the robust profile
--  log-likelihood using the Qₙ scale estimator (Source = Robust_Auto).
--  Source = Fixed returns 0.0 immediately.
--  Requires Values'Length >= 3; returns 0.0 for fewer observations.
--  All values must be strictly positive; Constraint_Error if any ≤ 0.0.
--
--  Algorithm: coarse grid search over Lambda in [0.0, 30.0] at step 0.5
--  (21 evaluations) locates the global maximum basin; Brent's method
--  (Brent 1973) then refines within +-0.5 of the coarse best, clamped to
--  [0.0, 30.0], converging to tolerance 1.0e-6 on lambda.  Lambda is
--  restricted to [0.0, 30.0]: negative values are not meaningful for
--  positive token-count data and the UCL back-transform is always
--  well-defined for lambda >= 0.
function Estimate_Lambda
  (Values : Long_Float_Array;
   Source : Box_Cox_Lambda_Source := Auto) return Long_Float;
```

#### Transformed limit computation

When Box-Cox is active, `Recompute_Chart` in `Coyote_SQC.App`:

1. Transforms all setup-interval values: `Z_i = Box_Cox (X_i, Lambda)`.
2. Computes `Grand_Mean_Z` and `Mean_MR_Z` in the transformed space using
   the standard formulae from §7.5.
3. Calls `Compute_I_Limits` with `Grand_Mean_Z` and `Mean_MR_Z` to obtain
   limits in the **transformed** space.
4. For the **I chart**: back-transforms each limit value independently via
   `Box_Cox_Inverse` before storing in `Chart_State`.  The plotted points and
   limits are then all in original (token) units.  `CL_z` and `LCL_z` are
   always within the valid domain `(−∞, 1/|λ|)` since all data values mapped
   there.  `UCL_z` may reach or exceed the asymptote `1/|λ|` for negative λ
   (because `Box_Cox(x, λ) → 1/|λ|` as `x → +∞`), meaning no finite original
   value maps to `UCL_z`; in this case `Has_UCL` is set to `False` (the upper
   limit is effectively +∞) while `CL` and `LCL` are still drawn.  Each limit
   is back-transformed in its own exception scope so a domain failure on
   `UCL_z` does not suppress `CL` or `LCL`.
5. For the **MR chart**: each MR chart has its own independent Box-Cox
   transformation with a separately estimated `λ_MR`.  `Recompute_Chart`
   estimates `λ_MR` from the setup-interval `MR_i = |x_i − x_{i-1}|` series
   (excluding zero-valued entries, exactly as the I chart excludes zero-token
   sessions).  CL and UCL are computed in the transformed MR space
   (`w_i = Box_Cox(MR_i, λ_MR)`) and back-transformed exactly via
   `Box_Cox_Inverse(·, λ_MR)`.  Points plotted are the original-space
   `MR_i = |x_i − x_{i-1}|`; the y-axis label is in original (token) units.
   A status-bar notice counts zero MR values excluded from `λ_MR` estimation.

The resolved lambdas are stored per chart kind in `Chart_Data.Box_Cox_Lambda`:
each I chart stores `λ_I` (estimated from the session-total series) and each
MR chart stores `λ_MR` (estimated from the MR series); these are independent
values recomputed by `Recompute_Chart` whenever `Reload_Sessions` or a
setup-interval change occurs.

### 7.10 Box-Cox Transformation for Xbar/S Charts

When the chart's `Box_Cox.Enabled` is `True` (from `Chart_Settings (Kind)`), `Recompute_Chart` applies the
same `Box_Cox`, `Box_Cox_Inverse`, and `Estimate_Lambda` functions from
`Coyote_SQC.Statistics.I_Chart` to per-turn Xbar/S chart data.

**Per-pair lambda estimation (Auto and Robust_Auto modes):** for each chart
pair (Turn, Tool Call, Thinking, JSD), all setup-interval per-turn values for that
pair are collected and passed to `Estimate_Lambda` with `Source =
Chart_Settings (Kind).Box_Cox.Lambda_Source`. Lambda estimates are independent across
pairs. Fewer than three eligible values falls back to λ = 0.

**Fixed mode:** a single `Fixed_Lambda` from `Chart_Settings (Kind).Box_Cox` applies
to all four chart pairs.

**Transformed-space parameters:** the resulting λ is stored in
`Chart_Data.Box_Cox_Lambda`. `CD.Params.Grand_Mean` and `CD.Params.Pooled_S`
are then replaced with `Grand_Mean_Z` and `Pooled_S_Z` (weighted grand mean and
pooled standard deviation of the z-transformed per-turn values across setup
sessions), so the standard `Xbar.Compute_Limits` and `S_Chart.Compute_Limits`
formulas (§7.2, §7.3) operate entirely in z-space.

**Xbar chart:** for each session, the per-turn values are transformed and their
mean `z̄_i` is computed. `Box_Cox_Inverse(z̄_i, λ)` is stored as the chart point
value in original token units. The z-space limits from `Xbar.Compute_Limits` are
each back-transformed independently; domain failures set `Has_UCL = False` /
`Has_LCL = False` for that limit only.

**S chart:** the sample standard deviation of the z-transformed per-turn values,
`s_i_Z = StdDev(z_{i,j})`, is stored directly. Limits from `S_Chart.Compute_Limits`
are stored in z-space without back-transformation.

**Subgroup zero-value exclusion:** any subgroup value of 0 (token charts) or
≤ 0.0 (JSD charts) cannot be transformed.  Such values are excluded from λ
estimation.  Sessions containing any such value are excluded from Box-Cox
chart display and λ estimation; a status-bar notice reports the count of
excluded values.


### 7.14 Jensen-Shannon Divergence Similarity — `Coyote_SQC.Statistics.JSD`

The JSD-based consecutive tool-call similarity statistic quantifies how similar
each pair of adjacent tool calls is within a session.  A high value means the
two calls are nearly identical (potential looping); a low value means they are
compositionally different.

#### Tokenization

For a consecutive pair (call_i, call_{i+1}), argument fields are compared
**independently** rather than pooled into a single token sequence.  For each
key in the **union** of both calls' top-level JSON argument fields (plus a
synthetic `tool_name` key), a token sequence is produced as follows:

1. For the `tool_name` key: tokens are the whitespace-split, lowercased words
   of the tool name.
2. For each JSON argument key present in either call: parse the `Arguments`
   JSON object; extract all string-valued leaf content for that key
   (recursively for nested objects and arrays); whitespace-split and lowercase.
3. A key absent from one call is treated as having an empty token sequence
   (zero tokens) on that side.

A call with no string-valued arguments contributes only the `tool_name`
comparison; this is identical in treatment to a call where every argument key
is absent — no special boundary exclusion applies.

#### Per-Argument Similarity (S_k)

For each key _k_ in the union of both calls' argument sets (including
`tool_name`), with token frequency vectors f^(1)_k and f^(2)_k:

```
n₁_k = token count for key k in call_i
n₂_k = token count for key k in call_{i+1}
N_k  = n₁_k + n₂_k
```

- **N_k = 0** (key has no string content in either call): no observation is
  produced; the key is skipped entirely.
- **Exactly one side zero** (key present in one call but absent or empty in
  the other): S_k = 0.0 is appended to the subgroup vector.
- **Both sides non-zero**: S_k is computed via the full JSD formula:

```
π^(1)_k = n₁_k/N_k,   π^(2)_k = n₂_k/N_k   (length-proportional weights)
k_eff_k = |vocab_k(call_i) ∪ vocab_k(call_{i+1})|

D_k    = H[π^(1)_k·f^(1)_k + π^(2)_k·f^(2)_k]
         − π^(1)_k·H[f^(1)_k] − π^(2)_k·H[f^(2)_k]
D_bc_k = D_k − (k_eff_k − 1) / (2·N_k·ln2)   (bias-corrected divergence)
S_k    = N_k·(1 − D_bc_k) = N_k·(1 − D_k) + (k_eff_k − 1)/(2·ln2)
```

where H[p] = −Σᵢ pᵢ·log₂(pᵢ) is the Shannon entropy (base-2, bits).

Each S_k satisfies σ²(S_k) = O(1) independent of N_k (Grosse et al., 2002,
§IV.B), because length-proportional weights are used within each per-argument
comparison.  Comparing arguments independently preserves this O(1) variance
property for every individual observation; pooling all argument tokens into a
single value per pair would inflate variance to O(K) where K is the number of
keys, invalidating the poolability justification for the Xbar/s chart.

**Interpretation:** S_k ≈ N_k means the argument value is identical in both
calls; S_k ≈ 0 means the two values are maximally different on that argument.

#### Subgroup

For a consecutive pair (call_i, call_{i+1}), all computed S_k values are
appended in order (`tool_name` first, then JSON argument keys in source order)
to the session's `Per_Consecutive_Tool_S` vector.

For a session with T non-empty tool calls, the subgroup vector
`Per_Consecutive_Tool_S` has length n = Σᵢ Kᵢ, where Kᵢ is the number of
non-skipped keys for pair i.  `N_Consecutive_Tool_Pairs` = T − 1.

**Exclusion rules:**
- Sessions with T ≤ 1 non-empty tool calls (n = 0): excluded entirely from
  both charts; no marker plotted.
- Sessions with subgroup size n = 1 (single per-argument observation): plotted
  as a hollow circle on the Xbar chart; no s marker (same convention as
  single-turn sessions on existing s charts).

Box-Cox transformation may optionally be applied to the `Tool_Call_JSD_Xbar`
and `Tool_Call_JSD_S` chart pair (see §7.10).  The O(1) variance property
means transformation is not required, but it remains available for workspaces
where the S_k distribution is substantially skewed.

#### Ada Package

```ada
with Coyote_SQC.Data_Model;

package Coyote_SQC.Statistics.JSD is

   --  Compute per-argument JSD similarity values for a consecutive tool call
   --  pair and append them to Result.
   --
   --  One S_k value is appended for each key in the union of:
   --    - a synthetic "tool_name" key (always processed; tool name tokens)
   --    - every top-level JSON argument key in Arguments_1 or Arguments_2
   --
   --  Keys with N_k = 0 (no string content on either side) are skipped.
   --  Keys present in one call but absent (or non-string) in the other
   --  contribute S_k = 0.0.  σ²(S_k) = O(1) for every appended value
   --  (Grosse et al. 2002, §IV.B), preserving Xbar/s poolability.
   --
   --  Result is not cleared before appending; the caller is responsible
   --  for initialising it.
   procedure Compute_S_Values
     (Tool_Name_1 : String;
      Arguments_1 : String;
      Tool_Name_2 : String;
      Arguments_2 : String;
      Result      : in out Coyote_SQC.Data_Model.Long_Float_Vectors.Vector);

   --  Return the total token count for a single tool call: prepend tool name,
   --  extract all JSON string values from the whole Arguments blob,
   --  whitespace-split, lowercase.  Exposed for unit testing.
   function Token_Count
     (Tool_Name : String;
      Arguments : String) return Natural;

end Coyote_SQC.Statistics.JSD;
```

### 7.14a Session Total JSD Similarity Scalar

`Total_Tool_Call_JSD_S` is the session-level sum of all per-argument JSD
similarity values computed by `Coyote_SQC.Statistics.JSD.Compute_S_Values`
across every consecutive tool call pair in the session:

```
Total_Tool_Call_JSD_S = Σ{ S_k : k ∈ Per_Consecutive_Tool_S }
```

Computed by `Coyote_SQC.Metrics.Compute` after the JSD loop that populates
`Per_Consecutive_Tool_S`.

**I/MR/EWMA chart kinds:** `Session_Tool_Call_JSD_Sum_I`,
`Session_Tool_Call_JSD_Sum_MR`, and `Session_Tool_Call_JSD_Sum_EWMA` use this
scalar as their observation.  Exclusion, limit formulas, and EWMA recursion
follow §7.8 and §7.11 exactly.  Box-Cox transformation is not applied; the
S_k values have O(1) variance by construction (Grosse et al. 2002, §IV.B),
so transformation provides no normality benefit here.

**Descriptor:** `Get_Observation = Obs_Tool_JSD_Sum`, `Box-Cox transformation is not applied (see §5.13)`,
`Exclusion_Rule = Zero_Tool_Call_Turns` (sessions with `N_Consecutive_Tool_Pairs = 0`
are excluded).
### 7.15 Kolmogorov-Smirnov Goodness-of-Fit Tests — `Coyote_SQC.Statistics.Tests`

Two one-sample KS tests are computed for the contributing selected sessions in
the multi-select detail panel (§11.6).

#### 7.15.1 KS Normality Test — `KS_Normality_P_Value`

Null hypothesis: the sample is drawn from Normal(μ, σ) with parameters
estimated from the data.

1. Sort the N values x₁ ≤ … ≤ xₙ.
2. Estimate μ̂ = mean(xᵢ), σ̂ = sample standard deviation.
3. D = max_i max(|i/N − Φ((xᵢ−μ̂)/σ̂)|, |(i−1)/N − Φ((xᵢ−μ̂)/σ̂)|).
4. p-value = Q(D√N), where Q(z) = 2 Σ_{k=1}^∞ (−1)^{k−1} exp(−2k²z²)
   (Kolmogorov distribution complement; series capped at 50 terms; Q(z)=1
   for z ≤ 0.27).

The normal CDF Φ is approximated via the Abramowitz & Stegun rational
approximation 7.1.26 (max |error| < 1.5×10⁻⁷).

Returns −1.0 (displayed as `"N/A"`) when N < 3 or σ̂ = 0.

#### 7.15.2 KS Exponential Test — `KS_Exponential_P_Value`

Null hypothesis: the sample is drawn from Exponential(λ) with
λ̂ = 1/mean(xᵢ) estimated from the data.

Same algorithm as §7.15.1, substituting the exponential CDF
F(x) = 1 − exp(−λ̂x) for Φ.

Returns −1.0 when N < 3 or mean ≤ 0.

### 7.16 Wald-Wolfowitz Runs Test — `Coyote_SQC.Statistics.Tests.Runs_Test_P_Value`

Tests whether the contributing sessions' statistics, in **chronological
order**, form an independent sequence.

1. Compute median M of all N values.
2. Scan in chronological order; assign each value to `above` (> M) or
   `below` (< M); skip ties (= M).
3. Count: n₁ = above, n₂ = below, R = number of maximal same-group runs.
4. Under independence:  
   E[R] = 2n₁n₂/(n₁+n₂) + 1  
   Var[R] = 2n₁n₂(2n₁n₂−n₁−n₂) / ((n₁+n₂)²(n₁+n₂−1))
5. Z = (R − E[R]) / √Var[R]; two-sided p = 2·Φ(−|Z|).

Returns −1.0 when N < 10, n₁ = 0, n₂ = 0, or Var[R] ≤ 0.


### 7.17 Hartigan Dip Test for Unimodality — `Coyote_SQC.Statistics.Tests.Dip_Test_P_Value`

Tests whether the contributing sessions' statistics are consistent with a
unimodal distribution.  A multimodal distribution (e.g. two distinct process
regimes) produces a larger dip statistic than unimodal data.

**Algorithm.** Given a sorted sample x₁ ≤ … ≤ xₙ:

1. Compute the dip statistic D_N using Hartigan's Algorithm AS 217:
   - Precompute the greatest convex minorant (GCM) predecessor chain `mn[j]`
     and the least concave majorant (LCM) successor chain `mj[k]` in O(N)
     passes over the sorted data.
   - Iterate over the modal interval [low, high], collecting GCM and LCM
     change points, computing the maximum vertical gap d between the two
     curves, and refining [low, high] until convergence (Maechler 1994
     termination fix prevents infinite loops on unimodal data).
   - The dip is the maximum deviation of the ECDF from its best-fitting
     unimodal CDF, divided by 2N.  All intermediate values are maintained
     in 2N units; the final division by 2N produces the reported statistic.

2. Estimate the p-value by Monte Carlo simulation (`K = 2 000` replicates):
   - Draw K independent samples of size N from Uniform[0, 1].  The uniform
     distribution maximises the expected dip among all unimodal CDFs
     (Hartigan & Hartigan 1985), so it is the correct null distribution.
   - Sort each sample and compute its dip statistic.
   - p-value = fraction of simulated dips ≥ D_N.
   - A fixed seed (12 345) is used for reproducibility: the same selection
     always shows the same p-value.

Returns −1.0 when N < 4.

**Interpretation.** A small p-value (e.g. < 0.05) is evidence of
multimodality — the dip is larger than expected for unimodal data.  In an
SQC context this suggests the chart metric may have two distinct process
regimes (e.g. short and long sessions) rather than one stable mode.

**Reference.** Hartigan, J.A. and Hartigan, P.M. (1985), "The Dip Test of
Unimodality", _Ann. Statist._ **13**: 70–84.  C implementation by
M. Maechler (ETH Zürich), in R package `diptest` (CRAN).

package Coyote_SQC.Statistics.Tests is

```ada
--  Hartigan dip test for unimodality.
--  Returns -1.0 when Values'Length < 4.
function Dip_Test_P_Value
  (Values : Long_Float_Array;
   K      : Positive := 2_000) return Long_Float;
```


### 7.18 Bootstrap Confidence Intervals — `Coyote_SQC.Statistics.Bootstrap`

Implements the percentile bootstrap for the three two-set comparison statistics
specified in SRS-SQC §5.17.  B = 10 000 resamples; fixed random seed 12 345
(Ada `Ada.Numerics.Discrete_Random`); 95% confidence interval (2.5th and 97.5th
percentiles of the bootstrap distribution).

```ada
package Coyote_SQC.Statistics.Bootstrap is

   type CI_Result is record
      Point_Estimate : Long_Float;
      Lower          : Long_Float;
      Upper          : Long_Float;
      Valid          : Boolean := False;
      --  Valid = False when N < 2 in either set, or when SD(A) = 0 for
      --  the ratio statistic, or when >50% of ratio replicates are
      --  undefined (SD(A*) = 0).  Point_Estimate, Lower, Upper are
      --  undefined when Valid = False; display as "N/A".
   end record;

   type Three_CI_Results is record
      Mean_Diff   : CI_Result;
      Median_Diff : CI_Result;
      SD_Ratio    : CI_Result;
   end record;

   --  Compute all three bootstrap CIs for the comparison Set_B − Set_A
   --  (mean and median differences) and Set_B / Set_A (SD ratio).
   --  Set_A and Set_B are heap-backed vectors (Data_Model.Long_Float_Vectors) of contributing session statistics;
   --  caller has already applied active-chart exclusion rules.
   --  Returns Valid = False for any statistic where fewer than 2
   --  observations are available in the relevant set.
   function Compute
     (Set_A : Coyote_SQC.Data_Model.Long_Float_Vectors.Vector;
      Set_B : Coyote_SQC.Data_Model.Long_Float_Vectors.Vector;
      B     : Positive := 10_000;
      Seed  : Integer  := 12_345) return Three_CI_Results;

end Coyote_SQC.Statistics.Bootstrap;

### 7.19 Quantile Control Chart — `Coyote_SQC.Statistics.Quantile_CC`

The Quantile Control Chart computes per-component bootstrap control limits
for the minimum, first quartile, median, third quartile, and maximum of
per-turn observations within each session, using a two-stage bootstrap
resampling procedure.

#### Two-Stage Bootstrap Procedure

```ada
with Ada.Containers.Vectors;
with Coyote_SQC.Data_Model;

package Coyote_SQC.Statistics.Quantile_CC is

   --  Number of bootstrap replicates.
   B_Replicates : constant Positive := 10_000;

   --  Fixed seed for reproducible bootstrap results.
   Bootstrap_Seed : constant Integer := 54_321;

   --  Bonferroni-adjusted alpha for 5 simultaneous comparisons.
   --  α = 0.0027 (3-sigma), α_B = α / 5 = 0.00054.
   --  Two-sided tail probability: α_B / 2 = 0.00027.
   --  r = max(1, floor(0.00027 * B_Replicates)), computed at
   --  elaboration from B_Replicates.
   Bonferroni_Rank : constant Natural :=
     Natural'Max (1, Natural (Long_Float'Floor
       (0.00027 * Long_Float (B_Replicates))));
   --  LCL_j = b_{(r)}, UCL_j = b_{(B - r + 1)},
   --  CL_j  = b_{(B / 2)} (median of the bootstrap distribution).

   --  The five quantile statistics computed from a subgroup sample.
   type Quantile_Index is (Min_Q, Q1, Median_Q, Q3, Max_Q);

   type Quantile_Array is array (Quantile_Index) of Long_Float;

   --  Bootstrap distribution for a single unique n_i.
   package Long_Float_Vecs is new Ada.Containers.Vectors (Natural, Long_Float);

   type Bootstrap_Distribution is array (Quantile_Index) of
     Long_Float_Vecs.Vector;

   --  Compute the five quantile statistics from a single subgroup sample
   --  of size n using linear interpolation (R type 7 default).
   --  Position p(k) = (n − 1) * (k − 1) / 4 for k = 1…5.
   --  Raises Constraint_Error if n < 1 or Values'Length < n.
   function Compute_Quantiles
     (Values : Long_Float_Array;
      N      : Natural) return Quantile_Array;

   --  Build the bootstrap distribution for a given subgroup size n_i.
   --  Pool_Values is the flattened vector of all setup-interval subgroup
   --  values, grouped by session: Pool_Offsets(I) is the 0-based start
   --  index of session I's subgroup in Pool_Values;
   --  Pool_Lengths(I) is the subgroup size of session I.
   --  Sessions with a zero-length subgroup are excluded by the caller.
   --  Returns a Bootstrap_Distribution containing B_Replicates values
   --  for each of the five quantile statistics, sorted ascending.
   function Build_Distribution
     (Pool_Values  : Long_Float_Array;
      Pool_Offsets : Coyote_SQC.Data_Model.Natural_Vectors.Vector;
      Pool_Lengths : Coyote_SQC.Data_Model.Natural_Vectors.Vector;
      N_I          : Positive;
      Seed         : Integer := Bootstrap_Seed)
     return Bootstrap_Distribution;
   --  The effective seed is Seed + N_I, so each subgroup size
   --  gets an independent bootstrap stream while remaining
   --  reproducible.

   --  Extract control limits and center line for each of the five
   --  quantile statistics from a precomputed bootstrap distribution.
   --  Uses the Bonferroni-adjusted tail rank Bonferroni_Rank.
   function Extract_Limits
     (Dist : Bootstrap_Distribution) return Quantile_Limits_Array;

   type Quantile_Limits_Record is record
      UCL      : Long_Float;
      CL       : Long_Float;
      LCL      : Long_Float;
      Has_UCL  : Boolean := True;
      Has_LCL  : Boolean := True;
   end record;

   type Quantile_Limits_Array is array (Quantile_Index) of
     Quantile_Limits_Record;

   --  Determine whether a component is out-of-control.
   --  Returns True when Value strictly exceeds UCL or is strictly below LCL.
   function Is_OOC
     (Value    : Long_Float;
      Limits   : Quantile_Limits_Record) return Boolean;

   --  Determine whether a session is out-of-control on a Quantile CC.
   --  Returns True when any component is out-of-control.
   function Session_Is_OOC
     (Values : Quantile_Array;
      Limits : Quantile_Limits_Array) return Boolean;

   --  Return the set of components that are out-of-control.
   --  Empty set when all components are in-control.
   function OOC_Components
     (Values : Quantile_Array;
      Limits : Quantile_Limits_Array) return Quantile_Component_Set;

   type Quantile_Component_Set is array (Quantile_Index) of Boolean
     with Default_Component_Value => False;

   --  Cache: maps subgroup size n_i → Bootstrap_Distribution.
   --  Distributions are lazily computed on first access and reused.
   --  The cache is cleared when the setup interval or session data changes.

end Coyote_SQC.Statistics.Quantile_CC;
```

#### Caching Strategy

A per-chart `Cache_Map` (keyed by `Natural`, the subgroup size `n_i`) stores
precomputed `Bootstrap_Distribution` objects.  The cache is:

- **Populated lazily:** the first `Chart_Point` for a given `n_i` triggers
  distribution computation.
- **Reused:** subsequent sessions with the same `n_i` reuse the cached
  distribution without recomputation.
- **Cleared:** when the setup interval changes or sessions are reloaded,
  all per-chart caches are emptied so that distributions reflect the new
  reference pool.

Because the bootstrap is `O(B · n_i)` per distribution and B_Replicates,
precomputing once per unique `n_i` ensures interactive performance even
for workspaces with thousands of sessions (typical workspaces have fewer
than 100 distinct subgroup sizes).


#### Interpolated Limits

The package provides `Interpolate_Limits` as an alternative to the full
bootstrap for every subgroup size.  When the workspace option
`Interpolate_Quantile_Limits` is enabled, limits are derived by computing
exact bootstrap distributions at a small set of anchor subgroup sizes and
scaling half-widths by `√(n_a / n)` for non-anchor sizes.

**Constants:**
- `Interp_Delta = 0.15` — tolerance for relative half-width error from
  `O(1/n)` bias.
- `Interp_C = 0.5` — quantile finite-sample bias constant.
- `Interp_Discrete_Max = 16` — smallest `n` where `1/√n` scaling is
  reliable (padded beyond `⌈(C/δ)²⌉` for discrete-index safety).

**Anchor algorithm.** Anchors are every integer 2 .. `Discrete_Max`,
then uniformly in `x = 1/√n` space with spacing `Δx = δ/√(Discrete_Max)`,
grown lazily by `Ensure_Anchors_Up_To(N)`.  The anchor vector is a
body-level variable shared across all chart kinds.

**Interpolation.** For `n ≥ 2`:
1. Ensure anchors up to `n`.
2. Find the nearest lower anchor `n_a ≤ n`.
3. Compute exact limits at `n_a` via `Get_Distribution` + `Extract_Limits`.
4. If `n = n_a`, return exact limits.
5. Otherwise scale half-widths: `HW(n) = HW(n_a) × √(n_a/n)` with CL
   taken unchanged from the anchor.

For `n = 1` (degenerate), exact bootstrap is used.

**Error bound.** The relative error in any half-width from the `O(1/n)`
bias term is bounded by `Interp_Delta² ≈ 2.25%` across the continuous
regime, which is well below the Monte Carlo noise of `B_Replicates = 10 000`.

```ada
   function Interpolate_Limits
     (Cache        : in out Quantile_CC_Cache;
      Pool_Values  : Long_Float_Array;
      Pool_Offsets : Coyote_SQC.Data_Model.Natural_Vectors.Vector;
      Pool_Lengths : Coyote_SQC.Data_Model.Natural_Vectors.Vector;
      N_I          : Positive;
      Seed         : Integer := Bootstrap_Seed)
     return Quantile_Limits_Array;
```

#### Chart Descriptor Extensions

For Quantile CC chart kinds, the `Chart_Descriptor` fields are:

- `Get_Subgroup` / `LF_Get_Subgroup`: extracts the per-turn subgroup vector
  for each session (used to populate the reference pool and compute per-session
  quantiles).
- `Get_Observation`: null (Quantile CC does not use scalar observations).
- `Exclusion_Rule`: depends on chart kind — `Zero_Thinking` for Thinking
  Tokens Quantile; `Zero_Tool_Call_Turns` for Tool Call Tokens Quantile and
  Tool Call JSD Quantile; `No_Exclusion` for Turn Tokens Quantile.
- Box-Cox, estimation method, and EWMA parameters in `Chart_Settings` are
  not consulted for Quantile CC chart kinds.

#### OOC Propagation

When `Session_Is_OOC` returns `True` for a session on a Quantile CC, the
session's marker on **all other charts** (Xbar, s, I, MR, EWMA, p) is
recolored according to the existing out-of-control rules: red if no
comment, orange if a comment is present.  This ensures that an anomaly
detected on one chart is immediately visible when browsing other metrics.

```

**Implementation notes:**

- `Ada.Numerics.Discrete_Random` is instantiated with `Integer` and seeded with
  `Seed` before the resample loop; the generator is local to each `Compute` call
  so the fixed seed guarantees reproducible output regardless of call order.
- For the SD ratio: bootstrap replicates where `StdDev(A*) = 0` are discarded.
  If more than 50% of replicates are discarded, `SD_Ratio.Valid := False`.
- All storage in `Bootstrap.Compute` is heap-backed: input parameters
  `Set_A` / `Set_B` use `Coyote_SQC.Data_Model.Long_Float_Vectors.Vector`;
  resample vectors `A_Star` / `B_Star` are pre-filled `LF_Vectors.Vector`
  objects overwritten in-place each iteration via `Replace_Element`; replicate
  accumulation vectors `Mean_Boot`, `Med_Boot`, `SD_Boot` and sorted-copy
  vectors `Set_A_Sorted`, `Set_B_Sorted` are likewise heap-backed.  This
  eliminates all dynamic stack pressure on the GTK callback thread regardless
  of session count (PCR-017).  `Coyote_SQC.Statistics.Tests` applies the same
  principle: `Sorted_V` / `Sim_V` in `Dip_Test_P_Value` and `KS_*` /
  `Runs_Test_P_Value` use `LF_Vectors.Vector`; the four working arrays
  (`Mn`, `Mj`, `Gcm`, `Lcm`) in `Compute_Dip` use `Int_Vectors.Vector`
  (an `Ada.Containers.Vectors (Positive, Integer)` instantiation).

## 8. Chart Definitions

### 7.11 EWMA Chart — `Coyote_SQC.Statistics.EWMA_Chart`

An Exponentially Weighted Moving Average (EWMA) chart provides a sensitive monitor
for small, sustained shifts in a session-level total that a standard I chart would
miss.  One EWMA chart corresponds to each of the eight Session Token I charts and the Session Turn Count I chart:
input tokens, output tokens, cache-read tokens, cache-write tokens,
thinking tokens, tool-call input tokens, and tool-call result tokens.

The EWMA statistic at step _t_ (where _t_ counts only non-excluded sessions) is:

```
Z_t = λ · x_t + (1 − λ) · Z_{t−1},   Z_0 = Grand_Mean
```

where `x_t` is the session observation, `λ` is the smoothing weight (`EWMA_Weight`
in `Workspace_Record`, default 0.2), and `Z_0` is the process target (Grand_Mean
computed from this chart kind's own setup-interval observations).

The time-varying control limits at step _t_ are:

```
UCL_t / LCL_t = Grand_Mean ± L · σ · √( λ/(2−λ) · [1 − (1−λ)^{2t}] )
```

where `σ = Mean_MR / d2` (`d2 = 1.128`, the span-2 moving range constant) and `L` is
the sigma multiplier (`EWMA_L` in `Workspace_Record`, default 3.0).

As _t_ → ∞ the limits converge to the steady-state values:

```
Grand_Mean ± L · σ · √( λ / (2 − λ) )
```

Each EWMA chart independently extracts its setup-interval observation series and
computes `Grand_Mean` and `Mean_MR` from first principles using the same formulas
(§7.5).  For a given session metric, the corresponding I and EWMA chart kinds share
the same `Get_Observation` accessor and `Exclusion_Rule`, so their parameter
estimates are always identical.  `Recompute_Chart` for an EWMA chart kind does not
read from any other chart's `Chart_Data` slot.

#### Exclusion rule

When Box-Cox is **not** active, all sessions are included in the EWMA sequence.
When Box-Cox **is** active, any session whose raw token total is zero cannot be
transformed; such sessions are excluded and the step counter _T_ is **not**
advanced.  The sequence resumes with the next eligible session.

#### Box-Cox behaviour (Option B)

When the chart's `Box_Cox.Enabled` is `True` (from `Chart_Settings (Kind)`), the EWMA recursion operates
in z-space (transformed values) so that the control limits are symmetric in
transformed units.  The final plotted value and each limit are then individually
back-transformed to original (token) units for display, matching the back-transform
treatment applied to I chart points and limits.

Concretely, for each eligible session:

1. Compute `z_t = Box_Cox(x_t, λ_BC)`.
2. Advance: `Z_t = λ · z_t + (1 − λ) · Z_{t−1}`, `Z_0 = Grand_Mean_Z`.
3. Compute time-varying limits in z-space.
4. Back-transform `Z_t` and each limit independently:
   - If back-transform of the plotted value `Z_t` fails (domain violation),
     the session is excluded from the EWMA chart.
   - If back-transform of `UCL_z` fails, `Has_UCL` is set to `False` while
     `CL` and `LCL` are still plotted.
   - `LCL` is clamped to 0.0 in original-unit space; `Has_LCL` is `False`
     when the formula yields a non-positive value.

The EWMA chart y-axis label is in original (token) units regardless of whether
Box-Cox is active.

#### Implementation

```ada
package Coyote_SQC.Statistics.EWMA_Chart is

   --  Compute one EWMA step.  Z_Prev is Z_{t-1}; pass Grand_Mean as Z_Prev
   --  for the first step (Z_0 = Grand_Mean).  Weight must be in (0.0, 1.0].
   function Compute_Z
     (X      : Long_Float;
      Z_Prev : Long_Float;
      Weight : Long_Float) return Long_Float;

   --  Compute time-varying EWMA control limits at step T (1-based).
   --  Sigma = Mean_MR / d2 (the caller computes the division).
   --  When Sigma = 0.0, Has_UCL and Has_LCL are both False.
   --  LCL is clamped to 0.0; Has_LCL = False when the formula yields LCL ≤ 0.
   function Compute_EWMA_Limits
     (Grand_Mean : Long_Float;
      Sigma      : Long_Float;
      Weight     : Long_Float;
      L          : Long_Float;
      T          : Positive) return Limits_Record;

end Coyote_SQC.Statistics.EWMA_Chart;

### 7.12 Box-Cox Transformation for Turn Count I/MR/EWMA Charts

When the chart's `Box_Cox.Enabled` is `True` (from `Chart_Settings (Kind)`), `Recompute_Chart` applies
the same `Box_Cox`, `Box_Cox_Inverse`, and `Estimate_Lambda` functions from
`Coyote_SQC.Statistics.I_Chart` to Turn Count I/MR/EWMA chart data, using the
the chart's own per-chart `Box_Cox` configuration (`Chart_Settings (Kind).Box_Cox`).

**No zero-value exclusion.** `N_Turns` is always ≥ 1, so no session is ever
excluded from the Turn Count charts on the grounds of a zero value.  The
transformed value for a session with `N_Turns = 1` is 0.0 for all λ (since
`Box_Cox(1.0, λ) = 0` for λ ≠ 0 and `ln(1.0) = 0` for λ = 0).  If all setup
sessions have `N_Turns = 1` the transformed values are all 0.0, `Mean_MR_Z = 0.0`,
and the MR̄ = 0 special case (§7.8) applies: no limits are drawn.

**Lambda estimation.** `Estimate_Lambda` is called with the setup-interval
`N_Turns` values as `Long_Float`, passing `Source = Chart_Settings (Kind).Box_Cox.Lambda_Source`.
Fewer than three setup sessions falls back to λ = 0.

**I chart display.** Limits are back-transformed to original (turn count) units.
`UCL_z` domain failure sets `Has_UCL = False`; `CL` and `LCL` are still drawn.

**MR chart display.** Moving range values are the original-space absolute
differences `MR_i = |N_i − N_{i-1}|`, plotted without transformation. The
Turn Count MR chart has its own independent Box-Cox transformation with a
separately estimated `λ_MR` from the setup-interval `MR_i` series; CL and UCL
are back-transformed exactly to original (turn count) units via
`Box_Cox_Inverse(·, λ_MR)`.

**EWMA chart display.** The EWMA recursion runs in z-space; the plotted value and
limits are individually back-transformed to original (turn count) units, following
the same Option B logic as §7.9.

The resolved lambda is stored in `Chart_Data.Box_Cox_Lambda` for each of the three
Turn Count chart kinds and is recomputed by `Recompute_Chart` on setup-interval
change or session reload.


### 7.13 Robust Control Limit Estimation

When `Chart_Settings (Kind).Estimation_Method = Robust_Median`, `Estimate_Parameters`
uses resistant estimators in place of the classical arithmetic ones for
I/MR and Xbar/s charts.  p-charts are unaffected.

#### Helper functions

```ada
--  Return the median of a Long_Float array.
--  For even N, returns the mean of the two middle values.
--  Returns 0.0 for an empty array.
function Median_Of (Values : Long_Float_Array) return Long_Float;
```

`Qn_Scale` (already declared in §7.9 for Box-Cox lambda estimation) is
reused here without modification.

#### I/MR charts (replaces §7.5 classical accumulators)

- **Center line (Grand_Mean):** `Median_Of` applied to the N
  setup-interval observations.  Has a 50% breakdown point; the
  arithmetic mean breaks down at 1/N.

- **I chart scale (σ):** `Qn_Scale` applied to the N setup-interval
  observations (or their Box-Cox transforms `z_i` when Box-Cox is active),
  divided by 2.2219.  `Qn_Scale` is already implemented for robust Box-Cox
  lambda estimation (§7.9).  This replaces `Median_Of(MR_values) / d₄`; the
  classical motivation for MR-based sigma (consistency with the paired MR
  chart) no longer applies since the I and MR charts now use independent
  Box-Cox transformations and sigma estimates.

  `Compute_I_Limits` gains a `Sigma : Long_Float` parameter replacing the
  previous `Mean_MR` parameter; the caller passes the pre-computed σ
  regardless of whether it came from MR or Q_n.  The `Robust : Boolean`
  divisor-selection parameter is removed.

- **MR chart UCL:** `D4 × Median_Of(w_i)` replaces `D4 × Mean_Of(w_i)` in
  robust mode, where `w_i = Box_Cox(MR_i, λ_MR)` are the transformed MR
  values.  `Has_UCL = False` when `Median_Of(w_i) = 0.0`.

- **EWMA charts** inherit the robust values automatically: `Z_0 =
  Grand_Mean (robust)` and `σ = Qn_Scale(z_i) / 2.2219` from the paired I
  chart.  No additional logic is required in the EWMA recursion.

#### Xbar/s charts (replaces §7.5 classical accumulators)

- **Grand_Mean:** unweighted median of the per-session means x̄_i
  (one per eligible setup session).  Replaces the size-weighted
  arithmetic grand mean.  An outlier session with an extreme token
  distribution cannot shift this estimate by more than a finite amount
  regardless of its magnitude.

- **Pooled_S:** `Qn_Scale` applied to the vector of pooled within-session
  residuals `x_{i,j} − x̄_i` (deviation of each per-turn value from
  its session's own arithmetic mean), collected across all eligible
  setup sessions.  The Qₙ consistency constant 2.2219 is calibrated for
  normally distributed inputs; within-session residuals are approximately
  normal, so this is appropriate.  `Qn_Scale` has 82% Gaussian efficiency
  (vs. MAD's 36.7%) and is already implemented for Box-Cox lambda
  estimation (§7.9), so no new algorithm is required.

  `Pooled_S` replaces the classical pooled standard deviation in the Xbar
  and s chart limit formulas (§7.2, §7.3).  The c4 bias correction applied
  per-point is unchanged.

  If the pooled residual vector has fewer than 2 elements, `Pooled_S` is
  set to 0.0 and no limits are drawn.

#### Interaction with Box-Cox

The estimation method is orthogonal to Box-Cox transformation.  When both
are active, the robust estimators operate on the *transformed* values
produced by the Box-Cox step (as for the classical estimators), so the
choice of estimation method does not affect the Box-Cox path.


```


`Coyote_SQC.Charts` declares the `Chart_Kind` enumeration (§6.7) and a
`Chart_Properties` record providing display metadata:

```ada
type Chart_Properties is record
   Label       : Ada.Strings.Unbounded.Unbounded_String;
   Group_Path  : Ada.Strings.Unbounded.Unbounded_String;
   Y_Axis_Label: Ada.Strings.Unbounded.Unbounded_String;
   Is_P_Chart  : Boolean;
   Is_I_Chart      : Boolean;
   Is_Xbar_S_Chart : Boolean;
   Is_EWMA_Chart   : Boolean;
   Is_MR_Chart        : Boolean;
   Is_Quantile_CC_Chart : Boolean;
end record;

function Properties (Kind : Chart_Kind) return Chart_Properties;
```

The fifty-five charts and their properties:

| `Chart_Kind` | Label | Group_Path | Y-Axis Label |
|---|---|---|---|
| `Turn_Tokens_Xbar` | `Turn Tokens -- Xbar` | `Token Consumption/Turn Tokens` | `Mean output tokens/turn` |
| `Turn_Tokens_S` | `Turn Tokens -- s` | `Token Consumption/Turn Tokens` | `Std dev output tokens/turn` |
| `Tool_Call_Tokens_Xbar` | `Tool Call Tokens -- Xbar` | `Token Consumption/Tool Call Tokens` | `Mean tool-call tokens/turn` |
| `Tool_Call_Tokens_S` | `Tool Call Tokens -- s` | `Token Consumption/Tool Call Tokens` | `Std dev tool-call tokens/turn` |
| `Thinking_Tokens_Xbar` | `Thinking Tokens -- Xbar` | `Token Consumption/Thinking Tokens` | `Mean thinking tokens/turn` |
| `Thinking_Tokens_S` | `Thinking Tokens -- s` | `Token Consumption/Thinking Tokens` | `Std dev thinking tokens/turn` |
| `Tool_Call_Failure_Rate` | `Tool Call Failure Rate` | `Rates/Tool Call Failure Rate` | `Failure proportion` |
| `Fraction_Tool_Call_Turns` | `Fraction: Tool-Call Turns` | `Rates/Tool-Call Turns` | `Fraction of turns` |
| `Fraction_Thinking_Turns` | `Fraction: Thinking Turns` | `Rates/Thinking Turns` | `Fraction of turns` |
| `Fraction_Thinking_Tokens_I` | `Fraction: Thinking Tokens -- I` | `Rates/Thinking Tokens` | `Thinking tokens / output tokens` |
| `Fraction_Thinking_Tokens_MR` | `Fraction: Thinking Tokens -- MR` | `Rates/Thinking Tokens` | `MR (thinking / output tokens)` |
| `Fraction_Thinking_Tokens_EWMA` | `Fraction: Thinking Tokens -- EWMA` | `Rates/Thinking Tokens` | `EWMA (thinking / output tokens)` |
| `Fraction_Tool_Call_Tokens_I` | `Fraction: Tool-Call Tokens -- I` | `Rates/Tool-Call Tokens` | `Tool-call tokens / output tokens` |
| `Fraction_Tool_Call_Tokens_MR` | `Fraction: Tool-Call Tokens -- MR` | `Rates/Tool-Call Tokens` | `MR (tool-call / output tokens)` |
| `Fraction_Tool_Call_Tokens_EWMA` | `Fraction: Tool-Call Tokens -- EWMA` | `Rates/Tool-Call Tokens` | `EWMA (tool-call / output tokens)` |
| `Session_Input_Tokens_I` | `Session Input Tokens -- I` | `Session Totals/Input Tokens` | `Total input tokens` |
| `Session_Input_Tokens_MR` | `Session Input Tokens -- MR` | `Session Totals/Input Tokens` | `Moving range (input tokens)` |
| `Session_Output_Tokens_I` | `Session Output Tokens -- I` | `Session Totals/Output Tokens` | `Total output tokens` |
| `Session_Output_Tokens_MR` | `Session Output Tokens -- MR` | `Session Totals/Output Tokens` | `Moving range (output tokens)` |
| `Session_Cache_Read_Tokens_I` | `Session Cache Read Tokens -- I` | `Session Totals/Cache Read Tokens` | `Total cache-read tokens` |
| `Session_Cache_Read_Tokens_MR` | `Session Cache Read Tokens -- MR` | `Session Totals/Cache Read Tokens` | `Moving range (cache-read tokens)` |
| `Session_Cache_Write_Tokens_I` | `Session Cache Write Tokens -- I` | `Session Totals/Cache Write Tokens` | `Total cache-write tokens` |
| `Session_Cache_Write_Tokens_MR` | `Session Cache Write Tokens -- MR` | `Session Totals/Cache Write Tokens` | `Moving range (cache-write tokens)` |
| `Session_Thinking_Tokens_I` | `Session Thinking Tokens -- I` | `Session Totals/Thinking Tokens` | `Total thinking tokens` |
| `Session_Thinking_Tokens_MR` | `Session Thinking Tokens -- MR` | `Session Totals/Thinking Tokens` | `Moving range (thinking tokens)` |
| `Session_Tool_Call_Tokens_I` | `Session Tool-Call Tokens -- I` | `Session Totals/Tool-Call Tokens` | `Total tool-call input tokens` |
| `Session_Tool_Call_Tokens_MR` | `Session Tool-Call Tokens -- MR` | `Session Totals/Tool-Call Tokens` | `Moving range (tool-call input tokens)` |
| `Session_Tool_Call_Result_Tokens_I` | `Session Tool-Call Result Tokens -- I` | `Session Totals/Tool-Call Result Tokens` | `Total tool-call result tokens` |
| `Session_Tool_Call_Result_Tokens_MR` | `Session Tool-Call Result Tokens -- MR` | `Session Totals/Tool-Call Result Tokens` | `Moving range (tool-call result tokens)` |
| `Session_Input_Tokens_EWMA` | `Session Input Tokens -- EWMA` | `Session Totals/Input Tokens` | `EWMA (input tokens)` |
| `Session_Output_Tokens_EWMA` | `Session Output Tokens -- EWMA` | `Session Totals/Output Tokens` | `EWMA (output tokens)` |
| `Session_Cache_Read_Tokens_EWMA` | `Session Cache Read Tokens -- EWMA` | `Session Totals/Cache Read Tokens` | `EWMA (cache-read tokens)` |
| `Session_Cache_Write_Tokens_EWMA` | `Session Cache Write Tokens -- EWMA` | `Session Totals/Cache Write Tokens` | `EWMA (cache-write tokens)` |
| `Session_Thinking_Tokens_EWMA` | `Session Thinking Tokens -- EWMA` | `Session Totals/Thinking Tokens` | `EWMA (thinking tokens)` |
| `Session_Tool_Call_Tokens_EWMA` | `Session Tool-Call Tokens -- EWMA` | `Session Totals/Tool-Call Tokens` | `EWMA (tool-call input tokens)` |
| `Session_Tool_Call_Result_Tokens_EWMA` | `Session Tool-Call Result Tokens -- EWMA` | `Session Totals/Tool-Call Result Tokens` | `EWMA (tool-call result tokens)` |
| `Session_Turn_Count_I` | `Session Turn Count -- I` | `Session Totals/Turn Count` | `Turn count` |
| `Session_Turn_Count_MR` | `Session Turn Count -- MR` | `Session Totals/Turn Count` | `Moving range (turn count)` |
| `Session_Turn_Count_EWMA` | `Session Turn Count -- EWMA` | `Session Totals/Turn Count` | `EWMA (turn count)` |
| `Session_Uncached_Input_Tokens_I` | `Session Uncached Input Tokens -- I` | `Session Totals/Uncached Input Tokens` | `Total uncached input tokens` |
| `Session_Uncached_Input_Tokens_MR` | `Session Uncached Input Tokens -- MR` | `Session Totals/Uncached Input Tokens` | `Moving range (uncached input tokens)` |
| `Session_Uncached_Input_Tokens_EWMA` | `Session Uncached Input Tokens -- EWMA` | `Session Totals/Uncached Input Tokens` | `EWMA (uncached input tokens)` |
| `Fraction_Thinking_Per_Tool_Call_I` | `Fraction: Thinking/Tool-Call Tokens -- I` | `Rates/Thinking per Tool-Call` | `Thinking tokens / tool-call tokens` |
| `Fraction_Thinking_Per_Tool_Call_MR` | `Fraction: Thinking/Tool-Call Tokens -- MR` | `Rates/Thinking per Tool-Call` | `MR (thinking / tool-call tokens)` |
| `Fraction_Thinking_Per_Tool_Call_EWMA` | `Fraction: Thinking/Tool-Call Tokens -- EWMA` | `Rates/Thinking per Tool-Call` | `EWMA (thinking / tool-call tokens)` |
| `Fraction_Uncached_Input_I` | `Fraction: Uncached/Total Input -- I` | `Rates/Uncached Input` | `Uncached input tokens / input tokens` |
| `Fraction_Uncached_Input_MR` | `Fraction: Uncached/Total Input -- MR` | `Rates/Uncached Input` | `MR (uncached / input tokens)` |
| `Fraction_Uncached_Input_EWMA` | `Fraction: Uncached/Total Input -- EWMA` | `Rates/Uncached Input` | `EWMA (uncached / input tokens)` |
| `Tool_Call_JSD_Xbar` | `Consecutive Tool Diversity -- Xbar` | `Tool Call Behavior/Consecutive Diversity` | `Mean consecutive tool-call similarity` |
| `Tool_Call_JSD_S` | `Consecutive Tool Diversity -- s` | `Tool Call Behavior/Consecutive Diversity` | `Std dev consecutive tool-call similarity` |
| `Session_Tool_Call_JSD_Sum_I` | `Consecutive Tool Diversity Sum -- I` | `Tool Call Behavior/Consecutive Diversity` | `Sum of tool-call similarity scores` |
| `Session_Tool_Call_JSD_Sum_MR` | `Consecutive Tool Diversity Sum -- MR` | `Tool Call Behavior/Consecutive Diversity` | `MR (sum of tool-call similarity scores)` |
| `Session_Tool_Call_JSD_Sum_EWMA` | `Consecutive Tool Diversity Sum -- EWMA` | `Tool Call Behavior/Consecutive Diversity` | `EWMA (sum of tool-call similarity scores)` |
| `Turn_Tokens_Quantile` | `Turn Tokens Quantile` | `Quantile Profiles/Quantile Profiles` | `Quantile (output tokens/turn)` |
| `Tool_Call_Tokens_Quantile` | `Tool Call Tokens Quantile` | `Quantile Profiles/Quantile Profiles` | `Quantile (tool-call tokens/turn)` |
| `Thinking_Tokens_Quantile` | `Thinking Tokens Quantile` | `Quantile Profiles/Quantile Profiles` | `Quantile (thinking tokens/turn)` |
| `Tool_Call_JSD_Quantile` | `Tool Call JSD Quantile` | `Quantile Profiles/Quantile Profiles` | `Quantile (JSD similarity)` |

The left-panel display order is derived from each chart's `Group_Path`:
groups and sub-groups are sorted alphabetically, with enum declaration
order preserved within each sub-group.

---

## 9. Workspace File Format

### 9.1 Extension and Location

Workspace files use the `.sqcw` extension. Location is user-chosen via file chooser.

### 9.2 JSON Schema (version 7)

```json
{
  "version": 10,
  "workspaceId": "uuid-string",
  "name": "string",
  "sourceDirectories": ["string", ...],
  "modelFilter": ["string", ...],
  "setupSessionIds": ["uuid-string", ...],
  "logYMode": false,
  "analyzeAllDirectories": false,
  "chartSettings": {
    "Session_Input_Tokens_I": {
      "boxCox": {
        "enabled": true,
        "lambdaSource": "auto",
        "fixedLambda": 0.0
      },
      "estimationMethod": "classical",
      "ewmaWeight": 0.2,
      "ewmaL": 3.0
    }
  },
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

**`chartSettings`** is an optional JSON object whose keys are `Chart_Kind`
enumeration value names serialised as strings (e.g. `"Session_Input_Tokens_I"`).
Only charts whose settings differ from the all-default record are required to appear
as keys; absent keys are loaded as the default `Chart_Settings_Record`. Within each
chart object:

- `boxCox` — optional; absent means Box-Cox disabled, Auto mode, fixed λ = 0.0.
  - `enabled` : boolean. Default `false`.
  - `lambdaSource` : one of `"auto"`, `"robust_auto"`, `"fixed"`. Default `"auto"`.
  - `fixedLambda` : number. Default `0.0`.
- `estimationMethod` — optional string; one of `"classical"` or `"robust_median"`.
  Default `"classical"`.
- `ewmaWeight` — optional number in (0.0, 1.0]. Default `0.2`. Consulted only for
  EWMA chart kinds; ignored for all others.
- `ewmaL` — optional number in [1.0, 4.0]. Default `3.0`. Consulted only for EWMA
  chart kinds; ignored for all others.

When writing the workspace file, chart entries whose settings are all at default
values **shall be omitted** from `chartSettings` to keep the file compact.

### 9.3 Version Migration

The application reads the `"version"` field first:

- `version = 10`: load normally using the schema above.
- `version = 9`: load and migrate — `analyzeAllDirectories` key is absent;
  default `false` is applied to `Workspace.Analyze_All_Directories`.
- `version = 8`: load and migrate — `logYMode` key is absent; default `false`
  is applied to `Workspace.Log_Y_Mode`.
- `version = 1` to `7`: load with automatic migration — see migration rules below.
- `version > 10`: refuse to open; show a dialog:
  *"This workspace was created by a newer version of coyote_sqc and cannot be opened."*
- `version < 1` or absent: attempt load with best-effort field mapping; show a
  warning: *"Workspace file has no version field; some data may be missing."*

**Migration from version ≤ 6:**

The following top-level fields from versions 1–6 are migrated into `chartSettings`
per-chart entries, then discarded. The workspace is resaved at version 10 immediately
after loading (triggering an implicit unsaved-changes notification).

| Old field | Charts receiving the migrated config |
|---|---|
| `iChartBoxCox` | All I, MR, and EWMA chart kinds whose observation is a session token total (input, output, cache read/write, thinking, tool-call, tool-call result, uncached input) |
| `xbarSBoxCox` | `Turn_Tokens_Xbar`, `Turn_Tokens_S`, `Tool_Call_Tokens_Xbar`, `Tool_Call_Tokens_S`, `Thinking_Tokens_Xbar`, `Thinking_Tokens_S` |
| `turnCountBoxCox` | `Session_Turn_Count_I`, `Session_Turn_Count_MR`, `Session_Turn_Count_EWMA` |
| `estimationMethod` | All chart kinds |
| `ewmaWeight`, `ewmaL` | All EWMA chart kinds |

If an old field is absent from the file (e.g. `iChartBoxCox` absent in a v1 file),
it defaults as documented for that version and the default is broadcast to the
affected chart kinds only if it differs from the per-chart default
(i.e. disabled Box-Cox and `"classical"` estimation are not written, keeping the
migrated `chartSettings` map sparse).

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
containing a `GtkLabel`. The five groups ("Token Consumption", "Rates", "Session Totals", "Tool Call Behavior") are separated
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
   Set_B             : UUID_Set;    -- Set B session UUIDs (two-set comparison)
   Edit_Set_B_Mode   : Boolean := False;
   --  When True, all selection actions (click, shift+click, shift+drag)
   --  modify Set_B instead of Selection.  Toggled by the toolbar
   --  Edit_Set_B_Button.
   --  GTK handles for two-set mode:
   Edit_Set_B_Button    : Gtk.Toggle_Button.Gtk_Toggle_Button;
   Clear_Both_Sets_Item : Gtk.Menu_Item.Gtk_Menu_Item;
   Date_From        : Ada.Calendar.Time;
   Date_To          : Ada.Calendar.Time;
   Run_Sequence_Mode : Boolean := False;  -- True = equal-spacing run-sequence x-axis
   --  Log_Y_Mode stored in Workspace_Record (persisted): State.Workspace.Log_Y_Mode
   --  Global run indices: Sessions(I).Run_Index = I (1-based, chronological order).
   --  Populated by Reload_Sessions; never renumbered when the date filter changes.
   Run_Index_Map    : Coyote_SQC.Data_Model.Natural_Vectors.Vector;
   --  GTK widget handles
   Canvas           : Gtk.Drawing_Area.Gtk_Drawing_Area;
   Detail_Panel_Box : Gtk.Box.Gtk_Box;
   --  Menu item handles for View menu (sensitivity managed by Update_Menu_States)
   Clear_Setup_Item            : Gtk.Menu_Item.Gtk_Menu_Item;
   Set_Selection_As_Setup_Item : Gtk.Menu_Item.Gtk_Menu_Item;
   Select_Setup_Interval_Item  : Gtk.Menu_Item.Gtk_Menu_Item;
   Run_Sequence_Item           : Gtk.Check_Menu_Item.Gtk_Check_Menu_Item;
   Log_Y_Item              : Gtk.Check_Menu_Item.Gtk_Check_Menu_Item;
   --  Resolved Box-Cox lambda values are stored per chart kind in
   --  Chart_Data.Box_Cox_Lambda (not in App_State directly).
end record;
```

A single `App_State_Access` global (package-level in `Coyote_SQC.App`) is
acceptable, mirroring the pattern used in `Digiplot.App` and consistent with
GTK's single-threaded callback model.

### 11.4 Toolbar — `Coyote_SQC.UI.Toolbar`

```
[From: YYYY-MM-DD HH:MM ▼]  [To: YYYY-MM-DD HH:MM ▼]  [Show All]  [Y-Fit]  [Run Sequence ☐]  [Log Y ☐]  [Edit Set B ☐]
```

- **From / To:** `Coyote_SQC.UI.Datetime_Picker` instances (§11.7).
- **Show All:** sets `Date_From` / `Date_To` to the minimum and maximum session start
  times; triggers canvas redraw.
- **Y-Fit:** calls `Canvas.Y_Fit` (§12.5).
- **Run Sequence ☐:** a `GtkCheckButton` (or `GtkToggleButton`) that toggles
- **Log Y ☐:** a `GtkCheckButton` that toggles `App_State.Workspace.Log_Y_Mode`.
  On toggle, calls `App.State.Modified := True`, updates `Log_Y_Item` in the View
  menu, and redraws the canvas.  The corresponding View menu item is kept in sync.
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
| Chart Settings… `Ctrl+,` | Open the Chart Settings dialog (§11.12) for the currently active chart; calls `UI.Chart_Settings_Dialog.Show (Active_Chart)` |
| *(separator)* | |
| Clear Selection | `App_State.Selection.Clear`; hide detail panel |
| Clear Both Sets | `App_State.Selection.Clear; App_State.Set_B.Clear`; update `Edit_Set_B_Button` and detail panel; grayed out when both sets are empty — handle stored in `App_State.Clear_Both_Sets_Item` |
| Clear Setup Interval | `Workspace.Clear_Setup_Interval` with confirmation; grayed out if `Setup_Session_Ids` is empty |
| Set Selection as Setup Interval | Assign `App_State.Selection` to `Workspace.Setup_Session_Ids`; shows confirmation dialog if a setup interval is already established; sets `Modified := True`, calls `Recompute_Charts` and `Queue_Redraw`; grayed out when `Selection` is empty — handle stored in `App_State.Set_Selection_As_Setup_Item` |
| Select Setup Interval | Copy `Workspace.Setup_Session_Ids` into `App_State.Selection`; calls `Update_Menu_States` and `Queue_Redraw` so newly selected points receive halos; grayed out when `Setup_Session_Ids` is empty — handle stored in `App_State.Select_Setup_Interval_Item` |
| *(separator)* | |
| X-Axis: Run Sequence | Toggle `App_State.Run_Sequence_Mode`; checkmark shown when active; triggers `Switch_X_Scale_Mode` (§12.2.1) and canvas redraw; kept in sync with the toolbar checkbox |
| Y-Axis: Log Scale | Toggle `App_State.Workspace.Log_Y_Mode`; checkmark shown when active; triggers a canvas redraw; kept in sync with the toolbar **Log Y** checkbox |

### 11.6 Detail Panel — `Coyote_SQC.UI.Detail_Panel`

The detail panel is hidden (zero width, `GtkPaned` position collapsed) when
`App_State.Selection` is empty. It is shown whenever the selection becomes non-empty.

**Single-session view** (exactly one UUID in selection):


```
GtkBox (vertical)
├── GtkFrame "Session"
│   └── GtkLabel (selectable; datetime, model, source dir, tokens, UUID)
├── GtkFrame "Distribution"          (always present; shows subgroup histogram
│   └── GtkDrawingArea               when Is_Xbar_S_Chart; "No data for active
│       (Histogram_Canvas, 160 px)   chart" otherwise)
├── GtkFrame "Summary Statistics"    (always present; populated when
│   └── GtkGrid (6 × 2)             Is_Xbar_S_Chart; shows "-" otherwise)
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

The Session frame content is implemented as a selectable `GtkLabel`
(`Set_Selectable (True)`).  This
allows the user to click-and-drag to copy the session ID, datetime, model,
or any other field without opening a text editor.

Scroll position in the Session Replay `GtkTextView` is saved in a
`Hash_Map<UUID → Gtk.Adjustment.Gtk_Adjustment>` and restored when the same session
is re-selected.

**Multi-select view** (two or more UUIDs in selection):

```
GtkBox (vertical)
├── GtkLabel "N sessions selected"
├── GtkLabel "YYYY-MM-DD – YYYY-MM-DD"
├── GtkFrame "Distribution"
│   └── GtkDrawingArea (Histogram_Canvas, 160 px fixed height)
├── GtkFrame "Summary Statistics"
│   └── GtkGrid (7 rows × 2 columns: Mean, Median, Std Dev,
│             KS Normal p, KS Exp p, Runs Test p, Dip Test p)
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

**Two-set comparison view** (Set B non-empty; see SRS-SQC §10.3):

```
GtkBox (vertical)
├── GtkGrid (set headers, 2 rows × 3 columns)
│   ├── [row 0] GtkLabel "Set A" (blue)  GtkLabel "<N> sessions"  GtkLabel "<date range>"
│   └── [row 1] GtkLabel "Set B" (orange) GtkLabel "<N> sessions"  GtkLabel "<date range>"
├── GtkFrame "Distribution"
│   └── GtkDrawingArea (Two_Set_Histogram_Canvas, 180 px fixed height)
├── GtkFrame "Summary Statistics"
│   └── GtkGrid (9 rows × 3 columns: label + Set A value + Set B value)
│       Rows: N, Mean, Median, Std Dev, KS Normal p, KS Exp p, Runs Test p, Dip Test p
├── GtkFrame "Comparison (Bootstrap 95% CI)"
│   └── GtkGrid (3 rows × 2 columns: label + "point [lower, upper]")
│       Rows: Mean diff (B−A), Median diff (B−A), SD ratio (B/A)
├── GtkFrame "Add Comment to All Selected"
│   ├── GtkTextView (entry; applies to Set A sessions only)
│   └── GtkButton "Add Comment to All"
└── [No Selected Sessions list in this view]
```

`Two_Set_Histogram_Canvas` extends `Coyote_SQC.UI.Histogram_Canvas` with a
second data series.  A new `Refresh_Two_Set` procedure accepts `Values_A` and
`Values_B` arrays; it computes shared bin boundaries from the combined range
using the Freedman-Diaconis rule on the pooled sample, then renders two bar
series in semi-transparent blue (Set A, opacity 0.5) and semi-transparent
orange (Set B, opacity 0.5).  The overlay lines (CL, UCL, LCL) are derived
from the first contributing Set A point, using the same rules as the
single-set histogram (§11.9).  A two-item inline legend ("Set A" / "Set B")
is drawn in the upper-right corner of the histogram area.

Bootstrap CIs are computed by calling `Coyote_SQC.Statistics.Bootstrap.Compute`
and displayed in the Comparison frame.  Computation is synchronous (the GTK
main loop thread); typical dataset sizes make this negligible.

```ada
--  New procedure in Coyote_SQC.UI.Histogram_Canvas:
procedure Refresh_Two_Set
  (Values_A  : Coyote_SQC.Data_Model.Long_Float_Vectors.Vector;
   Values_B  : Coyote_SQC.Data_Model.Long_Float_Vectors.Vector;
   CL        : Long_Float;
   UCL       : Long_Float;
   Has_UCL   : Boolean;
   LCL       : Long_Float;
   Has_LCL   : Boolean;
   X_Label   : String;
   Has_Data  : Boolean);
```

`Compute_Bins` (already exposed for unit testing) is called once on the
pooled union of both value sets; both sets receive the same `Bin_Min`,
`Bin_Width`, and `N_Bins`.


**Summary Statistics frame:** `GtkFrame "Summary Statistics"` containing a
`GtkGrid` (7 rows × 2 columns) placed between the Distribution histogram
and the Set as Setup Interval button.  The grid rows are: Mean, Median,
Std Dev, KS Normal p, KS Exp p, Runs Test p, Dip Test p.  Key labels are left-aligned
(column 0); value labels are right-aligned (column 1).  Initial value for
each label is `"-"`.  The frame is populated by
`Refresh_Histogram_If_Multi` (§11.9) using the same contributing session
set that feeds the histogram.  Values display as rounded integers for
|v| ≥ 100, or with 2 decimal places otherwise.  P-values display as
`"< 0.001"`, `"N/A"` (sample too small), or 3 decimal places.  The frame
updates whenever the active chart or the selection changes.
The statistical methods are specified in §7.15 (KS tests) and §7.16
(Wald-Wolfowitz runs test).

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
When shown, the latest comment line includes the timestamp (`YYYY-MM-DD HH:MM`) of
the most recent comment and its truncated body (max 80 characters, ellipsis appended
if truncated), separated by a colon and space.

### 11.9 Histogram Canvas — `Coyote_SQC.UI.Histogram_Canvas`

The histogram canvas is a `GtkDrawingArea` with a fixed height request of
160 px, embedded inside a `GtkFrame "Distribution"` in the multi-select detail
panel (§11.6).  All drawing uses Cairo.

#### Public interface

```ada
--  Build the GtkDrawingArea.  Must be called once per multi-select refresh;
--  the widget handle is stored internally and replaced on each call.
function Build return Gtk.Drawing_Area.Gtk_Drawing_Area;

--  Store new histogram data and queue a redraw.
procedure Refresh
  (Values   : Long_Float_Array;   --  eligible selected sessions' statistics
   CL       : Long_Float;         --  center-line overlay (solid blue)
   UCL      : Long_Float;         --  UCL overlay (red dashed); drawn when Has_UCL
   Has_UCL  : Boolean;
   LCL      : Long_Float;         --  LCL overlay (red dashed); when Has_LCL and LCL > 0
   Has_LCL  : Boolean;
   X_Label  : String;             --  active chart's Y_Axis_Label (x-axis label)
   Has_Data : Boolean);           --  False -> show "No data for active chart"

--  Bin computation -- exposed for unit testing.
--  N_Bins uses Freedman-Diaconis: h = 2*IQR/n^(1/3), k = ceil(range/h), capped at 32.
--  When IQR = 0 falls back to 1 bin.
--  When all values are equal: N_Bins = 1, Bin_Width = 1.0, Counts(1) = n.
procedure Compute_Bins
  (Values    :     Long_Float_Array;
   N_Bins    : out Positive;
   Bin_Min   : out Long_Float;
   Bin_Width : out Long_Float;
   Counts    : out Bin_Count_Array);
```

#### Rendering

The `On_Histogram_Draw` callback (connected to the `"draw"` signal) performs
the following steps in order:

1. **Clear** -- fill background white; fill margin areas light gray
   (ML=38 px, MR=8 px, MT=8 px, MB=28 px).
2. **No-data guard** -- if `Has_Data = False` or the value list is empty,
   render "No data for active chart" centred in the widget and return.
3. **Compute bins** -- call `Compute_Bins` on the stored value vector.
4. **Horizontal grid lines** -- light gray dashed lines at y-positions
   corresponding to counts 0, `max_count/2`, and `max_count`.  Count labels
   are drawn in the left margin.
5. **Bars** -- steel blue (`RGB 0.27, 0.51, 0.71`) filled rectangles, one per
   bin, with a 1 px gap between adjacent bars.
6. **Axes** -- black y-axis and x-axis lines.
7. **X-axis ticks** -- three tick marks and labels at `Bin_Min`,
   `Bin_Min + N_Bins/2 * Bin_Width`, and `Bin_Min + N_Bins * Bin_Width`.
8. **X-axis label** -- `X_Label` string centred below the tick labels.
9. **Overlay lines** (drawn last so they overlie the bars):
   - LCL: red dashed (`4.0, 3.0` dash pattern), 1 px wide.
   - UCL: red dashed, 1 px wide.
   - CL: solid blue, 1.5 px wide.
   - A line is suppressed if its data value falls outside
     `[Bin_Min - 0.5*Bin_Width, Bin_Min + N_Bins*Bin_Width + 0.5*Bin_Width]`.

#### Refresh triggering

`Refresh_Histogram_If_Multi` (in `Coyote_SQC.UI.Detail_Panel`) is called:

- At the end of `Build_Multi_View`, after the histogram `GtkFrame` is
  added to the panel.
- From `Coyote_SQC.UI.Left_Panel.On_Row_Activated`, immediately after
  `Chart_Canvas.Queue_Redraw`, so that switching charts updates the histogram
  without rebuilding the detail panel.



`Refresh_Histogram_If_Single` (in `Coyote_SQC.UI.Detail_Panel`) is called:

- At the end of `Build_Single_View`, after the histogram and summary
  statistics frames are added to the panel.
- From `Coyote_SQC.UI.Left_Panel.On_Row_Activated`, immediately after
  `Refresh_Histogram_If_Multi`, so that switching charts while a single
  session is selected updates the subgroup histogram without rebuilding the
  detail panel.

`Refresh_Histogram_If_Single` is a no-op when the selection does not contain
exactly one session.  When called with exactly one session selected, it:

1. Retrieves the chart descriptor for the active chart and checks
   `Props.Is_Xbar_S_Chart`.
2. If `True`: collects the per-turn subgroup values for the selected session
   via the descriptor's `Get_Subgroup` or `LF_Get_Subgroup` accessor (calling
   `Coyote_SQC.Metrics.Compute` to obtain the `Session_Metrics_Record`);
   looks up the matching `Chart_Point` in the active chart's `CD.Points` to
   obtain `CL`, `UCL`/`Has_UCL`, and `LCL`/`Has_LCL`; then calls
   `Histogram_Canvas.Refresh` with those values and the chart's `Y_Axis_Label`
   as `X_Label`.
3. If `False`: calls `Histogram_Canvas.Refresh` with `Has_Data => False`.
4. Updates the six `Stats_*_Lbl` widgets using the same logic as
   `Refresh_Histogram_If_Multi` (replacing the contributing-sessions set with
   the subgroup values from step 2, or clearing them to `"-"` in step 3).

#### Stats-label lifetime invariant

`Refresh` nulls all ten `Stats_*_Lbl` / `Stats_*_Key_Lbl` package-body
variables when removing `Inner_Box` (immediately after the
`Panel_Box.Remove` call, alongside the existing nulls for `Comment_Entry`
and `Multi_Comment_Entry`).  `Build_Single_View` and `Build_Multi_View`
additionally null and reassign them inside their stats-grid construction
blocks.  `Build_Two_Set_View` resets them at the top of its body.

`Refresh_Histogram_If_Multi` and `Refresh_Histogram_If_Single` rely on
this invariant: a non-null stats-label pointer is always a live GTK widget.
Any future `Build_*_View` procedure that does not assign stats-label
widgets must null them at its body entry so the invariant holds.

#### Box-Cox transformation and the histogram

When the active chart's Box-Cox is enabled (`Chart_Settings (Active_Chart).Box_Cox.Enabled = True`) and the active chart is one
of the eighteen I/MR charts (the eight Session Token I/MR pairs plus the Turn Count I/MR pair), `Refresh_Histogram_If_Multi` passes
**transformed** values to `Refresh`:

- For I charts: pass `Box_Cox (X_i, Lambda)` for each selected session's total.
  Pass the transformed-space CL and limits (before back-transform); these are
  the same values used to compute the chart's limit lines.
- For MR charts: pass the already-transformed MR values `|Z_i − Z_{i-1}|`
  directly; limits are already in transformed space.
- The `X_Label` string gains a suffix: `" (λ=0.31)"` (numeric lambda, always
  shown as a decimal, even for exact values like 0.0 or 0.5).

For all other chart kinds the `Refresh` call is unchanged.

### 11.10 Tool Call Detail Window — `Coyote_SQC.UI.Tool_Detail_Window`

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


### 11.11 Workspace Settings Dialog — Settings Sections

`Coyote_SQC.UI.Workspace_Settings.Show_Dialog` presents the following sections:

- **Workspace name** (`GtkEntry`).
- **Source directories** — `GtkListBox` with Add / Remove buttons; Add opens a
  directory chooser dialog.
- **Model filter** — `GtkListBox` of model identifier strings with Add (text entry)
  and Remove buttons, plus an "Include all models" checkbox that clears and disables
  the list.

Changes take effect on clicking OK: sessions are reloaded and the setup interval
integrity check (§11 of the requirements) is performed.

Per-chart Box-Cox, estimation method, and EWMA parameters are configured through
the Chart Settings dialog (§11.12), not through Workspace Settings.

### 11.12 Chart Settings Dialog — `Coyote_SQC.UI.Chart_Settings_Dialog`

Accessible via **View → Chart Settings…** (`Ctrl+,`) or by right-clicking the
chart canvas. The dialog is modal and titled *"Chart Settings — \<chart label\>"*
for the currently active chart. All settings affect only that chart; other charts
are unchanged.

#### Public Interface

```ada
package Coyote_SQC.UI.Chart_Settings_Dialog is

   --  Show the Chart Settings dialog for Kind, modal over Main_Window.
   --  Returns after the user clicks OK or Cancel.
   --  On OK: writes the new Chart_Settings_Record into
   --    App_State.Workspace.Chart_Settings (Kind), sets Modified := True,
   --    calls Recompute_Chart (Kind), and queues a canvas redraw.
   --  On Cancel: no changes are made.
   procedure Show
     (Kind        : Coyote_SQC.Charts.Chart_Kind;
      Main_Window : not null access Gtk.Window.Gtk_Window_Record'Class);

end Coyote_SQC.UI.Chart_Settings_Dialog;
```

#### Widget Layout

```
GtkDialog "Chart Settings — <chart label>"
└── GtkBox (vertical, spacing 8, border 12)
    ├── GtkExpander "Box-Cox Transformation"
    │   └── [Box-Cox section; see below]
    ├── GtkExpander "Estimation Method"
    │   └── [Estimation method section; see below]
    ├── GtkExpander "EWMA Parameters"  ← only when Kind is an EWMA chart
    │   └── [EWMA section; see below]
    ├── GtkButton "Reset to Defaults"
    └── [Dialog action area: OK, Cancel]
```

Expanders whose settings are at the per-chart default are **collapsed** when the
dialog opens; expanders with non-default settings are **expanded**.

#### Box-Cox Transformation Expander

```
┌─ Box-Cox Transformation ────────────────────────────────────────────────┐
│                                                                          │
│  [✓] Enable Box-Cox transformation                                       │
│                                                                          │
│  Lambda source:  [▼ Auto-estimate (MLE)               ▼]               │
│                                                                          │
│  Fixed λ:  [▼ ln (λ=0) ▼]  custom: [____0.00____]                     │
│            (sensitive only when Lambda source = Fixed)                   │
│                                                                          │
│  Estimated λ:       0.31  (recomputed when setup interval changes)      │
│  Estimated λ (MR):  0.22  ← shown only for MR chart kinds               │
│                                                                          │
│  Note: Box-Cox is not recommended for this chart type.  ← p/ratio only  │
└──────────────────────────────────────────────────────────────────────────┘
```

**Widget details:**

- **Enable checkbox** (`GtkCheckButton`): checked means `Box_Cox.Enabled = True`.
  All sub-widgets are insensitive when unchecked.
- **Lambda source combo** (`GtkComboBoxText`): `"Auto-estimate (MLE)"`,
  `"Auto-estimate (robust)"`, `"Fixed"`. Maps to `Auto`, `Robust_Auto`, `Fixed`
  respectively.
- **Fixed value combo** (`GtkComboBoxText`): `"ln (λ=0)"`, `"√ (λ=0.5)"`,
  `"no transform (λ=1)"`, `"custom…"`. Sensitive only when Lambda source = Fixed.
- **Lambda spin** (`GtkSpinButton`): range 0.0–30.0, step 0.01. Sensitive only
  when Lambda source = Fixed and Fixed value combo = `"custom…"`.
- **Estimated λ readout** (`GtkLabel`): reads `Chart_Data (Kind).Box_Cox_Lambda`.
  Greyed out when Lambda source = Fixed or fewer than 3 setup sessions available.
- **Estimated λ (MR) readout** (`GtkLabel`): reads
  `Chart_Data (Companion_MR_Kind (Kind)).Box_Cox_Lambda`. Shown only for MR
  chart kinds.
- **Advisory note** (`GtkLabel`): shown only for p-charts and ratio I/MR charts;
  reads *"Box-Cox is not recommended for this chart type."*

#### Estimation Method Expander

```
┌─ Estimation Method ─────────────────────────────────────────────────────┐
│                                                                          │
│  Method:  [▼ Classical (mean / pooled s / mean MR)  ▼]                 │
│                                                                          │
│  Note: p-charts always use the classical grand proportion.  ← p only    │
│  Note: EWMA uses the same setup-interval observations as its            │
│        companion I chart.                                                │
└──────────────────────────────────────────────────────────────────────────┘
```

**Widget details:**

- **Method combo** (`GtkComboBoxText`): `"Classical (mean / pooled s / mean MR)"` →
  `Classical`; `"Robust (median / Qₙ / median MR)"` → `Robust_Median`.
- **Note label**: varies by chart kind:
  - p-chart: *"p-charts always use the classical grand proportion regardless of
    this setting."*
  - EWMA chart: *"EWMA charts independently apply this method using the same
    setup-interval observations as the companion I chart."*
  - All others: no note shown.

#### EWMA Parameters Expander *(EWMA charts only)*

This expander is present only when `Kind` is one of the EWMA chart kinds
(those for which `Properties (Kind).Is_EWMA_Chart = True`). For all other
chart kinds the expander is absent entirely.

```
┌─ EWMA Parameters ───────────────────────────────────────────────────────┐
│                                                                          │
│  Smoothing weight (λ):  (range 0.01–1.00)  [__0.20__]                  │
│  Sigma multiplier (L):  (range 1.00–4.00)  [__3.00__]                  │
│                                                                          │
│  Smaller λ gives more smoothing and better detection of small           │
│  sustained shifts; λ = 1 reduces to the raw I chart.                    │
└──────────────────────────────────────────────────────────────────────────┘
```

**Widget details:**

- **Smoothing weight spinner** (`GtkSpinButton`): range 0.01–1.00, step 0.01.
  Initial value: `Chart_Settings (App_State.Workspace, Kind).EWMA_Weight`.
- **Sigma multiplier spinner** (`GtkSpinButton`): range 1.00–4.00, step 0.25.
  Initial value: `Chart_Settings (App_State.Workspace, Kind).EWMA_L`.

#### Reset to Defaults Button

Restores all three sections to their default values for this chart only:
`Box_Cox.Enabled = False`, `Estimation_Method = Classical`, `EWMA_Weight = 0.2`,
`EWMA_L = 3.0`. Does not affect any other chart.

#### Dialog Lifecycle

Changes take effect only when the user clicks **OK**. Cancel discards all pending
changes. On OK:

1. A new `Chart_Settings_Record` is constructed from the current widget state.
2. If the record equals the all-default record: the chart kind is **removed** from
   `Workspace.Chart_Settings` (keeping the map sparse).
3. Otherwise: `Workspace.Chart_Settings.Include (Kind, New_Settings)`.
4. `App_State.Modified := True`.
5. `Coyote_SQC.App.Recompute_Chart (Kind)` is called.
6. The canvas is redrawn via `Canvas.Queue_Draw`.

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

#### 12.2.2 Log Y Coordinate Mapping

When `App_State.Workspace.Log_Y_Mode` is `True`, the y-axis renders in base-10
logarithmic scale. The coordinate transforms operate in `log₁₀` space:

**`Data_To_Screen_Y` (log mode):**
```
log_y_min = Log(Y_Min, 10)   -- Ada.Numerics.Long_Elementary_Functions.Log(Y_Min) / Log(10.0)
log_y_max = Log(Y_Max, 10)
log_dy    = Log(DY, 10)
screen_y  = Margin_Top + (log_y_max - log_dy) / (log_y_max - log_y_min) * Plot_Height
```
Returns `Long_Float'Last` (off-screen) when `DY ≤ 0.0`.

**`Screen_To_Data_Y` (log mode):**
```
log_y_min = Log(Y_Min, 10)
log_y_max = Log(Y_Max, 10)
log_data  = log_y_max - (SY - Margin_Top) / Plot_Height * (log_y_max - log_y_min)
data_y    = 10.0 ** log_data
```

**Y tick generation (log mode):**  Tick marks are placed at decade boundaries:
powers of 10 from `10.0 ** Floor(log₁₀(Y_Min))` up through
`10.0 ** Ceil(log₁₀(Y_Max))`. Tick density adjusts gracefully: if more than
`N_Ticks` decades would appear, only every-Nth decade is labelled; if fewer than
2 decades are visible, sub-decade ticks (×2, ×5) are added.  Labels use the
compact form: `"1"`, `"10"`, `"100"`, `"1K"`, `"10K"`, `"100K"`, `"1M"`, etc.

**Y-zoom (log mode):**
```
log_y_min' = log(CY) + (log(Y_Min) - log(CY)) / factor
log_y_max' = log(CY) + (log(Y_Max) - log(CY)) / factor
Y_Min' = 10.0 ** log_y_min';  Y_Max' = 10.0 ** log_y_max'
```
A guard ensures `Y_Min' ≥ 1.0e-10` to prevent collapse near zero.

**Y-pan (log mode):**
The drag delta is computed in log space:
```
log_delta = (MY - Drag_Start.Y) / Plot_Height * (log(Drag_Y_Max) - log(Drag_Y_Min))
Y_Min' = 10.0 ** (log(Drag_Y_Min) + log_delta)
Y_Max' = 10.0 ** (log(Drag_Y_Max) + log_delta)
```

**Skipping non-positive values:**  When `Log_Y_Mode` is `True`, any chart point
with `Stat_Value ≤ 0.0` is skipped (not plotted).  UCL, LCL, and CL lines at
values ≤ 0.0 are not drawn.

**Y-Fit (log mode):**  Collects all positive `Stat_Value`, UCL, and LCL values
within the current x-range. Sets `Y_Min` and `Y_Max` to the minimum and maximum
of those positive values, then applies a 10 % multiplicative margin:
`Y_Min' = Y_Min / 1.1;  Y_Max' = Y_Max * 1.1`.  No-op if no positive values
are in range.

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

In linear mode, collects the y-values of all points within `[X_Min, X_Max]` (plus
UCL/LCL series within that range). Sets `Y_Min` and `Y_Max` to the minimum and
maximum of those values, expanded by 10% margin on each side. In **Log Y mode**
(§12.2.2), only positive values are collected and a multiplicative 10% margin is
applied (`Y_Min / 1.1`, `Y_Max * 1.1`). If no eligible points are in range,
no-op.  For Quantile Control Charts, the five component values (min, Q1,
median, Q3, max) and their associated UCL/LCL limits are collected from
`Chart_Data.Quantile_Points`.


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

6a. **Quantile diagrams (Quantile CC only):** when the active chart is a
   Quantile Control Chart (§6.42–6.45), steps 3–6 (connecting line,
   control limit series, center line, point markers) are replaced by the
   following quantile diagram rendering procedure.  For each session, a
   vertical quantile diagram is drawn at its x-coordinate, consisting of
   five horizontal component lines each inside a hollow control-limit
   box.  Components are rendered from the session's median y-value
   outward (median, then Q1/Q3, then min/max) so that narrower boxes
   are drawn on top of wider boxes.

   Component widths (horizontal extent from center, in pixels):

   | Component | Half-width |
   |---|---|
   | Minimum | 6 |
   | First quartile | 10 |
   | Median | 14 |
   | Third quartile | 10 |
   | Maximum | 6 |

   For each component:

   - **Control box:** a lozenge shape (rectangular body with triangular end caps) centered at the session's
     x-coordinate, whose triangular tips extend to `Data_To_Screen_Y (UCL_j)` (upper tip) and
     `Data_To_Screen_Y (LCL_j)` (lower tip).  The rectangular body spans from `UY + TH` to `LY - TH`, where `TH = half_width × 0.5` is the triangle height.  Total horizontal width: `2 × half_width`.
     Stroke width: 1 px.
   - **Component line:** a filled horizontal line segment centered at
     the session's x-coordinate at `Data_To_Screen_Y (Value_j)`, with
     total width `2 × half_width`.  Line thickness: 2 px.

   Component colors (line and box are the same color):

   | Condition | Color (Cairo RGB) |
   |---|---|
   | In-control, no comment for session | Black line `(0, 0, 0)`, gray lozenge `(0.41, 0.41, 0.41)` |
   | In-control, comment present | Green line `(0.1, 0.7, 0.2)`, green lozenge `(0.1, 0.7, 0.2)` |
   | Out-of-control, no comment | Red line `(0.9, 0.1, 0.1)`, red lozenge `(0.9, 0.1, 0.1)` |
   | Out-of-control, comment present | Orange line `(0.95, 0.5, 0.0)`, orange lozenge `(0.95, 0.5, 0.0)` |

   **Setup interval halo:** sessions in the setup interval receive a
   yellow ring: a hollow rectangle drawn 3 px outside the bounding box
   of the full diagram (from min LCL to max UCL vertically, from
   −max_half_width to +max_half_width horizontally), with 2 px stroke
   in yellow `(1.0, 0.80, 0.0)`.

   **Selection halo:** selected sessions receive a blue (Set A) ring or
   orange (Set B) ring drawn 3 px outside the bounding box, with 2 px
   stroke.

   **Log Y mode:** when `Log_Y_Mode` is active, any component whose
   `Value_j`, `UCL_j`, or `LCL_j` is ≤ 0 is skipped (not drawn).
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
11. **Box-Cox subtitle (I/MR and Xbar/S charts):** when Box-Cox is active for the
    currently displayed chart (`Chart_Data.Box_Cox_Active = True`), render a small
    italic annotation in the top-right corner of the plot area (9pt, Cairo
    `select_font_face` ITALIC, right-aligned 4px from the right margin, 4px below
    the top margin): `"Box-Cox λ = 0.31"` (numeric value from
    `Chart_Data.Box_Cox_Lambda`, formatted to two decimal places). The condition
    is `Props.Is_I_Chart or else Props.Is_MR_Chart or else Props.Is_Xbar_S_Chart
    or else Props.Is_EWMA_Chart` (add `Is_MR_Chart : Boolean` to `Chart_Properties`).
    The annotation reads `"Box-Cox λ = N.NN"` for I/Xbar_S/EWMA charts and
    `"Box-Cox λ_MR = N.NN"` for MR charts (reflecting the independently estimated
    MR lambda).  MR chart y-axis labels remain in original units; no `" (transformed
    units)"` suffix is appended.  For s charts with Box-Cox active,
    the y-axis label similarly reflects transformed units. Annotations are omitted
    when Box-Cox is disabled for the active chart.

12. **EWMA weight annotation (EWMA charts only):** when the active chart is one of
    the seven EWMA chart kinds, render a small italic annotation in the **top-left**
    corner of the plot area (9pt, Cairo ITALIC, left-aligned 4px from the left margin
    edge of the plot area, 4px below the top margin): `"EWMA λ = 0.20, L = 3.00"`,
    showing the current per-chart `EWMA_Weight` and `EWMA_L` values (from `Chart_Settings (Kind)`) each
    formatted to two decimal places.  The annotation is drawn regardless of whether
    Box-Cox is active; the two annotations (Box-Cox subtitle at top-right, EWMA
    annotation at top-left) can coexist on the same chart.

### 12.7 Point Marker Colors (Cairo RGB)

| Condition | Fill | Stroke | Hollow? |
|---|---|---|---|
| In-control, no comment | `(0, 0, 0)` | `(0, 0, 0)` | No |
| In-control, comment present | `(0.1, 0.7, 0.2)` | `(0.05, 0.5, 0.1)` | No |
| Out-of-control, no comment | `(0.9, 0.1, 0.1)` | `(0.9, 0.1, 0.1)` | No |
| Setup interval halo | — | `(1.0, 0.80, 0.0)` 2px ring at radius+6 | Additive |
| Out-of-control, comment present | `(0.95, 0.5, 0.0)` | `(0.7, 0.35, 0.0)` | No |
| Zero-thinking excluded | `(0, 0, 0)` | `(0.6, 0.6, 0.6)` | Yes |
| Single-turn on Xbar chart | `(0, 0, 0)` | `(0, 0, 0)` | Yes |
| Selected (Set A) halo | — | `(0.1, 0.3, 0.9)` 2px ring | Additive |
| Selected (Set B) halo | — | `(0.9, 0.5, 0.1)` 2px ring (orange) | Additive |
| Quantile CC component, in-control, no comment | Black line `(0,0,0)`, gray lozenge `(0.41,0.41,0.41)` |
| Quantile CC component, in-control, comment present | Green line `(0.1,0.7,0.2)`, green lozenge `(0.1,0.7,0.2)` |
| Quantile CC component, OOC, no comment | Red line `(0.9,0.1,0.1)`, red lozenge `(0.9,0.1,0.1)` |
| Quantile CC component, OOC, comment present | Orange line `(0.95,0.5,0.0)`, orange lozenge `(0.95,0.5,0.0)` |

Setup interval and selection halos are additive: a selected setup-interval point
receives both a yellow ring (radius+6) and a blue ring (radius+3). Hollow-gray and
single-turn markers do not receive a setup interval halo.

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


**Box-Cox transformation tests (`Coyote_SQC.Tests.Statistics.Box_Cox`):**

- `Box_Cox (x, 0.0)` agrees with `Log (x)` to 1 × 10⁻¹⁰ for `x` in {0.01, 1.0, 100.0, 10000.0}.
- `Box_Cox (x, 1.0) = x − 1.0` to 1 × 10⁻¹⁰ for the same `x` values.
- `Box_Cox (x, 0.5) = (Sqrt (x) − 1.0) / 0.5` to 1 × 10⁻¹⁰.
- Round-trip: `Box_Cox_Inverse (Box_Cox (x, λ), λ) = x` to 1 × 10⁻⁸ for a
  5 × 5 grid of `x` ∈ {1, 10, 100, 1000, 10000} and `λ` ∈ {−1.0, 0.0, 0.5, 1.0, 2.0}.
- `Box_Cox (0.0, 0.0)` raises `Constraint_Error`.
- `Estimate_Lambda` on a 20-sample log-normal dataset (generated by
  `Exp (Normal_Sample)` for a known normal sequence) returns λ within 0.2 of 0.0.
- `Estimate_Lambda` on a 20-sample normal dataset (x > 0, already normal) returns
  λ within 0.2 of 1.0.
- `Estimate_Lambda` with fewer than 3 values returns 0.0 without raising.
- I-chart limits with Box-Cox (λ = 0): for a 5-session setup interval with known
  log-normal token totals, verify that back-transformed UCL and LCL match
  hand-computed values (`exp(mean_z ± 3*MR_bar_z/d2)`) to 4 decimal places.
- I-chart with Box-Cox (λ = 0): `Has_LCL` is `False` when the back-transformed
  LCL formula yields a value ≤ 0 (i.e. when the exponent is negative — which
  cannot happen for ln-transform since back-transform is `exp(z) > 0`; verify
  `Has_LCL = True` for the ln case).
- I-chart with Box-Cox, negative λ asymptote: construct a 5-session setup
  interval whose token totals, when transformed with λ = −0.5, yield a
  `UCL_z ≥ 2.0` (the domain ceiling `1/0.5`).  Verify `Has_UCL = False` and
  that `CL` and `LCL` (when `Has_LCL = True`) are finite positive values
  equal to `Box_Cox_Inverse (Grand_Mean_z, −0.5)` and
  `Box_Cox_Inverse (LCL_z, −0.5)` respectively to 4 decimal places.
- MR-chart with Box-Cox: limits are in transformed space; `Has_LCL = False` always.

**EWMA chart tests (`Coyote_SQC.Statistics.EWMA_Chart`):**

- `Compute_Z` single step: `Z_0 = 80.0`, `x_1 = 100.0`, `λ = 0.2` →
  `Z_1 = 84.0` to 1 × 10⁻¹⁰.
- `Compute_Z` multi-step: verify a two-step sequence (Z_0=100, x_1=110, x_2=90,
  λ=0.2) produces Z_1=102.0 and Z_2=99.6 to 1 × 10⁻¹⁰.
- `Compute_EWMA_Limits` at T=1: Grand_Mean=100, σ=10, λ=0.2, L=3.0 →
  UCL=106.0, CL=100.0, LCL=94.0, Has_UCL=True, Has_LCL=True, to 1 × 10⁻⁸.
- `Compute_EWMA_Limits` near steady state (T=1000): verify UCL and LCL converge
  to `Grand_Mean ± L·σ·√(λ/(2−λ))` within 0.001.
- Zero sigma: `Compute_EWMA_Limits` with σ=0.0 → Has_UCL=False, Has_LCL=False.
- LCL clamping: Grand_Mean=1, σ=5, λ=0.5, L=3.0, T=1 → raw LCL = -6.5;
  verify LCL is clamped to 0.0 and Has_LCL=False, UCL=8.5, Has_UCL=True.
- Workspace round-trip: `EWMA_Weight=0.15` and `EWMA_L=2.75` survive save/load
  to within 0.001.
- Version migration: a workspace JSON file with `"version": 3` and no
  `ewmaWeight`/`ewmaL` fields migrates each EWMA chart to the default per-chart settings (EWMA_Weight = 0.2, EWMA_L = 3.0).
- Zero-session exclusion: a value array containing 0.0 passed to `Box_Cox`
  raises `Constraint_Error`; `Recompute_Chart` with a session having zero tokens
  excludes that session and posts a notice without raising.
- Correct `Total_Thinking_Tokens`, `Total_Tool_Call_Input_Tokens`, and `Total_Tool_Call_Result_Tokens` metric computation: `Coyote_SQC.Metrics.Compute` applied to a session with three turns — where two turns have thinking tokens (12 and 24), and two turns each contain one tool call with estimated input/output token counts (5/8 and 3/12) — returns `Total_Thinking_Tokens = 36`, `Total_Tool_Call_Input_Tokens = 8`, `Total_Tool_Call_Result_Tokens = 20`.
- I chart limits for new session-total charts: for each of the three new I chart kinds (`Session_Thinking_Tokens_I`, `Session_Tool_Call_Tokens_I`, `Session_Tool_Call_Result_Tokens_I`), apply `Compute_I_Limits` to a five-session setup interval with known totals; verify UCL, CL, and LCL match hand-computed §5.6 formula values to 4 decimal places.
- MR chart limits for new session-total charts: verify `Compute_MR_Limits` output for the three new MR chart kinds against the same five-session dataset.
- EWMA independence for new EWMA charts: verify that `Recompute_Chart` for `Session_Thinking_Tokens_EWMA`, `Session_Tool_Call_Tokens_EWMA`, and `Session_Tool_Call_Result_Tokens_EWMA` independently computes the same `Grand_Mean` and `Mean_MR` as the corresponding I chart, derived from the same setup-interval observations.
- Zero-value exclusion for new I/MR charts: with Box-Cox enabled, sessions having zero `Total_Thinking_Tokens`, `Total_Tool_Call_Input_Tokens`, or `Total_Tool_Call_Result_Tokens` are excluded from the respective I chart and EWMA step counter, and a status-bar notice is posted.
- Session Turn Count I/MR limit computation: apply `Compute_I_Limits` and `Compute_MR_Limits` to a five-session setup interval with known `N_Turns` values; verify UCL, CL, and LCL match hand-computed §5.6 formula values to 4 decimal places.
- Session Turn Count EWMA independence: verify that `Recompute_Chart` for `Session_Turn_Count_EWMA` independently computes the same `Grand_Mean` and `Mean_MR` as `Session_Turn_Count_I`, derived from the same setup-interval observations.
- Session Turn Count Box-Cox round-trip: `chartSettings` per-chart configuration for Session Turn Count charts (enabled, lambda source, fixed λ) survives workspace save/load unchanged.
- Session Turn Count Box-Cox version migration: a workspace file at version ≤ 6 migrates the old `turnCountBoxCox` field to per-chart entries; absent field yields per-chart default (disabled, auto, λ=0.0).
- Session Turn Count Box-Cox — N_Turns=1 non-exclusion: with `Chart_Settings(Session_Turn_Count_I).Box_Cox.Enabled = True` and a setup interval containing sessions with `N_Turns = 1`, verify no session is excluded and no status-bar notice is posted (since `Box_Cox(1.0, λ) = 0.0` is valid for all λ).
- Session Turn Count Box-Cox — MR̄=0 degenerate: with all setup sessions having `N_Turns = 1` and Box-Cox active, verify `Mean_MR_Z = 0.0`, no limits are drawn, and no exception is raised.

**Robust estimation tests (`Coyote_SQC.Tests.Statistics.Robust`):**

- `Median_Of` on a five-element sorted array returns the middle element
  to 1 × 10⁻¹⁰.
- `Median_Of` on a four-element array returns the mean of the two middle
  elements to 1 × 10⁻¹⁰.
- `Median_Of` on a one-element array returns that element.
- `Median_Of` on an empty array returns 0.0 without raising.
- Robust I chart sigma: for a five-session dataset containing one outlier
  session, verify `Grand_Mean = Median_Of(observations)` and
  `σ = Qn_Scale(observations) / 2.2219`; confirm both diverge from the
  corresponding classical estimates.  Verify `Compute_I_Limits` uses this σ
  to produce UCL and LCL matching hand-computed `Median ± 3 × σ` to 4
  decimal places.
- Robust MR chart UCL: for the same five-session dataset, verify
  `UCL_MR = D4 × Median_Of(w_i)` where `w_i = Box_Cox(MR_i, λ_MR)`; confirm
  this differs from `D4 × Mean_Of(w_i)` (classical path).
- Robust Xbar/s Grand_Mean: for a four-session dataset with one outlier
  session, verify `Grand_Mean = Median_Of(session_means)` and that this
  differs from the size-weighted classical grand mean.
- Robust Xbar/s Pooled_S: for the same dataset, verify `Pooled_S =
  Qn_Scale(pooled_residuals)` where residuals are `x_{i,j} − x̄_i`;
  confirm the result differs from the classical pooled standard deviation.
- Robust estimation with Box-Cox active: verify that with both features
  enabled, `Estimate_Parameters` receives transformed values and applies
  the robust estimators to those transformed values.
- p-charts unaffected: `Estimate_Parameters` with `Estimation_Method =
  Robust_Median` and a p-chart `Chart_Kind` returns `Grand_P = Σd / Σn`
  (identical to classical mode).
- EWMA with robust I chart parameters: verify that the EWMA chart uses
  `Grand_Mean (robust)` as `Z_0` and `σ = Qn_Scale(z_i) / 2.2219` in the
  limit formula; verify that time-varying limit values match hand-computed
  values using those robust parameters to 1 × 10⁻¹⁰.
- Per-chart estimation method round-trip: `Chart_Settings(Session_Input_Tokens_I).Estimation_Method = Robust_Median` survives workspace save/load unchanged (appears as `"estimationMethod": "robust_median"` inside the `chartSettings."Session_Input_Tokens_I"` JSON object).
- Version migration: a workspace JSON file with `"version": 6` and `"estimationMethod": "robust_median"` broadcasts `Robust_Median` to all chart kinds on load; the resulting `chartSettings` map contains one entry per I/MR and Xbar/s chart kind.


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


### 14.6 Quantile Control Chart Tests — `Coyote_SQC.Tests.Statistics.Quantile_CC`

- `Compute_Quantiles` with a known sorted 10-element array returns correct
  R type 7 values for all five quantiles to 1 × 10⁻¹⁰.
- `Compute_Quantiles` with n = 1 returns all five quantiles equal to the single
  value.
- `Build_Distribution` for a three-session pool with known values and n_i = 5
  produces a bootstrap distribution with B = 100 000 entries per quantile
  statistic; verify the limit ranks agree with the Bonferroni_Rank
  and UCL_Rank constants (Bonferroni α_B/2 = 0.00027).
- `Build_Distribution` with a single-session pool (only within-session
  variability) still produces valid limits without raising an exception.
- `Build_Distribution` seeding: each subgroup size `n_i` receives an
  independent stream (effective seed = base_seed + n_i); two calls with
  the same pool and `n_i` produce identical limits for all five statistics.
  (54 321) produce identical limits for all five statistics.
- `Extract_Limits` returns correct UCL_j, LCL_j, and CL_j from a known sorted
  bootstrap distribution vector to 1 × 10⁻¹⁰.
- `Is_OOC` returns `True` when a value strictly exceeds UCL or is strictly
  below LCL; returns `False` when the value is within `[LCL, UCL]`.
- `Session_Is_OOC` returns `True` when any single component is out-of-control;
  returns `False` when all five are in-control.
- `OOC_Components` returns an array where only the out-of-control positions
  are `True`.
- Cache: after the first call to `Build_Distribution` for a given n_i,
  subsequent calls for the same n_i return the cached distribution without
  recomputation.
- Cache invalidation: after a call to `Clear_Cache`, the next
  `Build_Distribution` recomputes the distribution.

### 14.7 Quantile Control Chart Rendering Tests — `Coyote_SQC.Tests.Chart_Canvas`

- Component widths: a session with n_i = 10 renders five horizontal line
  segments at the correct y-positions, with the median having the greatest
  half-width (14 px), Q1/Q3 having medium half-width (10 px), and min/max
  having the narrowest half-width (6 px).
- Component coloring: an in-control session with no comment renders black
  lines and gray lozenges; adding a comment changes both to green for
  in-control components; an OOC component with no comment renders red;
  an OOC component with a comment renders orange.
- Setup interval halo: a session in the setup interval receives a yellow
  ring drawn outside the bounding box of the full diagram.
- Selection halo: a selected session receives a blue (Set A) or orange
  (Set B) ring outside the bounding box.
- Log Y mode with zero/negative values: components whose UCL, LCL, or
  statistic is ≤ 0 are skipped and do not cause an exception.
*End of document.*
Note: Box_Cox_Inverse requires (for λ ≠ 0) that Z*λ + 1 > 0 for any transformed value Z being inverted. If this condition is not met the inverse raises Constraint_Error. When back-transform of UCL or CL fails the implementation must provide a visible explanation (status bar or popup) and one of the documented fallback behaviours: choose an alternate valid lambda, fall back to λ = 0 (log), or render limits in transformed units with a clear label. The application MUST NOT silently omit control limits without notifying the user.

