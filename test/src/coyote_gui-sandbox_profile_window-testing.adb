--  Coyote_GUI.Sandbox_Profile_Window.Testing body.
--
--  Project: coyote

package body Coyote_GUI.Sandbox_Profile_Window.Testing is

   function Allow_Write_View
     (S : Coyote_GUI.Sandbox_Profile_Window.Instance)
      return Gtk.Tree_View.Gtk_Tree_View
   is
   begin
      return S.Allow_Write_View;
   end Allow_Write_View;

   function Deny_Write_View
     (S : Coyote_GUI.Sandbox_Profile_Window.Instance)
      return Gtk.Tree_View.Gtk_Tree_View
   is
   begin
      return S.Deny_Write_View;
   end Deny_Write_View;

   function Deny_Read_View
     (S : Coyote_GUI.Sandbox_Profile_Window.Instance)
      return Gtk.Tree_View.Gtk_Tree_View
   is
   begin
      return S.Deny_Read_View;
   end Deny_Read_View;

   function Allow_Read_View
     (S : Coyote_GUI.Sandbox_Profile_Window.Instance)
      return Gtk.Tree_View.Gtk_Tree_View
   is
   begin
      return S.Allow_Read_View;
   end Allow_Read_View;

   function Add_Path_Button
     (S : Coyote_GUI.Sandbox_Profile_Window.Instance)
      return Gtk.Button.Gtk_Button
   is
   begin
      return S.Add_Path_Button;
   end Add_Path_Button;

   function Edit_Path_Button
     (S : Coyote_GUI.Sandbox_Profile_Window.Instance)
      return Gtk.Button.Gtk_Button
   is
   begin
      return S.Edit_Path_Button;
   end Edit_Path_Button;

   function Remove_Path_Button
     (S : Coyote_GUI.Sandbox_Profile_Window.Instance)
      return Gtk.Button.Gtk_Button
   is
   begin
      return S.Remove_Path_Button;
   end Remove_Path_Button;

end Coyote_GUI.Sandbox_Profile_Window.Testing;
