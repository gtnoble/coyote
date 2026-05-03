# Python → Ada Migration: Sequential Subagent Tasks

Each task is self-contained: read the listed files, make the listed changes,
verify with `cd test && alr run coyote_test`, then commit.  Every task must
leave the test suite fully green before the next task begins.

Before reading any Ada source, load the Ada style guide skill:
`/home/gtnoble/.pi/agent/skills/ada-style-guide/SKILL.md`

---

## Task 1 — Create `Test_HTTP_Server` package

**Goal:** Build the shared Ada HTTP/1.1 mock-server infrastructure that all
subsequent tasks will use.  No existing files change.

**Read first:**
- `test/coyote_test.gpr` — understand the source layout
- `test/src/llm_http_tests.adb` lines 1–82 — typical consumer: builds a
  Python script string, calls `Spawn_Server(Script)`, later calls `Stop_Server`
- `test/src/nine_p_mock_server_tests.adb` lines 1–20 — confirms
  `GNAT.Sockets` is already in scope in the test suite

**Create:**
- `test/src/test_http_server.ads`
- `test/src/test_http_server.adb`

**Spec (`test_http_server.ads`) must provide:**

A `Request` record with:
- `Method  : Ada.Strings.Unbounded.Unbounded_String`
- `Path    : Ada.Strings.Unbounded.Unbounded_String`
- `Headers : …` — a searchable key/value collection (case-insensitive lookup
  by header name); a simple `Ada.Containers.Vectors` of `(Name, Value)` pairs
  with a `Get_Header (Req, Name)` helper function returning `String` is fine
- `Body    : Ada.Strings.Unbounded.Unbounded_String`

A `Response` record with:
- `Status  : Natural := 200`
- `Headers : …` — same key/value collection type as above
- `Body    : Ada.Strings.Unbounded.Unbounded_String`

A handler type:
```ada
type Request_Handler is access procedure
  (Req :     Request;
   Res : out Response);
```

A `Server` task type (not a singleton) with:
- discriminant `Handler : not null Request_Handler` — passed at elaboration
- entry `Bind (Port : Positive)` — binds the listening socket; completes once
  the socket is bound and listening (so the caller knows it is safe to connect)
- entry `Stop` — signals the accept loop to exit after the current request (if
  any) finishes
- The task loops: accept one connection → parse HTTP/1.1 request → call
  `Handler` → write HTTP/1.1 response → close connection → repeat until `Stop`
  has been called or a socket error occurs

**HTTP/1.1 parsing requirements (minimal — covers all current test cases):**
- Read request line: `METHOD /path HTTP/1.1\r\n`
- Read headers until blank line (`\r\n\r\n`)
- If a `Content-Length` header is present, read exactly that many bytes as the
  body; otherwise body is empty
- Write response as:
  `HTTP/1.1 <status> <reason>\r\nContent-Length: <n>\r\n<extra headers>\r\n<body>`

**Use `GNAT.Sockets`** with `SO_REUSEADDR` on the listening socket.  Set a
reasonable receive timeout (e.g. 5 s) on accepted connections so a misbehaving
test client does not hang the server task forever.

**`coyote_test.gpr` does not need to change** — `for Source_Dirs use ("src/",
"config/");` already picks up any new file in `test/src/`.

**Verify:** `cd test && alr build` compiles cleanly (no test run needed yet
since no test uses this package yet).

**Commit:** `Add Test_HTTP_Server package for Ada mock HTTP servers`

---

## Task 2 — Migrate `llm_http_tests.adb`

**Goal:** Replace the three embedded Python HTTP server scripts with Ada
`Test_HTTP_Server` handler procedures.  This is the first consumer of Task 1's
infrastructure and validates it end-to-end.

**Read first:**
- `test/src/test_http_server.ads` (from Task 1)
- `test/src/llm_http_tests.adb` in full (246 lines)

**What the file currently does (Python side):**
- `Post_Server_Script` — serves one `POST /` → HTTP 201, body `"hello chunk"`
  (sent as two writes: `b'hello '` then `b'chunk'`)
- `Get_Server_Script` — serves one `GET /` → HTTP 200, body `"hello get"`
- `Error_Post_Server_Script` — serves one `POST /` → HTTP 400,
  body `"bad request"`
- `Spawn_Server (Script)` — `python3 -u -c <Script>`
- `Post_With_Retry` / `Get_With_Retry` — retry loop around `LLM.HTTP.Post/Get`

**Changes to `llm_http_tests.adb`:**
- Remove `with GNATCOLL.OS.Process` and its `use` clause
- Remove `Post_Server_Script`, `Get_Server_Script`, `Error_Post_Server_Script`,
  and `Spawn_Server` functions entirely
- Add `with Test_HTTP_Server`
- In each test procedure, replace:
  ```ada
  Handle := Spawn_Server (Post_Server_Script (Port));
  ```
  with a local `Server : Test_HTTP_Server.Server (Handler => …'Access)` task
  declaration followed by `Server.Bind (Port)`.
  Replace the `Wait (Handle)` cleanup with `Server.Stop`.
- The handler procedures (one per former script) become named local procedures
  of the appropriate `Request_Handler` signature.
- The note about Python sending `b'hello '` then `b'chunk'` as two separate
  writes: libcurl may see them in one or two chunks depending on buffering.
  The existing test assertions check the concatenated response body, so the Ada
  handler can simply set `Res.Body` to `"hello chunk"` and send it in one write
  — this matches what the assertions actually check.
- Keep `Post_With_Retry` and `Get_With_Retry` unchanged.

**Verify:** `cd test && alr run coyote_test` — all existing tests pass.

**Commit:** `Migrate llm_http_tests to Ada Test_HTTP_Server`

---

## Task 3 — Migrate `llm_auth_tests.adb`, `llm_catalogue_tests.adb`,
           `llm_openrouter_catalogue_tests.adb`

**Goal:** Replace one Python server script in each of these three files.  They
all follow the same pattern as Task 2.

**Read first:**
- `test/src/test_http_server.ads` (Task 1)
- `test/src/llm_auth_tests.adb` in full (651 lines) — look for
  `Refresh_Server_Script` and `Spawn_Server`
- `test/src/llm_catalogue_tests.adb` in full (463 lines) — look for
  `Live_Server_Script` and `Spawn_Server`
- `test/src/llm_openrouter_catalogue_tests.adb` in full (442 lines) — look for
  `Live_Server_Script` and `Spawn_Server`

**Per-file changes (apply the same pattern as Task 2 to each):**

*`llm_auth_tests.adb`:*
- `Refresh_Server_Script` serves one `GET /copilot_internal/v2/token` with
  specific header assertions and returns a JSON token body.
- Replace with an Ada handler procedure; the header assertions become
  `Assert` calls inside the handler using `Test_HTTP_Server.Get_Header`.

*`llm_catalogue_tests.adb`:*
- `Live_Server_Script` serves one `GET /models`, asserts Copilot-specific
  headers, returns the contents of a fixture file as the body.
  The Ada handler reads the file with `Ada.Text_IO` (or
  `Ada.Directories`/streams) and sets `Res.Body`.

*`llm_openrouter_catalogue_tests.adb`:*
- `Live_Server_Script` serves one `GET /api/v1/models`, no header assertions
  beyond Content-Type, returns a fixture file body.

In all three files: remove `with GNATCOLL.OS.Process`, its `use` clause, the
`Spawn_Server` function, the `Stop_Server` procedure, and the Python script
function.  Add `with Test_HTTP_Server`.

**Verify:** `cd test && alr run coyote_test` — all tests pass.

**Commit:** `Migrate auth and catalogue tests to Ada Test_HTTP_Server`

---

## Task 4 — Migrate `llm_anthropic_messages_tests.adb`

**Goal:** Replace 5 Python server scripts in the Anthropic provider test file.

**Read first:**
- `test/src/test_http_server.ads` (Task 1)
- `test/src/llm_anthropic_messages_tests.adb` in full (1162 lines)
  Identify these 5 functions: `Anthropic_Server_Script`,
  `Tool_Use_Server_Script`, `Stop_Reason_Server_Script`,
  `HTTP_Error_Server_Script`, `Early_Close_Server_Script`

**Key details per script:**
- `Anthropic_Server_Script` — serves one POST, writes the request body to a
  capture file (`capture_path` parameter), returns a fixed Anthropic SSE
  response.  The Ada handler writes the capture with `Ada.Text_IO`.
- `Tool_Use_Server_Script` — serves one POST, returns an SSE stream with
  tool-use content blocks.
- `Stop_Reason_Server_Script` — serves one POST, returns an SSE stream with a
  configurable stop reason (the script takes `Stop_Reason` as a parameter).
- `HTTP_Error_Server_Script` — serves one POST → HTTP 500 with a JSON error
  body.
- `Early_Close_Server_Script` — serves one POST, writes partial SSE data, then
  closes the connection without completing the response.  The Ada handler sets
  `Res.Body` to the truncated payload; the HTTP/1.1 framing will close the
  connection after sending it.

**Remove:** `Spawn_Server`, `Stop_Server`, `Wait_For_Server`, the
`GNATCOLL.OS.Process` dependency, the `C_Kill` import.
**Add:** `with Test_HTTP_Server`.

**Verify:** `cd test && alr run coyote_test` — all tests pass.

**Commit:** `Migrate llm_anthropic_messages_tests to Ada Test_HTTP_Server`

---

## Task 5 — Migrate `llm_openai_completions_tests.adb`

**Goal:** Replace 9 Python server scripts in the OpenAI completions test file.

**Read first:**
- `test/src/test_http_server.ads` (Task 1)
- `test/src/llm_openai_completions_tests.adb` in full (1287 lines)
  Identify: `Text_Server_Script`, `Tool_Server_Script`,
  `Multi_Tool_Server_Script`, `Thinking_Server_Script`,
  `Compaction_Summary_Server_Script`, `Non_Streaming_Server_Script`,
  `Non_Streaming_Tool_Server_Script`, `HTTP_Error_Server_Script`,
  `Early_Close_Server_Script`

**Key patterns:**
- Most scripts serve one POST → HTTP 200 with an SSE (`text/event-stream`)
  body consisting of pre-built JSON event lines.
- `Compaction_Summary_Server_Script` serves one POST → HTTP 200 with a
  non-streaming JSON response (the summary for compaction).
- `Non_Streaming_Server_Script` / `Non_Streaming_Tool_Server_Script` — also
  non-streaming JSON responses.
- `HTTP_Error_Server_Script` — HTTP 500 response.
- `Early_Close_Server_Script` — truncated response (same technique as Task 4).
- Several scripts assert request body fields (model name, message content,
  tool call IDs, etc.) using `json.loads`.  In Ada, parse the request body
  with `GNATCOLL.JSON.Read` and use `Assert` inside the handler.

**Remove:** `Spawn_Server`, `Stop_Server`, the `GNATCOLL.OS.Process`
dependency, `C_Kill`.  Add `with Test_HTTP_Server`, `with GNATCOLL.JSON`.

**Verify:** `cd test && alr run coyote_test` — all tests pass.

**Commit:** `Migrate llm_openai_completions_tests to Ada Test_HTTP_Server`

---

## Task 6 — Migrate `llm_openrouter_tests.adb`

**Goal:** Replace 4 Python server scripts in the OpenRouter provider test file,
including one multi-endpoint server.

**Read first:**
- `test/src/test_http_server.ads` (Task 1)
- `test/src/llm_openrouter_tests.adb` in full (914 lines)
  Identify: `Header_Server_Script`, `Reasoning_Server_Script`,
  `Live_Fetch_Then_Send_Server_Script`, `Capture_Authorization_Server_Script`

**Key details:**
- `Header_Server_Script` — one POST → SSE; asserts Authorization, HTTP-Referer,
  X-Title headers and request body fields.
- `Reasoning_Server_Script` — one POST → SSE; asserts reasoning-related fields.
- `Capture_Authorization_Server_Script` — one POST, writes capture file.
- `Live_Fetch_Then_Send_Server_Script` — the most complex: serves **both**
  `GET /api/v1/models` and `POST /api/v1/chat/completions` on the same port,
  looping until both have been called at least once, writing state to a capture
  file.  In Ada: the handler switches on `Req.Method` and `Req.Path`.  Use a
  protected `State` object (or simple flags guarded by a mutex) to track which
  endpoints have been called; the server loops via its internal accept loop
  until both flags are set, then the handler calls `Server.Stop` (or the server
  exits naturally after the second unique endpoint).  The simplest approach: let
  the server serve up to 10 requests; after each, check a shared atomic flag;
  the test waits for the server to exit and then reads the capture file.

**Remove:** `Spawn_Server`, `Stop_Server`, `GNATCOLL.OS.Process`, `C_Kill`.
**Add:** `with Test_HTTP_Server`.

**Verify:** `cd test && alr run coyote_test` — all tests pass.

**Commit:** `Migrate llm_openrouter_tests to Ada Test_HTTP_Server`

---

## Task 7 — Migrate `llm_github_copilot_tests.adb`

**Goal:** Replace 3 Python server scripts in the GitHub Copilot provider test
file.

**Read first:**
- `test/src/test_http_server.ads` (Task 1)
- `test/src/llm_github_copilot_tests.adb` in full (913 lines)
  Identify: `Anthropic_Server_Script`, `OpenAI_Server_Script`,
  `Refresh_Then_Send_Server_Script`

**Key details:**
- `Anthropic_Server_Script` — serves one POST → Anthropic-format SSE response;
  writes capture file.
- `OpenAI_Server_Script` — serves one POST → OpenAI-format SSE response; writes
  capture file.
- `Refresh_Then_Send_Server_Script` — serves two requests: first a
  `GET /copilot_internal/v2/token` (token refresh), then a `POST` (chat
  completion).  In Ada: a two-request server; the handler distinguishes the
  requests by method (first GET, second POST).

**Remove:** `Spawn_Server`, `Stop_Server`, `GNATCOLL.OS.Process`, `C_Kill`.
**Add:** `with Test_HTTP_Server`.

**Verify:** `cd test && alr run coyote_test` — all tests pass.

**Commit:** `Migrate llm_github_copilot_tests to Ada Test_HTTP_Server`

---

## Task 8 — Migrate `llm_agent_tests.adb` (first half: scripts 1–9)

**Goal:** Replace the first 9 Python server scripts in the agent test file
(the largest file at 4671 lines with 18 scripts total).

**Read first:**
- `test/src/test_http_server.ads` (Task 1)
- `test/src/llm_agent_tests.adb` — read the full file to understand its
  structure, then focus on these 9 scripts (in order of appearance):
  1. `Simple_Text_Server_Script` (line ~284) — accept-until-handled loop,
     1 effective request
  2. `Multi_Turn_Server_Script` (line ~365) — 2 requests
  3. `Unknown_Tool_Server_Script` (line ~450) — 2 requests
  4. `Retry_Then_Success_Server_Script` (line ~549) — 2 requests (first
     returns error, second returns success)
  5. `Single_Error_Server_Script` (line ~631) — 1 request → HTTP 400
  6. `Overflow_Then_Compact_Then_Success_Server_Script` (line ~665) — 3
     requests (req 1: HTTP 400 context-length error; req 2: HTTP 200 success;
     req 3: HTTP 200 success)
  7. `Overflow_Then_Compact_Then_Overflow_Server_Script` (line ~749) — 3
     requests (req 1: 400; req 2: 200 summary; req 3: 400)
  8. `Compaction_Server_Script` (line ~904) — accept-until-handled loop, 1
     effective request
  9. `Single_Turn_Server_Script` (line ~968) — 1 request

**Key patterns:**
- Scripts that use `while not H.handled … s.handle_request()` (accept-until
  done): In Ada, the server loops accepting connections; a boolean flag in the
  handler closure is set when the first real request arrives; after setting it,
  the handler calls `Server.Stop` so the task exits.
- Multi-request scripts with per-call-count logic: the handler maintains a
  call counter (access to an integer, or a protected integer) and switches
  behaviour based on it.
- All scripts assert request body fields with `json.loads`; use
  `GNATCOLL.JSON.Read` in the Ada handlers.

Do **not** remove `Spawn_Server` yet — scripts 10–18 (Task 9) still need it.
After replacing scripts 1–9, the `Spawn_Server` function is still called for
the remaining scripts.

**Verify:** `cd test && alr run coyote_test` — all tests pass.

**Commit:** `Migrate llm_agent_tests scripts 1–9 to Ada Test_HTTP_Server`

---

## Task 9 — Migrate `llm_agent_tests.adb` (second half: scripts 10–18)

**Goal:** Replace the remaining 9 Python server scripts in the agent test file
and remove all Python/process infrastructure from it.

**Read first:**
- `test/src/test_http_server.ads` (Task 1)
- `test/src/llm_agent_tests.adb` — focus on these scripts (in order):
  10. `Tool_Call_Server_Script` (line ~1027) — 2 requests (tool call then
      follow-up with tool result)
  11. `Two_Tool_Call_Server_Script` (line ~1105) — 1 request → parallel tool
      calls
  12. `Two_Tool_Loop_Server_Script` (line ~1170) — 2 requests
  13. `Tool_Failure_Server_Script` (line ~1260) — 2 requests (second includes
      tool error result)
  14. `Capture_Request_Server_Script` (line ~1337) — 1 request; writes capture
      file
  15. `Prompt_Then_Compaction_Server_Script` (line ~1391) — accept-until-2-
      requests loop (compaction triggered during second request)
  16. `Delayed_Tool_Call_Server_Script` (line ~1461) — 2 requests; second
      handler calls `delay 1.0` before responding (mirrors `time.sleep(1.0)`)
  17. `Delayed_Server_Script` (line ~1540) — 2 requests with a delay
  18. `Resume_Server_Script` (line ~1583) — 1 request

After replacing all 18 scripts:
- Remove `Spawn_Server`, `Stop_Server`, `Wait_For_Server` procedures
- Remove `with GNATCOLL.OS.Process` and `C_Kill` import
- Add `with Test_HTTP_Server`

**Verify:** `cd test && alr run coyote_test` — all tests pass.

**Commit:** `Migrate llm_agent_tests scripts 10–18 to Ada Test_HTTP_Server`

---

## Task 10 — Create `mock_coyote` Ada binary; migrate `llm_tools_tests.adb`

**Goal:** Replace the `mock_coyote.py` script (written to disk at test time)
with a compiled Ada binary.

**Read first:**
- `test/src/llm_tools_tests.adb` lines 340–461 — the full `mock_coyote.py`
  script content and the test that uses it
- `test/coyote_test.gpr` — understand how to add a second executable
- `src/coyote.adb` — reference for Ada CLI arg-parsing style

**What `mock_coyote.py` does:**
1. Parses `--prompt VAL`, `--model VAL`, `--agent VAL`, `--name VAL`,
   `--one-shot`, `--no-session` from `sys.argv`
2. If `--one-shot` or `--no-session` is missing, prints
   `{"error": "missing required flags"}` and exits 1
3. Prints `noise before json` (literal, to test that the caller skips
   non-JSON lines)
4. Prints `{"session_id": "123", "output": "<prompt>|<model>|<agent>|<name>"}`

**Create `test/tools/mock_coyote.adb`:**
- Implement the same logic in Ada using `Ada.Command_Line` and
  `Ada.Text_IO.Put_Line`
- Identical stdout output to the Python script

**Update `test/coyote_test.gpr`:**
- Add `"tools/"` to `for Source_Dirs`
- Change `for Main use ("coyote_test.adb")` to
  `for Main use ("coyote_test.adb", "mock_coyote.adb")`
- The binary will be built to `test/bin/mock_coyote`

**Update `test/src/llm_tools_tests.adb`:**
- Remove the `Script_Content` string literal, `Write_Text (Script_Path, …)`,
  `Make_Executable (Script_Path)`, `Delete_If_Exists (mock_coyote.py)` calls
- Replace `Ada.Environment_Variables.Set (Env_Name, Script_Path)` with
  `Ada.Environment_Variables.Set (Env_Name, Test_Root & "/../bin/mock_coyote")`
  (adjust relative path as needed to point at the built binary)
- Remove the `Script_Path` constant

**Verify:** `cd test && alr run coyote_test` — all tests pass, including
`Test_Spawn_Subagent_Success`.

**Commit:** `Replace mock_coyote.py with Ada binary`

---

## Task 11 — Create `Nine_P_Mock_Server` package;
            migrate `nine_p_mock_server_tests.adb`

**Goal:** Replace the large embedded Python 9P protocol server with a native
Ada task that uses the existing `Nine_P.Proto` production package for
message encoding/decoding.

**Read first:**
- `test/src/nine_p_mock_server_tests.adb` in full (818 lines) — understand
  all scenarios and the JSON result file format
- `src/nine_p-proto.ads` and `src/nine_p-proto.adb` — the existing 9P message
  codec that can be reused on the server side
- `src/nine_p.ads` — `Byte_Array`, `Byte_Vectors`, constants
- `test/src/test_http_server.ads` — reference for the Ada task server pattern
  established in Task 1

**What the Python server does:**
- Listens on TCP, accepts one connection
- Decodes raw 9P2000 messages from the wire using `struct.unpack`
- Records each decoded message in an `events` list
- Runs a scenario-driven flow (switch on `scenario` arg):
  - `read_once` — version + attach + walk + open + one read → data → drain
  - `read_aggregate` — version + attach + walk + open + three reads → drain
  - `write_split` — version + attach + walk + open → drain (allows writes)
  - `read_error` — version + attach + walk + open + read → Rerror → drain
  - `walk_failure` — version + attach + walk → Rerror → drain
  - `rversion_fail` — version → Rversion "unknown" (no attach)
  - `finalize_clunk` — version + attach + walk + open → drain (allows clunks)
- Writes a JSON result file: `{"events": […], "error": "…", "traceback": "…"}`

**Create `test/src/nine_p_mock_server.ads` and `.adb`:**

Instead of a JSON result file, use an in-memory protected type:

```ada
type Event_Record is record
   Msg_Type : Ada.Strings.Unbounded.Unbounded_String;
   Tag      : Interfaces.Unsigned_16;
end record;

type Scenario_Kind is
  (Read_Once, Read_Aggregate, Write_Split, Read_Error,
   Walk_Failure, Rversion_Fail, Finalize_Clunk);

protected type Server_Result is
   procedure Append_Event (E : Event_Record);
   procedure Set_Error (Msg : String);
   function Events return Event_Vectors.Vector;
   function Error return String;
end Server_Result;

task type Mock_Server is
   entry Start (Scenario : Scenario_Kind; Port : Positive;
                Result   : not null access Server_Result);
end Mock_Server;
```

The task body uses `GNAT.Sockets` (already imported in the test file), accepts
one connection, then runs the scenario logic.  Use `Nine_P.Proto` to:
- **Decode** incoming messages: read the 4-byte size prefix, read the rest,
  call the appropriate `Nine_P.Proto` decode function to get the message type
  and fields
- **Encode** responses: call `Nine_P.Proto` encode functions to build Rversion,
  Rattach, Rwalk, Ropen, Rread, Rwrite, Rclunk, Rerror bytes, then send them

The `drain` loop (accept Tclunk/Twrite until EOF or timeout) becomes a simple
Ada loop with a socket timeout.

**Update `test/src/nine_p_mock_server_tests.adb`:**
- Remove the `Mock_Server_Script` function (the entire embedded Python string)
- Remove `Spawn_Server`, `Wait_For_Server`, `Stop_Server` (the process-based
  versions)
- Remove `Read_File`, `Delete_If_Exists` (only needed for the JSON log file)
- Remove `GNATCOLL.JSON` import (no longer parsing a JSON log file)
- Replace each `Spawn_Server (Scenario, Port, Log_Path)` call with a
  `Mock_Server` task declaration and `Server.Start (Scenario, Port, Result)`
- Replace the log-file parse + JSON field access with direct access to
  `Result.Events` and `Result.Error`
- Keep `Dial_With_Retry` and all `Test_*` procedures unchanged except for the
  server startup/result-reading lines

**Verify:** `cd test && alr run coyote_test` — all tests pass.

**Commit:** `Replace Python 9P mock server with native Ada implementation`
