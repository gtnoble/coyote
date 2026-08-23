--  Coyote_GUI_Navigation_Tests — viewport navigation policy tests.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;

package Coyote_GUI_Navigation_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Line_Movement (T : in out Test);
   procedure Test_Page_Movement (T : in out Test);
   procedure Test_Top_Bottom_And_Clamp (T : in out Test);

end Coyote_GUI_Navigation_Tests;
