--  Coyote_Renderer.Markup body.
--
--  Extracted from Coyote_GUI.Buffer.  All rendering logic lives here;
--  Coyote_GUI.Buffer delegates to this package.
--
--  Project: coyote

with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Coyote_App.Utils;       use Coyote_App.Utils;
with Coyote_Cmark;           use Coyote_Cmark;
with Interfaces.C;           use Interfaces.C;
with Interfaces.C.Strings;
with System;                 use System;

package body Coyote_Renderer.Markup is

   function Xml_Escape (S : String) return String is
      R : Unbounded_String;
   begin
      for C of S loop
         case C is
            when '&'    => Append (R, "&amp;");
            when '<'    => Append (R, "&lt;");
            when '>'    => Append (R, "&gt;");
            when others => Append (R, C);
         end case;
      end loop;
      return To_String (R);
   end Xml_Escape;

   function To_Pango_Markup (MD_Text : String) return String is
      use type Interfaces.C.int;

      Doc   : Node_Ptr;
      It    : Iter_Ptr;
      Ev    : Event_Type_Int;
      Node  : Node_Ptr;
      Out_S : Unbounded_String;

      --  Ordered list counter stack (up to 8 levels)
      type Level_T is range 0 .. 7;
      List_Counter : array (Level_T) of Integer := (others => 0);
      Is_Bullet    : array (Level_T) of Boolean := (others => True);
      List_Depth   : Natural := 0;

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
         return Interfaces.C.Strings.Value
           (Coyote_Cmark.Node_Get_Type_String (N));
      end Cstr;

      function Lit (N : Node_Ptr) return String is
      begin
         return Interfaces.C.Strings.Value
           (Coyote_Cmark.Node_Get_Literal (N));
      end Lit;

      procedure Cell_Append (S : String) is
      begin
         if Cur_Row < Max_Table_Rows and then Cur_Col < Max_Table_Cols then
            Append
              (Table_Data (Row_Index (Cur_Row), Col_Index (Cur_Col)), S);
         end if;
      end Cell_Append;

      procedure Render_Table is
         Max_Col_Width : constant := 35;
         Col_Widths    : array (0 .. Max_Table_Cols - 1) of Natural :=
           (others => 0);

         function Pad (S : String; W : Natural) return String is
            L : constant Natural := Natural'Min (S'Length, W);
            R : String (1 .. W) := (others => ' ');
         begin
            R (1 .. L) := S (S'First .. S'First + L - 1);
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
               Append (Out_S,
                 Xml_Escape
                   (Pad
                      (To_String
                         (Table_Data (Row_Index (R), Col_Index (C))),
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

      C_Text : constant Interfaces.C.char_array :=
        Interfaces.C.To_C (MD_Text);

   begin
      if MD_Text'Length = 0 then
         return "";
      end if;

      Doc := Parse_Document (C_Text, C_Text'Length - 1, OPT_DEFAULT);
      if Doc = System.Null_Address then
         return Xml_Escape (MD_Text);
      end if;

      It := Iter_New (Doc);
      loop
         Ev   := Iter_Next (It);
         Node := Iter_Get_Node (It);
         exit when Ev = EVENT_DONE;

         declare
            NT : constant Node_Type_Int := Node_Get_Type (Node);
            TS : constant String := Cstr (Node);
         begin
            if TS = "table" then
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
                     Table_Cols := Cur_Col;
                  end if;
                  Cur_Row    := Cur_Row + 1;
                  Table_Rows := Cur_Row;
                  Cur_Col    := 0;
               end if;

            elsif TS = "table_row" then
               if Ev = EVENT_EXIT then
                  if Cur_Col > Table_Cols then
                     Table_Cols := Cur_Col;
                  end if;
                  Cur_Row    := Cur_Row + 1;
                  Table_Rows := Cur_Row;
                  Cur_Col    := 0;
               end if;

            elsif TS = "table_cell" then
               if Ev = EVENT_ENTER then
                  if Cur_Row < Max_Table_Rows
                    and then Cur_Col < Max_Table_Cols
                  then
                     Table_Data (Row_Index (Cur_Row), Col_Index (Cur_Col)) :=
                       Null_Unbounded_String;
                  end if;
                  In_Cell := True;
               else
                  In_Cell := False;
                  Cur_Col := Cur_Col + 1;
               end if;

            elsif NT = NODE_DOCUMENT then
               null;

            elsif NT = NODE_PARAGRAPH then
               if Ev = EVENT_EXIT and then not In_Cell then
                  Append (Out_S, "" & ASCII.LF & ASCII.LF);
               end if;

            elsif NT = NODE_HEADING then
               if not In_Cell then
                  if Ev = EVENT_ENTER then
                     declare
                        H_Level : constant Interfaces.C.int :=
                          Node_Get_Heading_Level (Node);
                     begin
                        if H_Level <= 2 then
                           Append (Out_S, ASCII.LF
                                   & "<span weight=""bold"""
                                   & " size=""larger"">");
                        elsif H_Level <= 4 then
                           Append (Out_S, ASCII.LF
                                   & "<span weight=""bold"""
                                   & " size=""medium"">");
                        else
                           Append (Out_S, ASCII.LF
                                   & "<span weight=""bold"">");
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
                     Append (Out_S, "<u>");
                  else
                     Append (Out_S, "</u>");
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
                  end if;
               end if;

            elsif NT = NODE_CODE_BLOCK then
               if Ev = EVENT_ENTER and then not In_Cell then
                  Append (Out_S, ASCII.LF
                          & "<span background=""#f4f4f4""><tt>");
                  Append (Out_S, Xml_Escape (Lit (Node)));
                  Append (Out_S, "</tt></span>" & ASCII.LF);
               end if;

            elsif NT = NODE_BLOCK_QUOTE then
               if not In_Cell then
                  if Ev = EVENT_ENTER then
                     Append (Out_S, ASCII.LF
                             & "<span alpha=""50%%"" font_style=""italic"">"
                             & UC_BOX_V & " ");
                  else
                     Append (Out_S, "</span>" & ASCII.LF & ASCII.LF);
                  end if;
               end if;

            elsif NT = NODE_LIST then
               if not In_Cell then
                  if Ev = EVENT_ENTER then
                     if List_Depth < Natural (Level_T'Last) then
                        List_Depth := List_Depth + 1;
                        List_Counter (Level_T (List_Depth)) := 0;
                        Is_Bullet   (Level_T (List_Depth)) :=
                          (Node_Get_List_Type (Node) = LIST_BULLET);
                     end if;
                  else
                     if List_Depth > 0 then
                        List_Depth := List_Depth - 1;
                     end if;
                     Append (Out_S, "" & ASCII.LF);
                  end if;
               end if;

            elsif NT = NODE_ITEM then
               if Ev = EVENT_ENTER
                 and then List_Depth > 0
                 and then not In_Cell
               then
                  if Is_Bullet (Level_T (List_Depth)) then
                     Append (Out_S, UC_BULLET & " ");
                  else
                     List_Counter (Level_T (List_Depth)) :=
                       List_Counter (Level_T (List_Depth)) + 1;
                     Append (Out_S,
                       Ada.Strings.Fixed.Trim
                         (Integer'Image
                            (List_Counter (Level_T (List_Depth))),
                          Ada.Strings.Left) & ". ");
                  end if;
               end if;

            elsif NT = NODE_TEXT then
               if Ev = EVENT_ENTER then
                  if In_Cell then
                     Cell_Append (Lit (Node));
                  else
                     Append (Out_S, Xml_Escape (Lit (Node)));
                  end if;
               end if;

            elsif NT = NODE_SOFTBREAK then
               if Ev = EVENT_ENTER then
                  if In_Cell then
                     Cell_Append (" ");
                  else
                     Append (Out_S, " ");
                  end if;
               end if;

            elsif NT = NODE_LINEBREAK then
               if Ev = EVENT_ENTER then
                  if In_Cell then
                     Cell_Append (" ");
                  else
                     Append (Out_S, "" & ASCII.LF);
                  end if;
               end if;

            elsif NT = NODE_THEMATIC_BREAK then
               if Ev = EVENT_ENTER and then not In_Cell then
                  Append (Out_S,
                    "<span alpha=""50%%"">"
                    & UC_HORIZ & UC_HORIZ & UC_HORIZ & UC_HORIZ
                    & UC_HORIZ & UC_HORIZ & UC_HORIZ & UC_HORIZ
                    & UC_HORIZ & UC_HORIZ & UC_HORIZ & UC_HORIZ
                    & "</span>" & ASCII.LF);
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

      Iter_Free (It);
      Node_Free (Doc);
      return To_String (Out_S);
   end To_Pango_Markup;

end Coyote_Renderer.Markup;
