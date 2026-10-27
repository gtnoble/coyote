with Ada.Command_Line;
with Ada.Text_IO;
with Ada.Strings.Unbounded;
with Math_Source;
with Math_Tokens;

procedure Math_Tokens_Probe is
   use type Math_Source.Diagnostic_Kind;
   use type Math_Tokens.Diagnostic_Kind;
   use type Math_Tokens.Token_Kind;
   use type Math_Tokens.Token;
   use type Ada.Strings.Unbounded.Unbounded_String;
   Checks : Natural := 0;
   Failures : Natural := 0;
   procedure Check (Condition : Boolean; Label : String) is
   begin
      Checks := Checks + 1;
      if Condition then
         Ada.Text_IO.Put_Line ("ok " & Label);
      else
         Failures := Failures + 1;
         Ada.Text_IO.Put_Line ("FAIL " & Label);
      end if;
   end Check;
   procedure Run is
      Input : Math_Source.Source;
      Tokens : Math_Tokens.Stream;
      Diagnostic : Math_Source.Diagnostic_Kind;
      Token_Diagnostic : Math_Tokens.Diagnostic_Kind;
      Error_Byte : Natural;
      String_Source : String (8 .. 15) := "\alpha x";
   begin
      Math_Source.Create ("a" & Character'Val (16#C3#) &
        Character'Val (16#A9#) & "😀", Input, Diagnostic, Error_Byte);
      Check (Diagnostic = Math_Source.No_Error, "valid UTF-8 accepted");
      Check (Math_Source.Text (Input) = "aé😀", "exact source retained");
      Check (Math_Source.Scalar_Length (Input) = 3, "scalar count");
      Check (Math_Source.UTF16_Length (Input) = 4, "UTF-16 count with astral");
      Check (Math_Source.Byte_Offset (Input, 2) = 3, "original byte map");
      Check (Math_Source.UTF16_Offset (Input, 3) = 4, "JS offset map");
      Check (Math_Source.UTF16_Offset
        (Input, Math_Source.Scalar_Length (Input)) =
          Math_Source.UTF16_Length (Input), "final scalar UTF-16 mapping");
      Check (Math_Source.Byte_Offset
        (Input, Math_Source.Scalar_Length (Input)) =
          Math_Source.Byte_Length (Input), "final scalar byte mapping");
      Check (Math_Source.Scalar_Boundary (Input, 3) = 2,
        "reverse byte boundary mapping");
      Math_Tokens.Lex (Input, Tokens, Token_Diagnostic, Error_Byte);
      Check (Token_Diagnostic = Math_Tokens.No_Error and
        Math_Tokens.Element (Tokens, 2).Kind = Math_Tokens.Control_Word and
        Math_Tokens.Element (Tokens, 2).First_Byte = 1 and
        Math_Tokens.Element (Tokens, 2).After_Byte = 3 and
        Math_Tokens.Element (Tokens, 2).First_UTF16 = 1 and
        Math_Tokens.Element (Tokens, 2).After_UTF16 = 2 and
        Math_Tokens.Source (Tokens) = "aé😀",
        "precomposed accent expands while retaining original source span");
      Math_Source.Create ("x₂₊₁x²α̂", Input, Diagnostic, Error_Byte);
      Math_Tokens.Lex (Input, Tokens, Token_Diagnostic, Error_Byte);
      Check (Token_Diagnostic = Math_Tokens.No_Error,
        "subscripts superscripts and Greek accent lex");
      declare
         Found_Subscript : Boolean := False;
         Found_Superscript : Boolean := False;
         Subscript_Count : Natural := 0;
      begin
         for I in 1 .. Math_Tokens.Count (Tokens) loop
            declare
               Item : constant Math_Tokens.Token :=
                 Math_Tokens.Element (Tokens, I);
            begin
               if Item.Kind = Math_Tokens.Subscript then
                  Subscript_Count := Subscript_Count + 1;
                  Found_Subscript := Item.First_Byte = 1 and then
                    Item.After_Byte = 4;
               elsif Item.Kind = Math_Tokens.Superscript then
                  Found_Superscript := Item.First_Byte = 11 and then
                    Item.After_Byte = 13;
               end if;
            end;
         end loop;
         Check (Found_Subscript and Found_Superscript and
           Subscript_Count = 1,
           "contiguous Unicode scripts group and retain original spans");
      end;
      Check (Math_Tokens.Source (Tokens) = "x₂₊₁x²α̂" and
        Math_Tokens.Element (Tokens, Math_Tokens.Count (Tokens)).Kind =
          Math_Tokens.End_Of_Input,
        "mixed transformed input retains exact source and EOF");
      Math_Source.Create ("á̧", Input, Diagnostic, Error_Byte);
      Math_Tokens.Lex (Input, Tokens, Token_Diagnostic, Error_Byte);
      Check (Token_Diagnostic = Math_Tokens.No_Error and
        Math_Tokens.Element (Tokens, 1).Kind = Math_Tokens.Control_Word and
        Math_Tokens.Element (Tokens, 2).Kind = Math_Tokens.Control_Word and
        Math_Tokens.Element (Tokens, 2).First_Byte = 3 and
        Math_Tokens.Element (Tokens, 2).After_Byte = 5 and
        Math_Tokens.Element (Tokens, 3).Kind = Math_Tokens.Left_Group,
        "repeated combining accents wrap the previous generated group");
      Math_Source.Create ("́", Input, Diagnostic, Error_Byte);
      Math_Tokens.Lex (Input, Tokens, Token_Diagnostic, Error_Byte);
      Check (Token_Diagnostic = Math_Tokens.Unicode_Unsupported and
        Error_Byte = 0,
        "unsupported standalone combining mark fails at original byte");
      Math_Source.Create ("x", Input, Diagnostic, Error_Byte);
      Check (Math_Source.Text (Input) = "x", "re-create replaces ownership");
      Math_Source.Create ((1 .. Math_Source.Max_Source_Bytes + 1 => 'x'),
        Input, Diagnostic, Error_Byte);
      Check (Diagnostic = Math_Source.Source_Too_Large and
        Error_Byte = Math_Source.Max_Source_Bytes + 1 and
        Math_Source.Text (Input)'Length = 0,
        "source overflow rejected before ownership copy");
      Math_Source.Create ("", Input, Diagnostic, Error_Byte);
      Check (Diagnostic = Math_Source.Empty_Source and
        Math_Source.Text (Input)'Length = 0 and not Math_Source.Is_Valid (Input),
        "empty source rejected");
      Math_Source.Create (Character'Val (16#C0#) & Character'Val (16#AF#),
        Input, Diagnostic, Error_Byte);
      Check (Diagnostic = Math_Source.Invalid_UTF8, "overlong encoding rejected");
      Math_Source.Create (Character'Val (16#ED#) & Character'Val (16#A0#) &
        Character'Val (16#80#), Input, Diagnostic, Error_Byte);
      Check (Diagnostic = Math_Source.Invalid_UTF8, "surrogate encoding rejected");
      Math_Source.Create (Character'Val (16#F0#) & Character'Val (16#9F#),
        Input, Diagnostic, Error_Byte);
      Check (Diagnostic = Math_Source.Invalid_UTF8 and Error_Byte = 0,
        "truncated UTF-8 rejected at lead byte");
      Math_Source.Create (Character'Val (16#E0#) & Character'Val (16#80#) &
        Character'Val (16#80#), Input, Diagnostic, Error_Byte);
      Check (Diagnostic = Math_Source.Invalid_UTF8 and Error_Byte = 0,
        "overlong three-byte UTF-8 rejected at lead byte");
      Math_Source.Create (Character'Val (16#F4#) & Character'Val (16#90#) &
        Character'Val (16#80#) & Character'Val (16#80#), Input,
        Diagnostic, Error_Byte);
      Check (Diagnostic = Math_Source.Invalid_UTF8 and Error_Byte = 0,
        "out-of-range UTF-8 rejected at lead byte");
      Math_Source.Create ("a" & Character'Val (0) & "b", Input,
        Diagnostic, Error_Byte);
      Check (Diagnostic = Math_Source.Forbidden_Control and Error_Byte = 1,
        "NUL explicitly rejected");
      Math_Source.Create (String'(1 => Character'Val (1)), Input, Diagnostic, Error_Byte);
      Check (Diagnostic = Math_Source.Forbidden_Control,
        "C0 control rejected");
      Math_Source.Create (Character'Val (11) & "x", Input, Diagnostic,
        Error_Byte);
      Check (Diagnostic = Math_Source.Forbidden_Control and Error_Byte = 0,
        "vertical tab remains rejected");
      Math_Source.Create (Character'Val (12) & "x", Input, Diagnostic,
        Error_Byte);
      Check (Diagnostic = Math_Source.Forbidden_Control and Error_Byte = 0,
        "form feed remains rejected");
      Math_Source.Create (String_Source, Input, Diagnostic, Error_Byte);
      Check (Math_Source.Text (Input) = String_Source,
        "non-one-based string retained");
      Math_Tokens.Lex (Input, Tokens, Token_Diagnostic, Error_Byte);
      Check (Token_Diagnostic = Math_Tokens.No_Error,
        "non-one-based source lexes");
      Check (Math_Tokens.Element (Tokens, 1).Kind = Math_Tokens.Control_Word,
        "control word token");
      Check (Math_Tokens.Element (Tokens, 1).First_Byte = 0 and
        Math_Tokens.Element (Tokens, 1).After_Byte = 7 and
        Ada.Strings.Unbounded.To_String
          (Math_Tokens.Element (Tokens, 1).Lexeme) = "\alpha",
        "control word lexeme excludes consumed whitespace");
      Math_Source.Create (String'(8 .. 13 => 'x'), Input, Diagnostic,
        Error_Byte);
      Math_Tokens.Lex (Input, Tokens, Token_Diagnostic, Error_Byte);
      Check (Token_Diagnostic = Math_Tokens.No_Error and
        Math_Tokens.Element (Tokens, 1).Lexeme =
          Ada.Strings.Unbounded.To_Unbounded_String ("x") and
        Math_Tokens.Element (Tokens, 1).Text_First = 1 and
        Math_Tokens.Element (Tokens, 1).Text_Length = 1,
        "non-one-based lexeme copies exact byte slice");
      Math_Source.Create ("\foo@bar" & Character'Val (9) &
        Character'Val (10) & "  x", Input, Diagnostic, Error_Byte);
      Math_Tokens.Lex (Input, Tokens, Token_Diagnostic, Error_Byte);
      Check (Token_Diagnostic = Math_Tokens.No_Error and
        Math_Tokens.Element (Tokens, 1).Kind = Math_Tokens.Control_Word and
        Ada.Strings.Unbounded.To_String
          (Math_Tokens.Element (Tokens, 1).Lexeme) = "\foo@bar" and
        Math_Tokens.Element (Tokens, 1).After_Byte = 12 and
        Math_Tokens.Element (Tokens, 2).Code_Point = Character'Pos ('x'),
        "@ control word consumes all trailing regex whitespace");
      Math_Source.Create ("\ " & Character'Val (9) & Character'Val (10) &
        "  x", Input, Diagnostic, Error_Byte);
      Math_Tokens.Lex (Input, Tokens, Token_Diagnostic, Error_Byte);
      Check (Math_Tokens.Element (Tokens, 1).Kind =
        Math_Tokens.Control_Symbol and
        Math_Tokens.Element (Tokens, 1).Code_Point = 32 and
        Math_Tokens.Element (Tokens, 1).After_Byte = 6 and
        Math_Tokens.Element (Tokens, 2).Code_Point = Character'Pos ('x'),
        "backslash horizontal whitespace and newline is one space token");
      Math_Source.Create ("{}[]0123#^_&x%comment" & Character'Val (10) &
        "\%\ 😀", Input, Diagnostic, Error_Byte);
      Math_Tokens.Lex (Input, Tokens, Token_Diagnostic, Error_Byte);
      Check (Token_Diagnostic = Math_Tokens.No_Error, "lex mixed input");
      Check (Math_Tokens.Element (Tokens, 1).Kind = Math_Tokens.Left_Group and
        Math_Tokens.Element (Tokens, 2).Kind = Math_Tokens.Right_Group,
        "group tokens");
      Check (Math_Tokens.Element (Tokens, 3).Kind = Math_Tokens.Character_Token,
        "brackets remain characters");
      Check (Math_Tokens.Element (Tokens, 9).Kind = Math_Tokens.Parameter and
        Math_Tokens.Element (Tokens, 10).Kind = Math_Tokens.Superscript and
        Math_Tokens.Element (Tokens, 11).Kind = Math_Tokens.Subscript and
        Math_Tokens.Element (Tokens, 12).Kind = Math_Tokens.Alignment,
        "parameter script and alignment kinds");
      Check (Math_Tokens.Element (Tokens, 13).Kind = Math_Tokens.Character_Token,
        "character follows comments");
      Check (Math_Tokens.Element (Tokens, Math_Tokens.Count (Tokens)).Kind =
        Math_Tokens.End_Of_Input, "explicit end token");
      Check (Math_Tokens.Source (Tokens) = Math_Source.Text (Input),
        "token stream owns source");
      Math_Source.Create (String'(1 => Character'Val (92)), Input, Diagnostic, Error_Byte);
      Math_Tokens.Lex (Input, Tokens, Token_Diagnostic, Error_Byte);
      Check (Token_Diagnostic = Math_Tokens.Trailing_Escape and Error_Byte = 0,
        "trailing escape diagnostic");
      declare
         Large : constant String :=
           (1 .. Math_Source.Max_Source_Bytes => 'x');
      begin
         Math_Source.Create (Large, Input, Diagnostic, Error_Byte);
         Math_Tokens.Lex (Input, Tokens, Token_Diagnostic, Error_Byte);
         Check (Token_Diagnostic = Math_Tokens.No_Error and
           Math_Tokens.Count (Tokens) = Math_Source.Max_Source_Bytes + 1,
           "maximum legal source token count bounded");
      end;
      Math_Source.Create ("abc", Input, Diagnostic, Error_Byte);
      Math_Tokens.Lex (Input, Tokens, Token_Diagnostic, Error_Byte);
      declare
         First : constant Math_Tokens.Token := Math_Tokens.Element (Tokens, 1);
         Again : Math_Tokens.Stream;
         Again_Diagnostic : Math_Tokens.Diagnostic_Kind;
         Again_Byte : Natural;
      begin
         Math_Tokens.Lex (Input, Again, Again_Diagnostic, Again_Byte);
         Check (Math_Tokens.Element (Again, 1) = First and
           Math_Tokens.Count (Again) = Math_Tokens.Count (Tokens),
           "repeated lexing deterministic");
      end;
   end Run;
begin
   Run;
   Ada.Text_IO.Put_Line ("ASSERTIONS " & Natural'Image (Checks) &
     " failures=" & Natural'Image (Failures));
   if Failures /= 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Math_Tokens_Probe;
