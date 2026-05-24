--  Coyote_SQC.Statistics body.
--
--  All computation operates on Long_Float to match
--  Ada.Numerics.Long_Elementary_Functions.
--
--  Project: coyote

with Ada.Numerics.Long_Elementary_Functions;
with Ada.Strings.Unbounded;

package body Coyote_SQC.Statistics is

   use Ada.Numerics.Long_Elementary_Functions;
   use Ada.Strings.Unbounded;
   use Coyote_SQC.Data_Model;

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

   procedure Estimate_Parameters
     (Metrics    :     Metrics_Vectors.Vector;
      Setup_Ids  :     UUID_Set;
      Kind       :     Coyote_SQC.Charts.Chart_Kind;
      Parameters : out Setup_Parameters)
   is
      use Coyote_SQC.Charts;

      --  Totals for grand mean / grand p computation (Xbar/s and I charts).
      Total_N             : Long_Float := 0.0;
      Total_Weighted_Mean : Long_Float := 0.0;

      --  Totals for pooled s computation (Xbar/s charts).
      Sum_Numerator   : Long_Float := 0.0;
      Sum_Denominator : Long_Float := 0.0;

      --  For p charts.
      Total_Events : Long_Float := 0.0;
      Total_Trials : Long_Float := 0.0;

      --  For I/MR charts — moving range accumulators.
      MR_Sum       : Long_Float := 0.0;
      MR_Count     : Natural    := 0;
      Prev_I_Value : Long_Float := 0.0;
      Has_Prev     : Boolean    := False;

      function In_Setup (M : Session_Metrics_Record) return Boolean is
      begin
         if Setup_Ids.Is_Empty then
            return True;  --  Retrospective: use all sessions
         end if;
         return Setup_Ids.Contains (M.Session_Id);
      end In_Setup;

      --  Estimate grand mean and pooled s from per-turn value vectors.
      procedure Accumulate_Xbar_S
        (Values : Natural_Vectors.Vector)
      is
         N : constant Natural := Natural (Values.Length);
      begin
         if N = 0 then
            return;
         end if;
         declare
            Mean : constant Long_Float := Mean_Of (Values);
         begin
            Total_N             := Total_N + Long_Float (N);
            Total_Weighted_Mean := Total_Weighted_Mean + Long_Float (N) * Mean;
            if N >= 2 then
               Sum_Numerator   :=
                 Sum_Numerator + Long_Float (N - 1) * Sample_Variance (Values);
               Sum_Denominator :=
                 Sum_Denominator + Long_Float (N - 1);
            end if;
         end;
      end Accumulate_Xbar_S;

      --  Accumulate a single I-chart observation (session total).
      procedure Accumulate_I (Val : Long_Float) is
      begin
         Total_N             := Total_N + 1.0;
         Total_Weighted_Mean := Total_Weighted_Mean + Val;
         if Has_Prev then
            MR_Sum   := MR_Sum + abs (Val - Prev_I_Value);
            MR_Count := MR_Count + 1;
         end if;
         Prev_I_Value := Val;
         Has_Prev     := True;
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

         end case;

         <<Next_Metric>>
      end loop;

      case Kind is

         when Turn_Tokens_Xbar | Turn_Tokens_S
            | Tool_Call_Tokens_Xbar | Tool_Call_Tokens_S
            | Thinking_Tokens_Xbar | Thinking_Tokens_S =>
            if Total_N > 0.0 then
               Parameters.Grand_Mean := Total_Weighted_Mean / Total_N;
            end if;
            if Sum_Denominator > 0.0 then
               Parameters.Pooled_S :=
                 Sqrt (Sum_Numerator / Sum_Denominator);
            end if;

         when Tool_Call_Failure_Rate
            | Fraction_Tool_Call_Turns
            | Fraction_Thinking_Turns =>
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
            | Session_Cache_Write_Tokens_EWMA =>
            if Total_N > 0.0 then
               Parameters.Grand_Mean := Total_Weighted_Mean / Total_N;
            end if;
            if MR_Count > 0 then
               Parameters.Mean_MR := MR_Sum / Long_Float (MR_Count);
            end if;

      end case;
   end Estimate_Parameters;

end Coyote_SQC.Statistics;
