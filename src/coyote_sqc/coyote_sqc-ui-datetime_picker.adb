--  Coyote_SQC.UI.Datetime_Picker body.
--
--  A composite widget: a GtkEntry displaying "YYYY-MM-DD HH:MM", with a
--  calendar icon that opens a GtkPopover containing a GtkCalendar and
--  two GtkSpinButtons for hours and minutes.
--
--  Project: coyote

with Ada.Calendar.Formatting;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Glib;                   use Glib;
with Gtk.Adjustment;
with Gtk.Box;
with Gtk.Enums;
with Gtk.Label;
with Gtk.Separator;
with Gtk.Widget;             use Gtk.Widget;

package body Coyote_SQC.UI.Datetime_Picker is

   use type Gtk.GEntry.Gtk_Entry;
   use type Gtk.Calendar.Gtk_Calendar;
   use type Gtk.Spin_Button.Gtk_Spin_Button;
   use type Gtk.Popover.Gtk_Popover;

   --  ── Registry ─────────────────────────────────────────────────────────
   --  Signal callbacks are bare access-to-procedure; they find their picker
   --  instance by searching this registry.

   Max_Reg : constant := 8;
   type Registry_Array is array (1 .. Max_Reg) of Instance_Access;
   Registry      : Registry_Array := (others => null);
   Registry_Size : Natural        := 0;

   procedure Register (P : Instance_Access) is
   begin
      if Registry_Size < Max_Reg then
         Registry_Size := Registry_Size + 1;
         Registry (Registry_Size) := P;
      end if;
   end Register;

   function Find_By_Entry
     (E : Gtk.GEntry.Gtk_Entry) return Instance_Access is
   begin
      for I in 1 .. Registry_Size loop
         if Registry (I) /= null and then Registry (I).Entry_W = E then
            return Registry (I);
         end if;
      end loop;
      return null;
   end Find_By_Entry;

   function Find_By_Calendar
     (C : Gtk.Calendar.Gtk_Calendar) return Instance_Access is
   begin
      for I in 1 .. Registry_Size loop
         if Registry (I) /= null and then Registry (I).Calendar = C then
            return Registry (I);
         end if;
      end loop;
      return null;
   end Find_By_Calendar;

   function Find_By_Spin
     (S : Gtk.Spin_Button.Gtk_Spin_Button) return Instance_Access is
   begin
      for I in 1 .. Registry_Size loop
         if Registry (I) /= null and then
            (Registry (I).Hour_Spin = S or else Registry (I).Min_Spin = S)
         then
            return Registry (I);
         end if;
      end loop;
      return null;
   end Find_By_Spin;

   --  ── Formatting helpers ────────────────────────────────────────────────

   function Pad2 (N : Natural) return String is
      use Ada.Strings.Fixed;
   begin
      return (if N < 10 then "0" else "")
             & Trim (Natural'Image (N), Ada.Strings.Left);
   end Pad2;

   function Format_Time (T : Ada.Calendar.Time) return String is
      use Ada.Calendar;
      Y  : constant Year_Number   := Year   (T);
      Mo : constant Month_Number  := Month  (T);
      D  : constant Day_Number    := Day    (T);
      H  : constant Ada.Calendar.Formatting.Hour_Number   :=
        Ada.Calendar.Formatting.Hour   (T);
      Mi : constant Ada.Calendar.Formatting.Minute_Number :=
        Ada.Calendar.Formatting.Minute (T);
   begin
      return Ada.Strings.Fixed.Trim (Natural'Image (Y), Ada.Strings.Left)
             & "-" & Pad2 (Natural (Mo))
             & "-" & Pad2 (Natural (D))
             & " " & Pad2 (Natural (H))
             & ":" & Pad2 (Natural (Mi));
   end Format_Time;

   --  ── Apply Time → Entry + Spinbuttons ──────────────────────────────────

   procedure Apply_Time (Self : in out Instance) is
      use Ada.Calendar;
      Y  : constant Year_Number   := Year   (Self.Current);
      Mo : constant Month_Number  := Month  (Self.Current);
      D  : constant Day_Number    := Day    (Self.Current);
      H  : constant Ada.Calendar.Formatting.Hour_Number   :=
        Ada.Calendar.Formatting.Hour   (Self.Current);
      Mi : constant Ada.Calendar.Formatting.Minute_Number :=
        Ada.Calendar.Formatting.Minute (Self.Current);
   begin
      Self.Updating := True;
      Self.Entry_W.Set_Text (Format_Time (Self.Current));
      if Self.Calendar /= null then
         Self.Calendar.Select_Month (Guint (Mo) - 1, Guint (Y));
         Self.Calendar.Select_Day   (Guint (D));
      end if;
      if Self.Hour_Spin /= null then
         Self.Hour_Spin.Set_Value (Gdouble (H));
      end if;
      if Self.Min_Spin /= null then
         Self.Min_Spin.Set_Value (Gdouble (Mi));
      end if;
      Self.Updating := False;
   end Apply_Time;

   --  ── Signal callbacks ──────────────────────────────────────────────────

   procedure On_Icon_Press
     (Self     : access Gtk.GEntry.Gtk_Entry_Record'Class;
      Icon_Pos : Gtk.GEntry.Gtk_Entry_Icon_Position)
   is
      pragma Unreferenced (Icon_Pos);
      P : constant Instance_Access :=
        Find_By_Entry (Gtk.GEntry.Gtk_Entry (Self));
   begin
      if P /= null and then P.Popover /= null then
         P.Popover.Show_All;
      end if;
   end On_Icon_Press;

   procedure On_Day_Selected
     (Self : access Gtk.Calendar.Gtk_Calendar_Record'Class)
   is
      use Ada.Calendar;
      P : constant Instance_Access :=
        Find_By_Calendar (Gtk.Calendar.Gtk_Calendar (Self));
   begin
      if P = null or else P.Updating then return; end if;
      declare
         Year_V  : Glib.Guint;
         Month_V : Glib.Guint;
         Day_V   : Glib.Guint;
         Old_H   : constant Ada.Calendar.Formatting.Hour_Number   :=
           Ada.Calendar.Formatting.Hour   (P.Current);
         Old_M   : constant Ada.Calendar.Formatting.Minute_Number :=
           Ada.Calendar.Formatting.Minute (P.Current);
      begin
         P.Calendar.Get_Date (Year_V, Month_V, Day_V);
         P.Current := Ada.Calendar.Formatting.Time_Of
           (Year   => Ada.Calendar.Year_Number   (Year_V),
            Month  => Ada.Calendar.Month_Number  (Month_V + 1),
            Day    => Ada.Calendar.Day_Number    (Day_V),
            Hour   => Old_H,
            Minute => Old_M,
            Second => 0);
         P.Updating := True;
         P.Entry_W.Set_Text (Format_Time (P.Current));
         P.Updating := False;
         if P.Callback /= null then
            P.Callback (P.Current);
         end if;
      end;
   end On_Day_Selected;

   procedure On_Spin_Value_Changed
     (Self : access Gtk.Spin_Button.Gtk_Spin_Button_Record'Class)
   is
      use Ada.Calendar;
      P : constant Instance_Access :=
        Find_By_Spin (Gtk.Spin_Button.Gtk_Spin_Button (Self));
   begin
      if P = null or else P.Updating then return; end if;
      declare
         H : constant Natural := Natural (P.Hour_Spin.Get_Value);
         M : constant Natural := Natural (P.Min_Spin.Get_Value);
      begin
         P.Current := Ada.Calendar.Formatting.Time_Of
           (Year   => Ada.Calendar.Year   (P.Current),
            Month  => Ada.Calendar.Month  (P.Current),
            Day    => Ada.Calendar.Day    (P.Current),
            Hour   => Ada.Calendar.Formatting.Hour_Number   (H),
            Minute => Ada.Calendar.Formatting.Minute_Number (M),
            Second => 0);
         P.Updating := True;
         P.Entry_W.Set_Text (Format_Time (P.Current));
         P.Updating := False;
         if P.Callback /= null then
            P.Callback (P.Current);
         end if;
      end;
   end On_Spin_Value_Changed;

   --  ── Create ────────────────────────────────────────────────────────────

   procedure Create
     (Self      : out Instance;
      Container : not null access Gtk.Box.Gtk_Box_Record'Class;
      Label     : String := "")
   is
      use Gtk.Box;
      use Gtk.GEntry;
      use Gtk.Calendar;
      use Gtk.Spin_Button;
      use Gtk.Separator;
      use Gtk.Popover;
      use Gtk.Label;
      use Gtk.Enums;

      Outer   : Gtk.Box.Gtk_Box;
      Lbl     : Gtk.Label.Gtk_Label;
      VBox    : Gtk.Box.Gtk_Box;
      HBox    : Gtk.Box.Gtk_Box;
      Sep     : Gtk.Separator.Gtk_Separator;
      Colon   : Gtk.Label.Gtk_Label;
      Adj_H   : Gtk.Adjustment.Gtk_Adjustment;
      Adj_M   : Gtk.Adjustment.Gtk_Adjustment;
   begin
      Self.Current  := Ada.Calendar.Clock;
      Self.Updating := False;
      Self.Callback := null;

      --  Entry widget.
      Gtk.GEntry.Gtk_New (Self.Entry_W);
      Self.Entry_W.Set_Width_Chars (16);
      Self.Entry_W.Set_Editable (False);
      Self.Entry_W.Set_Text (Format_Time (Self.Current));
      Self.Entry_W.Set_Icon_From_Icon_Name
        (Gtk.GEntry.Gtk_Entry_Icon_Primary, "x-office-calendar-symbolic");

      --  Popover.
      Gtk.Popover.Gtk_New (Self.Popover, Self.Entry_W);

      --  Popover content.
      Gtk.Box.Gtk_New_Vbox (VBox);
      VBox.Set_Border_Width (6);
      VBox.Set_Spacing (4);

      --  Calendar.
      Gtk.Calendar.Gtk_New (Self.Calendar);
      Self.Calendar.On_Day_Selected (On_Day_Selected'Access);
      VBox.Pack_Start (Self.Calendar, False, False, 0);

      --  Separator.
      Gtk.Separator.Gtk_New_Hseparator (Sep);
      VBox.Pack_Start (Sep, False, False, 4);

      --  Hour/minute spinners.
      Gtk.Box.Gtk_New_Hbox (HBox);
      HBox.Set_Spacing (4);

      Gtk.Adjustment.Gtk_New (Adj_H, 0.0, 0.0, 23.0, 1.0, 1.0, 0.0);
      Gtk.Adjustment.Gtk_New (Adj_M, 0.0, 0.0, 59.0, 1.0, 5.0, 0.0);
      Gtk.Spin_Button.Gtk_New (Self.Hour_Spin, Adj_H, 1.0, 0);
      Gtk.Spin_Button.Gtk_New (Self.Min_Spin,  Adj_M, 1.0, 0);
      Self.Hour_Spin.Set_Wrap (True);
      Self.Min_Spin.Set_Wrap  (True);
      Self.Hour_Spin.Set_Width_Chars (2);
      Self.Min_Spin.Set_Width_Chars  (2);
      Self.Hour_Spin.On_Value_Changed (On_Spin_Value_Changed'Access);
      Self.Min_Spin.On_Value_Changed  (On_Spin_Value_Changed'Access);

      Gtk.Label.Gtk_New (Colon, ":");
      HBox.Pack_Start (Self.Hour_Spin, False, False, 0);
      HBox.Pack_Start (Colon, False, False, 0);
      HBox.Pack_Start (Self.Min_Spin,  False, False, 0);
      VBox.Pack_Start (HBox, False, False, 0);

      Self.Popover.Add (VBox);

      --  Outer row: optional label + entry.
      Gtk.Box.Gtk_New_Hbox (Outer);
      Outer.Set_Spacing (4);
      if Label'Length > 0 then
         Gtk.Label.Gtk_New (Lbl, Label & ":");
         Outer.Pack_Start (Lbl, False, False, 0);
      end if;
      Outer.Pack_Start (Self.Entry_W, False, False, 0);
      Container.Pack_Start (Outer, False, False, 0);

      Self.Entry_W.On_Icon_Press (On_Icon_Press'Access);

      --  Set spinbutton values to match current time.
      Apply_Time (Self);

      --  Register for callback dispatch.
      Register (Self'Unchecked_Access);
   end Create;

   --  ── Public operations ─────────────────────────────────────────────────

   function Get_Time (Self : Instance) return Ada.Calendar.Time is
   begin
      return Self.Current;
   end Get_Time;

   procedure Set_Time (Self : in out Instance; T : Ada.Calendar.Time) is
   begin
      Self.Current := T;
      Apply_Time (Self);
   end Set_Time;

   procedure On_Changed (Self : in out Instance; CB : Changed_Callback) is
   begin
      Self.Callback := CB;
   end On_Changed;

   function Widget (Self : Instance) return Gtk.Widget.Gtk_Widget is
   begin
      return Gtk.Widget.Gtk_Widget (Self.Entry_W);
   end Widget;

end Coyote_SQC.UI.Datetime_Picker;
