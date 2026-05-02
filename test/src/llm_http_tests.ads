with AUnit;
with AUnit.Test_Fixtures;

package LLM_HTTP_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Post_Status_And_Chunk (T : in out Test);
   procedure Test_Get_Status_And_Chunk (T : in out Test);

end LLM_HTTP_Tests;
