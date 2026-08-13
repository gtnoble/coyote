--  Coyote_Lasem_Tests — focused tests for the Lasem MathML binding.
--
--  These tests do not require a GTK display.  They exercise Lasem through
--  its Cairo-backed document view.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;

package Coyote_Lasem_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Measure_MathML_Fraction (T : in out Test);
   procedure Test_Measure_MathML_Matrix (T : in out Test);
   procedure Test_Measure_MathML_Relations (T : in out Test);
   procedure Test_Invalid_MathML_Returns_Error (T : in out Test);

end Coyote_Lasem_Tests;
