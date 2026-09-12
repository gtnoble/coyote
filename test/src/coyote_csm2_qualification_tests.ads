--  Coyote_CSM2_Qualification_Tests — consolidated CSM-2 qualification.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Coyote_CSM2_Qualification_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Grammar_And_Recovery_Matrix (T : in out Test);
   procedure Test_All_Delta_Boundaries_Preserve_Semantics (T : in out Test);
   procedure Test_UTF8_Boundaries_Preserve_Semantics (T : in out Test);
   procedure Test_Exact_End_Of_Stream_Flush (T : in out Test);
   procedure Test_Markdown_Semantics_Pango_Reference (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Coyote_CSM2_Qualification_Tests;
