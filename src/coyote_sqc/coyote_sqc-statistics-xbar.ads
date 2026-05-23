--  Coyote_SQC.Statistics.Xbar — Xbar chart limit computation.
--
--  Project: coyote

package Coyote_SQC.Statistics.Xbar is

   --  Compute the Xbar control limits for a single point whose session has
   --  N turns.  Grand_Mean and Pooled_S come from the setup interval.
   --
   --  When N = 1 the returned record has Undefined = True and UCL/LCL are
   --  set to Long_Float'Last / Long_Float'First respectively (no limits).
   function Compute_Limits
     (Grand_Mean : Long_Float;
      Pooled_S   : Long_Float;
      N          : Positive) return Limits_Record;

end Coyote_SQC.Statistics.Xbar;
