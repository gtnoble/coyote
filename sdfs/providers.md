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
(`"openai-completions"` or `"anthropic-messages"`). This field is used by
`LLM.Agent` in `Build_Tools_Json` to select the appropriate tool schema
format (OpenAI function schema vs. Anthropic tool schema). Routing providers
(Copilot, OpenCode Go) set this field dynamically at dispatch time rather
than storing it in the catalogue, because the same model ID may map to
different wire formats depending on the provider's current routing logic.

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

---

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
  and cached to `~/.coyote/*_models_cache.json`. There is no background
  refresh. Consider a cache TTL check if stale catalogues become an issue.
- The Anthropic thinking beta header (`anthropic-beta: interleaved-thinking-...`)
  is hardcoded to the 2025-05-14 version. This should be made configurable
  or updated when Anthropic graduates the feature from beta.
