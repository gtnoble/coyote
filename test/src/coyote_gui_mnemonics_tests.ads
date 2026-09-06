--  Coyote_GUI_Mnemonics_Tests — mnemonic context validation tests.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Coyote_GUI_Mnemonics_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Extracts_First_Mnemonic (T : in out Test);
   procedure Test_Ignores_Escaped_Underscores (T : in out Test);
   procedure Test_Rejects_Duplicate_Context_Key (T : in out Test);
   procedure Test_Allows_Key_In_Separate_Context (T : in out Test);
   procedure Test_Current_UI_Context_Allocations (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Coyote_GUI_Mnemonics_Tests;
