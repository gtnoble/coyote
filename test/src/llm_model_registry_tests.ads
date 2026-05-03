with AUnit;
with AUnit.Test_Fixtures;

package LLM_Model_Registry_Tests is

  type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

  procedure Test_GitHub_Copilot_Anthropic_Wire_Format (T : in out Test);
  procedure Test_GitHub_Copilot_OpenAI_Wire_Format (T : in out Test);
  procedure Test_GitHub_Copilot_Not_Found (T : in out Test);
  procedure Test_OpenRouter_Cost_Loaded (T : in out Test);
  procedure Test_OpenRouter_Default_Fallback (T : in out Test);
  procedure Test_Unknown_Provider_Not_Found (T : in out Test);
  procedure Test_Available_Models_Filtering (T : in out Test);
  procedure Test_Anthropic_Available_Models (T : in out Test);
  procedure Test_Available_Models_Sorted (T : in out Test);

end LLM_Model_Registry_Tests;
