--  Coyote_App.Frontend.GUI.Testing — test-only widget accessors.
--
--  Project: coyote

with Gtk.Box;
with Gtk.Dialog;
with Gtk.Image;
with Gtk.Separator;
with Gtk.Tree_View;
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

   function Agents_Window
     (F : Coyote_App.Frontend.GUI.Instance)
      return Gtk.Window.Gtk_Window;

   function Agents_View
     (F : Coyote_App.Frontend.GUI.Instance)
      return Gtk.Tree_View.Gtk_Tree_View;

   procedure Apply_Handshake
     (F               : in out Coyote_App.Frontend.GUI.Instance;
      Agent_Id        : String;
      Parent_Agent_Id : String;
      Label           : String);

   procedure Build_Product_Information
     (F      : Coyote_App.Frontend.GUI.Instance;
      Dialog : out Gtk.Dialog.Gtk_Dialog;
      Image  : out Gtk.Image.Gtk_Image);

end Coyote_App.Frontend.GUI.Testing;
