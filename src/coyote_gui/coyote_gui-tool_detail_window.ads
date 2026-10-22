--  Coyote_GUI.Tool_Detail_Window — structured GTK tool-call details.
--
--  Opens an independent, transient window for one tool call.  The caller
--  supplies all data captured by the conversation renderer; active calls are
--  shown as snapshots with an explicit running status.
--
--  Project: coyote

with Gtk.Window;

package Coyote_GUI.Tool_Detail_Window is

   --  Show a modeless co-primary snapshot of Info, transient for Main_Window.
   --  Metadata and actions remain fixed; arguments and result scroll in
   --  separate resizable panes. Each window remains independent until closed.
   --  Call only on the GTK main task.
   procedure Show
     (Info        : Coyote_GUI.Tool_Info;
      Main_Window : not null access Gtk.Window.Gtk_Window_Record'Class);

end Coyote_GUI.Tool_Detail_Window;
