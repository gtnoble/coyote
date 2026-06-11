with AUnit;
with AUnit.Test_Fixtures;

package Collapse_Utils_Tests is
   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Collapse_Basic               (T : in out Test);
   procedure Test_Collapse_Paragraph           (T : in out Test);
   procedure Test_Collapse_Empty               (T : in out Test);
   procedure Test_Collapse_NoLF                (T : in out Test);
   procedure Test_Collapse_Leading_Trailing_WS (T : in out Test);
end Collapse_Utils_Tests;
