--  Coyote_SQC.Statistics.P_Chart body.
--
--  Project: coyote

with Ada.Numerics.Long_Elementary_Functions;

package body Coyote_SQC.Statistics.P_Chart is

   use Ada.Numerics.Long_Elementary_Functions;

   function Compute_Limits
     (Grand_P : Long_Float;
      N       : Natural) return Limits_Record
   is
   begin
      if N = 0 then
         return
           (UCL       => 0.0,
            CL        => 0.0,
            LCL       => 0.0,
            Undefined => True);
      end if;

      declare
         NF     : constant Long_Float := Long_Float (N);
         Spread : constant Long_Float :=
           3.0 * Sqrt (Grand_P * (1.0 - Grand_P) / NF);
      begin
         return
           (UCL       => Grand_P + Spread,
            CL        => Grand_P,
            LCL       => Long_Float'Max (0.0, Grand_P - Spread),
            Undefined => False);
      end;
   end Compute_Limits;

end Coyote_SQC.Statistics.P_Chart;
