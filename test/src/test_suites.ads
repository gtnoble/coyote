with AUnit.Test_Suites;
with Coyote_Cmark_Tests;
with Coyote_Utils_Tests;
with Dispatch_Tests;
with LLM_Compaction_Tests;
with LLM_Context_Tests;
with LLM_Skills_Tests;
with LLM_System_Prompt_Tests;

package Test_Suites is
   function Suite return AUnit.Test_Suites.Access_Test_Suite;
end Test_Suites;
