with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package LLM_OpenRouter_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Send_Adds_OpenRouter_Headers (T : in out Test);
   procedure Test_Send_Includes_Reasoning_Effort (T : in out Test);
   procedure Test_OpenRouter_Stale_Cache_Fetches_Live_Then_Sends
      (T : in out Test);
   procedure Test_OpenRouter_Settings_Api_Key_Fallback
      (T : in out Test);
   procedure Test_OpenRouter_Session_Id_Length (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end LLM_OpenRouter_Tests;
