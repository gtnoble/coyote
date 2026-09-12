--  Coyote_Renderer.Incremental body.
--
--  This implementation is deliberately format-independent.  It tokenizes the
--  closed CSM-2 vocabulary itself and builds the renderer-neutral semantic
--  document while retaining the legacy synchronous event facade.
--
--  Project: coyote

with Ada.Characters.Latin_1;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Coyote_Renderer.Semantics;

package body Coyote_Renderer.Incremental is

   use type Coyote_Renderer.Semantics.Block_Id;
   use type Coyote_Renderer.Semantics.Inline_Id;
   use type Coyote_Renderer.Semantics.Table_Cell_Id;
   use type Coyote_Renderer.Semantics.Table_Row_Id;
   use type Coyote_Renderer.Semantics.List_Kind;
   use type Coyote_Renderer.Semantics.Table_Alignment;

   procedure Ignore (Value : Boolean) is
      pragma Unreferenced (Value);
   begin
      null;
   end Ignore;

   procedure Ignore_Event (Value : Event) is
      pragma Unreferenced (Value);
   begin
      null;
   end Ignore_Event;

   procedure Emit_Live
     (Parser : in out Instance; Kind : Live_Event_Kind;
      Text : String := ""; Detail : String := ""; Level : Natural := 0;
      Source_Start : Natural := 0; Source_End : Natural := 0;
      Context_Id : Natural := 0; Deferred : Boolean := False;
      Complete : Boolean := False) is
   begin
      if Parser.Live /= null then
         Parser.Next_Sequence := Parser.Next_Sequence + 1;
         Parser.Live.all
           ((Kind => Kind, Text => To_Unbounded_String (Text),
             Detail => To_Unbounded_String (Detail), Level => Level,
             Source_Start => Source_Start, Source_End => Source_End,
             Context_Id => Context_Id, Sequence => Parser.Next_Sequence,
             Deferred => Deferred, Complete => Complete));
      end if;
   end Emit_Live;

   function Current_Context (Parser : Instance) return Natural is
   begin
      if Parser.Open > 0 then
         return Parser.Stack (Parser.Open).Context_Id;
      end if;
      return 0;
   end Current_Context;

   function Live_Begin (Name : String) return Live_Event_Kind is
   begin
      if Name = "strong" then
         return Live_Strong_Begin_Event;
      elsif Name = "em" then
         return Live_Em_Begin_Event;
      elsif Name = "del" then
         return Live_Del_Begin_Event;
      elsif Name = "link" then
         return Live_Link_Begin_Event;
      elsif Name = "code-inline" then
         return Live_Code_Inline_Begin_Event;
      elsif Name = "p" then
         return Live_Paragraph_Begin_Event;
      elsif Name in "h1" | "h2" | "h3" | "h4" | "h5" | "h6" then
         return Live_Heading_Begin_Event;
      elsif Name = "blockquote" then
         return Live_Blockquote_Begin_Event;
      elsif Name = "list" then
         return Live_List_Begin_Event;
      elsif Name = "item" then
         return Live_Item_Begin_Event;
      elsif Name = "code" then
         return Live_Code_Begin_Event;
      elsif Name = "table" then
         return Live_Table_Begin_Event;
      elsif Name = "math" then
         return Live_Math_Begin_Event;
      end if;
      return Live_Invalid_Event;
   end Live_Begin;

   function Live_End (Name : String) return Live_Event_Kind is
   begin
      if Name = "strong" then
         return Live_Strong_End_Event;
      elsif Name = "em" then
         return Live_Em_End_Event;
      elsif Name = "del" then
         return Live_Del_End_Event;
      elsif Name = "link" then
         return Live_Link_End_Event;
      elsif Name = "code-inline" then
         return Live_Code_Inline_End_Event;
      elsif Name = "p" then
         return Live_Paragraph_End_Event;
      elsif Name in "h1" | "h2" | "h3" | "h4" | "h5" | "h6" then
         return Live_Heading_End_Event;
      elsif Name = "blockquote" then
         return Live_Blockquote_End_Event;
      elsif Name = "list" then
         return Live_List_End_Event;
      elsif Name = "item" then
         return Live_Item_End_Event;
      elsif Name = "code" then
         return Live_Code_End_Event;
      elsif Name = "table" then
         return Live_Table_End_Event;
      elsif Name = "math" then
         return Live_Math_End_Event;
      end if;
      return Live_Invalid_Event;
   end Live_End;

   type Attribute is record
      Name  : Unbounded_String;
      Value : Unbounded_String;
   end record;

   type Attribute_Array is array (Positive range 1 .. Max_Attributes)
     of Attribute;

   type Tag_Info is record
      Valid       : Boolean := False;
      Closing     : Boolean := False;
      Self_Closing : Boolean := False;
      Name        : Unbounded_String;
      Attributes  : Attribute_Array;
      Count       : Natural := 0;
   end record;

   function Is_Space (Value : Character) return Boolean is
   begin
      return Value = ' ' or else Value = Ada.Characters.Latin_1.HT
        or else Value = Ada.Characters.Latin_1.LF
        or else Value = Ada.Characters.Latin_1.CR;
   end Is_Space;

   function Is_Name_Character (Value : Character) return Boolean is
   begin
      return Value in 'a' .. 'z' or else Value in '0' .. '9'
        or else Value = '-';
   end Is_Name_Character;

   function Is_Digit (Value : Character) return Boolean is
   begin
      return Value in '0' .. '9';
   end Is_Digit;

   function Attribute_At
     (Info : Tag_Info; Name : String; Value : out Unbounded_String)
      return Boolean
   is
   begin
      for I in 1 .. Info.Count loop
         if To_String (Info.Attributes (I).Name) = Name then
            Value := Info.Attributes (I).Value;
            return True;
         end if;
      end loop;
      return False;
   end Attribute_At;

   function Has_Attribute (Info : Tag_Info; Name : String) return Boolean is
      Value : Unbounded_String;
   begin
      return Attribute_At (Info, Name, Value);
   end Has_Attribute;

   function Parse_Tag (Source : String; Info : out Tag_Info) return Boolean is
      I       : Natural;
      Last    : constant Natural := Source'Last;
      Name_Start : Natural;
   begin
      Info := (others => <>);
      if Source'Length < 3 or else Source (Source'First) /= '<'
        or else Source (Last) /= '>'
      then
         return False;
      end if;

      I := Source'First + 1;
      if Source (I) = '/' then
         Info.Closing := True;
         I := I + 1;
      end if;
      if I >= Last or else not Is_Name_Character (Source (I)) then
         return False;
      end if;
      Name_Start := I;
      while I < Last and then Is_Name_Character (Source (I)) loop
         I := I + 1;
      end loop;
      Info.Name := To_Unbounded_String
        (Source (Name_Start .. I - 1));

      if Info.Closing then
         while I < Last and then Is_Space (Source (I)) loop
            I := I + 1;
         end loop;
         if I /= Last then
            return False;
         end if;
         Info.Valid := True;
         return True;
      end if;

      while I < Last loop
         while I < Last and then Is_Space (Source (I)) loop
            I := I + 1;
         end loop;
         exit when I = Last;
         if Source (I) = '/' then
            Info.Self_Closing := True;
            I := I + 1;
            while I < Last and then Is_Space (Source (I)) loop
               I := I + 1;
            end loop;
            if I /= Last then
               return False;
            end if;
            exit;
         end if;
         if Info.Count = Max_Attributes
           or else not Is_Name_Character (Source (I))
         then
            return False;
         end if;
         Info.Count := Info.Count + 1;
         declare
            A_Start : constant Natural := I;
         begin
            while I < Last and then Is_Name_Character (Source (I)) loop
               I := I + 1;
            end loop;
            Info.Attributes (Info.Count).Name :=
              To_Unbounded_String (Source (A_Start .. I - 1));
         end;
         while I < Last and then Is_Space (Source (I)) loop
            I := I + 1;
         end loop;
         if I >= Last or else Source (I) /= '=' then
            return False;
         end if;
         I := I + 1;
         while I < Last and then Is_Space (Source (I)) loop
            I := I + 1;
         end loop;
         if I >= Last or else Source (I) /= '"' then
            return False;
         end if;
         I := I + 1;
         declare
            V_Start : constant Natural := I;
         begin
            while I < Last and then Source (I) /= '"' loop
               if Source (I) = '<' then
                  return False;
               end if;
               I := I + 1;
            end loop;
            if I >= Last then
               return False;
            end if;
            Info.Attributes (Info.Count).Value :=
              To_Unbounded_String (Source (V_Start .. I - 1));
         end;
         I := I + 1;
      end loop;
      Info.Valid := I = Last;
      return Info.Valid;
   end Parse_Tag;

   function Decode_Entities
     (Source : String; Result : out Unbounded_String) return Boolean
   is
      I : Natural := Source'First;
   begin
      Result := Null_Unbounded_String;
      while I <= Source'Last loop
         if Source (I) /= '&' then
            Append (Result, Source (I));
            I := I + 1;
         else
            declare
               Semi : Natural := I + 1;
            begin
               while Semi <= Source'Last and then Source (Semi) /= ';' loop
                  Semi := Semi + 1;
               end loop;
               if Semi > Source'Last then
                  return False;
               end if;
               declare
                  Entity : constant String := Source (I + 1 .. Semi - 1);
                  Value   : Natural := 0;
                  Base    : Natural := 10;
                  Entity_Digits : Unbounded_String :=
                    To_Unbounded_String (Entity);
                  Valid   : Boolean := True;
               begin
                  if Entity = "amp" then
                     Append (Result, '&');
                  elsif Entity = "lt" then
                     Append (Result, '<');
                  elsif Entity = "gt" then
                     Append (Result, '>');
                  elsif Entity = "quot" then
                     Append (Result, '"');
                  elsif Entity = "apos" then
                     Append (Result, ''');
                  else
                     if Entity'Length >= 2 and then Entity (Entity'First) = '#'
                     then
                        if Entity (Entity'First + 1) = 'x'
                          or else Entity (Entity'First + 1) = 'X'
                        then
                           Base := 16;
                           if Entity'Length = 2 then
                              Valid := False;
                           else
                              Entity_Digits :=
                                To_Unbounded_String
                                  (Entity (Entity'First + 2 .. Entity'Last));
                           end if;
                        else
                           if Entity'Length = 1 then
                              Valid := False;
                           else
                              Entity_Digits :=
                                To_Unbounded_String
                                  (Entity (Entity'First + 1 .. Entity'Last));
                           end if;
                        end if;
                        if Valid then
                           for C of To_String (Entity_Digits) loop
                              declare
                                 N : Natural := 0;
                              begin
                                 if C in '0' .. '9' then
                                    N := Character'Pos (C) - Character'Pos ('0');
                                 elsif Base = 16 and then C in 'a' .. 'f' then
                                    N := Character'Pos (C) - Character'Pos ('a') + 10;
                                 elsif Base = 16 and then C in 'A' .. 'F' then
                                    N := Character'Pos (C) - Character'Pos ('A') + 10;
                                 else
                                    Valid := False;
                                 end if;
                                 if Valid then
                                    if Value > (Natural'Last - N) / Base then
                                       Valid := False;
                                    else
                                       Value := Value * Base + N;
                                    end if;
                                 end if;
                              end;
                           end loop;
                        end if;
                        if Valid and then Value <= 16#10FFFF#
                          and then not (Value in 16#D800# .. 16#DFFF#)
                        then
                           if Value <= 16#7F# then
                              Append (Result, Character'Val (Value));
                           elsif Value <= 16#7FF# then
                              Append (Result, Character'Val
                                (16#C0# + Value / 64));
                              Append (Result, Character'Val
                                (16#80# + Value mod 64));
                           elsif Value <= 16#FFFF# then
                              Append (Result, Character'Val
                                (16#E0# + Value / 4096));
                              Append (Result, Character'Val
                                (16#80# + (Value / 64) mod 64));
                              Append (Result, Character'Val
                                (16#80# + Value mod 64));
                           else
                              Append (Result, Character'Val
                                (16#F0# + Value / 262144));
                              Append (Result, Character'Val
                                (16#80# + (Value / 4096) mod 64));
                              Append (Result, Character'Val
                                (16#80# + (Value / 64) mod 64));
                              Append (Result, Character'Val
                                (16#80# + Value mod 64));
                           end if;
                        else
                           Valid := False;
                        end if;
                     else
                        Valid := False;
                     end if;
                     if not Valid then
                        return False;
                     end if;
                  end if;
               end;
               I := Semi + 1;
            end;
         end if;
      end loop;
      return True;
   end Decode_Entities;

   function Safe_UTF8_End
     (Source : String; First : Natural; Last : Natural) return Natural is
      I       : Natural := Last;
      Lead    : Natural;
      Needed  : Natural;
      Byte    : Natural;
   begin
      if First > Last then
         return Last;
      end if;
      while I >= First and then Character'Pos (Source (I)) in 16#80# .. 16#BF# loop
         exit when I = First;
         I := I - 1;
      end loop;
      if I < First then
         return Last;
      end if;
      Lead := Character'Pos (Source (I));
      if Lead <= 16#7F# then
         return Last;
      elsif Lead in 16#C2# .. 16#DF# then
         Needed := 2;
      elsif Lead in 16#E0# .. 16#EF# then
         Needed := 3;
      elsif Lead in 16#F0# .. 16#F4# then
         Needed := 4;
      else
         return Last;
      end if;
      if Last - I + 1 < Needed then
         return I - 1;
      end if;
      for J in I + 1 .. I + Needed - 1 loop
         Byte := Character'Pos (Source (J));
         if Byte not in 16#80# .. 16#BF# then
            return Last;
         end if;
      end loop;
      return Last;
   end Safe_UTF8_End;

   procedure Emit
     (Handler : Event_Handler;
      Kind    : Event_Kind;
      Text    : String := "";
      Level   : Natural := 0;
      Ready   : Boolean := False;
      Source_End : Natural := 0) is
   begin
      Handler.all
        ((Kind           => Kind,
          Text           => To_Unbounded_String (Text),
          Level          => Level,
          Semantic_Ready => Ready,
          Source_End     => Source_End));
   end Emit;

   procedure Set_Invalid_Document (Parser : in out Instance) is
      Block : Coyote_Renderer.Semantics.Block_Id;
   begin
      Coyote_Renderer.Semantics.Clear (Parser.Document);
      Block := Coyote_Renderer.Semantics.New_Block
        (Parser.Document, Coyote_Renderer.Semantics.Invalid_Source,
         To_String (Parser.Source));
      Ignore (Coyote_Renderer.Semantics.Append_Block (Parser.Document, Block));
   end Set_Invalid_Document;

   procedure Emit_Invalid
     (Parser : in out Instance; Handler : Event_Handler; Text : String) is
      Source : constant String := To_String (Parser.Source);
   begin
      Set_Invalid_Document (Parser);
      Emit (Handler, Invalid_Event, Text, 0, True,
            Natural (Length (Parser.Source)));
      Emit_Live (Parser, Live_Invalid_Event, Source, "", 0, 1,
         Natural'Max (1, Source'Length), Current_Context (Parser),
         Complete => True);
      Parser.Invalid := True;
   end Emit_Invalid;

   function Current_Block
     (Parser : Instance) return Coyote_Renderer.Semantics.Block_Id is
   begin
      if Parser.Open > 0 then
         for I in reverse 1 .. Parser.Open loop
            if Parser.Stack (I).Block /=
              Coyote_Renderer.Semantics.No_Block
            then
               return Parser.Stack (I).Block;
            end if;
         end loop;
      end if;
      return Coyote_Renderer.Semantics.No_Block;
   end Current_Block;

   function Current_Cell
     (Parser : Instance) return Coyote_Renderer.Semantics.Table_Cell_Id;

   function Attach_Inline
     (Parser : in out Instance;
      Child  : Coyote_Renderer.Semantics.Inline_Id) return Boolean is
   begin
      if Parser.Open = 0 then
         return False;
      elsif Parser.Stack (Parser.Open).Inline /=
        Coyote_Renderer.Semantics.No_Inline
      then
         return Coyote_Renderer.Semantics.Append_Inline
           (Parser.Document, Parser.Stack (Parser.Open).Inline, Child);
      elsif Parser.Stack (Parser.Open).Cell /=
        Coyote_Renderer.Semantics.No_Table_Cell
      then
         return Coyote_Renderer.Semantics.Append_Inline
           (Parser.Document, Parser.Stack (Parser.Open).Cell, Child);
      elsif Current_Block (Parser) /= Coyote_Renderer.Semantics.No_Block then
         return Coyote_Renderer.Semantics.Append_Inline
           (Parser.Document, Current_Block (Parser), Child);
      end if;
      return False;
   end Attach_Inline;

   procedure Add_Text
     (Parser : in out Instance;
      Handler : Event_Handler;
      Raw : String) is
      Decoded : Unbounded_String;
      Inline  : Coyote_Renderer.Semantics.Inline_Id;
   begin
      if Raw'Length = 0 then
         return;
      end if;
      for C of Raw loop
         if C = '>' then
            Emit_Invalid (Parser, Handler, Raw);
            return;
         end if;
      end loop;
      if not Decode_Entities (Raw, Decoded) then
         Emit_Invalid (Parser, Handler, Raw);
         return;
      end if;
      if Parser.Open > 0 then
         declare
            Parent_Name : constant String :=
              To_String (Parser.Stack (Parser.Open).Name);
         begin
            if Parent_Name = "table" or else Parent_Name = "row" then
               for Character_Value of To_String (Decoded) loop
                  if not Is_Space (Character_Value) then
                     Emit_Invalid (Parser, Handler, Raw);
                     return;
                  end if;
               end loop;
               return;
            end if;
         end;
      end if;
      Emit (Handler, Text_Event, Raw);
      Emit_Live (Parser, Live_Text_Event, To_String (Decoded), "", 0,
         Parser.Cursor + 1, Parser.Cursor + Raw'Length,
         Current_Context (Parser));
      if Parser.Open > 0 then
         declare
            Cell : constant Coyote_Renderer.Semantics.Table_Cell_Id :=
              Current_Cell (Parser);
         begin
            if Cell /= Coyote_Renderer.Semantics.No_Table_Cell then
               Ignore
                 (Coyote_Renderer.Semantics.Set_Table_Cell_Value
                    (Parser.Document, Cell,
                     Coyote_Renderer.Semantics.Table_Cell_Value
                       (Parser.Document, Cell)
                     & To_String (Decoded)));
            end if;
         end;
         Inline := Coyote_Renderer.Semantics.New_Inline
           (Parser.Document, Coyote_Renderer.Semantics.Text,
            To_String (Decoded), Raw);
         if not Attach_Inline (Parser, Inline) then
            Emit_Invalid (Parser, Handler, Raw);
         end if;
      end if;
   end Add_Text;

   function Is_Inline (Name : String) return Boolean is
   begin
      return Name = "strong" or else Name = "em" or else Name = "del"
        or else Name = "link" or else Name = "code-inline";
   end Is_Inline;

   function Is_Block (Name : String) return Boolean is
   begin
      return Name = "p" or else Name = "blockquote" or else Name = "list"
        or else Name = "item" or else Name = "code" or else Name = "table"
        or else Name = "row" or else Name = "cell" or else Name = "math"
        or else Name in "h1" | "h2" | "h3" | "h4" | "h5" | "h6";
   end Is_Block;

   function Is_Empty (Name : String) return Boolean is
   begin
      return Name = "br" or else Name = "hr";
   end Is_Empty;

   function Is_Allowed_Attribute
     (Name : String; Attribute_Name : String) return Boolean is
   begin
      if Name = "list" then
         return Attribute_Name = "kind" or else Attribute_Name = "start";
      elsif Name = "link" then
         return Attribute_Name = "url";
      elsif Name = "code" then
         return Attribute_Name = "lang";
      elsif Name = "row" then
         return Attribute_Name = "kind";
      elsif Name = "cell" then
         return Attribute_Name = "align";
      elsif Name = "math" then
         return Attribute_Name = "xmlns";
      end if;
      return False;
   end Is_Allowed_Attribute;

   function Positive_Value (Text : String; Value : out Positive) return Boolean is
      Result : Natural := 0;
   begin
      if Text'Length = 0 then
         return False;
      end if;
      for C of Text loop
         if not Is_Digit (C) then
            return False;
         end if;
         declare
            N : constant Natural := Character'Pos (C) - Character'Pos ('0');
         begin
            if Result > (Natural'Last - N) / 10 then
               return False;
            end if;
            Result := Result * 10 + N;
         end;
      end loop;
      if Result = 0 then
         return False;
      end if;
      Value := Positive (Result);
      return True;
   end Positive_Value;

   function Valid_Attributes
     (Info : Tag_Info; List_Kind : out Coyote_Renderer.Semantics.List_Kind;
      List_Start : out Positive; Language : out Unbounded_String;
      Header : out Boolean; Alignment : out Coyote_Renderer.Semantics.Table_Alignment)
      return Boolean is
      Name : constant String := To_String (Info.Name);
      Value : Unbounded_String;
      Start : Positive := 1;
   begin
      List_Kind := Coyote_Renderer.Semantics.Unordered_List;
      List_Start := 1;
      Language := Null_Unbounded_String;
      Header := False;
      Alignment := Coyote_Renderer.Semantics.Unspecified;
      for I in 1 .. Info.Count loop
         for J in I + 1 .. Info.Count loop
            if To_String (Info.Attributes (I).Name) =
              To_String (Info.Attributes (J).Name)
            then
               return False;
            end if;
         end loop;
      end loop;
      for I in 1 .. Info.Count loop
         declare
            A_Name : constant String :=
              To_String (Info.Attributes (I).Name);
            A_Value : constant String :=
              To_String (Info.Attributes (I).Value);
         begin
            if not Is_Allowed_Attribute (Name, A_Name) then
               return False;
            end if;
            if A_Name = "kind" and then Name = "list" then
               if A_Value = "ordered" then
                  List_Kind := Coyote_Renderer.Semantics.Ordered_List;
               elsif A_Value = "unordered" then
                  List_Kind := Coyote_Renderer.Semantics.Unordered_List;
               else
                  return False;
               end if;
            elsif A_Name = "start" then
               if not Positive_Value (A_Value, Start) then
                  return False;
               end if;
               List_Start := Start;
            elsif A_Name = "url" then
               null;
            elsif A_Name = "lang" then
               if not Decode_Entities (A_Value, Language) then
                  return False;
               end if;
            elsif A_Name = "kind" and then Name = "row" then
               if A_Value = "header" then
                  Header := True;
               elsif A_Value /= "body" then
                  return False;
               end if;
            elsif A_Name = "align" then
               if A_Value = "left" then
                  Alignment := Coyote_Renderer.Semantics.Left;
               elsif A_Value = "center" then
                  Alignment := Coyote_Renderer.Semantics.Center;
               elsif A_Value = "right" then
                  Alignment := Coyote_Renderer.Semantics.Right;
               elsif A_Value = "none" then
                  Alignment := Coyote_Renderer.Semantics.Unspecified;
               else
                  return False;
               end if;
            elsif A_Name = "xmlns" then
               if A_Value /=
                 "http://www.w3.org/1998/Math/MathML"
               then
                  return False;
               end if;
            end if;
         end;
      end loop;
      if Name = "link" then
         return Attribute_At (Info, "url", Value)
           and then Decode_Entities (To_String (Value), Language);
      elsif Name = "math" then
         return Attribute_At (Info, "xmlns", Value)
           and then To_String (Value) =
             "http://www.w3.org/1998/Math/MathML";
      elsif Name = "list" then
         return List_Kind = Coyote_Renderer.Semantics.Ordered_List
           or else not Has_Attribute (Info, "start");
      end if;
      return True;
   end Valid_Attributes;

   function Parent_Allows
     (Parser : Instance; Name : String) return Boolean is
      Parent : Unbounded_String;
   begin
      if Parser.Open = 0 then
         return Name /= "item" and then Name /= "row" and then Name /= "cell";
      end if;
      Parent := Parser.Stack (Parser.Open).Name;
      if Parent = "blockquote" then
         return Is_Block (Name) and then Name /= "item"
           and then Name /= "row" and then Name /= "cell";
      elsif Parent = "list" then
         return Name = "item";
      elsif Parent = "table" then
         return Name = "row";
      elsif Parent = "row" then
         return Name = "cell";
      elsif To_String (Parent) = "p"
        or else To_String (Parent) = "item"
        or else To_String (Parent) = "cell"
        or else Is_Inline (To_String (Parent))
      then
         return Is_Inline (Name) or else Name = "br";
      end if;
      return False;
   end Parent_Allows;

   function Find_Table
     (Parser : Instance) return Coyote_Renderer.Semantics.Block_Id is
   begin
      if Parser.Open > 0 then
         for I in reverse 1 .. Parser.Open loop
            if To_String (Parser.Stack (I).Name) = "table" then
               return Parser.Stack (I).Block;
            end if;
         end loop;
      end if;
      return Coyote_Renderer.Semantics.No_Block;
   end Find_Table;

   function Current_Cell
     (Parser : Instance) return Coyote_Renderer.Semantics.Table_Cell_Id is
   begin
      if Parser.Open > 0 then
         for I in reverse 1 .. Parser.Open loop
            if Parser.Stack (I).Cell /=
              Coyote_Renderer.Semantics.No_Table_Cell
            then
               return Parser.Stack (I).Cell;
            end if;
         end loop;
      end if;
      return Coyote_Renderer.Semantics.No_Table_Cell;
   end Current_Cell;

   function Row_Is_Valid
     (Parser : Instance;
      Table  : Coyote_Renderer.Semantics.Block_Id;
      Row    : Coyote_Renderer.Semantics.Table_Row_Id) return Boolean is
      Position : constant Natural :=
        Coyote_Renderer.Semantics.Table_Row_Count (Parser.Document, Table);
      Cells : constant Natural :=
        Coyote_Renderer.Semantics.Table_Cell_Count (Parser.Document, Row);
   begin
      if Cells = 0 then
         return False;
      elsif Coyote_Renderer.Semantics.Table_Row_Is_Header
        (Parser.Document, Row)
        and then Position /= 1
      then
         return False;
      elsif Position > 1
        and then Cells /=
          Coyote_Renderer.Semantics.Table_Cell_Count
            (Parser.Document,
             Coyote_Renderer.Semantics.Table_Row_At
               (Parser.Document, Table, 1))
      then
         return False;
      end if;
      for I in 1 .. Cells loop
         if Coyote_Renderer.Semantics.Table_Cell_Inline_Count
           (Parser.Document,
            Coyote_Renderer.Semantics.Table_Cell_At
              (Parser.Document, Row, I)) = 0
         then
            return False;
         end if;
      end loop;
      return True;
   end Row_Is_Valid;

   function Table_Is_Valid
     (Parser : Instance; Table : Coyote_Renderer.Semantics.Block_Id)
      return Boolean is
   begin
      return Coyote_Renderer.Semantics.Table_Row_Count
        (Parser.Document, Table) > 0
        and then Coyote_Renderer.Semantics.Table_Column_Count
          (Parser.Document, Table) > 0
        and then Parser.Open > 0
        and then not Parser.Stack (Parser.Open).Invalid;
   end Table_Is_Valid;

   function Event_For (Name : String) return Event_Kind is
   begin
      if Name = "table" then
         return Table_Event;
      elsif Name = "math" then
         return Math_Event;
      elsif Name = "code" then
         return Code_Event;
      elsif Name = "blockquote" then
         return Blockquote_Event;
      elsif Name in "h1" | "h2" | "h3" | "h4" | "h5" | "h6" then
         return Heading_Event;
      end if;
      return Text_Event;
   end Event_For;

   function Heading_Level (Name : String) return Natural is
   begin
      if Name'Length = 2 and then Name (Name'First) = 'h' then
         return Character'Pos (Name (Name'Last)) - Character'Pos ('0');
      end if;
      return 0;
   end Heading_Level;

   function Find_Tag_End
     (Source : String; Start : Natural) return Natural is
      In_Quote : Boolean := False;
      I        : Natural := Start + 1;
   begin
      while I <= Source'Last loop
         if Source (I) = '"' then
            In_Quote := not In_Quote;
         elsif Source (I) = '>' and then not In_Quote then
            return I;
         end if;
         I := I + 1;
      end loop;
      return 0;
   end Find_Tag_End;

   function Find_Closing_Tag
     (Source : String; Name : String; Start : Natural;
      Close_Start : out Natural; Close_End : out Natural) return Boolean is
      I    : Natural := Start;
      Info : Tag_Info;
   begin
      Close_Start := 0;
      Close_End := 0;
      while I <= Source'Last loop
         if Source (I) = '<' then
            Close_End := Find_Tag_End (Source, I);
            if Close_End /= 0
              and then Parse_Tag (Source (I .. Close_End), Info)
              and then Info.Closing
              and then To_String (Info.Name) = Name
              and then Info.Count = 0
            then
               Close_Start := I;
               return True;
            end if;
         end if;
         I := I + 1;
      end loop;
      return False;
   end Find_Closing_Tag;

   function Find_Closing_Tag_Prefix
     (Source : String; Name : String; Start : Natural;
      Prefix_Start : out Natural) return Boolean is
      I         : Natural := Start;
      Candidate : Natural;
      J         : Natural;
      Expected  : constant String := "</" & Name;
      Matched   : Boolean;
      K         : Natural;
   begin
      Prefix_Start := 0;
      while I <= Source'Last loop
         if Source (I) = '<' then
            Candidate := I;
            J := Candidate;
            Matched := True;
            K := Expected'First;
            while Matched and then K <= Expected'Last loop
               if J > Source'Last then
                  Prefix_Start := Candidate;
                  return True;
               elsif Source (J) /= Expected (K) then
                  Matched := False;
               else
                  J := J + 1;
                  K := K + 1;
               end if;
            end loop;
            if Matched then
               while J <= Source'Last and then Is_Space (Source (J)) loop
                  J := J + 1;
               end loop;
               if J > Source'Last then
                  Prefix_Start := Candidate;
                  return True;
               end if;
            end if;
         end if;
         I := I + 1;
      end loop;
      return False;
   end Find_Closing_Tag_Prefix;

   function Find_Math_Close
     (Source             : String;
      Content_First      : Natural;
      Close_Start        : out Natural;
      Close_End          : out Natural;
      Nested_Math_Count  : out Natural;
      Nested_Math_Start  : out Natural;
      Nested_Math_End    : out Natural) return Boolean
   is
      Names : array (Positive range 1 .. Max_Nesting_Depth)
        of Unbounded_String;
      Depth : Natural := 1;
      I     : Natural := Content_First;
   begin
      Close_Start       := 0;
      Close_End         := 0;
      Nested_Math_Count := 0;
      Nested_Math_Start := 0;
      Nested_Math_End   := 0;
      Names (1) := To_Unbounded_String ("math");
      while I <= Source'Last loop
         if Source (I) /= '<' then
            I := I + 1;
         else
            declare
               Tag_End : constant Natural := Find_Tag_End (Source, I);
               Info    : Tag_Info;
            begin
               if Tag_End = 0 or else not Parse_Tag
                 (Source (I .. Tag_End), Info)
               then
                  return False;
               end if;
               if Info.Closing then
                  if Depth = 0
                    or else To_String (Names (Depth)) /=
                      To_String (Info.Name)
                  then
                     return False;
                  elsif Depth = 1 then
                     Close_Start := I;
                     Close_End   := Tag_End;
                     return True;
                  else
                     Depth := Depth - 1;
                  end if;
               elsif not Info.Self_Closing then
                  if Depth = Max_Nesting_Depth then
                     return False;
                  end if;
                  if To_String (Info.Name) = "math" then
                     Nested_Math_Count := Nested_Math_Count + 1;
                     if Nested_Math_Start = 0 then
                        Nested_Math_Start := I;
                        Nested_Math_End   := Tag_End;
                     end if;
                  end if;
                  Depth := Depth + 1;
                  Names (Depth) := Info.Name;
               end if;
               I := Tag_End + 1;
            end;
         end if;
      end loop;
      return False;
   end Find_Math_Close;

   function Is_Whitespace_Range
     (Source : String; First : Natural; Last : Natural) return Boolean is
   begin
      if First > Last then
         return True;
      end if;
      for I in First .. Last loop
         if not Is_Space (Source (I)) then
            return False;
         end if;
      end loop;
      return True;
   end Is_Whitespace_Range;

   function Math_Tag_Is_Qualified (Info : Tag_Info) return Boolean is
      Namespace : Unbounded_String;
   begin
      return not Info.Closing
        and then not Info.Self_Closing
        and then To_String (Info.Name) = "math"
        and then Info.Count = 1
        and then Attribute_At (Info, "xmlns", Namespace)
        and then To_String (Namespace) =
          "http://www.w3.org/1998/Math/MathML";
   end Math_Tag_Is_Qualified;

   function Math_Source_Valid (Source : String) return Boolean is
      Outer_End        : Natural;
      Outer_Close      : Natural;
      Outer_Close_End  : Natural;
      Nested_Count     : Natural;
      Nested_Start     : Natural;
      Nested_End       : Natural;
      Inner_Close      : Natural;
      Inner_Close_End  : Natural;
      Inner_Nested     : Natural;
      Inner_Start      : Natural;
      Inner_End        : Natural;
      Outer_Info       : Tag_Info;
      Inner_Info       : Tag_Info;
      First_Nonspace   : Natural;
   begin
      if Source'Length = 0 then
         return False;
      end if;
      Outer_End := Find_Tag_End (Source, Source'First);
      if Outer_End = 0 or else not Parse_Tag
        (Source (Source'First .. Outer_End), Outer_Info)
        or else not Math_Tag_Is_Qualified (Outer_Info)
      then
         return False;
      end if;
      if not Find_Math_Close
        (Source, Outer_End + 1, Outer_Close, Outer_Close_End,
         Nested_Count, Nested_Start, Nested_End)
      then
         return False;
      end if;
      if not Is_Whitespace_Range
        (Source, Outer_Close_End + 1, Source'Last)
      then
         return False;
      end if;
      if Nested_Count = 0 then
         return True;
      elsif Nested_Count /= 1 then
         return False;
      end if;

      First_Nonspace := Outer_End + 1;
      while First_Nonspace < Outer_Close
        and then Is_Space (Source (First_Nonspace))
      loop
         First_Nonspace := First_Nonspace + 1;
      end loop;
      if First_Nonspace /= Nested_Start
        or else not Parse_Tag
          (Source (Nested_Start .. Nested_End), Inner_Info)
        or else not Math_Tag_Is_Qualified (Inner_Info)
      then
         return False;
      end if;
      if not Find_Math_Close
        (Source, Nested_End + 1, Inner_Close, Inner_Close_End,
         Inner_Nested, Inner_Start, Inner_End)
        or else Inner_Nested /= 0
        or else Inner_Close >= Outer_Close
      then
         return False;
      end if;
      return Is_Whitespace_Range
        (Source, Inner_Close_End + 1, Outer_Close - 1);
   end Math_Source_Valid;

   function Normalize_Math_Source (Source : String) return String is
      Outer_End       : Natural;
      Outer_Close     : Natural;
      Outer_Close_End : Natural;
      Nested_Count    : Natural;
      Nested_Start   : Natural;
      Nested_End     : Natural;
      Inner_Close     : Natural;
      Inner_Close_End : Natural;
      Inner_Nested    : Natural;
      Inner_Start    : Natural;
      Inner_End      : Natural;
      Outer_Info     : Tag_Info;
      First_Nonspace : Natural;
   begin
      if not Math_Source_Valid (Source) then
         return Source;
      end if;
      Outer_End := Find_Tag_End (Source, Source'First);
      if not Parse_Tag
        (Source (Source'First .. Outer_End), Outer_Info)
      then
         return Source;
      end if;
      if not Find_Math_Close
        (Source, Outer_End + 1, Outer_Close, Outer_Close_End,
         Nested_Count, Nested_Start, Nested_End)
      then
         return Source;
      end if;
      if Nested_Count = 1 then
         First_Nonspace := Outer_End + 1;
         while First_Nonspace < Outer_Close
           and then Is_Space (Source (First_Nonspace))
         loop
            First_Nonspace := First_Nonspace + 1;
         end loop;
         if First_Nonspace = Nested_Start
           and then Find_Math_Close
             (Source, Nested_End + 1, Inner_Close, Inner_Close_End,
              Inner_Nested, Inner_Start, Inner_End)
         then
            return Source (Nested_Start .. Inner_Close_End);
         end if;
      end if;
      return "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
        & Source (Outer_End + 1 .. Outer_Close - 1) & "</math>";
   end Normalize_Math_Source;

   procedure Complete_Top
     (Parser : in out Instance; Handler : Event_Handler; Last : Natural;
      Closing_Start : Natural) is
      Top_Entry : constant Stack_Entry := Parser.Stack (Parser.Open);
      Name  : constant String := To_String (Top_Entry.Name);
      Raw   : constant String := To_String (Parser.Source)
        (Top_Entry.Source_Start .. Last);
      Level : constant Natural := Heading_Level (Name);
   begin
      Ignore
        (Coyote_Renderer.Semantics.Set_Block_Source
           (Parser.Document, Top_Entry.Block, Raw));
      if Name = "code" then
         declare
            All_Source : constant String := To_String (Parser.Source);
            Payload_First : constant Natural :=
              Top_Entry.Source_Start + Top_Entry.Opening_Length;
            Payload_Last : constant Natural := Closing_Start - 1;
            Literal : constant String :=
              (if Payload_First <= Payload_Last then
                  All_Source (Payload_First .. Payload_Last)
               else "");
         begin
            Ignore
              (Coyote_Renderer.Semantics.Set_Code_Block_Data
                 (Parser.Document, Top_Entry.Block, Literal,
                  Coyote_Renderer.Semantics.Code_Language
                    (Parser.Document, Top_Entry.Block)));
         end;
      elsif Name = "math" then
         Ignore
           (Coyote_Renderer.Semantics.Set_Display_Math_Data
              (Parser.Document, Top_Entry.Block, Raw));
      end if;
      Parser.Open := Parser.Open - 1;
      Emit_Live (Parser, Live_End (Name), Raw, "", Level,
         Top_Entry.Source_Start, Last, Top_Entry.Context_Id,
         Complete => True);
      if Name = "p" then
         Emit (Handler, Paragraph_End_Event, "", 0,
           Parser.Open = 0, Last);
      elsif Name = "table" or else Name = "math" or else Name = "code"
        or else Name = "blockquote"
        or else Name in "h1" | "h2" | "h3" | "h4" | "h5" | "h6"
      then
         Emit (Handler, Event_For (Name), Raw, Level,
           Parser.Open = 0, Last);
      end if;
   end Complete_Top;

   procedure Open_Tag
     (Parser : in out Instance; Handler : Event_Handler;
      Info : Tag_Info; Start : Natural; Last : Natural) is
      Name : constant String := To_String (Info.Name);
      Kind : Coyote_Renderer.Semantics.Block_Kind;
      Inline_Kind : Coyote_Renderer.Semantics.Inline_Kind;
      List_Kind : Coyote_Renderer.Semantics.List_Kind;
      List_Start : Positive;
      Language : Unbounded_String;
      Header : Boolean;
      Alignment : Coyote_Renderer.Semantics.Table_Alignment;
      Block : Coyote_Renderer.Semantics.Block_Id;
      Inline : Coyote_Renderer.Semantics.Inline_Id;
      Row : Coyote_Renderer.Semantics.Table_Row_Id;
      Cell : Coyote_Renderer.Semantics.Table_Cell_Id;
   begin
      if Parser.Open = Max_Nesting_Depth then
         Emit_Invalid (Parser, Handler,
           To_String (Parser.Source) (Start .. Last));
         return;
      end if;
      if Info.Self_Closing then
         Emit_Invalid (Parser, Handler,
           To_String (Parser.Source) (Start .. Last));
         return;
      end if;
      if not Valid_Attributes
        (Info, List_Kind, List_Start, Language, Header, Alignment)
        or else not Parent_Allows (Parser, Name)
      then
         Emit_Invalid (Parser, Handler,
           To_String (Parser.Source) (Start .. Last));
         return;
      end if;
      if Is_Inline (Name) then
         if Name = "strong" then
            Inline_Kind := Coyote_Renderer.Semantics.Strong;
         elsif Name = "em" then
            Inline_Kind := Coyote_Renderer.Semantics.Emphasis;
         elsif Name = "del" then
            Inline_Kind := Coyote_Renderer.Semantics.Deletion;
         elsif Name = "link" then
            Inline_Kind := Coyote_Renderer.Semantics.Link;
         else
            Inline_Kind := Coyote_Renderer.Semantics.Inline_Code;
         end if;
         Inline := Coyote_Renderer.Semantics.New_Inline
           (Parser.Document, Inline_Kind, "",
            To_String (Parser.Source) (Start .. Last));
         if not Attach_Inline (Parser, Inline) then
            Emit_Invalid (Parser, Handler,
              To_String (Parser.Source) (Start .. Last));
            return;
         end if;
         if Name = "link" then
            declare
               URL : Unbounded_String;
            begin
               Ignore (Attribute_At (Info, "url", URL));
               declare
                  Decoded_URL : Unbounded_String;
               begin
                  Ignore (Decode_Entities (To_String (URL), Decoded_URL));
                  Ignore
                    (Coyote_Renderer.Semantics.Set_Link_URL
                       (Parser.Document, Inline,
                        To_String (Decoded_URL)));
               end;
            end;
         end if;
         Parser.Next_Context := Parser.Next_Context + 1;
         Parser.Open := Parser.Open + 1;
         Parser.Stack (Parser.Open) :=
           (Name => To_Unbounded_String (Name),
            Block => Coyote_Renderer.Semantics.No_Block,
            Inline => Inline,
            Row => Coyote_Renderer.Semantics.No_Table_Row,
            Cell => Coyote_Renderer.Semantics.No_Table_Cell,
            Source_Start => Start, Opening_Length => Last - Start + 1,
            Opaque_Emitted => Last + 1, Context_Id => Parser.Next_Context,
            Raw => Null_Unbounded_String, Opaque => Name = "code-inline",
            Invalid => False);
         Emit_Live (Parser, Live_Begin (Name), "", "", 0,
            Start, Last, Parser.Next_Context,
            Deferred => Name = "code-inline");
      else
         if Name = "p" then
            Kind := Coyote_Renderer.Semantics.Paragraph;
         elsif Name in "h1" | "h2" | "h3" | "h4" | "h5" | "h6" then
            Kind := Coyote_Renderer.Semantics.Heading;
         elsif Name = "blockquote" then
            Kind := Coyote_Renderer.Semantics.Blockquote;
         elsif Name = "list" then
            Kind := Coyote_Renderer.Semantics.List;
         elsif Name = "item" then
            Kind := Coyote_Renderer.Semantics.List_Item;
         elsif Name = "code" then
            Kind := Coyote_Renderer.Semantics.Code_Block;
         elsif Name = "table" then
            Kind := Coyote_Renderer.Semantics.Table;
         elsif Name = "math" then
            Kind := Coyote_Renderer.Semantics.Display_Math;
         else
            Kind := Coyote_Renderer.Semantics.Paragraph;
         end if;
         if Name = "row" then
            Row := Coyote_Renderer.Semantics.New_Table_Row
              (Parser.Document, Find_Table (Parser), Header);
            if Row = Coyote_Renderer.Semantics.No_Table_Row then
               Emit_Invalid (Parser, Handler,
                 To_String (Parser.Source) (Start .. Last));
               return;
            end if;
            Parser.Next_Context := Parser.Next_Context + 1;
            Parser.Open := Parser.Open + 1;
            Parser.Stack (Parser.Open) :=
              (Name => To_Unbounded_String (Name),
               Block => Coyote_Renderer.Semantics.No_Block,
               Inline => Coyote_Renderer.Semantics.No_Inline,
               Row => Row, Cell => Coyote_Renderer.Semantics.No_Table_Cell,
               Source_Start => Start, Opening_Length => Last - Start + 1,
               Opaque_Emitted => Last + 1, Context_Id => Parser.Next_Context,
               Raw => Null_Unbounded_String, Opaque => False,
               Invalid => False);
            Parser.Stack (Parser.Open).Context_Id := Parser.Next_Context;
            return;
         elsif Name = "cell" then
            Cell := Coyote_Renderer.Semantics.New_Table_Cell
              (Parser.Document,
               Parser.Stack (Parser.Open).Row, "",
               To_String (Parser.Source) (Start .. Last));
            if Cell = Coyote_Renderer.Semantics.No_Table_Cell then
               Emit_Invalid (Parser, Handler,
                 To_String (Parser.Source) (Start .. Last));
               return;
            end if;
            if Alignment /= Coyote_Renderer.Semantics.Unspecified then
               Ignore
                 (Coyote_Renderer.Semantics.Set_Table_Alignment
                    (Parser.Document, Find_Table (Parser),
                     Positive (Coyote_Renderer.Semantics.Table_Cell_Count
                       (Parser.Document, Parser.Stack (Parser.Open).Row)),
                     Alignment));
            end if;
            Parser.Next_Context := Parser.Next_Context + 1;
            Parser.Open := Parser.Open + 1;
            Parser.Stack (Parser.Open) :=
              (Name => To_Unbounded_String (Name),
               Block => Coyote_Renderer.Semantics.No_Block,
               Inline => Coyote_Renderer.Semantics.No_Inline,
               Row => Coyote_Renderer.Semantics.No_Table_Row, Cell => Cell,
               Source_Start => Start, Opening_Length => Last - Start + 1,
               Opaque_Emitted => Last + 1, Context_Id => Parser.Next_Context,
               Raw => Null_Unbounded_String, Opaque => False,
               Invalid => False);
            Parser.Stack (Parser.Open).Context_Id := Parser.Next_Context;
            return;
         end if;
         Block := Coyote_Renderer.Semantics.New_Block
           (Parser.Document, Kind,
            To_String (Parser.Source) (Start .. Last));
         if Parser.Open = 0 then
            Ignore (Coyote_Renderer.Semantics.Append_Block (Parser.Document, Block));
         elsif Name = "item"
           or else To_String (Parser.Stack (Parser.Open).Name) = "blockquote"
         then
            Ignore (Coyote_Renderer.Semantics.Append_Block
              (Parser.Document, Current_Block (Parser), Block));
         else
            Emit_Invalid (Parser, Handler,
              To_String (Parser.Source) (Start .. Last));
            return;
         end if;
         if Name = "list" then
            Ignore
              (Coyote_Renderer.Semantics.Set_List_Attributes
                 (Parser.Document, Block, List_Kind, List_Start));
         elsif Name in "h1" | "h2" | "h3" | "h4" | "h5" | "h6" then
            Ignore
              (Coyote_Renderer.Semantics.Set_Heading_Level
                 (Parser.Document, Block,
                  Positive (Heading_Level (Name))));
         elsif Name = "code" then
            Ignore
              (Coyote_Renderer.Semantics.Set_Code_Block_Data
                 (Parser.Document, Block, "", To_String (Language)));
         end if;
         Parser.Next_Context := Parser.Next_Context + 1;
         Parser.Open := Parser.Open + 1;
         Parser.Stack (Parser.Open) :=
           (Name => To_Unbounded_String (Name), Block => Block,
            Inline => Coyote_Renderer.Semantics.No_Inline,
            Row => Coyote_Renderer.Semantics.No_Table_Row,
            Cell => Coyote_Renderer.Semantics.No_Table_Cell,
            Source_Start => Start, Opening_Length => Last - Start + 1,
            Opaque_Emitted => Last + 1, Context_Id => Parser.Next_Context,
            Raw => Null_Unbounded_String, Opaque => Name = "code"
              or else Name = "math", Invalid => False);
         Emit_Live
           (Parser, Live_Begin (Name), "",
            (if Name = "list" then
                (if List_Kind = Coyote_Renderer.Semantics.Ordered_List then
                    "ordered:" & Positive'Image (List_Start)
                 else "unordered:1")
             else To_String (Language)),
            Heading_Level (Name), Start, Last, Parser.Next_Context,
            Deferred => Name = "table" or else Name = "code"
              or else Name = "math");
         if Name = "p" then
            Emit (Handler, Paragraph_Begin_Event);
         end if;
      end if;
   end Open_Tag;

   procedure Close_Tag
     (Parser : in out Instance; Handler : Event_Handler;
      Info : Tag_Info; Start : Natural; Last : Natural) is
      Name : constant String := To_String (Info.Name);
      Top  : constant String :=
        (if Parser.Open = 0 then "" else
           To_String (Parser.Stack (Parser.Open).Name));
      Raw  : constant String := To_String (Parser.Source) (Start .. Last);
   begin
      if Parser.Open = 0 or else Top /= Name then
         if Parser.Open > 0 then
            declare
               Root_Start : constant Natural :=
                 Parser.Stack (1).Source_Start;
            begin
               Emit_Invalid
                 (Parser, Handler,
                  To_String (Parser.Source) (Root_Start .. Last));
               Parser.Open := 0;
            end;
         else
            Emit_Invalid (Parser, Handler, Raw);
         end if;
         return;
      end if;
      if Parser.Stack (Parser.Open).Inline /=
        Coyote_Renderer.Semantics.No_Inline
      then
         declare
            Context : constant Natural := Parser.Stack (Parser.Open).Context_Id;
            Source_Start : constant Natural :=
              Parser.Stack (Parser.Open).Source_Start;
         begin
            Parser.Open := Parser.Open - 1;
            Emit_Live (Parser, Live_End (Name), "", "", 0,
               Source_Start, Last, Context, Complete => True);
         end;
         return;
      elsif Parser.Stack (Parser.Open).Cell /=
        Coyote_Renderer.Semantics.No_Table_Cell
      then
         Ignore
           (Coyote_Renderer.Semantics.Set_Table_Cell_Source
              (Parser.Document, Parser.Stack (Parser.Open).Cell,
               To_String (Parser.Source)
                 (Parser.Stack (Parser.Open).Source_Start .. Last)));
         Parser.Open := Parser.Open - 1;
         return;
      elsif Parser.Stack (Parser.Open).Row /=
        Coyote_Renderer.Semantics.No_Table_Row
      then
         declare
            Row : constant Coyote_Renderer.Semantics.Table_Row_Id :=
              Parser.Stack (Parser.Open).Row;
            Table : constant Coyote_Renderer.Semantics.Block_Id :=
              Find_Table (Parser);
            Row_Source : constant String :=
              To_String (Parser.Source)
                (Parser.Stack (Parser.Open).Source_Start .. Last);
         begin
            Ignore
              (Coyote_Renderer.Semantics.Set_Table_Row_Source
                 (Parser.Document, Row, Row_Source));
            if not Row_Is_Valid (Parser, Table, Row) then
               Emit_Invalid
                 (Parser, Handler,
                  To_String (Parser.Source)
                    (Parser.Stack (Parser.Open).Source_Start .. Last));
            end if;
         end;
         Parser.Open := Parser.Open - 1;
         return;
      elsif Name = "table" then
         declare
            Table : constant Coyote_Renderer.Semantics.Block_Id :=
              Parser.Stack (Parser.Open).Block;
            Raw_Table : constant String :=
              To_String (Parser.Source)
                (Parser.Stack (Parser.Open).Source_Start .. Last);
         begin
            if not Table_Is_Valid (Parser, Table) then
               Emit_Invalid (Parser, Handler, Raw_Table);
            else
               Complete_Top (Parser, Handler, Last, 0);
            end if;
         end;
      else
         Complete_Top (Parser, Handler, Last, 0);
      end if;
   end Close_Tag;

   procedure Complete_Empty
     (Parser : in out Instance; Handler : Event_Handler;
      Info : Tag_Info; Start : Natural; Last : Natural) is
      Name : constant String := To_String (Info.Name);
      Block : Coyote_Renderer.Semantics.Block_Id;
   begin
      if Info.Count /= 0 or else not Info.Self_Closing then
         Emit_Invalid (Parser, Handler,
           To_String (Parser.Source) (Start .. Last));
      elsif Name = "br" then
         if Parser.Open = 0 or else not Parent_Allows (Parser, "br") then
            Emit_Invalid (Parser, Handler,
              To_String (Parser.Source) (Start .. Last));
         else
            Emit (Handler, Line_Break_Event);
            Emit_Live (Parser, Live_Hard_Break_Event, "", "", 0,
               Start, Last, Current_Context (Parser), Complete => True);
            declare
               Inline : constant Coyote_Renderer.Semantics.Inline_Id :=
                 Coyote_Renderer.Semantics.New_Inline
                   (Parser.Document,
                    Coyote_Renderer.Semantics.Hard_Line_Break, "",
                    To_String (Parser.Source) (Start .. Last));
            begin
               Ignore (Attach_Inline (Parser, Inline));
            end;
         end if;
      elsif Name = "hr" then
         if Parser.Open /= 0 then
            Emit_Invalid (Parser, Handler,
              To_String (Parser.Source) (Start .. Last));
         else
            Block := Coyote_Renderer.Semantics.New_Block
              (Parser.Document, Coyote_Renderer.Semantics.Horizontal_Rule,
               To_String (Parser.Source) (Start .. Last));
            Ignore (Coyote_Renderer.Semantics.Append_Block (Parser.Document, Block));
            Emit (Handler, Horizontal_Rule_Event, "", 0, True, Last);
            Emit_Live (Parser, Live_Horizontal_Rule_Event, "", "", 0,
               Start, Last, 0, Complete => True);
         end if;
      else
         Emit_Invalid (Parser, Handler,
           To_String (Parser.Source) (Start .. Last));
      end if;
   end Complete_Empty;

   procedure Process_Opaque
     (Parser : in out Instance; Handler : Event_Handler;
      Close : out Natural) is
      Name : constant String := To_String (Parser.Stack (Parser.Open).Name);
      Source : constant String := To_String (Parser.Source);
      Close_End : Natural;
      Payload_First : constant Natural :=
        Parser.Stack (Parser.Open).Source_Start
        + Parser.Stack (Parser.Open).Opening_Length;
      Emit_Last : Natural;
      Held : Natural := 0;
   begin
      if Name = "math" then
         declare
            Nested_Count : Natural;
            Nested_Start : Natural;
            Nested_End   : Natural;
         begin
            if not Find_Math_Close
              (Source, Parser.Cursor + 1, Close, Close_End,
               Nested_Count, Nested_Start, Nested_End)
            then
               Close := 0;
            end if;
         end;
      else
         if not Find_Closing_Tag
           (Source, Name, Parser.Cursor + 1, Close, Close_End)
         then
            Close := 0;
         end if;
      end if;
      if Close = 0 then
         declare
            Prefix_Start : Natural;
         begin
            if Find_Closing_Tag_Prefix
              (Source, Name, Parser.Stack (Parser.Open).Opaque_Emitted,
               Prefix_Start)
            then
               Held := Source'Last - Prefix_Start + 1;
            end if;
         end;
         if Source'Last >= Parser.Stack (Parser.Open).Opaque_Emitted + Held then
            Emit_Last := Safe_UTF8_End
              (Source, Parser.Stack (Parser.Open).Opaque_Emitted,
               Source'Last - Held);
            if Emit_Last >= Parser.Stack (Parser.Open).Opaque_Emitted then
               Emit_Live (Parser, Live_Literal_Event,
                  Source (Parser.Stack (Parser.Open).Opaque_Emitted .. Emit_Last),
                  "", 0, Parser.Stack (Parser.Open).Opaque_Emitted, Emit_Last,
                  Parser.Stack (Parser.Open).Context_Id);
               Parser.Stack (Parser.Open).Opaque_Emitted := Emit_Last + 1;
            end if;
         end if;
         return;
      end if;
      if Close > Parser.Stack (Parser.Open).Opaque_Emitted then
         Emit_Live (Parser, Live_Literal_Event,
            Source (Parser.Stack (Parser.Open).Opaque_Emitted .. Close - 1),
            "", 0, Parser.Stack (Parser.Open).Opaque_Emitted, Close - 1,
            Parser.Stack (Parser.Open).Context_Id);
         Parser.Stack (Parser.Open).Opaque_Emitted := Close;
      end if;
      if Name = "code-inline" then
         declare
            Value : constant String := Source (Payload_First .. Close - 1);
            Cell : constant Coyote_Renderer.Semantics.Table_Cell_Id :=
              Current_Cell (Parser);
            Context : constant Natural := Parser.Stack (Parser.Open).Context_Id;
         begin
            Ignore (Coyote_Renderer.Semantics.Set_Inline_Value
              (Parser.Document, Parser.Stack (Parser.Open).Inline, Value));
            if Cell /= Coyote_Renderer.Semantics.No_Table_Cell then
               Ignore (Coyote_Renderer.Semantics.Set_Table_Cell_Value
                 (Parser.Document, Cell,
                  Coyote_Renderer.Semantics.Table_Cell_Value
                    (Parser.Document, Cell) & Value));
            end if;
            Ignore (Coyote_Renderer.Semantics.Set_Inline_Source
              (Parser.Document, Parser.Stack (Parser.Open).Inline,
               Source (Parser.Stack (Parser.Open).Source_Start .. Close_End)));
            Parser.Open := Parser.Open - 1;
            Emit_Live (Parser, Live_Code_Inline_End_Event, "", "", 0,
               Parser.Stack (Parser.Open + 1).Source_Start,
               Close_End, Context, Complete => True);
            Parser.Cursor := Close_End;
         end;
      else
         declare
            Last : constant Natural := Close_End;
         begin
            if not Math_Source_Valid
              (Source (Parser.Stack (Parser.Open).Source_Start .. Last))
              and then Name = "math"
            then
               Emit_Invalid (Parser, Handler,
                 Source (Parser.Stack (Parser.Open).Source_Start .. Last));
               Parser.Cursor := Last;
               Parser.Open := Parser.Open - 1;
               return;
            end if;
            Complete_Top (Parser, Handler, Last, Close);
            Parser.Cursor := Last;
         end;
      end if;
   end Process_Opaque;

   procedure Reset (Parser : in out Instance) is
   begin
      Parser.Pending := Null_Unbounded_String;
      Parser.Source := Null_Unbounded_String;
      Parser.Cursor := 0;
      Parser.Open := 0;
      Parser.Invalid := False;
      Parser.Next_Context := 0;
      Parser.Next_Sequence := 0;
      Parser.Live := null;
      Coyote_Renderer.Semantics.Clear (Parser.Document);
   end Reset;

   procedure Snapshot
     (Parser : Instance; Target : in out Coyote_Renderer.Semantics.Document) is
   begin
      Coyote_Renderer.Semantics.Copy (Parser.Document, Target);
   end Snapshot;

   procedure Feed_Internal
     (Parser : in out Instance; Data : String; Handler : Event_Handler) is
      Input : Unbounded_String := Parser.Source;
   begin
      Append (Input, Data);
      Parser.Source := Input;
      while Parser.Cursor < Length (Parser.Source) loop
         declare
            Source : constant String := To_String (Parser.Source);
            First  : constant Natural := Parser.Cursor + 1;
            Close  : Natural;
         begin
            if Parser.Open > 0 and then Parser.Stack (Parser.Open).Opaque then
               Process_Opaque (Parser, Handler, Close);
               exit when Close = 0;
            elsif Source (First) /= '<' then
               declare
                  Stop : Natural := First;
                  Raw_End : Natural;
               begin
                  while Stop <= Source'Last and then Source (Stop) /= '<' loop
                     Stop := Stop + 1;
                  end loop;
                  Raw_End := Safe_UTF8_End (Source, First, Stop - 1);
                  if Raw_End < First then
                     exit;
                  end if;
                  Add_Text (Parser, Handler, Source (First .. Raw_End));
                  Parser.Cursor := Raw_End;
               end;
            else
               Close := Find_Tag_End (Source, First);
               exit when Close = 0;
               declare
                  Tag : constant String := Source (First .. Close);
                  Info : Tag_Info;
               begin
                  if Parser.Open > 0
                    and then To_String (Parser.Stack (Parser.Open).Name) =
                      "math"
                  then
                     Emit_Invalid (Parser, Handler, Tag);
                  elsif Tag'Length > Max_Tag_Bytes
                    or else not Parse_Tag (Tag, Info)
                  then
                     Emit_Invalid (Parser, Handler, Tag);
                  elsif Info.Closing then
                     Close_Tag (Parser, Handler, Info, First, Close);
                  elsif Is_Empty (To_String (Info.Name)) then
                     Complete_Empty (Parser, Handler, Info, First, Close);
                  elsif Is_Block (To_String (Info.Name))
                    or else Is_Inline (To_String (Info.Name))
                  then
                     Open_Tag (Parser, Handler, Info, First, Close);
                  else
                     Emit_Invalid (Parser, Handler, Tag);
                  end if;
                  Parser.Cursor := Close;
               end;
            end if;
            exit when Parser.Invalid;
         end;
      end loop;
   end Feed_Internal;

   procedure Feed
     (Parser : in out Instance; Data : String; Handler : Event_Handler) is
   begin
      Parser.Live := null;
      Feed_Internal (Parser, Data, Handler);
   exception
      when others =>
         Parser.Live := null;
         raise;
   end Feed;

   procedure Feed
     (Parser : in out Instance; Data : String; Handler : Live_Handler) is
   begin
      Parser.Live := Handler;
      Feed_Internal (Parser, Data, Ignore_Event'Access);
      Parser.Live := null;
   exception
      when others =>
         Parser.Live := null;
         raise;
   end Feed;

   procedure Flush_Internal (Parser : in out Instance; Handler : Event_Handler) is
      Source : constant String := To_String (Parser.Source);
      First  : Natural := Parser.Cursor + 1;
      Invalid_Start : Natural := First;
   begin
      if not Parser.Invalid then
         if Parser.Open > 0 then
            Invalid_Start := Parser.Stack (1).Source_Start;
         end if;
         if Parser.Open > 0 and then Source'Length > 0 then
            Emit_Invalid (Parser, Handler, Source (Invalid_Start .. Source'Last));
         elsif Source'Length > 0 and then Invalid_Start <= Source'Last then
            Emit_Invalid (Parser, Handler, Source (Invalid_Start .. Source'Last));
         end if;
      end if;
      Parser.Pending := Null_Unbounded_String;
      Parser.Source := Null_Unbounded_String;
      Parser.Cursor := 0;
      Parser.Open := 0;
      Parser.Invalid := False;
   end Flush_Internal;

   procedure Flush
     (Parser : in out Instance; Handler : Event_Handler) is
   begin
      Parser.Live := null;
      Flush_Internal (Parser, Handler);
   exception
      when others =>
         Parser.Live := null;
         raise;
   end Flush;

   procedure Flush
     (Parser : in out Instance; Handler : Live_Handler) is
   begin
      Parser.Live := Handler;
      Flush_Internal (Parser, Ignore_Event'Access);
      Parser.Live := null;
   exception
      when others =>
         Parser.Live := null;
         raise;
   end Flush;

end Coyote_Renderer.Incremental;
