--  Coyote_GUI_Mode_Tests — Agent-menu availability by run mode.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Coyote_GUI_Mode_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Agent_Actions_Follow_Run_Mode (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Coyote_GUI_Mode_Tests;
