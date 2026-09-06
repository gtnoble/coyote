with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package LLM_Model_Registry_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_GitHub_Copilot_Anthropic_Wire_Format (T : in out Test);
   procedure Test_GitHub_Copilot_OpenAI_Wire_Format (T : in out Test);
   procedure Test_GitHub_Copilot_Default_Fallback (T : in out Test);
   procedure Test_OpenRouter_Cost_Loaded (T : in out Test);
   procedure Test_OpenRouter_Default_Fallback (T : in out Test);
   procedure Test_Unknown_Provider_Not_Found (T : in out Test);
   procedure Test_Available_Models_Filtering (T : in out Test);
   procedure Test_Anthropic_Available_Models (T : in out Test);
   procedure Test_Available_Models_Sorted (T : in out Test);
   procedure Test_OpenCode_Go_Wire_Format_Anthropic (T : in out Test);
   procedure Test_OpenCode_Go_Wire_Format_OpenAI (T : in out Test);
   procedure Test_OpenCode_Go_Wire_Format_Responses (T : in out Test);
   procedure Test_OpenCode_Go_Default_Fallback (T : in out Test);
   procedure Test_OpenCode_Go_Available_With_Key (T : in out Test);
   procedure Test_OpenAI_Default_Fallback (T : in out Test);
   procedure Test_OpenAI_Available_With_Key (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end LLM_Model_Registry_Tests;
