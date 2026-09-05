with LLM_System_Prompt_Tests;
with LLM_Context_Tests;
with LLM_Skills_Tests;
with LLM_HTTP_Tests;
with LLM_Settings_Tests;
with LLM_Types_Tests;
with LLM_Compaction_Tests;
with LLM_Session_Store_Tests;
with LLM_SSE_Tests;
with LLM_Tools_Tests;
with LLM_OpenAI_Completions_Tests;
with LLM_OpenAI_Responses_Tests;
with LLM_Auth_Tests;
with LLM_Catalogue_Tests;
with LLM_OpenRouter_Tests;
with LLM_OpenRouter_Catalogue_Tests;
with LLM_Anthropic_Messages_Tests;
with LLM_GitHub_Copilot_Tests;
with LLM_Model_Registry_Tests;
with LLM_OpenCode_Go_Catalogue_Tests;
with LLM_Agent_Tests;
with LLM_Parallel_Tools_Tests;
with AUnit.Test_Suites;

package body Test_LLM_Suite is

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (LLM_System_Prompt_Tests.Suite);
      Result.Add_Test (LLM_Context_Tests.Suite);
      Result.Add_Test (LLM_Skills_Tests.Suite);
      Result.Add_Test (LLM_HTTP_Tests.Suite);
      Result.Add_Test (LLM_Settings_Tests.Suite);
      Result.Add_Test (LLM_Types_Tests.Suite);
      Result.Add_Test (LLM_Compaction_Tests.Suite);
      Result.Add_Test (LLM_Session_Store_Tests.Suite);
      Result.Add_Test (LLM_SSE_Tests.Suite);
      Result.Add_Test (LLM_Tools_Tests.Suite);
      Result.Add_Test (LLM_OpenAI_Completions_Tests.Suite);
      Result.Add_Test (LLM_OpenAI_Responses_Tests.Suite);
      Result.Add_Test (LLM_Auth_Tests.Suite);
      Result.Add_Test (LLM_Catalogue_Tests.Suite);
      Result.Add_Test (LLM_OpenRouter_Tests.Suite);
      Result.Add_Test (LLM_OpenRouter_Catalogue_Tests.Suite);
      Result.Add_Test (LLM_Anthropic_Messages_Tests.Suite);
      Result.Add_Test (LLM_GitHub_Copilot_Tests.Suite);
      Result.Add_Test (LLM_Model_Registry_Tests.Suite);
      Result.Add_Test (LLM_OpenCode_Go_Catalogue_Tests.Suite);
      Result.Add_Test (LLM_Agent_Tests.Suite);
      Result.Add_Test (LLM_Parallel_Tools_Tests.Suite);

      return Result;
   end Suite;

end Test_LLM_Suite;
