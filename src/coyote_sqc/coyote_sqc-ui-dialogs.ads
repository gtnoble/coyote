--  Coyote_SQC.UI.Dialogs — confirmation and unsaved-changes dialogs.
--
--  Project: coyote

with Gtk.Window;

package Coyote_SQC.UI.Dialogs is

   type Dialog_Response is (Response_OK, Response_Cancel, Response_Other);

   --  Show a yes/no confirmation dialog.  Returns True if the user clicks OK.
   function Confirm
     (Parent  : Gtk.Window.Gtk_Window;
      Title   : String;
      Message : String) return Boolean;

   --  Unsaved-changes dialog: shows [Save] [Discard] [Cancel].
   --  Returns Response_OK (save), Response_Other (discard), Response_Cancel.
   function Unsaved_Changes
     (Parent         : Gtk.Window.Gtk_Window;
      Workspace_Name : String) return Dialog_Response;

   --  Show an informational message dialog.
   procedure Info
     (Parent  : Gtk.Window.Gtk_Window;
      Title   : String;
      Message : String);

   --  Show an error message dialog.
   procedure Error
     (Parent  : Gtk.Window.Gtk_Window;
      Title   : String;
      Message : String);

end Coyote_SQC.UI.Dialogs;
