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
| `Total_Input_Tokens` | Natural | Total context window tokens for the session, normalized across providers (see §4.8) |
| `Total_Output_Tokens` | Natural | Sum of output tokens across all turns |
| `Total_Cache_Read_Tokens` | Natural | Sum of cache-read tokens across all turns |
| `Total_Cache_Write_Tokens` | Natural | Sum of cache-write tokens across all turns |
| `Total_Uncached_Input_Tokens` | Natural | Input tokens neither served from cache nor written to cache; equal to `Total_Input_Tokens − Total_Cache_Read_Tokens − Total_Cache_Write_Tokens` |
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
| `Input_Tokens` | Natural | Estimated tokens consumed in the tool call input; derived from the serialised `arguments` JSON string length ÷ 4 (0 if arguments are absent) |
| `Output_Tokens` | Natural | Estimated tokens consumed in the tool result; derived from the result text length ÷ 4 (0 if no matching tool result has been recorded) |
| `Failed` | Boolean | True if the tool call resulted in any failure (see Glossary) |
| `Arguments` | Unbounded_String | Raw JSON argument string; stored at parse time for JSD similarity computation (§5.12) |

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
| `N_Tool_Call_Turns_For_Chart` | Natural | Count of tool-call turns (denominator for tool-call token chart) |
| `Total_Cache_Read_Tokens` | Natural | Total cache-read tokens for the session |
| `Total_Cache_Write_Tokens` | Natural | Total cache-write tokens for the session |
| `Total_Thinking_Tokens` | Natural | Sum of thinking tokens across all turns |
| `Total_Tool_Call_Input_Tokens` | Natural | Sum of tool call input-token estimates across all tool calls in all turns |
| `Total_Tool_Call_Result_Tokens` | Natural | Sum of tool call result-token estimates across all tool calls in all turns |
| `Total_Uncached_Input_Tokens` | Natural | Uncached input tokens for the session (`Total_Input_Tokens − Total_Cache_Read_Tokens − Total_Cache_Write_Tokens`) |
| `Per_Consecutive_Tool_S` | Vector of Long_Float | Per-argument JSD similarity values across all consecutive tool-call pairs; see §5.12 |
| `N_Consecutive_Tool_Pairs` | Natural | Number of eligible consecutive pairs (T−1 for T non-empty tool calls; 0 when T ≤ 1) |

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
| `Chart_Settings` | Map of Chart_Kind → Chart_Settings_Record | Per-chart configuration (Box-Cox transformation, estimation method, EWMA parameters); see §4.7a. Charts at default settings are omitted from the map. |

### 4.7 Chart Definition Record

| Field | Type | Description |
|---|---|---|
| `Chart_Type` | Chart_Type enum | Identifies which of the fifty-one charts this defines |

---

### 4.7a Chart Settings Record

One `Chart_Settings_Record` exists per chart in the `Chart_Settings` map of
`Workspace_Record`. Charts using entirely default settings need not appear in
the map; absent entries are treated as all-default.

| Field | Type | Description |
|---|---|---|
| `Box_Cox` | Box_Cox_Config | Box-Cox transformation configuration for this chart; see §5.7. Default: disabled, Auto mode, fixed λ = 0.0. |
| `Estimation_Method` | Estimation_Method_Kind | Whether to use classical or robust location/scale estimators for this chart's control limits; see §5.11. Default: `Classical`. p-charts always use the classical grand proportion regardless of this setting. |
| `EWMA_Weight` | Long_Float | Smoothing weight λ ∈ (0.0, 1.0] for EWMA charts only; ignored for all other chart kinds. Default: 0.2. |
| `EWMA_L` | Long_Float | Sigma multiplier L ∈ [1.0, 4.0] for EWMA charts only; ignored for all other chart kinds. Default: 3.0. |

---

### 4.8 Token Accounting Normalization

Different LLM providers use incompatible conventions for the `input_tokens`
field in their usage records:

- **Anthropic:** `input_tokens` reports only the *non-cached* fraction of the
  prompt. Cache-hit tokens (`cache_read_input_tokens`) and cache-fill tokens
  (`cache_creation_input_tokens`) are reported separately and are **not** included
  in `input_tokens`.
- **OpenAI:** `prompt_tokens` reports the *total* prompt token count, which
  **includes** any cached subset (`prompt_tokens_details.cached_tokens`).

To make `Total_Input_Tokens` comparable across providers, the application
normalises it to a common definition: **total tokens submitted to the model's
context window**, regardless of whether they were served from cache.

| Provider | Stored value of `Total_Input_Tokens` |
|---|---|
| Anthropic | `input_tokens + cache_read_input_tokens + cache_creation_input_tokens` |
| OpenAI | `prompt_tokens` (already the total; no change needed) |

`Total_Cache_Read_Tokens` and `Total_Cache_Write_Tokens` are stored with their
original provider semantics and are **not** altered by this normalization.

`Total_Uncached_Input_Tokens` is derived as
`Total_Input_Tokens − Total_Cache_Read_Tokens − Total_Cache_Write_Tokens` and
represents the tokens billed at full price (not served from, and not written
to, the cache). For Anthropic this equals the raw `input_tokens`; for OpenAI
this equals `prompt_tokens − cached_tokens`.


## 5. Statistical Methods
### Box-Cox back‑transform safety

Because the lambda search is restricted to [0.0, 30.0], the UCL
back-transform condition (Z·λ + 1 > 0) is structurally guaranteed for
all λ ≥ 0 when data are strictly positive: no runtime fallback or UI
notice is required for invertibility failures.  The only case where
limits are omitted is degenerate data (all setup-interval values
identical), which sets `Fallback_Used = True` and returns λ = 0.0; a
unit test must exercise this case and verify that no limits are drawn
and no exception is raised.

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

### 5.6 Individuals (I) and Moving-Range (MR) Chart Formulas

Session-level totals (`Total_Input_Tokens`, `Total_Output_Tokens`) are single
scalar observations per session; there is no within-session subgroup to average.
An Individuals (I) chart plots each value directly, and its companion Moving-Range
(MR) chart tracks the absolute difference between consecutive session values.

Let the setup interval contain `k` sessions ordered chronologically. Let `x_i` be
the session-level value (total input or output tokens) for session `i`.

**Moving ranges:**

    MR_i = |x_i − x_{i-1}|   for i = 2, 3, …, k

The first session in the setup interval contributes no moving range.

**Mean moving range:**

    MR̄ = (1/(k−1)) Σ_{i=2}^{k} MR_i

**I-chart center line:**

    x̄ = (1/k) Σ_{i=1}^{k} x_i

**I-chart control limits (same for every point):**

    UCL_I = x̄ + 3 × MR̄ / d2
    LCL_I = max(0, x̄ − 3 × MR̄ / d2)

where `d2 = 1.128` (the standard factor for a moving range of span 2).

**MR-chart center line:**

    CL_MR = MR̄

**MR-chart control limits:**

    UCL_MR = D4 × MR̄   (D4 = 3.267 for span 2)
    LCL_MR = 0 always   (Has_LCL is always False)

**Special cases:**

- A setup interval of exactly one session cannot produce any moving ranges
  (`k = 1 → MR̄` undefined). In this case no limits are drawn; the chart
  displays retrospective limits computed from all visible sessions instead.
- When `MR̄ = 0` (all setup-interval sessions have the same token total),
  no limits are drawn.
- The first session in the visible range has no predecessor; it is excluded
  from the MR chart (no marker, gap in the connecting line), exactly as
  single-turn sessions are excluded from the s chart.
- Sessions are always ordered chronologically for moving-range computation,
  regardless of the x-axis scale mode (Time Scale or Run Sequence).


### 5.7 Box-Cox Transformation for I/MR Charts

Token count observations (session input and output totals) are strictly positive
and typically right-skewed. Applying a Box-Cox transformation before computing I
and MR chart limits corrects skewness, produces limits that better reflect the
true process distribution, and reduces false out-of-control signals.

The Box-Cox family is parameterised by λ:

    y(x, λ) = (x^λ − 1) / λ   for λ ≠ 0
    y(x, 0) = ln(x)            for λ = 0

The transformation applies to all eight Session Token I/MR chart pairs
(`Session_Input_Tokens_I`, `Session_Input_Tokens_MR`,
`Session_Output_Tokens_I`, `Session_Output_Tokens_MR`,
`Session_Cache_Read_Tokens_I`, `Session_Cache_Read_Tokens_MR`,
`Session_Cache_Write_Tokens_I`, `Session_Cache_Write_Tokens_MR`,
`Session_Thinking_Tokens_I`, `Session_Thinking_Tokens_MR`,
`Session_Tool_Call_Tokens_I`, `Session_Tool_Call_Tokens_MR`,
`Session_Tool_Call_Result_Tokens_I`, `Session_Tool_Call_Result_Tokens_MR`,
`Session_Uncached_Input_Tokens_I`, `Session_Uncached_Input_Tokens_MR`).
Each I and MR chart has its own independent Box-Cox configuration, accessible
via the Chart Settings dialog (see §13.6).

**Lambda source:** λ may be estimated automatically from the setup-interval
data or specified as a fixed value. Three modes are available,
selected in the Chart Settings dialog (§13.6):

- **Auto-estimate (MLE)** — estimates λ by maximising the Box-Cox profile
  log-likelihood, equivalent to minimising log(Var[y(λ)]) after the Jacobian
  correction. Optimal when the setup-interval data is free of outliers.
- **Auto-estimate (robust)** — estimates λ by replacing the variance in the
  profile log-likelihood with the Qₙ scale estimator (Rousseeuw & Croux 1993):
  `Ŝ_Qₙ = c · d_{(h)}`, where `d_{(h)}` is the `h`-th order statistic of all
  `C(N, 2)` pairwise absolute differences `|y_i − y_j|`,
  `h = C(⌊N/2⌋ + 1, 2)`, and the consistency constant `c = 2.2219`
  (asymptotic); finite-sample corrections from Rousseeuw & Croux (1993) Table 1
  are applied for N ≤ 9. Qₙ has a 50% breakdown point and 82% Gaussian
  efficiency — robust to outliers while well-calibrated on clean data.
- **Fixed** — uses a user-specified λ directly. Common values: 0 (ln),
  0.5 (square root), 1 (identity, no transform).

Both auto modes require at least three setup-interval sessions; fewer
falls back to λ = 0.  Lambda is searched in [0.0, 30.0] (negative
values are not meaningful for positive token-count data); a coarse
grid at step 0.5 locates the global maximum basin, then Brent's method
(Brent 1973) refines to tolerance 1e-6 within ±0.5 of the coarse best.

**I chart display:** limits are computed in the transformed space and
back-transformed to original (token) units for display. The resulting UCL and
LCL are asymmetric around the center line, reflecting the skewness correction.

**MR chart display:** moving range values are the original-space absolute
differences `MR_i = |x_i − x_{i-1}|`, plotted without transformation. Each
MR chart has its own independent Box-Cox transformation: `λ_MR` is estimated
from the setup-interval `MR_i` series (excluding zero-valued entries); CL and
UCL are computed in the transformed MR space and back-transformed exactly to
original (token) units via `Box_Cox_Inverse`. The y-axis is labelled in
original (token) units. A status-bar notice reports the count of zero MR
values excluded from `λ_MR` estimation when transformation is active.

**Histogram display:** when Box-Cox is active and an I or MR chart is selected,
the multi-select distribution histogram shows the original-space value distribution.
The overlay lines (CL, UCL, LCL) are the back-transformed limits, also in original-space units.

**Sessions with zero tokens:** any session with a zero total-token count cannot
be transformed (ln(0) is undefined). Such sessions are excluded from the I and
MR charts and from λ estimation when transformation is enabled; a status-bar
notice reports the count of excluded sessions.

**Storage:** each chart's configuration is stored in the workspace `chartSettings` JSON map (see §13.1). The estimated λ (when using an auto mode) is a transient runtime value recomputed on setup-interval change and is not persisted.


### 5.8 Box-Cox Transformation for Xbar/S Charts

Per-turn token counts are strictly positive and typically right-skewed. A Box-Cox
transformation may be applied before computing Xbar and s chart limits to improve
normality and reduce false out-of-control signals. The same Box-Cox family as §5.7
is used (parameterised by λ).

The transformation applies to all eight per-turn Xbar/S charts:
`Turn_Tokens_Xbar`, `Turn_Tokens_S`, `Tool_Call_Tokens_Xbar`,
`Tool_Call_Tokens_S`, `Thinking_Tokens_Xbar`, `Thinking_Tokens_S`,
`Tool_Call_JSD_Xbar`, `Tool_Call_JSD_S`.

**Per-pair lambda in auto mode:** when the lambda source is Auto-estimate (MLE)
or Auto-estimate (robust), λ is estimated independently for each chart pair
(Turn, Tool Call, Thinking, JSD) from that pair's flattened setup-interval per-turn
values using the same algorithm as §5.7 (MLE or Qₙ robust, respectively). Turn,
Tool Call, Thinking, and JSD similarity values can therefore have different estimated λ values.
Fewer than three eligible turn values falls back to λ = 0.

**Shared lambda in fixed mode:** in fixed mode, a single user-specified λ applies
to all three chart pairs.

**Lambda source and configuration:** each Xbar/S chart has its own independent Box-Cox configuration, accessible via the Chart Settings dialog (§13.6).

**Xbar chart display:** the per-turn values for each session are transformed to
z-space; the session mean `z̄_i = mean(z_{i,j})` is computed and
back-transformed: `x̄_i_BC = Box_Cox_Inverse(z̄_i, λ)`. This back-transformed
value is plotted on the Xbar chart and compared against back-transformed limits,
so the y-axis remains in original (token) units.

**s chart display:** the sample standard deviation of the transformed values,
`s_i_Z = StdDev(z_{i,j})`, is plotted. This value is not back-transformable to
token units; the y-axis is in transformed units when Box-Cox is active.

**Grand mean and pooled s in transformed space:** `Grand_Mean_Z` is the
size-weighted grand mean of the per-session `z̄_i` values estimated from the
setup interval; `Pooled_S_Z` is the pooled standard deviation of the `z_{i,j}`
values. These override the standard grand mean and pooled s used by the Xbar and
s chart limit formulas (§5.2), which then operate entirely in z-space.

**Xbar limit back-transformation:** UCL_Z, CL_Z, and LCL_Z from the z-space
Xbar formula are each back-transformed to original units. If a limit's back-
transformation fails (domain violation for the given λ), it is suppressed
(`Has_UCL = False` etc.) while the remaining limits are still drawn. CL back-
transform failure excludes the session point entirely.

**s chart limits:** computed from `Pooled_S_Z` using the standard s chart formula
(§5.2); stored and displayed in transformed units without back-transformation.

**Subgroup values of zero:** any per-turn value of 0 (token charts) or ≤ 0.0
(JSD charts, where S_k = 0.0 arises when an argument is entirely absent on one
side) cannot be transformed.  Such values are excluded from λ estimation.
Sessions containing any such value are excluded from Box-Cox chart display and
λ estimation; a status-bar notice reports the count of excluded values.

**Storage:** each chart's configuration is stored in the workspace `chartSettings` JSON map (see §13.1). Estimated λ values are transient runtime values recomputed from the setup interval and not persisted.

### 5.12 Consecutive Tool Call Similarity — JSD Statistic

The JSD-based similarity statistic quantifies the compositional similarity
between pairs of adjacent tool calls within a session.  High values indicate
the two calls are nearly identical (potential looping); low values indicate
diversity.  The statistic uses the Jensen-Shannon divergence (Grosse et al.,
Phys. Rev. E 65, 041905, 2002) with length-proportional weights, which is the
unique weighting that simultaneously minimises estimator variance and makes the
finite-sample bias independent of string length.

#### Tokenization

For a consecutive pair (call_i, call_{i+1}), argument fields are compared
independently rather than pooled into a single token sequence.  For each key
in the **union** of both calls' top-level JSON argument fields (plus a
synthetic `tool_name` key), a token sequence is produced as follows:

1. For the `tool_name` key: tokens are the whitespace-split, lowercased words
   of the tool name string.
2. For each JSON argument key: parse the `Arguments` JSON object; extract all
   string-valued leaf content for that key (recursively for nested objects and
   arrays); whitespace-split and lowercase to produce the token sequence.
3. A key absent from one call is treated as having an empty token sequence
   (zero tokens) on that side.

A call with no string-valued arguments contributes only the `tool_name`
comparison; this is treated identically to a call where every argument key is
absent — no special boundary exclusion applies.

#### Per-Argument Similarity S_k

For each key _k_ in the union of both calls' argument sets (including
`tool_name`), with token frequency vectors f^(1)_k and f^(2)_k:

```
n₁_k = token count for key k in call_i
n₂_k = token count for key k in call_{i+1}
N_k  = n₁_k + n₂_k
```

- If N_k = 0 (key has no string content in either call): no observation is
  produced for key k; the key is skipped.
- If exactly one side has zero tokens (key present in one call but absent or
  empty in the other): S_k = 0.0 is appended.
- If both sides have tokens: S_k is computed via the full JSD formula:

```
π^(1)_k = n₁_k/N_k,   π^(2)_k = n₂_k/N_k
k_eff_k = |vocab_k(call_i) ∪ vocab_k(call_{i+1})|

D_k    = H[π^(1)_k·f^(1)_k + π^(2)_k·f^(2)_k]
         − π^(1)_k·H[f^(1)_k] − π^(2)_k·H[f^(2)_k]
D_bc_k = D_k − (k_eff_k − 1)/(2·N_k·ln2)
S_k    = N_k·(1 − D_bc_k) = N_k·(1 − D_k) + (k_eff_k − 1)/(2·ln2)
```

where H[p] = −Σ pᵢ log₂ pᵢ (Shannon entropy in bits).

Each S_k satisfies σ²(S_k) = O(1) independent of N_k (Grosse et al. 2002,
§IV.B) because length-proportional weights are used within each per-argument
comparison.  Comparing arguments independently preserves the O(1) variance
property for every observation; pooling all argument tokens into one value
would inflate variance to O(K) where K is the number of keys, breaking the
poolability justification for the Xbar/s chart.

#### Session Subgroup and Chart Types

For a consecutive pair (call_i, call_{i+1}), all computed S_k values are
appended in order (`tool_name` first, then JSON argument keys in source order)
to the session's `Per_Consecutive_Tool_S` vector.

For a session with T non-empty tool calls (calls that contribute at least one
S_k observation), the subgroup vector `Per_Consecutive_Tool_S` has length
n = Σᵢ Kᵢ, where Kᵢ is the number of non-skipped keys for pair i.
`N_Consecutive_Tool_Pairs` = T − 1.

This subgroup drives the Xbar/s chart pair (§6.37–6.38) using the standard
Xbar and s chart formulas (§5.2) with per-point variable-n control limits,
where n is the length of `Per_Consecutive_Tool_S` for that session.

**Exclusion rules:**
- Sessions with T ≤ 1 non-empty tool calls: `N_Consecutive_Tool_Pairs` = 0;
  excluded entirely from both charts; no marker plotted.
- Sessions with subgroup size n = 1 (single per-argument observation): plotted
  as a hollow circle on the Xbar chart; no s marker.

Box-Cox transformation may optionally be applied to the
`Tool_Call_JSD_Xbar` and `Tool_Call_JSD_S` chart pair; see §5.8.
Subgroup values of 0.0 (absent arguments) are excluded from both the chart
and λ estimation when Box-Cox is active.

### 5.13 Session Total JSD Similarity — I/MR/EWMA Scalar

The session-level **total JSD similarity** is defined as the sum of all
per-argument S_k values accumulated across every consecutive tool call pair
in the session:

```
Total_Tool_Call_JSD_S = Σ Per_Consecutive_Tool_S
```

This collapses the subgroup vector used by the Xbar/s charts (§5.12) into a
single scalar per session, suitable for an Individuals (I) chart, its
companion Moving-Range (MR) chart, and an EWMA chart — the same triplet used
for all other session-level totals.

**Observation:** one positive-real scalar per session.  
**Exclusion:** sessions with `N_Consecutive_Tool_Pairs = 0` (≤ 1 non-empty
tool calls) are excluded; no marker is plotted.  
**Limits (I chart):** derived from the mean moving range of the setup
interval (§5.6).  Box-Cox transformation is not applied (S_k values are
already well-behaved with O(1) variance by construction — Grosse et al. 2002,
§IV.B — so the transformation provides no benefit here).  
**MR chart:** `MR_i = |Total_Tool_Call_JSD_S_i − Total_Tool_Call_JSD_S_{i-1}|`;
sessions without consecutive pairs are skipped and do not advance the MR
sequence.  
**EWMA chart:** independently computes Grand_Mean and σ from the same
setup-interval observations as the corresponding I chart.



### 5.14 Kolmogorov-Smirnov Goodness-of-Fit Tests

The multi-select detail panel runs two one-sample KS tests against the
contributing selected sessions' active-chart statistics.

#### KS Normality Test

Null hypothesis: the sample is drawn from a Normal(μ, σ) distribution where
μ and σ are estimated from the data (composite hypothesis).

1. Sort the N values: x₁ ≤ x₂ ≤ … ≤ xₙ.
2. Compute μ̂ = mean(xᵢ) and σ̂ = sample standard deviation.
3. KS statistic: D = max over i of max(|i/N − Φ((xᵢ − μ̂)/σ̂)|,
   |(i−1)/N − Φ((xᵢ − μ̂)/σ̂)|), where Φ is the standard normal CDF.
4. Asymptotic p-value: Q(D√N) using the Kolmogorov distribution complement
   Q(z) = 2 Σ_{k=1}^∞ (−1)^{k−1} exp(−2k²z²).

Returns `N/A` when N < 3 or σ̂ = 0 (degenerate sample).

Note: because parameters are estimated from the data, the true critical
values are closer to the Lilliefors distribution than the standard KS table;
the asymptotic p-value is conservative (slightly high) in small samples.

#### KS Exponential Test

Null hypothesis: the sample is drawn from an Exponential(λ) distribution
where λ = 1/mean(xᵢ) is estimated from the data.

Same algorithm as the normality test, substituting the exponential CDF
F(x) = 1 − exp(−λ̂·x) for Φ.

Returns `N/A` when N < 3 or mean ≤ 0.

### 5.15 Wald-Wolfowitz Runs Test for Randomness

Tests whether the contributing selected sessions' statistics, in their
**chronological order**, form an independent, random sequence.

Algorithm:

1. Compute the median M of all N values.
2. Scan the values in chronological order; assign each to `above` (value > M)
   or `below` (value < M); skip ties (values equal to M).
3. Let n₁ = count of `above`, n₂ = count of `below`, R = number of runs
   (maximal consecutive same-group subsequences).
4. Under the null hypothesis of independence:
   - E[R] = 2n₁n₂/(n₁+n₂) + 1
   - Var[R] = 2n₁n₂(2n₁n₂ − n₁ − n₂) / ((n₁+n₂)²(n₁+n₂−1))
5. Z = (R − E[R]) / √Var[R]; two-sided p = 2·Φ(−|Z|).

Returns `N/A` when N < 10 or when n₁ = 0 or n₂ = 0 (all values on one
side of the median, e.g. all identical).

**Interpretation:** a low p-value (e.g. < 0.05) suggests the observations
are not independent — either too few runs (trending or clustered pattern) or
too many runs (oscillating pattern).

## 6. Charts

### 5.9 EWMA Chart for Session Totals

An Exponentially Weighted Moving Average (EWMA) chart complements each of the four
Session Token I charts by providing more sensitive detection of small, sustained
shifts in session-level token totals.

**Statistic.** The EWMA statistic at step _t_ is:

```
Z_t = λ · x_t + (1 − λ) · Z_{t−1},   Z_0 = Grand_Mean
```

where `x_t` is the session-level observation, `λ` is the smoothing weight
(default 0.2, range 0.01–1.00), and `Z_0` is the process target (the grand mean
estimated from the setup interval for this chart kind).  Smaller `λ` weights
recent observations less and gives more smoothing; `λ = 1` reduces to the raw I
chart.

**Control limits.** The limits at step _t_ are time-varying:

```
UCL_t / LCL_t = Grand_Mean ± L · σ · √( λ/(2−λ) · [1 − (1−λ)^{2t}] )
```

where `σ = MR̄ / d2` (`d2 = 1.128`) is the process-sigma estimate for this chart kind,
and `L` is the sigma multiplier (default 3.0, range 1.00–4.00).
The limits converge asymptotically to the steady-state values
`Grand_Mean ± L · σ · √(λ/(2−λ))`.  The LCL is clamped to 0.

**Parameter estimation.** Each EWMA chart independently computes `Grand_Mean` and
`Mean_MR` (hence σ) from the same setup-interval observations as the corresponding
I chart, using identical formulas (§5.6). Because the computation is deterministic,
the results are always equal. No cached state is read from another chart's computed
results.

**Step counter.** The step counter _t_ advances only for non-excluded sessions.
When Box-Cox is active, sessions with a zero token total are excluded and do not
advance _t_.

**Box-Cox (Option B).** When the chart's Box-Cox configuration is enabled, the EWMA
recursion is performed in z-space (transformed values) and the plotted statistic and
each limit are back-transformed individually to original (token) units for display.
If back-transformation of the plotted value fails, the session is excluded.  If
back-transformation of `UCL_z` fails, `Has_UCL` is set to `False`; `CL` and `LCL`
are still drawn.  The y-axis is in original (token) units.

**Configuration.** The smoothing weight `λ` and sigma multiplier `L` are per-EWMA-chart settings, accessible and configurable in the Chart Settings dialog (§13.6). They are stored in the workspace `chartSettings` JSON map.

### 5.10 Box-Cox Transformation for Turn Count I/MR/EWMA Charts

Session turn count (`N_Turns`) is a positive integer that can be right-skewed
across sessions — short, focused sessions and long, exploratory sessions
co-exist in a typical workspace. A Box-Cox transformation may be applied before
computing I, MR, and EWMA chart limits to improve normality and reduce false
out-of-control signals.

**Per-chart configuration.** Each Session Turn Count chart has its own independent Box-Cox configuration (§4.9), accessible via the Chart Settings dialog (§13.6). This allows turn count to be transformed with a different λ from token-count or Xbar/S charts, and to be independently toggled.

**Lambda source.** The same three lambda-source modes as §5.7 are available
(Auto-estimate (MLE), Auto-estimate (robust), Fixed), selected via a drop-down
in the Chart Settings dialog (§13.6). Auto modes require at least three setup-interval sessions
with `N_Turns ≥ 1`; fewer falls back to λ = 0.

**Sessions with N_Turns = 1.** A session with exactly one turn has a
positive value of 1, which is transformable (ln(1) = 0; (1^λ − 1)/λ = 0 for
all λ ≠ 0). Such sessions are **not** excluded from the Turn Count I/MR/EWMA
charts even when Box-Cox is active, because N_Turns is always ≥ 1 (i.e., no
zero-value exclusion applies). However, because the transformed value is
identically 0 regardless of λ, such sessions can still degenerate to MR̄ = 0
if all setup sessions happen to have one turn; the `MR̄ = 0` special case
(§5.6) applies.

**I chart display.** Limits are computed in the transformed space and
back-transformed to original (turn count) units for display. The resulting UCL
and LCL are asymmetric around the center line.

**MR chart display.** Moving range values are the original-space absolute
differences `MR_i = |N_i − N_{i-1}|`, plotted without transformation. The
Turn Count MR chart has its own independent Box-Cox transformation: `λ_MR` is
estimated from the setup-interval `MR_i` series (excluding zero-valued
entries); CL and UCL are computed in the transformed MR space and
back-transformed exactly to original (turn count) units via `Box_Cox_Inverse`.

**EWMA chart display.** When Box-Cox is active for this chart, the
EWMA recursion is performed in z-space (transformed values) and the plotted
statistic and each limit are back-transformed individually to original
(turn-count) units for display, following the same Option B logic as §5.9.

**Storage.** Each chart's configuration is stored in the workspace `chartSettings` JSON map (see §13.1).


### 5.11 Robust Control Limit Estimation

All chart families normally estimate their center lines and process scale using
classical arithmetic estimators (grand mean, pooled standard deviation, mean
moving range). These estimators can be materially distorted by a small number
of unusual sessions in the setup interval. A per-chart **Estimation
Method** option switches to robust alternatives.

Two methods are available, configurable in the Chart Settings dialog (§13.6):

- **Classical** (default) — all estimators as defined in §5.2–§5.6:
  size-weighted arithmetic grand mean, pooled sample standard deviation,
  arithmetic mean moving range. This matches traditional SPC practice and is
  recommended when the setup interval is known to be clean.
- **Robust (median/Qₙ)** — resistant estimators with a 50% breakdown point.
  Recommended when the setup interval may contain outlying sessions not
  representative of the process at its best.

Each chart independently uses classical or robust estimation. Behaviour by chart type is
described below.

**I/MR charts (§5.6):**

- **Center line** → **median** of the N setup-interval observations replaces
  the arithmetic mean. The median has a 50% breakdown point; the mean breaks
  down at 1/N.
- **I chart scale (σ)** → **Q_n(x_i) / 2.2219** replaces MR̄ / d₂. Q_n is
  applied to the N setup-interval observations (or their Box-Cox transforms
  when Box-Cox is active). Q_n has a 50% breakdown point and 82% Gaussian
  efficiency — consistent with the Qₙ estimator used for Xbar/s scale
  estimation and Box-Cox lambda estimation (§5.7). The classical motivation
  for deriving the I chart sigma from moving ranges (consistency with the
  paired MR chart) no longer applies since the I and MR charts now use
  independent Box-Cox transformations and sigma estimates.

- **MR chart UCL** → **D4 × median(w_i)** replaces D4 × MR̄_w in robust
  mode, where w_i = Box_Cox(MR_i, λ_MR) are the transformed MR values.
  Has_UCL = False when median(w_i) = 0.

**Xbar/s charts (§5.2):**

- **Grand mean (center line)** → **unweighted median of the per-session means**
  x̄_i replaces the size-weighted arithmetic grand mean. The unweighted median
  avoids the classical estimator being dominated by sessions with unusually many
  turns.
- **Scale** → **Qₙ of pooled within-session residuals** replaces pooled_s.
  The residuals are x_{i,j} − x̄_i (deviation from each session's own mean),
  pooled across all setup-interval sessions. Qₙ is applied to this pooled
  vector and the result used in place of pooled_s in the Xbar and s chart
  limit formulas (§5.2). The Qₙ consistency constant 2.2219 is calibrated for
  normally distributed inputs; within-session residuals are approximately
  normal, making this appropriate. Qₙ has 82% Gaussian efficiency —
  substantially higher than MAD (36.7%) — and is already implemented for
  robust Box-Cox lambda estimation (§5.7).

**p-charts (§5.3):**

p-chart parameter estimation is unchanged regardless of the estimation method
setting. The grand proportion p̄ = Σd / Σn is the standard estimator; robust
alternatives for proportions are not well-standardised in SPC practice and are
deferred.

**EWMA charts (§5.9):**

EWMA charts independently recompute `Grand_Mean` and σ from the same
setup-interval observations as the corresponding I chart (§5.9). When robust
estimation is enabled, `Grand_Mean` (→ median) and σ (→ Q_n(observations) / 2.2219)
are computed robustly from those same observations. Because the computation is
identical to the I chart and deterministic, the resulting values are always equal.
No cached state is read from another chart's computed results. When Box-Cox is also
active, robust estimation is applied to the transformed values (as for the
I chart), with no further special handling needed.

**Interaction with Box-Cox:**

The estimation method is orthogonal to Box-Cox transformation. When both are
active, the chosen estimator (classical or robust) operates on the
*transformed* values produced by the Box-Cox step. This is correct: the
transformation is designed to normalise the data before limit computation, so
the estimator always receives approximately normal inputs regardless of which
estimation method is selected.

**Minimum setup interval:**

The median and Qₙ estimators are well-defined for as few as 2 observations.
No additional minimum setup interval size is imposed beyond the minima already
specified for each chart type (§5.5, §5.6).

**Storage:** each chart's estimation method is stored in the workspace `chartSettings` JSON map (see §13.1).




Fifty-one charts are available in every workspace. They are pre-instantiated; the user does
not create or delete charts. All charts share a single workspace-level setup interval
(see Section 11).

### 6.1 Turn Token Consumption — Xbar Chart

**Measured quantity:** output tokens per turn.  
**Subgroup:** turns within a session.  
**Subgroup size n:** total turns in the session.  
**Statistic:** mean output tokens per turn (x̄).
**Limits:** derived from the grand mean and pooled standard deviation of the setup interval (§5.2). When Box-Cox transformation is enabled (§5.8), limits are computed in the transformed space and back-transformed to original (token) units for display.

### 6.2 Turn Token Consumption — s Chart

**Measured quantity:** output tokens per turn.  
**Subgroup:** turns within a session.  
**Subgroup size n:** total turns in the session.  
**Statistic:** sample standard deviation of output tokens across turns (s).
**Limits:** derived from the pooled standard deviation of the setup interval (§5.2). When Box-Cox transformation is enabled (§5.8), limits and the s statistic are displayed in transformed units.

### 6.3 Tool Call Token Consumption — Xbar Chart

**Measured quantity:** estimated tokens consumed per tool-call turn by tool calls (input + output of all tool calls within that turn).  
**Subgroup:** tool-call turns within a session.  
**Subgroup size n:** count of tool-call turns in the session.  
**Statistic:** mean tool call token consumption per tool-call turn (x̄).  
**Zero-tool-call sessions:** sessions where no turn contained a tool call are excluded from limit estimation and shown as hollow gray markers.
**Limits:** derived from the grand mean and pooled standard deviation of the setup interval (§5.2). When Box-Cox transformation is enabled (§5.8), limits are computed in the transformed space and back-transformed to original (token) units for display.

### 6.4 Tool Call Token Consumption — s Chart

**Measured quantity:** estimated tokens consumed per tool-call turn by tool calls (input + output of all tool calls within that turn).  
**Subgroup:** tool-call turns within a session.  
**Subgroup size n:** count of tool-call turns in the session.  
**Statistic:** sample standard deviation of tool call token consumption across tool-call turns (s).  
**Zero-tool-call sessions:** sessions where no turn contained a tool call are excluded from limit estimation and shown as hollow gray markers.
**Limits:** derived from the pooled standard deviation of the setup interval (§5.2). When Box-Cox transformation is enabled (§5.8), limits and the s statistic are displayed in transformed units.

### 6.5 Thinking Token Consumption — Xbar Chart

**Measured quantity:** thinking tokens per thinking-enabled turn.  
**Subgroup:** thinking-enabled turns within a session.  
**Subgroup size n:** count of thinking-enabled turns in the session.  
**Statistic:** mean thinking tokens per thinking-enabled turn (x̄).  
**Zero-thinking sessions:** excluded from limits; shown as hollow gray markers.
**Limits:** derived from the grand mean and pooled standard deviation of the setup interval (§5.2). When Box-Cox transformation is enabled (§5.8), limits are computed in the transformed space and back-transformed to original (token) units for display.

### 6.6 Thinking Token Consumption — s Chart

**Measured quantity:** thinking tokens per thinking-enabled turn.  
**Subgroup:** thinking-enabled turns within a session.  
**Subgroup size n:** count of thinking-enabled turns in the session.  
**Statistic:** sample standard deviation of thinking tokens across thinking-enabled turns (s).  
**Zero-thinking sessions:** excluded from limits; shown as hollow gray markers.
**Limits:** derived from the pooled standard deviation of the setup interval (§5.2). When Box-Cox transformation is enabled (§5.8), limits and the s statistic are displayed in transformed units.

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

### 6.10a Fraction of Thinking Tokens — I/MR/EWMA Charts

**Measured quantity:** ratio of thinking tokens to output tokens per session (`Total_Thinking_Tokens / Total_Output_Tokens`).
**Observation:** one scalar value per session; no within-session subgroup.
**Statistic (I chart):** the per-session ratio.
**Sessions with `Total_Output_Tokens = 0`:** excluded (ratio undefined; no marker plotted).
**Rationale:** thinking tokens arrive in correlated bursts, not as independent Bernoulli trials per output token; the ratio is right-skewed and overdispersed relative to the binomial distribution. An I chart is appropriate.
**Limits (I chart):** derived from the mean moving range of the setup interval (§5.6). Box-Cox transformation is not applied (ratio data is bounded and different from token count totals).
**MR chart:** `MR_i = |ratio_i − ratio_{i-1}|`; sessions with zero output tokens are skipped and do not contribute to the MR sequence.
**EWMA chart:** independently computes Grand_Mean and σ from the same setup-interval observations as the corresponding I chart.

### 6.10b Fraction of Tool-Call Tokens — I/MR/EWMA Charts

**Measured quantity:** ratio of tool-call input tokens to output tokens per session (`Total_Tool_Call_Input_Tokens / Total_Output_Tokens`).
**Observation:** one scalar value per session; no within-session subgroup.
**Statistic (I chart):** the per-session ratio.
**Sessions with `Total_Output_Tokens = 0`:** excluded (ratio undefined; no marker plotted).
**Rationale:** tool-call tokens are generated in discrete, correlated invocations; the binomial model does not apply. An I chart is appropriate.
**Limits (I chart):** derived from the mean moving range of the setup interval (§5.6). Box-Cox transformation is not applied.
**MR chart:** `MR_i = |ratio_i − ratio_{i-1}|`; sessions with zero output tokens are skipped.
**EWMA chart:** independently computes Grand_Mean and σ from the same setup-interval observations as the corresponding I chart.

### 6.10c Fraction: Thinking/Tool-Call Tokens — I/MR/EWMA Charts

**Measured quantity:** ratio of thinking tokens to tool-call input tokens per session (`Total_Thinking_Tokens / Total_Tool_Call_Input_Tokens`).
**Observation:** one scalar value per session; no within-session subgroup.
**Statistic (I chart):** the per-session ratio.
**Sessions with `Total_Tool_Call_Input_Tokens = 0`:** excluded (ratio undefined; no marker plotted).
**Rationale:** thinking tokens and tool-call tokens are both session-level scalars; their ratio is a continuous positive-valued quantity unsuitable for the binomial model. An I chart is appropriate.
**Limits (I chart):** derived from the mean moving range of the setup interval (§5.6). Box-Cox transformation is not applied (ratio data).
**MR chart:** `MR_i = |ratio_i − ratio_{i-1}|`; sessions with zero tool-call input tokens are skipped and do not advance the MR sequence.
**EWMA chart:** independently computes Grand_Mean and σ from the same setup-interval observations as the corresponding I chart.

### 6.10d Fraction: Uncached/Total Input Tokens — I/MR/EWMA Charts

**Measured quantity:** ratio of uncached input tokens to total input tokens per session (`Total_Uncached_Input_Tokens / Total_Input_Tokens`).
**Observation:** one scalar value per session; no within-session subgroup.
**Statistic (I chart):** the per-session ratio (a value in [0, 1] representing the fraction of context tokens billed at full price).
**Sessions with `Total_Input_Tokens = 0`:** excluded (ratio undefined; no marker plotted). In practice this only occurs for pathological sessions with no turns.
**Rationale:** the uncached fraction is a continuous rate that summarises prompt-cache effectiveness across sessions. An I chart detects sustained shifts in caching efficiency. Box-Cox transformation is not applied.
**Limits (I chart):** derived from the mean moving range of the setup interval (§5.6).
**MR chart:** `MR_i = |ratio_i − ratio_{i-1}|`; sessions with zero total input tokens are skipped.
**EWMA chart:** independently computes Grand_Mean and σ from the same setup-interval observations as the corresponding I chart.

### 6.10 Session Input Tokens — I Chart

**Measured quantity:** total input tokens for the session (`Total_Input_Tokens`).  
**Observation:** one scalar value per session; no within-session subgroup.  
**Statistic:** the session total (x).  
**Limits:** derived from the mean moving range of the setup interval (§5.6). When Box-Cox transformation is enabled (§5.7), limits are computed in the transformed space and back-transformed to original (token) units for display.

### 6.11 Session Input Tokens — MR Chart

**Measured quantity:** absolute difference in total input tokens between consecutive
sessions in chronological order.  
**Statistic:** `MR_i = |Total_Input_Tokens_i − Total_Input_Tokens_{i-1}|`.  
**First session:** no marker is plotted; a gap is left in the connecting line.  
**Limits:** `UCL = D4 × MR̄`; LCL = 0 always (§5.6). When Box-Cox transformation is enabled (§5.7), the MR chart uses its own independent Box-Cox transformation (λ_MR estimated from the setup-interval MR series); points are original-space absolute differences and limits are back-transformed to original (token) units.

### 6.12 Session Output Tokens — I Chart

**Measured quantity:** total output tokens for the session (`Total_Output_Tokens`).  
**Observation:** one scalar value per session; no within-session subgroup.  
**Statistic:** the session total (x).  
**Limits:** derived from the mean moving range of the setup interval (§5.6). When Box-Cox transformation is enabled (§5.7), limits are computed in the transformed space and back-transformed to original (token) units for display.

### 6.13 Session Output Tokens — MR Chart

**Measured quantity:** absolute difference in total output tokens between consecutive
sessions in chronological order.  
**Statistic:** `MR_i = |Total_Output_Tokens_i − Total_Output_Tokens_{i-1}|`.  
**First session:** no marker is plotted; a gap is left in the connecting line.  
**Limits:** `UCL = D4 × MR̄`; LCL = 0 always (§5.6). When Box-Cox transformation is enabled (§5.7), the MR chart uses its own independent Box-Cox transformation (λ_MR estimated from the setup-interval MR series); points are original-space absolute differences and limits are back-transformed to original (token) units.



### 6.14 Session Cache Read Tokens — I Chart

**Measured quantity:** total cache-read tokens for the session (`Total_Cache_Read_Tokens`).
**Observation:** one scalar value per session; no within-session subgroup.
**Statistic:** the session total (x).
**Limits:** derived from the mean moving range of the setup interval (§5.6). When Box-Cox transformation is enabled (§5.7), limits are computed in the transformed space and back-transformed to original (token) units for display.

### 6.15 Session Cache Read Tokens — MR Chart

**Measured quantity:** absolute difference in total cache-read tokens between consecutive sessions in chronological order.
**Statistic:** `MR_i = |Total_Cache_Read_Tokens_i − Total_Cache_Read_Tokens_{i-1}|`.
**First session:** no marker is plotted; a gap is left in the connecting line.
**Limits:** `UCL = D4 × MR̄`; LCL = 0 always (§5.6). When Box-Cox transformation is enabled (§5.7), the MR chart uses its own independent Box-Cox transformation (λ_MR estimated from the setup-interval MR series); points are original-space absolute differences and limits are back-transformed to original (token) units.

### 6.16 Session Cache Write Tokens — I Chart

**Measured quantity:** total cache-write tokens for the session (`Total_Cache_Write_Tokens`).
**Observation:** one scalar value per session; no within-session subgroup.
**Statistic:** the session total (x).
**Limits:** derived from the mean moving range of the setup interval (§5.6). When Box-Cox transformation is enabled (§5.7), limits are computed in the transformed space and back-transformed to original (token) units for display.

### 6.17 Session Cache Write Tokens — MR Chart

**Measured quantity:** absolute difference in total cache-write tokens between consecutive sessions in chronological order.
**Statistic:** `MR_i = |Total_Cache_Write_Tokens_i − Total_Cache_Write_Tokens_{i-1}|`.
**First session:** no marker is plotted; a gap is left in the connecting line.
**Limits:** `UCL = D4 × MR̄`; LCL = 0 always (§5.6). When Box-Cox transformation is enabled (§5.7), the MR chart uses its own independent Box-Cox transformation (λ_MR estimated from the setup-interval MR series); points are original-space absolute differences and limits are back-transformed to original (token) units.

### 6.18 Session Input Tokens — EWMA Chart

**Measured quantity:** total input tokens for the session (`Total_Input_Tokens`).
**Statistic:** the EWMA value `Z_t = λ · x_t + (1−λ) · Z_{t−1}` (§5.9).
**Limits:** time-varying UCL and LCL at step _t_ (§5.9). When Box-Cox is active,
the EWMA and limits are computed in z-space and back-transformed (§5.9).
**Parameters:** Grand_Mean and σ are independently computed from the same setup-interval observations as the Session Input Tokens — I chart.

### 6.19 Session Output Tokens — EWMA Chart

**Measured quantity:** total output tokens for the session (`Total_Output_Tokens`).
**Statistic:** the EWMA value `Z_t = λ · x_t + (1−λ) · Z_{t−1}` (§5.9).
**Limits:** time-varying UCL and LCL at step _t_ (§5.9). When Box-Cox is active,
the EWMA and limits are computed in z-space and back-transformed (§5.9).
**Parameters:** Grand_Mean and σ are independently computed from the same setup-interval observations as the Session Output Tokens — I chart.

### 6.20 Session Cache Read Tokens — EWMA Chart

**Measured quantity:** total cache-read tokens for the session (`Total_Cache_Read_Tokens`).
**Statistic:** the EWMA value `Z_t = λ · x_t + (1−λ) · Z_{t−1}` (§5.9).
**Limits:** time-varying UCL and LCL at step _t_ (§5.9). When Box-Cox is active,
the EWMA and limits are computed in z-space and back-transformed (§5.9).
**Parameters:** Grand_Mean and σ are independently computed from the same setup-interval observations as the Session Cache Read Tokens — I chart.

### 6.21 Session Cache Write Tokens — EWMA Chart

**Measured quantity:** total cache-write tokens for the session (`Total_Cache_Write_Tokens`).
**Statistic:** the EWMA value `Z_t = λ · x_t + (1−λ) · Z_{t−1}` (§5.9).
**Limits:** time-varying UCL and LCL at step _t_ (§5.9). When Box-Cox is active,
the EWMA and limits are computed in z-space and back-transformed (§5.9).
**Parameters:** Grand_Mean and σ are independently computed from the same setup-interval observations as the Session Cache Write Tokens — I chart.

### 6.22 Session Thinking Tokens — I Chart

**Measured quantity:** total thinking tokens for the session (`Total_Thinking_Tokens`).
**Observation:** one scalar value per session; no within-session subgroup.
**Statistic:** the session total (x).
**Zero-thinking sessions:** sessions where no turn produced thinking tokens are valid zero observations. When Box-Cox transformation is enabled (§5.7), sessions with a zero thinking-token total are excluded from the I chart and from λ estimation; a status-bar notice reports the count of excluded sessions.
**Limits:** derived from the mean moving range of the setup interval (§5.6). When Box-Cox transformation is enabled (§5.7), limits are computed in the transformed space and back-transformed to original (token) units for display.

### 6.23 Session Thinking Tokens — MR Chart

**Measured quantity:** absolute difference in total thinking tokens between consecutive sessions in chronological order.
**Statistic:** `MR_i = |Total_Thinking_Tokens_i − Total_Thinking_Tokens_{i-1}|`.
**First session:** no marker is plotted; a gap is left in the connecting line.
**Limits:** `UCL = D4 × MR̄`; LCL = 0 always (§5.6). When Box-Cox transformation is enabled (§5.7), the MR chart uses its own independent Box-Cox transformation (λ_MR estimated from the setup-interval MR series); points are original-space absolute differences and limits are back-transformed to original (token) units.

### 6.24 Session Thinking Tokens — EWMA Chart

**Measured quantity:** total thinking tokens for the session (`Total_Thinking_Tokens`).
**Statistic:** the EWMA value `Z_t = λ · x_t + (1−λ) · Z_{t−1}` (§5.9).
**Limits:** time-varying UCL and LCL at step _t_ (§5.9). When Box-Cox is active,
the EWMA and limits are computed in z-space and back-transformed (§5.9).
**Parameters:** Grand_Mean and σ are independently computed from the same setup-interval observations as the Session Thinking Tokens — I chart.

### 6.25 Session Tool-Call Tokens — I Chart

**Measured quantity:** total estimated tool call input tokens for the session (`Total_Tool_Call_Input_Tokens`).
**Observation:** one scalar value per session; no within-session subgroup.
**Statistic:** the session total (x).
**Zero-tool-call sessions:** sessions with no tool calls have a zero total and are valid zero observations. When Box-Cox transformation is enabled (§5.7), such sessions are excluded from the I chart and from λ estimation; a status-bar notice reports the count of excluded sessions.
**Limits:** derived from the mean moving range of the setup interval (§5.6). When Box-Cox transformation is enabled (§5.7), limits are computed in the transformed space and back-transformed to original (token) units for display.

### 6.26 Session Tool-Call Tokens — MR Chart

**Measured quantity:** absolute difference in total tool call input tokens between consecutive sessions in chronological order.
**Statistic:** `MR_i = |Total_Tool_Call_Input_Tokens_i − Total_Tool_Call_Input_Tokens_{i-1}|`.
**First session:** no marker is plotted; a gap is left in the connecting line.
**Limits:** `UCL = D4 × MR̄`; LCL = 0 always (§5.6). When Box-Cox transformation is enabled (§5.7), the MR chart uses its own independent Box-Cox transformation (λ_MR estimated from the setup-interval MR series); points are original-space absolute differences and limits are back-transformed to original (token) units.

### 6.27 Session Tool-Call Tokens — EWMA Chart

**Measured quantity:** total estimated tool call input tokens for the session (`Total_Tool_Call_Input_Tokens`).
**Statistic:** the EWMA value `Z_t = λ · x_t + (1−λ) · Z_{t−1}` (§5.9).
**Limits:** time-varying UCL and LCL at step _t_ (§5.9). When Box-Cox is active,
the EWMA and limits are computed in z-space and back-transformed (§5.9).
**Parameters:** Grand_Mean and σ are independently computed from the same setup-interval observations as the Session Tool-Call Tokens — I chart.

### 6.28 Session Tool-Call Result Tokens — I Chart

**Measured quantity:** total estimated tool call result tokens for the session (`Total_Tool_Call_Result_Tokens`).
**Observation:** one scalar value per session; no within-session subgroup.
**Statistic:** the session total (x).
**Zero-tool-call sessions:** sessions with no tool calls have a zero total and are valid zero observations. When Box-Cox transformation is enabled (§5.7), such sessions are excluded from the I chart and from λ estimation; a status-bar notice reports the count of excluded sessions.
**Limits:** derived from the mean moving range of the setup interval (§5.6). When Box-Cox transformation is enabled (§5.7), limits are computed in the transformed space and back-transformed to original (token) units for display.

### 6.29 Session Tool-Call Result Tokens — MR Chart

**Measured quantity:** absolute difference in total tool call result tokens between consecutive sessions in chronological order.
**Statistic:** `MR_i = |Total_Tool_Call_Result_Tokens_i − Total_Tool_Call_Result_Tokens_{i-1}|`.
**First session:** no marker is plotted; a gap is left in the connecting line.
**Limits:** `UCL = D4 × MR̄`; LCL = 0 always (§5.6). When Box-Cox transformation is enabled (§5.7), the MR chart uses its own independent Box-Cox transformation (λ_MR estimated from the setup-interval MR series); points are original-space absolute differences and limits are back-transformed to original (token) units.

### 6.30 Session Tool-Call Result Tokens — EWMA Chart

**Measured quantity:** total estimated tool call result tokens for the session (`Total_Tool_Call_Result_Tokens`).
**Statistic:** the EWMA value `Z_t = λ · x_t + (1−λ) · Z_{t−1}` (§5.9).
**Limits:** time-varying UCL and LCL at step _t_ (§5.9). When Box-Cox is active,
the EWMA and limits are computed in z-space and back-transformed (§5.9).
**Parameters:** Grand_Mean and σ are independently computed from the same setup-interval observations as the Session Tool-Call Result Tokens — I chart.

### 6.31 Session Turn Count — I Chart

**Measured quantity:** number of turns in the session (`N_Turns`).
**Observation:** one scalar value per session; no within-session subgroup.
**Statistic:** the session turn count (x).
**Limits:** derived from the mean moving range of the setup interval (§5.6). When Box-Cox transformation is enabled (§5.10), limits are computed in the transformed space and back-transformed to original (turn count) units for display.

### 6.32 Session Turn Count — MR Chart

**Measured quantity:** absolute difference in turn count between consecutive sessions in chronological order.
**Statistic:** `MR_i = |N_Turns_i − N_Turns_{i-1}|`.
**First session:** no marker is plotted; a gap is left in the connecting line.
**Limits:** `UCL = D4 × MR̄`; LCL = 0 always (§5.6). When Box-Cox transformation is enabled (§5.10), the MR chart uses its own independent Box-Cox transformation (λ_MR estimated from the setup-interval MR series); points are original-space absolute differences and limits are back-transformed to original (turn count) units.

### 6.33 Session Turn Count — EWMA Chart

**Measured quantity:** number of turns in the session (`N_Turns`).
**Statistic:** the EWMA value `Z_t = λ · x_t + (1−λ) · Z_{t−1}` (§5.9).
**Limits:** time-varying UCL and LCL at step _t_ (§5.9). When Box-Cox is active (§5.10), the EWMA and limits are computed in z-space and back-transformed to original (turn count) units for display.
**Parameters:** Grand_Mean and σ are independently computed from the same setup-interval observations as the Session Turn Count — I chart.
### 6.34 Session Uncached Input Tokens — I Chart

**Measured quantity:** total uncached input tokens for the session
(`Total_Uncached_Input_Tokens = Total_Input_Tokens − Total_Cache_Read_Tokens − Total_Cache_Write_Tokens`).
This represents tokens submitted to the model at full price, serving as a direct
proxy for prompt-cache effectiveness across sessions.
**Observation:** one scalar value per session; no within-session subgroup.
**Statistic:** the session total (x).
**Limits:** derived from the mean moving range of the setup interval (§5.6). When Box-Cox transformation is enabled (§5.7), limits are computed in the transformed space and back-transformed to original (token) units for display.

### 6.35 Session Uncached Input Tokens — MR Chart

**Measured quantity:** absolute difference in total uncached input tokens between
consecutive sessions in chronological order.
**Statistic:** `MR_i = |Total_Uncached_Input_Tokens_i − Total_Uncached_Input_Tokens_{i-1}|`.
**First session:** no marker is plotted; a gap is left in the connecting line.
**Limits:** `UCL = D4 × MR̄`; LCL = 0 always (§5.6). When Box-Cox transformation is enabled (§5.7), the MR chart uses its own independent Box-Cox transformation (λ_MR estimated from the setup-interval MR series); points are original-space absolute differences and limits are back-transformed to original (token) units.

### 6.36 Session Uncached Input Tokens — EWMA Chart

**Measured quantity:** total uncached input tokens for the session
(`Total_Uncached_Input_Tokens`).
**Statistic:** the EWMA value `Z_t = λ · x_t + (1−λ) · Z_{t−1}` (§5.9).
**Limits:** time-varying UCL and LCL at step _t_ (§5.9). When Box-Cox is active,
the EWMA and limits are computed in z-space and back-transformed (§5.9).
**Parameters:** Grand_Mean and σ are independently computed from the same setup-interval observations as the Session Uncached Input Tokens — I chart.





---

### 6.37 Consecutive Tool Call Diversity — Xbar Chart

**Measured quantity:** mean JSD-based similarity Sᵢ across consecutive tool
call pairs within a session (see §5.12).
**Subgroup:** the vector of Sᵢ values for consecutive pairs within the session.
**Subgroup size n:** total non-empty tool calls minus one (T−1).
**Statistic:** mean Sᵢ (x̄).
**Exclusion:** sessions with T ≤ 1 non-empty tool calls excluded entirely (no
marker).  Sessions with T = 2 (n = 1) plotted as hollow circles on the Xbar
chart; no s marker.
**Limits:** derived from the grand mean and pooled standard deviation of the
setup interval (§5.2), using the standard Xbar formulas.  When Box-Cox
transformation is enabled (§5.8), limits are computed in the transformed
space and back-transformed to original JSD units for display.

### 6.38 Consecutive Tool Call Diversity — s Chart

**Measured quantity:** standard deviation of Sᵢ values across consecutive
tool call pairs within a session (see §5.12).
**Subgroup:** the vector of Sᵢ values for consecutive pairs within the session.
**Subgroup size n:** total non-empty tool calls minus one (T−1).
**Statistic:** sample standard deviation of Sᵢ (s).
**Exclusion:** sessions with T ≤ 2 (n ≤ 1) have no s statistic; no marker
plotted on the s chart for these sessions.
**Limits:** derived from the pooled standard deviation of the setup interval
(§5.2), using the standard s chart formulas.  When Box-Cox transformation
is enabled (§5.8), limits are computed in the transformed space; the
standard deviation remains in transformed units.

### 6.39 Consecutive Tool Diversity Sum — I Chart

**Measured quantity:** total consecutive tool-call JSD similarity for the
session (`Total_Tool_Call_JSD_S` = Σ S_k across all consecutive pairs; see §5.13).
**Observation:** one scalar value per session; no within-session subgroup.
**Statistic:** the session total (x).
**Exclusion:** sessions with `N_Consecutive_Tool_Pairs = 0` (≤ 1 non-empty
tool calls) are excluded; no marker plotted.
**Limits:** derived from the mean moving range of the setup interval (§5.6).
Box-Cox transformation is not applied.

### 6.40 Consecutive Tool Diversity Sum — MR Chart

**Measured quantity:** absolute difference in `Total_Tool_Call_JSD_S` between
consecutive sessions in chronological order.
**Statistic:** `MR_i = |Total_Tool_Call_JSD_S_i − Total_Tool_Call_JSD_S_{i-1}|`.
**First session:** no marker is plotted; a gap is left in the connecting line.
**Exclusion:** sessions with `N_Consecutive_Tool_Pairs = 0` do not contribute
to the MR sequence (they are skipped as if absent from the time series).
**Limits:** `UCL = D4 × MR̄`; LCL = 0 always (§5.6).  Box-Cox transformation
is not applied.

### 6.41 Consecutive Tool Diversity Sum — EWMA Chart

**Measured quantity:** total consecutive tool-call JSD similarity for the
session (`Total_Tool_Call_JSD_S`).
**Statistic:** the EWMA value `Z_t = λ · x_t + (1−λ) · Z_{t−1}` (§5.9).
**Limits:** time-varying UCL and LCL at step _t_ (§5.9).
**Parameters:** Grand_Mean and σ are independently computed from the same
setup-interval observations as the Session Consecutive Tool Diversity Sum — I
chart (§6.39).

## 7. UI Layout and Navigation

### 7.1 Window Structure

The main window contains, from top to bottom:

1. **Menu bar** — File, Workspace, View menus (see Section 7.5).
2. **Toolbar** — date/time range pickers and zoom reset buttons.
3. **Three-panel content area** — left panel, chart area, detail panel, separated by
   draggable GtkPaned splitters.

### 7.2 Left Panel

A GtkListBox (~180px default width, user-resizable) listing the fifty-one charts in
four visually separated groups with indented sub-group labels. Top-level groups are
bold; sub-group labels are italic and indented 8 px; chart rows are indented 16 px.
Groups and sub-groups are ordered alphabetically (case-sensitive). Enum declaration
order is preserved within each sub-group.

```
Token Consumption
  Thinking Tokens
    Thinking Tokens -- Xbar
    Thinking Tokens -- s
  Tool Call Tokens
    Tool Call Tokens -- Xbar
    Tool Call Tokens -- s
  Turn Tokens
    Turn Tokens -- Xbar
    Turn Tokens -- s

Rates
  Thinking Tokens
    Fraction: Thinking Tokens -- I
    Fraction: Thinking Tokens -- MR
    Fraction: Thinking Tokens -- EWMA
  Thinking Turns
    Fraction: Thinking Turns
  Thinking per Tool-Call
    Fraction: Thinking/Tool-Call Tokens -- I
    Fraction: Thinking/Tool-Call Tokens -- MR
    Fraction: Thinking/Tool-Call Tokens -- EWMA
  Tool Call Failure Rate
    Tool Call Failure Rate
  Tool-Call Tokens
    Fraction: Tool-Call Tokens -- I
    Fraction: Tool-Call Tokens -- MR
    Fraction: Tool-Call Tokens -- EWMA
  Tool-Call Turns
    Fraction: Tool-Call Turns
  Uncached Input
    Fraction: Uncached/Total Input -- I
    Fraction: Uncached/Total Input -- MR
    Fraction: Uncached/Total Input -- EWMA

Session Totals
  Cache Read Tokens
    Session Cache Read Tokens -- I
    Session Cache Read Tokens -- MR
    Session Cache Read Tokens -- EWMA
  Cache Write Tokens
    Session Cache Write Tokens -- I
    Session Cache Write Tokens -- MR
    Session Cache Write Tokens -- EWMA
  Input Tokens
    Session Input Tokens -- I
    Session Input Tokens -- MR
    Session Input Tokens -- EWMA
  Output Tokens
    Session Output Tokens -- I
    Session Output Tokens -- MR
    Session Output Tokens -- EWMA
  Thinking Tokens
    Session Thinking Tokens -- I
    Session Thinking Tokens -- MR
    Session Thinking Tokens -- EWMA
  Tool-Call Result Tokens
    Session Tool-Call Result Tokens -- I
    Session Tool-Call Result Tokens -- MR
    Session Tool-Call Result Tokens -- EWMA
  Tool-Call Tokens
    Session Tool-Call Tokens -- I
    Session Tool-Call Tokens -- MR
    Session Tool-Call Tokens -- EWMA
  Turn Count
    Session Turn Count -- I
    Session Turn Count -- MR
    Session Turn Count -- EWMA
  Uncached Input Tokens
    Session Uncached Input Tokens -- I
    Session Uncached Input Tokens -- MR
    Session Uncached Input Tokens -- EWMA

Tool Call Behavior
  Consecutive Diversity
    Consecutive Tool Diversity -- Xbar
    Consecutive Tool Diversity -- s
    Consecutive Tool Diversity Sum -- I
    Consecutive Tool Diversity Sum -- MR
    Consecutive Tool Diversity Sum -- EWMA
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
   values; a second series for LCL. Where the formula yields a negative value,
   the LCL is clamped to zero and drawn at y = 0.
4. **Center line series:** a solid blue polyline connecting the per-point center line
   values.
5. **Point markers:** filled or hollow circles (see Section 7.3.3).
6. **Selection halos:** rendered on top of point markers (see Section 9).

#### 7.3.3 Point Marker Colors

| Condition | Marker |
|---|---|
| In-control, no comment | Filled black circle |
| In-control, comment present | Filled green circle |
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
- Chart Settings…  `Ctrl+,`  (opens Chart Settings dialog for the currently active chart; see §13.6)
- ─
- Clear Selection
- Clear Setup Interval  (grayed out if not established)
- Set Selection as Setup Interval  (grayed out if selection is empty)
- Select Setup Interval  (grayed out if not established; selects all current setup interval points)
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

### 8.5 Right-Click Context Menu

Right-clicking anywhere on the chart canvas opens a context menu anchored at the
cursor position:

- **Chart Settings…** — opens the Chart Settings dialog for the currently active chart (see §13.6). Equivalent to View → Chart Settings….
- **Y-Fit** — rescales the y-axis to fit visible points (equivalent to toolbar Y-Fit).
- **Show All** — resets the x-range to the full session extent (equivalent to toolbar Show All).
- ─
- **Set Selection as Setup Interval** — grayed out when selection is empty.
- **Clear Setup Interval** — grayed out when no setup interval is established.


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
- Session ID (UUID)

All text in the Session section shall be selectable: the user can click and drag
to copy the session ID or any other displayed field.

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


**Distribution histogram:**
- A Cairo-rendered histogram of the active chart's statistic for the selected
  sessions, placed between the date-range summary and the "Set as Setup
  Interval" button.
- Only sessions that are not excluded from the active chart contribute to the
  histogram (e.g. zero-tool-call sessions on the failure-rate chart are
  omitted; hollow-gray sessions on thinking charts are omitted).
- The number of bins is determined by the Freedman-Diaconis rule:
  `h = 2 × IQR / n^(1/3)`, `k = max(1, ceil(range / h))`, capped at 32,
  where `n` is the number of contributing selected sessions, IQR is their
  interquartile range (computed by linear interpolation on the sorted values),
  and `range = max − min`. When IQR = 0 (all values in the middle 50% are
  identical), the rule is undefined; the implementation falls back to a single
  bin covering the full range.
- Bin width is uniform: `(max_value − min_value) / k`. When all contributing
  sessions have the same statistic value, a single centred bar is rendered with
  `Bin_Width = 1.0`.
- Three vertical overlay lines are drawn:
  - Center line: solid blue, using the CL value of the first contributing
    selected point.
  - UCL: red dashed, drawn only when the chart has a finite UCL for the
    selected point.
  - LCL: red dashed, drawn only when the chart has a finite, positive LCL for
    the selected point.
  - Overlay lines outside the histogram x-range (± half a bin width) are
    suppressed.
- The x-axis is labelled with the active chart's statistic name (the same
  string used as the y-axis label on the main chart canvas). The y-axis shows
  "Count" tick labels at 0, max/2, and max.
- The histogram area height is fixed at 160 px and is not user-resizable.
- When no contributing session exists for the active chart, the histogram area
  displays the text "No data for active chart" centred in the widget.
- The histogram updates automatically whenever the active chart changes (via
  the left-panel chart selector) or the selection changes.

**Summary Statistics:**
Immediately below the distribution histogram, a "Summary Statistics" frame
shows descriptive statistics and goodness-of-fit test p-values for the
contributing selected sessions — the same set that populates the histogram
(sessions excluded from the active chart are omitted).  The frame contains a
two-column grid:

| Row label | Value shown |
|---|---|
| `Mean:` | Arithmetic mean of the contributing values |
| `Median:` | Median (50th percentile) of the contributing values |
| `Std Dev:` | Sample standard deviation (N−1 denominator) |
| `KS Normal p:` | p-value for the one-sample KS normality test (§5.14) |
| `KS Exp p:` | p-value for the one-sample KS exponential distribution test (§5.14) |
| `Runs Test p:` | Two-sided Wald-Wolfowitz randomness test p-value (§5.15) |

Display rules for numeric values: if |value| ≥ 100, display as a rounded
integer; otherwise display with 2 decimal places.  Display rules for
p-values: `"< 0.001"` when p < 0.001; `"N/A"` when the sample size is
below the test's minimum; otherwise 3 decimal places (e.g. `"0.042"`).
A value of exactly 1.000 is shown as `"1.000"`.

The frame updates automatically whenever the active chart changes or the
selection changes, using the same trigger as the histogram refresh.

**Set as Setup Interval button:**
- Clicking this button sets the workspace setup interval to exactly the selected
  sessions, applying to all fifty-one charts simultaneously.
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
center line and control limits for all fifty-one charts simultaneously. It is established
by selecting one or more sessions (Section 9) and either clicking "Set as Setup Interval"
in the multi-select detail panel (Section 10.2) or choosing **View → Set Selection as
Setup Interval** from the menu bar. There is no requirement for the
setup sessions to be contiguous in time.

### 11.2 Setup Interval Storage

The setup interval is stored as a set of session UUIDs in the `Setup_Session_Ids`
field of the `Workspace_Record`. It is workspace-level: a single setup interval
applies to all fifty-one charts. The set is stored within the workspace file.

### 11.3 Visual Representation

Setup interval sessions are rendered with filled yellow markers on all fifty-one charts.
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

A point that has at least one comment is colored to distinguish annotated sessions:

- **In-control, comment present:** rendered green rather than black.
- **Out-of-control, comment present:** rendered orange rather than red.

This allows annotated sessions to be visually distinguished from unannotated ones,
and annotated anomalies from uninvestigated anomalies.

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

The current workspace format is **version 7**. The `"version"` field increments
whenever new fields are added that cannot safely be ignored by an older reader.
Version history:

| Version | When introduced | Notable additions |
|---------|-----------------|-------------------|
| 1 | Initial release | Core workspace fields |
| 2 | — | `xbarSBoxCox` Xbar/S Box-Cox config |
| 3 | — | `iChartBoxCox` I/MR Box-Cox config |
| 4 | EWMA charts | `ewmaWeight`, `ewmaL` smoothing parameters |
| 5 | Session Turn Count charts | `turnCountBoxCox` Turn Count Box-Cox config |
| 6 | Robust control limit estimation | `estimationMethod` control limit estimation method |
| 7 | Per-chart settings | `chartSettings` per-chart Box-Cox, estimation method, and EWMA parameters |

**Version 7 migration.** Workspace files at version ≤ 6 are migrated automatically on load: the shared `iChartBoxCox` config (if present and enabled) is broadcast to all Session Token I/MR/EWMA chart kinds; `xbarSBoxCox` is broadcast to all Xbar/S chart kinds; `turnCountBoxCox` is broadcast to the Session Turn Count I/MR/EWMA chart kinds; `estimationMethod` is broadcast to all chart kinds. The top-level shared fields are then discarded and the workspace is resaved at version 7. Workspace files at version ≤ 3 that are missing `ewmaWeight` and `ewmaL` default each EWMA chart to `ewmaWeight = 0.2`, `ewmaL = 3.0`. On all other respects, earlier-version files load normally.

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

### 13.6 Chart Settings Dialog

Accessible via **View → Chart Settings…** (`Ctrl+,`) or by **right-clicking** the
chart canvas (see §8.5). Opens a modal dialog titled
*"Chart Settings — \<chart name\>"* for the currently active chart.

All changes take effect on clicking OK. The active chart's control limits are
recomputed immediately; other charts are unaffected.

A **"Reset to Defaults"** button restores all settings for this chart to their
default values without affecting other charts.

Settings for each chart are stored sparsely in the workspace `chartSettings` JSON map
(§13.1): only charts that differ from the default are written to the map.

#### Box-Cox Transformation

- **Enable Box-Cox transformation** checkbox. Default: unchecked.
- When enabled:
  - **Lambda source** drop-down:
    - **Auto-estimate (MLE)** (default) — estimates λ from the setup-interval
      data by MLE profile log-likelihood (§5.7).
    - **Auto-estimate (robust)** — estimates λ using the Qₙ robust scale
      estimator in place of variance; 50% breakdown point, 82% Gaussian
      efficiency (§5.7).
    - **Fixed** — uses a user-specified λ directly.
  - When **Fixed** is selected: a λ spin-button (range 0.0–30.0, step 0.01)
    is enabled.
  - **Estimated λ:** readout showing the current auto-estimated value (greyed
    out when Fixed is selected or fewer than three setup sessions are available).
  - For MR charts: an additional **Estimated λ (MR series):** readout showing
    the independently estimated λ_MR for the moving-range series.
- Box-Cox is available for all chart kinds. For p-charts and ratio I/MR charts
  where Box-Cox is statistically inadvisable, an inline note reads:
  *"Box-Cox is not recommended for this chart type."* The option remains
  functional regardless.

#### Estimation Method

- Drop-down with two choices:
  - **Classical** (default) — arithmetic mean, pooled s, mean MR (§5.11).
  - **Robust (median/Qₙ)** — median center line, Qₙ-based pooled scale, median
    MR; 50% breakdown point (§5.11).
- For p-charts, an inline note reads:
  *"p-charts always use the classical grand proportion regardless of this setting."*
- For EWMA charts, an inline note reads:
  *"EWMA charts independently apply this method using the same setup-interval
  observations as the companion I chart."*

#### EWMA Parameters *(EWMA charts only)*

Shown only for EWMA chart kinds; hidden for all other chart types.

- **Smoothing weight λ** spin-button (range 0.01–1.00, step 0.01). Default: 0.2.
  Smaller λ weights recent observations less, giving more smoothing and detecting
  smaller sustained shifts; λ = 1 reduces to the raw I chart.
- **Sigma multiplier L** spin-button (range 1.00–4.00, step 0.01). Default: 3.0.
  Controls the width of the EWMA control limits.

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
The same icon rule applies to the clickable GtkButton embedded in the session
replay view: the button's label prefix shall use the same ✓, ✗, or `-` symbol
rather than ⚙, so the outcome of each tool call is visible at a glance without
opening the detail window.

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
A tool call for which no result record is found in the session file (e.g. the
session was truncated before the tool completed) shall be assigned `Cancelled`
status and displayed with the `-` icon on both the session replay button and the
detail window title.

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
- Correct I-chart and MR-chart limit computation for known datasets (grand mean,
  mean moving range, UCL/LCL to 4 decimal places).
- Special cases for I/MR charts: single-session setup interval (MR̄ undefined →
  no limits drawn); MR̄ = 0 → no limits drawn; first session excluded from MR chart.
- EWMA chart `Compute_Z` formula: single-step and multi-step sequences agree with
  hand-computed values to 1 × 10⁻¹⁰.
- EWMA time-varying limits at T=1 and convergence toward steady-state at large T.
- EWMA: zero sigma → Has_UCL = False, Has_LCL = False.
- EWMA: LCL clamped to 0 when the formula yields a negative value.
- EWMA workspace round-trip: `ewmaWeight` and `ewmaL` survive save/load unchanged.
- EWMA version migration: workspace files at version ≤ 3 load with default
  `ewmaWeight = 0.2` and `ewmaL = 3.0`.
- Correct `Total_Thinking_Tokens`, `Total_Tool_Call_Input_Tokens`, and `Total_Tool_Call_Result_Tokens` metric computation: given a session with three turns where two have thinking tokens (12 and 24) and two turns each have one tool call with estimated input/output tokens (5/8 and 3/12), verify `Total_Thinking_Tokens = 36`, `Total_Tool_Call_Input_Tokens = 8`, `Total_Tool_Call_Result_Tokens = 20`.
- I/MR limit computation for the three new session-total chart kinds (Thinking Tokens, Tool-Call Tokens, Tool-Call Result Tokens): for a known five-session dataset, verify UCL, CL, and LCL match hand-computed §5.6 formula values to 4 decimal places.
- EWMA computation for the three new EWMA chart kinds (Thinking, Tool-Call, Tool-Call Result): verify `Z_t` and time-varying limits independently compute Grand_Mean and σ from the same setup-interval observations as the corresponding I chart.
- Zero-value session exclusion for new I/MR charts: sessions with zero `Total_Thinking_Tokens`, zero `Total_Tool_Call_Input_Tokens`, or zero `Total_Tool_Call_Result_Tokens` are excluded from the respective I/MR chart when Box-Cox is enabled, and a status-bar notice is posted.
- Session Turn Count I/MR limit computation: for a known five-session dataset, verify UCL, CL, and LCL match hand-computed §5.6 formula values to 4 decimal places.
- Session Turn Count EWMA computation: verify `Z_t` and time-varying limits independently compute Grand_Mean and σ from the same setup-interval observations as the corresponding I chart.
- Session Turn Count Box-Cox round-trip: `turnCountBoxCox` configuration (enabled, lambda source, fixed λ) survives workspace save/load unchanged.
- Session Turn Count Box-Cox version migration: workspace files at version ≤ 4 load with `turnCountBoxCox` disabled (default).
- Robust I chart estimation: for a five-session dataset containing one outlier
  session, verify that the robust Grand_Mean equals the median of the
  setup-interval observations, and that σ_robust = Q_n(observations) / 2.2219;
  confirm that both diverge from the corresponding classical estimates.
- Robust MR chart UCL: in robust mode, verify UCL = D4 × median(w_i) where
  w_i are the transformed MR values; confirm this differs from D4 × MR̄_w.
- Robust Xbar/s estimation: for a known dataset with one outlier session,
  verify that Grand_Mean equals the unweighted median of per-session means,
  and that Pooled_S equals Qₙ(pooled residuals) with consistency constant
  2.2219; confirm divergence from classical pooled_s.
- Robust estimation with Box-Cox active: verify that the median and
  Qₙ estimators (Q_n for I chart, Qₙ-based for Xbar/s) are applied to the Box-Cox-transformed values,
  not the original observations.
- p-charts unaffected by estimation method: Grand_P equals Σd / Σn
  regardless of whether Classical or Robust_Median is selected.
- EWMA with robust estimation: verify that Z_0 = median(observations) and
  σ = Q_n(observations) / 2.2219 are used in the EWMA limit formula when
  robust estimation is enabled; the time-varying limit values should match
  hand-computed values using those robust parameters.
- Robust estimation workspace round-trip: the `estimationMethod` field
  (`"classical"` or `"robust_median"`) survives workspace save/load
  unchanged.
- Robust estimation version migration: workspace files at version ≤ 5
  that are missing `estimationMethod` load with the default `"classical"`.
- Session Turn Count Box-Cox: sessions with N_Turns = 1 are not excluded from I/MR/EWMA charts when Box-Cox is active (since ln(1) = 0 is valid); verify no exclusion occurs and no status-bar notice is posted for such sessions.
- Session Turn Count Box-Cox: MR̄ = 0 when all setup-interval sessions have N_Turns = 1 after transformation (y = 0 for all); verify no limits are drawn and no exception is raised.
- Token normalization: for an Anthropic session with `input_tokens=100`, `cache_read_input_tokens=200`, `cache_creation_input_tokens=50`, verify `Total_Input_Tokens=350`, `Total_Cache_Read_Tokens=200`, `Total_Cache_Write_Tokens=50`, and `Total_Uncached_Input_Tokens=100`. For an OpenAI session with `prompt_tokens=350`, `cached_tokens=250`, verify `Total_Input_Tokens=350`, `Total_Cache_Read_Tokens=250`, `Total_Cache_Write_Tokens=0`, and `Total_Uncached_Input_Tokens=100`.
- Uncached input token I/MR limit computation: for a known five-session dataset, verify UCL, CL, and LCL match hand-computed §5.6 formula values to 4 decimal places.
- Uncached input token EWMA computation: verify `Z_t` and time-varying limits independently compute Grand_Mean and σ from the same setup-interval observations as the corresponding I chart.
- Uncached input token zero-value exclusion: sessions where `Total_Uncached_Input_Tokens = 0` are excluded from the I/MR chart when Box-Cox is enabled, and a status-bar notice is posted.
- `Fraction_Thinking_Tokens_I` I chart `Estimate_Parameters`: for two sessions with known `Total_Thinking_Tokens` and `Total_Output_Tokens`, verify `Grand_Mean = mean(thinking_i / output_i)` to 1×10⁻⁹.
- `Fraction_Tool_Call_Tokens_I` I chart `Estimate_Parameters`: for two sessions with known `Total_Tool_Call_Input_Tokens` and `Total_Output_Tokens`, verify `Grand_Mean = mean(tool_call_i / output_i)` to 1×10⁻⁹.
- Token fraction chart zero-output exclusion: sessions with `Total_Output_Tokens = 0` are excluded from both `Fraction_Thinking_Tokens_I` and `Fraction_Tool_Call_Tokens_I` charts; `Grand_Mean` is computed from eligible sessions only.
- `Fraction_Thinking_Per_Tool_Call_I` I chart `Estimate_Parameters`: for two sessions with known `Total_Thinking_Tokens` and `Total_Tool_Call_Input_Tokens`, verify `Grand_Mean = mean(thinking_i / tool_call_i)` to 1×10⁻⁹.
- `Fraction_Uncached_Input_I` I chart `Estimate_Parameters`: for two sessions with known `Total_Uncached_Input_Tokens` and `Total_Input_Tokens`, verify `Grand_Mean = mean(uncached_i / input_i)` to 1×10⁻⁹.
- New rate chart zero-denominator exclusion: sessions with `Total_Tool_Call_Input_Tokens = 0` are excluded from `Fraction_Thinking_Per_Tool_Call_I`; sessions with `Total_Input_Tokens = 0` are excluded from `Fraction_Uncached_Input_I`; `Grand_Mean` is computed from eligible sessions only.

---

- JSD `Compute_S` function: for two known token sequences, verify D, D_bc,
  and Sᵢ against hand-computed values (use simple 2–3 token examples with
  known union vocabulary size k_eff and total N).
- JSD identical calls: when Tool_Name and Arguments are identical, verify
  D = 0 and Sᵢ = N + (k_eff−1)/(2·ln2) (maximum similarity).
- JSD completely different calls: when vocabularies are disjoint, verify
  D = H[π^(1), π^(2)] and Sᵢ is at its minimum for those lengths.
- JSD no-argument call: for a call with tool name but no string-valued
  arguments, verify that only the tool-name S_k is appended and the call
  participates normally in consecutive pairs (no boundary exclusion).
- JSD missing argument: for a pair where key "stdin" is present in call 1
  but absent from call 2, verify S_stdin = 0.0 is appended to
  Per_Consecutive_Tool_S.
- JSD tokenisation: for a known JSON argument string, verify Token_Count
  returns the expected count after tool-name prepend, JSON string extraction,
  whitespace split, and lowercasing.
- JSD session metrics: for a session with T = 4 non-empty tool calls each
  having K = 2 non-skipped argument keys per pair, verify
  N_Consecutive_Tool_Pairs = 3 and Per_Consecutive_Tool_S has 6 elements
  (3 pairs × 2 keys each), with values matching independently hand-computed
  S_k values.
- JSD subgroup exclusion: sessions with T ≤ 1 produce
  N_Consecutive_Tool_Pairs = 0 and are excluded from both Xbar and s charts.
- JSD hollow circle: a session whose Per_Consecutive_Tool_S has exactly
  1 element is plotted as a hollow circle on the Xbar chart.
- JSD Xbar/s parameter estimation: for a known setup interval of three
  sessions with known per-argument S_k vectors, verify grand mean and pooled s
  match §5.2 formulas applied to the pooled Long_Float S_k values.
*End of document.*
