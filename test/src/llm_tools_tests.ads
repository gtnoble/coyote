with AUnit;
with AUnit.Test_Fixtures;

package LLM_Tools_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Bash_Success (T : in out Test);
   procedure Test_Bash_Failure (T : in out Test);
   procedure Test_Read (T : in out Test);
   procedure Test_Write (T : in out Test);
   procedure Test_Edit_Unique (T : in out Test);
   procedure Test_Edit_Non_Unique (T : in out Test);
   procedure Test_Edit_Missing (T : in out Test);
   procedure Test_Find (T : in out Test);
   procedure Test_Built_In_Tools_Include_Spawn_Subagent
     (T : in out Test);
   procedure Test_Spawn_Subagent_Success (T : in out Test);
   procedure Test_Spawn_Subagent_Requires_Prompt (T : in out Test);

end LLM_Tools_Tests;
