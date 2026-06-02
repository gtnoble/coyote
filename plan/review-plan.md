# Subagent Review Plan: Native Agent Implementation

## Purpose

Ten parallel subagent reviews covering correctness of the native Ada agentic
harness added in Phases 0–12.  Each review is scoped to a specific set of
source files and a specific class of correctness property.  Reviews do not
modify source files; they produce structured issue reports.

---

## Output Format

Each review writes its report to `plan/reviews/R<N>-<slug>.md` using this
template:

```markdown
# R<N>: <title>

## Verdict
PASS | PASS_WITH_NOTES | FAIL

## Summary
One paragraph.

## Issues

### [CRITICAL|HIGH|MEDIUM|LOW] <Short title>
**Files:** src/llm/foo.adb:123
**Description:** ...
**Evidence:** paste the relevant code
**Fix:** ...

## Confirmed Correct
Bullet list of properties explicitly verified as correct.
```

Severity definitions:
- **CRITICAL**: Wrong behaviour that will cause incorrect LLM calls, data
  corruption, crashes, or security issues.
- **HIGH**: Wrong behaviour that will reliably fail in normal use but only
  in specific scenarios.
- **MEDIUM**: Incorrect under edge cases or error paths; correct in the happy
  path.
- **LOW**: Style, missing guard, suboptimal but not incorrect.

---

## Pre-review reads (all reviewers)

Before starting your assigned review, read:
1. `/home/gtnoble/.pi/agent/skills/ada-style-guide/SKILL.md`
2. `/home/gtnoble/Projects/pi_acme_dev/AGENTS.md`
3. `plan/native-agent-migration.md`
   (the specification the implementation was built against)

---

## Review Tracks

All ten tracks are independent and can execute in parallel.

---

### R1 — libcurl Binding Safety

**Report file:** `plan/reviews/R1-curl-binding.md`

**Primary files:**
- `src/llm/thin_curl.c`
- `src/llm/llm-http-curl_binding.ads`
- `src/llm/llm-http-curl_binding.adb`
- `src/llm/llm-http.adb`

**Also read:** `/usr/include/x86_64-linux-gnu/curl/curl.h` (for CURLOPT numeric
values and the write-callback signature).

**Properties to verify:**

1. **Write callback signature** — the exported `Ada_Write_Callback` must have
   the C type `size_t (*)(char*, size_t, size_t, void*)` exactly.  Check that
   `Convention => C` and `Export` are both present, and that the Ada parameter
   types map to the C types.

2. **Write_Context layout** — `Write_Context` contains `On_Chunk_Address :
   System.Address`.  The callback body does:
   ```ada
   Ctx : Write_Context;
   for Ctx'Address use User_Data;
   pragma Import (Ada, Ctx);
   Handler : access procedure (Data : String);
   for Handler'Address use Ctx.On_Chunk_Address;
   pragma Import (Ada, Handler);
   ```
   Verify that: (a) `On_Chunk_Address` stores the address of the `On_Chunk`
   access variable on the caller's stack frame; (b) the caller's stack frame
   is guaranteed live during `curl_easy_perform` (which blocks); (c) reading
   `Handler` via the address overlay correctly retrieves the procedure pointer;
   (d) `Handler.all (Data)` is a valid call.

3. **CURLOPT_NOSIGNAL** — must be set to `1` on every handle before
   `curl_easy_perform`.  Verify it is set in both `Post` and `Get` paths in
   `llm-http.adb`.

4. **Curl handle cleanup on exception** — if the `On_Chunk` callback raises an
   exception, does the curl handle get cleaned up?  Verify `Easy_Cleanup` is
   called on all exit paths.

5. **Header list cleanup** — `curl_slist_free_all` must be called after
   `curl_easy_perform` on every path including exceptions.

6. **Null URL guard** — what happens if `URL = ""`?  Does `curl_easy_setopt`
   with a null URL crash or return an error code?  Verify the error code is
   checked.

7. **Return value of curl_easy_setopt wrappers** — the C wrappers in
   `thin_curl.c` return `CURLcode`.  Are the return values checked in the Ada
   body, or silently ignored?  A non-CURLE_OK return from `Set_URL` or
   `Set_Write_Function` means the operation will fail silently.

8. **Thread safety** — `curl_easy_init` / `curl_easy_perform` / `curl_easy_cleanup`
   are thread-safe per-handle (each handle is used in exactly one task at a
   time).  Verify no handle is shared across tasks or reused after cleanup.

---

### R2 — SSE Parser Correctness

**Report file:** `plan/reviews/R2-sse-parser.md`

**Primary files:**
- `src/llm/llm-sse.adb`
- `src/llm/llm-sse.ads`

**Reference:** The SSE specification (RFC-like): fields start with `event:`,
`data:`, `id:`, or `:` (comment).  Records are separated by blank lines
(`\n\n`).  Multiple `data:` lines within one record are concatenated with `\n`.
The space after the colon is optional but conventional.

**Properties to verify:**

1. **Blank-line record terminator** — a complete SSE record ends with `\n\n`
   (two consecutive newlines).  Verify the parser correctly accumulates partial
   data and only returns an event when the double-newline is seen.

2. **Data line stripping** — `data: {...}` must strip the leading `data: `
   prefix including the optional single space.  Verify behaviour when no space
   is present (`data:{...}`).

3. **Multiple data lines** — if a record contains:
   ```
   data: line1
   data: line2
   ```
   the data should be `"line1\nline2"`.  Verify this concatenation.

4. **Event name handling** — `event: ping` must be silently consumed
   (`Next_Event` returns False).  `event: message_start` must set the
   event name string.  Verify an event with only `data:` and no `event:`
   line returns an empty event name.

5. **`[DONE]` passthrough** — `data: [DONE]` must be returned to the caller
   (not silently dropped), allowing providers to detect end-of-stream.

6. **Partial chunk across Feed calls** — verify that `Feed ("data: hel")` then
   `Feed ("lo\n\n")` produces one complete event with data `"hello"`.

7. **Comment lines** — lines starting with `:` are comments and must be
   ignored.

8. **`id:` and `retry:` lines** — must be silently ignored (we don't use them).

9. **Reset** — verify `Reset` clears all internal state including partial
   line buffers.

10. **CRLF input** — some servers send `\r\n` line endings.  Does `\r` appear
    in the data field when CRLF is received?  The pi RPC skill notes that
    trailing `\r` should be stripped.

---

### R3 — OpenAI Completions Wire Format

**Report file:** `plan/reviews/R3-openai-completions.md`

**Primary files:**
- `src/llm/llm-providers-openai_completions.adb`
- `src/llm/llm-providers-openai_completions.ads`

**Reference:** OpenAI Chat Completions API v1.  The critical fields are
documented in the plan §Phase 2.

**Properties to verify:**

1. **System message placement** — the system prompt must be the FIRST message
   in the `messages` array with `"role":"system"`.  If `System_Prompt = ""`
   no system message should be sent.  Verify both cases.

2. **Message serialisation:**
   - User message: `{"role":"user","content":"<text>"}` — verify the content
     field is a plain string (not an array) for OpenAI.
   - Assistant text: `{"role":"assistant","content":"<text>"}`.
   - Assistant with tool calls: `{"role":"assistant","content":null,
     "tool_calls":[{"id":"<id>","type":"function","function":{"name":"<name>",
     "arguments":"<json_string>"}}]}`.  **Critical**: `arguments` must be a
     JSON *string* (serialised JSON), not a JSON object.
   - Tool result: `{"role":"tool","tool_call_id":"<id>","content":"<text>"}`.

3. **Tools array format** — each entry must be:
   ```json
   {"type":"function","function":{"name":"...","description":"...","parameters":{...}}}
   ```
   The `Schema_Json` from `Tool_Descriptor` is the `parameters` object.  Verify
   the outer `"type":"function","function":` wrapper is present.  Verify that
   when `Tools_Json = "[]"` or `No_Tools = True`, the `tools` field is omitted
   entirely (not sent as `[]`).

4. **Tool call assembly** — OpenAI streams tool calls in fragments.  Each
   `content_block_delta` for a tool call increments an `index` value.
   The accumulation per index must:
   - Start a new tool call when a new `index` is seen.
   - Concatenate `function.arguments` deltas.
   - Emit `Tool_Call_End` with the complete arguments string when `[DONE]`
     arrives.
   Verify the code handles the case where two tool calls appear in one
   response (different `index` values 0 and 1).

5. **Stop reason mapping** — verify the mapping from OpenAI `finish_reason`
   strings to `LLM.Types.Stop_Reason`:
   - `"stop"` → `Stop`
   - `"length"` → `Length`
   - `"tool_calls"` → `Tool_Use`
   - `"content_filter"` → `Error_Stop`
   - anything else → `Unknown_Stop`

6. **Usage extraction** — the `usage` object appears at the top level of the
   final SSE chunk (not inside `choices`).  Verify the parser reads from the
   right location.  Also verify the field names: `prompt_tokens` (not `input`)
   and `completion_tokens` (not `output`).

7. **Thinking tokens** — OpenAI/OpenRouter reasoning appears in
   `choices[0].delta.reasoning` (a string field, not a nested object).  Verify
   `Thinking_Delta` events are emitted with the content of this field.

8. **`max_completion_tokens` vs `max_tokens`** — newer OpenAI models use
   `max_completion_tokens`; older ones use `max_tokens`.  Check which field
   name the implementation sends.

---

### R4 — Anthropic Messages Wire Format

**Report file:** `plan/reviews/R4-anthropic-messages.md`

**Primary files:**
- `src/llm/llm-providers-anthropic_messages.adb`
- `src/llm/llm-providers-anthropic_messages.ads`

**Reference:** Anthropic Messages API.  The critical difference from OpenAI:
system prompt is a top-level field, content is always an array of typed blocks,
tools use `input_schema` not `parameters`.

**Properties to verify:**

1. **Required headers** — all Anthropic requests must include:
   - `anthropic-version: 2023-06-01`
   - `anthropic-beta: interleaved-thinking-2025-05-14`
   - `x-api-key: <key>` (NOT `Authorization: Bearer`)
   Verify all three are present.  Note: for GitHub Copilot the auth header
   is `Authorization: Bearer`, not `x-api-key`.  Verify the Anthropic_Messages
   provider does NOT add `x-api-key` when used via GitHub Copilot (which
   injects its own auth).

2. **System prompt placement** — the system prompt is a top-level `"system"`
   field, NOT a message in the `messages` array.  Verify it is not accidentally
   inserted as `{"role":"system",...}` in `messages`.

3. **Message serialisation (content arrays):**
   - User text: `{"role":"user","content":[{"type":"text","text":"..."}]}`
   - Assistant text: `{"role":"assistant","content":[{"type":"text","text":"..."}]}`
   - Assistant tool call: content block type must be `"tool_use"` (not
     `"tool_call"`), with fields `"id"`, `"name"`, `"input"` (an object, not
     a string).  **Critical**: `"input"` must be a parsed JSON object, not a
     JSON string.
   - Tool result: `{"role":"user","content":[{"type":"tool_result",
     "tool_use_id":"<id>","content":"<text>"}]}`  Note: it goes in a **user**
     message, not a separate `"tool"` role.

4. **Tools format** — each entry must use `"input_schema"` (not `"parameters"`):
   ```json
   {"name":"...","description":"...","input_schema":{...}}
   ```
   Verify the outer wrapper does NOT include `"type":"function"` (that is
   OpenAI format).

5. **Thinking field** — when `Thinking /= Off`, the request must include:
   ```json
   {"thinking": {"type": "enabled", "budget_tokens": <N>}}
   ```
   When `Thinking = Off`, the field must be omitted entirely.  Verify the
   budget values for each level against the plan spec.

6. **SSE event mapping:**
   - `content_block_start` with `content_block.type = "tool_use"` must set
     `Tool_Call_Id` from `content_block.id` and `Tool_Name` from
     `content_block.name` at this point, not just at delta time.
   - `content_block_delta` with `delta.type = "input_json_delta"` carries
     `delta.partial_json` (not `delta.text` or `delta.delta`).  Verify the
     correct field name is read.
   - `message_delta` carries `delta.stop_reason` and
     `usage.output_tokens`.  Note: Anthropic uses `output_tokens` not
     `completion_tokens`.

7. **Stop reason mapping** — verify:
   - `"end_turn"` → `Stop`
   - `"max_tokens"` → `Length`
   - `"tool_use"` → `Tool_Use`
   - `"error"` → `Error_Stop`

8. **Event ordering** — `Agent_Start_Event` must fire before the first SSE
   chunk is processed; `Agent_End_Event` must fire after `message_stop`.
   Verify neither fires multiple times per `Send` call.

---

### R5 — GitHub Copilot Auth and Dispatch

**Report file:** `plan/reviews/R5-github-copilot.md`

**Primary files:**
- `src/llm/llm-auth-github_copilot.adb`
- `src/llm/llm-providers-github_copilot.adb`
- `src/llm/llm-providers-github_copilot-catalogue.adb`

**Reference:** Plan §3.1 and the live credential file at
`~/.pi/agent/auth.json`.

**Properties to verify:**

1. **Token refresh request** — `Refresh_Token` must call:
   ```
   GET https://api.github.com/copilot_internal/v2/token
   Authorization: Bearer <Creds.Refresh_Token>
   User-Agent: GitHubCopilotChat/0.35.0
   Editor-Version: vscode/1.107.0
   Editor-Plugin-Version: copilot-chat/0.35.0
   Copilot-Integration-Id: vscode-chat
   ```
   Verify all five headers are sent and the URL path is exactly
   `/copilot_internal/v2/token`.

2. **Token refresh response parsing** — the response is
   `{"token":"tid=...;...","expires_at":<unix_s>}`.  Note `expires_at` is
   in **seconds**, but `Creds.Expires_Ms` stores **milliseconds**.  Verify the
   multiplication by 1000 is present.  Also check for the padding: the plan
   says subtract 5 minutes (300 000 ms) so the token is refreshed before it
   actually expires.

3. **Base URL extraction** — `proxy-ep=proxy.individual.githubcopilot.com` must
   yield `https://api.individual.githubcopilot.com` (replace `proxy.` with
   `api.`).  Verify the string manipulation handles both the `proxy.` prefix
   removal and the `https://api.` prefix addition correctly.

4. **Static headers on API calls** — every request sent to the Copilot base URL
   must include:
   - `User-Agent: GitHubCopilotChat/0.35.0`
   - `Editor-Version: vscode/1.107.0`
   - `Editor-Plugin-Version: copilot-chat/0.35.0`
   - `Copilot-Integration-Id: vscode-chat`
   - `Openai-Intent: conversation-edits`
   Verify these are added unconditionally in `Send`.

5. **X-Initiator logic** — `X-Initiator: user` when the last message in
   `Messages` has `Role = User`; `X-Initiator: agent` otherwise.  Verify the
   logic handles an empty `Messages` vector without raising.

6. **Wire format selection** — `Supports_Anthropic = True` must select the
   Anthropic Messages path; `Supports_Anthropic = False` must select OpenAI
   Completions.  For Anthropic path: verify the base URL passed to
   `Anthropic_Messages.Create` uses the dynamic base URL from `Get_Base_Url`,
   NOT `https://api.anthropic.com`.

7. **Auth header on Anthropic path** — when using `Anthropic_Messages` through
   Copilot, the auth must be `Authorization: Bearer <copilot_access_token>`.
   Anthropic direct uses `x-api-key`.  Verify the provider uses whichever
   header the caller (GitHub_Copilot adapter) injects, and does NOT add its
   own conflicting auth header.

8. **Catalogue field mapping** — for a chat model entry, verify:
   - `capabilities.supports.max_thinking_budget = 0` → `Max_Thinking_Budget = 0`
   - Non-empty `capabilities.supports.reasoning_effort` array → `Reasoning = True`
   - Both `"/v1/messages"` and `"/chat/completions"` in `supported_endpoints`
     → `Supports_Anthropic = True` AND `Supports_OpenAI = True`
   - `capabilities.type = "embeddings"` → entry is excluded from catalogue

9. **`Ensure_Valid` mutex** — if two tasks call `Ensure_Valid` simultaneously,
   only one should call `Refresh_Token`; the other should wait and then use
   the freshly-refreshed token.  Verify the protected object prevents
   double-refresh.

---

### R6 — OpenRouter Provider and Catalogue

**Report file:** `plan/reviews/R6-openrouter.md`

**Primary files:**
- `src/llm/llm-providers-openrouter.adb`
- `src/llm/llm-providers-openrouter-catalogue.adb`

**Reference:** Plan §3.2 and §3.3; the live API at
`https://openrouter.ai/api/v1`.

**Properties to verify:**

1. **Required headers** — every OpenRouter request must include:
   - `Authorization: Bearer <api_key>`
   - `HTTP-Referer: https://github.com/gtnoble/coyote`
   - `X-Title: coyote`
   Verify all three are present.

2. **Reasoning injection** — when `Thinking /= Off` and the model has
   `Reasoning = True`, the request body must include:
   ```json
   {"reasoning": {"effort": "<low|medium|high>"}}
   ```
   Level mapping: `Minimal|Low` → `"low"`, `Medium` → `"medium"`,
   `High|X_High` → `"high"`.  Verify the field is omitted when
   `Thinking = Off` or `Reasoning = False`.

3. **Pricing conversion** — the API returns prices as decimal strings, e.g.
   `"0.000003"` ($ per token).  The implementation must multiply by
   `1_000_000.0` to get $/M tokens.  Verify:
   - `Long_Float'Value ("0.000003") * 1_000_000.0 = 3.0`
   - An absent `input_cache_read` field → `Cost_Cache_Read = 0.0` (not an
     exception or garbage value).
   - A `"0"` pricing string (free models) → `0.0`, not a parse error.

4. **Context window selection** — `top_provider.context_length` takes priority
   over top-level `context_length`.  But `top_provider.context_length` can be
   `null` in the JSON.  Verify the null case falls back to top-level
   `context_length`, and that null is not parsed as 0.

5. **`supported_parameters` check** — `"reasoning"` in the array → `Reasoning = True`.
   Note: `"include_reasoning"` (a different field used by some models) must NOT
   trigger `Reasoning = True` unless the plan explicitly covers it.

6. **Cache file atomic write** — the cache is written via temp-file + rename.
   Verify the temp file is in the same directory as the target (cross-device
   rename would fail).

7. **Cache expiry check** — `fetched_at` is a Unix timestamp in seconds.
   Verify the comparison uses the same units (not mixing seconds with
   milliseconds or Ada.Calendar ticks).

8. **No-auth catalogue fetch** — `GET /api/v1/models` is called without an
   `Authorization` header (the endpoint is public).  Verify no API key is sent.

---

### R7 — Pi Adapter JSON Mapping

**Report file:** `plan/reviews/R7-pi-adapter.md`

**Primary files:**
- `src/llm/llm-agent-pi_adapter.adb`
- `src/coyote_app-dispatch.adb` (the consumer — read but do not modify)

**Method:** For each event type handled in `To_Pi_Json`, cross-check the
produced JSON against the corresponding handler in `Dispatch_Pi_Event`.

**Properties to verify:**

1. **`agent_end` messages field** — the adapter produces
   `{"type":"agent_end","messages":[]}`.  In `Dispatch_Pi_Event`, `agent_end`
   does not read the `messages` field at all.  This is correct; confirm.

2. **`message_end` field names** — the adapter sets `message.usage` with
   fields `input`, `output`, `cacheRead`, `cacheWrite`.  In `Dispatch_Pi_Event`
   the `message_end` handler reads `Get_Integer (Usage, "input")`,
   `Get_Integer (Usage, "cacheRead")`, etc.  Verify the field names match
   exactly (case-sensitive).  Also verify `stopReason` (camelCase) not
   `stop_reason`.

3. **`tool_execution_start` args field** — the adapter calls
   `Args_Object (To_String (Event.Args_Json))` to produce a JSON object from
   the args string.  In `Dispatch_Pi_Event`, `tool_execution_start` reads
   `Get_Object (Event, "args")` and iterates with `Map_JSON_Object`.  Verify
   that `Args_Object` returns a JSON object (not a string) and that an invalid
   JSON args string returns `{}` rather than raising.

4. **`model_select` field names** — the adapter emits `"contextWindow"` (camelCase).
   `Dispatch_Pi_Event` reads `Get_Integer (Model_Val, "contextWindow")`.
   Verify the exact field name.  Also verify `"provider"` and `"id"` (not
   `"model_id"`).

5. **`get_state` response model object** — the `Session_Info_Event` adapter
   produces `"model": {}` (empty object).  The `get_state` handler in dispatch
   reads `Provider` and `Model_Id` from `model`, and only sets
   `State.Current_Model` when both are non-empty AND the model is not already
   set.  Verify that the empty object does not clobber a model already set by
   a prior `model_select` event.

6. **`get_session_stats` cost field** — the adapter emits
   `"cost": <Long_Float>` in dollars (e.g. `0.0045`).  `Dispatch_Pi_Event`
   calls `Get_Cost_Dmil (Data, "cost")` which reads a JSON float and
   multiplies by `10_000.0` to get dmil.  Verify the round-trip:
   `dmil → / 10_000 → float → * 10_000 → dmil`.  Check for rounding
   correctness on non-round values.

7. **`auto_retry_end` `finalError` field** — the adapter always emits
   `"finalError"` even on success (empty string).  Dispatch reads
   `Get_String (Event, "finalError")`.  This is fine since the dispatch
   handler only uses it when `success = false`.  Confirm.

8. **Missing event types** — list every `Message_Update_Kind` that returns `""`
   from `To_Pi_Json` (Tool_Call_Start, Tool_Call_Delta, Tool_Call_End, etc.).
   Verify that none of these should produce a pi-protocol event.  Tool call
   display is handled by `Tool_Execution_Start/End_Event` (which the agentic
   loop emits directly), not by `Message_Update_Event`.  Confirm this
   reasoning is correct.

9. **`thinking_end` vs `text_end` handling in dispatch** — `Dispatch_Pi_Event`
   handles `thinking_end` by appending a blank line separator.  Verify the
   adapter emits `{"type":"message_update","assistantMessageEvent":
   {"type":"thinking_end"}}` (not `"thinking_block_stop"` or similar).

---

### R8 — Session Store JSONL Format Compatibility

**Report file:** `plan/reviews/R8-session-store.md`

**Primary files:**
- `src/llm/llm-session_store.adb`
- `src/session_lister.adb` (the reader — check for compatibility)
- `src/coyote_app-history.adb` (the renderer — check for compatibility)

**Method:** For each message type written by `Append_Message`, check that
`Session_Lister.Parse_Session_File` and `History.Render_Session_History` can
correctly read it back.

**Properties to verify:**

1. **Header line format** — `Session_Lister.Parse_Session_File` reads the first
   line to extract the session UUID and metadata.  Verify the header produced
   by `Create_Session` has the exact fields the lister expects: `id`, `version`,
   `createdAt` (or `created_at`?), `workDir` (or `work_dir`?).  Check the
   exact field names used by both writer and reader.

2. **Role strings** — `Session_Lister` and `History` identify messages by their
   `"role"` field value.  Verify exact matches:
   - User message: `"user"` (not `"User"`)
   - Assistant message: `"assistant"` (not `"Assistant"`)
   - Tool result: is it `"toolResult"` or `"tool_result"` or `"tool"`?  Check
     both writer and reader.

3. **Tool result structure** — the plan specifies:
   ```json
   {"role":"toolResult","toolCallId":"<id>","toolName":"<name>",
    "content":[{"type":"text","text":"<result>"}],"isError":false}
   ```
   Verify `History.Render_Session_History` reads `"toolCallId"` (not
   `"tool_call_id"`) and `"toolName"` (not `"tool_name"`).

4. **Assistant message with tool calls** — the plan specifies:
   ```json
   {"role":"assistant","content":[{"type":"toolCall","id":"...","name":"...",
    "arguments":<object>}]}
   ```
   Note: `"toolCall"` (not `"tool_use"` which is Anthropic wire format).
   Verify the type string matches what `History` expects.

5. **Usage field names** — the assistant message `usage` object uses field
   names `"input"`, `"output"`, `"cacheRead"`, `"cacheWrite"` — matching
   the LLM.Types.Usage record.  Verify `History.Render_Session_History` reads
   these same field names when restoring token stats.

6. **UUID v4 format** — the generated UUID must follow
   `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx` (36 chars, 4 hyphens, version nibble
   = 4, variant bits = 10xx).  Verify: length == 36, char 14 == '4',
   char 19 in `['8'..'9','a'..'b']`.

7. **Timestamp units** — `Session_Lister.Format_Timestamp` expects an ISO-8601
   string (e.g. `"2025-05-01T12:34:56Z"`) or a Unix timestamp as a number.
   Verify what format the session store writes and whether the lister can
   parse it.

8. **`Fork_Session` compatibility** — `Fork_Session` reads entries by role to
   count turns (a turn is one user message + all following non-user messages
   until the next user message).  Verify the native session's role strings
   match the counting logic in `Fork_Session`.

---

### R9 — Agentic Loop Correctness

**Report file:** `plan/reviews/R9-agent-loop.md`

**Primary files:**
- `src/llm/llm-agent.adb`

**Also read:**
- `src/llm/llm-types.ads` (Message type)
- `src/llm/llm-tools.ads` (Execute)
- `src/llm/llm-session_store.ads` (Append_Message)

**Properties to verify:**

1. **Tool call message construction** — after executing tools, the loop must
   build TWO messages and append both to `History`:
   - An assistant message containing `Tool_Call_Block` entries (one per tool
     call in the turn).
   - One or more user/tool-result messages containing `Tool_Result_Block`
     entries (one per tool result).
   The next LLM call must see both in `History`.  Verify the order is:
   `[...existing..., assistant_with_tool_calls, tool_results, ...]`

2. **Tool result ID matching** — the `Tool_Call_Id` in each `Tool_Result_Block`
   must match the `Tool_Call_Id` in the corresponding `Tool_Call_Block`.
   Verify the agentic loop uses the same ID from the event when building the
   tool result message.

3. **Provider construction per-turn** — a new provider object is created for
   each LLM call.  Verify the provider is NOT reused across turns (SSE state
   in the provider must be fresh each time).

4. **Abort flag check timing** — `Request_Abort` sets a protected flag.
   The loop checks this flag after each tool-execution batch.  Verify the
   flag is also checked before attempting the next LLM call (so an abort
   during tool execution stops the loop cleanly without making another API
   call).

5. **Auto-retry scope** — retry must wrap only the `Provider.Send` call, not
   the entire tool-execution batch.  Verify the retry loop does not re-execute
   already-completed tool calls.

6. **Session persistence timing** — user message must be persisted BEFORE the
   first LLM call (so if the process dies mid-turn, the user's prompt is
   saved).  Assistant message must be persisted AFTER the turn completes.
   Verify the order of `Append_Message` calls.

7. **`model_spec` parsing for compound IDs** — `"openrouter/anthropic/claude-3"` must
   split into provider=`"openrouter"`, model_id=`"anthropic/claude-3"` (split
   on first `/` only).  Verify `Ada.Strings.Fixed.Index` (which finds the
   FIRST occurrence) is used, not a different variant.

8. **Empty history on `New_Session`** — after `New_Session`, the `History`
   vector must be completely cleared and a new UUID generated.  Verify neither
   old messages nor the old UUID persists.

9. **`Switch_Session` history load** — after `Switch_Session (UUID)`, `History`
   must be populated from `Session_Store.Load_Messages (UUID)`.  Verify that
   the messages are loaded correctly and that the session UUID is updated.

10. **`Session_Stats_Event` accuracy** — the stats event is emitted after each
    turn.  Verify the cumulative usage is summed from all assistant messages in
    `History` (not just the most recent turn), and that the cost is correctly
    converted from the usage fields.

---

### R10 — Test Coverage Gaps

**Report file:** `plan/reviews/R10-test-coverage.md`

**Primary files:**
- All `test/src/llm_*_tests.adb` files
- The corresponding source `.adb` files they test

**Method:** For each test file, determine which code paths in the tested source
are exercised and which are not.  Focus on paths that could hide correctness
bugs.

**Properties to verify:**

1. **R3 gaps (OpenAI Completions):**
   - Is the multi-tool-call assembly (two `index` values in one response) tested?
   - Is the thinking delta path (`delta.reasoning`) tested?
   - Is the assistant-with-tool-calls message serialisation tested (the JSON
     going INTO the request, not just the response parsing)?
   - Is the non-streaming fallback path tested?

2. **R4 gaps (Anthropic Messages):**
   - Is the thinking budget mapping tested for all 6 levels?
   - Is the `tool_use` content block start (with `id` and `name`) tested?
   - Is a response containing BOTH thinking and text blocks tested?

3. **R5 gaps (GitHub Copilot):**
   - Is token expiry + refresh tested end-to-end (expired credentials → refresh
     → successful API call)?
   - Is the X-Initiator header checked in the mock server to verify it is
     `"agent"` when the last message is an assistant message?

4. **R7 gaps (Pi Adapter):**
   - Is `Session_Stats_Event` → `get_session_stats` cost round-trip tested with
     a non-zero value?
   - Is `Auto_Compaction_Start/End_Event` tested?

5. **R8 gaps (Session Store):**
   - Is an assistant message containing BOTH a thinking block and a text block
     tested for round-trip?
   - Is a multi-turn session (user + assistant + tool + user + assistant)
     tested for `Load_Messages` ordering?

6. **R9 gaps (Agent Loop):**
   - Is the two-consecutive-tool-call case tested (provider fires two
     `Tool_Call_End` events in one response)?
   - Is the tool execution failure case tested (tool returns `Is_Error = True`)?
   - Is `Switch_Session` with a session that has existing history tested?

7. **Mock server reliability** — the HTTP tests spawn Python processes.  Check
   whether there are race conditions in the test (e.g. the Ada test connects
   before the Python server is listening).  Is there a sleep/retry or a
   readiness check?

8. **Test isolation** — tests that write to the filesystem (session store
   tests, catalogue cache tests) must use temporary directories that are
   cleaned up after each test.  Verify no test leaves stale files in
   `~/.pi/agent/` that could affect subsequent test runs.

---

## Parallelism

All ten reviews are fully independent (read-only, separate output files).
They can be spawned simultaneously as subagents.

Suggested spawn order (one function_calls block):

```
spawn R1, R2, R3, R4, R5 (first batch)
then spawn R6, R7, R8, R9, R10 (second batch)
```

Or all ten at once if the orchestrator supports it.

---

## Post-review Action

After all reviews complete, read all ten `plan/reviews/R*.md` files and:

1. Triage issues by severity.
2. For CRITICAL and HIGH issues, spawn fix subagents immediately.
3. For MEDIUM issues, file them as follow-up work items.
4. Update `plan/review-plan.md` with the final triage summary.

---

## Output Directory

```
plan/reviews/
  R1-curl-binding.md
  R2-sse-parser.md
  R3-openai-completions.md
  R4-anthropic-messages.md
  R5-github-copilot.md
  R6-openrouter.md
  R7-pi-adapter.md
  R8-session-store.md
  R9-agent-loop.md
  R10-test-coverage.md
```
