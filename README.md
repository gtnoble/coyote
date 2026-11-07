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
- **Markdown responses** — assistant output uses direct libcmark-gfm rendering.
  GitHub Flavored Markdown tables are native tables. Inline `$...$` and
  `\(...\)` and display `$$...$$` and `\[...\]` math use the native Ada
  parser/layout engine, with code protected and unsupported input visible as
  source text. The bounded, uneven native profile includes textual definitions,
  fractions, scripts, roots, selected arrays and equation/tag cases, text/font
  styles, delimiters, limits, accents, color, `\mathchoice`, `\hbox`,
  generalized/infix fractions and CD helpers, angle/phase and selected text
  accents, color boxes, rules/dashed segments, and typed `\verb`, `\vcenter`, and `\pmb`
  forms guarded by raw-token literal grammar. Native Gaussian shadow is an
  approximation, not exact CSS; overflow and integer bounds are checked.
  Unsupported input remains visible as source. This is explicitly **not full
  TeX or complete KaTeX compatibility**. Bundled KaTeX 0.16.22 TTFs are in
  `share/coyote/math/fonts/`; retained MIT notices are in
  `share/coyote/math/licenses/`. Registered Unicode mappings and native Pango
  shaping with Unicode fallback are runtime paths; Unicode-range predicates
  are not themselves shaping. System font-family resolution remains unpinned,
  so fallback and shaping are not deterministic or fully qualified. See the
  [supported profile](share/coyote/math/README.md),
  [asset provenance](share/coyote/math/PROVENANCE.md), and
  [coverage map](plan/native-math-coverage.md). Plain output remains
  line-oriented.
- **Session compatibility** — newly written assistant JSONL records contain no
  `format` or `formatVersion` fields. Older records containing those fields
  remain loadable; the fields are ignored and their content is handled as
  Markdown during replay.
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
- Bundled KaTeX 0.16.22 math fonts under `share/coyote/math/fonts/` and their
  retained MIT notices under `share/coyote/math/licenses/` (no Lasem runtime
  dependency)
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

Physical windows are independent GUI processes. `File → New Window` and the
conversation `Fork` action launch a normal interactive GUI with explicit
`--frontend gui`; Fork additionally resumes the newly-created branch session.
These windows do not become coordinator virtual agents or inherit subagent
one-shot behavior.

Without an explicit frontend, coyote selects Plain for non-subagent one-shot
execution, GUI when a display or `COYOTE_FRONTEND=gui` is present, and Plain
otherwise. Coordinator-launched `--subagent` processes use the headless RPC
presentation channel instead of opening GUI windows. Ordinary child processes
intended to open their own GUI window may still inherit
`COYOTE_FRONTEND=gui`.

## GTK controls

The GTK frontend provides File, Edit, View, Agent, Options, and Help menus.
The Agent menu supports sending, stopping, pausing, resuming, compacting,
clearing, changing models, changing thinking level, and switching sessions.
The conversation `Fork` control opens a new physical GUI window containing the
new branch. `View → Agents Window` opens the modeless `coyote : Agents` independent
companion window, which presents the main agent as the root of a tree and
coordinator-launched short-lived subagents as child virtual windows. It is not
transient for the main window, allowing tiling window managers to tile it.
Closing the companion window hides it without stopping coyote; selecting a
live node still routes
prompts and applicable controls to that agent, while completed nodes remain
available for review but do not accept new prompts. Completed tool cards open
structured detail windows. This virtual-window organization is implemented in
the development build; display-backed and real-provider end-to-end
qualification remain open.

The Help menu opens the installed Mallard documentation through Yelp. F1 opens
the overview and Shift+F1 enables contextual help.

### HTTP stalled-transfer protection

Choose **Options → Preferences... → HTTP low-speed timeout (seconds)**, or set
`httpLowSpeedTimeSeconds` in `~/.coyote/settings.json`. The default is 30 seconds;
the supported range is 0–300, and **0 disables protection**. The setting applies
when a new session is created, including Plain and RPC subagent sessions. Saving
preferences does not change an in-flight request or an already-running child.

Transfers below one byte per second for the configured duration can fail with
curl code 28. The agent uses its normal retry policy: up to four attempts with
2-, 4-, and 8-second backoffs. Stop/cancellation does not restart the request.
This is not a total turn deadline or a detector of useful model progress:
heartbeat traffic may keep a stalled generation connected. If necessary, select
the affected agent in the Agents Window and choose **Agent → Stop** before
retrying. Very quiet legitimate responses may need a longer configured timeout.

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

### Ephemeral subagent model override

In the GTK frontend, `Agent -> Subagent Model...` sets a runtime-only model
override used by subsequently launched subagents of the running coordinator.
The override is not written to `settings.json`, survives `New Session`, and
clears when coyote exits; `Use default model` in the picker restores the
persistent `defaultSubagent*` behavior. Precedence for a subagent is: an
explicit `--model` on the invocation, then this override (published to child
processes as `COYOTE_SUBAGENT_MODEL`), then the persistent
`defaultSubagentProvider`/`defaultSubagentModel`, then the ordinary default.
While active, the status bar shows a `sub provider/model-id` segment.

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

Assistant response text uses direct libcmark-gfm Markdown rendering. Native
GFM tables are retained in the GUI. Inline and standalone math use the native
Ada math engine with code protection and visible-source fallback for
unsupported input. Legacy MathML-shaped source is not typeset. Newly written
assistant JSONL has no `format` or `formatVersion` fields; older records
containing those fields remain loadable because the fields are ignored and
their content is handled as Markdown during replay.

## Architecture

Coyote has two supported execution paths:

| Path | Responsibilities |
|---|---|
| GUI | GTK main task owns widgets; an agent task drives prompts and sends updates through protected queues |
| Plain | A headless runner drives the agent synchronously and writes line-oriented output |

Both paths share `LLM.Agent`, session persistence, provider adapters, and
`Coyote_App.Dispatch.Dispatch_Event`. The frontend contract carries structured
streaming events rather than provider-specific wire data. Assistant response
text uses direct libcmark-gfm Markdown rendering. Native GFM tables remain,
and the native Ada math engine handles supported inline/display expressions
with visible-source fallback; legacy MathML source is not typeset. Production
math rendering has no JavaScript runtime. GUI parsing/layout now uses
background jobs. Display formulas are painted by native workers and adopted
in batches. Inline formulas still call `Render_Layout_Inline` on the GTK main
task and submit jobs without `Request_Raster`; do not infer off-thread inline
painting. All widget updates remain on the GTK main task. Display formulas
offer a collapsed **Math structure** expander with a
native semantic tree; human assistive-technology acceptance is still pending.
Inline formulas remain capped at 64 per text view. The worker pool has two
workers and a queue capacity of eight. Cooperative pipeline-loop and phase-boundary checks do not
preempt parser/layout loops or native calls and do not establish the approved
250 ms completion target. The shared 64 MiB `Math_Raster_Budget` applies retained-raster leases to
completed-job vectors, display Cairo surfaces and GTK inline Pixbufs through
weak references. It does not bound whole-job allocation, all actual retention,
transient allocation or process RSS. The approved whole-job 256 MiB and
process-wide cache limits remain unqualified. See
[math requirements](requirements/native-math-compatibility.md)
and the [compatibility test plan](plan/native-math-compatibility-tests.md).
Unsupported input retains visible source.

## Testing

Tests live in `test/src/` and use AUnit. Build once, then run the development
suite directly:

```sh
cd test && alr build --development --profiles=coyote=development
xvfb-run -a /usr/bin/time -f 'wall=%e exit=%x' ./bin/coyote_test
```

PCR-126 developer verification (2026-11-07) passed **1068/1068** in the full
Xvfb suite, with zero failed assertions or unexpected errors and 138.877699 s
cumulative test time. The offline Plain/RPC timeout lifecycle harness also
passed. Commands, logs, and limits are retained in
[the PCR-126 evidence summary](plan/evidence/http-timeout-2026-11-07/README.md).
Run `python3 test/tools/check-http-timeout-lifecycle.py` from the repository root
after a development build; it requires Python 3 and uses isolated fake
credentials and a loopback server, not a live provider. This scoped evidence
is not native-math qualification, end-user acceptance, or an installed-binary
update; existing project warnings remain.

See [the current native-math test report](plan/native-math-parity-test-report.md)
for evidence and qualification status; coordinator-owned §11 is the current
snapshot. Sections §10 and earlier are historical. A previously recorded frozen full
development suite passed 1063/1063 with zero failed assertions or unexpected
errors in 82.418882 s. That run predates the latest source changes and is
historical regression evidence only; it does not qualify the current snapshot,
parity, resource behavior or product acceptance. The original `/tmp` evidence
files are absent, so do not treat them as available or freshly verified. Two
intermediate frozen-suite runs each failed one GTK tool-allocation assertion.
After three isolated focused passes, a test-only correction added a one-second
monotonic GTK poll without weakening the exact 760×600 dimension criterion;
the recorded frozen full suite then passed. All are historical evidence.
Current evidence and qualification limits belong in coordinator-owned report §11. Live provider tests are opt-in;
subagent subprocess tests are guarded by `COYOTE_TEST_SUBAGENT=1`.

## License

MIT OR Apache-2.0 WITH LLVM-exception
