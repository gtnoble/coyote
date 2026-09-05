--  Canonical AUnit domain suite for the Core tests.
--
--  Project: coyote

with AUnit.Test_Suites;

package Test_Core_Suite is
   function Suite return AUnit.Test_Suites.Access_Test_Suite;
end Test_Core_Suite;
