--  Canonical AUnit domain suite for the GUI tests.
--
--  Project: coyote

with AUnit.Test_Suites;

package Test_GUI_Suite is
   function Suite return AUnit.Test_Suites.Access_Test_Suite;
end Test_GUI_Suite;
