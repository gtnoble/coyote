--  Coyote_GUI.Buffer body.
--
--  Project: coyote

with Ada.Strings.Unbounded;          use Ada.Strings.Unbounded;
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
with Gtk.Enums;
with Gtk.Box;
with Gtk.Button;
with Gtk.Scrolled_Window;
with Gtk.Text_Child_Anchor;
with Gtk.Window;
with Gtk.Text_Tag;                   use Gtk.Text_Tag;
with Gtk.Widget;
with Pango.Font;

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

   --  ── Singleton access for button signal handlers ──────────────────────

   Current_Buffer : access Instance := null;

   --  ── Tag setup ─────────────────────────────────────────────────────────

   procedure Attach
     (B    : in out Instance;
      View : Gtk.Text_View.Gtk_Text_View;
      Buf  : Gtk.Text_Buffer.Gtk_Text_Buffer)
   is
   begin
      B.The_View := View;
      B.The_Buf  := Buf;
      Current_Buffer := B'Unchecked_Access;

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
      Iter : Gtk.Text_Iter.Gtk_Text_Iter;
      Mark : Gtk.Text_Mark.Gtk_Text_Mark;
      SI   : Gtk.Text_Iter.Gtk_Text_Iter;
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
      B.The_Buf.Insert (EI, "" & ASCII.LF & ASCII.LF);

      B.The_Buf.Delete_Mark (B.Stream_Mark);
      B.Stream_Mark    := null;
      B.Stream_Buf     := Null_Unbounded_String;
      B.In_Text_Block  := False;
   end End_Text_Block;

   --  ── Thinking blocks ───────────────────────────────────────────────────

   procedure Begin_Thinking (B : in out Instance) is
   begin
      End_Text_Block (B);
      if not B.In_Thinking then
         B.In_Thinking        := True;
         B.Prefix_Emitted     := False;
      end if;
   end Begin_Thinking;

   procedure Append_Thinking (B : in out Instance; Text : String) is
      use Coyote_App.Utils;
      Trimmed : constant String := Collapse_Thinking_Delta (Text);
   begin
      if Trimmed'Length = 0 then
         return;
      end if;

      if not B.Prefix_Emitted then
         Insert_Tagged (B, UC_BOX_V & " " & Trimmed, B.Tag_Thinking);
         B.Prefix_Emitted := True;
      else
         Insert_Tagged (B, Trimmed, B.Tag_Thinking);
      end if;
   end Append_Thinking;

   procedure End_Thinking (B : in out Instance) is
   begin
      if B.In_Thinking then
         if B.Prefix_Emitted then
            Insert_Tagged (B, "" & ASCII.LF & ASCII.LF, B.Tag_Thinking);
         end if;
         B.In_Thinking        := False;
         B.Prefix_Emitted     := False;
      end if;
   end End_Thinking;

   --  ── Tool call segments ────────────────────────────────────────────────

   --  ── Show_Tool_Detail ──────────────────────────────────────────────────
   --
   --  Open a non-modal window showing the tool arguments and result.

   procedure Show_Tool_Detail (Info : Tool_Frame_Info) is
      use Ada.Strings.Unbounded;
      use type GNATCOLL.JSON.JSON_Value_Type;
      use Gtk.Box;
      use Gtk.Enums;
      use Gtk.Frame;
      use Gtk.Label;
      use Gtk.Scrolled_Window;
      use Gtk.Text_Buffer;
      use Gtk.Text_View;
      use Gtk.Window;

      Tool_Name  : constant String := To_String (Info.Name);
      Args_Str   : constant String := To_String (Info.Args);
      Result_Str : constant String := To_String (Info.Result_Text);

      Status_Icon : constant String :=
        (case Info.Result_Status is
            when Success   => UC_CHECK,
            when Error     => UC_CROSS,
            when Cancelled => "-");

      Win   : Gtk_Window;
      Outer : Gtk_Box;

      --  Return the full display string for a JSON value.
      function Format_Value_Full
        (Val : GNATCOLL.JSON.JSON_Value) return String is
      begin
         if Val.Kind = GNATCOLL.JSON.JSON_String_Type then
            return Val.Get;
         else
            return Val.Write;
         end if;
      end Format_Value_Full;

   begin
      Gtk.Window.Gtk_New (Win, Window_Toplevel);
      Win.Set_Title (Status_Icon & " " & Tool_Name & " -- details");
      Win.Set_Default_Size (600, 500);

      Gtk.Box.Gtk_New_Vbox
        (Outer, Homogeneous => False, Spacing => 8);
      Outer.Set_Border_Width (8);
      Win.Add (Outer);

      --  ── Arguments section ──────────────────────────────────────────────
      declare
         Arg_Frame : Gtk_Frame;
         Args_Box  : Gtk_Box;
         Parsed    : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (Args_Str);
         Args_Val  : constant GNATCOLL.JSON.JSON_Value  :=
           (if Parsed.Success
            then Parsed.Value
            else GNATCOLL.JSON.JSON_Null);
      begin
         Gtk.Frame.Gtk_New (Arg_Frame, "Arguments");
         Gtk.Box.Gtk_New_Vbox
           (Args_Box, Homogeneous => False, Spacing => 4);
         Args_Box.Set_Border_Width (4);

         if Args_Val.Kind = GNATCOLL.JSON.JSON_Object_Type then
            declare
               procedure Add_Field
                 (Field_Name  : GNATCOLL.JSON.UTF8_String;
                  Field_Value : GNATCOLL.JSON.JSON_Value)
               is
                  Hdr    : Gtk_Label;
                  Scroll : Gtk_Scrolled_Window;
                  TV     : Gtk_Text_View;
                  Buf    : Gtk_Text_Buffer;
                  Iter   : Gtk.Text_Iter.Gtk_Text_Iter;
               begin
                  Gtk.Label.Gtk_New (Hdr);
                  Hdr.Set_Markup ("<b>" & Field_Name & "</b>");
                  Hdr.Set_Xalign (0.0);
                  Args_Box.Pack_Start (Hdr, False, False, 2);

                  Gtk.Text_Buffer.Gtk_New (Buf);
                  Gtk.Text_View.Gtk_New (TV, Buf);
                  TV.Set_Editable (False);
                  TV.Set_Wrap_Mode (Wrap_Word_Char);
                  declare
                     use Pango.Font;
                     Fd : Pango_Font_Description :=
                       From_String ("Monospace");
                  begin
                     TV.Modify_Font (Fd);
                     Free (Fd);
                  end;
                  Buf.Get_End_Iter (Iter);
                  Buf.Insert (Iter,
                              Format_Value_Full (Field_Value));
                  Gtk.Scrolled_Window.Gtk_New (Scroll);
                  Scroll.Set_Policy
                    (Policy_Never, Policy_Automatic);
                  Scroll.Set_Size_Request (-1, 100);
                  Scroll.Add (TV);
                  Args_Box.Pack_Start
                    (Scroll, False, False, 2);
               end Add_Field;
            begin
               Args_Val.Map_JSON_Object (Add_Field'Access);
            end;
         elsif Args_Val.Kind /= GNATCOLL.JSON.JSON_Null_Type then
            declare
               Scroll : Gtk_Scrolled_Window;
               TV     : Gtk_Text_View;
               Buf    : Gtk_Text_Buffer;
               Iter   : Gtk.Text_Iter.Gtk_Text_Iter;
            begin
               Gtk.Text_Buffer.Gtk_New (Buf);
               Gtk.Text_View.Gtk_New (TV, Buf);
               TV.Set_Editable (False);
               TV.Set_Wrap_Mode (Wrap_Word_Char);
               declare
                  use Pango.Font;
                  Fd : Pango_Font_Description :=
                    From_String ("Monospace");
               begin
                  TV.Modify_Font (Fd);
                  Free (Fd);
               end;
               Buf.Get_End_Iter (Iter);
               Buf.Insert (Iter, Args_Str);
               Gtk.Scrolled_Window.Gtk_New (Scroll);
               Scroll.Set_Policy
                 (Policy_Automatic, Policy_Automatic);
               Scroll.Add (TV);
               Args_Box.Pack_Start
                 (Scroll, True, True, 0);
            end;
         end if;

         Arg_Frame.Add (Args_Box);
         Outer.Pack_Start (Arg_Frame, False, False, 0);
      end;

      --  ── Result section ─────────────────────────────────────────────────
      declare
         Res_Frame  : Gtk_Frame;
         Result_Box : Gtk_Box;
         Status_Lab : Gtk_Label;
         Scroll     : Gtk_Scrolled_Window;
         TV         : Gtk_Text_View;
         Buf        : Gtk_Text_Buffer;
         Iter       : Gtk.Text_Iter.Gtk_Text_Iter;
         Status_Str : constant String :=
           (case Info.Result_Status is
               when Success   => UC_CHECK & " ok",
               when Error     => UC_CROSS & " error",
               when Cancelled => "- cancelled");
      begin
         Gtk.Frame.Gtk_New (Res_Frame, "Result");
         Gtk.Box.Gtk_New_Vbox
           (Result_Box, Homogeneous => False, Spacing => 4);
         Result_Box.Set_Border_Width (4);

         Gtk.Label.Gtk_New (Status_Lab, Status_Str);
         Status_Lab.Set_Xalign (0.0);
         Result_Box.Pack_Start
           (Status_Lab, False, False, 2);

         Gtk.Text_Buffer.Gtk_New (Buf);
         Gtk.Text_View.Gtk_New (TV, Buf);
         TV.Set_Editable (False);
         TV.Set_Wrap_Mode (Wrap_Word_Char);
         declare
            use Pango.Font;
            Fd : Pango_Font_Description :=
              From_String ("Monospace");
         begin
            TV.Modify_Font (Fd);
            Free (Fd);
         end;
         Buf.Get_End_Iter (Iter);
         if Result_Str'Length > 0 then
            Buf.Insert (Iter, Result_Str);
         else
            Buf.Insert (Iter, "(no result)");
         end if;
         Gtk.Scrolled_Window.Gtk_New (Scroll);
         Scroll.Set_Policy (Policy_Automatic, Policy_Automatic);
         Scroll.Add (TV);
         Result_Box.Pack_Start (Scroll, True, True, 0);

         Res_Frame.Add (Result_Box);
         Outer.Pack_Start (Res_Frame, True, True, 0);
      end;

      Win.Show_All;
   end Show_Tool_Detail;

   --  ── On_Tool_Detail_Clicked ───────────────────────────────────────────
   --
   --  Signal handler for tool-call detail buttons.  The button's widget
   --  name was set to the Tool_Id in Begin_Tool; we look it up in the
   --  Tools map to retrieve the stored arguments and result.

   procedure On_Tool_Detail_Clicked
     (Self : access Gtk.Button.Gtk_Button_Record'Class)
   is
      use Tool_Maps;
   begin
      if Current_Buffer = null then
         return;
      end if;
      declare
         Tool_Id : constant String :=
           Gtk.Widget.Get_Name (Gtk.Widget.Gtk_Widget (Self));
         Pos    : constant Cursor := Current_Buffer.Tools.Find (Tool_Id);
      begin
         if Pos /= No_Element then
            Show_Tool_Detail (Element (Pos));
         end if;
      end;
   end On_Tool_Detail_Clicked;

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
      use Gtk.Button;
      use Gtk.Frame;
      use Gtk.Label;
      use Gtk.Text_Iter;
      use Gtk.Widget;

      Iter   : Gtk.Text_Iter.Gtk_Text_Iter;
      Anchor : Gtk.Text_Child_Anchor.Gtk_Text_Child_Anchor;

      Frame       : Gtk.Frame.Gtk_Frame;
      Outer_Vbox  : Gtk.Box.Gtk_Box;
      Summary_Lab : Gtk.Label.Gtk_Label;
      Detail_Btn  : Gtk.Button.Gtk_Button;

      --  Parse the arguments JSON.
      Args_Parsed : constant GNATCOLL.JSON.Read_Result :=
        GNATCOLL.JSON.Read (Args);
      Args_Val    : constant GNATCOLL.JSON.JSON_Value  :=
        (if Args_Parsed.Success
         then Args_Parsed.Value
         else GNATCOLL.JSON.JSON_Null);

      Summary_Prefix_S : Unbounded_String;
      Summary_Full_S   : Unbounded_String;
      Frame_Label      : Unbounded_String;
   begin
      if B.Tools.Contains (Tool_Id) then
         return;
      end if;
      End_Text_Block (B);
      Insert_Plain (B, "" & ASCII.LF & ASCII.LF);

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
      Summary_Full_S := Summary_Prefix_S;
      Append (Summary_Full_S,
              ASCII.LF & "  <span foreground=""#888888"">"
              & Xml_Escape (UC_ELLIP) & " running...</span>");
      Frame_Label := To_Unbounded_String (UC_GEAR & " " & Name);

      B.The_Buf.Get_End_Iter (Iter);
      Anchor := B.The_Buf.Create_Child_Anchor (Iter);

      Gtk.Frame.Gtk_New (Frame, To_String (Frame_Label));
      Frame.Set_Size_Request (700, -1);
      Frame.Set_Border_Width (6);
      Frame.Set_Shadow_Type (Gtk.Enums.Shadow_Etched_In);
      Gtk.Box.Gtk_New_Vbox
        (Outer_Vbox, Homogeneous => False, Spacing => 6);

      Gtk.Label.Gtk_New (Summary_Lab);
      Summary_Lab.Set_Markup
        ("<small>" & To_String (Summary_Full_S) & "</small>");
      Summary_Lab.Set_Xalign (0.0);
      Summary_Lab.Set_Line_Wrap (True);
      Summary_Lab.Set_Max_Width_Chars (100);
      Summary_Lab.Set_Selectable (True);

      --  Details button: store Tool_Id as the widget name for later lookup.
      Gtk.Button.Gtk_New (Detail_Btn, "details...");
      Gtk.Widget.Set_Name
        (Gtk.Widget.Gtk_Widget (Detail_Btn), Tool_Id);
      Detail_Btn.On_Clicked (On_Tool_Detail_Clicked'Access);

      Outer_Vbox.Pack_Start
        (Summary_Lab,
         Expand  => False,
         Fill    => False,
         Padding => 6);
      Outer_Vbox.Pack_Start
        (Detail_Btn,
         Expand  => False,
         Fill    => False,
         Padding => 6);
      Frame.Add (Outer_Vbox);

      B.The_View.Add_Child_At_Anchor (Frame, Anchor);
      Frame.Show_All;

      B.Tools.Insert
        (Tool_Id,
         (Frame          => Frame,
          Summary_Label  => Summary_Lab,
          Summary_Prefix => Summary_Prefix_S,
          Detail_Button  => Detail_Btn,
          Name           => To_Unbounded_String (Name),
          Args           => To_Unbounded_String (Args),
          Result_Text    => Null_Unbounded_String,
          Result_Status  => Success));

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
      use Tool_Maps;
      Pos : constant Cursor := B.Tools.Find (Tool_Id);
   begin
      if Pos = No_Element then
         return;
      end if;
      declare
         Info       : Tool_Frame_Info := Element (Pos);
         Tool_Name  : constant String := To_String (Info.Name);
         New_Footer : Unbounded_String;
      begin
         Info.Result_Text   := To_Unbounded_String (Result);
         Info.Result_Status := Status;
         B.Tools.Replace (Tool_Id, Info);

         case Status is
            when Success   =>
               Info.Frame.Set_Label (UC_CHECK & " " & Tool_Name);
            when Error     =>
               Info.Frame.Set_Label (UC_CROSS & " " & Tool_Name);
            when Cancelled =>
               Info.Frame.Set_Label ("- " & Tool_Name);
         end case;

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
      Insert_Tagged (B, ASCII.LF & Text & ASCII.LF, Tag);
   end Append_Notice;

   procedure Append_Turn_Footer (B : in out Instance; Text : String) is
      pragma Unreferenced (Text);
   begin
      Insert_Tagged
        (B,
         "" & ASCII.LF
         & Str_Repeat (UC_HORIZ, 60)
         & ASCII.LF & ASCII.LF,
         B.Tag_Footer);
   end Append_Turn_Footer;

   --  ── Scroll ───────────────────────────────────────────────────────────

   procedure Scroll_To_End (B : in out Instance) is
   begin
      B.The_View.Scroll_Mark_Onscreen (B.The_Buf.Get_Insert);
   end Scroll_To_End;

   --  ── Markdown rendering toggle ─────────────────────────────────────────

   procedure Set_Render_Markdown (B : in out Instance; Enabled : Boolean) is
   begin
      B.Render_Markdown := Enabled;
   end Set_Render_Markdown;

   function Get_Render_Markdown (B : Instance) return Boolean is
   begin
      return B.Render_Markdown;
   end Get_Render_Markdown;

end Coyote_GUI.Buffer;
