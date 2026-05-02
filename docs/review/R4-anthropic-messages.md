# R4: Anthropic Messages Wire Format

## Verdict
PASS_WITH_NOTES

## Summary
I reviewed `LLM.Providers.Anthropic_Messages` against the R4 properties in `docs/review-plan.md` and did not find a wire-format correctness bug in the implementation. The request body uses Anthropic-style top-level `system`, content arrays, `tool_use` / `tool_result` blocks, correct thinking-budget mapping, and correct Anthropic headers including the required `anthropic-beta` header. The streaming parser also reads the Anthropic-specific SSE fields called out in the plan, including `delta.partial_json` and `usage.output_tokens`, and the stop-reason mapping matches the spec. I also verified the GitHub Copilot path uses bearer auth rather than `x-api-key`. `cd test && alr run pi_acme_test` passed. My only note is that the current tests leave several Anthropic-only protocol details unexercised, especially direct `x-api-key` auth and tool-call request/stream shapes.

## Issues

### [LOW] Tests do not exercise the direct `x-api-key` path or Anthropic tool-call wire format
**Files:** test/src/llm_anthropic_messages_tests.adb:453-578; test/src/llm_github_copilot_tests.adb:523-657; src/llm/llm-providers-anthropic_messages.adb:745-752
**Description:** The implementation appears correct, but the tests only cover version/beta headers, thinking-budget injection, a thinking+text SSE stream, Copilot bearer auth, and Copilot/OpenAI path selection. They do not cover the direct Anthropic authentication branch (`x-api-key`) or the most protocol-specific Anthropic tool-call behaviors: `input_schema` tools, assistant `tool_use` blocks with object-valued `input`, user `tool_result` messages, and `input_json_delta.partial_json` streaming. That leaves the highest-risk Anthropic-only paths vulnerable to regression.
**Evidence:**
```ada
Provider := LLM.Providers.Anthropic_Messages.Create
   (Base_Url => "http://127.0.0.1:18774",
    Api_Key  => "test-key");
...
Assert
   (Get_String_Field (Headers, "anthropic-version") = "2023-06-01",
    "anthropic-version header should be present");
Assert
   (Get_String_Field (Headers, "anthropic-beta")
    = "interleaved-thinking-2025-05-14",
    "anthropic-beta header should be present");
```

```ada
if Length (P.Api_Key) > 0 then
   if Uses_X_Api_Key (To_String (P.Base_Url)) then
      LLM.HTTP.Add_Header (Headers, "x-api-key", To_String (P.Api_Key));
   else
      LLM.HTTP.Add_Header
         (Headers, "Authorization", "Bearer " & To_String (P.Api_Key));
   end if;
end if;
```

The Anthropic unit tests never use an `anthropic.com` base URL, so the `x-api-key` branch is never exercised. Their SSE fixture also contains only thinking and text blocks, not `tool_use` blocks.
**Fix:** Add capture-based tests for: (1) a direct Anthropic base URL that must send `x-api-key` and must not send `Authorization`; (2) a Copilot Anthropic request that must send `Authorization` and must not send `x-api-key`; (3) request-body serialization of `system`, `tools[].input_schema`, assistant `tool_use.input` as a JSON object, and user `tool_result`; and (4) a streaming fixture with `content_block_start` / `input_json_delta.partial_json` / `message_delta.usage.output_tokens`.

## Confirmed Correct
- `Send` adds `Content-Type: application/json`, `anthropic-version: 2023-06-01`, and `anthropic-beta: interleaved-thinking-2025-05-14` on every Anthropic request (`src/llm/llm-providers-anthropic_messages.adb:738-743`).
- Auth-header selection is correct for the two supported modes reviewed here: direct Anthropic hosts use `x-api-key`, while non-Anthropic hosts such as GitHub Copilot use `Authorization: Bearer` (`src/llm/llm-providers-anthropic_messages.adb:745-752`). The Copilot adapter constructs the Anthropic provider with the Copilot base URL and access token, so the Anthropic path does not add a conflicting `x-api-key` header (`src/llm/llm-providers-github_copilot.adb:163-187`).
- The system prompt is serialized as a top-level `"system"` field and is not inserted into the `messages` array (`src/llm/llm-providers-anthropic_messages.adb:397-409`).
- User and assistant messages are serialized as Anthropic content arrays of typed blocks, not OpenAI-style scalar `content` strings (`src/llm/llm-providers-anthropic_messages.adb:282-378`).
- Assistant tool calls are serialized as `{"type":"tool_use", ...}` blocks, with `input` parsed from `Arguments_Json` into a JSON object; invalid or non-object JSON is rejected (`src/llm/llm-providers-anthropic_messages.adb:293-315`).
- Tool results are serialized as user-role messages containing `{"type":"tool_result","tool_use_id":...,"content":...}` blocks, which matches the Anthropic Messages format rather than OpenAI's separate `tool` role (`src/llm/llm-providers-anthropic_messages.adb:317-378`).
- End-to-end tool definition shape is correct for Anthropic: the caller builds Anthropic tool definitions with `input_schema`, while OpenAI uses `parameters`; the wire-format split happens in `LLM.Agent.Build_Tools_Json` (`src/llm/llm-agent.adb:382-409`).
- The thinking-budget mapping matches the plan exactly: Off=omit field, Minimal=1024, Low=2048, Medium=8192, High=16384, X_High=32768 (`src/llm/llm-providers-anthropic_messages.adb:181-199,431-439`).
- `Process_Content_Block_Start` captures `tool_use` block `id` and `name` at block-start time, as required (`src/llm/llm-providers-anthropic_messages.adb:541-589`).
- `Process_Content_Block_Delta` reads `delta.partial_json` for `input_json_delta`, not an OpenAI-style field name (`src/llm/llm-providers-anthropic_messages.adb:595-640`).
- `Process_Message_Delta` reads Anthropic `usage.output_tokens` from `message_delta` and maps stop reasons as specified: `end_turn`→`Stop`, `max_tokens`→`Length`, `tool_use`→`Tool_Use`, `error`→`Error_Stop` (`src/llm/llm-providers-anthropic_messages.adb:201-216,642-657`).
- On the happy path, `Agent_Start_Event` is emitted before streaming begins, `Message_End_Event` is emitted during `message_stop` finalization, and `Agent_End_Event` is emitted once after the stream completes (`src/llm/llm-providers-anthropic_messages.adb:494-511,735-787`).
- The existing tests do correctly verify the required Anthropic version/beta headers, the thinking-budget table, the basic Anthropic SSE thinking/text event sequence, and Copilot bearer-auth routing on the Anthropic path (`test/src/llm_anthropic_messages_tests.adb:374-578`, `test/src/llm_github_copilot_tests.adb:523-636`).
