with AUnit;
with AUnit.Test_Fixtures;

package LLM_Agent_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Single_Turn_Prompt               (T : in out Test);
   procedure Test_Tool_Call_Loop                   (T : in out Test);
   procedure Test_Two_Tool_Call_Loop               (T : in out Test);
   procedure Test_Tool_Execution_Failure           (T : in out Test);
   procedure Test_Switch_Session_Loads_History     (T : in out Test);
   procedure Test_Abort_Request                    (T : in out Test);
   procedure Test_Abort_Batched_Tools_Keep_History_Valid
     (T : in out Test);
   procedure Test_Abort_During_Shell_With_Timeout
     (T : in out Test);
   procedure Test_Session_File_Written_Only_After_Turn_End
     (T : in out Test);
   procedure Test_Session_Resume                   (T : in out Test);
   procedure Test_Create_Without_Model_Spec_Uses_Settings_Default
     (T : in out Test);
   procedure Test_Memory_Enabled_By_Env_Var (T : in out Test);
   procedure Test_Memory_Disabled_By_Default (T : in out Test);
   procedure Test_Multi_Turn_Same_Session_Carries_History
     (T : in out Test);
   procedure Test_Event_Sequence_Agent_Start_Through_Session_Stats
     (T : in out Test);
   procedure Test_Unknown_Tool_Becomes_Error_And_Agent_Continues
     (T : in out Test);
   procedure Test_Auto_Retry_On_HTTP_500_Then_Success
     (T : in out Test);
   procedure Test_Is_Context_Overflow_Error_Detects_Known_Phrases
     (T : in out Test);
   procedure Test_Overflow_Triggers_Compact_And_Retry
     (T : in out Test);
   procedure Test_Overflow_Recovery_Not_Attempted_Twice
     (T : in out Test);
   procedure Test_Overflow_Will_Retry_Event_Emitted
     (T : in out Test);
   procedure Test_Compact_Produces_Summary_Message
     (T : in out Test);
   procedure Test_Compact_Emits_Start_And_End_Events
     (T : in out Test);
   procedure Test_Compact_Short_History_Aborts
     (T : in out Test);
   procedure Test_Compact_Persists_Entry
     (T : in out Test);
   procedure Test_Auto_Compact_Fires_At_Threshold
     (T : in out Test);
   procedure Test_Auto_Compact_Does_Not_Fire_Below_Threshold
     (T : in out Test);
   procedure Test_Auto_Compact_Session_Persisted_After_Threshold
     (T : in out Test);
   procedure Test_Set_Compact_Settings_Disabled
     (T : in out Test);
   procedure Test_Compact_Then_Resume
     (T : in out Test);
   procedure Test_Compact_Live_Summarises_Conversation
     (T : in out Test);
   procedure Test_Tool_Result_Has_Stats_Footer
     (T : in out Test);
   procedure Test_Stats_Footer_Only_On_Last_Tool_In_Batch
     (T : in out Test);

   procedure Test_Image_Tool_Result_No_Footer (T : in out Test);

   --  Pause fires at the turn boundary: Agent_Paused_Event is emitted,
   --  the loop blocks, Resume unblocks it, and Agent_Resumed_Event is
   --  emitted before the run completes normally.
   procedure Test_Pause_Fires_At_Turn_Boundary (T : in out Test);

   --  Request_Abort while the loop is paused unblocks it and sets
   --  Was_Aborted on the Agent_End_Event.
   procedure Test_Stop_While_Paused (T : in out Test);

end LLM_Agent_Tests;
