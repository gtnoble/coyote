with AUnit.Assertions;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with GNATCOLL.JSON;         use GNATCOLL.JSON;
with Coyote_App; use Coyote_App;
with Coyote_App.Utils; use Coyote_App.Utils;
with Nine_P;
with Coyote_App.Dispatch;   use Coyote_App.Dispatch;

package body Coyote_App_Tests is

   use AUnit.Assertions;

   --  ── Model ─────────────────────────────────────────────────────────────

   procedure Test_State_Model (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      Assert (S.Current_Model = "", "Initial model should be empty");
      S.Set_Model ("anthropic/claude-3-5-sonnet");
      Assert (S.Current_Model = "anthropic/claude-3-5-sonnet",
              "Model should be updated");
      S.Set_Model ("openai/gpt-4o");
      Assert (S.Current_Model = "openai/gpt-4o",
              "Model should be overwritten");
   end Test_State_Model;

   --  ── Streaming flag ───────────────────────────────────────────────────

   procedure Test_State_Streaming (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      Assert (not S.Is_Streaming, "Initially not streaming");
      S.Set_Streaming (True);
      Assert (S.Is_Streaming,
              "Should be streaming after Set_Streaming(True)");
      S.Set_Streaming (False);
      Assert (not S.Is_Streaming, "Should stop streaming");
   end Test_State_Streaming;

   --  ── Token counts ─────────────────────────────────────────────────────

   procedure Test_State_Tokens (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      Assert (S.Turn_Input_Tokens  = 0, "Initial input tokens = 0");
      Assert (S.Turn_Output_Tokens = 0, "Initial output tokens = 0");
      S.Set_Turn_Tokens (12345, 678);
      Assert (S.Turn_Input_Tokens  = 12345, "Input tokens updated");
      Assert (S.Turn_Output_Tokens = 678,   "Output tokens updated");
      S.Set_Context_Window (200_000);
      Assert (S.Context_Window = 200_000,   "Context window updated");
   end Test_State_Tokens;

   --  ── Shutdown barrier ─────────────────────────────────────────────────

   procedure Test_State_Shutdown (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;

      Completed : Boolean := False;

      task Waiter;
      task body Waiter is
      begin
         S.Wait_Shutdown;
         Completed := True;
      end Waiter;

   begin
      delay 0.05;
      Assert (not Completed, "Waiter should block before Signal_Shutdown");
      S.Signal_Shutdown;
      delay 0.1;
      Assert (Completed, "Waiter should unblock after Signal_Shutdown");
   end Test_State_Shutdown;

   --  ── Session ID ───────────────────────────────────────────────────────

   procedure Test_State_Session_Id (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      Assert (S.Session_Id = "", "Initial session ID is empty");
      S.Set_Session_Id ("abc-def-012345");
      Assert (S.Session_Id = "abc-def-012345",
              "Session ID should be stored verbatim");
   end Test_State_Session_Id;

   --  ── Nth_Field ────────────────────────────────────────────────────────

   --  Basic space-separated cases.
   procedure Test_Nth_Field_Basic (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Nth_Field ("one two three", 1) = "one",   "Field 1");
      Assert (Nth_Field ("one two three", 2) = "two",   "Field 2");
      Assert (Nth_Field ("one two three", 3) = "three", "Field 3");
      Assert (Nth_Field ("one two three", 4) = "",      "Field 4 absent");
      Assert (Nth_Field ("  leading",     1) = "leading", "Leading spaces");
      Assert (Nth_Field ("a  b",          2) = "b",
              "Multiple spaces between fields");
      Assert (Nth_Field ("single",        1) = "single",
              "Single token, N=1");
      Assert (Nth_Field ("single",        2) = "",
              "Single token, N=2");
   end Test_Nth_Field_Basic;

   --  Tab separators — Nth_Field is field-separator-agnostic;
   --  this test verifies tab-separated input works correctly.
   procedure Test_Nth_Field_Tabs (T : in out Test) is
      pragma Unreferenced (T);
      Line : constant String :=
        "amazon-bedrock" & ASCII.HT
        & "amazon.nova-lite-v1:0" & ASCII.HT
        & "300K";
   begin
      Assert (Nth_Field (Line, 1) = "amazon-bedrock",     "Provider field");
      Assert (Nth_Field (Line, 2) = "amazon.nova-lite-v1:0", "Model field");
      Assert (Nth_Field (Line, 3) = "300K",               "Context field");
      Assert (Nth_Field (Line, 4) = "",                   "Field 4 absent");
   end Test_Nth_Field_Tabs;

   --  Edge cases: empty string, trailing whitespace, N=0 not reachable
   --  (N is Positive), single-char tokens.
   procedure Test_Nth_Field_Edges (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Nth_Field ("",      1) = "", "Empty string");
      Assert (Nth_Field ("   ",   1) = "", "Only spaces");
      Assert (Nth_Field ("a b  ", 2) = "b", "Trailing spaces, field 2");
      Assert (Nth_Field ("a b  ", 3) = "", "Trailing spaces, field 3 absent");
      Assert (Nth_Field ("x",     1) = "x", "Single char");
   end Test_Nth_Field_Edges;

   --  ── Parse_Fork_Token ────────────────────────────────────────────────

   procedure Test_Parse_Fork_Token_Match (T : in out Test) is
      pragma Unreferenced (T);
      UUID   : Unbounded_String;
      Turn_N : Positive := 1;
      Result : constant Boolean :=
        Parse_Fork_Token
          ("coyote-fork+42/abc1-def2-3456-789a-bcdef0123456/7",
           "coyote-fork+42/",
           UUID,
           Turn_N);
   begin
      Assert (Result, "Valid token should return True");
      Assert (To_String (UUID) = "abc1-def2-3456-789a-bcdef0123456",
              "UUID should be extracted correctly");
      Assert (Turn_N = 7, "Turn number should be 7");
   end Test_Parse_Fork_Token_Match;

   procedure Test_Parse_Fork_Token_Pid_Mismatch (T : in out Test) is
      pragma Unreferenced (T);
      UUID   : Unbounded_String;
      Turn_N : Positive := 1;
      Result : constant Boolean :=
        Parse_Fork_Token
          ("coyote-fork+99/abc1-def2-3456-789a-bcdef0123456/7",
           "coyote-fork+42/",
           UUID,
           Turn_N);
   begin
      Assert (not Result,
              "Mismatched PID prefix should return False");
   end Test_Parse_Fork_Token_Pid_Mismatch;

   procedure Test_Parse_Fork_Token_No_Slash (T : in out Test) is
      pragma Unreferenced (T);
      UUID   : Unbounded_String;
      Turn_N : Positive := 1;
      Result : constant Boolean :=
        Parse_Fork_Token
          ("coyote-fork+42/abc1-def2-3456-789a-bcdef0123456",
           "coyote-fork+42/",
           UUID,
           Turn_N);
   begin
      Assert (not Result,
              "Token without trailing /turn should return False");
   end Test_Parse_Fork_Token_No_Slash;

   procedure Test_Parse_Fork_Token_Bad_Turn (T : in out Test) is
      pragma Unreferenced (T);
      UUID   : Unbounded_String;
      Turn_N : Positive := 1;
      Result : constant Boolean :=
        Parse_Fork_Token
          ("coyote-fork+42/abc1-def2-3456-789a-bcdef0123456/not-a-number",
           "coyote-fork+42/",
           UUID,
           Turn_N);
   begin
      Assert (not Result,
              "Non-numeric turn field should return False");
   end Test_Parse_Fork_Token_Bad_Turn;

   procedure Test_Parse_Fork_Token_Empty_Uuid (T : in out Test) is
      pragma Unreferenced (T);
      UUID   : Unbounded_String;
      Turn_N : Positive := 1;
      Result : constant Boolean :=
        Parse_Fork_Token ("coyote-fork+42//7", "coyote-fork+42/", UUID, Turn_N);
   begin
      Assert (not Result,
              "Empty UUID field should return False");
   end Test_Parse_Fork_Token_Empty_Uuid;

   procedure Test_Parse_Fork_Token_Empty (T : in out Test) is
      pragma Unreferenced (T);
      UUID   : Unbounded_String;
      Turn_N : Positive := 1;
      Result : constant Boolean :=
        Parse_Fork_Token ("", "coyote-fork+42/", UUID, Turn_N);
   begin
      Assert (not Result, "Empty input should return False");
   end Test_Parse_Fork_Token_Empty;

   --  ── App_State Turn_Count ──────────────────────────────────────────────

   procedure Test_State_Turn_Count_Increment (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      Assert (S.Turn_Count = 0, "Initial Turn_Count should be 0");
      S.Increment_Turn_Count;
      Assert (S.Turn_Count = 1,
              "After one increment Turn_Count should be 1");
      S.Increment_Turn_Count;
      S.Increment_Turn_Count;
      Assert (S.Turn_Count = 3,
              "After three increments Turn_Count should be 3");
   end Test_State_Turn_Count_Increment;

   procedure Test_State_Turn_Count_Set (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      S.Set_Turn_Count (42);
      Assert (S.Turn_Count = 42,
              "Set_Turn_Count should store the given value");
      S.Set_Turn_Count (0);
      Assert (S.Turn_Count = 0, "Set_Turn_Count to 0 should work");
   end Test_State_Turn_Count_Set;

   procedure Test_State_Turn_Count_Reset (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      S.Set_Turn_Count (5);
      S.Reset_Turn_Count;
      Assert (S.Turn_Count = 0, "Reset_Turn_Count should set count back to 0");
   end Test_State_Turn_Count_Reset;

   --  ── App_State Is_Retrying ────────────────────────────────────────────
   --
   --  Is_Retrying tracks whether an auto-retry sequence is currently in
   --  flight.  It is set by the auto_retry_start event handler and cleared
   --  by auto_retry_end, new_session, and session reload.  The flag is used
   --  in the agent_end handler to suppress the spurious "No response" message
   --  for every failed attempt after the first: the agent emits agent_end
   --  before auto_retry_start, so the very first failure always sees
   --  Is_Retrying = False, but subsequent retry cycles see Is_Retrying = True.

   --  Is_Retrying defaults to False on a freshly created App_State.
   procedure Test_State_Is_Retrying_Initial (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      Assert (not S.Is_Retrying,
              "Is_Retrying should be False initially");
   end Test_State_Is_Retrying_Initial;

   --  Set_Is_Retrying toggles the flag in both directions.
   procedure Test_State_Is_Retrying_Set_And_Clear (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      S.Set_Is_Retrying (True);
      Assert (S.Is_Retrying,
              "Is_Retrying should be True after Set_Is_Retrying(True)");
      S.Set_Is_Retrying (False);
      Assert (not S.Is_Retrying,
              "Is_Retrying should be False after Set_Is_Retrying(False)");
   end Test_State_Is_Retrying_Set_And_Clear;

   --  Is_Retrying is independent of Text_Emitted and Has_Text_Delta.
   --  Setting one must not affect the others; the agent_end handler reads
   --  all three independently.
   procedure Test_State_Is_Retrying_Independent (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      --  Set only Is_Retrying; the text flags must stay False.
      S.Set_Is_Retrying (True);
      Assert (not S.Text_Emitted,
              "Text_Emitted must stay False when only Is_Retrying is set");
      Assert (not S.Has_Text_Delta,
              "Has_Text_Delta must stay False when only Is_Retrying is set");

      --  Set Text_Emitted; Is_Retrying must be unaffected.
      S.Set_Text_Emitted (True);
      Assert (S.Is_Retrying,
              "Is_Retrying must remain True after Set_Text_Emitted");

      --  Clear Is_Retrying; Text_Emitted must be unaffected.
      S.Set_Is_Retrying (False);
      Assert (not S.Is_Retrying,
              "Is_Retrying should be False after Set_Is_Retrying(False)");
      Assert (S.Text_Emitted,
              "Text_Emitted must remain True after clearing Is_Retrying");
   end Test_State_Is_Retrying_Independent;

   --  ── App_State Has_Text_Delta ──────────────────────────────────────────

   --  Has_Text_Delta defaults to False on a freshly created App_State.
   procedure Test_State_Has_Text_Delta_Initial (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      Assert (not S.Has_Text_Delta,
              "Has_Text_Delta should be False initially");
   end Test_State_Has_Text_Delta_Initial;

   --  Set_Has_Text_Delta toggles the flag in both directions.
   procedure Test_State_Has_Text_Delta_Set_And_Clear (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      S.Set_Has_Text_Delta (True);
      Assert (S.Has_Text_Delta,
              "Has_Text_Delta should be True after Set_Has_Text_Delta(True)");
      S.Set_Has_Text_Delta (False);
      Assert (not S.Has_Text_Delta,
              "Has_Text_Delta should be False after "
              & "Set_Has_Text_Delta(False)");
   end Test_State_Has_Text_Delta_Set_And_Clear;

   --  Has_Text_Delta and Text_Emitted are independent flags.  Setting one
   --  must not affect the other.  This matters because Text_Emitted is set
   --  by tool_execution_start (tool-only turn) while Has_Text_Delta is only
   --  set by text_delta (final text response).
   procedure Test_State_Has_Text_Delta_Independent (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      --  Set only Text_Emitted (tool-only turn); Has_Text_Delta must stay
      --  False.
      S.Set_Text_Emitted (True);
      Assert (not S.Has_Text_Delta,
              "Has_Text_Delta should stay False when only Text_Emitted "
              & "is set (tool-only turn)");
      Assert (S.Text_Emitted, "Text_Emitted should be True");

      --  Also set Has_Text_Delta; Text_Emitted must still be True.
      S.Set_Has_Text_Delta (True);
      Assert (S.Has_Text_Delta,
              "Has_Text_Delta should be True after Set_Has_Text_Delta(True)");
      Assert (S.Text_Emitted,
              "Text_Emitted must remain True after Set_Has_Text_Delta");

      --  Clear Has_Text_Delta; Text_Emitted must be unaffected.
      S.Set_Has_Text_Delta (False);
      Assert (not S.Has_Text_Delta,
              "Has_Text_Delta should be False after clearing");
      Assert (S.Text_Emitted,
              "Text_Emitted must be unaffected by clearing Has_Text_Delta");
   end Test_State_Has_Text_Delta_Independent;

   --  Pending_Stats is gated by Last_Stop_Reason in Dispatch_Event.
   --  Verify the three paths:
   --    "stop"    → stats requested → footer emitted
   --    "length"  → stats requested → footer emitted
   --    anything else → no stats requested → no footer
   procedure Test_State_Pending_Stats_Gated_By_Stop_Reason
     (T : in out Test)
   is
      pragma Unreferenced (T);
      S : App_State;

      --  Simulate the agent_end footer gate from Dispatch_Event:
      --    declare
      --       Stop : constant String := State.Last_Stop_Reason;
      --    begin
      --       if Stop = "stop" or else Stop = "length" then
      --          State.Set_Pending_Stats (True); ...
      --       end if;
      --    end;
      procedure Run_Agent_End_Gate is
         Stop : constant String := S.Last_Stop_Reason;
      begin
         if Stop = "stop" or else Stop = "length" then
            S.Set_Pending_Stats (True);
         end if;
      end Run_Agent_End_Gate;

   begin
      --  Path A: stopReason "toolUse" (intermediate tool-calling turn).
      --  Pending_Stats must stay False.
      S.Set_Last_Stop_Reason ("toolUse");
      Run_Agent_End_Gate;
      Assert (not S.Pending_Stats,
              "Pending_Stats must be False when stopReason = ""toolUse""");

      --  Path B: stopReason "" (no message_end received, e.g. agent crashed).
      --  Pending_Stats must stay False.
      S.Set_Last_Stop_Reason ("");
      Run_Agent_End_Gate;
      Assert (not S.Pending_Stats,
              "Pending_Stats must be False when stopReason is empty");

      --  Path C: stopReason "error".
      --  Pending_Stats must stay False (no text response produced).
      S.Set_Last_Stop_Reason ("error");
      Run_Agent_End_Gate;
      Assert (not S.Pending_Stats,
              "Pending_Stats must be False when stopReason = ""error""");

      --  Path D: stopReason "stop" — normal final text response.
      --  Pending_Stats must be True.
      S.Set_Last_Stop_Reason ("stop");
      Run_Agent_End_Gate;
      Assert (S.Pending_Stats,
              "Pending_Stats must be True when stopReason = ""stop""");

      --  Reset and check Path E: stopReason "length" — max-token final turn.
      --  Pending_Stats must be True.
      S.Set_Pending_Stats (False);
      S.Set_Last_Stop_Reason ("length");
      Run_Agent_End_Gate;
      Assert (S.Pending_Stats,
              "Pending_Stats must be True when stopReason = ""length""");
   end Test_State_Pending_Stats_Gated_By_Stop_Reason;

   --  ── App_State Models_Pending ─────────────────────────────────────────
   --
   --  Models_Pending gates the +models sub-window: the Acme_Event_Task sets
   --  it True and sends get_available_models; Dispatch_Event clears it
   --  once the response arrives and the window is opened.

   --  Models_Pending defaults to False on a freshly created App_State.
   procedure Test_State_Models_Pending_Initial (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      Assert (not S.Models_Pending,
              "Models_Pending should be False initially");
   end Test_State_Models_Pending_Initial;

   --  Set_Models_Pending toggles the flag in both directions.
   procedure Test_State_Models_Pending_Set_And_Clear (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      S.Set_Models_Pending (True);
      Assert (S.Models_Pending,
              "Models_Pending should be True after Set_Models_Pending(True)");
      S.Set_Models_Pending (False);
      Assert (not S.Models_Pending,
              "Models_Pending should be False after "
              & "Set_Models_Pending(False)");
   end Test_State_Models_Pending_Set_And_Clear;

   --  Models_Pending is independent of Pending_Stats and other boolean flags.
   --  Setting one must not affect the others.
   procedure Test_State_Models_Pending_Independent (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      --  Set only Models_Pending; Pending_Stats must stay False.
      S.Set_Models_Pending (True);
      Assert (not S.Pending_Stats,
              "Pending_Stats must stay False when only Models_Pending is set");
      Assert (not S.Is_Streaming,
              "Is_Streaming must stay False when only Models_Pending is set");
      Assert (not S.Is_Compacting,
              "Is_Compacting must stay False when only Models_Pending is set");

      --  Set Pending_Stats; Models_Pending must be unaffected.
      S.Set_Pending_Stats (True);
      Assert (S.Models_Pending,
              "Models_Pending must remain True after Set_Pending_Stats");

      --  Clear Models_Pending; Pending_Stats must remain True.
      S.Set_Models_Pending (False);
      Assert (not S.Models_Pending,
              "Models_Pending should be False after clearing");
      Assert (S.Pending_Stats,
              "Pending_Stats must be unaffected by clearing Models_Pending");
   end Test_State_Models_Pending_Independent;

   --  ── App_State Last_Stop_Reason ────────────────────────────────────────
   procedure Test_State_Last_Stop_Reason_Initial (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      Assert (S.Last_Stop_Reason = "",
              "Last_Stop_Reason should be empty initially");
   end Test_State_Last_Stop_Reason_Initial;

   --  Set_Last_Stop_Reason stores and can overwrite the value.
   procedure Test_State_Last_Stop_Reason_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      S.Set_Last_Stop_Reason ("stop");
      Assert (S.Last_Stop_Reason = "stop",
              "Last_Stop_Reason should return ""stop""");
      S.Set_Last_Stop_Reason ("toolUse");
      Assert (S.Last_Stop_Reason = "toolUse",
              "Last_Stop_Reason should update to ""toolUse""");
      S.Set_Last_Stop_Reason ("length");
      Assert (S.Last_Stop_Reason = "length",
              "Last_Stop_Reason should update to ""length""");
      S.Set_Last_Stop_Reason ("error");
      Assert (S.Last_Stop_Reason = "error",
              "Last_Stop_Reason should update to ""error""");
      S.Set_Last_Stop_Reason ("aborted");
      Assert (S.Last_Stop_Reason = "aborted",
              "Last_Stop_Reason should update to ""aborted""");
      S.Set_Last_Stop_Reason ("");
      Assert (S.Last_Stop_Reason = "",
              "Last_Stop_Reason should reset to empty string");
   end Test_State_Last_Stop_Reason_Round_Trip;

   --  Last_Stop_Reason is independent of all other flags.
   procedure Test_State_Last_Stop_Reason_Independent (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      S.Set_Last_Stop_Reason ("stop");
      Assert (not S.Has_Text_Delta,
              "Has_Text_Delta must be unaffected by Set_Last_Stop_Reason");
      Assert (not S.Has_Tool_In_Turn,
              "Has_Tool_In_Turn must be unaffected by Set_Last_Stop_Reason");
      Assert (not S.Text_Emitted,
              "Text_Emitted must be unaffected by Set_Last_Stop_Reason");
      Assert (not S.Is_Retrying,
              "Is_Retrying must be unaffected by Set_Last_Stop_Reason");

      --  Setting other flags must leave Last_Stop_Reason unchanged.
      S.Set_Has_Text_Delta (True);
      S.Set_Has_Tool_In_Turn (True);
      S.Set_Text_Emitted (True);
      S.Set_Is_Retrying (True);
      Assert (S.Last_Stop_Reason = "stop",
              "Last_Stop_Reason must be unaffected by other flag writes");
   end Test_State_Last_Stop_Reason_Independent;

   --  ── App_State Last_Error_Message ──────────────────────────────────────

   --  Last_Error_Message defaults to "" on a freshly created App_State.
   procedure Test_State_Last_Error_Message_Initial (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      Assert (S.Last_Error_Message = "",
              "Last_Error_Message should be empty initially");
   end Test_State_Last_Error_Message_Initial;

   --  Set_Last_Error_Message stores and can overwrite the value; it is
   --  independent of Last_Stop_Reason and all other flags.
   procedure Test_State_Last_Error_Message_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      S.Set_Last_Error_Message ("context length exceeded");
      Assert (S.Last_Error_Message = "context length exceeded",
              "Last_Error_Message should store the error string");

      --  Setting Last_Error_Message must not disturb Last_Stop_Reason.
      S.Set_Last_Stop_Reason ("error");
      S.Set_Last_Error_Message ("rate limit exceeded");
      Assert (S.Last_Error_Message = "rate limit exceeded",
              "Last_Error_Message should update to new value");
      Assert (S.Last_Stop_Reason = "error",
              "Last_Stop_Reason must be unaffected by Set_Last_Error_Message");

      --  Clear the error message; Last_Stop_Reason must remain.
      S.Set_Last_Error_Message ("");
      Assert (S.Last_Error_Message = "",
              "Last_Error_Message should reset to empty string");
      Assert (S.Last_Stop_Reason = "error",
              "Last_Stop_Reason must still be ""error"" after clearing "
              & "Last_Error_Message");
   end Test_State_Last_Error_Message_Round_Trip;


   --  ── Model in stats summary ────────────────────────────────────────────
   --
   --  These tests document the App_State accessor that gates the model part
   --  appended to the per-turn stats line in Dispatch_Event's
   --  get_session_stats handler.  The handler uses:
   --
   --    Model_Text : constant String := State.Current_Model;
   --    if Model_Text'Length > 0 then
   --       Append (Parts, " | ");
   --       Append (Parts, Model_Text);
   --    end if;
   --
   --  When a model is active the non-empty string is contributed; when no
   --  model has been set yet the condition is False and the stats line is
   --  not padded with a spurious separator.

   --  With a model set, Current_Model returns a non-empty string that
   --  satisfies the guard and would be appended to the stats parts.
   procedure Test_Stats_Model_Part_When_Set (T : in out Test) is
      pragma Unreferenced (T);
      S          : App_State;
      Model_Text : Ada.Strings.Unbounded.Unbounded_String;
   begin
      S.Set_Model ("anthropic/claude-opus-4-5");
      Model_Text :=
        Ada.Strings.Unbounded.To_Unbounded_String (S.Current_Model);
      Assert
        (Ada.Strings.Unbounded.Length (Model_Text) > 0,
         "Current_Model should be non-empty when a model is set");
      Assert
        (Ada.Strings.Unbounded.To_String (Model_Text)
           = "anthropic/claude-opus-4-5",
         "Current_Model should return the exact model string");
   end Test_Stats_Model_Part_When_Set;

   --  With no model set, Current_Model returns an empty string and the
   --  guard is False, so no model part is appended to the stats line.
   procedure Test_Stats_Model_Part_When_Empty (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      Assert
        (S.Current_Model'Length = 0,
         "Current_Model should be empty on a fresh App_State; "
         & "guard must be False so no model part is emitted");
   end Test_Stats_Model_Part_When_Empty;

   --  ── App_State cost fields ─────────────────────────────────────────────
   --
   --  These tests cover the new per-turn and session-level cost/token fields
   --  added for cost tracking.  All fields default to 0 and are updated
   --  atomically via Set_Turn_Cost and Set_Session_Stats.

   --  Turn_Cost_Dmil defaults to 0 on a fresh App_State.
   procedure Test_State_Turn_Cost_Initial (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      Assert (S.Turn_Cost_Dmil = 0,
              "Turn_Cost_Dmil should be 0 initially");
   end Test_State_Turn_Cost_Initial;

   --  Set_Turn_Cost stores the given dmil value and can be overwritten.
   procedure Test_State_Turn_Cost_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      --  0.0234 dollars = 234 dmil
      S.Set_Turn_Cost (234);
      Assert (S.Turn_Cost_Dmil = 234,
              "Turn_Cost_Dmil should store 234 after Set_Turn_Cost(234)");
      --  Overwrite with a different value.
      S.Set_Turn_Cost (1_560);
      Assert (S.Turn_Cost_Dmil = 1_560,
              "Turn_Cost_Dmil should update to 1560 on second Set_Turn_Cost");
      --  Reset to zero.
      S.Set_Turn_Cost (0);
      Assert (S.Turn_Cost_Dmil = 0,
              "Turn_Cost_Dmil should return to 0 after Set_Turn_Cost(0)");
   end Test_State_Turn_Cost_Round_Trip;

   --  All six session-stats fields default to 0.
   procedure Test_State_Session_Stats_Initial (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      Assert (S.Session_Cost_Dmil      = 0, "Session_Cost_Dmil = 0 initially");
      Assert (S.Session_Input_Tokens   = 0, "Session_Input_Tokens = 0");
      Assert (S.Session_Output_Tokens  = 0, "Session_Output_Tokens = 0");
      Assert (S.Session_Cache_Read     = 0, "Session_Cache_Read = 0");
      Assert (S.Session_Cache_Write    = 0, "Session_Cache_Write = 0");
      Assert (S.Session_Total_Tokens   = 0, "Session_Total_Tokens = 0");
   end Test_State_Session_Stats_Initial;

   --  Set_Session_Stats stores all six fields atomically and they can be
   --  read back independently via their individual accessors.
   procedure Test_State_Session_Stats_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      S.Set_Session_Stats
        (Cost_Dmil   => 4_321,
         Input       => 100_000,
         Output      => 2_500,
         Cache_Read  => 80_000,
         Cache_Write => 5_000,
         Total       => 187_500);
      Assert (S.Session_Cost_Dmil     = 4_321,
              "Session_Cost_Dmil should be 4321");
      Assert (S.Session_Input_Tokens  = 100_000,
              "Session_Input_Tokens should be 100000");
      Assert (S.Session_Output_Tokens = 2_500,
              "Session_Output_Tokens should be 2500");
      Assert (S.Session_Cache_Read    = 80_000,
              "Session_Cache_Read should be 80000");
      Assert (S.Session_Cache_Write   = 5_000,
              "Session_Cache_Write should be 5000");
      Assert (S.Session_Total_Tokens  = 187_500,
              "Session_Total_Tokens should be 187500");
   end Test_State_Session_Stats_Round_Trip;

   --  Set_Session_Stats with all-zeros resets every field.
   procedure Test_State_Session_Stats_Reset (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      --  Populate first.
      S.Set_Session_Stats (1_000, 50_000, 1_000, 40_000, 2_000, 93_000);
      --  Now reset.
      S.Set_Session_Stats (0, 0, 0, 0, 0, 0);
      Assert (S.Session_Cost_Dmil     = 0, "Cost reset to 0");
      Assert (S.Session_Input_Tokens  = 0, "Input reset to 0");
      Assert (S.Session_Output_Tokens = 0, "Output reset to 0");
      Assert (S.Session_Cache_Read    = 0, "Cache_Read reset to 0");
      Assert (S.Session_Cache_Write   = 0, "Cache_Write reset to 0");
      Assert (S.Session_Total_Tokens  = 0, "Total reset to 0");
   end Test_State_Session_Stats_Reset;

   --  Cost fields are entirely independent of the existing per-turn token
   --  counts: setting one must not disturb the other.
   procedure Test_State_Cost_Independent_Of_Tokens (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      S.Set_Turn_Tokens (12_000, 400);
      S.Set_Turn_Cost (234);
      Assert (S.Turn_Input_Tokens  = 12_000,
              "Turn_Input_Tokens unchanged after Set_Turn_Cost");
      Assert (S.Turn_Output_Tokens = 400,
              "Turn_Output_Tokens unchanged after Set_Turn_Cost");
      Assert (S.Turn_Cost_Dmil     = 234,
              "Turn_Cost_Dmil set correctly");

      --  Session stats must also be independent of per-turn fields.
      S.Set_Session_Stats (999, 200_000, 5_000, 0, 0, 205_000);
      Assert (S.Turn_Input_Tokens  = 12_000,
              "Turn_Input_Tokens unchanged after Set_Session_Stats");
      Assert (S.Turn_Cost_Dmil     = 234,
              "Turn_Cost_Dmil unchanged after Set_Session_Stats");
      Assert (S.Session_Cost_Dmil  = 999,
              "Session_Cost_Dmil set independently");
   end Test_State_Cost_Independent_Of_Tokens;

   --  A JSON string value is returned as-is, without surrounding quotes.
   procedure Test_JSON_Scalar_String (T : in out Test) is
      pragma Unreferenced (T);
      V : constant JSON_Value := Create ("hello world");
   begin
      Assert (JSON_Scalar_Image (V) = "hello world",
              "String value should be returned without quotes");
   end Test_JSON_Scalar_String;

   --  An empty JSON string is returned as an empty string.
   procedure Test_JSON_Scalar_Integer (T : in out Test) is
      pragma Unreferenced (T);
      V : constant JSON_Value := Create (Integer'(42));
   begin
      Assert (JSON_Scalar_Image (V) = "42",
              "Integer 42 should serialise as ""42""");
   end Test_JSON_Scalar_Integer;

   --  Negative integer values are serialised correctly.
   procedure Test_JSON_Scalar_Negative_Integer (T : in out Test) is
      pragma Unreferenced (T);
      V : constant JSON_Value := Create (Integer'(-7));
   begin
      Assert (JSON_Scalar_Image (V) = "-7",
              "Integer -7 should serialise as ""-7""");
   end Test_JSON_Scalar_Negative_Integer;

   --  Boolean true serialises to the JSON literal "true".
   procedure Test_JSON_Scalar_Boolean_True (T : in out Test) is
      pragma Unreferenced (T);
      V : constant JSON_Value := Create (True);
   begin
      Assert (JSON_Scalar_Image (V) = "true",
              "Boolean True should serialise as ""true""");
   end Test_JSON_Scalar_Boolean_True;

   --  Boolean false serialises to the JSON literal "false".
   procedure Test_JSON_Scalar_Boolean_False (T : in out Test) is
      pragma Unreferenced (T);
      V : constant JSON_Value := Create (False);
   begin
      Assert (JSON_Scalar_Image (V) = "false",
              "Boolean False should serialise as ""false""");
   end Test_JSON_Scalar_Boolean_False;

   --  Float values are serialised to a non-empty numeric string.
   procedure Test_JSON_Scalar_Float (T : in out Test) is
      pragma Unreferenced (T);
      V      : constant JSON_Value := Create (Float'(3.14));
      Result : constant String     := JSON_Scalar_Image (V);
   begin
      Assert (Result'Length > 0,
              "Float value should produce a non-empty string");
      --  Must not be the fallback sentinel.
      Assert (Result /= "...",
              "Float value should not produce ""...""");
   end Test_JSON_Scalar_Float;

   --  A JSON null value returns the "..." sentinel.
   procedure Test_JSON_Scalar_Null (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (JSON_Scalar_Image (JSON_Null) = "...",
              "Null value should return ""...""");
   end Test_JSON_Scalar_Null;

   --  A JSON object value returns the "..." sentinel.
   procedure Test_JSON_Scalar_Object (T : in out Test) is
      pragma Unreferenced (T);
      V : JSON_Value := Create_Object;
   begin
      V.Set_Field ("key", Create ("value"));
      Assert (JSON_Scalar_Image (V) = "...",
              "Object value should return ""...""");
   end Test_JSON_Scalar_Object;

   --  A JSON array value returns the "..." sentinel.
   procedure Test_JSON_Scalar_Array (T : in out Test) is
      pragma Unreferenced (T);
      Arr : JSON_Array;
      V   : JSON_Value;
   begin
      Append (Arr, Create (Integer'(1)));
      V := Create (Arr);
      Assert (JSON_Scalar_Image (V) = "...",
              "Array value should return ""...""");
   end Test_JSON_Scalar_Array;

   --  ── One_Shot_Result ────────────────────────────────────────────────

   --  One_Shot_Result returns "" before any result is stored.
   procedure Test_One_Shot_Result_Initial (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      Assert (S.One_Shot_Result = "",
              "One_Shot_Result should be empty before any Set call");
   end Test_One_Shot_Result_Initial;

   --  Set_One_Shot_Result stores the value; a second call is silently
   --  ignored (first-write-wins semantics).
   procedure Test_One_Shot_Result_First_Write_Wins (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      S.Set_One_Shot_Result ("{""output"":""hello""}");
      Assert (S.One_Shot_Result = "{""output"":""hello""}",
              "One_Shot_Result should return the first stored value");
      --  Second write must not overwrite.
      S.Set_One_Shot_Result ("{""error"":""ignored""}");
      Assert (S.One_Shot_Result = "{""output"":""hello""}",
              "Second Set_One_Shot_Result call must be ignored");
   end Test_One_Shot_Result_First_Write_Wins;

   --  ── Format_Tool_Field ─────────────────────────────────────────────────
   --
   --  U+2502 BOX DRAWINGS LIGHT VERTICAL (box-v): UTF-8 E2 94 82
   --  U+2026 HORIZONTAL ELLIPSIS (ellipsis):       UTF-8 E2 80 A6

   UC_Box_V : constant String :=
     Character'Val (16#E2#)
     & Character'Val (16#94#)
     & Character'Val (16#82#);

   UC_Ellip : constant String :=
     Character'Val (16#E2#)
     & Character'Val (16#80#)
     & Character'Val (16#A6#);

   --  Single-line value: no LF in Value -- "box-v name: value".
   procedure Test_Format_Tool_Field_Single_Line (T : in out Test) is
      pragma Unreferenced (T);
      Result : constant String :=
        Format_Tool_Field ("command", "echo hello");
   begin
      Assert (Result = UC_Box_V & " command: echo hello",
              "Single-line field should be ""box-v command: echo hello""; "
              & "got """ & Result & """");
   end Test_Format_Tool_Field_Single_Line;

   --  Two-line value: one LF -- label on first line, box-v only on second.
   procedure Test_Format_Tool_Field_Two_Lines (T : in out Test) is
      pragma Unreferenced (T);
      Value  : constant String := "echo a" & ASCII.LF & "echo b";
      Result : constant String :=
        Format_Tool_Field ("command", Value);
      Expect : constant String :=
        UC_Box_V & " command: echo a"
        & ASCII.LF & UC_Box_V & " echo b";
   begin
      Assert (Result = Expect,
              "Two-line field: got """ & Result & """");
   end Test_Format_Tool_Field_Two_Lines;

   --  Three-line value: two LFs -- box-v border on every line.
   procedure Test_Format_Tool_Field_Three_Lines (T : in out Test) is
      pragma Unreferenced (T);
      Value  : constant String :=
        "cd /tmp" & ASCII.LF
        & "echo a" & ASCII.LF
        & "echo b";
      Result : constant String :=
        Format_Tool_Field ("command", Value);
      Expect : constant String :=
        UC_Box_V & " command: cd /tmp"
        & ASCII.LF & UC_Box_V & " echo a"
        & ASCII.LF & UC_Box_V & " echo b";
   begin
      Assert (Result = Expect,
              "Three-line field: got """ & Result & """");
   end Test_Format_Tool_Field_Three_Lines;

   --  Trailing LF: last char is LF -- empty continuation line appended.
   procedure Test_Format_Tool_Field_Trailing_LF (T : in out Test) is
      pragma Unreferenced (T);
      Value  : constant String := "hello" & ASCII.LF;
      Result : constant String :=
        Format_Tool_Field ("k", Value);
      Expect : constant String :=
        UC_Box_V & " k: hello"
        & ASCII.LF & UC_Box_V & " ";
   begin
      Assert (Result = Expect,
              "Trailing-LF field: got """ & Result & """");
   end Test_Format_Tool_Field_Trailing_LF;

   --  Empty value: Format_Tool_Field returns "box-v name: ".
   procedure Test_Format_Tool_Field_Empty_Value (T : in out Test) is
      pragma Unreferenced (T);
      Result : constant String :=
        Format_Tool_Field ("key", "");
   begin
      Assert (Result = UC_Box_V & " key: ",
              "Empty-value field should be ""box-v key: ""; "
              & "got """ & Result & """");
   end Test_Format_Tool_Field_Empty_Value;

   --  Truncation: value longer than Max_Len is truncated with ellipsis.
   procedure Test_Format_Tool_Field_Truncation (T : in out Test) is
      pragma Unreferenced (T);
      --  Max_Len = 8: keep first 5 bytes ("abcde") + 3-byte ellipsis = 8.
      Value  : constant String := "abcdefghij";
      Result : constant String :=
        Format_Tool_Field ("k", Value, Max_Len => 8);
      Expect : constant String :=
        UC_Box_V & " k: abcde" & UC_Ellip;
   begin
      Assert (Result = Expect,
              "Truncated field should end with ellipsis; "
              & "got """ & Result & """");
   end Test_Format_Tool_Field_Truncation;

   --  ── Format_SI_Count ──────────────────────────────────────────────────

   procedure Test_Format_SI_Count_Below_Threshold (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Format_SI_Count (0)   = "0",   "0 -> ""0""");
      Assert (Format_SI_Count (1)   = "1",   "1 -> ""1""");
      Assert (Format_SI_Count (999) = "999", "999 -> ""999""");
   end Test_Format_SI_Count_Below_Threshold;

   --  Round multiples of 1000 have no fractional part.
   procedure Test_Format_SI_Count_Round_Numbers (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Format_SI_Count (1_000)   = "1k",   "1000 -> ""1k""");
      Assert (Format_SI_Count (2_000)   = "2k",   "2000 -> ""2k""");
      Assert (Format_SI_Count (10_000)  = "10k",  "10000 -> ""10k""");
      Assert (Format_SI_Count (200_000) = "200k", "200000 -> ""200k""");
   end Test_Format_SI_Count_Round_Numbers;

   --  Values with non-zero hundredths produce a "N.FFk" result;
   --  trailing zeros in the fractional part are stripped.
   procedure Test_Format_SI_Count_Fractional (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Format_SI_Count (1_500)  = "1.5k",  "1500 -> ""1.5k""");
      Assert (Format_SI_Count (1_100)  = "1.1k",  "1100 -> ""1.1k""");
      Assert (Format_SI_Count (12_300) = "12.3k", "12300 -> ""12.3k""");
      Assert (Format_SI_Count (1_050)  = "1.05k",
              "1050: rounds to 1.05 -> ""1.05k""");
   end Test_Format_SI_Count_Fractional;

   --  Values >= 1 000 000 use the M prefix; >= 1 000 000 000 use G.
   procedure Test_Format_SI_Count_M_Range (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Format_SI_Count (1_000_000)   = "1M",   "1M -> ""1M""");
      Assert (Format_SI_Count (1_500_000)   = "1.5M", "1.5M -> ""1.5M""");
      Assert (Format_SI_Count (200_000_000) = "200M", "200M -> ""200M""");
   end Test_Format_SI_Count_M_Range;

   --  ── Format_Cost ───────────────────────────────────────────────────────

   procedure Test_Format_Cost_Zero (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Format_Cost (0) = "$0.0000",
              "0 dmil -> ""$0.0000""");
   end Test_Format_Cost_Zero;

   --  Sub-dollar values: the integer part is 0, fractional part is
   --  zero-padded to four digits.
   procedure Test_Format_Cost_Fractional (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Format_Cost (1)    = "$0.0001", "1 dmil -> ""$0.0001""");
      Assert (Format_Cost (100)  = "$0.0100", "100 dmil -> ""$0.0100""");
      Assert (Format_Cost (234)  = "$0.0234", "234 dmil -> ""$0.0234""");
      Assert (Format_Cost (9999) = "$0.9999", "9999 dmil -> ""$0.9999""");
   end Test_Format_Cost_Fractional;

   --  Values >= 10000 have a non-zero dollar integer part.
   procedure Test_Format_Cost_Dollars (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Format_Cost (10000)  = "$1.0000",
              "10000 dmil -> ""$1.0000""");
      Assert (Format_Cost (12345)  = "$1.2345",
              "12345 dmil -> ""$1.2345""");
      Assert (Format_Cost (100000) = "$10.0000",
              "100000 dmil -> ""$10.0000""");
   end Test_Format_Cost_Dollars;


   --  Build a Nine_P.Byte_Array from a plain String for test input.
   --  Declared at the package body level so all Extract_Plumb_Data tests
   --  can use it.
   function To_Bytes (S : String) return Nine_P.Byte_Array is
      Result : Nine_P.Byte_Array (0 .. S'Length - 1);
   begin
      for I in S'Range loop
         Result (I - S'First) := Nine_P.Uint8 (Character'Pos (S (I)));
      end loop;
      return Result;
   end To_Bytes;

   --  Normal 7-field plumb message; ndata matches data length exactly.
   procedure Test_Extract_Plumb_Data_Basic (T : in out Test) is
      pragma Unreferenced (T);
      --  Fields: src / dst / wdir / type / attr / ndata / data
      Msg : constant Nine_P.Byte_Array :=
        To_Bytes ("app"      & ASCII.LF
                  & "coyote-model" & ASCII.LF
                  & "/home"    & ASCII.LF
                  & "text"     & ASCII.LF
                  & ""         & ASCII.LF
                  & "13"       & ASCII.LF
                  & "openai/gpt-4o");
   begin
      Assert (Extract_Plumb_Data (Msg) = "openai/gpt-4o",
              "Basic plumb message: data field returned verbatim");
   end Test_Extract_Plumb_Data_Basic;

   --  The plumber appends a trailing LF after the data; ndata must clip it.
   procedure Test_Extract_Plumb_Data_Strips_Trailing_LF (T : in out Test) is
      pragma Unreferenced (T);
      Uuid : constant String := "aabbccdd-1122-3344-5566-aabbccddeeff";
      Msg  : constant Nine_P.Byte_Array :=
        To_Bytes ("app"         & ASCII.LF
                  & "coyote-session" & ASCII.LF
                  & "/home"      & ASCII.LF
                  & "text"       & ASCII.LF
                  & ""           & ASCII.LF
                  & "36"         & ASCII.LF
                  & Uuid         & ASCII.LF);  --  trailing LF from plumber
   begin
      Assert (Extract_Plumb_Data (Msg) = Uuid,
              "Trailing LF after data is stripped via ndata");
   end Test_Extract_Plumb_Data_Strips_Trailing_LF;

   --  Fewer than 6 newlines: the ndata field is never reached -> "".
   procedure Test_Extract_Plumb_Data_Too_Few_Fields (T : in out Test) is
      pragma Unreferenced (T);
      Msg : constant Nine_P.Byte_Array :=
        To_Bytes ("src" & ASCII.LF & "dst" & ASCII.LF & "only-three-fields");
   begin
      Assert (Extract_Plumb_Data (Msg) = "",
              "Fewer than 6 newlines -> empty string");
   end Test_Extract_Plumb_Data_Too_Few_Fields;

   --  Empty byte array: loop body never executes -> "".
   procedure Test_Extract_Plumb_Data_Empty (T : in out Test) is
      pragma Unreferenced (T);
      Msg : constant Nine_P.Byte_Array (1 .. 0) := (others => 0);
   begin
      Assert (Extract_Plumb_Data (Msg) = "",
              "Empty byte array -> empty string");
   end Test_Extract_Plumb_Data_Empty;

   --  ── Get_Cost_Dmil ────────────────────────────────────────────────────

   --  A JSON float representing $0.001 -> 10 dmil.
   procedure Test_Get_Cost_Dmil_Float_Value (T : in out Test) is
      pragma Unreferenced (T);
      Val : JSON_Value := Create_Object;
   begin
      Val.Set_Field ("cost", Create (Long_Float (0.001)));
      Assert (Get_Cost_Dmil (Val, "cost") = 10,
              "Float 0.001 -> 10 dmil");
   end Test_Get_Cost_Dmil_Float_Value;

   --  A JSON float of 0.0 is not positive -> 0 dmil.
   procedure Test_Get_Cost_Dmil_Zero_Float (T : in out Test) is
      pragma Unreferenced (T);
      Val : JSON_Value := Create_Object;
   begin
      Val.Set_Field ("cost", Create (Long_Float (0.0)));
      Assert (Get_Cost_Dmil (Val, "cost") = 0,
              "Float 0.0 -> 0 dmil");
   end Test_Get_Cost_Dmil_Zero_Float;

   --  A JSON integer 0 is not positive -> 0 dmil.
   procedure Test_Get_Cost_Dmil_Integer_Zero (T : in out Test) is
      pragma Unreferenced (T);
      Val : JSON_Value := Create_Object;
   begin
      Val.Set_Field ("cost", Create (Integer'(0)));
      Assert (Get_Cost_Dmil (Val, "cost") = 0,
              "Integer 0 -> 0 dmil");
   end Test_Get_Cost_Dmil_Integer_Zero;

   --  An absent field -> 0 dmil.
   procedure Test_Get_Cost_Dmil_Absent_Field (T : in out Test) is
      pragma Unreferenced (T);
      Val : constant JSON_Value := Create_Object;
   begin
      Assert (Get_Cost_Dmil (Val, "cost") = 0,
              "Absent field -> 0 dmil");
   end Test_Get_Cost_Dmil_Absent_Field;

   --  A negative float -> 0 dmil (not positive guard).
   procedure Test_Get_Cost_Dmil_Negative_Float (T : in out Test) is
      pragma Unreferenced (T);
      Val : JSON_Value := Create_Object;
   begin
      Val.Set_Field ("cost", Create (Long_Float (-0.001)));
      Assert (Get_Cost_Dmil (Val, "cost") = 0,
              "Negative float -> 0 dmil");
   end Test_Get_Cost_Dmil_Negative_Float;

   --  ── Format_Status ────────────────────────────────────────────────────

   --  Shared helper -- true iff Sub appears anywhere in Str.
   function Status_Contains (Str : String; Sub : String) return Boolean is
   begin
      if Sub'Length = 0 or else Str'Length < Sub'Length then
         return False;
      end if;
      for I in Str'First .. Str'Last - Sub'Length + 1 loop
         if Str (I .. I + Sub'Length - 1) = Sub then
            return True;
         end if;
      end loop;
      return False;
   end Status_Contains;

   --  Default (empty) state: only the bullet and Extra are present.
   procedure Test_Format_Status_Default (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      Assert (Format_Status (S, "ready") = UC_BULLET & " ready",
              "Empty state should produce bullet + ready");
   end Test_Format_Status_Default;

   --  The Extra argument is reflected verbatim.
   procedure Test_Format_Status_Custom_Extra (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      Assert (Format_Status (S, "running") = UC_BULLET & " running",
              "Extra=running should produce bullet + running");
   end Test_Format_Status_Custom_Extra;

   --  When a model is set, "[provider/model]" appears in the status.
   procedure Test_Format_Status_With_Model (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      S.Set_Model ("anthropic/claude-3-5");
      Assert (Status_Contains (Format_Status (S), " [anthropic/claude-3-5]"),
              "Model set -> ""[anthropic/claude-3-5]"" in status");
   end Test_Format_Status_With_Model;

   --  When a session ID of >= 8 chars is set, "session:XXXXXXXX" appears.
   procedure Test_Format_Status_With_Session (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      S.Set_Session_Id ("abcdef01-1234-5678-uuid");
      Assert (Status_Contains (Format_Status (S), " session:abcdef01"),
              "Session ID -> first 8 chars shown as session:abcdef01");
   end Test_Format_Status_With_Session;

   --  When both token count and context window are set, "Nk/Mk (P%)" appears.
   procedure Test_Format_Status_With_Context (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      S.Set_Turn_Tokens (1500, 0);
      S.Set_Context_Window (200_000);
      Assert (Status_Contains (Format_Status (S), "1.5k/200k"),
              "Token/context window -> ""1.5k/200k"" in status");
   end Test_Format_Status_With_Context;

   --  When a thinking level is set, "~level" appears in the status.
   procedure Test_Format_Status_With_Thinking (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      S.Set_Thinking ("medium");
      Assert (Status_Contains (Format_Status (S), " ~medium"),
              "Thinking level -> "" ~medium"" in status");
   end Test_Format_Status_With_Thinking;

   --  ── Format_Model_Price ───────────────────────────────────────────────

   procedure Test_Format_Model_Price_All_Zeros (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (Format_Model_Price (0.0, 0.0, 0.0, 0.0) = "",
         "All-zero prices should return an empty string");
   end Test_Format_Model_Price_All_Zeros;

   procedure Test_Format_Model_Price_In_Out_Only (T : in out Test) is
      pragma Unreferenced (T);
      Result : constant String :=
        Format_Model_Price (3.0, 15.0, 0.0, 0.0);
   begin
      Assert
        (Result = "in $3" & UC_MICRO & " out $15" & UC_MICRO & " /tok",
         "in/out-only prices should produce SI µ segments"
         & " but got """ & Result & """");
   end Test_Format_Model_Price_In_Out_Only;

   procedure Test_Format_Model_Price_All_Four (T : in out Test) is
      pragma Unreferenced (T);
      Result : constant String :=
        Format_Model_Price (3.0, 15.0, 0.3, 4.0);
   begin
      Assert
        (Result = "in $3" & UC_MICRO
                  & " out $15" & UC_MICRO
                  & " cr $300n"
                  & " cw $4" & UC_MICRO
                  & " /tok",
         "All-four prices should produce four SI-prefixed segments"
         & " but got """ & Result & """");
   end Test_Format_Model_Price_All_Four;

   procedure Test_Format_Model_Price_Omits_Zeros (T : in out Test) is
      pragma Unreferenced (T);
      Result : constant String :=
        Format_Model_Price (2.5, 10.0, 0.0, 0.0);
   begin
      Assert
        (Ada.Strings.Unbounded.Index
           (To_Unbounded_String (Result), "cr") = 0,
         "Zero cache_read should not produce a ""cr"" label");
      Assert
        (Ada.Strings.Unbounded.Index
           (To_Unbounded_String (Result), "cw") = 0,
         "Zero cache_write should not produce a ""cw"" label");
      Assert
        (Ada.Strings.Unbounded.Index
           (To_Unbounded_String (Result), "/tok") > 0,
         "Non-zero in/out should still end with /tok");
   end Test_Format_Model_Price_Omits_Zeros;

   procedure Test_Format_Model_Price_Cache_Only (T : in out Test) is
      pragma Unreferenced (T);
      Result : constant String :=
        Format_Model_Price (0.0, 0.0, 0.3, 0.0);
   begin
      Assert
        (Result = "cr $300n /tok",
         "Cache-read-only price should produce ""cr $300n /tok"""
         & " but got """ & Result & """");
   end Test_Format_Model_Price_Cache_Only;

   --  ── Apply_Prompt_Filter ───────────────────────────────────────────────

   --  Empty filter: raw returned unchanged, Warn_Buf empty.
   procedure Test_Apply_Filter_Empty_Filter (T : in out Test) is
      pragma Unreferenced (T);
      Warn   : Ada.Strings.Unbounded.Unbounded_String;
      Result : constant String :=
        Apply_Prompt_Filter ("hello world", "", Warn);
   begin
      Assert (Result = "hello world",
              "Empty filter should return raw prompt unchanged");
      Assert (Ada.Strings.Unbounded.Length (Warn) = 0,
              "Empty filter should leave Warn_Buf empty");
   end Test_Apply_Filter_Empty_Filter;

   --  Filter that echoes stdin back: output equals trimmed input.
   procedure Test_Apply_Filter_Echo (T : in out Test) is
      pragma Unreferenced (T);
      Warn   : Ada.Strings.Unbounded.Unbounded_String;
      Result : constant String :=
        Apply_Prompt_Filter ("hello", "cat", Warn);
   begin
      Assert (Result = "hello",
              "cat filter should echo the prompt back; got """
              & Result & """");
      Assert (Ada.Strings.Unbounded.Length (Warn) = 0,
              "Successful filter should leave Warn_Buf empty");
   end Test_Apply_Filter_Echo;

   --  Filter that transforms input (convert to uppercase with tr).
   procedure Test_Apply_Filter_Transform (T : in out Test) is
      pragma Unreferenced (T);
      Warn   : Ada.Strings.Unbounded.Unbounded_String;
      Result : constant String :=
        Apply_Prompt_Filter ("hello", "tr a-z A-Z", Warn);
   begin
      Assert (Result = "HELLO",
              "tr filter should uppercase the prompt; got """
              & Result & """");
      Assert (Ada.Strings.Unbounded.Length (Warn) = 0,
              "Successful filter should leave Warn_Buf empty");
   end Test_Apply_Filter_Transform;

   --  Filter that exits non-zero: raw returned, Warn_Buf non-empty.
   procedure Test_Apply_Filter_Non_Zero_Exit (T : in out Test) is
      pragma Unreferenced (T);
      Warn   : Ada.Strings.Unbounded.Unbounded_String;
      Result : constant String :=
        Apply_Prompt_Filter ("hello", "exit 1", Warn);
   begin
      Assert (Result = "hello",
              "Non-zero-exit filter should return raw prompt");
      Assert (Ada.Strings.Unbounded.Length (Warn) > 0,
              "Non-zero-exit filter should populate Warn_Buf");
   end Test_Apply_Filter_Non_Zero_Exit;

   --  Filter that produces empty stdout: raw returned, Warn_Buf non-empty.
   procedure Test_Apply_Filter_Empty_Output (T : in out Test) is
      pragma Unreferenced (T);
      Warn   : Ada.Strings.Unbounded.Unbounded_String;
      --  Discard stdin and emit nothing.
      Result : constant String :=
        Apply_Prompt_Filter ("hello", "cat /dev/null", Warn);
   begin
      Assert (Result = "hello",
              "Empty-output filter should return raw prompt");
      Assert (Ada.Strings.Unbounded.Length (Warn) > 0,
              "Empty-output filter should populate Warn_Buf");
   end Test_Apply_Filter_Empty_Output;

   --  Output with surrounding whitespace/newlines is trimmed.
   procedure Test_Apply_Filter_Trims_Whitespace (T : in out Test) is
      pragma Unreferenced (T);
      Warn   : Ada.Strings.Unbounded.Unbounded_String;
      --  printf adds a trailing newline; echo adds one too.
      --  Use printf to emit leading/trailing spaces around the content.
      Result : constant String :=
        Apply_Prompt_Filter
          ("x", "printf '  trimmed  '", Warn);
   begin
      Assert (Result = "trimmed",
              "Filter output should be trimmed; got """ & Result & """");
      Assert (Ada.Strings.Unbounded.Length (Warn) = 0,
              "Successful filter should leave Warn_Buf empty");
   end Test_Apply_Filter_Trims_Whitespace;

   --  ── App_State Prompt_Filter ───────────────────────────────────────────

   procedure Test_State_Prompt_Filter_Initial (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      Assert (S.Prompt_Filter = "",
              "Prompt_Filter should be empty initially");
   end Test_State_Prompt_Filter_Initial;

   procedure Test_State_Prompt_Filter_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      S.Set_Prompt_Filter ("m4 -");
      Assert (S.Prompt_Filter = "m4 -",
              "Prompt_Filter should return stored value");
      S.Set_Prompt_Filter ("");
      Assert (S.Prompt_Filter = "",
              "Prompt_Filter should update to empty string");
   end Test_State_Prompt_Filter_Round_Trip;

   --  ── Is_Paused ─────────────────────────────────────────────────────────

   procedure Test_State_Is_Paused_Initial (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      Assert (not S.Is_Paused, "Is_Paused should be False initially");
   end Test_State_Is_Paused_Initial;

   procedure Test_State_Is_Paused_Set_And_Clear (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      S.Set_Paused (True);
      Assert (S.Is_Paused, "Is_Paused should be True after Set_Paused (True)");
      S.Set_Paused (False);
      Assert
        (not S.Is_Paused,
         "Is_Paused should be False after Set_Paused (False)");
   end Test_State_Is_Paused_Set_And_Clear;

   --  ── Is_Pause_Armed ────────────────────────────────────────────────────

   procedure Test_State_Is_Pause_Armed_Initial (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      Assert (not S.Is_Pause_Armed, "Is_Pause_Armed should be False initially");
   end Test_State_Is_Pause_Armed_Initial;

   procedure Test_State_Is_Pause_Armed_Set_And_Clear (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      S.Set_Pause_Armed (True);
      Assert
        (S.Is_Pause_Armed,
         "Is_Pause_Armed should be True after Set_Pause_Armed (True)");
      S.Set_Pause_Armed (False);
      Assert
        (not S.Is_Pause_Armed,
         "Is_Pause_Armed should be False after Set_Pause_Armed (False)");
   end Test_State_Is_Pause_Armed_Set_And_Clear;

   --  ── Tag_Suffix ────────────────────────────────────────────────────────

   procedure Test_State_Tag_Suffix_Initial (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      Assert (S.Tag_Suffix = "", "Tag_Suffix should be empty initially");
   end Test_State_Tag_Suffix_Initial;

   procedure Test_State_Tag_Suffix_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      S      : App_State;
      Suffix : constant String := " Models Sessions Thinking Stats";
   begin
      S.Set_Tag_Suffix (Suffix);
      Assert
        (S.Tag_Suffix = Suffix,
         "Tag_Suffix should return the stored suffix verbatim");
      S.Set_Tag_Suffix ("");
      Assert (S.Tag_Suffix = "", "Tag_Suffix should update to empty string");
   end Test_State_Tag_Suffix_Round_Trip;

end Coyote_App_Tests;
