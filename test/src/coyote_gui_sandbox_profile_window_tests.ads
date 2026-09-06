--  Coyote_GUI_Sandbox_Profile_Window_Tests — sandbox profile manager tests.
--
--  Construction tests require a GTK display; state and backend tests do not.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Coyote_GUI_Sandbox_Profile_Window_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with record
      Display_Available : Boolean := False;
   end record;

   overriding procedure Set_Up (T : in out Test);

   procedure Test_Create_Is_Idempotent (T : in out Test);
   procedure Test_Path_Editors_Use_Tree_Views (T : in out Test);
   procedure Test_Profile_Name_Validation (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;
end Coyote_GUI_Sandbox_Profile_Window_Tests;
