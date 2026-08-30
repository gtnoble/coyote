--  Coyote_App.Frontend.GUI.Testing — test-only widget accessors.
--
--  Project: coyote

with Gtk.Box;
with Gtk.Separator;
with Gtk.Window;

package Coyote_App.Frontend.GUI.Testing is

   function Main_Window
     (F : Coyote_App.Frontend.GUI.Instance)
      return Gtk.Window.Gtk_Window;

   function Outer_Box
     (F : Coyote_App.Frontend.GUI.Instance)
      return Gtk.Box.Gtk_Box;

   function Prompt_Box
     (F : Coyote_App.Frontend.GUI.Instance)
      return Gtk.Box.Gtk_Box;

   function Status_Box
     (F : Coyote_App.Frontend.GUI.Instance)
      return Gtk.Box.Gtk_Box;

   function Conversation_Prompt_Separator
     (F : Coyote_App.Frontend.GUI.Instance)
      return Gtk.Separator.Gtk_Separator;

   function Prompt_Status_Separator
     (F : Coyote_App.Frontend.GUI.Instance)
      return Gtk.Separator.Gtk_Separator;

end Coyote_App.Frontend.GUI.Testing;
