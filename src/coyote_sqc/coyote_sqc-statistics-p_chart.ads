--  Coyote_SQC.Statistics.P_Chart — p chart limit computation.
--
--  Project: coyote

package Coyote_SQC.Statistics.P_Chart is

   --  Compute the p chart control limits for a session with N observations
   --  (total tool calls, total turns, etc.).  Grand_P is the grand proportion
   --  from the setup interval.
   --
   --  When N = 0 the returned record has Undefined = True (session excluded).
   function Compute_Limits
     (Grand_P : Long_Float;
      N       : Natural) return Limits_Record;

end Coyote_SQC.Statistics.P_Chart;
