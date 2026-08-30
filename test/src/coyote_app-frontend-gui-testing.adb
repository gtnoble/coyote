--  Coyote_App.Frontend.GUI.Testing — test-only widget accessors.
--
--  Project: coyote

package body Coyote_App.Frontend.GUI.Testing is

   function Main_Window
     (F : Coyote_App.Frontend.GUI.Instance)
      return Gtk.Window.Gtk_Window
   is
   begin
      return F.Win;
   end Main_Window;

   function Outer_Box
     (F : Coyote_App.Frontend.GUI.Instance)
      return Gtk.Box.Gtk_Box
   is
   begin
      return F.Outer_Box;
   end Outer_Box;

   function Prompt_Box
     (F : Coyote_App.Frontend.GUI.Instance)
      return Gtk.Box.Gtk_Box
   is
   begin
      return F.Prompt_Box;
   end Prompt_Box;

   function Status_Box
     (F : Coyote_App.Frontend.GUI.Instance)
      return Gtk.Box.Gtk_Box
   is
   begin
      return F.Status_Box;
   end Status_Box;

   function Conversation_Prompt_Separator
     (F : Coyote_App.Frontend.GUI.Instance)
      return Gtk.Separator.Gtk_Separator
   is
   begin
      return F.Conversation_Prompt_Sep;
   end Conversation_Prompt_Separator;

   function Prompt_Status_Separator
     (F : Coyote_App.Frontend.GUI.Instance)
      return Gtk.Separator.Gtk_Separator
   is
   begin
      return F.Prompt_Status_Sep;
   end Prompt_Status_Separator;

end Coyote_App.Frontend.GUI.Testing;
