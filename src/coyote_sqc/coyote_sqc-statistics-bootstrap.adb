--  Coyote_SQC.Statistics.Bootstrap body — percentile bootstrap.
--
--  Implementation notes:
--  - Ada.Numerics.Discrete_Random is instantiated with Integer and seeded
--    with the Seed parameter; the generator is local to Compute, so the
--    fixed seed guarantees reproducible output regardless of call order.
--  - Set_A and Set_B are passed as heap-backed vectors to avoid large
--    stack allocations when session counts are high.
--  - Sorted copies (Set_A_Sorted, Set_B_Sorted) are heap-backed vectors
--    sorted via LF_Sorting.Sort.
--  - Resample vectors (A_Star, B_Star) are heap-backed LF_Vectors.Vector
--    objects pre-filled with M/N zeros before the main loop and updated
--    in-place with Replace_Element on each resample iteration.  This
--    avoids all dynamic stack allocation regardless of session count.
--  - Bootstrap replicate arrays use Ada.Containers.Vectors (heap-backed)
--    to avoid stack pressure at B = 10 000 × 8 bytes × 3 = 240 KB.
--  - LF_Sorting.Sort (Generic_Sorting instantiation) is used for all
--    in-place sorts on both resampled vectors and sorted-copy vectors.
--
--  Project: coyote

with Ada.Containers;
with Ada.Numerics.Discrete_Random;
with Ada.Numerics.Long_Elementary_Functions;

package body Coyote_SQC.Statistics.Bootstrap is

   --  Use the shared heap-backed vector type from Data_Model so that
   --  Compute's parameters and internal containers have the same type.
   package LF_Vectors renames Coyote_SQC.Data_Model.Long_Float_Vectors;
   package LF_Sorting  is new LF_Vectors.Generic_Sorting;

   --  ── Random number generation ──────────────────────────────────────────

   package Int_Random is new Ada.Numerics.Discrete_Random (Integer);

   --  Return a uniform index in [1 .. N].
   --  Maps negative Random values to non-negative integers without
   --  overflow: Integer'First + 1 → Integer'Last, -1 → 0.
   function Rand_Index
     (Gen : in out Int_Random.Generator;
      N   :        Positive) return Positive
   is
      Raw : Integer := Int_Random.Random (Gen);
   begin
      if Raw < 0 then
         Raw := -(Raw + 1);
      end if;
      return (Raw mod N) + 1;
   end Rand_Index;

   --  ── Statistics helpers — vector forms ────────────────────────────────

   function Mean_Of (V : LF_Vectors.Vector) return Long_Float is
      Sum : Long_Float := 0.0;
   begin
      if V.Is_Empty then
         return 0.0;
      end if;
      for X of V loop
         Sum := Sum + X;
      end loop;
      return Sum / Long_Float (V.Length);
   end Mean_Of;

   function Std_Dev_Of (V : LF_Vectors.Vector) return Long_Float is
      N    : constant Natural := Natural (V.Length);
      M    : Long_Float;
      Sum  : Long_Float := 0.0;
      Diff : Long_Float;
   begin
      if N < 2 then
         return 0.0;
      end if;
      M := Mean_Of (V);
      for X of V loop
         Diff := X - M;
         Sum  := Sum + Diff * Diff;
      end loop;
      return Ada.Numerics.Long_Elementary_Functions.Sqrt
        (Sum / Long_Float (N - 1));
   end Std_Dev_Of;

   --  Return the median of an already-sorted vector.
   --  For even N returns the mean of the two central values.
   function Median_Sorted (V : LF_Vectors.Vector) return Long_Float is
      N   : constant Positive := Positive (V.Length);
      Mid : constant Positive := (N + 1) / 2;
   begin
      if N mod 2 = 0 then
         return (V (Mid) + V (Mid + 1)) / 2.0;
      else
         return V (Mid);
      end if;
   end Median_Sorted;

   --  ── Compute ───────────────────────────────────────────────────────────

   function Compute
     (Set_A : LF_Vectors.Vector;
      Set_B : LF_Vectors.Vector;
      B     : Positive := 10_000;
      Seed  : Integer  := 12_345) return Three_CI_Results
   is
      M : constant Natural := Natural (Set_A.Length);
      N : constant Natural := Natural (Set_B.Length);

      Invalid_All : constant Three_CI_Results :=
        (Mean_Diff   => (Valid => False, others => <>),
         Median_Diff => (Valid => False, others => <>),
         SD_Ratio    => (Valid => False, others => <>));

      Gen : Int_Random.Generator;

      --  Container-backed bootstrap replicate arrays (heap, no manual free).
      Mean_Boot : LF_Vectors.Vector;
      Med_Boot  : LF_Vectors.Vector;
      SD_Boot   : LF_Vectors.Vector;

      SD_Boot_NA : Natural := 0;

      --  Heap-backed resample vectors; pre-filled before the main loop,
      --  then overwritten in-place each iteration via Replace_Element.
      A_Star : LF_Vectors.Vector;
      B_Star : LF_Vectors.Vector;

      --  Heap-backed sorted copies of the original sets (for point-estimate
      --  median).  Vector assignment copies the content; LF_Sorting.Sort
      --  sorts in place without additional stack allocation.
      Set_A_Sorted : LF_Vectors.Vector := Set_A;
      Set_B_Sorted : LF_Vectors.Vector := Set_B;

      --  Point estimates.
      Pt_Mean_Diff   : Long_Float;
      Pt_Median_Diff : Long_Float;
      Pt_SD_A        : Long_Float;
      Pt_SD_Ratio    : Long_Float;
      SD_Ratio_Valid : Boolean;

      Lo     : Positive;
      Hi     : Positive;
      Result : Three_CI_Results;
   begin
      --  Guard: minimum 2 observations in both sets.
      if M < 2 or else N < 2 then
         return Invalid_All;
      end if;

      --  Pre-allocate replicate vectors to avoid reallocation in the loop.
      Mean_Boot.Reserve_Capacity (Ada.Containers.Count_Type (B));
      Med_Boot.Reserve_Capacity  (Ada.Containers.Count_Type (B));
      SD_Boot.Reserve_Capacity   (Ada.Containers.Count_Type (B));

      --  Pre-allocate and fill resample vectors with sentinel zeros; the
      --  main loop overwrites every element on each iteration.
      A_Star.Reserve_Capacity (Ada.Containers.Count_Type (M));
      B_Star.Reserve_Capacity (Ada.Containers.Count_Type (N));
      for J in 1 .. M loop
         A_Star.Append (0.0);
      end loop;
      for J in 1 .. N loop
         B_Star.Append (0.0);
      end loop;

      --  Seed the local generator (guarantees reproducibility per Seed).
      Int_Random.Reset (Gen, Seed);

      --  Compute plug-in point estimates from the original sets.
      LF_Sorting.Sort (Set_A_Sorted);
      LF_Sorting.Sort (Set_B_Sorted);

      Pt_Mean_Diff   := Mean_Of (Set_B) - Mean_Of (Set_A);
      Pt_Median_Diff :=
        Median_Sorted (Set_B_Sorted) - Median_Sorted (Set_A_Sorted);

      Pt_SD_A := Std_Dev_Of (Set_A);
      if Pt_SD_A = 0.0 then
         SD_Ratio_Valid := False;
         Pt_SD_Ratio    := 0.0;
      else
         SD_Ratio_Valid := True;
         Pt_SD_Ratio    := Std_Dev_Of (Set_B) / Pt_SD_A;
      end if;

      --  Bootstrap resample loop.
      for I in 1 .. B loop
         --  Draw M values with replacement from Set_A (1-based vector).
         for J in 1 .. M loop
            A_Star.Replace_Element
              (Positive (J), Set_A (Rand_Index (Gen, M)));
         end loop;
         --  Draw N values with replacement from Set_B (1-based vector).
         for J in 1 .. N loop
            B_Star.Replace_Element
              (Positive (J), Set_B (Rand_Index (Gen, N)));
         end loop;

         --  Sort in place (required for median; harmless for mean/SD).
         LF_Sorting.Sort (A_Star);
         LF_Sorting.Sort (B_Star);

         --  Compute bootstrap replicate statistics.
         Mean_Boot.Append (Mean_Of (B_Star) - Mean_Of (A_Star));
         Med_Boot.Append  (Median_Sorted (B_Star) - Median_Sorted (A_Star));

         declare
            SD_A_Star : constant Long_Float := Std_Dev_Of (A_Star);
            SD_B_Star : constant Long_Float := Std_Dev_Of (B_Star);
         begin
            if SD_A_Star = 0.0 then
               SD_Boot.Append (0.0);
               SD_Boot_NA  := SD_Boot_NA + 1;
            else
               SD_Boot.Append (SD_B_Star / SD_A_Star);
            end if;
         end;
      end loop;

      --  Sort the bootstrap replicate distributions to extract percentiles.
      LF_Sorting.Sort (Mean_Boot);
      LF_Sorting.Sort (Med_Boot);
      LF_Sorting.Sort (SD_Boot);

      --  Percentile indices (1-based, rounded).
      --  2.5th  percentile: round(0.025 × B), clamped to [1, B].
      --  97.5th percentile: round(0.975 × B), clamped to [1, B].
      Lo := Positive'Max (1, Integer (0.025 * Long_Float (B) + 0.5));
      Hi := Positive'Min (B, Integer (0.975 * Long_Float (B) + 0.5));

      --  Assemble result records.
      Result.Mean_Diff :=
        (Point_Estimate => Pt_Mean_Diff,
         Lower          => Mean_Boot (Lo),
         Upper          => Mean_Boot (Hi),
         Valid          => True);

      Result.Median_Diff :=
        (Point_Estimate => Pt_Median_Diff,
         Lower          => Med_Boot (Lo),
         Upper          => Med_Boot (Hi),
         Valid          => True);

      if not SD_Ratio_Valid or else SD_Boot_NA * 2 > B then
         Result.SD_Ratio := (Valid => False, others => <>);
      else
         Result.SD_Ratio :=
           (Point_Estimate => Pt_SD_Ratio,
            Lower          => SD_Boot (Lo),
            Upper          => SD_Boot (Hi),
            Valid          => True);
      end if;

      return Result;
   end Compute;

end Coyote_SQC.Statistics.Bootstrap;
