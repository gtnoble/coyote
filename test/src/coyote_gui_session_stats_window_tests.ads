--  Coyote_GUI_Session_Stats_Window_Tests — session statistics window tests.
--
--  Snapshot and clear tests are display-independent.  The construction test
--  is skipped when no GTK display is available.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;

package Coyote_GUI_Session_Stats_Window_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with record
      Display_Available : Boolean := False;
   end record;

   overriding procedure Set_Up (T : in out Test);

   procedure Test_Snapshot_Round_Trip (T : in out Test);
   procedure Test_Clear_Resets_Snapshot (T : in out Test);
   procedure Test_Create_Is_Idempotent (T : in out Test);

end Coyote_GUI_Session_Stats_Window_Tests;
