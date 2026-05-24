--  Coyote_SQC.UI.Histogram_Canvas — AUnit test suite.
--
--  Tests cover Compute_Bins: Freedman-Diaconis bin count, bin population,
--  degenerate inputs, and edge cases.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;

package Coyote_SQC_Histogram_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Freedman-Diaconis bin count.
   procedure Test_Bins_N2             (T : in out Test);
   procedure Test_Bins_N8             (T : in out Test);
   procedure Test_Bins_N100           (T : in out Test);

   --  IQR = 0 fallback.
   procedure Test_FD_IQR_Zero         (T : in out Test);

   --  Bin population.
   procedure Test_Bins_Uniform        (T : in out Test);
   procedure Test_Bins_All_In_First   (T : in out Test);
   procedure Test_Bins_All_In_Last    (T : in out Test);

   --  Edge cases.
   procedure Test_Bins_All_Equal      (T : in out Test);
   procedure Test_Bins_N1             (T : in out Test);

end Coyote_SQC_Histogram_Tests;
