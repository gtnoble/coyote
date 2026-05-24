--  Coyote_SQC.Statistics.EWMA_Chart — Exponentially Weighted Moving Average
--  chart computation.
--
--  An EWMA chart monitors sustained shifts more sensitively than a 3-sigma
--  Individuals (I) chart by applying exponential smoothing to the sequence
--  of session-level observations.
--
--  Statistic:
--    Z_t = Weight * x_t + (1 - Weight) * Z_{t-1},  Z_0 = Grand_Mean
--
--  Time-varying control limits (converging to steady-state as t -> inf):
--    UCL_t = Grand_Mean +/- L * Sigma * sqrt(Weight / (2 - Weight)
--                                             * (1 - (1 - Weight)^(2*t)))
--
--  Steady-state limits (t -> inf):
--    UCL_inf / LCL_inf = Grand_Mean +/- L * Sigma * sqrt(Weight / (2 - Weight))
--
--  Sigma is estimated from the paired I chart: Sigma = Mean_MR / d2
--  where d2 = 1.128 (span-2 moving range constant).
--
--  Project: coyote


package Coyote_SQC.Statistics.EWMA_Chart is

   --  Update the EWMA statistic for one new observation.
   --
   --  Z_Prev is the statistic from the previous step, Z_{t-1}.
   --  On the very first step pass Grand_Mean as Z_Prev (Z_0 = Grand_Mean).
   --  Weight must be in (0.0, 1.0].
   --
   --  Returns Z_t = Weight * X + (1 - Weight) * Z_Prev.
   function Compute_Z
     (X      : Long_Float;
      Z_Prev : Long_Float;
      Weight : Long_Float) return Long_Float;

   --  Compute time-varying EWMA control limits at step T (1-based).
   --
   --  Grand_Mean is the process target (mean of setup-interval values).
   --  Sigma     is the process standard deviation estimate (Mean_MR / d2).
   --  Weight    is the EWMA smoothing parameter, in (0.0, 1.0].
   --  L         is the sigma multiplier for the control limits (typically 3.0).
   --  T         is the 1-based step index of the current observation.
   --
   --  When Sigma = 0.0, Has_UCL and Has_LCL are both False.
   --  The LCL is clamped to 0.0; Has_LCL is False when the formula
   --  yields LCL <= 0.0.
   function Compute_EWMA_Limits
     (Grand_Mean : Long_Float;
      Sigma      : Long_Float;
      Weight     : Long_Float;
      L          : Long_Float;
      T          : Positive) return Limits_Record;

end Coyote_SQC.Statistics.EWMA_Chart;
