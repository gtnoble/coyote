--  Coyote_SQC.UI.Toolbar — date range toolbar.
--
--  Project: coyote

with Ada.Calendar;
with Gtk.Box;

package Coyote_SQC.UI.Toolbar is

   --  Build the toolbar bar and add it to Container.
   procedure Build (Container : not null access Gtk.Box.Gtk_Box_Record'Class);

   --  Update the From/To pickers to reflect the current date range.
   --  Called during pan/zoom operations.
   procedure Sync_Pickers;
   --  Update the Run Sequence checkbox to reflect State.Run_Sequence_Mode.
   --  Called after the mode is toggled via the View menu item.
   procedure Sync_Run_Sequence_Button;

end Coyote_SQC.UI.Toolbar;
