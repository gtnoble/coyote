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
with Coyote_Lasem;
with Glib;                           use Glib;
with Pango;
with Pango.Attributes;
with Gdk.Event;
with Gdk.Types;
with Gdk.Types.Keysyms;
with GNATCOLL.JSON;
with Gtk.Adjustment;
with Gtk.Clipboard;
with Gtk.Layout;
with Gtk.Menu;
with Gtk.Menu_Item;
with Gtk.Selection_Data;
with Gtk.Menu_Shell;
with Gtk.Scrolled_Window;
with Gtk.Settings;
with Glib.Properties;
with Gtk.Widget;
with Interfaces.C;                   use Interfaces.C;
with Coyote_GUI.Navigation;
with Interfaces.C.Strings;
with Pango.Cairo;
with Pango.Enums;                    use Pango.Enums;
with Pango.Layout;                   use Pango.Layout;
with Pango.Font;
with System;                         use System;

package body Coyote_GUI.Conversation is

   use type Gdk.Event.Gdk_Event_Type;
   use type Gdk.Event.Gdk_Event_Mask;
   use type Gdk.Types.Gdk_Modifier_Type;
   use type GNATCOLL.JSON.JSON_Value_Type;
   use type Interfaces.C.Strings.chars_ptr;

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

   procedure Append_Math_Line
     (C : in out Instance; Source : String);

   procedure Invalidate_Line (C : in out Instance; Index : Positive);


   procedure Recompute_Vis_Lines
     (C : in out Instance; Force : Boolean := False);

   procedure Hit_Test
     (C            : in out Instance;
      X, Y         : Glib.Gint;
      Logical_Idx  : out Natural;
      Byte_Offset  : out Natural;
      Trailing     : out Glib.Gint);

   procedure Queue_Draw (C : in out Instance);

   procedure Draw_Rounded_Rectangle
     (Cr     : Cairo.Cairo_Context;
      X      : Gdouble;
      Y      : Gdouble;
      Width  : Gdouble;
      Height : Gdouble;
      Radius : Gdouble);

   procedure Draw_Tool_Background
     (Cr     : Cairo.Cairo_Context;
      Width  : Glib.Gint;
      Y      : Glib.Gint;
      Height : Glib.Gint;
      Style   : Line_Style;
      Status  : Tool_End_Status;
      Running : Boolean;
      Hover   : Boolean;
      Text    : String);

   procedure Copy_Selection_To_Clipboard (C : in out Instance);

   procedure Apply_Keyboard_Scroll
     (C    : in out Instance;
      Move : Coyote_GUI.Navigation.Movement);

   function Is_Interactive_Line (C : Instance; Index : Positive) return Boolean;

   function Interactive_Line_At
     (C     : Instance;
      Start : Positive;
      Step  : Integer) return Natural;

   procedure Ordered_Selection
     (C          : Instance;
      Start_Line : out Natural;
      Start_Byte : out Natural;
      End_Line   : out Natural;
      End_Byte   : out Natural);

   function Extract_Selection_Text (C : Instance) return String;

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
      C.Cache_Dirty := True;
      Debug_Log (C, "Append_Line style=" & Line_Style'Image (Style)
                 & " len=" & Natural'Image (Text'Length)
                 & " total=" & Natural'Image (Natural (C.Lines.Length)));
   end Append_Line;

   --  ── Append_Markup_Line ────────────────────────────────────────────────

   function Heading_Size_Attr (Style : Line_Style) return String is
   begin
      case Style is
         when Heading_1 =>
            return " size=""xx-large""";
         when Heading_2 =>
            return " size=""x-large""";
         when Heading_3 =>
            return " size=""large""";
         when Heading_4 =>
            return " size=""medium""";
         when others =>
            return "";
      end case;
   end Heading_Size_Attr;

   procedure Append_Markup_Line
     (C : in out Instance; Style : Line_Style; Text : String)
   is
      L      : Logical_Line (Style);
      Markup : Unbounded_String;
   begin
      case Style is
         when Heading_1 | Heading_2 | Heading_3
            | Heading_4 | Heading_5 | Heading_6 =>
            Markup := To_Unbounded_String ("<span weight=""bold""");
            Append (Markup, Heading_Size_Attr (Style));
            Append (Markup, ">");
            Append (Markup, Text);
            Append (Markup, "</span>");
            L.Text := Markup;
         when others =>
            L.Text := To_Unbounded_String (Sanitize_UTF8 (Text));
      end case;
      L.Has_Markup := True;
      C.Lines.Append (L);
      C.Cache_Dirty := True;
      Debug_Log (C, "Append_Markup_Line style=" & Line_Style'Image (Style)
                 & " len=" & Natural'Image (Text'Length)
                 & " total=" & Natural'Image (Natural (C.Lines.Length)));
   end Append_Markup_Line;
   procedure Invalidate_Line (C : in out Instance; Index : Positive) is
   begin
      C.Lines (Index).Vis_Count    := 0;
      C.Lines (Index).Pixel_Height := 0;
      C.Cache_Dirty := True;
   end Invalidate_Line;

   function MathML_Source (Source : String) return String is
      --  The extractor stores delimiter lines with the source so that
      --  selection and fallback preserve the original response.  Lasem
      --  receives only the inner MathML document.
      First_Content : constant Natural := Source'First + 3;
      Last_Content  : constant Natural := Source'Last - 2;
   begin
      if Source'Length <= 5 then
         return "";
      end if;
      return Source (First_Content .. Last_Content);
   end MathML_Source;

   procedure Append_Math_Line
     (C : in out Instance; Source : String)
   is
      MathML : constant String := MathML_Source (Source);
      C_Text : constant Interfaces.C.char_array :=
        Interfaces.C.To_C (MathML, Append_Nul => True);
      Width    : aliased Interfaces.C.unsigned := 0;
      Height   : aliased Interfaces.C.unsigned := 0;
      Baseline : aliased Interfaces.C.unsigned := 0;
      Error    : Interfaces.C.Strings.chars_ptr;
      L        : Logical_Line (Display_Math);
   begin
      Error := Coyote_Lasem.Measure_MathML
        (C_Text, Interfaces.C.long (MathML'Length),
         Width'Access, Height'Access, Baseline'Access,
         Interfaces.C.double (C.Math_Scale));
      if Error /= Interfaces.C.Strings.Null_Ptr then
         Debug_Log
           (C, "MathML parse failed: "
            & Interfaces.C.Strings.Value (Error));
         Coyote_Lasem.Free_Error (Error);
         Append_Line (C, Plain, Source);
         return;
      end if;

      L.Text          := To_Unbounded_String (Sanitize_UTF8 (Source));
      L.Pixel_Height  := Natural'Max (1, Natural (Height));
      L.Math_Width    := Natural (Width);
      L.Math_Baseline := Natural (Baseline);
      if C.Line_Height_Px > 0 then
         L.Vis_Count := Natural'Max
           (1,
            (L.Pixel_Height + Natural (C.Line_Height_Px) - 1)
            / Natural (C.Line_Height_Px));
      else
         L.Vis_Count := 1;
      end if;
      C.Lines.Append (L);
      C.Cache_Dirty := True;
   end Append_Math_Line;

   --  ── Draw_Rounded_Rectangle ───────────────────────────────────────────

   procedure Draw_Rounded_Rectangle
     (Cr     : Cairo_Context;
      X      : Gdouble;
      Y      : Gdouble;
      Width  : Gdouble;
      Height : Gdouble;
      Radius : Gdouble)
   is
      R  : constant Gdouble := Gdouble'Min
        (Radius, Gdouble'Min (Width / 2.0, Height / 2.0));
      Pi : constant Gdouble := 3.14159265358979323846;
   begin
      Move_To (Cr, X + R, Y);
      Line_To (Cr, X + Width - R, Y);
      Arc (Cr, X + Width - R, Y + R, R, -Pi / 2.0, 0.0);
      Line_To (Cr, X + Width, Y + Height - R);
      Arc (Cr, X + Width - R, Y + Height - R, R, 0.0, Pi / 2.0);
      Line_To (Cr, X + R, Y + Height);
      Arc (Cr, X + R, Y + Height - R, R, Pi / 2.0, Pi);
      Line_To (Cr, X, Y + R);
      Arc (Cr, X + R, Y + R, R, Pi, 3.0 * Pi / 2.0);
      Close_Path (Cr);
   end Draw_Rounded_Rectangle;

   --  ── Draw_Tool_Background ──────────────────────────────────────────────

   procedure Draw_Tool_Background
     (Cr     : Cairo_Context;
      Width  : Glib.Gint;
      Y      : Glib.Gint;
      Height : Glib.Gint;
      Style   : Line_Style;
      Status  : Tool_End_Status;
      Running : Boolean;
      Hover   : Boolean;
      Text    : String)
   is
      pragma Unreferenced (Text);
      Card_X   : constant Gdouble := 8.0;
      Card_W   : constant Gdouble := Gdouble (Width) - 16.0;
      Card_Y   : constant Gdouble := Gdouble (Y) + 1.0;
      Card_H   : constant Gdouble := Gdouble (Height) - 2.0;
      Radius   : constant Gdouble :=
        (if Style = Tool_Argument then 1.5 else 6.0);
      Accent_R : Gdouble := 0.35;
      Accent_G : Gdouble := 0.55;
      Accent_B : Gdouble := 0.85;
      Fill_R   : Gdouble := 0.96;
      Fill_G   : Gdouble := 0.97;
      Fill_B   : Gdouble := 0.99;
   begin
      if Running then
         Accent_R := 0.25;
         Accent_G := 0.47;
         Accent_B := 0.78;
         Fill_R   := 0.94;
         Fill_G   := 0.97;
         Fill_B   := 1.0;
      else
         case Status is
         when Success =>
            Accent_R := 0.20;
            Accent_G := 0.58;
            Accent_B := 0.35;
            Fill_R   := 0.94;
            Fill_G   := 0.98;
            Fill_B   := 0.95;
         when Error =>
            Accent_R := 0.78;
            Accent_G := 0.22;
            Accent_B := 0.22;
            Fill_R   := 1.0;
            Fill_G   := 0.95;
            Fill_B   := 0.95;
         when Cancelled =>
            Accent_R := 0.43;
            Accent_G := 0.47;
            Accent_B := 0.52;
            Fill_R   := 0.95;
            Fill_G   := 0.96;
            Fill_B   := 0.97;
         end case;
      end if;

      if Hover then
         Fill_R := Gdouble'Min (1.0, Fill_R + 0.035);
         Fill_G := Gdouble'Min (1.0, Fill_G + 0.035);
         Fill_B := Gdouble'Min (1.0, Fill_B + 0.035);
      elsif Style = Tool_Footer then
         Fill_R := Fill_R + (1.0 - Fill_R) * 0.35;
         Fill_G := Fill_G + (1.0 - Fill_G) * 0.35;
         Fill_B := Fill_B + (1.0 - Fill_B) * 0.35;
      end if;

      Draw_Rounded_Rectangle (Cr, Card_X, Card_Y, Card_W, Card_H, Radius);
      Set_Source_Rgb (Cr, Fill_R, Fill_G, Fill_B);
      Fill (Cr);

      Draw_Rounded_Rectangle (Cr, Card_X, Card_Y, Card_W, Card_H, Radius);
      Set_Source_Rgba (Cr, Accent_R, Accent_G, Accent_B, 0.34);
      Set_Line_Width (Cr, 1.0);
      Stroke (Cr);

      Set_Source_Rgb (Cr, Accent_R, Accent_G, Accent_B);
      Rectangle (Cr, Card_X, Card_Y, 4.0, Card_H);
      Fill (Cr);
   end Draw_Tool_Background;

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

   --  Measure every dirty (or all, on width change) logical line and
   --  store Pixel_Height / Vis_Count.  Document height is the sum of
   --  Pixel_Height, not a multiple of Line_Height_Px.

   function Fallback_Height (C : Instance) return Natural is
   begin
      if C.Line_Height_Px > 0 then
         return Natural (C.Line_Height_Px);
      end if;
      return 1;
   end Fallback_Height;

   procedure Prepare_Measure_Layout
     (C        : in out Instance;
      Index    :        Positive;
      Width_Px :        Glib.Gint)
   is
      Layout : Pango_Layout renames C.Measure_Layout;
      Text   : constant String := To_String (C.Lines (Index).Text);
   begin
      if C.Lines (Index).Has_Markup then
         Layout.Set_Markup (Text);
      else
         --  Clear stale markup attributes left by Set_Markup,
         --  including when the preceding line was cached.
         Layout.Set_Attributes
           (Pango.Attributes.Null_Pango_Attr_List);
         Layout.Set_Text (Text);
      end if;
      Layout.Set_Width (Width_Px * Pango_Scale);
      Layout.Set_Wrap (Pango_Wrap_Word_Char);
   end Prepare_Measure_Layout;

   procedure Measure_Line
     (C        : in out Instance;
      Index    :        Positive;
      Width_Px :        Glib.Gint)
   is
      Layout : Pango_Layout renames C.Measure_Layout;
      Vis    : Natural;
      H      : Natural;
   begin
      if C.Lines (Index).Style = Display_Math then
         H := C.Lines (Index).Pixel_Height;
         if H = 0 then
            H := Fallback_Height (C);
            C.Lines (Index).Pixel_Height := H;
         end if;
         Vis := Natural'Max
           (1, (H + Fallback_Height (C) - 1) / Fallback_Height (C));
         C.Lines (Index).Vis_Count := Vis;
         return;
      end if;

      Prepare_Measure_Layout (C, Index, Width_Px);
      declare
         Unused_W : Glib.Gint;
         Pixel_H  : Glib.Gint;
      begin
         Layout.Get_Pixel_Size (Unused_W, Pixel_H);
         if Pixel_H <= 0 then
            H := Fallback_Height (C);
         else
            H := Natural (Pixel_H);
         end if;
      end;
      Vis := Natural (Layout.Get_Line_Count);
      if Vis = 0 then
         Vis := 1;
      end if;
      C.Lines (Index).Pixel_Height := H;
      C.Lines (Index).Vis_Count    := Vis;
   end Measure_Line;

   function Line_Needs_Measure
     (C              : Instance;
      Index          : Positive;
      Full_Recompute : Boolean) return Boolean
   is
   begin
      if C.Lines (Index).Style = Display_Math then
         return C.Lines (Index).Pixel_Height = 0
           or else C.Lines (Index).Vis_Count = 0;
      end if;
      return Full_Recompute
        or else C.Lines (Index).Pixel_Height = 0
        or else C.Lines (Index).Vis_Count = 0;
   end Line_Needs_Measure;

   procedure Recompute_Vis_Lines
     (C : in out Instance; Force : Boolean := False)
   is
      Width_Px : constant Glib.Gint := C.Layout_W.Get_Allocated_Width;
      Total_Vis : Natural := 0;
      Total_Px  : Natural := 0;
   begin
      if Width_Px <= 0 or else C.Lines.Is_Empty then
         C.Total_Vis_Lines := 0;
         C.Total_Height_Px := 0;
         Debug_Log (C, "Recompute_Vis_Lines skip width="
                    & Glib.Gint'Image (Width_Px)
                    & " empty=" & Boolean'Image (C.Lines.Is_Empty));
         return;
      end if;

      --  Cache hit: width, line count, and all line contents unchanged.
      if not Force
        and then Width_Px = C.Cache_Width_Px
        and then Natural (C.Lines.Length) = C.Cached_Line_Count
        and then not C.Cache_Dirty
        and then C.Total_Height_Px > 0
      then
         Debug_Log
           (C,
            "Recompute_Vis_Lines skip cache hit width="
            & Glib.Gint'Image (Width_Px));
         return;
      end if;

      declare
         Full_Recompute : constant Boolean :=
           Force or else Width_Px /= C.Cache_Width_Px;
      begin
         for I in 1 .. Positive (C.Lines.Length) loop
            if Line_Needs_Measure (C, I, Full_Recompute) then
               Measure_Line (C, I, Width_Px);
            end if;
            Total_Vis := Total_Vis + C.Lines (I).Vis_Count;
            Total_Px  := Total_Px  + C.Lines (I).Pixel_Height;
         end loop;
      end;

      C.Total_Vis_Lines := Total_Vis;
      C.Total_Height_Px := Total_Px;

      Debug_Log (C, "Recompute_Vis_Lines logical="
                 & Natural'Image (Natural (C.Lines.Length))
                 & " visual=" & Natural'Image (Total_Vis)
                 & " height_px=" & Natural'Image (Total_Px)
                 & " line_h=" & Glib.Gint'Image (C.Line_Height_Px));

      --  Tell the GtkLayout the total scrollable area so it can position
      --  its bin window correctly and drive the shared adjustments.
      C.Layout_W.Set_Size
        (Glib.Guint (Width_Px),
         Glib.Guint (Total_Px));

      --  Update scrollbar range.
      declare
         Adj       : constant Gtk.Adjustment.Gtk_Adjustment :=
           C.Scroll.Get_Vadjustment;
         Doc_H     : constant Gdouble := Gdouble (Total_Px);
         Page_H    : constant Gdouble := Adj.Get_Page_Size;
         New_Upper : constant Gdouble := Gdouble'Max (Doc_H, Page_H);
      begin
         Adj.Set_Upper (New_Upper);
      end;
      C.Cache_Width_Px    := Width_Px;
      C.Cached_Line_Count := Natural (C.Lines.Length);
      C.Cache_Dirty       := False;
   end Recompute_Vis_Lines;
   --  ── Hit_Test ──────────────────────────────────────────────────────────

   procedure Hit_Test
     (C            : in out Instance;
      X, Y         : Glib.Gint;
      Logical_Idx  : out Natural;
      Byte_Offset  : out Natural;
      Trailing     : out Glib.Gint)
   is
      Width_Px : constant Glib.Gint := C.Layout_W.Get_Allocated_Width;
      --  Y is widget-relative (the layout's coordinate system already
      --  accounts for the scroll offset), so we use it directly.
      Target_Y : constant Natural := Natural (Glib.Gint'Max (Y, 0));
      Y_Off    : Natural := 0;
      Found    : Boolean := False;
   begin
      Logical_Idx := 0;
      Byte_Offset := 0;
      Trailing    := 0;

      if Width_Px <= 0 or else C.Lines.Is_Empty then
         return;
      end if;

      for I in 1 .. Positive (C.Lines.Length) loop
         declare
            Block_H : constant Natural :=
              (if C.Lines (I).Pixel_Height > 0
               then C.Lines (I).Pixel_Height
               else Fallback_Height (C));
         begin
            if Target_Y < Y_Off + Block_H then
               Logical_Idx := I;
               if C.Lines (I).Style = Display_Math then
                  Byte_Offset := 0;
                  Trailing    := 0;
               else
                  Prepare_Measure_Layout (C, I, Width_Px);
                  declare
                     Rel_Y : constant Glib.Gint :=
                       Glib.Gint (Target_Y - Y_Off);
                     Idx   : Glib.Gint;
                     Trl   : Glib.Gint;
                     Exact : Boolean;
                     pragma Unreferenced (Exact);
                  begin
                     C.Measure_Layout.Xy_To_Index
                       (X * Pango_Scale, Rel_Y * Pango_Scale,
                        Idx, Trl, Exact);
                     Byte_Offset := Natural (Idx);
                     Trailing    := Trl;
                  end;
               end if;
               Found := True;
               exit;
            end if;
            Y_Off := Y_Off + Block_H;
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
      declare
         Settings : constant Gtk.Settings.Gtk_Settings :=
           Gtk.Settings.Get_Default;
      begin
         C.Dark_Theme := Glib.Properties.Get_Property
           (Settings,
            Gtk.Settings.Gtk_Application_Prefer_Dark_Theme_Property);
      end;

      --  Event mask: button press, release, motion, key press, scroll.
      --  Scroll events are enabled so the frontend's Ctrl+wheel zoom
      --  handler (connected on the layout) receives them.
      Layout_W.Set_Events
        (Gdk.Event.Button_Press_Mask
         or Gdk.Event.Button_Release_Mask
         or Gdk.Event.Pointer_Motion_Mask
         or Gdk.Event.Key_Press_Mask
         or Gdk.Event.Scroll_Mask);
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

      --  Compute initial line height from the widget's default font, and
      --  create reusable layout objects so we never allocate PangoLayout
      --  per line during measurement or drawing.
      C.Measure_Layout := Layout_W.Create_Pango_Layout ("X");
      declare
         W, H : Glib.Gint;
      begin
         C.Measure_Layout.Get_Pixel_Size (W, H);
         if H > 0 then
            C.Line_Height_Px := H;
         end if;
      end;
      C.Draw_Layout := Layout_W.Create_Pango_Layout ("");
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

      Gtk.Menu_Item.Gtk_New (Item, "Copy");
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
         Current_Conv.Copy_Selection;
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

      Width_Px   : constant Glib.Gint :=
        Current_Conv.Layout_W.Get_Allocated_Width;
      Adj        : constant Gtk.Adjustment.Gtk_Adjustment :=
        Current_Conv.Scroll.Get_Vadjustment;
      Scroll_Y   : constant Glib.Gint := Glib.Gint (Adj.Get_Value);
      Alloc_H    : constant Glib.Gint :=
        Current_Conv.Layout_W.Get_Allocated_Height;
      Doc_Y      : Glib.Gint := 0;
      Y_Off      : Glib.Gint := -Scroll_Y;
   begin
      if Current_Conv = null or else Width_Px <= 0
        or else Current_Conv.Lines.Is_Empty
      then
         return False;
      end if;
      --  Use a neutral palette that remains readable in both GTK theme modes.
      if Current_Conv.Dark_Theme then
         Set_Source_Rgb (Cr, 0.12, 0.12, 0.14);
      else
         Set_Source_Rgb (Cr, 1.0, 1.0, 1.0);
      end if;
      Rectangle
        (Cr, 0.0, 0.0,
         Gdouble (Width_Px), Gdouble (Alloc_H));
      Fill (Cr);

      --  Walk logical lines, drawing only those whose pixel boxes
      --  intersect the visible viewport.
      Current_Conv.Debug_Log
        ("On_Draw logical="
         & Natural'Image (Natural (Current_Conv.Lines.Length))
         & " scroll_y=" & Glib.Gint'Image (Scroll_Y)
         & " height_px="
         & Natural'Image (Current_Conv.Total_Height_Px));
      for I in 1 .. Positive (Current_Conv.Lines.Length) loop
         declare
            L       : constant Logical_Line := Current_Conv.Lines (I);
            Text    : constant String := To_String (L.Text);
            Block_H : constant Glib.Gint :=
              Glib.Gint
                (if L.Pixel_Height > 0
                 then L.Pixel_Height
                 else Fallback_Height (Current_Conv.all));
         begin
            --  Skip if entirely above viewport.
            if Doc_Y + Block_H <= Scroll_Y then
               Doc_Y := Doc_Y + Block_H;
               Y_Off := Y_Off + Block_H;
               goto Continue;
            end if;

            --  Stop if entirely below viewport.
            if Y_Off >= Alloc_H then
               exit;
            end if;
            --  Reuse the draw layout for visible lines.
            declare
               Layout : Pango_Layout renames Current_Conv.Draw_Layout;
            begin
               if L.Has_Markup then
                  Layout.Set_Markup (Text);
               else
                  Layout.Set_Text (Text);
               end if;
               Layout.Set_Width (Width_Px * Pango_Scale);
               Layout.Set_Wrap (Pango_Wrap_Word_Char);

               --  Draw background for this logical line's pixel box.
               declare
               begin
                  case L.Style is
                     when Tool_Header | Tool_Argument | Tool_Footer =>
                        Draw_Tool_Background
                          (Cr, Width_Px, Y_Off, Block_H, L.Style,
                           L.Tool_Status, L.Tool_Running,
                           (Current_Conv.Hover_Tool_First > 0
                           and then I >= Current_Conv.Hover_Tool_First
                           and then I <= Current_Conv.Hover_Tool_Last)
                           or else I = Current_Conv.Interactive_Focus,
                           Text);
                     when Thinking =>
                        if Current_Conv.Dark_Theme then
                           Set_Source_Rgba (Cr, 0.20, 0.18, 0.12, 1.0);
                        else
                           Set_Source_Rgba (Cr, 1.0, 0.99, 0.91, 1.0);
                        end if;
                        Rectangle
                          (Cr, 0.0, Gdouble (Y_Off),
                           Gdouble (Width_Px), Gdouble (Block_H));
                        Fill (Cr);
                     when Notice_Info =>
                        if Current_Conv.Dark_Theme then
                           Set_Source_Rgba (Cr, 0.12, 0.18, 0.28, 1.0);
                        else
                           Set_Source_Rgba (Cr, 0.91, 0.94, 1.0, 1.0);
                        end if;
                        Rectangle
                          (Cr, 0.0, Gdouble (Y_Off),
                           Gdouble (Width_Px), Gdouble (Block_H));
                        Fill (Cr);
                     when Code_Block =>
                        if Current_Conv.Dark_Theme then
                           Set_Source_Rgba (Cr, 0.18, 0.18, 0.20, 1.0);
                        else
                           Set_Source_Rgba (Cr, 0.96, 0.96, 0.96, 1.0);
                        end if;
                        Rectangle
                          (Cr, 0.0, Gdouble (Y_Off),
                           Gdouble (Width_Px), Gdouble (Block_H));
                        Fill (Cr);
                     when Blockquote =>
                        --  Left border bar.
                        if Current_Conv.Dark_Theme then
                           Set_Source_Rgba (Cr, 0.55, 0.58, 0.64, 0.75);
                        else
                           Set_Source_Rgba (Cr, 0.6, 0.6, 0.6, 0.5);
                        end if;
                        Rectangle
                          (Cr, 0.0, Gdouble (Y_Off),
                           4.0, Gdouble (Block_H));
                        Fill (Cr);
                     when Display_Math =>
                        if Current_Conv.Dark_Theme then
                           Set_Source_Rgba (Cr, 0.16, 0.14, 0.22, 1.0);
                        else
                           Set_Source_Rgba (Cr, 0.97, 0.96, 1.0, 1.0);
                        end if;
                        Rectangle
                          (Cr, 0.0, Gdouble (Y_Off),
                           Gdouble (Width_Px), Gdouble (Block_H));
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

               --  Draw selection highlight if this line intersects
               --  selection.  Endpoints may be inverted while the
               --  user is dragging upward or leftward; order them
               --  before comparing.
               declare
                  Ord_Start_Line : Natural;
                  Ord_Start_Byte : Natural;
                  Ord_End_Line   : Natural;
                  Ord_End_Byte   : Natural;
               begin
                  Ordered_Selection
                    (Current_Conv.all,
                     Ord_Start_Line, Ord_Start_Byte,
                     Ord_End_Line, Ord_End_Byte);
                  if Current_Conv.Sel_Visible
                    and then I >= Ord_Start_Line
                    and then I <= Ord_End_Line
                  then
                     declare
                        Sel_Start : constant Natural :=
                          (if I = Ord_Start_Line
                           then Ord_Start_Byte
                           else 0);
                        Sel_End   : constant Natural :=
                          (if I = Ord_End_Line
                           then Ord_End_Byte
                           else Text'Length);
                     begin
                        if Sel_Start < Sel_End then
                           declare
                              R1, R2 : Pango.Pango_Rectangle;
                              Scale  : constant Gdouble :=
                                Gdouble (Pango_Scale);
                              Y1     : Gdouble;
                              Y2     : Gdouble;
                              X1     : Gdouble;
                              X2     : Gdouble;
                           begin
                              Layout.Index_To_Pos
                                (Glib.Gint (Sel_Start), R1);
                              Layout.Index_To_Pos
                                (Glib.Gint (Sel_End), R2);
                              Set_Source_Rgba
                                (Cr, 0.3, 0.5, 0.9, 0.3);
                              Y1 := Gdouble (Y_Off)
                                + Gdouble (R1.Y) / Scale;
                              Y2 := Gdouble (Y_Off)
                                + Gdouble (R2.Y + R2.Height) / Scale;
                              if R1.Y = R2.Y then
                                 --  Same visual row: one tight
                                 --  rectangle.
                                 X1 := Gdouble (R1.X) / Scale;
                                 X2 := Gdouble (R2.X) / Scale;
                                 if X2 < X1 then
                                    declare
                                       Tmp : constant Gdouble := X1;
                                    begin
                                       X1 := X2;
                                       X2 := Tmp;
                                    end;
                                 end if;
                                 Rectangle
                                   (Cr, X1, Y1, X2 - X1, Y2 - Y1);
                                 Fill (Cr);
                              else
                                 --  Multi-row: start glyph to the
                                 --  right edge, full middle rows,
                                 --  then the last row to the end
                                 --  glyph.
                                 Rectangle
                                   (Cr,
                                    Gdouble (R1.X) / Scale,
                                    Y1,
                                    Gdouble (Width_Px)
                                      - Gdouble (R1.X) / Scale,
                                    Gdouble (R1.Height) / Scale);
                                 Fill (Cr);
                                 if Y2
                                   - (Y1 + Gdouble (R1.Height)
                                      / Scale)
                                   > Gdouble (R2.Height)
                                   / Scale + 0.5
                                 then
                                    Rectangle
                                      (Cr,
                                       0.0,
                                       Y1 + Gdouble (R1.Height)
                                         / Scale,
                                       Gdouble (Width_Px),
                                       (Y2 - Gdouble (R2.Height)
                                          / Scale)
                                         - (Y1 + Gdouble
                                              (R1.Height)
                                            / Scale));
                                    Fill (Cr);
                                 end if;
                                 Rectangle
                                   (Cr,
                                    0.0,
                                    Y2 - Gdouble (R2.Height)
                                      / Scale,
                                    Gdouble (R2.X) / Scale,
                                    Gdouble (R2.Height) / Scale);
                                 Fill (Cr);
                              end if;
                           end;
                        end if;
                     end;
                  end if;
               end;

               --  Set text colour and font weight by style.
               case L.Style is
                  when Thinking | Notice_Info | Plain
                     | List_Item_Bullet | List_Item_Ordered
                     | Tool_Header | Tool_Argument | Tool_Footer =>
                     if Current_Conv.Dark_Theme then
                        Set_Source_Rgb (Cr, 0.94, 0.94, 0.96);
                     else
                        Set_Source_Rgb (Cr, 0.0, 0.0, 0.0);
                     end if;
                  when Heading_1 | Heading_2 =>
                     if Current_Conv.Dark_Theme then
                        Set_Source_Rgb (Cr, 0.96, 0.96, 0.98);
                     else
                        Set_Source_Rgb (Cr, 0.0, 0.0, 0.0);
                     end if;
                  when Heading_3 | Heading_4 =>
                     if Current_Conv.Dark_Theme then
                        Set_Source_Rgb (Cr, 0.90, 0.90, 0.94);
                     else
                        Set_Source_Rgb (Cr, 0.0, 0.0, 0.0);
                     end if;
                  when Heading_5 | Heading_6 =>
                     if Current_Conv.Dark_Theme then
                        Set_Source_Rgb (Cr, 0.86, 0.86, 0.90);
                     else
                        Set_Source_Rgb (Cr, 0.0, 0.0, 0.0);
                     end if;
                  when Code_Block =>
                     if Current_Conv.Dark_Theme then
                        Set_Source_Rgb (Cr, 0.85, 0.85, 0.88);
                     else
                        Set_Source_Rgb (Cr, 0.2, 0.2, 0.2);
                     end if;
                  when Blockquote =>
                     if Current_Conv.Dark_Theme then
                        Set_Source_Rgb (Cr, 0.78, 0.80, 0.84);
                     else
                        Set_Source_Rgb (Cr, 0.3, 0.3, 0.3);
                     end if;
                  when Thematic_Break =>
                     Set_Source_Rgb (Cr, 0.6, 0.6, 0.6);
                  when Notice_Warn =>
                     if Current_Conv.Dark_Theme then
                        Set_Source_Rgb (Cr, 1.0, 0.75, 0.20);
                     else
                        Set_Source_Rgb (Cr, 0.54, 0.35, 0.0);
                     end if;
                  when Notice_Error =>
                     if Current_Conv.Dark_Theme then
                        Set_Source_Rgb (Cr, 1.0, 0.45, 0.45);
                     else
                        Set_Source_Rgb (Cr, 0.8, 0.2, 0.2);
                     end if;
                  when Footer =>
                     if Current_Conv.Dark_Theme then
                        Set_Source_Rgb (Cr, 0.53, 0.53, 0.53);
                     else
                        Set_Source_Rgb (Cr, 0.40, 0.40, 0.40);
                     end if;
                  when Action_Strip =>
                     if Current_Conv.Dark_Theme then
                        Set_Source_Rgb (Cr, 0.45, 0.75, 1.0);
                     else
                        Set_Source_Rgb (Cr, 0.13, 0.4, 0.67);
                     end if;
                  when Display_Math =>
                     if Current_Conv.Dark_Theme then
                        Set_Source_Rgb (Cr, 0.95, 0.95, 0.98);
                     else
                        Set_Source_Rgb (Cr, 0.0, 0.0, 0.0);
                     end if;
               end case;

               if L.Style = Display_Math then
                  declare
                     MathML : constant String := MathML_Source (Text);
                     C_Text : constant Interfaces.C.char_array :=
                       Interfaces.C.To_C (MathML, Append_Nul => True);
                     Error  : Interfaces.C.Strings.chars_ptr;
                     Math_X : constant Gdouble :=
                       Gdouble'Max
                         (0.0,
                          (Gdouble (Width_Px) - Gdouble (L.Math_Width))
                          / 2.0);
                  begin
                     Error := Coyote_Lasem.Render_MathML
                       (C_Text, Interfaces.C.long (MathML'Length), Cr,
                        Interfaces.C.double (Math_X), Interfaces.C.double (Y_Off),
                        Interfaces.C.double (Current_Conv.Math_Scale));
                     if Error /= Interfaces.C.Strings.Null_Ptr then
                        Current_Conv.Debug_Log
                          ("MathML render failed: "
                           & Interfaces.C.Strings.Value (Error));
                        Coyote_Lasem.Free_Error (Error);
                     end if;
                  end;
               else
                  --  Render the Pango layout at the current Y offset.
                  Move_To (Cr, 0.0, Gdouble (Y_Off));
                  Pango.Cairo.Show_Layout (Cr, Layout);
               end if;
            end;

            Doc_Y := Doc_Y + Block_H;
            Y_Off := Y_Off + Block_H;
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
               Current_Conv.Publish_Primary_Selection;
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
      if Current_Conv = null then
         return False;
      end if;

      declare
         Hover_Line : Natural;
         Hover_Byte : Natural;
         Hover_Trail : Glib.Gint;
         New_First  : Natural := 0;
         New_Last   : Natural := 0;
      begin
         Hit_Test (Current_Conv.all,
                   Glib.Gint (Event.X), Glib.Gint (Event.Y),
                   Hover_Line, Hover_Byte, Hover_Trail);
         for TB of Current_Conv.Tools loop
            if Hover_Line >= TB.First_Line and then Hover_Line <= TB.Last_Line then
               New_First := TB.First_Line;
               New_Last := TB.Last_Line;
               exit;
            end if;
         end loop;
         if New_First /= Current_Conv.Hover_Tool_First
           or else New_Last /= Current_Conv.Hover_Tool_Last
         then
            Current_Conv.Hover_Tool_First := New_First;
            Current_Conv.Hover_Tool_Last := New_Last;
            Queue_Draw (Current_Conv.all);
         end if;
      end;

      if not Current_Conv.Sel_Dragging then
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
            Current_Conv.Publish_Primary_Selection;
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
         --  Normalize selection (start < end) so later copy and
         --  highlight walks see a document-ordered range.
         declare
            Ord_Start_Line : Natural;
            Ord_Start_Byte : Natural;
            Ord_End_Line   : Natural;
            Ord_End_Byte   : Natural;
         begin
            Ordered_Selection
              (Current_Conv.all,
               Ord_Start_Line, Ord_Start_Byte,
               Ord_End_Line, Ord_End_Byte);
            Current_Conv.Sel_Start_Line := Ord_Start_Line;
            Current_Conv.Sel_Start_Byte := Ord_Start_Byte;
            Current_Conv.Sel_End_Line   := Ord_End_Line;
            Current_Conv.Sel_End_Byte   := Ord_End_Byte;
         end;
         --  Stop dragging; the highlight stays visible until the
         --  next click or Escape clears it.
         Current_Conv.Sel_Dragging := False;
         Queue_Draw (Current_Conv.all);
      end if;
      return False;
   end On_Button_Release;

   procedure Apply_Keyboard_Scroll
     (C    : in out Instance;
      Move : Coyote_GUI.Navigation.Movement)
   is
      Adj : constant Gtk.Adjustment.Gtk_Adjustment := C.Scroll.Get_Vadjustment;
      Target : constant Glib.Gdouble :=
        Coyote_GUI.Navigation.Target_Value
          (Current   => Adj.Get_Value,
           Lower     => Adj.Get_Lower,
           Upper     => Adj.Get_Upper,
           Page_Size => Adj.Get_Page_Size,
           Line_Size => Glib.Gdouble'Max
             (Glib.Gdouble (C.Line_Height_Px), 1.0),
           Move      => Move);
   begin
      Adj.Set_Value (Target);
   end Apply_Keyboard_Scroll;

   function Is_Interactive_Line (C : Instance; Index : Positive) return Boolean is
   begin
      return C.Lines (Index).Style in Tool_Header | Action_Strip;
   end Is_Interactive_Line;

   function Interactive_Line_At
     (C     : Instance;
      Start : Positive;
      Step  : Integer) return Natural
   is
      Index : Integer := Integer (Start);
   begin
      while Index >= C.Lines.First_Index
        and then Index <= C.Lines.Last_Index
      loop
         if Is_Interactive_Line (C, Positive (Index)) then
            return Natural (Index);
         end if;
         Index := Index + Step;
      end loop;
      return 0;
   end Interactive_Line_At;

   procedure Move_Interactive_Focus
     (C       : in out Instance;
      Forward :        Boolean := True)
   is
      Start : Positive := 1;
      Step  : constant Integer := (if Forward then 1 else -1);
      Found : Natural;
   begin
      if C.Lines.Is_Empty then
         C.Interactive_Focus := 0;
         return;
      end if;
      if C.Interactive_Focus > 0 then
         Start := Positive (C.Interactive_Focus);
         if Forward then
            if Start < C.Lines.Last_Index then
               Start := Start + 1;
            else
               Start := C.Lines.First_Index;
            end if;
         elsif Start > C.Lines.First_Index then
            Start := Start - 1;
         else
            Start := C.Lines.Last_Index;
         end if;
      elsif not Forward then
         Start := C.Lines.Last_Index;
      end if;
      Found := Interactive_Line_At (C, Start, Step);
      if Found = 0 then
         Found := Interactive_Line_At
           (C, (if Forward then C.Lines.First_Index else C.Lines.Last_Index), Step);
      end if;
      C.Interactive_Focus := Found;
      Queue_Draw (C);
   end Move_Interactive_Focus;

   function Focused_Tool (C : Instance) return Tool_Click_Result is
   begin
      if C.Interactive_Focus = 0 then
         return (Found => False);
      end if;
      for TB of C.Tools loop
         if C.Interactive_Focus >= TB.First_Line
           and then C.Interactive_Focus <= TB.Last_Line
         then
            return (Found => True, Info => TB.Info);
         end if;
      end loop;
      return (Found => False);
   end Focused_Tool;

   function Focused_Action (C : Instance) return Action_Click_Result is
   begin
      if C.Interactive_Focus > 0
        and then C.Interactive_Focus <= C.Lines.Last_Index
        and then C.Lines (C.Interactive_Focus).Style = Action_Strip
      then
         return
           (Found  => True,
            Action => C.Lines (C.Interactive_Focus).Action);
      end if;
      return (Found => False);
   end Focused_Action;

   function Transcript_Text (C : Instance) return String is
      Result : Unbounded_String;
   begin
      if C.Lines.Is_Empty then
         return "";
      end if;
      for I in C.Lines.First_Index .. C.Lines.Last_Index loop
         if I > C.Lines.First_Index then
            Append (Result, ASCII.LF);
         end if;
         Append (Result, Strip_Pango_Markup (To_String (C.Lines (I).Text)));
      end loop;
      return To_String (Result);
   end Transcript_Text;

   function Selected_Text (C : Instance) return String is
   begin
      return Extract_Selection_Text (C);
   end Selected_Text;

   function Has_Selection (C : Instance) return Boolean is
   begin
      return C.Sel_Visible;
   end Has_Selection;

   procedure Select_All (C : in out Instance) is
   begin
      if C.Lines.Is_Empty then
         return;
      end if;
      C.Sel_Visible    := True;
      C.Sel_Start_Line := 1;
      C.Sel_Start_Byte := 0;
      C.Sel_End_Line   := Positive (C.Lines.Length);
      C.Sel_End_Byte   := Natural (Length
        (C.Lines (Positive (C.Lines.Length)).Text));
      C.Publish_Primary_Selection;
      Queue_Draw (C);
   end Select_All;

   procedure Clear_Selection (C : in out Instance) is
   begin
      if not C.Sel_Visible then
         return;
      end if;
      C.Sel_Visible := False;
      C.Publish_Primary_Selection;
      Queue_Draw (C);
   end Clear_Selection;

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
         Current_Conv.Copy_Selection;
         return True;
      end if;

      --  Ctrl+A: select all.
      if Event.Keyval = Gdk.Types.Keysyms.GDK_LC_a
        and then (Event.State and Gdk.Types.Control_Mask) /= 0
      then
         Current_Conv.Select_All;
         return True;
      end if;

      --  Escape clears a selection; otherwise it reaches the window Stop
      --  accelerator so Escape has a predictable global meaning.
      if Event.Keyval = Gdk.Types.Keysyms.GDK_Escape then
         if Current_Conv.Has_Selection then
            Current_Conv.Clear_Selection;
            return True;
         end if;
         return False;
      end if;

      --  Tab and Shift+Tab traverse custom tool/action controls.
      if Event.Keyval = Gdk.Types.Keysyms.GDK_Tab then
         Move_Interactive_Focus
           (Current_Conv.all,
            Forward => (Event.State and Gdk.Types.Shift_Mask) = 0);
         return True;
      end if;

      --  Enter and Space activate the focused custom control.  The frontend
      --  click handler is also connected to this widget and observes focus.
      if Event.Keyval in Gdk.Types.Keysyms.GDK_Return
         | Gdk.Types.Keysyms.GDK_KP_Enter
         | Gdk.Types.Keysyms.GDK_space
      then
         --  The frontend callback performs the action side effect.
         return False;
      end if;

      --  Vi-style and conventional viewport navigation.
      if (Event.State and Gdk.Types.Control_Mask) /= 0 then
         if Event.Keyval = Gdk.Types.Keysyms.GDK_LC_d then
            Apply_Keyboard_Scroll (Current_Conv.all, Coyote_GUI.Navigation.Page_Down);
            return True;
         elsif Event.Keyval = Gdk.Types.Keysyms.GDK_LC_u then
            Apply_Keyboard_Scroll (Current_Conv.all, Coyote_GUI.Navigation.Page_Up);
            return True;
         end if;
      elsif Event.Keyval = Gdk.Types.Keysyms.GDK_LC_j then
         Apply_Keyboard_Scroll (Current_Conv.all, Coyote_GUI.Navigation.Line_Down);
         return True;
      elsif Event.Keyval = Gdk.Types.Keysyms.GDK_LC_k then
         Apply_Keyboard_Scroll (Current_Conv.all, Coyote_GUI.Navigation.Line_Up);
         return True;
      elsif Event.Keyval = Gdk.Types.Keysyms.GDK_LC_g
        and then (Event.State and Gdk.Types.Shift_Mask) = 0
      then
         Apply_Keyboard_Scroll (Current_Conv.all, Coyote_GUI.Navigation.To_Top);
         return True;
      elsif Event.Keyval = Gdk.Types.Keysyms.GDK_LC_g
        and then (Event.State and Gdk.Types.Shift_Mask) /= 0
      then
         Apply_Keyboard_Scroll (Current_Conv.all, Coyote_GUI.Navigation.To_Bottom);
         return True;
      elsif Event.Keyval = Gdk.Types.Keysyms.GDK_Home then
         Apply_Keyboard_Scroll (Current_Conv.all, Coyote_GUI.Navigation.To_Top);
         return True;
      elsif Event.Keyval = Gdk.Types.Keysyms.GDK_End then
         Apply_Keyboard_Scroll (Current_Conv.all, Coyote_GUI.Navigation.To_Bottom);
         return True;
      elsif Event.Keyval = Gdk.Types.Keysyms.GDK_Page_Up then
         Apply_Keyboard_Scroll (Current_Conv.all, Coyote_GUI.Navigation.Page_Up);
         return True;
      elsif Event.Keyval = Gdk.Types.Keysyms.GDK_Page_Down then
         Apply_Keyboard_Scroll (Current_Conv.all, Coyote_GUI.Navigation.Page_Down);
         return True;
      end if;

      return False;
   end On_Key_Press;

   function Extract_Selection_Text (C : Instance) return String is
      Text : Unbounded_String;
   begin
      if not C.Sel_Visible
        or else C.Sel_Start_Line = 0
        or else C.Sel_End_Line = 0
      then
         return "";
      end if;

      declare
         Start_Line : Natural;
         Start_Byte : Natural;
         End_Line   : Natural;
         End_Byte   : Natural;
      begin
         Ordered_Selection
           (C, Start_Line, Start_Byte, End_Line, End_Byte);
         for I in Start_Line .. End_Line loop
            if I <= Positive (C.Lines.Length) then
               declare
                  Raw_Text  : constant String :=
                    To_String (C.Lines (I).Text);
                  Line_Text : constant String :=
                    (if C.Lines (I).Has_Markup
                     then Strip_Pango_Markup (Raw_Text)
                     else Raw_Text);
                  S_Byte    : constant Natural :=
                    (if I = Start_Line then Start_Byte else 0);
                  E_Byte    : constant Natural :=
                    (if I = End_Line
                     then Natural'Min (End_Byte, Line_Text'Length)
                     else Line_Text'Length);
               begin
                  if S_Byte < E_Byte
                    and then S_Byte <= Line_Text'Length
                  then
                     if Length (Text) > 0 then
                        Append (Text, ASCII.LF);
                     end if;
                     Append
                       (Text,
                        Line_Text
                          (Line_Text'First + S_Byte
                           .. Line_Text'First + E_Byte - 1));
                  end if;
               end;
            end if;
         end loop;
      end;
      return To_String (Text);
   end Extract_Selection_Text;

   procedure Publish_Primary_Selection (C : in out Instance) is
      use Gtk.Clipboard;
      Primary : constant Gtk_Clipboard :=
        Get (Gtk.Selection_Data.Selection_Primary);
      Text : constant String := Extract_Selection_Text (C);
   begin
      if Text'Length > 0 then
         Primary.Set_Text (Text);
         C.Primary_Owner := True;
      elsif C.Primary_Owner then
         Primary.Clear;
         C.Primary_Owner := False;
      end if;
   end Publish_Primary_Selection;

   --  ── Copy_Selection_To_Clipboard ────────────────────────────────────────

   procedure Copy_Selection_To_Clipboard (C : in out Instance) is
      use Gtk.Clipboard;
      Text : constant String := Extract_Selection_Text (C);
   begin
      if Text'Length > 0 then
         Get.Set_Text (Text);
      end if;
   end Copy_Selection_To_Clipboard;

   procedure Copy_Selection (C : in out Instance) is
   begin
      Copy_Selection_To_Clipboard (C);
   end Copy_Selection;

   --  ── Ordered_Selection ─────────────────────────────────────────────────

   procedure Ordered_Selection
     (C          : Instance;
      Start_Line : out Natural;
      Start_Byte : out Natural;
      End_Line   : out Natural;
      End_Byte   : out Natural)
   is
      Inverted : constant Boolean :=
        C.Sel_Start_Line > C.Sel_End_Line
        or else (C.Sel_Start_Line = C.Sel_End_Line
                 and then C.Sel_Start_Byte > C.Sel_End_Byte);
   begin
      if Inverted then
         Start_Line := C.Sel_End_Line;
         Start_Byte := C.Sel_End_Byte;
         End_Line   := C.Sel_Start_Line;
         End_Byte   := C.Sel_Start_Byte;
      else
         Start_Line := C.Sel_Start_Line;
         Start_Byte := C.Sel_Start_Byte;
         End_Line   := C.Sel_End_Line;
         End_Byte   := C.Sel_End_Byte;
      end if;
   end Ordered_Selection;

   --  ── Streaming text ────────────────────────────────────────────────────

   procedure Append_Text (C : in out Instance; Text : String) is
      Ready : Unbounded_String;
   begin
      if not C.In_Text_Block then
         C.In_Text_Block    := True;
         C.Stream_Buf       := Null_Unbounded_String;
         Append_Line (C, Plain, "");
         C.Stream_First_Line := Natural (C.Lines.Length);
         C.Text_UTF8.Reset;
      end if;
      Append (C.Stream_Buf, Text);
      C.Text_UTF8.Feed (Text, Ready);

      if Length (Ready) > 0 then
         declare
            Ready_Text : constant String := To_String (Ready);
            Start      : Natural := Ready_Text'First;
            Last_Idx   : Positive := Positive (C.Lines.Length);
         begin
            for I in Ready_Text'Range loop
               if Ready_Text (I) = ASCII.LF then
                  if I > Start then
                     Invalidate_Line (C, Last_Idx);
                     Append (C.Lines (Last_Idx).Text,
                             Ready_Text (Start .. I - 1));
                  end if;
                  Append_Line (C, Plain, "");
                  Last_Idx := Positive (C.Lines.Length);
                  Start    := I + 1;
               end if;
            end loop;
            if Start <= Ready_Text'Last then
               Invalidate_Line (C, Last_Idx);
               Append (C.Lines (Last_Idx).Text,
                       Ready_Text (Start .. Ready_Text'Last));
            end if;
         end;
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
      package Math_Source_Vectors is new Ada.Containers.Vectors
        (Positive, Unbounded_String);

      Math_Sources : Math_Source_Vectors.Vector;
      Masked_Text  : Unbounded_String;
      Math_Open    : Boolean := False;
      Math_Delim   : Unbounded_String;
      Math_Buffer  : Unbounded_String;

      procedure Append_Masked_Line (Line : String) is
      begin
         Append (Masked_Text, Line);
         Append (Masked_Text, ASCII.LF);
      end Append_Masked_Line;

      procedure Extract_Display_Math is
         Start : Natural := Full_Text'First;
      begin
         if Full_Text'Length = 0 then
            return;
         end if;

         for I in Full_Text'Range loop
            if Full_Text (I) = ASCII.LF
              or else I = Full_Text'Last
            then
               declare
                  Last : constant Natural :=
                    (if Full_Text (I) = ASCII.LF then I - 1 else I);
                  Line : constant String :=
                    (if Last >= Start then Full_Text (Start .. Last) else "");
                  Trimmed : constant String :=
                    Ada.Strings.Fixed.Trim (Line, Ada.Strings.Both);
               begin
                  if not Math_Open and then Trimmed = "$$" then
                     Math_Open := True;
                     Math_Delim := To_Unbounded_String (Trimmed);
                     Math_Buffer := Null_Unbounded_String;
                  elsif Math_Open
                    and then To_String (Math_Delim) = "$$"
                    and then Trimmed = "$$"
                  then
                     if Length (Math_Buffer) > 0 then
                        declare
                           Source : Unbounded_String := Math_Delim;
                        begin
                           Append (Source, ASCII.LF);
                           Append (Source, Math_Buffer);
                           Append (Source, Trimmed);
                           Math_Sources.Append (Source);
                        end;
                        Append_Masked_Line
                          ("COYOTE_MATH_BLOCK_"
                           & Ada.Strings.Fixed.Trim
                               (Natural'Image
                                  (Natural (Math_Sources.Length)),
                                Ada.Strings.Both)
                           & "__");
                     end if;
                     Math_Open := False;
                     Math_Delim := Null_Unbounded_String;
                     Math_Buffer := Null_Unbounded_String;
                  elsif Math_Open then
                     Append (Math_Buffer, Line);
                     Append (Math_Buffer, ASCII.LF);
                  else
                     Append_Masked_Line (Line);
                  end if;
               end;
               Start := I + 1;
            end if;
         end loop;

         if Math_Open then
            --  An unmatched delimiter is not math.  Preserve the complete
            --  source as plain Markdown rather than discarding content.
            Append_Masked_Line (To_String (Math_Delim));
            Append (Masked_Text, To_String (Math_Buffer));
         end if;
      end Extract_Display_Math;

      function Math_Index (Text : String) return Natural is
      begin
         for I in 1 .. Natural (Math_Sources.Length) loop
            declare
               Token : constant String :=
                 "COYOTE_MATH_BLOCK_"
                 & Ada.Strings.Fixed.Trim
                     (Natural'Image (I), Ada.Strings.Both)
                 & "__";
            begin
               if Text = Token then
                  return I;
               end if;
            end;
         end loop;
         return 0;
      end Math_Index;

      Doc    : Node_Ptr;
      It     : Iter_Ptr;
      Ev     : Event_Type_Int;
      Node   : Node_Ptr;

      --  Paragraph inline-accumulation state
      In_Para      : Boolean := False;
      Para_Buf     : Unbounded_String;
      Para_Empty   : Boolean := True;
      Math_Source  : Unbounded_String;
      In_List_Item : Boolean := False;

      --  List nesting state
      type Level_T is range 0 .. 7;
      List_Counter  : array (Level_T) of Integer := (others => 0);
      List_Is_Bullet : array (Level_T) of Boolean := (others => True);
      List_Depth    : Natural := 0;

      function List_Indent (Depth : Natural) return String is
      begin
         if Depth <= 1 then
            return "";
         end if;
         return Str_Repeat ("  ", Depth - 1);
      end List_Indent;

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
            if Length (Math_Source) > 0 then
               Append_Math_Line (C, To_String (Math_Source));
               Math_Source := Null_Unbounded_String;
            else
               Append_Markup_Line (C, Plain, To_String (Para_Buf));
            end if;
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

      Extract_Display_Math;
      declare
         C_Text : constant Interfaces.C.char_array :=
           Interfaces.C.To_C (To_String (Masked_Text), Append_Nul => True);
      begin
         Doc := Parse_Document
           (C_Text, C_Text'Length - 1, OPT_DEFAULT);
      end;
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
                     List_Counter (Level_T (List_Depth)) :=
                       Integer (Node_Get_List_Start (Node)) - 1;
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
                        Append (Prefix, List_Indent (List_Depth));
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
                  declare
                     Literal : constant String := Lit (Node);
                     Index   : constant Natural := Math_Index (Literal);
                  begin
                     if Index > 0 and then In_Para then
                        Math_Source := Math_Sources (Index);
                        Para_Empty := False;
                     elsif In_Cell then
                        Cell_Append (Literal);
                     elsif In_Para then
                        Append (Para_Buf, Xml_Escape (Literal));
                        Para_Empty := False;
                     end if;
                  end;
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
      Full_Text : constant String := Sanitize_UTF8 (To_String (C.Stream_Buf));
      Ignored   : Unbounded_String;
   begin
      if not C.In_Text_Block then
         return;
      end if;
      C.Text_UTF8.Flush (Ignored);

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
      C.Thinking_UTF8.Reset;
      C.Thinking_Tok.Reset;
   end Begin_Thinking;

   procedure Append_Thinking (C : in out Instance; Text : String) is
      Decoded   : Unbounded_String;
      Tokenized : Ada.Strings.Unbounded.Unbounded_String;
   begin
      C.Thinking_UTF8.Feed (Text, Decoded);
      C.Thinking_Tok.Feed (To_String (Decoded), Tokenized);
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
               Invalidate_Line (C, Last_Idx);
               Append (C.Lines (Last_Idx).Text, Sanitize_UTF8 (Proc));
            end;
         end if;
      end;
      Recompute_Vis_Lines (C);
      Queue_Draw (C);
   end Append_Thinking;

   procedure End_Thinking (C : in out Instance) is
      use Ada.Strings.Unbounded;
      Decoded   : Unbounded_String;
      Remaining : Unbounded_String;
      Tail      : Unbounded_String;
   begin
      C.Thinking_UTF8.Flush (Decoded);
      C.Thinking_Tok.Feed (To_String (Decoded), Remaining);
      C.Thinking_Tok.Flush (Tail);
      Append (Remaining, Tail);
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
                  Invalidate_Line (C, Last_Idx);
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
         C.Thinking_UTF8.Reset;
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
      declare
         First_Line : constant Positive := Positive (C.Lines.Length) + 1;
      begin
         Append_Line (C, Tool_Header,
                      UC_BOX_TL & " " & UC_GEAR & " " & Name);
         C.Lines (First_Line).Tool_Id := To_Unbounded_String (Tool_Id);

         --  Argument lines.
         if Args_Val.Kind = GNATCOLL.JSON.JSON_Object_Type then
            declare
               procedure Add_Arg_Line
                 (Field_Name  : GNATCOLL.JSON.UTF8_String;
                  Field_Value : GNATCOLL.JSON.JSON_Value)
               is
               begin
                  Append_Line (C, Tool_Argument,
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

         --  Store the exact footer line so interleaved tool completions can
         --  update their own placeholders.
         declare
            Footer_Line : constant Positive := Positive (C.Lines.Length) + 1;
         begin
            Append_Line (C, Tool_Footer,
                         UC_BOX_BL & " " & UC_ELLIP & " running" & UC_ELLIP);
            C.Lines (Footer_Line).Tool_Running := True;
            for I in First_Line .. Footer_Line loop
               C.Lines (I).Tool_Id := To_Unbounded_String (Tool_Id);
               C.Lines (I).Tool_Running := True;
            end loop;
            Append_Line (C, Plain, "");
            C.Tool_Starts.Include
              (Tool_Id,
               (First_Line  => First_Line,
                Footer_Line => Footer_Line,
                Name        => To_Unbounded_String (Name),
                Args        => To_Unbounded_String (Args)));
         end;
      end;

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
      Pos        : Cursor := C.Tool_Starts.Find (Tool_Id);
      Start_Info : Tool_Start_Info;
      First_Idx  : Positive;
   begin
      Debug_Log (C, "End_Tool tool_id=" & Tool_Id
                 & " status=" & Tool_End_Status'Image (Status));
      if Pos = No_Element then
         return;
      end if;
      Start_Info := Element (Pos);
      First_Idx  := Start_Info.First_Line;

      --  Replace the completed tool's own footer placeholder.
      if Start_Info.Footer_Line <= Positive (C.Lines.Length) then
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
            Invalidate_Line (C, Start_Info.Footer_Line);
            C.Lines (Start_Info.Footer_Line).Text := Replacement;
            C.Lines (Start_Info.Footer_Line).Tool_Status := Status;
            C.Lines (Start_Info.Footer_Line).Tool_Running := False;
            for I in Start_Info.First_Line .. Start_Info.Footer_Line loop
               C.Lines (I).Tool_Status := Status;
               C.Lines (I).Tool_Running := False;
            end loop;
         end;
      end if;

      --  Record a non-overlapping range for click handling.
      declare
         TB : Tool_Block;
      begin
         TB.First_Line := First_Idx;
         TB.Last_Line  := Start_Info.Footer_Line;
         TB.Info.Name  := Start_Info.Name;
         TB.Info.Args  := Start_Info.Args;
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
               Result.Info := TB.Info;
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

   --  ── Clear ───────────────────────────────────────────────────────────────

   procedure Clear (C : in out Instance) is
   begin
      C.Lines.Clear;
      C.Tools.Clear;
      C.Tool_Starts.Clear;
      C.In_Text_Block := False;
      C.Stream_Buf := Ada.Strings.Unbounded.Null_Unbounded_String;
      C.Text_UTF8.Reset;
      C.Stream_First_Line := 0;
      C.In_Thinking := False;
      C.Prefix_Emitted := False;
      C.Thinking_UTF8.Reset;
      C.Thinking_Tok.Reset;
      C.Sel_Dragging := False;
      C.Sel_Visible := False;
      Publish_Primary_Selection (C);
      C.Sel_Start_Line := 0;
      C.Sel_Start_Byte := 0;
      C.Sel_End_Line := 0;
      C.Sel_End_Byte := 0;
      C.Interactive_Focus := 0;
      C.Primary_Owner := False;
      C.Hover_Tool_First := 0;
      C.Hover_Tool_Last := 0;
      C.Cache_Width_Px := 0;
      C.Cached_Line_Count := 0;
      C.Cache_Dirty := True;
      C.Total_Vis_Lines := 0;
      C.Total_Height_Px := 0;
      --  Reset reusable layouts: stale attributes from Set_Markup would
      --  affect measurement of plain-text lines in the new session.
      C.Measure_Layout.Set_Text ("");
      C.Measure_Layout.Set_Attributes (Pango.Attributes.Null_Pango_Attr_List);
      C.Draw_Layout.Set_Text ("");
      Recompute_Vis_Lines (C);
      Queue_Draw (C);
   end Clear;

   --  ── Zoom ──────────────────────────────────────────────────────────────

   procedure Set_Font
     (C         : in out Instance;
      Desc      :        Pango.Font.Pango_Font_Description;
      Math_Scale :       Long_Float := 1.0)
   is
   begin
      C.Measure_Layout.Set_Font_Description (Desc);
      C.Draw_Layout.Set_Font_Description (Desc);
      C.Math_Scale := Long_Float'Max (Math_Scale, 0.01);

      if not C.Lines.Is_Empty then
         for I in 1 .. Positive (C.Lines.Length) loop
            if C.Lines (I).Style = Display_Math then
               declare
                  Source   : constant String :=
                    To_String (C.Lines (I).Text);
                  MathML   : constant String := MathML_Source (Source);
                  C_Text   : constant Interfaces.C.char_array :=
                    Interfaces.C.To_C (MathML, Append_Nul => True);
                  Width    : aliased Interfaces.C.unsigned := 0;
                  Height   : aliased Interfaces.C.unsigned := 0;
                  Baseline : aliased Interfaces.C.unsigned := 0;
                  Error    : Interfaces.C.Strings.chars_ptr;
               begin
                  Error := Coyote_Lasem.Measure_MathML
                    (C_Text, Interfaces.C.long (MathML'Length),
                     Width'Access, Height'Access, Baseline'Access,
                     Interfaces.C.double (C.Math_Scale));
                  if Error = Interfaces.C.Strings.Null_Ptr then
                     C.Lines (I).Pixel_Height := Natural (Height);
                     C.Lines (I).Math_Width := Natural (Width);
                     C.Lines (I).Math_Baseline := Natural (Baseline);
                  else
                     Debug_Log
                       (C, "MathML zoom remeasure failed: "
                        & Interfaces.C.Strings.Value (Error));
                     Coyote_Lasem.Free_Error (Error);
                  end if;
               end;
            end if;
            C.Lines (I).Vis_Count := 0;
            if C.Lines (I).Style /= Display_Math then
               C.Lines (I).Pixel_Height := 0;
            end if;
         end loop;
      end if;
      C.Cache_Dirty := True;
      Invalidate_Layout (C);
   end Set_Font;

   --  ── Invalidate_Layout ─────────────────────────────────────────────────

   procedure Invalidate_Layout (C : in out Instance) is
      Layout : Pango_Layout renames C.Measure_Layout;
      W, H   : Glib.Gint;
   begin
      Layout.Set_Text ("X");
      Layout.Get_Pixel_Size (W, H);
      if H > 0 then
         C.Line_Height_Px := H;
         Debug_Log
           (C, "Invalidate_Layout line_height_px=" & Glib.Gint'Image (H));
      end if;
      --  Invalidate cache: font change may alter wrapping at same width.
      C.Cache_Width_Px := 0;
      Recompute_Vis_Lines (C);
      Queue_Draw (C);
   end Invalidate_Layout;

end Coyote_GUI.Conversation;
