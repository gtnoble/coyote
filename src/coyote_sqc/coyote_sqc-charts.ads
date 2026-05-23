--  Coyote_SQC.Charts — chart kind enumeration and display metadata.
--
--  Project: coyote

with Ada.Strings.Unbounded;

package Coyote_SQC.Charts is

   --  The thirteen charts available in every workspace.  The declaration
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
      Session_Input_Tokens_I,
      Session_Input_Tokens_MR,
      Session_Output_Tokens_I,
      Session_Output_Tokens_MR);

   --  Display metadata for one chart.
   type Chart_Properties is record
      Label        : Ada.Strings.Unbounded.Unbounded_String;
      Group        : Ada.Strings.Unbounded.Unbounded_String;
      Y_Axis_Label : Ada.Strings.Unbounded.Unbounded_String;
      Is_P_Chart   : Boolean;
      Is_I_Chart   : Boolean;
   end record;

   --  Return the display properties for Kind.
   function Properties (Kind : Chart_Kind) return Chart_Properties;

end Coyote_SQC.Charts;
