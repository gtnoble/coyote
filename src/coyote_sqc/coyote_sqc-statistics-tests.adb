--  Coyote_SQC.Statistics.Tests body.
--
--  Project: coyote

with Ada.Numerics.Long_Elementary_Functions;
with Ada.Numerics.Float_Random;

package body Coyote_SQC.Statistics.Tests is

   use Ada.Numerics.Long_Elementary_Functions;

   --  ── Internal helpers ──────────────────────────────────────────────────

   --  In-place insertion sort (ascending).
   procedure Sort (A : in out Long_Float_Array) is
      Key : Long_Float;
      J   : Integer;
   begin
      for I in A'First + 1 .. A'Last loop
         Key := A (I);
         J   := I - 1;
         while J >= A'First and then A (J) > Key loop
            A (J + 1) := A (J);
            J := J - 1;
         end loop;
         A (J + 1) := Key;
      end loop;
   end Sort;

   --  Normal CDF via the Abramowitz & Stegun rational approximation 7.1.26
   --  (max |error| < 1.5e-7).
   function Normal_CDF (X : Long_Float) return Long_Float is
      Xp : constant Long_Float := abs X;
      T  : Long_Float;
      P  : Long_Float;
   begin
      T := 1.0 / (1.0 + 0.3275911 * Xp);
      P := T * (0.254829592
           + T * (-0.284496736
           + T * (1.421413741
           + T * (-1.453152027
           + T *  1.061405429))));
      P := P * Exp (-Xp * Xp);
      if X >= 0.0 then
         return 1.0 - P / 2.0;
      else
         return P / 2.0;
      end if;
   end Normal_CDF;

   --  Asymptotic Kolmogorov distribution complement Q(z):
   --    Q(z) = 2 * sum_{k=1}^inf (-1)^{k-1} * exp(-2*k^2*z^2)
   --  Returns 1.0 for z <= 0.27 (very small statistic).
   function Kolmogorov_Q (Z : Long_Float) return Long_Float is
      Sum    : Long_Float := 0.0;
      Term   : Long_Float;
      Sign   : Long_Float := 1.0;
      Neg2Z2 : constant Long_Float := -2.0 * Z * Z;
   begin
      if Z <= 0.27 then
         return 1.0;
      end if;
      for K in 1 .. 50 loop
         Term := Exp (Long_Float (K * K) * Neg2Z2);
         Sum  := Sum + Sign * Term;
         Sign := -Sign;
         exit when abs Term < 1.0e-16;
      end loop;
      return Long_Float'Min (1.0, Long_Float'Max (0.0, 2.0 * Sum));
   end Kolmogorov_Q;

   --  ── Descriptive statistics ────────────────────────────────────────────

   function Mean_Of (Values : Long_Float_Array) return Long_Float is
      Sum : Long_Float := 0.0;
   begin
      if Values'Length = 0 then
         return 0.0;
      end if;
      for V of Values loop
         Sum := Sum + V;
      end loop;
      return Sum / Long_Float (Values'Length);
   end Mean_Of;

   function Std_Dev_Of (Values : Long_Float_Array) return Long_Float is
      N  : constant Natural := Values'Length;
      Mu : Long_Float;
      SS : Long_Float := 0.0;
      D  : Long_Float;
   begin
      if N < 2 then
         return 0.0;
      end if;
      Mu := Mean_Of (Values);
      for V of Values loop
         D  := V - Mu;
         SS := SS + D * D;
      end loop;
      return Sqrt (SS / Long_Float (N - 1));
   end Std_Dev_Of;

   --  ── Goodness-of-fit tests ─────────────────────────────────────────────

   function KS_Normality_P_Value
     (Values : Long_Float_Array) return Long_Float
   is
      N      : constant Natural := Values'Length;
      Mu     : Long_Float;
      Sig    : Long_Float;
      D      : Long_Float := 0.0;
      Fn     : Long_Float;
      Fz     : Long_Float;
      Diff   : Long_Float;
      Sorted : Long_Float_Array := Values;
   begin
      if N < 3 then
         return -1.0;
      end if;
      Mu  := Mean_Of (Values);
      Sig := Std_Dev_Of (Values);
      if Sig = 0.0 then
         return -1.0;
      end if;
      Sort (Sorted);
      for I in Sorted'Range loop
         Fn   := Long_Float (I - Sorted'First + 1) / Long_Float (N);
         Fz   := Normal_CDF ((Sorted (I) - Mu) / Sig);
         Diff := abs (Fn - Fz);
         if Diff > D then
            D := Diff;
         end if;
         Diff := abs (Long_Float (I - Sorted'First) / Long_Float (N) - Fz);
         if Diff > D then
            D := Diff;
         end if;
      end loop;
      return Kolmogorov_Q (D * Sqrt (Long_Float (N)));
   end KS_Normality_P_Value;

   function KS_Exponential_P_Value
     (Values : Long_Float_Array) return Long_Float
   is
      N      : constant Natural := Values'Length;
      Mu     : Long_Float;
      Lambda : Long_Float;
      D      : Long_Float := 0.0;
      Fn     : Long_Float;
      Fz     : Long_Float;
      Diff   : Long_Float;
      Sorted : Long_Float_Array := Values;
   begin
      if N < 3 then
         return -1.0;
      end if;
      Mu := Mean_Of (Values);
      if Mu <= 0.0 then
         return -1.0;
      end if;
      Lambda := 1.0 / Mu;
      Sort (Sorted);
      for I in Sorted'Range loop
         Fn   := Long_Float (I - Sorted'First + 1) / Long_Float (N);
         Fz   := 1.0 - Exp (-Lambda * Sorted (I));
         Diff := abs (Fn - Fz);
         if Diff > D then
            D := Diff;
         end if;
         Diff := abs (Long_Float (I - Sorted'First) / Long_Float (N) - Fz);
         if Diff > D then
            D := Diff;
         end if;
      end loop;
      return Kolmogorov_Q (D * Sqrt (Long_Float (N)));
   end KS_Exponential_P_Value;

   function Runs_Test_P_Value
     (Values : Long_Float_Array) return Long_Float
   is
      N          : constant Natural := Values'Length;
      Sorted     : Long_Float_Array := Values;
      Med        : Long_Float;
      N1         : Long_Float := 0.0;
      N2         : Long_Float := 0.0;
      Runs       : Long_Float := 0.0;
      Prev_Above : Boolean    := False;
      First_Set  : Boolean    := False;
      E_R        : Long_Float;
      Var_R      : Long_Float;
      Z          : Long_Float;
   begin
      if N < 10 then
         return -1.0;
      end if;
      Sort (Sorted);
      declare
         Mid : constant Natural := N / 2;
      begin
         if N mod 2 = 1 then
            Med := Sorted (Sorted'First + Mid);
         else
            Med := (Sorted (Sorted'First + Mid - 1)
                  + Sorted (Sorted'First + Mid)) / 2.0;
         end if;
      end;
      --  Count n1, n2 and runs in original (chronological) order;
      --  observations equal to the median are excluded from both groups.
      for V of Values loop
         if V > Med then
            if First_Set and then not Prev_Above then
               Runs := Runs + 1.0;
            end if;
            if not First_Set then
               Runs := 1.0;
               First_Set := True;
            end if;
            Prev_Above := True;
            N1 := N1 + 1.0;
         elsif V < Med then
            if First_Set and then Prev_Above then
               Runs := Runs + 1.0;
            end if;
            if not First_Set then
               Runs := 1.0;
               First_Set := True;
            end if;
            Prev_Above := False;
            N2 := N2 + 1.0;
         end if;
      end loop;
      if N1 = 0.0 or else N2 = 0.0 then
         return -1.0;
      end if;
      E_R   := 2.0 * N1 * N2 / (N1 + N2) + 1.0;
      Var_R := 2.0 * N1 * N2 * (2.0 * N1 * N2 - N1 - N2)
               / ((N1 + N2) ** 2 * (N1 + N2 - 1.0));
      if Var_R <= 0.0 then
         return -1.0;
      end if;
      Z := (Runs - E_R) / Sqrt (Var_R);
      return 2.0 * Normal_CDF (-abs Z);
   end Runs_Test_P_Value;

   --  ── Dip test for unimodality ──────────────────────────────────────────

   --  Compute Hartigan's dip statistic for a sorted array.
   --  Implements Algorithm AS 217 (Hartigan, P.M., Appl. Stat., 1985, 34:3)
   --  translated from the C reference implementation by M. Maechler.
   --
   --  The algorithm finds the greatest convex minorant (GCM) and least
   --  concave majorant (LCM) of the ECDF, iteratively refining the modal
   --  interval [Low, High] until convergence.  All intermediate values are
   --  kept in "2N * dip" units; the final result is divided by 2N.
   --
   --  Pre-condition: X must be sorted ascending; X'Length >= 1.
   function Compute_Dip (X : Long_Float_Array) return Long_Float is
      N  : constant Positive := X'Length;
      B  : constant Integer  := X'First - 1; --  1-based index bias

      Mn  : array (1 .. N) of Integer;  --  GCM predecessor chain
      Mj  : array (1 .. N) of Integer;  --  LCM successor chain
      Gcm : array (1 .. N) of Integer;  --  GCM change-point list
      Lcm : array (1 .. N) of Integer;  --  LCM change-point list

      Low, High   : Integer;
      Dip_Val     : Long_Float;
      Ig, Ih      : Integer;
      Ix, Iv      : Integer;
      L_Gcm, L_Lcm : Integer;
      Dip_L, Dip_U, Dip_New : Long_Float;

      function Xv (I : Integer) return Long_Float is (X (B + I));
   begin
      if N < 2 or else Xv (N) = Xv (1) then
         return 0.0;
      end if;

      Low     := 1;
      High    := N;
      Dip_Val := 1.0; --  starting value in 2N units (= 1/(2N) actual dip)

      --  Build Mn: for each j, Mn(j) is the predecessor on the GCM hull.
      Mn (1) := 1;
      for J in 2 .. N loop
         Mn (J) := J - 1;
         loop
            declare
               Mnj   : constant Integer := Mn (J);
               Mnmnj : constant Integer := Mn (Mnj);
            begin
               exit when Mnj = 1
                 or else (Xv (J) - Xv (Mnj)) * Long_Float (Mnj - Mnmnj) <
                         (Xv (Mnj) - Xv (Mnmnj)) * Long_Float (J - Mnj);
               Mn (J) := Mnmnj;
            end;
         end loop;
      end loop;

      --  Build Mj: for each k, Mj(k) is the successor on the LCM hull.
      Mj (N) := N;
      for K in reverse 1 .. N - 1 loop
         Mj (K) := K + 1;
         loop
            declare
               Mjk   : constant Integer := Mj (K);
               Mjmjk : constant Integer := Mj (Mjk);
            begin
               exit when Mjk = N
                 or else (Xv (K) - Xv (Mjk)) * Long_Float (Mjk - Mjmjk) <
                         (Xv (Mjk) - Xv (Mjmjk)) * Long_Float (K - Mjk);
               Mj (K) := Mjmjk;
            end;
         end loop;
      end loop;

      --  Main iteration: refine modal interval [Low, High].
      loop
         --  Collect GCM change points from High down to Low.
         Gcm (1) := High;
         declare I : Integer := 1; begin
            while Gcm (I) > Low loop
               Gcm (I + 1) := Mn (Gcm (I));
               I := I + 1;
            end loop;
            Ig    := I;
            L_Gcm := I;
         end;
         Ix := Ig - 1;

         --  Collect LCM change points from Low up to High.
         Lcm (1) := Low;
         declare I : Integer := 1; begin
            while Lcm (I) < High loop
               Lcm (I + 1) := Mj (Lcm (I));
               I := I + 1;
            end loop;
            Ih    := I;
            L_Lcm := I;
         end;
         Iv := 2;

         --  Find the largest GCM-LCM gap greater than Dip_Val.
         declare
            D : Long_Float := 0.0;
         begin
            if L_Gcm /= 2 or else L_Lcm /= 2 then
               while Gcm (Ix) /= Lcm (Iv) loop
                  declare
                     Gcmix : constant Integer := Gcm (Ix);
                     Lcmiv : constant Integer := Lcm (Iv);
                     Dx    : Long_Float;
                  begin
                     if Gcmix > Lcmiv then
                        declare
                           Gcmi1 : constant Integer := Gcm (Ix + 1);
                        begin
                           Dx := Long_Float (Lcmiv - Gcmi1 + 1)
                              - (Xv (Lcmiv) - Xv (Gcmi1))
                                * Long_Float (Gcmix - Gcmi1)
                                / (Xv (Gcmix) - Xv (Gcmi1));
                           Iv := Iv + 1;
                           if Dx >= D then
                              D  := Dx;
                              Ig := Ix + 1;
                              Ih := Iv - 1;
                           end if;
                        end;
                     else
                        declare
                           Lcmiv1 : constant Integer := Lcm (Iv - 1);
                        begin
                           Dx := (Xv (Gcmix) - Xv (Lcmiv1))
                              * Long_Float (Lcmiv - Lcmiv1)
                              / (Xv (Lcmiv) - Xv (Lcmiv1))
                              - Long_Float (Gcmix - Lcmiv1 - 1);
                           Ix := Ix - 1;
                           if Dx >= D then
                              D  := Dx;
                              Ig := Ix + 1;
                              Ih := Iv;
                           end if;
                        end;
                     end if;
                     if Ix < 1 then
                        Ix := 1;
                     end if;
                     if Iv > L_Lcm then
                        Iv := L_Lcm;
                     end if;
                  end;
               end loop;
            else
               D := 1.0; --  l_gcm or l_lcm = 2: minimal gap
            end if;

            exit when D < Dip_Val; --  no improvement possible
         end;

         --  Compute dip contribution from GCM segments.
         Dip_L := 0.0;
         for J in Ig .. L_Gcm - 1 loop
            declare
               Max_T : Long_Float := 1.0;
               Jb    : constant Integer := Gcm (J + 1);
               Je    : constant Integer := Gcm (J);
            begin
               if Je - Jb > 1 and then Xv (Je) /= Xv (Jb) then
                  declare
                     C : constant Long_Float :=
                       Long_Float (Je - Jb) / (Xv (Je) - Xv (Jb));
                  begin
                     for Jj in Jb .. Je loop
                        declare
                           T : constant Long_Float :=
                             Long_Float (Jj - Jb + 1)
                             - (Xv (Jj) - Xv (Jb)) * C;
                        begin
                           if T > Max_T then
                              Max_T := T;
                           end if;
                        end;
                     end loop;
                  end;
               end if;
               if Max_T > Dip_L then
                  Dip_L := Max_T;
               end if;
            end;
         end loop;

         --  Compute dip contribution from LCM segments.
         Dip_U := 0.0;
         for J in Ih .. L_Lcm - 1 loop
            declare
               Max_T : Long_Float := 1.0;
               Jb    : constant Integer := Lcm (J);
               Je    : constant Integer := Lcm (J + 1);
            begin
               if Je - Jb > 1 and then Xv (Je) /= Xv (Jb) then
                  declare
                     C : constant Long_Float :=
                       Long_Float (Je - Jb) / (Xv (Je) - Xv (Jb));
                  begin
                     for Jj in Jb .. Je loop
                        declare
                           T : constant Long_Float :=
                             (Xv (Jj) - Xv (Jb)) * C
                             - Long_Float (Jj - Jb - 1);
                        begin
                           if T > Max_T then
                              Max_T := T;
                           end if;
                        end;
                     end loop;
                  end;
               end if;
               if Max_T > Dip_U then
                  Dip_U := Max_T;
               end if;
            end;
         end loop;

         Dip_New := Long_Float'Max (Dip_L, Dip_U);
         if Dip_New > Dip_Val then
            Dip_Val := Dip_New;
         end if;

         --  Convergence check (Maechler 1994 fix: prevents infinite loop).
         exit when Low = Gcm (Ig) and then High = Lcm (Ih);
         Low  := Gcm (Ig);
         High := Lcm (Ih);
      end loop;

      return Dip_Val / Long_Float (2 * N);
   end Compute_Dip;

   function Dip_Test_P_Value
     (Values : Long_Float_Array;
      K      : Positive := 2_000) return Long_Float
   is
      use Ada.Numerics.Float_Random;
      N      : constant Natural := Values'Length;
      Sorted : Long_Float_Array := Values;
      D_Obs  : Long_Float;
      Count  : Natural := 0;
      Gen    : Generator;
      Sim    : Long_Float_Array (1 .. N);
   begin
      if N < 4 then
         return -1.0;
      end if;
      Sort (Sorted);
      D_Obs := Compute_Dip (Sorted);

      --  Bootstrap null distribution: draw K samples of size N from
      --  Uniform[0,1].  The uniform distribution maximises the expected
      --  dip among all unimodal CDFs (Hartigan & Hartigan 1985), so it
      --  provides an upper bound on the null distribution.
      --  Fixed seed ensures the displayed p-value is reproducible.
      Reset (Gen, Initiator => 12_345);
      for K_Iter in 1 .. K loop
         for I in 1 .. N loop
            Sim (I) := Long_Float (Random (Gen));
         end loop;
         Sort (Sim);
         if Compute_Dip (Sim) >= D_Obs then
            Count := Count + 1;
         end if;
      end loop;

      return Long_Float (Count) / Long_Float (K);
   end Dip_Test_P_Value;

end Coyote_SQC.Statistics.Tests;
