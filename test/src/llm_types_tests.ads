with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

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

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end LLM_Types_Tests;
