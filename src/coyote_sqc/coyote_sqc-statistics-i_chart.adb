--  Coyote_SQC.Statistics.I_Chart body.
--
--  Project: coyote

with Ada.Numerics.Long_Elementary_Functions;

package body Coyote_SQC.Statistics.I_Chart is

   use Ada.Numerics.Long_Elementary_Functions;

   --  d2 for moving range of span 2.
   D2 : constant Long_Float := 1.128;

   --  D4 for MR chart UCL factor, span 2.
   D4 : constant Long_Float := 3.267;

   --  ── Standard I/MR limit computation ───────────────────────────────────

   function Compute_I_Limits
     (Grand_Mean : Long_Float;
      Mean_MR    : Long_Float) return Limits_Record
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
         Spread  : constant Long_Float := 3.0 * Mean_MR / D2;
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

   --  ── Lambda estimation (Box-Cox MLE) ───────────────────────────────────

   --  Evaluate the Box-Cox profile log-likelihood for a given lambda.
   --  L(λ) = -(n/2) * ln(var_z) + (λ-1) * Σ ln(x_i)
   --  where var_z is the biased sample variance of the transformed values.
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

   function Estimate_Lambda (Values : Long_Float_Array) return Long_Float is
   begin
      --  Need at least 3 observations for meaningful estimation.
      if Values'Length < 3 then
         return 0.0;
      end if;

      --  Pre-compute the constant term Σ ln(x_i) used in every evaluation.
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

         --  Coarse grid search: step 0.1 over [-2.0, 2.0] (41 evaluations).
         declare
            Best_Lambda : Long_Float := -2.0;
            Best_LL     : Long_Float := Long_Float'First;
            Lambda      : Long_Float := -2.0;
         begin
            while Lambda <= 2.0 + 1.0e-9 loop
               declare
                  LL : constant Long_Float :=
                    Log_Likelihood (Values, Lambda, Sum_Log_X);
               begin
                  if LL > Best_LL then
                     Best_LL     := LL;
                     Best_Lambda := Lambda;
                  end if;
               end;
               Lambda := Lambda + 0.1;
            end loop;

            --  Fine search: step 0.01 within ±0.15 of the coarse best.
            declare
               Fine_Lo   : constant Long_Float :=
                 Long_Float'Max (-2.0, Best_Lambda - 0.15);
               Fine_Hi   : constant Long_Float :=
                 Long_Float'Min (2.0,  Best_Lambda + 0.15);
               Fine_Best : Long_Float := Best_Lambda;
               Fine_LL   : Long_Float := Best_LL;
               FL        : Long_Float := Fine_Lo;
            begin
               while FL <= Fine_Hi + 1.0e-9 loop
                  declare
                     LL : constant Long_Float :=
                       Log_Likelihood (Values, FL, Sum_Log_X);
                  begin
                     if LL > Fine_LL then
                        Fine_LL   := LL;
                        Fine_Best := FL;
                     end if;
                  end;
                  FL := FL + 0.01;
               end loop;
               return Fine_Best;
            end;
         end;
      end;
   end Estimate_Lambda;

end Coyote_SQC.Statistics.I_Chart;
