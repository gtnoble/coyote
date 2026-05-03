# R10: Test Coverage Gaps

## Verdict
FAIL

## Summary
The LLM test suite exercises many important happy paths: basic HTTP streaming, SSE framing, UUID/header generation, fresh/stale catalogue cache behavior, one OpenAI text stream, one streamed tool call, Anthropic thinking-budget injection, basic GitHub Copilot header/path selection, and a simple agent tool loop. However, the remaining gaps cluster around correctness-sensitive branches rather than around low-risk helpers. The biggest blind spots are protocol edge cases and recovery behavior: OpenAI non-streaming/reasoning/multi-tool parsing, Anthropic `tool_use` request/stream handling and auth-header variants, end-to-end Copilot refresh-through-send, agent retry/switch-session/multi-tool-failure flows, and session-store/pi-adapter compatibility round-trips. Several Python mock-server tests also still rely on fixed sleeps rather than a readiness check.

## Coverage Inventory
- `test/src/llm_http_tests.adb` — covers only happy-path `POST`/`GET` status + chunk delivery; misses `curl_easy_setopt`/`curl_easy_perform` failures, empty-URL behavior, callback exceptions, and cleanup-on-exception paths in `LLM.HTTP`.
- `test/src/llm_sse_tests.adb` — covers full events, split chunks, `[DONE]`, ping skipping, fixtures, and `Reset`; misses comment lines, `id:`/`retry:` ignore paths, no-space `data:`/`event:` variants, and CRLF-specific parsing.
- `test/src/llm_types_tests.adb` — effectively covers the executable body of `LLM.Types` (`Usage."+"`); only low-risk type/default/enum combinations remain unexercised.
- `test/src/llm_openai_completions_tests.adb` — covers one streaming text response and one single-tool-call stream; misses multi-tool-call assembly across different `index` values, `delta.reasoning`, non-streaming fallback, alternate `finish_reason` mappings, and negative request/tool-JSON cases.
- `test/src/llm_anthropic_messages_tests.adb` — covers one thinking+text stream, basic headers, and all six thinking budgets; misses `tool_use` request serialization, `tool_use` stream start/delta/end handling, `x-api-key` vs bearer auth split, and stop reasons other than `end_turn`.
- `test/src/llm_openrouter_tests.adb` — covers env-key resolution and one `reasoning.effort = medium` request; misses direct `Api_Key`/settings fallback, suppression of `reasoning` for unsupported models, low/high effort mappings, and missing-key failure.
- `test/src/llm_openrouter_catalogue_tests.adb` — covers fresh-cache load, stale-cache live fetch, and stale fallback; misses missing-cache live fetch, malformed cache/JSON failure paths, explicit `input_cache_read => 0.0` assertions, and verification that `/models` is fetched without auth.
- `test/src/llm_auth_tests.adb` — covers load/save, basic expiry/base-url parsing, and raw refresh; misses `Ensure_Valid` end-to-end refresh, mutex/double-refresh behavior, non-200/invalid refresh responses, and `HOME`-unset write failure.
- `test/src/llm_catalogue_tests.adb` — covers fresh/stale GitHub Copilot catalogue cache behavior and live-fetch headers; misses missing-cache live fetch, cache-key/base-URL normalization edge cases, and malformed-cache handling.
- `test/src/llm_github_copilot_tests.adb` — covers static headers, `X-Initiator` user/agent, and Anthropic vs OpenAI path selection; misses expired-credentials → refresh → send, empty-message `X-Initiator` default, dynamic base-URL extraction from refreshed tokens, and auth-header conflict checks on the Anthropic delegate path.
- `test/src/llm_tools_tests.adb` — covers bash success/failure, basic read/write/edit/find; misses the `LLM.Tools.Execute` dispatcher itself, `glob`, read offset/limit validation, bash invalid-JSON/truncation paths, and write/find/glob error cases.
- `test/src/llm_session_store_tests.adb` — covers UUID format, header creation, single-message round trips, and fork compatibility; misses assistant messages containing both thinking and text blocks, usage/stopReason/timestamp preservation, multi-turn `Load_Messages` ordering, error tool results, and envelope-form session lines.
- `test/src/llm_model_registry_tests.adb` — covers basic lookup/filtering and anthropic availability; misses expired-Copilot refresh during `Refresh_GitHub_Copilot`, repeated-refresh replacement/de-duplication, failure handling when catalogue refresh returns nothing, and case-insensitive provider lookup.
- `test/src/llm_agent_tests.adb` — covers single turn, one tool loop, abort, and resume-via-`Create`; misses explicit `Switch_Session`, `New_Session`, `Set_Model`, `Set_Thinking`, retry/backoff, two-tool batches, tool failure, and `Session_Stats_Event` verification.
- `test/src/llm_pi_adapter_tests.adb` — covers only `agent_start`, `text_delta`, and `tool_execution_start`; misses `message_end`, `tool_execution_end`, `model_select`, `get_state`, `get_session_stats`, auto-retry, auto-compaction, invalid-args fallback, and `agent_end`.

## Issues

### [HIGH] Protocol-critical provider and agent branches are still largely untested
**Files:** `test/src/llm_openai_completions_tests.adb:335-510`, `src/llm/llm-providers-openai_completions.adb:218-242`, `src/llm/llm-providers-openai_completions.adb:421-475`, `src/llm/llm-providers-openai_completions.adb:488-735`, `test/src/llm_anthropic_messages_tests.adb:374-578`, `src/llm/llm-providers-anthropic_messages.adb:293-378`, `src/llm/llm-providers-anthropic_messages.adb:541-650`, `src/llm/llm-providers-anthropic_messages.adb:706-780`, `test/src/llm_github_copilot_tests.adb:523-659`, `src/llm/llm-providers-github_copilot.adb:133-208`, `test/src/llm_agent_tests.adb:438-842`, `src/llm/llm-agent.adb:537-641`, `src/llm/llm-agent.adb:707-938`
**Description:** The provider and agent suites mostly test one happy-path stream per transport. They do not cover several branches where wire-format bugs are most likely: OpenAI non-streaming responses, `delta.reasoning`, multiple tool calls with different `index` values, Anthropic `tool_use` request/stream handling, alternate stop reasons, end-to-end Copilot token refresh during `Send`, auto-retry/backoff, multiple tool calls in one agent turn, tool execution failure, or the explicit `Switch_Session` path. These are exactly the scenarios called out by R3, R4, R5, and R9.
**Evidence:**
```ada
--  The OpenAI tests define only two end-to-end cases:
procedure Test_Stream_Text_Response (T : in out Test) is
...
procedure Test_Stream_Tool_Call_Response (T : in out Test) is
...
```
```ada
--  But the provider has additional untested branches:
if Has_String_Field (Delta_Value, "reasoning") then
   ...
end if;

procedure Process_Non_Streaming_Response
  (Payload : String; ...)
...
for Index in State.Tool_Calls.First_Index .. State.Tool_Calls.Last_Index loop
   ...  --  multiple tool-call slots
end loop;
```
```ada
elsif Block_Type = "tool_use" then
   Block.Tool_Call_Id := ...
   Block.Tool_Name := ...
   Emit_Update (... Kind => LLM.Events.Tool_Call_Start ...);
```
```ada
elsif Is_Retryable_Error (Occurrence)
  and then Attempt <= Delays_Ms'Last
then
   ... --  auto-retry path
```
**Fix:** Add table-driven end-to-end cases for: (1) OpenAI non-streaming responses, reasoning deltas, and two simultaneous tool calls; (2) Anthropic `tool_use` requests and `input_json_delta` streams, plus `x-api-key` vs bearer auth; (3) expired Copilot credentials that must refresh before `Send`; and (4) agent retry, two-tool batches, tool-error handling, and explicit `Switch_Session` with pre-existing history.

### [MEDIUM] Session-store and pi-adapter compatibility coverage is too narrow
**Files:** `test/src/llm_session_store_tests.adb:230-485`, `src/llm/llm-session_store.adb:313-477`, `src/llm/llm-session_store.adb:510-605`, `src/llm/llm-session_store.adb:672-736`, `test/src/llm_pi_adapter_tests.adb:11-99`, `src/llm/llm-agent-pi_adapter.adb:48-274`
**Description:** The compatibility layers that must match existing pi/acme behavior are under-tested. `LLM.Session_Store` serializes assistant thinking blocks, tool-call objects, usage, stop reasons, timestamps, and tool-result envelopes, but the tests only round-trip a single user message, a single assistant tool-call message, and a single tool result. `LLM.Agent.Pi_Adapter` has many event mappings, but only three are tested. This leaves the R7 and R8 requirements mostly unverified, especially the `Session_Stats_Event` cost round-trip and auto-compaction event mapping.
**Evidence:**
```ada
--  Session store writes more than the tests currently assert:
Item.Set_Field ("type", "thinking");
...
Item.Set_Field ("type", "toolCall");
...
Result.Set_Field ("stopReason", Stop_Reason_Image (Msg.Stop));
Result.Set_Field ("usage", Usage);
```
```ada
--  Pi adapter tests cover only three event kinds.
procedure Test_Agent_Start_Json ...
procedure Test_Text_Delta_Json ...
procedure Test_Tool_Execution_Start_Json ...
```
```ada
--  But the adapter also maps:
elsif E in LLM.Events.Session_Stats_Event then
   ...
elsif E in LLM.Events.Auto_Compaction_Start_Event then
   ...
elsif E in LLM.Events.Auto_Compaction_End_Event then
   ...
```
**Fix:** Add round-trip tests for assistant messages containing both thinking and text blocks, multi-turn load ordering, usage/stopReason/timestamp preservation, error tool results, `Session_Stats_Event` with non-zero cost, `model_select`, `message_end`, `tool_execution_end`, `get_state`, `auto_retry_*`, and `auto_compaction_*` mappings. Include an invalid-JSON `Args_Json` case to verify `Args_Object` falls back to `{}`.

### [MEDIUM] Lower-level robustness and negative paths are under-covered across HTTP, SSE, auth, catalogues, and tools
**Files:** `test/src/llm_http_tests.adb:113-183`, `src/llm/llm-http.adb:64-158`, `test/src/llm_sse_tests.adb:55-204`, `src/llm/llm-sse.adb:18-148`, `test/src/llm_auth_tests.adb:221-422`, `src/llm/llm-auth.adb:183-260`, `src/llm/llm-auth-github_copilot.adb:151-255`, `test/src/llm_openrouter_catalogue_tests.adb:277-441`, `src/llm/llm-providers-openrouter-catalogue.adb:370-508`, `test/src/llm_catalogue_tests.adb:289-462`, `src/llm/llm-providers-github_copilot-catalogue.adb:386-563`, `test/src/llm_tools_tests.adb:113-314`, `src/llm/llm-tools.adb:11-47`, `src/llm/llm-tools-bash.adb:76-252`, `src/llm/llm-tools-file_ops.adb:361-647`
**Description:** The lower layers are still tested mostly on their success paths. Missing coverage includes HTTP cleanup/error branches, SSE comment/CRLF parsing, malformed cache files, missing-cache fetches, invalid refresh responses, `Ensure_Valid` mutex behavior, the `LLM.Tools.Execute` dispatcher, `glob`, bash truncation, and file-op validation errors. Those paths are exactly where latent correctness bugs become visible under real-world failure conditions.
**Evidence:**
```ada
--  HTTP tests only assert status/body on successful POST and GET.
procedure Test_Post_Status_And_Chunk ...
procedure Test_Get_Status_And_Chunk ...
```
```ada
--  But LLM.HTTP has explicit cleanup/error paths not exercised here:
exception
   when others =>
      Cleanup (H, Header_S, URL_C, Payload_C);
      raise;
end Perform_Request;
```
```ada
--  SSE parser has untested field-handling branches.
if Starts_With (Line, "event:") then
   ...
elsif Starts_With (Line, "data:") then
   ...
end if;
--  Comments, id:, retry:, and CRLF stripping are implicit behavior.
```
```ada
--  Tools dispatcher and glob path are untested.
elsif Name = "glob" then
   LLM.Tools.File_Ops.Execute_Glob (Args_Json, Result, Is_Error);
else
   raise Unknown_Tool with "unknown tool: " & Name;
end if;
```
**Fix:** Add negative tests for malformed JSON, invalid/missing fields, callback exceptions, CRLF/comment/id/retry SSE input, missing-cache live fetches, malformed cache contents, `Refresh_Token` non-200/invalid-body cases, `Ensure_Valid` double-caller serialization, dispatcher `Unknown_Tool`, `glob`, read offset/limit validation, and bash output truncation.

### [MEDIUM] Several Python mock-server tests still have startup races
**Files:** `test/src/llm_auth_tests.adb:386-390`, `test/src/llm_openrouter_catalogue_tests.adb:368-371`, `test/src/llm_catalogue_tests.adb:386-389`, `test/src/llm_agent_tests.adb:478-483`, `test/src/llm_agent_tests.adb:561-564`, `test/src/llm_agent_tests.adb:682-703`, `test/src/llm_agent_tests.adb:780-809`
**Description:** Some suites still assume the Python server will be ready after a fixed `delay 0.05` or `delay 0.10`. Unlike the more robust HTTP/provider suites, they do not retry the client call or poll for readiness. On a loaded CI worker, that can produce spurious connection failures before the server reaches `listen(2)`.
**Evidence:**
```ada
Handle := Spawn_Server (Refresh_Server_Script (Port));
delay 0.05;
LLM.Auth.GitHub_Copilot.Refresh_Token (Creds);
```
```ada
Handle := Spawn_Server (Live_Server_Script (Port, Fixture_Path));
delay 0.05;
Load_Catalogue (Models);
```
```ada
Handle := Spawn_Server (Single_Turn_Server_Script (Port));
delay 0.10;
LLM.Agent.Run_Prompt (...);
```
The suites that *do* wrap calls in retry loops (`llm_http_tests`, `llm_openai_completions_tests`, `llm_openrouter_tests`, `llm_anthropic_messages_tests`, `llm_github_copilot_tests`) are less exposed.
**Fix:** Replace fixed sleeps with a readiness probe or a retry wrapper around the first client call. Even a small poll loop that retries on `Curl_Error` until timeout would remove the race.

### [LOW] Temporary-path isolation is inconsistent and some capture files can outlive the test run
**Files:** `test/src/llm_anthropic_messages_tests.adb:377-390`, `test/src/llm_anthropic_messages_tests.adb:456-470`, `test/src/llm_anthropic_messages_tests.adb:523-538`, `test/src/llm_github_copilot_tests.adb:459-520`, `test/src/llm_tools_tests.adb:16-42`
**Description:** Several suites use fixed `/tmp/...` paths rather than unique per-run temp names. The Anthropic and GitHub Copilot suites delete capture files before the test, but do not guarantee removal afterward, and `llm_tools_tests` uses a global fixed root. This is not a functional bug in the product, but it can contaminate concurrent or interrupted test runs.
**Evidence:**
```ada
Capture : constant String := "/tmp/coyote_anthropic_capture_1.json";
...
Delete_If_Exists (Capture);
Handle := Spawn_Server (...);
--  no matching post-test delete of Capture
```
```ada
Run_Case
  (Home         => "/tmp/coyote_github_copilot_test_1",
   Capture_Path => "/tmp/coyote_github_copilot_capture_1.json",
   ...);
```
```ada
Test_Root : constant String := "/tmp/coyote_llm_tools_tests";
```
**Fix:** Use PID/UUID-suffixed temp directories/files for all homes, capture files, and tool roots, and delete them in both success and exception paths.

## Confirmed Correct
- `llm_types_tests.adb` effectively covers the executable body of `LLM.Types`; the `Usage` addition operator is directly asserted.
- `llm_sse_tests.adb` does cover the most important happy-path framing cases: complete events, multi-chunk buffering, `[DONE]`, ping skipping, and parser reset.
- `llm_openai_completions_tests.adb` does verify the request-side serialization of system/user/tool-call/tool-result messages for the tested happy path, not just response parsing.
- `llm_anthropic_messages_tests.adb` does verify the thinking-budget mapping for all six configured levels, satisfying that part of R4.
- `llm_github_copilot_tests.adb` does verify `X-Initiator = agent` using a captured request when the last message is an assistant message, so that specific R5 gap is already covered.
- `llm_openrouter_catalogue_tests.adb` and `llm_catalogue_tests.adb` both cover the important cache-freshness triad: fresh-cache load, stale-cache live refresh, and stale-cache fallback.
- `llm_session_store_tests.adb` does verify UUID formatting, session-header field names, and basic `Fork_Session` compatibility with native-written sessions.
- `llm_model_registry_tests.adb` does verify the OpenRouter unknown-model fallback and provider-based `Available_Models` filtering.
- `llm_http_tests.adb`, `llm_openai_completions_tests.adb`, `llm_openrouter_tests.adb`, `llm_anthropic_messages_tests.adb`, and `llm_github_copilot_tests.adb` all mitigate server-startup timing with retry loops around the first HTTP call.
