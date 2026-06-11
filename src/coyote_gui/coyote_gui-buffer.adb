--  Coyote_GUI.Buffer body.
--
--  Project: coyote

with Ada.Strings.Unbounded;          use Ada.Strings.Unbounded;
with Ada.Strings.Fixed;
with Coyote_Renderer.Markup;
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
   begin
      return Coyote_Renderer.Markup.Xml_Escape (S);
   end Xml_Escape;


   function To_Pango_Markup (MD_Text : String) return String is
   begin
      return Coyote_Renderer.Markup.To_Pango_Markup (MD_Text);
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
      Set_Property (B.Tag_Thinking, Background_Property, "#fffce8");

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
         B.Thinking_Buffer := Null_Unbounded_String;
         B.In_Thinking := True;
      end if;
   end Begin_Thinking;

   procedure Append_Thinking (B : in out Instance; Text : String) is
   begin
      --  Accumulate chunks; output is deferred until End_Thinking.
      Append (B.Thinking_Buffer, Text);
   end Append_Thinking;

   procedure End_Thinking (B : in out Instance) is
      use Coyote_App.Utils;
      Collapsed : constant String :=
        Collapse_Thinking_Delta (To_String (B.Thinking_Buffer));
   begin
      if B.In_Thinking then
         if Collapsed'Length > 0 then
            Insert_Tagged (B, UC_BOX_V & " " & Collapsed, B.Tag_Thinking);
            Insert_Tagged (B, "" & ASCII.LF, B.Tag_Thinking);
         end if;
         B.In_Thinking := False;
         B.Thinking_Buffer := Null_Unbounded_String;
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
      Frame_Label      : Unbounded_String;
   begin
      --  Guard: ignore duplicate tool IDs (e.g. from history replay).
      if B.Tools.Contains (Tool_Id) then
         return;
      end if;
      --  Close any open streaming text block before inserting the tool
      --  widget anchor.  The Stream_Mark must not span the child anchor,
      --  otherwise a later End_Text_Block will delete the tool frame.
      End_Text_Block (B);
      Insert_Plain (B, "" & ASCII.LF);
      --  Build summary prefix: header line + per-field arg lines.
      Append (Summary_Prefix_S,
              "<b>" & Xml_Escape (UC_GEAR & " " & Name) & "</b>");
      if Args_Val.Kind = GNATCOLL.JSON.JSON_Object_Type then
         declare
            procedure Add_Summary_Field
              (Field_Name  : GNATCOLL.JSON.UTF8_String;
               Field_Value : GNATCOLL.JSON.JSON_Value)
            is
            begin
               Append (Summary_Prefix_S,
                       ASCII.LF & "  <tt>"
                       & Xml_Escape
                           (Format_Tool_Field
                              (Field_Name,
                               JSON_Scalar_Image (Field_Value),
                               Max_Len => 80))
                       & "</tt>");
            end Add_Summary_Field;
         begin
            Args_Val.Map_JSON_Object (Add_Summary_Field'Access);
         end;
      end if;
      --  Full pending summary = prefix + ellipsis footer.
      Summary_Full_S := Summary_Prefix_S;
      Append (Summary_Full_S,
              ASCII.LF & "  <span foreground=""#888888"">"
              & Xml_Escape (UC_ELLIP) & " running...</span>");
      Frame_Label := To_Unbounded_String (UC_GEAR & " " & Name);

      --  ── Build GTK widget tree ──────────────────────────────────────────
      B.The_Buf.Get_End_Iter (Iter);
      Anchor := B.The_Buf.Create_Child_Anchor (Iter);

      Gtk.Frame.Gtk_New (Frame, To_String (Frame_Label));
      Frame.Set_Size_Request (700, -1);
      Gtk.Box.Gtk_New_Vbox
        (Outer_Vbox, Homogeneous => False, Spacing => 2);

      --  Summary label: always visible, Pango markup.
      Gtk.Label.Gtk_New (Summary_Lab);
      Summary_Lab.Set_Markup
        ("<small>" & To_String (Summary_Full_S) & "</small>");
      Summary_Lab.Set_Xalign (0.0);
      Summary_Lab.Set_Line_Wrap (True);
      Summary_Lab.Set_Max_Width_Chars (100);
      Summary_Lab.Set_Selectable (True);

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
               Section_Lab.Set_Selectable (True);
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
            Raw_Lab.Set_Selectable (True);
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
          Expander       => Expander,
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
               Append (New_Footer,
                       ASCII.LF
                       & "  <span foreground=""#4a7c59""><b>"
                       & Xml_Escape (UC_CHECK & " done")
                       & "</b></span>");
            when Error =>
               declare
                  Clip_End : constant Natural :=
                    (if Result'Length > 80
                     then Result'First + 79
                     else Result'Last);
               begin
                  Append
                    (New_Footer,
                     ASCII.LF
                     & "  <span foreground=""#cc3333""><b>"
                     & Xml_Escape
                         (UC_CROSS & " "
                          & Result (Result'First .. Clip_End))
                     & "</b></span>");
               end;
            when Cancelled =>
               Append
                 (New_Footer,
                  ASCII.LF
                  & "  <span foreground=""#888888"">- cancelled</span>");
         end case;
         Info.Summary_Label.Set_Markup
           ("<small>"
            & To_String (Info.Summary_Prefix)
            & To_String (New_Footer)
            & "</small>");
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
         Result_Lab.Set_Selectable (True);
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

   procedure Collapse_All_Tools (B : in out Instance) is
      use Tool_Maps;
      use Gtk.Expander;
   begin
      for Pos in B.Tools.Iterate loop
         declare
            Info : constant Tool_Frame_Info := Element (Pos);
         begin
            if Info.Expander /= null then
               Info.Expander.Set_Expanded (False);
            end if;
         end;
      end loop;
   end Collapse_All_Tools;

   procedure Expand_All_Tools (B : in out Instance) is
      use Tool_Maps;
      use Gtk.Expander;
   begin
      for Pos in B.Tools.Iterate loop
         declare
            Info : constant Tool_Frame_Info := Element (Pos);
         begin
            if Info.Expander /= null then
               Info.Expander.Set_Expanded (True);
            end if;
         end;
      end loop;
   end Expand_All_Tools;

   procedure Set_Render_Markdown (B : in out Instance; Enabled : Boolean) is
   begin
      B.Render_Markdown := Enabled;
   end Set_Render_Markdown;

   function Get_Render_Markdown (B : Instance) return Boolean is
   begin
      return B.Render_Markdown;
   end Get_Render_Markdown;

end Coyote_GUI.Buffer;
