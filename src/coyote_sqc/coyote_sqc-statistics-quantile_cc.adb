--  Coyote_SQC.Statistics.Quantile_CC body.
--
--  Project: coyote


package body Coyote_SQC.Statistics.Quantile_CC is

   use Coyote_SQC.Data_Model;

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
         K   : constant Natural     := Natural (Pos);
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

      Result (Min_Q)    := Linear_Quantile (0.00);
      Result (Q1)       := Linear_Quantile (0.25);
      Result (Median_Q) := Linear_Quantile (0.50);
      Result (Q3)       := Linear_Quantile (0.75);
      Result (Max_Q)    := Linear_Quantile (1.00);

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

      LC_Seed (RNG, Seed);

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

end Coyote_SQC.Statistics.Quantile_CC;
