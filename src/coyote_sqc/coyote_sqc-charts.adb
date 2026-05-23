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
              (Label        => U ("Turn Tokens -- Xbar"),
               Group        => U ("Token Consumption"),
               Y_Axis_Label => U ("Mean output tokens/turn"),
               Is_P_Chart   => False,
               Is_I_Chart   => False);
         when Turn_Tokens_S =>
            return
              (Label        => U ("Turn Tokens -- s"),
               Group        => U ("Token Consumption"),
               Y_Axis_Label => U ("Std dev output tokens/turn"),
               Is_P_Chart   => False,
               Is_I_Chart   => False);
         when Tool_Call_Tokens_Xbar =>
            return
              (Label        => U ("Tool Call Tokens -- Xbar"),
               Group        => U ("Token Consumption"),
               Y_Axis_Label => U ("Mean output tokens/tool-call turn"),
               Is_P_Chart   => False,
               Is_I_Chart   => False);
         when Tool_Call_Tokens_S =>
            return
              (Label        => U ("Tool Call Tokens -- s"),
               Group        => U ("Token Consumption"),
               Y_Axis_Label => U ("Std dev output tokens/tool-call turn"),
               Is_P_Chart   => False,
               Is_I_Chart   => False);
         when Thinking_Tokens_Xbar =>
            return
              (Label        => U ("Thinking Tokens -- Xbar"),
               Group        => U ("Token Consumption"),
               Y_Axis_Label => U ("Mean thinking tokens/turn"),
               Is_P_Chart   => False,
               Is_I_Chart   => False);
         when Thinking_Tokens_S =>
            return
              (Label        => U ("Thinking Tokens -- s"),
               Group        => U ("Token Consumption"),
               Y_Axis_Label => U ("Std dev thinking tokens/turn"),
               Is_P_Chart   => False,
               Is_I_Chart   => False);
         when Tool_Call_Failure_Rate =>
            return
              (Label        => U ("Tool Call Failure Rate"),
               Group        => U ("Rates"),
               Y_Axis_Label => U ("Failure proportion"),
               Is_P_Chart   => True,
               Is_I_Chart   => False);
         when Fraction_Tool_Call_Turns =>
            return
              (Label        => U ("Fraction: Tool-Call Turns"),
               Group        => U ("Rates"),
               Y_Axis_Label => U ("Fraction of turns"),
               Is_P_Chart   => True,
               Is_I_Chart   => False);
         when Fraction_Thinking_Turns =>
            return
              (Label        => U ("Fraction: Thinking Turns"),
               Group        => U ("Rates"),
               Y_Axis_Label => U ("Fraction of turns"),
               Is_P_Chart   => True,
               Is_I_Chart   => False);
         when Session_Input_Tokens_I =>
            return
              (Label        => U ("Session Input Tokens -- I"),
               Group        => U ("Session Totals"),
               Y_Axis_Label => U ("Total input tokens"),
               Is_P_Chart   => False,
               Is_I_Chart   => True);
         when Session_Input_Tokens_MR =>
            return
              (Label        => U ("Session Input Tokens -- MR"),
               Group        => U ("Session Totals"),
               Y_Axis_Label => U ("Moving range (input tokens)"),
               Is_P_Chart   => False,
               Is_I_Chart   => True);
         when Session_Output_Tokens_I =>
            return
              (Label        => U ("Session Output Tokens -- I"),
               Group        => U ("Session Totals"),
               Y_Axis_Label => U ("Total output tokens"),
               Is_P_Chart   => False,
               Is_I_Chart   => True);
         when Session_Output_Tokens_MR =>
            return
              (Label        => U ("Session Output Tokens -- MR"),
               Group        => U ("Session Totals"),
               Y_Axis_Label => U ("Moving range (output tokens)"),
               Is_P_Chart   => False,
               Is_I_Chart   => True);
      end case;
   end Properties;

end Coyote_SQC.Charts;
