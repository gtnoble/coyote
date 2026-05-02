# Plan: Replace `pi` with a Native Ada Agentic Harness

## 1. Motivation

`pi_acme` currently spawns `pi --mode rpc` as a subprocess and communicates
with it over JSON-line pipes.  This works well but imposes three costs:

- **Deployment dependency** — users must install the Node.js-based `pi` tool
  separately.
- **Process overhead** — every prompt starts a subprocess; the RPC round-trip
  serialises and deserialises JSON on both ends.
- **Protocol opacity** — bugs or protocol changes in `pi` are outside our
  control; the Ada side can only react to whatever events arrive.

A native Ada harness eliminates the subprocess, gives full control over the
agentic loop, and makes the application self-contained.

---

## 2. Provider Priorities

**Primary targets:** GitHub Copilot and OpenRouter.

The user's pi `settings.json` sets `"defaultProvider": "github-copilot"` with
`"defaultModel": "claude-sonnet-4.6"`.  OpenRouter is the other general-
purpose provider.  Direct Anthropic access is a lower-priority follow-on.

---

## 3. Provider Deep-Dive

### 3.1 GitHub Copilot

GitHub Copilot has a **live model catalogue endpoint** that returns the full
set of models available to the authenticated user, with precise capability
data per model — no static table required.

**Model catalogue endpoint** (requires Copilot API token + static headers):
```
GET <base_url>/models
Authorization: Bearer <copilot_api_token>
User-Agent: GitHubCopilotChat/0.35.0
Editor-Version: vscode/1.107.0
Editor-Plugin-Version: copilot-chat/0.35.0
Copilot-Integration-Id: vscode-chat
```

Returns `{"data": [...]}` with 38 chat models and 3 embedding models (as of
May 2026).  Only entries where `capabilities.type == "chat"` are used.

**Field mapping to `LLM.Model_Info`** from the catalogue response:

| API field | `Model_Info` field | Notes |
|---|---|---|
| `id` | `Model_Id` | e.g. `"claude-sonnet-4.6"` |
| `name` | `Name` | |
| `capabilities.limits.max_context_window_tokens` | `Context_Window` | |
| `capabilities.limits.max_output_tokens` | `Max_Tokens` | |
| `capabilities.supports.tool_calls` | `Supports_Tools` | Boolean |
| `capabilities.supports.vision` | `Supports_Images` | Boolean |
| `capabilities.supports.reasoning_effort != []` | `Reasoning` | non-empty array |
| `capabilities.supports.max_thinking_budget` | `Max_Thinking_Budget` | 0 = not supported |
| `capabilities.supports.min_thinking_budget` | `Min_Thinking_Budget` | |
| `"/v1/messages" in supported_endpoints` | wire format | Anthropic Messages |
| `"/chat/completions" in supported_endpoints` | wire format | OpenAI Completions |
| (subscription-based) | `Cost` | always zero |

The `supported_endpoints` field is the authoritative source for wire format.
Most Claude models list both; the provider prefers `/v1/messages` for any
model that supports it and falls back to `/chat/completions` otherwise.

**Caching strategy** — same 24-hour TTL / disk-cache pattern as OpenRouter.
Cache file: `~/.pi/agent/github_copilot_models_cache.json`, keyed to the
base URL so enterprise users are not served individual-plan data.

**Static headers (all API requests):**
```
User-Agent: GitHubCopilotChat/0.35.0
Editor-Version: vscode/1.107.0
Editor-Plugin-Version: copilot-chat/0.35.0
Copilot-Integration-Id: vscode-chat
Openai-Intent: conversation-edits
```

**Dynamic header:**
```
X-Initiator: user   (when last message role is "user")
X-Initiator: agent  (when last message role is anything else)
```

**Base URL** is dynamic: extracted from the `proxy-ep=` segment of the
short-lived Copilot API token:
```
Token: tid=...;exp=...;proxy-ep=proxy.individual.githubcopilot.com;...
→ API base: https://api.individual.githubcopilot.com
```
Fallback default: `https://api.individual.githubcopilot.com`.

**Credential lifecycle** (`~/.pi/agent/auth.json`):
```json
{
  "github-copilot": {
    "type": "oauth",
    "refresh": "<github_oauth_access_token>",
    "access":  "<short-lived_copilot_api_token>",
    "expires": <unix_timestamp_ms>
  }
}
```
The `access` token lives ~30 minutes.  When `expires` is past, call:
```
GET https://api.github.com/copilot_internal/v2/token
Authorization: Bearer <refresh>
User-Agent: GitHubCopilotChat/0.35.0
Editor-Version: vscode/1.107.0
Editor-Plugin-Version: copilot-chat/0.35.0
Copilot-Integration-Id: vscode-chat
```
Response: `{"token": "tid=...;...", "expires_at": <unix_s>}`.

Update `auth.json` atomically (temp-file rename).

**Initial login / re-login** is NOT implemented natively.  The user performs
the device-code OAuth flow via `pi login github-copilot` as before.  The Ada
harness only reads and refreshes existing credentials.

### 3.2 OpenRouter

OpenRouter speaks **OpenAI Chat Completions** (`/v1/chat/completions`) with
SSE streaming.

| Property | Value |
|---|---|
| Base URL | `https://openrouter.ai/api/v1` |
| Auth header | `Authorization: Bearer <api_key>` |
| API key env var | `OPENROUTER_API_KEY` |
| API key config | `~/.pi/agent/models.json` → `providers.openrouter.apiKey` |

**Optional headers** (added by default):
```
HTTP-Referer: https://github.com/gtnoble/pi_acme
X-Title: pi_acme
```

**Model-selection thinking parameter** (for reasoning models):
```json
{"reasoning": {"effort": "medium"}}
```
Values: `"low"` | `"medium"` | `"high"`.

**Provider routing** (OpenRouter-specific field, passed through as-is when
present in the model's `compat` config):
```json
{"provider": {"only": ["Anthropic"], "order": ["Anthropic", "Together"]}}
```

**Model catalogue fetched live** from the OpenRouter models API rather than
baked in as a static dataset.  See §3.3 and Phase 3 for the full design.

### 3.3 OpenRouter Model Catalogue API

```
GET https://openrouter.ai/api/v1/models
```

No authentication required.  Currently returns ~370 models; the list grows
continuously.  Each entry contains everything needed to populate
`LLM.Model_Info`:

```json
{
  "id":             "anthropic/claude-sonnet-4-20250514",
  "name":           "Claude Sonnet 4",
  "context_length": 200000,
  "architecture": {
    "input_modalities":  ["text", "image"],
    "output_modalities": ["text"]
  },
  "pricing": {
    "prompt":           "0.000003",
    "completion":       "0.000015",
    "input_cache_read": "0.0000003"
  },
  "top_provider": {
    "context_length":        200000,
    "max_completion_tokens": 16000
  },
  "supported_parameters": ["tools", "reasoning", ...]
}
```

**Field mapping to `LLM.Model_Info`:**

| API field | `Model_Info` field | Notes |
|---|---|---|
| `id` | `Model_Id` | e.g. `"anthropic/claude-sonnet-4-20250514"` |
| `name` | `Name` | display name |
| `top_provider.context_length` or `context_length` | `Context_Window` | prefer `top_provider` if non-null |
| `top_provider.max_completion_tokens` | `Max_Tokens` | default 4096 when null |
| `"image" in architecture.input_modalities` | `Supports_Images` | Boolean |
| `"tools" in supported_parameters` | `Supports_Tools` | Boolean |
| `"reasoning" in supported_parameters` | `Reasoning` | Boolean |
| `float(pricing.prompt) × 1_000_000` | `Cost.Input` | dollars per million tokens |
| `float(pricing.completion) × 1_000_000` | `Cost.Output` | |
| `float(pricing.input_cache_read) × 1_000_000` | `Cost.Cache_Read` | 0.0 when absent |

**Caching strategy** — the catalogue is fetched once per session and held
in memory.  On startup:
1. Check `~/.pi/agent/openrouter_models_cache.json` for a cached response
   with a `"fetched_at"` timestamp.
2. If the cache is present and younger than 24 hours, load from disk.
3. Otherwise fetch live, update the cache file, and use the fresh data.
4. If the live fetch fails and a stale cache exists, log a warning and use
   the stale data.  If no cache exists at all, log an error and return an
   empty list (the user can still type a model spec manually).

Cache file format:
```json
{"fetched_at": 1748000000, "data": [...raw API response array...]}
```

The cache file is written atomically (temp-file rename, same pattern as
`auth.json`).

---

## 4. Architecture

### 4.1 New Package Hierarchy (`src/llm/`)

```
llm.ads                     -- root; common type aliases
llm-types.ads/.adb          -- Content_Block, Message, Usage, Model_Info
llm-events.ads              -- tagged event hierarchy (mirrors pi RPC events)
llm-sse.ads/.adb            -- Server-Sent Events line parser
llm-settings.ads/.adb       -- reads ~/.pi/agent/settings.json +
                            --   ~/.pi/agent/models.json (api keys, overrides)
llm-auth.ads                -- Auth_Credentials type; auth.json read/write
llm-auth-github_copilot.ads/.adb  -- token refresh; base-URL extraction
llm-model_registry.ads/.adb -- hardcoded model table; curated subset for each
                            --   provider (full table from models.generated.js)
llm-providers.ads           -- abstract Provider_Adapter interface
llm-http.ads/.adb           -- HTTP POST with streaming write callback;
                            --   wraps Curl_Binding; owns error handling
llm-http-curl_binding.ads   -- Ada Import specs for libcurl easy API +
                            --   C-convention Write_Callback type
llm-http-curl_binding.adb   -- Ada_Write_Callback body (Convention => C, Export)
llm-providers-openai_completions.ads/.adb -- OpenAI /v1/chat/completions
                                          -- (base for OpenRouter, Copilot GPT)
llm-providers-anthropic_messages.ads/.adb -- Anthropic /v1/messages
                                          -- (base for Copilot Claude, direct)
llm-providers-openrouter.ads/.adb    -- OpenRouter (extends openai_completions)
llm-providers-github_copilot.ads/.adb -- Copilot (wraps either provider + auth +
                                          --   live catalogue)
llm-providers-github_copilot-catalogue.ads/.adb -- GET <base>/models fetch + cache
llm-tools.ads               -- Tool_Descriptor; Execute dispatcher
llm-tools-bash.ads/.adb     -- bash execution (GNATCOLL.OS.Process)
llm-tools-file_ops.ads/.adb -- read / write / edit / find / glob
llm-session_store.ads/.adb  -- JSONL session file write path
llm-agent.ads/.adb          -- the agentic loop
llm-agent-pi_adapter.ads    -- thin JSON bridge to Dispatch_Pi_Event
```

Existing packages (`Nine_P.*`, `Acme.*`, `Session_Lister`,
`Pi_Acme_App.*`) are **unchanged** until Phase 10.

### 4.2 Integration Strategy — Thin Adapter

`Dispatch_Pi_Event` is ~500 lines of working code.  The adapter converts
`LLM.Events.Agent_Event'Class` values to the same JSON strings the existing
dispatcher already parses.  No changes to `Pi_Acme_App.Dispatch`.

### 4.3 Task Structure After Migration

| Task | Before | After |
|---|---|---|
| `Pi_Stdout_Task` | reads pi stdout JSON | **removed** |
| `Pi_Stderr_Task` | reads pi stderr | **removed** |
| `Agent_Task` | — | runs `LLM.Agent.Run_Prompt`; feeds events via adapter |
| `Acme_Event_Task` | calls `Pi_RPC.Send` | calls `Agent.Send_Prompt` etc. |
| `Plumb_*_Task` × 3 | calls `Pi_RPC.Send` / restarts subprocess | calls `Agent.Set_Model` / `Switch_Session` |

Session switching becomes in-process; the `Restart_Loop` is eliminated.

---

## 5. Phased Implementation Plan

### Phase 0 — libcurl Binding + Settings  *(~1 day)*

**Build system changes** (no Alire packages required for HTTP):

`pi_acme.gpr`:
```ada
for Languages use ("Ada", "C");
for Source_Files use (... "thin_curl.c" ...);

package Compiler is
   for Switches ("C") use ("-O2", "-I/usr/include/x86_64-linux-gnu");
end Compiler;

package Linker is
   for Switches ("Ada") use ("-lcurl");
end Linker;
```

**`src/llm/thin_curl.c`** — non-variadic C wrappers for `curl_easy_setopt`
and `curl_easy_getinfo` (Ada cannot call variadic C functions directly):
```c
#include <curl/curl.h>
CURLcode curl_set_url           (CURL *h, const char *v)  { return curl_easy_setopt(h, CURLOPT_URL,           v); }
CURLcode curl_set_post          (CURL *h, long v)          { return curl_easy_setopt(h, CURLOPT_POST,          v); }
CURLcode curl_set_postfields    (CURL *h, const char *v)   { return curl_easy_setopt(h, CURLOPT_POSTFIELDS,    v); }
CURLcode curl_set_postfieldsize (CURL *h, long v)          { return curl_easy_setopt(h, CURLOPT_POSTFIELDSIZE, v); }
CURLcode curl_set_httpheader    (CURL *h, struct curl_slist *v) { return curl_easy_setopt(h, CURLOPT_HTTPHEADER, v); }
CURLcode curl_set_writefunction (CURL *h, curl_write_callback v) { return curl_easy_setopt(h, CURLOPT_WRITEFUNCTION, v); }
CURLcode curl_set_writedata     (CURL *h, void *v)         { return curl_easy_setopt(h, CURLOPT_WRITEDATA,     v); }
CURLcode curl_set_nosignal      (CURL *h, long v)          { return curl_easy_setopt(h, CURLOPT_NOSIGNAL,      v); }
CURLcode curl_get_response_code (CURL *h, long *out)       { return curl_easy_getinfo(h, CURLINFO_RESPONSE_CODE, out); }
```

**`LLM.HTTP.Curl_Binding`** — Ada import specs:
```ada
with Interfaces.C;          use Interfaces.C;
with Interfaces.C.Strings;
with System;

package LLM.HTTP.Curl_Binding is

   type Handle  is new System.Address;
   type Slist   is new System.Address;
   subtype Code is int;                      --  CURLcode
   CURLE_OK : constant Code := 0;

   --  C-convention write callback type.
   --  Ada_Write_Callback (in the body) is assigned to this type and
   --  passed to curl via curl_set_writefunction.
   type Write_Func is access function
     (Buffer   : System.Address;
      Size     : size_t;
      NMemb    : size_t;
      UserData : System.Address) return size_t
   with Convention => C;

   --  curl easy API
   function  Easy_Init    return Handle
     with Import, Convention => C, External_Name => "curl_easy_init";
   procedure Easy_Cleanup (H : Handle)
     with Import, Convention => C, External_Name => "curl_easy_cleanup";
   function  Easy_Perform (H : Handle) return Code
     with Import, Convention => C, External_Name => "curl_easy_perform";

   --  Non-variadic setopt/getinfo wrappers (thin_curl.c)
   function Set_URL            (H : Handle; V : C.Strings.chars_ptr) return Code
     with Import, Convention => C, External_Name => "curl_set_url";
   function Set_Post           (H : Handle; V : long)    return Code
     with Import, Convention => C, External_Name => "curl_set_post";
   function Set_Post_Fields    (H : Handle; V : C.Strings.chars_ptr) return Code
     with Import, Convention => C, External_Name => "curl_set_postfields";
   function Set_Post_Size      (H : Handle; V : long)    return Code
     with Import, Convention => C, External_Name => "curl_set_postfieldsize";
   function Set_Http_Header    (H : Handle; V : Slist)   return Code
     with Import, Convention => C, External_Name => "curl_set_httpheader";
   function Set_Write_Function (H : Handle; V : Write_Func) return Code
     with Import, Convention => C, External_Name => "curl_set_writefunction";
   function Set_Write_Data     (H : Handle; V : System.Address) return Code
     with Import, Convention => C, External_Name => "curl_set_writedata";
   function Set_No_Signal      (H : Handle; V : long)    return Code
     with Import, Convention => C, External_Name => "curl_set_nosignal";
   function Get_Response_Code  (H : Handle; Out_Code : access long) return Code
     with Import, Convention => C, External_Name => "curl_get_response_code";

   --  curl_slist for request headers
   function  Slist_Append   (L : Slist; S : C.Strings.chars_ptr) return Slist
     with Import, Convention => C, External_Name => "curl_slist_append";
   procedure Slist_Free_All (L : Slist)
     with Import, Convention => C, External_Name => "curl_slist_free_all";

   function Strerror (C : Code) return C.Strings.chars_ptr
     with Import, Convention => C, External_Name => "curl_easy_strerror";

   --  The single library-level C-convention write callback.
   --  UserData must point to a Write_Context (defined in llm-http.adb).
   function Ada_Write_Callback
     (Buffer   : System.Address;
      Size     : size_t;
      NMemb    : size_t;
      UserData : System.Address) return size_t
   with Export, Convention => C, External_Name => "ada_curl_write_cb";

end LLM.HTTP.Curl_Binding;
```

**`LLM.HTTP`** — the Ada-facing streaming HTTP client:
```ada
type Header_List is limited private;
procedure Add_Header (H : in out Header_List; Name, Value : String);

--  POST URL with streaming response.  On_Chunk is called for each received
--  byte chunk (not line-by-line); callers feed chunks to LLM.SSE.Feed.
--  Status is the HTTP response code (200, 401, 429, etc.).
--  Raises Curl_Error on transport/TLS failure.
procedure Post
  (URL      :        String;
   Headers  :        Header_List;
   Body     :        String;
   On_Chunk :        not null access procedure (Data : String);
   Status   :    out Natural);

--  GET URL (no body).  Same streaming callback convention.
procedure Get
  (URL      :        String;
   Headers  :        Header_List;
   On_Chunk :        not null access procedure (Data : String);
   Status   :    out Natural);

Curl_Error : exception;
```

Internally, `Post` and `Get`:
1. `Easy_Init` → set `CURLOPT_NOSIGNAL = 1` (critical for Ada task safety —
   prevents libcurl installing SIGALRM handlers that conflict with GNAT's
   task scheduler)
2. Set URL, method, headers, body
3. `Set_Write_Function (Ada_Write_Callback'Access)` +
   `Set_Write_Data (Ctx'Address)` where `Ctx.On_Chunk := On_Chunk`
4. `Easy_Perform` — **blocks the calling task**; `Ada_Write_Callback` fires
   in the same task for each received chunk; no extra threading needed
5. `Get_Response_Code` → Status
6. `Easy_Cleanup` (in a `begin … exception … when others => Easy_Cleanup; raise`)

The `Ada_Write_Callback` body (in `llm-http-curl_binding.adb`):
```ada
function Ada_Write_Callback
  (Buffer : System.Address; Size : size_t; NMemb : size_t;
   UserData : System.Address) return size_t
is
   Bytes : constant size_t := Size * NMemb;
   Ctx   : Write_Context;  --  overlay on UserData
   for Ctx'Address use UserData;
   Data  : String (1 .. Natural (Bytes));
   for Data'Address use Buffer;
begin
   if Bytes > 0 then
      Ctx.On_Chunk (Data);
   end if;
   return Bytes;
end Ada_Write_Callback;
```

- Create `llm.ads` (root package, empty body).
- Create `llm-settings.ads/.adb`:
  - Reads `~/.pi/agent/settings.json` → default provider/model/thinking level.
  - Reads `~/.pi/agent/models.json` (optional) → per-provider `apiKey`
    overrides and custom model definitions.
  - API key resolution order: models.json literal → `${ENV_VAR}` interpolation
    → environment variable (env map from `env-api-keys.js`).

Unit tests:
- Fixture JSON files; assert correct settings/key lookup priority.
- Mock `On_Chunk` callback; call `Post` against a local HTTP server
  (plain HTTP, no TLS needed for unit tests); assert chunks arrive
  incrementally and status code is captured correctly.

---

### Phase 1 — Types & SSE Parser  *(~2 days)*

**`LLM.Types`** — core conversation types:
```ada
type Role is (User, Assistant, Tool_Result);

type Content_Block_Kind is
  (Text_Block, Thinking_Block, Tool_Call_Block, Tool_Result_Block);

type Usage is record
   Input       : Natural := 0;
   Output      : Natural := 0;
   Cache_Read  : Natural := 0;
   Cache_Write : Natural := 0;
end record;

type Stop_Reason is
  (Stop, Length, Tool_Use, Aborted, Error_Stop, Unknown_Stop);
```

**`LLM.SSE`** — Server-Sent Events line parser:
- Stateful `Parser` record; `Feed (P, Data)` accumulates bytes
- `Next_Event (P, Event_Name, Data)` returns the next complete event
- Strips `event:`, `data:` prefixes; skips `ping` events; handles `[DONE]`
- Both OpenAI and Anthropic SSE use the same `data: {json}\n\n` envelope

Unit tests: canned Anthropic SSE fixture; canned OpenAI SSE fixture;
multi-chunk split across Feed calls; `[DONE]` termination.

---

### Phase 2 — OpenAI Completions Provider (Base)  *(~3 days)*

`LLM.Providers.OpenAI_Completions` handles the OpenAI Chat Completions wire
format.  Used directly by OpenRouter; extended by the GitHub Copilot provider.

**Request format:**
```json
{
  "model": "<model_id>",
  "messages": [{"role": "system|user|assistant|tool", "content": "..."}],
  "tools": [/* JSON Schema tool definitions */],
  "stream": true,
  "max_completion_tokens": 8192
}
```

**SSE response mapping** (OpenAI streaming):
```
data: {"choices":[{"delta":{"content":"Hello"}}]}
data: {"choices":[{"delta":{"tool_calls":[...]}}]}
data: {"usage":{...}}
data: [DONE]
```
Mapped to `LLM.Events` types matching the pi RPC event set.

**Tool call assembly:** OpenAI streams tool calls in fragments across multiple
`tool_calls[i].function.arguments` deltas; accumulate per `index` until `[DONE]`.

**Thinking tokens** (reasoning models):
```json
{"choices":[{"delta":{"reasoning":"...thinking..."}}]}
```
or (OpenRouter format):
```json
{"reasoning": {"effort": "medium"}}
```

**Non-streaming** (fallback): POST without `"stream": true`; parse the single
JSON response object.

All connections go through `LLM.HTTP.Post` (Phase 0), which uses
`curl_easy_perform` with the write callback.  No SSL initialisation ceremony:
libcurl uses system CA certificates by default.

Unit tests:
- Mock HTTP server (plain HTTP, started in test suite setup) returns a canned
  streaming SSE response line-by-line; assert correct event sequence, tool
  call assembly, and usage parsing.
- Assert: non-streaming path parses a single-object response correctly.

---

### Phase 3 — OpenRouter Provider + Live Model Catalogue  *(~2 days)*

`LLM.Providers.OpenRouter` extends `OpenAI_Completions` with:

1. **Base URL:** `https://openrouter.ai/api/v1` (hardcoded; overrideable).
2. **Auth header:** `Authorization: Bearer <api_key>` (from settings or
   `OPENROUTER_API_KEY` env var).
3. **Extra headers:** `HTTP-Referer: https://github.com/gtnoble/pi_acme`,
   `X-Title: pi_acme`.
4. **Thinking:** `{"reasoning": {"effort": "<low|medium|high>"}}` added when
   thinking level is non-off and model has `Reasoning = True`.
5. **Provider routing:** pass `{"provider": <routing_prefs>}` when the model
   definition carries routing preferences.
6. **Model ID passthrough:** `model: "<provider>/<model-id>"` as-is (e.g.
   `"anthropic/claude-sonnet-4-20250514"`).

**`LLM.Providers.OpenRouter.Catalogue`** — live model list:

```ada
--  Fetch the model catalogue from GET /api/v1/models.
--  Loads from disk cache (~/.pi/agent/openrouter_models_cache.json) when
--  present and younger than Max_Age_Hours; fetches live otherwise.
--  On live-fetch failure, falls back to stale cache with a logged warning.
procedure Load_Catalogue
  (Models        :    out LLM.Model_Registry.Model_Info_Vectors.Vector;
   Max_Age_Hours :        Natural := 24);
```

Parsing `GET /api/v1/models` response (fields per §3.3 above):
- `float(pricing.prompt) * 1_000_000.0` → `Cost.Input`
- `float(pricing.completion) * 1_000_000.0` → `Cost.Output`
- `pricing.input_cache_read` (may be absent) → `Cost.Cache_Read`
- `"tools" in supported_parameters` → `Supports_Tools`
- `"reasoning" in supported_parameters` → `Reasoning`
- `"image" in architecture.input_modalities` → `Supports_Images`
- `top_provider.context_length` (prefer) else `context_length` → `Context_Window`
- `top_provider.max_completion_tokens` (null → 4096) → `Max_Tokens`

Cache file (`~/.pi/agent/openrouter_models_cache.json`) format:
```json
{"fetched_at": 1748000000, "data": [ ...raw API array... ]}
```
Written atomically via temp-file rename.

Unit tests:
- Parse a fixture `GET /api/v1/models` response (saved from live API).
- Assert pricing conversion: `"0.000003"` → `3.0` ($/M tokens).
- Assert `Reasoning = True` for a model with `"reasoning"` in params.
- Assert `Supports_Tools = False` for a model without `"tools"` in params.
- Cache freshness logic: fresh cache loaded from disk; stale cache triggers
  fetch; missing cache triggers fetch; fetch failure falls back to stale.
- Assert `Authorization` and extra headers are present on completions calls.
- Assert `reasoning.effort` is included for a reasoning model.

---

### Phase 4 — GitHub Copilot Auth + Model Catalogue  *(~2 days)*

`LLM.Auth` — `Auth_Credentials` record; `auth.json` read/write:
```ada
type Provider_Credentials is record
   Credential_Type : Ada.Strings.Unbounded.Unbounded_String;
   Refresh_Token   : Ada.Strings.Unbounded.Unbounded_String;
   Access_Token    : Ada.Strings.Unbounded.Unbounded_String;
   Expires_Ms      : Long_Long_Integer := 0;
end record;
```
- `Load_Credentials (Provider)` reads `~/.pi/agent/auth.json`.
- `Save_Credentials (Provider, Creds)` writes atomically (temp-file rename).

`LLM.Auth.GitHub_Copilot`:
- `Token_Expired (Creds)` → `Creds.Expires_Ms < Ada.Calendar.Clock * 1000`.
- `Refresh_Token (Creds)` — GET
  `https://api.github.com/copilot_internal/v2/token` with static Copilot
  headers + `Authorization: Bearer <refresh>`, parse `{token, expires_at}`,
  save updated credentials.
- `Get_Base_Url (Token)` — extracts `proxy-ep=<host>` from the token string
  and returns `https://api.<host>`.  Falls back to
  `https://api.individual.githubcopilot.com`.
- `Ensure_Valid (Creds)` — calls `Refresh_Token` if expired, serialises
  refresh via a protected mutex so concurrent tasks don't double-refresh.

`LLM.Providers.GitHub_Copilot.Catalogue` — live model list:

```ada
--  Fetch the model catalogue from GET <base_url>/models.
--  Loads from disk cache (~/.pi/agent/github_copilot_models_cache.json)
--  when present and younger than Max_Age_Hours; fetches live otherwise.
--  Cache is keyed to Base_Url so enterprise users are not served
--  individual-plan data.
procedure Load_Catalogue
  (Base_Url      :        String;
   Token         :        String;
   Models        :    out LLM.Model_Registry.Model_Info_Vectors.Vector;
   Max_Age_Hours :        Natural := 24);
```

Only entries where `capabilities.type = "chat"` are included.
Wire format per entry: `/v1/messages` present → Anthropic Messages preferred;
`/chat/completions` only → OpenAI Completions.

Unit tests:
- Mock token strings; assert `Get_Base_Url` extraction.
- Mock HTTP server; assert `Refresh_Token` sends correct headers, parses
  response, updates `Expires_Ms`.
- `Token_Expired` with past/future timestamps.
- Parse a fixture catalogue response; assert `Max_Thinking_Budget`,
  `Reasoning`, `Supports_Tools`, and wire-format selection are correct.
- Cache freshness and stale-fallback behaviour (same pattern as Phase 3).

---

### Phase 5 — GitHub Copilot Provider  *(~2 days)*

`LLM.Providers.GitHub_Copilot` is a dispatch adapter: it inspects each
model's wire-format capability (populated from the live catalogue) and
delegates to the correct underlying provider.

```
"/v1/messages" in model.Supported_Endpoints  →  LLM.Providers.Anthropic_Messages (Phase 5b)
"/chat/completions" only                     →  LLM.Providers.OpenAI_Completions (Phase 2)
```

For every request the adapter:
1. Calls `LLM.Auth.GitHub_Copilot.Ensure_Valid` to get a fresh token.
2. Injects static Copilot headers.
3. Injects `X-Initiator: user` or `X-Initiator: agent` based on the last
   message role.
4. Substitutes the dynamic base URL from `Get_Base_Url`.
5. Delegates to the appropriate underlying provider.

**Phase 5b — `LLM.Providers.Anthropic_Messages`:**

Wire format is the Anthropic Messages API.  Used here for Copilot's Claude
models; also usable later for direct Anthropic access.

Request:
```json
{
  "model": "claude-sonnet-4.6",
  "system": "<system_prompt>",
  "messages": [{"role":"user","content":[{"type":"text","text":"Hello"}]}],
  "tools": [...],
  "stream": true,
  "max_tokens": 16000,
  "thinking": {"type":"enabled","budget_tokens":8192}
}
```

SSE event mapping (Anthropic streaming):
```
event: message_start
event: content_block_start  → thinking_start / text_start / toolcall_start
event: content_block_delta  → thinking_delta / text_delta / toolcall_delta
event: content_block_stop   → thinking_end / text_end / toolcall_end
event: message_delta        → contains stop_reason, usage
event: message_stop         → consumed internally
event: ping                 → ignored
```

Thinking level → `budget_tokens` map:
```
off=0, minimal=1024, low=2048, medium=8192, high=16384, xhigh=32768
```
When `off`, omit `thinking` field entirely.

Unit tests (mock server):
- Claude Sonnet request via Copilot → assert static + dynamic Copilot headers.
- SSE delta stream → correct event sequence.
- GPT-4o model → uses OpenAI completions path, not Anthropic.
- Token refresh triggered when `expires_ms` is in the past.

---

### Phase 6 — Built-in Tools  *(~2 days)*

`LLM.Tools` — tool descriptor + executor:
```ada
type Tool_Descriptor is record
   Name        : Ada.Strings.Unbounded.Unbounded_String;
   Description : Ada.Strings.Unbounded.Unbounded_String;
   Schema_Json : Ada.Strings.Unbounded.Unbounded_String;
end record;
```

`LLM.Tools.Bash`:
- Schema: `{"command": string, "description": string (optional)}`
- Uses `GNATCOLL.OS.Process.Start` (already used in project)
- Captures stdout + stderr interleaved; truncates at 200 KB; writes overflow
  to temp file

`LLM.Tools.File_Ops` — `read`, `write`, `edit`, `find`, `glob`:
- `edit`: find `oldText` in file, replace with `newText`; error on non-unique
  or missing match
- `find`/`glob`: recursive directory walk with include/exclude patterns

`LLM.Tools.Execute` — dispatcher that calls the right handler by name.

Unit tests: each tool with success and failure cases; `edit` non-unique error.

---

### Phase 7 — Agentic Loop  *(~3 days)*

`LLM.Agent`:
```ada
type Session is limited private;

procedure Create
  (S             :    out Session;
   Model_Spec    :        String;
   System_Prompt :        String := "";
   No_Tools      :        Boolean := False;
   Session_Id    :        String := "");

procedure Run_Prompt
  (S        : in out Session;
   Prompt   :        String;
   On_Event :        access procedure
                       (E : LLM.Events.Agent_Event'Class));

procedure Request_Abort    (S : in out Session);
procedure New_Session       (S : in out Session);
procedure Switch_Session    (S : in out Session; UUID : String);
procedure Set_Model         (S : in out Session; Spec : String);
procedure Set_Thinking      (S : in out Session; Level : String);
function  Session_Id        (S : Session) return String;
function  Current_Model_Spec (S : Session) return String;
function  Context_Window    (S : Session) return Natural;
```

Agentic loop body:
1. Emit `Agent_Start_Event`
2. Send conversation to provider; stream events via `On_Event`
3. On tool calls: emit `Tool_Execution_Start_Event`, execute, emit
   `Tool_Execution_End_Event`, append result, loop to step 2
4. Emit `Agent_End_Event`
5. On retryable errors (429, 529, 5xx): emit `Auto_Retry_Start_Event`,
   sleep with backoff, retry; emit `Auto_Retry_End_Event`
6. Persist conversation to session file via `LLM.Session_Store`

Unit tests with a mock provider adapter: single-turn; multi-turn with tool
call; abort; retry on injected 429; `New_Session` resets history.

---

### Phase 8 — Session Persistence (Write Path)  *(~2 days)*

`LLM.Session_Store`:
- `Create_Session (Cwd)` → generates UUID, writes JSONL header line
- `Append_Message (Session_Id, Msg)` → appends one JSONL line atomically
- `Load_Messages (Session_Id)` → returns `Message_Vectors.Vector`

The JSONL format must be field-for-field compatible with pi's format so that
`Session_Lister.Parse_Session_File`, `Pi_Acme_App.History.Render_Session_History`,
and `Fork_Session` all continue to work unchanged.

Unit tests:
- Write + read back; assert `Parse_Session_File` parses our output correctly.
- `Fork_Session` on a natively-written session.

---

### Phase 9 — Model Registry  *(~1 day)*

Both providers supply live catalogues; the registry is a simple in-memory
store populated at startup from those catalogues, with no hardcoded model
tables.

```ada
type Model_Info is record
   Model_Id            : Ada.Strings.Unbounded.Unbounded_String;
   Name                : Ada.Strings.Unbounded.Unbounded_String;
   Provider            : Ada.Strings.Unbounded.Unbounded_String;
   Context_Window      : Natural  := 128_000;
   Max_Tokens          : Natural  := 4_096;
   Reasoning           : Boolean  := False;
   Supports_Tools      : Boolean  := True;
   Supports_Images     : Boolean  := False;
   Max_Thinking_Budget : Natural  := 0;
   Min_Thinking_Budget : Natural  := 0;
   --  Wire format: "anthropic-messages" or "openai-completions"
   Wire_Format         : Ada.Strings.Unbounded.Unbounded_String;
   Cost                : Model_Cost;
end record;

--  Populate from the live GitHub Copilot catalogue.
procedure Refresh_GitHub_Copilot
  (Base_Url : String; Token : String);

--  Populate from the live OpenRouter catalogue.
procedure Refresh_OpenRouter;

function Lookup
  (Provider : String;
   Model_Id : String) return Model_Info;
--  For "openrouter", an unknown model_id returns a default Model_Info
--  rather than raising (allows models added after the last fetch).
--  For "github-copilot", raises Not_Found if the id is not in the
--  catalogue (prevents silently routing to a non-existent model).

function Available_Models return Model_Info_Vectors.Vector;
--  All models across all providers for which credentials are configured.
```

Startup sequence in `LLM.Agent.Create`:
1. `Ensure_Valid` → refresh Copilot token if needed → extract base URL
2. `Refresh_GitHub_Copilot (Base_Url, Token)` — loads catalogue (disk cache
   or live fetch)
3. `Refresh_OpenRouter` — loads catalogue (disk cache or live fetch)
4. Agent is ready; `Available_Models` reflects both providers

Unit tests: lookup GitHub Copilot model after fixture-driven `Refresh`;
lookup OpenRouter model; unknown openrouter ID returns default; unknown
copilot ID raises Not_Found; `Available_Models` with fixture credentials.

---

### Phase 10 — `Pi_Acme_App` Integration  *(~3 days)*

**The only phase that changes existing source files.**

New `LLM.Agent.Pi_Adapter`:
- Wraps `LLM.Events.Agent_Event'Class`; serialises each event to the JSON
  string that `Dispatch_Pi_Event` already handles.
- One-line per event: `Write (To_Json (Event))` → passed to `Dispatch_Pi_Event`.

Changes to `Pi_Acme_App.Run` only:
- Remove `Pi_RPC.Process` and `Pi_Stdout_Task` / `Pi_Stderr_Task`.
- Add `Agent : LLM.Agent.Session` in place of `Proc : Pi_RPC.Process`.
- Add `Agent_Task` that calls `Agent.Run_Prompt` and feeds events.
- `Acme_Event_Task`: `Send` → `Agent.Run_Prompt`; `Stop` → `Agent.Request_Abort`;
  `New` → `Agent.New_Session`; etc.
- `Plumb_Model_Task`: `Agent.Set_Model` instead of `Pi_RPC.Send`.
- `Plumb_Session_Task`: `Agent.Switch_Session` instead of subprocess restart.
- `Plumb_Thinking_Task`: `Agent.Set_Thinking` instead of `Pi_RPC.Send`.
- Remove `Restart_Loop`.

`Pi_RPC` is retained but marked deprecated; removed in Phase 12.

Validation criteria:
- All AUnit tests still pass.
- Interactive smoke test: open window, send prompt, see streaming Claude output
  (via GitHub Copilot).
- Session resume (`--session UUID`) renders history and continues.
- `New`, `Stop`, `Models`, `Sessions`, `Compact`, `Thinking` commands work.
- Plumb ports for model/session/thinking work.

---

### Phase 11 — Anthropic Direct  *(~1 day)*

Direct Anthropic access (`LLM.Providers.Anthropic_Messages` was already
implemented in Phase 5b for use by the Copilot adapter).  Phase 11 only adds:
- API key resolution from `ANTHROPIC_API_KEY` env var / settings.
- Registration in `LLM.Model_Registry` for the `anthropic` provider.

---

### Phase 12 — Cleanup & Documentation  *(~1 day)*

- Remove `Pi_RPC` package.
- Update `AGENTS.md` source layout and architecture sections.
- Add integration test `llm_integration_tests.adb` guarded by
  `GITHUB_TOKEN` / `OPENROUTER_API_KEY`.

---

## 6. Revised Phase Order & Timeline

| # | Phase | Effort | Risk to existing code |
|---|---|---|---|
| 0 | libcurl binding + settings | 1 d | None |
| 1 | Types + SSE parser | 2 d | None |
| 2 | OpenAI Completions provider (base) | 3 d | None |
| 3 | OpenRouter provider + live model catalogue | 2 d | None |
| 4 | GitHub Copilot auth + model catalogue | 2 d | None |
| 5 | GitHub Copilot provider + Anthropic Messages | 2 d | None |
| 6 | Built-in tools | 2 d | None |
| 7 | Agentic loop | 3 d | None |
| 8 | Session persistence (write path) | 2 d | None |
| 9 | Model registry | 1 d | None |
| 10 | `Pi_Acme_App` integration | 3 d | **Only phase with existing-code risk** |
| 11 | Anthropic direct | 1 d | None |
| 12 | Cleanup + docs | 1 d | Low |
| | **Total** | **~23 days** | |

Phases 0–9 are purely additive.  The existing test suite stays green throughout.
Phase 10 is the single integration milestone.

---

## 7. Package Dependency Graph

```
llm (root)
├── llm-http                    (libcurl write-callback POST/GET)
│   ├── llm-http-curl_binding   (Ada Import specs + Ada_Write_Callback export)
│   └── thin_curl.c             (non-variadic curl_easy_setopt wrappers)
├── llm-types
├── llm-events
├── llm-sse
├── llm-settings
├── llm-auth
│   └── llm-auth-github_copilot
├── llm-model_registry          (depends on llm-types, llm-settings)
├── llm-providers               (abstract interface; depends on llm-types, llm-events)
│   ├── llm-providers-openai_completions  (+ llm-sse, llm-http)
│   │   └── llm-providers-openrouter       (extends openai_completions)
│   ├── llm-providers-anthropic_messages  (+ llm-sse, llm-http)
│   └── llm-providers-github_copilot      (delegates to openai_c or anthropic_m;
│       │                                  + llm-auth-github_copilot)
│       └── llm-providers-github_copilot-catalogue  (live fetch + disk cache)
├── llm-tools
│   ├── llm-tools-bash
│   └── llm-tools-file_ops
├── llm-session_store           (depends on llm-types, session_lister)
└── llm-agent                   (depends on all of the above)
    └── llm-agent-pi_adapter    (depends on llm-agent, gnatcoll.json,
                                 pi_acme_app.dispatch types)
```

---

## 8. Key Design Decisions

**D1 — Thin adapter, reuse `Dispatch_Pi_Event`:** avoids rewriting ~500 lines
of working code; the JSON overhead is trivial vs. LLM latency.

**D2 — OpenRouter before GitHub Copilot direct API calls:** OpenRouter uses
the simpler OpenAI completions format (no OAuth, no header complexity).
Validating the HTTP + SSE + tool-call pipeline on OpenRouter first derisk
the GitHub Copilot implementation.

**D3 — Read-only Copilot auth:** the Ada harness reads and refreshes existing
`auth.json` credentials; it does NOT implement the device-code OAuth flow.
Initial login continues to use `pi login github-copilot`.

**D4 — Both providers use live catalogues, no hardcoded model tables:**
GitHub Copilot exposes `GET <base_url>/models` (requires auth + Copilot
headers); OpenRouter exposes `GET https://openrouter.ai/api/v1/models`
(public, no auth).  Both are fetched on startup with a 24-hour disk cache
(`github_copilot_models_cache.json` and `openrouter_models_cache.json`).
The Copilot cache is keyed to the base URL.  Unknown OpenRouter IDs fall
back to a default `Model_Info`; unknown Copilot IDs raise `Not_Found`.

**D5 — libcurl for HTTP instead of GNAT AWS:** `curl_easy_perform` calls the
write callback synchronously for each received chunk, giving true SSE
streaming with no extra threading.  This eliminates the AWS `SOCKET=openssl`
build ceremony, the `AWS.Net.SSL.Initialize` elaboration requirement, and the
raw-socket fallback risk.  The binding is ~150 lines (a C shim file +
Ada import specs + one exported C-convention callback).  libcurl 8.x is
present on every modern Linux as `libcurl4-openssl-dev`; no Alire package
is needed.

**D6 — Session file compatibility:** write pi's JSONL format exactly, so
`Session_Lister`, `History`, and `Fork_Session` require no changes.

**D7 — No initial login flow:** `pi login github-copilot` must have been run
once before.  If credentials are absent, emit a clear error message pointing
the user to run `pi login`.

---

## 9. Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| libcurl not installed | Low | Medium | Document `libcurl4-openssl-dev` as a build prerequisite; error message if absent |
| CURLOPT_NOSIGNAL omitted | Low | High | Ada tasks and libcurl's SIGALRM handling conflict; binding always sets NOSIGNAL=1 |
| GitHub Copilot API endpoint changes | Low | High | Pin User-Agent/Editor-Version; refresh logic isolated |
| Copilot token refresh race (two windows) | Low | Medium | Protected mutex in `Ensure_Valid` |
| OpenRouter API key not configured | Medium | Low | Clear error message → user sets `OPENROUTER_API_KEY` |
| OpenRouter API unavailable at startup | Low | Low | Stale disk cache used; default Model_Info fallback for unknown IDs |
| OpenRouter API schema changes | Low | Medium | Cached responses survive schema drift; parse defensively with defaults |
| Session JSONL format drift from pi | Low | Medium | Compatibility test in Phase 8 |

---

## 10. What Stays Unchanged

`Nine_P.*`, `Acme.*`, `Session_Lister` (read path), `Pi_Acme_App.Dispatch`,
`Pi_Acme_App.History`, `Pi_Acme_App.Utils`, `Pi_Acme_App.App_State`, all tag
commands, all plumb ports, the session listing tool, and the user-visible
window interface are **identical before and after the migration**.
