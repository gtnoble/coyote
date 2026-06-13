--  Coyote_SQC.Charts body.
--
--  Project: coyote

package body Coyote_SQC.Charts is

   use Ada.Strings.Unbounded;

   function U (S : String) return Unbounded_String
     renames Ada.Strings.Unbounded.To_Unbounded_String;

   function Properties (Kind : Chart_Kind) return Chart_Properties is
   begin
      case Kind is
         when Turn_Tokens_Xbar =>
            return
              (Label           => U ("Turn Tokens -- Xbar"),
               Group_Path      => U ("Token Consumption/Turn Tokens"),
               Y_Axis_Label    => U ("Mean output tokens/turn"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => True,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Turn_Tokens_S =>
            return
              (Label           => U ("Turn Tokens -- s"),
               Group_Path      => U ("Token Consumption/Turn Tokens"),
               Y_Axis_Label    => U ("Std dev output tokens/turn"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => True,
               Is_S_Chart      => True,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Tool_Call_Tokens_Xbar =>
            return
              (Label           => U ("Tool Call Tokens -- Xbar"),
               Group_Path      => U ("Token Consumption/Tool Call Tokens"),
               Y_Axis_Label    => U ("Mean output tokens/tool-call turn"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => True,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Tool_Call_Tokens_S =>
            return
              (Label           => U ("Tool Call Tokens -- s"),
               Group_Path      => U ("Token Consumption/Tool Call Tokens"),
               Y_Axis_Label    => U ("Std dev output tokens/tool-call turn"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => True,
               Is_S_Chart      => True,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Thinking_Tokens_Xbar =>
            return
              (Label           => U ("Thinking Tokens -- Xbar"),
               Group_Path      => U ("Token Consumption/Thinking Tokens"),
               Y_Axis_Label    => U ("Mean thinking tokens/turn"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => True,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Thinking_Tokens_S =>
            return
              (Label           => U ("Thinking Tokens -- s"),
               Group_Path      => U ("Token Consumption/Thinking Tokens"),
               Y_Axis_Label    => U ("Std dev thinking tokens/turn"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => True,
               Is_S_Chart      => True,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Tool_Call_Failure_Rate =>
            return
              (Label           => U ("Tool Call Failure Rate"),
               Group_Path      => U ("Rates/Tool Call Failure Rate"),
               Y_Axis_Label    => U ("Failure proportion"),
               Is_P_Chart      => True,
               Is_I_Chart      => False,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Fraction_Tool_Call_Turns =>
            return
              (Label           => U ("Fraction: Tool-Call Turns"),
               Group_Path      => U ("Rates/Tool-Call Turns"),
               Y_Axis_Label    => U ("Fraction of turns"),
               Is_P_Chart      => True,
               Is_I_Chart      => False,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Fraction_Thinking_Turns =>
            return
              (Label           => U ("Fraction: Thinking Turns"),
               Group_Path      => U ("Rates/Thinking Turns"),
               Y_Axis_Label    => U ("Fraction of turns"),
               Is_P_Chart      => True,
               Is_I_Chart      => False,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Fraction_Thinking_Tokens_I =>
            return
              (Label           => U ("Fraction: Thinking Tokens -- I"),
               Group_Path      => U ("Rates/Thinking Tokens"),
               Y_Axis_Label    => U ("Thinking tokens / output tokens"),
               Is_P_Chart      => False,
               Is_I_Chart      => True,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Fraction_Thinking_Tokens_MR =>
            return
              (Label           => U ("Fraction: Thinking Tokens -- MR"),
               Group_Path      => U ("Rates/Thinking Tokens"),
               Y_Axis_Label    => U ("MR (thinking / output tokens)"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => True,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Fraction_Thinking_Tokens_EWMA =>
            return
              (Label           => U ("Fraction: Thinking Tokens -- EWMA"),
               Group_Path      => U ("Rates/Thinking Tokens"),
               Y_Axis_Label    => U ("EWMA (thinking / output tokens)"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => True,
               Is_Quantile_CC_Chart => False);
         when Fraction_Tool_Call_Tokens_I =>
            return
              (Label           => U ("Fraction: Tool-Call Tokens -- I"),
               Group_Path      => U ("Rates/Tool-Call Tokens"),
               Y_Axis_Label    => U ("Tool-call tokens / output tokens"),
               Is_P_Chart      => False,
               Is_I_Chart      => True,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Fraction_Tool_Call_Tokens_MR =>
            return
              (Label           => U ("Fraction: Tool-Call Tokens -- MR"),
               Group_Path      => U ("Rates/Tool-Call Tokens"),
               Y_Axis_Label    => U ("MR (tool-call / output tokens)"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => True,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Fraction_Tool_Call_Tokens_EWMA =>
            return
              (Label           => U ("Fraction: Tool-Call Tokens -- EWMA"),
               Group_Path      => U ("Rates/Tool-Call Tokens"),
               Y_Axis_Label    => U ("EWMA (tool-call / output tokens)"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => True,
               Is_Quantile_CC_Chart => False);
         when Session_Input_Tokens_I =>
            return
              (Label           => U ("Session Input Tokens -- I"),
               Group_Path      => U ("Session Totals/Input Tokens"),
               Y_Axis_Label    => U ("Total input tokens"),
               Is_P_Chart      => False,
               Is_I_Chart      => True,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Session_Input_Tokens_MR =>
            return
              (Label           => U ("Session Input Tokens -- MR"),
               Group_Path      => U ("Session Totals/Input Tokens"),
               Y_Axis_Label    => U ("Moving range (input tokens)"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => True,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Session_Output_Tokens_I =>
            return
              (Label           => U ("Session Output Tokens -- I"),
               Group_Path      => U ("Session Totals/Output Tokens"),
               Y_Axis_Label    => U ("Total output tokens"),
               Is_P_Chart      => False,
               Is_I_Chart      => True,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Session_Output_Tokens_MR =>
            return
              (Label           => U ("Session Output Tokens -- MR"),
               Group_Path      => U ("Session Totals/Output Tokens"),
               Y_Axis_Label    => U ("Moving range (output tokens)"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => True,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Session_Cache_Read_Tokens_I =>
            return
              (Label           => U ("Session Cache Read Tokens -- I"),
               Group_Path      => U ("Session Totals/Cache Read Tokens"),
               Y_Axis_Label    => U ("Total cache-read tokens"),
               Is_P_Chart      => False,
               Is_I_Chart      => True,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Session_Cache_Read_Tokens_MR =>
            return
              (Label           => U ("Session Cache Read Tokens -- MR"),
               Group_Path      => U ("Session Totals/Cache Read Tokens"),
               Y_Axis_Label    => U ("Moving range (cache-read tokens)"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => True,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Session_Cache_Write_Tokens_I =>
            return
              (Label           => U ("Session Cache Write Tokens -- I"),
               Group_Path      => U ("Session Totals/Cache Write Tokens"),
               Y_Axis_Label    => U ("Total cache-write tokens"),
               Is_P_Chart      => False,
               Is_I_Chart      => True,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Session_Cache_Write_Tokens_MR =>
            return
              (Label           => U ("Session Cache Write Tokens -- MR"),
               Group_Path      => U ("Session Totals/Cache Write Tokens"),
               Y_Axis_Label    => U ("Moving range (cache-write tokens)"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => True,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Session_Thinking_Tokens_I =>
            return
              (Label           => U ("Session Thinking Tokens -- I"),
               Group_Path      => U ("Session Totals/Thinking Tokens"),
               Y_Axis_Label    => U ("Total thinking tokens"),
               Is_P_Chart      => False,
               Is_I_Chart      => True,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Session_Thinking_Tokens_MR =>
            return
              (Label           => U ("Session Thinking Tokens -- MR"),
               Group_Path      => U ("Session Totals/Thinking Tokens"),
               Y_Axis_Label    => U ("Moving range (thinking tokens)"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => True,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Session_Tool_Call_Tokens_I =>
            return
              (Label           => U ("Session Tool-Call Tokens -- I"),
               Group_Path      => U ("Session Totals/Tool-Call Tokens"),
               Y_Axis_Label    => U ("Total tool-call input tokens"),
               Is_P_Chart      => False,
               Is_I_Chart      => True,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Session_Tool_Call_Tokens_MR =>
            return
              (Label           => U ("Session Tool-Call Tokens -- MR"),
               Group_Path      => U ("Session Totals/Tool-Call Tokens"),
               Y_Axis_Label    => U ("Moving range (tool-call input tokens)"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => True,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Session_Tool_Call_Result_Tokens_I =>
            return
              (Label           => U ("Session Tool-Call Result Tokens -- I"),
               Group_Path      => U ("Session Totals/Tool-Call Result Tokens"),
               Y_Axis_Label    => U ("Total tool-call result tokens"),
               Is_P_Chart      => False,
               Is_I_Chart      => True,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Session_Tool_Call_Result_Tokens_MR =>
            return
              (Label           => U ("Session Tool-Call Result Tokens -- MR"),
               Group_Path      => U ("Session Totals/Tool-Call Result Tokens"),
               Y_Axis_Label    => U ("Moving range (tool-call result tokens)"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => True,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Session_Input_Tokens_EWMA =>
            return
              (Label           => U ("Session Input Tokens -- EWMA"),
               Group_Path      => U ("Session Totals/Input Tokens"),
               Y_Axis_Label    => U ("EWMA (input tokens)"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => True,
               Is_Quantile_CC_Chart => False);
         when Session_Output_Tokens_EWMA =>
            return
              (Label           => U ("Session Output Tokens -- EWMA"),
               Group_Path      => U ("Session Totals/Output Tokens"),
               Y_Axis_Label    => U ("EWMA (output tokens)"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => True,
               Is_Quantile_CC_Chart => False);
         when Session_Cache_Read_Tokens_EWMA =>
            return
              (Label           => U ("Session Cache Read Tokens -- EWMA"),
               Group_Path      => U ("Session Totals/Cache Read Tokens"),
               Y_Axis_Label    => U ("EWMA (cache-read tokens)"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => True,
               Is_Quantile_CC_Chart => False);
         when Session_Cache_Write_Tokens_EWMA =>
            return
              (Label           => U ("Session Cache Write Tokens -- EWMA"),
               Group_Path      => U ("Session Totals/Cache Write Tokens"),
               Y_Axis_Label    => U ("EWMA (cache-write tokens)"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => True,
               Is_Quantile_CC_Chart => False);
         when Session_Thinking_Tokens_EWMA =>
            return
              (Label           => U ("Session Thinking Tokens -- EWMA"),
               Group_Path      => U ("Session Totals/Thinking Tokens"),
               Y_Axis_Label    => U ("EWMA (thinking tokens)"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => True,
               Is_Quantile_CC_Chart => False);
         when Session_Tool_Call_Tokens_EWMA =>
            return
              (Label           => U ("Session Tool-Call Tokens -- EWMA"),
               Group_Path      => U ("Session Totals/Tool-Call Tokens"),
               Y_Axis_Label    => U ("EWMA (tool-call input tokens)"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => True,
               Is_Quantile_CC_Chart => False);
         when Session_Tool_Call_Result_Tokens_EWMA =>
            return
              (Label           => U ("Session Tool-Call Result Tokens -- EWMA"),
               Group_Path      => U ("Session Totals/Tool-Call Result Tokens"),
               Y_Axis_Label    => U ("EWMA (tool-call result tokens)"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => True,
               Is_Quantile_CC_Chart => False);
         when Session_Turn_Count_I =>
            return
              (Label           => U ("Session Turn Count -- I"),
               Group_Path      => U ("Session Totals/Turn Count"),
               Y_Axis_Label    => U ("Turn count"),
               Is_P_Chart      => False,
               Is_I_Chart      => True,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Session_Turn_Count_MR =>
            return
              (Label           => U ("Session Turn Count -- MR"),
               Group_Path      => U ("Session Totals/Turn Count"),
               Y_Axis_Label    => U ("Moving range (turn count)"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => True,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Session_Turn_Count_EWMA =>
            return
              (Label           => U ("Session Turn Count -- EWMA"),
               Group_Path      => U ("Session Totals/Turn Count"),
               Y_Axis_Label    => U ("EWMA (turn count)"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => True,
               Is_Quantile_CC_Chart => False);
         when Session_Uncached_Input_Tokens_I =>
            return
              (Label           => U ("Session Uncached Input Tokens -- I"),
               Group_Path      => U ("Session Totals/Uncached Input Tokens"),
               Y_Axis_Label    => U ("Total uncached input tokens"),
               Is_P_Chart      => False,
               Is_I_Chart      => True,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Session_Uncached_Input_Tokens_MR =>
            return
              (Label           => U ("Session Uncached Input Tokens -- MR"),
               Group_Path      => U ("Session Totals/Uncached Input Tokens"),
               Y_Axis_Label    => U ("Moving range (uncached input tokens)"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => True,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Session_Uncached_Input_Tokens_EWMA =>
            return
              (Label           => U ("Session Uncached Input Tokens -- EWMA"),
               Group_Path      => U ("Session Totals/Uncached Input Tokens"),
               Y_Axis_Label    => U ("EWMA (uncached input tokens)"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => True,
               Is_Quantile_CC_Chart => False);
         when Fraction_Thinking_Per_Tool_Call_I =>
            return
              (Label           => U ("Fraction: Thinking/Tool-Call Tokens -- I"),
               Group_Path      => U ("Rates/Thinking per Tool-Call"),
               Y_Axis_Label    => U ("Thinking tokens / tool-call tokens"),
               Is_P_Chart      => False,
               Is_I_Chart      => True,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Fraction_Thinking_Per_Tool_Call_MR =>
            return
              (Label           => U ("Fraction: Thinking/Tool-Call Tokens -- MR"),
               Group_Path      => U ("Rates/Thinking per Tool-Call"),
               Y_Axis_Label    => U ("MR (thinking / tool-call tokens)"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => True,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Fraction_Thinking_Per_Tool_Call_EWMA =>
            return
              (Label           => U ("Fraction: Thinking/Tool-Call Tokens -- EWMA"),
               Group_Path      => U ("Rates/Thinking per Tool-Call"),
               Y_Axis_Label    => U ("EWMA (thinking / tool-call tokens)"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => True,
               Is_Quantile_CC_Chart => False);
         when Fraction_Uncached_Input_I =>
            return
              (Label           => U ("Fraction: Uncached/Total Input -- I"),
               Group_Path      => U ("Rates/Uncached Input"),
               Y_Axis_Label    => U ("Uncached input tokens / input tokens"),
               Is_P_Chart      => False,
               Is_I_Chart      => True,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Fraction_Uncached_Input_MR =>
            return
              (Label           => U ("Fraction: Uncached/Total Input -- MR"),
               Group_Path      => U ("Rates/Uncached Input"),
               Y_Axis_Label    => U ("MR (uncached / input tokens)"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => True,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Fraction_Uncached_Input_EWMA =>
            return
              (Label           => U ("Fraction: Uncached/Total Input -- EWMA"),
               Group_Path      => U ("Rates/Uncached Input"),
               Y_Axis_Label    => U ("EWMA (uncached / input tokens)"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => True,
               Is_Quantile_CC_Chart => False);
         when Tool_Call_JSD_Xbar =>
            return
              (Label           => U ("Consecutive Tool Diversity -- Xbar"),
               Group_Path      => U ("Tool Call Behavior/Consecutive Diversity"),
               Y_Axis_Label    => U ("Mean consecutive tool-call similarity"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => True,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Tool_Call_JSD_S =>
            return
              (Label           => U ("Consecutive Tool Diversity -- s"),
               Group_Path      => U ("Tool Call Behavior/Consecutive Diversity"),
               Y_Axis_Label    => U ("Std dev consecutive tool-call similarity"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => True,
               Is_S_Chart      => True,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Session_Tool_Call_JSD_Sum_I =>
            return
              (Label           => U ("Consecutive Tool Diversity Sum -- I"),
               Group_Path      => U ("Tool Call Behavior/Consecutive Diversity"),
               Y_Axis_Label    => U ("Sum of tool-call similarity scores"),
               Is_P_Chart      => False,
               Is_I_Chart      => True,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Session_Tool_Call_JSD_Sum_MR =>
            return
              (Label           => U ("Consecutive Tool Diversity Sum -- MR"),
               Group_Path      => U ("Tool Call Behavior/Consecutive Diversity"),
               Y_Axis_Label    => U ("MR (sum of tool-call similarity scores)"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => True,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => False);
         when Session_Tool_Call_JSD_Sum_EWMA =>
            return
              (Label           => U ("Consecutive Tool Diversity Sum -- EWMA"),
               Group_Path      => U ("Tool Call Behavior/Consecutive Diversity"),
               Y_Axis_Label    => U ("EWMA (sum of tool-call similarity scores)"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => True,
               Is_Quantile_CC_Chart => False);
         when Turn_Tokens_Quantile =>
            return
              (Label           => U ("Turn Tokens Quantile"),
               Group_Path      => U ("Quantile Profiles/Quantile Profiles"),
               Y_Axis_Label    => U ("Quantile (output tokens/turn)"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => True);
         when Tool_Call_Tokens_Quantile =>
            return
              (Label           => U ("Tool Call Tokens Quantile"),
               Group_Path      => U ("Quantile Profiles/Quantile Profiles"),
               Y_Axis_Label    => U ("Quantile (tool-call tokens/turn)"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => True);
         when Thinking_Tokens_Quantile =>
            return
              (Label           => U ("Thinking Tokens Quantile"),
               Group_Path      => U ("Quantile Profiles/Quantile Profiles"),
               Y_Axis_Label    => U ("Quantile (thinking tokens/turn)"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => True);
         when Tool_Call_JSD_Quantile =>
            return
              (Label           => U ("Tool Call JSD Quantile"),
               Group_Path      => U ("Quantile Profiles/Quantile Profiles"),
               Y_Axis_Label    => U ("Quantile (JSD similarity)"),
               Is_P_Chart      => False,
               Is_I_Chart      => False,
               Is_MR_Chart     => False,
               Is_Xbar_S_Chart => False,
               Is_S_Chart      => False,
               Is_EWMA_Chart   => False,
               Is_Quantile_CC_Chart => True);
      end case;
   end Properties;

end Coyote_SQC.Charts;
