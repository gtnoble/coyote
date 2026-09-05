--  Canonical AUnit domain suite for the SQC tests.
--
--  Project: coyote

with AUnit.Test_Suites;

package Test_SQC_Suite is
   function Suite return AUnit.Test_Suites.Access_Test_Suite;
end Test_SQC_Suite;
