--  Coyote_SQC_Histogram_Tests body.
--
--  Project: coyote

with AUnit.Assertions;
with Coyote_SQC.UI.Histogram_Canvas;

package body Coyote_SQC_Histogram_Tests is

   use AUnit.Assertions;
   use Coyote_SQC.UI.Histogram_Canvas;

   --  ── Freedman-Diaconis bin count ───────────────────────────────────────
   --
   --  Formula: h = 2 * IQR / n^(1/3),  k = ceil(range / h).
   --  Q1 and Q3 are computed by linear interpolation on the sorted array.

   --  n=2, uniform (1.0, 2.0):
   --    Q1 = 1.25, Q3 = 1.75, IQR = 0.5
   --    h  = 2*0.5 / 2^(1/3) = 1.0 / 1.2599 ≈ 0.794
   --    k  = ceil(1.0 / 0.794) = ceil(1.26) = 2 bins.
   procedure Test_Bins_N2 (T : in out Test) is
      pragma Unreferenced (T);
      Vals  : constant Long_Float_Array := (1.0, 2.0);
      N     : Positive;
      B_Min : Long_Float;
      B_Wid : Long_Float;
      Cnts  : Bin_Count_Array;
   begin
      Compute_Bins (Vals, N, B_Min, B_Wid, Cnts);
      Assert (N = 2, "FD n=2: should produce 2 bins, got" & N'Image);
   end Test_Bins_N2;

   --  n=8, uniform (1.0 .. 8.0):
   --    Q1 = 2.75, Q3 = 6.25, IQR = 3.5
   --    h  = 2*3.5 / 8^(1/3) = 7.0 / 2.0 = 3.5
   --    k  = ceil(7.0 / 3.5) = ceil(2.0) = 2 bins.
   procedure Test_Bins_N8 (T : in out Test) is
      pragma Unreferenced (T);
      Vals : Long_Float_Array (1 .. 8);
      N    : Positive;
      BMin : Long_Float;
      BWid : Long_Float;
      Cnts : Bin_Count_Array;
   begin
      for I in Vals'Range loop
         Vals (I) := Long_Float (I);
      end loop;
      Compute_Bins (Vals, N, BMin, BWid, Cnts);
      Assert (N = 2, "FD n=8 uniform: should produce 2 bins, got" & N'Image);
   end Test_Bins_N8;

   --  n=100, uniform (1.0 .. 100.0):
   --    Q1 = 25.75, Q3 = 75.25, IQR = 49.5
   --    h  = 2*49.5 / 100^(1/3) = 99 / 4.6416 ≈ 21.33
   --    k  = ceil(99 / 21.33) = ceil(4.64) = 5 bins.
   procedure Test_Bins_N100 (T : in out Test) is
      pragma Unreferenced (T);
      Vals : Long_Float_Array (1 .. 100);
      N    : Positive;
      BMin : Long_Float;
      BWid : Long_Float;
      Cnts : Bin_Count_Array;
   begin
      for I in Vals'Range loop
         Vals (I) := Long_Float (I);
      end loop;
      Compute_Bins (Vals, N, BMin, BWid, Cnts);
      Assert (N = 5, "FD n=100 uniform: should produce 5 bins, got" & N'Image);
   end Test_Bins_N100;

   --  ── IQR = 0 fallback ─────────────────────────────────────────────────

   --  When the middle 50% of values are all equal, IQR = 0 and FD is
   --  undefined.  The implementation falls back to a single bin.
   --
   --  Values (1.0, 1.0, 1.0, 1.0, 2.0):
   --    Sorted: [1, 1, 1, 1, 2]
   --    Q1: idx = 0.25*4 = 1.0 → Sorted(2) = 1.0   (exact index, no lerp)
   --    Q3: idx = 0.75*4 = 3.0 → Sorted(4) = 1.0   (exact index, no lerp)
   --    IQR = 0.0 → single-bin fallback.
   procedure Test_FD_IQR_Zero (T : in out Test) is
      pragma Unreferenced (T);
      Vals : constant Long_Float_Array := (1.0, 1.0, 1.0, 1.0, 2.0);
      N    : Positive;
      BMin : Long_Float;
      BWid : Long_Float;
      Cnts : Bin_Count_Array;
   begin
      Compute_Bins (Vals, N, BMin, BWid, Cnts);
      Assert (N = 1,
              "FD IQR=0: should fall back to 1 bin, got" & N'Image);
      Assert (Cnts (1) = 5,
              "FD IQR=0: all 5 values should be in bin 1, got"
              & Cnts (1)'Image);
   end Test_FD_IQR_Zero;

   --  ── Bin population ────────────────────────────────────────────────────

   --  4 uniform values in [0, 3]:
   --    Q1 = 0.75, Q3 = 2.25, IQR = 1.5
   --    h  = 2*1.5 / 4^(1/3) = 3.0 / 1.587 ≈ 1.89
   --    k  = ceil(3.0 / 1.89) = ceil(1.59) = 2 bins.
   --  Total count must equal input length.
   procedure Test_Bins_Uniform (T : in out Test) is
      pragma Unreferenced (T);
      Vals  : constant Long_Float_Array := (0.0, 1.0, 2.0, 3.0);
      N     : Positive;
      BMin  : Long_Float;
      BWid  : Long_Float;
      Cnts  : Bin_Count_Array;
      Total : Natural := 0;
   begin
      Compute_Bins (Vals, N, BMin, BWid, Cnts);
      Assert (N = 2, "FD n=4 uniform: expected 2 bins, got" & N'Image);
      for I in 1 .. N loop
         Total := Total + Cnts (I);
      end loop;
      Assert (Total = 4,
              "total count should equal input length, got" & Total'Image);
   end Test_Bins_Uniform;

   --  All values at the minimum end up in bin 1.
   procedure Test_Bins_All_In_First (T : in out Test) is
      pragma Unreferenced (T);
      Vals  : constant Long_Float_Array := (0.0, 0.5, 0.9, 5.0, 10.0);
      N     : Positive;
      BMin  : Long_Float;
      BWid  : Long_Float;
      Cnts  : Bin_Count_Array;
   begin
      Compute_Bins (Vals, N, BMin, BWid, Cnts);
      --  Bin_Min = 0.0, so value 0.0 falls in bin 1.
      Assert (BMin = 0.0, "Bin_Min should be 0.0");
      Assert (Cnts (1) >= 1, "bin 1 should contain at least value 0.0");
   end Test_Bins_All_In_First;

   --  Value exactly equal to the maximum ends up in the last bin.
   procedure Test_Bins_All_In_Last (T : in out Test) is
      pragma Unreferenced (T);
      Vals  : constant Long_Float_Array := (0.0, 5.0, 10.0);
      N     : Positive;
      BMin  : Long_Float;
      BWid  : Long_Float;
      Cnts  : Bin_Count_Array;
   begin
      Compute_Bins (Vals, N, BMin, BWid, Cnts);
      --  Value 10.0 == V_Max should be clamped to the last bin.
      Assert (Cnts (N) >= 1, "last bin should contain V_Max (10.0)");
   end Test_Bins_All_In_Last;

   --  ── Edge cases ────────────────────────────────────────────────────────

   --  All values equal: range = 0 → N_Bins = 1, Bin_Width = 1.0, count = N.
   procedure Test_Bins_All_Equal (T : in out Test) is
      pragma Unreferenced (T);
      Vals : constant Long_Float_Array := (5.0, 5.0, 5.0);
      N    : Positive;
      BMin : Long_Float;
      BWid : Long_Float;
      Cnts : Bin_Count_Array;
   begin
      Compute_Bins (Vals, N, BMin, BWid, Cnts);
      Assert (N = 1,      "all-equal: N_Bins should be 1, got" & N'Image);
      Assert (BWid = 1.0, "all-equal: Bin_Width should be 1.0");
      Assert (Cnts (1) = 3,
              "all-equal: count should be 3, got" & Cnts (1)'Image);
   end Test_Bins_All_Equal;

   --  Single value: N_Bins = 1, Bin_Width = 1.0, count = 1.
   procedure Test_Bins_N1 (T : in out Test) is
      pragma Unreferenced (T);
      Vals : constant Long_Float_Array := (1 => 42.0);
      N    : Positive;
      BMin : Long_Float;
      BWid : Long_Float;
      Cnts : Bin_Count_Array;
   begin
      Compute_Bins (Vals, N, BMin, BWid, Cnts);
      Assert (N = 1,      "n=1: N_Bins should be 1, got" & N'Image);
      Assert (BWid = 1.0, "n=1: Bin_Width should be 1.0");
      Assert (Cnts (1) = 1,
              "n=1: count should be 1, got" & Cnts (1)'Image);
      Assert (BMin = 42.0, "n=1: Bin_Min should equal the single value");
   end Test_Bins_N1;

end Coyote_SQC_Histogram_Tests;
