# Component Development Log — Providers and HTTP

**Components:** `LLM.Providers.*`, `LLM.HTTP`, `LLM.HTTP.Curl_Binding`,
`LLM.SSE`, `LLM.Auth`, `LLM.Auth.GitHub_Copilot`, `LLM.Model_Registry`,
`LLM.Settings`, `LLM.Tools`, `LLM.Tools.Shell`, `LLM.Tools.Temp_File`

**Source files:** `src/llm/llm-providers-*.ads/.adb`, `src/llm/llm-http*.ads/.adb`,
`src/llm/llm-sse.*`, `src/llm/llm-auth*.ads/.adb`,
`src/llm/llm-model_registry.*`, `src/llm/llm-settings.*`,
`src/llm/llm-tools*.ads/.adb`

---

## Design Rationale

### AUnit provider-suite hierarchy (2026-09-05)

Provider and agent test callers now live in package-scoped leaf suites under
`Test_LLM_Suite`, rather than in one flat root registration body. The LLM
domain preserves 295 registrations and remains the dominant measured local
group at approximately 28–29 seconds; the full 822-test suite completes in
34.3 seconds with local fixtures and guarded external tests disabled.

### OpenAI Responses sibling adapter (2026-08-15, PCR-059)

Approach A: add `LLM.Providers.OpenAI_Responses` as a sibling of
`OpenAI_Completions`. Completions stays the compatibility wire for Copilot,
OpenCode Go, and Ollama. Native `"openai"` and OpenRouter move to Responses.

Key implementation notes (do not rediscover these from the spec):

- Endpoint `POST {base}/responses`. Auth unchanged (Bearer).
- Request: `input[]` + `instructions` + flat tools + `max_output_tokens`.
  Never `messages`, never nested `{type:function, function:{…}}`.
- Never send `store: true` or `previous_response_id`. OpenRouter is
  stateless and returns 400 if either is set. Coyote owns history in JSONL.
- SSE: dispatch on `type`. No `[DONE]`. Finalize on `response.completed`
  / `failed` / `incomplete`. Usage lives on the completed event under
  `input_tokens` / `output_tokens` / `*_details`.
- Streamed text is tracked by Responses output-item ID. The `.done` event
  closes the frontend text block, but the completed message item is suppressed
  only when that item already emitted a non-empty text delta; this prevents
  duplicate assistant content without conflating parser history with block
  state.
- Tool identity: persist `call_id` as coyote `Tool_Call_Id`. Echo
  `function_call` items (with `call_id`, `name`, `arguments`) plus matching
  `function_call_output` items on later turns.
- Reasoning replay: persist item `id` + `encrypted_content` on
  `Thinking_Block`. `Signature` holds encrypted content. Request
  `include: ["reasoning.encrypted_content"]` so later turns can send the
  item back. Effort map: Off omit/`none`, Minimal `minimal`, Low `low`,
  Medium `medium`, High `high`, X_High `xhigh`.
- Image tool results: `input_image` inside `function_call_output.output`.
  Do not use the Completions stub + follow-up user message.
- Cache: `prompt_cache_breakpoint: {mode:"explicit"}` on content parts,
  not Completions `cache_control`.
- Native OpenAI sibling adapter and OpenRouter Responses cutover are
  implemented. The complete 878-test AUnit regression suite passes with no
  failures or unexpected errors; focused provider, registry, agent, and
  parallel-tool tests also pass. Live-provider qualification remains an
  optional guarded activity and was not enabled in this environment.


### Dedicated subagent model preference (2026-08-08)

`LLM.Settings` persists the optional `defaultSubagentProvider` and
`defaultSubagentModel` fields alongside the existing GUI preferences. Empty
values remove the fields, preserving unrelated settings through the same atomic
replacement path. The agent resolves the dedicated model only in subagent
mode, after an explicit model argument and before the ordinary default.

### GUI Preferences settings and persistence (2026-08-06)

`LLM.Settings` now loads the optional `defaultSandboxProfile` field and exposes
`Save_Preferences` for model, thinking, and sandbox defaults. The save operation
preserves unrelated JSON fields, removes empty preference fields, and uses the
existing same-directory atomic replacement. The GTK-only `priceDisplay`
preference changes presentation of catalogue prices but never changes provider
pricing metadata or request costs. Write failures propagate to the GUI
agent-task command handler, which reports an error notice without changing
the active session. Settings and agent tests cover field loading, preservation,
clearing, atomic temporary-file cleanup, and sandbox-default precedence.

### Provider routing pattern (Copilot, OpenCode Go)

Both GitHub Copilot and OpenCode Go provide models on both the OpenAI
Completions and the Anthropic Messages wire formats. Rather than implementing
two separate wire-format parsers in each routing provider, the routing providers
delegate to the canonical `OpenAI_Completions.Provider` and
`Anthropic_Messages.Provider` packages. The model ID (inspected at `Send`
call time) determines which delegate is used. This pattern means a bug fix
in the Anthropic SSE parser automatically benefits Copilot Claude models.

### Wire-format selection via `Model_Info.Wire_Format`

`LLM.Model_Registry.Model_Info` carries a `Wire_Format` string
(`"openai-completions"`, `"openai-responses"`, or `"anthropic-messages"`).
This field is used by `LLM.Agent` in `Build_Tools_Json` to select the
appropriate tool schema format (nested Completions function schema, flat
Responses function schema, or Anthropic tool schema). Routing providers
(Copilot, OpenCode Go) set this field dynamically at dispatch time rather
than storing it in the catalogue, because the same model ID may map to
different wire formats depending on the provider's current routing logic.

### OpenCode Go model metadata via OpenRouter cross-reference

The live OpenCode Go `/v1/models` endpoint returns only model identifiers
(`id`, `object`, `created`, `owned_by`) — no context window, reasoning
support, or pricing fields.  Rather than maintaining a hardcoded
`Known_Meta` array that must be manually updated for every new model or
capability change, the catalogue builder cross-references each Go model ID
against the OpenRouter catalogue.  Matching is by normalised base name
(provider prefix stripped), which maps 17 of the 19 Go models to exact
OpenRouter entries (`glm-5` → `z-ai/glm-5`, `kimi-k2.6` →
`moonshotai/kimi-k2.6`, etc.).  Unmatched models (currently `mimo-v2-omni`
and `mimo-v2-pro`) fall back to conservative defaults (128k context, no
reasoning).  This approach eliminates the manual-update burden and keeps
the catalogue current with OpenRouter's model-list refreshes.


### SSE parser is stateless between chunks

`LLM.SSE` maintains no inter-chunk state of its own. The provider adapter
holds the partial-line buffer between `Curl_Binding` write callback invocations.
This design was chosen because the SSE spec requires lines to be terminated
by `\n` or `\r\n`, and libcurl delivers chunks of arbitrary size that may
split a line at any byte boundary. Having the provider adapter own the buffer
simplifies the SSE parser (pure function on a complete line) and avoids a
shared mutable object between the HTTP layer and the parser.

### `Result_Threshold` policy

`LLM.Tools.Temp_File.Result_Threshold` allocates `BYTES_PER_TOKEN ×
context_window / CONTEXT_SHARE` bytes to a single tool result. With the
default constants (4 bytes/token, share = 8), a 200k-token context window
yields a 100 KB threshold, clamped to the [4 KB, 200 KB] range. This policy
was chosen because:
- A single tool result should not occupy more than 1/8 of the context window
  (leaving headroom for the system prompt, prior history, and model response).
- The 4 KB floor ensures useful output even for very small context windows.
- The 200 KB ceiling prevents runaway memory use if the heuristic overestimates
  for an unusually large model.

### libcurl cancellation for streaming requests

`LLM.HTTP.Post` and `LLM.HTTP.Get` accept an optional protected
`LLM.Tools.Abort_Flag_Access`. When supplied, the native binding enables
`CURLOPT_XFERINFOFUNCTION` and passes the abort flag's atomic C mirror to a
C callback. The callback returns nonzero when the flag is set, so a blocked
`curl_easy_perform` exits without waiting for a response-body write callback.
Provider adapters forward this optional value through all wire-format and
routing delegates, including compaction requests. Existing direct HTTP and
provider callers remain source-compatible because the parameter defaults to
null.

### libcurl binding: no CURLOPT_TIMEOUT_MS on streaming requests

The libcurl binding does not set a per-request timeout (`CURLOPT_TIMEOUT_MS`)
on streaming SSE calls. Provider responses for complex tasks can take many
minutes (long tool chains). A fixed timeout would abort legitimate long-running
sessions. The `CURLOPT_LOW_SPEED_LIMIT` / `CURLOPT_LOW_SPEED_TIME` options
are used instead: if the transfer rate drops below a threshold for more than
N seconds, libcurl aborts with `CURLE_OPERATION_TIMEDOUT`. This catches truly
stalled connections without aborting slow-but-active streams.

### GitHub Copilot token refresh

Token refresh is deferred to request time.  The provider's `Send` calls
`Ensure_Valid` (which may exchange the refresh token for a new access token
via the GitHub token endpoint) only when a Copilot completion request is
actually made.  At startup, `Refresh_GitHub_Copilot` populates the model
registry using the cached access token when that token is present and
non-expired; no live refresh is performed.  If the cached token has expired
or the catalogue load fails (network error, lapsed subscription, etc.),
the Copilot portion of the registry remains empty and the agent starts
normally — `Lookup` returns a conservative default record with a
model-ID-based wire-format heuristic ("claude" → anthropic-messages,
else openai-completions).  The restore path is automatic: running
`coyote login github-copilot` writes fresh credentials to auth.json,
and the next startup will see a non-expired token and load the catalogue.

---

## Key Constraints

- Provider adapters must not retain mutable state between `Send` calls.
  `Session` in `LLM.Agent` owns all history; providers are stateless.
- The libcurl write callback runs in the same task that called
  `curl_easy_perform`. No libcurl handle is accessed from multiple tasks.
- `LLM.Tools.Shell.Execute` reads `$SHELL` from the environment at call time
  (not at package elaboration). This allows the user's shell to be changed
  without restarting coyote.
- For timeout and abort signalling, `setsid` is the outer wrapper. When a
  sandbox profile is active, it execs `bwrap`, preserving the process-group
  leader PID returned by `Start` for signals to the entire command tree.

---

## 2026-08-28 — Cancellable provider transfers

Added optional abort-flag propagation to the provider interface and all
OpenAI, Anthropic, GitHub Copilot, OpenRouter, and OpenCode Go routing paths.
The HTTP binding uses a C-native libcurl transfer-info callback and an atomic
mirror maintained by `LLM.Tools.Abort_Flag`; no Ada nested callback crosses the
C ABI. `test/src/llm_http_tests.adb` verifies that an idle response terminates
promptly after the flag is set. The development suite passes 928/928 tests.

## Unit Test Coverage Notes

- `LLM.SSE`: covered by AUnit tests — line parsing, multi-chunk events,
  data-only lines, comment lines.
- `LLM.Tools.Temp_File`: covered by AUnit tests — threshold calculation,
  truncation, temp-file naming uniqueness.
- `LLM.Settings`: covered by AUnit tests — JSON parsing, missing fields,
  env-var interpolation in models.json.
- Provider `Send` procedures: not directly unit-tested (require live endpoints
  or recording). Covered by integration tests (opt-in, env-var guarded).

---

## Open Questions / Future Work

- OpenRouter and OpenCode Go model catalogues are fetched once at startup
  and cached to `~/.coyote/*_models_cache.json`. The OpenCode Go catalogue
  cross-references the OpenRouter catalogue to obtain context window sizes,
  reasoning support, and pricing metadata, since the Go `/v1/models` endpoint
  returns only model IDs.  There is no background refresh. Consider a cache
  TTL check if stale catalogues become an issue.
  and cached to `~/.coyote/*_models_cache.json`. There is no background
  refresh. Consider a cache TTL check if stale catalogues become an issue.
- The Anthropic thinking beta header (`anthropic-beta: interleaved-thinking-...`)
  is hardcoded to the 2025-05-14 version. This should be made configurable
  or updated when Anthropic graduates the feature from beta.

---

## 2026-06-14: OpenAI Prompt Caching Parity with Anthropic

Two changes in `llm-providers-openai_completions.adb` to bring OpenAI-wire
caching performance in line with the Anthropic provider:

1. **`cache_control` on last user/tool message** (`Build_Request_Body`):
   After building the message array and before `Request.Set_Field("messages",
   Msgs)`, a `cache_control: {type:"ephemeral"}` marker is placed on the last
   message with `role:"user"` or `role:"tool"`.  This mirrors the Anthropic
   provider's strategy of placing a cache breakpoint on the conversation
   prefix so that the entire history up to the most recent tool result is
   cached.  Providers that honor `cache_control` (OpenRouter routing to
   Anthropic backends, GitHub Copilot) benefit from full conversation
   caching.  Providers that don't support `cache_control` (native OpenAI,
   DeepSeek via OpenRouter) silently ignore the unknown field and continue
   with automatic prefix caching as before.

   Prior to this change, only the system prompt and tool definitions carried
   `cache_control` markers; the conversation history was never explicitly
   cached.  On sessions where the conversation grew significantly (e.g., 137
   turns with large tool results), roughly half the request was uncached
   every turn (~50% miss rate).  The fix reduces miss rate to near zero for
   providers that honor the marker.

2. **DeepSeek `prompt_cache_hit_tokens` fallback** (`Parse_Usage`):
   DeepSeek's API reports cached tokens via `prompt_cache_hit_tokens` at the
   usage level, not via the nested `prompt_tokens_details.cached_tokens`
   path that OpenAI uses.  Added a fallback: if `cached_tokens` is zero or
   absent, `prompt_cache_hit_tokens` is read directly from the usage object.
   This ensures `Cache_Read` is populated correctly for DeepSeek models.

Both changes are backward-compatible: they add fields to outgoing requests
only when message arrays are non-empty, and they add an additional JSON
field read that defaults to zero when absent.

Root cause analysis from session comparison:
- Session `6c5fb2dc` (OpenRouter, 137 turns, thinking on): 50.4% cache miss
  rate, cacheWrite=0 on all turns, ~12M uncached tokens
- Session `2e112097` (GitHub Copilot→Anthropic, 115 turns, thinking off):
  ~0% miss rate, 156K cacheWrite, ~900 uncached tokens
The difference was driven by absence of `cache_control` on user/tool messages
in the OpenAI-wire path; the Anthropic path already had this.

## 2026-06-15: Eliminate `Ada.Text_IO.Get_Line` Stack-Overflow Vulnerability

**Problem:** The local `Read_File` helper functions in `LLM.Auth`,
`LLM.Settings`, `LLM.System_Prompt`, and all four catalogue packages
(`OpenRouter`, `Ollama`, `OpenCode_Go`, `GitHub_Copilot`) used
`Ada.Text_IO.Get_Line` in a loop.  GNAT's runtime implementation of
`Get_Line` uses tail-recursion proportional to line length; a single-line
512 KB JSON file (such as `~/.coyote/openrouter_models_cache.json`) caused
~512K recursive calls, exhausting the `Agent_Task`'s stack and producing
SIGSEGV.

**Fix:** Added `Coyote_Utils.Read_Whole_File`, a chunk-based
`Ada.Streams.Stream_IO` reader with an 8 KB buffer — zero recursion, no
line-length limit.  All eight duplicated `Read_File` bodies were replaced
with thin wrappers that call `Coyote_Utils.Read_Whole_File`, preserving any
local pre-condition checks.  The `Read_File_If_Exists` function in
`Coyote_Utils` was also rewritten to delegate to `Read_Whole_File`.

**Files changed:**
- `src/coyote_utils.ads` — added `Read_Whole_File` spec
- `src/coyote_utils.adb` — added `Read_Whole_File` body; rewrote
  `Read_File_If_Exists` as wrapper
- `src/llm/llm-auth.adb` — replaced local `Read_File` with `Coyote_Utils`
- `src/llm/llm-settings.adb` — replaced local `Read_File`; removed unused
  `with Ada.Text_IO`, `with GNATCOLL.JSON`
- `src/llm/llm-system_prompt.adb` — replaced local `Read_File`; removed
  unused `with Ada.Text_IO`
- `src/llm/llm-providers-openrouter-catalogue.adb` — replaced local
  `Read_File`
- `src/llm/llm-providers-ollama-catalogue.adb` — replaced local `Read_File`
- `src/llm/llm-providers-opencode_go-catalogue.adb` — replaced local
  `Read_File`
- `src/llm/llm-providers-github_copilot-catalogue.adb` — replaced local
  `Read_File`

**Result:** Net -118 lines (174 removed, 56 added).  Build clean.  688 tests
passing.  No more unbounded `Get_Line` recursion anywhere in the codebase.

## 2026-06-20: Migrate Ollama Chat to OpenAI-Compatible Endpoint

**Change:** Retired the native Ollama chat provider (`llm-providers-ollama.adb`,
957 lines) and migrated all Ollama chat traffic to use the OpenAI-compatible
`POST /v1/chat/completions` endpoint via `LLM.Providers.OpenAI_Completions`.
The native NDJSON streaming parser, custom request builder, thinking-block
state machine, and tool-call accumulator are replaced by the shared OpenAI SSE
pipeline — one less streaming protocol to maintain.

The catalogue (`llm-providers-ollama-catalogue.adb`) now performs a two-phase
fetch: `/api/tags` for the model list, then `/api/show` per model to extract
real capabilities (thinking, vision), context length (from
`model_info.{arch}.context_length`), and model family.  Previously the
catalogue hardcoded 128K context for Cloud models and guessed reasoning/vision
support from a small hardcoded family-name table.

**Files changed:**
- `src/llm/llm-providers-ollama.adb` — **deleted** (957 lines)
- `src/llm/llm-providers-ollama.ads` — replaced with minimal parent spec (the
  `Ollama.Catalogue` child package still needs a parent)
- `src/llm/llm-providers-ollama-catalogue.adb` — rewritten: removed
  `Estimated_Ctx`, added `Get_Natural_Field`, rewrote `Parse_Model` to read
  enriched fields from `/api/show`, rewrote `Fetch_Live` to call `/api/show`
  per model (+272/-66 lines)
- `src/llm/llm-agent.adb` — replaced `with LLM.Providers.Ollama` with
  `with LLM.Providers.OpenAI_Completions`; both dispatcher branches
  (summarization and agentic loop) now create `OpenAI_Completions.Provider`
  pointing at `https://ollama.com/v1/`
- `src/llm/llm-model_registry.adb` — changed `Wire_Format` from `"ollama"` to
  `"openai-completions"` in both `To_Model_Info` and `Default_Ollama_Model`
- `requirements/coyote-requirements.md` — updated REQ-CORE-150..156 and
  REQ-CORE-204 to reflect the OpenAI-compatible endpoint

**Result:** Net -841 lines (1,073 deleted, 232 added).  Build clean.  All
existing tests pass.  Ollama models now share the mature, well-tested OpenAI
SSE streaming pipeline.

## 2026-08-22 — Responses reasoning ownership (PCR-063)

Responses encrypted reasoning is owned by the provider/model identity that
produced it. `Thinking_Block` provenance is persisted explicitly, with legacy
session inference from the preceding `model_change` record. The agent filters
foreign and unknown thinking before every provider call without deleting it,
so switching back remains lossless. `OpenAI_Responses` now interprets only JSON
signatures containing Responses `id` or `encrypted_content`; arbitrary opaque
signatures from other wires no longer become reasoning input items.

Focused same-model replay, opaque-signature omission, cross-model filtering,
switch-back, explicit persistence, and legacy-inference tests pass.


### OpenRouter Broadcast session tracking (2026-08-22, PCR-065)

OpenRouter's Broadcast documentation defines an optional `session_id` request
field, up to 256 characters, for grouping related observability traces. It may
also be supplied through the `x-session-id` header. Coyote uses the request-body
field because the requested integration is payload-based. The current provider
uses OpenRouter's Responses endpoint rather than the Chat Completions endpoint
shown in the API example, so the field is added through the Responses provider's
existing customization hook without changing wire format or enabling server-side
conversation state.

The active coyote session UUID is passed into OpenRouter for normal agent turns
and compaction requests. Empty identifiers are omitted. A local HTTP mock test
asserts the exact JSON field while preserving the existing `store` and
`previous_response_id` omissions.

### OpenRouter Broadcast identity inheritance (2026-08-29, REQ-CORE-219)

`LLM.Agent` keeps the durable coyote session UUID separate from its OpenRouter
Broadcast identity. Root and ordinary sessions use their own UUID. Subagents
adopt `COYOTE_OPENROUTER_SESSION_ID` when present and retain that value through
recursive subagent creation; missing inheritance falls back to the new
subagent's own UUID. Both normal and compaction OpenRouter requests use the
stable identity. The application republishes it after startup, session
switches, and GUI new-session creation without altering `COYOTE_SESSION_ID`.
