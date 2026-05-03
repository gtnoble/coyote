with AUnit;
with AUnit.Test_Fixtures;

package LLM_OpenRouter_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Send_Adds_OpenRouter_Headers (T : in out Test);
   procedure Test_Send_Includes_Reasoning_Effort (T : in out Test);
   procedure Test_OpenRouter_Stale_Cache_Fetches_Live_Then_Sends
      (T : in out Test);
   procedure Test_OpenRouter_Settings_Api_Key_Fallback
      (T : in out Test);

end LLM_OpenRouter_Tests;
