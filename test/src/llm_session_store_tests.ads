with AUnit;
with AUnit.Test_Fixtures;

package LLM_Session_Store_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_New_UUID_Format                 (T : in out Test);
   procedure Test_New_UUID_Unique                 (T : in out Test);
   procedure Test_Create_Session_Header           (T : in out Test);
   procedure Test_User_Round_Trip                 (T : in out Test);
   procedure Test_Assistant_Tool_Call             (T : in out Test);
   procedure Test_Assistant_Thinking_Text_Round_Trip
     (T : in out Test);
   procedure Test_Tool_Result_Round_Trip          (T : in out Test);
   procedure Test_Fork_Session_Native_Source      (T : in out Test);
   procedure Test_Load_Legacy_Pi_Envelope_Lines   (T : in out Test);
   procedure Test_Load_Skips_Malformed_Lines      (T : in out Test);
   procedure Test_Assistant_Usage_And_Stop_Reason_Persist
     (T : in out Test);
   procedure Test_Append_Compaction_Writes_Entry  (T : in out Test);
   procedure Test_Compaction_Summary_Not_Persisted
     (T : in out Test);
   procedure Test_Load_With_Compaction_Entry      (T : in out Test);
   procedure Test_Load_Without_Compaction_Unchanged
     (T : in out Test);
   procedure Test_Append_Then_Load_Round_Trip     (T : in out Test);

end LLM_Session_Store_Tests;
