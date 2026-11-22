with Ada.Command_Line;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Math_Macros;
with Math_Source;
with Math_Tokens;
with Math_Expander;

procedure Math_Snapshot_Probe is
   use type Math_Source.Diagnostic_Kind;
   use type Math_Tokens.Diagnostic_Kind;
   use type Math_Tokens.Token_Kind;
   use type Math_Macros.Diagnostic_Kind;
   use type Math_Expander.Diagnostic_Kind;
   Context : Math_Macros.Context;
   Source_Value : Math_Source.Source;
   Stream : Math_Tokens.Stream;
   Cursor : Math_Expander.Cursor;
   Source_Status : Math_Source.Diagnostic_Kind;
   Lex_Status : Math_Tokens.Diagnostic_Kind;
   Define_Status : Math_Macros.Diagnostic_Kind;
   Error_Byte : Natural;
   Count : Positive := 1;
   Repeats : Positive := 1;
   Decoys : Natural := 0;
   Token : Math_Tokens.Token;
   Output_Count : Natural := 0;
   function Build_Input return String is
      Result : String (1 .. Repeats * 10);
      At_Byte : Positive := Result'First;
   begin
      for Call in 1 .. Repeats loop
         Result (At_Byte .. At_Byte + 9) := "\snapshot ";
         At_Byte := At_Byte + 10;
      end loop;
      return Result;
   end Build_Input;
   procedure Require (Value : Boolean; Message : String) is
   begin
      if not Value then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Message);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error with Message;
      end if;
   end Require;
   function Img (Value : Natural) return String is
     (Ada.Strings.Fixed.Trim (Natural'Image (Value), Ada.Strings.Both));
begin
   if Ada.Command_Line.Argument_Count > 0 then
      Count := Positive'Value (Ada.Command_Line.Argument (1));
   end if;
   if Ada.Command_Line.Argument_Count > 1 then
      Repeats := Positive'Value (Ada.Command_Line.Argument (2));
   end if;
   if Ada.Command_Line.Argument_Count > 2 then
      Decoys := Natural'Value (Ada.Command_Line.Argument (3));
   end if;
   declare
      Replacement_Text : constant String := (1 .. Count => 'x');
   begin
      Math_Source.Create (Replacement_Text, Source_Value, Source_Status, Error_Byte);
      Require (Source_Status = Math_Source.No_Error, "replacement source");
      Math_Tokens.Lex (Source_Value, Stream, Lex_Status, Error_Byte);
      Require (Lex_Status = Math_Tokens.No_Error, "replacement lex");
      declare
         Replacement : Math_Macros.Token_Sequence (1 .. Count);
      begin
         for Index in Replacement'Range loop
            Replacement (Index) := Math_Tokens.Element (Stream, Index);
         end loop;
         Math_Macros.Define_Tokens
           (Context, "\snapshot", 0, Replacement, True, Define_Status);
         Require (Define_Status = Math_Macros.No_Error, "direct token define");
      end;
   end;
   if Decoys > 0 then
      declare
         Dummy : constant Math_Macros.Token_Sequence (1 .. 1) :=
           (1 => Math_Tokens.Element (Stream, 1));
      begin
         for Index in 1 .. Decoys loop
            Math_Macros.Define_Tokens
              (Context, "\decoy" & Img (Index), 0, Dummy, True,
               Define_Status);
            Require (Define_Status = Math_Macros.No_Error, "decoy define");
         end loop;
      end;
      declare
         Target : Math_Macros.Token_Sequence (1 .. Count);
      begin
         for Index in Target'Range loop
            Target (Index) := Math_Tokens.Element (Stream, 1);
         end loop;
         Math_Macros.Define_Tokens
           (Context, "\snapshot", 0, Target, True, Define_Status);
      end;
      Require (Define_Status = Math_Macros.No_Error, "move target definition last");
   end if;
   declare
      Input_Text : constant String := Build_Input;
   begin
      Math_Source.Create (Input_Text, Source_Value, Source_Status, Error_Byte);
      Require (Source_Status = Math_Source.No_Error, "input source");
      Math_Tokens.Lex (Source_Value, Stream, Lex_Status, Error_Byte);
      Require (Lex_Status = Math_Tokens.No_Error, "input lex");
      Math_Expander.Open (Stream, Cursor, 10_000, Math_Expander.Maximum_Tokens);
      Ada.Text_IO.Put_Line ("meta|body=" & Img (Count) & "|calls=" & Img (Repeats) &
         "|decoys=" & Img (Decoys));
      loop
         Token := Math_Expander.Next (Cursor, Context);
         Output_Count := Output_Count + 1;
         Ada.Text_IO.Put_Line
           ("tok|" & Img (Output_Count) & "|" &
            Math_Tokens.Token_Kind'Image (Token.Kind) & "|" &
            Img (Token.Code_Point) & "|" &
            Img (Token.First_Byte) & "|" & Img (Token.After_Byte) & "|" &
            Img (Token.First_Scalar) & "|" & Img (Token.After_Scalar) & "|" &
            Img (Token.First_UTF16) & "|" & Img (Token.After_UTF16) & "|" &
            Img (Token.Text_First) & "|" & Img (Token.Text_Length) & "|" &
            Ada.Strings.Unbounded.To_String (Token.Lexeme) & "|" &
            (if Token.Verbatim_Starred then "1" else "0") & "|" &
            (if Token.Has_Invocation then "1" else "0") & "|" &
            Img (Token.Invocation_First_Byte) & "|" &
            Img (Token.Invocation_After_Byte));
         exit when Token.Kind = Math_Tokens.End_Of_Input;
      end loop;
      Ada.Text_IO.Put_Line
        ("state|diagnostic=" & Math_Expander.Diagnostic_Kind'Image
           (Math_Expander.Diagnostic (Cursor)) &
         "|scope=" & Img (Math_Macros.Scope_Depth (Context)) &
         "|definitions=" & Img (Math_Macros.Definition_Count (Context)) &
         "|defined=" & (if Math_Macros.Is_Defined (Context, "\snapshot")
                          then "1" else "0"));
      Require (Math_Expander.Diagnostic (Cursor) = Math_Expander.No_Error,
               "expansion diagnostic");
      Require (Output_Count = Count * Repeats + 1, "output count");
   end;
end Math_Snapshot_Probe;
