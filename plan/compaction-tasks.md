# Context Compaction — Subagent Task Breakdown

> **Status: SUPERSEDED.** This historical task breakdown predates the
> 2026-08-30 baseline. Its old project paths and legacy frontend references
> are retained for traceability only and must not be executed.

## Dependency graph

```
Task A ──┐
         ├──► Task C ──► Task D ──┬──► Task E
Task B ──┘                        ├──► Task F ──► Task G
```

Tasks A and B can run in **parallel**.
Task C starts once A and B are merged.
Task D starts once C is merged.
Tasks E and F can run in **parallel** once D is merged.
Task G starts once F is merged.

---

## Task A — New package `LLM.Compaction` (pure logic)

**Files to create:**
- `src/llm/llm-compaction.ads`
- `src/llm/llm-compaction.adb`
- `test/src/llm_compaction_tests.ads`
- `test/src/llm_compaction_tests.adb`

**Files to register the new tests (add entries to both):**
- `test/src/test_suites.ads` — add `with LLM_Compaction_Tests;`
- `test/src/test_suites.adb` — add a `LLM_Compaction_Caller` block and register all test cases

**No changes to existing source packages.**

### What to implement

`LLM.Compaction` is a **pure, stateless** package — no I/O, no task interactions,
no dependencies on any other new compaction code.

Read `src/llm/llm-types.ads` and `src/llm/llm-session_store.ads` for
the existing types before writing the spec.

The package must expose:

```ada
--  Compaction settings.
type Compact_Settings is record
   Enabled           : Boolean := True;
   Reserve_Tokens    : Positive := 16_384;
   Keep_Recent_Tokens : Positive := 20_000;
end record;

Default_Compact_Settings : constant Compact_Settings;

--  Estimate token count for one message (chars / 4, conservative).
--  Counts text, thinking, tool-call argument, and tool-result content.
function Estimate_Tokens
  (Msg : LLM.Types.Message) return Natural;

--  Estimate total context tokens for a history vector.
--  Uses the last assistant message's actual usage when present
--  (Input + Output + Cache_Read + Cache_Write); falls back to summing
--  Estimate_Tokens over all messages.
function Estimate_Context_Tokens
  (History : LLM.Types.Message_Vectors.Vector) return Natural;

--  True when compaction should be triggered.
function Should_Compact
  (Context_Tokens : Natural;
   Context_Window : Natural;
   Settings       : Compact_Settings) return Boolean;

--  Find the 0-based index of the first message to KEEP after compaction.
--  Walks backwards from the newest message, accumulating estimated tokens,
--  until >= Settings.Keep_Recent_Tokens are accumulated.
--  Always cuts at a user-role message boundary (never mid-turn).
--  Returns 0 if the whole history fits or cannot be cut further.
function Find_Cut_Point
  (History  : LLM.Types.Message_Vectors.Vector;
   Settings : Compact_Settings) return Natural;

--  Serialise messages to a plain labelled text block for summarisation.
--  Format per message:
--    [User]: <text content>
--    [Assistant]: <text content>
--    [Assistant thinking]: <thinking content>
--    [Assistant tool calls]: name(k=v, ...); ...
--    [Tool result]: <text content, truncated to 2 000 chars>
--  Messages are separated by a blank line.
--  The Compaction_Summary role (if present) is formatted as [Summary]: ...
function Serialize_Conversation
  (Messages : LLM.Types.Message_Vectors.Vector) return String;

--  Scan assistant messages in History for toolCall blocks named
--  "read", "write", or "edit", and extract their "path" argument.
--  Read-only files (read but not written/edited) go into Read_Files.
--  Written or edited files go into Modified_Files.
--  Both vectors are cleared before filling.
procedure Track_File_Ops
  (History        :     LLM.Types.Message_Vectors.Vector;
   Read_Files     : out Ada.Strings.Unbounded.Unbounded_String;
   Modified_Files : out Ada.Strings.Unbounded.Unbounded_String);
```

`Read_Files` and `Modified_Files` are newline-separated path lists
(empty string when nothing was found). If a path appears in both
"read" and "write/edit", it goes into `Modified_Files` only.

`Track_File_Ops` scans `Tool_Call_Block` entries (in assistant messages)
whose `Tool_Name` is `"read"`, `"write"`, or `"edit"`, and parses the
`Arguments_Json` for a `"path"` string field. Use `GNATCOLL.JSON` to
parse the JSON string — see how `llm-session_store.adb` uses it.

The summarisation prompts (verbatim string constants):

```ada
Summarization_System_Prompt : constant String :=
  "You are a context summarization assistant. Your task is to read a"
  & " conversation between a user and an AI coding assistant, then"
  & " produce a structured summary following the exact format"
  & " specified."
  & ASCII.LF & ASCII.LF
  & "Do NOT continue the conversation. Do NOT respond to any"
  & " questions in the conversation. ONLY output the structured"
  & " summary.";

Summarization_Prompt : constant String := ...;   --  see below
Update_Summarization_Prompt : constant String := ...; --  see below
```

**`Summarization_Prompt`** (use verbatim):
```
The messages above are a conversation to summarize. Create a structured context checkpoint summary that another LLM will use to continue the work.

Use this EXACT format:

## Goal
[What is the user trying to accomplish? Can be multiple items if the session covers different tasks.]

## Constraints & Preferences
- [Any constraints, preferences, or requirements mentioned by user]
- [Or "(none)" if none were mentioned]

## Progress
### Done
- [x] [Completed tasks/changes]

### In Progress
- [ ] [Current work]

### Blocked
- [Issues preventing progress, if any]

## Key Decisions
- **[Decision]**: [Brief rationale]

## Next Steps
1. [Ordered list of what should happen next]

## Critical Context
- [Any data, examples, or references needed to continue]
- [Or "(none)" if not applicable]

Keep each section concise. Preserve exact file paths, function names, and error messages.
```

**`Update_Summarization_Prompt`** (use verbatim):
```
The messages above are NEW conversation messages to incorporate into the existing summary provided in <previous-summary> tags.

Update the existing structured summary with new information. RULES:
- PRESERVE all existing information from the previous summary
- ADD new progress, decisions, and context from the new messages
- UPDATE the Progress section: move items from "In Progress" to "Done" when completed
- UPDATE "Next Steps" based on what was accomplished
- PRESERVE exact file paths, function names, and error messages
- If something is no longer relevant, you may remove it

Use this EXACT format:

## Goal
[Preserve existing goals, add new ones if the task expanded]

## Constraints & Preferences
- [Preserve existing, add new ones discovered]

## Progress
### Done
- [x] [Include previously done items AND newly completed items]

### In Progress
- [ ] [Current work - update based on progress]

### Blocked
- [Current blockers - remove if resolved]

## Key Decisions
- **[Decision]**: [Brief rationale] (preserve all previous, add new)

## Next Steps
1. [Update based on current state]

## Critical Context
- [Preserve important context, add new if needed]

Keep each section concise. Preserve exact file paths, function names, and error messages.
```

### Tests

Write a thorough AUnit test fixture covering at minimum:

- `Estimate_Tokens`: user message with known text returns `ceil(len/4)`;
  assistant with text + thinking + tool call; tool-result truncation has no
  effect on estimation
- `Estimate_Context_Tokens`: empty vector returns 0; vector with one assistant
  message uses its usage fields when non-zero; vector without usage falls back
  to sum of estimates
- `Should_Compact`: returns False when disabled; returns False when tokens fit
  with reserve; returns True at the threshold
- `Find_Cut_Point`: returns 0 for a small history; cuts at a user-message
  boundary; does not cut inside a tool-call/tool-result pair; respects
  `Keep_Recent_Tokens`
- `Serialize_Conversation`: user text appears with `[User]:` prefix; assistant
  text with `[Assistant]:`; tool results truncated at 2 000 chars; blank line
  between messages
- `Track_File_Ops`: read-only paths go to `Read_Files`; written paths go to
  `Modified_Files`; path in both read and write goes only to `Modified_Files`

Register all tests in `test_suites.ads/.adb` using the `LLM_Compaction_Caller`
instantiation pattern already used for other LLM packages (see
`LLM_Types_Caller` as the nearest example).

### Verify

```sh
cd /home/gtnoble/Projects/pi_acme_dev && alr build 2>&1 | tail -5
cd test && alr run coyote_test 2>&1 | grep -E "PASS|FAIL|ERROR|compaction"
```

All new tests must pass; no existing tests may regress.

---

## Task B — `LLM.Types`: `Compaction_Summary` role + provider wire encoding

**Files to modify:**
- `src/llm/llm-types.ads`
- `src/llm/llm-session_store.adb`
- `src/llm/llm-providers-openai_completions.adb`
- `src/llm/llm-providers-anthropic_messages.adb`
- `test/src/llm_types_tests.ads` + `llm_types_tests.adb`
- `test/src/test_suites.adb` (add new test cases)

**No new packages.**

### What to implement

#### 1. `llm-types.ads`

Add `Compaction_Summary` to the `Role` enumeration, after `Tool_Result`:

```ada
type Role is (User, Assistant, Tool_Result, Compaction_Summary);
```

A `Compaction_Summary` message represents the synthetic context-checkpoint
message prepended to the history after compaction. It has one `Text_Block`
in its `Content` vector carrying the full summary text.

#### 2. `llm-session_store.adb` — serialisation guard

`Message_To_Json` must **not** serialise `Compaction_Summary` messages to
disk (they are synthetic and are regenerated from the `compaction` JSONL entry
on load). Add a guard at the top of `Message_To_Json`:

```ada
when LLM.Types.Compaction_Summary =>
   raise Session_Error with
     "Compaction_Summary messages must not be persisted directly";
```

`Load_Messages` already skips unknown roles, so no change there is needed for
this task (Task C adds the real compaction-entry reader).

#### 3. Provider wire encoding

Both `llm-providers-openai_completions.adb` and
`llm-providers-anthropic_messages.adb` iterate over `S.Messages` (or
equivalent) to build the request body. Find every `case Msg.Role is` (or
equivalent role dispatch) and add a `Compaction_Summary` arm that encodes
the message as a **user** turn:

- The content is the text from the single `Text_Block` in `Msg.Content`.
- No structural differences from a normal user message on the wire.

Read the existing `User` arm in each provider and follow the same pattern.

#### 4. Tests

Add to `llm_types_tests.ads/.adb`:

- `Test_Compaction_Summary_Role` — construct a `Compaction_Summary` message
  with one text block; assert `Msg.Role = Compaction_Summary`; assert the
  text round-trips from the block.

Add to `test_suites.adb` under the existing `LLM_Types_Caller` block.

**Do not** add a round-trip test through `Message_To_Json` for
`Compaction_Summary` — the guard must raise, not silently skip.

### Verify

```sh
cd /home/gtnoble/Projects/pi_acme_dev && alr build 2>&1 | tail -5
cd test && alr run coyote_test 2>&1 | grep -E "PASS|FAIL|ERROR"
```

---

## Task C — `LLM.Session_Store`: compaction persistence + updated loader

**Prerequisite:** Tasks A and B merged.

**Files to modify:**
- `src/llm/llm-session_store.ads`
- `src/llm/llm-session_store.adb`
- `test/src/llm_session_store_tests.ads`
- `test/src/llm_session_store_tests.adb`
- `test/src/test_suites.adb` (add new test cases)

### What to implement

#### 1. New procedure `Append_Compaction`

Add to the public spec (`llm-session_store.ads`):

```ada
--  Append a compaction entry to the session JSONL.
--
--  Summary         — the LLM-generated markdown summary text.
--  First_Kept_Index — 0-based index of the first message in the
--                    pre-compaction message list that is retained
--                    (messages 0 .. First_Kept_Index-1 are summarised
--                    and discarded).
--  Tokens_Before   — estimated token count before compaction.
--  Read_Files      — newline-separated list of read-only file paths
--                    (may be empty string).
--  Modified_Files  — newline-separated list of written/edited paths
--                    (may be empty string).
--
--  The written JSONL line is:
--    {"type":"compaction","summary":"...","firstKeptMessageIndex":N,
--     "tokensBefore":N,"details":{"readFiles":[...],"modifiedFiles":[...]}}
--
--  Raises Session_Error when the file cannot be found or written.
procedure Append_Compaction
  (Session_Id        : String;
   Summary           : String;
   First_Kept_Index  : Natural;
   Tokens_Before     : Natural;
   Read_Files        : String;
   Modified_Files    : String);
```

The JSON arrays in `details` are built by splitting the newline-separated
strings on `ASCII.LF`. Empty strings produce empty JSON arrays `[]`.

#### 2. Updated `Load_Messages`

The existing loader reads entries sequentially. Extend it to handle a
`compaction` entry:

**Algorithm (single pass):**

```
pre_msgs     : vector of Message        -- messages seen before compaction
post_msgs    : vector of Message        -- messages seen after compaction
compaction_found  : Boolean := False
compaction_summary : String
first_kept   : Natural := 0

for each JSONL line (skipping line 1 header):
  parse JSON
  if not compaction_found:
    if line has role user/assistant/toolResult:
      pre_msgs.append(parse message)
    elsif line has type = "compaction":
      compaction_found := True
      compaction_summary := line["summary"]
      first_kept := line["firstKeptMessageIndex"]  (default 0)
  else:  -- after compaction entry
    if line has role user/assistant/toolResult:
      post_msgs.append(parse message)

if compaction_found:
  result := [synthetic Compaction_Summary message]
          ++ pre_msgs[first_kept ..]
          ++ post_msgs
else:
  result := pre_msgs
```

The synthetic `Compaction_Summary` message has:
- `Role    => LLM.Types.Compaction_Summary`
- `Content => [Text_Block with the summary text]`
- `Tok_Usage => (others => 0)`
- `Stop    => LLM.Types.Unknown_Stop`
- `Timestamp => To_Unbounded_String ("")`

Only the **last** `compaction` entry in the file matters; if there are two
(which should not happen in normal operation but could in corrupted files),
the second one wins — because the pass resets `pre_msgs` to empty and
`compaction_found` to True again.

#### 3. Tests

Add to `llm_session_store_tests.ads/.adb`:

- `Test_Append_Compaction_Writes_Entry` — create a session, append two user
  messages, call `Append_Compaction` with `First_Kept_Index = 1`, verify
  the JSONL file contains a line with `"type":"compaction"` and the correct
  `firstKeptMessageIndex`.

- `Test_Load_With_Compaction_Entry` — write a JSONL fixture by hand (header
  + two message lines + one compaction line with `firstKeptMessageIndex=1`
  + one more message line after the compaction); call `Load_Messages`; assert:
  - First message has role `Compaction_Summary`
  - Second message is the second pre-compaction message (index 1)
  - Third message is the post-compaction message
  - Total length is 3

- `Test_Load_Without_Compaction_Unchanged` — existing behaviour: a session
  with no `compaction` entry loads all messages in order (regression guard).

- `Test_Compaction_Summary_Not_Persisted` — call `Append_Message` with a
  `Compaction_Summary`-role message; assert `Session_Error` is raised.

Register all new tests in `test_suites.adb` under `LLM_Session_Store_Caller`.

### Verify

```sh
cd /home/gtnoble/Projects/pi_acme_dev && alr build 2>&1 | tail -5
cd test && alr run coyote_test 2>&1 | grep -E "PASS|FAIL|ERROR|Session_Store"
```

---

## Task D — `LLM.Agent`: `Compact` procedure + token tracking

**Prerequisite:** Tasks A, B, and C merged.

**Files to modify:**
- `src/llm/llm-agent.ads`
- `src/llm/llm-agent.adb`
- `test/src/llm_agent_tests.ads`
- `test/src/llm_agent_tests.adb`
- `test/src/test_suites.adb` (add new test cases)

### What to implement

#### 1. Session record additions (`llm-agent.adb` private section)

Add to `type Session is limited record`:

```ada
Last_Context_Tokens : Natural := 0;
```

`Last_Context_Tokens` is updated after each completed, non-aborted assistant
turn. Compute it as:
```
Tok_Usage.Input + Tok_Usage.Output
  + Tok_Usage.Cache_Read + Tok_Usage.Cache_Write
```
from the builder object at the point where `Saw_Msg_End` is True and
`Stop /= Aborted` (look for where `Builder.Stop` is assigned and the
turn is flushed).

#### 2. New public procedure `Compact`

Add to `llm-agent.ads`:

```ada
--  Compact the session context by summarising old messages.
--
--  Calls the LLM once (non-streaming, no tools) to generate a
--  structured summary of messages 0 .. cut-1 of the current history,
--  then replaces S.History with:
--    [Compaction_Summary message] ++ History[cut ..]
--  and appends a compaction entry to the session JSONL file.
--
--  Emits Auto_Compaction_Start_Event before and
--  Auto_Compaction_End_Event after.  On any error the end event
--  carries the error message and Aborted => True; S.History is
--  left unchanged.
--
--  Reason is passed through to Auto_Compaction_Start_Event.Reason.
--  Safe values: "manual", "threshold", "overflow".
--
--  Must not be called while Run_Prompt is executing.
procedure Compact
  (S        : in out Session;
   On_Event : not null access procedure
                (E : LLM.Events.Agent_Event'Class);
   Reason   : String := "manual");
```

#### 3. `Compact` body

```
procedure Compact (S, On_Event, Reason):
  1. Emit Auto_Compaction_Start_Event (Reason => Reason).

  2. Cut := LLM.Compaction.Find_Cut_Point (S.History,
               S.Compact_Settings).
     If Cut = 0 and History.Length <= 1 then
       emit Auto_Compaction_End_Event (Aborted => True,
         Err_Msg => "Nothing to compact")
       and return.

  3. Determine if this is an update compaction:
     Previous_Summary := "" (empty)
     If History.First_Element.Role = Compaction_Summary then
       Previous_Summary := text of that block.

  4. Build summarisation prompt:
     - Serialize_Conversation over History[0 .. Cut-1].
     - Wrap in "<conversation>\n{text}\n</conversation>\n\n"
     - If Previous_Summary non-empty append
         "<previous-summary>\n{Previous_Summary}\n</previous-summary>\n\n"
         then append LLM.Compaction.Update_Summarization_Prompt
       else append LLM.Compaction.Summarization_Prompt.

  5. Build a single-element message vector:
       [{Role => User, Content => [Text_Block with prompt text], ...}]

  6. Call Provider.Send with:
       Model_Id      => current model id
       System_Prompt => LLM.Compaction.Summarization_System_Prompt
       Messages      => the single-message vector
       Tools_Json    => ""
       Thinking      => Off
       Max_Tokens    => (Reserve_Tokens * 4) / 5   -- 80%
       Handler       => local handler that collects text deltas

     The local handler accumulates text content blocks only; ignores
     everything else; honours S.Abort_State.

  7. If S.Abort_State.Requested after Send returns:
       emit Auto_Compaction_End_Event (Aborted => True, Err_Msg => "")
       return.

  8. If no text was collected (empty summary):
       emit Auto_Compaction_End_Event (Aborted => True,
         Err_Msg => "Empty summary returned")
       return.

  9. Track_File_Ops (S.History, Read_Files, Modified_Files).
     Append non-empty file-list XML to summary text.

  10. Tokens_Before := S.Last_Context_Tokens (or Estimate if 0).

  11. LLM.Session_Store.Append_Compaction (
        S.Session_UUID, Summary, Cut, Tokens_Before,
        Read_Files, Modified_Files).

  12. Rebuild S.History:
        New_History := empty
        New_History.Append (Compaction_Summary message with summary text)
        for I in Cut .. S.History.Last_Index loop
          New_History.Append (S.History (I))
        end loop
        S.History := New_History

  13. S.Last_Context_Tokens :=
        LLM.Compaction.Estimate_Context_Tokens (S.History).

  14. Emit Auto_Compaction_End_Event (Summary, Aborted => False,
        Will_Retry => False).

  15. On exception: emit Auto_Compaction_End_Event (Aborted => True,
        Err_Msg => exception message); re-raise is NOT needed (just log
        via the event, leave history unchanged).
```

The provider is accessed the same way as in `Run_Prompt` — reuse the
provider-selection logic already present in that procedure (extract it into
a local helper or duplicate the minimal call). The abort mechanism is the
same `Abort_State.Requested` check.

Look at `llm-agent-testing.ads/.adb` to understand how the stub provider
is injected for tests — Task D's tests will use the same mechanism.

#### 4. Tests

Add to `llm_agent_tests.ads/.adb`:

- `Test_Compact_Produces_Summary_Message` — set up a stub provider that
  returns a canned summary text when called with no tools; populate
  `S.History` with a few messages; call `Compact`; assert:
  - `S.History.First_Element.Role = Compaction_Summary`
  - The summary text is present in the first element's text block
  - History length = 1 (summary) + kept messages

- `Test_Compact_Emits_Start_And_End_Events` — same setup; collect events
  via the `On_Event` callback; assert an `Auto_Compaction_Start_Event`
  precedes an `Auto_Compaction_End_Event`, and the end event has
  `Aborted = False`.

- `Test_Compact_Short_History_Aborts` — single-message history (or empty);
  call `Compact`; assert the end event has `Aborted = True` and history
  is unchanged.

- `Test_Compact_Persists_Entry` — after `Compact` succeeds, load the session
  from disk via `Load_Messages`; assert the loaded history starts with a
  `Compaction_Summary` message.

Register all new tests under `LLM_Agent_Caller` in `test_suites.adb`.

### Verify

```sh
cd /home/gtnoble/Projects/pi_acme_dev && alr build 2>&1 | tail -5
cd test && alr run coyote_test 2>&1 | grep -E "PASS|FAIL|ERROR|Agent"
```

---

## Task E — Wire the `Compact` tag button

**Prerequisite:** Task D merged.

**Files to modify:**
- `src/coyote_app.adb`

**No new packages, no new tests required** (the existing app-state tests
cover the flag; integration is exercised manually).

### What to implement

Find the `elsif Text = "Compact" then` block (around line 1112 in the
current file). Replace the stub body with:

```ada
elsif Text = "Compact" then
   if not State.Is_Streaming
     and then not State.Is_Compacting
   then
      Commands.Enqueue (Compact_Command);
   end if;
```

Add `Compact_Command` as a new command variant.  Follow the exact same
pattern as `New_Session_Command`:

1. Find the discriminated type (or enumeration) used for the command queue
   entries and add `Compact_Command` to it.

2. In the `Agent_Task` command-dispatch loop, add a handler for
   `Compact_Command` that calls:
   ```ada
   LLM.Agent.Compact
     (Agent_Session,
      Dispatch_Event'Unrestricted_Access,
      "manual");
   ```
   Guard the call: only proceed when `not State.Is_Streaming and not State.Is_Compacting`.

3. Remove the now-unused `[Compact not yet implemented]` append and the
   surrounding stub state-management code (the `Set_Compacting True/False`
   wrapper lines that surround the stub text).

`Dispatch_Event` already handles `Auto_Compaction_Start_Event` and
`Auto_Compaction_End_Event` — no changes needed there.

### Verify

```sh
cd /home/gtnoble/Projects/pi_acme_dev && alr build 2>&1 | tail -5
cd test && alr run coyote_test 2>&1 | grep -E "PASS|FAIL|ERROR"
```

No existing tests should regress. Manual verification: run coyote, have a
conversation, click `Compact` in the tag — the window should show the
"Compacting context…" notice followed by "Context compacted." and the
tag should update.

---

## Task F — Auto-compaction threshold trigger

**Prerequisite:** Task D merged.

**Files to modify:**
- `src/llm/llm-agent.adb`
- `test/src/llm_agent_tests.ads`
- `test/src/llm_agent_tests.adb`
- `test/src/test_suites.adb` (add new test cases)

### What to implement

After each successfully completed, non-aborted assistant turn (at the point
where the turn is flushed and `S.Last_Context_Tokens` is updated), add:

```ada
if not S.Abort_State.Requested
  and then LLM.Compaction.Should_Compact
    (S.Last_Context_Tokens,
     S.Model_Info.Context_Window,
     S.Compact_Settings)
then
   Compact (S, On_Event, "threshold");
end if;
```

This check belongs inside the `Run_Prompt` body, after the main provider
call returns successfully and the history has been flushed — but **before**
the agentic loop decides whether to make another tool-call turn.  The
agentic loop continues after compaction with the trimmed history.

The `Compact` procedure is already defined (Task D), so this is a small
addition.

#### Tests

Add to `llm_agent_tests.ads/.adb`:

- `Test_Auto_Compact_Fires_At_Threshold` — configure a stub provider that
  returns a fixed token usage that exceeds
  `Context_Window - Reserve_Tokens`; set the model's `Context_Window` to a
  small value so the threshold triggers after the first turn; assert that
  `Auto_Compaction_Start_Event` is emitted during `Run_Prompt` and that
  the history contains a `Compaction_Summary` message after the call.

- `Test_Auto_Compact_Does_Not_Fire_Below_Threshold` — same setup but usage
  well below the threshold; assert no `Auto_Compaction_Start_Event` is
  emitted.

Register both under `LLM_Agent_Caller` in `test_suites.adb`.

### Verify

```sh
cd /home/gtnoble/Projects/pi_acme_dev && alr build 2>&1 | tail -5
cd test && alr run coyote_test 2>&1 | grep -E "PASS|FAIL|ERROR|Agent"
```

---

## Task G — Overflow detection and compact-then-retry

**Prerequisite:** Task F merged.

**Files to modify:**
- `src/llm/llm-agent.adb`
- `test/src/llm_agent_tests.ads`
- `test/src/llm_agent_tests.adb`
- `test/src/test_suites.adb` (add new test cases)

### What to implement

#### 1. Overflow error detection

Add a helper function (private to `llm-agent.adb`):

```ada
function Is_Context_Overflow_Error (Msg : String) return Boolean;
```

Returns `True` when `Msg` contains any of the following substrings
(case-insensitive):
- `"prompt is too long"`
- `"context_length_exceeded"`
- `"maximum context length"`
- `"too many tokens"`
- `"reduce the length of the messages"`

Use `Ada.Strings.Fixed.Index` with a case-fold (lower-case the input before
matching) or match against common variants.

#### 2. Overflow recovery in `Run_Prompt`

The existing retry loop already catches exceptions from `Provider.Send`.
Add an overflow-specific branch **before** the generic retryable-error check:

```ada
-- Inside the exception handler in the provider-call loop:
elsif Is_Context_Overflow_Error
        (Ada.Exceptions.Exception_Message (Occurrence))
then
   if Overflow_Recovery_Attempted then
      --  Already tried once; give up.
      declare
         Ev : constant LLM.Events.Auto_Compaction_End_Event := ...;
         --  Aborted => True, Will_Retry => False,
         --  Err_Msg => "Context overflow recovery failed after one attempt."
      begin
         Emit (On_Event, Ev);
      end;
      exit Attempt_Loop;
   end if;

   Overflow_Recovery_Attempted := True;

   --  Remove the last assistant error message from history if present.
   --  (An aborted/error assistant message may have been partially appended.)
   Remove_Trailing_Error_Message (S.History);

   --  Compact, then loop to retry the same prompt.
   Compact (S, On_Event, "overflow");

   if S.Abort_State.Requested then
      exit Attempt_Loop;
   end if;

   --  Do NOT advance Attempt; fall through to retry the provider call
   --  with the compacted history.
   goto Retry_Provider_Call;  -- or use a continue-equivalent
```

Declare `Overflow_Recovery_Attempted : Boolean := False;` alongside the
existing `Retry_Used` boolean.

`Remove_Trailing_Error_Message` is a local procedure that pops the last
message from `S.History` if its `Stop = Error_Stop` or `Stop = Aborted`.

The `Will_Retry => True` flag on the `Auto_Compaction_End_Event` emitted by
`Compact` when reason = "overflow" signals to the UI that the agent will
retry automatically.  Pass `Will_Retry => True` through the
`Auto_Compaction_End_Event` when the retry will happen, and `False` when
giving up.  (Task D's `Compact` procedure always emits `Will_Retry => False`;
for the overflow case, either adjust the `Compact` signature to accept a
`Will_Retry` parameter, or emit a second synthetic event here.)

The cleanest approach: after `Compact` returns successfully and before
looping back to retry, emit a second `Auto_Compaction_End_Event` with
`Will_Retry => True` to update the UI. Do not change the `Compact` procedure
signature.

#### 3. Tests

Add to `llm_agent_tests.ads/.adb`:

- `Test_Overflow_Triggers_Compact_And_Retry` — configure a stub provider
  that raises an exception with `"prompt is too long"` on the first call and
  succeeds on the second call (use the existing stub provider's
  `Set_Should_Raise_On_Call_N` mechanism or equivalent); assert that
  `Auto_Compaction_Start_Event` is emitted and the final response is the
  successful second-call answer.

- `Test_Overflow_Recovery_Not_Attempted_Twice` — stub raises overflow on
  both calls; assert `Auto_Compaction_End_Event` with `Aborted = True` and
  that `Run_Prompt` exits after the second failure without looping forever.

Register under `LLM_Agent_Caller` in `test_suites.adb`.

### Verify

```sh
cd /home/gtnoble/Projects/pi_acme_dev && alr build 2>&1 | tail -5
cd test && alr run coyote_test 2>&1 | grep -E "PASS|FAIL|ERROR|overflow|Overflow"
```

---

## General notes for all subagents

- Load the Ada style guide skill before writing any Ada:
  `/home/gtnoble/.pi/agent/skills/ada-style-guide/SKILL.md`
- Two-space indentation; `--  double-dash` comments; specs carry full doc
  comments; bodies carry only implementation notes.
- The main project build command is `alr build` from
  `/home/gtnoble/Projects/pi_acme_dev/`.
- The test suite is built and run with `alr run coyote_test` from
  `/home/gtnoble/Projects/pi_acme_dev/test/`.
- New source files in `src/llm/` are picked up automatically by
  `coyote.gpr` (the `Source_Dirs` glob covers the directory).
- New test files in `test/src/` are picked up automatically by the test
  project's equivalent glob.
- Always read the full content of every file you modify before editing it.
- Run the build after every significant change; fix compilation errors before
  proceeding to the next step.
