--  Coyote_Help_Tests — tests for Yelp URI and availability logic.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Coyote_Help_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Root_URI (T : in out Test);
   procedure Test_Topic_URI (T : in out Test);
   procedure Test_Help_Data_Directory (T : in out Test);
   procedure Test_Yelp_Is_Available (T : in out Test);
   procedure Test_Product_Information_Text (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Coyote_Help_Tests;
