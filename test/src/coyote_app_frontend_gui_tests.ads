--  Coyote_App_Frontend_GUI_Tests — native GTK top-level layout tests.
--
--  The construction test requires a GTK display and is skipped otherwise.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;
with Coyote_App.Frontend.GUI;

package Coyote_App_Frontend_GUI_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with record
      Display_Available : Boolean := False;
      Frontend          : Coyote_App.Frontend.GUI.Instance;
   end record;

   overriding procedure Set_Up (T : in out Test);
   overriding procedure Tear_Down (T : in out Test);

   procedure Test_Layout_And_Shutdown_Lifecycle
     (T : in out Test);

   procedure Test_Product_Information_Icon
     (T : in out Test);

end Coyote_App_Frontend_GUI_Tests;
