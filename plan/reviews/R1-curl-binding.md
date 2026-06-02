# R1: libcurl Binding Safety

## Verdict
FAIL

## Summary
The core binding is largely correct. The exported Ada write callback matches libcurl's `curl_write_callback` signature, the `Write_Context`/`On_Chunk` indirection is valid for the synchronous `curl_easy_perform` call, `CURLOPT_NOSIGNAL` is set on every request, all used `curl_easy_setopt`/`curl_easy_getinfo` wrapper return codes are checked, and both the easy handle and header list are cleaned up on normal and exceptional exits. An empty URL also fails cleanly rather than crashing: the code passes an empty C string, checks `Set_URL`, and then surfaces libcurl's perform-time URL error as `Curl_Error`. However, the implementation never performs the required one-time `curl_global_init` before calling `curl_easy_init`. Per `curl.h`, that initialization must happen exactly once before any other libcurl call. Relying on implicit lazy initialization leaves a process-wide thread-safety hole if multiple Ada tasks reach libcurl before global initialization completes.

## Issues

### [MEDIUM] Required `curl_global_init` is missing
**Files:** src/llm/llm-http.adb:91-159, src/llm/llm-http-curl_binding.ads:32-89, /usr/include/x86_64-linux-gnu/curl/curl.h:2682-2693
**Description:** `LLM.HTTP` calls `curl_easy_init` directly for each request, but the binding exposes no `curl_global_init` wrapper and the package never performs libcurl's required one-time process initialization. libcurl's own header says `curl_global_init()` should be invoked exactly once before any other libcurl functions. Without that, the first request depends on libcurl's implicit lazy initialization path instead of an explicit, synchronized one-time init. In a tasking Ada program this is a real safety concern: two tasks can race on first use, and the code is no longer following libcurl's documented initialization contract.
**Evidence:**
```ada
function Easy_Init return Handle with
  Import, Convention => C, External_Name => "curl_easy_init";
...
procedure Perform_Request
  (URL     :     String; Headers : Header_List; Use_Post : Boolean;
   Payload : String; On_Chunk : not null access procedure (Data : String);
   Status  : out Natural)
is
   H : Curl_Binding.Handle := Curl_Binding.Easy_Init;
```

```c
/* NAME curl_global_init()
 *
 * DESCRIPTION
 *
 * curl_global_init() should be invoked exactly once for each application that
 * uses libcurl and before any call of other libcurl functions.
 */
CURL_EXTERN CURLcode curl_global_init(long flags);
```
**Fix:** Add `curl_global_init` (and optionally `curl_global_cleanup`) to `LLM.HTTP.Curl_Binding`, and call `curl_global_init (CURL_GLOBAL_DEFAULT)` exactly once before any `Easy_Init`. The safest pattern here is a protected one-time initializer or package-level elaboration routine that serializes first use across tasks.

## Confirmed Correct
- The exported callback profile matches `curl_write_callback` from `curl.h`:
  `size_t (*)(char *buffer, size_t size, size_t nitems, void *outstream)` maps to `System.Address, Size_T, Size_T, System.Address -> Size_T`, and `Ada_Write_Callback` is declared with both `Convention => C` and `Export`.
- `thin_curl.c` uses the correct libcurl wrapper signatures for `CURLOPT_URL`, `CURLOPT_POST`, `CURLOPT_POSTFIELDS`, `CURLOPT_POSTFIELDSIZE`, `CURLOPT_HTTPHEADER`, `CURLOPT_WRITEFUNCTION`, `CURLOPT_WRITEDATA`, `CURLOPT_NOSIGNAL`, and `CURLINFO_RESPONSE_CODE`.
- `Write_Context` contains only `On_Chunk_Address : System.Address`, and `Perform_Request` stores `On_Chunk'Address` into a stack-allocated `Ctx` record before passing `Ctx'Address` as `CURLOPT_WRITEDATA`.
- The callback-side overlays are internally consistent:
  `Ctx` is overlaid on `User_Data`, `Handler` is overlaid on `Ctx.On_Chunk_Address`, and `Handler.all (Data)` is a valid call as long as `Perform_Request` is still active.
- That lifetime requirement is satisfied here because `curl_easy_perform` is synchronous/blocking; the caller's `Perform_Request` stack frame, its `On_Chunk` parameter object, and the local `Ctx` object all remain live for the entire duration of the callback sequence.
- `CURLOPT_NOSIGNAL` is set before `curl_easy_perform`, and both `Post` and `Get` flow through the same `Perform_Request` path, so the setting is applied uniformly.
- Every used `curl_easy_setopt`/`curl_easy_getinfo` wrapper result is checked through `Check`; failures from `Set_URL`, `Set_Write_Function`, `Set_Write_Data`, `Set_Post`, `Set_Post_Fields`, `Set_Post_Size`, `Set_Http_Header`, `Set_No_Signal`, `Easy_Perform`, and `Get_Response_Code` are not silently ignored.
- Easy-handle cleanup is correct on all exit paths. `Cleanup` is called both after the normal `Easy_Perform`/`Get_Response_Code` path and again in the `exception` handler, so a callback-induced transfer failure still releases the handle.
- Header-list cleanup is also correct on all exit paths. `Build_Slist` frees any partial list on append failure, and `Cleanup` calls `curl_slist_free_all` whenever a request-owned slist exists.
- If `On_Chunk` raises an exception, `Ada_Write_Callback` catches it and returns `0`; that causes `curl_easy_perform` to fail, after which `Perform_Request` raises `Curl_Error` and runs `Cleanup`.
- `URL = ""` is safe. The code passes an empty C string, not a null pointer, so there is no null-URL crash path; libcurl reports the bad URL as an error and the Ada code surfaces it via `Check`.
- No libcurl easy handle is shared across tasks or reused after cleanup. Each request creates a fresh local `H` in `Perform_Request`, passes it only within that subprogram, and nulls it after `Easy_Cleanup`.
