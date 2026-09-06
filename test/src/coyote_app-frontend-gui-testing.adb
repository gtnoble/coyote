--  Coyote_App.Frontend.GUI.Testing — test-only widget accessors.
--
--  Project: coyote

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Coyote_App.Agent_RPC;
with Coyote_GUI;

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

   function Agents_Window
     (F : Coyote_App.Frontend.GUI.Instance)
      return Gtk.Window.Gtk_Window
   is
   begin
      return F.Agents_Window;
   end Agents_Window;

   function Agents_View
     (F : Coyote_App.Frontend.GUI.Instance)
      return Gtk.Tree_View.Gtk_Tree_View
   is
   begin
      return F.Agents_View;
   end Agents_View;

   function Sandbox_Profiles_Item
     (F : Coyote_App.Frontend.GUI.Instance)
      return Gtk.Menu_Item.Gtk_Menu_Item
   is
   begin
      return F.Sandbox_Profiles_Item;
   end Sandbox_Profiles_Item;

   function Sandbox_Profiles_Created
     (F : Coyote_App.Frontend.GUI.Instance) return Boolean
   is
   begin
      return Coyote_GUI.Sandbox_Profile_Window.Is_Created
        (F.Sandbox_Profile_Window);
   end Sandbox_Profiles_Created;

   function Sandbox_Profiles_Title
     (F : Coyote_App.Frontend.GUI.Instance) return String
   is
   begin
      return Coyote_GUI.Sandbox_Profile_Window.Window_Title
        (F.Sandbox_Profile_Window);
   end Sandbox_Profiles_Title;

   procedure Apply_Handshake
     (F               : in out Coyote_App.Frontend.GUI.Instance;
      Agent_Id        : String;
      Parent_Agent_Id : String;
      Label           : String)
   is
      Update : Coyote_GUI.Update;
   begin
      Update.Kind := Coyote_GUI.Rpc_Frame;
      Update.Text := To_Unbounded_String
        (Coyote_App.Agent_RPC.Encode
           (Coyote_App.Agent_RPC.Make_Handshake
              (Agent_Id        => Agent_Id,
               Parent_Agent_Id => Parent_Agent_Id,
               Label           => Label)));
      Coyote_App.Frontend.GUI.Apply_RPC_Frame (F, Update);
   end Apply_Handshake;

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
