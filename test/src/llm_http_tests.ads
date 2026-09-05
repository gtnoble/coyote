with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package LLM_HTTP_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Post_Status_And_Chunk (T : in out Test);
   procedure Test_Get_Status_And_Chunk (T : in out Test);
   procedure Test_HTTP_Non_200_Returns_Status_And_Body (T : in out Test);
   procedure Test_HTTP_Abort_During_Stalled_Response (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end LLM_HTTP_Tests;
