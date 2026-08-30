# Coyote

**Coyote** is a native Ada LLM coding agent with an [acme](https://en.wikipedia.org/wiki/Acme_(text_editor)) text editor frontend. It opens a `+coyote` acme window and runs an in-process agentic loop — streaming thinking, tool output, and assistant responses directly into the window body.

Sessions are stored in a JSONL format compatible with [pi](https://github.com/mariozechner/pi-coding-agent), so session files can be shared between coyote and pi.

## Features

- **Streaming output** — thinking blocks, assistant text, and tool summaries rendered live in the acme window body
- **Built-in tools** — `bash`, `read`, `write`, `edit`, `find`, `glob`, and `shell — use to spawn ephemeral subagents with `coyote --one-shot --prompt -``
- **Multiple providers** — OpenAI Chat Completions, Anthropic Messages, OpenRouter, GitHub Copilot, and Ollama
- **Context compaction** — automatic or manual summarisation of older conversation history to stay within model context windows
- **Plumber integration** — switch model or thinking level by button-3 clicking `coyote-model+` or `coyote-thinking+` tokens in any acme window; button-3 a `coyote-session+` token to open a session in a new window; button-3 a `coyote-fork+` token at the end of any turn or after a tool-call batch to branch the session at that point
- **Session persistence** — conversations saved to `~/.coyote/sessions/` as JSONL files
- **Subagent support** — spawn an ephemeral coyote window by invoking coyote via the shell tool: pipe the prompt to stdin and call `coyote --subagent --prompt -`. The GUI Preferences dialog can select a dedicated subagent model; `--model provider/id` still overrides it. Use `--agent TEXT|@path` and `--name LABEL` to control the subagent. Session lineage is recorded automatically.

## Requirements

- [GNAT](https://www.gnu.org/software/gnat/) Ada 2022 compiler (GCC-based)
- [Alire](https://alire.ada.dev/) package manager (`alr`)
- [plan9port](https://9fans.github.io/plan9port/) — acme, plumber, and 9P utilities (expected at `/usr/local/plan9`)
- `libcurl` development headers (e.g. `libcurl4-openssl-dev` on Debian/Ubuntu)
- Yelp Help viewer (required by the GTK Help menu)
- `gnatcoll` ≥ 25.0.0 (pulled automatically by Alire)

## Building

```sh
# Development build
alr build

# Release build
alr build --release
```

Binaries are placed in `bin/`:
- `bin/coyote` — the main agent frontend
- `bin/coyote_list_sessions` — lists saved sessions for the current directory

## Usage

```
coyote [--session UUID] [--model PROVIDER/ID] [--agent NAME]
       [--custom-prompt TEXT|@PATH]
       [--no-tools] [--no-session]
       [--prompt TEXT] [--one-shot] [--name LABEL]
       [--prompt-filter CMD]
```

| Flag | Description |
|---|---|
| `--session UUID` | Resume an existing session by UUID |
| `--model PROVIDER/ID` | Select a model (e.g. `github-copilot/claude-sonnet-4.6`) |
| `--agent NAME` | Use a named agent definition from the discovered catalogue |
| `--custom-prompt TEXT\|@PATH` | Append extra instructions to the system prompt; prefix with `@` to load from a file |
| `--no-tools` | Disable the built-in tool set for this session |
| `--no-session` | Do not persist the conversation to disk |
| `--prompt TEXT` | Send TEXT as the first prompt immediately after startup |
| `--one-shot` | Exit after the first complete agent turn; prints a JSON result to stdout |
| `--name LABEL` | Append `:LABEL` to the window name (e.g. `CWD/+coyote:refactor`) |
| `--prompt-filter CMD` | Shell command through which interactive prompts are filtered before being sent to the agent. The raw prompt is written to stdin; stdout becomes the filtered prompt (and the echoed text). Runs via `$SHELL -c CMD`. Overrides `promptFilter` in `settings.json`. |

### Acme tag commands

Once running, the `+coyote` window tag contains:

| Command | Action |
|---|---|
| `Send` | Submit the text typed below the separator line as a new prompt |
| `Stop` | Abort the currently-running agent turn |
| `New` | Start a fresh session |
| `Clear` | Clear the window body |
| `Models` | Open a `+models` sub-window listing available models as `coyote-model+PID/PROVIDER/ID` tokens |
| `Sessions` | Open a `+sessions` sub-window listing saved sessions for the current directory |
| `Thinking` | Open a `+thinking` sub-window with clickable `coyote-thinking+PID/LEVEL` tokens |
| `Stats` | Open a `+stats` sub-window with current session token usage and cost |

### Session listing

```sh
coyote_list_sessions
```

Prints sessions for the current working directory as tab-separated lines:

```
coyote-session+UUID    name    date    snippet
```

Button-3 any `coyote-session+` token in acme (with the coyote plumber rule active) to launch a new `coyote --session UUID` process for that session.

## Configuration

All configuration files live under `~/.coyote/`.

### `~/.coyote/settings.json`

```json
{
  "defaultProvider":          "github-copilot",
  "defaultModel":             "claude-sonnet-4.6",
  "defaultSubagentProvider":  "openrouter",
  "defaultSubagentModel":     "anthropic/claude-haiku",
  "defaultThinkingLevel":     "low",
  "maxRecursionDepth":        1,
  "shellTerminationGraceSeconds": 2,
  "priceDisplay":             "si",
  "appendSystemPrompt":       "You are a helpful coding assistant.",
  "promptFilter":             "m4 -",
  "skillPaths":               ["/opt/company/skills", "/home/user/project-skills"]
}
```

| Field | Description |
|---|---|
| `defaultProvider` | Provider to use for ordinary sessions when `--model` is not specified |
| `defaultModel` | Model ID to use for ordinary sessions when `--model` is not specified |
| `defaultSubagentProvider` | Provider to use for `--subagent` when `--model` is not specified |
| `defaultSubagentModel` | Model ID to use for `--subagent` when `--model` is not specified; absent values fall back to the ordinary default |
| `defaultThinkingLevel` | Reasoning level at startup (`low`, `medium`, `high`) |
| `maxRecursionDepth` | Maximum nested `--subagent` depth; zero disables subagent spawning and the default is 1 |
| `shellTerminationGraceSeconds` | Grace period after SIGTERM is sent to running shell-tool process groups; integer seconds from 0 through 30, default 2. Zero escalates immediately to SIGKILL; a second SIGTERM escalates immediately. |
| `priceDisplay` | GTK model-picker price display: `si` for SI-prefixed $/tok values or `db` for `10 × log10 ($/tok)`. Defaults to `si`; zero prices show `free` and negative prices are blank. |
| `appendSystemPrompt` | Text appended to every system prompt |
| `promptFilter` | Shell command through which interactive prompts (Send/Steer) are filtered. The raw prompt is written to stdin; stdout becomes the prompt sent to the agent and the text echoed in the window. Runs via `$SHELL -c CMD`. Can be overridden per-invocation with `--prompt-filter`. |
| `skillPaths` | Optional JSON array of additional absolute skill-root directories. Each root contains child directories with `SKILL.md`; entries are searched in listed order before project-local roots. |

### `~/.coyote/models.json`

Configures provider API keys and can override provider settings:

```json
{
  "providers": {
    "anthropic": {
      "apiKey": "${ANTHROPIC_API_KEY}"
    },
    "openai": {
      "apiKey": "sk-..."
    },
    "openrouter": {
      "apiKey": "${OPENROUTER_API_KEY}"
    }
  }
}
```

API key resolution order:
1. Literal value in `models.json`
2. `${ENV_VAR}` interpolation in `models.json`
3. Provider-specific environment variable fallback

### `~/.coyote/auth.json`

Written automatically by coyote for providers that use refreshable credentials (e.g. GitHub Copilot). You generally do not need to edit this file by hand.

## Providers and Models

Model specs use `provider/model-id` format:

| Provider | Example spec |
|---|---|
| Anthropic | `anthropic/claude-opus-4-5` |
| OpenAI | `openai/gpt-4o` |
| OpenRouter | `openrouter/anthropic/claude-sonnet-4-20250514` |
| GitHub Copilot | `github-copilot/claude-sonnet-4.6` |
| Ollama | `ollama/neural-chat` |

## Built-in Tools

| Tool | Description |
|---|---|
| `shell` | Execute a shell command; use it to spawn ephemeral subagents: pipe the prompt to stdin and call `coyote --one-shot --prompt -` (pass `--model`, `--agent`, `--name` to control the subagent) |
## Project Context and Skills

Coyote builds the system prompt from several optional sources, loaded each time a session starts. This lets you inject project-specific instructions and reusable reference knowledge without altering the agent's core prompt.

### AGENTS.md

Place an `AGENTS.md` file in the root of your working directory and coyote will automatically append its contents to the system prompt under a `# Project Context` heading. This is the primary way to give the agent project-specific background: architecture notes, coding conventions, build instructions, test commands, and so on.

```
your-project/
| `shell` | Execute a shell command; use it to spawn ephemeral subagents with `coyote --one-shot --prompt -` |
For finer-grained or shareable context, place Markdown files inside a `.coyote/context/` directory. Files are loaded in alphabetical order and injected into the system prompt in the same `# Project Context` block as `AGENTS.md`.

```
your-project/
  .coyote/
    context/
      architecture.md
      conventions.md
```

A global context directory is also supported for instructions you want in every session:

```
~/.coyote/context/
  global-guidelines.md
```

**Load order** (all sources are combined in this order):

1. `~/.coyote/context/*.md` — global context (alphabetical)
2. `{Cwd}/.coyote/context/*.md` — project-local context (alphabetical)
3. `{Cwd}/AGENTS.md` — project root context file

### Skills (`~/.coyote/skills/`, `~/.agents/skills/`, `.coyote/skills/`, `.agents/skills/`)

Skills are reusable reference documents that the agent can load on demand. Each skill lives in its own subdirectory and must contain a `SKILL.md` file with YAML frontmatter declaring `name` and `description` fields:

```
~/.coyote/skills/
  my-skill/
    SKILL.md        ← frontmatter + full reference content
    extra.md        ← optional supporting files
```

**`SKILL.md` structure:**

```markdown
---
name: my-skill
description: "One or two sentence description of what this skill covers and
  when the agent should load it. Keywords: foo, bar, baz."
---

# My Skill

Full reference content here...
```

Coyote scans the built-in roots and any configured `skillPaths` roots at startup
in this order:

1. `~/.coyote/skills/` — global, coyote-specific
2. `~/.agents/skills/` — global, provider-agnostic (shared across agents)
3. `$BASE/share/agents/skills/` — installation-relative, provider-agnostic
4. Configured `skillPaths` roots, in JSON-array order
5. `{Cwd}/.coyote/skills/` — project-local, coyote-specific
6. `{Cwd}/.agents/skills/` — project-local, provider-agnostic

Later roots shadow earlier skills with the same `name`. The GTK `Options →
Preferences...` dialog edits the additional roots with an ordered list,
`Add Directory...`, `Remove Selected`, `Move Up`, and `Move Down` controls.
`Add Directory...` uses a folder chooser. The saved paths affect subsequently
created sessions.

Skills that are found are listed in the system prompt as an `<available_skills>` block. The agent reads a skill's file with the `read` tool when the current task matches its description — skills are **lazy-loaded** so only relevant content consumes context tokens.

Skills missing a `name` or `description` in their frontmatter are silently skipped.

### Agent Definitions (`~/.coyote/agents/`, `~/.agents/agents/`, `.coyote/agents/`, `.agents/agents/`)

Agent definitions are named system-prompt files that the agent can be invoked as subagents by spawning coyote via the shell tool. Each definition lives in its own subdirectory and must contain an `AGENT.md` file with YAML frontmatter declaring `name` and `description` fields:

```
~/.coyote/agents/
  code-reviewer/
    AGENT.md        ← frontmatter + system prompt body
    guidelines.md   ← optional supporting files (accessible via location)
```

[...snip...]

To invoke an agent definition use `--agent NAME` on the command line when launching a new coyote process (e.g. `printf "..." | coyote --one-shot --agent NAME --prompt -`), or provide `--agent NAME` when launching an interactive coyote window. Only names are accepted — inline text and file paths are not valid values for `--agent`.

```
[Agent_Def from --agent NAME]          ← replaces default preamble when supplied
  OR [default preamble + tool guidelines]
[--custom-prompt TEXT|@PATH]           ← appended after preamble when supplied
[appendSystemPrompt from settings.json] ← optional global append
[# Project Context]
  [~/.coyote/context/*.md]             ← global context files
  [{Cwd}/.coyote/context/*.md]         ← project-local context files
  [{Cwd}/AGENTS.md]                    ← project root file
[<available_skills> block]             ← skill names + descriptions only
                                       ← sources: ~/.coyote/skills, ~/.agents/skills,
                                       ←          {Cwd}/.coyote/skills, {Cwd}/.agents/skills
[<available_agents> block]             ← agent names, descriptions, locations
                                       ← sources: ~/.coyote/agents, ~/.agents/agents,
                                       ←          {Cwd}/.coyote/agents, {Cwd}/.agents/agents
[Current date / working directory]     ← always last
```

## Plumber Integration

Coyote listens on three plumb ports:

| Port | Token format | Action |
|---|---|---|
| `/coyote-model` | `coyote-model+PID/PROVIDER/ID` | Switch the active model in the running instance identified by PID |
| `/coyote-thinking` | `coyote-thinking+PID/LEVEL` | Set the reasoning level (`low`, `medium`, `high`) |
| `/coyote-fork` | `coyote-fork+PID/UUID/N[/S]` | Fork the session at turn N (optionally step S within that turn) and open it in a new window |

Session tokens (`coyote-session+UUID`) are emitted by `coyote_list_sessions` and in the `+sessions` sub-window. The plumber rule for them launches a fresh `coyote --session UUID` process rather than routing to a running instance — no running coyote window is required.

Button-3 any matching token in any acme window to trigger the action.

## Architecture

`Coyote_App.Run` drives the application with five concurrent Ada tasks:

| Task | Responsibility |
|---|---|
| `Agent_Task` | Owns the `LLM.Agent.Session`, drives prompts, calls `Dispatch_Event` to render each streaming event into the acme window |
| `Acme_Event_Task` | Reads the acme event file via 9P; handles `Send`, `Stop`, `New`, `Clear`, `Models`, `Sessions`, `Thinking`, `Stats` tag commands |
| `Plumb_Model_Task` | Reads the `/coyote-model` plumb port; calls `LLM.Agent.Set_Model` |
| `Plumb_Thinking_Task` | Reads the `/coyote-thinking` plumb port; calls `LLM.Agent.Set_Thinking` |
| `Plumb_Fork_Task` | Reads the `/coyote-fork` plumb port; forks the session at the requested turn (and optional step) and spawns a new coyote window |

All shared mutable state lives in `App_State`, a protected object. Each task opens its own 9P connection to avoid cross-task contention.

## Help

The GTK frontend uses Yelp as its required Help viewer. Mallard documentation
is installed under `share/help/C/coyote/` and is opened with `help:coyote` topic
URIs. The Help menu provides Overview, task topics, Index, Keys & Shortcuts,
Product Information, and Click for Help. F1 opens Overview; Shift+F1 and Click
for Help arm contextual Help for the next main-window click.

The development checkout also resolves Help pages relative to `bin/coyote`.
The existing GPR `Install` artifact declaration installs the built binaries and
all application data under Alire's default installation prefix:

```sh
alr install
```

The launcher adds the executable-relative `share` directory to Yelp's XDG data
search path before starting Yelp, so the standard `help:coyote` URI works in
both installed and checkout layouts.

For contributors, `yelp-tools` and `itstool` provide Mallard validation and
translation tooling.

## Testing

Tests live in `test/src/` and use AUnit. Integration tests that need a live acme/9P server are separately guarded.

```sh
cd test && alr run coyote_test
```

## License

MIT OR Apache-2.0 WITH LLVM-exception
