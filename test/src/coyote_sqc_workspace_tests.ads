--  Coyote_SQC.Workspace — AUnit test suite.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;

package Coyote_SQC_Workspace_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Round_Trip          (T : in out Test);
   procedure Test_Version_Too_High    (T : in out Test);
   procedure Test_Missing_Version     (T : in out Test);
   procedure Test_UUID_Deduplication  (T : in out Test);
   procedure Test_New_UUID_Format     (T : in out Test);
   procedure Test_New_UUID_Unique     (T : in out Test);

end Coyote_SQC_Workspace_Tests;
