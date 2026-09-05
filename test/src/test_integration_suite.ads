--  Canonical AUnit domain suite for the Integration tests.
--
--  Project: coyote

with AUnit.Test_Suites;

package Test_Integration_Suite is
   function Suite return AUnit.Test_Suites.Access_Test_Suite;
end Test_Integration_Suite;
