# Coyote

**Coyote** is a native Ada LLM coding agent with GTK and plain-text frontends.
It runs an in-process agentic loop with streaming thinking, tool output,
assistant responses, session persistence, and context compaction.

Sessions are stored in JSONL format compatible with
[pi](https://github.com/mariozechner/pi-coding-agent), so session files can be
shared between coyote and pi.

## Features

- **GTK frontend** — graphical conversation view with Markdown, tool cards,
  session management, status, preferences, keyboard navigation, and Help
- **Plain frontend** — line-oriented output for pipes, scripts, and one-shot
  execution; one-shot mode emits exactly one JSON result on standard output
- **Built-in tools** — `bash`, `read`, `write`, `edit`, `find`, `glob`, and
  `shell`
- **Multiple providers** — OpenAI Chat Completions, Anthropic Messages,
  OpenRouter, GitHub Copilot, and Ollama
- **Context compaction** — automatic or manual summarisation of older history
- **Session persistence** — conversations saved under
  `~/.coyote/sessions/` as JSONL files
- **Subagent support** — invoke `coyote --subagent --prompt -` from a shell
  pipeline. The runtime system prompt replaces this portable command with the
  absolute, shell-quoted path of the active coyote executable. Coordinator-
  launched workers use the headless RPC presentation channel and report their
  short-lived virtual-window conversation to the coordinator; they do not open
  separate desktop windows. Standalone subagents without a coordinator
  channel use the Plain frontend. This virtual-window organization is
  implemented in the development build; display-backed and real-provider
  end-to-end qualification remain open.

## Requirements

- [GNAT](https://www.gnu.org/software/gnat/) Ada 2022 compiler (GCC-based)
- [Alire](https://alire.ada.dev/) package manager (`alr`)
- `libcurl` development headers (for example `libcurl4-openssl-dev`)
- `libcmark-gfm` and `libcmark-gfm-extensions` development headers
- GTK3 and GtkAda development packages
- Lasem 0.6 and Computer Modern math fonts for display math
- Yelp Help viewer for the GTK Help menu
- `gnatcoll` ≥ 25.0.0 (pulled automatically by Alire)

## Building

```sh
# Development build
alr build
```

Binaries are placed in `bin/`:

- `bin/coyote` — the main agent executable
- `bin/coyote_list_sessions` — lists sessions for the current directory
- `bin/coyote_sqc` — Statistical Quality Control application

## Usage

```text
coyote [--session UUID] [--model PROVIDER/ID] [--agent TEXT|@PATH]
       [--no-tools] [--no-session]
       [--prompt TEXT|-] [--one-shot] [--subagent] [--name LABEL]
       [--prompt-filter CMD] [--frontend gui|plain]
```

| Flag | Description |
|---|---|
| `--session UUID` | Resume an existing session by UUID |
| `--model PROVIDER/ID` | Select a model |
| `--agent TEXT\|@PATH` | Append extra instructions to the system prompt |
| `--no-tools` | Disable the built-in tool set |
| `--no-session` | Do not persist the conversation |
| `--prompt TEXT\|-` | Send an initial prompt; `-` reads it from standard input |
| `--one-shot` | Exit after one turn and print a JSON result to standard output |
| `--subagent` | Behave as one-shot; coordinator-launched workers use the headless RPC presentation channel and retain active steering semantics |
| `--name LABEL` | Add an optional label to the GUI window title |
| `--prompt-filter CMD` | Filter interactive prompts through `$SHELL -c CMD` |
| `--frontend gui\|plain` | Override automatic frontend selection |

Without an explicit frontend, coyote selects Plain for non-subagent one-shot
execution, GUI when a display or `COYOTE_FRONTEND=gui` is present, and Plain
otherwise. Coordinator-launched `--subagent` processes use the headless RPC
presentation channel instead of opening GUI windows. Ordinary child processes
intended to open their own GUI window may still inherit
`COYOTE_FRONTEND=gui`.

## GTK controls

The GTK frontend provides File, Edit, View, Agent, Options, and Help menus.
The Agent menu supports sending, stopping, pausing, resuming, compacting,
clearing, changing models, changing thinking level, switching sessions, and
forking a session. The agents panel presents the main agent as the root of a
tree and coordinator-launched short-lived subagents as child virtual windows.
Selecting a live node routes prompts and applicable controls to that agent;
completed nodes remain available for review but do not accept new prompts.
Completed tool cards open structured detail windows. This virtual-window
organization is implemented in the development build; display-backed and
real-provider end-to-end qualification remain open.

The Help menu opens the installed Mallard documentation through Yelp. F1 opens
the overview and Shift+F1 enables contextual help.

## Session listing

```sh
coyote_list_sessions
```

Prints tab-separated rows for the current working directory:

```text
UUID    name    date    snippet
```

Resume a session explicitly with:

```sh
coyote --session UUID
```

## Configuration

Configuration files live under `~/.coyote/`. The main settings file is
`~/.coyote/settings.json`:

```json
{
  "defaultProvider": "github-copilot",
  "defaultModel": "claude-sonnet-4.6",
  "defaultSubagentProvider": "openrouter",
  "defaultSubagentModel": "anthropic/claude-haiku",
  "defaultThinkingLevel": "low",
  "maxRecursionDepth": 1,
  "shellTerminationGraceSeconds": 2,
  "priceDisplay": "si",
  "promptFilter": "m4 -",
  "skillPaths": ["/opt/company/skills", "/home/user/project-skills"]
}
```

## Architecture

Coyote has two supported execution paths:

| Path | Responsibilities |
|---|---|
| GUI | GTK main task owns widgets; an agent task drives prompts and sends updates through protected queues |
| Plain | A headless runner drives the agent synchronously and writes line-oriented output |

Both paths share `LLM.Agent`, session persistence, provider adapters, and
`Coyote_App.Dispatch.Dispatch_Event`. The frontend contract carries structured
streaming events rather than provider-specific wire data.

## Testing

Tests live in `test/src/` and use AUnit:

```sh
cd test && alr run coyote_test
```

The complete development suite currently contains 806 registered tests and
passes 806/806. Live provider tests remain opt-in.

## License

MIT OR Apache-2.0 WITH LLVM-exception
