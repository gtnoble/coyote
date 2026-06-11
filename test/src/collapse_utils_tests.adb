with AUnit.Assertions;
with Coyote_App.Utils;

package body Collapse_Utils_Tests is

   procedure Test_Collapse_Basic (T : in out Test) is
      pragma Unreferenced (T);
      --  Simulate tokens with LF between them
      Input  : constant String :=
        "The" & ASCII.LF & "user" & ASCII.LF & "wants me" & ASCII.LF;
      Result : constant String :=
        Coyote_App.Utils.Collapse_Thinking_Delta (Input);
   begin
      AUnit.Assertions.Assert
        (Result = "The user wants me",
         "Expected 'The user wants me' but got '" & Result & "'");
   end Test_Collapse_Basic;

   procedure Test_Collapse_Paragraph (T : in out Test) is
      pragma Unreferenced (T);
      Input  : constant String :=
        "Para one." & ASCII.LF & ASCII.LF & "Para two." & ASCII.LF;
      Result : constant String :=
        Coyote_App.Utils.Collapse_Thinking_Delta (Input);
   begin
      AUnit.Assertions.Assert
        (Result = "Para one." & ASCII.LF & ASCII.LF & "Para two.",
         "Expected paragraph break preserved, got '" & Result & "'");
   end Test_Collapse_Paragraph;

   procedure Test_Collapse_Empty (T : in out Test) is
      pragma Unreferenced (T);
   begin
      AUnit.Assertions.Assert
        (Coyote_App.Utils.Collapse_Thinking_Delta ("") = "",
         "Empty input should return empty");
      AUnit.Assertions.Assert
        (Coyote_App.Utils.Collapse_Thinking_Delta
           ("  " & ASCII.LF & " ") = "",
         "Whitespace-only should return empty");
   end Test_Collapse_Empty;

   procedure Test_Collapse_NoLF (T : in out Test) is
      pragma Unreferenced (T);
      Input  : constant String := "Hello world";
      Result : constant String :=
        Coyote_App.Utils.Collapse_Thinking_Delta (Input);
   begin
      AUnit.Assertions.Assert
        (Result = "Hello world",
         "Input with no newlines should be unchanged");
   end Test_Collapse_NoLF;

   procedure Test_Collapse_Leading_Trailing_WS (T : in out Test) is
      pragma Unreferenced (T);
      Input  : constant String :=
        ASCII.LF & "  Hello  " & ASCII.LF & ASCII.LF;
      Result : constant String :=
        Coyote_App.Utils.Collapse_Thinking_Delta (Input);
   begin
      AUnit.Assertions.Assert
        (Result = "Hello",
         "Expected leading, trailing, and interior whitespace trimmed");
   end Test_Collapse_Leading_Trailing_WS;

end Collapse_Utils_Tests;
