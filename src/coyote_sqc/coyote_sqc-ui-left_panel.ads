--  Coyote_SQC.UI.Left_Panel — chart selector GtkListBox.
--
--  Project: coyote

with Gtk.Scrolled_Window;

package Coyote_SQC.UI.Left_Panel is

   --  Build the left-panel chart selector and return a scrolled window
   --  containing it.
   function Build return Gtk.Scrolled_Window.Gtk_Scrolled_Window;

   --  Highlight the currently active chart row.
   procedure Refresh_Selection;

end Coyote_SQC.UI.Left_Panel;
