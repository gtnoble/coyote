--  Coyote_GUI.Buffer body.
--
--  Project: coyote

with Ada.Strings.Unbounded;          use Ada.Strings.Unbounded;
with Ada.Strings.Fixed;
with Coyote_App.Utils;               use Coyote_App.Utils;
with GNATCOLL.JSON;
with Coyote_Cmark;                   use Coyote_Cmark;
with Glib;                           use Glib;
with Glib.Properties;                use Glib.Properties;
with Gtk.Frame;
with Gtk.Label;
with Gtk.Text_Buffer;
with Gtk.Text_Iter;
with Gtk.Text_Mark;
with Gtk.Text_View;
with Gtk.Box;
with Gtk.Expander;
with Gtk.Separator;
with Gtk.Text_Child_Anchor;
with Gtk.Text_Tag;                   use Gtk.Text_Tag;
with Gtk.Widget;
with Interfaces.C;                   use Interfaces.C;
with Interfaces.C.Strings;
with Pango.Enums;
with System;                         use System;

package body Coyote_GUI.Buffer is

   --  ── Pango markup helper ───────────────────────────────────────────────

   function Xml_Escape (S : String) return String is
      use Ada.Strings.Unbounded;
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

   --  ── Markdown → Pango markup ───────────────────────────────────────────

   function To_Pango_Markup (MD_Text : String) return String is
      use Ada.Strings.Unbounded;
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

      --  Append S to the current table cell accumulation buffer.
      procedure Cell_Append (S : String) is
      begin
         if Cur_Row < Max_Table_Rows and then Cur_Col < Max_Table_Cols then
            Append
              (Table_Data (Row_Index (Cur_Row), Col_Index (Cur_Col)), S);
         end if;
      end Cell_Append;

      --  Render the accumulated table as a monospace box-drawing block into
      --  Out_S, then clear the table state.
      procedure Render_Table is
         Max_Col_Width : constant := 35;
         Col_Widths    : array (0 .. Max_Table_Cols - 1) of Natural :=
           (others => 0);

         --  Return S padded with spaces (or truncated) to exactly W chars.
         function Pad (S : String; W : Natural) return String is
            L : constant Natural := Natural'Min (S'Length, W);
            R : String (1 .. W) := (others => ' ');
         begin
            R (1 .. L) := S (S'First .. S'First + L - 1);
            return R;
         end Pad;

         --  Emit one horizontal rule using the supplied cap/junction glyphs.
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

         --  Compute per-column widths, capped at Max_Col_Width.
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

         --  Emit the whole table inside a single <tt> span so the monospace
         --  font makes columns align.
         Append (Out_S, "<tt>");
         H_Rule (UC_BOX_TL, UC_BOX_T, UC_BOX_TR);

         for R in 0 .. Table_Rows - 1 loop
            --  Data row
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

            --  Separator beneath the header row
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
                  --  Reset this cell before accumulating new content.
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
                  Append (Out_S, "" & ASCII.LF);
               end if;

            elsif NT = NODE_HEADING then
               if not In_Cell then
                  if Ev = EVENT_ENTER then
                     Append (Out_S, "<b>");
                  else
                     Append (Out_S, "</b>" & ASCII.LF);
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
                  Append (Out_S, "<tt>");
                  Append (Out_S, Xml_Escape (Lit (Node)));
                  Append (Out_S, "</tt>" & ASCII.LF);
               end if;

            elsif NT = NODE_BLOCK_QUOTE then
               if not In_Cell then
                  if Ev = EVENT_ENTER then
                     Append (Out_S, "<i><span alpha=""50%%"">");
                  else
                     Append (Out_S, "</span></i>" & ASCII.LF);
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

   --  ── Tag setup ─────────────────────────────────────────────────────────

   procedure Attach
     (B    : in out Instance;
      View : Gtk.Text_View.Gtk_Text_View;
      Buf  : Gtk.Text_Buffer.Gtk_Text_Buffer)
   is
   begin
      B.The_View := View;
      B.The_Buf  := Buf;

      B.Tag_Thinking := Buf.Create_Tag ("thinking");
      Set_Property (B.Tag_Thinking, Foreground_Property, "#888888");
      Set_Property (B.Tag_Thinking, Left_Margin_Property, Gint (24));

      B.Tag_Notice_Info := Buf.Create_Tag ("notice_info");
      Set_Property (B.Tag_Notice_Info, Foreground_Property, "#4488cc");

      B.Tag_Notice_Warn := Buf.Create_Tag ("notice_warn");
      Set_Property (B.Tag_Notice_Warn, Foreground_Property, "#cc8800");

      B.Tag_Notice_Error := Buf.Create_Tag ("notice_error");
      Set_Property (B.Tag_Notice_Error, Foreground_Property, "#cc3333");

      B.Tag_Footer := Buf.Create_Tag ("footer");
      Set_Property (B.Tag_Footer, Foreground_Property, "#888888");
   end Attach;

   --  ── Internal helpers ──────────────────────────────────────────────────

   procedure Insert_Tagged
     (B    : in out Instance;
      Text :        String;
      Tag  :        Gtk.Text_Tag.Gtk_Text_Tag)
   is
      use Gtk.Text_Iter;
      Iter  : Gtk.Text_Iter.Gtk_Text_Iter;
      Mark  : Gtk.Text_Mark.Gtk_Text_Mark;
      SI    : Gtk.Text_Iter.Gtk_Text_Iter;
   begin
      B.The_Buf.Get_End_Iter (Iter);
      Mark := B.The_Buf.Create_Mark ("", Iter, Left_Gravity => True);
      B.The_Buf.Insert (Iter, Text);
      B.The_Buf.Get_Iter_At_Mark (SI, Mark);
      B.The_Buf.Apply_Tag (Tag, SI, Iter);
      B.The_Buf.Delete_Mark (Mark);
   end Insert_Tagged;

   procedure Insert_Plain (B : in out Instance; Text : String) is
      use Gtk.Text_Iter;
      Iter : Gtk.Text_Iter.Gtk_Text_Iter;
   begin
      B.The_Buf.Get_End_Iter (Iter);
      B.The_Buf.Insert (Iter, Text);
   end Insert_Plain;

   --  ── Streaming text ────────────────────────────────────────────────────

   procedure Append_Text (B : in out Instance; Text : String) is
      use Gtk.Text_Iter;
      Iter : Gtk.Text_Iter.Gtk_Text_Iter;
   begin
      if not B.In_Text_Block then
         B.In_Text_Block := True;
         B.Stream_Buf    := Ada.Strings.Unbounded.Null_Unbounded_String;
         B.The_Buf.Get_End_Iter (Iter);
         B.Stream_Mark :=
           B.The_Buf.Create_Mark ("", Iter, Left_Gravity => True);
      end if;
      Ada.Strings.Unbounded.Append (B.Stream_Buf, Text);
      Insert_Plain (B, Text);
   end Append_Text;

   procedure End_Text_Block (B : in out Instance) is
      use Ada.Strings.Unbounded;
      use Gtk.Text_Iter;
      SI, EI : Gtk.Text_Iter.Gtk_Text_Iter;
      Markup : constant String :=
        (if B.Render_Markdown
         then To_Pango_Markup (To_String (B.Stream_Buf))
         else "");
   begin
      if not B.In_Text_Block then
         return;
      end if;

      B.The_Buf.Get_Iter_At_Mark (SI, B.Stream_Mark);
      B.The_Buf.Get_End_Iter (EI);
      B.The_Buf.Delete (SI, EI);

      B.The_Buf.Get_Iter_At_Mark (SI, B.Stream_Mark);
      if Markup'Length > 0 then
         B.The_Buf.Insert_Markup (SI, Markup, -1);
      else
         B.The_Buf.Get_Iter_At_Mark (SI, B.Stream_Mark);
         B.The_Buf.Insert (SI, To_String (B.Stream_Buf));
      end if;

      B.The_Buf.Get_End_Iter (EI);
      B.The_Buf.Insert (EI, "" & ASCII.LF);

      B.The_Buf.Delete_Mark (B.Stream_Mark);
      B.Stream_Mark    := null;
      B.Stream_Buf     := Null_Unbounded_String;
      B.In_Text_Block  := False;
   end End_Text_Block;

   --  ── Thinking blocks ───────────────────────────────────────────────────

   procedure Begin_Thinking (B : in out Instance) is
   begin
      --  Close any open streaming text block first, so its Stream_Mark
      --  cannot span the thinking-block insertion and be swept away later.
      End_Text_Block (B);
      if not B.In_Thinking then
         B.In_Thinking := True;
         Insert_Tagged (B, UC_BOX_V & " ", B.Tag_Thinking);
      end if;
   end Begin_Thinking;

   procedure Append_Thinking (B : in out Instance; Text : String) is
   begin
      Insert_Tagged (B, Text, B.Tag_Thinking);
   end Append_Thinking;

   procedure End_Thinking (B : in out Instance) is
   begin
      if B.In_Thinking then
         Insert_Tagged (B, "" & ASCII.LF, B.Tag_Thinking);
         B.In_Thinking := False;
      end if;
   end End_Thinking;

   --  ── Tool call segments ────────────────────────────────────────────────

   procedure Begin_Tool
     (B          : in out Instance;
      Name       :        String;
      Args       :        String;
      Session_Id :        String;
      Tool_Id    :        String)
   is
      pragma Unreferenced (Session_Id);
      use Ada.Strings.Unbounded;
      use type GNATCOLL.JSON.JSON_Value_Type;
      use Gtk.Box;
      use Gtk.Expander;
      use Gtk.Frame;
      use Gtk.Label;
      use Gtk.Text_Iter;
      use Gtk.Widget;

      Iter   : Gtk.Text_Iter.Gtk_Text_Iter;
      Anchor : Gtk.Text_Child_Anchor.Gtk_Text_Child_Anchor;

      Frame       : Gtk.Frame.Gtk_Frame;
      Outer_Vbox  : Gtk.Box.Gtk_Box;
      Summary_Lab : Gtk.Label.Gtk_Label;
      Expander    : Gtk.Expander.Gtk_Expander;
      Detail_Vbox : Gtk.Box.Gtk_Box;

      --  Parse the arguments JSON.
      Args_Parsed : constant GNATCOLL.JSON.Read_Result :=
        GNATCOLL.JSON.Read (Args);
      Args_Val    : constant GNATCOLL.JSON.JSON_Value  :=
        (if Args_Parsed.Success
         then Args_Parsed.Value
         else GNATCOLL.JSON.JSON_Null);

      --  Return the full display string for a JSON value.
      --  Strings are returned raw; all other types use JSON serialisation.
      function Format_Value_Full
        (Val : GNATCOLL.JSON.JSON_Value) return String
      is
      begin
         if Val.Kind = GNATCOLL.JSON.JSON_String_Type then
            return Val.Get;
         else
            return Val.Write;
         end if;
      end Format_Value_Full;
      Summary_Prefix_S : Unbounded_String;
      Summary_Full_S   : Unbounded_String;
   begin
      --  Close any open streaming text block before inserting the tool
      --  widget anchor.  The Stream_Mark must not span the child anchor,
      --  otherwise a later End_Text_Block will delete the tool frame.
      End_Text_Block (B);
      --  Build summary prefix: header line + per-field arg lines.
      Append (Summary_Prefix_S,
              UC_BOX_TL & " " & UC_GEAR & " " & Name);
      if Args_Val.Kind = GNATCOLL.JSON.JSON_Object_Type then
         declare
            procedure Add_Summary_Field
              (Field_Name  : GNATCOLL.JSON.UTF8_String;
               Field_Value : GNATCOLL.JSON.JSON_Value)
            is
            begin
               Append (Summary_Prefix_S,
                       ASCII.LF
                       & Format_Tool_Field
                           (Field_Name,
                            JSON_Scalar_Image (Field_Value),
                            Max_Len => 80));
            end Add_Summary_Field;
         begin
            Args_Val.Map_JSON_Object (Add_Summary_Field'Access);
         end;
      end if;
      --  Full pending summary = prefix + ellipsis footer.
      Summary_Full_S := Summary_Prefix_S;
      Append (Summary_Full_S, ASCII.LF & UC_BOX_BL & " " & UC_ELLIP);

      --  ── Build GTK widget tree ──────────────────────────────────────────
      Insert_Plain (B, "" & ASCII.LF);
      B.The_Buf.Get_End_Iter (Iter);
      Anchor := B.The_Buf.Create_Child_Anchor (Iter);

      Gtk.Frame.Gtk_New (Frame, UC_GEAR & " " & Name);
      Gtk.Box.Gtk_New_Vbox
        (Outer_Vbox, Homogeneous => False, Spacing => 2);

      --  Summary label: always visible, monospace, acme-style box drawing.
      Gtk.Label.Gtk_New (Summary_Lab);
      Summary_Lab.Set_Markup
        ("<tt><small>"
         & Xml_Escape (To_String (Summary_Full_S))
         & "</small></tt>");
      Summary_Lab.Set_Xalign (0.0);
      Summary_Lab.Set_Line_Wrap (False);

      --  Expander for the coyote-open-style detail view.
      --  GtkExpander manages its own toggle; no custom callbacks needed.
      Gtk.Expander.Gtk_New (Expander, "details");
      Gtk.Box.Gtk_New_Vbox
        (Detail_Vbox, Homogeneous => False, Spacing => 4);

      --  Populate Detail_Vbox: one labelled section per argument field.
      if Args_Val.Kind = GNATCOLL.JSON.JSON_Object_Type then
         declare
            procedure Add_Detail_Field
              (Field_Name  : GNATCOLL.JSON.UTF8_String;
               Field_Value : GNATCOLL.JSON.JSON_Value)
            is
               Section_Lab : Gtk.Label.Gtk_Label;
            begin
               Gtk.Label.Gtk_New (Section_Lab);
               Section_Lab.Set_Markup
                 ("<b><tt>"
                  & Xml_Escape
                      (UC_HORIZ & UC_HORIZ & " " & Field_Name
                       & " " & UC_HORIZ & UC_HORIZ)
                  & "</tt></b>" & ASCII.LF
                  & "<tt>"
                  & Xml_Escape (Format_Value_Full (Field_Value))
                  & "</tt>");
               Section_Lab.Set_Xalign (0.0);
               Section_Lab.Set_Line_Wrap (True);
               Section_Lab.Set_Max_Width_Chars (80);
               Detail_Vbox.Pack_Start
                 (Section_Lab,
                  Expand  => False,
                  Fill    => False,
                  Padding => 2);
            end Add_Detail_Field;
         begin
            Args_Val.Map_JSON_Object (Add_Detail_Field'Access);
         end;
      elsif Args_Val.Kind /= GNATCOLL.JSON.JSON_Null_Type then
         declare
            Raw_Lab : Gtk.Label.Gtk_Label;
         begin
            Gtk.Label.Gtk_New (Raw_Lab);
            Raw_Lab.Set_Markup
              ("<b><tt>"
               & Xml_Escape
                   (UC_HORIZ & UC_HORIZ & " arguments "
                    & UC_HORIZ & UC_HORIZ)
               & "</tt></b>" & ASCII.LF
               & "<tt>" & Xml_Escape (Args) & "</tt>");
            Raw_Lab.Set_Xalign (0.0);
            Raw_Lab.Set_Line_Wrap (True);
            Raw_Lab.Set_Max_Width_Chars (80);
            Detail_Vbox.Pack_Start
              (Raw_Lab,
               Expand  => False,
               Fill    => False,
               Padding => 2);
         end;
      end if;

      Expander.Add (Detail_Vbox);

      Outer_Vbox.Pack_Start
        (Summary_Lab,
         Expand  => False,
         Fill    => False,
         Padding => 2);
      Outer_Vbox.Pack_Start
        (Expander,
         Expand  => False,
         Fill    => False,
         Padding => 2);
      Frame.Add (Outer_Vbox);

      B.The_View.Add_Child_At_Anchor (Frame, Anchor);
      Frame.Show_All;

      B.Tools.Insert
        (Tool_Id,
         (Frame          => Frame,
          Summary_Label  => Summary_Lab,
          Summary_Prefix => Summary_Prefix_S,
          Detail_Box     => Detail_Vbox,
          Name           => To_Unbounded_String (Name)));

      Insert_Plain (B, "" & ASCII.LF);
   end Begin_Tool;

   procedure End_Tool
     (B       : in out Instance;
      Tool_Id :        String;
      Status  :        Tool_End_Status;
      Result  :        String)
   is
      use Ada.Strings.Unbounded;
      use Gtk.Label;
      use Gtk.Separator;
      use Tool_Maps;
      Pos : constant Cursor := B.Tools.Find (Tool_Id);
   begin
      if Pos = No_Element then
         return;
      end if;
      declare
         Info       : constant Tool_Frame_Info := Element (Pos);
         Tool_Name  : constant String          := To_String (Info.Name);
         New_Footer : Unbounded_String;
         Sep        : Gtk.Separator.Gtk_Separator;
         Result_Lab : Gtk.Label.Gtk_Label;
         Status_Str : constant String :=
           (case Status is
               when Success   => UC_CHECK & " ok",
               when Error     => UC_CROSS & " error",
               when Cancelled => "- cancelled");
      begin
         --  Update the frame title icon.
         case Status is
            when Success   =>
               Info.Frame.Set_Label (UC_CHECK & " " & Tool_Name);
            when Error     =>
               Info.Frame.Set_Label (UC_CROSS & " " & Tool_Name);
            when Cancelled =>
               Info.Frame.Set_Label ("- " & Tool_Name);
         end case;

         --  Rebuild the summary label with the resolved footer line.
         case Status is
            when Success =>
               Append (New_Footer, UC_BOX_BL & " " & UC_CHECK);
            when Error =>
               declare
                  Clip_End : constant Natural :=
                    (if Result'Length > 80
                     then Result'First + 79
                     else Result'Last);
               begin
                  Append
                    (New_Footer,
                     UC_BOX_BL & " " & UC_CROSS & " "
                     & Result (Result'First .. Clip_End));
               end;
            when Cancelled =>
               Append
                 (New_Footer, UC_BOX_BL & " " & UC_CROSS & " cancelled");
         end case;
         Info.Summary_Label.Set_Markup
           ("<tt><small>"
            & Xml_Escape
                (To_String (Info.Summary_Prefix)
                 & ASCII.LF & To_String (New_Footer))
            & "</small></tt>");

         --  Append separator + result section to Detail_Box.
         Gtk.Separator.Gtk_New_Hseparator (Sep);
         Info.Detail_Box.Pack_Start
           (Sep, Expand => False, Fill => False, Padding => 4);

         Gtk.Label.Gtk_New (Result_Lab);
         Result_Lab.Set_Markup
           ("<b><tt>"
            & Xml_Escape
                (UC_HORIZ & UC_HORIZ & " result "
                 & UC_HORIZ & UC_HORIZ & "  " & Status_Str)
            & "</tt></b>" & ASCII.LF
            & "<tt>"
            & Xml_Escape
                (if Result'Length > 0 then Result else "(no result)")
            & "</tt>");
         Result_Lab.Set_Xalign (0.0);
         Result_Lab.Set_Line_Wrap (True);
         Result_Lab.Set_Max_Width_Chars (80);
         Info.Detail_Box.Pack_Start
           (Result_Lab,
            Expand  => False,
            Fill    => False,
            Padding => 2);
         Info.Detail_Box.Show_All;
      end;
   end End_Tool;

   --  ── Notices and footers ───────────────────────────────────────────────

   procedure Append_Notice
     (B    : in out Instance;
      Kind :        Notice_Kind;
      Text : String)
   is
      Tag : Gtk.Text_Tag.Gtk_Text_Tag;
   begin
      case Kind is
         when Info    => Tag := B.Tag_Notice_Info;
         when Warning => Tag := B.Tag_Notice_Warn;
         when Error   => Tag := B.Tag_Notice_Error;
      end case;
      Insert_Tagged (B, Text & ASCII.LF, Tag);
   end Append_Notice;

   procedure Append_Turn_Footer (B : in out Instance; Text : String) is
   begin
      Insert_Tagged (B, Text & ASCII.LF, B.Tag_Footer);
   end Append_Turn_Footer;

   --  ── Scroll ───────────────────────────────────────────────────────────

   procedure Scroll_To_End (B : in out Instance) is
   begin
      B.The_View.Scroll_Mark_Onscreen (B.The_Buf.Get_Insert);
   end Scroll_To_End;

   procedure Set_Render_Markdown (B : in out Instance; Enabled : Boolean) is
   begin
      B.Render_Markdown := Enabled;
   end Set_Render_Markdown;

   function Get_Render_Markdown (B : Instance) return Boolean is
   begin
      return B.Render_Markdown;
   end Get_Render_Markdown;

end Coyote_GUI.Buffer;
