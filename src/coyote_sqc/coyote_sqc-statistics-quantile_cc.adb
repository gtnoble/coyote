--  Coyote_SQC.Statistics.Quantile_CC body.
--
--  Project: coyote


with Ada.Numerics.Long_Elementary_Functions;
package body Coyote_SQC.Statistics.Quantile_CC is

   use Coyote_SQC.Data_Model;

   use Ada.Numerics.Long_Elementary_Functions;

   --  ── Sorting helpers ────────────────────────────────────────────────

   --  In-place insertion sort — faster than heapsort for small N.
   --  Used in the inner bootstrap loop where N_I is typically < 50.
   procedure Insertion_Sort (A : in out Long_Float_Array) is
      J   : Positive;
      Tmp : Long_Float;
   begin
      for I in A'First + 1 .. A'Last loop
         Tmp := A (I);
         J   := I;
         while J > A'First and then A (J - 1) > Tmp loop
            A (J) := A (J - 1);
            J := J - 1;
         end loop;
         A (J) := Tmp;
      end loop;
   end Insertion_Sort;

   --  In-place heapsort with direct array access (no indirection).
   --  Eliminates cache_maps__reference overhead (29% of CPU in gprof
   --  from the Generic_Array_Sort indirect element accessor).
   --  Used for large arrays (N > 500) and the outer Sort_Vec sorts
   --  where quicksort recursion overhead dominates.
   procedure Heap_Sort (A : in out Long_Float_Array) is
      N : constant Positive := A'Length;

      procedure Sift_Down (Start, Last : Positive) is
         Root   : constant Long_Float := A (Start);
         Parent : Positive := Start;
         Child  : Positive;
      begin
         loop
            Child := 2 * Parent;
            exit when Child > Last;
            if Child < Last and then A (Child) < A (Child + 1) then
               Child := Child + 1;
            end if;
            exit when Root >= A (Child);
            A (Parent) := A (Child);
            Parent := Child;
         end loop;
         A (Parent) := Root;
      end Sift_Down;
   begin
      if N <= 1 then
         return;
      end if;
      for I in reverse 1 .. N / 2 loop
         Sift_Down (I, N);
      end loop;
      for I in reverse 2 .. N loop
         declare
            Tmp : constant Long_Float := A (1);
         begin
            A (1) := A (I);
            A (I) := Tmp;
         end;
         Sift_Down (1, I - 1);
      end loop;
   end Heap_Sort;


   --  In-place quicksort with median-of-three pivot.
   --  Falls back to Insertion_Sort for segments of size <= 16.
   --  Replaces the former Generic_Array_Sort (heapsort) instantiation
   --  whose indirect element references consumed 61% of CPU in gprof.
   procedure Quick_Sort (A : in out Long_Float_Array) is
      Cutoff : constant Positive := 16;

      function Median_Of_Three (Lo, Mid, Hi : Positive) return Positive is
         V_Lo  : constant Long_Float := A (Lo);
         V_Mid : constant Long_Float := A (Mid);
         V_Hi  : constant Long_Float := A (Hi);
      begin
         if (V_Lo <= V_Mid and then V_Mid <= V_Hi)
           or else (V_Hi <= V_Mid and then V_Mid <= V_Lo)
         then
            return Mid;
         elsif (V_Mid <= V_Lo and then V_Lo <= V_Hi)
           or else (V_Hi <= V_Lo and then V_Lo <= V_Mid)
         then
            return Lo;
         else
            return Hi;
         end if;
      end Median_Of_Three;

      procedure Swap (I, J : Positive) is
         Tmp : constant Long_Float := A (I);
      begin
         A (I) := A (J);
         A (J) := Tmp;
      end Swap;

      procedure Sort_Segment (Lo, Hi : Positive) is
      begin
         if Hi - Lo + 1 <= Cutoff then
            Insertion_Sort (A (Lo .. Hi));
            return;
         end if;

         declare
            Mid    : constant Positive := Lo + (Hi - Lo) / 2;
            Pivot  : constant Positive := Median_Of_Three (Lo, Mid, Hi);
            P_Val  : constant Long_Float := A (Pivot);
         begin
            Swap (Pivot, Hi);

            declare
               Store : Natural := Lo - 1;
            begin
               for J in Lo .. Hi - 1 loop
                  if A (J) <= P_Val then
                     Store := Store + 1;
                     Swap (Store, J);
                  end if;
               end loop;

               Swap (Store + 1, Hi);

               declare
                  Left_Sz  : constant Natural := Store + 1 - Lo;
                  Right_Sz : constant Natural := Hi - (Store + 1);
                  Piv_Pos  : constant Positive := Store + 1;
               begin
                  if Left_Sz < Right_Sz then
                     Sort_Segment (Lo, Piv_Pos - 1);
                     Sort_Segment (Piv_Pos + 1, Hi);
                  else
                     Sort_Segment (Piv_Pos + 1, Hi);
                     Sort_Segment (Lo, Piv_Pos - 1);
                  end if;
               end;
            end;
         end;
      end Sort_Segment;

   begin
      if A'Length > 500 then
         Heap_Sort (A);
      elsif A'Length > 1 then
         Sort_Segment (A'First, A'Last);
      end if;
   end Quick_Sort;

   --  ── Random number generation ─────────────────────────────────────────
   --  Simple 31-bit linear congruential generator for reproducibility
   --  across all platforms.  Parameters from glibc rand().
   type LC_State is record
      X : Long_Long_Integer := 1;
   end record;

   Modulus : constant Long_Long_Integer := 2_147_483_647;  -- 2^31 − 1

   procedure LC_Next (State : in out LC_State; R : out Float) is
   begin
      State.X := (State.X * Long_Long_Integer (1_103_515_245) + 12_345) mod Modulus;
      if State.X = 0 then
         State.X := 1;
      end if;
      R := Float (State.X) / Float (Modulus);
   end LC_Next;

   procedure LC_Seed (State : in out LC_State; Seed : Integer) is
   begin
      State.X := Long_Long_Integer (abs (Seed)) mod Modulus;
      if State.X = 0 then
         State.X := 1;
      end if;
   end LC_Seed;

   --  ── Compute_Quantiles ─────────────────────────────────────────────────

   function Compute_Quantiles
     (Values : Long_Float_Array;
      N      : Natural) return Quantile_Array
   is
      Sorted_Vals : Long_Float_Array (1 .. N) := Values (1 .. N);
      Result      : Quantile_Array;

      function Linear_Quantile (P : Long_Float) return Long_Float is
         Pos : constant Long_Float := P * Long_Float (N - 1);
         K   : constant Natural     := Natural (Long_Float'Truncation (Pos));
         F   : constant Long_Float  := Pos - Long_Float (K);
         Idx1 : constant Positive   := K + 1;
         Idx2 : constant Positive   := Positive'Min (K + 2, N);
      begin
         if Idx1 = Idx2 or else F = 0.0 then
            return Sorted_Vals (Idx1);
         else
            return Sorted_Vals (Idx1) * (1.0 - F) + Sorted_Vals (Idx2) * F;
         end if;
      end Linear_Quantile;

   begin
      if N < 1 then
         raise Constraint_Error with
           "Compute_Quantiles: N must be >= 1";
      end if;
      if Values'Length < N then
         raise Constraint_Error with
           "Compute_Quantiles: Values'Length < N";
      end if;

      Quick_Sort (Sorted_Vals);
      --  Invariant: sort produced a sorted array (requires -gnata).
      pragma Assert
        ((for all I in 1 .. N - 1 => Sorted_Vals (I) <= Sorted_Vals (I + 1)),
         "Quick_Sort failed to produce a sorted array");

      Result (Min_Q)    := Linear_Quantile (0.00);
      Result (Q1)       := Linear_Quantile (0.25);
      Result (Median_Q) := Linear_Quantile (0.50);
      Result (Q3)       := Linear_Quantile (0.75);
      Result (Max_Q)    := Linear_Quantile (1.00);

      --  Invariant: quantile ordering (requires -gnata).
      pragma Assert
        (Result (Min_Q) <= Result (Q1)
         and then Result (Q1) <= Result (Median_Q)
         and then Result (Median_Q) <= Result (Q3)
         and then Result (Q3) <= Result (Max_Q),
         "Compute_Quantiles non-monotonic");
      return Result;
   end Compute_Quantiles;

   --  ── Internal: sort a Long_Float_Vecs.Vector in-place ──────────────────
   procedure Sort_Vec (V : in out Long_Float_Vecs.Vector) is
      N : constant Natural := Natural (V.Length);
      subtype Array_Idx is Positive range 1 .. Natural'Max (1, N);
      A : Long_Float_Array (Array_Idx);
   begin
      if N = 0 then
         return;
      end if;
      for I in A'Range loop
         A (I) := V.Element (I - 1);
      end loop;
      Heap_Sort (A);
      for I in A'Range loop
         V.Replace_Element (I - 1, A (I));
      end loop;
   end Sort_Vec;

   --  ── Build_Distribution ────────────────────────────────────────────────

   function Build_Distribution
     (Pool_Values  : Long_Float_Array;
      Pool_Offsets : Natural_Vectors.Vector;
      Pool_Lengths : Natural_Vectors.Vector;
      N_I          : Positive;
      Seed         : Integer := Bootstrap_Seed)
     return Bootstrap_Distribution
   is
      K : constant Natural := Natural (Pool_Offsets.Length);
      Dist : Bootstrap_Distribution;
      Resample_Buf : Long_Float_Array (1 .. N_I);
      RNG : LC_State;

      function Rand return Float is
         R : Float;
      begin
         LC_Next (RNG, R);
         return R;
      end Rand;

      function Random_Natural (Max : Natural) return Natural is
      begin
         if Max = 0 then
            return 0;
         end if;
         return Natural'Min (Natural (Rand * Float (Max)), Max - 1);
      end Random_Natural;

   begin
      if K = 0 then
         return Dist;
      end if;

      for Comp in Quantile_Index loop
         Dist (Comp).Reserve_Capacity
           (Ada.Containers.Count_Type (B_Replicates));
      end loop;

      LC_Seed (RNG, Seed + Integer (N_I));

      for B in 1 .. B_Replicates loop
         declare
            Sess_Idx : constant Positive := Random_Natural (K) + 1;
            Offset   : constant Natural :=
              Natural (Pool_Offsets.Element (Sess_Idx));
            Length   : constant Natural :=
              Natural (Pool_Lengths.Element (Sess_Idx));
            Sess_Size : constant Natural := Length;
         begin
            for J in 1 .. N_I loop
               declare
                  Pick : constant Natural := Random_Natural (Sess_Size);
               begin
                  Resample_Buf (J) := Pool_Values (Offset + Pick + 1);
               end;
            end loop;

            declare
               Q : constant Quantile_Array :=
                 Compute_Quantiles (Resample_Buf, N_I);
            begin
               for Comp in Quantile_Index loop
                  Dist (Comp).Append (Q (Comp));
               end loop;
            end;
         end;
      end loop;

      for Comp in Quantile_Index loop
         Sort_Vec (Dist (Comp));
      end loop;

      return Dist;
   end Build_Distribution;

   --  ── Extract_Limits ────────────────────────────────────────────────────

   function Extract_Limits
     (Dist : Bootstrap_Distribution) return Quantile_Limits_Array
   is
      Result : Quantile_Limits_Array;
   begin
      for Comp in Quantile_Index loop
         declare
            V : Long_Float_Vecs.Vector renames Dist (Comp);
            S : constant Natural := Natural (V.Length);
         begin
            if S = 0 then
               Result (Comp) := (UCL     => 0.0,
                                 CL      => 0.0,
                                 LCL     => 0.0,
                                 Has_UCL => False,
                                 Has_LCL => False);
            else
               Result (Comp) :=
                 (UCL      => V.Element (UCL_Rank - 1),
                  CL       => V.Element (B_Replicates / 2 - 1),
                  LCL      => V.Element (Bonferroni_Rank - 1),
                  Has_UCL  => True,
                  Has_LCL  => True);
            end if;
         end;
      end loop;
      return Result;
   end Extract_Limits;

   --  ── Is_OOC ────────────────────────────────────────────────────────────

   function Is_OOC
     (Value  : Long_Float;
      Limits : Quantile_Limits_Record) return Boolean
   is
   begin
      if Limits.Has_UCL and then Value > Limits.UCL then
         return True;
      elsif Limits.Has_LCL and then Value < Limits.LCL then
         return True;
      else
         return False;
      end if;
   end Is_OOC;

   --  ── Session_Is_OOC ────────────────────────────────────────────────────

   function Session_Is_OOC
     (Values : Quantile_Array;
      Limits : Quantile_Limits_Array) return Boolean
   is
   begin
      for Comp in Quantile_Index loop
         if Is_OOC (Values (Comp), Limits (Comp)) then
            return True;
         end if;
      end loop;
      return False;
   end Session_Is_OOC;

   --  ── OOC_Components ────────────────────────────────────────────────────

   function OOC_Components
     (Values : Quantile_Array;
      Limits : Quantile_Limits_Array) return Quantile_Component_Set
   is
      Result : Quantile_Component_Set;
   begin
      for Comp in Quantile_Index loop
         Result (Comp) := Is_OOC (Values (Comp), Limits (Comp));
      end loop;
      return Result;
   end OOC_Components;

   --  ── Cache functions ───────────────────────────────────────────────────

   function Get_Distribution
     (Cache        : in out Quantile_CC_Cache;
      Pool_Values  : Long_Float_Array;
      Pool_Offsets : Natural_Vectors.Vector;
      Pool_Lengths : Natural_Vectors.Vector;
      N_I          : Positive;
      Seed         : Integer := Bootstrap_Seed) return Bootstrap_Distribution
   is
   begin
      for E of Cache.Entries loop
         if E.N = N_I then
            return E.Dist;
         end if;
      end loop;

      declare
         Dist : constant Bootstrap_Distribution :=
           Build_Distribution
             (Pool_Values, Pool_Offsets, Pool_Lengths, N_I, Seed);
      begin
         Cache.Entries.Append ((N => N_I, Dist => Dist));
         return Dist;
      end;
   end Get_Distribution;

   procedure Clear_Cache (Cache : in out Quantile_CC_Cache) is
   begin
      Cache.Entries.Clear;
   end Clear_Cache;

   --  ── Interpolated limits ─────────────────────────────────────────────

   --  Anchor set: grows lazily as larger N values are encountered.
   --  Shared across all chart kinds (anchors depend only on N, not on
   --  which per-turn quantity is being charted).
   Anchors : Natural_Vectors.Vector;

   --  Ensure the anchor vector includes every integer up to Discrete_Max
   --  and extends in 1/√n space up to at least N.
   procedure Ensure_Anchors_Up_To (N : Positive) is
      --  n_min for the continuous regime: the larger of Discrete_Max
      --  and ceil((C/δ)²).
      N_Min_Raw : constant Long_Float :=
        (Interp_C / Interp_Delta) ** 2;
      N_Min : constant Positive :=
        Positive'Max (Interp_Discrete_Max,
          Positive (Long_Float'Ceiling (N_Min_Raw)));
      --  Spacing in x = 1/√n: Δx = δ / √N_Min.
      X_Delta : constant Long_Float :=
        Interp_Delta / Sqrt (Long_Float (N_Min));
   begin
      if Anchors.Is_Empty then
         --  Phase 1: every integer 2 .. N_Min
         for I in 2 .. N_Min loop
            Anchors.Append (Natural (I));
         end loop;
      end if;

      --  Phase 2: extend uniformly in x = 1/√n until we cover N.
      while Anchors.Last_Element < Natural (N) loop
         declare
            Last_N : constant Natural :=
              Natural (Anchors.Last_Element);
            X_Last : constant Long_Float :=
              1.0 / Sqrt (Long_Float (Last_N));
            X_Next : constant Long_Float := X_Last - X_Delta;
         begin
            if X_Next <= 0.0 then
               --  Numerically degenerate; just step by 1.
               Anchors.Append (Natural (Last_N + 1));
            else
               declare
                  Next_N : constant Positive :=
                    Positive (Long_Float'Ceiling
                      (1.0 / (X_Next * X_Next)));
               begin
                  if Next_N <= Last_N then
                     Anchors.Append (Natural (Last_N + 1));
                  else
                     Anchors.Append (Natural (Next_N));
                  end if;
               end;
            end if;
         end;
      end loop;
   end Ensure_Anchors_Up_To;

   --  ── Interpolate_Limits ─────────────────────────────────────────────

   function Interpolate_Limits
     (Cache        : in out Quantile_CC_Cache;
      Pool_Values  : Long_Float_Array;
      Pool_Offsets : Natural_Vectors.Vector;
      Pool_Lengths : Natural_Vectors.Vector;
      N_I          : Positive;
      Seed         : Integer := Bootstrap_Seed)
     return Quantile_Limits_Array
   is
      Result : Quantile_Limits_Array;
   begin
      --  For n = 1 (degenerate), use exact bootstrap.
      if N_I = 1 then
         declare
            Dist : constant Bootstrap_Distribution :=
              Get_Distribution
                (Cache, Pool_Values, Pool_Offsets, Pool_Lengths,
                 1, Seed);
         begin
            return Extract_Limits (Dist);
         end;
      end if;

      --  Grow anchors if needed.
      Ensure_Anchors_Up_To (N_I);

      --  Find nearest lower anchor ≤ N_I.
      declare
         Anchor_N : Natural := 0;
      begin
         for A of Anchors loop
            exit when Natural (A) > N_I;
            Anchor_N := Natural (A);
         end loop;

         if Anchor_N = 0 then
            --  Should not happen for N_I ≥ 2, but guard.
            pragma Assert (False, "Interpolate_Limits: no anchor for N_I");
            for Comp in Quantile_Index loop
               Result (Comp) :=
                 (UCL     => 0.0,
                  CL      => 0.0,
                  LCL     => 0.0,
                  Has_UCL => False,
                  Has_LCL => False);
            end loop;
            return Result;
         end if;

         --  Compute exact distribution at the anchor.
         declare
            Dist : constant Bootstrap_Distribution :=
              Get_Distribution
                (Cache, Pool_Values, Pool_Offsets, Pool_Lengths,
                 Anchor_N, Seed);
            Anchor_Limits : constant Quantile_Limits_Array :=
              Extract_Limits (Dist);
         begin
            if N_I = Anchor_N then
               return Anchor_Limits;
            end if;

            --  Scale half-widths by √(Anchor_N / N_I).
            declare
               Scale : constant Long_Float :=
                 Sqrt
                   (Long_Float (Anchor_N) / Long_Float (N_I));
            begin
               for Comp in Quantile_Index loop
                  declare
                     L : Quantile_Limits_Record renames
                       Anchor_Limits (Comp);
                  begin
                     Result (Comp).CL := L.CL;
                     Result (Comp).Has_UCL := L.Has_UCL;
                     Result (Comp).Has_LCL := L.Has_LCL;
                     if L.Has_UCL then
                        Result (Comp).UCL :=
                          L.CL + (L.UCL - L.CL) * Scale;
                     else
                        Result (Comp).UCL := 0.0;
                     end if;
                     if L.Has_LCL then
                        Result (Comp).LCL :=
                          L.CL - (L.CL - L.LCL) * Scale;
                     else
                        Result (Comp).LCL := 0.0;
                     end if;
                  end;
               end loop;
            end;
         end;
      end;

      return Result;
   end Interpolate_Limits;


end Coyote_SQC.Statistics.Quantile_CC;
