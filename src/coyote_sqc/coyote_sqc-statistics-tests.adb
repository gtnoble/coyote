--  Coyote_SQC.Statistics.Tests body.
--
--  Project: coyote

with Ada.Numerics.Long_Elementary_Functions;

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

end Coyote_SQC.Statistics.Tests;
