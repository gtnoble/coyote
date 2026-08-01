--  Coyote_GUI.Conversation body.
--
--  Project: coyote

with Ada.Text_IO;
with Ada.Containers;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;          use Ada.Strings.Unbounded;
with Cairo;                          use Cairo;
with Coyote_App.Utils;               use Coyote_App.Utils;
with Coyote_Cmark;                   use Coyote_Cmark;
with Glib;                           use Glib;
with Gdk.Event;
with Gdk.Types;
with Gdk.Types.Keysyms;
with GNATCOLL.JSON;
with Gtk.Adjustment;
with Gtk.Clipboard;
with Gtk.Layout;
with Gtk.Menu;
with Gtk.Menu_Item;
with Gtk.Menu_Shell;
with Gtk.Scrolled_Window;
with Gtk.Widget;
with Interfaces.C;                   use Interfaces.C;
with Interfaces.C.Strings;
with Pango.Cairo;
with Pango.Enums;                    use Pango.Enums;
with Pango.Layout;                   use Pango.Layout;
with System;                         use System;

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

   procedure On_Adjustment_Value_Changed
     (Self : access Gtk.Adjustment.Gtk_Adjustment_Record'Class);

   procedure Copy_Menu_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class);

   --  ── Internal helpers ──────────────────────────────────────────────────

   procedure Debug_Log (C : in out Instance; Msg : String);

   procedure Append_Line
     (C : in out Instance; Style : Line_Style; Text : String);

   procedure Append_Markup_Line
     (C : in out Instance; Style : Line_Style; Text : String);

   procedure Recompute_Vis_Lines
     (C : in out Instance; Force : Boolean := False);

   procedure Hit_Test
     (C            : in out Instance;
      X, Y         : Glib.Gint;
      Logical_Idx  : out Natural;
      Byte_Offset  : out Natural;
      Trailing     : out Glib.Gint);

   procedure Queue_Draw (C : in out Instance);

   procedure Copy_Selection_To_Clipboard (C : in out Instance);

   --  Escape XML special characters for Pango markup.
   function Xml_Escape (S : String) return String;

   --  Strip Pango markup tags, returning plain text.
   function Strip_Pango_Markup (S : String) return String;

   --  Return the type-string for a cmark node (never null).
   function Cstr (N : Node_Ptr) return String;

   --  Return the literal text for a cmark node (never null).
   function Lit (N : Node_Ptr) return String;

   --  ── Append_Line ───────────────────────────────────────────────────────

   procedure Append_Line
     (C : in out Instance; Style : Line_Style; Text : String)
   is
      L : Logical_Line (Style);
   begin
      L.Text := To_Unbounded_String (Sanitize_UTF8 (Text));
      C.Lines.Append (L);
      Debug_Log (C, "Append_Line style=" & Line_Style'Image (Style)
                 & " len=" & Natural'Image (Text'Length)
                 & " total=" & Natural'Image (Natural (C.Lines.Length)));
   end Append_Line;

   --  ── Append_Markup_Line ────────────────────────────────────────────────

   procedure Append_Markup_Line
     (C : in out Instance; Style : Line_Style; Text : String)
   is
      L : Logical_Line (Style);
   begin
      L.Text       := To_Unbounded_String (Sanitize_UTF8 (Text));
      L.Has_Markup := True;
      C.Lines.Append (L);
      Debug_Log (C, "Append_Markup_Line style=" & Line_Style'Image (Style)
                 & " len=" & Natural'Image (Text'Length)
                 & " total=" & Natural'Image (Natural (C.Lines.Length)));
   end Append_Markup_Line;

   --  ── Xml_Escape ────────────────────────────────────────────────────────

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

   --  ── Strip_Pango_Markup ────────────────────────────────────────────────

   function Strip_Pango_Markup (S : String) return String is
      R     : Unbounded_String;
      In_Tag : Boolean := False;
      I      : Natural := S'First;
   begin
      while I <= S'Last loop
         if S (I) = '<' then
            In_Tag := True;
         elsif S (I) = '>' then
            In_Tag := False;
         elsif not In_Tag then
            Append (R, S (I));
         end if;
         I := I + 1;
      end loop;
      return To_String (R);
   end Strip_Pango_Markup;

   --  ── Cstr / Lit ────────────────────────────────────────────────────────

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

   --  ── Recompute_Vis_Lines ───────────────────────────────────────────────

   procedure Recompute_Vis_Lines
     (C : in out Instance; Force : Boolean := False) is
      Width_Px : constant Glib.Gint := C.Layout_W.Get_Allocated_Width;
      Total    : Natural := 0;
   begin
      if Width_Px <= 0 or else C.Lines.Is_Empty then
         Debug_Log (C, "Recompute_Vis_Lines skip width=" & Glib.Gint'Image (Width_Px)
                    & " empty=" & Boolean'Image (C.Lines.Is_Empty));
         return;
      end if;

      --  Cache hit: width and line count unchanged.
      if not Force
        and then Width_Px = C.Cache_Width_Px
        and then Natural (C.Lines.Length) = C.Cached_Line_Count
        and then C.Total_Vis_Lines > 0
      then
         Debug_Log
           (C,
            "Recompute_Vis_Lines skip cache hit width="
            & Glib.Gint'Image (Width_Px));
         return;
      end if;

      for I in 1 .. Positive (C.Lines.Length) loop
         declare
            Layout : Pango_Layout;
            Vis    : Natural;
         begin
            if C.Lines (I).Has_Markup then
               Layout := C.Layout_W.Create_Pango_Layout ("");
               Layout.Set_Markup (To_String (C.Lines (I).Text));
            else
               Layout := C.Layout_W.Create_Pango_Layout
                 (To_String (C.Lines (I).Text));
            end if;
            Layout.Set_Width (Width_Px * Pango_Scale);
            Layout.Set_Wrap (Pango_Wrap_Word_Char);
            Vis := Natural (Layout.Get_Line_Count);
            C.Lines (I).Vis_Count := Vis;
            Total := Total + Vis;
         end;
      end loop;

      C.Total_Vis_Lines := Total;

      Debug_Log (C, "Recompute_Vis_Lines logical="
                 & Natural'Image (Natural (C.Lines.Length))
                 & " visual=" & Natural'Image (Total)
                 & " line_h=" & Glib.Gint'Image (C.Line_Height_Px));

      --  Tell the GtkLayout the total scrollable area so it can position
      --  its bin window correctly and drive the shared adjustments.
      C.Layout_W.Set_Size
        (Glib.Guint (Width_Px),
         Glib.Guint (Integer (Total) * Integer (C.Line_Height_Px)));

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
      C.Cache_Width_Px    := Width_Px;
      C.Cached_Line_Count := Natural (C.Lines.Length);
   end Recompute_Vis_Lines;

   --  ── Hit_Test ──────────────────────────────────────────────────────────

   procedure Hit_Test
     (C            : in out Instance;
      X, Y         : Glib.Gint;
      Logical_Idx  : out Natural;
      Byte_Offset  : out Natural;
      Trailing     : out Glib.Gint)
   is
      Width_Px    : constant Glib.Gint := C.Layout_W.Get_Allocated_Width;
      --  Y is widget-relative (the layout's coordinate system already
      --  accounts for the scroll offset), so we use it directly.
      Vis_Line_N  : constant Natural :=
        Natural (Glib.Gint'Max (Y, 0) / C.Line_Height_Px);
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
            Vis_Cnt : constant Natural := C.Lines (I).Vis_Count;
         begin
            if Vis_Line_N < Vis_Off + Vis_Cnt then
               --  Found the target line; create a Pango layout for
               --  Xy_To_Index resolution only.
               Logical_Idx := I;
               declare
                  Layout : Pango_Layout;
               begin
                  if C.Lines (I).Has_Markup then
                     Layout := C.Layout_W.Create_Pango_Layout ("");
                     Layout.Set_Markup (To_String (C.Lines (I).Text));
                  else
                     Layout := C.Layout_W.Create_Pango_Layout
                       (To_String (C.Lines (I).Text));
                  end if;
                  Layout.Set_Width (Width_Px * Pango_Scale);
                  Layout.Set_Wrap (Pango_Wrap_Word_Char);

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
      Debug_Log (C, "Queue_Draw");
      C.Layout_W.Queue_Draw;
   end Queue_Draw;

   --  ── Attach ─────────────────────────────────────────────────────────────

   procedure Attach
     (C        : in out Instance;
      Scroll   : not null access Gtk.Scrolled_Window.Gtk_Scrolled_Window_Record'Class;
      Layout_W : not null access Gtk.Layout.Gtk_Layout_Record'Class)
   is
   begin
      C.Scroll    := Gtk.Scrolled_Window.Gtk_Scrolled_Window (Scroll);
      C.Layout_W  := Gtk.Layout.Gtk_Layout (Layout_W);
      Current_Conv := C'Unchecked_Access;

      --  Event mask: button press, release, motion, key press.
      Layout_W.Set_Events
        (Gdk.Event.Button_Press_Mask
         or Gdk.Event.Button_Release_Mask
         or Gdk.Event.Pointer_Motion_Mask
         or Gdk.Event.Key_Press_Mask);
      Layout_W.Set_Can_Focus (True);

      --  Connect signals.
      Layout_W.On_Draw (On_Draw'Access);
      Layout_W.On_Button_Press_Event (On_Button_Press'Access);
      Layout_W.On_Button_Release_Event (On_Button_Release'Access);
      Layout_W.On_Motion_Notify_Event (On_Motion_Notify'Access);
      Layout_W.On_Key_Press_Event (On_Key_Press'Access);
      Layout_W.On_Size_Allocate (On_Size_Allocate'Access);

      --  Monitor scroll position changes.
      declare
         Adj : constant Gtk.Adjustment.Gtk_Adjustment :=
           Scroll.Get_Vadjustment;
      begin
         Adj.On_Value_Changed (On_Adjustment_Value_Changed'Access);
      end;

      --  Compute initial line height from the widget's default font.
      declare
         Layout : constant Pango_Layout := Layout_W.Create_Pango_Layout ("X");
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
      Current_Conv.Debug_Log
        ("On_Size_Allocate alloc_w=" & Glib.Gint'Image (Allocation.Width)
         & " alloc_h=" & Glib.Gint'Image (Allocation.Height));
      Recompute_Vis_Lines (Current_Conv.all);
   end On_Size_Allocate;

   --  ── Signal: adjustment value-changed ──────────────────────────────────

   procedure On_Adjustment_Value_Changed
     (Self : access Gtk.Adjustment.Gtk_Adjustment_Record'Class)
   is
   begin
      if Current_Conv = null then
         return;
      end if;
      Current_Conv.Debug_Log
        ("On_Adjustment_Value_Changed value="
         & Glib.Gdouble'Image (Self.Get_Value)
         & " lower=" & Glib.Gdouble'Image (Self.Get_Lower)
         & " upper=" & Glib.Gdouble'Image (Self.Get_Upper)
         & " page_size=" & Glib.Gdouble'Image (Self.Get_Page_Size));
   end On_Adjustment_Value_Changed;

   --  ── Signal: draw ──────────────────────────────────────────────────────

   function On_Draw
     (Self : access Gtk.Widget.Gtk_Widget_Record'Class;
      Cr   : Cairo.Cairo_Context) return Boolean
   is
      pragma Unreferenced (Self);

      Width_Px   : constant Glib.Gint := Current_Conv.Layout_W.Get_Allocated_Width;
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

      --  Fill entire widget background with white so plain lines
      --  always have a white backdrop regardless of system theme.
      Set_Source_Rgb (Cr, 1.0, 1.0, 1.0);
      declare
         Alloc_H : constant Glib.Gint :=
           Current_Conv.Layout_W.Get_Allocated_Height;
      begin
         Rectangle
           (Cr, 0.0, 0.0,
            Gdouble (Width_Px), Gdouble (Alloc_H));
         Fill (Cr);
      end;

      --  Walk logical lines, drawing only those whose visual lines
      --  intersect the visible viewport.
      Current_Conv.Debug_Log
        ("On_Draw logical=" & Natural'Image (Natural (Current_Conv.Lines.Length))
         & " first_vis=" & Natural'Image (First_Vis)
         & " scroll_y=" & Glib.Gint'Image (Scroll_Y)
         & " line_h=" & Glib.Gint'Image (Current_Conv.Line_Height_Px));
      for I in 1 .. Positive (Current_Conv.Lines.Length) loop
         declare
            L      : constant Logical_Line := Current_Conv.Lines (I);
            Text   : constant String := To_String (L.Text);
            Vis_Cnt : constant Natural := L.Vis_Count;
         begin
            --  Skip if entirely above viewport, using cached visual count.
            if Vis_Off + Vis_Cnt <= First_Vis then
               Vis_Off := Vis_Off + Vis_Cnt;
               goto Continue;
            end if;

            --  Stop if entirely below viewport.
            if Y_Off >= Current_Conv.Layout_W.Get_Allocated_Height then
               exit;
            end if;

            --  Only create a Pango layout for lines that are visible.
            declare
               Layout : Pango_Layout;
            begin
               if L.Has_Markup then
                  Layout := Current_Conv.Layout_W.Create_Pango_Layout ("");
                  Layout.Set_Markup (Text);
               else
                  Layout := Current_Conv.Layout_W.Create_Pango_Layout (Text);
               end if;
               Layout.Set_Width (Width_Px * Pango_Scale);
               Layout.Set_Wrap (Pango_Wrap_Word_Char);

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
                     when Code_Block =>
                        Set_Source_Rgba (Cr, 0.96, 0.96, 0.96, 1.0);
                        Rectangle
                          (Cr, 0.0, Gdouble (Y_Off),
                           Gdouble (Width_Px), Gdouble (Block_H));
                        Fill (Cr);
                     when Blockquote =>
                        --  Left border bar.
                        Set_Source_Rgba (Cr, 0.6, 0.6, 0.6, 0.5);
                        Rectangle
                          (Cr, 0.0, Gdouble (Y_Off),
                           4.0, Gdouble (Block_H));
                        Fill (Cr);
                     when Notice_Warn | Notice_Error | Footer
                        | Action_Strip | Plain
                        | Heading_1 | Heading_2 | Heading_3
                        | Heading_4 | Heading_5 | Heading_6
                        | Thematic_Break
                        | List_Item_Bullet | List_Item_Ordered =>
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

               --  Set text colour and font weight by style.
               case L.Style is
                  when Thinking | Notice_Info | Plain
                     | List_Item_Bullet | List_Item_Ordered =>
                     Set_Source_Rgb (Cr, 0.0, 0.0, 0.0);
                  when Heading_1 | Heading_2 =>
                     Set_Source_Rgb (Cr, 0.0, 0.0, 0.0);
                  when Heading_3 | Heading_4 =>
                     Set_Source_Rgb (Cr, 0.0, 0.0, 0.0);
                  when Heading_5 | Heading_6 =>
                     Set_Source_Rgb (Cr, 0.0, 0.0, 0.0);
                  when Code_Block =>
                     Set_Source_Rgb (Cr, 0.2, 0.2, 0.2);
                  when Blockquote =>
                     Set_Source_Rgb (Cr, 0.3, 0.3, 0.3);
                  when Thematic_Break =>
                     Set_Source_Rgb (Cr, 0.6, 0.6, 0.6);
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
            end;

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
      Current_Conv.Layout_W.Grab_Focus;

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
               Raw_Text  : constant String :=
                 To_String (C.Lines (I).Text);
               Line_Text : constant String :=
                 (if C.Lines (I).Has_Markup
                  then Strip_Pango_Markup (Raw_Text)
                  else Raw_Text);
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
      Start    : Natural  := Text'First;
      Last_Idx : Positive;
   begin
      if not C.In_Text_Block then
         C.In_Text_Block    := True;
         C.Stream_Buf       := Null_Unbounded_String;
         Append_Line (C, Plain, "");
         C.Stream_First_Line := Natural (C.Lines.Length);
      end if;
      Append (C.Stream_Buf, Text);

      Last_Idx := Positive (C.Lines.Length);
      for I in Text'Range loop
         if Text (I) = ASCII.LF then
            if I > Start then
               Append (C.Lines (Last_Idx).Text,
                       Sanitize_UTF8 (Text (Start .. I - 1)));
            end if;
            Append_Line (C, Plain, "");
            Last_Idx := Positive (C.Lines.Length);
            Start    := I + 1;
         end if;
      end loop;
      if Start <= Text'Last then
         Append (C.Lines (Last_Idx).Text,
                 Sanitize_UTF8 (Text (Start .. Text'Last)));
      end if;
      Recompute_Vis_Lines (C);
      Queue_Draw (C);
   end Append_Text;

   --  ── Render_Markdown_Block ────────────────────────────────────────────
   --
   --  Parse Full_Text as GFM and emit styled Logical_Line entries.
   --  Block-level nodes become lines with appropriate Line_Style;
   --  inline formatting within paragraphs is accumulated as Pango
   --  markup and emitted with Has_Markup = True.

   procedure Render_Markdown_Block
     (C : in out Instance; Full_Text : String)
   is
      C_Text : constant Interfaces.C.char_array :=
        Interfaces.C.To_C (Full_Text);
      Doc    : Node_Ptr;
      It     : Iter_Ptr;
      Ev     : Event_Type_Int;
      Node   : Node_Ptr;

      --  Paragraph inline-accumulation state
      In_Para      : Boolean := False;
      Para_Buf     : Unbounded_String;
      Para_Empty   : Boolean := True;
      In_List_Item : Boolean := False;

      --  List nesting state
      type Level_T is range 0 .. 7;
      List_Counter  : array (Level_T) of Integer := (others => 0);
      List_Is_Bullet : array (Level_T) of Boolean := (others => True);
      List_Depth    : Natural := 0;

      --  Table accumulation state (two-pass box-drawing)
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

      procedure Cell_Append (S : String) is
      begin
         if Cur_Row < Max_Table_Rows
           and then Cur_Col < Max_Table_Cols
         then
            Append
              (Table_Data (Row_Index (Cur_Row), Col_Index (Cur_Col)), S);
         end if;
      end Cell_Append;

      procedure Flush_Para is
      begin
         if In_Para and then not Para_Empty then
            Append_Markup_Line (C, Plain, To_String (Para_Buf));
         end if;
         In_Para    := False;
         Para_Buf   := Null_Unbounded_String;
         Para_Empty := True;
      end Flush_Para;

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
            Line : Unbounded_String;
         begin
            Append (Line, L_Cap);
            for Col in 0 .. Table_Cols - 1 loop
               for I in 1 .. Col_Widths (Col) + 2 loop
                  Append (Line, UC_HORIZ);
               end loop;
               if Col < Table_Cols - 1 then
                  Append (Line, Junction);
               end if;
            end loop;
            Append (Line, R_Cap);
            Append_Line (C, Plain, To_String (Line));
         end H_Rule;

      begin
         if Table_Rows = 0 or else Table_Cols = 0 then
            return;
         end if;

         for Col in 0 .. Table_Cols - 1 loop
            for Row in 0 .. Table_Rows - 1 loop
               declare
                  L : constant Natural :=
                    Length (Table_Data (Row_Index (Row), Col_Index (Col)));
               begin
                  if L > Col_Widths (Col) then
                     Col_Widths (Col) := L;
                  end if;
               end;
            end loop;
            if Col_Widths (Col) > Max_Col_Width then
               Col_Widths (Col) := Max_Col_Width;
            end if;
         end loop;

         H_Rule (UC_BOX_TL, UC_BOX_T, UC_BOX_TR);

         for Row in 0 .. Table_Rows - 1 loop
            declare
               Line : Unbounded_String;
            begin
               Append (Line, UC_BOX_V);
               for Col in 0 .. Table_Cols - 1 loop
                  Append (Line, " ");
                  Append (Line,
                    Pad (To_String
                           (Table_Data (Row_Index (Row), Col_Index (Col))),
                         Col_Widths (Col)));
                  Append (Line, " " & UC_BOX_V);
               end loop;
               Append_Line (C, Plain, To_String (Line));
            end;

            if Row = 0 and then Table_Rows > 1 then
               H_Rule (UC_BOX_L, UC_BOX_X, UC_BOX_R);
            end if;
         end loop;

         H_Rule (UC_BOX_BL, UC_BOX_B, UC_BOX_BR);
      end Render_Table;

   begin
      if Full_Text'Length = 0 then
         return;
      end if;

      Doc := Parse_Document (C_Text, C_Text'Length - 1, OPT_DEFAULT);
      if Doc = System.Null_Address then
         --  Fall back to plain text.
         declare
            Start : Natural := Full_Text'First;
         begin
            for I in Full_Text'Range loop
               if Full_Text (I) = ASCII.LF then
                  Append_Line (C, Plain,
                               Full_Text (Start .. I - 1));
                  Start := I + 1;
               end if;
            end loop;
            if Start <= Full_Text'Last then
               Append_Line (C, Plain,
                            Full_Text (Start .. Full_Text'Last));
            end if;
         end;
         return;
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
            --  ── Table handling ────────────────────────────────────────
            if TS = "table" then
               if Ev = EVENT_ENTER then
                  Flush_Para;
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
                  if Cur_Row < Max_Table_Rows
                    and then Cur_Col < Max_Table_Cols
                  then
                     Table_Data (Row_Index (Cur_Row),
                                 Col_Index (Cur_Col)) :=
                       Null_Unbounded_String;
                  end if;
                  In_Cell := True;
               else
                  In_Cell := False;
                  Cur_Col := Cur_Col + 1;
               end if;

            --  ── Document ──────────────────────────────────────────────
            elsif NT = NODE_DOCUMENT then
               null;

            --  ── Paragraph ─────────────────────────────────────────────
            elsif NT = NODE_PARAGRAPH then
               if Ev = EVENT_ENTER then
                  if not In_List_Item then
                     Flush_Para;
                     In_Para    := True;
                     Para_Buf   := Null_Unbounded_String;
                     Para_Empty := True;
                  end if;
               else
                  if not In_List_Item then
                     Flush_Para;
                     Append_Line (C, Plain, "");
                  end if;
               end if;

            --  ── Heading ────────────────────────────────────────────────
            elsif NT = NODE_HEADING then
               if Ev = EVENT_ENTER then
                  Flush_Para;
                  In_Para    := True;
                  Para_Buf   := Null_Unbounded_String;
                  Para_Empty := True;
               else
                  declare
                     H_Level : constant Interfaces.C.int :=
                       Node_Get_Heading_Level (Node);
                     Style   : Line_Style;
                  begin
                     case Integer (H_Level) is
                        when 1 => Style := Heading_1;
                        when 2 => Style := Heading_2;
                        when 3 => Style := Heading_3;
                        when 4 => Style := Heading_4;
                        when 5 => Style := Heading_5;
                        when 6 => Style := Heading_6;
                        when others => Style := Plain;
                     end case;
                     if not Para_Empty then
                        Append_Markup_Line
                          (C, Style, To_String (Para_Buf));
                     end if;
                     In_Para    := False;
                     Para_Buf   := Null_Unbounded_String;
                     Para_Empty := True;
                  end;
                  Append_Line (C, Plain, "");
               end if;

            --  ── Code block ────────────────────────────────────────────
            elsif NT = NODE_CODE_BLOCK then
               if Ev = EVENT_ENTER then
                  Flush_Para;
                  declare
                     Code_Text : constant String := Lit (Node);
                     Start     : Natural := Code_Text'First;
                  begin
                     for I in Code_Text'Range loop
                        if Code_Text (I) = ASCII.LF then
                           Append_Line
                             (C, Code_Block,
                              Code_Text (Start .. I - 1));
                           Start := I + 1;
                        end if;
                     end loop;
                     if Start <= Code_Text'Last then
                        Append_Line
                          (C, Code_Block,
                           Code_Text (Start .. Code_Text'Last));
                     end if;
                  end;
                  Append_Line (C, Plain, "");
               end if;

            --  ── Block quote ───────────────────────────────────────────
            elsif NT = NODE_BLOCK_QUOTE then
               if Ev = EVENT_ENTER then
                  Flush_Para;
               else
                  Append_Line (C, Plain, "");
               end if;

            --  ── List ───────────────────────────────────────────────────
            elsif NT = NODE_LIST then
               if Ev = EVENT_ENTER then
                  Flush_Para;
                  if List_Depth < Natural (Level_T'Last) then
                     List_Depth := List_Depth + 1;
                     List_Counter (Level_T (List_Depth)) := 0;
                     List_Is_Bullet (Level_T (List_Depth)) :=
                       (Node_Get_List_Type (Node) = LIST_BULLET);
                  end if;
               else
                  if List_Depth > 0 then
                     List_Depth := List_Depth - 1;
                     if List_Depth = 0 then
                        Append_Line (C, Plain, "");
                     end if;
                  end if;
               end if;

            --  ── List item ──────────────────────────────────────────────
            elsif NT = NODE_ITEM then
               if Ev = EVENT_ENTER then
                  if List_Depth > 0 then
                     declare
                        Prefix : Unbounded_String;
                     begin
                        if List_Is_Bullet (Level_T (List_Depth)) then
                           Append (Prefix, UC_BULLET & " ");
                        else
                           List_Counter (Level_T (List_Depth)) :=
                             List_Counter (Level_T (List_Depth)) + 1;
                           Append (Prefix,
                             Ada.Strings.Fixed.Trim
                               (Integer'Image
                                  (List_Counter (Level_T (List_Depth))),
                                Ada.Strings.Left) & ". ");
                        end if;
                        In_Para      := True;
                        Para_Buf     := Prefix;
                        Para_Empty   := False;
                        In_List_Item := True;
                     end;
                  end if;
               else
                  Flush_Para;
                  In_List_Item := False;
               end if;

            --  ── Thematic break ────────────────────────────────────────
            elsif NT = NODE_THEMATIC_BREAK then
               if Ev = EVENT_ENTER then
                  Flush_Para;
                  Append_Line
                    (C, Thematic_Break,
                     Str_Repeat (UC_HORIZ, 12));
                  Append_Line (C, Plain, "");
               end if;

            --  ── Inline formatting (within paragraph) ──────────────────
            elsif NT = NODE_STRONG then
               if In_Para then
                  if Ev = EVENT_ENTER then
                     Append (Para_Buf, "<b>");
                  else
                     Append (Para_Buf, "</b>");
                  end if;
               end if;

            elsif NT = NODE_EMPH then
               if In_Para then
                  if Ev = EVENT_ENTER then
                     Append (Para_Buf, "<i>");
                  else
                     Append (Para_Buf, "</i>");
                  end if;
               end if;

            elsif NT = NODE_LINK then
               if In_Para then
                  if Ev = EVENT_ENTER then
                     Append (Para_Buf, "<u>");
                  else
                     Append (Para_Buf, "</u>");
                  end if;
               end if;

            elsif NT = NODE_CODE then
               if Ev = EVENT_ENTER then
                  if In_Cell then
                     Cell_Append (Lit (Node));
                  elsif In_Para then
                     Append (Para_Buf, "<tt>");
                     Append (Para_Buf, Xml_Escape (Lit (Node)));
                     Append (Para_Buf, "</tt>");
                  end if;
               end if;

            elsif NT = NODE_TEXT then
               if Ev = EVENT_ENTER then
                  if In_Cell then
                     Cell_Append (Lit (Node));
                  elsif In_Para then
                     Append (Para_Buf, Xml_Escape (Lit (Node)));
                     Para_Empty := False;
                  end if;
               end if;

            elsif NT = NODE_SOFTBREAK then
               if Ev = EVENT_ENTER then
                  if In_Cell then
                     Cell_Append (" ");
                  elsif In_Para then
                     Append (Para_Buf, " ");
                  end if;
               end if;

            elsif NT = NODE_LINEBREAK then
               if Ev = EVENT_ENTER then
                  if In_Cell then
                     Cell_Append (" ");
                  elsif In_Para then
                     --  Hard break: flush current para line,
                     --  start a new one.
                     Flush_Para;
                     In_Para    := True;
                     Para_Buf   := Null_Unbounded_String;
                     Para_Empty := True;
                  end if;
               end if;

            --  ── GFM strikethrough ─────────────────────────────────────
            else
               if TS = "strikethrough" and then In_Para then
                  if Ev = EVENT_ENTER then
                     Append (Para_Buf, "<s>");
                  else
                     Append (Para_Buf, "</s>");
                  end if;
               end if;
            end if;
         end;
      end loop;

      Flush_Para;
      Iter_Free (It);
      Node_Free (Doc);
   end Render_Markdown_Block;

   --  ── End_Text_Block ────────────────────────────────────────────────────

   procedure End_Text_Block (C : in out Instance) is
      Full_Text : constant String := To_String (C.Stream_Buf);
   begin
      if not C.In_Text_Block then
         return;
      end if;

      Debug_Log (C, "End_Text_Block len=" & Natural'Image (Full_Text'Length)
                 & " markdown=" & Boolean'Image (C.Render_Markdown));

      --  Remove the raw streaming lines that Append_Text emitted.
      --  Stream_First_Line is the last blank line before streaming
      --  started; streaming lines occupy positions Stream_First_Line+1
      --  onward.  Delete the leading blank and all streamed content.
      if C.Stream_First_Line > 0
        and then Natural (C.Lines.Length) >= C.Stream_First_Line
      then
         C.Lines.Delete_Last
           (Ada.Containers.Count_Type
              (Natural (C.Lines.Length) - C.Stream_First_Line + 1));
         Debug_Log
           (C,
            "End_Text_Block removed streaming lines, remaining="
            & Natural'Image (Natural (C.Lines.Length)));
      end if;

      if C.Render_Markdown and then Full_Text'Length > 0 then
         Render_Markdown_Block (C, Full_Text);
      else
         --  Plain text: split on LF.
         declare
            Start : Natural := Full_Text'First;
         begin
            for I in Full_Text'Range loop
               if Full_Text (I) = ASCII.LF then
                  Append_Line (C, Plain,
                               Full_Text (Start .. I - 1));
                  Start := I + 1;
               end if;
            end loop;
            if Start <= Full_Text'Last then
               Append_Line (C, Plain,
                            Full_Text (Start .. Full_Text'Last));
            end if;
         end;
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
      Debug_Log (C, "Begin_Thinking");
      C.In_Thinking    := True;
      C.Prefix_Emitted := False;
      C.Thinking_Tok.Reset;
   end Begin_Thinking;

   procedure Append_Thinking (C : in out Instance; Text : String) is
      Tokenized : Ada.Strings.Unbounded.Unbounded_String;
   begin
      C.Thinking_Tok.Feed (Text, Tokenized);
      if Length (Tokenized) = 0 then
         return;
      end if;

      declare
         Proc : constant String := To_String (Tokenized);
      begin
         Debug_Log (C, "Append_Thinking len=" & Natural'Image (Proc'Length));

         if not C.Prefix_Emitted then
            Append_Line (C, Thinking, UC_BOX_V & " " & Sanitize_UTF8 (Proc));
            C.Prefix_Emitted := True;
         else
            declare
               Last_Idx : constant Positive := Positive (C.Lines.Length);
            begin
               Append (C.Lines (Last_Idx).Text, Sanitize_UTF8 (Proc));
            end;
         end if;
      end;
      Recompute_Vis_Lines (C);
      Queue_Draw (C);
   end Append_Thinking;

   procedure End_Thinking (C : in out Instance) is
      use Ada.Strings.Unbounded;
      Remaining : Unbounded_String;
   begin
      C.Thinking_Tok.Flush (Remaining);
      if Length (Remaining) > 0 then
         declare
            Proc : constant String := Sanitize_UTF8 (To_String (Remaining));
         begin
            if not C.Prefix_Emitted then
               Append_Line (C, Thinking, UC_BOX_V & " " & Proc);
               C.Prefix_Emitted := True;
            else
               declare
                  Last_Idx : constant Positive := Positive (C.Lines.Length);
               begin
                  Append (C.Lines (Last_Idx).Text, Proc);
               end;
            end if;
            Recompute_Vis_Lines (C);
            Queue_Draw (C);
         end;
      end if;
      Debug_Log (C, "End_Thinking in_thinking=" & Boolean'Image (C.In_Thinking)
                 & " prefix_emitted=" & Boolean'Image (C.Prefix_Emitted));
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
      Debug_Log (C, "Begin_Tool name=" & Name & " tool_id=" & Tool_Id);
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
      Debug_Log (C, "End_Tool tool_id=" & Tool_Id
                 & " status=" & Tool_End_Status'Image (Status));
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
                        & Sanitize_UTF8 (Result (Result'First .. Preview)));
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
      Debug_Log (C, "Append_Action_Strip label=" & Label);
      L.Text   := To_Unbounded_String (Sanitize_UTF8 (Label));
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
      Debug_Log (C, "Append_Notice kind=" & Line_Style'Image (Kind)
                 & " len=" & Natural'Image (Text'Length));
      Append_Line (C, Kind, Text);
      Recompute_Vis_Lines (C);
      Queue_Draw (C);
   end Append_Notice;

   procedure Append_Turn_Footer (C : in out Instance; Text : String) is
      pragma Unreferenced (Text);
   begin
      Debug_Log (C, "Append_Turn_Footer");
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

   --  ── Debug logging ────────────────────────────────────────────────────

   procedure Debug_Log (C : in out Instance; Msg : String) is
   begin
      if C.Debug_Logging then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "[conv] " & Msg);
      end if;
   end Debug_Log;

   procedure Set_Debug_Logging (C : in out Instance; Enabled : Boolean) is
   begin
      C.Debug_Logging := Enabled;
      Debug_Log (C, "debug logging " & (if Enabled then "enabled" else "disabled"));
   end Set_Debug_Logging;

   function Get_Debug_Logging (C : Instance) return Boolean is
   begin
      return C.Debug_Logging;
   end Get_Debug_Logging;

   --  ── Invalidate_Layout ─────────────────────────────────────────────────

   procedure Invalidate_Layout (C : in out Instance) is
      Layout : constant Pango_Layout :=
        C.Layout_W.Create_Pango_Layout ("X");
      W, H   : Glib.Gint;
   begin
      Layout.Get_Pixel_Size (W, H);
      if H > 0 then
         C.Line_Height_Px := H;
         Debug_Log (C, "Invalidate_Layout line_height_px=" & Glib.Gint'Image (H));
      end if;
      --  Invalidate cache: font change may alter wrapping at same width.
      C.Cache_Width_Px := 0;
      Recompute_Vis_Lines (C);
      Queue_Draw (C);
   end Invalidate_Layout;

end Coyote_GUI.Conversation;
