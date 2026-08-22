with AUnit;
with AUnit.Test_Fixtures;

package Model_Row_Match_Tests is
   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Empty_Query_Matches (T : in out Test);
   procedure Test_Whitespace_Query_Matches (T : in out Test);
   procedure Test_Name_Substring_Casefold (T : in out Test);
   procedure Test_Provider_Match (T : in out Test);
   procedure Test_Spec_Match (T : in out Test);
   procedure Test_No_Match (T : in out Test);
   procedure Test_Count_Unfiltered (T : in out Test);
   procedure Test_Count_Filtered (T : in out Test);
end Model_Row_Match_Tests;
