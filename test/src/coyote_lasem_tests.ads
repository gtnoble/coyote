--  Coyote_Lasem_Tests — focused tests for the Lasem iTeX binding.
--
--  These tests do not require a GTK display.  They exercise Lasem through
--  Cairo image surfaces and are skipped when the local Lasem installation
--  is unavailable at link time.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;

package Coyote_Lasem_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Measure_Fraction (T : in out Test);
   procedure Test_Measure_Complex_Expression (T : in out Test);
   procedure Test_Invalid_Itex_Returns_Error (T : in out Test);

end Coyote_Lasem_Tests;
