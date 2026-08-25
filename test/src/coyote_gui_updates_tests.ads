--  Coyote_GUI_Updates_Tests — unit tests for GTK update queue wakeups.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;

package Coyote_GUI_Updates_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_First_Enqueue_Wakes_Exactly_Once (T : in out Test);
   procedure Test_Pending_Enqueue_Does_Not_Duplicate_Wakeup (T : in out Test);
   procedure Test_Idle_Done_Keeps_Source_For_Pending_Work (T : in out Test);
   procedure Test_Idle_Done_Clears_Source_When_Empty (T : in out Test);
   procedure Test_Enqueue_Rearms_After_Idle_Done (T : in out Test);
   procedure Test_Stopped_Queue_Does_Not_Wake (T : in out Test);
   procedure Test_Footer_Summary_Round_Trips (T : in out Test);

end Coyote_GUI_Updates_Tests;
