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

   function Agent_Pane
     (F : Coyote_App.Frontend.GUI.Instance)
      return Gtk.Paned.Gtk_Paned
   is
   begin
      return F.Agent_Pane;
   end Agent_Pane;

   function Agents_View
     (F : Coyote_App.Frontend.GUI.Instance)
      return Gtk.Tree_View.Gtk_Tree_View
   is
   begin
      return F.Agents_View;
   end Agents_View;

   procedure Build_Product_Information
     (F      : Coyote_App.Frontend.GUI.Instance;
      Dialog : out Gtk.Dialog.Gtk_Dialog;
      Image  : out Gtk.Image.Gtk_Image)
   is
   begin
      Coyote_App.Frontend.GUI.Build_Product_Information
        (F.Win, Dialog, Image);
   end Build_Product_Information;

end Coyote_App.Frontend.GUI.Testing;
