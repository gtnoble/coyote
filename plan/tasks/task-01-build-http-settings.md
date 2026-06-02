# Task 01 — Build System, libcurl Binding, LLM.HTTP, LLM.Settings

## Before you start

1. Load the Ada style guide skill:
   `/home/gtnoble/.pi/agent/skills/ada-style-guide/SKILL.md`
2. Read the project instructions:
   `/home/gtnoble/Projects/pi_acme_dev/AGENTS.md`
3. Read the full plan for background:
   `plan/native-agent-migration.md`

Working directory: `/home/gtnoble/Projects/pi_acme_dev`

## Context

This is the first task in a series that will replace the `pi --mode rpc`
subprocess with a native Ada agentic harness.  No prior tasks have run;
the repository is in its original state.

This task:
- Extends the GPR build files to support C sources and link libcurl.
- Adds the root `LLM` package.
- Implements the libcurl HTTP binding and the `LLM.HTTP` streaming client.
- Implements `LLM.Settings` (reads `~/.pi/agent/settings.json`).
- Adds unit tests for both new packages.

All new source goes under `src/llm/`.  No existing source files are changed
except the two GPR files.

## Build system changes

### `coyote.gpr`

Add `"src/llm/"` to `Source_Dirs`, add C to `Languages`, add the curl
linker switch, and add C compiler switches.  The file currently reads:

```ada
for Source_Dirs use ("src/", "config/", "tools/");
```

Change to:

```ada
for Languages use ("Ada", "C");
for Source_Dirs use ("src/", "src/llm/", "config/", "tools/");
```

Add inside the existing `package Compiler`:

```ada
for Switches ("C") use ("-O2");
```

Add a new `package Linker`:

```ada
package Linker is
   for Switches ("Ada") use ("-lcurl");
end Linker;
```

### `test/coyote_test.gpr`

The test project inherits from the main project via an Alire pin, so it
already sees all source.  Add `"src/llm/"` to its `Source_Dirs` as well:

```ada
for Source_Dirs use ("src/", "src/llm/", "config/");
```

Add the same linker switch so tests link against libcurl:

```ada
package Linker is
   for Switches ("Ada") use ("-lcurl");
end Linker;
```

## Files to create

### `src/llm/llm.ads`

Root package — empty spec, no body.

```ada
--  LLM — native Ada agentic harness root package.
--
--  Project: coyote
package LLM is
end LLM;
```

### `src/llm/thin_curl.c`

Non-variadic C wrappers for `curl_easy_setopt` and `curl_easy_getinfo`.
Ada cannot call variadic C functions directly; these one-liners bridge the
gap without any indirection overhead.

```c
#include <curl/curl.h>

CURLcode curl_set_url           (CURL *h, const char *v)
  { return curl_easy_setopt(h, CURLOPT_URL,           v); }
CURLcode curl_set_post          (CURL *h, long v)
  { return curl_easy_setopt(h, CURLOPT_POST,          v); }
CURLcode curl_set_postfields    (CURL *h, const char *v)
  { return curl_easy_setopt(h, CURLOPT_POSTFIELDS,    v); }
CURLcode curl_set_postfieldsize (CURL *h, long v)
  { return curl_easy_setopt(h, CURLOPT_POSTFIELDSIZE, v); }
CURLcode curl_set_httpheader    (CURL *h, struct curl_slist *v)
  { return curl_easy_setopt(h, CURLOPT_HTTPHEADER,    v); }
CURLcode curl_set_writefunction (CURL *h, curl_write_callback v)
  { return curl_easy_setopt(h, CURLOPT_WRITEFUNCTION, v); }
CURLcode curl_set_writedata     (CURL *h, void *v)
  { return curl_easy_setopt(h, CURLOPT_WRITEDATA,     v); }
CURLcode curl_set_nosignal      (CURL *h, long v)
  { return curl_easy_setopt(h, CURLOPT_NOSIGNAL,      v); }
CURLcode curl_get_response_code (CURL *h, long *out)
  { return curl_easy_getinfo(h, CURLINFO_RESPONSE_CODE, out); }
```

### `src/llm/llm-http-curl_binding.ads`

Ada import specs for the libcurl easy API plus the exported C-convention
write callback declaration.

```ada
--  LLM.HTTP.Curl_Binding — thin Ada binding to libcurl easy interface.
--
--  All curl_easy_setopt calls are routed through non-variadic C wrappers
--  in thin_curl.c because Ada cannot directly call variadic C functions.
--
--  Ada_Write_Callback is exported with Convention => C so that it can be
--  passed to curl_set_writefunction.  Its UserData parameter must point to
--  a Write_Context record (defined in llm-http.adb).
--
--  Project: coyote

with Interfaces.C;
with Interfaces.C.Strings;
with System;

package LLM.HTTP.Curl_Binding is

   type Handle is new System.Address;
   type Slist  is new System.Address;

   Null_Handle : constant Handle := Handle (System.Null_Address);
   Null_Slist  : constant Slist  := Slist  (System.Null_Address);

   subtype Code is Interfaces.C.int;  --  CURLcode
   CURLE_OK : constant Code := 0;

   --  C-convention write callback type.
   type Write_Func is access function
     (Buffer   : System.Address;
      Size     : Interfaces.C.size_t;
      NMemb    : Interfaces.C.size_t;
      UserData : System.Address) return Interfaces.C.size_t
   with Convention => C;

   --  curl easy API
   function  Easy_Init    return Handle
     with Import, Convention => C, External_Name => "curl_easy_init";
   procedure Easy_Cleanup (H : Handle)
     with Import, Convention => C, External_Name => "curl_easy_cleanup";
   function  Easy_Perform (H : Handle) return Code
     with Import, Convention => C, External_Name => "curl_easy_perform";

   --  Non-variadic setopt wrappers (thin_curl.c)
   function Set_URL       (H : Handle; V : Interfaces.C.Strings.chars_ptr)
     return Code
     with Import, Convention => C, External_Name => "curl_set_url";
   function Set_Post      (H : Handle; V : Interfaces.C.long) return Code
     with Import, Convention => C, External_Name => "curl_set_post";
   function Set_Post_Fields (H : Handle; V : Interfaces.C.Strings.chars_ptr)
     return Code
     with Import, Convention => C, External_Name => "curl_set_postfields";
   function Set_Post_Size (H : Handle; V : Interfaces.C.long) return Code
     with Import, Convention => C, External_Name => "curl_set_postfieldsize";
   function Set_Http_Header (H : Handle; V : Slist) return Code
     with Import, Convention => C, External_Name => "curl_set_httpheader";
   function Set_Write_Function (H : Handle; V : Write_Func) return Code
     with Import, Convention => C, External_Name => "curl_set_writefunction";
   function Set_Write_Data (H : Handle; V : System.Address) return Code
     with Import, Convention => C, External_Name => "curl_set_writedata";
   function Set_No_Signal (H : Handle; V : Interfaces.C.long) return Code
     with Import, Convention => C, External_Name => "curl_set_nosignal";
   function Get_Response_Code
     (H : Handle; Out_Code : access Interfaces.C.long) return Code
     with Import, Convention => C, External_Name => "curl_get_response_code";

   --  curl_slist header list
   function  Slist_Append
     (L : Slist; S : Interfaces.C.Strings.chars_ptr) return Slist
     with Import, Convention => C, External_Name => "curl_slist_append";
   procedure Slist_Free_All (L : Slist)
     with Import, Convention => C, External_Name => "curl_slist_free_all";

   function Strerror (C : Code) return Interfaces.C.Strings.chars_ptr
     with Import, Convention => C, External_Name => "curl_easy_strerror";

   --  Library-level C-convention write callback.
   --  UserData must point to an LLM.HTTP.Write_Context.
   function Ada_Write_Callback
     (Buffer   : System.Address;
      Size     : Interfaces.C.size_t;
      NMemb    : Interfaces.C.size_t;
      UserData : System.Address) return Interfaces.C.size_t
   with Export, Convention => C, External_Name => "ada_curl_write_cb";

end LLM.HTTP.Curl_Binding;
```

### `src/llm/llm-http-curl_binding.adb`

Body containing only `Ada_Write_Callback`.  The `Write_Context` type is
declared in `llm-http.adb` (private to that package body) and passed via
`System.Address`; we overlay it here without importing the type.

```ada
--  LLM.HTTP.Curl_Binding body.
--
--  Ada_Write_Callback is called by libcurl on the same task that called
--  curl_easy_perform.  It overlays the buffer and user-data pointers onto
--  Ada objects without copying, then calls the On_Chunk access procedure
--  stored in the Write_Context.
--
--  Project: coyote

with Interfaces.C; use Interfaces.C;
with System;

package body LLM.HTTP.Curl_Binding is

   --  Write_Context layout must match the private declaration in llm-http.adb.
   --  We do not import that type here; instead we overlay it via 'Address.
   type On_Chunk_Access is access procedure (Data : String);

   type Write_Context is record
      On_Chunk : On_Chunk_Access;
   end record;

   function Ada_Write_Callback
     (Buffer   : System.Address;
      Size     : size_t;
      NMemb    : size_t;
      UserData : System.Address) return size_t
   is
      Bytes : constant size_t := Size * NMemb;
      Ctx   : Write_Context;
      for Ctx'Address use UserData;
      pragma Import (Ada, Ctx);
      Data  : String (1 .. Natural (Bytes));
      for Data'Address use Buffer;
      pragma Import (Ada, Data);
   begin
      if Bytes > 0 then
         Ctx.On_Chunk (Data);
      end if;
      return Bytes;
   end Ada_Write_Callback;

end LLM.HTTP.Curl_Binding;
```

### `src/llm/llm-http.ads`

Public Ada-facing HTTP client.  Uses `LLM.HTTP.Curl_Binding` internally.

```ada
--  LLM.HTTP — streaming HTTP client backed by libcurl.
--
--  Post and Get both call On_Chunk for each received byte chunk as the
--  response streams in.  Callers typically feed these chunks to
--  LLM.SSE.Feed to parse Server-Sent Events.
--
--  CURLOPT_NOSIGNAL is always set to 1 so that libcurl does not install
--  SIGALRM handlers that would conflict with GNAT's task scheduler.
--
--  TLS is handled transparently by libcurl using the system CA bundle.
--  No SSL initialisation is required by the caller.
--
--  Project: coyote

package LLM.HTTP is

   --  Opaque list of HTTP request headers built with Add_Header.
   type Header_List is limited private;

   --  Append "Name: Value" to the list.
   procedure Add_Header
     (H     : in out Header_List;
      Name  :        String;
      Value :        String);

   --  POST Body to URL, streaming the response body to On_Chunk.
   --  Status receives the HTTP response code (200, 401, 429, …).
   --  Raises Curl_Error on transport or TLS failure.
   procedure Post
     (URL      :        String;
      Headers  :        Header_List;
      Body     :        String;
      On_Chunk :        not null access procedure (Data : String);
      Status   :    out Natural);

   --  GET URL, streaming the response body to On_Chunk.
   procedure Get
     (URL      :        String;
      Headers  :        Header_List;
      On_Chunk :        not null access procedure (Data : String);
      Status   :    out Natural);

   --  Raised when libcurl returns a non-CURLE_OK result code.
   Curl_Error : exception;

private

   type Header_Node;
   type Header_Node_Access is access Header_Node;
   type Header_Node is record
      Value : Ada.Strings.Unbounded.Unbounded_String;
      Next  : Header_Node_Access;
   end record;

   type Header_List is limited record
      Head : Header_Node_Access;
      Tail : Header_Node_Access;
   end record;

end LLM.HTTP;
```

### `src/llm/llm-http.adb`

Implement `Post`, `Get`, and `Add_Header`.  The `Write_Context` type here
must have the same memory layout as the one declared in
`llm-http-curl_binding.adb` (single `access procedure` field).

Key implementation points:
- Build a `curl_slist` from the `Header_List` linked list before the call;
  free it afterwards (in an exception handler so it is always freed).
- Pass `Ctx'Address` (where `Ctx.On_Chunk := On_Chunk`) to `Set_Write_Data`.
- Check `CURLE_OK` after `Easy_Perform`; raise `Curl_Error` with the
  `Strerror` message on failure.
- Always call `Easy_Cleanup` whether or not `Easy_Perform` succeeds.
- `Status` is set from `Get_Response_Code` after `Easy_Perform`.

Add `with Ada.Strings.Unbounded;` to the spec (needed by the private part).

### `src/llm/llm-settings.ads`

```ada
--  LLM.Settings — read pi agent configuration files.
--
--  Reads ~/.pi/agent/settings.json for defaults and optionally
--  ~/.pi/agent/models.json for per-provider API key overrides.
--
--  API key resolution order (first non-empty wins):
--    1. models.json  providers.<provider>.apiKey  (literal or ${VAR})
--    2. Environment variable for the provider (see Env_Var_For)
--
--  Project: coyote

package LLM.Settings is

   --  Load configuration.  Silent if files are absent.
   procedure Load;

   --  Default provider from settings.json (e.g. "github-copilot").
   function Default_Provider return String;

   --  Default model from settings.json (e.g. "claude-sonnet-4.6").
   function Default_Model return String;

   --  Default thinking level from settings.json (e.g. "high").
   function Default_Thinking_Level return String;

   --  Resolve an API key for Provider.
   --  Checks models.json overrides first, then the environment variable
   --  returned by Env_Var_For.  Returns "" if not configured.
   function Api_Key (Provider : String) return String;

   --  Return the conventional environment variable name for Provider.
   --  e.g. "openrouter" -> "OPENROUTER_API_KEY"
   --       "anthropic"  -> "ANTHROPIC_API_KEY"
   --       "github-copilot" -> "COPILOT_GITHUB_TOKEN"  (fallback: GH_TOKEN)
   --  Returns "" for unknown providers.
   function Env_Var_For (Provider : String) return String;

end LLM.Settings;
```

Implement in `llm-settings.adb` using `GNATCOLL.JSON`.  `Load` reads
`~/.pi/agent/settings.json` (must exist) and `~/.pi/agent/models.json`
(optional); silently ignores parse errors or absent files.
`${ENV_VAR}` substitution in `apiKey` values: detect the `${…}` pattern
and expand via `Ada.Environment_Variables.Value`.

## Test files to create

### `test/src/llm_http_tests.ads`

```ada
with AUnit;
with AUnit.Test_Fixtures;

package LLM_HTTP_Tests is
   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;
   procedure Test_Add_Header    (T : in out Test);
   procedure Test_Write_Callback (T : in out Test);
end LLM_HTTP_Tests;
```

### `test/src/llm_http_tests.adb`

Two tests:

1. **`Test_Add_Header`**: construct a `Header_List`, call `Add_Header` twice,
   then use `Post` against a locally-started HTTP server (spawn
   `python3 -m http.server 0 --bind 127.0.0.1` via
   `GNATCOLL.OS.Process.Start`; read its port from stdout; POST to it; assert
   `Status = 501` since python's simple server returns 501 for POST).
   If spawning the server fails, skip gracefully with `AUnit.Assert (True, …)`.

2. **`Test_Write_Callback`**: call `Ada_Write_Callback` directly with a
   known string, assert the `On_Chunk` callback received the exact bytes,
   and assert the return value equals `Size * NMemb`.  Import the exported
   C symbol:
   ```ada
   function Ada_Write_Callback
     (Buffer : System.Address; Size, NMemb : Interfaces.C.size_t;
      UserData : System.Address) return Interfaces.C.size_t
   with Import, Convention => C, External_Name => "ada_curl_write_cb";
   ```

### `test/src/llm_settings_tests.ads`

```ada
with AUnit;
with AUnit.Test_Fixtures;

package LLM_Settings_Tests is
   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;
   procedure Test_Env_Var_For     (T : in out Test);
   procedure Test_Api_Key_Env     (T : in out Test);
end LLM_Settings_Tests;
```

### `test/src/llm_settings_tests.adb`

1. **`Test_Env_Var_For`**: assert `Env_Var_For ("openrouter") = "OPENROUTER_API_KEY"`,
   `Env_Var_For ("anthropic") = "ANTHROPIC_API_KEY"`, and
   `Env_Var_For ("github-copilot") = "COPILOT_GITHUB_TOKEN"`.

2. **`Test_Api_Key_Env`**: set `OPENROUTER_API_KEY` to a known test value via
   `Ada.Environment_Variables.Set`, call `LLM.Settings.Load`, then assert
   `Api_Key ("openrouter") = <test value>`.  Restore the env var afterwards.

## Files to modify

### `test/src/test_suites.ads`

No change needed (it only exports `Suite`).

### `test/src/test_suites.adb`

Add `with LLM_HTTP_Tests;` and `with LLM_Settings_Tests;` to the context
clause.  Add `package LLM_HTTP_Caller is new AUnit.Test_Caller (LLM_HTTP_Tests.Test);`
and similarly for settings.  Register the test procedures in `Suite`.
Follow the existing pattern exactly.

## Acceptance criteria

```sh
# Main build must succeed
alr build

# Test suite must pass (new tests included)
cd test && alr run coyote_test
```

All existing tests continue to pass.  The two new test packages add at
least 4 passing tests.
