with Math_Source;
with Math_Builtin_Macros;
with Math_Symbols;
with Math_Model;
with Ada.Containers;
with Ada.Strings.Unbounded;

package body Math_Expander is
   use type Ada.Containers.Count_Type;
   use type Math_Tokens.Token_Kind;
   use type Math_Macros.Diagnostic_Kind;
   use type Math_Source.Diagnostic_Kind;
   use type Math_Tokens.Diagnostic_Kind;

   procedure Open
     (Input : Math_Tokens.Stream; Item : in out Cursor;
      Max_Expand : Positive := Default_Max_Expand;
      Token_Ceiling : Positive := Maximum_Tokens;
      Expansion_Only : Boolean := False) is
   begin
      Item.Input := Input;
      Item.Queue.Clear;
      for I in 1 .. Math_Tokens.Count (Input) loop
         Item.Queue.Append (Math_Tokens.Element (Input, I));
      end loop;
      Item.Position := 1;
      Item.Expanded := 0;
      Item.Returned := 0;
      Item.Token_Ceiling := Positive'Min (Maximum_Tokens, Token_Ceiling);
      Item.Live_Tokens := Math_Tokens.Count (Input);
      Item.Max_Expand := Positive'Min (Maximum_Max_Expand, Max_Expand);
      Item.Status := No_Error;
      Item.Messages.Clear;
      Item.Last_Message := (others => <>);
      Item.Message_Serial := 0;
      if Item.Live_Tokens > Item.Token_Ceiling then
         Item.Status := Token_Limit;
      end if;
      Item.Pushback_Used := False;
      Item.Suppress_Next := False;
      Item.Regular_Mode := False;
      Item.Expansion_Only := Expansion_Only;
      Item.Previous_Middle_Binding.Clear;
      Item.Previous_Double_Binding.Clear;
      Item.Had_Previous_Middle := False;
      Item.Had_Previous_Double := False;
   end Open;

   procedure No_Expand_Next (Item : in out Cursor) is
   begin
      Item.Suppress_Next := True;
   end No_Expand_Next;

   procedure Set_Mode (Item : in out Cursor; Regular : Boolean) is
   begin
      Item.Regular_Mode := Regular;
   end Set_Mode;

   function UTF8 (Point : Natural) return String is
   begin
      if Point < 16#80# then
         return String'(1 => Character'Val (Point));
      elsif Point < 16#800# then
         return Character'Val (16#C0# + Point / 64) &
           Character'Val (16#80# + Point mod 64);
      elsif Point < 16#10000# then
         return Character'Val (16#E0# + Point / 4_096) &
           Character'Val (16#80# + (Point / 64) mod 64) &
           Character'Val (16#80# + Point mod 64);
      else
         return Character'Val (16#F0# + Point / 262_144) &
           Character'Val (16#80# + (Point / 4_096) mod 64) &
           Character'Val (16#80# + (Point / 64) mod 64) &
           Character'Val (16#80# + Point mod 64);
      end if;
   end UTF8;

   procedure Pushback (Item : in out Cursor; Value : Math_Tokens.Token) is
   begin
      if Item.Pushback_Used or else
        Item.Live_Tokens >= Item.Token_Ceiling
      then
         Item.Status := Token_Limit;
      else
         Item.Pushback_Used := True;
         Item.Pushed := Value;
         Item.Live_Tokens := Item.Live_Tokens + 1;
      end if;
   end Pushback;

   function Read_Raw (Item : in out Cursor) return Math_Tokens.Token is
   begin
      if Item.Pushback_Used then
         Item.Pushback_Used := False;
         Item.Live_Tokens := Item.Live_Tokens - 1;
         return Item.Pushed;
      elsif Item.Position <= Natural (Item.Queue.Length) then
         declare
            Value : constant Math_Tokens.Token :=
              Item.Queue (Positive (Item.Position));
         begin
            Item.Position := Item.Position + 1;
            Item.Live_Tokens := Item.Live_Tokens - 1;
            if Item.Position > 1_024 and then
              Item.Position > Natural (Item.Queue.Length) / 2
            then
               Item.Queue.Delete_First
                 (Count => Ada.Containers.Count_Type (Item.Position - 1));
               Item.Position := 1;
            end if;
            return Value;
         end;
      end if;
      return Math_Tokens.Element (Item.Input, Math_Tokens.Count (Item.Input));
   end Read_Raw;

   function Name_Of
     (Item : Cursor; Tok : Math_Tokens.Token) return String is
      pragma Unreferenced (Item);
   begin
      if Tok.Kind not in Math_Tokens.Control_Word |
        Math_Tokens.Control_Symbol
      then
         return "";
      end if;
      declare
         Text : constant String :=
           Ada.Strings.Unbounded.To_String (Tok.Lexeme);
         Last : Natural := Text'Last;
      begin
         if Tok.Kind = Math_Tokens.Control_Word then
            Last := Text'First + 1;
            while Last < Text'Last and then
              Text (Last + 1) in 'A' .. 'Z' | 'a' .. 'z' | '@'
            loop
               Last := Last + 1;
            end loop;
         end if;
         return Text (Text'First .. Last);
      end;
   end Name_Of;

   procedure Queue_At_Cursor
     (Item : in out Cursor; Seq : Math_Macros.Token_Sequence) is
   begin
      if Item.Live_Tokens > Item.Token_Ceiling or else
        Seq'Length > Item.Token_Ceiling - Item.Live_Tokens
      then
         Item.Status := Token_Limit;
         return;
      end if;
      if Item.Pushback_Used then
         Item.Queue.Insert
           (Before => Positive (Item.Position), New_Item => Item.Pushed);
         Item.Pushback_Used := False;
      end if;
      for I in reverse Seq'Range loop
         Item.Queue.Insert
           (Before => Positive (Item.Position), New_Item => Seq (I));
      end loop;
      Item.Live_Tokens := Item.Live_Tokens + Seq'Length;
   end Queue_At_Cursor;


   function Next
     (Item : in out Cursor; Shared : in out Math_Macros.Context)
      return Math_Tokens.Token is
      Tok : Math_Tokens.Token;
   begin
      loop
      <<Iterate>>
      Tok := Read_Raw (Item);
      if Item.Status /= No_Error then
         return Tok;
      end if;
      if Item.Suppress_Next then
         Item.Suppress_Next := False;
         return Tok;
      end if;
      if (Tok.Kind = Math_Tokens.Character_Token and then
          Tok.Code_Point = Character'Pos ('|') and then
          Item.Has_Middle_Binding) or else
        (Tok.Kind = Math_Tokens.Control_Symbol and then
         Name_Of (Item, Tok) = "\|" and then
         Item.Has_Double_Binding)
      then
         declare
            Is_Double : Boolean :=
              Tok.Kind = Math_Tokens.Control_Symbol;
            Look : Math_Tokens.Token;
            Replacement : Token_Vectors.Vector;
         begin
            if Item.Expanded >= Item.Max_Expand then
               Item.Status := Expansion_Limit;
               return Tok;
            end if;
            Item.Expanded := Item.Expanded + 1;
            if not Is_Double and then Item.Has_Double_Binding then
               Look := Read_Raw (Item);
               if Look.Kind = Math_Tokens.Character_Token and then
                 Look.Code_Point = Character'Pos ('|')
               then
                  Is_Double := True;
               elsif Look.Kind /= Math_Tokens.End_Of_Input then
                  Pushback (Item, Look);
               end if;
            end if;
            if Is_Double and then Item.Has_Double_Binding then
               Replacement := Item.Double_Binding;
               if Item.Double_Once then
                  Item.Middle_Binding := Item.Previous_Middle_Binding;
                  Item.Has_Middle_Binding := Item.Had_Previous_Middle;
                  Item.Middle_Once := False;
                  Item.Previous_Middle_Binding.Clear;
                  Item.Had_Previous_Middle := False;
                  Item.Double_Binding := Item.Previous_Double_Binding;
                  Item.Has_Double_Binding := Item.Had_Previous_Double;
                  Item.Double_Once := False;
                  Item.Previous_Double_Binding.Clear;
                  Item.Had_Previous_Double := False;
               end if;
            else
               Replacement := Item.Middle_Binding;
               if Item.Middle_Once then
                  Item.Middle_Binding := Item.Previous_Middle_Binding;
                  Item.Has_Middle_Binding := Item.Had_Previous_Middle;
                  Item.Middle_Once := False;
                  Item.Previous_Middle_Binding.Clear;
                  Item.Had_Previous_Middle := False;
                  Item.Double_Binding := Item.Previous_Double_Binding;
                  Item.Has_Double_Binding := Item.Had_Previous_Double;
                  Item.Double_Once := False;
                  Item.Previous_Double_Binding.Clear;
                  Item.Had_Previous_Double := False;
               end if;
            end if;
            declare
               Seq : Math_Macros.Token_Sequence
                 (1 .. Natural (Replacement.Length));
            begin
               for I in Seq'Range loop
                  Seq (I) := Replacement (Positive (I));
               end loop;
               Queue_At_Cursor (Item, Seq);
            end;
            goto Iterate;
         end;
      end if;
      if Tok.Kind = Math_Tokens.Control_Word then
         declare
            Name : constant String := Name_Of (Item, Tok);
         begin
            if Name = "\char" then
               declare
                  First : Math_Tokens.Token := Read_Raw (Item);
                  Base : Natural := 10;
                  Value : Natural := 0;
                  Digit : Natural := 0;
                  function Digit_Value
                    (Token : Math_Tokens.Token) return Natural is
                     Point : constant Natural := Token.Code_Point;
                  begin
                     if Token.Kind /= Math_Tokens.Character_Token then
                        return 16;
                     elsif Point in 48 .. 57 then return Point - 48;
                     elsif Point in 65 .. 70 then return Point - 55;
                     elsif Point in 97 .. 102 then return Point - 87;
                     else return 16;
                     end if;
                  end Digit_Value;
               begin
                  while First.Kind = Math_Tokens.Space_Token loop
                     First := Read_Raw (Item);
                  end loop;
                  if First.Kind = Math_Tokens.End_Of_Input then
                     Item.Status := Argument_Error;
                     return Tok;
                  elsif First.Code_Point = Character'Pos ('`') then
                     First := Read_Raw (Item);
                     if First.Kind = Math_Tokens.Control_Word or else
                       First.Kind = Math_Tokens.Control_Symbol
                     then
                        declare
                           Text : constant String :=
                             Ada.Strings.Unbounded.To_String (First.Lexeme);
                        begin
                           if Text'Length < 2 then
                              Item.Status := Argument_Error;
                              return Tok;
                           end if;
                           if First.Kind = Math_Tokens.Control_Symbol then
                              Value := First.Code_Point;
                           else
                              Value := Character'Pos
                                (Text (Text'First + 1));
                           end if;
                        end;
                     elsif First.Kind = Math_Tokens.Character_Token then
                        Value := First.Code_Point;
                     else
                        Item.Status := Argument_Error;
                        return Tok;
                     end if;
                  else
                     if First.Code_Point = Character'Pos ('"') then
                        Base := 16;
                        First := Read_Raw (Item);
                     elsif First.Code_Point = Character'Pos (''') then
                        Base := 8;
                        First := Read_Raw (Item);
                     end if;
                     Digit := Digit_Value (First);
                     if Digit >= Base then
                        Item.Status := Argument_Error;
                        return Tok;
                     end if;
                     Value := Digit;
                     loop
                        First := Read_Raw (Item);
                        Digit := Digit_Value (First);
                        exit when Digit >= Base;
                        if Value > (16#10FFFF# - Digit) / Base then
                           Item.Status := Argument_Error;
                           return Tok;
                        end if;
                        Value := Value * Base + Digit;
                     end loop;
                     if First.Kind /= Math_Tokens.End_Of_Input then
                        Pushback (Item, First);
                     end if;
                  end if;
                  if Value >= 16#10FFFF# then
                     Item.Status := Argument_Error;
                     return Tok;
                  end if;
                  Tok.Kind := Math_Tokens.Character_Token;
                  Tok.Code_Point := Value;
                  Tok.Lexeme := Ada.Strings.Unbounded.To_Unbounded_String
                    (UTF8 (Value));
                  Tok.Text_First := Natural'Last;
                  Item.Returned := Item.Returned + 1;
                  return Tok;
               end;
            elsif Name = "\message" or else
              Name = "\errmessage" or else Name = "\show"
            then
               declare
                  Arg : Token_Vectors.Vector;
                  T : Math_Tokens.Token := Read_Raw (Item);
                  Level : Natural := 0;
                  Started : Boolean := False;
               begin
                  if Name /= "\show" then
                     while T.Kind = Math_Tokens.Space_Token loop
                        T := Read_Raw (Item);
                     end loop;
                     if T.Kind = Math_Tokens.Left_Group then
                        Level := 1;
                        Started := True;
                     elsif T.Kind /= Math_Tokens.End_Of_Input and then
                       T.Kind /= Math_Tokens.Right_Group
                     then
                        Arg.Append (T);
                        Started := True;
                     end if;
                     while Started and then Level > 0 loop
                        T := Read_Raw (Item);
                        if T.Kind = Math_Tokens.End_Of_Input then
                           Item.Status := Argument_Error;
                           return Tok;
                        elsif T.Kind = Math_Tokens.Left_Group then
                           Level := Level + 1;
                           Arg.Append (T);
                        elsif T.Kind = Math_Tokens.Right_Group then
                           Level := Level - 1;
                           if Level > 0 then Arg.Append (T); end if;
                        else
                           Arg.Append (T);
                        end if;
                     end loop;
                     if not Started then
                        Item.Status := Argument_Error;
                        return Tok;
                     end if;
                  end if;
                  declare
                     Message : Ada.Strings.Unbounded.Unbounded_String;
                     Text : String (1 .. Maximum_Diagnostic_Length) :=
                       (others => ' ');
                     Value : Ada.Strings.Unbounded.Unbounded_String;
                     Length : Natural;
                     Severity : constant Diagnostic_Severity :=
                       (if Name = "\errmessage" then Error
                        else Information);
                  begin
                     if Name = "\show" then
                        Value := Ada.Strings.Unbounded.To_Unbounded_String
                          ("\show " &
                           Ada.Strings.Unbounded.To_String (T.Lexeme));
                     else
                        for Part of Arg loop
                           Ada.Strings.Unbounded.Append
                             (Message,
                              Ada.Strings.Unbounded.To_String (Part.Lexeme));
                        end loop;
                        Value := Message;
                     end if;
                     declare
                        Content : constant String :=
                          Ada.Strings.Unbounded.To_String (Value);
                     begin
                        Length := Natural'Min
                          (Content'Length, Maximum_Diagnostic_Length);
                        if Length > 0 then
                           Text (1 .. Length) :=
                             Content (Content'First ..
                               Content'First + Length - 1);
                        end if;
                     end;
                     Item.Last_Message :=
                       (Severity => Severity, Message => Text,
                        Length => Length);
                     Item.Message_Serial := Item.Message_Serial + 1;
                     if Item.Messages.Length < Maximum_Tokens then
                        Item.Messages.Append (Item.Last_Message);
                     end if;
                  end;
                  goto Iterate;
               end;
            elsif Name = "\dots" or else Name = "\cdots" or else
              Name = "\dotso" or else Name = "\dotsb" or else
              Name = "\dotsc" or else Name = "\dotsi" or else
              Name = "\dotsm" or else Name = "\dotsx"
            then
               declare
                  Look : Math_Tokens.Token := Read_Raw (Item);
                  Spaces : Token_Vectors.Vector;
                  Glyph : Natural := 16#2026#;
                  Symbol : Math_Symbols.Symbol_Record;
                  Next_Name : Ada.Strings.Unbounded.Unbounded_String :=
                    Ada.Strings.Unbounded.Null_Unbounded_String;
               begin
                  while Look.Kind = Math_Tokens.Space_Token loop
                     Spaces.Append (Look);
                     Look := Read_Raw (Item);
                  end loop;
                  Next_Name := Ada.Strings.Unbounded.To_Unbounded_String
                    (Name_Of (Item, Look));
                  declare
                     Replay : Math_Macros.Token_Sequence
                       (1 .. Natural (Spaces.Length) +
                        (if Look.Kind = Math_Tokens.End_Of_Input then 0 else 1));
                  begin
                     for I in 1 .. Natural (Spaces.Length) loop
                        Replay (I) := Spaces (Positive (I));
                     end loop;
                     if Look.Kind /= Math_Tokens.End_Of_Input then
                        Replay (Replay'Last) := Look;
                     end if;
                     if Replay'Length > 0 then
                        Queue_At_Cursor (Item, Replay);
                     end if;
                  end;
                  if Name = "\cdots" or else Name = "\dotsb" or else
                    Name = "\dotsi" or else Name = "\dotsm"
                  then
                     Glyph := 16#22EF#;
                  elsif Name = "\dots" and then not Item.Regular_Mode and then
                    Look.Code_Point in 43 | 45 | 42 | 58 | 61 | 60 | 62
                  then
                     Glyph := 16#22EF#;
                  elsif Name = "\dots" and then
                    Ada.Strings.Unbounded.To_String (Next_Name) in
                    "\not" | "\DOTSB" | "\coprod" | "\bigvee" |
                    "\bigwedge" | "\biguplus" | "\bigcap" |
                    "\bigcup" | "\prod" | "\sum" | "\bigotimes" |
                    "\bigoplus" | "\bigodot" | "\bigsqcup" | "\And" |
                    "\longrightarrow" | "\Longrightarrow" |
                    "\longleftarrow" | "\Longleftarrow" |
                    "\longleftrightarrow" | "\Longleftrightarrow" |
                    "\mapsto" | "\longmapsto" | "\hookrightarrow" |
                    "\doteq" | "\mathbin" | "\mathrel" |
                    "\relbar" | "\Relbar" | "\xrightarrow" |
                    "\xleftarrow" | "\int" | "\oint" | "\iint" |
                    "\iiint" | "\iiiint" | "\idotsint" |
                    "\DOTSI" | "\DOTSX"
                  then
                     Glyph := 16#22EF#;
                  elsif Look.Kind = Math_Tokens.Control_Word then
                     Symbol := Math_Symbols.Lookup_Math
                       (Ada.Strings.Unbounded.To_String (Next_Name));
                     if Symbol.Found and then Symbol.Class in
                       Math_Model.Binary_Atom | Math_Model.Relation_Atom
                     then
                        Glyph := 16#22EF#;
                     end if;
                  end if;
                  Tok.Kind := Math_Tokens.Character_Token;
                  Tok.Code_Point := Glyph;
                  Tok.Lexeme := Ada.Strings.Unbounded.To_Unbounded_String
                    (UTF8 (Glyph));
                  Item.Returned := Item.Returned + 1;
                  return Tok;
               end;
            elsif Name = "\futurelet" then
               if Item.Expansion_Only then
                  Item.Returned := Item.Returned + 1;
                  return Tok;
               end if;
               declare
                  Target : constant Math_Tokens.Token := Read_Raw (Item);
                  First : constant Math_Tokens.Token := Read_Raw (Item);
                  Second : constant Math_Tokens.Token := Read_Raw (Item);
                  D : Math_Macros.Diagnostic_Kind;
               begin
                  if Target.Kind not in Math_Tokens.Control_Word |
                    Math_Tokens.Control_Symbol or else
                    First.Kind = Math_Tokens.End_Of_Input or else
                    Second.Kind = Math_Tokens.End_Of_Input
                  then
                     Item.Status := Malformed_Definition;
                  else
                     Math_Macros.Define_Tokens
                       (Shared, Name_Of (Item, Target), 0,
                        (1 => Second), False, D);
                     if D /= Math_Macros.No_Error then
                        Item.Status := Malformed_Definition;
                     else
                        Queue_At_Cursor (Item, (1 => First, 2 => Second));
                     end if;
                  end if;
               end;
               goto Iterate;
            elsif Name = "\long" and then
              not Math_Macros.Is_Defined (Shared, Name) and then
              not Math_Builtin_Macros.Lookup (Name).Found
            then
               if Item.Expansion_Only then
                  Item.Returned := Item.Returned + 1;
                  return Tok;
               end if;
               Tok := Read_Raw (Item);
               if Tok.Kind = Math_Tokens.Control_Word and then
                 Name_Of (Item, Tok) in "\def" | "\gdef" |
                   "\edef" | "\xdef"
               then
                  Pushback (Item, Tok);
                  goto Iterate;
               elsif Math_Macros.Is_Defined (Shared, Name) or else
                 Math_Builtin_Macros.Lookup (Name).Found
               then
                  Pushback (Item, Tok);
                  Tok := (Kind => Math_Tokens.Control_Word,
                    Lexeme => Ada.Strings.Unbounded.To_Unbounded_String
                      (Name), others => <>);
                  Pushback (Item, Tok);
                  goto Iterate;
               else
                  Item.Status := Malformed_Definition;
               end if;
               goto Iterate;
            elsif Name = "\def" or else Name = "\gdef" or else
              Name = "\edef" or else Name = "\xdef" or else
              Name = "\global"
            then
               if Item.Expansion_Only then
                  Item.Returned := Item.Returned + 1;
                  return Tok;
               end if;
               declare
                  Is_Global : Boolean := Name = "\gdef" or else
                    Name = "\xdef";
                  Directive : Math_Tokens.Token := Tok;
               begin
                  if Name = "\global" then
                     Is_Global := True;
                     Directive := Read_Raw (Item);
                     if Directive.Kind /= Math_Tokens.Control_Word or else
                       Name_Of (Item, Directive) not in
                         "\def" | "\edef" | "\xdef" | "\let"
                     then
                        Item.Status := Malformed_Definition;
                        return Tok;
                     end if;
                     if Name_Of (Item, Directive) = "\let" then
                        declare
                           Target : constant Math_Tokens.Token :=
                             Read_Raw (Item);
                           Equal : Math_Tokens.Token := Read_Raw (Item);
                           Source : Math_Tokens.Token;
                           D : Math_Macros.Diagnostic_Kind;
                        begin
                           while Equal.Kind = Math_Tokens.Space_Token loop
                              Equal := Read_Raw (Item);
                           end loop;
                           if Target.Kind not in Math_Tokens.Control_Word |
                             Math_Tokens.Control_Symbol or else
                             (Equal.Kind = Math_Tokens.Character_Token and then
                              Equal.Code_Point = 61)
                           then
                              Source := Read_Raw (Item);
                           else
                              Source := Equal;
                           end if;
                           if Target.Kind not in Math_Tokens.Control_Word |
                             Math_Tokens.Control_Symbol or else
                             Source.Kind not in Math_Tokens.Control_Word |
                             Math_Tokens.Control_Symbol
                           then
                              Item.Status := Malformed_Definition;
                           elsif Math_Macros.Is_Defined
                             (Shared, Name_Of (Item, Source))
                           then
                              Math_Macros.Copy_Definition
                                (Shared, Name_Of (Item, Target),
                                 Name_Of (Item, Source), True, D);
                              if D /= Math_Macros.No_Error then
                                 Item.Status := Malformed_Definition;
                              end if;
                           else
                              Math_Macros.Define_Tokens
                                (Shared, Name_Of (Item, Target), 0,
                                 (1 => Source), True, D);
                              if D /= Math_Macros.No_Error then
                                 Item.Status := Malformed_Definition;
                              end if;
                           end if;
                        end;
                        goto Iterate;
                     end if;
                  end if;
                  declare
                     Name_Tok : constant Math_Tokens.Token := Read_Raw (Item);
                     Macro_Name : constant String := Name_Of (Item, Name_Tok);
                     Params : Natural := 0;
                     Rep : Token_Vectors.Vector;
                     D : Math_Macros.Diagnostic_Kind;
                     Failed : Boolean := False;
                     Depth : Natural := 0;
                  begin
                     if Name_Tok.Kind not in Math_Tokens.Control_Word |
                       Math_Tokens.Control_Symbol
                     then
                        Item.Status := Malformed_Definition;
                        return Tok;
                     end if;
                     loop
                        Tok := Read_Raw (Item);
                        exit when Tok.Kind = Math_Tokens.Left_Group;
                        if Tok.Kind = Math_Tokens.Parameter then
                           Tok := Read_Raw (Item);
                           if Tok.Kind /= Math_Tokens.Character_Token or else
                             Tok.Code_Point not in 49 .. 57 or else
                             Tok.Code_Point /= 49 + Params
                           then
                              Failed := True;
                              exit;
                           end if;
                           Params := Params + 1;
                        elsif Tok.Kind = Math_Tokens.End_Of_Input then
                           Failed := True;
                           exit;
                        end if;
                     end loop;
                     if not Failed then
                        loop
                           Tok := Read_Raw (Item);
                           if Tok.Kind = Math_Tokens.End_Of_Input then
                              Failed := True;
                              exit;
                           elsif Tok.Kind = Math_Tokens.Left_Group then
                              Depth := Depth + 1;
                           elsif Tok.Kind = Math_Tokens.Right_Group then
                              if Depth = 0 then exit; end if;
                              Depth := Depth - 1;
                           end if;
                           Rep.Append (Tok);
                        end loop;
                     end if;
                     if Failed then
                        Item.Status := Malformed_Definition;
                     else
                        if Name = "\edef" or else Name = "\xdef" or else
                          (Name = "\global" and then
                           Name_Of (Item, Directive) in "\edef" | "\xdef")
                        then
                           declare
                              Seq : Math_Macros.Token_Sequence
                                (1 .. Natural (Rep.Length));
                              Expanded_Source : Math_Source.Source;
                              Expanded_Stream : Math_Tokens.Stream;
                              Expanded_Cursor : Cursor;
                              Expanded_Token : Math_Tokens.Token;
                              Expanded_Tokens : Token_Vectors.Vector;
                              SD : Math_Source.Diagnostic_Kind;
                              TD : Math_Tokens.Diagnostic_Kind;
                              Byte : Natural;
                              Available : Natural := Item.Max_Expand -
                                Item.Expanded;
                              Remaining : Positive := Positive'Max
                                (1, Available);
                           begin
                              for I in Seq'Range loop
                                 Seq (I) := Rep (Positive (I));
                              end loop;
                              Math_Tokens.From_Tokens
                                (Item.Input,
                                 Math_Tokens.Token_Sequence (Seq),
                                 Expanded_Stream);
                              Math_Expander.Open
                                (Expanded_Stream, Expanded_Cursor,
                                 Remaining, Item.Token_Ceiling,
                                 Expansion_Only => True);
                              loop
                                 Expanded_Token := Math_Expander.Next
                                   (Expanded_Cursor, Shared);
                                 exit when Expanded_Token.Kind =
                                   Math_Tokens.End_Of_Input;
                                 Expanded_Tokens.Append (Expanded_Token);
                              end loop;
                              Item.Expanded := Item.Expanded +
                                Expanded_Cursor.Expanded;
                              if Expanded_Cursor.Expanded > Available then
                                 Item.Status := Expansion_Limit;
                              end if;
                              if Math_Expander.Diagnostic
                                (Expanded_Cursor) /= No_Error or else
                                Natural (Expanded_Tokens.Length) >=
                                  Item.Token_Ceiling
                              then
                                 if Item.Status /= Expansion_Limit then
                                    Item.Status := Math_Expander.Diagnostic
                                      (Expanded_Cursor);
                                 end if;
                                 if Item.Status = No_Error then
                                    Item.Status := Token_Limit;
                                 end if;
                              else
                                 Rep := Expanded_Tokens;
                              end if;
                              pragma Unreferenced (SD, TD, Byte);
                           end;
                        end if;
                        if Item.Status = No_Error then
                           declare
                              Seq : Math_Macros.Token_Sequence
                                (1 .. Natural (Rep.Length));
                           begin
                              for I in Seq'Range loop
                                 Seq (I) := Rep (Positive (I));
                              end loop;
                              Math_Macros.Define_Tokens
                                (Shared, Macro_Name, Params, Seq,
                                 Is_Global, D);
                           end;
                           if D /= Math_Macros.No_Error then
                              Item.Status := Malformed_Definition;
                           end if;
                        end if;
                     end if;
                  end;
               end;
               goto Iterate;
            elsif Name = "\newcommand" or else Name = "\renewcommand" or else
              Name = "\providecommand"
            then
               if Item.Expansion_Only then
                  Item.Returned := Item.Returned + 1;
                  return Tok;
               end if;
               declare
                  Name_Tok : Math_Tokens.Token := Read_Raw (Item);
                  Macro_Name : String (1 .. 256) := (others => ' ');
                  Name_Length : Natural := 0;
                  Params : Natural := 0;
                  Has_Default : Boolean := False;
                  Default : Token_Vectors.Vector;
                  Rep : Token_Vectors.Vector;
                  Depth : Natural := 0;
                  D : Math_Macros.Diagnostic_Kind;
                  Existing : Boolean;
                  Failed : Boolean := False;
               begin
                  while Name_Tok.Kind = Math_Tokens.Space_Token loop
                     Name_Tok := Read_Raw (Item);
                  end loop;
                  if Name_Tok.Kind = Math_Tokens.Left_Group then
                     Name_Tok := Read_Raw (Item);
                     if Name_Tok.Kind not in Math_Tokens.Control_Word |
                       Math_Tokens.Control_Symbol then Failed := True;
                     else
                        declare N : constant String := Name_Of (Item, Name_Tok); begin
                           if N'Length > Macro_Name'Length then
                              Failed := True;
                           else
                              Name_Length := N'Length; Macro_Name (1 .. N'Length) := N;
                           end if;
                        end;
                        if Read_Raw (Item).Kind /= Math_Tokens.Right_Group then Failed := True; end if;
                     end if;
                  elsif Name_Tok.Kind in Math_Tokens.Control_Word | Math_Tokens.Control_Symbol then
                     declare N : constant String := Name_Of (Item, Name_Tok); begin
                        if N'Length > Macro_Name'Length then
                           Failed := True;
                        else
                           Name_Length := N'Length; Macro_Name (1 .. N'Length) := N;
                        end if;
                     end;
                  else Failed := True;
                  end if;
                  if not Failed then
                     Tok := Read_Raw (Item);
                     while Tok.Kind = Math_Tokens.Space_Token loop
                        Tok := Read_Raw (Item);
                     end loop;
                  end if;
                  if not Failed and then Tok.Kind = Math_Tokens.Character_Token and then Tok.Code_Point = 91 then
                     Tok := Read_Raw (Item);
                     if Tok.Kind /= Math_Tokens.Character_Token or else Tok.Code_Point not in 48 .. 57 then Failed := True;
                     else
                        Params := Tok.Code_Point - 48;
                        Tok := Read_Raw (Item);
                        if Tok.Kind /= Math_Tokens.Character_Token or else Tok.Code_Point /= 93 then Failed := True; end if;
                     end if;
                     while not Failed loop Tok := Read_Raw (Item); exit when Tok.Kind /= Math_Tokens.Space_Token; end loop;
                  end if;
                  if not Failed and then Tok.Kind = Math_Tokens.Character_Token and then Tok.Code_Point = 91 then
                     Has_Default := True;
                     Depth := 0;
                     loop
                        Tok := Read_Raw (Item);
                        if Tok.Kind = Math_Tokens.End_Of_Input then
                           Failed := True;
                           exit;
                        elsif Tok.Kind = Math_Tokens.Character_Token and then
                          Tok.Code_Point = 93 and then Depth = 0
                        then
                           exit;
                        elsif Tok.Kind = Math_Tokens.Left_Group then
                           Depth := Depth + 1;
                        elsif Tok.Kind = Math_Tokens.Right_Group and then
                          Depth > 0
                        then
                           Depth := Depth - 1;
                        end if;
                        Default.Append (Tok);
                     end loop;
                     while not Failed loop
                        Tok := Read_Raw (Item);
                        exit when Tok.Kind /= Math_Tokens.Space_Token;
                     end loop;
                  end if;
                  if Has_Default and then Params = 0 then
                     Failed := True;
                  end if;
                  if not Failed and then Tok.Kind /= Math_Tokens.Left_Group then
                     Failed := True;
                  end if;
                  if not Failed then
                     loop
                        Tok := Read_Raw (Item);
                        if Tok.Kind = Math_Tokens.End_Of_Input then Failed := True; exit;
                        elsif Tok.Kind = Math_Tokens.Left_Group then Depth := Depth + 1;
                        elsif Tok.Kind = Math_Tokens.Right_Group then
                           if Depth = 0 then exit; end if; Depth := Depth - 1;
                        end if;
                        Rep.Append (Tok);
                     end loop;
                  end if;
                  if Failed or else Name_Length = 0 then
                     Item.Status := Malformed_Definition;
                  else
                     declare M : constant String := Macro_Name (1 .. Name_Length); begin
                        Existing := Math_Macros.Is_Defined (Shared, M) or else
                          Math_Builtin_Macros.Lookup (M).Found;
                        if (Name = "\newcommand" and Existing) or else
                          (Name = "\renewcommand" and not Existing)
                        then Item.Status := Malformed_Definition;
                        elsif Name = "\providecommand" and Existing then null;
                        else
                           declare Seq : Math_Macros.Token_Sequence (1 .. Natural (Rep.Length)); begin
                              for I in Seq'Range loop Seq (I) := Rep (Positive (I)); end loop;
                              Math_Macros.Define_Tokens (Shared, M, Params, Seq, False, D);
                              if D = Math_Macros.No_Error and then Has_Default then
                                 declare
                                    Default_Seq : Math_Macros.Token_Sequence
                                      (1 .. Natural (Default.Length));
                                 begin
                                    for I in Default_Seq'Range loop
                                       Default_Seq (I) := Default (I);
                                    end loop;
                                    Math_Macros.Set_Optional_Default
                                      (Shared, M, Default_Seq, D);
                                 end;
                              end if;
                              if D /= Math_Macros.No_Error then Item.Status := Malformed_Definition; end if;
                           end;
                        end if;
                     end;
                  end if;
               end;
               goto Iterate;
            elsif Name = "\let" then
               if Item.Expansion_Only then
                  Item.Returned := Item.Returned + 1;
                  return Tok;
               end if;
               declare
                  Target : constant Math_Tokens.Token := Read_Raw (Item);
                  Equal : Math_Tokens.Token := Read_Raw (Item);
                  Source : Math_Tokens.Token;
                  D : Math_Macros.Diagnostic_Kind;
               begin
                  while Equal.Kind = Math_Tokens.Space_Token loop Equal := Read_Raw (Item); end loop;
                  if Target.Kind not in Math_Tokens.Control_Word | Math_Tokens.Control_Symbol or else
                    (Equal.Kind = Math_Tokens.Character_Token and then Equal.Code_Point = 61)
                  then Source := Read_Raw (Item); else Source := Equal; end if;
                  if Target.Kind not in Math_Tokens.Control_Word | Math_Tokens.Control_Symbol or else
                    Source.Kind not in Math_Tokens.Control_Word | Math_Tokens.Control_Symbol
                  then Item.Status := Malformed_Definition;
                  else
                     if Math_Macros.Is_Defined (Shared, Name_Of (Item, Source)) then
                        Math_Macros.Copy_Definition
                          (Shared, Name_Of (Item, Target),
                           Name_Of (Item, Source), False, D);
                     else
                        declare
                           Builtin_Source : constant
                             Math_Builtin_Macros.Macro_Record :=
                               Math_Builtin_Macros.Lookup
                                 (Name_Of (Item, Source));
                           Template_Source : Math_Source.Source;
                           Template_Stream : Math_Tokens.Stream;
                           Source_Status : Math_Source.Diagnostic_Kind;
                           Lex_Status : Math_Tokens.Diagnostic_Kind;
                           Error_Byte : Natural;
                           Text : constant String :=
                             Ada.Strings.Unbounded.To_String
                               (Builtin_Source.Template);
                        begin
                           if not Builtin_Source.Found then
                              declare
                                 Seq : Math_Macros.Token_Sequence (1 .. 1) :=
                                   (1 => Source);
                              begin
                                 Math_Macros.Define_Tokens
                                   (Shared, Name_Of (Item, Target), 0,
                                    Seq, False, D);
                              end;
                              if D /= Math_Macros.No_Error then
                                 Item.Status := Malformed_Definition;
                              end if;
                           else
                              Math_Source.Create
                                (Text, Template_Source, Source_Status,
                                 Error_Byte);
                              Math_Tokens.Lex
                                (Template_Source, Template_Stream,
                                 Lex_Status, Error_Byte);
                              if Source_Status /= Math_Source.No_Error or else
                                Lex_Status /= Math_Tokens.No_Error
                              then
                                 Item.Status := Malformed_Definition;
                              else
                                 declare
                                    Seq : Math_Macros.Token_Sequence
                                      (1 .. Math_Tokens.Count
                                         (Template_Stream) - 1);
                                 begin
                                    for I in Seq'Range loop
                                       Seq (I) := Math_Tokens.Element
                                         (Template_Stream, I);
                                    end loop;
                                    Math_Macros.Define_Tokens
                                      (Shared, Name_Of (Item, Target),
                                       Builtin_Source.Num_Params, Seq,
                                       False, D);
                                 end;
                                 if D /= Math_Macros.No_Error then
                                    Item.Status := Malformed_Definition;
                                 end if;
                              end if;
                           end if;
                        end;
                     end if;
                  end if;
               end;
               goto Iterate;
            elsif Name = "\TextOrMath" or else
              Name = "\@ifnextchar" or else
              Name = "\@firstoftwo" or else
              Name = "\@secondoftwo" or else
              Name = "\@ifstar"
            then
               if Item.Expanded >= Item.Max_Expand then
                  Item.Status := Expansion_Limit;
                  return Tok;
               end if;
               Item.Expanded := Item.Expanded + 1;
               declare
                  Args : array (1 .. 3) of Token_Vectors.Vector;
                  Count : constant Positive :=
                    (if Name = "\@ifnextchar" then 3 else 2);
                  Failed : Boolean := False;
                  Temporary_Tokens : Natural := 0;
                  procedure Append_Temporary
                    (Target : in out Token_Vectors.Vector;
                     Value : Math_Tokens.Token) is
                  begin
                     if Temporary_Tokens >= Item.Token_Ceiling -
                       Natural'Min (Item.Live_Tokens, Item.Token_Ceiling)
                     then
                        Item.Status := Token_Limit;
                        Failed := True;
                     else
                        Target.Append (Value);
                        Temporary_Tokens := Temporary_Tokens + 1;
                     end if;
                  end Append_Temporary;
                  procedure Read_Raw_Argument
                    (Target : in out Token_Vectors.Vector) is
                     Part : Math_Tokens.Token := Read_Raw (Item);
                     Level : Natural := 0;
                  begin
                     while Part.Kind = Math_Tokens.Space_Token loop
                        Part := Read_Raw (Item);
                     end loop;
                     if Part.Kind = Math_Tokens.End_Of_Input or else
                       Part.Kind = Math_Tokens.Right_Group
                     then
                        Failed := True;
                     elsif Part.Kind = Math_Tokens.Left_Group then
                        Level := 1;
                        loop
                           Part := Read_Raw (Item);
                           if Part.Kind = Math_Tokens.End_Of_Input then
                              Failed := True;
                              exit;
                           elsif Part.Kind = Math_Tokens.Left_Group then
                              Level := Level + 1;
                           elsif Part.Kind = Math_Tokens.Right_Group then
                              Level := Level - 1;
                              exit when Level = 0;
                           end if;
                           if Level > 0 then
                              Append_Temporary (Target, Part);
                              exit when Failed;
                           end if;
                        end loop;
                     else
                        Append_Temporary (Target, Part);
                     end if;
                  end Read_Raw_Argument;
                  function Same_Token
                    (Left, Right : Math_Tokens.Token) return Boolean is
                  begin
                     return Left.Kind = Right.Kind and then
                       Left.Code_Point = Right.Code_Point and then
                       Ada.Strings.Unbounded.To_String (Left.Lexeme) =
                       Ada.Strings.Unbounded.To_String (Right.Lexeme);
                  end Same_Token;
                  Selected : Natural := 1;
                  Look : Math_Tokens.Token;
               begin
                  for A in 1 .. Count loop
                     Read_Raw_Argument (Args (A));
                     exit when Failed;
                  end loop;
                  if Failed then
                     if Item.Status = No_Error then
                        Item.Status := Argument_Error;
                     end if;
                     return Tok;
                  end if;
                  if Name = "\TextOrMath" then
                     Selected := (if Item.Regular_Mode then 1 else 2);
                  elsif Name = "\@firstoftwo" then
                     Selected := 1;
                  elsif Name = "\@secondoftwo" then
                     Selected := 2;
                  elsif Name = "\@ifstar" then
                     loop
                        Look := Read_Raw (Item);
                        exit when Look.Kind /= Math_Tokens.Space_Token;
                     end loop;
                     if Look.Kind = Math_Tokens.Character_Token and then
                       Look.Code_Point = Character'Pos ('*')
                     then
                        Selected := 1;
                     else
                        Selected := 2;
                        Args (2).Append (Look);
                     end if;
                  else
                     loop
                        Look := Read_Raw (Item);
                        exit when Look.Kind /= Math_Tokens.Space_Token;
                     end loop;
                     if Same_Token (Args (1).First_Element, Look) then
                        Selected := 2;
                     else
                        Selected := 3;
                        Args (3).Append (Look);
                     end if;
                  end if;
                  declare
                     Seq : Math_Macros.Token_Sequence
                       (1 .. Natural (Args (Selected).Length));
                  begin
                     for I in Seq'Range loop
                        Seq (I) := Args (Selected) (Positive (I));
                     end loop;
                     Queue_At_Cursor (Item, Seq);
                  end;
                  goto Iterate;
               end;
            elsif Name = "\noexpand" then
               Tok := Read_Raw (Item);
               if Tok.Kind = Math_Tokens.End_Of_Input then
                  Item.Status := Argument_Error;
                  return Tok;
               end if;
               Pushback (Item, Tok);
               No_Expand_Next (Item);
               goto Iterate;
            elsif Name = "\expandafter" then
               declare
                  First : constant Math_Tokens.Token := Read_Raw (Item);
                  Second : constant Math_Tokens.Token := Read_Raw (Item);
                  Expanded_Second : Math_Tokens.Token := Second;
                  Replacement : Token_Vectors.Vector;
                  Is_Macro : constant Boolean :=
                    Second.Kind = Math_Tokens.Control_Word and then
                    (Math_Macros.Is_Defined (Shared, Name_Of (Item, Second))
                     or else Math_Builtin_Macros.Lookup
                       (Name_Of (Item, Second)).Found);
               begin
                  if First.Kind = Math_Tokens.End_Of_Input or else
                    Second.Kind = Math_Tokens.End_Of_Input
                  then
                     Item.Status := Argument_Error;
                     return Tok;
                  end if;
                  if Is_Macro then
                     Pushback (Item, Second);
                     Expanded_Second := Next (Item, Shared);
                     if Item.Status /= No_Error then return Tok; end if;
                  end if;
                  Replacement.Append (Expanded_Second);
                  Replacement.Append (First);
                  declare
                     Seq : Math_Macros.Token_Sequence
                       (1 .. Natural (Replacement.Length));
                  begin
                     for I in Seq'Range loop
                        Seq (I) := Replacement (Positive (I));
                     end loop;
                     Queue_At_Cursor (Item, Seq);
                  end;
                  goto Iterate;
               end;
            elsif Name = "\textregistered" then
               Item.Returned := Item.Returned + 1;
               return Tok;
            elsif (Name = "\bra@ket" or else Name = "\bra@set") and then
              not Math_Macros.Is_Defined (Shared, Name)
            then
               if Item.Expanded >= Item.Max_Expand then
                  Item.Status := Expansion_Limit;
                  return Tok;
               end if;
               Item.Expanded := Item.Expanded + 1;
               declare
                  Args : array (1 .. 5) of Token_Vectors.Vector;
                  Temporary_Tokens : Natural := 0;
                  Failed : Boolean := False;
                  procedure Read_Raw_Argument
                    (Target : in out Token_Vectors.Vector) is
                     Part : Math_Tokens.Token := Read_Raw (Item);
                     Level : Natural := 0;
                  begin
                     while Part.Kind = Math_Tokens.Space_Token loop
                        Part := Read_Raw (Item);
                     end loop;
                     if Part.Kind = Math_Tokens.Left_Group then
                        Level := 1;
                        loop
                           Part := Read_Raw (Item);
                           if Part.Kind = Math_Tokens.End_Of_Input then
                              Failed := True;
                              exit;
                           elsif Part.Kind = Math_Tokens.Left_Group then
                              Level := Level + 1;
                           elsif Part.Kind = Math_Tokens.Right_Group then
                              Level := Level - 1;
                              exit when Level = 0;
                           end if;
                           if Level > 0 then
                              if Temporary_Tokens >= Item.Token_Ceiling -
                                Natural'Min
                                  (Item.Live_Tokens, Item.Token_Ceiling)
                              then
                                 Item.Status := Token_Limit;
                                 Failed := True;
                                 exit;
                              end if;
                              Target.Append (Part);
                              Temporary_Tokens := Temporary_Tokens + 1;
                           end if;
                        end loop;
                     elsif Part.Kind = Math_Tokens.End_Of_Input or else
                       Part.Kind = Math_Tokens.Right_Group
                     then
                        Failed := True;
                     else
                        if Temporary_Tokens >= Item.Token_Ceiling -
                          Natural'Min
                            (Item.Live_Tokens, Item.Token_Ceiling)
                        then
                           Item.Status := Token_Limit;
                           Failed := True;
                        else
                           Target.Append (Part);
                           Temporary_Tokens := Temporary_Tokens + 1;
                        end if;
                     end if;
                  end Read_Raw_Argument;
                  Combined : Token_Vectors.Vector;
                  Child_Stream : Math_Tokens.Stream;
                  Child : Cursor;
                  Expanded_Tokens : Token_Vectors.Vector;
                  Child_Token : Math_Tokens.Token;
                  Remaining : Positive := Positive'Max
                    (1, Item.Max_Expand - Item.Expanded);
                  Child_Ceiling : Positive := Positive'Max
                    (1, Item.Token_Ceiling -
                       Natural'Min (Item.Live_Tokens, Item.Token_Ceiling));
               begin
                  for A in Args'Range loop
                     Read_Raw_Argument (Args (A));
                     exit when Failed;
                  end loop;
                  if Failed then
                     if Item.Status = No_Error then
                        Item.Status := Argument_Error;
                     end if;
                     return Tok;
                  end if;
                  for V of Args (1) loop Combined.Append (V); end loop;
                  for V of Args (5) loop Combined.Append (V); end loop;
                  for V of Args (4) loop Combined.Append (V); end loop;
                  declare
                     Seq : Math_Tokens.Token_Sequence
                       (1 .. Natural (Combined.Length));
                  begin
                     for I in Seq'Range loop
                        Seq (I) := Combined (Positive (I));
                     end loop;
                     Math_Tokens.From_Tokens
                       (Item.Input, Seq, Child_Stream);
                  end;
                  Math_Expander.Open
                    (Child_Stream, Child, Remaining, Child_Ceiling,
                     Expansion_Only => True);
                  Child.Middle_Binding := Item.Middle_Binding;
                  Child.Double_Binding := Item.Double_Binding;
                  Child.Has_Middle_Binding := Item.Has_Middle_Binding;
                  Child.Has_Double_Binding := Item.Has_Double_Binding;
                  Child.Middle_Once := Item.Middle_Once;
                  Child.Double_Once := Item.Double_Once;
                  Child.Previous_Middle_Binding := Item.Middle_Binding;
                  Child.Previous_Double_Binding := Item.Double_Binding;
                  Child.Had_Previous_Middle := Item.Has_Middle_Binding;
                  Child.Had_Previous_Double := Item.Has_Double_Binding;
                  Child.Middle_Binding.Clear;
                  Child.Double_Binding.Clear;
                  for V of Args (2) loop
                     Child.Middle_Binding.Append (V);
                  end loop;
                  if Args (3).Is_Empty then
                     Child.Double_Binding := Item.Double_Binding;
                  else
                     for V of Args (3) loop
                        Child.Double_Binding.Append (V);
                     end loop;
                  end if;
                  Child.Has_Middle_Binding := True;
                  Child.Has_Double_Binding :=
                    (not Args (3).Is_Empty) or else
                    Item.Has_Double_Binding;
                  Child.Middle_Once := Name = "\bra@set";
                  Child.Double_Once := Name = "\bra@set";
                  loop
                     Child_Token := Next (Child, Shared);
                     exit when Child_Token.Kind = Math_Tokens.End_Of_Input;
                     Expanded_Tokens.Append (Child_Token);
                     exit when Natural (Expanded_Tokens.Length) >= Child_Ceiling;
                  end loop;
                  Item.Expanded := Item.Expanded + Child.Expanded;
                  if Item.Expanded > Item.Max_Expand then
                     Item.Status := Expansion_Limit;
                  elsif Child.Status /= No_Error then
                     Item.Status := Child.Status;
                  elsif Natural (Expanded_Tokens.Length) >= Child_Ceiling then
                     Item.Status := Token_Limit;
                  else
                     declare
                        Seq : Math_Macros.Token_Sequence
                          (1 .. Natural (Expanded_Tokens.Length));
                     begin
                        for I in Seq'Range loop
                           Seq (I) := Expanded_Tokens (Positive (I));
                        end loop;
                        Queue_At_Cursor (Item, Seq);
                     end;
                  end if;
                  goto Iterate;
               end;
            elsif Math_Macros.Is_Defined (Shared, Name) or else
              Math_Builtin_Macros.Lookup (Name).Found
            then
               if Item.Expanded >= Item.Max_Expand then
                  Item.Status := Expansion_Limit;
                  return Tok;
               end if;
               Item.Expanded := Item.Expanded + 1;
               declare
                  User_Defined : constant Boolean :=
                    Math_Macros.Is_Defined (Shared, Name);
                  Builtin : constant Math_Builtin_Macros.Macro_Record :=
                    Math_Builtin_Macros.Lookup (Name);
                  Template_Source : Math_Source.Source;
                  Template_Stream : Math_Tokens.Stream;
                  Source_Status : Math_Source.Diagnostic_Kind;
                  Lex_Status : Math_Tokens.Diagnostic_Kind;
                  Error_Byte : Natural;
                  Params : Natural := 0;
                  Def_Count : Natural := 0;
                  Has_Default : Boolean := False;
                  Default_Count : Natural := 0;
                  Args : array (1 .. 9) of Token_Vectors.Vector;
                  Out_Tokens : Token_Vectors.Vector;
                  Bad : Boolean := False;
                  Temporary_Tokens : Natural := 0;
                  procedure Append_Temporary
                    (Target : in out Token_Vectors.Vector;
                     Value : Math_Tokens.Token) is
                  begin
                     if Temporary_Tokens >= Item.Token_Ceiling -
                       Natural'Min (Item.Live_Tokens, Item.Token_Ceiling)
                     then
                        Item.Status := Token_Limit;
                        Bad := True;
                     else
                        Target.Append (Value);
                        Temporary_Tokens := Temporary_Tokens + 1;
                     end if;
                  end Append_Temporary;
                  function Definition_Token
                    (Index : Positive) return Math_Tokens.Token is
                     Value : Math_Tokens.Token;
                  begin
                     if User_Defined then
                        Value := Math_Macros.Token_At
                          (Math_Macros.Lookup (Shared, Name), Index);
                     else
                        Value := Math_Tokens.Element (Template_Stream, Index);
                     end if;
                     if not Value.Has_Invocation then
                        Value.Has_Invocation := True;
                        Value.Invocation_First_Byte :=
                          (if Tok.Has_Invocation then
                             Tok.Invocation_First_Byte
                           else Tok.First_Byte);
                        Value.Invocation_After_Byte :=
                          (if Tok.Has_Invocation then
                             Tok.Invocation_After_Byte
                           else Tok.After_Byte);
                     end if;
                     return Value;
                  end Definition_Token;
               begin
                  if User_Defined then
                     declare
                        Def : constant Math_Macros.Definition :=
                          Math_Macros.Lookup (Shared, Name);
                     begin
                        Params := Math_Macros.Num_Params (Def);
                        Has_Default := Math_Macros.Has_Optional_Default (Def);
                        Default_Count := Math_Macros.Default_Token_Count (Def);
                        Def_Count := Math_Macros.Token_Count (Def);
                     end;
                  else
                     Params := Builtin.Num_Params;
                     declare
                        Text : constant String :=
                          Ada.Strings.Unbounded.To_String (Builtin.Template);
                     begin
                        Math_Source.Create
                          (Text, Template_Source, Source_Status, Error_Byte);
                        if Source_Status /= Math_Source.No_Error then
                           Item.Status := Malformed_Definition;
                           return Tok;
                        end if;
                     end;
                     Math_Tokens.Lex
                       (Template_Source, Template_Stream, Lex_Status,
                        Error_Byte);
                     if Lex_Status /= Math_Tokens.No_Error then
                        Item.Status := Malformed_Definition;
                        return Tok;
                     end if;
                     Def_Count := Math_Tokens.Count (Template_Stream) - 1;
                  end if;
                  for A in 1 .. Params loop
                     declare
                        T : Math_Tokens.Token := Read_Raw (Item);
                        Spaces : Token_Vectors.Vector;
                     begin
                        while T.Kind = Math_Tokens.Space_Token loop
                           Spaces.Append (T);
                           T := Read_Raw (Item);
                        end loop;
                        if A = 1 and then Has_Default and then
                          T.Kind = Math_Tokens.Character_Token and then
                          T.Code_Point = 91
                        then
                           declare
                              Level : Natural := 0;
                           begin
                              loop
                                 T := Read_Raw (Item);
                                 if T.Kind = Math_Tokens.End_Of_Input then
                                    Bad := True;
                                    exit;
                                 elsif T.Kind = Math_Tokens.Left_Group then
                                    Level := Level + 1;
                                 elsif T.Kind = Math_Tokens.Right_Group then
                                    if Level > 0 then
                                       Level := Level - 1;
                                    end if;
                                 elsif T.Kind = Math_Tokens.Character_Token and then
                                   T.Code_Point = 93 and then Level = 0
                                 then
                                    exit;
                                 end if;
                                 Append_Temporary (Args (A), T);
                              end loop;
                           end;
                        elsif A = 1 and then Has_Default then
                           for I in 1 .. Default_Count loop
                              Append_Temporary
                                (Args (A), Math_Macros.Default_Token_At
                                   (Math_Macros.Lookup (Shared, Name),
                                    Positive (I)));
                           end loop;
                           if T.Kind /= Math_Tokens.End_Of_Input then
                              Pushback (Item, T);
                           end if;
                           for I in reverse 1 .. Natural (Spaces.Length) loop
                              Pushback (Item, Spaces (Positive (I)));
                           end loop;
                        elsif T.Kind = Math_Tokens.Left_Group then
                           declare
                              Level : Natural := 1;
                           begin
                              while Level > 0 loop
                                 T := Read_Raw (Item);
                                 if T.Kind = Math_Tokens.End_Of_Input then
                                    Bad := True;
                                    exit;
                                 elsif T.Kind = Math_Tokens.Left_Group then
                                    Level := Level + 1;
                                 elsif T.Kind = Math_Tokens.Right_Group then
                                    Level := Level - 1;
                                 end if;
                                 if Level > 0 then
                                    Append_Temporary (Args (A), T);
                                 end if;
                              end loop;
                           end;
                        elsif T.Kind = Math_Tokens.End_Of_Input or else
                          T.Kind = Math_Tokens.Right_Group
                        then
                           Bad := True;
                        else
                           Append_Temporary (Args (A), T);
                        end if;
                     end;
                  end loop;
                  if Bad then
                     if Item.Status = No_Error then
                        Item.Status := Argument_Error;
                     end if;
                     return Tok;
                  end if;
                  declare
                     I : Positive := 1;
                  begin
                     while I <= Def_Count loop
                        declare
                           T : constant Math_Tokens.Token :=
                             Definition_Token (I);
                        begin
                           if T.Kind = Math_Tokens.Parameter and then
                             not User_Defined and then I < Def_Count and then
                             Definition_Token (I + 1).Kind =
                               Math_Tokens.Parameter and then
                             Ada.Strings.Unbounded.To_String
                               (Definition_Token (I + 1).Lexeme) = "#"
                           then
                              Append_Temporary
                                (Out_Tokens,
                                 (Kind => Math_Tokens.Character_Token,
                                  Code_Point => 35, Lexeme =>
                                    Ada.Strings.Unbounded.To_Unbounded_String
                                      ("#"), others => <>));
                              I := I + 1;
                           elsif T.Kind = Math_Tokens.Parameter and then
                             not User_Defined and then I > 1 and then
                             Definition_Token (I - 1).Kind =
                               Math_Tokens.Parameter and then
                             Ada.Strings.Unbounded.To_String (T.Lexeme) = "#"
                           then
                              null;
                           elsif T.Kind = Math_Tokens.Parameter and then
                             I < Def_Count and then
                             Definition_Token (I + 1).Kind =
                               Math_Tokens.Character_Token and then
                             Definition_Token (I + 1).Code_Point in 49 .. 57
                           then
                              I := I + 1;
                              declare
                                 Arg_No : constant Positive := Positive
                                   (Definition_Token (I).Code_Point - 48);
                              begin
                                 for V of Args (Arg_No) loop
                                    Append_Temporary (Out_Tokens, V);
                                 end loop;
                              end;
                           elsif T.Kind = Math_Tokens.Parameter then
                              Append_Temporary (Out_Tokens, T);
                           else
                              Append_Temporary (Out_Tokens, T);
                           end if;
                        end;
                        I := I + 1;
                     end loop;
                  end;
                  if Bad or else Item.Status /= No_Error then
                     if Item.Status = No_Error then
                        Item.Status := Token_Limit;
                     end if;
                     return Tok;
                  end if;
                  declare
                     Seq : Math_Macros.Token_Sequence
                       (1 .. Natural (Out_Tokens.Length));
                  begin
                     for I in Seq'Range loop
                        Seq (I) := Out_Tokens (Positive (I));
                     end loop;
                     Queue_At_Cursor (Item, Seq);
                  end;
                  if Item.Status /= No_Error then
                     return Tok;
                  end if;
                  goto Iterate;
               end;
            end if;
         end;
      end if;
      Item.Returned := Item.Returned + 1;
      if Item.Returned > Item.Token_Ceiling then
         Item.Status := Token_Limit;
      end if;
      return Tok;
      end loop;
   end Next;

   function Peek (Item : in out Cursor; Shared : in out Math_Macros.Context)
      return Math_Tokens.Token is
      Tok : constant Math_Tokens.Token := Next (Item, Shared);
   begin
      Pushback (Item, Tok);
      return Tok;
   end Peek;

   procedure Scan_Argument
     (Item : in out Cursor; Shared : in out Math_Macros.Context;
      Result : out Math_Tokens.Stream;
      Diagnostic : out Diagnostic_Kind) is
      Tokens : Token_Vectors.Vector;
      T : Math_Tokens.Token;
      Level : Natural := 0;
      Started : Boolean := False;
   begin
      loop
         T := Next (Item, Shared);
         if T.Kind = Math_Tokens.End_Of_Input then
            Item.Status := Argument_Error;
            Diagnostic := Argument_Error;
            return;
         elsif not Started and then T.Kind = Math_Tokens.Space_Token then
            null;
         elsif not Started and then T.Kind = Math_Tokens.Left_Group then
            Started := True;
            Level := 1;
         elsif not Started then
            Started := True;
            Tokens.Append (T);
            exit;
         elsif T.Kind = Math_Tokens.Left_Group then
            Level := Level + 1;
            Tokens.Append (T);
         elsif T.Kind = Math_Tokens.Right_Group then
            Level := Level - 1;
            exit when Level = 0;
            Tokens.Append (T);
         else
            Tokens.Append (T);
         end if;
      end loop;
      declare
         Seq : Math_Tokens.Token_Sequence (1 .. Natural (Tokens.Length));
      begin
         for I in Seq'Range loop
            Seq (I) := Tokens (Positive (I));
         end loop;
         Math_Tokens.From_Tokens (Item.Input, Seq, Result);
         Diagnostic := No_Error;
      end;
   end Scan_Argument;

   procedure Begin_Group (Shared : in out Math_Macros.Context) is
   begin
      Math_Macros.Begin_Group (Shared);
   end Begin_Group;

   procedure End_Group (Shared : in out Math_Macros.Context) is
   begin
      Math_Macros.End_Group (Shared);
   end End_Group;

   procedure End_All (Shared : in out Math_Macros.Context) is
   begin
      Math_Macros.End_All (Shared);
   end End_All;

   function Diagnostic (Item : Cursor) return Diagnostic_Kind is
     (Item.Status);

   function Message_Count (Item : Cursor) return Natural is
     (Natural (Item.Messages.Length));

   function Diagnostic_At
     (Item : Cursor; Index : Positive) return Diagnostic_Record is
     (Item.Messages (Index));

   function Last_Diagnostic (Item : Cursor) return Diagnostic_Record is
     (Item.Last_Message);

   function Diagnostic_Serial (Item : Cursor) return Natural is
     (Item.Message_Serial);
end Math_Expander;
