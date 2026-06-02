# R5: GitHub Copilot Auth and Dispatch

## Verdict
FAIL

## Summary
The GitHub Copilot auth/dispatch implementation is mostly correct: token refresh uses the right endpoint and required headers, `proxy-ep` base-URL extraction is implemented correctly, static Copilot headers are added on catalogue and inference requests, Anthropic-vs-OpenAI routing follows the catalogue flags, and `Ensure_Valid` serializes refreshes within the process so concurrent callers do not double-refresh. The material correctness gap is token lifetime handling: refreshed tokens are stored and considered valid until their exact expiry time, but the review plan requires a 5-minute pre-expiry margin. That missing padding can let requests start with a token that is about to expire.

## Issues

### [HIGH] Copilot tokens are refreshed at exact expiry instead of 5 minutes early
**Files:** src/llm/llm-auth-github_copilot.adb:99-101, 213-215, 223-246; test/src/llm_auth_tests.adb:394-400
**Description:** `expires_at` is correctly parsed as seconds and converted to milliseconds, but the implementation does not apply the required 5-minute pre-expiry margin. `Token_Expired` only compares `Creds.Expires_Ms` against the current time, and `Refresh_Token` stores the exact expiry (`expires_at * 1000`) with no `- 300_000` adjustment. As a result, a request can proceed with a token that is technically still valid when checked but expires during or immediately before a Copilot API call.
**Evidence:**
```ada
function Token_Expired (Creds : Provider_Credentials) return Boolean is
begin
   return Creds.Expires_Ms < Current_Unix_Ms;
end Token_Expired;
```

```ada
Creds.Access_Token := Token;
Creds.Expires_Ms := Expires * 1000;
Save_Credentials ("github-copilot", Creds);
```

```ada
Assert
  (Creds.Expires_Ms = 9_999_999_999_000,
   "Refresh_Token should convert expires_at seconds to milliseconds");
```
**Fix:** Keep `Expires_Ms` as the real millisecond expiry, but make expiry checks conservative, e.g. `return Creds.Expires_Ms <= Current_Unix_Ms + 300_000;`. Alternatively, store a refresh deadline (`expires_at * 1000 - 300_000`) consistently and document that semantics. Update the auth test to assert the padded behavior, not the exact-expiry behavior.

## Confirmed Correct
- `Refresh_Token` targets `https://api.github.com/copilot_internal/v2/token` by default and sends the required refresh headers: `Authorization`, `User-Agent`, `Editor-Version`, `Editor-Plugin-Version`, and `Copilot-Integration-Id`.
- The refresh response parsing does multiply `expires_at` by 1000 before assigning `Expires_Ms`, so the seconds-to-milliseconds conversion itself is correct.
- `Get_Base_Url` correctly extracts `proxy-ep=...`, rewrites `proxy.<host>` to `https://api.<host>`, accepts `api.<host>` as-is with `https://`, and falls back to `https://api.individual.githubcopilot.com` when `proxy-ep` is absent.
- Every Copilot inference request gets all five static Copilot headers plus `X-Initiator`; the live catalogue fetch also adds the same static Copilot header set.
- `X-Initiator` logic is safe for empty histories and returns `user` for an empty vector or a final user message, otherwise `agent`.
- Anthropic-capable models are routed through `LLM.Providers.Anthropic_Messages`; non-Anthropic models are routed through `LLM.Providers.OpenAI_Completions`.
- The Anthropic delegate is constructed with the dynamic Copilot base URL, not `https://api.anthropic.com`.
- On the Anthropic path, authentication is sent as `Authorization: Bearer <copilot_access_token>` because `LLM.Providers.Anthropic_Messages` only switches to `x-api-key` when the base URL contains `anthropic.com`.
- Catalogue parsing correctly maps `max_thinking_budget`, `min_thinking_budget`, `tool_calls`, `vision`, reasoning support from a non-empty `reasoning_effort` array, and endpoint support from `supported_endpoints`.
- Catalogue parsing excludes non-chat entries by checking `capabilities.type = "chat"`.
- `Ensure_Valid`'s protected guard prevents double-refresh inside one process: a waiting caller reloads `auth.json` after acquiring the mutex and rechecks expiry before deciding whether another refresh is needed.
