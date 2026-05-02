# R3: OpenAI Completions Wire Format

## Verdict
PASS

## Summary
I reviewed `src/llm/llm-providers-openai_completions.ads`, `src/llm/llm-providers-openai_completions.adb`, and `test/src/llm_openai_completions_tests.adb` against the R3 properties in `docs/review-plan.md`. The OpenAI chat-completions adapter is correctly serialising request messages for the scoped cases, correctly omitting empty tool arrays, correctly mapping `finish_reason` and usage fields, and correctly assembling streamed tool-call argument fragments by `index`. The targeted AUnit coverage for the text and tool-call happy paths also passed in the project test run.

## Issues

None.

## Confirmed Correct
- **System message placement:** `Build_Request_Body` appends the system prompt before iterating conversation history, so a non-empty system prompt is always the first element in `messages`; an empty system prompt is omitted entirely (`src/llm/llm-providers-openai_completions.adb:421-452`).
- **User/assistant/tool message serialisation:**
  - User messages are emitted as `{"role":"user","content":"..."}` (`src/llm/llm-providers-openai_completions.adb:340-350`).
  - Assistant text messages are emitted as `{"role":"assistant","content":"..."}` when no tool calls are present (`src/llm/llm-providers-openai_completions.adb:352-390`).
  - Assistant tool-call messages are emitted with `"content": null` and a `tool_calls` array; `function.arguments` is written as a JSON **string** via `Set_Field ("arguments", To_String (...))`, not as an object (`src/llm/llm-providers-openai_completions.adb:363-385`).
  - Tool results are emitted as `{"role":"tool","tool_call_id":"...","content":"..."}` (`src/llm/llm-providers-openai_completions.adb:392-418`).
- **Tools array handling:** the provider parses `Tools_Json`, requires it to be a JSON array, and only sets the request `tools` field when that array is non-empty; `"[]"` therefore omits the field entirely (`src/llm/llm-providers-openai_completions.adb:454-472`). Upstream tool construction for the OpenAI wire format uses the required wrapper `{"type":"function","function":{..."parameters":{...}}}` (`src/llm/llm-agent.adb:395-409`).
- **Multi-index tool-call assembly:** streamed tool calls are accumulated in per-index slots, with a new slot created when a new `index` is seen; `function.arguments` fragments are concatenated into `Arguments_Json`, and `Tool_Call_End` emits the complete assembled argument string during finalisation (`src/llm/llm-providers-openai_completions.adb:478-596`). The design supports multiple simultaneous tool calls with distinct indices.
- **Stop-reason mapping:** `To_Stop_Reason` maps `stop → Stop`, `length → Length`, `tool_calls → Tool_Use`, `content_filter → Error_Stop`, and all other values to `Unknown_Stop` (`src/llm/llm-providers-openai_completions.adb:218-232`).
- **Usage extraction:** usage is read from the top-level response object, not from `choices`, and uses the correct OpenAI field names `prompt_tokens` and `completion_tokens` (`src/llm/llm-providers-openai_completions.adb:234-243`, `598-613`, `688-703`).
- **Thinking deltas:** `choices[0].delta.reasoning` is recognised as a string field and emitted as `Thinking_Delta` events (`src/llm/llm-providers-openai_completions.adb:629-639`).
- **Token-limit field name:** the request sends `max_completion_tokens`, not `max_tokens`, which matches the Phase 2 request shape in the implementation plan and the current tests (`src/llm/llm-providers-openai_completions.adb:435-437`; `test/src/llm_openai_completions_tests.adb:185-186`).
- **Tests exercised and passing:** the checked-in tests validate system-message-first behaviour for text completions, omission of `tools` when `Tools_Json = "[]"`, correct assistant/tool/tool-result request serialisation, and streamed tool-call argument assembly (`test/src/llm_openai_completions_tests.adb:169-229`, `234-320`, `334-511`).
