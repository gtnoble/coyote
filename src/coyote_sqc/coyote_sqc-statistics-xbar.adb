--  Coyote_SQC.Statistics.Xbar body.
--
--  Project: coyote

with Ada.Numerics.Long_Elementary_Functions;
with Coyote_SQC.Statistics.C4;

package body Coyote_SQC.Statistics.Xbar is

   use Ada.Numerics.Long_Elementary_Functions;

   function Compute_Limits
     (Grand_Mean : Long_Float;
      Pooled_S   : Long_Float;
      N          : Positive) return Limits_Record
   is
   begin
      if N = 1 then
         --  No variance estimate available for a single-turn session.
         return
           (UCL       => Long_Float'Last,
            CL        => Grand_Mean,
            LCL       => Long_Float'First,
            Undefined => True);
      end if;

      if Pooled_S = 0.0 then
         --  §7.5: all setup sessions have n=1 → Pooled_S=0; no limits drawn.
         return
           (UCL       => Long_Float'Last,
            CL        => Grand_Mean,
            LCL       => Long_Float'First,
            Undefined => True);
      end if;

      declare
         C4_N   : constant Long_Float := C4.C4 (N);
         NF     : constant Long_Float := Long_Float (N);
         Spread : constant Long_Float :=
           3.0 * Pooled_S / (C4_N * Sqrt (NF));
      begin
         return
           (UCL       => Grand_Mean + Spread,
            CL        => Grand_Mean,
            LCL       => Grand_Mean - Spread,
            Undefined => False);
      end;
   end Compute_Limits;

end Coyote_SQC.Statistics.Xbar;
