--  Coyote_GUI_Prompt_Queue_Tests — typed preference queue coverage.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Coyote_GUI_Prompt_Queue_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Set_Preferences_Round_Trips (T : in out Test);
   procedure Test_Enqueue_Reports_Acceptance (T : in out Test);
   procedure Test_Target_Agent_Id_Round_Trips (T : in out Test);
   procedure Test_Enqueue_Rejects_Overflow (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Coyote_GUI_Prompt_Queue_Tests;
