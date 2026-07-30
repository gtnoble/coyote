--  Coyote_GUI.Buffer body.
--
--  Project: coyote

with Ada.Strings.Unbounded;          use Ada.Strings.Unbounded;
with Coyote_Renderer.Markup;
with Coyote_App.Utils;               use Coyote_App.Utils;
with GNATCOLL.JSON;
with Glib;                           use Glib;
with Glib.Properties;                use Glib.Properties;
with Gtk.Text_Buffer;
with Gtk.Text_Iter;
with Gtk.Text_Mark;
with Gtk.Text_View;
with Gtk.Enums;
with Gtk.Text_Tag;                   use Gtk.Text_Tag;
with Pango.Enums;                    use Pango.Enums;

package body Coyote_GUI.Buffer is

   --  ── Pango markup helper ───────────────────────────────────────────────

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
      Set_Property (B.Tag_Thinking, Foreground_Property, "#000000");
      Set_Property (B.Tag_Thinking, Left_Margin_Property, Gint (24));
      Set_Property (B.Tag_Thinking, Background_Property, "#fffce8");

      B.Tag_Notice_Info := Buf.Create_Tag ("notice_info");
      Set_Property (B.Tag_Notice_Info, Foreground_Property, "#000000");
      Set_Property (B.Tag_Notice_Info, Background_Property, "#e8f0ff");

      B.Tag_Notice_Warn := Buf.Create_Tag ("notice_warn");
      Set_Property (B.Tag_Notice_Warn, Foreground_Property, "#cc8800");

      B.Tag_Notice_Error := Buf.Create_Tag ("notice_error");
      Set_Property (B.Tag_Notice_Error, Foreground_Property, "#cc3333");

      B.Tag_Footer := Buf.Create_Tag ("footer");
      Set_Property (B.Tag_Footer, Foreground_Property, "#888888");

      B.Tag_Action := Buf.Create_Tag ("action");
      Set_Property (B.Tag_Action, Foreground_Property, "#2266aa");
      Set_Property (B.Tag_Action, Underline_Property,
                    Pango.Enums.Pango_Underline_Single);
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
   --
   --  Tool calls are rendered as box-drawing text blocks:
   --
   --    ┌ ⚙ shell
   --    │ command  ls -la
   --    │ cwd      /home/gtnoble
   --    └ … running…
   --
   --  On completion the footer line is replaced in-place:
   --
   --    └ ✓ done
   --    └ ✗ error message (truncated)
   --    └ - cancelled
   --
   --  The entire block is tagged with a per-tool GtkTextTag.  Clicking
   --  anywhere in the block opens a detail window.

   --  ── Format_Tool_Detail ────────────────────────────────────────────────
   --
   --  Build the title and content strings for a tool detail window.

   procedure Format_Tool_Detail
     (Info    : in     Tool_Info;
      Title   :    out Unbounded_String;
      Content :    out Unbounded_String)
   is
      use type GNATCOLL.JSON.JSON_Value_Type;

      Tool_Name  : constant String := To_String (Info.Name);
      Args_Str   : constant String := To_String (Info.Args);
      Result_Str : constant String := To_String (Info.Result_Text);

      Status_Icon : constant String :=
        (case Info.Result_Status is
            when Success   => UC_CHECK,
            when Error     => UC_CROSS,
            when Cancelled => "-");

      Parsed   : constant GNATCOLL.JSON.Read_Result :=
        GNATCOLL.JSON.Read (Args_Str);
      Args_Val : constant GNATCOLL.JSON.JSON_Value  :=
        (if Parsed.Success
         then Parsed.Value
         else GNATCOLL.JSON.JSON_Null);

      function Format_Value (Val : GNATCOLL.JSON.JSON_Value) return String is
      begin
         if Val.Kind = GNATCOLL.JSON.JSON_String_Type then
            return Val.Get;
         else
            return Val.Write;
         end if;
      end Format_Value;

      SEP : constant String := Str_Repeat (UC_DBL_H, 60);
   begin
      Title := To_Unbounded_String
        (Status_Icon & " " & Tool_Name & " -- details");

      --  Header.
      Append (Content,
              UC_GEAR & " " & Tool_Name & "  "
              & (case Info.Result_Status is
                    when Success   => UC_CHECK & " ok",
                    when Error     => UC_CROSS & " error",
                    when Cancelled => "- cancelled")
              & ASCII.LF);
      Append (Content, SEP & ASCII.LF);

      --  Arguments.
      if Args_Val.Kind = GNATCOLL.JSON.JSON_Object_Type then
         declare
            procedure Append_Arg
              (Field_Name  : GNATCOLL.JSON.UTF8_String;
               Field_Value : GNATCOLL.JSON.JSON_Value)
            is
            begin
               Append (Content,
                       ASCII.LF
                       & UC_HORIZ & UC_HORIZ & " " & Field_Name
                       & " " & UC_HORIZ & UC_HORIZ
                       & ASCII.LF
                       & Format_Value (Field_Value)
                       & ASCII.LF);
            end Append_Arg;
         begin
            Args_Val.Map_JSON_Object (Append_Arg'Access);
         end;
      elsif Args_Val.Kind /= GNATCOLL.JSON.JSON_Null_Type then
         Append (Content,
                 ASCII.LF
                 & UC_HORIZ & UC_HORIZ & " arguments "
                 & UC_HORIZ & UC_HORIZ
                 & ASCII.LF
                 & Format_Value (Args_Val)
                 & ASCII.LF);
      end if;

      --  Result.
      Append (Content,
              ASCII.LF
              & UC_HORIZ & UC_HORIZ & " result " & UC_HORIZ & UC_HORIZ
              & ASCII.LF
              & (if Result_Str'Length > 0
                 then Result_Str
                 else "(no result)")
              & ASCII.LF);
   end Format_Tool_Detail;

   --  ── Begin_Tool ───────────────────────────────────────────────────────

   procedure Begin_Tool
     (B          : in out Instance;
      Name       :        String;
      Args       :        String;
      Session_Id :        String;
      Tool_Id    :        String)
   is
      pragma Unreferenced (Session_Id);
      use type GNATCOLL.JSON.JSON_Value_Type;
      use Gtk.Text_Iter;

      Tag_Name : constant String := "tool_" & Tool_Id;
      Tag      : Gtk.Text_Tag.Gtk_Text_Tag;
      SI, EI   : Gtk.Text_Iter.Gtk_Text_Iter;
      Mark     : Gtk.Text_Mark.Gtk_Text_Mark;

      Args_Parsed : constant GNATCOLL.JSON.Read_Result :=
        GNATCOLL.JSON.Read (Args);
      Args_Val    : constant GNATCOLL.JSON.JSON_Value  :=
        (if Args_Parsed.Success
         then Args_Parsed.Value
         else GNATCOLL.JSON.JSON_Null);

      Block_Text : Unbounded_String;
   begin
      if B.Tools.Contains (Tool_Id) then
         return;
      end if;
      End_Text_Block (B);
      Insert_Plain (B, "" & ASCII.LF & ASCII.LF);

      --  Build the box-drawing text block.
      --  Header line.
      Append (Block_Text, UC_BOX_TL & " " & UC_GEAR & " " & Name);

      --  Argument lines.
      if Args_Val.Kind = GNATCOLL.JSON.JSON_Object_Type then
         declare
            procedure Add_Arg_Line
              (Field_Name  : GNATCOLL.JSON.UTF8_String;
               Field_Value : GNATCOLL.JSON.JSON_Value)
            is
            begin
               Append (Block_Text,
                       ASCII.LF & UC_BOX_V & " "
                       & Format_Tool_Field
                           (Field_Name,
                            JSON_Scalar_Image (Field_Value),
                            Max_Len => 80));
            end Add_Arg_Line;
         begin
            Args_Val.Map_JSON_Object (Add_Arg_Line'Access);
         end;
      end if;

      --  Footer placeholder (replaced by End_Tool).
      Append (Block_Text,
              ASCII.LF & UC_BOX_BL & " " & UC_ELLIP & " running"
              & UC_ELLIP);

      --  Insert the block and record its start position.
      B.The_Buf.Get_End_Iter (SI);
      Mark := B.The_Buf.Create_Mark ("", SI, Left_Gravity => True);
      Insert_Plain (B, To_String (Block_Text));
      Insert_Plain (B, "" & ASCII.LF);

      --  Create a tag for the entire block and apply it.
      Tag := B.The_Buf.Create_Tag (Tag_Name);
      B.The_Buf.Get_Iter_At_Mark (SI, Mark);
      B.The_Buf.Get_End_Iter (EI);
      --  Back up one character to exclude the trailing LF we added.
      declare
         Dummy_BC : Boolean;
      begin
         Gtk.Text_Iter.Backward_Char (EI, Dummy_BC);
      end;
      B.The_Buf.Apply_Tag (Tag, SI, EI);

      --  Store tool info.
      B.Tools.Insert
        (Tool_Id,
         (Name          => To_Unbounded_String (Name),
          Args          => To_Unbounded_String (Args),
          Result_Text   => Null_Unbounded_String,
          Result_Status => Success,
          Tag           => Tag,
          Start_Mark    => Mark));
   end Begin_Tool;

   --  ── End_Tool ──────────────────────────────────────────────────────────

   procedure End_Tool
     (B       : in out Instance;
      Tool_Id :        String;
      Status  :        Tool_End_Status;
      Result  :        String)
   is
      use Gtk.Text_Iter;
      use Tool_Maps;
      Pos : constant Cursor := B.Tools.Find (Tool_Id);
   begin
      if Pos = No_Element then
         return;
      end if;
      declare
         Info : Tool_Info := Element (Pos);
         SI   : Gtk.Text_Iter.Gtk_Text_Iter;
         EI   : Gtk.Text_Iter.Gtk_Text_Iter;
         Replacement : Unbounded_String;
      begin
         Info.Result_Text   := To_Unbounded_String (Result);
         Info.Result_Status := Status;
         B.Tools.Replace (Tool_Id, Info);

         --  Build the replacement footer line.
         case Status is
            when Success =>
               Replacement := To_Unbounded_String
                 (UC_BOX_BL & " " & UC_CHECK & " done");
            when Error =>
               declare
                  Preview : constant Natural :=
                    (if Result'Length > 80
                     then Result'First + 79
                     else Result'Last);
               begin
                  Replacement := To_Unbounded_String
                    (UC_BOX_BL & " " & UC_CROSS & " "
                     & Result (Result'First .. Preview));
               end;
            when Cancelled =>
               Replacement := To_Unbounded_String
                 (UC_BOX_BL & " - cancelled");
         end case;

         --  Find the placeholder footer line (the last line of the block,
         --  which starts with UC_BOX_BL) and replace it.
         B.The_Buf.Get_Iter_At_Mark (SI, Info.Start_Mark);
         --  Advance to the footer line: search forward for UC_BOX_BL.
         loop
            exit when Gtk.Text_Iter.Get_Char (SI) = Glib.Gunichar (16#2514#);
            declare
               Dummy_FC : Boolean;
            begin
               Gtk.Text_Iter.Forward_Char (SI, Dummy_FC);
            end;
            exit when Gtk.Text_Iter.Is_End (SI);
         end loop;
         if not Gtk.Text_Iter.Is_End (SI) then
            --  SI is at the start of the footer line.  Find end of line.
            EI := SI;
            loop
               exit when Gtk.Text_Iter.Is_End (EI);
               exit when Gtk.Text_Iter.Get_Char (EI)
                 = Character'Pos (ASCII.LF);
               declare
                  Dummy_FC2 : Boolean;
               begin
                  Gtk.Text_Iter.Forward_Char (EI, Dummy_FC2);
               end;
            end loop;
            --  Delete the old footer and insert the replacement.
            B.The_Buf.Delete (SI, EI);
            B.The_Buf.Insert (SI, To_String (Replacement));
         end if;
      end;
   end End_Tool;

   --  ── Handle_Tool_Click ─────────────────────────────────────────────────

   function Handle_Tool_Click
     (B : in out Instance;
      X :        Glib.Gint;
      Y :        Glib.Gint) return Tool_Click_Result
   is
      use Gtk.Text_Iter;
      use Tool_Maps;
      use type Gtk.Text_Tag.Text_Tag_List.GSlist;

      Iter    : aliased Gtk.Text_Iter.Gtk_Text_Iter;
      Buf_X   : Glib.Gint;
      Buf_Y   : Glib.Gint;
      Tags    : Gtk.Text_Tag.Text_Tag_List.GSlist;
      Tmp     : Gtk.Text_Tag.Text_Tag_List.GSlist;
      Dummy   : Boolean;
   begin
      --  Convert widget coordinates to buffer coordinates and get the iter.
      B.The_View.Window_To_Buffer_Coords
        (Gtk.Enums.Text_Window_Widget, X, Y, Buf_X, Buf_Y);
      Dummy := Gtk.Text_View.Get_Iter_At_Location
        (B.The_View, Iter'Access, Buf_X, Buf_Y);

      --  Check all tags at this position for a tool tag.
      Tags := Gtk.Text_Iter.Get_Tags (Iter);
      Tmp := Tags;
      while Tmp /= Gtk.Text_Tag.Text_Tag_List.Null_List loop
         declare
            Tag      : constant Gtk.Text_Tag.Gtk_Text_Tag :=
              Gtk.Text_Tag.Text_Tag_List.Get_Data (Tmp);
            Tag_Name : constant String :=
              Glib.Properties.Get_Property (Tag, Name_Property);
         begin
            if Tag_Name'Length > 5
              and then Tag_Name (Tag_Name'First .. Tag_Name'First + 4)
                       = "tool_"
            then
               declare
                  Tool_Id : constant String :=
                    Tag_Name (Tag_Name'First + 5 .. Tag_Name'Last);
                  Pos : constant Cursor := B.Tools.Find (Tool_Id);
               begin
                  if Pos /= No_Element then
                     Gtk.Text_Tag.Text_Tag_List.Free (Tags);
                     declare
                        Result : Tool_Click_Result (Found => True);
                     begin
                        Format_Tool_Detail
                          (Element (Pos), Result.Title, Result.Content);
                        return Result;
                     end;
                  end if;
               end;
               exit;
            end if;
         end;
         Tmp := Gtk.Text_Tag.Text_Tag_List.Next (Tmp);
      end loop;
      Gtk.Text_Tag.Text_Tag_List.Free (Tags);

      return (Found => False);
   end Handle_Tool_Click;

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

   --  ── Action strips ──────────────────────────────────────────────────

   procedure Append_Action_Strip
     (B      : in out Instance;
      Label  :        String;
      Action :        Action_Info)
   is
      Tag_Name : constant String := "action_" & Natural_Image (B.Action_Seq);
   begin
      B.Action_Seq := B.Action_Seq + 1;

      --  Store action info in the map keyed by tag name.
      B.Actions.Include (Tag_Name, Action);

      --  Create a tag for the click target and apply it.
      declare
         Tag : constant Gtk.Text_Tag.Gtk_Text_Tag :=
           B.The_Buf.Create_Tag (Tag_Name);
      begin
         --  Inherit action appearance from the base Tag_Action.
         Set_Property (Tag, Foreground_Property, "#2266aa");
         Set_Property (Tag, Underline_Property,
                       Pango.Enums.Pango_Underline_Single);
         Insert_Tagged (B, Label, Tag);
      end;
   end Append_Action_Strip;

   function Handle_Action_Click
     (B : in out Instance;
      X :        Glib.Gint;
      Y :        Glib.Gint) return Action_Click_Result
   is
      use Gtk.Text_Iter;
      use type Gtk.Text_Tag.Text_Tag_List.GSlist;

      Iter    : aliased Gtk.Text_Iter.Gtk_Text_Iter;
      Buf_X   : Glib.Gint;
      Buf_Y   : Glib.Gint;
      Tags    : Gtk.Text_Tag.Text_Tag_List.GSlist;
      Tmp     : Gtk.Text_Tag.Text_Tag_List.GSlist;
      Dummy   : Boolean;
   begin
      B.The_View.Window_To_Buffer_Coords
        (Gtk.Enums.Text_Window_Widget, X, Y, Buf_X, Buf_Y);
      Dummy := Gtk.Text_View.Get_Iter_At_Location
        (B.The_View, Iter'Access, Buf_X, Buf_Y);

      Tags := Gtk.Text_Iter.Get_Tags (Iter);
      Tmp := Tags;
      while Tmp /= Gtk.Text_Tag.Text_Tag_List.Null_List loop
         declare
            Tag      : constant Gtk.Text_Tag.Gtk_Text_Tag :=
              Gtk.Text_Tag.Text_Tag_List.Get_Data (Tmp);
            Tag_Name : constant String :=
              Glib.Properties.Get_Property (Tag, Name_Property);
         begin
            if Tag_Name'Length > 7
              and then Tag_Name (Tag_Name'First .. Tag_Name'First + 6)
                       = "action_"
            then
               if B.Actions.Contains (Tag_Name) then
                  Gtk.Text_Tag.Text_Tag_List.Free (Tags);
                  return (Found => True, Action => B.Actions.Element (Tag_Name));
               end if;
               exit;
            end if;
         end;
         Tmp := Gtk.Text_Tag.Text_Tag_List.Next (Tmp);
      end loop;
      Gtk.Text_Tag.Text_Tag_List.Free (Tags);
      return (Found => False);
   end Handle_Action_Click;

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
