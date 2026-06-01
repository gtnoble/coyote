# Component Development Log — Core Agent

**Components:** `LLM.Agent`, `LLM.Compaction`, `LLM.Session_Store`,
`LLM.System_Prompt`, `LLM.Skills`, `LLM.Types`, `LLM.Events`

**Source files:** `src/llm/llm-agent.ads/.adb`, `src/llm/llm-compaction.*`,
`src/llm/llm-session_store.*`, `src/llm/llm-system_prompt.*`,
`src/llm/llm-skills.*`, `src/llm/llm-types.*`, `src/llm/llm-events.ads`

---

## Design Rationale

### Why `On_Event` is a synchronous callback, not a queue

The agent loop in `LLM.Agent.Run_Prompt` invokes the `On_Event` callback
synchronously in the caller's task for each event. An alternative would be
to enqueue events into a thread-safe queue and have the agent loop post-process
them. The synchronous approach was chosen because:

1. In the Acme path, the agent task can write directly to the 9P window body
   without any additional synchronisation. A queue would introduce unnecessary
   latency and complexity.
2. In the GUI path, the callback (`Dispatch_Event`) immediately enqueues into
   `Coyote_GUI.Updates`, so the queue exists exactly where it is needed (the
   GTK thread boundary) rather than universally.
3. Provider adapters call `On_Event` from within the libcurl write callback,
   which runs in the calling task. A queue at this layer would decouple the
   streaming backpressure from display, potentially allowing the provider to
   outpace the UI with no flow control.

### Why conversation history is a flat `Message_Vectors.Vector`

A tree structure (to model branching from forks) was considered. The flat
vector was chosen because:
- Session forking is implemented by copying the JSONL file at fork time and
  loading it as a new session; the in-memory history of each session is
  always linear.
- A flat vector makes compaction cut-point calculation straightforward
  (`Find_Cut_Point` walks in reverse from the end).
- The providers' wire formats (OpenAI, Anthropic) expect a flat ordered array.

### Token estimation: 4 bytes per token

The `Estimate_Tokens` function in `LLM.Compaction` uses a simple 4-bytes-per-
token heuristic. The actual ratio varies: English prose is approximately
4 bytes/token; code with long identifiers is higher; minified code is lower.
4 bytes/token is conservative (over-estimates token count), which means
compaction triggers slightly earlier than necessary — a safe bias that avoids
context overflow rather than risking it. A tiktoken binding was considered but
rejected: it would add a C dependency and require per-model tokenizer files.

### Session JSONL: append-per-message, not write-at-turn-end

Each message is appended immediately after it is added to the in-memory
history. This means the JSONL file is always current to the last successfully
completed message, even if the process is killed mid-turn. A partial turn
(user message present, no assistant response yet) is benign on reload:
the agent simply shows the prior context and awaits a new prompt.

### `Compaction_Summary` as a synthetic message role

When compaction replaces a prefix of the history with a summary, the summary
is inserted as a synthetic message with role `compaction_summary`. This role
does not appear in the wire format; `LLM.Agent` maps it to a `user` message
with a structured preamble when building the request JSON. This keeps the
in-memory type system clean (only the values in `LLM.Types.Role`) while
allowing the session store and history replay to distinguish compaction
boundaries from normal user messages.

---

## Key Constraints

- `Run_Prompt` must not be called concurrently with `Compact` on the same
  `Session` value. The `Session` type is `limited private`; callers are
  responsible for sequencing.
- `Abort_Flag` is an atomic boolean that can be set from any task (e.g. the
  `Acme_Event_Task` on a Stop button press). It is checked in the libcurl
  write callback and between tool executions.
- `LLM.Session_Store` opens each file in append mode for each write and
  closes it immediately. This avoids holding a file handle open across the
  lifetime of the agent, which would prevent external tools (e.g. coyote_sqc)
  from reading the session file.

---

## Unit Test Coverage Notes

- `LLM.Compaction`: covered by AUnit tests in `test/src/` —
  `Result_Threshold` boundary cases; `Find_Cut_Point` with varying histories.
- `LLM.Session_Store`: covered by AUnit tests — v1/v3 parse round-trips;
  compaction record encoding; cwd-slug encoding.
- `LLM.Skills`: covered by AUnit tests — discovery with mock file trees;
  shadowing; frontmatter missing-field handling.
- `LLM.Agent`: not directly unit-tested (requires a live provider or mock).
  Covered by demonstration tests.

---

## Open Questions / Future Work

- The `promptFilter` feature runs the filter via `$SHELL -c CMD` synchronously
  in the prompt-reading path. If the filter is slow, this blocks the acme
  event loop. Consider moving it to a separate task if latency becomes an issue.
- The 4-bytes-per-token heuristic should be validated against real session
  data once sufficient sessions are accumulated in coyote_sqc.
