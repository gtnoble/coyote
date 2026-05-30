--  Coyote_SQC_Integrity_Tests — AUnit test suite for
--  Coyote_SQC.Workspace.Integrity.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;

package Coyote_SQC_Integrity_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Check_All_Present       (T : in out Test);
   procedure Test_Check_Some_Missing      (T : in out Test);
   procedure Test_Check_All_Missing       (T : in out Test);
   procedure Test_Check_Empty_Setup       (T : in out Test);
   procedure Test_Remove_Missing_Partial  (T : in out Test);
   procedure Test_Remove_Missing_All      (T : in out Test);
   procedure Test_Remove_Missing_None     (T : in out Test);

end Coyote_SQC_Integrity_Tests;
