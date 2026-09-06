--  Coyote_GUI.Sandbox_Profile_Window.Testing — test accessors.
--
--  Project: coyote

with Gtk.Button;
with Gtk.Tree_View;

package Coyote_GUI.Sandbox_Profile_Window.Testing is

   function Path_View
     (S : Coyote_GUI.Sandbox_Profile_Window.Instance)
      return Gtk.Tree_View.Gtk_Tree_View;

   function Add_Path_Button
     (S : Coyote_GUI.Sandbox_Profile_Window.Instance)
      return Gtk.Button.Gtk_Button;

   function Edit_Path_Button
     (S : Coyote_GUI.Sandbox_Profile_Window.Instance)
      return Gtk.Button.Gtk_Button;

   function Remove_Path_Button
     (S : Coyote_GUI.Sandbox_Profile_Window.Instance)
      return Gtk.Button.Gtk_Button;

end Coyote_GUI.Sandbox_Profile_Window.Testing;
