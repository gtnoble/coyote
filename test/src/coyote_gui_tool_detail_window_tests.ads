--  Coyote_GUI_Tool_Detail_Window_Tests — tool detail widget tests.
--
--  GTK construction tests are skipped when no display is available.
--
--  Project: coyote

with AUnit.Test_Fixtures;
with AUnit.Test_Suites;
with Gtk.Window;

package Coyote_GUI_Tool_Detail_Window_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with record
      Display_Available : Boolean := False;
      Main_Window      : Gtk.Window.Gtk_Window;
   end record;

   overriding procedure Set_Up (T : in out Test);
   overriding procedure Tear_Down (T : in out Test);

   procedure Test_Stable_Layout_And_Snapshots (T : in out Test);
   procedure Test_Argument_Formatting_And_Empty_Values (T : in out Test);
   procedure Test_Image_Failure_Fallback (T : in out Test);
   procedure Test_Running_Snapshot_Is_Stable (T : in out Test);
   procedure Test_Successful_Image_Layout (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Coyote_GUI_Tool_Detail_Window_Tests;
