with AUnit.Assertions;
with Coyote_App.Utils;
with AUnit.Test_Caller;

package body Collapse_Utils_Tests is

   procedure Test_Collapse_Basic (T : in out Test) is
      pragma Unreferenced (T);
      --  Simulate OpenAI-style tokens with LF between them.
      --  The collapse function should convert single LFs to spaces
      --  and strip leading/trailing LFs.
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
           (ASCII.LF & ASCII.HT & ASCII.LF) = "",
         "LF/HT-only should return empty");
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
      --  Spaces are content (word boundaries from Anthropic).
      --  Only LF/CR/HT are trimmed; spaces are preserved.
      Input  : constant String :=
        ASCII.LF & "  Hello  " & ASCII.LF & ASCII.LF;
      Result : constant String :=
        Coyote_App.Utils.Collapse_Thinking_Delta (Input);
   begin
      AUnit.Assertions.Assert
        (Result = "  Hello  ",
         "Expected LFs trimmed but internal and leading/trailing spaces preserved");
   end Test_Collapse_Leading_Trailing_WS;

   procedure Test_Collapse_Preserves_Spaces (T : in out Test) is
      pragma Unreferenced (T);
      --  Anthropic-style deltas: leading space carries word-boundary info.
      Result : constant String :=
        Coyote_App.Utils.Collapse_Thinking_Delta (" the");
   begin
      AUnit.Assertions.Assert
        (Result = " the",
         "Expected leading space to be preserved as word boundary");
   end Test_Collapse_Preserves_Spaces;

   procedure Test_Collapse_OpenAI_Style (T : in out Test) is
      pragma Unreferenced (T);
      --  OpenAI-style tokens: each has trailing LF.
      --  The collapse function should strip trailing LF and preserve text.
      Input  : constant String := "All" & ASCII.LF;
      Result : constant String :=
        Coyote_App.Utils.Collapse_Thinking_Delta (Input);
   begin
      AUnit.Assertions.Assert
        (Result = "All",
         "Expected trailing LF stripped, got '" & Result & "'");
   end Test_Collapse_OpenAI_Style;

   procedure Test_Collapse_OpenAI_Mid_Stream (T : in out Test) is
      pragma Unreferenced (T);
      --  OpenAI-style tokens concatenated: single LFs become spaces.
      Input  : constant String :=
        "first" & ASCII.LF & "second" & ASCII.LF & "third";
      Result : constant String :=
        Coyote_App.Utils.Collapse_Thinking_Delta (Input);
   begin
      AUnit.Assertions.Assert
        (Result = "first second third",
         "Expected single LFs collapsed to spaces, got '" & Result & "'");
   end Test_Collapse_OpenAI_Mid_Stream;

   package Collapse_Utils_Caller is
     new AUnit.Test_Caller (Collapse_Utils_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Collapse_Utils_Caller.Create
        ("Collapse_Thinking_Delta: single-LF collapse to spaces",
         Collapse_Utils_Tests.Test_Collapse_Basic'Access));
      Result.Add_Test (Collapse_Utils_Caller.Create
        ("Collapse_Thinking_Delta: paragraph breaks (LF LF) preserved",
         Collapse_Utils_Tests.Test_Collapse_Paragraph'Access));
      Result.Add_Test (Collapse_Utils_Caller.Create
        ("Collapse_Thinking_Delta: empty input returns empty string",
         Collapse_Utils_Tests.Test_Collapse_Empty'Access));
      Result.Add_Test (Collapse_Utils_Caller.Create
        ("Collapse_Thinking_Delta: no-LF input returned verbatim",
         Collapse_Utils_Tests.Test_Collapse_NoLF'Access));
      Result.Add_Test (Collapse_Utils_Caller.Create
        ("Collapse_Thinking_Delta: leading/trailing whitespace stripped",
         Collapse_Utils_Tests.Test_Collapse_Leading_Trailing_WS'Access));
      Result.Add_Test (Collapse_Utils_Caller.Create
        ("Collapse_Thinking_Delta: spaces preserved as word boundaries",
         Collapse_Utils_Tests.Test_Collapse_Preserves_Spaces'Access));
      Result.Add_Test (Collapse_Utils_Caller.Create
        ("Collapse_Thinking_Delta: OpenAI-style trailing LF stripped",
         Collapse_Utils_Tests.Test_Collapse_OpenAI_Style'Access));
      Result.Add_Test (Collapse_Utils_Caller.Create
        ("Collapse_Thinking_Delta: OpenAI mid-stream LFs become spaces",
         Collapse_Utils_Tests.Test_Collapse_OpenAI_Mid_Stream'Access));

      return Result;
   end Suite;

end Collapse_Utils_Tests;
