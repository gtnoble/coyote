--  Coyote_SQC.Statistics.S_Chart — s chart limit computation.
--
--  Project: coyote

package Coyote_SQC.Statistics.S_Chart is

   --  Compute the s chart control limits for a session with N turns.
   --  Pooled_S is the pooled standard deviation from the setup interval.
   --
   --  When N = 1 the returned record has Undefined = True (no s statistic).
   function Compute_Limits
     (Pooled_S : Long_Float;
      N        : Positive) return Limits_Record;

end Coyote_SQC.Statistics.S_Chart;
