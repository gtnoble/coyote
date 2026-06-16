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

   --  ── Adaptive interpolation ───────────────────────────────────────────

   --  Coordinate transformation: x = 1/√n.
   function X_Of_N (N : Positive) return Long_Float is
     (1.0 / Sqrt (Long_Float (N)));

   --  Inverse: n = ceil(1/x²), clamped to at least 1.
   function N_Of_X (X : Long_Float) return Positive is
   begin
      if X <= 0.0 then
         return Positive'Last;
      end if;
      return Positive'Max (1, Positive (Long_Float'Ceiling (1.0 / (X * X))));
   end N_Of_X;

   --  Bisection midpoint in x = 1/√n space, clamped to (A+1)‥(B−1).
   function X_Midpoint (A, B : Positive) return Positive is
      X_Mid : constant Long_Float :=
        (1.0 / Sqrt (Long_Float (A)) + 1.0 / Sqrt (Long_Float (B))) / 2.0;
      N_Mid : constant Positive := N_Of_X (X_Mid);
   begin
      if N_Mid <= A then
         return A + 1;
      elsif N_Mid >= B then
         return B - 1;
      else
         return N_Mid;
      end if;
   end X_Midpoint;

   --  Linear interpolation in x = 1/√n space between two anchors.
   procedure Interpolate_From_Anchors
     (N_A       : Positive;
      Lims_A    : Quantile_Limits_Array;
      N_B       : Positive;
      Lims_B    : Quantile_Limits_Array;
      N_Target  : Positive;
      Result    : out Quantile_Limits_Array)
   is
      X_A      : constant Long_Float := X_Of_N (N_A);
      X_B      : constant Long_Float := X_Of_N (N_B);
      X_T      : constant Long_Float := X_Of_N (N_Target);
      Frac     : constant Long_Float := (X_T - X_A) / (X_B - X_A);
   begin
      for Comp in Quantile_Index loop
         declare
            LA : Quantile_Limits_Record renames Lims_A (Comp);
            LB : Quantile_Limits_Record renames Lims_B (Comp);
         begin
            Result (Comp).CL :=
              LA.CL + (LB.CL - LA.CL) * Frac;
            Result (Comp).Has_UCL := LA.Has_UCL and LB.Has_UCL;
            Result (Comp).Has_LCL := LA.Has_LCL and LB.Has_LCL;
            if Result (Comp).Has_UCL then
               Result (Comp).UCL :=
                 LA.UCL + (LB.UCL - LA.UCL) * Frac;
            else
               Result (Comp).UCL := 0.0;
            end if;
            if Result (Comp).Has_LCL then
               Result (Comp).LCL :=
                 LA.LCL + (LB.LCL - LA.LCL) * Frac;
            else
               Result (Comp).LCL := 0.0;
            end if;
         end;
      end loop;
   end Interpolate_From_Anchors;

   --  Get exact limits at N, computing and caching the bootstrap
   --  distribution if needed.
   function Exact_Limits_At
     (Cache        : in out Quantile_CC_Cache;
      Pool_Values  : Long_Float_Array;
      Pool_Offsets : Natural_Vectors.Vector;
      Pool_Lengths : Natural_Vectors.Vector;
      N            : Positive;
      Seed         : Integer) return Quantile_Limits_Array
   is
      Dist : constant Bootstrap_Distribution :=
        Get_Distribution (Cache, Pool_Values, Pool_Offsets, Pool_Lengths,
                          N, Seed);
   begin
      return Extract_Limits (Dist);
   end Exact_Limits_At;

   --  Maximum absolute error between two limit arrays, across all
   --  components (CL, UCL differences, LCL differences).
   function Max_Limit_Error
     (Exact, Interp : Quantile_Limits_Array) return Long_Float
   is
      E : Long_Float := 0.0;
   begin
      for Comp in Quantile_Index loop
         declare
            D : Long_Float;
         begin
            D := abs (Exact (Comp).CL - Interp (Comp).CL);
            if D > E then E := D; end if;
            if Exact (Comp).Has_UCL and Interp (Comp).Has_UCL then
               D := abs (Exact (Comp).UCL - Interp (Comp).UCL);
               if D > E then E := D; end if;
            end if;
            if Exact (Comp).Has_LCL and Interp (Comp).Has_LCL then
               D := abs (Exact (Comp).LCL - Interp (Comp).LCL);
               if D > E then E := D; end if;
            end if;
         end;
      end loop;
      return E;
   end Max_Limit_Error;

   --  Maximum half-width across all components of a limit array.
   function Max_HW (Limits : Quantile_Limits_Array) return Long_Float is
      HW : Long_Float := 0.0;
   begin
      for Comp in Quantile_Index loop
         if Limits (Comp).Has_UCL then
            declare
               H : constant Long_Float :=
                 Limits (Comp).UCL - Limits (Comp).CL;
            begin
               if H > HW then HW := H; end if;
            end;
         end if;
         if Limits (Comp).Has_LCL then
            declare
               H : constant Long_Float :=
                 Limits (Comp).CL - Limits (Comp).LCL;
            begin
               if H > HW then HW := H; end if;
            end;
         end if;
      end loop;
      return HW;
   end Max_HW;

   --  Compute the tolerance for an anchor pair: max(pct * HW_a, abs_floor).
   function Tolerance_For (Lims_A : Quantile_Limits_Array;
                           Rel    : Long_Float;
                           Abs_Min : Long_Float) return Long_Float
   is
      H : constant Long_Float := Max_HW (Lims_A);
   begin
      return Long_Float'Max (H * Rel, Abs_Min);
   end Tolerance_For;

   --  Ensure the anchor set covers at least up to Target_N.  Anchors
   --  are stored in Cache.Anchors as a sorted vector.
   procedure Ensure_Anchors_Cover
     (Cache        : in out Quantile_CC_Cache;
      Pool_Values  : Long_Float_Array;
      Pool_Offsets : Natural_Vectors.Vector;
      Pool_Lengths : Natural_Vectors.Vector;
      Target_N     : Positive;
      Seed         : Integer)
   is
      Anchors : Natural_Vectors.Vector renames Cache.Anchors;
      Rel     : constant Long_Float := Cache.Tolerance_Rel;
      Abs_Min  : constant Long_Float := Cache.Tolerance_Abs;

      --  Seed the discrete regime on first use.
      procedure Seed_Discrete is
      begin
         for I in 2 .. Adaptive_Discrete_Max loop
            Anchors.Append (I);
         end loop;
      end Seed_Discrete;

      --  Recursively refine the gap (Idx_Left, Idx_Right) — indices
      --  into Anchors, with corresponding n values A and B.
      procedure Refine_Gap (Idx_Left, Idx_Right : Positive) is
         A : constant Positive := Anchors.Element (Idx_Left);
         B : constant Positive := Anchors.Element (Idx_Right);
         N_Mid : constant Positive := X_Midpoint (A, B);
         --  Guard: if the gap is too narrow, accept it.
      begin
         if N_Mid <= A or else N_Mid >= B then
            return;
         end if;

         declare
            Lims_A  : constant Quantile_Limits_Array :=
              Exact_Limits_At (Cache, Pool_Values,
                               Pool_Offsets, Pool_Lengths, A, Seed);
            Lims_B  : constant Quantile_Limits_Array :=
              Exact_Limits_At (Cache, Pool_Values,
                               Pool_Offsets, Pool_Lengths, B, Seed);
            Lims_Exact : constant Quantile_Limits_Array :=
              Exact_Limits_At (Cache, Pool_Values,
                               Pool_Offsets, Pool_Lengths, N_Mid, Seed);
            Lims_Interp : Quantile_Limits_Array;
            Error       : Long_Float;
            Tol         : Long_Float;
         begin
            Interpolate_From_Anchors
              (A, Lims_A, B, Lims_B, N_Mid, Lims_Interp);
            Error := Max_Limit_Error (Lims_Exact, Lims_Interp);
            Tol := Tolerance_For (Lims_A, Rel, Abs_Min);

            if Error > Tol then
               --  Insert N_Mid as a new anchor.
               Anchors.Insert (Idx_Right, N_Mid);
               --  Recursively refine the two sub-intervals.
               Refine_Gap (Idx_Left, Idx_Right);
               Refine_Gap (Idx_Right, Idx_Right + 1);
            end if;
         end;
      end Refine_Gap;

      --  Find the insertion/extend gap and refine.
      procedure Extend_And_Refine is
      begin
         if Anchors.Is_Empty then
            Seed_Discrete;
         end if;

         if Target_N <= Anchors.Last_Element then
            return;  --  Already covered.
         end if;

         --  Add Target_N as a new anchor.
         Anchors.Append (Target_N);

         --  Refine the gap from the previous anchor to Target_N.
         if Natural (Anchors.Length) >= 2 then
         declare
            LI : constant Natural := Natural (Anchors.Last_Index);
         begin
            Refine_Gap (LI - 1, LI);
         end;
         end if;
      end Extend_And_Refine;

   begin
      Extend_And_Refine;
   end Ensure_Anchors_Cover;

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
      Anchors : Natural_Vectors.Vector renames Cache.Anchors;
   begin
      --  n = 1 is degenerate — use exact bootstrap.
      if N_I = 1 then
         return Exact_Limits_At
           (Cache, Pool_Values, Pool_Offsets, Pool_Lengths, 1, Seed);
      end if;

      --  Ensure anchors cover N_I.
      Ensure_Anchors_Cover
        (Cache, Pool_Values, Pool_Offsets, Pool_Lengths, N_I, Seed);

      --  If N_I is itself an anchor, return exact limits.
      for I in 2 .. Natural (Anchors.Last_Index) loop
         if Anchors.Element (I) = N_I then
            return Exact_Limits_At
              (Cache, Pool_Values, Pool_Offsets, Pool_Lengths,
               N_I, Seed);
         end if;
      end loop;

      --  Find the two bounding anchors a ≤ N_I ≤ b.
      declare
         Idx_Left  : Natural := 0;
         Idx_Right : Natural := 0;
      begin
         for I in 1 .. Natural (Anchors.Last_Index) loop
            declare
               A : constant Positive := Anchors.Element (I);
            begin
               if A <= N_I then
                  Idx_Left := I;
               else
                  Idx_Right := I;
                  exit;
               end if;
            end;
         end loop;

         if Idx_Left = 0 or else Idx_Right = 0 then
            --  Should not happen — anchors always cover N_I.
            pragma Assert (False, "Interpolate_Limits: no bounding anchors");
            return Exact_Limits_At
              (Cache, Pool_Values, Pool_Offsets, Pool_Lengths,
               N_I, Seed);
         end if;

         declare
            A : constant Positive := Anchors.Element (Idx_Left);
            B : constant Positive := Anchors.Element (Idx_Right);
            Lims_A : constant Quantile_Limits_Array :=
              Exact_Limits_At (Cache, Pool_Values,
                               Pool_Offsets, Pool_Lengths, A, Seed);
            Lims_B : constant Quantile_Limits_Array :=
              Exact_Limits_At (Cache, Pool_Values,
                               Pool_Offsets, Pool_Lengths, B, Seed);
            Result : Quantile_Limits_Array;
         begin
            Interpolate_From_Anchors (A, Lims_A, B, Lims_B, N_I, Result);
            return Result;
         end;
      end;
   end Interpolate_Limits;
end Coyote_SQC.Statistics.Quantile_CC;
