--  Coyote_GUI.Buffer body.
--
--  Project: coyote

with Ada.Strings.Unbounded;          use Ada.Strings.Unbounded;
with Ada.Strings.Fixed;
with Coyote_App.Utils;               use Coyote_App.Utils;
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

      Doc  : Node_Ptr;
      It   : Iter_Ptr;
      Ev   : Event_Type_Int;
      Node : Node_Ptr;
      Out_S : Unbounded_String;

      --  Ordered list counter stack (up to 8 levels)
      type Level_T is range 0 .. 7;
      List_Counter : array (Level_T) of Integer  := (others => 0);
      Is_Bullet    : array (Level_T) of Boolean  := (others => True);
      List_Depth   : Natural := 0;

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
            if TS = "table" or else TS = "table_row"
              or else TS = "table_cell"
            then
               if Ev = EVENT_EXIT and then TS = "table" then
                  Append (Out_S, "" & ASCII.LF);
               end if;

            elsif NT = NODE_DOCUMENT then
               null;

            elsif NT = NODE_PARAGRAPH then
               if Ev = EVENT_EXIT then
                  Append (Out_S, "" & ASCII.LF);
               end if;

            elsif NT = NODE_HEADING then
               if Ev = EVENT_ENTER then Append (Out_S, "<b>");
               else Append (Out_S, "</b>" & ASCII.LF);
               end if;

            elsif NT = NODE_STRONG then
               if Ev = EVENT_ENTER then Append (Out_S, "<b>");
               else Append (Out_S, "</b>");
               end if;

            elsif NT = NODE_EMPH then
               if Ev = EVENT_ENTER then Append (Out_S, "<i>");
               else Append (Out_S, "</i>");
               end if;

            elsif NT = NODE_LINK then
               if Ev = EVENT_ENTER then Append (Out_S, "<u>");
               else Append (Out_S, "</u>");
               end if;

            elsif NT = NODE_CODE then
               if Ev = EVENT_ENTER then
                  Append (Out_S, "<tt>");
                  Append (Out_S, Xml_Escape (Lit (Node)));
                  Append (Out_S, "</tt>");
               end if;

            elsif NT = NODE_CODE_BLOCK then
               if Ev = EVENT_ENTER then
                  Append (Out_S, "<tt>");
                  Append (Out_S, Xml_Escape (Lit (Node)));
                  Append (Out_S, "</tt>" & ASCII.LF);
               end if;

            elsif NT = NODE_BLOCK_QUOTE then
               if Ev = EVENT_ENTER then
                  Append (Out_S, "<i><span alpha=""50%%"">");
               else
                  Append (Out_S, "</span></i>" & ASCII.LF);
               end if;

            elsif NT = NODE_LIST then
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

            elsif NT = NODE_ITEM then
               if Ev = EVENT_ENTER and then List_Depth > 0 then
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
                  Append (Out_S, Xml_Escape (Lit (Node)));
               end if;

            elsif NT = NODE_SOFTBREAK then
               if Ev = EVENT_ENTER then Append (Out_S, " "); end if;

            elsif NT = NODE_LINEBREAK then
               if Ev = EVENT_ENTER then
                  Append (Out_S, "" & ASCII.LF);
               end if;

            elsif NT = NODE_THEMATIC_BREAK then
               if Ev = EVENT_ENTER then
                  Append (Out_S,
                    "<span alpha=""50%%"">"
                    & UC_HORIZ & UC_HORIZ & UC_HORIZ & UC_HORIZ
                    & UC_HORIZ & UC_HORIZ & UC_HORIZ & UC_HORIZ
                    & UC_HORIZ & UC_HORIZ & UC_HORIZ & UC_HORIZ
                    & "</span>" & ASCII.LF);
               end if;

            else
               if TS = "strikethrough" then
                  if Ev = EVENT_ENTER then Append (Out_S, "<s>");
                  else Append (Out_S, "</s>");
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
        To_Pango_Markup (To_String (B.Stream_Buf));
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
      use Gtk.Box;
      use Gtk.Frame;
      use Gtk.Label;
      use Gtk.Text_Iter;
      use Gtk.Widget;

      Iter   : Gtk.Text_Iter.Gtk_Text_Iter;
      Anchor : Gtk.Text_Child_Anchor.Gtk_Text_Child_Anchor;

      Frame    : Gtk.Frame.Gtk_Frame;
      Vbox     : Gtk.Box.Gtk_Box;
      Args_Lab : Gtk.Label.Gtk_Label;
      Stat_Lab : Gtk.Label.Gtk_Label;
   begin
      Insert_Plain (B, "" & ASCII.LF);

      B.The_Buf.Get_End_Iter (Iter);
      Anchor := B.The_Buf.Create_Child_Anchor (Iter);

      Gtk.Frame.Gtk_New (Frame, UC_GEAR & " " & Name);
      Gtk.Box.Gtk_New_Vbox (Vbox, Homogeneous => False, Spacing => 2);

      Gtk.Label.Gtk_New (Args_Lab);
      Args_Lab.Set_Markup
        ("<tt><small>" & Xml_Escape (Args) & "</small></tt>");
      Args_Lab.Set_Xalign (0.0);

      Gtk.Label.Gtk_New (Stat_Lab, "running...");
      Stat_Lab.Set_Xalign (1.0);

      Vbox.Pack_Start (Args_Lab, Expand => True,  Fill => True,
                       Padding => 2);
      Vbox.Pack_Start (Stat_Lab, Expand => False, Fill => False,
                       Padding => 2);
      Frame.Add (Vbox);

      B.The_View.Add_Child_At_Anchor (Frame, Anchor);
      Frame.Show_All;

      B.Tools.Insert (Tool_Id,
        (Frame        => Frame,
         Status_Label => Stat_Lab,
         Name         => To_Unbounded_String (Name)));

      Insert_Plain (B, "" & ASCII.LF);
   end Begin_Tool;

   procedure End_Tool
     (B       : in out Instance;
      Tool_Id :        String;
      Status  :        Tool_End_Status;
      Result  :        String)
   is
      pragma Unreferenced (Result);
      use Ada.Strings.Unbounded;
      use Tool_Maps;
      Pos : constant Cursor := B.Tools.Find (Tool_Id);
   begin
      if Pos = No_Element then
         return;
      end if;
      declare
         Info  : constant Tool_Frame_Info := Element (Pos);
         Label : constant String          := To_String (Info.Name);
      begin
         case Status is
            when Success =>
               Info.Frame.Set_Label (UC_CHECK & " " & Label);
               Info.Status_Label.Set_Text ("done");
            when Error =>
               Info.Frame.Set_Label (UC_CROSS & " " & Label);
               Info.Status_Label.Set_Text ("error");
            when Cancelled =>
               Info.Frame.Set_Label ("- " & Label);
               Info.Status_Label.Set_Text ("cancelled");
         end case;
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

end Coyote_GUI.Buffer;
