with AUnit;
with AUnit.Test_Fixtures;

package LLM_Compaction_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Estimate_Tokens (T : in out Test);
   procedure Test_Estimate_Context_Tokens (T : in out Test);
   procedure Test_Should_Compact (T : in out Test);
   procedure Test_Find_Cut_Point (T : in out Test);
   procedure Test_Serialize_Conversation (T : in out Test);
   procedure Test_Full_Compaction_Candidate (T : in out Test);

end LLM_Compaction_Tests;
