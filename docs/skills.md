# Skills

Skills are reusable instruction documents that coyote surfaces to the agent
at startup.  Only the `name` and `description` from each skill's frontmatter
are injected into the system prompt; the full body is loaded on demand â the
agent reads the `SKILL.md` file via the `shell` tool (e.g. `cat`) when it
decides the skill is relevant.

This lazy-load model keeps the context window lean while still making every
installed skill discoverable.

---

## File Format

A `SKILL.md` file consists of YAML frontmatter followed by the skill body.

```
---
name: my-skill
description: "What this skill does and when to use it. Keywords: foo, bar."
---

# My Skill

Full skill content goes here.  The agent loads this text into its context
window when it decides the skill is relevant to the current task.
```

### Frontmatter Fields

| Field | Required | Description |
|---|---|---|
| `name` | **Yes** | Unique identifier. Lowercase letters, digits, and hyphens. Must match the parent directory name. |
| `description` | **Yes** | Short summary (â¤ 1 024 chars, double-quoted). This is the **only** text the agent sees before deciding whether to load the skill â make it count. |

**Skills missing either required field are silently skipped.**

When two skills share the same `name`, the more project-local entry wins (see
[Discovery & Shadowing](#discovery--shadowing) below).

### Body

The body is free-form Markdown.  Keep it under ~500 lines; put bulky
reference material in sibling files and have the body tell the agent where to
find them.

---

## Discovery & Shadowing

Coyote scans six root groups in order. Later roots shadow earlier ones when two
skills share the same name, so project-local skills override global ones.
The fourth group contains the configured `skillPaths` entries in their saved
array order.

| Priority | Path | Scope |
|---|---|---|
| 1 (lowest) | `~/.coyote/skills/*/SKILL.md` | Global, coyote-specific |
| 2 | `~/.agents/skills/*/SKILL.md` | Global, provider-agnostic |
| 3 | `$BASE/share/agents/skills/*/SKILL.md` | Installation-relative, provider-agnostic |
| 4 | `skillPaths/*/SKILL.md` | Configured roots, in saved array order |
| 5 | `{cwd}/.coyote/skills/*/SKILL.md` | Project-local, coyote-specific |
| 6 (highest) | `{cwd}/.agents/skills/*/SKILL.md` | Project-local, provider-agnostic |

---

## Directory Layout

```
~/.coyote/skills/          â global, coyote-specific root
└── my-skill/
    ├── SKILL.md           â required; frontmatter + overview/instructions
    └── reference.md       â optional; loaded by agent on demand
```

Relative paths in the body should be written relative to the directory
containing `SKILL.md`.

---

## Writing Effective Descriptions

The description is the **sole signal** the agent uses to decide which skills
are relevant.  It is presented in the `<available_skills>` block in the system
prompt.

Rules:
- **Always double-quote** the value â unquoted values containing colons,
  em-dashes, or other YAML special characters cause a silent parse failure.
- Write in **third person** (the text is injected into the system prompt).
- State **what** the skill covers and **when** to load it.
- Include relevant **keywords** so the agent can match the skill to a task
  even when phrasing varies.
- Stay under **1 024 characters**.

Good:
```yaml
description: "Fetches and parses RSS feeds, extracts article text and metadata. Use when asked to read news, monitor feeds, or aggregate content. Keywords: RSS, Atom, news, feed, scrape."
```

Bad (unquoted colon triggers YAML parse error; too vague):
```yaml
description: Helps with web content: news and feeds.
```

---

## Writing Effective Skill Bodies

### Be concise

The agent is already capable â only add context it doesn't already have.
Challenge every paragraph: does this earn its token cost?

### Progressive disclosure

Keep `SKILL.md` to an overview and navigation guide.  Put large reference
tables, long examples, and domain-specific detail in sibling files.  Reference
them from `SKILL.md` so the agent knows to read them when needed.

```
my-skill/
├── SKILL.md        â always loaded when triggered (~overview + TOC)
├── advanced.md     â agent reads when task requires it
└── reference.md    â agent reads when task requires it
```

Avoid chains deeper than one level (`SKILL.md â file.md`, never
`SKILL.md â file.md â detail.md`) â the agent may not follow deeply nested
references.

### Match specificity to fragility

- One correct path â give exact steps (low freedom).
- Many valid approaches â give general guidance (high freedom).

---

## Minimal Example

`~/.coyote/skills/sql-tuning/SKILL.md`:

```markdown
---
name: sql-tuning
description: "PostgreSQL query tuning: EXPLAIN ANALYZE, index selection, vacuum, statistics, partition pruning. Use when asked to speed up slow queries, diagnose table bloat, or choose indexes. Keywords: PostgreSQL, SQL, index, EXPLAIN, vacuum, performance."
---

# SQL Tuning

## Workflow

1. Run `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) <query>;` and capture output.
2. Look for `Seq Scan` on large tables â likely missing index.
3. Check `actual rows` vs `estimated rows` â large divergence â run `ANALYZE`.
4. Confirm index usage with `\d tablename`.

## Index selection

| Pattern | Preferred index type |
|---|---|
| Equality on low-cardinality column | B-tree (default) |
| `LIKE 'prefix%'` | B-tree with `text_pattern_ops` |
| Full-text search | GIN on `tsvector` |
| JSONB containment (`@>`) | GIN |
| Geometric / range types | GiST |

See `reference.md` for full operator class list.
```

---

## Common Pitfalls

| Problem | Fix |
|---|---|
| Skill silently skipped | Ensure both `name` and `description` are present with valid `---`/`---` delimiters |
| Description parse error | Wrap in double quotes; escape literal `"` as `\"` |
| Wrong skill loaded | Check for name collisions across roots; most project-local wins |
| Agent never loads skill | Improve description â add trigger phrases and keywords |
| Context bloat | Move large reference material to sibling files with progressive disclosure |
