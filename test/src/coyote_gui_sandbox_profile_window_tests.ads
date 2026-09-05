--  Coyote_GUI_Sandbox_Profile_Window_Tests — sandbox profile manager tests.
--
--  Construction tests require a GTK display; state and backend tests do not.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;

package Coyote_GUI_Sandbox_Profile_Window_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with record
      Display_Available : Boolean := False;
   end record;

   overriding procedure Set_Up (T : in out Test);

   procedure Test_Create_Is_Idempotent (T : in out Test);
   procedure Test_Profile_Name_Validation (T : in out Test);

end Coyote_GUI_Sandbox_Profile_Window_Tests;
