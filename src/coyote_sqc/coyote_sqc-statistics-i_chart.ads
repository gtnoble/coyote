--  Coyote_SQC.Statistics.I_Chart — Individuals (I) and Moving-Range (MR)
--  chart limit computation.
--
--  For an I chart every observation is a single session-level value; there
--  is no within-session subgroup.  Control limits are derived from the mean
--  moving range (MR̄) between consecutive setup-interval sessions.
--
--  Constants:
--    d2 = 1.128  (moving range of span 2)
--    D4 = 3.267  (MR chart UCL factor for span 2)
--
--  Project: coyote

package Coyote_SQC.Statistics.I_Chart is

   --  Compute the I-chart (Individuals) control limits.
   --
   --  Grand_Mean is the mean of all setup-interval session values.
   --  Mean_MR    is the mean of consecutive moving ranges (MR̄).
   --
   --  When Mean_MR = 0.0 (all setup sessions have the same value, or only
   --  one setup session exists) Has_UCL and Has_LCL are both False.
   --  The LCL is clamped to 0 when the formula yields a negative value;
   --  Has_LCL is True only when the clamped LCL value would be > 0.
   function Compute_I_Limits
     (Grand_Mean : Long_Float;
      Mean_MR    : Long_Float) return Limits_Record;

   --  Compute the MR-chart (Moving Range) control limits.
   --
   --  Mean_MR is the mean moving range from the setup interval (MR̄).
   --
   --  UCL = D4 * MR̄ = 3.267 * MR̄.
   --  LCL = 0 always (Has_LCL is always False).
   --  When Mean_MR = 0.0, Has_UCL is False.
   function Compute_MR_Limits (Mean_MR : Long_Float) return Limits_Record;

end Coyote_SQC.Statistics.I_Chart;
