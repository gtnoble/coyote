--  Coyote_Signal_Shutdown_Tests — real signal shutdown lifecycle tests.
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Coyote_Signal_Shutdown_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Grace_Waits_For_Deadline (T : in out Test);
   procedure Test_Second_Signal_Escalates (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Coyote_Signal_Shutdown_Tests;
