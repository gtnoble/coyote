--  Coyote_SQC.Statistics.S_Chart body.
--
--  Project: coyote

with Ada.Numerics.Long_Elementary_Functions;
with Coyote_SQC.Statistics.C4;

package body Coyote_SQC.Statistics.S_Chart is

   use Ada.Numerics.Long_Elementary_Functions;

   function Compute_Limits
     (Pooled_S : Long_Float;
      N        : Positive) return Limits_Record
   is
   begin
      if N = 1 then
         return
           (UCL       => 0.0,
            CL        => 0.0,
            LCL       => 0.0,
            Undefined => True);
      end if;

      if Pooled_S = 0.0 then
         --  §7.5: Pooled_S=0 → no limits (all setup sessions have n=1).
         return
           (UCL       => Long_Float'Last,
            CL        => 0.0,
            LCL       => Long_Float'First,
            Undefined => True);
      end if;

      declare
         C4_N    : constant Long_Float := C4.C4 (N);
         Half_W  : constant Long_Float :=
           3.0 * Pooled_S * Sqrt (1.0 - C4_N ** 2);
      begin
         return
           (UCL       => C4_N * Pooled_S + Half_W,
            CL        => C4_N * Pooled_S,
            LCL       => Long_Float'Max (0.0, C4_N * Pooled_S - Half_W),
            Undefined => False);
      end;
   end Compute_Limits;

end Coyote_SQC.Statistics.S_Chart;
