--  Coyote_App_Frontend_GUI_Tests — native GTK top-level layout tests.
--
--  The construction test requires a GTK display and is skipped otherwise.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;
with Coyote_App.Frontend.GUI;

package Coyote_App_Frontend_GUI_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with record
      Display_Available : Boolean := False;
   end record;

   overriding procedure Set_Up (T : in out Test);
   overriding procedure Tear_Down (T : in out Test);

   procedure Test_Layout_And_Shutdown_Lifecycle
     (T : in out Test);

   procedure Test_Agent_Tree_Expands_New_Subagents
     (T : in out Test);

   procedure Test_Product_Information_Icon
     (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Coyote_App_Frontend_GUI_Tests;
