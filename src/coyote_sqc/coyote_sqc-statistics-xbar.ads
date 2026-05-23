--  Coyote_SQC.Statistics.Xbar — Xbar chart limit computation.
--
--  Project: coyote

package Coyote_SQC.Statistics.Xbar is

   --  Compute the Xbar control limits for a single point whose session has
   --  N turns.  Grand_Mean and Pooled_S come from the setup interval.
   --
   --  When N = 1 or Pooled_S = 0 the returned record has Has_UCL and
   --  Has_LCL both False (no limits drawn).  When limits are defined the
   --  LCL may be negative; Has_LCL is always True in that case.
   function Compute_Limits
     (Grand_Mean : Long_Float;
      Pooled_S   : Long_Float;
      N          : Positive) return Limits_Record;

end Coyote_SQC.Statistics.Xbar;
