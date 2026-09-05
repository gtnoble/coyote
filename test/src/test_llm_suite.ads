--  Canonical AUnit domain suite for the LLM tests.
--
--  Project: coyote

with AUnit.Test_Suites;

package Test_LLM_Suite is
   function Suite return AUnit.Test_Suites.Access_Test_Suite;
end Test_LLM_Suite;
