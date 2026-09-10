--  Coyote_App.Frontend.GUI.Testing — test-only widget accessors.
--
--  Project: coyote

with Gtk.Box;
with Gtk.Dialog;
with Gtk.Image;
with Gtk.Menu_Item;
with Gtk.Progress_Bar;
with Gtk.Separator;
with Gtk.Tree_View;
with Gtk.Window;

package Coyote_App.Frontend.GUI.Testing is

   function Main_Window
     (F : Coyote_App.Frontend.GUI.Instance) return Gtk.Window.Gtk_Window;

   function Outer_Box
     (F : Coyote_App.Frontend.GUI.Instance) return Gtk.Box.Gtk_Box;

   function Prompt_Box
     (F : Coyote_App.Frontend.GUI.Instance) return Gtk.Box.Gtk_Box;

   function Status_Box
     (F : Coyote_App.Frontend.GUI.Instance) return Gtk.Box.Gtk_Box;

   function Status_Content_Box
     (F : Coyote_App.Frontend.GUI.Instance) return Gtk.Box.Gtk_Box;

   function Context_Progress
     (F : Coyote_App.Frontend.GUI.Instance)
     return Gtk.Progress_Bar.Gtk_Progress_Bar;

   function Conversation_Prompt_Separator
     (F : Coyote_App.Frontend.GUI.Instance) return Gtk.Separator.Gtk_Separator;

   function Prompt_Status_Separator
     (F : Coyote_App.Frontend.GUI.Instance) return Gtk.Separator.Gtk_Separator;

   function Agents_Window
     (F : Coyote_App.Frontend.GUI.Instance) return Gtk.Window.Gtk_Window;

   function Agents_View
     (F : Coyote_App.Frontend.GUI.Instance) return Gtk.Tree_View.Gtk_Tree_View;

   function Sandbox_Profiles_Item
     (F : Coyote_App.Frontend.GUI.Instance) return Gtk.Menu_Item.Gtk_Menu_Item;

   function Sandbox_Profiles_Created
     (F : Coyote_App.Frontend.GUI.Instance) return Boolean;

   function Sandbox_Profiles_Title
     (F : Coyote_App.Frontend.GUI.Instance) return String;

   procedure Apply_Handshake
     (F               : in out Coyote_App.Frontend.GUI.Instance;
      Agent_Id        :        String;
      Parent_Agent_Id :        String;
      Label           :        String);

   procedure Build_Product_Information
     (F      :     Coyote_App.Frontend.GUI.Instance;
      Dialog : out Gtk.Dialog.Gtk_Dialog;
      Image  : out Gtk.Image.Gtk_Image);

end Coyote_App.Frontend.GUI.Testing;
