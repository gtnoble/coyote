with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Suites;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Characters.Latin_1;
with GNATCOLL.JSON;         use GNATCOLL.JSON;
with Coyote_App; use Coyote_App;
with Coyote_App.Utils; use Coyote_App.Utils;
with Coyote_App.Dispatch;   use Coyote_App.Dispatch;
with Ada.Strings.Fixed;
with Coyote_Cmark;
with Interfaces.C;
with Interfaces.C.Strings;
with System;

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

   --  ── Format_Turn_Footer_Display step-level separator ───────────────────

   procedure Test_Format_Turn_Footer_Display_Step (T : in out Test) is
      pragma Unreferenced (T);
      Footer : constant String :=
        Format_Turn_Footer_Display
          (Input_Tokens  => 1000,
           Output_Tokens => 200,
           Stop_Reason_Text => "toolUse",
           Is_Step       => True);
   begin
      --  Step footer uses single-line separator (UC_HORIZ, U+2500).
      Assert
        (Ada.Strings.Fixed.Index (Footer, UC_HORIZ) > 0,
         "Step footer must use single-line separator");
      --  Step footer must NOT use double-line separator.
      Assert
        (Ada.Strings.Fixed.Index (Footer, UC_DBL_H) = 0,
         "Step footer must not use double-line separator");
   end Test_Format_Turn_Footer_Display_Step;

   --  ── App_State Turn_Step ───────────────────────────────────────────────

   procedure Test_State_Turn_Step_Increment (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      Assert (S.Turn_Step = 0, "Initial Turn_Step should be 0");
      S.Increment_Turn_Step;
      Assert (S.Turn_Step = 1,
              "After one increment Turn_Step should be 1");
      S.Increment_Turn_Step;
      S.Increment_Turn_Step;
      Assert (S.Turn_Step = 3,
              "After three increments Turn_Step should be 3");
   end Test_State_Turn_Step_Increment;

   procedure Test_State_Turn_Step_Set (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      S.Set_Turn_Step (5);
      Assert (S.Turn_Step = 5,
              "Set_Turn_Step should store the given value");
   end Test_State_Turn_Step_Set;

   procedure Test_State_Turn_Step_Reset (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      S.Set_Turn_Step (5);
      S.Reset_Turn_Step;
      Assert (S.Turn_Step = 0,
              "Reset_Turn_Step should return to 0");
   end Test_State_Turn_Step_Reset;

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

   --  ── Test_Tool_Segment_Line_Count ──────────────────────────────────────
   --  Verify the LF-count arithmetic used by the TUI rendering block for
   --  Tool_Segment arg fields: count(LF in Format_Tool_Field output) + 1
   --  must equal the number of ncurses display lines produced.

   procedure Test_Tool_Segment_Line_Count (T : in out Test) is
      pragma Unreferenced (T);
      use Ada.Characters.Latin_1;

      --  Single-line value: no embedded LF → 0 LFs in result → 1 line.
      Single    : constant String :=
        Format_Tool_Field ("command", "echo hello");
      NL_Single : Natural          := 0;

      --  Two-line value: one embedded LF → 1 LF in result → 2 lines.
      Multi     : constant String :=
        Format_Tool_Field ("command", "line1" & LF & "line2");
      NL_Multi  : Natural          := 0;
   begin
      for C of Single loop
         if C = LF then
            NL_Single := NL_Single + 1;
         end if;
      end loop;
      Assert (NL_Single + 1 = 1,
              "Single-line field: expected 1 display line, got "
              & Natural'Image (NL_Single + 1));

      for C of Multi loop
         if C = LF then
            NL_Multi := NL_Multi + 1;
         end if;
      end loop;
      Assert (NL_Multi + 1 = 2,
              "Two-line field: expected 2 display lines, got "
              & Natural'Image (NL_Multi + 1));
   end Test_Tool_Segment_Line_Count;


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

   --  When a sandbox profile is active, its name appears in the status.
   procedure Test_Format_Status_With_Sandbox (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      S.Set_Sandbox ("restricted");
      Assert (Status_Contains (Format_Status (S, "running"),
                               " [restricted]"),
              "Sandbox profile should appear in the status");
   end Test_Format_Status_With_Sandbox;

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

   procedure Test_Format_DB_Price_Representative (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Format_DB_Price (1_000_000.0) = "0",
              "one dollar per token should be 0 dB");
      Assert (Format_DB_Price (3.0) = "-55.23",
              "3 dollars per MTok should convert to -55.23 dB");
      Assert (Format_DB_Price (15.0) = "-48.24",
              "15 dollars per MTok should convert to -48.24 dB");
   end Test_Format_DB_Price_Representative;

   procedure Test_Format_DB_Price_Free_And_Negative (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Format_DB_Price (0.0) = "free",
              "zero price should display as free");
      Assert (Format_DB_Price (-1.0) = "",
              "negative price should display as blank");
   end Test_Format_DB_Price_Free_And_Negative;

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
      Assert (not S.Is_Pause_Armed,
              "Is_Pause_Armed should be False initially");
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

   --  ── Sandbox ──────────────────────────────────────────────────────────

   procedure Test_State_Sandbox_Initial (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      Assert
        (S.Current_Sandbox = "",
         "Current_Sandbox should be empty initially");
   end Test_State_Sandbox_Initial;

   procedure Test_State_Sandbox_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      S.Set_Sandbox ("restricted");
      Assert
        (S.Current_Sandbox = "restricted",
         "Current_Sandbox should return stored profile name");
      S.Set_Sandbox ("full-access");
      Assert
        (S.Current_Sandbox = "full-access",
         "Current_Sandbox should return updated profile name");
   end Test_State_Sandbox_Round_Trip;

   procedure Test_State_Sandbox_Clear (T : in out Test) is
      pragma Unreferenced (T);
      S : App_State;
   begin
      S.Set_Sandbox ("restricted");
      Assert
        (S.Current_Sandbox = "restricted",
         "precondition: sandbox should be set");
      S.Set_Sandbox ("");
      Assert
        (S.Current_Sandbox = "",
         "Set_Sandbox ("""") should clear the profile back to empty");
   end Test_State_Sandbox_Clear;

   --  ── GFM (libcmark-gfm) table parsing ─────────────────────────────────

   --  Verify that Parse_Document with the GFM extensions enabled parses a
   --  pipe table and exposes a node whose type string is "table".
   procedure Test_Cmark_GFM_Table_Parsed (T : in out Test) is
      pragma Unreferenced (T);
      use Interfaces.C;
      use Interfaces.C.Strings;
      use System;

      Table_MD : constant String :=
        "| Name  | Value |" & ASCII.LF &
        "|-------|-------|" & ASCII.LF &
        "| foo   | 42    |" & ASCII.LF;

      C_Text   : constant char_array := To_C (Table_MD, Append_Nul => True);
      Doc      : Coyote_Cmark.Node_Ptr;
      Iter     : Coyote_Cmark.Iter_Ptr;
      Ev       : Coyote_Cmark.Event_Type_Int;
      Node     : Coyote_Cmark.Node_Ptr;
      Found_Table : Boolean := False;
      TS_Ptr   : chars_ptr;
   begin
      Doc  := Coyote_Cmark.Parse_Document
                (C_Text, size_t (Table_MD'Length),
                 Coyote_Cmark.OPT_DEFAULT);
      Assert (Doc /= System.Null_Address,
              "Parse_Document must return a non-null document node");

      Iter := Coyote_Cmark.Iter_New (Doc);
      loop
         Ev := Coyote_Cmark.Iter_Next (Iter);
         exit when Ev = Coyote_Cmark.EVENT_DONE;
         if Ev = Coyote_Cmark.EVENT_ENTER then
            Node   := Coyote_Cmark.Iter_Get_Node (Iter);
            TS_Ptr := Coyote_Cmark.Node_Get_Type_String (Node);
            if String'(Value (TS_Ptr)) = "table" then
               Found_Table := True;
            end if;
         end if;
      end loop;
      Coyote_Cmark.Iter_Free (Iter);
      Coyote_Cmark.Node_Free (Doc);

      Assert (Found_Table,
              "GFM table input must produce a node with type_string='table'");
   end Test_Cmark_GFM_Table_Parsed;

   --  Verify that standard CommonMark paragraph nodes still have the
   --  correct type string after the migration to libcmark-gfm.
   procedure Test_Cmark_Paragraph_Type_String (T : in out Test) is
      pragma Unreferenced (T);
      use Interfaces.C;
      use Interfaces.C.Strings;
      use System;

      Para_MD : constant String := "Hello, world." & ASCII.LF;
      C_Text  : constant char_array := To_C (Para_MD, Append_Nul => True);
      Doc     : Coyote_Cmark.Node_Ptr;
      Iter    : Coyote_Cmark.Iter_Ptr;
      Ev      : Coyote_Cmark.Event_Type_Int;
      Node    : Coyote_Cmark.Node_Ptr;
      Found_Para : Boolean := False;
      TS_Ptr  : chars_ptr;
   begin
      Doc  := Coyote_Cmark.Parse_Document
                (C_Text, size_t (Para_MD'Length),
                 Coyote_Cmark.OPT_DEFAULT);
      Assert (Doc /= System.Null_Address,
              "Parse_Document must return a non-null document node");

      Iter := Coyote_Cmark.Iter_New (Doc);
      loop
         Ev := Coyote_Cmark.Iter_Next (Iter);
         exit when Ev = Coyote_Cmark.EVENT_DONE;
         if Ev = Coyote_Cmark.EVENT_ENTER then
            Node   := Coyote_Cmark.Iter_Get_Node (Iter);
            TS_Ptr := Coyote_Cmark.Node_Get_Type_String (Node);
            if String'(Value (TS_Ptr)) = "paragraph" then
               Found_Para := True;
            end if;
         end if;
      end loop;
      Coyote_Cmark.Iter_Free (Iter);
      Coyote_Cmark.Node_Free (Doc);

      Assert (Found_Para,
              "Standard paragraph must still have type_string='paragraph'");
   end Test_Cmark_Paragraph_Type_String;


   package App_State_Caller is
     new AUnit.Test_Caller (Coyote_App_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (App_State_Caller.Create
        ("App_State model round-trip",
         Coyote_App_Tests.Test_State_Model'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State streaming flag",
         Coyote_App_Tests.Test_State_Streaming'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State token counts",
         Coyote_App_Tests.Test_State_Tokens'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State shutdown barrier",
         Coyote_App_Tests.Test_State_Shutdown'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State session ID",
         Coyote_App_Tests.Test_State_Session_Id'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Nth_Field basic space-separated",
         Coyote_App_Tests.Test_Nth_Field_Basic'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Nth_Field tab-separated input",
         Coyote_App_Tests.Test_Nth_Field_Tabs'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Nth_Field edge cases",
         Coyote_App_Tests.Test_Nth_Field_Edges'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Turn_Footer: step-level separator",
         Coyote_App_Tests.Test_Format_Turn_Footer_Display_Step'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Turn_Step increment",
         Coyote_App_Tests.Test_State_Turn_Step_Increment'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Turn_Step set",
         Coyote_App_Tests.Test_State_Turn_Step_Set'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Turn_Step reset",
         Coyote_App_Tests.Test_State_Turn_Step_Reset'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Turn_Count increment",
         Coyote_App_Tests.Test_State_Turn_Count_Increment'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Turn_Count set",
         Coyote_App_Tests.Test_State_Turn_Count_Set'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Turn_Count reset",
         Coyote_App_Tests.Test_State_Turn_Count_Reset'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Is_Retrying initial value is False",
         Coyote_App_Tests.Test_State_Is_Retrying_Initial'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Is_Retrying set and clear",
         Coyote_App_Tests.Test_State_Is_Retrying_Set_And_Clear'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Is_Retrying independent of text flags",
         Coyote_App_Tests.Test_State_Is_Retrying_Independent'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Has_Text_Delta initial value is False",
         Coyote_App_Tests.Test_State_Has_Text_Delta_Initial'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Has_Text_Delta set and clear",
         Coyote_App_Tests.Test_State_Has_Text_Delta_Set_And_Clear'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Has_Text_Delta independent of Text_Emitted",
         Coyote_App_Tests.Test_State_Has_Text_Delta_Independent'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Last_Stop_Reason initial value is empty",
         Coyote_App_Tests.Test_State_Last_Stop_Reason_Initial'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Last_Stop_Reason round-trip for all stop-reason values",
         Coyote_App_Tests.Test_State_Last_Stop_Reason_Round_Trip'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Last_Stop_Reason independent of all other flags",
         Coyote_App_Tests.Test_State_Last_Stop_Reason_Independent'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Last_Error_Message initial value is empty",
         Coyote_App_Tests.Test_State_Last_Error_Message_Initial'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Last_Error_Message round-trip and independence",
         Coyote_App_Tests
           .Test_State_Last_Error_Message_Round_Trip'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Pending_Stats gated by Last_Stop_Reason "
         & "(stop/length only)",
         Coyote_App_Tests
           .Test_State_Pending_Stats_Gated_By_Stop_Reason'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Stats model part: non-empty when model is set",
         Coyote_App_Tests.Test_Stats_Model_Part_When_Set'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Stats model part: empty guard when no model set",
         Coyote_App_Tests.Test_Stats_Model_Part_When_Empty'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Turn_Cost_Dmil initial value is 0",
         Coyote_App_Tests.Test_State_Turn_Cost_Initial'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Turn_Cost_Dmil round-trip via Set_Turn_Cost",
         Coyote_App_Tests.Test_State_Turn_Cost_Round_Trip'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State session stats fields all start at 0",
         Coyote_App_Tests.Test_State_Session_Stats_Initial'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Set_Session_Stats stores all six fields atomically",
         Coyote_App_Tests.Test_State_Session_Stats_Round_Trip'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Set_Session_Stats with zeros resets all fields",
         Coyote_App_Tests.Test_State_Session_Stats_Reset'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State cost fields are independent of per-turn token counts",
         Coyote_App_Tests.Test_State_Cost_Independent_Of_Tokens'Access));
      Result.Add_Test (App_State_Caller.Create
        ("JSON_Scalar_Image: string value returned without quotes",
         Coyote_App_Tests.Test_JSON_Scalar_String'Access));
      Result.Add_Test (App_State_Caller.Create
        ("JSON_Scalar_Image: integer value serialised as numeric string",
         Coyote_App_Tests.Test_JSON_Scalar_Integer'Access));
      Result.Add_Test (App_State_Caller.Create
        ("JSON_Scalar_Image: negative integer serialised correctly",
         Coyote_App_Tests.Test_JSON_Scalar_Negative_Integer'Access));
      Result.Add_Test (App_State_Caller.Create
        ("JSON_Scalar_Image: boolean true serialises to ""true""",
         Coyote_App_Tests.Test_JSON_Scalar_Boolean_True'Access));
      Result.Add_Test (App_State_Caller.Create
        ("JSON_Scalar_Image: boolean false serialises to ""false""",
         Coyote_App_Tests.Test_JSON_Scalar_Boolean_False'Access));
      Result.Add_Test (App_State_Caller.Create
        ("JSON_Scalar_Image: float value serialises to non-empty string",
         Coyote_App_Tests.Test_JSON_Scalar_Float'Access));
      Result.Add_Test (App_State_Caller.Create
        ("JSON_Scalar_Image: null value returns ""...""",
         Coyote_App_Tests.Test_JSON_Scalar_Null'Access));
      Result.Add_Test (App_State_Caller.Create
        ("JSON_Scalar_Image: object value returns ""...""",
         Coyote_App_Tests.Test_JSON_Scalar_Object'Access));
      Result.Add_Test (App_State_Caller.Create
        ("JSON_Scalar_Image: array value returns ""...""",
         Coyote_App_Tests.Test_JSON_Scalar_Array'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State One_Shot_Result initial value is empty",
         Coyote_App_Tests.Test_One_Shot_Result_Initial'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State One_Shot_Result first-write-wins",
         Coyote_App_Tests.Test_One_Shot_Result_First_Write_Wins'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Tool_Field: single-line value returns border + label + value",
         Coyote_App_Tests.Test_Format_Tool_Field_Single_Line'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Tool_Field: two-line value carries border on both lines",
         Coyote_App_Tests.Test_Format_Tool_Field_Two_Lines'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Tool_Field: three-line value carries border on every line",
         Coyote_App_Tests.Test_Format_Tool_Field_Three_Lines'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Tool_Field: trailing LF produces empty continuation line",
         Coyote_App_Tests.Test_Format_Tool_Field_Trailing_LF'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Tool_Field: empty value returns border + label only",
         Coyote_App_Tests.Test_Format_Tool_Field_Empty_Value'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Tool_Field: value over Max_Len is truncated with ellipsis",
         Coyote_App_Tests.Test_Format_Tool_Field_Truncation'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Tool_Segment line count: LF-count + 1 = display lines",
         Coyote_App_Tests.Test_Tool_Segment_Line_Count'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_SI_Count: values below 1000 returned as decimal",
         Coyote_App_Tests.Test_Format_SI_Count_Below_Threshold'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_SI_Count: exact multiples of 1000 use ""k"" suffix",
         Coyote_App_Tests.Test_Format_SI_Count_Round_Numbers'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_SI_Count: non-zero hundredths produce ""N.FFk"" form",
         Coyote_App_Tests.Test_Format_SI_Count_Fractional'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_SI_Count: values >= 1 000 000 use ""M"" suffix",
         Coyote_App_Tests.Test_Format_SI_Count_M_Range'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Cost: 0 dmil -> ""$0.0000""",
         Coyote_App_Tests.Test_Format_Cost_Zero'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Cost: sub-dollar values zero-pad fractional digits",
         Coyote_App_Tests.Test_Format_Cost_Fractional'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Cost: values >= 10000 dmil have non-zero dollar part",
         Coyote_App_Tests.Test_Format_Cost_Dollars'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Model_Price: all zeros returns empty string",
         Coyote_App_Tests.Test_Format_Model_Price_All_Zeros'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Model_Price: in/out only produces two SI Âµ segments",
         Coyote_App_Tests.Test_Format_Model_Price_In_Out_Only'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Model_Price: all four fields, four SI-prefixed segments",
         Coyote_App_Tests.Test_Format_Model_Price_All_Four'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Model_Price: zero cache fields are silently omitted",
         Coyote_App_Tests.Test_Format_Model_Price_Omits_Zeros'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Model_Price: cache-read-only produces nano cr segment",
         Coyote_App_Tests.Test_Format_Model_Price_Cache_Only'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_DB_Price: representative values use $/tok",
         Coyote_App_Tests.Test_Format_DB_Price_Representative'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_DB_Price: free and negative values",
         Coyote_App_Tests.Test_Format_DB_Price_Free_And_Negative'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Get_Cost_Dmil: JSON float converted to dmil units",
         Coyote_App_Tests.Test_Get_Cost_Dmil_Float_Value'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Get_Cost_Dmil: JSON float 0.0 returns 0",
         Coyote_App_Tests.Test_Get_Cost_Dmil_Zero_Float'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Get_Cost_Dmil: JSON integer 0 returns 0",
         Coyote_App_Tests.Test_Get_Cost_Dmil_Integer_Zero'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Get_Cost_Dmil: absent field returns 0",
         Coyote_App_Tests.Test_Get_Cost_Dmil_Absent_Field'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Get_Cost_Dmil: negative float returns 0",
         Coyote_App_Tests.Test_Get_Cost_Dmil_Negative_Float'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Status: empty state produces ""* ready""",
         Coyote_App_Tests.Test_Format_Status_Default'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Status: Extra argument reflected verbatim",
         Coyote_App_Tests.Test_Format_Status_Custom_Extra'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Status: model shown as ""[provider/model]""",
         Coyote_App_Tests.Test_Format_Status_With_Model'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Status: session ID shows first 8 chars",
         Coyote_App_Tests.Test_Format_Status_With_Session'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Status: token/context window shown as ""Nk/Mk""",
         Coyote_App_Tests.Test_Format_Status_With_Context'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Status: thinking level shown as "" ~level""",
         Coyote_App_Tests.Test_Format_Status_With_Thinking'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Status: sandbox profile shown as ""[profile]""",
         Coyote_App_Tests.Test_Format_Status_With_Sandbox'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Apply_Prompt_Filter: empty filter returns raw unchanged",
         Coyote_App_Tests.Test_Apply_Filter_Empty_Filter'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Apply_Prompt_Filter: cat filter echoes prompt back",
         Coyote_App_Tests.Test_Apply_Filter_Echo'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Apply_Prompt_Filter: tr filter transforms prompt to uppercase",
         Coyote_App_Tests.Test_Apply_Filter_Transform'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Apply_Prompt_Filter: non-zero exit falls back to raw with warning",
         Coyote_App_Tests.Test_Apply_Filter_Non_Zero_Exit'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Apply_Prompt_Filter: empty stdout falls back to raw with warning",
         Coyote_App_Tests.Test_Apply_Filter_Empty_Output'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Apply_Prompt_Filter: output is trimmed of surrounding whitespace",
         Coyote_App_Tests.Test_Apply_Filter_Trims_Whitespace'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Prompt_Filter initial value is empty",
         Coyote_App_Tests.Test_State_Prompt_Filter_Initial'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Prompt_Filter round-trip via Set_Prompt_Filter",
         Coyote_App_Tests.Test_State_Prompt_Filter_Round_Trip'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Is_Paused initial value is False",
         Coyote_App_Tests.Test_State_Is_Paused_Initial'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Is_Paused toggles via Set_Paused",
         Coyote_App_Tests.Test_State_Is_Paused_Set_And_Clear'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Is_Pause_Armed initial value is False",
         Coyote_App_Tests.Test_State_Is_Pause_Armed_Initial'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Is_Pause_Armed toggles via Set_Pause_Armed",
         Coyote_App_Tests.Test_State_Is_Pause_Armed_Set_And_Clear'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Current_Sandbox initial value is empty",
         Coyote_App_Tests.Test_State_Sandbox_Initial'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Current_Sandbox round-trip via Set_Sandbox",
         Coyote_App_Tests.Test_State_Sandbox_Round_Trip'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Set_Sandbox to empty clears the profile",
         Coyote_App_Tests.Test_State_Sandbox_Clear'Access));
      Result.Add_Test (App_State_Caller.Create
        ("GFM cmark: table input produces node with type_string 'table'",
         Coyote_App_Tests.Test_Cmark_GFM_Table_Parsed'Access));
      Result.Add_Test (App_State_Caller.Create
        ("GFM cmark: paragraph still has type_string 'paragraph'",
         Coyote_App_Tests.Test_Cmark_Paragraph_Type_String'Access));

      return Result;
   end Suite;

end Coyote_App_Tests;
