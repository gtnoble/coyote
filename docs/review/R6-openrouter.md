# R6: OpenRouter Provider and Catalogue

## Verdict
PASS_WITH_NOTES

## Summary
The OpenRouter provider and catalogue implementation matches the Phase 3 plan on the main correctness points. The catalogue parses pricing strings as dollars-per-token and converts them to dollars-per-million correctly, treats `top_provider.context_length = null` as a fallback to the top-level `context_length`, keys reasoning support only off the exact `"reasoning"` supported parameter, writes and evaluates cache timestamps in Unix seconds, and fetches `GET /api/v1/models` without an `Authorization` header. The only issue I found is a low-severity API robustness hole: the OpenRouter metadata headers are added in `Create`, not enforced in `Send`, so a caller that default-constructs `Provider` instead of using `Create` can send requests without `HTTP-Referer` and `X-Title`.

## Issues

### [LOW] Metadata headers are not guaranteed unless callers use `Create`
**Files:** src/llm/llm-providers-openrouter.adb:31-38, src/llm/llm-providers-openrouter.adb:120-152, src/llm/llm-providers-openai_completions.adb:778-787
**Description:** The required OpenRouter metadata headers are injected only by the `Create` constructor. `Send` repairs the base URL and API key, but it does not ensure that `HTTP-Referer` and `X-Title` are present before delegating to the base OpenAI sender. Because `Provider` can still be default-declared and then used via `Send`, the implementation does not guarantee those headers on every OpenRouter request.
**Evidence:**
```ada
function Create (Api_Key : String := "") return Provider is
begin
   return Result : Provider do
      Set_Base_Url (Result, Default_Base_Url);
      Set_Api_Key (Result, Api_Key);
      Add_Header (Result, "HTTP-Referer", "https://github.com/gtnoble/pi_acme");
      Add_Header (Result, "X-Title", "pi_acme");
   end return;
end Create;
```

```ada
overriding
procedure Send
   (P             : in out Provider;
    ...)
is
   Api_Key : constant String := Resolve_Api_Key (P);
begin
   if Api_Key'Length = 0 then
      raise LLM.HTTP.Curl_Error with ...;
   end if;

   if Get_Base_Url (P)'Length = 0 then
      Set_Base_Url (P, Default_Base_Url);
   end if;

   Set_Api_Key (P, Api_Key);

   LLM.Providers.OpenAI_Completions.Send_Request (...);
end Send;
```

```ada
LLM.HTTP.Add_Header (Headers, "Content-Type", "application/json");
LLM.HTTP.Add_Header
   (Headers, "Authorization", "Bearer " & To_String (P.Api_Key));

for Header of P.Extra_Headers loop
   LLM.HTTP.Add_Header
      (Headers,
       To_String (Header.Name),
       To_String (Header.Value));
end loop;
```
**Fix:** Make `Send` idempotently ensure the default OpenRouter metadata headers are present before calling `Send_Request`, or make construction through `Create` mandatory by preventing default initialization of the type.

## Confirmed Correct
- **Authorization header on completions calls:** `Send` resolves the API key and stores it with `Set_Api_Key`, and the base OpenAI sender always emits `Authorization: Bearer <api_key>` before posting the request (`src/llm/llm-providers-openrouter.adb:130-145`, `src/llm/llm-providers-openai_completions.adb:778-780`).
- **HTTP-Referer and X-Title when using the intended constructor path:** `Create` adds `HTTP-Referer: https://github.com/gtnoble/pi_acme` and `X-Title: pi_acme`, and the request sender forwards all extra headers (`src/llm/llm-providers-openrouter.adb:31-38`, `src/llm/llm-providers-openai_completions.adb:782-787`). The request test also asserts those headers for the normal `Create` path (`test/src/llm_openrouter_tests.adb:387-423`).
- **Reasoning-effort mapping:** `Minimal | Low -> "low"`, `Medium -> "medium"`, and `High | X_High -> "high"` exactly match the plan (`src/llm/llm-providers-openrouter.adb:79-93`).
- **Reasoning injection is gated correctly:** `Customize_Request` returns immediately when `Thinking = Off` (empty effort) or the model is not marked as reasoning-capable in the catalogue, so `reasoning` is only added when both conditions are satisfied (`src/llm/llm-providers-openrouter.adb:95-117`).
- **Reasoning capability detection is exact-match only:** catalogue parsing sets `Reasoning := Array_Contains (Parameters, "reasoning")`, so `"include_reasoning"` does not incorrectly enable reasoning support (`src/llm/llm-providers-openrouter-catalogue.adb:274-297`, `src/llm/llm-providers-openrouter-catalogue.adb:349-350`). The fixture and test explicitly cover this (`test/fixtures/openrouter_models.json`, `test/src/llm_openrouter_catalogue_tests.adb:326-328`).
- **Null `top_provider.context_length` handling:** `Get_Natural_Field` only accepts JSON integers. When `top_provider.context_length` is `null`, `Top_Context` becomes the sentinel `0`, and `Parse_Model` falls back to the top-level `context_length` rather than treating null as a real zero (`src/llm/llm-providers-openrouter-catalogue.adb:234-253`, `src/llm/llm-providers-openrouter-catalogue.adb:316-341`). The fixture includes this case for the Llama model (`test/fixtures/openrouter_models.json`).
- **Null `top_provider.max_completion_tokens` fallback:** when `max_completion_tokens` is null or absent, `Parse_Model` uses `4096` as required (`src/llm/llm-providers-openrouter-catalogue.adb:330-347`). The test verifies this on the Llama fixture (`test/src/llm_openrouter_catalogue_tests.adb:323-325`).
- **Pricing conversion and units:** `Parse_Price` reads decimal strings and multiplies by `1_000_000.0`, converting OpenRouter’s dollars-per-token strings to dollars-per-million-token costs (`src/llm/llm-providers-openrouter-catalogue.adb:299-314`). This correctly yields `3.0` for `"0.000003"`, `0.0` for `"0"`, and `0.0` when the field is absent because the empty-string path returns the default without raising.
- **Absent `input_cache_read` handling:** `Parse_Price` uses `Get_String_Field`; when `input_cache_read` is absent, the empty-string check returns the default `0.0` cleanly (`src/llm/llm-providers-openrouter-catalogue.adb:304-313`).
- **Cache file atomic write uses same-directory temp file:** `Temp_Path` appends `.tmp` to the final cache path, so the temporary file lives in the same directory as the target before `Rename_File` (`src/llm/llm-providers-openrouter-catalogue.adb:73-76`, `src/llm/llm-providers-openrouter-catalogue.adb:118-154`).
- **Cache timestamps use seconds consistently:** `Current_Unix_S` produces Unix seconds, `Save_Cache` writes that value as `fetched_at`, and `Is_Fresh` compares it against `Max_Age_Hours * 3600` using the same unit (`src/llm/llm-providers-openrouter-catalogue.adb:156-186`, `src/llm/llm-providers-openrouter-catalogue.adb:423-439`, `src/llm/llm-providers-openrouter-catalogue.adb:471-474`).
- **No-auth catalogue fetch:** `Fetch_Live` creates an empty `Header_List` and passes it directly to `LLM.HTTP.Get`; unlike completions requests, no `Authorization` header is added anywhere on this path (`src/llm/llm-providers-openrouter-catalogue.adb:370-392`).
- **Fresh/stale cache behavior:** `Load_Catalogue` prefers a fresh cache, fetches live when the cache is stale, and falls back to stale cached data if the live fetch fails (`src/llm/llm-providers-openrouter-catalogue.adb:442-508`). The catalogue tests cover all three behaviors (`test/src/llm_openrouter_catalogue_tests.adb:277-440`).
- **Reasoning request field shape:** when enabled, the provider sends exactly `{"reasoning": {"effort": "..."}}` (`src/llm/llm-providers-openrouter.adb:110-115`). The request test verifies `body['reasoning']['effort'] == 'medium'` for a reasoning-capable model (`test/src/llm_openrouter_tests.adb:334-385`, `test/src/llm_openrouter_tests.adb:425-479`).
