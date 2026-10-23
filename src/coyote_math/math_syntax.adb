with Ada.Strings.Unbounded;
with Math_Model;

package body Math_Syntax is
   use Ada.Strings.Unbounded;
   use Math_Model;

   Parse_Failure : exception;

   type Parser_State is record
      Item : Document;
      Input : String (1 .. Max_Source_Bytes) := (others => ASCII.NUL);
      Last : Natural := 0;
      Cursor_Pos : Natural := 1;
      Depth : Natural := 0;
      Regular_Mode : Boolean := False;
      Font_Mode : Font_Kind := Math_Italic;
      Has_Font_Mode : Boolean := False;
   end record;

   procedure Fail
     (State : in out Parser_State;
      Why : String;
      Where : Natural := 0) is
   begin
      if Length (State.Item.Message) = 0 then
         State.Item.Message := To_Unbounded_String (Why);
         State.Item.Failure := (if Where = 0 then State.Cursor_Pos else Where);
      end if;
      raise Parse_Failure;
   end Fail;

   function Peek (State : Parser_State) return Character is
   begin
      if State.Cursor_Pos > State.Last then
         return Character'Val (0);
      end if;
      return State.Input (State.Cursor_Pos);
   end Peek;

   procedure Advance (State : in out Parser_State);

   function Is_Math_Whitespace (Char : Character) return Boolean is
   begin
      return Char = ' ' or else Char = ASCII.HT or else
          Char = ASCII.LF or else Char = ASCII.CR;
   end Is_Math_Whitespace;

   procedure Skip_Whitespace (State : in out Parser_State) is
   begin
      if not State.Regular_Mode then
         while Is_Math_Whitespace (Peek (State)) loop
            Advance (State);
         end loop;
      end if;
   end Skip_Whitespace;

   procedure Advance (State : in out Parser_State) is
   begin
      State.Cursor_Pos := State.Cursor_Pos + 1;
   end Advance;

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
   begin
      Fresh.Kind := Glyph_Node;
      Fresh.Code_Point := Point;
      Fresh.Class := Class;
      Fresh.Font := (if State.Regular_Mode then Main_Regular else
                     (if State.Has_Font_Mode then State.Font_Mode else Font));
      Fresh.Position := Positive (Natural'Max (1, Position));
      return Add (State, Fresh);
   end New_Glyph;

   function Parse_Expression
     (State : in out Parser_State;
      Grouped : Boolean;
      Stop_Environment : String := "";
      Stop_Separators : Boolean := True) return Node_Id;

   function Is_Environment_End
     (State : Parser_State;
      Name : String) return Boolean is
      Probe : Natural := State.Cursor_Pos;
   begin
      if Probe > State.Last or else State.Input (Probe) /= '\' then
         return False;
      end if;
      Probe := Probe + 1;
      if Probe + 2 > State.Last or else
          State.Input (Probe .. Probe + 2) /= "end"
      then
         return False;
      end if;
      Probe := Probe + 3;
      while Probe <= State.Last and then
        Is_Math_Whitespace (State.Input (Probe))
      loop
         Probe := Probe + 1;
      end loop;
      if Probe > State.Last or else State.Input (Probe) /= '{' then
         return False;
      end if;
      Probe := Probe + 1;
      for K in Name'Range loop
         if Probe > State.Last or else State.Input (Probe) /= Name (K) then
            return False;
         end if;
         Probe := Probe + 1;
      end loop;
      return Probe <= State.Last and then State.Input (Probe) = '}';
   end Is_Environment_End;

   function Parse_Array
     (State : in out Parser_State;
      Name : String;
      Start : Natural) return Node_Id;

   function Parse_Argument (State : in out Parser_State) return Node_Id;

   function Read_Command (State : in out Parser_State) return String is
      Start : Natural;
      Last : Natural;
   begin
      Advance (State);
      if Peek (State) = Character'Val (0) then
         Fail (State, "incomplete command", State.Cursor_Pos - 1);
      end if;
      if Peek (State) in 'A' .. 'Z' or else Peek (State) in 'a' .. 'z' then
         Start := State.Cursor_Pos;
         while Peek (State) in 'A' .. 'Z' or else
           Peek (State) in 'a' .. 'z'
         loop
            Advance (State);
         end loop;
         Last := State.Cursor_Pos - 1;
         Skip_Whitespace (State);
         return State.Input (Start .. Last);
      end if;
      Start := State.Cursor_Pos;
      Advance (State);
      return State.Input (Start .. Start);
   end Read_Command;

   function Symbol
     (Name : String;
      Point : out Natural;
      Class : out Atom_Class;
      Font : out Font_Kind) return Boolean is
   begin
      Class := Ordinary;
      Font := Math_Italic;
      if Name = "alpha" then Point := 16#03B1#;
      elsif Name = "beta" then Point := 16#03B2#;
      elsif Name = "gamma" then Point := 16#03B3#;
      elsif Name = "delta" then Point := 16#03B4#;
      elsif Name = "epsilon" then Point := 16#03F5#;
      elsif Name = "zeta" then Point := 16#03B6#;
      elsif Name = "eta" then Point := 16#03B7#;
      elsif Name = "theta" then Point := 16#03B8#;
      elsif Name = "iota" then Point := 16#03B9#;
      elsif Name = "kappa" then Point := 16#03BA#;
      elsif Name = "lambda" then Point := 16#03BB#;
      elsif Name = "mu" then Point := 16#03BC#;
      elsif Name = "nu" then Point := 16#03BD#;
      elsif Name = "xi" then Point := 16#03BE#;
      elsif Name = "pi" then Point := 16#03C0#;
      elsif Name = "rho" then Point := 16#03C1#;
      elsif Name = "sigma" then Point := 16#03C3#;
      elsif Name = "tau" then Point := 16#03C4#;
      elsif Name = "upsilon" then Point := 16#03C5#;
      elsif Name = "phi" then Point := 16#03D5#;
      elsif Name = "chi" then Point := 16#03C7#;
      elsif Name = "psi" then Point := 16#03C8#;
      elsif Name = "omega" then Point := 16#03C9#;
      elsif Name = "Gamma" then Point := 16#0393#;Font := Main_Regular;
      elsif Name = "Delta" then Point := 16#0394#;Font := Main_Regular;
      elsif Name = "Theta" then Point := 16#0398#;Font := Main_Regular;
      elsif Name = "Lambda" then Point := 16#039B#;Font := Main_Regular;
      elsif Name = "Xi" then Point := 16#039E#;Font := Main_Regular;
      elsif Name = "Pi" then Point := 16#03A0#;Font := Main_Regular;
      elsif Name = "Sigma" then Point := 16#03A3#;Font := Main_Regular;
      elsif Name = "Phi" then Point := 16#03A6#;Font := Main_Regular;
      elsif Name = "Psi" then Point := 16#03A8#;Font := Main_Regular;
      elsif Name = "Omega" then Point := 16#03A9#;Font := Main_Regular;
      elsif Name = "infty" then Point := 16#221E#;Font := Main_Regular;
      elsif Name = "lim" or else Name = "max" or else
        Name = "min"
      then
         Point := Character'Pos (Name (Name'First));
         Class := Operator_Atom;
         Font := Main_Regular;
      elsif Name = "times" then
         Point := 16#00D7#;
         Class := Binary_Atom;
         Font := Main_Regular;
      elsif Name = "in" then
         Point := 16#2208#;
         Class := Relation_Atom;
         Font := Main_Regular;
      elsif Name = "to" or else Name = "rightarrow" then
         Point := 16#2192#;
         Class := Relation_Atom;
         Font := Main_Regular;
      elsif Name = "leftarrow" then
         Point := 16#2190#;
         Class := Relation_Atom;
         Font := Main_Regular;
      elsif Name = "leftrightarrow" then
         Point := 16#2194#;
         Class := Relation_Atom;
         Font := Main_Regular;
      elsif Name = "cup" then
         Point := 16#222A#;
         Class := Binary_Atom;
         Font := Main_Regular;
      elsif Name = "cap" then
         Point := 16#2229#;
         Class := Binary_Atom;
         Font := Main_Regular;
      elsif Name = "forall" then
         Point := 16#2200#;
         Class := Ordinary;
         Font := Main_Regular;
      elsif Name = "exists" then
         Point := 16#2203#;
         Class := Ordinary;
         Font := Main_Regular;
      elsif Name = "partial" then
         Point := 16#2202#;
         Class := Ordinary;
         Font := Main_Regular;
      elsif Name = "nabla" then
         Point := 16#2207#;
         Class := Ordinary;
         Font := Main_Regular;
      elsif Name = "ldots" or else Name = "dots" then
         Point := 16#2026#;
         Class := Ordinary;
         Font := Main_Regular;
      elsif Name = "cdot" then
         Point := 16#22C5#;
         Class := Binary_Atom;
         Font := Main_Regular;
      elsif Name = "pm" then
         Point := 16#00B1#;
         Class := Binary_Atom;
         Font := Main_Regular;
      elsif Name = "le" or else Name = "leq" then
         Point := 16#2264#;
         Class := Relation_Atom;
         Font := Main_Regular;
      elsif Name = "ne" or else Name = "neq" then
         Point := Character'Pos ('=');
         Class := Relation_Atom;
         Font := Main_Regular;
      elsif Name = "ge" or else Name = "geq" then
         Point := 16#2265#;
         Class := Relation_Atom;
         Font := Main_Regular;
      else
         return False;
      end if;
      return True;
   end Symbol;

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

   function Parse_Atom (State : in out Parser_State) return Node_Id is
      Start : constant Natural := State.Cursor_Pos;
      Char : constant Character := Peek (State);
      Name : Unbounded_String;
      Point : Natural;
      Class : Atom_Class;
      Font : Font_Kind;
      Fresh : Node;
      Id : Node_Id;
   begin
      if Char = '\' then
         Name := To_Unbounded_String (Read_Command (State));
         declare
            Word : constant String := To_String (Name);
         begin
            if Word = "left" then
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
                  Env_Start : constant Natural := State.Cursor_Pos;
               begin
                  while Peek (State) in 'A' .. 'Z' or else
                    Peek (State) in 'a' .. 'z'
                  loop
                     Advance (State);
                  end loop;
                  if Peek (State) /= '}' or Env_Start = State.Cursor_Pos then
                     Fail (State, "invalid environment name", Env_Start);
                  end if;
                  declare
                     Env_Name : constant String :=
                       State.Input (Env_Start .. State.Cursor_Pos - 1);
                  begin
                     Advance (State);
                     return Parse_Array (State, Env_Name, Start);
                  end;
               end;
            elsif Word = "frac" or else Word = "dfrac" or else
                Word = "tfrac"
            then
               declare
                  Numerator : constant Node_Id := Parse_Argument (State);
                  Denom : constant Node_Id := Parse_Argument (State);
               begin
                  Fresh.Kind := Fraction_Node;
                  Fresh.First := Numerator;
                  Fresh.Second := Denom;
                  Fresh.Fraction_Type :=
                    (if Word = "dfrac" then Display_Fraction else
                     (if Word = "tfrac" then Text_Fraction else
                      Default_Fraction));
                  Fresh.Position := Positive (Start);
                  return Add (State, Fresh);
               end;
            elsif Word in "mathbf" | "mathbb" | "mathcal" then
               declare
                  Old_Font : constant Font_Kind := State.Font_Mode;
                  Old_Active : constant Boolean := State.Has_Font_Mode;
                  Content : Node_Id;
                  Cursor : Node_Id;
                  Glyph : Node;
               begin
                  State.Font_Mode :=
                    (if Word = "mathbf" then Main_Bold else
                     (if Word = "mathbb" then AMS_Regular else
                      Caligraphic_Regular));
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
            elsif Word = "hat" or else Word = "bar" or else
              Word = "vec"
            then
               declare
                  Base : constant Node_Id := Parse_Argument (State);
                  Accent : constant Node := State.Item.Nodes
                    (Positive (Base));
                  Mark : constant Natural :=
                    (if Word = "hat" then 16#2C6# elsif Word = "bar" then
                     0 else 16#2192#);
               begin
                  Fresh.Kind := Accent_Node;
                  Fresh.First := Base;
                  Fresh.Code_Point := Mark;
                  Fresh.Position := Positive (Start);
                  return Add (State, Fresh);
               end;
            elsif Word = "text" or else Word = "mathrm" then
               declare
                  Old_Mode : constant Boolean := State.Regular_Mode;
                  Content : Node_Id;
               begin
                  State.Regular_Mode := True;
                  Content := Parse_Argument (State);
                  State.Regular_Mode := Old_Mode;
                  return Content;
               exception
                  when Parse_Failure =>
                     State.Regular_Mode := Old_Mode;
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
                     Index_Node := Parse_Expression (State, True);
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
            elsif Word = "," or else Word = ";" or else Word = "!" or else
                Word = "quad"
            then
               Fresh.Kind := Space_Node;
               Fresh.Position := Positive (Start);
               if Word = "," then Fresh.Amount := 0.166_667;
               elsif Word = ";" then Fresh.Amount := 0.277_778;
               elsif Word = "!" then Fresh.Amount := -0.166_667;
               else Fresh.Amount := 1.0;
               end if;
               return Add (State, Fresh);
            elsif Word = "sum" or else Word = "prod" or else Word = "int" then
               Point := (if Word = "sum" then 16#2211# else
                    (if Word = "prod" then 16#220F# else 16#222B#));
               return New_Glyph (State, Point, Operator_Atom, Size_1, Start);
            elsif Word = "sin" or else Word = "cos" or else
                Word = "tan" or else Word = "log" or else
                Word = "ln" or else Word = "exp"
            then
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
               if not Symbol (Word, Point, Class, Font) then
                  Fail (State, "unknown command: \" & Word, Start);
               end if;
               if Word = "ne" or else Word = "neq" then
                  Fresh.Kind := Overlay_Node;
                  Fresh.First := New_Glyph
                    (State, Character'Pos ('='), Class, Font, Start);
                  Fresh.Second := New_Glyph
                    (State, Character'Pos ('/'), Class, Main_Regular, Start);
                  Fresh.Position := Positive (Start);
                  return Add (State, Fresh);
               end if;
               return New_Glyph (State, Point, Class, Font, Start);
            end if;
         end;
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
         return New_Glyph
             (State, 32, Ordinary, Main_Regular, Start);
      elsif Char = '+' or else Char = '-' then
         Advance (State);
         return New_Glyph
             (State,
              (if Char = '-' then 16#2212# else Character'Pos (Char)),
              Binary_Atom, Main_Regular, Start);
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
      elsif Char = '&' then
         Advance (State);
         return New_Glyph
             (State, Character'Pos (Char), Ordinary, Main_Regular, Start);
      elsif Char = ',' or else Char = ';' then
         Advance (State);
         return New_Glyph
             (State, Character'Pos (Char), Punctuation, Main_Regular, Start);
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
      Is_Aligned : constant Boolean := Name = "aligned" or else
          Name = "align";
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
         Advance (State);
      end Consume_End;
   begin
      if State.Depth >= Max_Depth then
         Fail (State, "nesting depth exceeded", Start);
      end if;
      State.Depth := State.Depth + 1;
      if Name not in "matrix" | "pmatrix" | "bmatrix" | "Bmatrix" |
          "vmatrix" | "Vmatrix" | "cases" | "aligned" | "align" |
          "gathered"
      then
         Fail (State, "unknown environment: " & Name, Start);
      end if;
      Fresh.Kind := Array_Node;
      Fresh.Array_Type := (if Name = "cases" then Cases_Array else
           (if Is_Aligned then Aligned_Array else Matrix_Array));
      Fresh.Position := Positive (Start);
      if Name = "pmatrix" then
         Fresh.Left_Delimiter := Parenthesis_Delimiter;
         Fresh.Right_Delimiter := Parenthesis_Delimiter;
      elsif Name = "bmatrix" then
         Fresh.Left_Delimiter := Bracket_Delimiter;
         Fresh.Right_Delimiter := Bracket_Delimiter;
      elsif Name = "Bmatrix" or else Name = "cases" then
         Fresh.Left_Delimiter := Brace_Delimiter;
         if Name /= "cases" then
            Fresh.Right_Delimiter := Brace_Delimiter;
         end if;
      elsif Name = "vmatrix" then
         Fresh.Left_Delimiter := Bar_Delimiter;
         Fresh.Right_Delimiter := Bar_Delimiter;
      elsif Name = "Vmatrix" then
         Fresh.Left_Delimiter := Double_Bar_Delimiter;
         Fresh.Right_Delimiter := Double_Bar_Delimiter;
      end if;
      Array_Id := Add (State, Fresh);
      New_Row;
      loop
         if End_Matches then
            if Cell_Tail = No_Node then
               Fail (State, "empty array cell", State.Cursor_Pos);
            end if;
            Append_Row;
            Consume_End;
            exit;
         elsif Peek (State) = Character'Val (0) then
            Fail (State, "missing environment end", Start);
         elsif Peek (State) = '&' then
            Fail (State, "empty array cell", State.Cursor_Pos);
         elsif Peek (State) = '\' and then
             State.Cursor_Pos < State.Last and then
             State.Input (State.Cursor_Pos + 1) = '\'
         then
            Fail (State, "empty array row", State.Cursor_Pos);
         else
            if Current_Columns >= Max_Array_Columns then
               Fail (State, "array column limit exceeded", Start);
            end if;
            Cell_Id := Parse_Expression (State, False, Name);
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
                 (Peek (State) = '\' and then
                    State.Cursor_Pos < State.Last and then
                    State.Input (State.Cursor_Pos + 1) = '\')
               then
                  Fail (State, "empty array cell", State.Cursor_Pos);
               end if;
            elsif Peek (State) = '\' and then
                State.Cursor_Pos < State.Last and then
                State.Input (State.Cursor_Pos + 1) = '\'
            then
               Advance (State);
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
      if Is_Aligned and then (Column_Count < 2 or else
             Column_Count mod 2 /= 0)
      then
         Fail (State, "aligned environment needs column pairs", Start);
      end if;
      if Name = "gathered" and then Column_Count /= 1 then
         Fail (State, "gathered environment has one column", Start);
      end if;
      State.Depth := State.Depth - 1;
      return Array_Id;
   end Parse_Array;

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
         Advance (State);
         Result := Parse_Expression (State, True, "", False);
         if Peek (State) /= '}' then
            Fail (State, "missing closing brace");
         end if;
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
      Stop_Separators : Boolean := True) return Node_Id is
      Start : constant Natural := State.Cursor_Pos;
      Row : Node;
      Row_Id : Node_Id;
      Tail : Node_Id := No_Node;
      Part : Node_Id;
      Sup : Node_Id;
      Sub : Node_Id;
      Base : Node_Id;
      Marker : Character;
   begin
      Row.Kind := Row_Node;
      Row.Position := Positive (Natural'Max (1, Start));
      Row_Id := Add (State, Row);
      Skip_Whitespace (State);
      loop
         Skip_Whitespace (State);
         exit when Peek (State) = Character'Val (0);
         exit when Grouped and then
           (Peek (State) = '}' or else Peek (State) = ']');
         exit when not Grouped and then Peek (State) = '\' and then
           State.Cursor_Pos < State.Last and then
           State.Input (State.Cursor_Pos + 1) = 'r' and then
           State.Input (State.Cursor_Pos ..
             Natural'Min (State.Last, State.Cursor_Pos + 5)) = "\right";
         exit when Stop_Environment'Length > 0 and then
           ((Stop_Separators and then Peek (State) = '&') or else
            (Peek (State) = '\' and then
               State.Cursor_Pos < State.Last and then
             (State.Input (State.Cursor_Pos + 1) = '\' or else
              Is_Environment_End (State, Stop_Environment))));
         if Peek (State) = '}' then
            Fail (State, "unmatched closing brace");
         end if;
         Part := Parse_Atom (State);
         Skip_Whitespace (State);
         Sup := No_Node;
         Sub := No_Node;
         declare
            Limits : Boolean := False;
         begin
            if Peek (State) = '\' and then
              State.Cursor_Pos + 6 <= State.Last and then
              State.Input (State.Cursor_Pos .. State.Cursor_Pos + 6) =
                "\limits"
            then
               if State.Item.Nodes (Positive (Part)).Class /= Operator_Atom
               then
                  Fail (State, "\limits requires an operator");
               end if;
               for J in 1 .. 7 loop
                  Advance (State);
               end loop;
               Limits := True;
            end if;
         while Peek (State) = '^' or else Peek (State) = '_' loop
            Marker := Peek (State);
            Advance (State);
            if (Marker = '^' and Sup /= No_Node) or else
              (Marker = '_' and Sub /= No_Node)
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
            if Marker = '^' then Sup := Base;else Sub := Base;end if;
         end loop;
         if Sup /= No_Node or else Sub /= No_Node then
            Row.Kind := Row_Node;
            declare
               Scripts : Node;
            begin
               Scripts.Kind := Scripts_Node;
               Scripts.Class := State.Item.Nodes (Positive (Part)).Class;
               Scripts.First := Part;
               Scripts.Second := Sup;
               Scripts.Third := Sub;
               Scripts.Script_Type :=
                 (if Limits then Limit_Scripts else Side_Scripts);
               Scripts.Position := State.Item.Nodes (Positive (Part)).Position;
               Part := Add (State, Scripts);
            end;
         end if;
         end;
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
      if Tail = No_Node and then not Grouped then
         Fail (State, "empty expression");
      end if;
      return Row_Id;
   end Parse_Expression;

   function Parse (Source : String) return Document is
      State : Parser_State;
   begin
      if Source'Length > Max_Source_Bytes then
         --  Keep rejected input bounded; callers retain their source.
            if Source'Length > 0 then
            State.Item.Text := To_Unbounded_String
                (Source (Source'First .. Source'First + Max_Source_Bytes - 1));
         end if;
         State.Item.Message :=
           To_Unbounded_String ("source byte limit exceeded");
         State.Item.Failure := Max_Source_Bytes + 1;
         return State.Item;
      end if;
      State.Item.Text := To_Unbounded_String (Source);
      State.Last := Source'Length;
      if State.Last > 0 then
         declare
            First : Natural := 1;
         begin
            while First <= State.Last and then
              Is_Math_Whitespace (Source (Source'First + First - 1))
            loop
               First := First + 1;
            end loop;
            if First < State.Last and then
              Source (Source'First + First - 1) = '<' and then
              Source (Source'First + First) in 'A' .. 'Z' | 'a' .. 'z'
            then
               State.Item.Message :=
                 To_Unbounded_String
                   ("XML-like markup is not supported as math syntax");
               State.Item.Failure := First;
               return State.Item;
            end if;
         end;
         for Offset in 1 .. State.Last loop
            State.Input (Offset) := Source (Source'First + Offset - 1);
            if State.Input (Offset) = Character'Val (0) then
               State.Item.Message :=
                 To_Unbounded_String ("NUL byte in math source");
               State.Item.Failure := Offset;
               return State.Item;
            end if;
         end loop;
      end if;
      begin
         if State.Last = 0 then
            Fail (State, "empty math expression", 1);
         end if;
         State.Item.Root_Id := Parse_Expression (State, False);
         if State.Cursor_Pos <= State.Last then
            Fail (State, "unexpected trailing input");
         end if;
      exception
         when Parse_Failure =>
            State.Item.Root_Id := No_Node;
            State.Item.Nodes.Clear;
      end;
      return State.Item;
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

end Math_Syntax;
