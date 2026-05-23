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
               Is_P_Chart   => False);
         when Turn_Tokens_S =>
            return
              (Label        => U ("Turn Tokens -- s"),
               Group        => U ("Token Consumption"),
               Y_Axis_Label => U ("Std dev output tokens/turn"),
               Is_P_Chart   => False);
         when Tool_Call_Tokens_Xbar =>
            return
              (Label        => U ("Tool Call Tokens -- Xbar"),
               Group        => U ("Token Consumption"),
               Y_Axis_Label => U ("Mean tool-call tokens/turn"),
               Is_P_Chart   => False);
         when Tool_Call_Tokens_S =>
            return
              (Label        => U ("Tool Call Tokens -- s"),
               Group        => U ("Token Consumption"),
               Y_Axis_Label => U ("Std dev tool-call tokens/turn"),
               Is_P_Chart   => False);
         when Thinking_Tokens_Xbar =>
            return
              (Label        => U ("Thinking Tokens -- Xbar"),
               Group        => U ("Token Consumption"),
               Y_Axis_Label => U ("Mean thinking tokens/turn"),
               Is_P_Chart   => False);
         when Thinking_Tokens_S =>
            return
              (Label        => U ("Thinking Tokens -- s"),
               Group        => U ("Token Consumption"),
               Y_Axis_Label => U ("Std dev thinking tokens/turn"),
               Is_P_Chart   => False);
         when Tool_Call_Failure_Rate =>
            return
              (Label        => U ("Tool Call Failure Rate"),
               Group        => U ("Rates"),
               Y_Axis_Label => U ("Failure proportion"),
               Is_P_Chart   => True);
         when Fraction_Tool_Call_Turns =>
            return
              (Label        => U ("Fraction: Tool-Call Turns"),
               Group        => U ("Rates"),
               Y_Axis_Label => U ("Fraction of turns"),
               Is_P_Chart   => True);
         when Fraction_Thinking_Turns =>
            return
              (Label        => U ("Fraction: Thinking Turns"),
               Group        => U ("Rates"),
               Y_Axis_Label => U ("Fraction of turns"),
               Is_P_Chart   => True);
      end case;
   end Properties;

end Coyote_SQC.Charts;
