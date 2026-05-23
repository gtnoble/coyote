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
           (UCL     => 0.0,
            CL      => 0.0,
            LCL     => 0.0,
            Has_UCL => False,
            Has_LCL => False);
      end if;

      if Pooled_S = 0.0 then
         --  §7.5: Pooled_S=0 → no limits (all setup sessions have n=1).
         return
           (UCL     => 0.0,
            CL      => 0.0,
            LCL     => 0.0,
            Has_UCL => False,
            Has_LCL => False);
      end if;

      declare
         C4_N    : constant Long_Float := C4.C4 (N);
         Half_W  : constant Long_Float :=
           3.0 * Pooled_S * Sqrt (1.0 - C4_N ** 2);
         LCL_Val : constant Long_Float :=
           Long_Float'Max (0.0, C4_N * Pooled_S - Half_W);
      begin
         --  LCL is drawn only when the formula yields a positive value;
         --  a clamped LCL = 0 means there is no meaningful lower bound.
         return
           (UCL     => C4_N * Pooled_S + Half_W,
            CL      => C4_N * Pooled_S,
            LCL     => LCL_Val,
            Has_UCL => True,
            Has_LCL => LCL_Val > 0.0);
      end;
   end Compute_Limits;

end Coyote_SQC.Statistics.S_Chart;
