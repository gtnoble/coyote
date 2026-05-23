--  Coyote_SQC.UI.Detail_Panel — session detail and multi-select panel.
--
--  Project: coyote

with Gtk.Box;

package Coyote_SQC.UI.Detail_Panel is

   --  Build and return the outer detail panel box.
   function Build return Gtk.Box.Gtk_Box;

   --  Refresh the detail panel contents to reflect the current selection.
   --  Call whenever App_State.Selection changes.
   procedure Refresh;

   --  Show or hide the detail panel via the Paned divider position.
   procedure Set_Visible (Visible : Boolean);

end Coyote_SQC.UI.Detail_Panel;
