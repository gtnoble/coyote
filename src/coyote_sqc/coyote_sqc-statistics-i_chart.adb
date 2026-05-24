--  Coyote_SQC.Statistics.I_Chart body.
--
--  Project: coyote

with Ada.Numerics.Long_Elementary_Functions;
with Ada.Containers.Vectors;

package body Coyote_SQC.Statistics.I_Chart is
   package LF_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Long_Float);

   use Ada.Numerics.Long_Elementary_Functions;

   --  d2 for moving range of span 2.
   D2 : constant Long_Float := 1.128;

   --  D4 for MR chart UCL factor, span 2.
   D4 : constant Long_Float := 3.267;
   --  d4 consistency constant for median of span-2 absolute differences
   --  under normality (Croux & Rousseeuw 1992). Used when Robust = True.
   D4_Robust : constant Long_Float := 0.9515;

   --  ── Standard I/MR limit computation ───────────────────────────────────

   function Compute_I_Limits
     (Grand_Mean : Long_Float;
      Mean_MR    : Long_Float;
      Robust     : Boolean    := False) return Limits_Record
   is
   begin
      if Mean_MR = 0.0 then
         --  Cannot derive spread estimate; no limits drawn.
         return
           (UCL     => 0.0,
            CL      => Grand_Mean,
            LCL     => 0.0,
            Has_UCL => False,
            Has_LCL => False);
      end if;

      declare
         Divisor : constant Long_Float := (if Robust then D4_Robust else D2);
         Spread  : constant Long_Float := 3.0 * Mean_MR / Divisor;
         Raw_LCL : constant Long_Float := Grand_Mean - Spread;
         Eff_LCL : constant Long_Float :=
           (if Raw_LCL < 0.0 then 0.0 else Raw_LCL);
      begin
         return
           (UCL     => Grand_Mean + Spread,
            CL      => Grand_Mean,
            LCL     => Eff_LCL,
            Has_UCL => True,
            Has_LCL => Eff_LCL > 0.0);
      end;
   end Compute_I_Limits;

   function Compute_MR_Limits (Mean_MR : Long_Float) return Limits_Record is
   begin
      if Mean_MR = 0.0 then
         return
           (UCL     => 0.0,
            CL      => 0.0,
            LCL     => 0.0,
            Has_UCL => False,
            Has_LCL => False);
      end if;

      return
        (UCL     => D4 * Mean_MR,
         CL      => Mean_MR,
         LCL     => 0.0,
         Has_UCL => True,
         Has_LCL => False);
   end Compute_MR_Limits;

   --  ── Box-Cox transformation ─────────────────────────────────────────────

   function Box_Cox (X : Long_Float; Lambda : Long_Float) return Long_Float is
   begin
      if X <= 0.0 then
         raise Constraint_Error with
           "Box_Cox: X must be strictly positive; got"
           & Long_Float'Image (X);
      end if;
      if abs Lambda < 1.0e-10 then
         return Log (X);
      else
         return (X ** Lambda - 1.0) / Lambda;
      end if;
   end Box_Cox;

   function Box_Cox_Inverse
     (Z : Long_Float; Lambda : Long_Float) return Long_Float
   is
      Base : Long_Float;
   begin
      if abs Lambda < 1.0e-10 then
         return Exp (Z);
      else
         Base := Z * Lambda + 1.0;
         if Base <= 0.0 then
            raise Constraint_Error with
              "Box_Cox_Inverse: non-positive base"
              & " (lambda=" & Long_Float'Image (Lambda)
              & ", z=" & Long_Float'Image (Z) & ")";
         end if;
         return Base ** (1.0 / Lambda);
      end if;
   end Box_Cox_Inverse;

   --  ── Qn scale estimator ─────────────────────────────────────────────────

   --  Internal worker: compute the Qn scale estimate on any Long_Float array.
   --  No positivity check; used both by the public Qn_Scale and internally
   --  by Robust_Log_Likelihood (which operates on transformed z-values).
   function Qn_Scale_Core (Vals : Long_Float_Array) return Long_Float is
      N : constant Positive := Vals'Length;
   begin
      if N < 2 then
         raise Constraint_Error with
           "Qn_Scale: need at least 2 observations";
      end if;

      declare
         package LF_Sorting is new LF_Vectors.Generic_Sorting;

         N_Pairs : constant Positive := N * (N - 1) / 2;
         Half_N  : constant Positive := N / 2 + 1;
         H       : constant Positive := Half_N * (Half_N - 1) / 2;
         Dists   : LF_Vectors.Vector;
         Cn      : Long_Float;
      begin
         Dists.Reserve_Capacity (Ada.Containers.Count_Type (N_Pairs));

         --  Collect all pairwise absolute differences.
         for I in Vals'First .. Vals'Last - 1 loop
            for J in I + 1 .. Vals'Last loop
               Dists.Append (abs (Vals (I) - Vals (J)));
            end loop;
         end loop;

         LF_Sorting.Sort (Dists);

         --  Finite-sample correction factor c_n.
         --  Table 1 values for n = 2..9 from Rousseeuw & Croux (1993).
         --  Even/odd asymptotic formulae for n >= 10 from the same paper.
         if N <= 9 then
            declare
               type Cn_Table is array (2 .. 9) of Long_Float;
               Cn_Values : constant Cn_Table :=
                 (2 => 0.399_0,
                  3 => 0.994_0,
                  4 => 0.512_0,
                  5 => 0.844_0,
                  6 => 0.611_0,
                  7 => 0.857_0,
                  8 => 0.669_0,
                  9 => 0.872_0);
            begin
               Cn := Cn_Values (N);
            end;
         else
            --  For n >= 10: even n -> n/(n-0.9); odd n -> n/(n+1.4).
            if N mod 2 = 0 then
               Cn := Long_Float (N) / (Long_Float (N) - 0.9);
            else
               Cn := Long_Float (N) / (Long_Float (N) + 1.4);
            end if;
         end if;

         return Cn * 2.2219 * Dists (H);
      end;
   end Qn_Scale_Core;

   function Qn_Scale (Values : Long_Float_Array) return Long_Float is
   begin
      for V of Values loop
         if V <= 0.0 then
            raise Constraint_Error with
              "Qn_Scale: all values must be strictly positive; got"
              & Long_Float'Image (V);
         end if;
      end loop;
      return Qn_Scale_Core (Values);
   end Qn_Scale;


   --  ── Lambda estimation ─────────────────────────────────────────────────

   --  Return True when Box_Cox_Inverse is well-defined for the UCL of an
   --  I chart built from Values transformed at Lambda.
   --
   --  The I-chart UCL in z-space is Grand_Mean_Z + 3 * Mean_MR_Z / D2.
   --  For Lambda >= 0.0 the inverse is always defined (exp is always > 0;
   --  positive-lambda power is always > 0 when the base is > 0 and we have
   --  positive token counts).  For Lambda < 0.0 the inverse requires
   --  UCL_Z * Lambda + 1 > 0, i.e. UCL_Z < -1.0 / Lambda (the asymptote).
   function UCL_Z_Invertible
     (Values : Long_Float_Array; Lambda : Long_Float) return Boolean
   is
      N        : constant Long_Float := Long_Float (Values'Length);
      Sum_Z    : Long_Float := 0.0;
      Prev_Z   : Long_Float := 0.0;
      Has_Prev : Boolean    := False;
      MR_Sum   : Long_Float := 0.0;
      MR_Cnt   : Natural    := 0;
      Mean_Z   : Long_Float;
      Mean_MR  : Long_Float;
      UCL_Z    : Long_Float;
   begin
      --  For Lambda >= 0, Box_Cox_Inverse is always defined on positive reals.
      if Lambda >= 0.0 then
         return True;
      end if;

      --  Compute Grand_Mean_Z and Mean_MR_Z in the transformed space.
      for X of Values loop
         declare
            Z : constant Long_Float := Box_Cox (X, Lambda);
         begin
            Sum_Z := Sum_Z + Z;
            if Has_Prev then
               MR_Sum := MR_Sum + abs (Z - Prev_Z);
               MR_Cnt := MR_Cnt + 1;
            end if;
            Prev_Z   := Z;
            Has_Prev := True;
         end;
      end loop;

      Mean_Z  := Sum_Z / N;
      Mean_MR := (if MR_Cnt > 0 then MR_Sum / Long_Float (MR_Cnt) else 0.0);
      UCL_Z   := Mean_Z + 3.0 * Mean_MR / D2;

      --  Safe iff UCL_Z * Lambda + 1 > 0  (Lambda < 0 here).
      return UCL_Z * Lambda + 1.0 > 0.0;
   end UCL_Z_Invertible;

   --  Evaluate the Box-Cox MLE profile log-likelihood for a given lambda.
   --  L(lambda) = -(n/2) * ln(var_z) + (lambda-1) * sum ln(x_i)
   --  Returns Long_Float'First when the variance is zero (degenerate).
   function Log_Likelihood
     (Values      : Long_Float_Array;
      Lambda      : Long_Float;
      Sum_Log_X   : Long_Float) return Long_Float
   is
      N      : constant Long_Float := Long_Float (Values'Length);
      Sum_Z  : Long_Float := 0.0;
      Sum_Z2 : Long_Float := 0.0;
      Var_Z  : Long_Float;
      Mean_Z : Long_Float;
   begin
      for X of Values loop
         declare
            Z : constant Long_Float := Box_Cox (X, Lambda);
         begin
            Sum_Z  := Sum_Z  + Z;
            Sum_Z2 := Sum_Z2 + Z * Z;
         end;
      end loop;
      Mean_Z := Sum_Z / N;
      Var_Z  := Sum_Z2 / N - Mean_Z * Mean_Z;
      if Var_Z <= 0.0 then
         return Long_Float'First;
      end if;
      return -(N / 2.0) * Log (Var_Z) + (Lambda - 1.0) * Sum_Log_X;
   end Log_Likelihood;

   --  Evaluate the robust profile log-likelihood for a given lambda.
   --  Substitutes the Qn scale estimator for the sample standard deviation.
   --  L_robust(lambda) = -N * ln(Qn(z)) + (lambda-1) * sum ln(x_i)
   --  Returns Long_Float'First when Qn_Scale returns zero (degenerate).
   function Robust_Log_Likelihood
     (Values      : Long_Float_Array;
      Lambda      : Long_Float;
      Sum_Log_X   : Long_Float) return Long_Float
   is
      N      : constant Long_Float := Long_Float (Values'Length);
      Z_Vals : Long_Float_Array (1 .. Values'Length);
      S      : Long_Float;
   begin
      for I in Values'Range loop
         Z_Vals (I - Values'First + 1) := Box_Cox (Values (I), Lambda);
      end loop;
      S := Qn_Scale_Core (Z_Vals);
      if S <= 0.0 then
         return Long_Float'First;
      end if;
      return -N * Log (S) + (Lambda - 1.0) * Sum_Log_X;
   end Robust_Log_Likelihood;

   function Estimate_Lambda
     (Values        : Long_Float_Array;
      Use_Robust    : Boolean := False;
      Fallback_Used : out Boolean) return Long_Float
   is
   begin
      Fallback_Used := False;

      --  Need at least 3 observations for meaningful estimation.
      if Values'Length < 3 then
         return 0.0;
      end if;

      --  Constant-data pre-check: if all values are equal (or differ only
      --  by floating-point noise), Var_Z will be a near-zero artefact that
      --  inflates the log-likelihood spuriously.  Detect this before entering
      --  the grid and return the safe fallback immediately.
      declare
         Min_X : Long_Float := Values (Values'First);
         Max_X : Long_Float := Values (Values'First);
      begin
         for X of Values loop
            if X < Min_X then Min_X := X; end if;
            if X > Max_X then Max_X := X; end if;
         end loop;
         if Max_X - Min_X < 1.0e-10 * Max_X then
            Fallback_Used := True;
            return 0.0;
         end if;
      end;

      --  Pre-compute the constant term sum ln(x_i) used in every evaluation.
      declare
         Sum_Log_X : Long_Float := 0.0;
      begin
         for X of Values loop
            if X <= 0.0 then
               raise Constraint_Error with
                 "Estimate_Lambda: all values must be strictly positive";
            end if;
            Sum_Log_X := Sum_Log_X + Log (X);
         end loop;

         --  Coarse grid search: step 0.1 over [-5.0, 5.0] (101 evaluations).
         --  Track the global best (Best_Lambda) and the best lambda whose I-chart
         --  UCL is back-transform-safe (Best_Safe_Lambda).
         declare
            Best_Lambda      : Long_Float := -5.0;
            Best_LL          : Long_Float := Long_Float'First;
            Best_Safe_Lambda : Long_Float := 0.0;
            Best_Safe_LL     : Long_Float := Long_Float'First;
            Lambda           : Long_Float := -5.0;
         begin
            while Lambda <= 5.0 + 1.0e-9 loop
               declare
                  LL : constant Long_Float :=
                    (if Use_Robust
                     then Robust_Log_Likelihood
                            (Values, Lambda, Sum_Log_X)
                     else Log_Likelihood
                            (Values, Lambda, Sum_Log_X));
               begin
                  if LL > Best_LL then
                     Best_LL     := LL;
                     Best_Lambda := Lambda;
                  end if;
                  if LL > Best_Safe_LL
                    and then UCL_Z_Invertible (Values, Lambda)
                  then
                     Best_Safe_LL     := LL;
                     Best_Safe_Lambda := Lambda;
                  end if;
               end;
               Lambda := Lambda + 0.1;
            end loop;

            --  Degenerate data: every log-likelihood evaluation returned
            --  Long_Float'First (e.g. all observations identical).
            --  Fall back to lambda = 0.0 (log transform).
            if Best_LL = Long_Float'First then
               Fallback_Used := True;
               return 0.0;
            end if;

            --  Fine search: step 0.01 within +-0.15 of the coarse best.
            --  Track both the global fine winner and the best safe fine winner.
            declare
               Fine_Lo        : constant Long_Float :=
                 Long_Float'Max (-5.0, Best_Lambda - 0.15);
               Fine_Hi        : constant Long_Float :=
                 Long_Float'Min (5.0,   Best_Lambda + 0.15);
               Fine_Best      : Long_Float := Best_Lambda;
               Fine_LL        : Long_Float := Best_LL;
               Fine_Safe_Best : Long_Float := Best_Safe_Lambda;
               Fine_Safe_LL   : Long_Float := Best_Safe_LL;
               FL             : Long_Float := Fine_Lo;
            begin
               while FL <= Fine_Hi + 1.0e-9 loop
                  declare
                     LL : constant Long_Float :=
                       (if Use_Robust
                        then Robust_Log_Likelihood
                               (Values, FL, Sum_Log_X)
                        else Log_Likelihood
                               (Values, FL, Sum_Log_X));
                  begin
                     if LL > Fine_LL then
                        Fine_LL   := LL;
                        Fine_Best := FL;
                     end if;
                     if LL > Fine_Safe_LL
                       and then UCL_Z_Invertible (Values, FL)
                     then
                        Fine_Safe_LL   := LL;
                        Fine_Safe_Best := FL;
                     end if;
                  end;
                  FL := FL + 0.01;
               end loop;

               --  Prefer the MLE optimum if it is back-transform-safe.
               if UCL_Z_Invertible (Values, Fine_Best) then
                  return Fine_Best;
               end if;

               --  Otherwise use the best safe lambda.  If none was found
               --  (all grid candidates unsafe — extremely unlikely for
               --  reasonable data), fall back to lambda = 0.0.
               Fallback_Used := True;
               if Fine_Safe_LL > Long_Float'First then
                  return Fine_Safe_Best;
               else
                  return 0.0;
               end if;
            end;
         end;
      end;
   end Estimate_Lambda;
end Coyote_SQC.Statistics.I_Chart;
