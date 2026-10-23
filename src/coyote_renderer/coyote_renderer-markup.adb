--  Coyote_Renderer.Markup body.
--
--  All shared GFM-to-Pango rendering logic lives here;
--  The native conversation stack and GTK session replay use this package.
--
--  Project: coyote

with Ada.Containers;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Coyote_App.Utils;      use Coyote_App.Utils;
with Coyote_Cmark;          use Coyote_Cmark;
with Interfaces.C;          use Interfaces.C;

package body Coyote_Renderer.Markup is

   use type Ada.Containers.Count_Type;

   function Xml_Escape (S : String) return String is
      R : Unbounded_String;
   begin
      for C of S loop
         case C is
            when '&' =>
               Append (R, "&amp;");
            when '<' =>
               Append (R, "&lt;");
            when '>' =>
               Append (R, "&gt;");
            when others =>
               Append (R, C);
         end case;
      end loop;
      return To_String (R);
   end Xml_Escape;

   function Render (MD_Text : String) return Render_Result is
      Doc         : Document;
      It          : Iterator;
      Ev          : Event_Type_Int;
      Node        : Node_Ptr;
      Out_S       : Unbounded_String;
      Result      : Render_Result;
      Link_Label  : Unbounded_String;
      Link_Url    : Unbounded_String;
      In_Link     : Boolean := False;
      Image_Depth : Natural := 0;

      --  Ordered list counter stack (up to 8 levels)
      type Level_T is range 0 .. 7;
      List_Counter : array (Level_T) of Integer := (others => 0);
      Is_Bullet    : array (Level_T) of Boolean := (others => True);
      List_Depth   : Natural                    := 0;

      function List_Indent (Depth : Natural) return String is
      begin
         if Depth <= 1 then
            return "";
         end if;
         return Str_Repeat ("  ", Depth - 1);
      end List_Indent;

      function Ends_With_Line_Feed return Boolean is
      begin
         return
           Length (Out_S) > 0
           and then Element (Out_S, Length (Out_S)) = ASCII.LF;
      end Ends_With_Line_Feed;

      --  Table accumulation state (two-pass box-drawing renderer)
      Max_Table_Cols : constant := 16;
      Max_Table_Rows : constant := 256;
      type Col_Index is range 0 .. Max_Table_Cols - 1;
      type Row_Index is range 0 .. Max_Table_Rows - 1;
      In_Cell    : Boolean := False;
      Table_Rows : Natural := 0;
      Table_Cols : Natural := 0;
      Cur_Row    : Natural := 0;
      Cur_Col    : Natural := 0;
      Table_Data : array (Row_Index, Col_Index) of Unbounded_String;

      function Cstr (N : Node_Ptr) return String is
      begin
         return Coyote_Cmark.Type_String (N);
      end Cstr;

      function Lit (N : Node_Ptr) return String is
      begin
         return Coyote_Cmark.Literal (N);
      end Lit;

      function Visible_Length (Markup : String) return Natural is
         Count : Natural := 0;
         Index : Integer := Markup'First;
      begin
         while Index <= Markup'Last loop
            if Markup (Index) = '<' then
               while Index <= Markup'Last and then Markup (Index) /= '>' loop
                  Index := Index + 1;
               end loop;
               Index := Index + 1;
            elsif Markup (Index) = '&' then
               while Index <= Markup'Last and then Markup (Index) /= ';' loop
                  Index := Index + 1;
               end loop;
               Count := Count + 1;
               Index := Index + 1;
            else
               if Character'Pos (Markup (Index)) < 16#80#
                 or else Character'Pos (Markup (Index)) >= 16#C0#
               then
                  Count := Count + 1;
               end if;
               Index := Index + 1;
            end if;
         end loop;
         return Count;
      end Visible_Length;

      function Image_Alt (Image : Node_Ptr) return String is
         Value : Unbounded_String;
         Child : Node_Ptr := Node_First_Child (Image);
      begin
         while Child /= Coyote_Cmark.Null_Node loop
            declare
               Child_Type : constant Node_Type_Int := Node_Get_Type (Child);
            begin
               if Child_Type = NODE_TEXT or else Child_Type = NODE_CODE then
                  Append (Value, Lit (Child));
               elsif Child_Type = NODE_SOFTBREAK then
                  Append (Value, " ");
               elsif Child_Type = NODE_LINEBREAK then
                  Append (Value, ASCII.LF);
               elsif Child_Type = NODE_IMAGE then
                  Append (Value, Image_Alt (Child));
               elsif Child_Type /= NODE_HTML_INLINE
                 and then Child_Type /= NODE_HTML_BLOCK
                 and then Node_First_Child (Child) /= Coyote_Cmark.Null_Node
               then
                  Append (Value, Image_Alt (Child));
               end if;
            end;
            Child := Node_Next (Child);
         end loop;
         return To_String (Value);
      end Image_Alt;

      procedure Cell_Append (S : String) is
      begin
         if Cur_Row < Max_Table_Rows and then Cur_Col < Max_Table_Cols then
            Append (Table_Data (Row_Index (Cur_Row), Col_Index (Cur_Col)), S);
         end if;
      end Cell_Append;

      procedure Render_Table is
         Max_Col_Width : constant                                   := 35;
         Col_Widths    : array (0 .. Max_Table_Cols - 1) of Natural :=
           (others => 0);

         function Pad (S : String; W : Natural) return String is
            L : constant Natural := Natural'Min (S'Length, W);
            R : String (1 .. W)  := (others => ' ');
         begin
            if L > 0 then
               R (1 .. L) := S (S'First .. S'First + L - 1);
            end if;
            return R;
         end Pad;

         procedure H_Rule (L_Cap, Junction, R_Cap : String) is
         begin
            Append (Out_S, L_Cap);
            for C in 0 .. Table_Cols - 1 loop
               for I in 1 .. Col_Widths (C) + 2 loop
                  Append (Out_S, UC_HORIZ);
               end loop;
               if C < Table_Cols - 1 then
                  Append (Out_S, Junction);
               end if;
            end loop;
            Append (Out_S, R_Cap & "" & ASCII.LF);
         end H_Rule;

      begin
         if Table_Rows = 0 or else Table_Cols = 0 then
            return;
         end if;

         for C in 0 .. Table_Cols - 1 loop
            for R in 0 .. Table_Rows - 1 loop
               declare
                  L : constant Natural :=
                    Length (Table_Data (Row_Index (R), Col_Index (C)));
               begin
                  if L > Col_Widths (C) then
                     Col_Widths (C) := L;
                  end if;
               end;
            end loop;
            if Col_Widths (C) > Max_Col_Width then
               Col_Widths (C) := Max_Col_Width;
            end if;
         end loop;
         Append (Out_S, "<tt>");
         H_Rule (UC_BOX_TL, UC_BOX_T, UC_BOX_TR);

         for R in 0 .. Table_Rows - 1 loop
            Append (Out_S, UC_BOX_V);
            for C in 0 .. Table_Cols - 1 loop
               Append (Out_S, " ");
               Append
                 (Out_S,
                  Xml_Escape
                    (Pad
                       (To_String (Table_Data (Row_Index (R), Col_Index (C))),
                        Col_Widths (C))));
               Append (Out_S, " " & UC_BOX_V);
            end loop;
            Append (Out_S, "" & ASCII.LF);

            if R = 0 and then Table_Rows > 1 then
               H_Rule (UC_BOX_L, UC_BOX_X, UC_BOX_R);
            end if;
         end loop;

         H_Rule (UC_BOX_BL, UC_BOX_B, UC_BOX_BR);
         Append (Out_S, "</tt>" & ASCII.LF);
      end Render_Table;

      type Inline_Math is record
         Source : Unbounded_String;
         Latex  : Unbounded_String;
         Token  : Unbounded_String;
      end record;
      package Inline_Math_Vectors is new Ada.Containers.Vectors
        (Index_Type => Positive, Element_Type => Inline_Math);
      Math_Items : Inline_Math_Vectors.Vector;
      Parse_Text : Unbounded_String := To_Unbounded_String (MD_Text);

      function Shield_Inline_Math return String is
         Value             : constant String := To_String (Parse_Text);
         Output            : Unbounded_String;
         Index             : Integer         := Value'First;
         Counter           : Natural         := 0;
         Fence             : Character       := ASCII.NUL;
         Fence_Ticks       : Natural         := 0;
         Code_Ticks        : Natural         := 0;
         In_HTML           : Boolean         := False;
         In_URL            : Boolean         := False;
         Destination_Depth : Natural         := 0;

         function Slash_Escaped (Position : Integer) return Boolean is
            Count  : Natural := 0;
            Cursor : Integer := Position - 1;
         begin
            while Cursor >= Value'First
              and then Value (Cursor) = ASCII.Back_Slash
            loop
               Count  := Count + 1;
               Cursor := Cursor - 1;
            end loop;
            return Count mod 2 = 1;
         end Slash_Escaped;

         function In_Raw_HTML (Position : Integer) return Boolean is
            Open_Tag   : Integer := Position - 1;
            Tag_End    : Integer;
            Tag_Closed : Boolean := False;
            Tag_Name   : Unbounded_String;
            Close_Tag  : Unbounded_String;
         begin
            while Open_Tag >= Value'First
              and then Value (Open_Tag) not in '<' | '>'
            loop
               Open_Tag := Open_Tag - 1;
            end loop;
            if Open_Tag >= Value'First and then Value (Open_Tag) = '>' then
               Tag_Closed := True;
               Open_Tag   := Open_Tag - 1;
               while Open_Tag >= Value'First and then Value (Open_Tag) /= '<'
               loop
                  Open_Tag := Open_Tag - 1;
               end loop;
            end if;
            if Open_Tag < Value'First or else Open_Tag = Position - 1 then
               return False;
            end if;
            if Ada.Strings.Fixed.Index
                (Value (Open_Tag .. Position - 1), "</") >
              0
            then
               return False;
            end if;
            Tag_End := Open_Tag + 1;
            while Tag_End < Position
              and then Value (Tag_End) in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9'
            loop
               Append (Tag_Name, Value (Tag_End));
               Tag_End := Tag_End + 1;
            end loop;
            if Length (Tag_Name) = 0 or else not Tag_Closed
              or else Tag_End >= Position or else Value (Tag_End) /= '>'
            then
               return False;
            end if;
            Close_Tag := To_Unbounded_String ("</" & To_String (Tag_Name));
            return
              Ada.Strings.Fixed.Index
                (Value (Position .. Value'Last), To_String (Close_Tag)) >
              0;
         end In_Raw_HTML;

         function New_Token return Unbounded_String is
            Candidate : Unbounded_String;
         begin
            loop
               Counter   := Counter + 1;
               Candidate :=
                 To_Unbounded_String
                   ("COYOTEINLINEMATH" &
                    Ada.Strings.Fixed.Trim
                      (Natural'Image (Counter), Ada.Strings.Both) &
                    "TOKEN");
               exit when Ada.Strings.Fixed.Index
                   (Value, To_String (Candidate)) =
                 0;
            end loop;
            return Candidate;
         end New_Token;

         procedure Save_Math (First, Last, Inner_First, Inner_Last : Integer)
         is
            Source : constant String           := Value (First .. Last);
            Latex  : constant String           :=
              (if Inner_Last >= Inner_First then
                 Value (Inner_First .. Inner_Last)
               else "");
            Token  : constant Unbounded_String := New_Token;
         begin
            if Math_Items.Length < 64 then
               Math_Items.Append
                 ((To_Unbounded_String (Source), To_Unbounded_String (Latex),
                   Token));
               Append (Output, To_String (Token));
            else
               Append (Output, Source);
            end if;
            Index := Last + 1;
         end Save_Math;

         function Fence_Line (Position : Integer) return Boolean is
            Line_End : Integer := Position;
            Cursor   : Integer := Position;
            Count    : Natural := 0;
            Char     : Character;
         begin
            while Line_End <= Value'Last and then Value (Line_End) /= ASCII.LF
            loop
               Line_End := Line_End + 1;
            end loop;
            while Cursor < Line_End and then Value (Cursor) in ' ' | ASCII.HT
            loop
               Cursor := Cursor + 1;
            end loop;
            if Cursor >= Line_End or else Value (Cursor) not in '`' | '~' then
               return False;
            end if;
            Char := Value (Cursor);
            while Cursor < Line_End and then Value (Cursor) = Char loop
               Count  := Count + 1;
               Cursor := Cursor + 1;
            end loop;
            if Fence_Ticks = 0 then
               if Count < 3 then
                  return False;
               end if;
               Fence       := Char;
               Fence_Ticks := Count;
               return True;
            elsif Char /= Fence or else Count < Fence_Ticks then
               return False;
            end if;
            while Cursor < Line_End and then Value (Cursor) in ' ' | ASCII.HT
            loop
               Cursor := Cursor + 1;
            end loop;
            if Cursor = Line_End then
               Fence_Ticks := 0;
            end if;
            return True;
         end Fence_Line;
      begin
         while Index <= Value'Last loop
            if Index = Value'First or else Value (Index - 1) = ASCII.LF then
               if Fence_Line (Index) then
                  declare
                     Finish : Integer := Index;
                  begin
                     while Finish <= Value'Last
                       and then Value (Finish) /= ASCII.LF
                     loop
                        Finish := Finish + 1;
                     end loop;
                     if Finish <= Value'Last then
                        Finish := Finish + 1;
                     end if;
                     Append (Output, Value (Index .. Finish - 1));
                     Index             := Finish;
                     Code_Ticks        := 0;
                     In_HTML           := False;
                     In_URL            := False;
                     Destination_Depth := 0;
                     goto Continue_Scan;
                  end;
               end if;
            end if;
            if Fence_Ticks > 0 then
               Append (Output, Value (Index));
               Index := Index + 1;
            elsif In_HTML then
               Append (Output, Value (Index));
               if Value (Index) = '>' then
                  In_HTML := False;
               end if;
               Index := Index + 1;
            elsif In_URL and then Value (Index) in ' ' | ASCII.HT | ASCII.LF
            then
               In_URL := False;
               Append (Output, Value (Index));
               Index := Index + 1;
            elsif Destination_Depth > 0 then
               Append (Output, Value (Index));
               if Value (Index) = '(' then
                  Destination_Depth := Destination_Depth + 1;
               elsif Value (Index) = ')' then
                  Destination_Depth := Destination_Depth - 1;
               end if;
               Index := Index + 1;
            elsif Value (Index) = '`' then
               declare
                  Finish : Integer := Index;
               begin
                  while Finish <= Value'Last and then Value (Finish) = '`' loop
                     Finish := Finish + 1;
                  end loop;
                  if Code_Ticks = 0 then
                     Code_Ticks := Finish - Index;
                  elsif Code_Ticks = Finish - Index then
                     Code_Ticks := 0;
                  end if;
                  Append (Output, Value (Index .. Finish - 1));
                  Index := Finish;
               end;
            elsif Code_Ticks = 0 and then Value (Index) = '<' then
               In_HTML := True;
               Append (Output, Value (Index));
               Index := Index + 1;
            elsif Code_Ticks = 0
              and then
              (Index = Value'First
               or else Value (Index - 1) in ' ' | ASCII.HT | ASCII.LF)
              and then Index + 6 <= Value'Last
              and then
              (Value (Index .. Index + 6) = "http://"
               or else
               (Index + 7 <= Value'Last
                and then Value (Index .. Index + 7) = "https://"))
            then
               In_URL := True;
               Append (Output, Value (Index));
               Index := Index + 1;
            elsif Code_Ticks = 0 and then Value (Index) = '('
              and then Index > Value'First and then Value (Index - 1) = ']'
            then
               Destination_Depth := 1;
               Append (Output, Value (Index));
               Index := Index + 1;
            elsif Code_Ticks = 0 and then not In_HTML and then not In_URL
              and then not In_Raw_HTML (Index)
              and then not Slash_Escaped (Index) and then Value (Index) = '$'
              and then Index < Value'Last and then Value (Index + 1) /= '$'
              and then Value (Index + 1) /= ' '
              and then (Index = Value'First or else Value (Index - 1) /= '$')
            then
               declare
                  Finish : Integer := Index + 1;
               begin
                  while Finish <= Value'Last loop
                     exit when Value (Finish) = ASCII.LF;
                     if Value (Finish) = '$' and then Finish > Index + 1
                       and then
                         Ada.Strings.Fixed.Index
                           (Value (Index + 1 .. Finish - 1), " and ") >
                         0
                     then
                        Finish := Value'Last + 1;
                        exit;
                     end if;
                     if Value (Finish) = '$' and then Finish > Index + 1
                       and then Value (Finish - 1) not in ' ' | ASCII.HT
                       and then not Slash_Escaped (Finish)
                       and then
                       (Finish = Value'Last
                        or else Value (Finish + 1) not in '0' .. '9')
                       and then
                       (Finish = Value'Last or else Value (Finish + 1) /= '$')
                       and then not
                       (Finish + 2 <= Value'Last
                        and then Value (Finish + 1) in ',' | ';'
                        and then Value (Finish + 2) = ' '
                        and then Finish + 4 <= Value'Last
                        and then Value (Finish + 3) = '$'
                        and then Value (Finish + 4) in '0' .. '9')
                     then
                        exit;
                     end if;
                     Finish := Finish + 1;
                  end loop;
                  if Finish <= Value'Last and then Value (Finish) = '$'
                    and then Value (Index + 1) in '0' .. '9'
                    and then
                      Ada.Strings.Fixed.Index
                        (Value (Index + 1 .. Finish - 1), " and ") >
                      0
                  then
                     Append (Output, Value (Index .. Finish));
                     Index := Finish + 1;
                  elsif Finish <= Value'Last and then Value (Finish) = '$'
                    and then not
                    (Value (Index + 1) in '0' .. '9'
                     and then
                       Ada.Strings.Fixed.Index
                         (Value (Index + 1 .. Finish - 1), " ") >
                       0)
                  then
                     Save_Math (Index, Finish, Index + 1, Finish - 1);
                  else
                     Append (Output, Value (Index));
                     Index := Index + 1;
                  end if;
               end;
            elsif Code_Ticks = 0 and then not Slash_Escaped (Index)
              and then Value (Index) = ASCII.Back_Slash
              and then Index < Value'Last and then Value (Index + 1) = '('
            then
               declare
                  Finish : Integer := Index + 2;
               begin
                  while Finish + 1 <= Value'Last
                    and then not
                    (Value (Finish) = ASCII.Back_Slash
                     and then Value (Finish + 1) = ')'
                     and then not Slash_Escaped (Finish))
                    and then Value (Finish) /= ASCII.LF
                  loop
                     Finish := Finish + 1;
                  end loop;
                  if Finish + 1 <= Value'Last
                    and then Value (Finish) = ASCII.Back_Slash
                    and then Value (Finish + 1) = ')'
                  then
                     Save_Math (Index, Finish + 1, Index + 2, Finish - 1);
                  else
                     Append (Output, Value (Index));
                     Index := Index + 1;
                  end if;
               end;
            else
               Append (Output, Value (Index));
               Index := Index + 1;
            end if;
            <<Continue_Scan>>
            null;
         end loop;
         return To_String (Output);
      end Shield_Inline_Math;

   begin
      if MD_Text'Length = 0 then
         return Result;
      end if;

      Parse_Text := To_Unbounded_String (Shield_Inline_Math);
      declare
         C_Text : constant Interfaces.C.char_array :=
           Interfaces.C.To_C (To_String (Parse_Text));
      begin
         Parse (Doc, C_Text, C_Text'Length - 1, OPT_DEFAULT);
      end;
      if Is_Null (Root (Doc)) then
         Result.Markup := To_Unbounded_String (Xml_Escape (MD_Text));
         return Result;
      end if;

      Start (It, Root (Doc));
      if Is_Null (Handle (It)) then
         Result.Markup := To_Unbounded_String (Xml_Escape (MD_Text));
         return Result;
      end if;
      loop
         Ev := Iter_Next (Handle (It));
         exit when Ev = EVENT_DONE;
         Node := Iter_Get_Node (Handle (It));

         declare
            NT : constant Node_Type_Int := Node_Get_Type (Node);
            TS : constant String        := Cstr (Node);
         begin
            if Image_Depth > 0 then
               if NT = NODE_IMAGE then
                  if Ev = EVENT_ENTER then
                     Image_Depth := Image_Depth + 1;
                  else
                     Image_Depth := Image_Depth - 1;
                  end if;
               end if;

            elsif NT = NODE_IMAGE then
               if Ev = EVENT_ENTER and then not In_Cell then
                  declare
                     Alt          : constant String := Image_Alt (Node);
                     Shown        : constant String           :=
                       (if Alt'Length = 0 then "[image]" else Alt);
                     Start_Offset : constant Natural          :=
                       Visible_Length (To_String (Out_S));
                     Link_Target  : constant Unbounded_String :=
                       (if In_Link then Link_Url else Null_Unbounded_String);
                     Shown_Length : constant Natural          :=
                       Visible_Length (Xml_Escape (Shown));
                  begin
                     Append (Out_S, Xml_Escape (Shown));
                     if In_Link then
                        Append (Link_Label, Shown);
                     end if;
                     Result.Images.Append
                       ((Alt_Text         => To_Unbounded_String (Alt),
                         Destination      =>
                           To_Unbounded_String (Coyote_Cmark.Url (Node)),
                         Title            =>
                           To_Unbounded_String (Coyote_Cmark.Title (Node)),
                         Link_Destination => Link_Target,
                         Start_Char       => Start_Offset,
                         End_Char         => Start_Offset + Shown_Length));
                     Image_Depth := 1;
                  end;
               end if;

            elsif TS = "table" then
               if Ev = EVENT_ENTER then
                  Cur_Row    := 0;
                  Cur_Col    := 0;
                  Table_Rows := 0;
                  Table_Cols := 0;
               else
                  Render_Table;
               end if;

            elsif TS = "table_header" then
               if Ev = EVENT_EXIT then
                  if Cur_Col > Table_Cols then
                     Table_Cols := Natural'Min (Cur_Col, Max_Table_Cols);
                  end if;
                  Cur_Row    := Natural'Min (Cur_Row + 1, Max_Table_Rows);
                  Table_Rows := Cur_Row;
                  Cur_Col    := 0;
               end if;
            elsif TS = "table_row" then
               if Ev = EVENT_EXIT then
                  if Cur_Col > Table_Cols then
                     Table_Cols := Natural'Min (Cur_Col, Max_Table_Cols);
                  end if;
                  Cur_Row    := Natural'Min (Cur_Row + 1, Max_Table_Rows);
                  Table_Rows := Cur_Row;
                  Cur_Col    := 0;
               end if;
            elsif TS = "table_cell" then
               if Ev = EVENT_ENTER then
                  if Cur_Row < Max_Table_Rows and then Cur_Col < Max_Table_Cols
                  then
                     Table_Data (Row_Index (Cur_Row), Col_Index (Cur_Col)) :=
                       Null_Unbounded_String;
                  end if;
                  In_Cell := True;
               else
                  In_Cell := False;
                  Cur_Col := Natural'Min (Cur_Col + 1, Max_Table_Cols);
               end if;

            elsif NT = NODE_DOCUMENT then
               null;

            elsif NT = NODE_PARAGRAPH then
               if Ev = EVENT_EXIT and then not In_Cell then
                  --  A paragraph inside a list item is an item separator;
                  --  it must not emit the blank block separator.
                  if List_Depth > 0 then
                     if not Ends_With_Line_Feed then
                        Append (Out_S, ASCII.LF);
                     end if;
                  else
                     Append (Out_S, "" & ASCII.LF & ASCII.LF);
                  end if;
               end if;

            elsif NT = NODE_HEADING then
               if not In_Cell then
                  if Ev = EVENT_ENTER then
                     declare
                        H_Level : constant Interfaces.C.int :=
                          Node_Get_Heading_Level (Node);
                     begin
                        if H_Level <= 2 then
                           Append
                             (Out_S,
                              ASCII.LF & "<span weight=""bold""" &
                              " size=""larger"">");
                        elsif H_Level <= 4 then
                           Append
                             (Out_S,
                              ASCII.LF & "<span weight=""bold""" &
                              " size=""medium"">");
                        else
                           Append (Out_S, ASCII.LF & "<span weight=""bold"">");
                        end if;
                     end;
                  else
                     Append (Out_S, "</span>" & ASCII.LF & ASCII.LF);
                  end if;
               end if;

            elsif NT = NODE_STRONG then
               if not In_Cell then
                  if Ev = EVENT_ENTER then
                     Append (Out_S, "<b>");
                  else
                     Append (Out_S, "</b>");
                  end if;
               end if;

            elsif NT = NODE_EMPH then
               if not In_Cell then
                  if Ev = EVENT_ENTER then
                     Append (Out_S, "<i>");
                  else
                     Append (Out_S, "</i>");
                  end if;
               end if;

            elsif NT = NODE_LINK then
               if not In_Cell then
                  if Ev = EVENT_ENTER then
                     Link_Label := Null_Unbounded_String;
                     Link_Url := To_Unbounded_String (Coyote_Cmark.Url (Node));
                     In_Link    := True;
                     Append (Out_S, "<u>");
                  else
                     Append (Out_S, "</u>");
                     if Length (Link_Label) > 0 then
                        Result.Links.Append
                          ((Label => Link_Label, Destination => Link_Url));
                     end if;
                     In_Link := False;
                  end if;
               end if;

            elsif NT = NODE_CODE then
               if Ev = EVENT_ENTER then
                  if In_Cell then
                     Cell_Append (Lit (Node));
                  else
                     Append (Out_S, "<tt>");
                     Append (Out_S, Xml_Escape (Lit (Node)));
                     Append (Out_S, "</tt>");
                     if In_Link then
                        Append (Link_Label, Lit (Node));
                     end if;
                  end if;
               end if;

            elsif NT = NODE_CODE_BLOCK then
               if Ev = EVENT_ENTER and then not In_Cell then
                  Append
                    (Out_S, ASCII.LF & "<span background=""#f4f4f4""><tt>");
                  Append (Out_S, Xml_Escape (Lit (Node)));
                  Append (Out_S, "</tt></span>" & ASCII.LF);
               end if;

            elsif NT = NODE_HTML_INLINE or else NT = NODE_HTML_BLOCK then
               if Ev = EVENT_ENTER then
                  declare
                     Html_Source : constant String := Lit (Node);
                  begin
                     if In_Cell then
                        Cell_Append (Html_Source);
                     else
                        Append (Out_S, Xml_Escape (Html_Source));
                        if In_Link then
                           Append (Link_Label, Html_Source);
                        end if;
                     end if;
                  end;
               end if;

            elsif NT = NODE_BLOCK_QUOTE then
               if not In_Cell then
                  if Ev = EVENT_ENTER then
                     Append
                       (Out_S,
                        ASCII.LF &
                        "<span alpha=""50%%"" font_style=""italic"">" &
                        UC_BOX_V & " ");
                  else
                     Append (Out_S, "</span>" & ASCII.LF & ASCII.LF);
                  end if;
               end if;

            elsif NT = NODE_LIST then
               if not In_Cell then
                  if Ev = EVENT_ENTER then
                     if List_Depth < Natural (Level_T'Last) then
                        List_Depth                          := List_Depth + 1;
                        List_Counter (Level_T (List_Depth)) :=
                          Integer (Node_Get_List_Start (Node)) - 1;
                        Is_Bullet (Level_T (List_Depth))    :=
                          (Node_Get_List_Type (Node) = LIST_BULLET);
                     end if;
                  else
                     if List_Depth > 0 then
                        List_Depth := List_Depth - 1;
                     end if;
                     if not Ends_With_Line_Feed then
                        Append (Out_S, ASCII.LF);
                     end if;
                  end if;
               end if;

            elsif NT = NODE_ITEM then
               if Ev = EVENT_ENTER and then List_Depth > 0 and then not In_Cell
               then
                  if not Ends_With_Line_Feed then
                     Append (Out_S, ASCII.LF);
                  end if;
                  Append (Out_S, List_Indent (List_Depth));
                  if Is_Bullet (Level_T (List_Depth)) then
                     Append (Out_S, UC_BULLET & " ");
                  else
                     List_Counter (Level_T (List_Depth)) :=
                       List_Counter (Level_T (List_Depth)) + 1;
                     Append
                       (Out_S,
                        Ada.Strings.Fixed.Trim
                          (Integer'Image (List_Counter (Level_T (List_Depth))),
                           Ada.Strings.Left) &
                        ". ");
                  end if;
               end if;

            elsif NT = NODE_TEXT then
               if Ev = EVENT_ENTER then
                  declare
                     Text_Value : constant String := Lit (Node);
                     Cursor     : Natural         := Text_Value'First;
                     Position   : Natural;
                     Found      : Natural;
                     Best       : Natural;

                     procedure Emit (Text : String) is
                     begin
                        if In_Cell then
                           Cell_Append (Text);
                        else
                           Append (Out_S, Xml_Escape (Text));
                           if In_Link then
                              Append (Link_Label, Text);
                           end if;
                        end if;
                     end Emit;
                  begin
                     while Cursor <= Text_Value'Last loop
                        Found := 0;
                        Best  := 0;
                        for Index in
                          Math_Items.First_Index .. Math_Items.Last_Index
                        loop
                           Position :=
                             Ada.Strings.Fixed.Index
                               (Text_Value,
                                To_String (Math_Items (Index).Token), Cursor);
                           if Position > 0
                             and then (Found = 0 or else Position < Found)
                           then
                              Found := Position;
                              Best  := Index;
                           end if;
                        end loop;
                        if Found = 0 then
                           Emit (Text_Value (Cursor .. Text_Value'Last));
                           exit;
                        end if;
                        if Found > Cursor then
                           Emit (Text_Value (Cursor .. Found - 1));
                        end if;
                        declare
                           Item : constant Inline_Math := Math_Items (Best);
                           Start_Char : constant Natural     :=
                             Visible_Length (To_String (Out_S));
                           Source : constant String := To_String (Item.Source);
                        begin
                           Emit (Source);
                           if not In_Cell then
                              Result.Maths.Append
                                ((Source => Item.Source, LaTeX => Item.Latex,
                                  Start_Char => Start_Char,
                                  End_Char   =>
                                    Start_Char +
                                    Visible_Length (Xml_Escape (Source))));
                           end if;
                           Cursor := Found + Length (Item.Token);
                        end;
                     end loop;
                  end;
               end if;

            elsif NT = NODE_SOFTBREAK then
               if Ev = EVENT_ENTER then
                  if In_Cell then
                     Cell_Append (" ");
                  else
                     Append (Out_S, " ");
                     if In_Link then
                        Append (Link_Label, " ");
                     end if;
                  end if;
               end if;

            elsif NT = NODE_LINEBREAK then
               if Ev = EVENT_ENTER then
                  if In_Cell then
                     Cell_Append (" ");
                  else
                     Append (Out_S, "" & ASCII.LF);
                     if In_Link then
                        Append (Link_Label, ASCII.LF);
                     end if;
                  end if;
               end if;

            elsif NT = NODE_THEMATIC_BREAK then
               if Ev = EVENT_ENTER and then not In_Cell then
                  Append
                    (Out_S,
                     "<span alpha=""50%%"">" & UC_HORIZ & UC_HORIZ & UC_HORIZ &
                     UC_HORIZ & UC_HORIZ & UC_HORIZ & UC_HORIZ & UC_HORIZ &
                     UC_HORIZ & UC_HORIZ & UC_HORIZ & UC_HORIZ & "</span>" &
                     ASCII.LF);
               end if;

            else
               if TS = "strikethrough" and then not In_Cell then
                  if Ev = EVENT_ENTER then
                     Append (Out_S, "<s>");
                  else
                     Append (Out_S, "</s>");
                  end if;
               end if;
            end if;
         end;
      end loop;

      if Length (Out_S) = 0 then
         Result.Markup := To_Unbounded_String (Xml_Escape (MD_Text));
      else
         Result.Markup := Out_S;
      end if;
      return Result;

   end Render;

   function To_Pango_Markup (MD_Text : String) return String is
   begin
      return To_String (Render (MD_Text).Markup);
   end To_Pango_Markup;
end Coyote_Renderer.Markup;
