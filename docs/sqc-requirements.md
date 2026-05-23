# SQC/SPC Companion Application — Requirements Document

**Project:** Coyote Session Quality Control  
**Version:** 0.1 (draft)  
**Date:** 2026-05-21  
**Status:** In progress

---

## Table of Contents

1. [Purpose and Scope](#1-purpose-and-scope)
2. [Glossary](#2-glossary)
3. [System Overview](#3-system-overview)
4. [Data Model](#4-data-model)
5. [Statistical Methods](#5-statistical-methods)
6. [Charts](#6-charts)
7. [UI Layout and Navigation](#7-ui-layout-and-navigation)
8. [Chart Interaction](#8-chart-interaction)
9. [Point Selection](#9-point-selection)
10. [Detail Panel](#10-detail-panel)
11. [Setup Interval](#11-setup-interval)
12. [Comments](#12-comments)
13. [Workspace Management](#13-workspace-management)
14. [Session Replay Rendering](#14-session-replay-rendering)
15. [Non-Functional Requirements](#15-non-functional-requirements)

---

## 1. Purpose and Scope

This document specifies the requirements for a Statistical Quality Control (SQC) /
Statistical Process Control (SPC) companion application for the Coyote coding agent.
The application ingests Coyote session data, computes control chart statistics, and
presents an interactive GTK GUI for process monitoring, investigation, and annotation.

The application is a standalone executable, separate from Coyote itself, but shares
the session file format and, where practical, rendering code.

---

## 2. Glossary

**Session**  
A single Coyote session, initiated with one user prompt and comprising one or more
turns. Sessions are the unit of observation; each session corresponds to exactly one
point on every chart.

**Turn**  
A single LLM completion within a session — one request/response cycle. A session
contains one or more turns. Turns with tool calls may be followed by further turns
that process the tool results.

**Thinking turn**  
A turn in which the model produced a non-zero number of thinking tokens.

**Tool-call turn**  
A turn in which the model generated one or more tool calls.

**Tool call failure**  
Any of the following outcomes for an individual tool call: non-zero exit code from
the shell tool; a parsing error on the model-generated tool call input; an exception
raised during tool execution; or any error response returned by the tool to the model.

**Subgroup**  
The set of turns within a single session. The subgroup size `n` is the number of
turns in that session.

**Point**  
A single plotted marker on a chart, representing one session.

**Control limits**  
The upper control limit (UCL) and lower control limit (LCL) computed from the setup
interval. For Xbar/s charts the limits are ±3σ from the center line. For p-charts the
limits are ±3 standard deviations of the binomial proportion.

**Center line**  
The estimated process mean or proportion, computed from the setup interval.

**Setup interval**  
The user-designated set of sessions used to estimate the center line and control
limits for a given chart. Setup interval points are assumed to represent the process
operating in a stable, in-control state.

**Out-of-control point**  
A point whose statistic falls outside the control limits (3-sigma rule only).

**Workspace**  
The top-level container for the SQC application. A workspace stores: the set of
source directories and model filters, all chart setup intervals, and all session and
turn-level comments. Workspaces are stored as files in a user-chosen location.

**Source directory**  
A filesystem path that was the working directory when one or more Coyote sessions
were recorded. Corresponds to Coyote's concept of a "project directory."

**Session replay**  
A read-only rendered view of a session's conversation — assistant text, thinking
blocks, and tool call frames — as rendered in the Coyote GUI.

---

## 3. System Overview

The application is a native Ada/GTK3 executable. It reads Coyote session JSONL files
from one or more source directories, aggregates session-level and turn-level metrics,
and presents them as interactive SPC control charts.

The application does not write to or modify Coyote session files. All application
state (workspace definition, chart setup intervals, comments) is stored in a separate
workspace file.

### 3.1 Relationship to Coyote

The application depends on Coyote session data but is architecturally decoupled from
Coyote's session file format through a defined internal data model (Section 4). If the
Coyote session format changes, only the parser that populates the internal data model
requires updating; chart logic, statistics, and the UI are unaffected.

Session replay rendering reuses a shared Ada package extracted from the Coyote GUI
renderer, rather than duplicating the rendering code. See Section 14.

### 3.2 Executable Name

The executable shall be named `coyote_sqc`.

---

## 4. Data Model

This section defines the application's internal data model. All downstream logic
(statistics, charts, UI) operates on this model, not on raw session files.

### 4.1 Session Record

One record per Coyote session.

| Field | Type | Description |
|---|---|---|
| `Session_Id` | UUID string | Coyote session UUID |
| `Start_Time` | Ada.Calendar.Time | Timestamp of the first turn |
| `Source_Directory` | String | Working directory when session was recorded |
| `Model` | String | Model identifier used for the session |
| `First_User_Message` | Unbounded_String | Full text of the first user message |
| `Total_Input_Tokens` | Natural | Sum of input tokens across all turns |
| `Total_Output_Tokens` | Natural | Sum of output tokens across all turns |
| `Turns` | Vector of Turn_Record | Ordered sequence of turns in the session |

### 4.2 Turn Record

One record per LLM completion within a session.

| Field | Type | Description |
|---|---|---|
| `Turn_Index` | Positive | 1-based position within the session |
| `Input_Tokens` | Natural | Input tokens for this turn |
| `Output_Tokens` | Natural | Output tokens for this turn |
| `Thinking_Tokens` | Natural | Thinking tokens produced (0 if thinking disabled) |
| `Thinking_Enabled` | Boolean | Whether thinking was active for this turn |
| `Tool_Calls` | Vector of Tool_Call_Record | Tool calls made in this turn (may be empty) |

### 4.3 Tool Call Record

One record per tool call within a turn.

| Field | Type | Description |
|---|---|---|
| `Tool_Name` | String | Name of the tool invoked |
| `Input_Tokens` | Natural | Tokens consumed in the tool call input |
| `Output_Tokens` | Natural | Tokens consumed in the tool result |
| `Failed` | Boolean | True if the tool call resulted in any failure (see Glossary) |

### 4.4 Session Metrics Record

Derived from a Session_Record. Computed once at load time and cached.

| Field | Type | Description |
|---|---|---|
| `Session_Id` | UUID string | Foreign key to Session_Record |
| `N_Turns` | Positive | Number of turns in the session |
| `N_Tool_Call_Turns` | Natural | Turns containing at least one tool call |
| `N_Thinking_Turns` | Natural | Turns with Thinking_Tokens > 0 |
| `N_Tool_Calls` | Natural | Total tool calls across all turns |
| `N_Failed_Tool_Calls` | Natural | Tool calls where Failed = True |
| `Any_Thinking` | Boolean | True if any turn had Thinking_Enabled = True |
| `Per_Turn_Input_Tokens` | Vector of Natural | Input token count per turn |
| `Per_Turn_Output_Tokens` | Vector of Natural | Output token count per turn |
| `Per_Turn_Tool_Tokens` | Vector of Natural | Tool call token total per turn |
| `Per_Turn_Thinking_Tokens` | Vector of Natural | Thinking token count per thinking-enabled turn only |
| `N_Thinking_Turns_For_Chart` | Natural | Count of thinking-enabled turns (denominator for thinking chart) |

### 4.5 Comment Record

| Field | Type | Description |
|---|---|---|
| `Comment_Id` | UUID string | Unique identifier |
| `Session_Id` | UUID string | Session this comment is attached to |
| `Timestamp` | Ada.Calendar.Time | When the comment was created |
| `Text` | Unbounded_String | Comment body |

### 4.6 Workspace Record

| Field | Type | Description |
|---|---|---|
| `Workspace_Id` | UUID string | Unique identifier |
| `Name` | Unbounded_String | Human-readable workspace name |
| `Source_Directories` | Vector of String | Source directory paths to scan for sessions |
| `Model_Filter` | Vector of String | Included model identifiers; empty means all models |
| `Setup_Session_Ids` | Set of UUID string | Sessions comprising the workspace setup interval; empty if not yet established |
| `Comments` | Vector of Comment_Record | All comments for this workspace |

### 4.7 Chart Definition Record

| Field | Type | Description |
|---|---|---|
| `Chart_Type` | Chart_Type enum | Identifies which of the nine charts this defines |

---

## 5. Statistical Methods

### 5.1 General Principles

- The only out-of-control rule applied is the 3-sigma rule: a point is out-of-control
  if its statistic falls strictly outside the UCL or below the LCL.
- Control limits are variable: they are computed individually for each point using
  that session's actual subgroup size `n`, not an average `n`. This produces a
  stepped, non-straight control limit series.
- Center lines are also variable where the underlying estimator depends on `n`
  (p-charts, s-chart). The center line is plotted as a connected series of
  per-point values.
- All limit and center-line parameters are estimated exclusively from the sessions
  in the setup interval. Points outside the setup interval are evaluated against
  those fixed parameters.
- If no setup interval has been set, the application displays retrospective limits
  computed from all currently visible sessions (subject to the active date range
  filter). Retrospective limits are displayed in gray with a "retrospective limits"
  label to distinguish them from formally established control limits.

### 5.2 Xbar/s Chart Formulas

Let the setup interval contain `k` sessions. For session `i`, let `n_i` be the number
of turns and `x_{i,j}` be the value of the measured quantity for turn `j`.

**Session mean:**

    x̄_i = (1/n_i) Σ_j x_{i,j}

**Session standard deviation (sample):**

    s_i = sqrt( (1/(n_i−1)) Σ_j (x_{i,j} − x̄_i)² )

    (Undefined for n_i = 1; see Section 5.5.)

**Grand mean (center line for Xbar chart):**

    x̄̄ = (Σ_i n_i * x̄_i) / (Σ_i n_i)

**Pooled standard deviation estimate:**

    s̄ = sqrt( (Σ_i (n_i−1) * s_i²) / (Σ_i (n_i−1)) )

**Xbar control limits for point i (n = n_i):**

    UCL_x̄(i) = x̄̄ + 3 * s̄ / (c4(n_i) * sqrt(n_i))
    LCL_x̄(i) = x̄̄ − 3 * s̄ / (c4(n_i) * sqrt(n_i))

**s chart center line for point i:**

    CL_s(i) = c4(n_i) * s̄

**s chart control limits for point i:**

    UCL_s(i) = s̄ * (c4(n_i) + 3 * sqrt(1 − c4(n_i)²))
    LCL_s(i) = max(0,  s̄ * (c4(n_i) − 3 * sqrt(1 − c4(n_i)²)))

where `c4(n)` is the standard unbiasing constant for the sample standard deviation.

### 5.3 p-Chart Formulas

Let the setup interval contain `k` sessions. For session `i`, let `n_i` be the
subgroup size (total tool calls or total turns, depending on chart) and `d_i` be the
count of the event of interest (failures, tool-call turns, or thinking turns).

**Proportion for session i:**

    p_i = d_i / n_i

**Grand proportion (center line):**

    p̄ = (Σ_i d_i) / (Σ_i n_i)

**Control limits for point i:**

    UCL_p(i) = p̄ + 3 * sqrt( p̄*(1−p̄) / n_i )
    LCL_p(i) = max(0, p̄ − 3 * sqrt( p̄*(1−p̄) / n_i ))

### 5.4 c4 Constant

The `c4(n)` unbiasing constant shall be computed using the exact formula:

    c4(n) = sqrt(2/(n−1)) * Γ(n/2) / Γ((n−1)/2)

A lookup table covering `n` from 2 to 100 shall be precomputed at application
startup; values for `n > 100` shall use the approximation `c4(n) ≈ 1 − 1/(4(n−1))`.

### 5.5 Special Cases

**Single-turn sessions (n = 1) on Xbar/s charts:**  
The session mean `x̄_i` is plotted on the Xbar chart. The session is excluded from
the pooled standard deviation estimate. No marker is plotted on the s chart for this
session; a gap is left in the s chart connecting line. The Xbar chart marker for this
session is rendered as a hollow circle to indicate the absence of a variance estimate.
Single-turn sessions within the setup interval contribute their value to the grand
mean but not to the pooled standard deviation.

**Sessions with n_i = 0 on p-charts:**  
Sessions with a zero subgroup size (e.g., zero tool calls on the tool call failure
rate chart) are excluded from the chart entirely — no marker is plotted and they do
not contribute to setup interval estimation.

**Thinking token chart — zero-thinking sessions:**  
Sessions where no turn had `Thinking_Enabled = True` are excluded from the Xbar/s
thinking token chart's limit estimation and are shown as hollow gray circle markers
to indicate "thinking was off" rather than "thinking produced zero tokens." Sessions
where thinking was enabled but all thinking-enabled turns produced zero thinking
tokens are plotted normally as zero.

For the thinking token chart, the Xbar statistic is the mean thinking token count
computed over **thinking-enabled turns only**. The subgroup size `n_i` is the count
of thinking-enabled turns in the session, not the total turn count.

---

## 6. Charts

Nine charts are available in every workspace. They are pre-instantiated; the user does
not create or delete charts. All charts share a single workspace-level setup interval
(see Section 11).

### 6.1 Turn Token Consumption — Xbar Chart

**Measured quantity:** output tokens per turn.  
**Subgroup:** turns within a session.  
**Subgroup size n:** total turns in the session.  
**Statistic:** mean output tokens per turn (x̄).

### 6.2 Turn Token Consumption — s Chart

**Measured quantity:** output tokens per turn.  
**Subgroup:** turns within a session.  
**Subgroup size n:** total turns in the session.  
**Statistic:** sample standard deviation of output tokens across turns (s).

### 6.3 Tool Call Token Consumption — Xbar Chart

**Measured quantity:** total tokens consumed per turn by tool calls (input + output
of all tool calls within that turn).  
**Subgroup:** turns within a session.  
**Subgroup size n:** total turns in the session.  
**Statistic:** mean tool call token consumption per turn (x̄).  
**Note:** Turns with no tool calls contribute a value of 0 to the subgroup.

### 6.4 Tool Call Token Consumption — s Chart

**Measured quantity:** total tokens consumed per turn by tool calls.  
**Subgroup:** turns within a session.  
**Subgroup size n:** total turns in the session.  
**Statistic:** sample standard deviation of tool call token consumption across turns (s).  
**Note:** Turns with no tool calls contribute a value of 0 to the subgroup.

### 6.5 Thinking Token Consumption — Xbar Chart

**Measured quantity:** thinking tokens per thinking-enabled turn.  
**Subgroup:** thinking-enabled turns within a session.  
**Subgroup size n:** count of thinking-enabled turns in the session.  
**Statistic:** mean thinking tokens per thinking-enabled turn (x̄).  
**Zero-thinking sessions:** excluded from limits; shown as hollow gray markers.

### 6.6 Thinking Token Consumption — s Chart

**Measured quantity:** thinking tokens per thinking-enabled turn.  
**Subgroup:** thinking-enabled turns within a session.  
**Subgroup size n:** count of thinking-enabled turns in the session.  
**Statistic:** sample standard deviation of thinking tokens across thinking-enabled turns (s).  
**Zero-thinking sessions:** excluded from limits; shown as hollow gray markers.

### 6.7 Tool Call Failure Rate — p-Chart

**Event:** a tool call resulted in a failure (see Glossary §2).  
**Subgroup size n:** total tool calls in the session.  
**Proportion p:** failed tool calls / total tool calls.  
**Sessions with n = 0:** excluded (no marker plotted).

### 6.8 Fraction of Tool-Call Turns — p-Chart

**Event:** a turn contained at least one tool call.  
**Subgroup size n:** total turns in the session.  
**Proportion p:** tool-call turns / total turns.

### 6.9 Fraction of Thinking Turns — p-Chart

**Event:** a turn had Thinking_Enabled = True.  
**Subgroup size n:** total turns in the session.  
**Proportion p:** thinking-enabled turns / total turns.

---

## 7. UI Layout and Navigation

### 7.1 Window Structure

The main window contains, from top to bottom:

1. **Menu bar** — File, Workspace, View menus (see Section 7.5).
2. **Toolbar** — date/time range pickers and zoom reset buttons.
3. **Three-panel content area** — left panel, chart area, detail panel, separated by
   draggable GtkPaned splitters.

### 7.2 Left Panel

A GtkListBox (~180px default width, user-resizable) listing the nine charts in two
visually separated groups:

```
Token Consumption
─────────────────
Turn Tokens — Xbar
Turn Tokens — s
Tool Call Tokens — Xbar
Tool Call Tokens — s
Thinking Tokens — Xbar
Thinking Tokens — s

Rates
─────────────────
Tool Call Failure Rate
Fraction: Tool-Call Turns
Fraction: Thinking Turns
```

Clicking a row switches the chart displayed in the chart area. The active chart is
highlighted. Switching charts does not affect the current point selection.

### 7.3 Chart Area

The chart area displays the currently selected chart. All charts occupy the full
chart area height.

#### 7.3.1 Axes

- **X-axis:** tick labels are formatted as `YYYY-MM-DD HH:MM` in both scale modes
  (see Section 7.3.5). Tick density decreases gracefully as the visible range is
  compressed.
- **Y-axis:** the chart statistic. Label shows the quantity and units.

#### 7.3.2 Chart Elements

The following elements are rendered in this z-order (bottom to top):

1. **Setup interval band:** a faint yellow filled rectangle spanning the x-extent of
   the setup interval sessions, drawn behind all other elements.
2. **Connecting line:** a thin black polyline threading through all plotted points in
   chronological order.
3. **Control limit series:** red dashed line segments connecting the per-point UCL
   values; a second series for LCL. Where the LCL is zero (clamped), the lower limit
   line is omitted.
4. **Center line series:** a solid blue polyline connecting the per-point center line
   values.
5. **Point markers:** filled or hollow circles (see Section 7.3.3).
6. **Selection halos:** rendered on top of point markers (see Section 9).

#### 7.3.3 Point Marker Colors

| Condition | Marker |
|---|---|
| In-control, no comment | Filled black circle |
| Out-of-control, no comment | Filled red circle |
| In setup interval (any control status) | Filled yellow circle |
| Out-of-control, comment present | Filled orange circle |
| In setup interval, out-of-control | Filled yellow circle (yellow takes precedence) |
| Selected | Blue halo ring drawn around the marker, regardless of fill |
| Zero-thinking excluded (Section 5.5) | Hollow gray circle |
| Single-turn session on Xbar chart (Section 5.5) | Hollow black circle |
| Single-turn session on s chart | No marker; gap in connecting line |

#### 7.3.4 Retrospective Limits

When no setup interval has been established, control limits are computed
retrospectively from all sessions currently visible in the date range. The control
limit series is rendered in gray (rather than red) and a small text label
"retrospective limits" is displayed near the upper control limit line. The center line
is also gray. This state is purely visual; no setup interval is stored.

#### 7.3.5 X-Axis Scale Modes

Two x-axis scale modes are available and toggled via **View → X-Axis: Run Sequence**
(a checkable menu item):

**Time Scale** (default)
Each session's x-position is proportional to its absolute `Start_Time`. Horizontal
spacing reflects actual elapsed wall-clock time between sessions; a cluster of
sessions run on the same afternoon appears bunched together while a gap spanning
weeks appears as wide blank space.

**Run Sequence**
Each session is assigned a 1-based integer run index in chronological order; that
integer is used as its x-coordinate. All plotted points are spaced equally regardless
of the actual time gaps between them. Tick labels on the x-axis continue to display
datetimes: each tick is labeled with the `Start_Time` of the session at (or nearest
to) that index position, formatted as `YYYY-MM-DD HH:MM`.

*Run index assignment:* indices are global — assigned once across all sessions in the
workspace, sorted by `Start_Time`. Sessions excluded by the date filter are hidden but
retain their index numbers; visible sessions may therefore be non-consecutively
numbered. This prevents jarring index renumbering when the date range changes.

*Toolbar pickers in run-sequence mode:* the From/To datetime pickers continue to
filter by calendar time. Changing a picker hides or reveals sessions based on their
`Start_Time`; their run indices are unchanged. The pickers are updated to show the
`Start_Time` of the first and last *visible* sessions when the view is panned or
zoomed.

*Setup interval band:* in run-sequence mode the faint yellow rectangle spans the
run-index extent of the setup interval sessions rather than their time extent.

*Persistence:* the selected scale mode is not stored in the workspace file; it resets
to **Time Scale** each time the application starts.

### 7.4 Toolbar

```
[From: YYYY-MM-DD HH:MM ▼]  [To: YYYY-MM-DD HH:MM ▼]  [Show All]  [Y-Fit]  [Run Sequence ☐]
```

- **From / To pickers:** GtkEntry with a GtkCalendar popover and time spinners.
  Changing either end adjusts the visible x-range of the chart without discarding
  data. The pickers update live during pan operations. In Run Sequence mode the
  pickers show the `Start_Time` of the first and last visible sessions.
- **Show All:** resets the x-range to the full extent of all sessions in the
  workspace (subject to model filter).
- **Y-Fit:** rescales the y-axis to fit all points currently visible in the x-range,
  with a 10% margin above and below.

### 7.5 Menu Bar

**File**
- New Workspace…
- Open Workspace…
- Recent Workspaces ▶
- Save Workspace        `Ctrl+S`
- Save Workspace As…
- ─
- Quit                  `Ctrl+Q`

**Workspace**
- Workspace Settings…   (edit name, source directories, model filter)
- Reload Sessions       (re-scan source directories)

**View**
- Show All
- Y-Fit
- ─
- Clear Selection
- Clear Setup Interval  (grayed out if not established)
- ─
- X-Axis: Run Sequence  (checkable; toggles between Time Scale and Run Sequence modes; see Section 7.3.5)

---

## 8. Chart Interaction

### 8.1 Zoom

- **Mouse wheel on chart area:** zooms the x-axis, centered on the cursor position.
  The From/To toolbar pickers update to reflect the new range.
  In Run Sequence mode, mouse-wheel zoom operates in index units (one "zoom step"
  expands or contracts the visible index range, keeping equal spacing between points).
  The From/To toolbar pickers update to show the datetimes of the new boundary
  sessions.
- **Mouse wheel on y-axis area of a sub-chart:** zooms that sub-chart's y-axis
  independently, centered on the cursor y position.

### 8.2 Pan

- **Click-and-drag on chart background** (no point within selection radius):
  pans both axes simultaneously. The From/To pickers update live during drag. In Run
  Sequence mode, pan operates in index units; the pickers update to show the datetimes
  of the boundary sessions.

### 8.3 Point Hover

When the cursor is within 6 pixels of a point marker, a GtkPopover tooltip is shown
anchored to that marker. The tooltip contains:

```
2025-04-12 14:32  •  anthropic/claude-sonnet-4-5
~/Projects/myapp

"Refactor the authentication module to use..."

Input: 24,831 tokens   Output: 6,204 tokens

Comments: 1
```

Fields:
- Datetime formatted as `YYYY-MM-DD HH:MM` in local time.
- Model identifier.
- Source directory (home directory abbreviated to `~`).
- Truncated first user message, max 80 characters, ellipsis appended if truncated.
- Total input and output tokens for the session.
- Comment count (omitted if zero).

The tooltip is dismissed when the cursor moves beyond 12 pixels from the point.

### 8.4 Y-Fit Button

Rescales the visible y-range to fit all points currently within the x-range, with a
10% margin.

---

## 9. Point Selection

### 9.1 Selection Mechanics

| Action | Effect |
|---|---|
| Click a point | Replace selection with this point; open detail panel |
| Shift+click a point | Add point to selection (or deselect if already selected) |
| Shift+drag a box | Add all points within the box to the current selection |
| Click empty chart area | Clear selection; close detail panel |

Selected points are rendered with a blue halo ring drawn around their marker,
regardless of the marker's fill color.

### 9.2 Selection Persistence

The selection is **persistent across chart switches.** When the user switches to a
different chart in the left panel, the same set of sessions remains selected and their
markers are highlighted on the new chart. A session that was excluded from the new
chart (e.g., zero-tool-call session on the failure rate chart) is not visible, but
remains in the selection; it reappears as selected if the user switches back to a
chart where it is plotted.

### 9.3 Selection State in Detail Panel

When the selection contains exactly one point, the detail panel shows the
single-session view (Section 10.1). When the selection contains two or more points,
the detail panel shows the multi-select view (Section 10.2). When the selection is
empty, the detail panel is hidden (collapsed to zero width).

---

## 10. Detail Panel

The detail panel is a GtkScrolledWindow occupying the right column of the three-panel
layout. Its default width is 380px; it is user-resizable via the GtkPaned splitter.
It is hidden when the selection is empty.

### 10.1 Single-Session View

Displayed when exactly one point is selected.

**Header section:**
- Datetime (local time, `YYYY-MM-DD HH:MM:SS`)
- Model identifier
- Source directory
- Total input tokens / total output tokens

**Prompt section:**
- Label: "Prompt"
- Full text of the first user message in a read-only GtkTextView with word wrap.

**Session Replay section:**
- Label: "Session Replay"
- A read-only scrollable GtkTextView rendered using the shared session renderer
  (Section 14). Renders assistant text (with markdown), thinking blocks, and tool
  call frames. The full session is rendered; the view is independently scrollable
  within the detail panel.

**Comments section:**
- Label: "Comments"
- Chronological list of existing comments for this session, each showing the
  comment timestamp and text.
- A GtkTextView entry field for a new comment.
- An "Add Comment" button. On click, the comment is saved to the workspace with the
  current timestamp and the point marker color is updated immediately if applicable.

### 10.2 Multi-Select View

Displayed when two or more points are selected.

**Summary header:**
- Count of selected sessions (e.g., "12 sessions selected").
- Date range of selected sessions (earliest to latest, `YYYY-MM-DD`).

**Set as Setup Interval button:**
- Clicking this button sets the workspace setup interval to exactly the selected
  sessions, applying to all nine charts simultaneously.
- If a setup interval is already established, a confirmation dialog is shown:
  "Replace existing setup interval for this workspace?"
- On confirmation, all charts recompute their limits and recolor the setup interval
  points yellow.
- The setup interval is saved to the workspace file immediately.

**Bulk Comment section:**
- Label: "Add Comment to All Selected"
- A GtkTextView entry field.
- An "Add Comment to All" button. On click, the comment text is saved as a separate
  Comment_Record for each selected session, all sharing the same timestamp.

**Selected Sessions list:**
- A scrollable GtkListBox listing each selected session with columns:
  datetime, model (abbreviated), source directory (abbreviated).
- Clicking any row in this list switches the detail panel to the single-session view
  for that session without clearing the overall selection.

---

## 11. Setup Interval

### 11.1 Establishing a Setup Interval

A setup interval is a single workspace-level set of sessions used to estimate the
center line and control limits for all nine charts simultaneously. It is established
by selecting one or more sessions (Section 9) and clicking "Set as Setup Interval"
in the multi-select detail panel (Section 10.2). There is no requirement for the
setup sessions to be contiguous in time.

### 11.2 Setup Interval Storage

The setup interval is stored as a set of session UUIDs in the `Setup_Session_Ids`
field of the `Workspace_Record`. It is workspace-level: a single setup interval
applies to all nine charts. The set is stored within the workspace file.

### 11.3 Visual Representation

Setup interval sessions are rendered with filled yellow markers on all nine charts.
A faint yellow vertical band spans the x-extent of the setup interval sessions on
every chart.

### 11.4 Setup Interval Integrity

When the workspace model filter or source directory list is changed, the application
checks the workspace setup interval against the new filtered session set. If any
session in the setup interval is no longer present in the filtered data:

1. A dialog is shown stating the number of setup sessions that would be removed by
   the filter change.
2. The user is given the option to: (a) revert the filter change, or (b) proceed,
   which clears the workspace setup interval.
3. A cleared setup interval reverts all charts to retrospective limits.

### 11.5 Clearing a Setup Interval

The workspace setup interval can be cleared via View → Clear Setup Interval (grayed
out if no setup interval is established). A confirmation dialog is shown. On
confirmation, all charts revert to retrospective limits.

---

## 12. Comments

### 12.1 Comment Granularity

Comments are attached to sessions (a whole session, identified by session UUID).
Comments are workspace-scoped — they are stored in the workspace file and not written
to Coyote session files.

### 12.2 Comment Display

In the single-session detail panel, all comments for the session are listed
chronologically. There is no cap on the number of comments per session.

### 12.3 Effect on Point Color

A point that is out-of-control and has at least one comment is rendered orange rather
than red. This allows annotated anomalies to be visually distinguished from
uninvestigated anomalies.

### 12.4 Comment Visibility in Hover Tooltip

If a session has one or more comments, the hover tooltip (Section 8.3) shows a
"Comments: N" line. The comment text itself is not shown in the tooltip; full comment
text is visible in the detail panel.

---

## 13. Workspace Management

### 13.1 Workspace File Format

Workspace files are stored as JSON. The file format is versioned with a top-level
`"version"` field. The application shall refuse to open workspace files with a version
higher than it supports, and shall display an appropriate error message.

### 13.2 Workspace File Location

Workspace files are stored in a user-chosen location. There is no enforced location;
the user selects the path via the standard file chooser dialog when creating or saving
a workspace. Recent workspaces are remembered in a per-user application configuration
file stored at `~/.config/coyote_sqc/config.json`.

### 13.3 Source Directories

A workspace references one or more source directories. The application scans each
source directory for Coyote session JSONL files at startup and on Workspace →
Reload Sessions. Subdirectories are not scanned recursively — only the specified
directory itself is scanned.

Sessions from all source directories are pooled into a single ordered sequence sorted
by session start time.

### 13.4 Model Filter

The workspace model filter is a list of model identifier strings. When the filter list
is non-empty, only sessions using a model in the list are loaded and displayed. When
the filter list is empty (the default), all models are included.

### 13.5 Workspace Settings Dialog

Accessible via Workspace → Workspace Settings…. Contains:
- Workspace name field.
- List of source directories with Add and Remove buttons. The Add button opens a
  directory chooser dialog.
- Model filter section: a list of model identifiers with Add (text entry) and Remove
  buttons, plus a "Include all models" checkbox that clears and disables the list.

Changes take effect on clicking OK, at which point sessions are reloaded and the
setup interval integrity check (Section 11.4) is performed.
---

## 14. Session Replay Rendering

### 14.1 Shared Renderer Package

The session replay renderer shall be implemented as a standalone Ada package,
`Coyote_Renderer`, that is compiled into both the Coyote GUI application and
`coyote_sqc`. This package encapsulates:

- Markdown to Pango markup conversion (via libcmark-gfm with GFM extensions).
- Thinking block rendering (collapsible or inline, matching Coyote GUI appearance).
- Tool call frame rendering as embedded GtkFrame widgets via GtkTextChildAnchor.
- Text tag definitions for thinking, notices, and footers.

The package takes a `Session_Record` as input and populates a `GtkTextBuffer`. It
operates in read-only mode; no editing callbacks are attached.

### 14.2 Rendering in the Detail Panel

The session replay GtkTextView in the single-session detail panel is populated by
calling `Coyote_Renderer.Render_Session`. The buffer is replaced each time a new
session is selected. Rendering is performed on the GTK main loop thread to avoid
threading issues with GtkTextBuffer.

### 14.3 Dependency

`coyote_sqc` depends on `libcmark-gfm` and the GTK3 binding, consistent with the
main Coyote application.

---


### 14.4 Tool Call Detail Window

Each tool call frame rendered in the session replay (§10.1) shall be an
interactive widget. Clicking the widget once opens a **tool call detail
window** for that tool call.

#### 14.4.1 Window type and multiplicity

The detail window is a non-modal `GtkWindow` declared transient for the main
application window. Multiple detail windows may be open simultaneously; each
is independent. A detail window closes only when the user clicks its close
button; it is not closed automatically when the point selection changes or
the main window is navigated.

#### 14.4.2 Window title

The window title shall be formatted as:

```
⚙ tool_name — Turn N — YYYY-MM-DD HH:MM
```

where `tool_name` is the tool's name, `N` is the 1-based turn index within
the session, and the datetime is the session start time in local time. If the
tool call's status is resolved at render time, the gear icon is replaced with
✓ (success), ✗ (error), or `-` (cancelled).

#### 14.4.3 Header section

Below the window title bar, a non-editable header section displays:

- Session datetime (local time, `YYYY-MM-DD HH:MM:SS`)
- Model identifier
- Source directory (home directory abbreviated to `~`)
- Turn number and position of this tool call within the turn
  (e.g. `Turn 3, call 2 of 4`)

#### 14.4.4 Arguments section

The arguments section renders one labelled subsection per top-level field of
the tool call's arguments JSON object, in the order the fields appear in the
JSON. Each subsection consists of a bold field-name header followed by a
read-only, selectable, scrollable `GtkTextView` containing the decoded string
value of the field. All text uses a monospace font. If the arguments value is
not a JSON object, the raw argument string is shown in a single unlabelled
`GtkTextView`.

#### 14.4.5 Result section

The result section is headed by a coloured status banner:

- Green background: `✓ success`
- Red background: `✗ error`
- Gray background: `- cancelled`

Below the banner, a read-only, selectable, scrollable `GtkTextView` displays
the full result text with no truncation, in a monospace font.

If the tool call result is an image (i.e. the tool was invoked with a
`media_type` argument), the result section displays an embedded `GtkImage`
widget decoded from the base64 result rather than a `GtkTextView`.

#### 14.4.6 Layout

The window contains, from top to bottom: header section, arguments section,
result section. Each `GtkTextView` is wrapped in a `GtkScrolledWindow`. The
overall window is itself scrollable if the content exceeds the window height.
A minimum window size of 600 × 400 px is enforced.

#### 14.4.7 Selectability

All text in the window — header fields, argument values, result text — shall
be selectable and copyable by the user.

#### 14.4.8 Render-time data capture

The data required to populate the detail window (tool name, arguments, result
text, status, turn index, call position within the turn, and session metadata)
shall be captured in the clickable widget's callback closure at session render
time. No re-parsing of the session file shall occur when the window is opened.

## 15. Non-Functional Requirements

### 15.1 Language and Toolchain

The application shall be implemented in Ada 2022 using GNAT/GCC. The build system
shall be Alire (`alr`) with a GPRbuild project file.

### 15.2 GUI Toolkit

The GUI shall use GTK3 via the existing Ada GTK binding used in the Coyote project.

### 15.3 Data Model Decoupling

All logic that reads Coyote JSONL session files shall be isolated in a single parser
package (`Coyote_SQC.Session_Parser`). No chart, statistics, or UI package shall
reference the session file format directly. This ensures that a change to the Coyote
session file format requires changes only in `Coyote_SQC.Session_Parser`.

### 15.4 Performance

The application shall load and display charts for a workspace containing up to 10,000
sessions within 5 seconds on a modern workstation, using the session cache
(Section 13.6). Chart re-render on zoom/pan shall complete within 50ms.

### 15.5 Coding Conventions

The application shall follow the same Ada style conventions as the Coyote project:
two-space indentation, `--  double-dash` comments, `.ads`/`.adb` spec/body split,
`Unbounded_String` for variable-length stored strings, `UC_*` constants for Unicode
glyphs.

### 15.6 Testing

All statistical formula implementations shall have AUnit unit tests covering:
- Correct Xbar/s limit computation for known datasets.
- Correct p-chart limit computation for known datasets.
- Special cases: n=1 sessions, n=0 sessions, zero-thinking sessions.
- c4 constant accuracy against a reference table for n = 2..25.

---

*End of document.*
