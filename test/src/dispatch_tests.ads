--  Dispatch_Tests — integration tests for Coyote_App.Dispatch.
--
--  These tests require a running acme instance.  Each test creates a
--  temporary window, dispatches one or more native LLM.Events values via
--  Dispatch_Event, then reads the window body via 9P to verify output.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with AUnit;
with AUnit.Test_Fixtures;

package Dispatch_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  agent_start sets Is_Streaming and updates the status line.
   procedure Test_Dispatch_Agent_Start
     (T : in out Test);

   --  agent_end clears Is_Streaming and reverts the status line.
   procedure Test_Dispatch_Agent_End_Normal
     (T : in out Test);

   --  text_delta appends the delta text to the window body.
   procedure Test_Dispatch_Text_Delta
     (T : in out Test);

   --  thinking_delta prefixes lines with the box-drawing border character.
   procedure Test_Dispatch_Thinking_Delta
     (T : in out Test);

   --  tool_execution_start writes the tool header and sets Has_Tool_In_Turn.
   procedure Test_Dispatch_Tool_Start
     (T : in out Test);

   --  tool_execution_end (success) replaces the placeholder with a check.
   procedure Test_Dispatch_Tool_End_Success
     (T : in out Test);

   --  tool_execution_end (error) replaces the placeholder with a cross.
   procedure Test_Dispatch_Tool_End_Error
     (T : in out Test);

   --  message_end updates turn token counts and stop reason in App_State.
   procedure Test_Dispatch_Message_End_Tokens
     (T : in out Test);

   --  Session_Stats_Event triggers Append_Live_Turn_Footer when
   --  Pending_Stats is True.
   procedure Test_Dispatch_Session_Stats_Footer
     (T : in out Test);

   --  model_select updates Current_Model and Context_Window in App_State.
   procedure Test_Dispatch_Model_Select
     (T : in out Test);

   --  Session_Info_Event sets Session_Id and Current_Thinking in App_State.
   procedure Test_Dispatch_Session_Info
     (T : in out Test);

   --  auto_retry_start writes a retry notice and sets Is_Retrying.
   procedure Test_Dispatch_Auto_Retry_Start
     (T : in out Test);

   --  A complete text turn appends its footer only after session_stats.
   procedure Test_Dispatch_Full_Turn_Footer_Only_After_Session_Stats
     (T : in out Test);

   --  An aborted turn must not append the live turn footer.
   procedure Test_Dispatch_Aborted_Turn_No_Footer
     (T : in out Test);

   --  auto_retry_end clears Is_Retrying so a later normal turn can finish.
   procedure Test_Dispatch_Auto_Retry_End_Then_Normal_Turn
     (T : in out Test);

   --  auto_compaction start/end events leave dispatch state consistent.
   procedure Test_Dispatch_Auto_Compaction_Start_And_End
     (T : in out Test);

   --  agent_end with no text or tool output shows the no-response warning.
   procedure Test_Dispatch_Agent_End_No_Response_Shows_Error
     (T : in out Test);

end Dispatch_Tests;
