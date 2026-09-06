--  Coyote_GUI.Session_Stats_Window — live GTK session statistics support window.
--
--  The window is modeless, transient for the main GUI window, and reused
--  across repeated Session Stats commands.  All operations are called on the
--  GTK main-loop thread.
--
--  Project: coyote

with Coyote_GUI;
with Gtk.Label;
with Gtk.Window;

package Coyote_GUI.Session_Stats_Window is

   type Instance is private;

   --  Initialise the reusable support window for Main_Window.
   procedure Create
     (S           : in out Instance;
      Main_Window : not null access Gtk.Window.Gtk_Window_Record'Class);

   --  Return True after the support window has been constructed.
   function Is_Created (S : Instance) return Boolean;

   --  Show the support window, raising an existing instance when necessary.
   procedure Show
     (S : in out Instance);

   --  Update the live report with the current statistics snapshot.
   procedure Update
     (S     : in out Instance;
      Stats :  Coyote_GUI.Session_Stats_Record);

   --  Return the most recently received statistics snapshot.
   function Current_Stats
     (S : Instance) return Coyote_GUI.Session_Stats_Record;

   --  Clear the report when the active session changes.
   procedure Clear
     (S : in out Instance);

private

   type Instance is record
      Window       : Gtk.Window.Gtk_Window;
      Session_Id   : Gtk.Label.Gtk_Label;
      Model        : Gtk.Label.Gtk_Label;
      Turn_Count   : Gtk.Label.Gtk_Label;
      Last_Input   : Gtk.Label.Gtk_Label;
      Last_Output  : Gtk.Label.Gtk_Label;
      Last_Cost    : Gtk.Label.Gtk_Label;
      Input        : Gtk.Label.Gtk_Label;
      Cache_Read   : Gtk.Label.Gtk_Label;
      Cache_Write  : Gtk.Label.Gtk_Label;
      Output       : Gtk.Label.Gtk_Label;
      Cost         : Gtk.Label.Gtk_Label;
      Stats        : Coyote_GUI.Session_Stats_Record;
      Created      : Boolean := False;
   end record;

end Coyote_GUI.Session_Stats_Window;
