--  Coyote_GUI.Tool_Detail_Window — structured GTK tool-call details.
--
--  Opens an independent, transient window for one tool call.  The caller
--  supplies all data captured by the conversation renderer; active calls are
--  shown as snapshots with an explicit running status.
--
--  Project: coyote

with Ada.Strings.Unbounded;
with Gtk.Window;

package Coyote_GUI.Tool_Detail_Window is

   --  False means the parent/session no longer owns the captured result.
   type Image_Handler is access function
     (Parent : Gtk.Window.Gtk_Window; Binding : Natural;
      Data : Ada.Strings.Unbounded.Unbounded_String;
      Media_Type : String) return Boolean;

   --  Show a modeless co-primary snapshot of Info, transient for Main_Window.
   --  Metadata and actions remain fixed; arguments and result scroll in
   --  separate resizable panes. Each window remains independent until closed.
   --  Call only on the GTK main task.
   procedure Show
     (Info        : Coyote_GUI.Tool_Info;
      Main_Window : not null access Gtk.Window.Gtk_Window_Record'Class;
      On_Add_Image : Image_Handler := null;
      Binding : Natural := 0);

end Coyote_GUI.Tool_Detail_Window;
