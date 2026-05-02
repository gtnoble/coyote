# R7: Pi Adapter JSON Mapping

## Verdict
FAIL

## Summary
The adapter is mostly field-for-field compatible with `Dispatch_Pi_Event`: the camelCase names (`stopReason`, `cacheRead`, `contextWindow`, `toolCallId`, `thinkingLevel`, `maxAttempts`, `finalError`, `willRetry`) all match what the dispatcher actually reads, the `get_state` empty-model object is handled safely, the `get_session_stats` float-cost round-trip is correct, and zero-length mappings for unsupported `Message_Update_Kind` values are filtered before dispatch. The one substantive compatibility gap is `message_end`: the adapter never emits `message.usage.cost.total`, so the dispatcher cannot populate `State.Turn_Cost_Dmil`, and the live turn footer loses the per-turn cost display that the existing consumer supports.

## Issues

### [MEDIUM] `message_end` omits `usage.cost.total`, so per-turn cost never reaches the dispatcher
**Files:** `src/llm/llm-agent-pi_adapter.adb:113-120`, `src/pi_acme_app-dispatch.adb:428-447`, `src/pi_acme_app-utils.adb:569-574`

**Description:** `Dispatch_Pi_Event` treats `message.usage.cost.total` as the source of per-turn cost. The adapter serialises only token counts inside `message.usage`, so `Get_Object (Usage, "cost")` returns `JSON_Null` and `Turn_Cost` stays zero. The native path therefore drops the per-turn cost portion of the footer even though the dispatcher still has logic to display it.

**Evidence:**
```ada
--  src/llm/llm-agent-pi_adapter.adb
Usage.Set_Field ("input", Integer (Event.Tok_Usage.Input));
Usage.Set_Field ("output", Integer (Event.Tok_Usage.Output));
Usage.Set_Field
  ("cacheRead", Integer (Event.Tok_Usage.Cache_Read));
Usage.Set_Field
  ("cacheWrite", Integer (Event.Tok_Usage.Cache_Write));
Message.Set_Field ("usage", Usage);
```

```ada
--  src/pi_acme_app-dispatch.adb
Cost_Val  : constant JSON_Value :=
  Get_Object (Usage, "cost");
Turn_Cost : constant Natural :=
  (if Cost_Val.Kind = JSON_Object_Type
   then Get_Cost_Dmil (Cost_Val, "total")
   else 0);
...
if Turn_Cost > 0 then
   State.Set_Turn_Cost (Turn_Cost);
end if;
```

```ada
--  src/pi_acme_app-utils.adb
if Turn_Cost_Dmil > 0 then
   ...
   Append (Parts, Format_Cost (Turn_Cost_Dmil) & " turn");
end if;
```

**Fix:** Either extend the native event path so `Message_End_Event` carries per-message cost and emit `message.usage.cost.total` as a JSON float in dollars, or compute the turn cost in the native path before the footer is rendered and update the dispatcher/state through an equivalent field.

## Confirmed Correct
- `agent_end` emits an extra `messages: []` field, but `Dispatch_Pi_Event` reads only `type` for `agent_end`, so this is harmless.
- `message_end` uses the exact field names and casing the dispatcher expects for the fields it does emit: `message.role`, `message.stopReason`, optional `message.errorMessage`, and `usage.input` / `usage.output` / `usage.cacheRead` / `usage.cacheWrite`.
- `tool_execution_start` emits `toolName`, `toolCallId`, and an `args` JSON object. `Args_Object` accepts only parsed JSON objects and falls back to `{}` on invalid or non-object input, which matches the dispatcher's `Get_Object (Event, "args")` expectation and avoids exceptions.
- `tool_execution_end` emits the exact fields the dispatcher consumes: `toolCallId` as a string, `isError` as a boolean, and `result` as a string.
- `model_select` uses `model.provider`, `model.id`, and `model.contextWindow` with the exact camelCase the dispatcher reads; there is no snake_case/camelCase mismatch here.
- The `get_state` response shape is compatible with the dispatcher: `data.sessionId`, `data.thinkingLevel`, and `data.model` as an object. Because the adapter uses an empty object for `model`, the dispatcher's guarded update (`provider` and `id` must both be non-empty, and the current model must still be empty) does not clobber an already-populated model.
- The `get_session_stats` response shape matches the consumer exactly: `data.tokens.input`, `output`, `cacheRead`, `cacheWrite`, `total`, plus `data.cost` as a JSON float. The adapter converts `Cost_Dmil` to dollars via `/ 10_000.0`, and `Get_Cost_Dmil` converts the float back with `* 10_000.0` and rounding, so the intended dmil round-trip is preserved.
- `auto_retry_start` and `auto_retry_end` field names/types match dispatch exactly: `attempt`, `maxAttempts`, `delayMs`, `errorMessage`, `success`, and `finalError`. Emitting `finalError` as `""` on success is safe because the dispatcher only uses it when `success = false`.
- `auto_compaction_start` / `auto_compaction_end` use the exact names the dispatcher reads: `reason`, `aborted`, `willRetry`, and `errorMessage`. The extra `summary` field is ignored safely.
- `thinking_end` and `text_end` are emitted with the exact subtype names the dispatcher handles inside `assistantMessageEvent`; there is no mismatch such as `thinking_block_stop`.
- The only `Message_Update_Kind` values that map to `""` are `Thinking_Start`, `Text_Start`, `Tool_Call_Start`, `Tool_Call_Delta`, and `Tool_Call_End`. These zero-length results are filtered before dispatch in `src/pi_acme_app.adb` (`if Json_Str'Length > 0 then ... Dispatch_Pi_Event ...`), so they cannot reach `Dispatch_Pi_Event`. This is correct: the dispatcher has no pi-protocol handlers for start/tool-call update subevents, and tool-call UI display is driven instead by `Tool_Execution_Start_Event` / `Tool_Execution_End_Event`.
