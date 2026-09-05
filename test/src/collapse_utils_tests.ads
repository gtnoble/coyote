with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Collapse_Utils_Tests is
   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Collapse_Basic               (T : in out Test);
   procedure Test_Collapse_Paragraph           (T : in out Test);
   procedure Test_Collapse_Empty               (T : in out Test);
   procedure Test_Collapse_NoLF                (T : in out Test);
   procedure Test_Collapse_Leading_Trailing_WS (T : in out Test);
   procedure Test_Collapse_Preserves_Spaces    (T : in out Test);
   procedure Test_Collapse_OpenAI_Style        (T : in out Test);
   procedure Test_Collapse_OpenAI_Mid_Stream   (T : in out Test);
   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Collapse_Utils_Tests;
