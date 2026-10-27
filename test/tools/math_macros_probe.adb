with Ada.Command_Line;
with Ada.Text_IO;
with Ada.Strings.Fixed;
with Ada.Strings;
with Ada.Strings.Unbounded;
with Math_Macros;
with Math_Source;
with Math_Tokens;
with Math_Expander;
with Math_Builtin_Macros;


procedure Math_Macros_Probe is
   use type Math_Tokens.Token_Kind;
   use type Math_Source.Diagnostic_Kind;
   use type Math_Tokens.Diagnostic_Kind;
   use type Math_Macros.Diagnostic_Kind;
   use type Math_Expander.Diagnostic_Kind;
   use type Math_Expander.Diagnostic_Severity;
   use type Math_Expander.Diagnostic_Record;
   Checks : Natural := 0;
   Failures : Natural := 0;
   Ctx : Math_Macros.Context;
   procedure Check (Value : Boolean; Label : String) is
   begin
      Checks := Checks + 1;
      if Value then
         Ada.Text_IO.Put_Line ("ok " & Label);
      else
         Failures := Failures + 1;
         Ada.Text_IO.Put_Line ("FAIL " & Label);
      end if;
   end Check;
   procedure Open_Text
     (Text : String; Cur : in out Math_Expander.Cursor;
      Limit : Positive := Math_Expander.Default_Max_Expand;
      Token_Ceiling : Positive := Math_Expander.Maximum_Tokens) is
      Source : Math_Source.Source;
      Stream : Math_Tokens.Stream;
      SD : Math_Source.Diagnostic_Kind;
      TD : Math_Tokens.Diagnostic_Kind;
      Byte : Natural;
   begin
      Math_Source.Create (Text, Source, SD, Byte);
      Check (SD = Math_Source.No_Error, "source constructed");
      Math_Tokens.Lex (Source, Stream, TD, Byte);
      Check (TD = Math_Tokens.No_Error, "source lexed");
      Math_Expander.Open (Stream, Cur, Limit, Token_Ceiling);
   end Open_Text;
   procedure Expect_Code
     (Text : String; Expected : Natural; Label : String;
      Limit : Positive := Math_Expander.Default_Max_Expand) is
      Cur : Math_Expander.Cursor;
      T : Math_Tokens.Token;
   begin
      Open_Text (Text, Cur, Limit);
      T := Math_Expander.Next (Cur, Ctx);
      Check (T.Kind = Math_Tokens.Character_Token and then
        T.Code_Point = Expected, Label);
   end Expect_Code;
   procedure Expect_Message
     (Source, Expected : String;
      Severity : Math_Expander.Diagnostic_Severity; Label : String) is
      Local_Cursor : Math_Expander.Cursor;
      T : Math_Tokens.Token;
      Record_Value : Math_Expander.Diagnostic_Record;
   begin
      Math_Macros.Reset (Ctx);
      Open_Text (Source, Local_Cursor);
      loop
         T := Math_Expander.Next (Local_Cursor, Ctx);
         exit when T.Kind = Math_Tokens.End_Of_Input;
      end loop;
      Record_Value := Math_Expander.Last_Diagnostic (Local_Cursor);
      Check
        (Record_Value.Severity = Severity
         and then Record_Value.Length = Expected'Length
         and then Record_Value.Message (1 .. Record_Value.Length) = Expected,
         Label);
      Check (Math_Expander.Message_Count (Local_Cursor) = 1,
        "single primitive message has one owned history record");
      Check
        (Math_Expander.Diagnostic_At (Local_Cursor, 1) = Record_Value,
         "indexed diagnostic matches compatibility accessor");
      Open_Text ("x", Local_Cursor);
      Check (Math_Expander.Message_Count (Local_Cursor) = 0,
        "opening cursor clears prior message history");
   end Expect_Message;

   procedure Expect_Output (Text, Expected, Label : String) is
      Local_Cursor : Math_Expander.Cursor;
      T : Math_Tokens.Token;
      Actual : String (1 .. 512);
      Length : Natural := 0;
   begin
      Math_Macros.Reset (Ctx);
      Open_Text (Text, Local_Cursor);
      loop
         T := Math_Expander.Next (Local_Cursor, Ctx);
         exit when T.Kind = Math_Tokens.End_Of_Input;
         if T.Kind = Math_Tokens.Character_Token and then Length < Actual'Length then
            Length := Length + 1;
            Actual (Length) := Character'Val (T.Code_Point);
         else
            Length := Actual'Length;
         end if;
      end loop;
      Check (Math_Expander.Diagnostic (Local_Cursor) = Math_Expander.No_Error and then
        Length = Expected'Length and then Actual (1 .. Length) = Expected, Label);
   end Expect_Output;

   procedure Expect_Raw_Output (Text, Expected, Label : String) is
      Local_Cursor : Math_Expander.Cursor;
      Actual, Reference : Math_Tokens.Token;
      Source : Math_Source.Source;
      Stream : Math_Tokens.Stream;
      SD : Math_Source.Diagnostic_Kind;
      TD : Math_Tokens.Diagnostic_Kind;
      Byte : Natural;
      Index : Positive := 1;
      Same : Boolean := True;
   begin
      Math_Macros.Reset (Ctx);
      Open_Text (Text, Local_Cursor);
      Math_Source.Create (Expected, Source, SD, Byte);
      Math_Tokens.Lex (Source, Stream, TD, Byte);
      loop
         Actual := Math_Expander.Next (Local_Cursor, Ctx);
         exit when Actual.Kind = Math_Tokens.End_Of_Input;
         if Index <= Math_Tokens.Count (Stream) then
            Reference := Math_Tokens.Element (Stream, Index);
            Same := Same and then Actual.Kind = Reference.Kind
              and then Actual.Code_Point = Reference.Code_Point
              and then Ada.Strings.Unbounded.To_String (Actual.Lexeme) =
                Ada.Strings.Unbounded.To_String (Reference.Lexeme);
         else
            Same := False;
         end if;
         Index := Index + 1;
      end loop;
      Same := Same and then Index = Math_Tokens.Count (Stream)
        and then Math_Tokens.Element (Stream, Index).Kind =
          Math_Tokens.End_Of_Input;
      Check (SD = Math_Source.No_Error and then TD = Math_Tokens.No_Error
        and then Math_Expander.Diagnostic (Local_Cursor) = Math_Expander.No_Error
        and then Same, Label);
   end Expect_Raw_Output;

   Cur : Math_Expander.Cursor;
   T : Math_Tokens.Token;
   MD : Math_Macros.Diagnostic_Kind;
begin
   Open_Text ("\def\id#1{#1}", Cur);
   loop
      T := Math_Expander.Next (Cur, Ctx);
      exit when T.Kind = Math_Tokens.End_Of_Input;
   end loop;
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.No_Error,
     "\def parses successfully");
   Check (Math_Macros.Is_Defined (Ctx, "\id"), "\def installs name");
   Check (Math_Macros.Num_Params (Math_Macros.Lookup (Ctx, "\id")) = 1,
     "\def records one parameter");
   Check (Math_Macros.Token_Count (Math_Macros.Lookup (Ctx, "\id")) = 2,
     "replacement stores parameter marker and digit");
   Expect_Code ("\id{x}", Character'Pos ('x'), "single argument substituted");
   T := Math_Expander.Peek (Cur, Ctx);
   Check (T.Kind = Math_Tokens.End_Of_Input, "peek observes EOF without consuming");
   T := Math_Expander.Next (Cur, Ctx);
   Check (T.Kind = Math_Tokens.End_Of_Input, "empty input EOF");
   Open_Text ("\id{x}", Cur);
   T := Math_Expander.Next (Cur, Ctx);
   Check (T.First_Byte = 4 and then T.After_Byte = 5 and then
     T.First_Scalar = 4 and then T.After_Scalar = 5 and then
     T.First_UTF16 = 4 and then T.After_UTF16 = 5,
     "substituted argument retains invocation provenance");

   Open_Text ("\def\unicode#1{#1}", Cur);
   loop
      T := Math_Expander.Next (Cur, Ctx);
      exit when T.Kind = Math_Tokens.End_Of_Input;
   end loop;
   Open_Text ("\unicode{λ}", Cur);
   T := Math_Expander.Next (Cur, Ctx);
   Check (T.Code_Point = 955 and then T.First_Byte = 9 and then
     T.After_Byte = 11 and then T.First_Scalar = 9 and then
     T.After_Scalar = 10 and then T.First_UTF16 = 9 and then
     T.After_UTF16 = 10,
     "unicode actual argument retains exact invocation span");

   Open_Text ("\def\pair#1#2{#2#1}", Cur);
   loop
      T := Math_Expander.Next (Cur, Ctx);
      exit when T.Kind = Math_Tokens.End_Of_Input;
   end loop;
   Check (Math_Macros.Num_Params (Math_Macros.Lookup (Ctx, "\pair")) = 2,
     "two sequential parameters parsed");
   Open_Text ("\def\nine#1#2#3#4#5#6#7#8#9{#9}", Cur);
   loop T := Math_Expander.Next (Cur, Ctx); exit when T.Kind = Math_Tokens.End_Of_Input; end loop;
   Check (Math_Macros.Num_Params (Math_Macros.Lookup (Ctx, "\nine")) = 9,
     "parameter nine is accepted");
   Expect_Code ("\nine{a}{b}{c}{d}{e}{f}{g}{h}{i}", Character'Pos ('i'),
     "ninth argument substituted");
   Expect_Code ("\pair{a}{b}", Character'Pos ('b'), "first reordered argument");
   T := Math_Expander.Next (Cur, Ctx);

   Open_Text ("\def\nest#1{[#1]}", Cur);
   loop
      T := Math_Expander.Next (Cur, Ctx);
      exit when T.Kind = Math_Tokens.End_Of_Input;
   end loop;
   Open_Text ("\nest{{q}}", Cur);
   T := Math_Expander.Next (Cur, Ctx);
   Check (T.Code_Point = Character'Pos ('['), "nested argument replacement prefix");
   T := Math_Expander.Next (Cur, Ctx);
   Check (T.Kind = Math_Tokens.Left_Group, "nested argument opening brace retained");
   Open_Text ("\def\cross{\nest{λ}}", Cur);
   loop
      T := Math_Expander.Next (Cur, Ctx);
      exit when T.Kind = Math_Tokens.End_Of_Input;
   end loop;
   Open_Text ("\cross", Cur);
   T := Math_Expander.Next (Cur, Ctx);
   Check (T.Code_Point = Character'Pos ('['),
     "nested control words resolve from owned lexemes");
   T := Math_Expander.Next (Cur, Ctx);
   Check (T.Code_Point = 955 and then T.First_Byte = 17 and then
     T.After_Byte = 19 and then T.First_Scalar = 17 and then
     T.After_Scalar = 18 and then T.First_UTF16 = 17 and then
     T.After_UTF16 = 18 and then T.Has_Invocation and then
     T.Invocation_First_Byte = 0 and then T.Invocation_After_Byte = 6,
     "unicode literal retains definition span and stamps invocation span");
   T := Math_Expander.Next (Cur, Ctx);
   Check (T.Code_Point = Character'Pos (']'),
     "nested definition closes after cross-source expansion");

   Math_Macros.Begin_Group (Ctx);
   Open_Text ("\def\id#1{u}", Cur);
   loop T := Math_Expander.Next (Cur, Ctx); exit when T.Kind = Math_Tokens.End_Of_Input; end loop;
   Check (Math_Macros.Is_Defined (Ctx, "\id"), "inner shadow visible");
   Math_Macros.Begin_Group (Ctx);
   Open_Text ("\def\id#1{v}", Cur);
   loop T := Math_Expander.Next (Cur, Ctx); exit when T.Kind = Math_Tokens.End_Of_Input; end loop;
   Math_Macros.End_Group (Ctx);
   Expect_Code ("\id{x}", Character'Pos ('u'), "inner scope restores enclosing shadow");
   Math_Macros.End_Group (Ctx);
   Expect_Code ("\id{x}", Character'Pos ('x'), "outer scope restores original definition");
   Math_Macros.Begin_Group (Ctx);
   Open_Text ("\def\local{l}", Cur);
   loop T := Math_Expander.Next (Cur, Ctx); exit when T.Kind = Math_Tokens.End_Of_Input; end loop;
   Check (Math_Macros.Is_Defined (Ctx, "\local"), "local definition visible in group");
   Math_Macros.End_Group (Ctx);
   Check (not Math_Macros.Is_Defined (Ctx, "\local"), "local definition restored");
   Math_Macros.Begin_Group (Ctx);
   Math_Macros.Begin_Group (Ctx);
   Open_Text ("\gdef\permanent{p}", Cur);
   loop T := Math_Expander.Next (Cur, Ctx); exit when T.Kind = Math_Tokens.End_Of_Input; end loop;
   Math_Macros.End_Group (Ctx);
   Math_Macros.End_Group (Ctx);
   Check (Math_Macros.Is_Defined (Ctx, "\permanent"), "nested global survives unwinds");

   Open_Text ("\def\id#1{z}\id{x}", Cur);
   loop T := Math_Expander.Next (Cur, Ctx); exit when T.Kind = Math_Tokens.End_Of_Input; end loop;
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.No_Error,
     "shadow definition parsed");
   Expect_Code ("\id{x}", Character'Pos ('z'), "definition replaces prior binding");

   Open_Text ("\unknown ", Cur);
   T := Math_Expander.Next (Cur, Ctx);
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.No_Error,
     "undefined control word does not error");
   Check (T.Kind = Math_Tokens.Control_Word, "undefined control word passes through");

   Math_Macros.Reset (Ctx);
   Open_Text ("\gdef\bad{\unknown}", Cur);
   loop
      T := Math_Expander.Next (Cur, Ctx);
      exit when T.Kind = Math_Tokens.End_Of_Input;
   end loop;
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.No_Error,
     "global error macro definition persists");
   Open_Text ("\bad", Cur);
   T := Math_Expander.Next (Cur, Ctx);
   Check (T.Kind = Math_Tokens.Control_Word and then T.Has_Invocation and then
     T.First_Byte = 10 and then T.After_Byte = 18 and then
     T.Invocation_First_Byte = 0 and then T.Invocation_After_Byte = 4,
     "persisted macro keeps raw definition bytes and invocation bounds");
   T := Math_Expander.Next (Cur, Ctx);
   Check (T.Kind = Math_Tokens.End_Of_Input,
     "persisted macro expansion reaches EOF");
   Open_Text ("\bad", Cur);
   T := Math_Expander.Next (Cur, Ctx);
   Check (T.Kind = Math_Tokens.Control_Word and then T.Has_Invocation and then
     T.Invocation_First_Byte = 0 and then T.Invocation_After_Byte = 4,
     "reused global macro retains current invocation provenance");
   T := Math_Expander.Next (Cur, Ctx);
   Check (T.Kind = Math_Tokens.End_Of_Input,
     "reused macro expansion reaches EOF");
   Open_Text ("\def \spaced #1{#1}", Cur);
   loop T := Math_Expander.Next (Cur, Ctx); exit when T.Kind = Math_Tokens.End_Of_Input; end loop;
   Check (Math_Macros.Is_Defined (Ctx, "\spaced"), "lexer-consumed spaces do not corrupt names");
   Open_Text ("x", Cur);
   T := Math_Expander.Peek (Cur, Ctx);
   Check (T.Code_Point = Character'Pos ('x'), "peek returns next token");
   T := Math_Expander.Next (Cur, Ctx);
   Check (T.Code_Point = Character'Pos ('x'), "peek does not consume token");
   Open_Text ("\id{x}", Cur);
   Math_Expander.No_Expand_Next (Cur);
   T := Math_Expander.Next (Cur, Ctx);
   Check (T.Kind = Math_Tokens.Control_Word, "one-token suppression bypasses macro expansion");
   Open_Text ("x", Cur);
   T := Math_Expander.Next (Cur, Ctx);
   Math_Expander.Pushback (Cur, T);
   T := Math_Expander.Next (Cur, Ctx);
   Check (T.Code_Point = Character'Pos ('x'), "pushback replays prior token");

   Open_Text ("xy", Cur, Token_Ceiling => 2);
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.Token_Limit,
     "initial token stream over ceiling is diagnosed during Open");

   Open_Text ("\def\bad#2{x}", Cur);
   loop T := Math_Expander.Next (Cur, Ctx); exit when T.Kind = Math_Tokens.End_Of_Input; end loop;
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.Malformed_Definition,
     "nonsequential parameter is rejected");
   Open_Text ("\def\bad#1{x", Cur);
   loop T := Math_Expander.Next (Cur, Ctx); exit when T.Kind = Math_Tokens.End_Of_Input; end loop;
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.Malformed_Definition,
     "unterminated replacement is rejected");

   Open_Text ("\def\need#1{x}\need", Cur);
   loop T := Math_Expander.Next (Cur, Ctx); exit when T.Kind = Math_Tokens.End_Of_Input; end loop;
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.Argument_Error,
     "missing argument reported");

   Open_Text ("\def\loop{\loop}\loop", Cur, 5);
   loop T := Math_Expander.Next (Cur, Ctx); exit when T.Kind = Math_Tokens.End_Of_Input; end loop;
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.Expansion_Limit,
     "recursive expansion bounded");
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.Expansion_Limit,
     "recursive budget diagnostic stable after exhaustion");
   Open_Text ("\def\badhash{##}", Cur);
   loop T := Math_Expander.Next (Cur, Ctx); exit when T.Kind = Math_Tokens.End_Of_Input; end loop;
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.Malformed_Definition,
     "unsupported doubled parameter marker is malformed, not an exception");

   Open_Text ("\def\long{\long}\long", Cur, 10_000);
   loop
      T := Math_Expander.Next (Cur, Ctx);
      exit when T.Kind = Math_Tokens.End_Of_Input;
   end loop;
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.Expansion_Limit,
     "10,000-step recursive expansion budget terminates without stack growth");
   declare
      Source : Math_Source.Source;
      Stream : Math_Tokens.Stream;
      SD : Math_Source.Diagnostic_Kind;
      TD : Math_Tokens.Diagnostic_Kind;
      Byte : Natural;
      Value : Math_Tokens.Token_Sequence (1 .. 1);
   begin
      Math_Macros.Reset (Ctx);
      for I in reverse 1 .. 10_000 loop
         declare
            Ref_Source : Math_Source.Source;
            Ref_Stream : Math_Tokens.Stream;
            Ref_SD : Math_Source.Diagnostic_Kind;
            Ref_TD : Math_Tokens.Diagnostic_Kind;
            Ref_Byte : Natural;
            Ref_Name : constant String := "\chain" &
              Ada.Strings.Fixed.Trim (Integer'(I + 1)'Image, Ada.Strings.Left);
            Replacement : Math_Macros.Token_Sequence (1 .. 1);
         begin
            Math_Source.Create (Ref_Name, Ref_Source, Ref_SD, Ref_Byte);
            Math_Tokens.Lex (Ref_Source, Ref_Stream, Ref_TD, Ref_Byte);
            Replacement (1) := Math_Tokens.Element (Ref_Stream, 1);
            Math_Macros.Define_Tokens
              (Ctx, "\chain" & Ada.Strings.Fixed.Trim (I'Image, Ada.Strings.Left),
               0, Replacement, False, MD);
         end;
      end loop;
      Math_Source.Create ("\chain10001", Source, SD, Byte);
      Math_Tokens.Lex (Source, Stream, TD, Byte);
      Value (1) := Math_Tokens.Element (Stream, 2);
      Math_Tokens.From_Tokens (Stream, Value, Stream);
      Math_Source.Create ("\chain1", Source, SD, Byte);
      Math_Tokens.Lex (Source, Stream, TD, Byte);
      Value (1) := Math_Tokens.Element (Stream, 1);
      Math_Tokens.From_Tokens (Stream, Value, Stream);
      Math_Expander.Open (Stream, Cur, 10_000, 20_000);
      T := Math_Expander.Next (Cur, Ctx);
      Check (T.Kind = Math_Tokens.Control_Word and then
        Math_Expander.Diagnostic (Cur) = Math_Expander.No_Error,
        "10,000-link single-chain expansion completes without stack growth");
      Math_Macros.Reset (Ctx);
   end;

   declare
      Stream : Math_Tokens.Stream;
      Source : Math_Source.Source;
      SD : Math_Source.Diagnostic_Kind;
      TD : Math_Tokens.Diagnostic_Kind;
      Byte : Natural;
      Seq : Math_Macros.Token_Sequence (1 .. 1);
   begin
      Math_Source.Create ("x", Source, SD, Byte);
      Math_Tokens.Lex (Source, Stream, TD, Byte);
      Seq (1) := Math_Tokens.Element (Stream, 1);
      Math_Macros.Reset (Ctx);
      for I in 1 .. Math_Macros.Max_Definitions loop
         Math_Macros.Define_Tokens
           (Ctx, "\d" & Ada.Strings.Fixed.Trim (I'Image, Ada.Strings.Left), 0, Seq, False, MD);
         exit when MD /= Math_Macros.No_Error;
      end loop;
      Check (MD = Math_Macros.No_Error and then
        Math_Macros.Definition_Count (Ctx) = Math_Macros.Max_Definitions,
        "sequential definitions reach configured bound");
      Math_Macros.Define_Tokens
        (Ctx, "\overflow", 0, Seq, False, MD);
      Check (MD = Math_Macros.Definition_Limit,
        "definitions beyond configured bound report resource limit");
      Check (Math_Macros.Diagnostic (Ctx) = Math_Macros.No_Error,
        "context diagnostic accessor remains clear for rejected definition");
      Math_Macros.Reset (Ctx);
   end;

   Open_Text ("\def\a{a}\a", Cur, 1);
   T := Math_Expander.Next (Cur, Ctx);
   Check (T.Code_Point = Character'Pos ('a'), "limit allows configured expansion");
   T := Math_Expander.Next (Cur, Ctx);
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.No_Error,
     "one expansion terminates at EOF");

   Open_Text ("\def\grow#1{#1#1}\grow{xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx}",
     Cur, 1_000, 64);
   loop T := Math_Expander.Next (Cur, Ctx); exit when T.Kind = Math_Tokens.End_Of_Input; end loop;
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.Token_Limit,
     "expanded token queue enforces token ceiling");

   Open_Text ("\def\arg#1{#1}", Cur);
   loop T := Math_Expander.Next (Cur, Ctx); exit when T.Kind = Math_Tokens.End_Of_Input; end loop;
   Open_Text ("{a{b}c}", Cur);
   declare
      Result : Math_Tokens.Stream;
      ED : Math_Expander.Diagnostic_Kind;
   begin
      Math_Expander.Scan_Argument (Cur, Ctx, Result, ED);
      Check (ED = Math_Expander.No_Error, "balanced argument scanning succeeds");
      Check (Math_Tokens.Count (Result) = 6, "balanced argument retains inner braces and tokens");
   end;

   Math_Macros.Begin_Group (Ctx);
   for I in 1 .. 256 loop Math_Macros.Begin_Group (Ctx); end loop;
   Check (Math_Macros.Definition_Count (Ctx) >= 0, "scope operations remain defined");
   Math_Macros.Reset (Ctx);
   Check (Math_Macros.Definition_Count (Ctx) = 0, "reset clears definitions and scopes");
   declare
      Source : Math_Source.Source;
      Stream : Math_Tokens.Stream;
      SD : Math_Source.Diagnostic_Kind;
      TD : Math_Tokens.Diagnostic_Kind;
      Byte : Natural;
   begin
      Math_Source.Create ("x", Source, SD, Byte);
      Math_Tokens.Lex (Source, Stream, TD, Byte);
      Math_Macros.Define (Ctx, "\manual", 1, Stream, 1, 0, False, MD);
   end;
   Check (MD = Math_Macros.Definition_Limit, "invalid slice rejected without mutation");

   Math_Macros.Reset (Ctx);
   Expect_Output ("\newcommand{\foo}{a}\foo", "a", "newcommand braced name expands");
   Expect_Output ("\newcommand\foo{b}\foo", "b", "newcommand control-word name expands");
   Expect_Output ("\newcommand{\foo}[0]{c}\foo", "c", "newcommand accepts explicit zero arguments");
   Expect_Output ("\newcommand{\foo}[1]{#1}\foo{x}", "x", "newcommand substitutes one argument");
   Expect_Output ("\newcommand{\foo}[2]{#2#1}\foo{x}{y}", "yx", "newcommand reorders two arguments");
   Expect_Output ("\newcommand{\foo}[9]{#9}\foo{a}{b}{c}{d}{e}{f}{g}{h}{i}", "i", "newcommand accepts nine arguments");
   Expect_Output ("\providecommand{\foo}{p}\foo", "p", "providecommand defines absent macro");
   Expect_Output ("\@ifstar{Y}{N}*", "Y",
     "ifstar selects starred branch");
   Expect_Output ("\@ifstar{Y}{N}x", "Nx",
     "ifstar selects unstarred branch and preserves its lookahead");
   Expect_Output ("\@ifstar{Y}{N}*x", "Yx",
     "ifstar consumes only the star token");
   Expect_Output ("\@ifnextchar *{Y}{N}*", "Y",
     "ifnextchar selects matching character");
   Expect_Output ("\@ifnextchar *{Y}{N}x", "Nx",
     "ifnextchar selects nonmatch without consuming token");
   Expect_Output ("\@ifnextchar \alpha{Y}{N}\alpha", "Y",
     "ifnextchar matches a control token");
   Open_Text ("\@ifnextchar *{Y}{N}{*}", Cur);
   T := Math_Expander.Next (Cur, Ctx);
   Check (T.Kind = Math_Tokens.Character_Token and then
     T.Code_Point = Character'Pos ('N'),
     "ifnextchar does not treat a group as a matching character");
   Expect_Output ("\@firstoftwo{A}{\def\side{X}}A", "AA",
     "firstoftwo leaves unchosen definition inert");
   Check (not Math_Macros.Is_Defined (Ctx, "\side"),
     "unselected conditional branch has no definition side effect");
   Expect_Output ("\@secondoftwo{{A}B}{C}", "C",
     "secondoftwo skips nested unchosen group");
   Open_Text ("\noexpand\alpha", Cur);
   T := Math_Expander.Next (Cur, Ctx);
   Check (T.Kind = Math_Tokens.Control_Word and then
     Math_Expander.Diagnostic (Cur) = Math_Expander.No_Error,
     "noexpand returns its token without expanding it");
   Open_Text ("\let\myalpha=\alpha\myalpha", Cur);
   T := Math_Expander.Next (Cur, Ctx);
   Check (T.Kind = Math_Tokens.Control_Word and then
     Math_Expander.Diagnostic (Cur) = Math_Expander.No_Error,
     "let copies a primitive control token alias");
   Expect_Output ("\def\foo{A}\expandafter\foo\foo", "AA",
     "expandafter processes second macro before first macro");
   Expect_Output ("\newcommand{\foo}{a}\providecommand{\foo}{b}\foo", "a", "providecommand preserves existing binding");
   Expect_Output ("\newcommand{\foo}{a}\renewcommand{\foo}{r}\foo", "r", "renewcommand replaces existing binding");
   Expect_Output ("\newcommand{\foo}{a}\let\bar=\foo\renewcommand{\foo}{b}\bar", "a", "let alias freezes prior replacement");
   Expect_Output ("\newcommand{\foo}[1]{#1}\let\bar\foo\bar{l}", "l", "let alias copies parameter count");
   Expect_Output ("\newcommand{\foo}{a}\let\bar\foo\foo", "a", "let source remains callable");
   Expect_Output ("\global\def\foo{g}\foo", "g", "global def installs macro");
   Expect_Output ("\def\foo{a}\global\let\bar=\foo\def\foo{b}\bar",
     "a", "global let snapshots a definition");
   Open_Text ("\global\let\bar=\missing\bar", Cur);
   loop T := Math_Expander.Next (Cur, Ctx); exit when T.Kind = Math_Tokens.End_Of_Input; end loop;
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.No_Error and then
     Math_Macros.Is_Defined (Ctx, "\bar"),
     "global let aliases an undefined control token");
   Expect_Output ("\futurelet\next xA\next", "xAA",
     "futurelet aliases second lookahead and replays both tokens");
   Expect_Output ("\long\def\foo#1{#1}\foo{x}", "x",
     "long prefix accepts def using bounded macro semantics");
   Expect_Output ("\newcommand{\foo}{a}\renewcommand{\foo}{b}\foo", "b", "newcommand and renewcommand shadow");
   Expect_Output ("\newcommand{\foo}{a}\providecommand{\bar}{b}\foo\bar", "ab", "declarations coexist");
   Expect_Output ("\newcommand{\foo}[1]{x#1}\foo{y}", "xy", "replacement literals and parameters expand");
   Expect_Output ("\newcommand{\foo}{\newcommand{\bar}{z}}\foo\bar", "z", "expanded definition directives execute");
   Expect_Output ("\newcommand{\foo}{a}\let\bar=\foo\bar", "a", "let accepts optional equals");
   Expect_Output ("\newcommand{\foo}{a}\providecommand{\foo}{b}\foo", "a", "provide existing branch has no output");
   Expect_Output ("\newcommand{\foo}{a}\renewcommand{\foo}{a}\foo", "a", "renew identical body succeeds");
   Expect_Output ("\newcommand{\foo}[0]{x}\foo", "x", "zero parameter invocation works");
   Expect_Output ("\newcommand{\foo}[1]{#1#1}\foo{q}", "qq", "parameter may be duplicated");
   Expect_Output ("\newcommand{\foo}{a}\let\bar=\foo\let\baz=\bar\baz", "a", "let copies an alias snapshot");
   Open_Text ("\newcommand{\foo}{a}\newcommand{\foo}{b}", Cur);
   loop T := Math_Expander.Next (Cur, Ctx); exit when T.Kind = Math_Tokens.End_Of_Input; end loop;
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.Malformed_Definition, "newcommand rejects duplicate declaration");
   Open_Text ("\renewcommand{\absent}{x}", Cur);
   loop T := Math_Expander.Next (Cur, Ctx); exit when T.Kind = Math_Tokens.End_Of_Input; end loop;
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.Malformed_Definition, "renewcommand rejects missing declaration");
   Open_Text ("\newcommand{\foo}[10]{x}", Cur);
   loop T := Math_Expander.Next (Cur, Ctx); exit when T.Kind = Math_Tokens.End_Of_Input; end loop;
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.Malformed_Definition, "argument count above nine rejected");
   Expect_Output ("\newcommand{\foo}[1][d]{#1}\foo", "d",
     "optional default is used when first argument is absent");
   Expect_Output ("\newcommand{\foo}[1][d]{#1}\foo[x]", "x",
     "optional bracket argument overrides default");
   Math_Macros.Reset (Ctx);
   Open_Text ("\newcommand{\foo}[1][d]{#1}\foo[{x]y}]", Cur);
   declare
      Actual : String (1 .. 4) := (others => ' ');
      Length : Natural := 0;
   begin
      loop
         T := Math_Expander.Next (Cur, Ctx);
         exit when T.Kind = Math_Tokens.End_Of_Input;
         if T.Kind = Math_Tokens.Character_Token then
            Length := Length + 1;
            Actual (Length) := Character'Val (T.Code_Point);
         end if;
      end loop;
      Check (Length = 3 and then Actual (1 .. 3) = "x]y" and then
        Math_Expander.Diagnostic (Cur) = Math_Expander.No_Error,
        "optional argument closing bracket inside braces is data");
   end;
   Expect_Output ("\newcommand{\foo}[2][d]{#1#2}\foo{z}", "dz",
     "optional default leaves following required arguments available");
   Math_Macros.Reset (Ctx);
   Open_Text ("\newcommand{\foo}[1][{d}]{#1}\foo", Cur);
   T := Math_Expander.Next (Cur, Ctx);
   Check (T.Kind = Math_Tokens.Left_Group and then
     Math_Expander.Diagnostic (Cur) = Math_Expander.No_Error,
     "grouped optional default preserves its opening brace");
   T := Math_Expander.Next (Cur, Ctx);
   Check (T.Kind = Math_Tokens.Character_Token and then
     T.Code_Point = 100,
     "grouped optional default preserves content");
   Open_Text ("\newcommand{\foo}[1][d", Cur);
   loop T := Math_Expander.Next (Cur, Ctx); exit when T.Kind = Math_Tokens.End_Of_Input; end loop;
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.Malformed_Definition,
     "unterminated optional default is rejected");
   Open_Text ("\newcommand{\foo}[1]{#2}", Cur);
   loop T := Math_Expander.Next (Cur, Ctx); exit when T.Kind = Math_Tokens.End_Of_Input; end loop;
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.Malformed_Definition, "out-of-range parameter rejected");
   Math_Macros.Reset (Ctx);
   Math_Macros.Begin_Group (Ctx);
   Open_Text ("\newcommand{\foo}{a}\let\bar=\foo", Cur);
   loop T := Math_Expander.Next (Cur, Ctx); exit when T.Kind = Math_Tokens.End_Of_Input; end loop;
   Math_Macros.End_Group (Ctx);
   Check (not Math_Macros.Is_Defined (Ctx, "\foo") and then
     not Math_Macros.Is_Defined (Ctx, "\bar"), "local declarations and let aliases unwind");
   Math_Macros.Reset (Ctx);
   Check (Math_Macros.Diagnostic (Ctx) = Math_Macros.No_Error and then
     Math_Macros.Definition_Count (Ctx) = 0, "reset clears scope error status and definitions");
   Open_Text ("\let\bar=\missing", Cur);
   loop T := Math_Expander.Next (Cur, Ctx); exit when T.Kind = Math_Tokens.End_Of_Input; end loop;
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.No_Error and then
     Math_Macros.Is_Defined (Ctx, "\bar"),
     "let snapshots an undefined control token");
   Expect_Output ("\def\source{a}\edef\foo{\source}\def\source{b}\foo",
     "a", "edef expands replacement when definition is made");
   Expect_Output ("\def\source{a}\xdef\foo{\source}\def\source{b}\foo",
     "a", "xdef expands and globally stores replacement");
   Open_Text ("\edef\foo{\missing}", Cur);
   loop T := Math_Expander.Next (Cur, Ctx); exit when T.Kind = Math_Tokens.End_Of_Input; end loop;
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.No_Error and then
     Math_Macros.Is_Defined (Ctx, "\foo"),
     "edef preserves unexpandable control words in replacement");
   Math_Macros.Reset (Ctx);
   Open_Text ("\edef\foo{\def\side{X}}", Cur);
   loop
      T := Math_Expander.Next (Cur, Ctx);
      exit when T.Kind = Math_Tokens.End_Of_Input;
   end loop;
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.No_Error and then
     not Math_Macros.Is_Defined (Ctx, "\side"),
     "edef does not execute assignment in its replacement");
   Expect_Output ("\edef\foo{\def\side{X}}\foo\side", "X",
     "deferred edef assignment executes only when invoked");
   Math_Macros.Reset (Ctx);
   Open_Text ("\xdef\foo{\global\def\side{X}}", Cur);
   loop
      T := Math_Expander.Next (Cur, Ctx);
      exit when T.Kind = Math_Tokens.End_Of_Input;
   end loop;
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.No_Error and then
     not Math_Macros.Is_Defined (Ctx, "\side"),
     "xdef does not execute global assignment in its replacement");
   Math_Macros.Reset (Ctx);
   Open_Text ("\def\src{a}\edef\a{\src}\edef\b{\src}", Cur, 1);
   loop
      T := Math_Expander.Next (Cur, Ctx);
      exit when T.Kind = Math_Tokens.End_Of_Input;
   end loop;
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.Expansion_Limit,
     "multiple edef temporaries share parent expansion budget");
   Math_Macros.Reset (Ctx);
   Open_Text ("\def\a{\edef\b{\a}}\a", Cur, 20);
   loop
      T := Math_Expander.Next (Cur, Ctx);
      exit when T.Kind = Math_Tokens.End_Of_Input;
   end loop;
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.Expansion_Limit,
     "recursive edef expansion remains bounded");
   Open_Text ("\noexpand\foo", Cur);
   T := Math_Expander.Next (Cur, Ctx);
   Check (T.Kind = Math_Tokens.Control_Word and then
     Math_Expander.Diagnostic (Cur) = Math_Expander.No_Error,
     "noexpand accepts an undefined control token");
   Check (Math_Builtin_Macros.Lookup ("\iff").Found,
     "builtin equivalence alias is registered");
   Check (Math_Builtin_Macros.Lookup ("\implies").Found,
     "builtin implication alias is registered");
   Check (Math_Builtin_Macros.Lookup ("\ne").Found,
     "builtin inequality alias is registered");
   Check (Math_Builtin_Macros.Lookup ("\neq").Found,
     "builtin inequality target is registered");
   declare
      Unicode_Template : constant String :=
        Ada.Strings.Unbounded.To_String
          (Math_Builtin_Macros.Lookup ("\gvertneqq").Template);
      Expected_Template : constant String :=
        "\html@mathml{\@gvertneqq}{" & Character'Val (16#E2#) &
        Character'Val (16#89#) & Character'Val (16#A9#) & "}";
   begin
      Check (Unicode_Template = Expected_Template,
        "builtin lookup preserves exact UTF-8 template bytes");
   end;
   Check (Math_Builtin_Macros.Lookup ("\blue").Num_Params = 1,
     "parameterized builtin arity is derived around escaped hashes");
   Check (Math_Builtin_Macros.Lookup ("\AA").Num_Params = 0,
     "zero-argument builtin arity is derived");
   Check (not Math_Builtin_Macros.Lookup ("\dots").Found,
     "callable builtin is intentionally excluded");
   Check
     (Ada.Strings.Fixed.Index
        (Ada.Strings.Unbounded.To_String
           (Math_Builtin_Macros.Lookup ("\copyright").Template),
         "\TextOrMath{\textcopyright}{\text{\textcopyright}}") > 0,
      "copyright builtin contains its mode-selected template branches");
   Expect_Code ("\char65", Character'Pos ('A'),
     "char parses decimal code point");
   Expect_Code ("\char""41", Character'Pos ('A'),
     "char parses hexadecimal code point");
   Expect_Code ("\char'101", Character'Pos ('A'),
     "char parses octal code point");
   Expect_Code ("\char`A", Character'Pos ('A'),
     "char parses quoted character");
   Expect_Code ("\char`\alpha", Character'Pos ('a'),
     "char quoted control word uses its first name character");
   Expect_Code ("\char0", 0, "char accepts code point zero");
   Expect_Code ("\char55296", 55296,
     "char preserves numeric surrogate code points");
   Open_Text ("\char1114111", Cur);
   T := Math_Expander.Next (Cur, Ctx);
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.Argument_Error,
     "char rejects KaTeX exclusive maximum code point");
   Open_Text ("\char1114112", Cur);
   T := Math_Expander.Next (Cur, Ctx);
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.Argument_Error,
     "char rejects values above Unicode maximum");
   Open_Text ("\char99999999", Cur);
   T := Math_Expander.Next (Cur, Ctx);
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.Argument_Error,
     "char rejects out-of-range Unicode scalar");
   Open_Text ("\dots+", Cur);
   T := Math_Expander.Next (Cur, Ctx);
   Check (T.Code_Point = 16#22EF# and then
     Ada.Strings.Unbounded.To_String (T.Lexeme) = "⋯",
     "dots uses its glyph lexeme after binary-operator lookahead");
   T := Math_Expander.Next (Cur, Ctx);
   Check (T.Code_Point = Character'Pos ('+'),
     "dots preserves its unexpanded lookahead token");
   Open_Text ("\TextOrMath{A}{B}", Cur);
   Math_Expander.Set_Mode (Cur, True);
   T := Math_Expander.Next (Cur, Ctx);
   Check (T.Kind = Math_Tokens.Character_Token and then
     T.Code_Point = Character'Pos ('A'),
     "TextOrMath selects its text argument in regular mode");
   Open_Text ("\TextOrMath{A}{B}", Cur);
   Math_Expander.Set_Mode (Cur, False);
   T := Math_Expander.Next (Cur, Ctx);
   Check (T.Kind = Math_Tokens.Character_Token and then
     T.Code_Point = Character'Pos ('B'),
     "TextOrMath selects its math argument outside regular mode");
   Open_Text ("\TextOrMath{abcdef}{x}", Cur, Token_Ceiling => 6);
   T := Math_Expander.Next (Cur, Ctx);
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.Token_Limit,
     "TextOrMath argument scanning respects the token ceiling");
   Open_Text ("\dots\alpha", Cur);
   T := Math_Expander.Next (Cur, Ctx);
   Check (T.Code_Point = 16#2026#,
     "dots uses ellipsis for ordinary math symbols");
   Open_Text ("\TextOrMath{A}{B}", Cur);
   Math_Expander.Set_Mode (Cur, True);
   T := Math_Expander.Next (Cur, Ctx);
   Check (T.Kind = Math_Tokens.Character_Token and then
     T.Code_Point = Character'Pos ('A'),
     "TextOrMath selects its text argument in regular mode");
   Open_Text ("\TextOrMath{A}{B}", Cur);
   Math_Expander.Set_Mode (Cur, False);
   T := Math_Expander.Next (Cur, Ctx);
   Check (T.Kind = Math_Tokens.Character_Token and then
     T.Code_Point = Character'Pos ('B'),
     "TextOrMath selects its math argument outside regular mode");
   Open_Text ("\cdots", Cur);
   T := Math_Expander.Next (Cur, Ctx);
   Check (T.Code_Point = 16#22EF#,
     "cdots emits the centered ellipsis glyph");
   Open_Text ("\dots,", Cur);
   T := Math_Expander.Next (Cur, Ctx);
   Check (T.Code_Point = 16#2026#,
     "dots classifies punctuation as standard ellipsis");
   Expect_Code ("\dotso+", 16#2026#,
     "dotso emits standard ellipsis");
   Expect_Code ("\dotsc+", 16#2026#,
     "dotsc emits standard ellipsis");
   Expect_Code ("\dotsb+", 16#22EF#,
     "dotsb emits centered ellipsis");
   Expect_Code ("\dotsi+", 16#22EF#,
     "dotsi emits centered ellipsis");
   Expect_Code ("\dotsm+", 16#22EF#,
     "dotsm emits centered ellipsis");
   Expect_Code ("\dotsx+", 16#2026#,
     "dotsx emits standard ellipsis");
   Expect_Output ("\message{hidden}x", "x",
     "message consumes its argument without output tokens");
   Expect_Output ("\errmessage{{nested} message}x", "x",
     "errmessage consumes balanced argument without output tokens");
   Expect_Output ("\show\alpha x", "x",
     "show consumes one token without output tokens");
   Expect_Message ("\message{hello}x", "hello",
     Math_Expander.Information, "message is available from cursor diagnostics");
   Expect_Message ("\errmessage{oops}x", "oops",
     Math_Expander.Error, "errmessage records error severity and text");
   Expect_Message ("\show\alpha x", "\show \alpha",
     Math_Expander.Information, "show preserves token detail in diagnostics");
   Check (not Math_Builtin_Macros.Lookup ("\unknown").Found,
     "unknown macro is absent from builtin table");
   Check (not Math_Builtin_Macros.Lookup ("\to").Found,
     "unregistered arrow alias remains absent");
   Math_Macros.Reset (Ctx);
   Open_Text ("\blue{x}", Cur);
   loop
      T := Math_Expander.Next (Cur, Ctx);
      exit when T.Kind = Math_Tokens.End_Of_Input;
   end loop;
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.No_Error,
     "parameterized builtin expands without diagnostics");
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.No_Error and then
     Math_Macros.Definition_Count (Ctx) = 0,
     "parameterized builtin never registers in context");
   Open_Text ("\\blue{z}", Cur);
   declare
      Saw_Z : Boolean := False;
   begin
      loop
         T := Math_Expander.Next (Cur, Ctx);
         exit when T.Kind = Math_Tokens.End_Of_Input;
         Saw_Z := Saw_Z or else T.Code_Point = Character'Pos ('z');
      end loop;
      Check (Saw_Z and then
        Math_Expander.Diagnostic (Cur) = Math_Expander.No_Error,
        "builtin #1 marker substitutes argument text");
   end;
   Check (Math_Macros.Definition_Count (Ctx) = 0,
     "builtin expansion does not mutate user macro context");
   Open_Text ("\AA", Cur);
   loop
      T := Math_Expander.Next (Cur, Ctx);
      exit when T.Kind = Math_Tokens.End_Of_Input;
   end loop;
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.No_Error,
     "zero-argument builtin expands without diagnostics");
   Check (Math_Macros.Definition_Count (Ctx) = 0,
     "zero-argument expansion does not install definitions");
   Open_Text ("\newcommand{\AA}{x}", Cur);
   loop
      T := Math_Expander.Next (Cur, Ctx);
      exit when T.Kind = Math_Tokens.End_Of_Input;
   end loop;
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.Malformed_Definition,
     "newcommand rejects builtin name");
   Math_Macros.Reset (Ctx);
   Open_Text ("\renewcommand{\AA}{x}\AA", Cur);
   loop
      T := Math_Expander.Next (Cur, Ctx);
      exit when T.Kind = Math_Tokens.End_Of_Input;
   end loop;
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.No_Error,
     "renewcommand overrides builtin");
   Check (Math_Macros.Definition_Count (Ctx) = 1,
     "user override is the only context definition");
   Math_Macros.Reset (Ctx);
   Open_Text ("\def\AA{x}\AA", Cur);
   loop
      T := Math_Expander.Next (Cur, Ctx);
      exit when T.Kind = Math_Tokens.End_Of_Input;
   end loop;
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.No_Error,
     "def overrides builtin");
   Check (Math_Macros.Definition_Count (Ctx) = 1,
     "def override remains user-owned");
   Math_Macros.Reset (Ctx);
   Open_Text ("\newcommand{\iff}{x}\iff", Cur);
   loop
      T := Math_Expander.Next (Cur, Ctx);
      exit when T.Kind = Math_Tokens.End_Of_Input;
   end loop;
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.Malformed_Definition,
     "newcommand recognizes builtin name");
   Check (Math_Macros.Definition_Count (Ctx) = 0,
     "builtin names are never preloaded into shared context");
   Expect_Raw_Output
     ("\bra@ket{L}{M}{D}{R}{a|b}", "LaMbR",
      "bra-ket custom middle binding expands character token stream");
   Expect_Raw_Output
     ("\bra@ket{L}{M}{D}{R}{a||b}", "LaDbR",
      "bra-ket double middle binding consumes the pair once");
   Expect_Raw_Output
     ("\bra@set{L}{M}{D}{R}{a|b|c}", "LaMb|cR",
      "bra-set applies its middle binding to only the first bar");
   Expect_Raw_Output
     ("\bra@ket{L}{M}{D}{R}{a{b|c}d}", "La{bMc}dR",
      "nested grouping preserves braces and inherits the binding");
   Expect_Raw_Output
     ("\def\makebar{|}\bra@ket{L}{M}{D}{R}{a\makebar b}",
      "LaMbR", "a macro-produced bar triggers the helper binding");
   Expect_Raw_Output
     ("\bra@ket{L}{M}{D}{R}{a|b}|c", "LaMbR|c",
      "helper binding scope ends before following bar");
   Expect_Raw_Output
     ("\def\bra@ket#1{Q}\bra@ket{L}{M}{D}{R}{a|b}",
      "Q{M}{D}{R}{a|b}", "user definition of helper takes precedence");
   Expect_Raw_Output
     ("\bra@ket{L}{M}{}{R}{a|b}", "LaMbR",
      "empty double-middle argument leaves single binding functional");
   Expect_Raw_Output
     ("\bra@ket{L}{M}{D}{R}{a{b|c}d}", "La{bMc}dR",
      "nested token groups retain visible group delimiters");
   Expect_Raw_Output
     ("\bra@ket{L}{M}{D}{R}{a\bra@ket{l}{n}{e}{r}{x|y}z|q}",
      "LalxnyrzMqR",
      "nested helper inherits scoped binding and restores outer binding");

   Open_Text ("\bra@ket{L}{M}{D}{R}{a|b", Cur);
   loop
      T := Math_Expander.Next (Cur, Ctx);
      exit when T.Kind = Math_Tokens.End_Of_Input;
   end loop;
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.Argument_Error,
     "malformed helper argument reports failure");
   Expect_Raw_Output ("|x", "|x",
     "malformed helper does not leak cursor bar binding");

   Open_Text ("\bra@ket{L}{M}{D}{R}{a|b}", Cur, 1);
   loop T := Math_Expander.Next (Cur, Ctx);
      exit when T.Kind = Math_Tokens.End_Of_Input; end loop;
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.Expansion_Limit,
     "helper and nested expansion share configured expansion budget");
   Open_Text ("\bra@ket{L}{M}{D}{R}{a|b}", Cur, 2);
   loop T := Math_Expander.Next (Cur, Ctx);
      exit when T.Kind = Math_Tokens.End_Of_Input; end loop;
   Check (Math_Expander.Diagnostic (Cur) = Math_Expander.No_Error,
     "helper expansion completes at the exact minimum budget");

   Check (Failures = 0, "all prior checks passed");
   Ada.Text_IO.Put_Line ("Checks:" & Checks'Image & " Failures:" & Failures'Image);
   if Failures /= 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Math_Macros_Probe;
