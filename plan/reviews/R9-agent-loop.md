# R9: Agentic Loop Correctness

## Verdict
FAIL

## Summary
The core loop gets several important mechanics right: compound model specs are split on the first slash, each LLM round constructs a fresh provider object, the in-memory history order for tool-use turns is correct (`assistant-with-tool-calls` before `tool-result` messages), the user prompt is persisted before the first provider call, and abort is checked before the next LLM call. However, there are two high-severity state-consistency problems around mid-turn persistence/abort handling, plus one medium-severity accuracy problem in session-cost reporting. In particular, assistant tool-call messages are persisted before the overall turn finishes, and aborting a multi-tool batch can leave unresolved tool calls in history/session state.

## Issues

### [HIGH] Assistant tool-call messages are persisted before the turn completes
**Files:** src/llm/llm-agent.adb:816-823, src/llm/llm-agent.adb:826-878
**Description:** The loop persists the assistant message immediately after a provider response, even when that response ends in tool use and more work is still pending in the same user turn. This violates the R9 persistence requirement that assistant messages be saved only after the turn completes. If the process dies after the assistant tool-call message is appended but before all tool results and the follow-up LLM call complete, the session file is left with an incomplete transcript that cannot be cleanly resumed.
**Evidence:**
```ada
if Has_Assistant_Message (Builder) then
   declare
      Reply : constant LLM.Types.Message := Assistant_Message (Builder);
   begin
      S.History.Append (Reply);
      LLM.Session_Store.Append_Message
        (To_String (S.Session_UUID), Reply);
   end;
end if;

if not Pending_Tools.Is_Empty then
   for Tool_Block of Pending_Tools loop
      ...
      S.History.Append (Tool_Msg);
      LLM.Session_Store.Append_Message
        (To_String (S.Session_UUID), Tool_Msg);
   end loop;
else
   exit Agentic_Loop;
end if;
```
The assistant message is flushed before tool execution starts and before the next provider call in the same turn.
**Fix:** Buffer all non-user messages produced during a turn in memory and append them to the session file only once the turn reaches a stable boundary. At minimum, do not persist an assistant tool-call message until its corresponding tool-result messages have also been produced and the turn state is internally consistent.

### [HIGH] Aborting a multi-tool batch can leave unresolved tool calls in history
**Files:** src/llm/llm-agent.adb:826-875
**Description:** When one assistant response contains multiple tool calls, the assistant message with all `Tool_Call_Block`s is appended first, then tool results are appended one by one. An abort request during that loop exits before remaining tools are executed. That leaves `History` (and the persisted session) with an assistant message that advertises all tool calls but only a prefix of the matching tool-result messages. The next prompt/resume will send an invalid transcript to OpenAI/Anthropic-style APIs.
**Evidence:**
```ada
if not Pending_Tools.Is_Empty then
   for Tool_Block of Pending_Tools loop
      exit when S.Abort_State.Requested;
      ...
      S.History.Append (Tool_Msg);
      LLM.Session_Store.Append_Message
        (To_String (S.Session_UUID), Tool_Msg);
   end loop;

   exit Agentic_Loop when S.Abort_State.Requested;
else
   exit Agentic_Loop;
end if;
```
Because the assistant tool-call message has already been appended earlier in the loop, aborting here can preserve only some of the required result messages.
**Fix:** Treat a tool batch as atomic with respect to persisted history. On abort, either roll back the just-added assistant/tool-result messages for the unfinished turn, or synthesize terminal error/aborted results for every unexecuted tool call so the transcript remains structurally valid.

### [MEDIUM] Session stats cost is wrong after a model change within the same session
**Files:** src/llm/llm-agent.adb:499-527, src/llm/llm-agent.adb:529-535, src/llm/llm-types.ads:68-75
**Description:** `Session_Stats` correctly sums token usage across the whole history, but it prices every historical message using the current `S.Model_Info.Cost`. If the user changes models between turns, or resumes an older session and continues under a different model, the cumulative cost becomes incorrect.
**Evidence:**
```ada
for Msg of S.History loop
   Totals := Totals + Msg.Tok_Usage;
   Total_Cost := Total_Cost
     + Long_Float (Msg.Tok_Usage.Input)
       * S.Model_Info.Cost.Input / 1_000_000.0
     + Long_Float (Msg.Tok_Usage.Output)
       * S.Model_Info.Cost.Output / 1_000_000.0
     + Long_Float (Msg.Tok_Usage.Cache_Read)
       * S.Model_Info.Cost.Cache_Read / 1_000_000.0;
end loop;
```
`LLM.Types.Message` contains usage but no provider/model identity, so historical turns cannot be priced at their original rates.
**Fix:** Store provider/model (or precomputed per-message cost) with assistant messages and compute session cost from those recorded values. If only current-turn cost is desired, restrict the event to the latest assistant message instead of re-pricing the full history.

## Confirmed Correct
- `Split_Model_Spec` uses `Ada.Strings.Fixed.Index (Spec, "/")`, so compound model IDs such as `openrouter/anthropic/claude-3` are split on the first slash only.
- The in-memory history order for tool-use turns is correct: the assistant message containing `Tool_Call_Block` entries is appended before the subsequent `Tool_Result` message(s), and the next `Provider.Send` receives `S.History` in that order.
- Tool-call ID propagation is consistent: `Tool_Call_End` stores `Update.Tool_Call_Id` into both the assistant `Tool_Call_Block` and the pending tool record, and `Tool_Result_Message` reuses that same ID as `Result_Id`.
- A fresh provider object is constructed for each LLM round in `Agentic_Loop` (`GitHub_Copilot.Create`, `OpenRouter.Create`, `Anthropic_Messages.Create` are each called inside the loop body, not reused across turns).
- Abort is checked before the next LLM call (`if S.Abort_State.Requested then exit Agentic_Loop; end if;` at the top of the loop), not only after tool execution.
- Auto-retry scope is limited to `Provider.Send` inside `Send_With_Retry`; completed tools are not retried or re-executed by the retry loop.
- The user prompt is appended to `History` and persisted via `LLM.Session_Store.Append_Message` before the first provider call of the turn.
- `New_Session` clears `History` and allocates a fresh UUID with `Create_Session`.
- `Switch_Session` validates existence, updates `Session_UUID`, reloads `History` from `LLM.Session_Store.Load_Messages (UUID)`, and PCR-044 coverage verifies sandbox profile restoration or clearing from the target header.
- Usage totals in `Session_Stats` are cumulative across the full in-memory history, not just the most recent assistant turn.
