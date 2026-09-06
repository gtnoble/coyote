--  Coyote_GUI.Tool_Detail_Window — structured GTK tool-call details.
--
--  Opens an independent, transient window for one tool call.  The caller
--  supplies all data captured by the conversation renderer; active calls are
--  shown as snapshots with an explicit running status.
--
--  Project: coyote

with Coyote_GUI;
with Gtk.Window;

package Coyote_GUI.Tool_Detail_Window is

   --  Show a structured, non-modal detail window for Info.  The window is
   --  transient for Main_Window and remains open until closed by the user.
   procedure Show
     (Info        : in Coyote_GUI.Tool_Info;
      Main_Window : not null access Gtk.Window.Gtk_Window_Record'Class);

end Coyote_GUI.Tool_Detail_Window;
