with Ada.Strings.Unbounded;
with Math_Model;
with Math_Metrics;
with Math_Source;
with Math_Symbols;
with Math_Tokens;
with Math_Expander;
with Math_Macros;
with Math_Stretchy;
with Math_Work_Control;
with Math_Unicode;

package body Math_Syntax is
   use Ada.Strings.Unbounded;
   use Math_Model;
   use type Math_Source.Diagnostic_Kind;
   use type Math_Tokens.Token_Kind;
   use type Math_Tokens.Diagnostic_Kind;
   use type Math_Expander.Diagnostic_Kind;
   use type Math_Expander.Diagnostic_Severity;
   use type Math_Macros.Diagnostic_Kind;

   Parse_Failure : exception;

   type Parser_State
     (Shared : not null access Math_Macros.Context) is limited record
      Item : Document;
      Cursor : Math_Expander.Cursor;
      Current : Math_Tokens.Token;
      Cursor_Pos : Natural := 1;
      Depth : Natural := 0;
      Diagnostic_Serial : Natural := 0;
      Regular_Mode : Boolean := False;
      Color_Box_Mode : Boolean := False;
      Font_Mode : Font_Kind := Math_Italic;
      Has_Font_Mode : Boolean := False;
      Dollar_Math_Allowed : Boolean := False;
      Settings : Options := (Strict => Strict_Warn, others => <>);
      Environment_Stop : Unbounded_String;
      CD_Mode : Boolean := False;
      Work : Math_Work_Control.Context_Access := null;
      AMS_Row : Boolean := False;
      Pending_Tag : Node_Id := No_Node;
      Has_Tag : Boolean := False;
   end record;

   procedure Fail
     (State : in out Parser_State;
      Why : String;
      Where : Natural := 0) is
   begin
      if Length (State.Item.Message) = 0 then
         State.Item.Message := To_Unbounded_String (Why);
         State.Item.Failure := (if Where = 0 then State.Cursor_Pos else Where);
         State.Item.Diagnostics.Append
           (New_Item => Math_Syntax.Diagnostic'
              (Kind => (if Why'Length >= 7 and then Why (Why'First ..
                 Why'First + 6) = "refused" then
                    (if State.Settings.Strict = Strict_Error then Parse_Error
                     else Refusal)
                 else Parse_Error),
               Message => To_Unbounded_String (Why),
               Position => State.Item.Failure));
      end if;
      raise Parse_Failure;
   end Fail;

   function Peek (State : Parser_State) return Character is
      Text : constant String := To_String (State.Current.Lexeme);
   begin
      if State.Current.Kind = Math_Tokens.End_Of_Input then
         return Character'Val (0);
      elsif State.Current.Kind = Math_Tokens.Space_Token then
         return ' ';
      elsif State.Current.Kind = Math_Tokens.Verbatim_Token then
         return ' ';
      elsif Text'Length > 0 then
         return Text (Text'First);
      end if;
      return Character'Val (0);
   end Peek;

   function Command_Is (State : Parser_State; Name : String) return Boolean is
     (State.Current.Kind in Math_Tokens.Control_Word |
        Math_Tokens.Control_Symbol
      and then To_String (State.Current.Lexeme) = Name);

   function Is_Stretchy_Command (Name : String) return Boolean is
   begin
      if Name in
        "xrightarrow" | "xleftarrow" | "Overrightarrow" |
        "xRightarrow" | "xLeftarrow" | "overleftharpoon" |
        "underleftarrow" | "underrightarrow" |
        "overleftrightarrow" | "underleftrightarrow" |
        "xleftharpoonup" | "xleftharpoondown" |
        "overrightharpoon" | "xrightharpoonup" |
        "xrightharpoondown" | "xlongequal" |
        "xtwoheadleftarrow" | "xtwoheadrightarrow" |
        "xleftrightarrow" | "xLeftrightarrow" |
        "xrightleftharpoons" | "xleftrightharpoons" |
        "xhookleftarrow" | "xhookrightarrow" | "overlinesegment" |
        "underlinesegment" | "overgroup" | "undergroup" |
        "xmapsto" | "xtofrom" | "xrightleftarrows" |
        "xrightequilibrium" | "xleftequilibrium"
      then
         return Math_Stretchy.PartCount (Name) > 0;
      end if;
      return False;
   end Is_Stretchy_Command;

   function Command_Is_Labelled_Arrow (Name : String) return Boolean is
     (Name in "xrightarrow" | "xleftarrow" |
        "xRightarrow" | "xLeftarrow" |
        "xleftharpoonup" | "xleftharpoondown" |
        "xrightharpoonup" | "xrightharpoondown" | "xlongequal" |
        "xtwoheadleftarrow" | "xtwoheadrightarrow" |
        "xleftrightarrow" | "xLeftrightarrow" |
        "xrightleftharpoons" | "xleftrightharpoons" |
        "xhookleftarrow" | "xhookrightarrow" | "xmapsto" |
        "xtofrom" | "xrightleftarrows" | "xrightequilibrium" |
        "xleftequilibrium");

   procedure Advance (State : in out Parser_State) is
      Serial : Natural;
   begin
      State.Current := Math_Expander.Next (State.Cursor, State.Shared.all);
      State.Cursor_Pos :=
        (if State.Current.Has_Invocation then
           State.Current.Invocation_First_Byte
         else State.Current.First_Byte) + 1;
      Serial := Math_Expander.Diagnostic_Serial (State.Cursor);
      while State.Diagnostic_Serial < Serial loop
         State.Diagnostic_Serial := State.Diagnostic_Serial + 1;
         if State.Diagnostic_Serial <=
           Math_Expander.Message_Count (State.Cursor)
         then
            declare
               Message : constant Math_Expander.Diagnostic_Record :=
                 Math_Expander.Diagnostic_At
                   (State.Cursor, State.Diagnostic_Serial);
            begin
               State.Item.Diagnostics.Append
                 (New_Item => Math_Syntax.Diagnostic'
                    (Kind => (if Message.Severity =
                                Math_Expander.Information
                              then Warning else Refusal),
                     Message => To_Unbounded_String
                       (Message.Message (1 .. Message.Length)),
                     Position => State.Cursor_Pos));
            end;
         end if;
      end loop;
      if Math_Expander.Diagnostic (State.Cursor) /= Math_Expander.No_Error then
         Fail (State, "macro expansion: " &
           Math_Expander.Diagnostic (State.Cursor)'Image);
      end if;
      if Math_Macros.Diagnostic (State.Shared.all) /= Math_Macros.No_Error then
         Fail (State, "macro scope error");
      end if;
   end Advance;

   function Is_Math_Whitespace (Char : Character) return Boolean is
     (Char in ' ' | ASCII.HT | ASCII.LF | ASCII.CR);

   procedure Skip_Whitespace (State : in out Parser_State) is
   begin
      if not State.Regular_Mode then
         while State.Current.Kind = Math_Tokens.Space_Token loop
            Advance (State);
         end loop;
      end if;
   end Skip_Whitespace;

   function Current_Code_Point (State : Parser_State) return Natural is
     (State.Current.Code_Point);

   function Font_For_Name (Name : String) return Font_Kind is
   begin
      if Name in "mathbf" | "boldsymbol" | "bm" | "bf" | "textbf" then
         return Main_Bold;
      elsif Name in "mathbb" | "Bbb" then
         return AMS_Regular;
      elsif Name = "bold" then
         return Main_Bold;
      elsif Name in "mathcal" | "cal" then
         return Caligraphic_Regular;
      elsif Name in "mathit" | "it" | "mathnormal" then
         return Math_Italic;
      elsif Name in "textit" | "emph" then
         return Main_Italic;
      elsif Name in "textnormal" | "textmd" | "textup" | "rm" |
        "textrm" | "mathrm"
      then
         return Main_Regular;
      elsif Name in "mathsf" | "sf" | "textsf" then
         return Sans_Serif_Regular;
      elsif Name = "mathsfit" then
         return Sans_Serif_Italic;
      elsif Name in "mathtt" | "tt" | "texttt" then
         return Typewriter_Regular;
      elsif Name in "mathfrak" | "frak" then
         return Fraktur_Regular;
      elsif Name = "mathscr" then
         return Script_Regular;
      else
         return Main_Regular;
      end if;
   end Font_For_Name;

   function Add
     (State : in out Parser_State;
      Item : Node) return Node_Id is
      Fresh : Node := Item;
   begin
      if Natural (State.Item.Nodes.Length) >= Max_Nodes then
         Fail (State, "node limit exceeded");
      end if;
      Fresh.Position := Item.Position;
      State.Item.Nodes.Append (Fresh);
      return Node_Id (State.Item.Nodes.Last_Index);
   end Add;

   procedure Link
     (State : in out Parser_State;
      Row : Node_Id;
      Part : Node_Id) is
      Cursor : Node_Id;
      Value : Node;
   begin
      if State.Item.Nodes (Positive (Row)).First = No_Node then
         Value := State.Item.Nodes (Positive (Row));
         Value.First := Part;
         State.Item.Nodes.Replace_Element (Positive (Row), Value);
      else
         Cursor := State.Item.Nodes (Positive (Row)).First;
         loop
            Value := State.Item.Nodes (Positive (Cursor));
            exit when Value.Next = No_Node;
            Cursor := Value.Next;
         end loop;
         Value.Next := Part;
         State.Item.Nodes.Replace_Element (Positive (Cursor), Value);
      end if;
   end Link;

   function New_Glyph
     (State : in out Parser_State;
      Point : Natural;
      Class : Atom_Class;
      Font : Font_Kind;
      Position : Natural) return Node_Id is
      Fresh : Node;
      Actual_Font : Font_Kind := Font;
      Main_Metric : Math_Metrics.Glyph_Metric;
      Large_Metric : Math_Metrics.Glyph_Metric;
      Natural_Limits : constant Boolean := Point in
        16#2210# | 16#2211# | 16#220F# | 16#8720# | 8896 |
        8897 | 8898 | 8899 | 10752 | 10753 | 10754 | 10756 | 10758;
   begin
      if Class = Operator_Atom and then not State.Regular_Mode and then
        not State.Has_Font_Mode
      then
         Main_Metric := Math_Metrics.Lookup (Main_Regular, Point);
         Large_Metric := Math_Metrics.Lookup (Size_1, Point);
         if not Main_Metric.Found and then Large_Metric.Found then
            Actual_Font := Size_1;
         end if;
      end if;
      Fresh.Kind := Glyph_Node;
      Fresh.Code_Point := Point;
      Fresh.Class := Class;
      Fresh.Font := (if State.Has_Font_Mode then State.Font_Mode else
                     (if State.Regular_Mode then Main_Regular
                      else Actual_Font));
      Fresh.Script_Type :=
        (if Class = Operator_Atom and then Natural_Limits
         then Limit_Scripts else Side_Scripts);
      Fresh.Position := Positive (Natural'Max (1, Position));
      return Add (State, Fresh);
   end New_Glyph;

   function Parse_Expression
     (State : in out Parser_State;
      Grouped : Boolean;
      Stop_Environment : String := "";
      Stop_Separators : Boolean := True;
      Stop_Dollar : Boolean := False;
      Stop_At_Expression_Boundary : Boolean := False;
      Stop_CD_Start : Boolean := False;
      Stop_CD_Arrow : Character := Character'Val (0);
      Stop_Square : Boolean := False) return Node_Id;

   function Is_Environment_End
     (State : Parser_State; Name : String) return Boolean is
      pragma Unreferenced (Name);
   begin
      return Command_Is (State, "\end");
   end Is_Environment_End;

   function Parse_Array
     (State : in out Parser_State;
      Name : String;
      Start : Natural) return Node_Id;

   function Parse_CD (State : in out Parser_State; Start : Natural)
      return Node_Id;

   function Parse_Argument (State : in out Parser_State) return Node_Id;

   function Read_Raw_Argument
     (State : in out Parser_State) return String is
      Content : Unbounded_String;
      Level : Natural := 0;
      Grouped : Boolean;
      procedure Consume_Current is
         Text : constant String := To_String (State.Current.Lexeme);
      begin
         if Length (Content) + Text'Length > Max_Source_Bytes then
            Fail (State, "raw command argument limit exceeded");
         end if;
         Append (Content, Text);
         Math_Expander.No_Expand_Next (State.Cursor);
         Advance (State);
      end Consume_Current;
   begin
      while State.Current.Kind = Math_Tokens.Space_Token loop
         Math_Expander.No_Expand_Next (State.Cursor);
         Advance (State);
      end loop;
      if State.Current.Kind = Math_Tokens.End_Of_Input or else
        State.Current.Kind = Math_Tokens.Right_Group
      then
         Fail (State, "missing command argument");
      end if;
      Grouped := State.Current.Kind = Math_Tokens.Left_Group;
      if Grouped then
         Math_Expander.No_Expand_Next (State.Cursor);
         Advance (State);
         Level := 1;
      end if;
      loop
         if State.Current.Kind = Math_Tokens.End_Of_Input then
            Fail (State, "missing closing command argument");
         end if;
         if Grouped and then State.Current.Kind = Math_Tokens.Right_Group
         then
            Level := Level - 1;
            if Level = 0 then
               Advance (State);
               return To_String (Content);
            end if;
         elsif Grouped and then
           State.Current.Kind = Math_Tokens.Left_Group
         then
            Level := Level + 1;
         elsif not Grouped then
            Consume_Current;
            return To_String (Content);
         end if;
         Consume_Current;
      end loop;
   end Read_Raw_Argument;

   function Parse_Color
     (State : in out Parser_State; Color_Text : String; Start : Natural)
      return Color_Value
   is
   begin
      if Color_Text = "red" then return (1.0, 0.0, 0.0, 1.0);
      elsif Color_Text = "green" then return (0.0, 0.5, 0.0, 1.0);
      elsif Color_Text = "blue" then return (0.0, 0.0, 1.0, 1.0);
      elsif Color_Text = "black" then return (0.0, 0.0, 0.0, 1.0);
      elsif Color_Text = "white" then return (1.0, 1.0, 1.0, 1.0);
      elsif Color_Text = "orange" then return (1.0, 0.5, 0.0, 1.0);
      elsif Color_Text = "purple" then return (0.5, 0.0, 0.5, 1.0);
      elsif Color_Text = "gray" or else Color_Text = "grey" then
         return (0.5, 0.5, 0.5, 1.0);
      elsif Color_Text'Length = 7 and then
        Color_Text (Color_Text'First) = '#'
      then
         declare
            function Hex (C : Character) return Natural is
            begin
               if C in '0' .. '9' then
                  return Character'Pos (C) - Character'Pos ('0');
               elsif C in 'a' .. 'f' then
                  return Character'Pos (C) - Character'Pos ('a') + 10;
               elsif C in 'A' .. 'F' then
                  return Character'Pos (C) - Character'Pos ('A') + 10;
               else
                  Fail (State, "invalid color value", Start);
                  return 0;
               end if;
            end Hex;
            function Channel (Offset : Positive) return Long_Float is
            begin
               return Long_Float
                 (Hex (Color_Text (Color_Text'First + Offset)) * 16 +
                  Hex (Color_Text (Color_Text'First + Offset + 1))) / 255.0;
            end Channel;
         begin
            return (Channel (1), Channel (3), Channel (5), 1.0);
         end;
      else
         Fail (State, "unsupported color name", Start);
         return (others => <>);
      end if;
   end Parse_Color;

   function Read_Raw_Option
     (State : in out Parser_State) return String is
      Content : Unbounded_String;
      Depth : Natural := 0;
   begin
      Math_Expander.No_Expand_Next (State.Cursor);
      Advance (State);
      loop
         if State.Current.Kind = Math_Tokens.End_Of_Input then
            Fail (State, "missing closing command option");
         elsif Peek (State) = '[' then
            Depth := Depth + 1;
         elsif Peek (State) = ']' then
            if Depth = 0 then
               Advance (State);
               return To_String (Content);
            end if;
            Depth := Depth - 1;
         end if;
         if Length (Content) + Length (State.Current.Lexeme) >
           Max_Source_Bytes
         then
            Fail (State, "raw command option limit exceeded");
         end if;
         Append (Content, To_String (State.Current.Lexeme));
         Math_Expander.No_Expand_Next (State.Cursor);
         Advance (State);
      end loop;
   end Read_Raw_Option;

   function Literal_Command
     (State : in out Parser_State;
      Name : String;
      Position : Natural) return Node_Id is
      Row : Node;
      Row_Id : Node_Id;
      Glyph_Id : Node_Id;
   begin
      Row.Kind := Row_Node;
      Row.Position := Positive (Position);
      Row_Id := Add (State, Row);
      for Index in Name'Range loop
         Glyph_Id := New_Glyph
           (State, Character'Pos (Name (Index)), Ordinary, Main_Regular,
            Position);
         Link (State, Row_Id, Glyph_Id);
      end loop;
      return Row_Id;
   end Literal_Command;

   function Text_Accent_Codepoint (Name : String) return Natural is
   begin
      if Name = "\r" then
         return 16#02DA#;
      elsif Name'Length = 2 and then
        Name (Name'First + 1) = Character'Val (34)
      then
         return 16#00A8#;
      elsif Name = "\`" then
         return 16#02CB#;
      elsif Name = "\'" then
         return 16#02CA#;
      elsif Name = "\^" then
         return 16#02C6#;
      elsif Name = "\~" then
         return 16#02DC#;
      elsif Name = "\=" then
         return 16#02C9#;
      elsif Name = "\." then
         return 16#02D9#;
      elsif Name = "\u" then
         return 16#02D8#;
      elsif Name = "\v" then
         return 16#02C7#;
      elsif Name = "\c" then
         return 16#00B8#;
      elsif Name = "\H" then
         return 16#02DD#;
      else
         return 0;
      end if;
   end Text_Accent_Codepoint;

   function Read_Command (State : in out Parser_State) return String is
      Text : constant String := To_String (State.Current.Lexeme);
   begin
      if Text in "\text" | "\mathrm" | "\emph" |
        "\textbf" | "\textit" | "\textmd" | "\textnormal" |
        "\textrm" | "\textsf" | "\texttt" | "\textup"
      then
         Math_Expander.Set_Mode (State.Cursor, True);
      end if;
      if State.Current.Kind not in Math_Tokens.Control_Word |
        Math_Tokens.Control_Symbol or else Text'Length < 2
      then
         Fail (State, "expected command");
      end if;
      if Text = "\href" or else Text = "\url" or else
        Text = "\includegraphics" or else Text = "\htmlClass" or else
        Text = "\htmlId" or else Text = "\htmlStyle" or else
        Text = "\htmlData"
      then
         Math_Expander.No_Expand_Next (State.Cursor);
      end if;
      Advance (State);
      return Text (Text'First + 1 .. Text'Last);
   end Read_Command;

   function Parse_Dimension_String
     (State : in out Parser_State; Text : String) return Long_Float;

   function Read_Dimension (State : in out Parser_State) return Long_Float is
      Text : Unbounded_String;
      function Complete_Unit return Boolean is
         Value : constant String := To_String (Text);
      begin
         return Value'Length >= 3 and then
           Value (Value'Last - 1 .. Value'Last) in
             "em" | "ex" | "mu" | "pt" | "cm" | "mm" | "in" |
             "bp" | "pc" | "dd" | "cc" | "nd" | "nc" | "sp";
      end Complete_Unit;
   begin
      Skip_Whitespace (State);
      if State.Current.Kind = Math_Tokens.Left_Group then
         return Parse_Dimension_String (State, Read_Raw_Argument (State));
      end if;
      loop
         exit when State.Current.Kind = Math_Tokens.End_Of_Input;
         exit when Complete_Unit;
         if State.Current.Kind in Math_Tokens.Control_Word |
           Math_Tokens.Control_Symbol
         then
            declare
               Candidate : constant String := To_String (Text) &
                 To_String (State.Current.Lexeme);
               Candidate_Split : Natural := Candidate'First;
            begin
               while Candidate_Split <= Candidate'Last and then
                 Candidate (Candidate_Split) in '0' .. '9' | '+' |
                   '-' | '.'
               loop
                  Candidate_Split := Candidate_Split + 1;
               end loop;
               exit when Candidate_Split = Candidate'First or else
                 Candidate'Last - Candidate_Split + 1 /= 2;
               Append (Text, To_String (State.Current.Lexeme));
               Advance (State);
            end;
         elsif State.Current.Kind = Math_Tokens.Space_Token or else
           State.Current.Kind in Math_Tokens.Left_Group |
             Math_Tokens.Right_Group
         then
            exit;
         else
            Append (Text, To_String (State.Current.Lexeme));
            Advance (State);
         end if;
      end loop;
      return Parse_Dimension_String (State, To_String (Text));
   end Read_Dimension;

   function Parse_Dimension_String
     (State : in out Parser_State; Text : String) return Long_Float is
      Split : Natural := Text'First;
      Number : Long_Float;
      Unit : String (1 .. 2);
      Factor : Long_Float;
      Value : Long_Float;
      Normalized_Number : Unbounded_String;
      Number_First : Natural;
   begin
      while Split <= Text'Last and then
        Text (Split) in '0' .. '9' | '+' | '-' | '.'
      loop
         Split := Split + 1;
      end loop;
      if Split = Text'First or else Split > Text'Last or else
        Text'Last - Split + 1 /= 2
      then
         Fail (State, "invalid dimension");
      end if;
      Number_First := Text'First;
      if Text (Number_First) in '+' | '-' then
         Append (Normalized_Number, Text (Number_First));
         Number_First := Number_First + 1;
      end if;
      if Number_First <= Split - 1 and then
        Text (Number_First) = '.'
      then
         Append (Normalized_Number, '0');
      end if;
      Append
        (Normalized_Number,
         Text (Number_First .. Split - 1));
      begin
         Number := Long_Float'Value
           (if Length (Normalized_Number) > 0
            then To_String (Normalized_Number)
            else Text (Text'First .. Split - 1));
      exception
         when Constraint_Error => Fail (State, "invalid dimension");
      end;
      Unit := Text (Split .. Text'Last);
      if Unit = "em" then Factor := 1.0;
      elsif Unit = "ex" then Factor := 0.431;
      elsif Unit = "mu" then Factor := 1.0 / 18.0;
      elsif Unit = "pt" then Factor := 0.1;
      elsif Unit = "cm" then Factor := 2.845_276;
      elsif Unit = "mm" then Factor := 0.284_528;
      elsif Unit = "in" then Factor := 7.227;
      elsif Unit = "bp" then Factor := (72.27 / 72.0) / 10.0;
      elsif Unit = "pc" then Factor := 1.2;
      elsif Unit = "dd" then Factor := (1_238.0 / 1_157.0) / 10.0;
      elsif Unit = "cc" then Factor := (14_856.0 / 1_157.0) / 10.0;
      elsif Unit = "nd" then Factor := (685.0 / 642.0) / 10.0;
      elsif Unit = "nc" then Factor := (1_370.0 / 107.0) / 10.0;
      elsif Unit = "sp" then Factor := 1.0 / 655_360.0;
      else
         Fail (State, "unsupported dimension unit");
         return 0.0;
      end if;
      if Number /= Number or else
        (Factor > 1.0 and then
         abs Number > Long_Float'Last / Factor)
      then
         Fail (State, "dimension must be finite");
      end if;
      Value := Number * Factor;
      if abs Value > 16_384.0 then
         Fail (State, "dimension exceeds bounded geometry");
      end if;
      if Value > 0.0 then
         return Long_Float'Min
           (Value, Long_Float (State.Settings.Max_Size));
      end if;
      return Value;
   end Parse_Dimension_String;

   function Delimiter_Of (Name : String) return Delimiter_Kind is
   begin
      if Name = "(" or else Name = "\lparen" then
         return Parenthesis_Delimiter;
      elsif Name = ")" or else Name = "\rparen" then
         return Parenthesis_Delimiter;
      elsif Name = "[" or else Name = "]" then
         return Bracket_Delimiter;
      elsif Name = "{" or else Name = "}" or else
        Name = "\{" or else Name = "\}"
      then
         return Brace_Delimiter;
      elsif Name in "\langle" | "\rangle" | "<" | ">" then
         return Angle_Delimiter;
      elsif Name in "\lfloor" | "\rfloor" then
         return Floor_Delimiter;
      elsif Name in "\lceil" | "\rceil" then
         return Ceiling_Delimiter;
      elsif Name = "|" or else Name = "\vert" then
         return Bar_Delimiter;
      elsif Name = "\|" or else Name = "\Vert" then
         return Double_Bar_Delimiter;
      elsif Name = "." then
         return No_Delimiter;
      else
         raise Parse_Failure with "unsupported delimiter: " & Name;
      end if;
   end Delimiter_Of;

   function Delimiter_Class (Name : String) return Atom_Class is
   begin
      if Name in "(" | "[" | "{" | "\\{" | "\lparen" |
        "\langle" | "<" | "\lfloor" | "\lceil" then
         return Opening;
      elsif Name in ")" | "]" | "}" | "\\}" | "\rparen" |
        "\rangle" | ">" | "\rfloor" | "\rceil" then
         return Closing;
      else
         return Ordinary;
      end if;
   end Delimiter_Class;

   function Profile_For (Point : Natural) return Script_Profile is
   begin
      if Point in 16#0100# .. 16#024F# or else Point in 16#1E00# .. 16#1EFF# then
         return Latin_Fallback;
      elsif Point in 16#0400# .. 16#052F# then
         return Cyrillic_Fallback;
      elsif Point in 16#0530# .. 16#058F# then
         return Armenian_Fallback;
      elsif Point in 16#10A0# .. 16#10FF# then
         return Georgian_Fallback;
      elsif Point in 16#0590# .. 16#05FF# then
         return Hebrew_Fallback;
      elsif Point in 16#0600# .. 16#08FF# then
         return Arabic_Fallback;
      elsif Point in 16#0900# .. 16#1CFF# or else
        Point in 16#A800# .. 16#ABFF#
      then
         return Indic_Fallback;
      elsif Point in 16#2E80# .. 16#9FFF# or else
        Point in 16#F900# .. 16#FAFF#
      then
         return CJK_Fallback;
      elsif Point in 16#AC00# .. 16#D7AF# then
         return Hangul_Fallback;
      elsif Point in 16#FF00# .. 16#FFEF# then
         return Fullwidth_Fallback;
      else
         return Other_Script_Fallback;
      end if;
   end Profile_For;

   function Parse_Atom (State : in out Parser_State) return Node_Id is
      Start : constant Natural := State.Cursor_Pos;
      Char : constant Character := Peek (State);
      Name : Unbounded_String;
      Point : Natural;
      Class : Atom_Class;
      Font : Font_Kind;
      Registry : Math_Symbols.Symbol_Record;
      Fresh : Node;
      Id : Node_Id;
   begin
      if State.Current.Kind = Math_Tokens.Verbatim_Token then
         Fresh.Kind := Verbatim_Node;
         Fresh.Class := Ordinary;
         Fresh.Font := Typewriter_Regular;
         Fresh.Verbatim_Text := State.Current.Lexeme;
         Fresh.Verbatim_Starred := State.Current.Verbatim_Starred;
         Fresh.Position := Positive (Start);
         Advance (State);
         return Add (State, Fresh);
      elsif State.Current.Kind = Math_Tokens.Character_Token and then
        State.Current.Text_First = Natural'Last
      then
         Point := Current_Code_Point (State);
         Advance (State);
         return New_Glyph (State, Point, Ordinary, Main_Regular, Start);
      elsif Char = '\' then
         Name := To_Unbounded_String (Read_Command (State));
         declare
            Word : constant String := To_String (Name);
         begin
            if Word in "tag" | "tag@literal" | "tag@paren" then
               declare
                  Literal : constant Boolean := Word = "tag@literal";
                  Content : constant Node_Id := Parse_Argument (State);
                  Tag_Node : Node;
               begin
                  if (not State.AMS_Row and then not State.Settings.Display_Mode) then
                     Fail (State, "tag command requires display mode", Start);
                  elsif State.Has_Tag or else State.Pending_Tag /= No_Node then
                     Fail (State, "duplicate equation tag", Start);
                  end if;
                  Tag_Node.Kind := Row_Node;
                  Tag_Node.First := Content;
                  Tag_Node.Position := Positive (Start);
                  if not Literal then
                     declare
                        Open : constant Node_Id := New_Glyph
                          (State, Character'Pos ('('), Opening, Main_Regular, Start);
                        Close : constant Node_Id := New_Glyph
                          (State, Character'Pos (')'), Closing, Main_Regular, Start);
                        Tag_Row : Node;
                        Tag_Row_Id : Node_Id;
                     begin
                        Tag_Row.Kind := Row_Node;
                        Tag_Row.Position := Positive (Start);
                        Tag_Row_Id := Add (State, Tag_Row);
                        Link (State, Tag_Row_Id, Open);
                        Link (State, Tag_Row_Id, Content);
                        Link (State, Tag_Row_Id, Close);
                        State.Pending_Tag := Tag_Row_Id;
                     end;
                  else
                     State.Pending_Tag := Content;
                  end if;
                  State.Has_Tag := True;
                  Fresh.Kind := Space_Node;
                  Fresh.Position := Positive (Start);
                  return Add (State, Fresh);
               end;
            elsif Word in "notag" | "nonumber" then
               --  Outside AMS environments these commands are defined no-ops.
               if State.AMS_Row then
                  if State.Has_Tag then
                     Fail (State, "tag command conflicts with tag suppression", Start);
                  end if;
                  State.Has_Tag := True;
               end if;
               Fresh.Kind := Space_Node;
               Fresh.Position := Positive (Start);
               return Add (State, Fresh);
            elsif Word = "\" or else Word = "newline" then
               Fresh.Kind := Space_Node;
               if Word = "\" then
                  Fresh.Code_Point := 7;
                  Fresh.Break := Forced_Break;
                  if Peek (State) = '[' then
                     declare
                        Margin : constant Long_Float := Parse_Dimension_String
                          (State, Read_Raw_Option (State));
                     begin
                        Fresh.Amount := Margin;
                     end;
                  end if;
               end if;
               Fresh.Position := Positive (Start);
               return Add (State, Fresh);
            elsif Word = "relax" then
               Fresh.Kind := Space_Node;
               Fresh.Amount := 0.0;
               Fresh.Position := Positive (Start);
               return Add (State, Fresh);
            elsif Word = "space" then
               Fresh.Kind := Space_Node;
               Fresh.Amount := 0.333;
               Fresh.Break := Forbid_Break;
               Fresh.Position := Positive (Start);
               return Add (State, Fresh);
            elsif Word in "cdleft" | "cdright" | "cdparent" |
              "\cdleft" | "\cdright" | "\cdparent"
            then
               declare
                  Content : constant Node_Id := Parse_Argument (State);
               begin
                  if Word in "cdleft" | "cdright" |
                    "\cdleft" | "\cdright"
                  then
                     Fresh.Kind := Style_Node;
                     Fresh.Math_Style := Script_Style;
                  else
                     Fresh.Kind := Row_Node;
                  end if;
                  Fresh.Stretchy_Name := To_Unbounded_String (Word);
                  Fresh.First := Content;
                  Fresh.Position := Positive (Start);
                  return Add (State, Fresh);
               end;
            elsif Word in "cdleftarrow" | "cdrightarrow" |
              "cdlongequal" | "\cdleftarrow" | "\cdrightarrow" |
              "\cdlongequal"
            then
               declare
                  Below : Node_Id := No_Node;
                  Above : Node_Id;
               begin
                  Skip_Whitespace (State);
                  if Peek (State) = '[' then
                     Advance (State);
                     Below := Parse_Expression
                       (State, True, Stop_Square => True);
                     if Peek (State) /= ']' then
                        Fail (State, "missing CD lower label", Start);
                     end if;
                     Advance (State);
                  end if;
                  Above := Parse_Argument (State);
                  Fresh.Kind := Stretchy_Node;
                  Fresh.Stretchy_Name := To_Unbounded_String
                    (if Word (Word'First) = '\'
                     then Word (Word'First + 1 .. Word'Last)
                     else Word);
                  Fresh.First := Above;
                  Fresh.Second := Below;
                  Fresh.Code_Point := 1;
                  Fresh.Position := Positive (Start);
                  return Add (State, Fresh);
               end;
            elsif Word in "hskip" | "kern" | "mkern" | "mskip" then
               declare
                  Space : constant Long_Float := Read_Dimension (State);
               begin
                  Fresh.Kind := Space_Node;
                  Fresh.Amount := Space;
                  Fresh.Position := Positive (Start);
                  return Add (State, Fresh);
               end;
            elsif Word in "mathrel" | "mathord" | "mathbin" |
              "mathop" | "mathopen" | "mathclose" | "mathpunct" |
              "mathinner"
            then
               declare
                  Content : constant Node_Id := Parse_Argument (State);
                  Wrapper : Node;
               begin
                  Wrapper.Kind := Row_Node;
                  Wrapper.First := Content;
                  Wrapper.Class :=
                    (if Word = "mathrel" then Relation_Atom
                     elsif Word = "mathord" then Ordinary
                     elsif Word = "mathbin" then Binary_Atom
                     elsif Word = "mathop" then Operator_Atom
                     elsif Word = "mathopen" then Opening
                     elsif Word = "mathclose" then Closing
                     elsif Word = "mathpunct" then Punctuation
                     else Inner);
                  Wrapper.Position := Positive (Start);
                  return Add (State, Wrapper);
               end;
            elsif Word = "html@mathml" then
               declare
                  Visual : constant Node_Id := Parse_Argument (State);
                  Semantic : constant Node_Id := Parse_Argument (State);
               begin
                  Fresh.Kind := Dual_Node;
                  Fresh.First := Visual;
                  Fresh.Second := Semantic;
                  Fresh.Dual_Type := Visual_First;
                  Fresh.Position := Positive (Start);
                  return Add (State, Fresh);
               end;
            elsif Word = "mathchoice" then
               Fresh.Kind := MathChoice_Node;
               Fresh.First := Parse_Argument (State);
               Fresh.Second := Parse_Argument (State);
               Fresh.Third := Parse_Argument (State);
               Fresh.Fourth := Parse_Argument (State);
               Fresh.Position := Positive (Start);
               return Add (State, Fresh);
            elsif Word = "vcenter" then
               if State.Regular_Mode then
                  Fail (State, "\\vcenter is only valid in math mode", Start);
               end if;
               Fresh.Kind := VCenter_Node;
               Fresh.First := Parse_Argument (State);
               Fresh.Position := Positive (Start);
               return Add (State, Fresh);
            elsif Word = "pmb" then
               declare
                  Content : constant Node_Id := Parse_Argument (State);
                  Base : Math_Syntax.Node :=
                    State.Item.Nodes (Positive (Content));
               begin
                  if Base.Kind = Scripts_Node and then Base.First /= No_Node then
                     Base := State.Item.Nodes (Positive (Base.First));
                  end if;
                  if Base.Kind = Row_Node and then Base.First /= No_Node then
                     Base := State.Item.Nodes (Positive (Base.First));
                  end if;
                  Fresh.Kind := Poor_Bold_Node;
                  Fresh.First := Content;
                  Fresh.Class :=
                    (if Base.Class in Binary_Atom | Relation_Atom
                     then Base.Class else Ordinary);
                  Fresh.Poor_Bold_Class := Fresh.Class;
                  Fresh.Position := Positive (Start);
                  return Add (State, Fresh);
               end;
            elsif Word = "hbox" then
               declare
                  Old_Mode : constant Boolean := State.Regular_Mode;
                  Old_Dollar_Mode : constant Boolean :=
                    State.Dollar_Math_Allowed;
                  Content : Node_Id;
               begin
                  State.Regular_Mode := True;
                  State.Dollar_Math_Allowed := True;
                  Content := Parse_Argument (State);
                  State.Regular_Mode := Old_Mode;
                  State.Dollar_Math_Allowed := Old_Dollar_Mode;
                  Fresh.Kind := Row_Node;
                  Fresh.First := Content;
                  Fresh.Position := Positive (Start);
                  return Add (State, Fresh);
               exception
                  when Parse_Failure =>
                     State.Regular_Mode := Old_Mode;
                     State.Dollar_Math_Allowed := Old_Dollar_Mode;
                     raise;
               end;
            elsif Word = "not" then
               declare
                  Base : constant Node_Id := Parse_Atom (State);
                  Base_Node : constant Node := State.Item.Nodes
                    (Positive (Base));
               begin
                  if Base_Node.Class /= Relation_Atom then
                     Fail (State, "\\not requires a relation atom", Start);
                  end if;
                  Fresh.Kind := Overlay_Node;
                  Fresh.First := Base;
                  Fresh.Second := New_Glyph
                    (State, Character'Pos ('/'), Ordinary, Main_Regular, Start);
                  Fresh.Class := Relation_Atom;
                  Fresh.Position := Positive (Start);
                  return Add (State, Fresh);
               end;
            elsif Word in "mathrlap" | "mathllap" | "mathclap" |
              "rlap" | "llap" | "clap"
            then
               Fresh.Kind := Overlap_Node;
               Fresh.First := Parse_Argument (State);
               Fresh.Overlap_Mode :=
                 (if Word in "mathllap" | "llap" then Left_Overlap
                  elsif Word in "mathclap" | "clap" then Center_Overlap
                  else Right_Overlap);
               Fresh.Position := Positive (Start);
               return Add (State, Fresh);
            elsif Word in "operatorname" | "operatorname@" |
              "operatornamewithlimits" or else
              (Word = "operatorname" and then Peek (State) = '*')
            then
               declare
                  Old_Mode : constant Boolean := State.Regular_Mode;
                  Old_Font : constant Font_Kind := State.Font_Mode;
                  Old_Has_Font : constant Boolean := State.Has_Font_Mode;
                  Op_Id : Node_Id;
                  Op_Row : Node;
                  Has_Limits : constant Boolean :=
                    Word = "operatornamewithlimits" or else
                    (Word = "operatorname" and then Peek (State) = '*');
               begin
                  if Peek (State) = '*' then
                     Advance (State);
                  end if;
                  State.Regular_Mode := True;
                  State.Has_Font_Mode := True;
                  State.Font_Mode := Main_Regular;
                  Op_Id := Parse_Argument (State);
                  State.Regular_Mode := Old_Mode;
                  State.Font_Mode := Old_Font;
                  State.Has_Font_Mode := Old_Has_Font;
                  Op_Row.Kind := Row_Node;
                  Op_Row.Class := Operator_Atom;
                  Op_Row.Position := Positive (Start);
                  Op_Row.First := Op_Id;
                  if Has_Limits then
                     Op_Row.Code_Point := 1;
                  end if;
                  return Add (State, Op_Row);
               exception
                  when Parse_Failure =>
                     State.Regular_Mode := Old_Mode;
                     State.Font_Mode := Old_Font;
                     State.Has_Font_Mode := Old_Has_Font;
                     raise;
               end;
            elsif Word = "@" then
               if Peek (State) = 'n' then
                  if Peek (State) /= 'n' then
                     Fail (State, "unsupported control symbol: \\@", Start);
                  end if;
                  Advance (State);
                  if Peek (State) /= 'o' then
                     Fail (State, "unsupported control symbol: \\@", Start);
                  end if;
                  Advance (State);
                  if Peek (State) /= 't' then
                     Fail (State, "unsupported control symbol: \\@", Start);
                  end if;
                  Advance (State);
                  return New_Glyph
                    (State, 16#338#, Relation_Atom, Main_Regular, Start);
               else
                  Fail (State, "unsupported control symbol: \\@", Start);
               end if;
            elsif Word = "char" then
               declare
                  Code : constant Natural := Current_Code_Point (State);
               begin
                  Advance (State);
                  return New_Glyph
                    (State, Code, Ordinary, Main_Regular, Start);
               end;
            elsif Word in "big" | "Big" | "bigg" | "Bigg" |
              "bigl" | "Bigl" | "biggl" | "Biggl" |
              "bigr" | "Bigr" | "biggr" | "Biggr" |
              "bigm" | "Bigm" | "biggm" | "Biggm"
            then
               declare
                  Delimiter_Command : Unbounded_String;
                  Delimiter_Name : Unbounded_String;
                  Delimiter_Kind_Value : Delimiter_Kind;
                  Delimiter_Size : constant Long_Float :=
                    (if Word in "big" | "bigl" | "bigr" | "bigm" then 1.2
                     elsif Word in "Big" | "Bigl" | "Bigr" | "Bigm" then 1.8
                     elsif Word in "bigg" | "biggl" | "biggr" | "biggm"
                       then 2.4
                     else 3.0);
               begin
                  if Peek (State) = '\' then
                     Delimiter_Command := To_Unbounded_String
                       ("\" & Read_Command (State));
                  elsif Peek (State) in '(' | ')' | '[' | ']' | '{' | '}' |
                    '|' | '<' | '>'
                  then
                     Delimiter_Command := To_Unbounded_String
                       (String'(1 => Peek (State)));
                     Advance (State);
                  else
                     Fail (State, "missing delimiter after sizing command", Start);
                  end if;
                  Delimiter_Name := Delimiter_Command;
                  begin
                     Delimiter_Kind_Value := Delimiter_Of
                       (To_String (Delimiter_Name));
                  exception
                     when Parse_Failure =>
                        Fail (State, "unsupported sized delimiter", Start);
                  end;
                  Fresh.Kind := Delimited_Node;
                  Fresh.Class := Delimiter_Class
                    (To_String (Delimiter_Name));
                  Fresh.Code_Point :=
                    (if Word in "big" | "Big" | "bigg" | "Bigg" then 1
                     elsif Word in "bigl" | "Bigl" | "biggl" | "Biggl" then 2
                     elsif Word in "bigr" | "Bigr" | "biggr" | "Biggr" then 3
                     else 4);
                  Fresh.Amount := Delimiter_Size;
                  Fresh.Left_Delimiter := Delimiter_Kind_Value;
                  Fresh.Position := Positive (Start);
                  return Add (State, Fresh);
               end;
            elsif Word = "middle" then
               declare
                  Delimiter_Command : Unbounded_String;
                  Delimiter_Kind_Value : Delimiter_Kind;
               begin
                  if Peek (State) = '\' then
                     Delimiter_Command := To_Unbounded_String
                       ("\" & Read_Command (State));
                  elsif Peek (State) in '(' | ')' | '[' | ']' | '{' | '}' |
                    '|' | '<' | '>'
                  then
                     Delimiter_Command := To_Unbounded_String
                       (String'(1 => Peek (State)));
                     Advance (State);
                  else
                     Fail (State, "missing delimiter after middle", Start);
                  end if;
                  begin
                     Delimiter_Kind_Value := Delimiter_Of
                       (To_String (Delimiter_Command));
                  exception
                     when Parse_Failure =>
                        Fail (State, "unsupported middle delimiter", Start);
                  end;
                  if Delimiter_Kind_Value = No_Delimiter then
                     Fail (State, "invisible middle delimiter", Start);
                  end if;
                  Fresh.Kind := Delimited_Node;
                  Fresh.Code_Point := 4;
                  Fresh.Amount := 1.0;
                  Fresh.Left_Delimiter := Delimiter_Kind_Value;
                  Fresh.Position := Positive (Start);
                  return Add (State, Fresh);
               end;
            elsif Word = "left" then
               declare
                  Left_Command : Unbounded_String;
                  Left_Kind : Delimiter_Kind;
                  Inner : Node_Id;
                  Right_Command : Unbounded_String;
                  Right_Kind : Delimiter_Kind;
               begin
                  if Peek (State) = '\' then
                     Left_Command := To_Unbounded_String
                       ("\" & Read_Command (State));
                  else
                     Left_Command := To_Unbounded_String
                       (String'(1 => Peek (State)));
                     Advance (State);
                  end if;
                  begin
                     Left_Kind := Delimiter_Of (To_String (Left_Command));
                  exception
                     when Parse_Failure =>
                        Fail (State, "unsupported left delimiter", Start);
                  end;
                  Inner := Parse_Expression (State, False, "", False);
                  if Peek (State) /= '\' or else
                    Read_Command (State) /= "right"
                  then
                     Fail (State, "missing right delimiter", Start);
                  end if;
                  if Peek (State) = '\' then
                     Right_Command := To_Unbounded_String
                       ("\" & Read_Command (State));
                  else
                     Right_Command := To_Unbounded_String
                       (String'(1 => Peek (State)));
                     Advance (State);
                  end if;
                  begin
                     Right_Kind := Delimiter_Of (To_String (Right_Command));
                  exception
                     when Parse_Failure =>
                        Fail (State, "unsupported right delimiter", Start);
                  end;
                  if Inner = No_Node then
                     Fail (State, "empty left/right expression", Start);
                  end if;
                  Fresh.Kind := Delimited_Node;
                  Fresh.First := Inner;
                  Fresh.Left_Delimiter := Left_Kind;
                  Fresh.Right_Delimiter := Right_Kind;
                  Fresh.Position := Positive (Start);
                  return Add (State, Fresh);
               end;
            elsif Word = "begin" then
               Skip_Whitespace (State);
               if Peek (State) /= '{' then
                  Fail (State, "missing environment name", Start);
               end if;
               Advance (State);
               declare
                  Env_Name : Unbounded_String;
               begin
                  while Peek (State) in 'A' .. 'Z' | 'a' .. 'z' loop
                     Append (Env_Name, Peek (State));
                     Advance (State);
                  end loop;
                  if Peek (State) = '*' then
                     Append (Env_Name, '*');
                     Advance (State);
                  end if;
                  if Peek (State) /= '}' or else Length (Env_Name) = 0 then
                     Fail (State, "invalid environment name", Start);
                  end if;
                  Math_Macros.Begin_Group (State.Shared.all);
                  Advance (State);
                  declare
                     Result : constant Node_Id :=
                       (if To_String (Env_Name) = "CD"
                        then Parse_CD (State, Start)
                        else Parse_Array
                          (State, To_String (Env_Name), Start));
                  begin
                     return Result;
                  end;
               end;
            elsif Word in "frac" | "dfrac" | "tfrac" | "cfrac" then
               declare
                  Alignment_Text : Unbounded_String;
                  Numerator : Node_Id;
                  Denom : Node_Id;
               begin
                  if Word = "cfrac" and then Peek (State) = '[' then
                     Alignment_Text := To_Unbounded_String
                       (Read_Raw_Option (State));
                  end if;
                  if Length (Alignment_Text) > 0 and then
                    To_String (Alignment_Text) not in "l" | "r"
                  then
                     Fail (State, "invalid cfrac alignment", Start);
                  end if;
                  Numerator := Parse_Argument (State);
                  Denom := Parse_Argument (State);
                  Fresh.Kind := Fraction_Node;
                  Fresh.First := Numerator;
                  Fresh.Second := Denom;
                  Fresh.Fraction_Type :=
                    (if Word = "dfrac" or else Word = "cfrac"
                     then Display_Fraction
                     elsif Word = "tfrac" then Text_Fraction
                     else Default_Fraction);
                  Fresh.Fraction_Continued := Word = "cfrac";
                  Fresh.Fraction_Alignment_Mode :=
                    (if To_String (Alignment_Text) = "l" then Left_Fraction
                     elsif To_String (Alignment_Text) = "r" then Right_Fraction
                     else Center_Fraction);
                  Fresh.Fraction_Style_Mode :=
                    (if Word = "cfrac" then Display_Style
                     else Natural_Style);
                  Fresh.Position := Positive (Start);
                  return Add (State, Fresh);
               end;
            elsif Word = "\abovefrac" then
               declare
                  Numerator : constant Node_Id := Parse_Argument (State);
                  Thickness : constant Long_Float :=
                    Parse_Dimension_String (State, Read_Raw_Argument (State));
                  Denom : constant Node_Id := Parse_Argument (State);
               begin
                  Fresh.Kind := Fraction_Node;
                  Fresh.First := Numerator;
                  Fresh.Second := Denom;
                  Fresh.Fraction_Bar :=
                    (if Thickness > 0.0 then Custom_Rule else No_Rule);
                  Fresh.Fraction_Rule_Thickness := Thickness;
                  Fresh.Position := Positive (Start);
                  return Add (State, Fresh);
               end;
            elsif Word in "\atopfrac" | "\bracefrac" |
              "\brackfrac"
            then
               declare
                  Numerator : constant Node_Id := Parse_Argument (State);
                  Denom : constant Node_Id := Parse_Argument (State);
               begin
                  Fresh.Kind := Fraction_Node;
                  Fresh.First := Numerator;
                  Fresh.Second := Denom;
                  Fresh.Fraction_Bar := No_Rule;
                  if Word = "\bracefrac" then
                     Fresh.Left_Delimiter := Brace_Delimiter;
                     Fresh.Right_Delimiter := Brace_Delimiter;
                  elsif Word = "\brackfrac" then
                     Fresh.Left_Delimiter := Bracket_Delimiter;
                     Fresh.Right_Delimiter := Bracket_Delimiter;
                  end if;
                  Fresh.Position := Positive (Start);
                  return Add (State, Fresh);
               end;
            elsif Word = "genfrac" then
               declare
                  Left_Text : constant String := Read_Raw_Argument (State);
                  Right_Text : constant String := Read_Raw_Argument (State);
                  Size_Text : constant String := Read_Raw_Argument (State);
                  Style_Text : constant String := Read_Raw_Argument (State);
                  Thickness : Long_Float := -1.0;
                  Has_Size : constant Boolean := Size_Text'Length > 0;
                  Style : Math_Style_Kind := Natural_Style;
                  Left_Kind : Delimiter_Kind := No_Delimiter;
                  Right_Kind : Delimiter_Kind := No_Delimiter;
                  Numerator : constant Node_Id := Parse_Argument (State);
                  Denom : constant Node_Id := Parse_Argument (State);
               begin
                  if Left_Text'Length > 0 then
                     Left_Kind := Delimiter_Of (Left_Text);
                  end if;
                  if Right_Text'Length > 0 then
                     Right_Kind := Delimiter_Of (Right_Text);
                  end if;
                  if Has_Size then
                     Thickness := Parse_Dimension_String (State, Size_Text);
                  end if;
                  if Style_Text'Length > 0 then
                     if Style_Text not in "0" | "1" | "2" | "3" then
                        Fail (State, "invalid genfrac style", Start);
                     end if;
                     Style := (case Style_Text (Style_Text'First) is
                       when '0' => Display_Style,
                       when '1' => Text_Style,
                       when '2' => Script_Style,
                       when others => Script_Script_Style);
                  end if;
                  Fresh.Kind := Fraction_Node;
                  Fresh.First := Numerator;
                  Fresh.Second := Denom;
                  Fresh.Fraction_Bar :=
                    (if not Has_Size then Default_Rule
                     elsif Thickness > 0.0 then Custom_Rule
                     else No_Rule);
                  Fresh.Fraction_Rule_Thickness := Thickness;
                  Fresh.Fraction_Type :=
                    (if Style = Display_Style then Display_Fraction
                     elsif Style = Text_Style then Text_Fraction
                     else Default_Fraction);
                  Fresh.Fraction_Style_Mode := Style;
                  Fresh.Left_Delimiter := Left_Kind;
                  Fresh.Right_Delimiter := Right_Kind;
                  Fresh.Position := Positive (Start);
                  return Add (State, Fresh);
               end;
            elsif Word in "over" | "choose" | "atop" | "brace" |
              "brack" | "above"
            then
               declare
                  Marker_Node : Node;
               begin
                  Marker_Node.Kind := Space_Node;
                  Marker_Node.Code_Point :=
                    (if Word = "over" then 1 elsif Word = "choose" then 2
                     elsif Word = "atop" then 3 elsif Word = "brace" then 4
                     elsif Word = "brack" then 5 else 6);
                  Marker_Node.Position := Positive (Start);
                  if Word = "above" then
                     if Peek (State) = '{' then
                        declare
                           Raw_Size : constant String :=
                             Read_Raw_Argument (State);
                        begin
                           Marker_Node.Amount :=
                             (if Raw_Size'Length = 0 then 0.0
                              else Parse_Dimension_String (State, Raw_Size));
                        end;
                     else
                        Marker_Node.Amount := Read_Dimension (State);
                     end if;
                  end if;
                  return Add (State, Marker_Node);
               end;
            elsif Word in "binom" | "dbinom" | "tbinom" then
               declare
                  Top : constant Node_Id := Parse_Argument (State);
                  Bottom : constant Node_Id := Parse_Argument (State);
               begin
                  Fresh.Kind := Binomial_Node;
                  Fresh.First := Top;
                  Fresh.Second := Bottom;
                  Fresh.Math_Style :=
                    (if Word = "dbinom" then Display_Style
                     elsif Word = "tbinom" then Text_Style
                     else Natural_Style);
                  Fresh.Left_Delimiter := Parenthesis_Delimiter;
                  Fresh.Right_Delimiter := Parenthesis_Delimiter;
                  Fresh.Fraction_Bar := No_Rule;
                  Fresh.Fraction_Type :=
                    (if Fresh.Math_Style = Display_Style then Display_Fraction
                     elsif Fresh.Math_Style = Text_Style then Text_Fraction
                     else Default_Fraction);
                  Fresh.Fraction_Style_Mode := Fresh.Math_Style;
                  Fresh.Position := Positive (Start);
                  return Add (State, Fresh);
               end;
            elsif Word = "\@binrel" then
               declare
                  Class_Argument : constant Node_Id := Parse_Argument (State);
                  Body_Id : constant Node_Id := Parse_Argument (State);
                  Argument : Math_Syntax.Node :=
                    State.Item.Nodes (Positive (Class_Argument));
                  Body_Value : Math_Syntax.Node :=
                    State.Item.Nodes (Positive (Body_Id));
                  Class : Atom_Class := Ordinary;
               begin
                  if Argument.Class in Binary_Atom | Relation_Atom then
                     Class := Argument.Class;
                  elsif Argument.Kind = Row_Node and then
                    Argument.First /= No_Node
                  then
                     Argument := State.Item.Nodes
                       (Positive (Argument.First));
                     if Argument.Class in Binary_Atom | Relation_Atom then
                        Class := Argument.Class;
                     end if;
                  end if;
                  Body_Value.Class := Class;
                  State.Item.Nodes.Replace_Element
                    (Positive (Body_Id), Body_Value);
                  return Body_Id;
               end;
            elsif Word in "stackrel" | "overset" | "underset" then
               declare
                  Annotation : constant Node_Id := Parse_Argument (State);
                  Base : constant Node_Id := Parse_Argument (State);
                  Base_Atom : Math_Syntax.Node :=
                    State.Item.Nodes (Positive (Base));
                  Is_Stackrel : constant Boolean := Word = "stackrel";
               begin
                  if Base_Atom.Kind = Row_Node and then
                    Base_Atom.First /= No_Node
                  then
                     Base_Atom := State.Item.Nodes
                       (Positive (Base_Atom.First));
                  end if;
                  Fresh.Kind := Annotation_Node;
                  Fresh.Class :=
                    (if Is_Stackrel then Relation_Atom
                     elsif Base_Atom.Class = Binary_Atom then Binary_Atom
                     elsif Base_Atom.Class = Relation_Atom then Relation_Atom
                     else Ordinary);
                  Fresh.First := Base;
                  Fresh.Second := Annotation;
                  Fresh.Annotation_Type :=
                    (if Word = "underset" then Under_Annotation
                     else Over_Annotation);
                  Fresh.Code_Point := 1;
                  Fresh.Position := Positive (Start);
                  return Add (State, Fresh);
               end;
            elsif Word in "overbrace" | "underbrace" then
               Fresh.Kind := Accent_Node;
               Fresh.First := Parse_Argument (State);
               Fresh.Code_Point :=
                 (if Word = "overbrace" then Over_Brace_Code_Point
                  else Under_Brace_Code_Point);
               Fresh.Position := Positive (Start);
               return Add (State, Fresh);
            elsif Word in "overrightarrow" | "overleftarrow" then
               Fresh.Kind := Accent_Node;
               Fresh.First := Parse_Argument (State);
               Fresh.Code_Point :=
                 (if Word = "overrightarrow" then Over_Right_Arrow_Code_Point
                  else Over_Left_Arrow_Code_Point);
               Fresh.Position := Positive (Start);
               return Add (State, Fresh);
            elsif Is_Stretchy_Command (Word) then
               declare
                  Is_Labelled : constant Boolean :=
                    Command_Is_Labelled_Arrow (Word);
                  Is_Accent : constant Boolean :=
                    Word in
                      "Overrightarrow" | "overleftharpoon" |
                      "overrightharpoon" | "underleftarrow" |
                      "underrightarrow" | "overleftrightarrow" |
                      "underleftrightarrow" | "overlinesegment" |
                      "underlinesegment" | "overgroup" | "undergroup";
                  Above : Node_Id := No_Node;
                  Below : Node_Id := No_Node;
               begin
                  if Is_Accent then
                     Above := Parse_Argument (State);
                  else
                     if Is_Labelled and then Peek (State) = '[' then
                        Advance (State);
                        Below := Parse_Expression (State, True, Stop_Square => True);
                        if Peek (State) /= ']' then
                           Fail
                             (State, "missing closing arrow label", Start);
                        end if;
                        Advance (State);
                     end if;
                     Above := Parse_Argument (State);
                     if Is_Labelled and then Peek (State) = '[' then
                        Advance (State);
                        Below := Parse_Expression (State, True, Stop_Square => True);
                        if Peek (State) /= ']' then
                           Fail
                             (State, "missing closing arrow label", Start);
                        end if;
                        Advance (State);
                     end if;
                  end if;
                  Fresh.Kind := Stretchy_Node;
                  Fresh.First := Above;
                  Fresh.Second := Below;
                  Fresh.Stretchy_Name := To_Unbounded_String (Word);
                  Fresh.Annotation_Type :=
                    (if Word in "underleftarrow" | "underrightarrow" |
                       "underleftrightarrow" | "underlinesegment" |
                       "undergroup"
                     then Under_Annotation else Over_Annotation);
                  Fresh.Code_Point :=
                    (if Word = "widecheck" then Wide_Check_Code_Point
                     elsif Word = "utilde" then Under_Tilde_Code_Point
                     elsif Is_Labelled then 1 else 0);
                  if Word = "utilde" then
                     Fresh.Annotation_Type := Under_Annotation;
                  end if;
                  Fresh.Position := Positive (Start);
                  return Add (State, Fresh);
               end;
            elsif Word in "cancel" | "bcancel" | "xcancel" | "sout" |
              "phase" | "angl"
            then
               declare
                  Content : Node_Id;
               begin
                  if Word = "angl" then
                     declare
                        Old_Mode : constant Boolean := State.Regular_Mode;
                        Old_Font : constant Font_Kind := State.Font_Mode;
                        Old_Has_Font : constant Boolean := State.Has_Font_Mode;
                     begin
                        State.Regular_Mode := True;
                        State.Has_Font_Mode := True;
                        State.Font_Mode := Main_Regular;
                        Content := Parse_Argument (State);
                        State.Regular_Mode := Old_Mode;
                        State.Font_Mode := Old_Font;
                        State.Has_Font_Mode := Old_Has_Font;
                     exception
                        when others =>
                           State.Regular_Mode := Old_Mode;
                           State.Font_Mode := Old_Font;
                           State.Has_Font_Mode := Old_Has_Font;
                           raise;
                     end;
                  else
                     Content := Parse_Argument (State);
                  end if;
                  Fresh.Kind := Enclosed_Node;
                  Fresh.First := Content;
                  Fresh.Enclosure :=
                    (if Word = "bcancel" then BCancel_Enclosure
                     elsif Word = "xcancel" then XCancel_Enclosure
                     elsif Word = "sout" then Strike_Enclosure
                     elsif Word = "phase" then Phase_Enclosure
                     elsif Word = "angl" then Actuarial_Enclosure
                     else Cancel_Enclosure);
                  Fresh.Position := Positive (Start);
                  return Add (State, Fresh);
               end;
            elsif Word = "rule" then
               declare
                  Raise_By : Long_Float := 0.0;
                  Width_Value : Long_Float;
                  Height_Value : Long_Float;
               begin
                  Skip_Whitespace (State);
                  if Peek (State) = '[' then
                     declare
                        Raw_Raise : Unbounded_String;
                     begin
                        Advance (State);
                        while State.Current.Kind /= Math_Tokens.End_Of_Input and then
                          Peek (State) /= ']'
                        loop
                           Append (Raw_Raise, To_String (State.Current.Lexeme));
                           Advance (State);
                        end loop;
                        Raise_By := Parse_Dimension_String
                          (State, To_String (Raw_Raise));
                     end;
                     if Peek (State) /= ']' then
                        Fail (State, "missing rule raise bracket", Start);
                     end if;
                     Advance (State);
                  end if;
                  Width_Value := Read_Dimension (State);
                  Height_Value := Read_Dimension (State);
                  if Width_Value < 0.0 or else Height_Value < 0.0 then
                     Fail (State, "rule dimensions must be nonnegative", Start);
                  end if;
                  Fresh.Kind := Rule_Node;
                  Fresh.Width := Width_Value;
                  Fresh.Height := Height_Value;
                  Fresh.Amount := Raise_By;
                  Fresh.Position := Positive (Start);
                  return Add (State, Fresh);
               end;
            elsif Word = "raisebox" then
               declare
                  Shift : constant Long_Float := Read_Dimension (State);
                  Old_Dollar_Mode : constant Boolean :=
                    State.Dollar_Math_Allowed;
                  Content : Node_Id;
               begin
                  State.Dollar_Math_Allowed := True;
                  Content := Parse_Argument (State);
                  State.Dollar_Math_Allowed := Old_Dollar_Mode;
                  Fresh.Kind := Raised_Node;
                  Fresh.Amount := Shift;
                  Fresh.First := Content;
                  Fresh.Position := Positive (Start);
                  return Add (State, Fresh);
               exception
                  when Parse_Failure =>
                     State.Dollar_Math_Allowed := Old_Dollar_Mode;
                     raise;
               end;
            elsif Word in "tiny" | "sixptsize" | "scriptsize" |
              "footnotesize" | "small" | "normalsize" | "large" |
              "Large" | "LARGE" | "huge" | "Huge"
            then
               Fresh.Kind := Sized_Node;
               Fresh.Scale :=
                 (if Word = "tiny" then 0.5
                  elsif Word = "sixptsize" then 0.6
                  elsif Word = "scriptsize" then 0.7
                  elsif Word = "footnotesize" then 0.8
                  elsif Word = "small" then 0.9
                  elsif Word = "normalsize" then 1.0
                  elsif Word = "large" then 1.2
                  elsif Word = "Large" then 1.44
                  elsif Word = "LARGE" then 1.728
                  elsif Word = "huge" then 2.074
                  else 2.488);
               Fresh.First := Parse_Expression
                 (State, True, To_String (State.Environment_Stop), True,
                  Stop_Dollar => State.Dollar_Math_Allowed);
               Fresh.Position := Positive (Start);
               return Add (State, Fresh);
            elsif Word in "boxed" | "fbox" then
               declare
                  Old_Dollar_Mode : constant Boolean :=
                    State.Dollar_Math_Allowed;
               begin
                  State.Dollar_Math_Allowed := True;
                  Fresh.Kind := Boxed_Node;
                  Fresh.First := Parse_Argument (State);
                  State.Dollar_Math_Allowed := Old_Dollar_Mode;
                  Fresh.Position := Positive (Start);
                  return Add (State, Fresh);
               exception
                  when Parse_Failure =>
                     State.Dollar_Math_Allowed := Old_Dollar_Mode;
                     raise;
               end;
            elsif Word in "phantom" | "hphantom" | "vphantom" |
              "smash"
            then
               Fresh.Kind := Phantom_Node;
               Fresh.First := Parse_Argument (State);
               Fresh.Code_Point :=
                 (if Word = "hphantom" then 1
                  elsif Word = "vphantom" then 2
                  elsif Word = "smash" then 3 else 0);
               Fresh.Position := Positive (Start);
               return Add (State, Fresh);
            elsif Word in "colorbox" | "fcolorbox" then
               declare
                  Border : Color_Value := (others => <>);
                  Background : Color_Value;
                  Old_Mode : constant Boolean := State.Regular_Mode;
                  Old_Color_Box_Mode : constant Boolean := State.Color_Box_Mode;
                  Old_Font : constant Font_Kind := State.Font_Mode;
                  Old_Has_Font : constant Boolean := State.Has_Font_Mode;
                  Old_Dollar_Mode : constant Boolean :=
                    State.Dollar_Math_Allowed;
                  Content : Node_Id;
               begin
                  if Word = "fcolorbox" then
                     Border := Parse_Color
                       (State, Read_Raw_Argument (State), Start);
                     Background := Parse_Color
                       (State, Read_Raw_Argument (State), Start);
                  else
                     Background := Parse_Color
                       (State, Read_Raw_Argument (State), Start);
                  end if;
                  State.Regular_Mode := True;
                  State.Color_Box_Mode := True;
                  State.Has_Font_Mode := True;
                  State.Font_Mode := Main_Regular;
                  State.Dollar_Math_Allowed := True;
                  Content := Parse_Argument (State);
                  State.Regular_Mode := Old_Mode;
                  State.Color_Box_Mode := Old_Color_Box_Mode;
                  State.Font_Mode := Old_Font;
                  State.Has_Font_Mode := Old_Has_Font;
                  State.Dollar_Math_Allowed := Old_Dollar_Mode;
                  Fresh.Kind := Enclosed_Node;
                  Fresh.First := Content;
                  Fresh.Enclosure :=
                    (if Word = "fcolorbox" then Framed_Color_Box_Enclosure
                     else Color_Box_Enclosure);
                  Fresh.Box_Background := Background;
                  Fresh.Box_Border := Border;
                  Fresh.Box_Border_Thickness :=
                    (if Word = "fcolorbox" then 0.04 else 0.0);
                  Fresh.Position := Positive (Start);
                  return Add (State, Fresh);
               exception
                  when others =>
                     State.Regular_Mode := Old_Mode;
                     State.Color_Box_Mode := Old_Color_Box_Mode;
                     State.Font_Mode := Old_Font;
                     State.Has_Font_Mode := Old_Has_Font;
                     State.Dollar_Math_Allowed := Old_Dollar_Mode;
                     raise;
               end;
            elsif Word in "color" | "textcolor" then
               declare
                  Color_Text : constant String := Read_Raw_Argument (State);
                  Parsed_Color : constant Color_Value :=
                    Parse_Color (State, Color_Text, Start);
                  Content : constant Node_Id :=
                    (if Word = "color" and then
                       not State.Settings.Color_Is_Text_Color
                     then Parse_Expression
                       (State, True, To_String (State.Environment_Stop),
                        Stop_At_Expression_Boundary => True)
                     else Parse_Argument (State));
               begin
                  Fresh.Kind := Color_Node;
                  Fresh.First := Content;
                  Fresh.Color := Parsed_Color;
                  Fresh.Position := Positive (Start);
                  return Add (State, Fresh);
               end;
            elsif Word in "displaystyle" | "textstyle" | "scriptstyle" | "scriptscriptstyle" then
               Fresh.Kind := Style_Node;
               Fresh.First := Parse_Argument (State);
               Fresh.Math_Style :=
                 (if Word = "displaystyle" then Display_Style
                  elsif Word = "textstyle" then Text_Style
                  elsif Word = "scriptstyle" then Script_Style
                  else Script_Script_Style);
               Fresh.Position := Positive (Start);
               return Add (State, Fresh);
            elsif Word in "bf" | "bold" | "cal" | "frak" | "it" |
              "rm" | "sf" | "tt"
            then
               State.Font_Mode := Font_For_Name (Word);
               State.Has_Font_Mode := True;
               Fresh.Kind := Space_Node;
               Fresh.Position := Positive (Start);
               return Add (State, Fresh);
            elsif Word in "mathbf" | "mathbb" | "mathcal" | "Bbb" |
              "mathit" | "mathsf" | "mathtt" | "mathfrak" |
              "mathscr" | "boldsymbol" | "bm" | "bold" | "mathnormal" |
              "mathsfit" | "textbf" | "textit" | "textmd" |
              "textnormal" | "textrm" | "textsf" | "texttt" |
              "textup" | "emph"
            then
               declare
                  Old_Font : constant Font_Kind := State.Font_Mode;
                  Old_Active : constant Boolean := State.Has_Font_Mode;
                  Content : Node_Id;
                  Cursor : Node_Id;
                  Glyph : Node;
               begin
                  State.Font_Mode := Font_For_Name (Word);
                  State.Has_Font_Mode := True;
                  Content := Parse_Argument (State);
                  if State.Item.Nodes (Positive (Content)).Kind = Row_Node then
                     Cursor := State.Item.Nodes (Positive (Content)).First;
                     while Cursor /= No_Node loop
                        Glyph := State.Item.Nodes (Positive (Cursor));
                        if Glyph.Kind = Glyph_Node then
                           Glyph.Font := State.Font_Mode;
                           State.Item.Nodes.Replace_Element
                             (Positive (Cursor), Glyph);
                        end if;
                        Cursor := Glyph.Next;
                     end loop;
                  end if;
                  State.Font_Mode := Old_Font;
                  State.Has_Font_Mode := Old_Active;
                  return Content;
               exception
                  when Parse_Failure =>
                     State.Font_Mode := Old_Font;
                     State.Has_Font_Mode := Old_Active;
                     raise;
               end;
            elsif Word in "hat" | "widehat" | "bar" | "vec" |
              "dot" | "ddot" | "tilde" | "widetilde" | "widecheck" |
              "utilde" | "check" |
              "breve" | "acute" | "grave" | "mathring" | "overline" |
              "underline" | "r" | "H" | "u" | "v"
            then
               declare
                  Base : constant Node_Id := Parse_Argument (State);
                  Mark : constant Natural :=
                    (if Word = "bar" or else Word = "overline" or else
                     Word = "underline" then 0
                     elsif Word = "widehat" then Wide_Hat_Code_Point
                     elsif Word = "widetilde" then Wide_Tilde_Code_Point
                     elsif Word = "widecheck" then Wide_Check_Code_Point
                     elsif Word = "utilde" then Under_Tilde_Code_Point
                     elsif Word = "overrightarrow" then
                       Over_Right_Arrow_Code_Point
                     elsif Word = "overleftarrow" then
                       Over_Left_Arrow_Code_Point
                     elsif Word = "hat" then 16#02C6#
                     elsif Word = "vec" then 16#2192#
                     elsif Word = "dot" then 16#02D9#
                     elsif Word = "ddot" then 16#00A8#
                     elsif Word = "tilde" then 16#007E#
                     elsif Word = "check" then 16#02C7#
                     elsif Word = "breve" then 16#02D8#
                     elsif Word = "acute" then 16#00B4#
                     elsif Word = "grave" then 16#0060#
                     elsif Word = "r" then 16#02DA#
                     elsif Word = "H" then 16#02DD#
                     elsif Word = "u" then 16#02D8#
                     elsif Word = "v" then 16#02C7#
                     else 16#00B0#);
               begin
                  Fresh.Kind := Accent_Node;
                  Fresh.First := Base;
                  Fresh.Code_Point := Mark;
                  Fresh.Amount :=
                    (if Word = "underline" then 1.0 else 0.0);
                  if Word = "utilde" then
                     Fresh.Accent_Type := Below_Accent;
                  end if;
                  Fresh.Position := Positive (Start);
                  return Add (State, Fresh);
               end;
            elsif Word = "operatorname" then
               declare
                  Old_Mode : constant Boolean := State.Regular_Mode;
                  Old_Font : constant Font_Kind := State.Font_Mode;
                  Old_Has_Font : constant Boolean := State.Has_Font_Mode;
                  Op_Id : Node_Id;
                  Op_Row : Node;
                  Text_Id : Node_Id;
               begin
                  State.Regular_Mode := True;
                  State.Has_Font_Mode := True;
                  State.Font_Mode := Main_Regular;
                  Op_Id := Parse_Argument (State);
                  State.Regular_Mode := Old_Mode;
                  State.Font_Mode := Old_Font;
                  State.Has_Font_Mode := Old_Has_Font;
                  Op_Row.Kind := Row_Node;
                  Op_Row.Class := Operator_Atom;
                  Op_Row.Position := Positive (Start);
                  Op_Row.First := Op_Id;
                  Text_Id := Add (State, Op_Row);
                  return Text_Id;
               exception
                  when Parse_Failure =>
                     State.Regular_Mode := Old_Mode;
                     State.Font_Mode := Old_Font;
                     State.Has_Font_Mode := Old_Has_Font;
                     raise;
               end;
            elsif Word in "href" | "url" | "includegraphics" |
              "htmlClass" | "htmlId" | "htmlStyle" | "htmlData"
            then
               declare
                  First_Argument : Unbounded_String;
                  Second_Argument : Unbounded_String;
                  Has_Option : Boolean := False;
                  Option_Value : Unbounded_String;
                  procedure Validate_Graphics_Options is
                     Text : constant String := To_String (Option_Value);
                     Start : Integer := Text'First;
                  begin
                     while Start <= Text'Last loop
                        while Start <= Text'Last and then
                          Text (Start) in ' ' | ASCII.HT | ASCII.LF | ASCII.CR
                        loop
                           Start := Start + 1;
                        end loop;
                        exit when Start > Text'Last;
                        declare
                           Finish : Integer := Start;
                           Equals_At : Integer := 0;
                        begin
                           while Finish <= Text'Last and then
                             Text (Finish) /= ','
                           loop
                              if Text (Finish) = '=' then
                                 Equals_At := Finish;
                              end if;
                              Finish := Finish + 1;
                           end loop;
                           if Equals_At <= Start or else
                             Equals_At >= Finish - 1 or else
                             (Finish > Text'Last and then
                              Text (Text'Last) = ',')
                           then
                              Fail (State,
                                "invalid includegraphics option", Start);
                           end if;
                           Start := Finish + 1;
                        end;
                     end loop;
                  end Validate_Graphics_Options;
               begin
                  if Word = "includegraphics" then
                     Skip_Whitespace (State);
                     if Peek (State) = '[' then
                        Option_Value := To_Unbounded_String
                          (Read_Raw_Option (State));
                        Has_Option := True;
                     end if;
                     First_Argument := To_Unbounded_String
                       (Read_Raw_Argument (State));
                  else
                     First_Argument := To_Unbounded_String
                       (Read_Raw_Argument (State));
                     if Word /= "url" then
                        Second_Argument := To_Unbounded_String
                          (Read_Raw_Argument (State));
                     end if;
                  end if;
                  if Word = "includegraphics" and then Has_Option then
                     if Length (Option_Value) = 0 then
                        Fail (State, "empty includegraphics options", Start);
                     end if;
                     Validate_Graphics_Options;
                  end if;
                  if Word in "href" | "htmlClass" | "htmlId" |
                    "htmlStyle" | "htmlData" and then
                    Length (Second_Argument) = 0
                  then
                     Fail (State, "empty command body", Start);
                  elsif Word in "includegraphics" | "href" | "url" and then
                    Length (First_Argument) = 0
                  then
                     Fail (State, "empty command argument", Start);
                  elsif Word in "htmlClass" | "htmlId" | "htmlStyle" |
                    "htmlData" and then Length (First_Argument) = 0
                  then
                     Fail (State, "empty HTML command argument", Start);
                  elsif State.Settings.Strict = Strict_Error then
                     Fail (State, "refused untrusted command: \" & Word,
                       Start);
                  else
                     State.Item.Diagnostics.Append
                       (New_Item => Math_Syntax.Diagnostic'
                          (Kind => (if State.Settings.Strict = Strict_Warn
                                    then Warning else Refusal),
                           Message => To_Unbounded_String
                             ("refused untrusted command: \" & Word),
                           Position => Start));
                     declare
                        Command : constant Node_Id := Literal_Command
                          (State, "\" & Word, Start);
                        Colored : Node;
                     begin
                        Colored.Kind := Color_Node;
                        Colored.First := Command;
                        Colored.Color := (Red => 204.0 / 255.0,
                                          Green => 0.0, Blue => 0.0,
                                          Alpha => 1.0);
                        Colored.Position := Positive (Start);
                        return Add (State, Colored);
                     end;
                  end if;
               end;
            elsif Word = "text" or else Word = "mathrm" then
               declare
                  Old_Mode : constant Boolean := State.Regular_Mode;
                  Content : Node_Id;
               begin
                  State.Regular_Mode := True;
                  Math_Expander.Set_Mode (State.Cursor, True);
                  Content := Parse_Argument (State);
                  State.Regular_Mode := Old_Mode;
                  Math_Expander.Set_Mode (State.Cursor, Old_Mode);
                  return Content;
               exception
                  when Parse_Failure =>
                     State.Regular_Mode := Old_Mode;
                     Math_Expander.Set_Mode (State.Cursor, Old_Mode);
                     raise;
               end;
            elsif Word = "textregistered" then
               return New_Glyph
                 (State, 16#00AE#, Ordinary, Main_Regular, Start);
            elsif Word = "textcircled" and then
              (State.Regular_Mode or else
               State.Settings.Strict /= Strict_Error)
            then
               declare
                  Base : constant Node_Id := Parse_Argument (State);
               begin
                  Fresh.Kind := Accent_Node;
                  Fresh.First := Base;
                  Fresh.Code_Point :=
                    (if Word = "textcircled" then 16#25EF#
                     else Text_Accent_Codepoint ("\c"));
                  Fresh.Accent_Type :=
                    (if Word = "c" then Below_Accent else Full_Accent);
                  Fresh.Position := Positive (Start);
                  return Add (State, Fresh);
               end;
            elsif Word in "emph" | "textbf" | "textit" | "textmd" |
              "textnormal" | "textrm" | "textsf" | "texttt" |
              "textup"
            then
               declare
                  Old_Mode : constant Boolean := State.Regular_Mode;
                  Old_Font : constant Font_Kind := State.Font_Mode;
                  Old_Has_Font : constant Boolean := State.Has_Font_Mode;
                  Content : Node_Id;
               begin
                  State.Regular_Mode := True;
                  State.Font_Mode := Font_For_Name (Word);
                  State.Has_Font_Mode := True;
                  Math_Expander.Set_Mode (State.Cursor, True);
                  Content := Parse_Argument (State);
                  State.Regular_Mode := Old_Mode;
                  State.Font_Mode := Old_Font;
                  State.Has_Font_Mode := Old_Has_Font;
                  Math_Expander.Set_Mode (State.Cursor, Old_Mode);
                  return Content;
               exception
                  when Parse_Failure =>
                     State.Regular_Mode := Old_Mode;
                     State.Font_Mode := Old_Font;
                     State.Has_Font_Mode := Old_Has_Font;
                     Math_Expander.Set_Mode (State.Cursor, Old_Mode);
                     raise;
               end;
            elsif Word = "sqrt" then
               Skip_Whitespace (State);
               declare
                  Index_Node : Node_Id := No_Node;
                  Radicand : Node_Id;
               begin
                  Skip_Whitespace (State);
                  if Peek (State) = '[' then
                     Advance (State);
                     Index_Node := Parse_Expression (State, True, Stop_Square => True);
                     if Peek (State) /= ']' then
                        Fail (State, "missing sqrt index bracket");
                     end if;
                     Advance (State);
                  end if;
                  Radicand := Parse_Argument (State);
                  Fresh.Kind := Radical_Node;
                  Fresh.First := Radicand;
                  Fresh.Second := Index_Node;
                  Fresh.Position := Positive (Start);
                  return Add (State, Fresh);
               end;
            elsif Word in "," | ":" | ">" | ";" | "!" | "quad" then
               Fresh.Kind := Space_Node;
               Fresh.Position := Positive (Start);
               if Word = "," then
                  Fresh.Amount := 0.166_667;
               elsif Word in ":" | ">" then
                  Fresh.Amount := 4.0 / 18.0;
               elsif Word = ";" then
                  Fresh.Amount := 0.277_778;
               elsif Word = "!" then
                  Fresh.Amount := -0.166_667;
               else
                  Fresh.Amount := 1.0;
               end if;
               return Add (State, Fresh);
            elsif Word in "allowbreak" | "nobreak" | "nobreakspace" then
               Fresh.Kind := Space_Node;
               Fresh.Break :=
                 (if Word = "allowbreak" then Allow_Break
                  else Forbid_Break);
               if Word = "nobreakspace" then
                  Fresh.Amount := 0.333;
               end if;
               Fresh.Position := Positive (Start);
               return Add (State, Fresh);
            elsif Word = "sum" or else Word = "prod" or else Word = "int" then
               Point := (if Word = "sum" then 16#2211# else
                    (if Word = "prod" then 16#220F# else 16#222B#));
               return New_Glyph (State, Point, Operator_Atom, Size_1, Start);
            elsif Word in "lim" | "limsup" | "liminf" | "max" | "min" |
              "sup" | "inf" | "sin" | "cos" | "tan" | "log" | "ln" |
              "exp" | "sinh" | "cosh" | "tanh" | "arcsin" | "arccos" |
              "arctan" | "cot" | "sec" | "csc" | "det" | "arg" |
              "argmax" | "argmin" | "ker" | "dim" | "deg" | "gcd" |
              "Pr" | "arcctg" | "arctg" | "cotg" | "ctg" | "cth" |
              "coth" | "cosec" | "hom" | "lg" | "sh" | "tg" | "th" |
              "ch"
            then
               if Word in "lim" | "limsup" | "liminf" | "max" | "min" |
                 "sup" | "inf" | "argmax" | "argmin" | "ker" | "dim" |
                 "deg" | "gcd" | "Pr" | "arcctg" | "arctg" | "cotg" |
                 "ctg" | "cth" | "coth" | "cosec" | "hom" | "lg" |
                 "sh" | "tg" | "th" | "ch"
               then
                  declare
                     Op_Row : Node;
                     Op_Id : Node_Id;
                  begin
                     Op_Row.Kind := Row_Node;
                     Op_Row.Class := Operator_Atom;
                     Op_Row.Code_Point :=
                       Character'Pos (Word (Word'First));
                     Op_Row.Position := Positive (Start);
                     Op_Id := Add (State, Op_Row);
                     for K in Word'Range loop
                        Id := New_Glyph
                          (State, Character'Pos (Word (K)), Ordinary,
                           Main_Regular, Start);
                        Link (State, Op_Id, Id);
                     end loop;
                     return Op_Id;
                  end;
               end if;
               declare
                  Op_Row : Node;
                  Op_Id : Node_Id;
               begin
                  Op_Row.Kind := Row_Node;
                  Op_Row.Class := Operator_Atom;
                  Op_Row.Position := Positive (Start);
                  Op_Id := Add (State, Op_Row);
                  for K in Word'Range loop
                     Id := New_Glyph
                         (State, Character'Pos (Word (K)), Ordinary,
                          Main_Regular, Start);
                     Link (State, Op_Id, Id);
                  end loop;
                  return Op_Id;
               end;
            else
               declare
                  Alias : constant String :=
                    (if Word in "ne" | "neq" then "="
                     elsif Word = "notin" then "\in"
                     elsif Word = "to" then "\rightarrow"
                     elsif Word = "dots" then "\ldots"
                     elsif Word = "le" then "\leq"
                     elsif Word = "ge" then "\geq"
                     elsif Word = "implies" then "\Rightarrow"
                     elsif Word = "iff" then "\Leftrightarrow"
                     else "\" & Word);
               begin
                  Registry :=
                    (if State.Regular_Mode then
                       Math_Symbols.Lookup_Text (Alias)
                     else Math_Symbols.Lookup_Math (Alias));
               end;
               if Text_Accent_Codepoint ("\" & Word) /= 0 and then
                 (State.Regular_Mode or else
                  State.Settings.Strict /= Strict_Error)
               then
                  Point := Text_Accent_Codepoint ("\" & Word);
                  if Point /= 0 then
                     declare
                        Base : constant Node_Id := Parse_Argument (State);
                        Accent : Node;
                     begin
                        Accent.Kind := Accent_Node;
                        Accent.First := Base;
                        Accent.Code_Point := Point;
                        if Word = "c" then
                           Accent.Accent_Type := Below_Accent;
                        end if;
                        Accent.Position := Positive (Start);
                        return Add (State, Accent);
                     end;
                  end if;
               end if;
               if not Registry.Found and then not State.Regular_Mode and then
                 State.Settings.Strict = Strict_Error and then
                 Word /= "textcircled" and then
                 Text_Accent_Codepoint ("\" & Word) /= 0
               then
                  Fail
                    (State, "refused text accent in math mode: " & Word,
                     Start);
               end if;
               if not Registry.Found then
                  Fail (State, "unknown command: \" & Word, Start);
               end if;
               Point := Registry.Code_Point;
               Class := Registry.Class;
               Font := Registry.Font;
               return New_Glyph
                 (State, Point, Class,
                  (if State.Regular_Mode then Main_Regular else Font), Start);
            end if;
         end;
      elsif State.Current.Kind = Math_Tokens.Character_Token and then
        State.Current.Code_Point >= 16#80#
      then
         Point := Current_Code_Point (State);
         Registry :=
           (if State.Regular_Mode then Math_Symbols.Lookup_Text
              (To_String (State.Current.Lexeme))
            else Math_Symbols.Lookup_Math
              (To_String (State.Current.Lexeme)));
         if not Registry.Found and then Point in
           16#2211# | 16#220F# | 16#222B#
         then
            Registry := (True, Point, Operator_Atom, Size_1);
         elsif not Registry.Found and then Point in
           16#203C# | 16#225F# | 16#27E6# | 16#27E7# |
           16#2983# | 16#2984# | 16#2A7D# | 16#2A7E# | 16#2A7F#
         then
            Registry := (True, Point,
              (if Point in 16#27E6# | 16#2983# then Opening
               elsif Point in 16#27E7# | 16#2984# then Closing
               else Relation_Atom),
              (if Point in 16#27E6# | 16#27E7# then AMS_Regular
               else Main_Regular));
         elsif not Registry.Found and then Point = 16#2209# then
            Fresh.Kind := Overlay_Node;
            Fresh.First := New_Glyph
              (State, 16#2208#, Relation_Atom, Main_Regular, Start);
            Fresh.Second := New_Glyph
              (State, Character'Pos ('/'), Ordinary, Main_Regular, Start);
            Fresh.Class := Relation_Atom;
            Fresh.Position := Positive (Start);
            Advance (State);
            return Add (State, Fresh);
         elsif not Registry.Found and then Point = 16#2260# then
            Fresh.Kind := Overlay_Node;
            Fresh.First := New_Glyph
              (State, Character'Pos ('='), Relation_Atom, Main_Regular, Start);
            Fresh.Second := New_Glyph
              (State, Character'Pos ('/'), Ordinary, Main_Regular, Start);
            Fresh.Class := Relation_Atom;
            Fresh.Position := Positive (Start);
            Advance (State);
            return Add (State, Fresh);
         end if;
         if not Registry.Found then
            if State.Current.Text_First /= Natural'Last and then
              Math_Unicode.Is_Script_Data (Point) and then
              (State.Regular_Mode or else
               State.Settings.Strict /= Strict_Error)
            then
               Fresh.Kind := Text_Run_Node;
               Fresh.Class := Ordinary;
               Fresh.Text_Run_Profile := Profile_For (Point);
               Fresh.Text_Run_Text := State.Current.Lexeme;
               Fresh.Position := Positive (Start);
               if not State.Regular_Mode and then
                 State.Settings.Strict = Strict_Warn
               then
                  State.Item.Diagnostics.Append
                    (New_Item => Math_Syntax.Diagnostic'
                       (Kind => Warning,
                        Message => To_Unbounded_String
                          ("approximating unsupported Unicode glyph with " &
                           "native text shaping"),
                        Position => Start));
               end if;
               Advance (State);
               return Add (State, Fresh);
            end if;
            Fail (State, "unsupported Unicode scalar", Start);
         end if;
         Advance (State);
         return New_Glyph
           (State, Registry.Code_Point, Registry.Class,
            (if State.Regular_Mode then Main_Regular else Registry.Font), Start);
      elsif Char in 'A' .. 'Z' or else Char in 'a' .. 'z' then
         Advance (State);
         return New_Glyph
             (State, Character'Pos (Char), Ordinary, Math_Italic, Start);
      elsif Char in '0' .. '9' then
         Advance (State);
         return New_Glyph
             (State, Character'Pos (Char), Ordinary, Main_Regular, Start);
      elsif Char = ' ' and then State.Regular_Mode then
         Advance (State);
         if State.Color_Box_Mode then
            Fresh.Kind := Space_Node;
            Fresh.Amount := 0.333;
            Fresh.Position := Positive (Start);
            return Add (State, Fresh);
         end if;
         return New_Glyph
             (State, 32, Ordinary, Main_Regular, Start);
      elsif Char = '+' or else Char = '-' then
         Advance (State);
         return New_Glyph
             (State,
              (if Char = '-' then 16#2212# else Character'Pos (Char)),
              Binary_Atom, Main_Regular, Start);
      elsif Char = '|' and then not State.CD_Mode then
         Registry := Math_Symbols.Lookup_Math ("|");
         if Registry.Found then
            Advance (State);
            return New_Glyph
              (State, Registry.Code_Point, Registry.Class, Registry.Font,
               Start);
         end if;
         Fail (State, "unsupported math character", Start);
      elsif Char = '=' or else Char = '<' or else Char = '>' then
         Advance (State);
         return New_Glyph
             (State, Character'Pos (Char), Relation_Atom, Main_Regular, Start);
      elsif Char = '(' or else Char = '[' then
         Advance (State);
         return New_Glyph
             (State, Character'Pos (Char), Opening, Main_Regular, Start);
      elsif Char = ')' or else Char = ']' then
         Advance (State);
         return New_Glyph
             (State, Character'Pos (Char), Closing, Main_Regular, Start);
      elsif Char in '@' | '|' and then State.CD_Mode then
         Advance (State);
         return New_Glyph
           (State, Character'Pos (Char), Ordinary, Main_Regular, Start);
      elsif Char = '%' then
         Fail (State, "comments are not supported as math syntax", Start);
      elsif Char = '&' then
         Advance (State);
         return New_Glyph
             (State, Character'Pos (Char), Ordinary, Main_Regular, Start);
      elsif Char = ',' or else Char = ';' or else
        Character'Pos (Char) = 39 or else Char = '!' or else Char = '?'
      then
         Advance (State);
         return New_Glyph
             (State, Character'Pos (Char), Punctuation, Main_Regular, Start);
      elsif Char = '`' then
         Advance (State);
         return New_Glyph (State, 16#2018#, Ordinary, Main_Regular, Start);
      elsif Char = '/' or else Char = '.' or else Char = ':' then
         Advance (State);
         return New_Glyph
             (State, Character'Pos (Char),
              (if Char = ':' then Relation_Atom else Ordinary),
              Main_Regular, Start);
      elsif Char = '{' then
         return Parse_Argument (State);
      elsif Char = Character'Val (0) then
         Fail (State, "expected math atom");
      else
         Fail (State, "unsupported or invalid input byte", Start);
      end if;
      return No_Node;
   end Parse_Atom;

   function Parse_Array
     (State : in out Parser_State;
      Name : String;
      Start : Natural) return Node_Id is
      Fresh : Node;
      Array_Id : Node_Id;
      Row_Id : Node_Id;
      Row_Tail : Node_Id := No_Node;
      Cell_Id : Node_Id;
      Cell_Tail : Node_Id;
      Row_Count : Natural := 0;
      Column_Count : Natural := 0;
      Current_Columns : Natural;
      Is_Aligned : constant Boolean := Name in "aligned" | "align" |
          "align*" | "alignat" | "alignat*" | "alignedat" |
          "split";
      Is_Gathered : constant Boolean := Name in "gather" | "gather*" |
          "gathered";
      Is_Equation : constant Boolean := Name in "equation" | "equation*";
      Is_Small_Matrix : constant Boolean := Name = "smallmatrix";
      Is_Cases : constant Boolean := Name in "cases" | "dcases" |
          "drcases" | "rcases";
      Explicit_Spec : constant Boolean := Name in "array" | "darray" |
          "subarray";
      Spec_Text : Unbounded_String;
      Expected_Columns : Natural := 0;
      function End_Matches return Boolean is
      begin
         return Is_Environment_End (State, Name);
      end End_Matches;
      procedure Append_Cell (Cell : Node_Id) is
         Row_Value : Node;
         Cell_Value : Node;
      begin
         if Cell_Tail = No_Node then
            Row_Value := State.Item.Nodes (Positive (Row_Id));
            Row_Value.First := Cell;
            State.Item.Nodes.Replace_Element (Positive (Row_Id), Row_Value);
         else
            Cell_Value := State.Item.Nodes (Positive (Cell_Tail));
            Cell_Value.Next := Cell;
            State.Item.Nodes.Replace_Element
              (Positive (Cell_Tail), Cell_Value);
         end if;
         Cell_Tail := Cell;
         Current_Columns := Current_Columns + 1;
         Column_Count := Natural'Max (Column_Count, Current_Columns);
      end Append_Cell;
      procedure Append_Row is
         Array_Value : Node;
         Row_Value : Node;
      begin
         if Row_Count >= Max_Array_Rows then
            Fail (State, "array row limit exceeded", Start);
         end if;
         if Expected_Columns > 0 and then
           Current_Columns /= Expected_Columns
         then
            Fail (State, "array row has wrong number of columns", Start);
         end if;
         if Row_Tail = No_Node then
            Array_Value := State.Item.Nodes (Positive (Array_Id));
            Array_Value.First := Row_Id;
            State.Item.Nodes.Replace_Element
              (Positive (Array_Id), Array_Value);
         else
            Row_Value := State.Item.Nodes (Positive (Row_Tail));
            Row_Value.Next := Row_Id;
            State.Item.Nodes.Replace_Element
              (Positive (Row_Tail), Row_Value);
         end if;
         Row_Tail := Row_Id;
         Row_Count := Row_Count + 1;
      end Append_Row;
      procedure New_Row is
         Row_Value : Node;
      begin
         Row_Value.Kind := Row_Node;
         Row_Value.Position := Positive (State.Cursor_Pos);
         Row_Id := Add (State, Row_Value);
         Cell_Tail := No_Node;
         Current_Columns := 0;
      end New_Row;
      procedure Consume_End is
      begin
         if Read_Command (State) /= "end" then
            Fail (State, "expected environment end");
         end if;
         Skip_Whitespace (State);
         if Peek (State) /= '{' then
            Fail (State, "invalid environment end");
         end if;
         Advance (State);
         for K in Name'Range loop
            if Peek (State) /= Name (K) then
               Fail (State, "mismatched environment end");
            end if;
            Advance (State);
         end loop;
         if Peek (State) /= '}' then
            Fail (State, "mismatched environment end");
         end if;
         Math_Macros.End_Group (State.Shared.all);
         Advance (State);
      end Consume_End;
   begin
      if State.Depth >= Max_Depth then
         Fail (State, "nesting depth exceeded", Start);
      end if;
      State.Depth := State.Depth + 1;
      if Name in "array" | "darray" | "subarray" then
         Skip_Whitespace (State);
         if State.Current.Kind /= Math_Tokens.Left_Group then
            Fail (State, "missing array column specification", Start);
         end if;
         declare
            Raw_Spec : constant String := Read_Raw_Argument (State);
            Spec_Columns : Natural := 0;
         begin
            if Raw_Spec'Length = 0 then
               Fail (State, "empty array column specification", Start);
            end if;
            for C of Raw_Spec loop
               if C in 'l' | 'c' | 'r' then
                  Spec_Columns := Spec_Columns + 1;
               elsif C /= '|' and then C /= ' ' then
                  Fail (State, "unsupported array column specification", Start);
               end if;
            end loop;
            if Spec_Columns = 0 or else Spec_Columns > Max_Array_Columns
            then
               Fail (State, "invalid array column specification", Start);
            end if;
            if Name = "subarray" and then Spec_Columns /= 1 then
               Fail (State, "subarray requires one column", Start);
            end if;
            Spec_Text := To_Unbounded_String (Raw_Spec);
            Expected_Columns := Spec_Columns;
         end;
      elsif Is_Small_Matrix then
         null;
      elsif Is_Cases then
         Spec_Text := To_Unbounded_String ("ll");
         Expected_Columns := 2;
      elsif Name in "alignat" | "alignat*" | "alignedat" then
         declare
            Raw_Count : constant String := Read_Raw_Argument (State);
         begin
            if Raw_Count'Length /= 1 or else Raw_Count (Raw_Count'First)
              not in '1' .. '9'
            then
               Fail (State, "alignedat requires a positive pair count", Start);
            end if;
            Spec_Text := To_Unbounded_String (Raw_Count);
            Expected_Columns := 2 * Natural'Value (Raw_Count);
         end;
      end if;
      if Name not in "matrix" | "matrix*" | "pmatrix" | "pmatrix*" |
          "bmatrix" | "bmatrix*" | "Bmatrix" | "Bmatrix*" |
          "vmatrix" | "vmatrix*" | "Vmatrix" | "Vmatrix*" |
          "cases" | "dcases" | "drcases" | "rcases" |
          "smallmatrix" | "aligned" | "align" | "align*" | "alignat" |
          "alignat*" | "alignedat" | "gather" | "gather*" |
          "gathered" | "split" | "array" | "darray" | "subarray" |
          "equation" | "equation*"
      then
         Fail (State, "unknown environment: " & Name, Start);
      end if;
      if Is_Equation and then State.Depth /= 1 then
         Fail (State, "nested equation environment is unsupported", Start);
      end if;
      if Is_Equation then
         State.Settings.Display_Mode := True;
         State.AMS_Row := True;
         State.Pending_Tag := No_Node;
         State.Has_Tag := False;
      end if;
      Fresh.Kind := Array_Node;
      Fresh.Array_Type := (if Is_Cases then Cases_Array else
           (if Is_Aligned then Aligned_Array else Matrix_Array));
      Fresh.Position := Positive (Start);
      Fresh.Column_Spec := Spec_Text;
      if Is_Small_Matrix then
         Fresh.Math_Style := Script_Style;
         Fresh.Amount := 0.5;
      elsif Name in "dcases" | "drcases" then
         Fresh.Math_Style := Display_Style;
         Fresh.Amount := 1.2;
      else
         Fresh.Math_Style := Text_Style;
         Fresh.Amount := (if Is_Cases then 1.2 else 1.0);
      end if;
      if Explicit_Spec then
         Fresh.Row_Spacing := (if Name = "subarray" then 0.10 else 0.16);
      end if;
      if Name in "pmatrix" | "pmatrix*" then
         Fresh.Left_Delimiter := Parenthesis_Delimiter;
         Fresh.Right_Delimiter := Parenthesis_Delimiter;
      elsif Name in "bmatrix" | "bmatrix*" then
         Fresh.Left_Delimiter := Bracket_Delimiter;
         Fresh.Right_Delimiter := Bracket_Delimiter;
      elsif Name in "Bmatrix" | "Bmatrix*" then
         Fresh.Left_Delimiter := Brace_Delimiter;
         Fresh.Right_Delimiter := Brace_Delimiter;
      elsif Is_Cases then
         if Name in "rcases" | "drcases" then
            Fresh.Right_Delimiter := Brace_Delimiter;
         else
            Fresh.Left_Delimiter := Brace_Delimiter;
         end if;
      elsif Name in "vmatrix" | "vmatrix*" then
         Fresh.Left_Delimiter := Bar_Delimiter;
         Fresh.Right_Delimiter := Bar_Delimiter;
      elsif Name in "Vmatrix" | "Vmatrix*" then
         Fresh.Left_Delimiter := Double_Bar_Delimiter;
         Fresh.Right_Delimiter := Double_Bar_Delimiter;
      end if;
      Array_Id := Add (State, Fresh);
      New_Row;
      loop
         if Command_Is (State, "\hline") or else
           Command_Is (State, "\hdashline")
         then
            declare
               Rule_Name : constant String := Read_Command (State);
               Array_Value : Node :=
                 State.Item.Nodes (Positive (Array_Id));
            begin
               if Cell_Tail /= No_Node and then Row_Count = 0 then
                  Fail (State, "array rule is only valid between rows");
               end if;
               Array_Value.Array_Rules.Append
                 (New_Item => Array_Rule'
                    (Boundary => Row_Count,
                     Kind => (if Rule_Name = "hdashline" then
                       Dashed_Array_Rule else Solid_Array_Rule)));
               State.Item.Nodes.Replace_Element
                 (Positive (Array_Id), Array_Value);
            end;
         elsif End_Matches then
            if Cell_Tail = No_Node and then Row_Count = 0 then
               Fail (State, "empty array cell", State.Cursor_Pos);
            elsif Cell_Tail /= No_Node then
               Append_Row;
            end if;
            Consume_End;
            exit;
         elsif Peek (State) = Character'Val (0) then
            Fail (State, "missing environment end", Start);
         elsif Peek (State) = '&' then
            Fail (State, "empty array cell", State.Cursor_Pos);
         elsif Command_Is (State, "\\")
         then
            Fail (State, "empty array row", State.Cursor_Pos);
         else
            if Current_Columns >= Max_Array_Columns then
               Fail (State, "array column limit exceeded", Start);
            end if;
            declare
               Old_Stop : constant Unbounded_String :=
                 State.Environment_Stop;
            begin
               State.Environment_Stop := To_Unbounded_String (Name);
               Cell_Id := Parse_Expression (State, False, Name);
               State.Environment_Stop := Old_Stop;
            exception
               when Parse_Failure =>
                  State.Environment_Stop := Old_Stop;
                  raise;
            end;
            Append_Cell (Cell_Id);
            if Current_Columns > Max_Array_Columns then
               Fail (State, "array column limit exceeded", Start);
            end if;
            if End_Matches then
               Append_Row;
               Consume_End;
               exit;
            elsif Peek (State) = '&' then
               Advance (State);
               if End_Matches or else Peek (State) = '&' or else
                 Command_Is (State, "\\")
               then
                  Fail (State, "empty array cell", State.Cursor_Pos);
               end if;
            elsif Command_Is (State, "\\") then
               Advance (State);
               Append_Row;
               New_Row;
            else
               Fail (State, "expected array separator or environment end");
            end if;
         end if;
      end loop;
      if Row_Count = 0 or else Column_Count = 0 then
         Fail (State, "empty array", Start);
      end if;
      if Is_Equation and then (Row_Count /= 1 or else Column_Count /= 1) then
         Fail (State, "equation environment requires one row and one column", Start);
      end if;
      if Is_Aligned and then (Column_Count < 2 or else
             Column_Count mod 2 /= 0)
      then
         Fail (State, "aligned environment needs column pairs", Start);
      end if;
      if Is_Cases and then Column_Count /= 2 then
         Fail (State, "cases environment requires exactly two columns", Start);
      end if;
      if Explicit_Spec then
         declare
            Spec_Columns : Natural := 0;
         begin
            for S of To_String (Spec_Text) loop
               if S in 'l' | 'c' | 'r' then
                  Spec_Columns := Spec_Columns + 1;
               end if;
            end loop;
            if Column_Count /= Spec_Columns then
               Fail (State, "array row has wrong number of columns", Start);
            end if;
         end;
      end if;
      if Name = "alignedat" or else Name = "alignat" then
         if Column_Count /= 2 * Natural'Value (To_String (Spec_Text)) then
            Fail (State, "alignedat row has wrong number of columns", Start);
         end if;
      end if;
      if Is_Gathered and then Column_Count /= 1 then
         Fail (State, "gathered environment has one column", Start);
      end if;
      if Is_Equation then
         Fresh.Kind := Tagged_Node;
         Fresh.First := Array_Id;
         Fresh.Second := State.Pending_Tag;
         Fresh.Tag_Is_Left := State.Settings.Left_Tags;
         Fresh.Position := Positive (Start);
         Array_Id := Add (State, Fresh);
         State.AMS_Row := False;
         State.Pending_Tag := No_Node;
         State.Has_Tag := False;
      end if;
      State.Depth := State.Depth - 1;
      return Array_Id;
   end Parse_Array;

   function Parse_CD (State : in out Parser_State; Start : Natural)
      return Node_Id is
      Array_Id : Node_Id;
      Array_Row : Node_Id;
      Row_Tail : Node_Id := No_Node;
      Cell_Tail : Node_Id := No_Node;
      Row_Count : Natural := 0;
      Columns : Natural := 0;
      Old_CD_Mode : constant Boolean := State.CD_Mode;
      Macro_Error : Math_Macros.Diagnostic_Kind;
      procedure Append_Cell (Cell : Node_Id) is
         Value : Node;
      begin
         if Columns >= Max_Array_Columns then
            Fail (State, "CD column limit exceeded", Start);
         end if;
         Columns := Columns + 1;
         if Cell_Tail = No_Node then
            Value := State.Item.Nodes (Positive (Array_Row));
            Value.First := Cell;
            State.Item.Nodes.Replace_Element (Positive (Array_Row), Value);
         else
            Value := State.Item.Nodes (Positive (Cell_Tail));
            Value.Next := Cell;
            State.Item.Nodes.Replace_Element (Positive (Cell_Tail), Value);
         end if;
         Cell_Tail := Cell;
      end Append_Cell;
      procedure New_Row (Has_Ghost : Boolean := False) is
         Value : Node;
      begin
         if Row_Count >= Max_Array_Rows and then
           (not Has_Ghost or else Row_Count /= Max_Array_Rows)
         then
            Fail (State, "CD row limit exceeded", Start);
         end if;
         Array_Row := Add (State,
           (Kind => Row_Node, Position => Positive (Start), others => <>));
         if Row_Tail = No_Node then
            Value := State.Item.Nodes (Positive (Array_Id));
            Value.First := Array_Row;
            State.Item.Nodes.Replace_Element (Positive (Array_Id), Value);
         else
            Value := State.Item.Nodes (Positive (Row_Tail));
            Value.Next := Array_Row;
            State.Item.Nodes.Replace_Element (Positive (Row_Tail), Value);
         end if;
         Row_Tail := Array_Row;
         Row_Count := Row_Count + 1;
         Cell_Tail := No_Node;
         Columns := 0;
      end New_Row;
      procedure Attach (Row : Node_Id; Tail : in out Node_Id;
                        Part : Node_Id) is
         Value : Node := State.Item.Nodes (Positive (Part));
      begin
         Value.Next := No_Node;
         State.Item.Nodes.Replace_Element (Positive (Part), Value);
         if Tail = No_Node then
            Value := State.Item.Nodes (Positive (Row));
            Value.First := Part;
            State.Item.Nodes.Replace_Element (Positive (Row), Value);
         else
            Value := State.Item.Nodes (Positive (Tail));
            Value.Next := Part;
            State.Item.Nodes.Replace_Element (Positive (Tail), Value);
         end if;
         Tail := Part;
      end Attach;
      function Empty_Row (Position : Positive) return Node_Id is
        (Add (State, (Kind => Row_Node, Position => Position, others => <>)));
      procedure Build_Row (Parsed : Node_Id; Odd : Boolean) is
         Current : Node_Id := State.Item.Nodes (Positive (Parsed)).First;
         Cell : Node_Id := Empty_Row (Positive (Start));
         Tail : Node_Id := No_Node;
         Marker : Natural;
         Labels : array (1 .. 2) of Node_Id;
         Arrow : Node;
      begin
         while Current /= No_Node loop
            Math_Work_Control.Poll (State.Work);
            declare
               Value : constant Node := State.Item.Nodes (Positive (Current));
               Next : constant Node_Id := Value.Next;
            begin
               if Value.Kind /= Glyph_Node or else
                 Value.Code_Point /= Character'Pos ('@')
               then
                  Attach (Cell, Tail, Current);
                  Current := Next;
               else
                  --  The reference drops the first implicit cell in odd rows.
                  if not Odd or else Columns > 0 then
                     Append_Cell (Cell);
                  end if;
                  Cell := Empty_Row (Value.Position);
                  Tail := No_Node;
                  Current := Next;
                  if Current = No_Node then
                     Fail (State, "missing CD arrow marker", Value.Position);
                  end if;
                  declare
                     M : constant Node := State.Item.Nodes (Positive (Current));
                  begin
                     if M.Kind /= Glyph_Node then
                        Fail (State, "invalid CD arrow marker", M.Position);
                     end if;
                     Marker := M.Code_Point;
                     Current := M.Next;
                  end;
                  if Marker not in Character'Pos ('>') | Character'Pos ('<') |
                    Character'Pos ('A') | Character'Pos ('V') |
                    Character'Pos ('=') | Character'Pos ('|') |
                    Character'Pos ('.')
                  then
                     Fail (State, "invalid CD arrow marker", Value.Position);
                  end if;
                  for L in Labels'Range loop
                     Labels (L) := Empty_Row (Value.Position);
                     if Marker in Character'Pos ('>') | Character'Pos ('<') |
                       Character'Pos ('A') | Character'Pos ('V')
                     then
                        declare
                           Label_Tail : Node_Id := No_Node;
                           Found : Boolean := False;
                        begin
                           while Current /= No_Node loop
                              Math_Work_Control.Poll (State.Work);
                              declare
                                 X : constant Node := State.Item.Nodes
                                   (Positive (Current));
                              begin
                                 if X.Kind = Glyph_Node and then
                                   X.Code_Point = Marker
                                 then
                                    Current := X.Next;
                                    Found := True;
                                    exit;
                                 elsif X.Kind = Glyph_Node and then
                                   X.Code_Point = Character'Pos ('@')
                                 then
                                    Fail (State, "incomplete CD arrow", X.Position);
                                 end if;
                                 Attach (Labels (L), Label_Tail, Current);
                                 Current := X.Next;
                              end;
                           end loop;
                           if not Found then
                              Fail (State, "incomplete CD arrow", Value.Position);
                           end if;
                        end;
                     end if;
                  end loop;
                  Arrow := (Position => Value.Position, others => <>);
                  if Marker in Character'Pos ('>') | Character'Pos ('<') |
                    Character'Pos ('=')
                  then
                     Arrow.Kind := Stretchy_Node;
                     Arrow.Stretchy_Name := To_Unbounded_String
                       (if Marker = Character'Pos ('>') then "cdrightarrow"
                        elsif Marker = Character'Pos ('<') then "cdleftarrow"
                        else "cdlongequal");
                     Arrow.First := Labels (1);
                     Arrow.Second := Labels (2);
                     Arrow.Code_Point := 1;
                  elsif Marker in Character'Pos ('A') | Character'Pos ('V') then
                     Arrow.Kind := CD_Arrow_Node;
                     Arrow.First := Labels (1);
                     Arrow.Second := Labels (2);
                     Arrow.Code_Point :=
                       (if Marker = Character'Pos ('A') then 16#2191#
                        else 16#2193#);
                  elsif Marker = Character'Pos ('|') then
                     Arrow.Kind := Delimited_Node;
                     Arrow.Left_Delimiter := Double_Bar_Delimiter;
                     Arrow.Amount := 1.8;
                     Arrow.Code_Point := 1;
                  else
                     Arrow.Kind := Space_Node;
                  end if;
                  declare
                     Id : constant Node_Id := Add (State, Arrow);
                  begin
                     Append_Cell (Add (State,
                       (Kind => Row_Node, First => Id,
                        Position => Value.Position, others => <>)));
                  end;
               end if;
            end;
         end loop;
         if not Odd then
            Append_Cell (Cell);
         end if;
      end Build_Row;
   begin
      if State.Depth >= Max_Depth then
         Fail (State, "nesting depth exceeded", Start);
      end if;
      State.Depth := State.Depth + 1;
      Array_Id := Add (State,
        (Kind => Array_Node, Array_Type => CD_Array,
         Math_Style => Display_Style, Position => Positive (Start),
         others => <>));
      State.CD_Mode := True;
      Math_Macros.Define_Tokens
        (State.Shared.all, "\cr", 0,
         (1 => (Kind => Math_Tokens.Control_Symbol,
           Lexeme => To_Unbounded_String ("\\"), others => <>)),
         False, Macro_Error);
      if Macro_Error /= Math_Macros.No_Error then
         Fail (State, "unable to scope CD row command", Start);
      end if;
      loop
         Math_Work_Control.Poll (State.Work);
         Math_Macros.Begin_Group (State.Shared.all);
         declare
            Parsed : constant Node_Id := Parse_Expression
              (State, False, "CD", Stop_Separators => True);
         begin
            Math_Macros.End_Group (State.Shared.all);
            exit when State.Item.Nodes (Positive (Parsed)).First = No_Node
              and then Is_Environment_End (State, "CD");
            New_Row;
            Build_Row (Parsed, Row_Count mod 2 = 0);
         end;
         if State.Current.Kind = Math_Tokens.Alignment or else
           Command_Is (State, "\\")
         then
            Advance (State);
         elsif Is_Environment_End (State, "CD") then
            exit;
         else
            Fail (State, "missing CD row separator or environment end", Start);
         end if;
      end loop;
      --  The final reference body row affects centering but has no cells.
      New_Row (Has_Ghost => True);
      if Read_Command (State) /= "end" or else
        Read_Raw_Argument (State) /= "CD"
      then
         Fail (State, "mismatched CD environment end", Start);
      end if;
      Math_Macros.End_Group (State.Shared.all);
      State.CD_Mode := Old_CD_Mode;
      State.Depth := State.Depth - 1;
      return Array_Id;
   exception
      when others =>
         State.CD_Mode := Old_CD_Mode;
         raise;
   end Parse_CD;

   function Parse_Argument (State : in out Parser_State) return Node_Id is
      Result : Node_Id;
   begin
      Skip_Whitespace (State);
      if Peek (State) = Character'Val (0) or else Peek (State) = '^' or else
          Peek (State) = '_' or else Peek (State) = '}'
      then
         Fail (State, "missing argument");
      end if;
      if State.Depth >= Max_Depth then
         Fail (State, "nesting depth exceeded");
      end if;
      State.Depth := State.Depth + 1;
      if Peek (State) = '{' then
         declare
            Old_Font : constant Font_Kind := State.Font_Mode;
            Old_Has_Font : constant Boolean := State.Has_Font_Mode;
         begin
            Math_Macros.Begin_Group (State.Shared.all);
            Advance (State);
            Result := Parse_Expression (State, True, "", False);
            if Peek (State) /= '}' then
               Fail (State, "missing closing brace");
            end if;
            Math_Macros.End_Group (State.Shared.all);
            State.Font_Mode := Old_Font;
            State.Has_Font_Mode := Old_Has_Font;
         exception
            when Parse_Failure =>
               State.Font_Mode := Old_Font;
               State.Has_Font_Mode := Old_Has_Font;
               raise;
         end;
         Advance (State);
      else
         if Peek (State) = Character'Val (0) or else Peek (State) = '^' or else
             Peek (State) = '_' or else Peek (State) = '}'
         then
            Fail (State, "missing argument");
         end if;
         Result := Parse_Atom (State);
      end if;
      State.Depth := State.Depth - 1;
      return Result;
   end Parse_Argument;

   function Parse_Expression
     (State : in out Parser_State;
      Grouped : Boolean;
      Stop_Environment : String := "";
      Stop_Separators : Boolean := True;
      Stop_Dollar : Boolean := False;
      Stop_At_Expression_Boundary : Boolean := False;
      Stop_CD_Start : Boolean := False;
      Stop_CD_Arrow : Character := Character'Val (0);
      Stop_Square : Boolean := False) return Node_Id is
      Start : constant Natural := State.Cursor_Pos;
      Row : Node;
      Row_Id : Node_Id;
      Tail : Node_Id := No_Node;
      Part : Node_Id;
      Sup : Node_Id;
      Sub : Node_Id;
      Base : Node_Id;
      Marker : Character;
      Infix_Id : Node_Id := No_Node;
      Infix_Tail : Node_Id := No_Node;
      Infix_Count : Natural := 0;
      Infix_Code : Natural := 0;
      Numerator_Row : Node_Id := No_Node;
      Denominator_Row : Node_Id := No_Node;
      Fraction_Id : Node_Id := No_Node;
      Fraction : Node;
      Numerator : Node;
      Denominator : Node;
   begin
      Row.Kind := Row_Node;
      Row.Position := Positive (Natural'Max (1, Start));
      Row_Id := Add (State, Row);
      Skip_Whitespace (State);
      loop
         Skip_Whitespace (State);
         exit when Peek (State) = Character'Val (0);
         exit when Grouped and then Peek (State) = '}';
         exit when Grouped and then Stop_Square and then
           Peek (State) = ']';
         exit when Stop_Dollar and then Peek (State) = '$';
         exit when not Grouped and then Stop_CD_Start and then
           State.CD_Mode and then Peek (State) = '@';
         exit when not Grouped and then
           Stop_CD_Arrow /= Character'Val (0) and then
           State.CD_Mode and then Peek (State) = Stop_CD_Arrow;
         exit when Stop_At_Expression_Boundary and then
           (Command_Is (State, "\right") or else
            State.Current.Kind = Math_Tokens.Alignment or else
            Command_Is (State, "\\"));
         exit when not Grouped and then Command_Is (State, "\right");
         exit when Stop_Environment'Length > 0 and then
           (((Stop_Separators or State.CD_Mode) and then
             State.Current.Kind = Math_Tokens.Alignment) or else
            Command_Is (State, "\\") or else
            Is_Environment_End (State, Stop_Environment));
         if Peek (State) = '$' and then State.Dollar_Math_Allowed then
            Advance (State);
            Part := Parse_Expression (State, True, "", False, True);
            if Peek (State) /= '$' then
               Fail (State, "missing closing math delimiter", Start);
            end if;
            Advance (State);
         elsif Peek (State) = '}' then
            Fail (State, "unmatched closing brace");
         else
            Part := Parse_Atom (State);
         end if;
         if State.Item.Nodes (Positive (Part)).Kind = Text_Run_Node then
            declare
               Run : Node := State.Item.Nodes (Positive (Part));
            begin
               while State.Current.Kind = Math_Tokens.Character_Token and then
                 State.Current.Code_Point >= 16#80# and then
                 State.Regular_Mode and then
                 not Math_Symbols.Lookup_Text
                   (To_String (State.Current.Lexeme)).Found and then
                 Math_Unicode.Is_Script_Data (State.Current.Code_Point) and then
                 Profile_For (State.Current.Code_Point) = Run.Text_Run_Profile
               loop
                  Append (Run.Text_Run_Text, To_String (State.Current.Lexeme));
                  Advance (State);
               end loop;
               State.Item.Nodes.Replace_Element (Positive (Part), Run);
            end;
         end if;
         Skip_Whitespace (State);
         Sup := No_Node;
         Sub := No_Node;
         declare
            Limits : Boolean :=
              State.Item.Nodes (Positive (Part)).Code_Point = 1 or else
              State.Item.Nodes (Positive (Part)).Script_Type = Limit_Scripts;
            Script_Modifier : Natural := 0;
         begin
            if Command_Is (State, "\limits") or else
              Command_Is (State, "\nolimits") or else
              Command_Is (State, "\displaylimits")
            then
               if State.Item.Nodes (Positive (Part)).Class /= Operator_Atom
               then
                  Fail (State, "limit modifier requires an operator");
               end if;
               Limits := Command_Is (State, "\limits") or else
                 Command_Is (State, "\displaylimits");
               Script_Modifier :=
                 (if Command_Is (State, "\limits") then 1
                  elsif Command_Is (State, "\nolimits") then 2 else 3);
               Advance (State);
            end if;
            while Peek (State) = '^' or else Peek (State) = '_' loop
               Marker := Peek (State);
               Advance (State);
               if (Marker = '^' and then Sup /= No_Node) or else
                 (Marker = '_' and then Sub /= No_Node)
               then
                  Fail (State, "duplicate script marker", State.Cursor_Pos - 1);
               end if;
               Skip_Whitespace (State);
               if Peek (State) = Character'Val (0) or else
                   Peek (State) = '^' or else Peek (State) = '_' or else
                   Peek (State) = '}'
               then
                  Fail (State, "missing script argument");
               end if;
               Base := Parse_Argument (State);
               Skip_Whitespace (State);
               if Marker = '^' then
                  Sup := Base;
               else
                  Sub := Base;
               end if;
            end loop;
            if Sup /= No_Node or else Sub /= No_Node then
               Row.Kind := Row_Node;
               declare
                  Scripts : Node;
               begin
                  Scripts.Kind := Scripts_Node;
                  Scripts.Class :=
                    State.Item.Nodes (Positive (Part)).Class;
                  Scripts.First := Part;
                  Scripts.Second := Sup;
                  Scripts.Third := Sub;
                  Scripts.Script_Type :=
                    (if Limits then Limit_Scripts else Side_Scripts);
                  Scripts.Code_Point := Script_Modifier;
                  Scripts.Position :=
                    State.Item.Nodes (Positive (Part)).Position;
                  Part := Add (State, Scripts);
               end;
            end if;
         end;
         if State.Item.Nodes (Positive (Part)).Kind = Space_Node and then
           State.Item.Nodes (Positive (Part)).Code_Point in 1 .. 6
         then
            Infix_Count := Infix_Count + 1;
            if Infix_Count > 1 then
               Fail (State, "only one infix operator per group",
                 State.Item.Nodes (Positive (Part)).Position);
            end if;
            Infix_Id := Part;
            Infix_Code := State.Item.Nodes (Positive (Part)).Code_Point;
            Infix_Tail := Tail;
         end if;
         if Tail = No_Node then
            Row := State.Item.Nodes (Positive (Row_Id));
            Row.First := Part;
            State.Item.Nodes.Replace_Element (Positive (Row_Id), Row);
         else
            Row := State.Item.Nodes (Positive (Tail));
            Row.Next := Part;
            State.Item.Nodes.Replace_Element (Positive (Tail), Row);
         end if;
         Tail := Part;
      end loop;
      if Infix_Id /= No_Node then
         if Infix_Tail = No_Node or else
           State.Item.Nodes (Positive (Infix_Id)).Next = No_Node
         then
            Fail (State, "infix fraction requires both operands",
              State.Item.Nodes (Positive (Infix_Id)).Position);
         end if;
         Numerator := (Kind => Row_Node, First =>
           State.Item.Nodes (Positive (Row_Id)).First,
           Position => State.Item.Nodes (Positive (Row_Id)).Position,
           others => <>);
         Denominator := (Kind => Row_Node,
           First => State.Item.Nodes (Positive (Infix_Id)).Next,
           Position => State.Item.Nodes
             (Positive (State.Item.Nodes (Positive (Infix_Id)).Next)).Position,
           others => <>);
         Numerator_Row := Add (State, Numerator);
         Denominator_Row := Add (State, Denominator);
         if Infix_Tail /= No_Node then
            declare
               Last_Num : Node_Id := State.Item.Nodes
                 (Positive (Row_Id)).First;
               Last_Value : Node;
            begin
               while Last_Num /= Infix_Tail loop
                  Last_Num := State.Item.Nodes (Positive (Last_Num)).Next;
               end loop;
               Last_Value := State.Item.Nodes (Positive (Last_Num));
               Last_Value.Next := No_Node;
               State.Item.Nodes.Replace_Element
                 (Positive (Last_Num), Last_Value);
            end;
         end if;
         declare
            Marker_Value : constant Node :=
              State.Item.Nodes (Positive (Infix_Id));
         begin
            Fraction.Kind := Fraction_Node;
            Fraction.First := Numerator_Row;
            Fraction.Second := Denominator_Row;
            Fraction.Position := Marker_Value.Position;
            Fraction.Fraction_Bar :=
              (if Infix_Code = 2 or else Infix_Code = 3 or else
                 Infix_Code = 4 or else Infix_Code = 5 or else
                 (Infix_Code = 6 and then Marker_Value.Amount <= 0.0)
               then No_Rule
               elsif Infix_Code = 6 then Custom_Rule
               else Default_Rule);
            Fraction.Fraction_Rule_Thickness :=
              (if Infix_Code = 6 then Marker_Value.Amount else -1.0);
            Fraction.Fraction_Style_Mode := Natural_Style;
            Fraction.Fraction_Type := Default_Fraction;
            Fraction.Left_Delimiter :=
              (if Infix_Code = 2 then Parenthesis_Delimiter
               elsif Infix_Code = 4 then Brace_Delimiter
               elsif Infix_Code = 5 then Bracket_Delimiter
               else No_Delimiter);
            Fraction.Right_Delimiter := Fraction.Left_Delimiter;
            Fraction_Id := Add (State, Fraction);
         end;
         Row := State.Item.Nodes (Positive (Row_Id));
         Row.First := Fraction_Id;
         State.Item.Nodes.Replace_Element (Positive (Row_Id), Row);
      end if;
      return Row_Id;
   end Parse_Expression;

   function Parse
     (Source : String; Shared : not null access Math_Macros.Context;
      Global_Group : Boolean := False;
      Work : Math_Work_Control.Context_Access := null) return Document is
   begin
      return Parse
        (Source, Shared, (Strict => Strict_Warn, others => <>),
         Global_Group, Work);
   end Parse;

   function Parse
     (Source : String; Settings : Options;
      Work : Math_Work_Control.Context_Access := null) return Document is
      Shared : aliased Math_Macros.Context;
   begin
      return Parse (Source, Shared'Access, Settings, Work => Work);
   end Parse;

   function Parse
     (Source : String; Shared : not null access Math_Macros.Context;
      Settings : Options; Global_Group : Boolean := False;
      Work : Math_Work_Control.Context_Access := null) return Document
   is
      State : Parser_State (Shared);
      Entry_Depth : constant Natural := Math_Macros.Scope_Depth (Shared.all);
      Validated : Math_Source.Source;
      Tokens : Math_Tokens.Stream;
      Diagnostic : Math_Source.Diagnostic_Kind;
      Lexical_Error : Math_Tokens.Diagnostic_Kind;
      Error_Byte : Natural;
   begin
      State.Settings := Settings;
      State.Work := Work;
      if Source'Length > Max_Source_Bytes then
         State.Item.Text := To_Unbounded_String
           (Source (Source'First .. Source'First + Max_Source_Bytes - 1));
         State.Item.Message :=
           To_Unbounded_String ("source byte limit exceeded");
         State.Item.Failure := Max_Source_Bytes + 1;
         State.Item.Diagnostics.Append
           (New_Item => Math_Syntax.Diagnostic'
              (Kind => Parse_Error, Message => State.Item.Message,
               Position => State.Item.Failure));
         return State.Item;
      end if;
      State.Item.Text := To_Unbounded_String (Source);
      Math_Source.Create
        ((if Source'Length = 0 then " " else Source), Validated,
         Diagnostic, Error_Byte, Work => Work);
      if Diagnostic /= Math_Source.No_Error then
         State.Item.Message := To_Unbounded_String
           (if Diagnostic = Math_Source.Invalid_UTF8
            then "invalid UTF-8 in math source"
            else "forbidden control in math source");
         State.Item.Failure := Error_Byte + 1;
         State.Item.Diagnostics.Append
           (New_Item => Math_Syntax.Diagnostic'
              (Kind => Parse_Error, Message => State.Item.Message,
               Position => State.Item.Failure));
         return State.Item;
      end if;
      declare
         First : Integer := Source'First;
      begin
         while First <= Source'Last and then
           Is_Math_Whitespace (Source (First))
         loop
            First := First + 1;
         end loop;
         if First < Source'Last and then Source (First) = '<' and then
           Source (First + 1) in 'A' .. 'Z' | 'a' .. 'z'
         then
            State.Item.Message := To_Unbounded_String
              ("XML-like markup is not supported as math syntax");
            State.Item.Failure := First - Source'First + 1;
            State.Item.Diagnostics.Append
              (New_Item => Math_Syntax.Diagnostic'
                 (Kind => Parse_Error, Message => State.Item.Message,
                  Position => State.Item.Failure));
            return State.Item;
         end if;
      end;
      Math_Tokens.Lex
        (Validated, Tokens, Lexical_Error, Error_Byte, Work => Work);
      if Lexical_Error /= Math_Tokens.No_Error then
         State.Item.Message := To_Unbounded_String
           ("invalid math token stream: " & Lexical_Error'Image);
         State.Item.Failure := Error_Byte + 1;
         State.Item.Diagnostics.Append
           (New_Item => Math_Syntax.Diagnostic'
              (Kind => Parse_Error, Message => State.Item.Message,
               Position => State.Item.Failure));
         return State.Item;
      end if;

      Math_Expander.Open
        (Tokens, State.Cursor, Max_Expand => Settings.Max_Expand,
         Work => Work);
      if not Global_Group then
         Math_Macros.Begin_Group (Shared.all);
      end if;
      begin

         if Source'Length = 0 then
            State.Current := (Kind => Math_Tokens.End_Of_Input, others => <>);
            State.Item.Root_Id := Add
              (State, Node'(Kind => Row_Node, Position => 1, others => <>));
         else
            Advance (State);
            Skip_Whitespace (State);
            State.Item.Root_Id := Parse_Expression (State, False);
         end if;
         if State.Current.Kind /= Math_Tokens.End_Of_Input then
            Fail (State, "unexpected trailing input");
         end if;
         if State.Pending_Tag /= No_Node and then not State.AMS_Row then
            declare
               Tag_Wrapper : Node;
            begin
               Tag_Wrapper.Kind := Row_Node;
               Tag_Wrapper.First := Add
                 (State, Node'(Kind => Tagged_Node,
                   First => State.Item.Root_Id,
                   Second => State.Pending_Tag,
                   Tag_Is_Left => State.Settings.Left_Tags,
                   Position => 1, others => <>));
               Tag_Wrapper.Position := 1;
               State.Item.Root_Id := Add (State, Tag_Wrapper);
            end;
         end if;
      exception
         when Parse_Failure =>
            State.Item.Root_Id := No_Node;
            State.Item.Nodes.Clear;
      end;
      Math_Macros.Restore_To_Depth (Shared.all, Entry_Depth);
      return State.Item;
   exception
      when others =>
         Math_Macros.Restore_To_Depth (Shared.all, Entry_Depth);
         raise;
   end Parse;

   function Parse
     (Source : String;
      Work : Math_Work_Control.Context_Access := null) return Document is
   begin
      return Parse
        (Source, (Strict => Strict_Warn, others => <>), Work);
   end Parse;

   function Is_Valid (Item : Document) return Boolean is
   begin
      return Length (Item.Message) = 0 and then Item.Root_Id /= No_Node;
   end Is_Valid;

   function Source (Item : Document) return String is
   begin
      return To_String (Item.Text);
   end Source;

   function Error (Item : Document) return String is
   begin
      return To_String (Item.Message);
   end Error;

   function Error_Position (Item : Document) return Natural is
   begin
      return Item.Failure;
   end Error_Position;

   function Root (Item : Document) return Node_Id is
   begin
      return Item.Root_Id;
   end Root;

   function Count (Item : Document) return Natural is
   begin
      return Natural (Item.Nodes.Length);
   end Count;

   function Element (Item : Document; Id : Positive) return Node is
   begin
      return Item.Nodes (Id);
   end Element;

   function Diagnostic_Count (Item : Document) return Natural is
     (Natural (Item.Diagnostics.Length));

   function Diagnostic_At
     (Item : Document; Index : Positive) return Diagnostic is
     (Item.Diagnostics (Index));

end Math_Syntax;
