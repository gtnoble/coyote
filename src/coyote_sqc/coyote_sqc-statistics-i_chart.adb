--  Coyote_SQC.Statistics.I_Chart body.
--
--  Project: coyote

package body Coyote_SQC.Statistics.I_Chart is

   --  d2 for moving range of span 2.
   D2 : constant Long_Float := 1.128;

   --  D4 for MR chart UCL factor, span 2.
   D4 : constant Long_Float := 3.267;

   function Compute_I_Limits
     (Grand_Mean : Long_Float;
      Mean_MR    : Long_Float) return Limits_Record
   is
   begin
      if Mean_MR = 0.0 then
         --  Cannot derive spread estimate; no limits drawn.
         return
           (UCL     => 0.0,
            CL      => Grand_Mean,
            LCL     => 0.0,
            Has_UCL => False,
            Has_LCL => False);
      end if;

      declare
         Spread    : constant Long_Float := 3.0 * Mean_MR / D2;
         Raw_LCL   : constant Long_Float := Grand_Mean - Spread;
         Eff_LCL   : constant Long_Float :=
           (if Raw_LCL < 0.0 then 0.0 else Raw_LCL);
      begin
         return
           (UCL     => Grand_Mean + Spread,
            CL      => Grand_Mean,
            LCL     => Eff_LCL,
            Has_UCL => True,
            Has_LCL => Eff_LCL > 0.0);
      end;
   end Compute_I_Limits;

   function Compute_MR_Limits (Mean_MR : Long_Float) return Limits_Record is
   begin
      if Mean_MR = 0.0 then
         return
           (UCL     => 0.0,
            CL      => 0.0,
            LCL     => 0.0,
            Has_UCL => False,
            Has_LCL => False);
      end if;

      return
        (UCL     => D4 * Mean_MR,
         CL      => Mean_MR,
         LCL     => 0.0,
         Has_UCL => True,
         Has_LCL => False);
   end Compute_MR_Limits;

end Coyote_SQC.Statistics.I_Chart;
