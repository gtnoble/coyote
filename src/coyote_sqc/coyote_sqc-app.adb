--  Coyote_SQC.App body.
--
--  Project: coyote

with Ada.Exceptions;
with Ada.Unchecked_Deallocation;
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

   --  Mean and standard deviation for Long_Float subgroup vectors (JSD).
   function Mean_LF_F (V : Long_Float_Vectors.Vector) return Long_Float is
      N : constant Natural := Natural (V.Length);
   begin
      if N = 0 then return 0.0; end if;
      declare
         S : Long_Float := 0.0;
      begin
         for X of V loop S := S + X; end loop;
         return S / Long_Float (N);
      end;
   end Mean_LF_F;

   function StdDev_LF_F (V : Long_Float_Vectors.Vector) return Long_Float is
      N : constant Natural := Natural (V.Length);
   begin
      if N < 2 then return 0.0; end if;
      declare
         M    : constant Long_Float := Mean_LF_F (V);
         Sum2 : Long_Float := 0.0;
      begin
         for X of V loop
            declare D : constant Long_Float := X - M;
            begin Sum2 := Sum2 + D * D; end;
         end loop;
         return Sqrt (Sum2 / Long_Float (N - 1));
      end;
   end StdDev_LF_F;


   --  Convert Natural_Vectors.Vector to Long_Float_Array for use with
   --  Median_Of / Qn_Scale_Any in the robust plot-method path.
   function To_LF_Array
     (V : Natural_Vectors.Vector) return Coyote_SQC.Statistics.I_Chart.Long_Float_Array
   is
      A : Coyote_SQC.Statistics.I_Chart.Long_Float_Array (1 .. Natural (V.Length));
      I : Natural := A'First;
   begin
      for X of V loop
         A (I) := Long_Float (X);
         I := I + 1;
      end loop;
      return A;
   end To_LF_Array;

   --  Convert Long_Float_Vectors.Vector to Long_Float_Array for use with
   --  Median_Of / Qn_Scale_Any in the robust plot-method path (JSD / MI).
   function To_LF_Array_F
     (V : Long_Float_Vectors.Vector) return Coyote_SQC.Statistics.I_Chart.Long_Float_Array
   is
      A : Coyote_SQC.Statistics.I_Chart.Long_Float_Array (1 .. Natural (V.Length));
      I : Natural := A'First;
   begin
      for X of V loop
         A (I) := X;
         I := I + 1;
      end loop;
      return A;
   end To_LF_Array_F;


   --  ── Compute_Session_Stat ─────────────────────────────────────────────

   procedure Compute_Session_Stat
     (Metrics    :     Session_Metrics_Record;
      Kind       :     Chart_Kind;
      Value      : out Long_Float;
      N          : out Positive;
      Excluded   : out Boolean;
      Single     : out Boolean;
      Hollow_Gray : out Boolean;
      Plot_Method :     Plot_Method_Kind := Classical)
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
            if Plot_Method = Robust_Median then
               Value :=
                 Coyote_SQC.Statistics.I_Chart.Median_Of
                   (To_LF_Array (Metrics.Per_Turn_Output_Tokens));
            else
               Value := Mean_LF (Metrics.Per_Turn_Output_Tokens);
            end if;
            Single := (N = 1);

         when Turn_Tokens_S =>
            N := Metrics.N_Turns;
            if N = 1 then
               Excluded := True;
            else
               if Plot_Method = Robust_Median then
                  Value :=
                    Coyote_SQC.Statistics.I_Chart.Qn_Scale_Any
                      (To_LF_Array (Metrics.Per_Turn_Output_Tokens));
               else
                  Value := StdDev_LF (Metrics.Per_Turn_Output_Tokens);
               end if;
            end if;

         when Tool_Call_Tokens_Xbar =>
            if Metrics.N_Tool_Call_Turns_For_Chart = 0 then
               Excluded    := True;
               Hollow_Gray := True;
            else
               N      := Metrics.N_Tool_Call_Turns_For_Chart;
               if Plot_Method = Robust_Median then
                  Value :=
                    Coyote_SQC.Statistics.I_Chart.Median_Of
                      (To_LF_Array (Metrics.Per_Turn_Tool_Tokens));
               else
                  Value := Mean_LF (Metrics.Per_Turn_Tool_Tokens);
               end if;
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
               if Plot_Method = Robust_Median then
                  Value :=
                    Coyote_SQC.Statistics.I_Chart.Qn_Scale_Any
                      (To_LF_Array (Metrics.Per_Turn_Tool_Tokens));
               else
                  Value := StdDev_LF (Metrics.Per_Turn_Tool_Tokens);
               end if;
            end if;

         when Thinking_Tokens_Xbar =>
            if not Metrics.Any_Thinking then
               Excluded    := True;
               Hollow_Gray := True;
            else
               N      := Metrics.N_Thinking_Turns_For_Chart;
               if Plot_Method = Robust_Median then
                  Value :=
                    Coyote_SQC.Statistics.I_Chart.Median_Of
                      (To_LF_Array (Metrics.Per_Turn_Thinking_Tokens));
               else
                  Value := Mean_LF (Metrics.Per_Turn_Thinking_Tokens);
               end if;
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
               if Plot_Method = Robust_Median then
                  Value :=
                    Coyote_SQC.Statistics.I_Chart.Qn_Scale_Any
                      (To_LF_Array (Metrics.Per_Turn_Thinking_Tokens));
               else
                  Value := StdDev_LF (Metrics.Per_Turn_Thinking_Tokens);
               end if;
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

         when Session_Tool_Call_JSD_Sum_I =>
            if Metrics.N_Consecutive_Tool_Pairs = 0 then
               Excluded := True;
            else
               Value := Metrics.Total_Tool_Call_JSD_S;
               N     := 1;
            end if;

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
            | Fraction_Thinking_Per_Tool_Call_EWMA | Fraction_Uncached_Input_EWMA
            | Session_Tool_Call_JSD_Sum_EWMA
            | Session_Tool_Call_MI_Sum_I
            | Session_Tool_Call_MI_Sum_EWMA | Session_Total_Cost_EWMA | Session_Input_Cost_EWMA | Session_Output_Cost_EWMA | Session_Cache_Read_Cost_EWMA | Session_Cache_Write_Cost_EWMA | Session_Uncached_Input_Cost_EWMA =>
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
            | Fraction_Thinking_Per_Tool_Call_MR | Fraction_Uncached_Input_MR
            | Session_Tool_Call_JSD_Sum_MR | Session_Tool_Call_MI_Sum_MR | Session_Total_Cost_MR | Session_Input_Cost_MR | Session_Output_Cost_MR | Session_Cache_Read_Cost_MR | Session_Cache_Write_Cost_MR | Session_Uncached_Input_Cost_MR =>
            --  call for non-first sessions.
            Excluded := True;
         when Tool_Call_JSD_Xbar =>
            if Metrics.N_Consecutive_Tool_Pairs = 0 then
               Excluded    := True;
            elsif Metrics.N_Consecutive_Tool_Pairs = 1 then
               N      := Metrics.N_Consecutive_Tool_Pairs;
               if Plot_Method = Robust_Median then
                  Value :=
                    Coyote_SQC.Statistics.I_Chart.Median_Of
                      (To_LF_Array_F (Metrics.Per_Consecutive_Tool_S));
               else
                  Value := Mean_LF_F (Metrics.Per_Consecutive_Tool_S);
               end if;
               Single := True;  --  Hollow circle: no variance estimate
            else
               N     := Metrics.N_Consecutive_Tool_Pairs;
               if Plot_Method = Robust_Median then
                  Value :=
                    Coyote_SQC.Statistics.I_Chart.Median_Of
                      (To_LF_Array_F (Metrics.Per_Consecutive_Tool_S));
               else
                  Value := Mean_LF_F (Metrics.Per_Consecutive_Tool_S);
               end if;
            end if;
         when Tool_Call_JSD_S =>
            if Metrics.N_Consecutive_Tool_Pairs <= 1 then
               Excluded := True;
            else
               N     := Metrics.N_Consecutive_Tool_Pairs;
               if Plot_Method = Robust_Median then
                  Value :=
                    Coyote_SQC.Statistics.I_Chart.Qn_Scale_Any
                      (To_LF_Array_F (Metrics.Per_Consecutive_Tool_S));
               else
                  Value := StdDev_LF_F (Metrics.Per_Consecutive_Tool_S);
               end if;
            end if;
         --  MI chart kinds — mirror JSD but use Per_Consecutive_Tool_MI.
         when Tool_Call_MI_Xbar =>
            if Metrics.N_Consecutive_Tool_MI_Pairs = 0 then
               Excluded    := True;
            elsif Metrics.N_Consecutive_Tool_MI_Pairs = 1 then
               N      := Metrics.N_Consecutive_Tool_MI_Pairs;
               if Plot_Method = Robust_Median then
                  Value :=
                    Coyote_SQC.Statistics.I_Chart.Median_Of
                      (To_LF_Array_F (Metrics.Per_Consecutive_Tool_MI));
               else
                  Value := Mean_LF_F (Metrics.Per_Consecutive_Tool_MI);
               end if;
               Single := True;
            else
               N     := Metrics.N_Consecutive_Tool_MI_Pairs;
               if Plot_Method = Robust_Median then
                  Value :=
                    Coyote_SQC.Statistics.I_Chart.Median_Of
                      (To_LF_Array_F (Metrics.Per_Consecutive_Tool_MI));
               else
                  Value := Mean_LF_F (Metrics.Per_Consecutive_Tool_MI);
               end if;
            end if;

         when Tool_Call_MI_S =>
            if Metrics.N_Consecutive_Tool_MI_Pairs <= 1 then
               Excluded := True;
            else
               N     := Metrics.N_Consecutive_Tool_MI_Pairs;
               if Plot_Method = Robust_Median then
                  Value :=
                    Coyote_SQC.Statistics.I_Chart.Qn_Scale_Any
                      (To_LF_Array_F (Metrics.Per_Consecutive_Tool_MI));
               else
                  Value := StdDev_LF_F (Metrics.Per_Consecutive_Tool_MI);
               end if;

            end if;


         --  Token cost I charts.
         when Session_Total_Cost_I =>
            Value := Metrics.Total_Cost;
            N     := 1;
         when Session_Input_Cost_I =>
            Value := Metrics.Total_Input_Cost;
            N     := 1;
         when Session_Output_Cost_I =>
            Value := Metrics.Total_Output_Cost;
            N     := 1;
         when Session_Cache_Read_Cost_I =>
            Value := Metrics.Total_Cache_Read_Cost;
            N     := 1;
         when Session_Cache_Write_Cost_I =>
            Value := Metrics.Total_Cache_Write_Cost;
            N     := 1;
         when Session_Uncached_Input_Cost_I =>
            Value := Metrics.Total_Uncached_Input_Cost;
            N     := 1;

         --  Token cost Xbar/S charts.
         when Turn_Total_Cost_Xbar =>
            N := Metrics.N_Turns;
            if Plot_Method = Robust_Median then
               Value :=
                 Coyote_SQC.Statistics.I_Chart.Median_Of
                   (To_LF_Array_F (Metrics.Per_Turn_Cost));
            else
               Value := Mean_LF_F (Metrics.Per_Turn_Cost);
            end if;
            Single := (N = 1);
         when Turn_Total_Cost_S =>
            N := Metrics.N_Turns;
            if N = 1 then
               Excluded := True;
            else
               if Plot_Method = Robust_Median then
                  Value :=
                    Coyote_SQC.Statistics.I_Chart.Qn_Scale_Any
                      (To_LF_Array_F (Metrics.Per_Turn_Cost));
               else
                  Value := StdDev_LF_F (Metrics.Per_Turn_Cost);
               end if;
            end if;

         when Turn_Input_Cost_Xbar =>
            N := Metrics.N_Turns;
            if Plot_Method = Robust_Median then
               Value :=
                 Coyote_SQC.Statistics.I_Chart.Median_Of
                   (To_LF_Array_F (Metrics.Per_Turn_Input_Cost));
            else
               Value := Mean_LF_F (Metrics.Per_Turn_Input_Cost);
            end if;
            Single := (N = 1);
         when Turn_Input_Cost_S =>
            N := Metrics.N_Turns;
            if N = 1 then
               Excluded := True;
            else
               if Plot_Method = Robust_Median then
                  Value :=
                    Coyote_SQC.Statistics.I_Chart.Qn_Scale_Any
                      (To_LF_Array_F (Metrics.Per_Turn_Input_Cost));
               else
                  Value := StdDev_LF_F (Metrics.Per_Turn_Input_Cost);
               end if;
            end if;

         when Turn_Output_Cost_Xbar =>
            N := Metrics.N_Turns;
            if Plot_Method = Robust_Median then
               Value :=
                 Coyote_SQC.Statistics.I_Chart.Median_Of
                   (To_LF_Array_F (Metrics.Per_Turn_Output_Cost));
            else
               Value := Mean_LF_F (Metrics.Per_Turn_Output_Cost);
            end if;
            Single := (N = 1);
         when Turn_Output_Cost_S =>
            N := Metrics.N_Turns;
            if N = 1 then
               Excluded := True;
            else
               if Plot_Method = Robust_Median then
                  Value :=
                    Coyote_SQC.Statistics.I_Chart.Qn_Scale_Any
                      (To_LF_Array_F (Metrics.Per_Turn_Output_Cost));
               else
                  Value := StdDev_LF_F (Metrics.Per_Turn_Output_Cost);
               end if;
            end if;

         when Turn_Cache_Read_Cost_Xbar =>
            N := Metrics.N_Turns;
            if Plot_Method = Robust_Median then
               Value :=
                 Coyote_SQC.Statistics.I_Chart.Median_Of
                   (To_LF_Array_F (Metrics.Per_Turn_Cache_Read_Cost));
            else
               Value := Mean_LF_F (Metrics.Per_Turn_Cache_Read_Cost);
            end if;
            Single := (N = 1);
         when Turn_Cache_Read_Cost_S =>
            N := Metrics.N_Turns;
            if N = 1 then
               Excluded := True;
            else
               if Plot_Method = Robust_Median then
                  Value :=
                    Coyote_SQC.Statistics.I_Chart.Qn_Scale_Any
                      (To_LF_Array_F (Metrics.Per_Turn_Cache_Read_Cost));
               else
                  Value := StdDev_LF_F (Metrics.Per_Turn_Cache_Read_Cost);
               end if;
            end if;

         when Turn_Cache_Write_Cost_Xbar =>
            N := Metrics.N_Turns;
            if Plot_Method = Robust_Median then
               Value :=
                 Coyote_SQC.Statistics.I_Chart.Median_Of
                   (To_LF_Array_F (Metrics.Per_Turn_Cache_Write_Cost));
            else
               Value := Mean_LF_F (Metrics.Per_Turn_Cache_Write_Cost);
            end if;
            Single := (N = 1);
         when Turn_Cache_Write_Cost_S =>
            N := Metrics.N_Turns;
            if N = 1 then
               Excluded := True;
            else
               if Plot_Method = Robust_Median then
                  Value :=
                    Coyote_SQC.Statistics.I_Chart.Qn_Scale_Any
                      (To_LF_Array_F (Metrics.Per_Turn_Cache_Write_Cost));
               else
                  Value := StdDev_LF_F (Metrics.Per_Turn_Cache_Write_Cost);
               end if;
            end if;

         when Turn_Uncached_Input_Cost_Xbar =>
            N := Metrics.N_Turns;
            if Plot_Method = Robust_Median then
               Value :=
                 Coyote_SQC.Statistics.I_Chart.Median_Of
                   (To_LF_Array_F (Metrics.Per_Turn_Uncached_Input_Cost));
            else
               Value := Mean_LF_F (Metrics.Per_Turn_Uncached_Input_Cost);
            end if;
            Single := (N = 1);
         when Turn_Uncached_Input_Cost_S =>
            N := Metrics.N_Turns;
            if N = 1 then
               Excluded := True;
            else
               if Plot_Method = Robust_Median then
                  Value :=
                    Coyote_SQC.Statistics.I_Chart.Qn_Scale_Any
                      (To_LF_Array_F (Metrics.Per_Turn_Uncached_Input_Cost));
               else
                  Value := StdDev_LF_F (Metrics.Per_Turn_Uncached_Input_Cost);
               end if;
            end if;

         --  Quantile CC charts: handled separately in Recompute_Chart.
         when Turn_Tokens_Quantile
            | Tool_Call_Tokens_Quantile
            | Thinking_Tokens_Quantile
            | Tool_Call_JSD_Quantile
            | Tool_Call_MI_Quantile =>
            Excluded := True;
      end case;
   end Compute_Session_Stat;


   --  ── Metric accessor functions ─────────────────────────────────────────
   --
   --  Each function extracts one scalar observation from a metrics record
   --  and returns it as an Observation_Result.  When the session cannot
   --  contribute a valid observation for this chart (e.g. zero denominator
   --  for a ratio chart), the function returns (Valid => False).  Using a
   --  discriminated result type prevents callers from accidentally using an
   --  excluded-session signal value in arithmetic.

   function Obs_Input_Tokens
     (M : Session_Metrics_Record) return Observation_Result is
   begin
      return (Valid => True, Value => Long_Float (M.Total_Input_Tokens));
   end Obs_Input_Tokens;

   function Obs_Output_Tokens
     (M : Session_Metrics_Record) return Observation_Result is
   begin
      return (Valid => True, Value => Long_Float (M.Total_Output_Tokens));
   end Obs_Output_Tokens;

   function Obs_Cache_Read
     (M : Session_Metrics_Record) return Observation_Result is
   begin
      return (Valid => True, Value => Long_Float (M.Total_Cache_Read_Tokens));
   end Obs_Cache_Read;

   function Obs_Cache_Write
     (M : Session_Metrics_Record) return Observation_Result is
   begin
      return (Valid => True, Value => Long_Float (M.Total_Cache_Write_Tokens));
   end Obs_Cache_Write;

   function Obs_Thinking_Tokens
     (M : Session_Metrics_Record) return Observation_Result is
   begin
      return (Valid => True, Value => Long_Float (M.Total_Thinking_Tokens));
   end Obs_Thinking_Tokens;

   function Obs_Tool_Call_Tokens
     (M : Session_Metrics_Record) return Observation_Result is
   begin
      return
        (Valid => True, Value => Long_Float (M.Total_Tool_Call_Input_Tokens));
   end Obs_Tool_Call_Tokens;

   function Obs_Tool_Result_Tokens
     (M : Session_Metrics_Record) return Observation_Result is
   begin
      return
        (Valid => True,
         Value => Long_Float (M.Total_Tool_Call_Result_Tokens));
   end Obs_Tool_Result_Tokens;

   function Obs_Uncached_Input
     (M : Session_Metrics_Record) return Observation_Result is
   begin
      return
        (Valid => True,
         Value => Long_Float (M.Total_Uncached_Input_Tokens));
   end Obs_Uncached_Input;

   function Obs_Turn_Count
     (M : Session_Metrics_Record) return Observation_Result is
   begin
      return (Valid => True, Value => Long_Float (M.N_Turns));
   end Obs_Turn_Count;

   --  ── Cost observation accessors ────────────────────────────────────

   function Obs_Total_Cost
     (M : Session_Metrics_Record) return Observation_Result is
   begin
      return (Valid => True, Value => M.Total_Cost);
   end Obs_Total_Cost;

   function Obs_Input_Cost
     (M : Session_Metrics_Record) return Observation_Result is
   begin
      return (Valid => True, Value => M.Total_Input_Cost);
   end Obs_Input_Cost;

   function Obs_Output_Cost
     (M : Session_Metrics_Record) return Observation_Result is
   begin
      return (Valid => True, Value => M.Total_Output_Cost);
   end Obs_Output_Cost;

   function Obs_Cache_Read_Cost
     (M : Session_Metrics_Record) return Observation_Result is
   begin
      return (Valid => True, Value => M.Total_Cache_Read_Cost);
   end Obs_Cache_Read_Cost;

   function Obs_Cache_Write_Cost
     (M : Session_Metrics_Record) return Observation_Result is
   begin
      return (Valid => True, Value => M.Total_Cache_Write_Cost);
   end Obs_Cache_Write_Cost;

   function Obs_Uncached_Input_Cost
     (M : Session_Metrics_Record) return Observation_Result is
   begin
      return (Valid => True, Value => M.Total_Uncached_Input_Cost);
   end Obs_Uncached_Input_Cost;

   --  ── Cost subgroup accessors (Long_Float) ──────────────────────────

   function Sub_Total_Cost
     (M : Session_Metrics_Record) return Long_Float_Vectors.Vector is
   begin
      return M.Per_Turn_Cost;
   end Sub_Total_Cost;

   function Sub_Input_Cost
     (M : Session_Metrics_Record) return Long_Float_Vectors.Vector is
   begin
      return M.Per_Turn_Input_Cost;
   end Sub_Input_Cost;

   function Sub_Output_Cost
     (M : Session_Metrics_Record) return Long_Float_Vectors.Vector is
   begin
      return M.Per_Turn_Output_Cost;
   end Sub_Output_Cost;

   function Sub_Cache_Read_Cost
     (M : Session_Metrics_Record) return Long_Float_Vectors.Vector is
   begin
      return M.Per_Turn_Cache_Read_Cost;
   end Sub_Cache_Read_Cost;

   function Sub_Cache_Write_Cost
     (M : Session_Metrics_Record) return Long_Float_Vectors.Vector is
   begin
      return M.Per_Turn_Cache_Write_Cost;
   end Sub_Cache_Write_Cost;

   function Sub_Uncached_Input_Cost
     (M : Session_Metrics_Record) return Long_Float_Vectors.Vector is
   begin
      return M.Per_Turn_Uncached_Input_Cost;
   end Sub_Uncached_Input_Cost;


   --  Ratio accessor: thinking tokens / output tokens.
   --  Returns (Valid => False) when Total_Output_Tokens = 0 (session
   --  excluded from this chart).
   function Obs_Frac_Thinking
     (M : Session_Metrics_Record) return Observation_Result is
   begin
      if M.Total_Output_Tokens = 0 then
         return (Valid => False);
      end if;
      return
        (Valid => True,
         Value => Long_Float (M.Total_Thinking_Tokens)
                  / Long_Float (M.Total_Output_Tokens));
   end Obs_Frac_Thinking;

   --  Ratio accessor: tool-call input tokens / output tokens.
   --  Returns (Valid => False) when Total_Output_Tokens = 0.
   function Obs_Frac_Tool_Call
     (M : Session_Metrics_Record) return Observation_Result is
   begin
      if M.Total_Output_Tokens = 0 then
         return (Valid => False);
      end if;
      return
        (Valid => True,
         Value => Long_Float (M.Total_Tool_Call_Input_Tokens)
                  / Long_Float (M.Total_Output_Tokens));
   end Obs_Frac_Tool_Call;

   --  Ratio accessor: thinking tokens / tool-call input tokens.
   --  Returns (Valid => False) when Total_Tool_Call_Input_Tokens = 0.
   function Obs_Frac_Thinking_Per_Tool
     (M : Session_Metrics_Record) return Observation_Result is
   begin
      if M.Total_Tool_Call_Input_Tokens = 0 then
         return (Valid => False);
      end if;
      return
        (Valid => True,
         Value => Long_Float (M.Total_Thinking_Tokens)
                  / Long_Float (M.Total_Tool_Call_Input_Tokens));
   end Obs_Frac_Thinking_Per_Tool;

   --  Ratio accessor: uncached input tokens / total input tokens.
   --  Returns (Valid => False) when Total_Input_Tokens = 0.
   function Obs_Frac_Uncached_Input
     (M : Session_Metrics_Record) return Observation_Result is
   begin
      if M.Total_Input_Tokens = 0 then
         return (Valid => False);
      end if;
      return
        (Valid => True,
         Value => Long_Float (M.Total_Uncached_Input_Tokens)
                  / Long_Float (M.Total_Input_Tokens));
   end Obs_Frac_Uncached_Input;

   --  ── Subgroup accessor functions ───────────────────────────────────────

   function Sub_Output_Tokens
     (M : Session_Metrics_Record) return Natural_Vectors.Vector is
   begin
      return M.Per_Turn_Output_Tokens;
   end Sub_Output_Tokens;

   function Sub_Tool_Tokens
     (M : Session_Metrics_Record) return Natural_Vectors.Vector is
   begin
      return M.Per_Turn_Tool_Tokens;
   end Sub_Tool_Tokens;

   function Sub_Thinking_Tokens
     (M : Session_Metrics_Record) return Natural_Vectors.Vector is
   begin
      return M.Per_Turn_Thinking_Tokens;
   end Sub_Thinking_Tokens;

   function Sub_JSD_S
     (M : Session_Metrics_Record) return Long_Float_Vectors.Vector is
   begin
      return M.Per_Consecutive_Tool_S;
   end Sub_JSD_S;
   function Sub_MI_LF
     (M : Session_Metrics_Record) return Long_Float_Vectors.Vector is
   begin
      return M.Per_Consecutive_Tool_MI;
   end Sub_MI_LF;
   --  Obs_Tool_JSD_Sum: session-total JSD similarity score.
   --  Returns (Valid => False) when there are no consecutive tool-call pairs
   --  (fewer than 2 non-empty tool calls in the session).
   function Obs_Tool_JSD_Sum
     (M : Session_Metrics_Record) return Observation_Result is
   begin
      if M.N_Consecutive_Tool_Pairs = 0 then
         return (Valid => False);
      end if;
      return (Valid => True, Value => M.Total_Tool_Call_JSD_S);
   end Obs_Tool_JSD_Sum;

   --  Obs_Tool_MI_Sum: session-total MI score.
   --  Returns (Valid => False) when there are no consecutive tool-call pairs
   --  (fewer than 2 non-empty tool calls in the session).
   function Obs_Tool_MI_Sum
     (M : Session_Metrics_Record) return Observation_Result is
   begin
      if M.N_Consecutive_Tool_MI_Pairs = 0 then
         return (Valid => False);
      end if;
      return (Valid => True, Value => M.Total_Tool_Call_MI);
   end Obs_Tool_MI_Sum;


   --  Descriptor — return a self-contained descriptor for Kind.

   function Descriptor (Kind : Coyote_SQC.Charts.Chart_Kind)
     return Chart_Descriptor
   is
      D : Chart_Descriptor;
   begin
      D.Kind       := Kind;
      D.Properties := Coyote_SQC.Charts.Properties (Kind);
      case Kind is
         when Turn_Tokens_Xbar | Turn_Tokens_S =>
            D.Get_Subgroup   := Sub_Output_Tokens'Access;
            D.Exclusion_Rule := No_Exclusion;
         when Thinking_Tokens_Xbar | Thinking_Tokens_S =>
            D.Get_Subgroup   := Sub_Thinking_Tokens'Access;
            D.Exclusion_Rule := Zero_Thinking;
         when Tool_Call_Tokens_Xbar | Tool_Call_Tokens_S =>
            D.Get_Subgroup   := Sub_Tool_Tokens'Access;
            D.Exclusion_Rule := Zero_Tool_Call_Turns;
         when Tool_Call_Failure_Rate | Fraction_Tool_Call_Turns
            | Fraction_Thinking_Turns =>
            D.Exclusion_Rule := No_Exclusion;
         when Fraction_Thinking_Tokens_I
            | Fraction_Thinking_Tokens_MR
            | Fraction_Thinking_Tokens_EWMA =>
            D.Get_Observation := Obs_Frac_Thinking'Access;
            D.Exclusion_Rule  := Zero_Output_Tokens;
         when Fraction_Tool_Call_Tokens_I
            | Fraction_Tool_Call_Tokens_MR
            | Fraction_Tool_Call_Tokens_EWMA =>
            D.Get_Observation := Obs_Frac_Tool_Call'Access;
            D.Exclusion_Rule  := Zero_Output_Tokens;
         when Fraction_Thinking_Per_Tool_Call_I
            | Fraction_Thinking_Per_Tool_Call_MR
            | Fraction_Thinking_Per_Tool_Call_EWMA =>
            D.Get_Observation := Obs_Frac_Thinking_Per_Tool'Access;
            D.Exclusion_Rule  := Zero_Tool_Call_Tokens;
         when Fraction_Uncached_Input_I
            | Fraction_Uncached_Input_MR
            | Fraction_Uncached_Input_EWMA =>
            D.Get_Observation := Obs_Frac_Uncached_Input'Access;
            D.Exclusion_Rule  := Zero_Input_Tokens;
         when Session_Input_Tokens_I
            | Session_Input_Tokens_MR
            | Session_Input_Tokens_EWMA =>
            D.Get_Observation := Obs_Input_Tokens'Access;
            D.Exclusion_Rule  := Zero_Observation;
         when Session_Output_Tokens_I
            | Session_Output_Tokens_MR
            | Session_Output_Tokens_EWMA =>
            D.Get_Observation := Obs_Output_Tokens'Access;
            D.Exclusion_Rule  := Zero_Observation;
         when Session_Cache_Read_Tokens_I
            | Session_Cache_Read_Tokens_MR
            | Session_Cache_Read_Tokens_EWMA =>
            D.Get_Observation := Obs_Cache_Read'Access;
            D.Exclusion_Rule  := Zero_Observation;
         when Session_Cache_Write_Tokens_I
            | Session_Cache_Write_Tokens_MR
            | Session_Cache_Write_Tokens_EWMA =>
            D.Get_Observation := Obs_Cache_Write'Access;
            D.Exclusion_Rule  := Zero_Observation;
         when Session_Thinking_Tokens_I
            | Session_Thinking_Tokens_MR
            | Session_Thinking_Tokens_EWMA =>
            D.Get_Observation := Obs_Thinking_Tokens'Access;
            D.Exclusion_Rule  := Zero_Observation;
         when Session_Tool_Call_Tokens_I
            | Session_Tool_Call_Tokens_MR
            | Session_Tool_Call_Tokens_EWMA =>
            D.Get_Observation := Obs_Tool_Call_Tokens'Access;
            D.Exclusion_Rule  := Zero_Observation;
         when Session_Tool_Call_Result_Tokens_I
            | Session_Tool_Call_Result_Tokens_MR
            | Session_Tool_Call_Result_Tokens_EWMA =>
            D.Get_Observation := Obs_Tool_Result_Tokens'Access;
            D.Exclusion_Rule  := Zero_Observation;
         when Session_Uncached_Input_Tokens_I
            | Session_Uncached_Input_Tokens_MR
            | Session_Uncached_Input_Tokens_EWMA =>
            D.Get_Observation := Obs_Uncached_Input'Access;
            D.Exclusion_Rule  := Zero_Observation;
         when Session_Turn_Count_I
            | Session_Turn_Count_MR
            | Session_Turn_Count_EWMA =>
            D.Get_Observation := Obs_Turn_Count'Access;
            D.Exclusion_Rule  := No_Exclusion;
         when Tool_Call_JSD_Xbar | Tool_Call_JSD_S =>
            D.LF_Get_Subgroup := Sub_JSD_S'Access;
            D.Exclusion_Rule  := Zero_Tool_Call_Turns;
         when Session_Tool_Call_JSD_Sum_I
            | Session_Tool_Call_JSD_Sum_MR
            | Session_Tool_Call_JSD_Sum_EWMA =>
            D.Get_Observation := Obs_Tool_JSD_Sum'Access;
            D.Exclusion_Rule  := Zero_Tool_Call_Turns;
         when Tool_Call_MI_Xbar | Tool_Call_MI_S =>
            D.LF_Get_Subgroup := Sub_MI_LF'Access;
            D.Exclusion_Rule  := Zero_Tool_Call_Turns;
         when Session_Tool_Call_MI_Sum_I
            | Session_Tool_Call_MI_Sum_MR
            | Session_Tool_Call_MI_Sum_EWMA =>
            D.Get_Observation := Obs_Tool_MI_Sum'Access;
            D.Exclusion_Rule  := Zero_Tool_Call_Turns;
         when Turn_Tokens_Quantile =>
            D.Get_Subgroup   := Sub_Output_Tokens'Access;
            D.Exclusion_Rule := No_Exclusion;
         when Tool_Call_Tokens_Quantile =>
            D.Get_Subgroup   := Sub_Tool_Tokens'Access;
            D.Exclusion_Rule := Zero_Tool_Call_Turns;
         when Thinking_Tokens_Quantile =>
            D.Get_Subgroup   := Sub_Thinking_Tokens'Access;
            D.Exclusion_Rule := Zero_Thinking;
         when Tool_Call_JSD_Quantile =>
            D.LF_Get_Subgroup := Sub_JSD_S'Access;
            D.Exclusion_Rule  := Zero_Tool_Call_Turns;
         when Tool_Call_MI_Quantile =>
            D.LF_Get_Subgroup := Sub_MI_LF'Access;
            D.Exclusion_Rule  := Zero_Tool_Call_Turns;

         --  Token cost I/MR/EWMA charts (session-level).
         when Session_Total_Cost_I | Session_Total_Cost_MR | Session_Total_Cost_EWMA =>
            D.Get_Observation := Obs_Total_Cost'Access;
            D.Exclusion_Rule  := Zero_Observation;
         when Session_Input_Cost_I | Session_Input_Cost_MR | Session_Input_Cost_EWMA =>
            D.Get_Observation := Obs_Input_Cost'Access;
            D.Exclusion_Rule  := Zero_Observation;
         when Session_Output_Cost_I | Session_Output_Cost_MR | Session_Output_Cost_EWMA =>
            D.Get_Observation := Obs_Output_Cost'Access;
            D.Exclusion_Rule  := Zero_Observation;
         when Session_Cache_Read_Cost_I | Session_Cache_Read_Cost_MR | Session_Cache_Read_Cost_EWMA =>
            D.Get_Observation := Obs_Cache_Read_Cost'Access;
            D.Exclusion_Rule  := Zero_Observation;
         when Session_Cache_Write_Cost_I | Session_Cache_Write_Cost_MR | Session_Cache_Write_Cost_EWMA =>
            D.Get_Observation := Obs_Cache_Write_Cost'Access;
            D.Exclusion_Rule  := Zero_Observation;
         when Session_Uncached_Input_Cost_I | Session_Uncached_Input_Cost_MR | Session_Uncached_Input_Cost_EWMA =>
            D.Get_Observation := Obs_Uncached_Input_Cost'Access;
            D.Exclusion_Rule  := Zero_Observation;
         --  Token cost Xbar/S charts (turn-level).
         when Turn_Total_Cost_Xbar | Turn_Total_Cost_S =>
            D.LF_Get_Subgroup := Sub_Total_Cost'Access;
            D.Exclusion_Rule  := No_Exclusion;
         when Turn_Input_Cost_Xbar | Turn_Input_Cost_S =>
            D.LF_Get_Subgroup := Sub_Input_Cost'Access;
            D.Exclusion_Rule  := No_Exclusion;
         when Turn_Output_Cost_Xbar | Turn_Output_Cost_S =>
            D.LF_Get_Subgroup := Sub_Output_Cost'Access;
            D.Exclusion_Rule  := No_Exclusion;
         when Turn_Cache_Read_Cost_Xbar | Turn_Cache_Read_Cost_S =>
            D.LF_Get_Subgroup := Sub_Cache_Read_Cost'Access;
            D.Exclusion_Rule  := No_Exclusion;
         when Turn_Cache_Write_Cost_Xbar | Turn_Cache_Write_Cost_S =>
            D.LF_Get_Subgroup := Sub_Cache_Write_Cost'Access;
            D.Exclusion_Rule  := No_Exclusion;
         when Turn_Uncached_Input_Cost_Xbar | Turn_Uncached_Input_Cost_S =>
            D.LF_Get_Subgroup := Sub_Uncached_Input_Cost'Access;
            D.Exclusion_Rule  := No_Exclusion;

      end case;
      return D;
   end Descriptor;

   --  ── Recompute_Chart ──────────────────────────────────────────────────


   procedure Recompute_Chart (Kind : Chart_Kind) is
      Props   : constant Coyote_SQC.Charts.Chart_Properties :=
        Coyote_SQC.Charts.Properties (Kind);
      Dsc     : constant Chart_Descriptor := Descriptor (Kind);

      CD : Chart_Data;
      --  State for moving-range (MR) chart kinds.
      Prev_Total     : Long_Float := 0.0;
      Has_Prev_Total : Boolean    := False;
      --  Box-Cox transformed tracking for MR chart kinds.
      --  State for EWMA chart kinds.
      Z_Ewma_Prev : Long_Float := 0.0;  --  Z_{t-1}; reset to Grand_Mean before loop
      T_Ewma      : Natural    := 0;    --  step counter (1-based)
      --  Per-chart settings (Box-Cox, estimation method, EWMA params).
      Chart_Cfg : constant Coyote_SQC.Data_Model.Chart_Settings_Record :=
        Coyote_SQC.Workspace.Chart_Settings (State.Workspace, Kind);
      --  Return subgroup values as Long_Float regardless of which accessor
      --  (Natural or Long_Float) the chart uses.  Enables Box-Cox parameter
      --  estimation and application to share a single code flow for both
      --  token-based and JSD chart kinds.
      function Get_LF_Values
        (M : Session_Metrics_Record)
        return Long_Float_Vectors.Vector
      is
      begin
         if Dsc.LF_Get_Subgroup /= null then
            return Dsc.LF_Get_Subgroup (M);
         elsif Dsc.Get_Subgroup /= null then
            declare
               NV  : constant Natural_Vectors.Vector :=
                 Dsc.Get_Subgroup (M);
               LFV : Long_Float_Vectors.Vector;
            begin
               for V of NV loop
                  LFV.Append (Long_Float (V));
               end loop;
               return LFV;
            end;
         else
            return Long_Float_Vectors.Empty_Vector;
         end if;
      end Get_LF_Values;
      --  Return True when V is in the domain of the given transform.
      --  Box_Cox requires strictly positive input (ln(0) is undefined).
      --  Sqrt_VS / Anscombe / Freeman_Tukey require V >= 0.
      --  Arcsinh_VS accepts all real values.
      function Transform_Domain_OK
        (V    : Long_Float;
         Kind : Data_Model.Transform_Kind) return Boolean
      is
         use Data_Model;
      begin
         case Kind is
            when Arcsinh_VS    => return V > Long_Float'First;
            when Box_Cox       => return V > 0.0;
            when None | Sqrt_VS | Anscombe | Freeman_Tukey =>
               return V >= 0.0;
         end case;
      end Transform_Domain_OK;
   begin
      --  Estimate setup parameters.
      CD.Is_Retro := State.Workspace.Setup_Session_Ids.Is_Empty;
      Statistics.Estimate_Parameters
        (Metrics   => State.All_Metrics,
         Setup_Ids => State.Workspace.Setup_Session_Ids,
         Kind      => Kind,
         Method    => Chart_Cfg.Estimation_Method,
         Parameters => CD.Params);

      --  Box-Cox: when enabled for I/EWMA/Turn Count chart kinds, override the
      --  Grand_Mean and I_Sigma in CD.Params with transformed-space values.
      if Dsc.Get_Observation /= null
        and then not Props.Is_MR_Chart
        and then Chart_Cfg.Transform.Kind /= Data_Model.None
      then
         declare
            --  Collect setup-interval raw values in chronological order.
            Raw   : Coyote_SQC.Statistics.I_Chart.Long_Float_Array
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
                     Obs_R : constant Observation_Result :=
                       Dsc.Get_Observation (M);
                  begin
                     if Obs_R.Valid
                       and then Transform_Domain_OK
                                  (Obs_R.Value, Chart_Cfg.Transform.Kind)
                     then
                        N_Raw := N_Raw + 1;
                        Raw (N_Raw) := Obs_R.Value;
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
                  & " I/MR chart (transform requires positive input).");
            end if;

            --  Resolve lambda.
            if Chart_Cfg.Transform.Lambda_Source =
                  Data_Model.Fixed
            then
               Lambda := Chart_Cfg.Transform.Fixed_Lambda;
            else
               if Chart_Cfg.Transform.Kind = Data_Model.Box_Cox and then N_Raw >= 3 then
                  declare
                     Fallback : Boolean;
                  begin
                     Lambda := Coyote_SQC.Statistics.I_Chart.Estimate_Lambda
                                 (Raw (1 .. N_Raw),
                                  Use_Robust    =>
                                    Chart_Cfg.Transform
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
            CD.Transform_Lambda := Lambda;
            CD.Transform_Active := Chart_Cfg.Transform.Kind;

            --  Recompute Grand_Mean and I_Sigma in the transformed space.
            --  I_Sigma: classical = mean(MR_z)/d2; robust = Qn(z_vals)/2.2219.
            if N_Raw > 0 then
               declare
                  Z_Vals   : Coyote_SQC.Statistics.I_Chart.Long_Float_Array (1 .. N_Raw);
                  Sum_Z    : Long_Float := 0.0;
                  Prev_Z   : Long_Float := 0.0;
                  Has_PZ   : Boolean    := False;
                  MR_Z_Sum : Long_Float := 0.0;
                  MR_Z_Cnt : Natural    := 0;
               begin
                  for Idx in 1 .. N_Raw loop
                     declare
                        Z : constant Long_Float :=
                          Coyote_SQC.Statistics.I_Chart.Apply_Transform (Raw (Idx), Chart_Cfg.Transform.Kind, Lambda);
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
                  if Chart_Cfg.Estimation_Method =
                        Data_Model.Robust_Median
                  then
                     CD.Params.Grand_Mean :=
                       Coyote_SQC.Statistics.I_Chart.Median_Of (Z_Vals);
                     if N_Raw >= 2 then
                        CD.Params.I_Sigma :=
                          Coyote_SQC.Statistics.I_Chart.Qn_Scale_Any (Z_Vals) / 2.2219;
                     end if;
                  else
                     CD.Params.Grand_Mean := Sum_Z / Long_Float (N_Raw);
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
        and then Dsc.Get_Observation /= null
        and then Chart_Cfg.Transform.Kind /= Data_Model.None
      then
         declare
            Raws  : Coyote_SQC.Statistics.I_Chart.Long_Float_Array
                      (1 .. Natural (State.All_Metrics.Length));
            N_R   : Natural := 0;
         begin
            for M of State.All_Metrics loop
               if State.Workspace.Setup_Session_Ids.Is_Empty
                 or else State.Workspace.Setup_Session_Ids.Contains
                           (M.Session_Id)
               then
                  declare
                     Obs_R : constant Observation_Result :=
                       Dsc.Get_Observation (M);
                  begin
                     if Obs_R.Valid then
                        N_R := N_R + 1;
                        Raws (N_R) := Obs_R.Value;
                     end if;
                  end;
               end if;
            end loop;

            if N_R >= 2 then
               declare
                  MR_Buf    : Coyote_SQC.Statistics.I_Chart.Long_Float_Array
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
                        if Transform_Domain_OK (MR_I, Chart_Cfg.Transform.Kind) then
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

                  if Chart_Cfg.Transform.Lambda_Source =
                        Data_Model.Fixed
                  then
                     Lambda_MR :=
                       Chart_Cfg.Transform.Fixed_Lambda;
                  elsif Chart_Cfg.Transform.Kind = Data_Model.Box_Cox and then N_MR >= 3 then
                     declare
                        Fallback : Boolean;
                     begin
                        Lambda_MR := Coyote_SQC.Statistics.I_Chart.Estimate_Lambda
                          (MR_Buf (1 .. N_MR),
                           Use_Robust    =>
                             Chart_Cfg.Transform.Lambda_Source =
                             Data_Model.Robust_Auto,
                           Fallback_Used => Fallback);
                     end;
                  end if;

                  if N_MR > 0 then
                     declare
                        W_Arr : Coyote_SQC.Statistics.I_Chart.Long_Float_Array
                                  (1 .. N_MR);
                        W_Sum : Long_Float := 0.0;
                        CL_W  : Long_Float;
                     begin
                        for Idx in 1 .. N_MR loop
                           W_Arr (Idx) :=
                             Coyote_SQC.Statistics.I_Chart.Apply_Transform
                               (MR_Buf (Idx), Chart_Cfg.Transform.Kind, Lambda_MR);
                           W_Sum := W_Sum + W_Arr (Idx);
                        end loop;
                        if Chart_Cfg.Estimation_Method =
                              Data_Model.Robust_Median
                        then
                           CL_W := Coyote_SQC.Statistics.I_Chart.Median_Of (W_Arr);
                        else
                           CL_W := W_Sum / Long_Float (N_MR);
                        end if;

                        if CL_W > 0.0 then
                           declare
                              MR_W_Lim : constant Statistics.Limits_Record :=
                                Coyote_SQC.Statistics.I_Chart.Compute_MR_Limits (CL_W);
                           begin
                              CD.MR_Transform_Limits :=
                                (UCL     =>
                                   Coyote_SQC.Statistics.I_Chart.Invert_Transform
                                     (MR_W_Lim.UCL, Chart_Cfg.Transform.Kind, Lambda_MR),
                                 CL      =>
                                   Coyote_SQC.Statistics.I_Chart.Invert_Transform
                                     (MR_W_Lim.CL,  Chart_Cfg.Transform.Kind, Lambda_MR),
                                 LCL     => 0.0,
                                 Has_UCL => True,
                                 Has_LCL => False);
                              CD.MR_Transform_Lambda := Lambda_MR;
                              CD.MR_Transform_Active := Chart_Cfg.Transform.Kind;
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
      --  When Box-Cox is enabled for Xbar/S charts, estimate lambda independently for
      --  each chart pair (Turn/Tool/Thinking) from the setup-interval
      --  per-turn values, then override CD.Params.Grand_Mean and
      --  CD.Params.Pooled_S with their transformed-space equivalents so
      --  that the standard Xbar/S limit formulas operate in z-space.
      --  For Xbar charts, limits are back-transformed to original units.
      if Props.Is_Xbar_S_Chart
        and then Chart_Cfg.Transform.Kind /= Data_Model.None
        and then (Dsc.Get_Subgroup /= null
                  or else Dsc.LF_Get_Subgroup /= null)
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

         begin
            --  Pass 1: count eligible values.
            for M of State.All_Metrics loop
               if Is_Setup_M (M) then
                  for V of Get_LF_Values (M) loop
                     if not Transform_Domain_OK (V, Chart_Cfg.Transform.Kind) then
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
                  & " subgroup value(s) with zero excluded from Xbar/S"
                  & " chart transform estimation.");
            end if;

            --  Resolve lambda (fixed or auto-estimate).
            if Chart_Cfg.Transform.Lambda_Source =
                  Data_Model.Fixed
            then
               Lambda := Chart_Cfg.Transform.Fixed_Lambda;
            else
               --  Pass 2: fill array for Estimate_Lambda.
               declare
                  Raw   : Coyote_SQC.Statistics.I_Chart.Long_Float_Array
                            (1 .. Max_Vals);
                  N_Raw : Natural := 0;
               begin
                  for M of State.All_Metrics loop
                     if Is_Setup_M (M) then
                        for V of Get_LF_Values (M) loop
                           if V > 0.0 then
                              N_Raw := N_Raw + 1;
                              Raw (N_Raw) := V;
                           end if;
                        end loop;
                     end if;
                  end loop;
                  if N_Raw >= 3 then
                     declare
                        Fallback : Boolean;
                     begin
                        Lambda := Coyote_SQC.Statistics.I_Chart.Estimate_Lambda
                                    (Raw (1 .. N_Raw),
                                     Use_Robust    =>
                                       Chart_Cfg.Transform
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

            CD.Transform_Lambda := Lambda;
            CD.Transform_Active := Chart_Cfg.Transform.Kind;

            --  Pass 3: compute Grand_Mean_Z and Pooled_S_Z by session.
            --  Each session contributes N_Z transformed values; we weight
            --  by session size for the grand mean and use pooled variance.
            if Max_Vals > 0 then
               if Chart_Cfg.Estimation_Method =
                     Data_Model.Robust_Median
               then
                  --  Robust path: collect session means and in-session
                  --  residuals in the transformed space, then use median
                  --  and Qn for Grand_Mean and Pooled_S respectively.
                  declare
                     Rob_Means     : Coyote_SQC.Data_Model.Long_Float_Vectors.Vector;
                     Rob_Residuals : Coyote_SQC.Data_Model.Long_Float_Vectors.Vector;
                  begin
                     for M of State.All_Metrics loop
                        if Is_Setup_M (M) then
                           declare
                              Tokens : constant Long_Float_Vectors.Vector :=
                                Get_LF_Values (M);
                              Z_Sum  : Long_Float := 0.0;
                              N_Z    : Natural    := 0;
                              Z_Vals : Coyote_SQC.Statistics.I_Chart.Long_Float_Array
                                         (1 .. Natural (Tokens.Length));
                           begin
                              for V of Tokens loop
                                 if V > 0.0 then
                                    declare
                                       Z : constant Long_Float :=
                                         Coyote_SQC.Statistics.I_Chart.Apply_Transform
                                           (V, Chart_Cfg.Transform.Kind, Lambda);
                                    begin
                                       Z_Sum := Z_Sum + Z;
                                       N_Z := N_Z + 1;
                                       Z_Vals (N_Z) := Z;
                                    end;
                                 end if;
                              end loop;
                              if N_Z > 0 then
                                 declare
                                    Mean_Z : constant Long_Float :=
                                      Z_Sum / Long_Float (N_Z);
                                 begin
                                    Rob_Means.Append (Mean_Z);
                                    for Idx in 1 .. N_Z loop
                                       Rob_Residuals.Append
                                         (Z_Vals (Idx) - Mean_Z);
                                    end loop;
                                 end;
                              end if;
                           end;
                        end if;
                     end loop;

                     --  Grand_Mean: median of session means.
                     if not Rob_Means.Is_Empty then
                        declare
                           N_Sess : constant Positive :=
                             Positive (Rob_Means.Length);
                           Arr : Coyote_SQC.Statistics.I_Chart.Long_Float_Array
                                   (1 .. N_Sess);
                           Idx : Positive := 1;
                        begin
                           for V of Rob_Means loop
                              Arr (Idx) := V;
                              Idx := Idx + 1;
                           end loop;
                           CD.Params.Grand_Mean :=
                             Coyote_SQC.Statistics.I_Chart.Median_Of (Arr);
                        end;
                     end if;

                     --  Pooled_S: Qn scale of all pooled within-session
                     --  residuals in z-space.
                     if not Rob_Residuals.Is_Empty
                       and then Natural (Rob_Residuals.Length) >= 2
                     then
                        declare
                           N_Res : constant Positive :=
                             Positive (Rob_Residuals.Length);
                           Arr : Coyote_SQC.Statistics.I_Chart.Long_Float_Array
                                   (1 .. N_Res);
                           Idx : Positive := 1;
                        begin
                           for V of Rob_Residuals loop
                              Arr (Idx) := V;
                              Idx := Idx + 1;
                           end loop;
                           CD.Params.Pooled_S :=
                             Coyote_SQC.Statistics.I_Chart.Qn_Scale_Any (Arr);
                        end;
                     end if;
                  end;
               else
                  --  Classical path: weighted mean and pooled variance.
                  declare
                     Total_N  : Long_Float := 0.0;
                     Total_WM : Long_Float := 0.0;
                     Sum_Num  : Long_Float := 0.0;
                     Sum_Den  : Long_Float := 0.0;
                  begin
                     for M of State.All_Metrics loop
                        if Is_Setup_M (M) then
                           declare
                              Tokens : constant Long_Float_Vectors.Vector :=
                                Get_LF_Values (M);
                              Z_Sum  : Long_Float := 0.0;
                              Z_Sq   : Long_Float := 0.0;
                              N_Z    : Natural    := 0;
                           begin
                              for V of Tokens loop
                                 if V > 0.0 then
                                    declare
                                       Z : constant Long_Float :=
                                         Coyote_SQC.Statistics.I_Chart.Apply_Transform
                                           (V, Chart_Cfg.Transform.Kind, Lambda);
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
            end if;
         end;
      end if;



      --  Initialise EWMA state: Z_0 = Grand_Mean (in original or z-space).
      if Props.Is_EWMA_Chart then
         Z_Ewma_Prev := CD.Params.Grand_Mean;
      end if;

      --  ── Quantile Control Chart path ──────────────────────────────────
      if Props.Is_Quantile_CC_Chart then
         --  Quantile CC uses a two-stage bootstrap; the regular Chart_Point
         --  loop is skipped.  Instead, Quantile_Points are populated with
         --  the five-quantile statistics and bootstrap-based limits.
         declare
            use Coyote_SQC.Statistics.Quantile_CC;

            --  Build the reference pool: flattened subgroup values from
            --  all eligible setup-interval sessions, plus offsets and
            --  lengths for per-session grouping.
            type Pool_Acc is access Long_Float_Array;
            Pool_Vals : Pool_Acc :=
              new Long_Float_Array (1 .. 1024 * 1024);
            procedure Free_Pool is
              new Ada.Unchecked_Deallocation
                (Long_Float_Array, Pool_Acc);
            Pool_Offs    : Data_Model.Natural_Vectors.Vector;
            Pool_Lens    : Data_Model.Natural_Vectors.Vector;
            Pool_Idx     : Natural := 0;
            Pool_Count   : Natural := 0;

            procedure Append_Subgroup (Vals : Long_Float_Vectors.Vector) is
               Len : constant Natural := Natural (Vals.Length);
            begin
               if Len = 0 then
                  return;
               end if;
               if Pool_Idx + Len > Pool_Vals'Last then
                  return;  --  safety clamp
               end if;
               Pool_Offs.Append (Pool_Idx);
               Pool_Lens.Append (Len);
               for I in 1 .. Len loop
                  Pool_Vals (Pool_Idx + I) := Vals.Element (I);
               end loop;
               Pool_Idx := Pool_Idx + Len;
               Pool_Count := Pool_Count + 1;
            end Append_Subgroup;

            Is_Retro : constant Boolean :=
              State.Workspace.Setup_Session_Ids.Is_Empty;
         begin
            --  Populate the reference pool from setup-interval sessions
            --  (or all sessions for retrospective mode).
            for M of State.All_Metrics loop
               if Is_Retro
                 or else State.Workspace.Setup_Session_Ids.Contains
                           (M.Session_Id)
               then
                  case Dsc.Exclusion_Rule is
                     when Zero_Thinking =>
                        if not M.Any_Thinking then
                           goto Skip_Pool_Session;
                        end if;
                     when Zero_Tool_Call_Turns =>
                        if M.N_Tool_Call_Turns_For_Chart = 0 then
                           goto Skip_Pool_Session;
                        end if;
                     when others => null;
                  end case;

                  declare
                     LFV : constant Long_Float_Vectors.Vector :=
                       Get_LF_Values (M);
                  begin
                     if Natural (LFV.Length) > 0 then
                        Append_Subgroup (LFV);
                     end if;
                  end;
               end if;
               <<Skip_Pool_Session>>
            end loop;

            --  Clear and reuse the per-chart quantile cache.
            Clear_Cache (CD.Quantile_Cache);

            --  Compute one quantile diagram per session.
            CD.Quantile_Points.Clear;
            for I in 1 .. Natural (State.Sessions.Length) loop
               declare
                  Sess  : constant Data_Model.Session_Record :=
                    State.Sessions.Element (I);
                  M     : constant Data_Model.Session_Metrics_Record :=
                    State.All_Metrics.Element (I);
                  In_Setup : constant Boolean :=
                    State.Workspace.Setup_Session_Ids.Contains
                      (Sess.Session_Id);
                  Has_Comm : constant Boolean :=
                    Has_Comment (To_String (Sess.Session_Id));
                  QP : Quantile_Point;
               begin
                  QP.Session_Id    := Sess.Session_Id;
                  QP.Session_Index := I;
                  QP.Session_Time  := Sess.Start_Time;
                  QP.In_Setup      := In_Setup;
                  QP.Has_Comment   := Has_Comm;

                  case Dsc.Exclusion_Rule is
                     when Zero_Thinking =>
                        if not M.Any_Thinking then
                           QP.Excluded := True;
                        end if;
                     when Zero_Tool_Call_Turns =>
                        if M.N_Tool_Call_Turns_For_Chart = 0 then
                           QP.Excluded := True;
                        end if;
                     when others => null;
                  end case;

                  if not QP.Excluded then
                     declare
                        LFV : constant Long_Float_Vectors.Vector :=
                          Get_LF_Values (M);
                        N_I : constant Natural := Natural (LFV.Length);
                     begin
                        if N_I = 0 then
                           QP.Excluded := True;
                        else
                           QP.N := N_I;
                           declare
                              Sorted : Long_Float_Array (1 .. N_I);
                           begin
                              for J in 1 .. N_I loop
                                 Sorted (J) := LFV.Element (J);
                              end loop;
                              QP.Values := Compute_Quantiles (Sorted, N_I);
                           end;
                           if Pool_Count > 0 then
                              if State.Workspace.Interpolate_Quantile_Limits
                              then
                                 QP.Limits := Interpolate_Limits
                                   (Cache        => CD.Quantile_Cache,
                                    Pool_Values  =>
                                      Pool_Vals (1 .. Pool_Idx),
                                    Pool_Offsets => Pool_Offs,
                                    Pool_Lengths => Pool_Lens,
                                    N_I          => N_I,
                                    Bonferroni_Enabled => State.Workspace.Quantile_Bonferroni);
                              else
                                 declare
                                    Dist : constant Bootstrap_Distribution :=
                                      Get_Distribution
                                        (CD.Quantile_Cache,
                                         Pool_Vals (1 .. Pool_Idx),
                                         Pool_Offs, Pool_Lens,
                                         N_I);
                                 begin
                                    QP.Limits := Extract_Limits
                                      (Dist,
                                       State.Workspace.Quantile_Bonferroni);
                                 end;
                              end if;
                           else
                              for Comp in Quantile_Index loop
                                 QP.Limits (Comp) :=
                                   (UCL => 0.0, CL => 0.0, LCL => 0.0,
                                    Has_UCL => False, Has_LCL => False);
                              end loop;
                           end if;
                           QP.OOC_Comps :=
                             OOC_Components (QP.Values, QP.Limits);
                           QP.Has_OOC :=
                             Session_Is_OOC (QP.Values, QP.Limits);
                        end if;
                     end;
                  end if;

                  CD.Quantile_Points.Append (QP);
               end;
            end loop;

            Free_Pool (Pool_Vals);
            CD.Is_Retro := Is_Retro;
            State.Charts (Kind) := CD;
            return;
         end;
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
            Compute_Session_Stat (M, Kind, Value, N, Excl, Single, HGray, Chart_Cfg.Plot_Method);
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
                      | Session_Total_Cost_MR
                      | Session_Input_Cost_MR
                      | Session_Output_Cost_MR
                      | Session_Cache_Read_Cost_MR
                      | Session_Cache_Write_Cost_MR
                      | Session_Uncached_Input_Cost_MR
            then
               declare
                  Obs_R : constant Observation_Result :=
                    Dsc.Get_Observation (M);
               begin
                  --  MR points are always original-space absolute differences.
                  if Obs_R.Valid then
                     if Has_Prev_Total then
                        Value := abs (Obs_R.Value - Prev_Total);
                        Excl  := False;
                     end if;
                     Prev_Total     := Obs_R.Value;
                     Has_Prev_Total := True;
                  end if;
               end;
            end if;

            --  Fraction & JSD-sum I/MR: ratio/JSD accessors return
            --  (Valid => False) for excluded sessions (zero denominator);
            --  skip those for MR purposes.
            if Kind in Fraction_Thinking_Tokens_MR | Fraction_Tool_Call_Tokens_MR
            then
               declare
                  Obs_R : constant Observation_Result :=
                    Dsc.Get_Observation (M);
               begin
                  if Obs_R.Valid then
                     if Has_Prev_Total then
                        Value := abs (Obs_R.Value - Prev_Total);
                        Excl  := False;
                     end if;
                     Prev_Total     := Obs_R.Value;
                     Has_Prev_Total := True;
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
                  Obs_R : constant Observation_Result :=
                    Dsc.Get_Observation (M);
               begin
                  if Obs_R.Valid then
                     declare
                        Raw_X : constant Long_Float := Obs_R.Value;
                     begin
                        if CD.Transform_Active /= Data_Model.None
                          and then Raw_X > 0.0
                        then
                           declare
                              Z_X : constant Long_Float :=
                                Coyote_SQC.Statistics.I_Chart.Apply_Transform
                                  (Raw_X, CD.Transform_Active,
                                   CD.Transform_Lambda);
                              Sigma_Z : constant Long_Float :=
                                CD.Params.I_Sigma;
                           begin
                              Z_Ewma_Prev :=
                                Statistics.EWMA_Chart.Compute_Z
                                  (X      => Z_X,
                                   Z_Prev => Z_Ewma_Prev,
                                   Weight => Chart_Cfg.EWMA_Weight);
                              T_Ewma := T_Ewma + 1;
                              --  Assume success; back-transform failures below
                              --  will reset Excl to True.
                              Excl := False;
                              declare
                                 Lim_Z       : constant Statistics.Limits_Record :=
                                   Statistics.EWMA_Chart.Compute_EWMA_Limits
                                     (Grand_Mean => CD.Params.Grand_Mean,
                                      Sigma      => Sigma_Z,
                                      Weight     => Chart_Cfg.EWMA_Weight,
                                      L          => Chart_Cfg.EWMA_L,
                                      T          => T_Ewma);
                                 Inv_UCL     : Long_Float := 0.0;
                                 Has_Inv_UCL : Boolean    := False;
                                 Inv_CL      : Long_Float := 0.0;
                                 Inv_LCL     : Long_Float := 0.0;
                                 Has_Inv_LCL : Boolean    := False;
                              begin
                                 begin
                                    Inv_UCL :=
                                      Coyote_SQC.Statistics.I_Chart.Invert_Transform
                                        (Lim_Z.UCL, CD.Transform_Active,
                                         CD.Transform_Lambda);
                                    Has_Inv_UCL := Lim_Z.Has_UCL;
                                 exception
                                    when Constraint_Error => null;
                                 end;
                                 begin
                                    Inv_CL :=
                                      Coyote_SQC.Statistics.I_Chart.Invert_Transform
                                        (Lim_Z.CL, CD.Transform_Active,
                                         CD.Transform_Lambda);
                                 exception
                                    when Constraint_Error => Excl := True;
                                 end;
                                 if not Excl and then Lim_Z.Has_LCL then
                                    begin
                                       Inv_LCL :=
                                         Coyote_SQC.Statistics.I_Chart.Invert_Transform
                                           (Lim_Z.LCL, CD.Transform_Active,
                                            CD.Transform_Lambda);
                                       Has_Inv_LCL := True;
                                    exception
                                       when Constraint_Error => null;
                                    end;
                                 end if;
                                 if not Excl then
                                    begin
                                       Value :=
                                         Coyote_SQC.Statistics.I_Chart.Invert_Transform
                                           (Z_Ewma_Prev, CD.Transform_Active,
                                            CD.Transform_Lambda);
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
                        elsif CD.Transform_Active = Data_Model.None then
                           --  No transformation: EWMA in original (token) space.
                           declare
                              Sigma : constant Long_Float := CD.Params.I_Sigma;
                           begin
                              Z_Ewma_Prev :=
                                Statistics.EWMA_Chart.Compute_Z
                                  (X      => Raw_X,
                                   Z_Prev => Z_Ewma_Prev,
                                   Weight => Chart_Cfg.EWMA_Weight);
                              T_Ewma := T_Ewma + 1;
                              Limits :=
                                Statistics.EWMA_Chart.Compute_EWMA_Limits
                                  (Grand_Mean => CD.Params.Grand_Mean,
                                   Sigma      => Sigma,
                                   Weight     => Chart_Cfg.EWMA_Weight,
                                   L          => Chart_Cfg.EWMA_L,
                                   T          => T_Ewma);
                              Value := Z_Ewma_Prev;
                              Excl  := False;
                           end;
                        end if;
                        --  Box-Cox active with Raw_X = 0: Excl stays True.
                     end;
                  end if;
                  --  Obs_R.Valid is False: session has no valid observation
                  --  (zero denominator); Excl stays True.
               end;
            end if;


            --  Xbar/S Box-Cox: transform per-turn values and recompute the
            --  session statistic in z-space.  For Xbar charts the mean is
            --  back-transformed to original token units; for S charts the
            --  standard deviation remains in transformed units.
            if CD.Transform_Active /= Data_Model.None
              and then not Excl
              and then Dsc.Properties.Is_Xbar_S_Chart
            then
               declare
                  Tokens : constant Long_Float_Vectors.Vector :=
                    Get_LF_Values (M);
                  Z_Sum  : Long_Float := 0.0;
                  Z_Sq   : Long_Float := 0.0;
                  N_Z    : Natural    := 0;
                  Use_Robust_Plot : constant Boolean :=
                    Chart_Cfg.Plot_Method = Robust_Median;
                  Z_Vals : Coyote_SQC.Statistics.I_Chart.Long_Float_Array
                             (1 .. Natural (Tokens.Length));
               begin
                  for V of Tokens loop
                     if not Transform_Domain_OK (V, Chart_Cfg.Transform.Kind) then
                        --  Any zero turn value → exclude this session from
                        --  the transform chart (value outside domain).
                        Excl := True;
                     elsif not Excl then
                        declare
                           Z : constant Long_Float :=
                             Coyote_SQC.Statistics.I_Chart.Apply_Transform
                               (V, CD.Transform_Active, CD.Transform_Lambda);
                        begin
                           Z_Sum := Z_Sum + Z;
                           Z_Sq  := Z_Sq  + Z * Z;
                           N_Z   := N_Z + 1;
                           if Use_Robust_Plot then
                              Z_Vals (N_Z) := Z;
                           end if;
                        end;
                     end if;
                  end loop;

                  if not Excl then
                     if N_Z = 0 then
                        Excl := True;
                     else
                        if Use_Robust_Plot then
                           --  Robust estimators on transformed values.
                           declare
                              Z_Sub : constant
                                Coyote_SQC.Statistics.I_Chart
                                  .Long_Float_Array :=
                                  Z_Vals (1 .. N_Z);
                           begin
                              if not Dsc.Properties.Is_S_Chart then
                                 --  Xbar: median of z-values,
                                 --  back-transform to original.
                                 declare
                                    Med_Z : constant Long_Float :=
                                      Coyote_SQC.Statistics.I_Chart.Median_Of
                                        (Z_Sub);
                                 begin
                                    Value :=
                                      Coyote_SQC.Statistics.I_Chart.Invert_Transform
                                        (Med_Z, CD.Transform_Active,
                                         CD.Transform_Lambda);
                                 exception
                                    when Constraint_Error => Excl := True;
                                 end;
                              else
                                 --  S chart: Qn scale of z-values
                                 --  (stays in z-space).
                                 if N_Z >= 2 then
                                    Value :=
                                      Coyote_SQC.Statistics.I_Chart.Qn_Scale_Any
                                        (Z_Sub);
                                    Single := False;
                                 else
                                    Excl := True;
                                 end if;
                              end if;
                           end;
                        else
                           --  Classical estimators: mean / sample std dev.
                           declare
                              Mean_Z : constant Long_Float :=
                                Z_Sum / Long_Float (N_Z);
                           begin
                              if not Dsc.Properties.Is_S_Chart then
                                 --  Back-transform session mean to original
                                 --  token units for display.
                                 begin
                                    Value :=
                                      Coyote_SQC.Statistics.I_Chart.Invert_Transform
                                        (Mean_Z, CD.Transform_Active,
                                         CD.Transform_Lambda);
                                 exception
                                    when Constraint_Error => Excl := True;
                                 end;
                              else
                                 --  Std dev stays in transformed units.
                                 if N_Z >= 2 then
                                    Value :=
                                      Sqrt
                                        ((Z_Sq
                                          - Z_Sum * Z_Sum
                                            / Long_Float (N_Z))
                                           / Long_Float (N_Z - 1));
                                    Single := False;
                                 else
                                    Excl := True;
                                 end if;
                              end if;
                           end;
                        end if;
                     end if;
                  end if;
               end;
            end if;

            if Excl then
               Limits := (UCL => 0.0, CL => 0.0, LCL => 0.0,
                          Has_UCL => False,
                          Has_LCL => False);
            else
               if Dsc.Properties.Is_P_Chart then
                  Limits := Statistics.P_Chart.Compute_Limits
                    (Grand_P => CD.Params.Grand_P,
                     N       => N);
               elsif Dsc.Properties.Is_Xbar_S_Chart then
                  if Dsc.Properties.Is_S_Chart then
                     Limits := Statistics.S_Chart.Compute_Limits
                       (Pooled_S => CD.Params.Pooled_S,
                        N        => N);
                  else
                     declare
                        L_Z : constant Statistics.Limits_Record :=
                          Statistics.Xbar.Compute_Limits
                            (Grand_Mean => CD.Params.Grand_Mean,
                             Pooled_S   => CD.Params.Pooled_S,
                             N          => N);
                     begin
                        if CD.Transform_Active /= Data_Model.None and then L_Z.Has_UCL then
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
                                   Coyote_SQC.Statistics.I_Chart.Invert_Transform
                                     (L_Z.UCL, CD.Transform_Active, CD.Transform_Lambda);
                                 Has_Inv_UCL := True;
                              exception
                                 when Constraint_Error => null;
                              end;
                              begin
                                 Inv_CL :=
                                   Coyote_SQC.Statistics.I_Chart.Invert_Transform
                                     (L_Z.CL, CD.Transform_Active, CD.Transform_Lambda);
                              exception
                                 when Constraint_Error => Excl := True;
                              end;
                              if L_Z.Has_LCL then
                                 begin
                                    Inv_LCL :=
                                      Coyote_SQC.Statistics.I_Chart.Invert_Transform
                                        (L_Z.LCL, CD.Transform_Active, CD.Transform_Lambda);
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
                  end if;
               elsif Dsc.Properties.Is_I_Chart then
                  declare
                     L_Z : constant Statistics.Limits_Record :=
                       Coyote_SQC.Statistics.I_Chart.Compute_I_Limits
                         (Grand_Mean => CD.Params.Grand_Mean,
                          Sigma      => CD.Params.I_Sigma);
                  begin
                     if CD.Transform_Active /= Data_Model.None and then L_Z.Has_UCL then
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
                                Coyote_SQC.Statistics.I_Chart.Invert_Transform
                                  (L_Z.UCL, CD.Transform_Active, CD.Transform_Lambda);
                              Has_Inv_UCL := True;
                           exception
                              when Constraint_Error => null;
                           end;
                           Inv_CL  := Coyote_SQC.Statistics.I_Chart.Invert_Transform
                                        (L_Z.CL, CD.Transform_Active, CD.Transform_Lambda);
                           Inv_LCL :=
                             (if L_Z.Has_LCL
                              then Coyote_SQC.Statistics.I_Chart.Invert_Transform
                                     (L_Z.LCL, CD.Transform_Active, CD.Transform_Lambda)
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
               elsif Dsc.Properties.Is_MR_Chart then
                  if CD.MR_Transform_Active /= Data_Model.None then
                     Limits := CD.MR_Transform_Limits;
                  else
                     Limits := Coyote_SQC.Statistics.I_Chart.Compute_MR_Limits
                       (Mean_MR => CD.Params.Mean_MR);
                  end if;
               else
                  null;  --  EWMA: limits were computed in the EWMA section
               end if;
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
                Has_CL        => CD.Params.Parameters_Valid and then not Excl,
                Excluded      => Excl,
                Single_Turn   => Single,
                In_Setup      => In_Setup,
                Hollow_Gray   => HGray,
                Has_Comment   => Has_Comment (To_String (Sess.Session_Id)),
                Is_OOC_From_Quantile => False));
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

      --  ── OOC propagation: Quantile CC → other charts ──────────────────
      --  Collect all session UUIDs flagged out-of-control on any Quantile
      --  CC chart, then set Is_OOC_From_Quantile on those sessions'
      --  Chart_Point entries in every non-Quantile chart kind.
      declare
         OOC_Set : Data_Model.UUID_Set;
      begin
         for K in Chart_Kind loop
            if Coyote_SQC.Charts.Properties (K).Is_Quantile_CC_Chart then
               for QP of State.Charts (K).Quantile_Points loop
                  if QP.Has_OOC then
                     OOC_Set.Include (QP.Session_Id);
                  end if;
               end loop;
            end if;
         end loop;
         for K in Chart_Kind loop
            if not Coyote_SQC.Charts.Properties (K).Is_Quantile_CC_Chart then
               for P of State.Charts (K).Points loop
                  if OOC_Set.Contains (P.Session_Id) then
                     P.Is_OOC_From_Quantile := True;
                  end if;
               end loop;
            end if;
         end loop;
      end;
   end Recompute_Charts;

   --  ── Reload_Sessions ──────────────────────────────────────────────────

   procedure Reload_Sessions is
      Old_Sessions : constant Session_Vectors.Vector :=
        State.Sessions;
      Old_Metrics  : constant Metrics_Vectors.Vector :=
        State.All_Metrics;

      Epoch : constant Ada.Calendar.Time :=
        Ada.Calendar.Time_Of (1970, 1, 1, 0.0);
   begin
      State.Sessions.Clear;
      State.All_Metrics.Clear;


      --  Load pricing data for cost chart computation.
      State.Pricing := Coyote_SQC.Config.Load_Pricing;
      --  Pass Old_Sessions so Load_Sessions can skip parsing unchanged files.
      Coyote_SQC.Session_Parser.Load_Sessions
        (Source_Directories      => State.Workspace.Source_Directories,
         Model_Filter            => State.Workspace.Model_Filter,
         Sessions                => State.Sessions,
         Analyze_All_Directories => State.Workspace.Analyze_All_Directories,
         Previous_Sessions       => Old_Sessions);

      --  Reuse cached metrics for unchanged sessions; compute only for new
      --  or modified ones.
      for Sess of State.Sessions loop
         declare
            Found : Boolean := False;
         begin
            for Old of Old_Sessions loop
               if Old.Session_Id = Sess.Session_Id
                 and then Old.File_Mtime = Sess.File_Mtime
               then
                  for M of Old_Metrics loop
                     if M.Session_Id = Old.Session_Id then
                        State.All_Metrics.Append (M);
                        Found := True;
                        exit;
                     end if;
                  end loop;
                  exit;
               end if;
            end loop;
            if not Found then
               State.All_Metrics.Append
                 (Coyote_SQC.Metrics.Compute (Sess, State.Pricing));
            end if;
         end;
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
      use Ada.Numerics.Long_Elementary_Functions;
      CS      : Canvas_State renames State.Canvas_St;
      CD      : Chart_Data renames State.Charts (State.Active_Chart);
      Log_Y   : constant Boolean := State.Workspace.Log_Y_Mode;
      Y1      : Long_Float :=  Long_Float'Last;
      Y2      : Long_Float := -Long_Float'Last;
      Any     : Boolean := False;
   begin
      for P of CD.Points loop
         if (not P.Excluded or else P.Hollow_Gray)
           and then P.Session_Time >= State.Date_From
           and then P.Session_Time <= State.Date_To
         then
            --  In log mode skip non-positive stat values.
            if not Log_Y or else P.Stat_Value > 0.0 then
               if P.Stat_Value < Y1 then Y1 := P.Stat_Value; end if;
               if P.Stat_Value > Y2 then Y2 := P.Stat_Value; end if;
               Any := True;
            end if;
            if not P.Excluded and then not P.Single_Turn then
               if P.Has_UCL then
                  --  In log mode skip non-positive UCL/LCL.
                  if not Log_Y or else P.UCL > 0.0 then
                     if P.UCL > Y2 then Y2 := P.UCL; end if;
                  end if;
                  if not Log_Y or else P.LCL > 0.0 then
                     if P.LCL < Y1 then Y1 := P.LCL; end if;
                  end if;
               end if;
            end if;
         end if;
      end loop;

      --  Quantile CC: include component values and limits in Y range.
      if Properties (State.Active_Chart).Is_Quantile_CC_Chart then
         declare
            use Coyote_SQC.Statistics.Quantile_CC;
         begin
            for QP of CD.Quantile_Points loop
               if not QP.Excluded
                 and then QP.Session_Time >= State.Date_From
                 and then QP.Session_Time <= State.Date_To
               then
                  for Comp in Quantile_Index loop
                     declare
                        V : constant Long_Float := QP.Values (Comp);
                        L : Quantile_Limits_Record renames
                          QP.Limits (Comp);
                     begin
                        --  Component value.
                        if not Log_Y or else V > 0.0 then
                           if V < Y1 then Y1 := V; end if;
                           if V > Y2 then Y2 := V; end if;
                           Any := True;
                        end if;
                        --  UCL.
                        if L.Has_UCL
                          and then (not Log_Y or else L.UCL > 0.0)
                        then
                           if L.UCL > Y2 then Y2 := L.UCL; end if;
                        end if;
                        --  LCL.
                        if L.Has_LCL
                          and then (not Log_Y or else L.LCL > 0.0)
                        then
                           if L.LCL < Y1 then Y1 := L.LCL; end if;
                        end if;
                     end;
                  end loop;
               end if;
            end loop;
         end;
      end if;

      if not Any then return; end if;

      if Log_Y and then Y1 > 0.0 then
         --  Multiplicative 10 % margin in log space.
         CS.Y_Min := Y1 / 1.1;
         CS.Y_Max := Y2 * 1.1;
      else
         declare
            Margin : constant Long_Float := (Y2 - Y1) * 0.1;
            M      : constant Long_Float :=
              (if Margin > 0.0 then Margin else 1.0);
         begin
            CS.Y_Min := Y1 - M;
            CS.Y_Max := Y2 + M;
         end;
      end if;
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
      if State.Clear_Both_Sets_Item /= null then
         State.Clear_Both_Sets_Item.Set_Sensitive
           (not State.Selection.Is_Empty
            or else not State.Set_B.Is_Empty);
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
      WS_Migrated      : Boolean := False;
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
              (Workspace_Path, State.Workspace, WS_Version_Found, WS_Migrated);
            State.Workspace_Path :=
              To_Unbounded_String (Workspace_Path);
            Coyote_SQC.Config.Record_Open
              (To_String (State.Workspace.Name), Workspace_Path);
            if WS_Migrated then
               --  Workspace was migrated from v<=6 to v7; mark as modified
               --  so the user is prompted to resave at version 7.
               State.Modified := True;
            end if;
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
