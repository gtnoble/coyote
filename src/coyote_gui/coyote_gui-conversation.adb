--  Coyote_GUI.Conversation body.
--
--  Project: coyote

with Ada.Strings.Unbounded;          use Ada.Strings.Unbounded;
with Cairo;                          use Cairo;
with Coyote_App.Utils;               use Coyote_App.Utils;
with Glib;                           use Glib;
with Gdk.Event;
with Gdk.Types;
with Gdk.Types.Keysyms;
with GNATCOLL.JSON;
with Gtk.Adjustment;
with Gtk.Clipboard;
with Gtk.Drawing_Area;
with Gtk.Menu;
with Gtk.Menu_Item;
with Gtk.Menu_Shell;
with Gtk.Scrolled_Window;
with Gtk.Widget;
with Pango.Cairo;
with Pango.Enums;                    use Pango.Enums;
with Pango.Layout;                   use Pango.Layout;

package body Coyote_GUI.Conversation is

   use type Gdk.Event.Gdk_Event_Type;
   use type Gdk.Event.Gdk_Event_Mask;
   use type Gdk.Types.Gdk_Modifier_Type;
   use type GNATCOLL.JSON.JSON_Value_Type;

   --  ── Global pointer for signal callbacks ───────────────────────────────

   Current_Conv : access Instance := null;

   --  ── Forward declarations for signal handlers ──────────────────────────

   function On_Draw
     (Self : access Gtk.Widget.Gtk_Widget_Record'Class;
      Cr   : Cairo.Cairo_Context) return Boolean;

   function On_Button_Press
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event_Button) return Boolean;

   function On_Button_Release
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event_Button) return Boolean;

   function On_Motion_Notify
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event_Motion) return Boolean;

   function On_Key_Press
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event_Key) return Boolean;

   procedure On_Size_Allocate
     (Self       : access Gtk.Widget.Gtk_Widget_Record'Class;
      Allocation : Gtk.Widget.Gtk_Allocation);

   procedure Copy_Menu_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class);

   --  ── Internal helpers ──────────────────────────────────────────────────

   procedure Append_Line
     (C : in out Instance; Style : Line_Style; Text : String);

   procedure Recompute_Vis_Lines (C : in out Instance);

   procedure Hit_Test
     (C            : in out Instance;
      X, Y         : Glib.Gint;
      Logical_Idx  : out Natural;
      Byte_Offset  : out Natural;
      Trailing     : out Glib.Gint);

   procedure Queue_Draw (C : in out Instance);

   procedure Copy_Selection_To_Clipboard (C : in out Instance);

   --  ── Append_Line ───────────────────────────────────────────────────────

   procedure Append_Line
     (C : in out Instance; Style : Line_Style; Text : String)
   is
      L : Logical_Line (Style);
   begin
      L.Text := To_Unbounded_String (Text);
      C.Lines.Append (L);
   end Append_Line;

   --  ── Recompute_Vis_Lines ───────────────────────────────────────────────

   procedure Recompute_Vis_Lines (C : in out Instance) is
      Width_Px : constant Glib.Gint := C.DA.Get_Allocated_Width;
      Total    : Natural := 0;
   begin
      if Width_Px <= 0 or else C.Lines.Is_Empty then
         return;
      end if;

      for I in 1 .. Positive (C.Lines.Length) loop
         declare
            Layout : constant Pango_Layout :=
              C.DA.Create_Pango_Layout (To_String (C.Lines (I).Text));
            Vis    : Natural;
         begin
            Layout.Set_Width (Width_Px * Pango_Scale);
            Layout.Set_Wrap (Pango_Wrap_Word_Char);
            Vis := Natural (Layout.Get_Line_Count);
            Total := Total + Vis;
         end;
      end loop;

      C.Total_Vis_Lines := Total;

      --  Update scrollbar range.
      declare
         Adj      : constant Gtk.Adjustment.Gtk_Adjustment :=
           C.Scroll.Get_Vadjustment;
         Doc_H    : constant Gdouble :=
           Gdouble (Total) * Gdouble (C.Line_Height_Px);
         Page_H   : constant Gdouble := Adj.Get_Page_Size;
         New_Upper : constant Gdouble := Gdouble'Max (Doc_H, Page_H);
      begin
         Adj.Set_Upper (New_Upper);
      end;
   end Recompute_Vis_Lines;

   --  ── Hit_Test ──────────────────────────────────────────────────────────

   procedure Hit_Test
     (C            : in out Instance;
      X, Y         : Glib.Gint;
      Logical_Idx  : out Natural;
      Byte_Offset  : out Natural;
      Trailing     : out Glib.Gint)
   is
      Width_Px    : constant Glib.Gint := C.DA.Get_Allocated_Width;
      --  Y is widget-relative (the drawing area's coordinate system already
      --  accounts for the scroll offset), so we use it directly.
      Vis_Line_N  : constant Natural :=
        Natural (Y / C.Line_Height_Px);
      Vis_Off     : Natural := 0;
      Found       : Boolean := False;
   begin
      Logical_Idx := 0;
      Byte_Offset := 0;
      Trailing    := 0;

      if Width_Px <= 0 or else C.Lines.Is_Empty then
         return;
      end if;

      for I in 1 .. Positive (C.Lines.Length) loop
         declare
            Layout : constant Pango_Layout :=
              C.DA.Create_Pango_Layout (To_String (C.Lines (I).Text));
            Vis_Cnt : Natural;
         begin
            Layout.Set_Width (Width_Px * Pango_Scale);
            Layout.Set_Wrap (Pango_Wrap_Word_Char);
            Vis_Cnt := Natural (Layout.Get_Line_Count);

            if Vis_Line_N < Vis_Off + Vis_Cnt then
               Logical_Idx := I;
               declare
                  Rel_Y : constant Glib.Gint :=
                    Y - Glib.Gint (Vis_Off) * C.Line_Height_Px;
                  Idx   : Glib.Gint;
                  Trl   : Glib.Gint;
                  Exact : Boolean;
                  pragma Unreferenced (Exact);
               begin
                  Layout.Xy_To_Index
                    (X * Pango_Scale, Rel_Y * Pango_Scale,
                     Idx, Trl, Exact);
                  Byte_Offset := Natural (Idx);
                  Trailing    := Trl;
               end;
               Found := True;
               exit;
            end if;
            Vis_Off := Vis_Off + Vis_Cnt;
         end;
      end loop;

      if not Found then
         Logical_Idx := Positive (C.Lines.Length);
         Byte_Offset := Natural (Length (C.Lines (Logical_Idx).Text));
      end if;
   end Hit_Test;

   --  ── Queue_Draw ────────────────────────────────────────────────────────

   procedure Queue_Draw (C : in out Instance) is
   begin
      C.DA.Queue_Draw;
   end Queue_Draw;

   --  ── Attach ─────────────────────────────────────────────────────────────

   procedure Attach
     (C      : in out Instance;
      Scroll : not null access Gtk.Scrolled_Window.Gtk_Scrolled_Window_Record'Class;
      DA     : not null access Gtk.Drawing_Area.Gtk_Drawing_Area_Record'Class)
   is
   begin
      C.Scroll := Gtk.Scrolled_Window.Gtk_Scrolled_Window (Scroll);
      C.DA     := Gtk.Drawing_Area.Gtk_Drawing_Area (DA);
      Current_Conv := C'Unchecked_Access;

      --  Event mask: button press, release, motion, key press.
      DA.Set_Events
        (Gdk.Event.Button_Press_Mask
         or Gdk.Event.Button_Release_Mask
         or Gdk.Event.Pointer_Motion_Mask
         or Gdk.Event.Key_Press_Mask);
      DA.Set_Can_Focus (True);

      --  Connect signals.
      DA.On_Draw (On_Draw'Access);
      DA.On_Button_Press_Event (On_Button_Press'Access);
      DA.On_Button_Release_Event (On_Button_Release'Access);
      DA.On_Motion_Notify_Event (On_Motion_Notify'Access);
      DA.On_Key_Press_Event (On_Key_Press'Access);
      DA.On_Size_Allocate (On_Size_Allocate'Access);

      --  Compute initial line height from the widget's default font.
      declare
         Layout : constant Pango_Layout := DA.Create_Pango_Layout ("X");
         W, H   : Glib.Gint;
      begin
         Layout.Get_Pixel_Size (W, H);
         if H > 0 then
            C.Line_Height_Px := H;
         end if;
      end;
   end Attach;

   --  ── Show_Copy_Menu ────────────────────────────────────────────────────

   procedure Show_Copy_Menu
     (C     : in out Instance;
      Event : Gdk.Event.Gdk_Event_Button)
   is
      use Gtk.Menu;
      use Gtk.Menu_Item;
      Menu  : Gtk_Menu;
      Item  : Gtk_Menu_Item;
   begin
      Gtk.Menu.Gtk_New (Menu);

      Gtk.Menu_Item.Gtk_New_With_Mnemonic (Item, "_Copy");
      Item.On_Activate (Copy_Menu_Activate'Access);
      Gtk.Menu_Shell.Append (Gtk.Menu_Shell.Gtk_Menu_Shell (Menu), Item);

      Menu.Show_All;
      Menu.Popup
        (Button        => Event.Button,
         Activate_Time => Event.Time);
   end Show_Copy_Menu;

   procedure Copy_Menu_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Self);
   begin
      if Current_Conv /= null then
         Copy_Selection_To_Clipboard (Current_Conv.all);
      end if;
   end Copy_Menu_Activate;

   --  ── Signal: size-allocate ──────────────────────────────────────────────

   procedure On_Size_Allocate
     (Self       : access Gtk.Widget.Gtk_Widget_Record'Class;
      Allocation : Gtk.Widget.Gtk_Allocation)
   is
      pragma Unreferenced (Self, Allocation);
   begin
      if Current_Conv = null then
         return;
      end if;
      Recompute_Vis_Lines (Current_Conv.all);
   end On_Size_Allocate;

   --  ── Signal: draw ──────────────────────────────────────────────────────

   function On_Draw
     (Self : access Gtk.Widget.Gtk_Widget_Record'Class;
      Cr   : Cairo.Cairo_Context) return Boolean
   is
      pragma Unreferenced (Self);

      Width_Px   : constant Glib.Gint := Current_Conv.DA.Get_Allocated_Width;
      Adj        : constant Gtk.Adjustment.Gtk_Adjustment :=
        Current_Conv.Scroll.Get_Vadjustment;
      Scroll_Y   : constant Glib.Gint := Glib.Gint (Adj.Get_Value);
      First_Vis  : constant Natural :=
        Natural (Scroll_Y / Current_Conv.Line_Height_Px);
      Vis_Off    : Natural := 0;
      Y_Off      : Glib.Gint := - (Scroll_Y mod Current_Conv.Line_Height_Px);
   begin
      if Current_Conv = null or else Width_Px <= 0
        or else Current_Conv.Lines.Is_Empty
      then
         return False;
      end if;

      --  Walk logical lines, drawing only those whose visual lines
      --  intersect the visible viewport.
      for I in 1 .. Positive (Current_Conv.Lines.Length) loop
         declare
            L      : constant Logical_Line := Current_Conv.Lines (I);
            Text   : constant String := To_String (L.Text);
            Layout : constant Pango_Layout :=
              Current_Conv.DA.Create_Pango_Layout (Text);
            Vis_Cnt : Natural;
         begin
            Layout.Set_Width (Width_Px * Pango_Scale);
            Layout.Set_Wrap (Pango_Wrap_Word_Char);
            Vis_Cnt := Natural (Layout.Get_Line_Count);

            --  Skip if entirely above viewport.
            if Vis_Off + Vis_Cnt <= First_Vis then
               Vis_Off := Vis_Off + Vis_Cnt;
               goto Continue;
            end if;

            --  Stop if entirely below viewport.
            if Y_Off >= Current_Conv.DA.Get_Allocated_Height then
               exit;
            end if;

            --  Draw background for this logical line's visual lines.
            declare
               Block_H : constant Glib.Gint :=
                 Glib.Gint (Vis_Cnt) * Current_Conv.Line_Height_Px;
            begin
               case L.Style is
                  when Thinking =>
                     Set_Source_Rgba (Cr, 1.0, 0.99, 0.91, 1.0);
                     Rectangle
                       (Cr, 0.0, Gdouble (Y_Off),
                        Gdouble (Width_Px), Gdouble (Block_H));
                     Fill (Cr);
                  when Notice_Info =>
                     Set_Source_Rgba (Cr, 0.91, 0.94, 1.0, 1.0);
                     Rectangle
                       (Cr, 0.0, Gdouble (Y_Off),
                        Gdouble (Width_Px), Gdouble (Block_H));
                     Fill (Cr);
                  when Notice_Warn | Notice_Error | Footer
                     | Action_Strip | Plain =>
                     null;
               end case;
            end;

            --  Draw selection highlight if this line intersects selection.
            if Current_Conv.Sel_Visible
              and then I >= Current_Conv.Sel_Start_Line
              and then I <= Current_Conv.Sel_End_Line
            then
               declare
                  Sel_Start : constant Natural :=
                    (if I = Current_Conv.Sel_Start_Line
                     then Current_Conv.Sel_Start_Byte
                     else 0);
                  Sel_End   : constant Natural :=
                    (if I = Current_Conv.Sel_End_Line
                     then Current_Conv.Sel_End_Byte
                     else Text'Length);
               begin
                  if Sel_Start < Sel_End then
                     declare
                        R1, R2 : Pango.Pango_Rectangle;
                     begin
                        Layout.Index_To_Pos
                          (Glib.Gint (Sel_Start), R1);
                        Layout.Index_To_Pos
                          (Glib.Gint (Sel_End), R2);
                        Set_Source_Rgba
                          (Cr, 0.3, 0.5, 0.9, 0.3);
                        Rectangle
                          (Cr,
                           Gdouble (R1.X) / Gdouble (Pango_Scale),
                           Gdouble (Y_Off),
                           Gdouble (R2.X - R1.X) / Gdouble (Pango_Scale),
                           Gdouble (Current_Conv.Line_Height_Px));
                        Fill (Cr);
                     end;
                  end if;
               end;
            end if;

            --  Set text colour by style.
            case L.Style is
               when Thinking | Notice_Info | Plain =>
                  Set_Source_Rgb (Cr, 0.0, 0.0, 0.0);
               when Notice_Warn =>
                  Set_Source_Rgb (Cr, 0.8, 0.53, 0.0);
               when Notice_Error =>
                  Set_Source_Rgb (Cr, 0.8, 0.2, 0.2);
               when Footer =>
                  Set_Source_Rgb (Cr, 0.53, 0.53, 0.53);
               when Action_Strip =>
                  Set_Source_Rgb (Cr, 0.13, 0.4, 0.67);
            end case;

            --  Render the Pango layout at the current Y offset.
            Move_To (Cr, 0.0, Gdouble (Y_Off));
            Pango.Cairo.Show_Layout (Cr, Layout);

            Vis_Off := Vis_Off + Vis_Cnt;
            Y_Off  := Y_Off + Glib.Gint (Vis_Cnt) * Current_Conv.Line_Height_Px;
         end;
         <<Continue>>
      end loop;

      return True;
   end On_Draw;

   --  ── Signal: button-press ──────────────────────────────────────────────

   function On_Button_Press
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event_Button) return Boolean
   is
      pragma Unreferenced (Self);
   begin
      if Current_Conv = null then
         return False;
      end if;

      if Event.The_Type /= Gdk.Event.Button_Press then
         return False;
      end if;

      --  Grab focus for keyboard events.
      Current_Conv.DA.Grab_Focus;

      if Event.Button = 1 then
         --  Start selection.
         declare
            L_Idx : Natural;
            B_Off : Natural;
            Trl   : Glib.Gint;
         begin
            Hit_Test (Current_Conv.all,
                      Glib.Gint (Event.X), Glib.Gint (Event.Y),
                      L_Idx, B_Off, Trl);
            if L_Idx > 0 then
               Current_Conv.Sel_Dragging   := True;
               Current_Conv.Sel_Visible    := True;
               Current_Conv.Sel_Start_Line := L_Idx;
               Current_Conv.Sel_Start_Byte := B_Off;
               Current_Conv.Sel_End_Line   := L_Idx;
               Current_Conv.Sel_End_Byte   := B_Off;
               Queue_Draw (Current_Conv.all);
            end if;
         end;
         --  Don't stop propagation; the frontend's handler
         --  checks for tool/action clicks after us.
         null;

      elsif Event.Button = 3 and then Current_Conv.Sel_Visible then
         --  Right-click on a selection: show Copy context menu.
         Show_Copy_Menu (Current_Conv.all, Event);
         return True;
      end if;

      return False;
   end On_Button_Press;

   --  ── Signal: motion-notify ─────────────────────────────────────────────

   function On_Motion_Notify
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event_Motion) return Boolean
   is
      pragma Unreferenced (Self);
   begin
      if Current_Conv = null
        or else not Current_Conv.Sel_Dragging
      then
         return False;
      end if;

      declare
         L_Idx : Natural;
         B_Off : Natural;
         Trl   : Glib.Gint;
      begin
         Hit_Test (Current_Conv.all,
                   Glib.Gint (Event.X), Glib.Gint (Event.Y),
                   L_Idx, B_Off, Trl);
         if L_Idx > 0 then
            Current_Conv.Sel_End_Line := L_Idx;
            Current_Conv.Sel_End_Byte := B_Off;
            Queue_Draw (Current_Conv.all);
         end if;
      end;
      return True;
   end On_Motion_Notify;

   --  ── Signal: button-release ────────────────────────────────────────────

   function On_Button_Release
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event_Button) return Boolean
   is
      pragma Unreferenced (Self);
   begin
      if Current_Conv = null then
         return False;
      end if;

      if Event.Button = 1 and then Current_Conv.Sel_Dragging then
         --  Normalize selection (start < end).
         if Current_Conv.Sel_Start_Line > Current_Conv.Sel_End_Line
           or else (Current_Conv.Sel_Start_Line = Current_Conv.Sel_End_Line
                    and then Current_Conv.Sel_Start_Byte
                             > Current_Conv.Sel_End_Byte)
         then
            declare
               TL : constant Natural := Current_Conv.Sel_Start_Line;
               TB : constant Natural := Current_Conv.Sel_Start_Byte;
            begin
               Current_Conv.Sel_Start_Line := Current_Conv.Sel_End_Line;
               Current_Conv.Sel_Start_Byte := Current_Conv.Sel_End_Byte;
               Current_Conv.Sel_End_Line   := TL;
               Current_Conv.Sel_End_Byte   := TB;
            end;
         end if;
         --  Stop dragging; the highlight stays visible until the
         --  next click or Escape clears it.
         Current_Conv.Sel_Dragging := False;
      end if;
      return False;
   end On_Button_Release;

   --  ── Signal: key-press ─────────────────────────────────────────────────

   function On_Key_Press
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event_Key) return Boolean
   is
      pragma Unreferenced (Self);
      use type Gdk.Types.Gdk_Key_Type;
   begin
      if Current_Conv = null then
         return False;
      end if;

      --  Ctrl+C: copy selection to clipboard.
      if Event.Keyval = Gdk.Types.Keysyms.GDK_LC_c
        and then (Event.State and Gdk.Types.Control_Mask) /= 0
      then
         Copy_Selection_To_Clipboard (Current_Conv.all);
         return True;
      end if;

      --  Ctrl+A: select all.
      if Event.Keyval = Gdk.Types.Keysyms.GDK_LC_a
        and then (Event.State and Gdk.Types.Control_Mask) /= 0
      then
         if not Current_Conv.Lines.Is_Empty then
            Current_Conv.Sel_Visible    := True;
            Current_Conv.Sel_Start_Line := 1;
            Current_Conv.Sel_Start_Byte := 0;
            Current_Conv.Sel_End_Line   :=
              Positive (Current_Conv.Lines.Length);
            Current_Conv.Sel_End_Byte   :=
              Natural (Length
                (Current_Conv.Lines
                   (Positive (Current_Conv.Lines.Length)).Text));
            Queue_Draw (Current_Conv.all);
         end if;
         return True;
      end if;

      --  Escape: clear selection.
      if Event.Keyval = Gdk.Types.Keysyms.GDK_Escape then
         Current_Conv.Sel_Visible := False;
         Queue_Draw (Current_Conv.all);
         return True;
      end if;

      return False;
   end On_Key_Press;

   --  ── Copy_Selection_To_Clipboard ────────────────────────────────────────

   procedure Copy_Selection_To_Clipboard (C : in out Instance) is
      use Gtk.Clipboard;
      Text : Unbounded_String;
   begin
      if not C.Sel_Visible
        or else C.Sel_Start_Line = 0
        or else C.Sel_End_Line = 0
      then
         return;
      end if;

      for I in C.Sel_Start_Line .. C.Sel_End_Line loop
         if I <= Positive (C.Lines.Length) then
            declare
               Line_Text : constant String :=
                 To_String (C.Lines (I).Text);
               S_Byte    : constant Natural :=
                 (if I = C.Sel_Start_Line
                  then C.Sel_Start_Byte
                  else 0);
               E_Byte    : constant Natural :=
                 (if I = C.Sel_End_Line
                  then Natural'Min (C.Sel_End_Byte, Line_Text'Length)
                  else Line_Text'Length);
            begin
               if S_Byte < E_Byte
                 and then S_Byte <= Line_Text'Length
               then
                  if Length (Text) > 0 then
                     Append (Text, ASCII.LF);
                  end if;
                  Append (Text,
                    Line_Text
                      (Line_Text'First + S_Byte
                       .. Line_Text'First + E_Byte - 1));
               end if;
            end;
         end if;
      end loop;

      if Length (Text) > 0 then
         declare
            Clip : constant Gtk_Clipboard := Get;
         begin
            Clip.Set_Text (To_String (Text));
         end;
      end if;
   end Copy_Selection_To_Clipboard;

   --  ── Streaming text ────────────────────────────────────────────────────

   procedure Append_Text (C : in out Instance; Text : String) is
   begin
      if not C.In_Text_Block then
         C.In_Text_Block := True;
         C.Stream_Buf    := Null_Unbounded_String;
      end if;
      Append (C.Stream_Buf, Text);
   end Append_Text;

   procedure End_Text_Block (C : in out Instance) is
      Full_Text : constant String := To_String (C.Stream_Buf);
      Start     : Natural := Full_Text'First;
   begin
      if not C.In_Text_Block then
         return;
      end if;

      --  Split on LF, creating one logical line per line.
      for I in Full_Text'Range loop
         if Full_Text (I) = ASCII.LF then
            Append_Line (C, Plain,
                         Full_Text (Start .. I - 1));
            Start := I + 1;
         end if;
      end loop;
      if Start <= Full_Text'Last then
         Append_Line (C, Plain, Full_Text (Start .. Full_Text'Last));
      end if;

      --  Blank line after text block.
      Append_Line (C, Plain, "");

      C.In_Text_Block := False;
      C.Stream_Buf    := Null_Unbounded_String;
      Recompute_Vis_Lines (C);
      Queue_Draw (C);
   end End_Text_Block;

   --  ── Thinking blocks ───────────────────────────────────────────────────

   procedure Begin_Thinking (C : in out Instance) is
   begin
      C.In_Thinking    := True;
      C.Prefix_Emitted := False;
   end Begin_Thinking;

   procedure Append_Thinking (C : in out Instance; Text : String) is
      Trimmed : constant String := Collapse_Thinking_Delta (Text);
   begin
      if Trimmed'Length = 0 then
         return;
      end if;

      if not C.Prefix_Emitted then
         Append_Line (C, Thinking, UC_BOX_V & " " & Trimmed);
         C.Prefix_Emitted := True;
      else
         --  Append to the last line's text so thinking flows as one
         --  paragraph, not one line per delta.
         declare
            Last_Idx : constant Positive := Positive (C.Lines.Length);
         begin
            Append (C.Lines (Last_Idx).Text, Trimmed);
         end;
      end if;
      Recompute_Vis_Lines (C);
      Queue_Draw (C);
   end Append_Thinking;

   procedure End_Thinking (C : in out Instance) is
   begin
      if C.In_Thinking then
         if C.Prefix_Emitted then
            Append_Line (C, Thinking, "");
         end if;
         C.In_Thinking    := False;
         C.Prefix_Emitted := False;
         Recompute_Vis_Lines (C);
         Queue_Draw (C);
      end if;
   end End_Thinking;

   --  ── Tool call segments ────────────────────────────────────────────────

   procedure Begin_Tool
     (C          : in out Instance;
      Name       :        String;
      Args       :        String;
      Session_Id :        String;
      Tool_Id    :        String)
   is
      pragma Unreferenced (Session_Id);

      Args_Parsed : constant GNATCOLL.JSON.Read_Result :=
        GNATCOLL.JSON.Read (Args);
      Args_Val    : constant GNATCOLL.JSON.JSON_Value  :=
        (if Args_Parsed.Success
         then Args_Parsed.Value
         else GNATCOLL.JSON.JSON_Null);
   begin
      --  Blank line before tool block.
      Append_Line (C, Plain, "");

      --  Header line.
      C.Cur_Tool_First := Positive (C.Lines.Length) + 1;
      C.Cur_Tool_Id    := To_Unbounded_String (Tool_Id);
      C.Tool_Starts.Include (Tool_Id, C.Cur_Tool_First);
      Append_Line (C, Plain,
                   UC_BOX_TL & " " & UC_GEAR & " " & Name);

      --  Argument lines.
      if Args_Val.Kind = GNATCOLL.JSON.JSON_Object_Type then
         declare
            procedure Add_Arg_Line
              (Field_Name  : GNATCOLL.JSON.UTF8_String;
               Field_Value : GNATCOLL.JSON.JSON_Value)
            is
            begin
               Append_Line (C, Plain,
                 UC_BOX_V & " "
                 & Format_Tool_Field
                     (Field_Name,
                      JSON_Scalar_Image (Field_Value),
                      Max_Len => 80));
            end Add_Arg_Line;
         begin
            Args_Val.Map_JSON_Object (Add_Arg_Line'Access);
         end;
      end if;

      --  Footer placeholder.
      Append_Line (C, Plain,
                   UC_BOX_BL & " " & UC_ELLIP & " running" & UC_ELLIP);
      Append_Line (C, Plain, "");

      Recompute_Vis_Lines (C);
      Queue_Draw (C);
   end Begin_Tool;

   procedure End_Tool
     (C       : in out Instance;
      Tool_Id :        String;
      Status  :        Tool_End_Status;
      Result  :        String)
   is
      use Tool_Start_Maps;
      Pos       : Cursor := C.Tool_Starts.Find (Tool_Id);
      First_Idx : Positive;
      Last_Idx  : constant Positive := Positive (C.Lines.Length);
   begin
      if Pos = No_Element then
         return;
      end if;
      First_Idx := Element (Pos);

      --  Replace the placeholder footer line (second-to-last line, before
      --  the trailing blank line).
      if Last_Idx > First_Idx + 1 then
         declare
            Replacement : Unbounded_String;
         begin
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
            C.Lines (Last_Idx - 1).Text := Replacement;
         end;
      end if;

      --  Record tool block for click handling.
      declare
         TB : Tool_Block;
      begin
         TB.First_Line := First_Idx;
         TB.Last_Line  := Last_Idx;
         TB.Info.Name  := To_Unbounded_String
           (To_String (C.Lines (First_Idx).Text));
         TB.Info.Result_Text   := To_Unbounded_String (Result);
         TB.Info.Result_Status := Status;
         C.Tools.Append (TB);
      end;

      C.Tool_Starts.Delete (Pos);
      Recompute_Vis_Lines (C);
      Queue_Draw (C);
   end End_Tool;

   --  ── Handle_Tool_Click ─────────────────────────────────────────────────

   function Handle_Tool_Click
     (C : in out Instance;
      X :        Glib.Gint;
      Y :        Glib.Gint) return Tool_Click_Result
   is
      L_Idx : Natural;
      B_Off : Natural;
      Trl   : Glib.Gint;
   begin
      Hit_Test (C, X, Y, L_Idx, B_Off, Trl);
      if L_Idx = 0 then
         return (Found => False);
      end if;

      for TB of C.Tools loop
         if L_Idx >= TB.First_Line and then L_Idx <= TB.Last_Line then
            declare
               Result : Tool_Click_Result (Found => True);
            begin
               Result.Title := To_Unbounded_String
                 ("Tool: " & To_String (TB.Info.Name));
               Result.Content := To_Unbounded_String
                 ("Arguments:" & ASCII.LF
                  & To_String (TB.Info.Args) & ASCII.LF & ASCII.LF
                  & "Result:" & ASCII.LF
                  & To_String (TB.Info.Result_Text));
               return Result;
            end;
         end if;
      end loop;

      return (Found => False);
   end Handle_Tool_Click;

   --  ── Handle_Action_Click ───────────────────────────────────────────────

   function Handle_Action_Click
     (C : in out Instance;
      X :        Glib.Gint;
      Y :        Glib.Gint) return Action_Click_Result
   is
      L_Idx : Natural;
      B_Off : Natural;
      Trl   : Glib.Gint;
   begin
      Hit_Test (C, X, Y, L_Idx, B_Off, Trl);
      if L_Idx = 0
        or else L_Idx > Positive (C.Lines.Length)
      then
         return (Found => False);
      end if;

      if C.Lines (L_Idx).Style = Action_Strip then
         return (Found => True,
                 Action => C.Lines (L_Idx).Action);
      end if;

      return (Found => False);
   end Handle_Action_Click;

   --  ── Action strips ─────────────────────────────────────────────────────

   procedure Append_Action_Strip
     (C      : in out Instance;
      Label  :        String;
      Action :        Action_Info)
   is
      L : Logical_Line (Action_Strip);
   begin
      L.Text   := To_Unbounded_String (Label);
      L.Action := Action;
      C.Lines.Append (L);
      Recompute_Vis_Lines (C);
      Queue_Draw (C);
   end Append_Action_Strip;

   --  ── Notices and footers ───────────────────────────────────────────────

   procedure Append_Notice
     (C    : in out Instance;
      Kind :        Line_Style;
      Text :        String)
   is
   begin
      Append_Line (C, Kind, Text);
      Recompute_Vis_Lines (C);
      Queue_Draw (C);
   end Append_Notice;

   procedure Append_Turn_Footer (C : in out Instance; Text : String) is
      pragma Unreferenced (Text);
   begin
      Append_Line (C, Plain, "");
      Append_Line (C, Footer,
                   Str_Repeat (UC_HORIZ, 60));
      Append_Line (C, Plain, "");
      Recompute_Vis_Lines (C);
      Queue_Draw (C);
   end Append_Turn_Footer;

   --  ── Markdown rendering toggle ─────────────────────────────────────────

   procedure Set_Render_Markdown (C : in out Instance; Enabled : Boolean) is
   begin
      C.Render_Markdown := Enabled;
   end Set_Render_Markdown;

   function Get_Render_Markdown (C : Instance) return Boolean is
   begin
      return C.Render_Markdown;
   end Get_Render_Markdown;

   --  ── Invalidate_Layout ─────────────────────────────────────────────────

   procedure Invalidate_Layout (C : in out Instance) is
      Layout : constant Pango_Layout :=
        C.DA.Create_Pango_Layout ("X");
      W, H   : Glib.Gint;
   begin
      Layout.Get_Pixel_Size (W, H);
      if H > 0 then
         C.Line_Height_Px := H;
      end if;
      Recompute_Vis_Lines (C);
      Queue_Draw (C);
   end Invalidate_Layout;

end Coyote_GUI.Conversation;
