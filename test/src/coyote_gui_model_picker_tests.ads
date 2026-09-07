--  Coyote_GUI_Model_Picker_Tests — typed selection-result tests.
--
--  The modal GTK interaction remains display-backed qualification.

with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Coyote_GUI_Model_Picker_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Cancelled_Result (T : in out Test);
   procedure Test_Selected_Result (T : in out Test);
   procedure Test_Default_Result (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Coyote_GUI_Model_Picker_Tests;
