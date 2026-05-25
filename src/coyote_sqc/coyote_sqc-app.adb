--  Coyote_SQC.App body.
--
--  Project: coyote

with Ada.Exceptions;
with Ada.Calendar;
with Ada.Numerics.Long_Elementary_Functions;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Coyote_SQC.Metrics;
with Coyote_SQC.Session_Parser;
with Coyote_SQC.Statistics.C4;
with Coyote_SQC.Statistics.P_Chart;
with Coyote_SQC.Statistics.S_Chart;
with Coyote_SQC.Statistics.Xbar;
with Coyote_SQC.Statistics.I_Chart;
with Gtk.Main;
with Gtk.Widget;

--  Forward declaration — UI builder lives in Coyote_SQC.UI.
with Coyote_SQC.Config;
with Coyote_SQC.Statistics;
with Coyote_SQC.Statistics.EWMA_Chart;
with Coyote_SQC.Workspace;
with Coyote_SQC.UI;
with Coyote_SQC.UI.Dialogs;
with Coyote_SQC.UI.Toolbar;
with Coyote_SQC.UI.Chart_Canvas;

package body Coyote_SQC.App is
   use type Ada.Calendar.Time;
   use type Gtk.Window.Gtk_Window;

   use Ada.Numerics.Long_Elementary_Functions;
   use Coyote_SQC.Charts;
   use Coyote_SQC.Data_Model;

   --  ── Helper: sample mean of a Natural vector ───────────────────────────

   function Mean_LF (V : Natural_Vectors.Vector) return Long_Float is
      N : constant Natural := Natural (V.Length);
   begin
      if N = 0 then return 0.0; end if;
      declare
         S : Long_Float := 0.0;
      begin
         for X of V loop
            S := S + Long_Float (X);
         end loop;
         return S / Long_Float (N);
      end;
   end Mean_LF;

   function StdDev_LF (V : Natural_Vectors.Vector) return Long_Float is
      N : constant Natural := Natural (V.Length);
   begin
      if N < 2 then return 0.0; end if;
      declare
         M    : constant Long_Float := Mean_LF (V);
         Sum2 : Long_Float := 0.0;
      begin
         for X of V loop
            declare D : constant Long_Float := Long_Float (X) - M;
            begin Sum2 := Sum2 + D * D; end;
         end loop;
         return Sqrt (Sum2 / Long_Float (N - 1));
      end;
   end StdDev_LF;

   --  ── Compute_Session_Stat ─────────────────────────────────────────────

   procedure Compute_Session_Stat
     (Metrics    :     Session_Metrics_Record;
      Kind       :     Chart_Kind;
      Value      : out Long_Float;
      N          : out Positive;
      Excluded   : out Boolean;
      Single     : out Boolean;
      Hollow_Gray: out Boolean)
   is
   begin
      Value       := 0.0;
      N           := 1;
      Excluded    := False;
      Single      := False;
      Hollow_Gray := False;
      case Kind is
         when Turn_Tokens_Xbar =>
            N := Metrics.N_Turns;
            Value  := Mean_LF (Metrics.Per_Turn_Output_Tokens);
            Single := (N = 1);

         when Turn_Tokens_S =>
            N := Metrics.N_Turns;
            if N = 1 then
               Excluded := True;
            else
               Value := StdDev_LF (Metrics.Per_Turn_Output_Tokens);
            end if;

         when Tool_Call_Tokens_Xbar =>
            if Metrics.N_Tool_Call_Turns_For_Chart = 0 then
               Excluded    := True;
               Hollow_Gray := True;
            else
               N      := Metrics.N_Tool_Call_Turns_For_Chart;
               Value  := Mean_LF (Metrics.Per_Turn_Tool_Tokens);
               Single := (N = 1);
            end if;

         when Tool_Call_Tokens_S =>
            if Metrics.N_Tool_Call_Turns_For_Chart = 0 then
               Excluded    := True;
               Hollow_Gray := True;
            elsif Metrics.N_Tool_Call_Turns_For_Chart <= 1 then
               Excluded := True;
            else
               N     := Metrics.N_Tool_Call_Turns_For_Chart;
               Value := StdDev_LF (Metrics.Per_Turn_Tool_Tokens);
            end if;

         when Thinking_Tokens_Xbar =>
            if not Metrics.Any_Thinking then
               Excluded    := True;
               Hollow_Gray := True;
            else
               N      := Metrics.N_Thinking_Turns_For_Chart;
               Value  := Mean_LF (Metrics.Per_Turn_Thinking_Tokens);
               Single := (N = 1);
            end if;

         when Thinking_Tokens_S =>
            if not Metrics.Any_Thinking then
               Excluded    := True;
               Hollow_Gray := True;
            elsif Metrics.N_Thinking_Turns_For_Chart <= 1 then
               Excluded := True;
            else
               N     := Metrics.N_Thinking_Turns_For_Chart;
               Value := StdDev_LF (Metrics.Per_Turn_Thinking_Tokens);
            end if;

         when Tool_Call_Failure_Rate =>
            if Metrics.N_Tool_Calls = 0 then
               Excluded := True;
            else
               N     := Metrics.N_Tool_Calls;
               Value := Long_Float (Metrics.N_Failed_Tool_Calls)
                        / Long_Float (Metrics.N_Tool_Calls);
            end if;

         when Fraction_Tool_Call_Turns =>
            N     := Metrics.N_Turns;
            Value := Long_Float (Metrics.N_Tool_Call_Turns)
                     / Long_Float (N);

         when Fraction_Thinking_Turns =>
            N     := Metrics.N_Turns;
            Value := Long_Float (Metrics.N_Thinking_Turns)
                     / Long_Float (N);
         when Session_Input_Tokens_I =>
            Value := Long_Float (Metrics.Total_Input_Tokens);
            N     := 1;

         when Session_Output_Tokens_I =>
            Value := Long_Float (Metrics.Total_Output_Tokens);
            N     := 1;

         when Session_Cache_Read_Tokens_I =>
            Value := Long_Float (Metrics.Total_Cache_Read_Tokens);
            N     := 1;

         when Session_Cache_Write_Tokens_I =>
            Value := Long_Float (Metrics.Total_Cache_Write_Tokens);
            N     := 1;
         when Session_Thinking_Tokens_I =>
            Value := Long_Float (Metrics.Total_Thinking_Tokens);
            N     := 1;

         when Session_Tool_Call_Tokens_I =>
            Value := Long_Float (Metrics.Total_Tool_Call_Input_Tokens);
            N     := 1;

         when Session_Tool_Call_Result_Tokens_I =>
            Value := Long_Float (Metrics.Total_Tool_Call_Result_Tokens);
            N     := 1;

         when Session_Uncached_Input_Tokens_I =>
            Value := Long_Float (Metrics.Total_Uncached_Input_Tokens);
            N     := 1;

         when Session_Turn_Count_I =>
            Value := Long_Float (Metrics.N_Turns);
            N     := 1;

         when Fraction_Thinking_Tokens_I =>
            if Metrics.Total_Output_Tokens = 0 then
               Excluded := True;
            else
               N     := 1;
               Value := Long_Float (Metrics.Total_Thinking_Tokens)
                        / Long_Float (Metrics.Total_Output_Tokens);
            end if;

         when Fraction_Tool_Call_Tokens_I =>
            if Metrics.Total_Output_Tokens = 0 then
               Excluded := True;
            else
               N     := 1;
               Value := Long_Float (Metrics.Total_Tool_Call_Input_Tokens)
                        / Long_Float (Metrics.Total_Output_Tokens);
            end if;

         when Fraction_Thinking_Per_Tool_Call_I =>
            if Metrics.Total_Tool_Call_Input_Tokens = 0 then
               Excluded := True;
            else
               N     := 1;
               Value := Long_Float (Metrics.Total_Thinking_Tokens)
                        / Long_Float (Metrics.Total_Tool_Call_Input_Tokens);
            end if;

         when Fraction_Uncached_Input_I =>
            if Metrics.Total_Input_Tokens = 0 then
               Excluded := True;
            else
               N     := 1;
               Value := Long_Float (Metrics.Total_Uncached_Input_Tokens)
                        / Long_Float (Metrics.Total_Input_Tokens);
            end if;

         when Session_Input_Tokens_EWMA
            | Session_Output_Tokens_EWMA
            | Session_Cache_Read_Tokens_EWMA
            | Session_Cache_Write_Tokens_EWMA
            | Session_Thinking_Tokens_EWMA
            | Session_Tool_Call_Tokens_EWMA
            | Session_Tool_Call_Result_Tokens_EWMA
            | Session_Uncached_Input_Tokens_EWMA
            | Session_Turn_Count_EWMA | Fraction_Thinking_Tokens_EWMA | Fraction_Tool_Call_Tokens_EWMA
            | Fraction_Thinking_Per_Tool_Call_EWMA | Fraction_Uncached_Input_EWMA =>
            --  EWMA requires previous Z value; caller overrides in the
            --  per-session loop after calling Compute_Session_Stat.
            Excluded := True;
         when Session_Input_Tokens_MR | Session_Output_Tokens_MR
            | Session_Cache_Read_Tokens_MR | Session_Cache_Write_Tokens_MR
            | Session_Thinking_Tokens_MR
            | Session_Tool_Call_Tokens_MR
            | Session_Tool_Call_Result_Tokens_MR
            | Session_Uncached_Input_Tokens_MR
            | Session_Turn_Count_MR | Fraction_Thinking_Tokens_MR | Fraction_Tool_Call_Tokens_MR
            | Fraction_Thinking_Per_Tool_Call_MR | Fraction_Uncached_Input_MR =>
            --  Moving range requires the previous session value; the caller
            --  (Recompute_Chart) overrides Excluded and Value after this
            --  call for non-first sessions.
            Excluded := True;
      end case;
   end Compute_Session_Stat;

   --  ── Recompute_Chart ──────────────────────────────────────────────────

   procedure Recompute_Chart (Kind : Chart_Kind) is
      Props   : constant Coyote_SQC.Charts.Chart_Properties :=
        Coyote_SQC.Charts.Properties (Kind);

      CD : Chart_Data;
      --  State for moving-range (MR) chart kinds.
      Prev_Total     : Long_Float := 0.0;
      Has_Prev_Total : Boolean    := False;
      --  Box-Cox transformed tracking for MR chart kinds.
      --  State for EWMA chart kinds.
      Z_Ewma_Prev : Long_Float := 0.0;  --  Z_{t-1}; reset to Grand_Mean before loop
      T_Ewma      : Natural    := 0;    --  step counter (1-based)
   begin
      --  Estimate setup parameters.
      CD.Is_Retro := State.Workspace.Setup_Session_Ids.Is_Empty;
      Statistics.Estimate_Parameters
        (Metrics   => State.All_Metrics,
         Setup_Ids => State.Workspace.Setup_Session_Ids,
         Kind      => Kind,
         Method    => State.Workspace.Estimation_Method,
         Parameters => CD.Params);

      --  Box-Cox: when enabled for I/EWMA chart kinds, override the
      --  Grand_Mean and I_Sigma in CD.Params with transformed-space values.
      if (Props.Is_I_Chart or else Props.Is_EWMA_Chart)
        and then Kind not in Session_Turn_Count_I
                              | Session_Turn_Count_EWMA | Fraction_Thinking_Tokens_I | Fraction_Thinking_Tokens_EWMA | Fraction_Tool_Call_Tokens_I | Fraction_Tool_Call_Tokens_EWMA
                              | Fraction_Thinking_Per_Tool_Call_I | Fraction_Thinking_Per_Tool_Call_EWMA
                              | Fraction_Uncached_Input_I | Fraction_Uncached_Input_EWMA
        and then State.Workspace.I_Chart_Box_Cox.Enabled
      then
         declare
            --  Collect setup-interval raw values in chronological order.
            Raw   : Statistics.I_Chart.Long_Float_Array
                      (1 .. Natural (State.All_Metrics.Length));
            N_Raw  : Natural := 0;
            N_Zero : Natural := 0;
            Lambda : Long_Float;
         begin
            for M of State.All_Metrics loop
               if State.Workspace.Setup_Session_Ids.Is_Empty
                 or else State.Workspace.Setup_Session_Ids.Contains
                           (M.Session_Id)
               then
                  declare
                     Val : constant Long_Float :=
                       (case Kind is
                           when Session_Input_Tokens_I
                              | Session_Input_Tokens_MR
                              | Session_Input_Tokens_EWMA      =>
                              Long_Float (M.Total_Input_Tokens),
                           when Session_Cache_Read_Tokens_I
                              | Session_Cache_Read_Tokens_MR
                              | Session_Cache_Read_Tokens_EWMA  =>
                              Long_Float (M.Total_Cache_Read_Tokens),
                           when Session_Cache_Write_Tokens_I
                              | Session_Cache_Write_Tokens_MR
                              | Session_Cache_Write_Tokens_EWMA =>
                              Long_Float (M.Total_Cache_Write_Tokens),
                           when Session_Thinking_Tokens_I
                              | Session_Thinking_Tokens_MR
                              | Session_Thinking_Tokens_EWMA        =>
                              Long_Float (M.Total_Thinking_Tokens),
                           when Session_Tool_Call_Tokens_I
                              | Session_Tool_Call_Tokens_MR
                              | Session_Tool_Call_Tokens_EWMA        =>
                              Long_Float (M.Total_Tool_Call_Input_Tokens),
                           when Session_Tool_Call_Result_Tokens_I
                              | Session_Tool_Call_Result_Tokens_MR
                              | Session_Tool_Call_Result_Tokens_EWMA =>
                              Long_Float (M.Total_Tool_Call_Result_Tokens),
                           when Session_Uncached_Input_Tokens_I
                              | Session_Uncached_Input_Tokens_MR
                              | Session_Uncached_Input_Tokens_EWMA =>
                              Long_Float (M.Total_Uncached_Input_Tokens),
                           when others                          =>
                              Long_Float (M.Total_Output_Tokens));
                  begin
                     if Val > 0.0 then
                        N_Raw := N_Raw + 1;
                        Raw (N_Raw) := Val;
                     else
                        N_Zero := N_Zero + 1;
                     end if;
                  end;
               end if;
            end loop;

            if N_Zero > 0 then
               State.Status_Bar.Set_Text
                 (Natural'Image (N_Zero)
                  & " session(s) with zero tokens excluded from"
                  & " I/MR chart (Box-Cox requires x > 0).");
            end if;

            --  Resolve lambda.
            if State.Workspace.I_Chart_Box_Cox.Lambda_Source =
                  Data_Model.Fixed
            then
               Lambda := State.Workspace.I_Chart_Box_Cox.Fixed_Lambda;
            else
               if N_Raw >= 3 then
                  declare
                     Fallback : Boolean;
                  begin
                     Lambda := Statistics.I_Chart.Estimate_Lambda
                                 (Raw (1 .. N_Raw),
                                  Use_Robust    =>
                                    State.Workspace.I_Chart_Box_Cox
                                      .Lambda_Source =
                                      Data_Model.Robust_Auto,
                                  Fallback_Used => Fallback);
                     if Fallback then
                        State.Status_Bar.Set_Text
                          ("Box-Cox: lambda fell back to 0.0 (log)"
                           & " -- MLE optimum was non-invertible or"
                           & " data was degenerate.");
                     end if;
                  end;
               else
                  Lambda := 0.0;
               end if;
            end if;
            CD.Box_Cox_Lambda := Lambda;
            CD.Box_Cox_Active := True;

            --  Recompute Grand_Mean and I_Sigma in the transformed space.
            --  I_Sigma: classical = mean(MR_z)/d2; robust = Qn(z_vals)/2.2219.
            if N_Raw > 0 then
               declare
                  Z_Vals   : Statistics.I_Chart.Long_Float_Array (1 .. N_Raw);
                  Sum_Z    : Long_Float := 0.0;
                  Prev_Z   : Long_Float := 0.0;
                  Has_PZ   : Boolean    := False;
                  MR_Z_Sum : Long_Float := 0.0;
                  MR_Z_Cnt : Natural    := 0;
               begin
                  for Idx in 1 .. N_Raw loop
                     declare
                        Z : constant Long_Float :=
                          Statistics.I_Chart.Box_Cox (Raw (Idx), Lambda);
                     begin
                        Z_Vals (Idx) := Z;
                        Sum_Z := Sum_Z + Z;
                        if Has_PZ then
                           MR_Z_Sum := MR_Z_Sum + abs (Z - Prev_Z);
                           MR_Z_Cnt := MR_Z_Cnt + 1;
                        end if;
                        Prev_Z := Z;
                        Has_PZ := True;
                     end;
                  end loop;
                  CD.Params.Grand_Mean := Sum_Z / Long_Float (N_Raw);
                  if State.Workspace.Estimation_Method =
                        Data_Model.Robust_Median
                  then
                     if N_Raw >= 2 then
                        CD.Params.I_Sigma :=
                          Statistics.I_Chart.Qn_Scale_Any (Z_Vals) / 2.2219;
                     end if;
                  else
                     CD.Params.I_Sigma :=
                       (if MR_Z_Cnt > 0
                        then MR_Z_Sum / (Long_Float (MR_Z_Cnt) * 1.128)
                        else 0.0);
                  end if;
               end;
            end if;
         end;
      end if;

      --  ── Box-Cox for token MR chart kinds (independent λ_MR) ─────────────
      --  Each MR chart has its own λ_MR estimated from the setup-interval
      --  MR series.  Points are always original-space |x_i − x_{i-1}|.
      if Props.Is_MR_Chart
        and then Kind not in Session_Turn_Count_MR | Fraction_Thinking_Tokens_MR | Fraction_Tool_Call_Tokens_MR
                            | Fraction_Thinking_Per_Tool_Call_MR | Fraction_Uncached_Input_MR
        and then State.Workspace.I_Chart_Box_Cox.Enabled
      then
         declare
            Raws  : Statistics.I_Chart.Long_Float_Array
                      (1 .. Natural (State.All_Metrics.Length));
            N_R   : Natural := 0;
         begin
            for M of State.All_Metrics loop
               if State.Workspace.Setup_Session_Ids.Is_Empty
                 or else State.Workspace.Setup_Session_Ids.Contains
                           (M.Session_Id)
               then
                  N_R := N_R + 1;
                  Raws (N_R) := Long_Float
                    (case Kind is
                        when Session_Input_Tokens_MR        =>
                           M.Total_Input_Tokens,
                        when Session_Output_Tokens_MR       =>
                           M.Total_Output_Tokens,
                        when Session_Cache_Read_Tokens_MR   =>
                           M.Total_Cache_Read_Tokens,
                        when Session_Cache_Write_Tokens_MR  =>
                           M.Total_Cache_Write_Tokens,
                        when Session_Thinking_Tokens_MR     =>
                           M.Total_Thinking_Tokens,
                        when Session_Tool_Call_Tokens_MR    =>
                           M.Total_Tool_Call_Input_Tokens,
                        when Session_Uncached_Input_Tokens_MR =>
                           M.Total_Uncached_Input_Tokens,
                        when others                         =>
                           M.Total_Tool_Call_Result_Tokens);
               end if;
            end loop;

            if N_R >= 2 then
               declare
                  MR_Buf    : Statistics.I_Chart.Long_Float_Array
                                (1 .. N_R - 1);
                  N_MR      : Natural := 0;
                  N_Zero_MR : Natural := 0;
                  Lambda_MR : Long_Float := 0.0;
               begin
                  for Idx in 2 .. N_R loop
                     declare
                        MR_I : constant Long_Float :=
                          abs (Raws (Idx) - Raws (Idx - 1));
                     begin
                        if MR_I > 0.0 then
                           N_MR := N_MR + 1;
                           MR_Buf (N_MR) := MR_I;
                        else
                           N_Zero_MR := N_Zero_MR + 1;
                        end if;
                     end;
                  end loop;

                  if N_Zero_MR > 0 then
                     State.Status_Bar.Set_Text
                       (Natural'Image (N_Zero_MR)
                        & " zero MR value(s) excluded from"
                        & " MR chart lambda estimation.");
                  end if;

                  if State.Workspace.I_Chart_Box_Cox.Lambda_Source =
                        Data_Model.Fixed
                  then
                     Lambda_MR :=
                       State.Workspace.I_Chart_Box_Cox.Fixed_Lambda;
                  elsif N_MR >= 3 then
                     declare
                        Fallback : Boolean;
                     begin
                        Lambda_MR := Statistics.I_Chart.Estimate_Lambda
                          (MR_Buf (1 .. N_MR),
                           Use_Robust    =>
                             State.Workspace.I_Chart_Box_Cox.Lambda_Source =
                             Data_Model.Robust_Auto,
                           Fallback_Used => Fallback);
                     end;
                  end if;

                  if N_MR > 0 then
                     declare
                        W_Arr : Statistics.I_Chart.Long_Float_Array
                                  (1 .. N_MR);
                        W_Sum : Long_Float := 0.0;
                        CL_W  : Long_Float;
                     begin
                        for Idx in 1 .. N_MR loop
                           W_Arr (Idx) :=
                             Statistics.I_Chart.Box_Cox
                               (MR_Buf (Idx), Lambda_MR);
                           W_Sum := W_Sum + W_Arr (Idx);
                        end loop;
                        if State.Workspace.Estimation_Method =
                              Data_Model.Robust_Median
                        then
                           CL_W := Statistics.I_Chart.Median_Of (W_Arr);
                        else
                           CL_W := W_Sum / Long_Float (N_MR);
                        end if;

                        if CL_W > 0.0 then
                           declare
                              MR_W_Lim : constant Statistics.Limits_Record :=
                                Statistics.I_Chart.Compute_MR_Limits (CL_W);
                           begin
                              CD.MR_BC_Limits :=
                                (UCL     =>
                                   Statistics.I_Chart.Box_Cox_Inverse
                                     (MR_W_Lim.UCL, Lambda_MR),
                                 CL      =>
                                   Statistics.I_Chart.Box_Cox_Inverse
                                     (MR_W_Lim.CL,  Lambda_MR),
                                 LCL     => 0.0,
                                 Has_UCL => True,
                                 Has_LCL => False);
                              CD.MR_BC_Lambda := Lambda_MR;
                              CD.MR_BC_Active := True;
                           exception
                              when Constraint_Error => null;
                           end;
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;
      end if;

      --  ── Box-Cox for Session Turn Count I/MR/EWMA chart kinds ────────────
      --  When Turn_Count_Box_Cox is enabled, estimate lambda from setup-
      --  interval N_Turns values and override CD.Params with z-space
      --  equivalents.  N_Turns is always >= 1, so no zero-value exclusion.
      if Kind in Session_Turn_Count_I
                 | Session_Turn_Count_EWMA
        and then State.Workspace.Turn_Count_Box_Cox.Enabled
      then
         declare
            Raw   : Statistics.I_Chart.Long_Float_Array
                      (1 .. Natural (State.All_Metrics.Length));
            N_Raw : Natural := 0;
            Lambda : Long_Float;
         begin
            for M of State.All_Metrics loop
               if State.Workspace.Setup_Session_Ids.Is_Empty
                 or else State.Workspace.Setup_Session_Ids.Contains
                           (M.Session_Id)
               then
                  N_Raw := N_Raw + 1;
                  Raw (N_Raw) := Long_Float (M.N_Turns);
               end if;
            end loop;

            --  Resolve lambda.
            if State.Workspace.Turn_Count_Box_Cox.Lambda_Source =
                  Data_Model.Fixed
            then
               Lambda := State.Workspace.Turn_Count_Box_Cox.Fixed_Lambda;
            else
               if N_Raw >= 3 then
                  declare
                     Fallback : Boolean;
                  begin
                     Lambda := Statistics.I_Chart.Estimate_Lambda
                                 (Raw (1 .. N_Raw),
                                  Use_Robust    =>
                                    State.Workspace.Turn_Count_Box_Cox
                                      .Lambda_Source =
                                      Data_Model.Robust_Auto,
                                  Fallback_Used => Fallback);
                     if Fallback then
                        State.Status_Bar.Set_Text
                          ("Box-Cox: lambda fell back to 0.0 (log)"
                           & " -- MLE optimum was non-invertible or"
                           & " data was degenerate.");
                     end if;
                  end;
               else
                  Lambda := 0.0;
               end if;
            end if;
            CD.Box_Cox_Lambda := Lambda;
            CD.Box_Cox_Active := True;

            --  Recompute Grand_Mean and I_Sigma in the transformed space.
            --  I_Sigma: classical = mean(MR_z)/d2; robust = Qn(z_vals)/2.2219.
            if N_Raw > 0 then
               declare
                  Z_Vals   : Statistics.I_Chart.Long_Float_Array (1 .. N_Raw);
                  Sum_Z    : Long_Float := 0.0;
                  Prev_Z   : Long_Float := 0.0;
                  Has_PZ   : Boolean    := False;
                  MR_Z_Sum : Long_Float := 0.0;
                  MR_Z_Cnt : Natural    := 0;
               begin
                  for Idx in 1 .. N_Raw loop
                     declare
                        Z : constant Long_Float :=
                          Statistics.I_Chart.Box_Cox (Raw (Idx), Lambda);
                     begin
                        Z_Vals (Idx) := Z;
                        Sum_Z := Sum_Z + Z;
                        if Has_PZ then
                           MR_Z_Sum := MR_Z_Sum + abs (Z - Prev_Z);
                           MR_Z_Cnt := MR_Z_Cnt + 1;
                        end if;
                        Prev_Z := Z;
                        Has_PZ := True;
                     end;
                  end loop;
                  CD.Params.Grand_Mean := Sum_Z / Long_Float (N_Raw);
                  if State.Workspace.Estimation_Method =
                        Data_Model.Robust_Median
                  then
                     if N_Raw >= 2 then
                        CD.Params.I_Sigma :=
                          Statistics.I_Chart.Qn_Scale_Any (Z_Vals) / 2.2219;
                     end if;
                  else
                     CD.Params.I_Sigma :=
                       (if MR_Z_Cnt > 0
                        then MR_Z_Sum / (Long_Float (MR_Z_Cnt) * 1.128)
                        else 0.0);
                  end if;
               end;
            end if;
         end;
      end if;

      --  ── Box-Cox for Turn Count MR chart (independent λ_MR) ─────────────
      --  λ_MR is estimated from the setup-interval MR series of N_Turns.
      --  Points are always original-space |N_i − N_{i-1}|.
      if Kind = Session_Turn_Count_MR
        and then State.Workspace.Turn_Count_Box_Cox.Enabled
      then
         declare
            Raws  : Statistics.I_Chart.Long_Float_Array
                      (1 .. Natural (State.All_Metrics.Length));
            N_R   : Natural := 0;
         begin
            for M of State.All_Metrics loop
               if State.Workspace.Setup_Session_Ids.Is_Empty
                 or else State.Workspace.Setup_Session_Ids.Contains
                           (M.Session_Id)
               then
                  N_R := N_R + 1;
                  Raws (N_R) := Long_Float (M.N_Turns);
               end if;
            end loop;

            if N_R >= 2 then
               declare
                  MR_Buf    : Statistics.I_Chart.Long_Float_Array
                                (1 .. N_R - 1);
                  N_MR      : Natural := 0;
                  N_Zero_MR : Natural := 0;
                  Lambda_MR : Long_Float := 0.0;
               begin
                  for Idx in 2 .. N_R loop
                     declare
                        MR_I : constant Long_Float :=
                          abs (Raws (Idx) - Raws (Idx - 1));
                     begin
                        if MR_I > 0.0 then
                           N_MR := N_MR + 1;
                           MR_Buf (N_MR) := MR_I;
                        else
                           N_Zero_MR := N_Zero_MR + 1;
                        end if;
                     end;
                  end loop;

                  if N_Zero_MR > 0 then
                     State.Status_Bar.Set_Text
                       (Natural'Image (N_Zero_MR)
                        & " zero MR value(s) excluded from"
                        & " Turn Count MR lambda estimation.");
                  end if;

                  if State.Workspace.Turn_Count_Box_Cox.Lambda_Source =
                        Data_Model.Fixed
                  then
                     Lambda_MR :=
                       State.Workspace.Turn_Count_Box_Cox.Fixed_Lambda;
                  elsif N_MR >= 3 then
                     declare
                        Fallback : Boolean;
                     begin
                        Lambda_MR := Statistics.I_Chart.Estimate_Lambda
                          (MR_Buf (1 .. N_MR),
                           Use_Robust    =>
                             State.Workspace.Turn_Count_Box_Cox.Lambda_Source =
                             Data_Model.Robust_Auto,
                           Fallback_Used => Fallback);
                     end;
                  end if;

                  if N_MR > 0 then
                     declare
                        W_Arr : Statistics.I_Chart.Long_Float_Array
                                  (1 .. N_MR);
                        W_Sum : Long_Float := 0.0;
                        CL_W  : Long_Float;
                     begin
                        for Idx in 1 .. N_MR loop
                           W_Arr (Idx) :=
                             Statistics.I_Chart.Box_Cox
                               (MR_Buf (Idx), Lambda_MR);
                           W_Sum := W_Sum + W_Arr (Idx);
                        end loop;
                        if State.Workspace.Estimation_Method =
                              Data_Model.Robust_Median
                        then
                           CL_W := Statistics.I_Chart.Median_Of (W_Arr);
                        else
                           CL_W := W_Sum / Long_Float (N_MR);
                        end if;

                        if CL_W > 0.0 then
                           declare
                              MR_W_Lim : constant Statistics.Limits_Record :=
                                Statistics.I_Chart.Compute_MR_Limits (CL_W);
                           begin
                              CD.MR_BC_Limits :=
                                (UCL     =>
                                   Statistics.I_Chart.Box_Cox_Inverse
                                     (MR_W_Lim.UCL, Lambda_MR),
                                 CL      =>
                                   Statistics.I_Chart.Box_Cox_Inverse
                                     (MR_W_Lim.CL,  Lambda_MR),
                                 LCL     => 0.0,
                                 Has_UCL => True,
                                 Has_LCL => False);
                              CD.MR_BC_Lambda := Lambda_MR;
                              CD.MR_BC_Active := True;
                           exception
                              when Constraint_Error => null;
                           end;
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;
      end if;

      --  ── Box-Cox for Xbar/S chart kinds ─────────────────────────────────
      --  When Xbar_S_Box_Cox is enabled, estimate lambda independently for
      --  each chart pair (Turn/Tool/Thinking) from the setup-interval
      --  per-turn values, then override CD.Params.Grand_Mean and
      --  CD.Params.Pooled_S with their transformed-space equivalents so
      --  that the standard Xbar/S limit formulas operate in z-space.
      --  For Xbar charts, limits are back-transformed to original units.
      --  For S charts, limits remain in transformed units.
      if Props.Is_Xbar_S_Chart
        and then State.Workspace.Xbar_S_Box_Cox.Enabled
      then
         declare
            --  Collect all setup-interval per-turn values for this pair.
            --  Upper bound: sum of relevant turn counts across all sessions.
            Max_Vals : Natural := 0;
            N_Zero   : Natural := 0;
            Lambda   : Long_Float;

            function Is_Setup_M
              (M : Session_Metrics_Record) return Boolean is
            begin
               if State.Workspace.Setup_Session_Ids.Is_Empty then
                  return True;
               end if;
               return State.Workspace.Setup_Session_Ids.Contains
                        (M.Session_Id);
            end Is_Setup_M;

            --  Return the relevant per-turn token vector for this kind.
            function Get_Turn_Tokens
              (M : Session_Metrics_Record)
               return Natural_Vectors.Vector is
            begin
               case Kind is
                  when Turn_Tokens_Xbar | Turn_Tokens_S =>
                     return M.Per_Turn_Output_Tokens;
                  when Tool_Call_Tokens_Xbar | Tool_Call_Tokens_S =>
                     return M.Per_Turn_Tool_Tokens;
                  when others =>
                     return M.Per_Turn_Thinking_Tokens;
               end case;
            end Get_Turn_Tokens;
         begin
            --  Pass 1: count eligible values.
            for M of State.All_Metrics loop
               if Is_Setup_M (M) then
                  for V of Get_Turn_Tokens (M) loop
                     if V = 0 then
                        N_Zero := N_Zero + 1;
                     else
                        Max_Vals := Max_Vals + 1;
                     end if;
                  end loop;
               end if;
            end loop;

            if N_Zero > 0 then
               State.Status_Bar.Set_Text
                 (Natural'Image (N_Zero)
                  & " turn(s) with zero tokens excluded from Xbar/S"
                  & " chart Box-Cox estimation.");
            end if;

            --  Resolve lambda (fixed or auto-estimate).
            if State.Workspace.Xbar_S_Box_Cox.Lambda_Source =
                  Data_Model.Fixed
            then
               Lambda := State.Workspace.Xbar_S_Box_Cox.Fixed_Lambda;
            else
               --  Pass 2: fill array for Estimate_Lambda.
               declare
                  Raw   : Statistics.I_Chart.Long_Float_Array
                            (1 .. Max_Vals);
                  N_Raw : Natural := 0;
               begin
                  for M of State.All_Metrics loop
                     if Is_Setup_M (M) then
                        for V of Get_Turn_Tokens (M) loop
                           if V > 0 then
                              N_Raw := N_Raw + 1;
                              Raw (N_Raw) := Long_Float (V);
                           end if;
                        end loop;
                     end if;
                  end loop;
                  if N_Raw >= 3 then
                     declare
                        Fallback : Boolean;
                     begin
                        Lambda := Statistics.I_Chart.Estimate_Lambda
                                    (Raw (1 .. N_Raw),
                                     Use_Robust    =>
                                       State.Workspace.Xbar_S_Box_Cox
                                         .Lambda_Source =
                                         Data_Model.Robust_Auto,
                                     Fallback_Used => Fallback);
                        if Fallback then
                           State.Status_Bar.Set_Text
                             ("Box-Cox: lambda fell back to 0.0 (log)"
                              & " -- MLE optimum was non-invertible or"
                              & " data was degenerate.");
                        end if;
                     end;
                  else
                     Lambda := 0.0;
                  end if;
               end;
            end if;

            CD.Box_Cox_Lambda := Lambda;
            CD.Box_Cox_Active := True;

            --  Pass 3: compute Grand_Mean_Z and Pooled_S_Z by session.
            --  Each session contributes N_Z transformed values; we weight
            --  by session size for the grand mean and use pooled variance.
            if Max_Vals > 0 then
               declare
                  Total_N  : Long_Float := 0.0;
                  Total_WM : Long_Float := 0.0;
                  Sum_Num  : Long_Float := 0.0;
                  Sum_Den  : Long_Float := 0.0;
               begin
                  for M of State.All_Metrics loop
                     if Is_Setup_M (M) then
                        declare
                           Tokens : constant Natural_Vectors.Vector :=
                             Get_Turn_Tokens (M);
                           Z_Sum  : Long_Float := 0.0;
                           Z_Sq   : Long_Float := 0.0;
                           N_Z    : Natural    := 0;
                        begin
                           for V of Tokens loop
                              if V > 0 then
                                 declare
                                    Z : constant Long_Float :=
                                      Statistics.I_Chart.Box_Cox
                                        (Long_Float (V), Lambda);
                                 begin
                                    Z_Sum := Z_Sum + Z;
                                    Z_Sq  := Z_Sq  + Z * Z;
                                    N_Z   := N_Z + 1;
                                 end;
                              end if;
                           end loop;
                           if N_Z > 0 then
                              declare
                                 Mean_Z : constant Long_Float :=
                                   Z_Sum / Long_Float (N_Z);
                              begin
                                 Total_N  := Total_N  + Long_Float (N_Z);
                                 Total_WM :=
                                   Total_WM + Long_Float (N_Z) * Mean_Z;
                                 if N_Z >= 2 then
                                    declare
                                       Var_Z : constant Long_Float :=
                                         (Z_Sq
                                          - Z_Sum * Z_Sum
                                            / Long_Float (N_Z))
                                         / Long_Float (N_Z - 1);
                                    begin
                                       Sum_Num :=
                                         Sum_Num
                                         + Long_Float (N_Z - 1) * Var_Z;
                                       Sum_Den :=
                                         Sum_Den + Long_Float (N_Z - 1);
                                    end;
                                 end if;
                              end;
                           end if;
                        end;
                     end if;
                  end loop;
                  if Total_N > 0.0 then
                     CD.Params.Grand_Mean := Total_WM / Total_N;
                  end if;
                  if Sum_Den > 0.0 then
                     CD.Params.Pooled_S :=
                       Sqrt (Sum_Num / Sum_Den);
                  end if;
               end;
            end if;
         end;
      end if;



      --  Initialise EWMA state: Z_0 = Grand_Mean (in original or z-space).
      if Props.Is_EWMA_Chart then
         Z_Ewma_Prev := CD.Params.Grand_Mean;
      end if;
      --  Compute one point per session.
      for I in 1 .. Natural (State.Sessions.Length) loop
         declare
            Sess  : constant Session_Record :=
              State.Sessions.Element (I);
            M     : constant Session_Metrics_Record :=
              State.All_Metrics.Element (I);
            Value    : Long_Float;
            N        : Positive;
            Excl     : Boolean;
            Single   : Boolean;
            HGray    : Boolean;
            Limits   : Statistics.Limits_Record;
            In_Setup : constant Boolean :=
              State.Workspace.Setup_Session_Ids.Contains (Sess.Session_Id);
         begin
            Compute_Session_Stat (M, Kind, Value, N, Excl, Single, HGray);
            --  MR chart override: compute moving range from previous session.
            if Kind in Session_Input_Tokens_MR
                      | Session_Output_Tokens_MR
                      | Session_Cache_Read_Tokens_MR
                      | Session_Cache_Write_Tokens_MR
                      | Session_Thinking_Tokens_MR
                      | Session_Tool_Call_Tokens_MR
                      | Session_Tool_Call_Result_Tokens_MR
                      | Session_Uncached_Input_Tokens_MR
                      | Session_Turn_Count_MR
            then
               declare
                  Cur : constant Long_Float :=
                    (case Kind is
                        when Session_Input_Tokens_MR        =>
                           Long_Float (M.Total_Input_Tokens),
                        when Session_Cache_Read_Tokens_MR   =>
                           Long_Float (M.Total_Cache_Read_Tokens),
                        when Session_Cache_Write_Tokens_MR  =>
                           Long_Float (M.Total_Cache_Write_Tokens),
                        when Session_Thinking_Tokens_MR         =>
                           Long_Float (M.Total_Thinking_Tokens),
                        when Session_Tool_Call_Tokens_MR        =>
                           Long_Float (M.Total_Tool_Call_Input_Tokens),
                        when Session_Tool_Call_Result_Tokens_MR =>
                           Long_Float (M.Total_Tool_Call_Result_Tokens),
                        when Session_Turn_Count_MR          =>
                           Long_Float (M.N_Turns),
                        when Session_Uncached_Input_Tokens_MR   =>
                           Long_Float (M.Total_Uncached_Input_Tokens),
                        when others                         =>
                           Long_Float (M.Total_Output_Tokens));
               begin
                  --  MR points are always original-space absolute differences.
                  if Has_Prev_Total then
                     Value := abs (Cur - Prev_Total);
                     Excl  := False;
                  end if;
                  Prev_Total     := Cur;
                  Has_Prev_Total := True;
               end;
            end if;

            --  Fraction I/MR: skip zero-output sessions; ratio-based MR.
            if Kind in Fraction_Thinking_Tokens_MR | Fraction_Tool_Call_Tokens_MR
                     | Fraction_Thinking_Per_Tool_Call_MR | Fraction_Uncached_Input_MR
            then
               declare
                  Denom_OK : constant Boolean :=
                    (case Kind is
                        when Fraction_Thinking_Tokens_MR
                           | Fraction_Tool_Call_Tokens_MR  =>
                              M.Total_Output_Tokens > 0,
                        when Fraction_Thinking_Per_Tool_Call_MR =>
                              M.Total_Tool_Call_Input_Tokens > 0,
                        when Fraction_Uncached_Input_MR         =>
                              M.Total_Input_Tokens > 0,
                        when others                             => False);
               begin
                  if Denom_OK then
                     declare
                        Cur : constant Long_Float :=
                          (case Kind is
                              when Fraction_Thinking_Tokens_MR =>
                                 Long_Float (M.Total_Thinking_Tokens)
                                 / Long_Float (M.Total_Output_Tokens),
                              when Fraction_Tool_Call_Tokens_MR =>
                                 Long_Float (M.Total_Tool_Call_Input_Tokens)
                                 / Long_Float (M.Total_Output_Tokens),
                              when Fraction_Thinking_Per_Tool_Call_MR =>
                                 Long_Float (M.Total_Thinking_Tokens)
                                 / Long_Float (M.Total_Tool_Call_Input_Tokens),
                              when Fraction_Uncached_Input_MR =>
                                 Long_Float (M.Total_Uncached_Input_Tokens)
                                 / Long_Float (M.Total_Input_Tokens),
                              when others => 0.0);
                     begin
                        if Has_Prev_Total then
                           Value := abs (Cur - Prev_Total);
                           Excl  := False;
                        end if;
                        Prev_Total     := Cur;
                        Has_Prev_Total := True;
                     end;
                  end if;
               end;
            end if;

            --  ── EWMA chart override ────────────────────────────────────────
            --  Compute the exponentially weighted moving average and
            --  time-varying control limits.  When Box-Cox is active the EWMA
            --  is computed in z-space and back-transformed (Option B), so
            --  the plotted statistic and limits are in original token units.
            if Props.Is_EWMA_Chart then
               declare
                  Raw_X : constant Long_Float :=
                    (case Kind is
                        when Session_Input_Tokens_EWMA      =>
                           Long_Float (M.Total_Input_Tokens),
                        when Session_Output_Tokens_EWMA     =>
                           Long_Float (M.Total_Output_Tokens),
                        when Session_Cache_Read_Tokens_EWMA =>
                           Long_Float (M.Total_Cache_Read_Tokens),
                        when Session_Thinking_Tokens_EWMA           =>
                           Long_Float (M.Total_Thinking_Tokens),
                        when Session_Tool_Call_Tokens_EWMA          =>
                           Long_Float (M.Total_Tool_Call_Input_Tokens),
                        when Session_Tool_Call_Result_Tokens_EWMA   =>
                           Long_Float (M.Total_Tool_Call_Result_Tokens),
                        when Session_Turn_Count_EWMA        =>
                           Long_Float (M.N_Turns),
                        when Session_Uncached_Input_Tokens_EWMA =>
                           Long_Float (M.Total_Uncached_Input_Tokens),
                        when Fraction_Thinking_Tokens_EWMA =>
                           (if M.Total_Output_Tokens > 0
                            then Long_Float (M.Total_Thinking_Tokens)
                                 / Long_Float (M.Total_Output_Tokens)
                            else 0.0),
                        when Fraction_Tool_Call_Tokens_EWMA =>
                           (if M.Total_Output_Tokens > 0
                            then Long_Float (M.Total_Tool_Call_Input_Tokens)
                                 / Long_Float (M.Total_Output_Tokens)
                            else 0.0),
                        when Fraction_Thinking_Per_Tool_Call_EWMA =>
                           (if M.Total_Tool_Call_Input_Tokens > 0
                            then Long_Float (M.Total_Thinking_Tokens)
                                 / Long_Float (M.Total_Tool_Call_Input_Tokens)
                            else 0.0),
                        when Fraction_Uncached_Input_EWMA =>
                           (if M.Total_Input_Tokens > 0
                            then Long_Float (M.Total_Uncached_Input_Tokens)
                                 / Long_Float (M.Total_Input_Tokens)
                            else 0.0),
                        when others                         =>
                           Long_Float (M.Total_Cache_Write_Tokens));
               begin
                  if CD.Box_Cox_Active and then Raw_X > 0.0 then
                     declare
                        Z_X     : constant Long_Float :=
                          Statistics.I_Chart.Box_Cox
                            (Raw_X, CD.Box_Cox_Lambda);
                        Sigma_Z : constant Long_Float := CD.Params.I_Sigma;
                     begin
                        Z_Ewma_Prev :=
                          Statistics.EWMA_Chart.Compute_Z
                            (X      => Z_X,
                             Z_Prev => Z_Ewma_Prev,
                             Weight => State.Workspace.EWMA_Weight);
                        T_Ewma := T_Ewma + 1;
                        --  Assume success; back-transform failures below
                        --  will reset Excl to True.
                        Excl := False;
                        declare
                           Lim_Z       : constant Statistics.Limits_Record :=
                             Statistics.EWMA_Chart.Compute_EWMA_Limits
                               (Grand_Mean => CD.Params.Grand_Mean,
                                Sigma      => Sigma_Z,
                                Weight     => State.Workspace.EWMA_Weight,
                                L          => State.Workspace.EWMA_L,
                                T          => T_Ewma);
                           Inv_UCL     : Long_Float := 0.0;
                           Has_Inv_UCL : Boolean    := False;
                           Inv_CL      : Long_Float := 0.0;
                           Inv_LCL     : Long_Float := 0.0;
                           Has_Inv_LCL : Boolean    := False;
                        begin
                           begin
                              Inv_UCL :=
                                Statistics.I_Chart.Box_Cox_Inverse
                                  (Lim_Z.UCL, CD.Box_Cox_Lambda);
                              Has_Inv_UCL := Lim_Z.Has_UCL;
                           exception
                              when Constraint_Error => null;
                           end;
                           begin
                              Inv_CL :=
                                Statistics.I_Chart.Box_Cox_Inverse
                                  (Lim_Z.CL, CD.Box_Cox_Lambda);
                           exception
                              when Constraint_Error => Excl := True;
                           end;
                           if not Excl and then Lim_Z.Has_LCL then
                              begin
                                 Inv_LCL :=
                                   Statistics.I_Chart.Box_Cox_Inverse
                                     (Lim_Z.LCL, CD.Box_Cox_Lambda);
                                 Has_Inv_LCL := True;
                              exception
                                 when Constraint_Error => null;
                              end;
                           end if;
                           if not Excl then
                              begin
                                 Value :=
                                   Statistics.I_Chart.Box_Cox_Inverse
                                     (Z_Ewma_Prev, CD.Box_Cox_Lambda);
                                 Excl := False;
                              exception
                                 when Constraint_Error => Excl := True;
                              end;
                           end if;
                           if not Excl then
                              Limits :=
                                (UCL     => Inv_UCL,
                                 CL      => Inv_CL,
                                 LCL     => Inv_LCL,
                                 Has_UCL => Has_Inv_UCL,
                                 Has_LCL => Has_Inv_LCL);
                           end if;
                        end;
                     end;
                  elsif not CD.Box_Cox_Active
                    and then (Kind not in Fraction_Thinking_Tokens_EWMA
                                        | Fraction_Tool_Call_Tokens_EWMA
                                        | Fraction_Thinking_Per_Tool_Call_EWMA
                                        | Fraction_Uncached_Input_EWMA
                              or else
                                (case Kind is
                                    when Fraction_Thinking_Tokens_EWMA
                                       | Fraction_Tool_Call_Tokens_EWMA =>
                                          M.Total_Output_Tokens > 0,
                                    when Fraction_Thinking_Per_Tool_Call_EWMA =>
                                          M.Total_Tool_Call_Input_Tokens > 0,
                                    when Fraction_Uncached_Input_EWMA =>
                                          M.Total_Input_Tokens > 0,
                                    when others => True))
                  then
                     --  No transformation: EWMA in original (token) space.
                     declare
                        Sigma : constant Long_Float := CD.Params.I_Sigma;
                     begin
                        Z_Ewma_Prev :=
                          Statistics.EWMA_Chart.Compute_Z
                            (X      => Raw_X,
                             Z_Prev => Z_Ewma_Prev,
                             Weight => State.Workspace.EWMA_Weight);
                        T_Ewma := T_Ewma + 1;
                        Limits :=
                          Statistics.EWMA_Chart.Compute_EWMA_Limits
                            (Grand_Mean => CD.Params.Grand_Mean,
                             Sigma      => Sigma,
                             Weight     => State.Workspace.EWMA_Weight,
                             L          => State.Workspace.EWMA_L,
                             T          => T_Ewma);
                        Value := Z_Ewma_Prev;
                        Excl  := False;
                     end;
                  end if;
                  --  Box-Cox active with Raw_X = 0: Excl stays True.
               end;
            end if;


            --  Xbar/S Box-Cox: transform per-turn values and recompute the
            --  session statistic in z-space.  For Xbar charts the mean is
            --  back-transformed to original token units; for S charts the
            --  standard deviation remains in transformed units.
            if CD.Box_Cox_Active
              and then not Excl
              and then Kind in
                Turn_Tokens_Xbar   | Turn_Tokens_S
                | Tool_Call_Tokens_Xbar | Tool_Call_Tokens_S
                | Thinking_Tokens_Xbar  | Thinking_Tokens_S
            then
               declare
                  Tokens : constant Natural_Vectors.Vector :=
                    (case Kind is
                        when Turn_Tokens_Xbar | Turn_Tokens_S =>
                           M.Per_Turn_Output_Tokens,
                        when Tool_Call_Tokens_Xbar | Tool_Call_Tokens_S =>
                           M.Per_Turn_Tool_Tokens,
                        when others =>
                           M.Per_Turn_Thinking_Tokens);
                  Z_Sum  : Long_Float := 0.0;
                  Z_Sq   : Long_Float := 0.0;
                  N_Z    : Natural    := 0;
               begin
                  for V of Tokens loop
                     if V = 0 then
                        --  Any zero turn value → exclude this session from
                        --  the Box-Cox chart (cannot transform zero).
                        Excl := True;
                     elsif not Excl then
                        declare
                           Z : constant Long_Float :=
                             Statistics.I_Chart.Box_Cox
                               (Long_Float (V), CD.Box_Cox_Lambda);
                        begin
                           Z_Sum := Z_Sum + Z;
                           Z_Sq  := Z_Sq  + Z * Z;
                           N_Z   := N_Z + 1;
                        end;
                     end if;
                  end loop;

                  if not Excl then
                     if N_Z = 0 then
                        Excl := True;
                     else
                        declare
                           Mean_Z : constant Long_Float :=
                             Z_Sum / Long_Float (N_Z);
                        begin
                           case Kind is
                              when Turn_Tokens_Xbar
                                 | Tool_Call_Tokens_Xbar
                                 | Thinking_Tokens_Xbar =>
                                 --  Back-transform session mean to original
                                 --  token units for display.
                                 begin
                                    Value :=
                                      Statistics.I_Chart.Box_Cox_Inverse
                                        (Mean_Z, CD.Box_Cox_Lambda);
                                 exception
                                    when Constraint_Error => Excl := True;
                                 end;
                              when Turn_Tokens_S
                                 | Tool_Call_Tokens_S
                                 | Thinking_Tokens_S =>
                                 --  Std dev stays in transformed units.
                                 if N_Z >= 2 then
                                    Value :=
                                      Sqrt
                                        ((Z_Sq
                                          - Z_Sum * Z_Sum
                                            / Long_Float (N_Z))
                                         / Long_Float (N_Z - 1));
                                    --  Single = False: n>=2 always here.
                                    Single := False;
                                 else
                                    --  n=1: no s statistic in z-space.
                                    Excl := True;
                                 end if;
                              when others => null;
                           end case;
                        end;
                     end if;
                  end if;
               end;
            end if;

            if Excl then
               Limits := (UCL => 0.0, CL => 0.0, LCL => 0.0,
                          Has_UCL => False,
                          Has_LCL => False);
            else
               case Kind is
                  when Turn_Tokens_Xbar
                     | Tool_Call_Tokens_Xbar
                     | Thinking_Tokens_Xbar =>
                     declare
                        L_Z : constant Statistics.Limits_Record :=
                          Statistics.Xbar.Compute_Limits
                            (Grand_Mean => CD.Params.Grand_Mean,
                             Pooled_S   => CD.Params.Pooled_S,
                             N          => N);
                     begin
                        if CD.Box_Cox_Active and then L_Z.Has_UCL then
                           --  Back-transform limits from z-space to original
                           --  token units.  UCL back-transform may fail when
                           --  UCL_z approaches the domain asymptote (negative
                           --  lambda); that case sets Has_UCL = False.
                           --  Each limit is in its own exception scope.
                           declare
                              Inv_UCL     : Long_Float := 0.0;
                              Has_Inv_UCL : Boolean    := False;
                              Inv_CL      : Long_Float := 0.0;
                              Inv_LCL     : Long_Float := 0.0;
                              Has_Inv_LCL : Boolean    := False;
                           begin
                              begin
                                 Inv_UCL :=
                                   Statistics.I_Chart.Box_Cox_Inverse
                                     (L_Z.UCL, CD.Box_Cox_Lambda);
                                 Has_Inv_UCL := True;
                              exception
                                 when Constraint_Error => null;
                              end;
                              begin
                                 Inv_CL :=
                                   Statistics.I_Chart.Box_Cox_Inverse
                                     (L_Z.CL, CD.Box_Cox_Lambda);
                              exception
                                 when Constraint_Error => Excl := True;
                              end;
                              if L_Z.Has_LCL then
                                 begin
                                    Inv_LCL :=
                                      Statistics.I_Chart.Box_Cox_Inverse
                                        (L_Z.LCL, CD.Box_Cox_Lambda);
                                    Has_Inv_LCL := True;
                                 exception
                                    when Constraint_Error => null;
                                 end;
                              end if;
                              Limits :=
                                (UCL     => Inv_UCL,
                                 CL      => Inv_CL,
                                 LCL     => Inv_LCL,
                                 Has_UCL => Has_Inv_UCL,
                                 Has_LCL => Has_Inv_LCL);
                           end;
                        else
                           Limits := L_Z;
                        end if;
                     end;
                  when Turn_Tokens_S
                     | Tool_Call_Tokens_S
                     | Thinking_Tokens_S =>
                     Limits := Statistics.S_Chart.Compute_Limits
                       (Pooled_S => CD.Params.Pooled_S,
                        N        => N);
                  when Tool_Call_Failure_Rate
                     | Fraction_Tool_Call_Turns
                     | Fraction_Thinking_Turns =>
                     Limits := Statistics.P_Chart.Compute_Limits
                       (Grand_P => CD.Params.Grand_P,
                        N       => N);
                  when Session_Input_Tokens_I
                     | Session_Output_Tokens_I
                     | Session_Cache_Read_Tokens_I
                     | Session_Cache_Write_Tokens_I
                     | Session_Thinking_Tokens_I
                     | Session_Tool_Call_Tokens_I
                     | Session_Tool_Call_Result_Tokens_I
                     | Session_Uncached_Input_Tokens_I
                     | Session_Turn_Count_I | Fraction_Thinking_Tokens_I | Fraction_Tool_Call_Tokens_I
                     | Fraction_Thinking_Per_Tool_Call_I | Fraction_Uncached_Input_I =>
                     declare
                        L_Z : constant Statistics.Limits_Record :=
                          Statistics.I_Chart.Compute_I_Limits
                            (Grand_Mean => CD.Params.Grand_Mean,
                             Sigma      => CD.Params.I_Sigma);
                     begin
                        if CD.Box_Cox_Active and then L_Z.Has_UCL then
                           --  Back-transform limits to original units.
                           --  CL_z and LCL_z are always within the valid
                           --  domain of Box_Cox_Inverse: all observed data
                           --  values mapped into (-inf, 1/|lambda|), so
                           --  Grand_Mean_z and any value below it are valid
                           --  inputs.  UCL_z may reach or exceed the
                           --  asymptote 1/|lambda| for negative lambda,
                           --  meaning no finite x maps to that z; the
                           --  original-space UCL is effectively +inf.
                           --  Each limit is back-transformed independently
                           --  so that a domain failure on UCL_z does not
                           --  suppress the CL and LCL.
                           declare
                              Inv_UCL     : Long_Float := 0.0;
                              Has_Inv_UCL : Boolean    := False;
                              Inv_CL      : Long_Float;
                              Inv_LCL     : Long_Float;
                           begin
                              begin
                                 Inv_UCL     :=
                                   Statistics.I_Chart.Box_Cox_Inverse
                                     (L_Z.UCL, CD.Box_Cox_Lambda);
                                 Has_Inv_UCL := True;
                              exception
                                 when Constraint_Error => null;
                              end;
                              Inv_CL  := Statistics.I_Chart.Box_Cox_Inverse
                                           (L_Z.CL, CD.Box_Cox_Lambda);
                              Inv_LCL :=
                                (if L_Z.Has_LCL
                                 then Statistics.I_Chart.Box_Cox_Inverse
                                        (L_Z.LCL, CD.Box_Cox_Lambda)
                                 else 0.0);
                              Limits :=
                                (UCL     => Inv_UCL,
                                 CL      => Inv_CL,
                                 LCL     => Inv_LCL,
                                 Has_UCL => Has_Inv_UCL,
                                 Has_LCL => L_Z.Has_LCL);
                           end;
                        else
                           Limits := L_Z;
                        end if;
                     end;
                  when Session_Input_Tokens_MR
                     | Session_Output_Tokens_MR
                     | Session_Cache_Read_Tokens_MR
                     | Session_Cache_Write_Tokens_MR
                     | Session_Thinking_Tokens_MR
                     | Session_Tool_Call_Tokens_MR
                     | Session_Tool_Call_Result_Tokens_MR
                     | Session_Uncached_Input_Tokens_MR
                     | Session_Turn_Count_MR | Fraction_Thinking_Tokens_MR | Fraction_Tool_Call_Tokens_MR
                     | Fraction_Thinking_Per_Tool_Call_MR | Fraction_Uncached_Input_MR =>
                     if CD.MR_BC_Active then
                        Limits := CD.MR_BC_Limits;
                     else
                        Limits := Statistics.I_Chart.Compute_MR_Limits
                          (Mean_MR => CD.Params.Mean_MR);
                     end if;
                  when Session_Input_Tokens_EWMA
                     | Session_Output_Tokens_EWMA
                     | Session_Cache_Read_Tokens_EWMA
                     | Session_Cache_Write_Tokens_EWMA
                     | Session_Thinking_Tokens_EWMA
                     | Session_Tool_Call_Tokens_EWMA
                     | Session_Tool_Call_Result_Tokens_EWMA
                     | Session_Uncached_Input_Tokens_EWMA
                     | Session_Turn_Count_EWMA | Fraction_Thinking_Tokens_EWMA | Fraction_Tool_Call_Tokens_EWMA
                     | Fraction_Thinking_Per_Tool_Call_EWMA | Fraction_Uncached_Input_EWMA =>
                     null;
               end case;
            end if;

            CD.Points.Append
              ((Session_Id    => Sess.Session_Id,
                Session_Index => I,
                Session_Time  => Sess.Start_Time,
                Stat_Value    => Value,
                UCL           => Limits.UCL,
                CL            => (if Single then Value else Limits.CL),
                LCL           => Limits.LCL,
                Has_UCL       => Limits.Has_UCL,
                Has_LCL       => Limits.Has_LCL,
                Excluded      => Excl,
                Single_Turn   => Single,
                In_Setup      => In_Setup,
                Hollow_Gray   => HGray,
                Has_Comment   => Has_Comment
                                   (To_String (Sess.Session_Id))));
         end;
      end loop;

      State.Charts (Kind) := CD;
   end Recompute_Chart;

   procedure Recompute_Charts is
   begin
      for K in Chart_Kind loop
         Recompute_Chart (K);
      end loop;
      Update_Menu_States;
   end Recompute_Charts;

   --  ── Reload_Sessions ──────────────────────────────────────────────────

   procedure Reload_Sessions is
      Epoch : constant Ada.Calendar.Time :=
        Ada.Calendar.Time_Of (1970, 1, 1, 0.0);
   begin
      State.Sessions.Clear;
      State.All_Metrics.Clear;

      Coyote_SQC.Session_Parser.Load_Sessions
        (Source_Directories => State.Workspace.Source_Directories,
         Model_Filter       => State.Workspace.Model_Filter,
         Sessions           => State.Sessions);

      --  Compute metrics for each loaded session.
      for Sess of State.Sessions loop
         State.All_Metrics.Append
           (Coyote_SQC.Metrics.Compute (Sess));
      end loop;

      --  Set initial date range.
      if not State.Sessions.Is_Empty then
         State.Date_From := State.Sessions.First_Element.Start_Time;
         State.Date_To   := State.Sessions.Last_Element.Start_Time;
      else
         State.Date_From := Epoch;
         State.Date_To   := Epoch;
      end if;

      Recompute_Charts;
      Coyote_SQC.UI.Chart_Canvas.Reset_View;
      Coyote_SQC.UI.Toolbar.Sync_Pickers;
   end Reload_Sessions;

   --  ── Y_Fit ────────────────────────────────────────────────────────────

   procedure Y_Fit is
      use Ada.Calendar;
      CS  : Canvas_State renames State.Canvas_St;
      CD  : Chart_Data renames State.Charts (State.Active_Chart);
      Y1  : Long_Float :=  Long_Float'Last;
      Y2  : Long_Float := -Long_Float'Last;
      Any : Boolean := False;
   begin
      for P of CD.Points loop
         if (not P.Excluded or else P.Hollow_Gray)
           and then P.Session_Time >= State.Date_From
           and then P.Session_Time <= State.Date_To
         then
            if P.Stat_Value < Y1 then Y1 := P.Stat_Value; end if;
            if P.Stat_Value > Y2 then Y2 := P.Stat_Value; end if;
            if not P.Excluded and then not P.Single_Turn then
               if P.Has_UCL then
                  if P.UCL > Y2 then Y2 := P.UCL; end if;
                  if P.LCL < Y1 then Y1 := P.LCL; end if;
               end if;
            end if;
            Any := True;
         end if;
      end loop;

      if not Any then return; end if;

      declare
         Margin : constant Long_Float := (Y2 - Y1) * 0.1;
         M      : constant Long_Float :=
           (if Margin > 0.0 then Margin else 1.0);
      begin
         CS.Y_Min := Y1 - M;
         CS.Y_Max := Y2 + M;
      end;
   end Y_Fit;

   --  ── Update_Title ─────────────────────────────────────────────────────

   procedure Update_Menu_States is
      use type Gtk.Menu_Item.Gtk_Menu_Item;
   begin
      if State = null then return; end if;
      if State.Clear_Setup_Item /= null then
         State.Clear_Setup_Item.Set_Sensitive
           (not State.Workspace.Setup_Session_Ids.Is_Empty);
      end if;
      if State.Set_Selection_As_Setup_Item /= null then
         State.Set_Selection_As_Setup_Item.Set_Sensitive
           (not State.Selection.Is_Empty);
      end if;
      if State.Select_Setup_Interval_Item /= null then
         State.Select_Setup_Interval_Item.Set_Sensitive
           (not State.Workspace.Setup_Session_Ids.Is_Empty);
      end if;
   end Update_Menu_States;

   procedure Update_Title is
      Name : constant String := To_String (State.Workspace.Name);
      Title : constant String :=
        "coyote_sqc"
        & (if Name'Length > 0 then " - " & Name else "")
        & (if State.Modified then " *" else "");
   begin
      if State.Main_Window /= null then
         State.Main_Window.Set_Title (Title);
      end if;
   end Update_Title;

   --  ── Has_Comment ──────────────────────────────────────────────────────

   function Has_Comment (Session_Id : String) return Boolean is
   begin
      for C of State.Workspace.Comments loop
         if To_String (C.Session_Id) = Session_Id then
            return True;
         end if;
      end loop;
      return False;
   end Has_Comment;

   --  ── Run ──────────────────────────────────────────────────────────────

   procedure Run (Workspace_Path : String := "") is
      Epoch : constant Ada.Calendar.Time :=
        Ada.Calendar.Time_Of (1970, 1, 1, 0.0);
      --  Version found during workspace load (0 = no version field).
      WS_Version_Found : Natural := 1;
      --  Error from workspace load (empty = no error).
      WS_Load_Error : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
   begin
      --  Allocate application state.
      State := new App_State;
      State.Date_From      := Epoch;
      State.Date_To        := Epoch;

      --  Load workspace if requested.
      if Workspace_Path'Length > 0 then
         begin
            Coyote_SQC.Workspace.Load
              (Workspace_Path, State.Workspace, WS_Version_Found);
            State.Workspace_Path :=
              To_Unbounded_String (Workspace_Path);
            Coyote_SQC.Config.Record_Open
              (To_String (State.Workspace.Name), Workspace_Path);
         exception
            when E : Coyote_SQC.Workspace.Workspace_Error =>
               WS_Load_Error := Ada.Strings.Unbounded.To_Unbounded_String
                 (Ada.Exceptions.Exception_Message (E));
            when E : others =>
               WS_Load_Error := Ada.Strings.Unbounded.To_Unbounded_String
                 (Ada.Exceptions.Exception_Name (E)
                  & ": " & Ada.Exceptions.Exception_Message (E));
         end;
      end if;

      --  Initialise GTK.
      Gtk.Main.Init;

      --  Build the main window.
      Coyote_SQC.UI.Build_Main_Window;

      --  §9.3: show error when workspace version is too high.
      if Ada.Strings.Unbounded.Length (WS_Load_Error) > 0 then
         Coyote_SQC.UI.Dialogs.Error
           (State.Main_Window,
            "Workspace Error",
            Ada.Strings.Unbounded.To_String (WS_Load_Error));
      end if;

      --  §9.3: show warning when version field is absent.
      if Workspace_Path'Length > 0 and then WS_Version_Found = 0 then
         Coyote_SQC.UI.Dialogs.Info
           (State.Main_Window,
            "Workspace Warning",
            "Workspace file has no version field; some data may be missing.");
      end if;

      --  Load sessions if workspace has source directories.
      if not State.Workspace.Source_Directories.Is_Empty then
         Reload_Sessions;
      end if;
      Update_Title;

      --  Kick off the GTK event loop.
      Gtk.Main.Main;
   end Run;

end Coyote_SQC.App;
