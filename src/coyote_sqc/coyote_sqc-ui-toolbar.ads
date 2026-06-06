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
   --  Update the Log Y checkbox to reflect State.Workspace.Log_Y_Mode.
   --  Called after the mode is toggled via the View menu item.
   procedure Sync_Log_Y_Button;
   --  Update the Edit Set B toggle to reflect State.Edit_Set_B_Mode.
   --  Called after the mode is cleared programmatically (e.g. by
   --  Clear Both Sets).
   procedure Sync_Edit_Set_B_Button;

end Coyote_SQC.UI.Toolbar;
