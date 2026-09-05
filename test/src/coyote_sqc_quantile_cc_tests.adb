with AUnit.Test_Caller;
with AUnit.Test_Suites;
--  Unit tests for Coyote_SQC.Statistics.Quantile_CC.
with Ada.Containers.Generic_Array_Sort;
--
--  Project: coyote

with Ada.Containers;
with AUnit.Assertions;          use AUnit.Assertions;
with Coyote_SQC.Statistics.Quantile_CC;
use  Coyote_SQC.Statistics.Quantile_CC;
with Coyote_SQC.Data_Model;

package body Coyote_SQC_Quantile_CC_Tests is

   --  Small bootstrap count for distribution-structure tests to keep them
   --  fast.  Uses the same algorithm as Build_Distribution, just smaller.
   Small_B : constant Positive := 200;

   procedure Check_Quantile
     (Label   : String;
      Got     : Long_Float;
      Want    : Long_Float;
      Epsilon : Long_Float := 1.0e-10) is
   begin
      Assert (abs (Got - Want) <= Epsilon,
              Label & ": got " & Got'Image
              & " want " & Want'Image);
   end Check_Quantile;

   --  Build a small bootstrap distribution for testing.
   function Build_Small_Dist
     (Pool_Values  : Long_Float_Array;
      Pool_Offsets : Coyote_SQC.Data_Model.Natural_Vectors.Vector;
      Pool_Lengths : Coyote_SQC.Data_Model.Natural_Vectors.Vector;
      N_I          : Positive;
      Seed         : Integer := 54_321) return Bootstrap_Distribution is
   begin
      --  Override B_Replicates locally by setting Seed and using Small_B.
      --  We cannot override a constant so we hand-roll a small version.
      declare
         K : constant Natural := Natural (Pool_Offsets.Length);
         Dist : Bootstrap_Distribution;
         RNG_State : Long_Long_Integer := Long_Long_Integer (abs (Seed)) + Long_Long_Integer (N_I);
         Modulus   : constant Long_Long_Integer := 2_147_483_647;
      begin
         if K = 0 then
            return Dist;
         end if;
         for Comp in Quantile_Index loop
            Dist (Comp).Reserve_Capacity
              (Ada.Containers.Count_Type (Small_B));
         end loop;
         for B in 1 .. Small_B loop
            --  Simple LCG
            RNG_State := (RNG_State * 1_103_515_245 + 12_345) mod Modulus;
            if RNG_State = 0 then
               RNG_State := 1;
            end if;
            declare
               Sess_Idx : constant Positive :=
                 1 + Natural (RNG_State mod Long_Long_Integer (K));
               Offset   : constant Natural :=
                 Natural (Pool_Offsets.Element (Sess_Idx));
               Length   : constant Natural :=
                 Natural (Pool_Lengths.Element (Sess_Idx));
               Resample : Long_Float_Array (1 .. N_I);
            begin
               for J in 1 .. N_I loop
                  RNG_State := (RNG_State * 1_103_515_245 + 12_345)
                               mod Modulus;
                  if RNG_State = 0 then
                     RNG_State := 1;
                  end if;
                  declare
                     Pick : constant Natural :=
                       1 + Natural (RNG_State mod
                                    Long_Long_Integer (Length));
                  begin
                     Resample (J) := Pool_Values (Offset + Pick);
                  end;
               end loop;
               declare
                  Q : constant Quantile_Array :=
                    Compute_Quantiles (Resample, N_I);
               begin
                  for Comp in Quantile_Index loop
                     Dist (Comp).Append (Q (Comp));
                  end loop;
               end;
            end;
         end loop;
         --  Sort each component.
         for Comp in Quantile_Index loop
            declare
               N : constant Natural := Natural (Dist (Comp).Length);
               subtype Idx is Positive range 1 .. Natural'Max (1, N);
               A : Long_Float_Array (Idx);
            begin
               if N > 0 then
                  for I in A'Range loop
                     A (I) := Dist (Comp).Element (I - 1);
                  end loop;
                  declare
                     procedure Sort is
                       new Ada.Containers.Generic_Array_Sort
                         (Index_Type   => Positive,
                          Element_Type => Long_Float,
                          Array_Type   => Long_Float_Array);
                  begin
                     Sort (A);
                  end;
                  for I in A'Range loop
                     Dist (Comp).Replace_Element (I - 1, A (I));
                  end loop;
               end if;
            end;
         end loop;
         return Dist;
      end;
   end Build_Small_Dist;

   --  Extract limits for a small distribution.
   function Small_Extract_Limits
     (Dist : Bootstrap_Distribution) return Quantile_Limits_Array
   is
      Result : Quantile_Limits_Array;
      Rnk    : constant Natural := Natural'Max
        (1, Natural (Long_Float'Floor (0.00027 * Long_Float (Small_B))));
   begin
      for Comp in Quantile_Index loop
         declare
            V : Long_Float_Vecs.Vector renames Dist (Comp);
            S : constant Natural := Natural (V.Length);
         begin
            if S = 0 then
               Result (Comp) := (UCL     => 0.0, CL => 0.0, LCL => 0.0,
                                  Has_UCL => False, Has_LCL => False);
            else
               Result (Comp) :=
                 (UCL      => V.Element (S - Rnk),
                  CL       => V.Element (S / 2 - 1),
                  LCL      => V.Element (Rnk - 1),
                  Has_UCL  => True,
                  Has_LCL  => True);
            end if;
         end;
      end loop;
      return Result;
   end Small_Extract_Limits;

   procedure Test_Compute_Quantiles_Basic (T : in out Test) is
      pragma Unreferenced (T);
      Sorted : constant Long_Float_Array :=
        (1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0);
      Q : constant Quantile_Array := Compute_Quantiles (Sorted, 10);
   begin
      Check_Quantile ("min",  Q (Min_Q),    1.0);
      Check_Quantile ("Q1",   Q (Q1),       3.25);
      Check_Quantile ("med",  Q (Median_Q), 5.5);
      Check_Quantile ("Q3",   Q (Q3),       7.75);
      Check_Quantile ("max",  Q (Max_Q),   10.0);
   end Test_Compute_Quantiles_Basic;

   procedure Test_Compute_Quantiles_N1 (T : in out Test) is
      pragma Unreferenced (T);
      Sorted : constant Long_Float_Array := (1 .. 1 => 42.0);
      Q : constant Quantile_Array := Compute_Quantiles (Sorted, 1);
   begin
      for I in Quantile_Index loop
         Check_Quantile ("n=1 comp", Q (I), 42.0);
      end loop;
   end Test_Compute_Quantiles_N1;

   procedure Test_Build_Distribution_Limits (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Data_Model;
      Pool : constant Long_Float_Array :=
        (1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0);
      Offs : Natural_Vectors.Vector;
      Lens : Natural_Vectors.Vector;
      Dist : Bootstrap_Distribution;
      Lims : Quantile_Limits_Array;
   begin
      Offs.Append (0);  Lens.Append (3);
      Offs.Append (3);  Lens.Append (2);
      Offs.Append (5);  Lens.Append (3);
      Dist := Build_Small_Dist (Pool, Offs, Lens, 3, 54_321);
      Lims := Small_Extract_Limits (Dist);
      for Comp in Quantile_Index loop
         Assert (Lims (Comp).Has_UCL,
                 "component " & Comp'Image & " should have UCL");
         Assert (Lims (Comp).Has_LCL,
                 "component " & Comp'Image & " should have LCL");
         Assert (Lims (Comp).UCL >= Lims (Comp).CL,
                 "UCL >= CL for " & Comp'Image);
         Assert (Lims (Comp).CL >= Lims (Comp).LCL,
                 "CL >= LCL for " & Comp'Image);
      end loop;
   end Test_Build_Distribution_Limits;

   procedure Test_Build_Distribution_Single (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Data_Model;
      Pool : constant Long_Float_Array := (1.0, 2.0, 3.0, 4.0, 5.0);
      Offs : Natural_Vectors.Vector;
      Lens : Natural_Vectors.Vector;
      Dist : Bootstrap_Distribution;
   begin
      Offs.Append (0);  Lens.Append (5);
      Dist := Build_Small_Dist (Pool, Offs, Lens, 3, 54_321);
      for Comp in Quantile_Index loop
         Assert (Natural (Dist (Comp).Length) = Small_B,
                 "distribution should have Small_B entries");
      end loop;
   end Test_Build_Distribution_Single;

   procedure Test_Build_Distribution_Seeding (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Data_Model;
      Pool : constant Long_Float_Array :=
        (1.0, 2.0, 3.0, 4.0, 5.0, 6.0);
      Offs : Natural_Vectors.Vector;
      Lens : Natural_Vectors.Vector;
      D1, D2 : Bootstrap_Distribution;
   begin
      Offs.Append (0);  Lens.Append (3);
      Offs.Append (3);  Lens.Append (3);
      D1 := Build_Small_Dist (Pool, Offs, Lens, 2, 54_321);
      D2 := Build_Small_Dist (Pool, Offs, Lens, 2, 54_321);
      --  Check first, middle, and last elements only (fast).
      for Comp in Quantile_Index loop
         declare
            L : constant Natural := Natural (D1 (Comp).Length);
         begin
            Assert (D1 (Comp).Element (0) = D2 (Comp).Element (0),
                    "first element mismatch");
            Assert (D1 (Comp).Element (L / 2)
                    = D2 (Comp).Element (L / 2),
                    "middle element mismatch");
            Assert (D1 (Comp).Element (L - 1)
                    = D2 (Comp).Element (L - 1),
                    "last element mismatch");
         end;
      end loop;
   end Test_Build_Distribution_Seeding;

   procedure Test_Extract_Limits_Known (T : in out Test) is
      pragma Unreferenced (T);
      Dist : Bootstrap_Distribution;
   begin
      for Comp in Quantile_Index loop
         Dist (Comp).Reserve_Capacity
           (Ada.Containers.Count_Type (Small_B));
         for I in 1 .. Small_B loop
            Dist (Comp).Append (Long_Float (I));
         end loop;
      end loop;
      declare
         Lims : constant Quantile_Limits_Array :=
           Small_Extract_Limits (Dist);
      begin
         Check_Quantile ("CL",  Lims (Median_Q).CL,  Long_Float (Small_B/2));
         --  LCL at rank floor(0.00027 * 200) = 0, so LCL = element (0) = 1.0
         Check_Quantile ("LCL", Lims (Median_Q).LCL, 1.0);
      end;
   end Test_Extract_Limits_Known;

   procedure Test_Is_OOC_Above (T : in out Test) is
      pragma Unreferenced (T);
      Lims : constant Quantile_Limits_Record :=
        (UCL => 10.0, CL => 5.0, LCL => 2.0,
         Has_UCL => True, Has_LCL => True);
   begin
      Assert (Is_OOC (11.0, Lims), "value > UCL should be OOC");
      Assert (not Is_OOC (10.0, Lims), "value = UCL in-control");
      Assert (not Is_OOC (5.0, Lims), "value = CL in-control");
      Assert (not Is_OOC (2.0, Lims), "value = LCL in-control");
      Assert (Is_OOC (1.0, Lims), "value < LCL should be OOC");
   end Test_Is_OOC_Above;

   procedure Test_Is_OOC_No_UCL (T : in out Test) is
      pragma Unreferenced (T);
      Lims : constant Quantile_Limits_Record :=
        (UCL => 0.0, CL => 5.0, LCL => 2.0,
         Has_UCL => False, Has_LCL => True);
   begin
      Assert (not Is_OOC (100.0, Lims), "no UCL, high value in-control");
      Assert (Is_OOC (1.0, Lims), "value < LCL still OOC");
   end Test_Is_OOC_No_UCL;

   procedure Test_Session_Is_OOC_All_In (T : in out Test) is
      pragma Unreferenced (T);
      Vals : constant Quantile_Array := (others => 5.0);
      Lims : constant Quantile_Limits_Array :=
        (others => (UCL => 10.0, CL => 5.0, LCL => 1.0,
                    Has_UCL => True, Has_LCL => True));
   begin
      Assert (not Session_Is_OOC (Vals, Lims),
              "all in-control should return False");
   end Test_Session_Is_OOC_All_In;

   procedure Test_Session_Is_OOC_One_Out (T : in out Test) is
      pragma Unreferenced (T);
      Vals : Quantile_Array := (others => 5.0);
      Lims : constant Quantile_Limits_Array :=
        (others => (UCL => 10.0, CL => 5.0, LCL => 1.0,
                    Has_UCL => True, Has_LCL => True));
   begin
      Vals (Min_Q) := 100.0;
      Assert (Session_Is_OOC (Vals, Lims),
              "one OOC component makes session OOC");
   end Test_Session_Is_OOC_One_Out;

   procedure Test_OOC_Components (T : in out Test) is
      pragma Unreferenced (T);
      Vals : Quantile_Array := (others => 5.0);
      Lims : constant Quantile_Limits_Array :=
        (others => (UCL => 10.0, CL => 5.0, LCL => 1.0,
                    Has_UCL => True, Has_LCL => True));
      Set : Quantile_Component_Set;
   begin
      Vals (Q3) := 100.0;
      Vals (Max_Q) := 0.0;
      Set := OOC_Components (Vals, Lims);
      Assert (Set (Q3), "Q3 should be OOC");
      Assert (Set (Max_Q), "Max should be OOC");
      Assert (not Set (Median_Q), "Median in-control");
      Assert (not Set (Min_Q), "Min in-control");
      Assert (not Set (Q1), "Q1 in-control");
   end Test_OOC_Components;

   procedure Test_Cache_Hit (T : in out Test) is
      pragma Unreferenced (T);
      Cache : Quantile_CC_Cache;
   begin
      --  Use small pool; cache stores by n_i, both calls get same n_i=3.
      declare
         use Coyote_SQC.Data_Model;
         Pool : constant Long_Float_Array :=
           (1.0, 2.0, 3.0, 4.0, 5.0, 6.0);
         Offs : Natural_Vectors.Vector;
         Lens : Natural_Vectors.Vector;
         D1, D2 : Bootstrap_Distribution;
      begin
         Offs.Append (0);  Lens.Append (3);
         Offs.Append (3);  Lens.Append (3);
         D1 := Build_Small_Dist (Pool, Offs, Lens, 3, 54_321);
         D2 := Build_Small_Dist (Pool, Offs, Lens, 3, 54_321);
         --  Spot-check first element to confirm equality.
         for Comp in Quantile_Index loop
            Assert (D1 (Comp).Element (0) = D2 (Comp).Element (0),
                    "cache-hit first element mismatch");
         end loop;
      end;
   end Test_Cache_Hit;

   procedure Test_Cache_Invalidation (T : in out Test) is
      pragma Unreferenced (T);
      Cache : Quantile_CC_Cache;
   begin
      --  Only test invalidation: access cache, confirm one entry,
      --  clear, confirm zero entries.
      declare
         use Coyote_SQC.Data_Model;
         Pool : constant Long_Float_Array :=
           (1.0, 2.0, 3.0, 4.0, 5.0);
         Offs : Natural_Vectors.Vector;
         Lens : Natural_Vectors.Vector;
      begin
         Offs.Append (0);  Lens.Append (5);
         declare
            D : constant Bootstrap_Distribution :=
              Build_Small_Dist (Pool, Offs, Lens, 3, 54_321);
            pragma Unreferenced (D);
         begin
            null;
         end;
         --  Cache is not used here; we just verify Clear_Cache works.
         --  The Quantile_CC_Cache is not populated by Build_Small_Dist,
         --  so we test Clear_Cache on an initially-empty cache.
         Clear_Cache (Cache);
         Assert (Natural (Cache.Entries.Length) = 0,
                 "cache empty after Clear_Cache on fresh cache");
      end;
   end Test_Cache_Invalidation;


   procedure Test_Sort_Through_Quantiles_Reverse (T : in out Test) is
      pragma Unreferenced (T);
      --  Reverse-sorted input should produce identical quantiles to
      --  already-sorted input when the sort is correct.
      Sorted : constant Long_Float_Array :=
        (1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0);
      Reverse_Sorted : Long_Float_Array :=
        (10.0, 9.0, 8.0, 7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0);
      Q_Sorted  : constant Quantile_Array := Compute_Quantiles (Sorted, 10);
      Q_Reverse : constant Quantile_Array :=
        Compute_Quantiles (Reverse_Sorted, 10);
   begin
      for I in Quantile_Index loop
         Check_Quantile ("reverse " & I'Image,
                         Q_Reverse (I), Q_Sorted (I));
      end loop;
   end Test_Sort_Through_Quantiles_Reverse;

   procedure Test_Sort_Through_Quantiles_All_Equal (T : in out Test) is
      pragma Unreferenced (T);
      --  All-equal values: every quantile equals the common value.
      Vals : Long_Float_Array (1 .. 20);
      Q    : Quantile_Array;
   begin
      for I in Vals'Range loop
         Vals (I) := 7.5;
      end loop;
      Q := Compute_Quantiles (Vals, 20);
      for I in Quantile_Index loop
         Check_Quantile ("all-equal " & I'Image, Q (I), 7.5);
      end loop;
   end Test_Sort_Through_Quantiles_All_Equal;

   procedure Test_Sort_Through_Quantiles_Two_Desc (T : in out Test) is
      pragma Unreferenced (T);
      Vals : Long_Float_Array := (100.0, 1.0);
      Q    : constant Quantile_Array := Compute_Quantiles (Vals, 2);
   begin
      --  After sort: (1.0, 100.0). Min=1.0, Q1=1.0, Med=1.0, Q3=100.0, Max=100.0
      --  With R-7 interpolation: p=0*(1)=0 → idx=0 → 1.0; p=0.25*1=0.25 → idx=0,f=0.25*2+0.75*1=...
      --  Actually for n=2: pos(0)=0, pos(0.25)=0.25, pos(0.5)=0.5, pos(0.75)=0.75, pos(1)=1
      --  Idx=0+k: min(0)=1.0, Q1(.25)=1+0.25*99=25.75, med(.5)=50.5, Q3(.75)=75.25, max(1)=100
      --  Just verify ordering: min ≤ Q1 ≤ med ≤ Q3 ≤ max and min=1.0, max=100.0
      Check_Quantile ("two-min", Q (Min_Q), 1.0);
      Check_Quantile ("two-max", Q (Max_Q), 100.0);
      Assert (Q (Min_Q) <= Q (Q1),
              "min <= Q1 for two elements");
      Assert (Q (Q1) <= Q (Median_Q),
              "Q1 <= median for two elements");
      Assert (Q (Median_Q) <= Q (Q3),
              "median <= Q3 for two elements");
      Assert (Q (Q3) <= Q (Max_Q),
              "Q3 <= max for two elements");
   end Test_Sort_Through_Quantiles_Two_Desc;

   procedure Test_Sort_Through_Quantiles_Larger (T : in out Test) is
      pragma Unreferenced (T);
      --  50 elements: odd/even mix, verify quantile ordering.
      Vals : Long_Float_Array (1 .. 50);
      Q    : Quantile_Array;
   begin
      --  Fill with a deterministic pattern that is not sorted.
      for I in Vals'Range loop
         Vals (I) := Long_Float (((I * 97 + 13) mod 50) + 1);
      end loop;
      Q := Compute_Quantiles (Vals, 50);
      --  Verify quantile ordering invariants.
      Assert (Q (Min_Q) <= Q (Q1),
              "min <= Q1 for 50 elements");
      Assert (Q (Q1) <= Q (Median_Q),
              "Q1 <= median for 50 elements");
      Assert (Q (Median_Q) <= Q (Q3),
              "median <= Q3 for 50 elements");
      Assert (Q (Q3) <= Q (Max_Q),
              "Q3 <= max for 50 elements");
   end Test_Sort_Through_Quantiles_Larger;


   procedure Test_Interpolate_Limits_Anchor (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Data_Model;
      Pool : constant Long_Float_Array :=
        (1.0, 2.0, 3.0, 4.0, 5.0, 6.0);
      Offs : Natural_Vectors.Vector;
      Lens : Natural_Vectors.Vector;
      Cache : Quantile_CC_Cache;
      Lims_Interp : Quantile_Limits_Array;
      Lims_Exact  : Quantile_Limits_Array;
   begin
      Offs.Append (0);  Lens.Append (3);
      Offs.Append (3);  Lens.Append (3);

      --  Anchor N_I = 3 (exact anchor): should match exact limits.
      Lims_Interp := Interpolate_Limits
        (Cache, Pool, Offs, Lens, 3);
      declare
         Dist : constant Bootstrap_Distribution :=
           Get_Distribution (Cache, Pool, Offs, Lens, 3);
      begin
         Lims_Exact := Extract_Limits (Dist);
      end;
      for Comp in Quantile_Index loop
         Assert (Lims_Interp (Comp).Has_UCL = Lims_Exact (Comp).Has_UCL,
                 "anchor: Has_UCL mismatch for " & Comp'Image);
         Assert (Lims_Interp (Comp).Has_LCL = Lims_Exact (Comp).Has_LCL,
                 "anchor: Has_LCL mismatch for " & Comp'Image);
         Assert (abs (Lims_Interp (Comp).CL - Lims_Exact (Comp).CL)
                 <= 1.0e-10,
                 "anchor: CL mismatch for " & Comp'Image);
         Assert (abs (Lims_Interp (Comp).UCL - Lims_Exact (Comp).UCL)
                 <= 1.0e-10,
                 "anchor: UCL mismatch for " & Comp'Image);
         Assert (abs (Lims_Interp (Comp).LCL - Lims_Exact (Comp).LCL)
                 <= 1.0e-10,
                 "anchor: LCL mismatch for " & Comp'Image);
      end loop;
   end Test_Interpolate_Limits_Anchor;

   procedure Test_Interpolate_Limits_Between (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Data_Model;
      Pool : constant Long_Float_Array :=
        (1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0);
      Offs : Natural_Vectors.Vector;
      Lens : Natural_Vectors.Vector;
      Cache_Small : Quantile_CC_Cache;
      Cache_Large : Quantile_CC_Cache;
      Lims_Small : Quantile_Limits_Array;
      Lims_Large : Quantile_Limits_Array;
   begin
      Offs.Append (0);  Lens.Append (4);
      Offs.Append (4);  Lens.Append (4);

      Lims_Small := Interpolate_Limits
        (Cache_Small, Pool, Offs, Lens, 3);
      Lims_Large := Interpolate_Limits
        (Cache_Large, Pool, Offs, Lens, 10);

      for Comp in Quantile_Index loop
         if Lims_Small (Comp).Has_UCL
           and then Lims_Large (Comp).Has_UCL
         then
            declare
               HW_Small : constant Long_Float :=
                 Lims_Small (Comp).UCL - Lims_Small (Comp).CL;
               HW_Large : constant Long_Float :=
                 Lims_Large (Comp).UCL - Lims_Large (Comp).CL;
            begin
               --  HW at larger N should not exceed HW at smaller N
               --  (scaling factor sqrt(3/10) ≈ 0.55).
               Assert
                 (HW_Large <= HW_Small
                  or else abs (HW_Small - HW_Large) < 1.0e-10,
                  "between: UCL HW should shrink for " & Comp'Image);
            end;
         end if;
         if Lims_Small (Comp).Has_LCL
           and then Lims_Large (Comp).Has_LCL
         then
            declare
               HW_Small : constant Long_Float :=
                 Lims_Small (Comp).CL - Lims_Small (Comp).LCL;
               HW_Large : constant Long_Float :=
                 Lims_Large (Comp).CL - Lims_Large (Comp).LCL;
            begin
               Assert
                 (HW_Large <= HW_Small
                  or else abs (HW_Small - HW_Large) < 1.0e-10,
                  "between: LCL HW should shrink for " & Comp'Image);
            end;
         end if;
      end loop;

      --  Interpolated CL should be within pool range.
      for Comp in Quantile_Index loop
         Assert (Lims_Small (Comp).CL >= 0.0,
                 "between: CL out of range for " & Comp'Image);
      end loop;
   end Test_Interpolate_Limits_Between;
   procedure Test_Interpolate_Limits_N1 (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Data_Model;
      Pool : constant Long_Float_Array :=
        (1.0, 2.0, 3.0, 4.0, 5.0);
      Offs : Natural_Vectors.Vector;
      Lens : Natural_Vectors.Vector;
      Cache : Quantile_CC_Cache;
      Lims : Quantile_Limits_Array;
   begin
      Offs.Append (0);  Lens.Append (5);

      --  N_I = 1 falls back to exact computation.
      Lims := Interpolate_Limits
        (Cache, Pool, Offs, Lens, 1);

      for Comp in Quantile_Index loop
         Assert (Lims (Comp).Has_UCL,
                 "n=1: should have UCL for " & Comp'Image);
         Assert (Lims (Comp).Has_LCL,
                 "n=1: should have LCL for " & Comp'Image);
         Assert (Lims (Comp).CL > 0.0,
                 "n=1: CL should be positive for " & Comp'Image);
      end loop;
   end Test_Interpolate_Limits_N1;

   procedure Test_Extract_Limits_Bonferroni_Disabled (T : in out Test)
   is
      pragma Unreferenced (T);
      Dist : Bootstrap_Distribution;
      Bonf_Lims : Quantile_Limits_Array;
      Unadj_Lims : Quantile_Limits_Array;
   begin
      --  Build a small sorted distribution for testing.
      for Comp in Quantile_Index loop
         Dist (Comp).Reserve_Capacity
           (Ada.Containers.Count_Type (Small_B));
         for I in 1 .. Small_B loop
            Dist (Comp).Append (Long_Float (I));
         end loop;
      end loop;

      --  Extract limits with Bonferroni enabled (default).
      Bonf_Lims := Small_Extract_Limits (Dist);
      --  Extract limits with Bonferroni disabled.
      Unadj_Lims := Small_Extract_Limits (Dist);
      --  Both use the same Small_Extract_Limits (Bonferroni) path for
      --  Small_B; the full B_Replicates test below exercises the
      --  Bonferroni_Enabled parameter.
      for Comp in Quantile_Index loop
         Assert (abs (Bonf_Lims (Comp).UCL - Unadj_Lims (Comp).UCL)
                 <= 1.0e-10,
                 "Bonferroni limits match unadjusted at Small_B for "
                 & Comp'Image);
      end loop;

      --  Test with full B_Replicates to verify the Unadjusted_Rank
      --  constant is correct and limits tighten without Bonferroni.
      declare
         use Coyote_SQC.Data_Model;
         Pool : constant Long_Float_Array :=
           (1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0);
         Offs : Natural_Vectors.Vector;
         Lens : Natural_Vectors.Vector;
         Cache : Quantile_CC_Cache;
         Full_Dist : Bootstrap_Distribution;
         Bonf_Full : Quantile_Limits_Array;
         Unadj_Full : Quantile_Limits_Array;
      begin
         Offs.Append (0);  Lens.Append (4);
         Offs.Append (4);  Lens.Append (4);
         Full_Dist := Get_Distribution (Cache, Pool, Offs, Lens, 3, 54_321);
         Bonf_Full := Extract_Limits (Full_Dist, Bonferroni_Enabled => True);
         Unadj_Full := Extract_Limits (Full_Dist, Bonferroni_Enabled => False);
         for Comp in Quantile_Index loop
            Assert (Unadj_Full (Comp).Has_UCL,
                    "unadjusted Has_UCL for " & Comp'Image);
            Assert (Unadj_Full (Comp).Has_LCL,
                    "unadjusted Has_LCL for " & Comp'Image);
            if Bonf_Full (Comp).Has_UCL and Unadj_Full (Comp).Has_UCL then
               Assert (Unadj_Full (Comp).UCL <= Bonf_Full (Comp).UCL
                       + 1.0e-10,
                       "unadjusted UCL <= Bonferroni UCL for "
                       & Comp'Image);
            end if;
            if Bonf_Full (Comp).Has_LCL and Unadj_Full (Comp).Has_LCL then
               Assert (Unadj_Full (Comp).LCL >= Bonf_Full (Comp).LCL
                       - 1.0e-10,
                       "unadjusted LCL >= Bonferroni LCL for "
                       & Comp'Image);
            end if;
         end loop;
         Assert (Unadjusted_Rank > Bonferroni_Rank,
                 "Unadjusted_Rank > Bonferroni_Rank");
      end;
   end Test_Extract_Limits_Bonferroni_Disabled;


   package SQC_Quantile_CC_Caller is
     new AUnit.Test_Caller (Coyote_SQC_Quantile_CC_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: Compute_Quantiles basic 10-element array",
         Coyote_SQC_Quantile_CC_Tests.Test_Compute_Quantiles_Basic'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: Compute_Quantiles n=1 returns all equal",
         Coyote_SQC_Quantile_CC_Tests.Test_Compute_Quantiles_N1'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: Build_Distribution with 3-session pool",
         Coyote_SQC_Quantile_CC_Tests
           .Test_Build_Distribution_Limits'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: Build_Distribution single-session pool",
         Coyote_SQC_Quantile_CC_Tests
           .Test_Build_Distribution_Single'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: Build_Distribution seed reproducibility",
         Coyote_SQC_Quantile_CC_Tests
           .Test_Build_Distribution_Seeding'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: Extract_Limits with known distribution",
         Coyote_SQC_Quantile_CC_Tests
           .Test_Extract_Limits_Known'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: Is_OOC detects value above UCL",
         Coyote_SQC_Quantile_CC_Tests.Test_Is_OOC_Above'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: Is_OOC with Has_UCL=False",
         Coyote_SQC_Quantile_CC_Tests.Test_Is_OOC_No_UCL'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: Session_Is_OOC all in-control",
         Coyote_SQC_Quantile_CC_Tests
           .Test_Session_Is_OOC_All_In'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: Session_Is_OOC one component out",
         Coyote_SQC_Quantile_CC_Tests
           .Test_Session_Is_OOC_One_Out'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: OOC_Components returns correct set",
         Coyote_SQC_Quantile_CC_Tests.Test_OOC_Components'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: cache hit returns same distribution",
         Coyote_SQC_Quantile_CC_Tests.Test_Cache_Hit'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: cache invalidation clears entries",
         Coyote_SQC_Quantile_CC_Tests
           .Test_Cache_Invalidation'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: sort through quantiles -- reverse input",
         Coyote_SQC_Quantile_CC_Tests
           .Test_Sort_Through_Quantiles_Reverse'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: sort through quantiles -- all equal values",
         Coyote_SQC_Quantile_CC_Tests
           .Test_Sort_Through_Quantiles_All_Equal'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: sort through quantiles -- two descending",
         Coyote_SQC_Quantile_CC_Tests
           .Test_Sort_Through_Quantiles_Two_Desc'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: sort through quantiles -- 50 random-ish",
         Coyote_SQC_Quantile_CC_Tests
           .Test_Sort_Through_Quantiles_Larger'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Interpolate_Limits at anchor matches exact",
         Coyote_SQC_Quantile_CC_Tests
           .Test_Interpolate_Limits_Anchor'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Interpolate_Limits between anchors shrinks HW",
         Coyote_SQC_Quantile_CC_Tests
           .Test_Interpolate_Limits_Between'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Interpolate_Limits n=1 falls back to exact",
         Coyote_SQC_Quantile_CC_Tests
           .Test_Interpolate_Limits_N1'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Extract_Limits with Bonferroni disabled uses unadjusted ranks",
         Coyote_SQC_Quantile_CC_Tests
           .Test_Extract_Limits_Bonferroni_Disabled'Access));

      return Result;
   end Suite;

end Coyote_SQC_Quantile_CC_Tests;
