with AUnit;
with AUnit.Test_Fixtures;

package LLM_Types_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Text_Block (T : in out Test);
   procedure Test_Thinking_Block (T : in out Test);
   procedure Test_Tool_Call_Block (T : in out Test);
   procedure Test_Tool_Result_Block (T : in out Test);
   procedure Test_Compaction_Summary_Role (T : in out Test);
   procedure Test_Usage_Addition (T : in out Test);
   procedure Test_Message_Vectors (T : in out Test);

   procedure Test_Tool_Result_Block_Media_Type (T : in out Test);

end LLM_Types_Tests;
