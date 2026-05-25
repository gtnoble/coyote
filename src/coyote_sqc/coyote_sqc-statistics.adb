--  Coyote_SQC.Statistics body.
--
--  All computation operates on Long_Float to match
--  Ada.Numerics.Long_Elementary_Functions.
--
--  Project: coyote

with Ada.Containers.Vectors;
with Ada.Numerics.Long_Elementary_Functions;
with Ada.Strings.Unbounded;
with Coyote_SQC.Statistics.I_Chart;

package body Coyote_SQC.Statistics is

   use Ada.Numerics.Long_Elementary_Functions;
   use Ada.Strings.Unbounded;
   use Coyote_SQC.Data_Model;
   use type Coyote_SQC.Data_Model.Estimation_Method_Kind;

   --  Internal Long_Float vector used for robust estimation accumulation.
   package LF_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Long_Float);

   --  Return the unbiased sample variance of a Natural vector.
   --  Returns 0.0 when the vector has fewer than 2 elements.
   function Sample_Variance
     (Values : Natural_Vectors.Vector) return Long_Float
   is
      N : constant Natural := Natural (Values.Length);
   begin
      if N < 2 then
         return 0.0;
      end if;
      declare
         Sum   : Long_Float := 0.0;
         Mean  : Long_Float := 0.0;
         Sumsq : Long_Float := 0.0;
      begin
         for V of Values loop
            Sum := Sum + Long_Float (V);
         end loop;
         Mean := Sum / Long_Float (N);
         for V of Values loop
            declare
               D : constant Long_Float := Long_Float (V) - Mean;
            begin
               Sumsq := Sumsq + D * D;
            end;
         end loop;
         return Sumsq / Long_Float (N - 1);
      end;
   end Sample_Variance;

   --  Return the sum of a Natural vector as a Long_Float.
   function Sum_Of (Values : Natural_Vectors.Vector) return Long_Float is
      S : Long_Float := 0.0;
   begin
      for V of Values loop
         S := S + Long_Float (V);
      end loop;
      return S;
   end Sum_Of;

   --  Return the arithmetic mean of a Natural vector, or 0.0 if empty.
   function Mean_Of (Values : Natural_Vectors.Vector) return Long_Float is
      N : constant Natural := Natural (Values.Length);
   begin
      if N = 0 then
         return 0.0;
      end if;
      return Sum_Of (Values) / Long_Float (N);
   end Mean_Of;

   --  Sort a slice of a LF_Value_Array in-place (insertion sort).
   procedure Sort_Slice
     (A : in out LF_Value_Array;
      Lo : Positive;
      Hi : Natural)
   is
   begin
      for I in Lo + 1 .. Hi loop
         declare
            Key : constant Long_Float := A (I);
            J   : Integer := I - 1;
         begin
            while J >= Lo and then A (J) > Key loop
               A (J + 1) := A (J);
               J := J - 1;
            end loop;
            A (J + 1) := Key;
         end;
      end loop;
   end Sort_Slice;

   function Median_Of (Values : LF_Value_Array) return Long_Float is
      N : constant Natural := Values'Length;
   begin
      if N = 0 then
         return 0.0;
      end if;
      if N = 1 then
         return Values (Values'First);
      end if;
      declare
         --  Work on a copy so we do not modify the caller's array.
         Copy : LF_Value_Array := Values;
         Mid  : constant Positive := Copy'First + (N - 1) / 2;
      begin
         Sort_Slice (Copy, Copy'First, Copy'Last);
         if N mod 2 = 1 then
            return Copy (Mid);
         else
            return (Copy (Mid) + Copy (Mid + 1)) / 2.0;
         end if;
      end;
   end Median_Of;

   procedure Estimate_Parameters
     (Metrics    :     Metrics_Vectors.Vector;
      Setup_Ids  :     UUID_Set;
      Kind       :     Coyote_SQC.Charts.Chart_Kind;
      Method     :     Coyote_SQC.Data_Model.Estimation_Method_Kind
      := Coyote_SQC.Data_Model.Classical;
      Parameters : out Setup_Parameters)
   is
      use Coyote_SQC.Charts;

      --  ── Classical accumulators ─────────────────────────────────────────

      --  Totals for grand mean / grand p computation (Xbar/s and I charts).
      Total_N             : Long_Float := 0.0;
      Total_Weighted_Mean : Long_Float := 0.0;

      --  Totals for pooled s computation (Xbar/s charts).
      Sum_Numerator   : Long_Float := 0.0;
      Sum_Denominator : Long_Float := 0.0;

      --  For p charts.
      Total_Events : Long_Float := 0.0;
      Total_Trials : Long_Float := 0.0;

      --  For classical I/MR charts — moving range accumulators.
      MR_Sum       : Long_Float := 0.0;
      MR_Count     : Natural    := 0;
      Prev_I_Value : Long_Float := 0.0;
      Has_Prev     : Boolean    := False;

      --  ── Robust accumulators ────────────────────────────────────────────

      --  I/MR robust: collect all observation values and MR values.
      Robust_I_Obs  : LF_Vectors.Vector;  --  one per eligible session
      Robust_I_MR   : LF_Vectors.Vector;  --  consecutive |obs_i - obs_{i-1}|
      Robust_I_Prev : Long_Float := 0.0;
      Robust_I_HasP : Boolean    := False;

      --  Xbar/s robust: session means and pooled within-session residuals.
      Robust_XS_Means     : LF_Vectors.Vector;  --  one per eligible session
      Robust_XS_Residuals : LF_Vectors.Vector;  --  x_{i,j} - x̄_i

      --  ────────────────────────────────────────────────────────────────────

      function In_Setup (M : Session_Metrics_Record) return Boolean is
      begin
         if Setup_Ids.Is_Empty then
            return True;  --  Retrospective: use all sessions
         end if;
         return Setup_Ids.Contains (M.Session_Id);
      end In_Setup;

      --  Accumulate per-turn values for Xbar/s charts (both classical and
      --  robust; the correct output is selected at finalization).
      procedure Accumulate_Xbar_S
        (Values : Natural_Vectors.Vector)
      is
         N : constant Natural := Natural (Values.Length);
      begin
         if N = 0 then
            return;
         end if;
         declare
            Session_Mean : constant Long_Float := Mean_Of (Values);
         begin
            --  Classical accumulators.
            Total_N             := Total_N + Long_Float (N);
            Total_Weighted_Mean :=
              Total_Weighted_Mean + Long_Float (N) * Session_Mean;
            if N >= 2 then
               Sum_Numerator   :=
                 Sum_Numerator + Long_Float (N - 1) * Sample_Variance (Values);
               Sum_Denominator :=
                 Sum_Denominator + Long_Float (N - 1);
            end if;

            --  Robust accumulators (session mean for Grand_Mean median;
            --  residuals for Qₙ Pooled_S).
            Robust_XS_Means.Append (Session_Mean);
            for V of Values loop
               Robust_XS_Residuals.Append
                 (Long_Float (V) - Session_Mean);
            end loop;
         end;
      end Accumulate_Xbar_S;

      --  Accumulate a single I-chart observation (session total or turn count).
      procedure Accumulate_I (Val : Long_Float) is
      begin
         --  Classical.
         Total_N             := Total_N + 1.0;
         Total_Weighted_Mean := Total_Weighted_Mean + Val;
         if Has_Prev then
            MR_Sum   := MR_Sum + abs (Val - Prev_I_Value);
            MR_Count := MR_Count + 1;
         end if;
         Prev_I_Value := Val;
         Has_Prev     := True;

         --  Robust.
         Robust_I_Obs.Append (Val);
         if Robust_I_HasP then
            Robust_I_MR.Append (abs (Val - Robust_I_Prev));
         end if;
         Robust_I_Prev := Val;
         Robust_I_HasP := True;
      end Accumulate_I;

   begin
      Parameters := (others => 0.0);

      for M of Metrics loop
         if not In_Setup (M) then
            goto Next_Metric;
         end if;

         case Kind is

            when Turn_Tokens_Xbar | Turn_Tokens_S =>
               Accumulate_Xbar_S (M.Per_Turn_Output_Tokens);

            when Tool_Call_Tokens_Xbar | Tool_Call_Tokens_S =>
               if M.N_Tool_Call_Turns_For_Chart > 0 then
                  Accumulate_Xbar_S (M.Per_Turn_Tool_Tokens);
               end if;

            when Thinking_Tokens_Xbar | Thinking_Tokens_S =>
               if M.Any_Thinking then
                  Accumulate_Xbar_S (M.Per_Turn_Thinking_Tokens);
               end if;

            when Tool_Call_Failure_Rate =>
               if M.N_Tool_Calls > 0 then
                  Total_Events :=
                    Total_Events + Long_Float (M.N_Failed_Tool_Calls);
                  Total_Trials :=
                    Total_Trials + Long_Float (M.N_Tool_Calls);
               end if;

            when Fraction_Tool_Call_Turns =>
               Total_Events :=
                 Total_Events + Long_Float (M.N_Tool_Call_Turns);
               Total_Trials :=
                 Total_Trials + Long_Float (M.N_Turns);

            when Fraction_Thinking_Turns =>
               Total_Events :=
                 Total_Events + Long_Float (M.N_Thinking_Turns);
               Total_Trials :=
                 Total_Trials + Long_Float (M.N_Turns);

            when Session_Input_Tokens_I | Session_Input_Tokens_MR
               | Session_Input_Tokens_EWMA =>
               Accumulate_I (Long_Float (M.Total_Input_Tokens));

            when Session_Output_Tokens_I | Session_Output_Tokens_MR
               | Session_Output_Tokens_EWMA =>
               Accumulate_I (Long_Float (M.Total_Output_Tokens));
            when Session_Cache_Read_Tokens_I | Session_Cache_Read_Tokens_MR
               | Session_Cache_Read_Tokens_EWMA =>
               Accumulate_I (Long_Float (M.Total_Cache_Read_Tokens));
            when Session_Cache_Write_Tokens_I | Session_Cache_Write_Tokens_MR
               | Session_Cache_Write_Tokens_EWMA =>
               Accumulate_I (Long_Float (M.Total_Cache_Write_Tokens));
            when Session_Thinking_Tokens_I
               | Session_Thinking_Tokens_MR
               | Session_Thinking_Tokens_EWMA =>
               Accumulate_I (Long_Float (M.Total_Thinking_Tokens));
            when Session_Tool_Call_Tokens_I
               | Session_Tool_Call_Tokens_MR
               | Session_Tool_Call_Tokens_EWMA =>
               Accumulate_I (Long_Float (M.Total_Tool_Call_Input_Tokens));
            when Session_Tool_Call_Result_Tokens_I
               | Session_Tool_Call_Result_Tokens_MR
               | Session_Tool_Call_Result_Tokens_EWMA =>
               Accumulate_I (Long_Float (M.Total_Tool_Call_Result_Tokens));

            when Session_Turn_Count_I
               | Session_Turn_Count_MR
               | Session_Turn_Count_EWMA =>
               Accumulate_I (Long_Float (M.N_Turns));

         end case;

         <<Next_Metric>>
      end loop;

      --  ── Finalize parameters ─────────────────────────────────────────────

      case Kind is

         when Turn_Tokens_Xbar | Turn_Tokens_S
            | Tool_Call_Tokens_Xbar | Tool_Call_Tokens_S
            | Thinking_Tokens_Xbar | Thinking_Tokens_S =>

            if Method = Robust_Median then
               --  Grand_Mean: unweighted median of session arithmetic means.
               declare
                  N_Sess : constant Natural :=
                    Natural (Robust_XS_Means.Length);
               begin
                  if N_Sess > 0 then
                     declare
                        Means_Arr : LF_Value_Array (1 .. N_Sess);
                        I         : Positive := 1;
                     begin
                        for V of Robust_XS_Means loop
                           Means_Arr (I) := V;
                           I := I + 1;
                        end loop;
                        Parameters.Grand_Mean := Median_Of (Means_Arr);
                     end;
                  end if;
               end;

               --  Pooled_S: Qₙ scale of pooled within-session residuals.
               declare
                  N_Res : constant Natural :=
                    Natural (Robust_XS_Residuals.Length);
               begin
                  if N_Res >= 2 then
                     declare
                        Res_Arr : I_Chart.Long_Float_Array (1 .. N_Res);
                        I       : Positive := 1;
                     begin
                        for V of Robust_XS_Residuals loop
                           Res_Arr (I) := V;
                           I := I + 1;
                        end loop;
                        --  Qn_Scale requires strictly positive values;
                        --  residuals can be negative.  We shift all values
                        --  by max(0, -min) + 1 to ensure positivity.
                        declare
                           Min_Val : Long_Float := Res_Arr (Res_Arr'First);
                        begin
                           for V of Res_Arr loop
                              if V < Min_Val then
                                 Min_Val := V;
                              end if;
                           end loop;
                           if Min_Val <= 0.0 then
                              declare
                                 Shift : constant Long_Float :=
                                   -Min_Val + 1.0;
                              begin
                                 for K in Res_Arr'Range loop
                                    Res_Arr (K) := Res_Arr (K) + Shift;
                                 end loop;
                              end;
                           end if;
                           --  Qn_Scale is shift-equivariant: Qn(x + c) = Qn(x).
                           Parameters.Pooled_S :=
                             I_Chart.Qn_Scale (Res_Arr);
                        end;
                     end;
                  end if;
               end;

            else
               --  Classical path.
               if Total_N > 0.0 then
                  Parameters.Grand_Mean := Total_Weighted_Mean / Total_N;
               end if;
               if Sum_Denominator > 0.0 then
                  Parameters.Pooled_S :=
                    Sqrt (Sum_Numerator / Sum_Denominator);
               end if;
            end if;

         when Tool_Call_Failure_Rate
            | Fraction_Tool_Call_Turns
            | Fraction_Thinking_Turns =>
            --  p-charts always use classical grand proportion.
            if Total_Trials > 0.0 then
               Parameters.Grand_P := Total_Events / Total_Trials;
            end if;

         when Session_Input_Tokens_I  | Session_Input_Tokens_MR
            | Session_Input_Tokens_EWMA
            | Session_Output_Tokens_I | Session_Output_Tokens_MR
            | Session_Output_Tokens_EWMA
            | Session_Cache_Read_Tokens_I  | Session_Cache_Read_Tokens_MR
            | Session_Cache_Read_Tokens_EWMA
            | Session_Cache_Write_Tokens_I | Session_Cache_Write_Tokens_MR
            | Session_Cache_Write_Tokens_EWMA
            | Session_Thinking_Tokens_I  | Session_Thinking_Tokens_MR
            | Session_Thinking_Tokens_EWMA
            | Session_Tool_Call_Tokens_I | Session_Tool_Call_Tokens_MR
            | Session_Tool_Call_Tokens_EWMA
            | Session_Tool_Call_Result_Tokens_I
            | Session_Tool_Call_Result_Tokens_MR
            | Session_Tool_Call_Result_Tokens_EWMA
            | Session_Turn_Count_I
            | Session_Turn_Count_MR
            | Session_Turn_Count_EWMA =>

            if Method = Robust_Median then
               --  Grand_Mean: median of all setup-interval observations.
               declare
                  N_Obs : constant Natural :=
                    Natural (Robust_I_Obs.Length);
               begin
                  if N_Obs > 0 then
                     declare
                        Obs_Arr : LF_Value_Array (1 .. N_Obs);
                        I       : Positive := 1;
                     begin
                        for V of Robust_I_Obs loop
                           Obs_Arr (I) := V;
                           I := I + 1;
                        end loop;
                        Parameters.Grand_Mean := Median_Of (Obs_Arr);
                        --  I_Sigma: Qn of observations / 2.2219
                        --  (replaces median(MR) / d₄ per spec §7.13).
                        if Obs_Arr'Length >= 2 then
                           declare
                              IC_Arr : I_Chart.Long_Float_Array
                                (1 .. Obs_Arr'Length);
                              J : Positive := 1;
                           begin
                              for K in Obs_Arr'Range loop
                                 IC_Arr (J) := Obs_Arr (K); J := J + 1;
                              end loop;
                              Parameters.I_Sigma :=
                                I_Chart.Qn_Scale_Any (IC_Arr) / 2.2219;
                           end;
                        end if;
                     end;
                  end if;
               end;

               --  Mean_MR: median of consecutive moving ranges.
               --  Used for MR chart UCL (D4 × median in robust mode).
               declare
                  N_MR : constant Natural :=
                    Natural (Robust_I_MR.Length);
               begin
                  if N_MR > 0 then
                     declare
                        MR_Arr : LF_Value_Array (1 .. N_MR);
                        I      : Positive := 1;
                     begin
                        for V of Robust_I_MR loop
                           MR_Arr (I) := V;
                           I := I + 1;
                        end loop;
                        Parameters.Mean_MR := Median_Of (MR_Arr);
                     end;
                  end if;
               end;

            else
               --  Classical path.
               if Total_N > 0.0 then
                  Parameters.Grand_Mean := Total_Weighted_Mean / Total_N;
               end if;
               if MR_Count > 0 then
                  Parameters.Mean_MR := MR_Sum / Long_Float (MR_Count);
               if Total_N > 0.0 and then MR_Count > 0 then
                  Parameters.I_Sigma :=
                    Parameters.Mean_MR / 1.128;
               end if;
               end if;
            end if;

      end case;
   end Estimate_Parameters;

end Coyote_SQC.Statistics;
