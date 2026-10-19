with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Coyote_App.Frontend.GUI.Help_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with record
      Display_Available : Boolean := False;
   end record;

   overriding procedure Set_Up (T : in out Test);
   overriding procedure Tear_Down (T : in out Test);

   procedure Test_Help_Menu_And_Product_Information (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Coyote_App.Frontend.GUI.Help_Tests;
