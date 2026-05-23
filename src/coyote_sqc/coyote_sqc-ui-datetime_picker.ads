--  Coyote_SQC.UI.Datetime_Picker — composite date/time picker widget.
--
--  A GtkEntry showing "YYYY-MM-DD HH:MM" with a popover containing a
--  GtkCalendar and two GtkSpinButtons for hours and minutes.
--
--  Project: coyote

with Ada.Calendar;
with Gtk.Box;
with Gtk.Calendar;
with Gtk.GEntry;
with Gtk.Popover;
with Gtk.Spin_Button;
with Gtk.Widget;

package Coyote_SQC.UI.Datetime_Picker is

   type Changed_Callback is access procedure (T : Ada.Calendar.Time);

   type Instance is tagged limited private;
   type Instance_Access is access all Instance;

   --  Create a new picker and add it to Container.
   procedure Create
     (Self      : out Instance;
      Container : not null access Gtk.Box.Gtk_Box_Record'Class;
      Label     : String := "");

   function  Get_Time  (Self : Instance) return Ada.Calendar.Time;
   procedure Set_Time  (Self : in out Instance; T : Ada.Calendar.Time);
   procedure On_Changed (Self : in out Instance; CB : Changed_Callback);

   --  Return the GtkEntry widget for embedding in toolbars.
   function Widget (Self : Instance) return Gtk.Widget.Gtk_Widget;

private
   type Instance is tagged limited record
      Entry_W  : Gtk.GEntry.Gtk_Entry;
      Popover  : Gtk.Popover.Gtk_Popover;
      Calendar : Gtk.Calendar.Gtk_Calendar;
      Hour_Spin: Gtk.Spin_Button.Gtk_Spin_Button;
      Min_Spin : Gtk.Spin_Button.Gtk_Spin_Button;
      Current  : Ada.Calendar.Time;
      Callback : Changed_Callback := null;
      Updating : Boolean := False;
   end record;

end Coyote_SQC.UI.Datetime_Picker;
