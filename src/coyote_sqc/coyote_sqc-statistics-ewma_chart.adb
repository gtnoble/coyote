--  Coyote_SQC.Statistics.EWMA_Chart body.
--
--  Project: coyote

with Ada.Numerics.Long_Elementary_Functions;

package body Coyote_SQC.Statistics.EWMA_Chart is

   use Ada.Numerics.Long_Elementary_Functions;

   --  d2 constant for span-2 moving range (same as I_Chart).

   function Compute_Z
     (X      : Long_Float;
      Z_Prev : Long_Float;
      Weight : Long_Float) return Long_Float
   is
   begin
      return Weight * X + (1.0 - Weight) * Z_Prev;
   end Compute_Z;

   function Compute_EWMA_Limits
     (Grand_Mean : Long_Float;
      Sigma      : Long_Float;
      Weight     : Long_Float;
      L          : Long_Float;
      T          : Positive) return Limits_Record
   is
      --  Sigma is already the process-sigma estimate (Mean_MR / d2).
      --  Scale factor accounts for the variance reduction due to smoothing
      --  and the degree of convergence at step T.
      Scale_Factor : Long_Float;
      Half_Width   : Long_Float;
      Raw_LCL      : Long_Float;
   begin
      if Sigma <= 0.0 then
         return (UCL => 0.0, CL => Grand_Mean, LCL => 0.0,
                 Has_UCL => False, Has_LCL => False);
      end if;

      --  Variance factor: lambda/(2-lambda) * [1 - (1-lambda)^(2t)]
      --  Use the exact formula; the term (1-Weight)^(2*T) vanishes for
      --  large T, giving the steady-state factor Weight / (2 - Weight).
      Scale_Factor :=
        Sqrt (Weight / (2.0 - Weight)
              * (1.0 - (1.0 - Weight) ** (2 * T)));

      Half_Width := L * Sigma * Scale_Factor;
      Raw_LCL    := Grand_Mean - Half_Width;

      return
        (UCL     => Grand_Mean + Half_Width,
         CL      => Grand_Mean,
         LCL     => Long_Float'Max (0.0, Raw_LCL),
         Has_UCL => True,
         Has_LCL => Raw_LCL > 0.0);
   end Compute_EWMA_Limits;

end Coyote_SQC.Statistics.EWMA_Chart;
