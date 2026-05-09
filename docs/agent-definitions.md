# Agent Definitions

Agent definitions let you package a reusable system prompt — plus optional
model and reasoning-level preferences — into a named `AGENT.md` file that
coyote discovers automatically.  Once discovered, a definition can be:

- selected at startup with `coyote --agent NAME`
- spawned programmatically with the `spawn_subagent` tool (pass the name to
  the `agent` parameter)

---

## File Format

An `AGENT.md` file consists of YAML frontmatter followed by the agent body
(the system prompt).

```
---
name: my-agent
description: "One-sentence summary used in the system prompt and spawn_subagent listings."
model: github_copilot/claude-sonnet-4
thinking: medium
---

# My Agent

Full system-prompt text goes here.  Everything after the second `---`
delimiter is injected verbatim as the agent's system prompt.
```

### Frontmatter Fields

| Field | Required | Description |
|---|---|---|
| `name` | **Yes** | Unique identifier. Used with `--agent` and `spawn_subagent`. Lowercase letters, digits, and hyphens; must match the parent directory name. |
| `description` | **Yes** | Short summary (≤ 1 024 chars, double-quoted). Presented to the agent in the `<available_agents>` block so it knows when and how to delegate. |
| `model` | No | Preferred model in `provider/model-id` form (e.g. `github_copilot/claude-sonnet-4`). Overrides the current model when the agent starts or is spawned. |
| `thinking` | No | Reasoning level: one of `off`, `low`, `medium`, `high`, `xhigh`. Overrides the current thinking level when the agent starts or is spawned. |

**Definitions missing either required field are silently skipped.**

When two definitions share the same `name`, the more project-local entry
wins (see [Discovery & Shadowing](#discovery--shadowing) below).

### Body

Everything after the closing `---` delimiter is the agent's system prompt.
When the agent is launched with `--custom-prompt`, that text is appended to
the body.  The body may be empty (zero-length) for agents that rely entirely
on a custom prompt supplied at invocation time.

---

## Discovery & Shadowing

Coyote scans four roots in order.  Later roots shadow earlier ones when two
definitions share the same name, so project-local definitions override global
ones.

| Priority | Path | Scope |
|---|---|---|
| 1 (lowest) | `~/.coyote/agents/*/AGENT.md` | Global, coyote-specific |
| 2 | `~/.agents/agents/*/AGENT.md` | Global, provider-agnostic |
| 3 | `{cwd}/.coyote/agents/*/AGENT.md` | Project-local, coyote-specific |
| 4 (highest) | `{cwd}/.agents/agents/*/AGENT.md` | Project-local, provider-agnostic |

Each direct subdirectory of a root is inspected for an `AGENT.md` file.
Non-directory entries and subdirectories without `AGENT.md` are ignored.

---

## Directory Layout

```
~/.coyote/agents/          ← global, coyote-specific root
└── my-agent/
    ├── AGENT.md           ← required
    └── helpers/           ← optional supporting files (scripts, docs, …)
        └── reference.md
```

The `location` field exposed to the agent in the system prompt points to the
`AGENT.md` file itself, so supporting files are accessible as siblings:

```
helpers/reference.md   # relative to dirname(location)
```

---

## Using Agent Definitions

### At Startup

```sh
coyote --agent my-agent
coyote --agent my-agent --custom-prompt "Focus only on the auth subsystem."
```

### Via spawn_subagent

The `spawn_subagent` tool accepts an `agent` parameter that matches the `name`
field.  The agent definition's body becomes the subagent's system prompt; the
`model` and `thinking` frontmatter fields are honoured automatically.

```json
{
  "agent": "my-agent",
  "prompt": "Review the diff and summarise the security implications."
}
```

### In the System Prompt

Discovered definitions are listed in the `<available_agents>` XML block that
coyote injects into the system prompt.  Each entry includes `name`,
`description`, and `location`, giving the agent everything it needs to decide
when to delegate and where to find supporting resources.

---

## Minimal Example

`~/.coyote/agents/code-reviewer/AGENT.md`:

```markdown
---
name: code-reviewer
description: "Specialist agent for Ada code review. Reviews for style, correctness, and concurrency safety. Use via spawn_subagent when a focused review is needed."
model: github_copilot/claude-sonnet-4
thinking: low
---

You are a specialist Ada code reviewer.  Apply the Ada Quality and Style Guide
rigorously.  Focus on:

1. Naming and formatting conventions
2. Correct use of protected objects and task types
3. Exception handling at task boundaries
4. Any use of shared state across tasks

Return your findings as a numbered list.  Flag critical issues with ⚠️.
```

---

## Common Pitfalls

| Problem | Fix |
|---|---|
| Definition silently skipped | Ensure both `name` and `description` are present and the file has valid `---`/`---` delimiters |
| Description parse error | Wrap the value in double quotes; escape any literal `"` as `\"` |
| Wrong definition loaded | Check for name collisions across roots; the most project-local entry wins |
| `Agent_Not_Found` at runtime | Verify the `name` field matches exactly what was passed to `--agent` or `spawn_subagent` |
| Model not applied | Confirm the `model` value is in `provider/model-id` form and that the provider is configured |
