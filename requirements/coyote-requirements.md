# coyote Requirements Specification (SRS-CORE)

**Component:** coyote (core agent executable and shared libraries)
**Version:** 1.7
**Date:** 2026-07-12
**Status:** Draft
**Project Plan:** `plan/project-plan.md`

---

## Table of Contents

1. [Scope](#1-scope)
2. [Referenced Documents](#2-referenced-documents)
3. [Requirements](#3-requirements)
   - 3.1 Capability Requirements
     - 3.1.17 Enhanced System Prompt (REQ-CORE-170)
     - 3.1.18 Structured Memory System (REQ-CORE-180)
     - 3.1.19 Coordinator Subagent Orchestration (REQ-CORE-190)
   - 3.2 External Interface Requirements
   - 3.3 Internal Interface Requirements
   - 3.4 Internal Data Requirements
   - 3.5 Environment Requirements
   - 3.6 Resource Requirements
   - 3.7 Software Quality Factors
   - 3.8 Design and Implementation Constraints
   - 3.9 Adaptation Requirements
   - 3.10 Safety Requirements
   - 3.11 Security and Privacy Requirements
   - 3.12 Personnel and Training Requirements
4. [Qualification Provisions](#4-qualification-provisions)
5. [Requirements Traceability](#5-requirements-traceability)
6. [Notes](#6-notes)

---

## 1. Scope

**Component identifier:** coyote

**System context:** coyote is a self-contained LLM coding agent. It manages
a conversation session with a large language model, executes tool calls on
behalf of the model, and presents streaming output to the user via one of
three frontends: the acme text editor (via 9P VFS), a GTK3 graphical window,
or plain text output. A companion utility `coyote_list_sessions` lists
sessions saved for the current working directory; `coyote_open` opens a
tool-call detail window.

**Document overview:** This specification states the capability, interface,
data, environment, resource, quality, and constraint requirements for the
coyote component. Each requirement carries a unique identifier
(`REQ-CORE-NNN`) and a stated verification method:

- **T** — Test (automated AUnit test case)
- **D** — Demonstration (manually demonstrated by running the application)
- **I** — Inspection (review of source code or configuration)
- **A** — Analysis (examination of design documents or build artefacts)

---

## 2. Referenced Documents

| ID | Title | Location |
|---|---|---|
| PLAN | Project Plan | `plan/project-plan.md` |
| SDD-CORE | coyote Design Description | `design/coyote-design.md` |
| AGENTS | Agent Working Instructions | `AGENTS.md` |
| SKILL-FORMAT | Skills file format reference | `docs/skills.md` |
| SESSION-FORMAT | coyote-session-format skill | `~/.coyote/skills/coyote-session-format/SKILL.md` |

---

## 3. Requirements

### 3.1 Capability Requirements

#### 3.1.1 Frontend Selection

**REQ-CORE-001** (D)
The executable shall select the Plain frontend when the `--one-shot` flag is
given without the `--subagent` flag, regardless of any display environment.

**REQ-CORE-002** (D)
The executable shall select the Acme frontend when the environment variable
`$winid` is set to a non-zero integer, or `COYOTE_FRONTEND` equals `"acme"`,
provided the Plain-only condition of REQ-CORE-001 does not apply and no
`--frontend` flag overrides the selection.

**REQ-CORE-003** (D)
The executable shall select the GUI frontend when none of the above apply,
no `--frontend` flag overrides the selection, and at least one of the following
is true: `$DISPLAY` is non-empty, `$WAYLAND_DISPLAY` is non-empty, or
`COYOTE_FRONTEND` equals `"gui"`.

**REQ-CORE-004** (D)
When no display environment is detected, no `--frontend` flag overrides the
selection, and none of REQ-CORE-001, REQ-CORE-002, or REQ-CORE-003 applies,
the executable shall select the Plain frontend.

**REQ-CORE-005** (I)
When the Acme or GUI frontend is selected, the executable shall set the
environment variable `COYOTE_FRONTEND=acme` or `COYOTE_FRONTEND=gui`
respectively before spawning any child processes, so that subagents inherit
the headful context.


**REQ-CORE-006** (T)
The executable shall accept an optional `--frontend acme|gui|plain`
command-line argument that overrides all automatic frontend detection.
When `--frontend` is given, the named frontend shall be used regardless
of the display environment.

---

#### 3.1.2 Command-Line Interface

**REQ-CORE-010** (T)
The executable shall accept a `--session UUID` argument. When provided, the
session identified by UUID shall be resumed (conversation history reloaded)
rather than a new session created.

**REQ-CORE-011** (D)
When `--session UUID` is given and the session's recorded working directory
exists, the executable shall change the process working directory to that
path before opening the frontend.

**REQ-CORE-012** (D)
When `--session UUID` is given and the session's recorded working directory
no longer exists, the executable shall emit a warning notice visible to the
user and continue without changing directory.

**REQ-CORE-013** (T)
The executable shall accept a `--model PROVIDER/ID` argument that overrides
the default model for the session.

**REQ-CORE-014** (T)
The executable shall accept an `--agent TEXT|@PATH` argument. When the value
begins with `@`, the remainder is treated as a file path; the file's contents
are appended to the system prompt. Otherwise the value string itself is
appended to the system prompt.

**REQ-CORE-015** (T)
The executable shall accept a `--no-tools` flag. When set, the built-in tool
set shall be disabled for the session; the model receives no tool definitions.

**REQ-CORE-016** (T)
The executable shall accept a `--no-session` flag. When set, the conversation
shall not be persisted to disk.

**REQ-CORE-017** (T)
The executable shall accept a `--prompt TEXT` argument that sends TEXT as the
first user prompt immediately after startup, without waiting for interactive
input.

**REQ-CORE-018** (T)
When `--prompt -` is given, the executable shall read the initial prompt from
standard input (until EOF) and send it as the first user prompt.

**REQ-CORE-019** (D)
The executable shall accept an `--one-shot` flag. When set, the executable
shall exit automatically after the first complete agent turn and print a
JSON result summary to standard output.

**REQ-CORE-020** (D)
The executable shall accept a `--subagent` flag. When set, the executable
shall behave as `--one-shot` but shall not force the Plain frontend — the
inherited display context (`COYOTE_FRONTEND` or `$winid`) governs frontend
selection, allowing a headful window to open.

**REQ-CORE-021** (D)
The executable shall accept a `--name LABEL` argument. When provided, the
label shall be appended to the window or process name so that the user can
distinguish multiple concurrent coyote instances.

**REQ-CORE-022** (D)
The executable shall accept a `--prompt-filter CMD` argument. When provided,
each interactive prompt shall be passed through the shell command CMD (via
`$SHELL -c CMD`) before being sent to the agent; the filtered output becomes
the prompt.

**REQ-CORE-023** (D)
The executable shall emit an error message on stderr and set a non-zero exit
status when an unrecognised command-line argument is given.

**REQ-CORE-024** (D)
The executable shall accept `-h` and `--help` command-line arguments.
When either is given, the executable shall write a summary of all accepted
arguments and their meanings to standard output and exit with a success
status, without starting a session or opening a frontend window.

---

#### 3.1.3 Session Lineage Propagation

**REQ-CORE-030** (I)
When a session is created, its UUID shall be exported as the environment
variable `COYOTE_SESSION_ID` so that child processes can record the parent
lineage.

**REQ-CORE-031** (I)
When the environment variable `COYOTE_SESSION_ID` is already set at startup
and `COYOTE_PARENT_SESSION` is not set, the executable shall promote the
inherited value to `COYOTE_PARENT_SESSION` and record it in the new session's
JSONL header.

**REQ-CORE-032** (I)
When the `--no-session` flag is active, the executable shall export
`COYOTE_NO_SESSION=1` so that subagent processes inherit the no-session
behaviour.

---

#### 3.1.4 Streaming Output

**REQ-CORE-040** (D)
The agent shall stream assistant text to the active frontend incrementally
as tokens arrive, without buffering the full response before display.

**REQ-CORE-041** (D)
The agent shall stream thinking-block content to the active frontend
incrementally when the model produces extended thinking output.

**REQ-CORE-042** (D)
The agent shall display tool-call start and end events to the active frontend,
including the tool name, arguments, and result summary.

**REQ-CORE-043** (D)
The agent shall display model-selection events (provider, model ID, context
window size) to the active frontend at the start of each session.

**REQ-CORE-044** (D)
The agent shall display session statistics (total tokens, cache tokens, cost
estimate in deci-mils) to the active frontend after each completed turn.

**REQ-CORE-045** (D)
The agent shall display automatic-retry events (attempt number, delay,
error message) to the active frontend when a transient provider error causes
the agent to retry a request.

**REQ-CORE-046** (D)
The agent shall display compaction events (start and end, with summary or
error) to the active frontend when context compaction occurs.

---

#### 3.1.5 Tool Execution

**REQ-CORE-050** (T)
The agent shall provide a built-in `shell` tool that executes a shell command
and returns its combined stdout/stderr output as the tool result.

**REQ-CORE-051** (T)
When the `shell` tool is called with a non-empty `media_type` argument, the
tool shall capture stdout as raw bytes, base64-encode them, and return an
image content block of the specified MIME type instead of a text result.

**REQ-CORE-052** (T)
When a tool result exceeds the configured size cap, the result shall be
truncated; the excess bytes shall be written to a temporary file under `/tmp/`
and the truncated result shall include a trailer stating the path to the
overflow file.

**REQ-CORE-053** (I)
Image tool results (non-empty `media_type`) shall bypass the size cap entirely
and be returned without truncation.

**REQ-CORE-054** (D)
When the model invokes a tool and `--no-tools` is active, the agent shall
return an error result to the model rather than executing the tool.

**REQ-CORE-055** (D)
Tool execution shall be abortable: when the user triggers an abort (via the
Stop tag command in Acme or equivalent in GUI), a running tool invocation
shall be cancelled and the agent loop shall terminate cleanly.

**REQ-CORE-056** (I)
The shell tool shall accept an optional integer `run_group` argument. When
every tool call in a turn carries a valid `run_group > 0`, tool calls shall
be executed in groups: calls within the same group run concurrently, groups
run sequentially in ascending group-number order. When any tool call lacks a
`run_group` (or has `run_group = 0`), all calls in the turn shall execute
sequentially in the original call order. The `run_group` field shall be
stripped from the arguments JSON before the command executor receives it.

---

#### 3.1.6 Context Compaction

**REQ-CORE-060** (D)
When the estimated token count of the conversation history exceeds the
compaction threshold (context window minus `Reserve_Tokens`), the agent shall
automatically trigger context compaction before sending the next request.

**REQ-CORE-061** (D)
The agent shall support manual compaction triggered by the user (via the
Compact tag command in Acme, or the `:compact` GUI command).

**REQ-CORE-062** (D)
Context compaction shall call the active model once with a structured
summarisation prompt, replace the in-memory history with one compaction
summary message followed by a retained tail of the transcript, and record a
compaction entry in the session JSONL file.

**REQ-CORE-063** (D)
When compaction fails (provider error, parsing failure), the in-memory
history shall be left unchanged and an error notice shall be displayed to
the user.

**REQ-CORE-064** (I)
The `--one-shot` and `--subagent` modes shall disable automatic compaction.

**REQ-CORE-065** (D)
The compaction summarisation prompt shall use a structured nine-section
format: (1) Primary Request and Intent, (2) Key Technical Concepts,
(3) Files and Code Sections (with full code snippets and rationale),
(4) Errors and Fixes, (5) Problem Solving, (6) All User Messages (not
tool results), (7) Pending Tasks, (8) Current Work (with verbatim quotes
from the most recent conversation), and (9) Optional Next Step.

**REQ-CORE-066** (D)
The agent shall include an analysis-block drafting phase in the compaction
prompt where the model organises its reasoning before writing the summary.
The analysis block shall be stripped from the stored summary after
compaction completes, retaining only the summary content in context.

**REQ-CORE-067** (D)
The agent shall implement a circuit breaker for automatic compaction:
after three consecutive compaction failures (any cause — provider error,
parsing failure, or empty summary), automatic compaction shall be
suspended for the remainder of the session. Manual compaction shall
still be available.

**REQ-CORE-068** (D)
The agent shall support partial compaction: when the conversation history
exceeds the compaction threshold, the agent may keep the most recent N
turns verbatim and summarise only the earlier portion. The summarised
portion shall be presented as a continuation preamble prefixed with
"This session is being continued from a previous conversation that ran
out of context."

---

#### 3.1.7 Model and Provider Selection

**REQ-CORE-070** (D)
When no `--model` argument is given, the agent shall read the default model
from `~/.coyote/settings.json` (`defaultProvider` / `defaultModel` fields).

**REQ-CORE-071** (D)
When neither `--model` nor `settings.json` specifies a model, the agent shall
select the first available model from the live model registry.

**REQ-CORE-072** (D)
The agent shall support the following LLM providers: OpenAI Chat Completions,
Anthropic Messages, GitHub Copilot, OpenRouter, OpenCode Go, and Ollama Cloud.

**REQ-CORE-073** (D)
API keys for each provider shall be resolved in the following order: (1) a
literal `apiKey` in `~/.coyote/models.json`, (2) a `${ENV_VAR}` interpolation
in `models.json`, (3) the provider-standard environment variable name.

**REQ-CORE-074** (D)
GitHub Copilot tokens that are expired or near expiry shall be automatically
refreshed using the stored refresh token before the request is sent.

**REQ-CORE-075** (D)
In the Acme frontend, the model may be switched at runtime by sending a
`coyote-model+PID/PROVIDER/ID` token via the `/coyote-model` plumb port.
The switch shall take effect on the next `Run_Prompt` call.

**REQ-CORE-076** (D)
In the Acme frontend, the thinking level may be switched at runtime by
sending a `coyote-thinking+PID/LEVEL` token via the `/coyote-thinking` plumb
port.

**REQ-CORE-077** (D)
The agent shall start and operate normally (display the selected frontend
window and accept user input) even when a configured provider's credentials
are invalid, expired, or the provider API is unreachable at startup.  The
provider's portion of the model registry shall be left empty and any
provider-specific failure shall be reported only when the user explicitly
attempts to use that provider's models.

**REQ-CORE-078** (D)
When constructing the OpenCode Go model catalogue, the agent shall obtain
per-model metadata — context window size, maximum output tokens, reasoning
support, and per-token pricing — by cross-referencing the model identifier
list from the OpenCode Go `/v1/models` endpoint against the OpenRouter
model catalogue.  For each Go model ID, the agent shall locate the
matching entry in the OpenRouter catalogue (or its on-disk cache) and
populate the catalogue `Model_Info` record from the OpenRouter fields
(`context_length`, `top_provider.max_completion_tokens`,
`supported_parameters` membership for reasoning, and pricing sub-fields).
Models not found on OpenRouter shall fall back to conservative defaults
(context window 128,000, max tokens 16,384, no reasoning).


---

#### 3.1.8 Session Persistence

**REQ-CORE-080** (T)
Each session shall be persisted as a JSONL file in
`~/.coyote/sessions/<cwd-slug>/` where `<cwd-slug>` is the URL-encoded
representation of the current working directory path.

**REQ-CORE-081** (T)
The session JSONL file shall contain a header record, one record per message
(user, assistant, tool result), compaction records, and model-change records,
in the v3 envelope format.

**REQ-CORE-082** (T)
When `--session UUID` is given, the agent shall reload the conversation
history from the existing JSONL file and resume the session.

**REQ-CORE-083** (T)
When `--no-session` is active, no JSONL file shall be created or written.

**REQ-CORE-084** (D)
The `coyote_list_sessions` utility shall list all sessions saved for the
current working directory, showing session UUID, name, and date.

---

#### 3.1.9 Skill Discovery

**REQ-CORE-090** (T)
The agent shall discover SKILL.md files from the following roots, in order:
`~/.coyote/skills/*/SKILL.md`, `~/.agents/skills/*/SKILL.md`,
`$BASE/share/agents/skills/*/SKILL.md`
(where `$BASE` is the installation prefix derived from the binary path),
`{CWD}/.coyote/skills/*/SKILL.md`, `{CWD}/.agents/skills/*/SKILL.md`.

**REQ-CORE-091** (T)
A SKILL.md file that is missing a `name` or `description` YAML frontmatter
field shall be silently skipped.

**REQ-CORE-092** (D)
Discovered skills shall be formatted into an XML-style block and included in
the system prompt sent to the model.

**REQ-CORE-093** (I)
Project-local skills (CWD roots) shall shadow global skills of the same name.

**REQ-CORE-094** (I)
When the executable path is of the form `$BASE/bin/coyote`, the agent shall
derive the installation prefix `$BASE` by resolving the real path of the
executable and taking the parent of its parent directory; otherwise
`$BASE` shall be empty and the installation-relative skill root
(`$BASE/share/agents/skills/`) shall be skipped.

---

#### 3.1.10 Acme Frontend

**REQ-CORE-100** (D)
The Acme frontend shall open a named window in the running acme instance via
the 9P VFS, using the window ID from `$winid`.

**REQ-CORE-101** (D)
The Acme frontend shall support the following tag commands: Send, Stop, New,
Clear, Continue, Models, Sessions, Thinking, Stats, Compact, Pause, Resume, SetDefault.

**REQ-CORE-102** (D)
The Send tag command shall read the window body text below the last prompt
separator and send it as a new user prompt.

**REQ-CORE-103** (D)
The Stop tag command shall abort the currently running agent turn and cancel
any in-progress tool execution.

**REQ-CORE-104** (D)
The New tag command shall spawn a new coyote instance in a new acme window.

**REQ-CORE-105** (D)
The Sessions tag command shall display the list of sessions for the current
working directory in the window.

**REQ-CORE-106** (D)
The Stats tag command shall display cumulative session statistics (total
tokens, cost) in the window.

**REQ-CORE-107** (D)
The Pause and Resume tag commands shall pause and resume the agent loop at
the next turn boundary.

**REQ-CORE-108** (D)
In the Acme frontend, a `coyote-fork+PID/UUID/N[/S]` token sent via the
`/coyote-fork` plumb port shall fork the session at turn N (and optionally
step S within that turn) and open the forked session in a new coyote window.
When the optional step suffix `/S` is present, the fork shall capture the
conversation up to and including the S-th assistant message and all tool
results from that message's tool-call batch. When the step suffix is absent,
the fork shall capture all complete turns up to and including turn N (the
current behaviour).

**REQ-CORE-108a** (D)
A turn footer carrying a fork token shall be emitted after every assistant
message — both intermediate tool-call responses (stop reason `toolUse`) and
final text responses (stop reason `stop` or `length`). The final footer of
each turn shall use the full-turn token format (`coyote-fork+PID/UUID/N`,
no step suffix) and a double-line separator; intermediate footers shall use
the step-level token format (`coyote-fork+PID/UUID/N/S`) and a single-line
separator to visually distinguish step boundaries from turn boundaries.

**REQ-CORE-108b** (D)
Step-level footers shall be emitted after the last tool result of the
corresponding tool-call batch, so that the forked session includes both the
assistant's tool-call message and the tool results, forming a valid and
loadable conversation state.

**REQ-CORE-109** (D)
The SetDefault tag command shall write the active model identifier and
thinking level to `~/.coyote/settings.json` under the `defaultProvider`,
`defaultModel`, and `defaultThinkingLevel` keys, so that subsequent coyote
sessions inherit the current configuration as their default.

---

#### 3.1.11 GUI Frontend

**REQ-CORE-110** (D)
The GUI frontend shall open a GTK3 application window containing a
conversation view, a prompt input area, a menu bar, and a status bar.

**REQ-CORE-111** (D)
Assistant text shall be rendered with GitHub Flavored Markdown formatting
(bold, italic, code spans, fenced code, tables, strikethrough, links) using
libcmark-gfm.

**REQ-CORE-112** (D)
Tool-call frames shall be embedded in the conversation view as GTK child
anchor widgets, showing the tool name and a status indicator.

**REQ-CORE-113** (D)
The GUI frontend shall support the following menu actions, equivalent to the
Acme tag commands: Send, Stop, New, Clear, Models, Session Stats, Compact,
Pause, Resume.

**REQ-CORE-114** (D)
The GUI frontend shall support vi-style scroll navigation (j/k/g/G/Ctrl-D/
Ctrl-U) in the conversation view.

**REQ-CORE-114a** (D)
The GUI frontend shall provide a follow mode that auto-scrolls the
conversation view to the bottom as new content arrives. Any user scroll
action (mouse wheel, scrollbar drag, keyboard navigation) shall
unconditionally disable follow mode. Follow mode shall be re-enabled only by
clicking the "New output" button, not by repositioning the viewport to the
bottom. Follow mode shall default to enabled at window creation.

**REQ-CORE-115** (D)
The GUI frontend shall propagate `COYOTE_FRONTEND=gui` to all child processes
so that subagents open their own GUI windows.

---

#### 3.1.12 Plain Frontend

**REQ-CORE-120** (D)
The Plain frontend shall write assistant text, tool summaries, and notices
to standard output as plain text with no ANSI escape codes.

**REQ-CORE-121** (D)
In `--one-shot` mode, the Plain frontend shall write a JSON result summary
to standard output after the first complete agent turn and then exit.

---

#### 3.1.13 Session History Replay

**REQ-CORE-130** (D)
When a session is resumed, the agent shall replay the stored conversation
history into the active frontend so the user can see the prior exchange.

**REQ-CORE-131** (D)
The history replay shall render assistant messages with Markdown formatting
in the GUI frontend and as plain text in the Acme and Plain frontends.

---

#### 3.1.14 Error Handling

**REQ-CORE-140** (D)
All errors detected during an agent turn (provider errors, tool execution
failures, JSON parse errors) shall be displayed as notices in the active
frontend; they shall not be silently discarded.

**REQ-CORE-141** (D)
Errors shall also be written to standard error for logging purposes.

**REQ-CORE-142** (D)
The executable shall handle SIGTERM gracefully: in-progress tool executions
shall be cancelled, any open session file shall be flushed, and the process
shall exit cleanly.

---

#### 3.1.15 Ollama Cloud Provider
#### 3.1.15 Ollama Cloud Provider

**REQ-CORE-150** (D)
The agent shall support Ollama Cloud as an LLM provider, identified by the
provider name `"ollama"`. When selected, the agent shall communicate with the
Ollama API using the OpenAI-compatible `/v1/chat/completions` endpoint
described in REQ-CORE-154.
**REQ-CORE-151** (I)
The Ollama provider base URL shall be configurable. The cloud default is
`https://ollama.com/v1/`. When a `baseUrl` key is present in the
`~/.coyote/models.json` entry for the `"ollama"` provider, that value shall
be used instead, permitting use with a locally-running Ollama instance (e.g.
`http://localhost:11434`).

**REQ-CORE-152** (D)
Ollama API authentication shall use a bearer token in the `Authorization:
Bearer <token>` HTTP header. The token shall be resolved using the standard
API key resolution order (REQ-CORE-073), with the provider-standard
environment variable `OLLAMA_API_KEY`. When no API key is configured and
the effective base URL is a localhost address, the `Authorization` header
shall be omitted.

**REQ-CORE-153** (D)
The Ollama provider shall populate the model registry at startup by issuing
`GET /api/tags` against the configured base URL and then enriching each
model entry via `POST /api/show` to extract capabilities (thinking, vision,
tools), context length, and model family. Each entry's `name` field becomes
the model identifier in the registry. When no API key is configured and the
base URL is not a localhost address, registry population shall be skipped.
localhost address, registry population shall be skipped.

**REQ-CORE-154** (I)
**REQ-CORE-154** (I)
Ollama requests shall be sent to `POST /v1/chat/completions` (the OpenAI-
compatible endpoint) using the standard OpenAI chat-completions wire format.
The JSON request body shall include `model`, `messages`, `tools`, `stream`
(set to `true`), and — for thinking-capable models when a non-zero thinking
level is requested — a `reasoning_effort` field mapping to `"low"`,
`"medium"`, or `"high"`. The streaming response shall be parsed as standard
OpenAI SSE (Server-Sent Events): each event contains a JSON delta within a
`data:` line.

**REQ-CORE-155** (I)
The Ollama wire format shall be designated `"openai-completions"` in the
model registry `Wire_Format` field. Tool definitions sent to Ollama models
shall use the standard OpenAI `{type: "function", function: ...}` format.

**REQ-CORE-156** (D)
Token usage for Ollama responses shall be extracted from the final SSE
`usage` event, using the standard `prompt_tokens` and `completion_tokens`
fields. Cache token counts are not reported by the Ollama compat API and
shall be recorded as zero.
Cache token counts are not reported by the Ollama API and shall be recorded as zero.

#### 3.1.16 Man Page

**REQ-CORE-160** (I)
A man page for the `coyote` executable shall be provided in standard
troff/nroff man(7) format, installed as `coyote.1` in the appropriate
man directory.  The man page shall document all command-line arguments,
environment variables used by coyote (`COYOTE_SESSION_ID`,
`COYOTE_PARENT_SESSION`, `COYOTE_NO_SESSION`, `COYOTE_FRONTEND`),
frontend selection behaviour, configuration files, and basic usage
examples.  It shall include the standard man-page sections: NAME,
SYNOPSIS, DESCRIPTION, OPTIONS, ENVIRONMENT, FILES, EXAMPLES, and
SEE ALSO.


---

#### 3.1.17 Enhanced System Prompt

**REQ-CORE-170** (D)
The system prompt shall include a personality definition section that
specifies the agent's communication style: terse, direct, pragmatic; no
cheerleading, motivational language, or artificial reassurance; no
conversational interjections as response openers ("Done —", "Got it",
"Great question").

**REQ-CORE-171** (D)
The system prompt shall include conditional tool-use instructions keyed to
the capabilities currently available in the session. When editing tools are
available, the prompt shall instruct the agent to use them rather than
printing code blocks. When terminal tools are available, the prompt shall
instruct the agent to run commands rather than printing them. When no
editing tools are available, the prompt shall instruct the agent to print
code blocks as suggestions.

**REQ-CORE-172** (D)
Each turn's prompt shall carry a reminder instruction section appended
to the user message. The reminder shall reinforce: persist until the task
is completely resolved before ending the turn; report progress after
3 to 5 tool calls with varied, concise 1-to-2-sentence updates; avoid
repeating verbatim plans across turns; preface each tool batch with a
one-sentence preamble stating why, what, and expected outcome.


#### 3.1.18 Structured Memory System

**REQ-CORE-180** (D)
The agent shall discover and load MEMORY.md index files from
~/.coyote/memory/MEMORY.md and {CWD}/.coyote/MEMORY.md, respecting
a content cap of 200 lines or 25,000 bytes per file with a truncation
warning when exceeded. Memory loading shall be disabled by default
and enabled only when the environment variable COYOTE_ENABLE_MEMORY
is set to "1". When enabled, the loaded content shall be included in
the system prompt as persistent project context.

**REQ-CORE-181** (D)
The system prompt shall describe a four-type memory taxonomy
(user, feedback, project, reference) with explicit when_to_save and
how_to_use guidance for each type. Memories shall be stored as
individual Markdown files in ~/.coyote/memory/.

**REQ-CORE-182** (I)
The feedback memory type shall require a "Why:" line capturing the reason
behind the user's correction or confirmation, enabling future agent
instances to judge edge cases rather than blindly following the rule.
The project memory type shall require absolute dates (converting relative
references like "Thursday") so they remain interpretable over time.

**REQ-CORE-183** (D)
The system prompt shall instruct the agent to search existing memories
before writing new ones, to avoid duplicates. Memory files shall be
indexed via a MEMORY.md file that lists topic files and their purposes;
the agent shall write new topic files and update the index when saving
memories.


#### 3.1.19 Coordinator Subagent Orchestration

**REQ-CORE-190** (D)
When subagent spawning is available, the system prompt shall include a
coordinator-mode instruction section requiring the agent to: launch
independent subagents in parallel when possible; never delegate
understanding — the coordinator shall read all worker results and
synthesize them before writing follow-up prompts; write worker prompts
with specific file paths and line numbers rather than vague "based on
your findings" directives.

**REQ-CORE-191** (D)
Subagent results reported to the main agent shall include a structured
summary block distinguishing: task status (completed, failed, killed),
a human-readable summary, the agent's final text response, and usage
statistics (token count, tool-use count, duration). This structured
format shall help the coordinator distinguish worker completion
notifications from user messages.

**REQ-CORE-192** (I)
The coordinator prompt shall prohibit the coordinator from fabricating
or predicting subagent results before they arrive. When the user asks
about an in-flight subagent, the coordinator shall report status only,
without guessing at findings.


---

### 3.2 External Interface Requirements

#### 3.2.1 LLM Provider APIs

**REQ-CORE-200** (I)
The coyote HTTP client shall communicate with LLM provider APIs using
server-sent event (SSE) streaming over HTTPS, implemented via libcurl.

**REQ-CORE-201** (I)
The OpenAI Chat Completions wire format shall be used for: OpenAI,
OpenRouter, GitHub Copilot (for OpenAI-compatible models), and
OpenCode Go (for OpenAI-compatible models).

**REQ-CORE-202** (I)
The Anthropic Messages wire format shall be used for: direct Anthropic
API access, GitHub Copilot (for Claude models), and OpenCode Go
(for Claude models).

**REQ-CORE-203** (D)
When an image tool result is being sent to a provider using the OpenAI
wire format, the image content shall be split: a plain-text stub in the
tool message and a follow-up user message carrying the `image_url`, because
OpenAI does not support vision content inside `role=tool` messages.

**REQ-CORE-204** (I)
Ollama Cloud and locally-configured Ollama models shall use the OpenAI
compatible chat-completions wire format (`"openai-completions"`). This
format is identical to the one used by OpenRouter and other OpenAI-compat
providers: the chat endpoint is `POST /v1/chat/completions` and the
response stream is standard server-sent events (SSE).

---

#### 3.2.2 acme 9P VFS

**REQ-CORE-210** (I)
The Acme frontend shall access the acme window VFS by mounting the `acme`
namespace using the plan9port 9P client library.

**REQ-CORE-211** (I)
Each concurrent task in the Acme frontend path that accesses the 9P VFS
shall use its own `Nine_P.Client.Fs` connection; connections shall not be
shared between tasks.

**REQ-CORE-212** (D)
Plumb port access (`/coyote-model`, `/coyote-thinking`, `/coyote-fork`) shall
use the `plumb` namespace, mounted separately from the acme namespace.

---

#### 3.2.3 GTK3

**REQ-CORE-220** (I)
The GUI frontend shall use GTK3 (version 3.x) for window management,
widget layout, and event handling.

**REQ-CORE-221** (I)
All GTK operations shall execute on the GTK main loop task (the main Ada
task). Agent events shall be transferred to the GTK main loop via a
thread-safe protected queue.

---

#### 3.2.4 Configuration Files

**REQ-CORE-230** (T)
The agent shall read `~/.coyote/settings.json` at startup to obtain the
default provider, model, thinking level, compaction settings, and
`promptFilter`.

**REQ-CORE-231** (T)
The agent shall read `~/.coyote/models.json` at startup to obtain per-provider
model overrides and API key configuration.

**REQ-CORE-232** (T)
GitHub Copilot OAuth tokens shall be read from and written to
`~/.coyote/auth.json`. Token refresh shall update this file atomically.

**REQ-CORE-233** (I)
When a configuration file is absent or malformed, the agent shall proceed
with defaults and shall not abort startup.

---

#### 3.2.5 Session JSONL Files

**REQ-CORE-240** (T)
Session files shall be written in the v3 JSONL envelope format as specified
in the coyote-session-format skill documentation.

**REQ-CORE-241** (T)
The agent shall be able to read and replay session files in both v1 and v3
formats, for backward compatibility.

---

### 3.3 Internal Interface Requirements

**REQ-CORE-300** (I)
The `Frontend'Class` abstract interface shall define the contract between the
agent dispatch layer and all frontend implementations. All frontend-specific
operations (text append, tool frame management, notice display, status update,
prompt reading, shutdown) shall be routed through this interface.

**REQ-CORE-301** (I)
The `LLM.Events.Agent_Event'Class` hierarchy shall define the contract between
the agent loop (`LLM.Agent`) and the dispatch layer (`Coyote_App.Dispatch`).
No frontend-specific code shall appear in `LLM.Agent`.

**REQ-CORE-302** (I)
The tool result size cap and temporary-file overflow logic shall be
encapsulated in `LLM.Tools.Temp_File` and shall not be duplicated in tool
implementations.

---

### 3.4 Internal Data Requirements

**REQ-CORE-400** (I)
The conversation history shall be maintained in memory as an ordered sequence
of `LLM.Types.Message` records throughout a session.

**REQ-CORE-401** (I)
Each message record shall carry role, content blocks (text, thinking, tool
call, tool result, image), and token usage metadata.

**REQ-CORE-402** (I)
The compaction cut point shall be computed using the token estimation
functions in `LLM.Compaction` based on the `Keep_Recent_Tokens` setting.

---

### 3.5 Environment Requirements

**REQ-CORE-500** (I)
The executable shall be built with GNAT (GCC Ada 2022) using Alire and
GPRbuild. No other Ada compiler is required to be supported.

**REQ-CORE-501** (I)
The Acme frontend shall require plan9port to be installed at
`/usr/local/plan9` or at the path given by the `$PLAN9` environment variable.
If plan9port is absent, the Acme frontend shall not be selected (it is only
selected when `$winid` is set, which requires running inside acme).

**REQ-CORE-502** (I)
The GUI frontend shall require GTK3 runtime libraries to be present on the
target system.

**REQ-CORE-503** (I)
All frontends require libcurl (HTTPS) at runtime.

**REQ-CORE-504** (I)
The GUI frontend requires libcmark-gfm at runtime for Markdown rendering.

**REQ-CORE-505** (I)
The executable shall run on Linux. macOS support via plan9port is possible
but is not a stated requirement.

---

### 3.6 Resource Requirements

**REQ-CORE-600** (A)
Memory usage shall be bounded by the conversation history and the GTK widget
tree. There shall be no unbounded accumulation of history in memory without
compaction.

**REQ-CORE-601** (A)
The agent shall not block the GTK main loop. All LLM API calls and tool
executions shall occur on a separate Ada task.

---

### 3.7 Software Quality Factors

**REQ-CORE-700** (D)
**Streaming latency:** The first streamed token from the LLM shall appear in
the active frontend within 200 ms of arrival from the network, under normal
system load.

**REQ-CORE-701** (D)
**Session persistence reliability:** When the executable exits normally
(including after `--one-shot`), all conversation turns sent during the session
shall be present in the session JSONL file.

**REQ-CORE-702** (D)
**Error visibility:** No error condition encountered during an agent turn
shall be silently discarded. All errors shall produce a visible notice in the
frontend or a message on stderr.

**REQ-CORE-703** (I)
**Frontend isolation:** A panic or exception in one frontend implementation
shall not propagate to affect other components. Exceptions at task boundaries
shall be caught and converted to error notices.

**REQ-CORE-704** (I)
**Maintainability:** New LLM providers shall be addable without modifying
existing provider packages.

---

### 3.8 Design and Implementation Constraints

**REQ-CORE-800** (I)
The implementation language shall be Ada 2022.

**REQ-CORE-801** (I)
The build system shall be Alire with GPRbuild. The build profile for
development shall always be `development` (`alr build` with no flags).
Release builds use `alr build --release` and are only produced on explicit
user request.

**REQ-CORE-802** (I)
JSON processing shall use the GNATCOLL.JSON library.

**REQ-CORE-803** (I)
HTTP and SSE streaming shall use the native libcurl binding in
`LLM.HTTP.Curl_Binding`. No external HTTP subprocess shall be used.

**REQ-CORE-804** (I)
Unicode glyphs used in output shall be expressed via the `UC_*` constants
in `Coyote_App.Utils`. Raw Unicode string literals above Latin-1 shall not
appear in Ada source.

**REQ-CORE-805** (I)
New packages shall follow the existing `.ads`/`.adb` split convention. Public
APIs shall be fully commented in the `.ads` file.

---


### 3.9 Adaptation Requirements

Not applicable to this project. coyote has no installation-dependent or
site-dependent parameters requiring separate specification; all configuration
is user-managed via `~/.coyote/settings.json` and `~/.coyote/models.json`.

---

### 3.10 Safety Requirements

Not applicable to this project. coyote is a developer tool; no
safety-critical hazards have been identified.

---

### 3.11 Security and Privacy Requirements

Deferred per the Project Plan (§5.19.3 waived). No sensitive user data is
handled beyond API keys stored in user-controlled configuration files. This
section will be activated if a relevant deployment scenario is identified.

---

### 3.12 Personnel and Training Requirements

Not applicable to this project. No training programme or operator
qualification requirements are identified.

## 4. Qualification Provisions

Traceability from requirements to test cases. Test Plan reference:
`plan/test-plan.md` (to be authored).

| Requirement ID | Description (abbreviated) | Verification | Test Case (TBD) |
|---|---|---|---|
| REQ-CORE-001 | Plain frontend on --one-shot | D | TC-001 |
| REQ-CORE-002 | Acme frontend on $winid or COYOTE_FRONTEND=acme | D | TC-002 |
| REQ-CORE-003 | GUI frontend on $DISPLAY/$WAYLAND_DISPLAY/COYOTE_FRONTEND=gui | D | TC-003 |
| REQ-CORE-004 | Plain frontend fallback after all checks fail | D | TC-004 |
| REQ-CORE-005 | COYOTE_FRONTEND=acme|gui propagation | I | TC-005 |
| REQ-CORE-006 | --frontend flag overrides detection | T | TC-006 |
| REQ-CORE-010 | --session UUID resumes session | T | TC-010 |
| REQ-CORE-011 | CWD restored on session resume | D | TC-011 |
| REQ-CORE-012 | Warning on missing CWD | D | TC-012 |
| REQ-CORE-013 | --model overrides default | T | TC-013 |
| REQ-CORE-014 | --agent TEXT appended to prompt | T | TC-014 |
| REQ-CORE-015 | --no-tools disables tools | T | TC-015 |
| REQ-CORE-016 | --no-session suppresses file creation | T | TC-016 |
| REQ-CORE-017 | --prompt TEXT sends initial prompt | T | TC-017 |
| REQ-CORE-018 | --prompt - reads from stdin | T | TC-018 |
| REQ-CORE-019 | --one-shot exits and prints JSON | D | TC-019 |
| REQ-CORE-020 | --subagent opens headful window | D | TC-020 |
| REQ-CORE-021 | --name LABEL appended to window | D | TC-021 |
| REQ-CORE-022 | --prompt-filter applied to prompts | D | TC-022 |
| REQ-CORE-023 | Unknown arg → error + non-zero exit | D | TC-023 |
| REQ-CORE-024 | -h/--help prints usage and exits | D | TC-024 |
| REQ-CORE-030 | COYOTE_SESSION_ID exported | I | TC-030 |
| REQ-CORE-031 | Parent session lineage recorded | I | TC-031 |
| REQ-CORE-032 | COYOTE_NO_SESSION propagated | T | TC-032 |
| REQ-CORE-040 | Streaming assistant text | D | TC-040 |
| REQ-CORE-041 | Streaming thinking blocks | D | TC-041 |
| REQ-CORE-042 | Tool call events displayed | D | TC-042 |
| REQ-CORE-043 | Model-select event displayed | D | TC-043 |
| REQ-CORE-044 | Session stats displayed | D | TC-044 |
| REQ-CORE-045 | Auto-retry events displayed | D | TC-045 |
| REQ-CORE-046 | Compaction events displayed | D | TC-046 |
| REQ-CORE-050 | shell tool executes commands | T | TC-050 |
| REQ-CORE-051 | shell tool media_type → image block | T | TC-051 |
| REQ-CORE-052 | Oversized result truncated to temp file | T | TC-052 |
| REQ-CORE-053 | Image results bypass size cap | I | TC-053 |
| REQ-CORE-054 | --no-tools returns error to model | D | TC-054 |
| REQ-CORE-055 | Stop aborts tool execution | D | TC-055 |
| REQ-CORE-056 | run_group controls parallel/sequential execution | T | TC-056 |
| REQ-CORE-060 | Auto compaction at threshold | D | TC-060 |
| REQ-CORE-061 | Manual compaction via command | D | TC-061 |
| REQ-CORE-062 | Compaction summarises and trims history | D | TC-062 |
| REQ-CORE-063 | Compaction failure leaves history intact | D | TC-063 |
| REQ-CORE-064 | --one-shot/--subagent disable auto-compact | I | TC-064 |
| REQ-CORE-065 | 9-section structured compaction prompt | D | TC-065 |
| REQ-CORE-066 | Auto-compact circuit breaker (max 3 failures) | D | TC-066 |
| REQ-CORE-067 | Partial compaction (keep last N turns) | D | TC-067 |
| REQ-CORE-068 | Compaction analysis-block drafting | I | TC-068 |
| REQ-CORE-070 | Default model from settings.json | D | TC-070 |
| REQ-CORE-071 | Fallback to first registry model | D | TC-071 |
| REQ-CORE-072 | All six providers supported | D | TC-072 |
| REQ-CORE-073 | API key resolution order | T | TC-073 |
| REQ-CORE-074 | Copilot token auto-refresh | D | TC-074 |
| REQ-CORE-075 | Runtime model switch via plumb | D | TC-075 |
| REQ-CORE-076 | Runtime thinking switch via plumb | D | TC-076 |
| REQ-CORE-077 | Provider graceful startup | D | TC-077 |
| REQ-CORE-078 | OpenCode Go metadata from OpenRouter | D | TC-078 |

| REQ-CORE-080 | Session saved to correct path | T | TC-080 |
| REQ-CORE-081 | Session uses v3 JSONL format | T | TC-081 |
| REQ-CORE-082 | Session resume loads history | T | TC-082 |
| REQ-CORE-083 | --no-session suppresses file | T | TC-083 |
| REQ-CORE-084 | coyote_list_sessions lists sessions | D | TC-084 |
| REQ-CORE-090 | Skill discovery from five roots | T | TC-090 |
| REQ-CORE-091 | Incomplete SKILL.md silently skipped | T | TC-091 |
| REQ-CORE-092 | Skills included in system prompt | D | TC-092 |
| REQ-CORE-093 | Local skills shadow global | T | TC-093 |
| REQ-CORE-094 | BASE derived from binary path | I | TC-094 |
| REQ-CORE-100..107 | Acme frontend tag commands (Send, Stop, New, etc.) | D | TC-100..107 |
| REQ-CORE-108..108b | Session fork tokens and step-level turn footers | D | TC-108..108b |
| REQ-CORE-109 | SetDefault writes to settings.json | D | TC-109 |
| REQ-CORE-110..115 | GUI frontend capabilities | D | TC-110..115 |
| REQ-CORE-120..121 | Plain frontend capabilities | D | TC-120..121 |
| REQ-CORE-130..131 | Session history replay | D | TC-130..131 |
| REQ-CORE-140..142 | Error handling | D | TC-140..142 |
| REQ-CORE-150..156 | Ollama Cloud provider | D/I | TC-150..156 |
| REQ-CORE-160 | Man page for coyote executable | I | TC-160 |
| REQ-CORE-170 | Personality and interaction rules in prompt | D | TC-170 |
| REQ-CORE-171 | Conditional tool-use instructions by capability | D | TC-171 |
| REQ-CORE-172 | Per-turn reminder instructions appended to prompt | D | TC-172 |
| REQ-CORE-180 | MEMORY.md index file discovery | D | TC-180 |
| REQ-CORE-181 | Four-type memory taxonomy in system prompt | D | TC-181 |
| REQ-CORE-182 | Memory save/retrieval behaviour guidance | I | TC-182 |
| REQ-CORE-183 | Memory search and content caps | D | TC-183 |
| REQ-CORE-190 | Coordinator prompt for subagent orchestration | D | TC-190 |
| REQ-CORE-191 | Structured subagent result reporting | D | TC-191 |
| REQ-CORE-192 | Synthesis-before-delegation instruction | I | TC-192 |
| REQ-CORE-200..204 | Provider API interfaces | I | TC-200..204 |
| REQ-CORE-210..212 | acme 9P VFS interface | I | TC-210..212 |
| REQ-CORE-220..221 | GTK3 interface | I | TC-220..221 |
| REQ-CORE-230..233 | Configuration file interface | T | TC-230..233 |
| REQ-CORE-240..241 | Session JSONL format | T | TC-240..241 |
| REQ-CORE-300..302 | Internal interfaces | I | TC-300..302 |
| REQ-CORE-400..402 | Internal data | I | TC-400..402 |
| REQ-CORE-500..505 | Environment requirements | I | TC-500..505 |
| REQ-CORE-600..601 | Resource requirements | A | TC-600..601 |
| REQ-CORE-700..704 | Quality factors | D/I | TC-700..704 |
| REQ-CORE-800..805 | Constraints | I | TC-800..805 |


---

## 5. Requirements Traceability

All requirements in this specification derive from the following project
objectives stated in the Project Plan (PLAN §1 and §3):

| Objective | Derived Requirements |
|---|---|
| Self-contained Ada LLM agent with no Node.js dependency | REQ-CORE-024, REQ-CORE-500–505, REQ-CORE-800–805 |
| Multi-frontend support (acme, GTK3, plain) | REQ-CORE-001–004, REQ-CORE-100–131 |
| Streaming output | REQ-CORE-040–046, REQ-CORE-700 |
| Tool execution | REQ-CORE-050–056 |
| Session persistence and resume | REQ-CORE-080–084, REQ-CORE-701 |
| Context compaction | REQ-CORE-060–064 |
| Multi-provider LLM support | REQ-CORE-070–078, REQ-CORE-150–156, REQ-CORE-200–204 |
| Man pages for coyote and coyote_sqc | REQ-CORE-160 |
| Skill discovery and system prompt construction | REQ-CORE-090–094 |
| Subagent spawning with session lineage | REQ-CORE-019–020, REQ-CORE-030–032 |
| Error visibility and graceful shutdown | REQ-CORE-140–142, REQ-CORE-702–703 |
| Enhanced system prompt with personality and task constraints | REQ-CORE-170–172 |
| Structured memory system (four-type taxonomy) | REQ-CORE-180–183 |
| Coordinator subagent orchestration | REQ-CORE-190–192 |
| Compaction quality and robustness | REQ-CORE-065–068 |

---

## 6. Notes

**Abbreviations:**
- SRS: Software Requirements Specification
- SDD: Software Design Description
- JSONL: JSON Lines (newline-delimited JSON)
- SSE: Server-Sent Events
- VFS: Virtual File System
- CWD: Current Working Directory
- GFM: GitHub Flavored Markdown
- UUID: Universally Unique Identifier

**Excluded scope:**
- coyote_sqc requirements are in `requirements/coyote-sqc-requirements.md` (SRS-SQC).
- The shared `coyote_renderer` library requirements are covered implicitly
  under the GUI frontend and coyote_sqc requirements.
- `coyote_open` (tool-call detail window) requirements are noted under
  REQ-CORE-084 only; a full specification is deferred.

**Independence limitation:**
This specification was authored by the developer. The user (product owner)
is invited to review it and raise any issues before it advances to
client-control status.
