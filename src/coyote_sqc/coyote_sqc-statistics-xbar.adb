--  Coyote_SQC.Statistics.Xbar body.
--
--  Project: coyote

with Ada.Numerics.Long_Elementary_Functions;

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
           (UCL     => 0.0,
            CL      => Grand_Mean,
            LCL     => 0.0,
            Has_UCL => False,
            Has_LCL => False);
      end if;

      if Pooled_S = 0.0 then
         --  §7.5: all setup sessions have n=1 → Pooled_S=0; no limits drawn.
         return
           (UCL     => 0.0,
            CL      => Grand_Mean,
            LCL     => 0.0,
            Has_UCL => False,
            Has_LCL => False);
      end if;

         --  Pooled_S is a direct estimator of sigma (not s_bar),
         --  so no c4 unbiasing constant is needed here.
      declare
         NF     : constant Long_Float := Long_Float (N);
         Spread : constant Long_Float :=
           3.0 * Pooled_S / Sqrt (NF);
      begin
         --  Xbar LCL can be negative; it is always drawn when limits exist.
         return
           (UCL     => Grand_Mean + Spread,
            CL      => Grand_Mean,
            LCL     => Grand_Mean - Spread,
            Has_UCL => True,
            Has_LCL => True);
      end;
   end Compute_Limits;

end Coyote_SQC.Statistics.Xbar;
