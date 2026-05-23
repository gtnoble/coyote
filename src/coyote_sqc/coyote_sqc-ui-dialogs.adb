--  Coyote_SQC.UI.Dialogs body.
--
--  Project: coyote

with Glib;                   use Glib;
with Gtk.Box;
with Gtk.Dialog;             use Gtk.Dialog;
with Gtk.Label;
with Gtk.Message_Dialog;
with Gtk.Widget;

package body Coyote_SQC.UI.Dialogs is

   --  Helper: run a dialog and get the response.
   function Run_Dialog (D : Gtk.Dialog.Gtk_Dialog) return Gtk_Response_Type is
      Ignore : Gtk.Widget.Gtk_Widget;
      pragma Unreferenced (Ignore);
   begin
      D.Show_All;
      return D.Run;
   end Run_Dialog;

   function Confirm
     (Parent  : Gtk.Window.Gtk_Window;
      Title   : String;
      Message : String) return Boolean
   is
      D   : Gtk.Message_Dialog.Gtk_Message_Dialog;
      Res : Gtk_Response_Type;
   begin
      Gtk.Message_Dialog.Gtk_New
        (D,
         Parent   => Parent,
         Flags    => Gtk.Dialog.Modal,
         The_Type => Gtk.Message_Dialog.Message_Question,
         Buttons  => Gtk.Message_Dialog.Buttons_Ok_Cancel,
         Message  => Message);
      D.Set_Title (Title);
      Res := Run_Dialog (Gtk.Dialog.Gtk_Dialog (D));
      D.Destroy;
      return Res = Gtk_Response_OK;
   end Confirm;

   function Unsaved_Changes
     (Parent         : Gtk.Window.Gtk_Window;
      Workspace_Name : String) return Dialog_Response
   is
      D    : Gtk.Dialog.Gtk_Dialog;
      Res  : Gtk_Response_Type;
      Lbl  : Gtk.Label.Gtk_Label;
      Dummy : Gtk.Widget.Gtk_Widget;
      pragma Unreferenced (Dummy);
   begin
      Gtk.Dialog.Gtk_New (D, "Unsaved Changes", Parent, Gtk.Dialog.Modal);
      Gtk.Label.Gtk_New (Lbl, "Save changes to workspace '"
                         & Workspace_Name & "'?");
      D.Get_Content_Area.Pack_Start (Lbl, True, True, 8);
      Dummy := D.Add_Button ("_Save",    Gtk_Response_OK);
      Dummy := D.Add_Button ("_Discard", Gtk_Response_Apply);
      Dummy := D.Add_Button ("_Cancel",  Gtk_Response_Cancel);
      Res := Run_Dialog (D);
      D.Destroy;
      if Res = Gtk_Response_OK then
         return Response_OK;
      elsif Res = Gtk_Response_Apply then
         return Response_Other;
      else
         return Response_Cancel;
      end if;
   end Unsaved_Changes;

   procedure Info
     (Parent  : Gtk.Window.Gtk_Window;
      Title   : String;
      Message : String)
   is
      D   : Gtk.Message_Dialog.Gtk_Message_Dialog;
      Dummy : Gtk_Response_Type;
      pragma Unreferenced (Dummy);
   begin
      Gtk.Message_Dialog.Gtk_New
        (D,
         Parent   => Parent,
         Flags    => Gtk.Dialog.Modal,
         The_Type => Gtk.Message_Dialog.Message_Info,
         Buttons  => Gtk.Message_Dialog.Buttons_OK,
         Message  => Message);
      D.Set_Title (Title);
      Dummy := Run_Dialog (Gtk.Dialog.Gtk_Dialog (D));
      D.Destroy;
   end Info;

   procedure Error
     (Parent  : Gtk.Window.Gtk_Window;
      Title   : String;
      Message : String)
   is
      D     : Gtk.Message_Dialog.Gtk_Message_Dialog;
      Dummy : Gtk_Response_Type;
      pragma Unreferenced (Dummy);
   begin
      Gtk.Message_Dialog.Gtk_New
        (D,
         Parent   => Parent,
         Flags    => Gtk.Dialog.Modal,
         The_Type => Gtk.Message_Dialog.Message_Error,
         Buttons  => Gtk.Message_Dialog.Buttons_OK,
         Message  => Message);
      D.Set_Title (Title);
      Dummy := Run_Dialog (Gtk.Dialog.Gtk_Dialog (D));
      D.Destroy;
   end Error;

end Coyote_SQC.UI.Dialogs;
