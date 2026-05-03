with AUnit;
with AUnit.Test_Fixtures;

package LLM_Spawn_Subagent_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Bad_Json (T : in out Test);
   procedure Test_Empty_Prompt (T : in out Test);
   procedure Test_Binary_Not_Found (T : in out Test);
   procedure Test_Abort_Before_Spawn (T : in out Test);

end LLM_Spawn_Subagent_Tests;
