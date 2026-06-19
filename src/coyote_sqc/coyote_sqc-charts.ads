--  Coyote_SQC.Charts — chart kind enumeration and display metadata.
--
--  Project: coyote

with Ada.Strings.Unbounded;

package Coyote_SQC.Charts is

   --  The ninety-one charts available in every workspace.
   --  order matches the left-panel display order.
   type Chart_Kind is
     (Turn_Tokens_Xbar,
      Turn_Tokens_S,
      Tool_Call_Tokens_Xbar,
      Tool_Call_Tokens_S,
      Thinking_Tokens_Xbar,
      Thinking_Tokens_S,
      Tool_Call_Failure_Rate,
      Fraction_Tool_Call_Turns,
      Fraction_Thinking_Turns,
      Fraction_Thinking_Tokens_I,
      Fraction_Thinking_Tokens_MR,
      Fraction_Thinking_Tokens_EWMA,
      Fraction_Tool_Call_Tokens_I,
      Fraction_Tool_Call_Tokens_MR,
      Fraction_Tool_Call_Tokens_EWMA,
      Session_Input_Tokens_I,
      Session_Input_Tokens_MR,
      Session_Output_Tokens_I,
      Session_Output_Tokens_MR,
      Session_Cache_Read_Tokens_I,
      Session_Cache_Read_Tokens_MR,
      Session_Cache_Write_Tokens_I,
      Session_Cache_Write_Tokens_MR,
      Session_Thinking_Tokens_I,
      Session_Thinking_Tokens_MR,
      Session_Tool_Call_Tokens_I,
      Session_Tool_Call_Tokens_MR,
      Session_Tool_Call_Result_Tokens_I,
      Session_Tool_Call_Result_Tokens_MR,
      Session_Input_Tokens_EWMA,
      Session_Output_Tokens_EWMA,
      Session_Cache_Read_Tokens_EWMA,
      Session_Cache_Write_Tokens_EWMA,
      Session_Thinking_Tokens_EWMA,
      Session_Tool_Call_Tokens_EWMA,
      Session_Tool_Call_Result_Tokens_EWMA,
      --  Session Turn Count I/MR/EWMA charts:
      Session_Turn_Count_I,
      Session_Turn_Count_MR,
      Session_Turn_Count_EWMA,
      --  Uncached session input token I/MR/EWMA charts:
      Session_Uncached_Input_Tokens_I,
      Session_Uncached_Input_Tokens_MR,
      Session_Uncached_Input_Tokens_EWMA,
      --  Thinking tokens per tool-call token I/MR/EWMA rate charts:
      Fraction_Thinking_Per_Tool_Call_I,
      Fraction_Thinking_Per_Tool_Call_MR,
      Fraction_Thinking_Per_Tool_Call_EWMA,
      --  Uncached input tokens per total input token I/MR/EWMA rate charts:
      Fraction_Uncached_Input_I,
      Fraction_Uncached_Input_MR,
      Fraction_Uncached_Input_EWMA,
      --  Tool call consecutive diversity charts (Xbar/s):
      Tool_Call_JSD_Xbar,
      Tool_Call_JSD_S,
      --  Session-level I/MR/EWMA charts for total consecutive tool-call
      --  similarity per session (sum of all Per_Consecutive_Tool_S values).
      Session_Tool_Call_JSD_Sum_I,
      Session_Tool_Call_JSD_Sum_MR,
      Session_Tool_Call_JSD_Sum_EWMA,
      --  Quantile Control Charts:
      Turn_Tokens_Quantile,
      Tool_Call_Tokens_Quantile,
      Thinking_Tokens_Quantile,
      Tool_Call_JSD_Quantile,
      Tool_Call_MI_Xbar,
      Tool_Call_MI_S,
      Session_Tool_Call_MI_Sum_I,
      Session_Tool_Call_MI_Sum_MR,
      Session_Tool_Call_MI_Sum_EWMA,
      Tool_Call_MI_Quantile,
   --  Token Cost Charts — Session-level I/MR/EWMA (6 categories × 3):
   Session_Total_Cost_I,
   Session_Total_Cost_MR,
   Session_Total_Cost_EWMA,
   Session_Input_Cost_I,
   Session_Input_Cost_MR,
   Session_Input_Cost_EWMA,
   Session_Output_Cost_I,
   Session_Output_Cost_MR,
   Session_Output_Cost_EWMA,
   Session_Cache_Read_Cost_I,
   Session_Cache_Read_Cost_MR,
   Session_Cache_Read_Cost_EWMA,
   Session_Cache_Write_Cost_I,
   Session_Cache_Write_Cost_MR,
   Session_Cache_Write_Cost_EWMA,
   Session_Uncached_Input_Cost_I,
   Session_Uncached_Input_Cost_MR,
   Session_Uncached_Input_Cost_EWMA,
   --  Token Cost Charts — Turn-level Xbar/s (6 categories × 2):
   Turn_Total_Cost_Xbar,
   Turn_Total_Cost_S,
   Turn_Input_Cost_Xbar,
   Turn_Input_Cost_S,
   Turn_Output_Cost_Xbar,
   Turn_Output_Cost_S,
   Turn_Cache_Read_Cost_Xbar,
   Turn_Cache_Read_Cost_S,
   Turn_Cache_Write_Cost_Xbar,
   Turn_Cache_Write_Cost_S,
   Turn_Uncached_Input_Cost_Xbar,
   Turn_Uncached_Input_Cost_S);

   --  Display metadata for one chart.
   type Chart_Properties is record
      Label        : Ada.Strings.Unbounded.Unbounded_String;
      Group_Path        : Ada.Strings.Unbounded.Unbounded_String;
      Y_Axis_Label : Ada.Strings.Unbounded.Unbounded_String;
      Is_P_Chart   : Boolean;
      Is_I_Chart      : Boolean;
      Is_MR_Chart     : Boolean;
      Is_Xbar_S_Chart : Boolean;
      Is_EWMA_Chart   : Boolean;
      Is_S_Chart      : Boolean;  --  True for s charts (stays in z-space when Box-Cox active)
      Is_Quantile_CC_Chart : Boolean;
   end record;

   --  Return the display properties for Kind.
   function Properties (Kind : Chart_Kind) return Chart_Properties;

end Coyote_SQC.Charts;
