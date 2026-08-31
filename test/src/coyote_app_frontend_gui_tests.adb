--  Coyote_App_Frontend_GUI_Tests body.
--
--  Project: coyote

with Ada.Environment_Variables;
with AUnit.Assertions;
with Coyote_App.Frontend.GUI.Testing;
with Coyote_GUI.Prompt_Queue;
with Coyote_Process_Control;
with GNAT.OS_Lib;
with GNAT.Strings;
with Glib;
with Gtk.Box;
with Gtk.Container;
with Gtk.Dialog;
with Gtk.Enums;
with Gtk.Image;
with Gtk.Main;
with Gtk.Separator;
with Gtk.Widget;
with Gtk.Window;

package body Coyote_App_Frontend_GUI_Tests is

   use AUnit.Assertions;
   use type Glib.Gint;
   use type Glib.Guint;
   use type Gtk.Box.Gtk_Box;
   use type Gtk.Dialog.Gtk_Dialog;
   use type Gtk.Image.Gtk_Image;
   use type Gtk.Image.Gtk_Image_Type;
   use type GNAT.Strings.String_Access;
   use type Gtk.Separator.Gtk_Separator;
   use type Gtk.Window.Gtk_Window;
   use type Gtk.Widget.Gtk_Widget;
   use type Coyote_GUI.Prompt_Queue.Item_Kind;

   function Display_Available return Boolean is
   begin
      return Ada.Environment_Variables.Exists ("DISPLAY")
        or else Ada.Environment_Variables.Exists ("WAYLAND_DISPLAY");
   exception
      when others =>
         return False;
   end Display_Available;

   overriding procedure Set_Up (T : in out Test) is
   begin
      if Display_Available then
         Gtk.Main.Init;
         T.Display_Available := True;
      end if;
   end Set_Up;

   overriding procedure Tear_Down (T : in out Test) is
      pragma Unreferenced (T);
   begin
      null;
   end Tear_Down;

   procedure Test_Layout_And_Shutdown_Lifecycle
     (T : in out Test)
   is
      use Coyote_App.Frontend.GUI.Testing;
      Frontend      : Coyote_App.Frontend.GUI.Instance;
      Outer         : Gtk.Box.Gtk_Box;
      Prompt        : Gtk.Box.Gtk_Box;
      Status        : Gtk.Box.Gtk_Box;
      Conv_Prompt   : Gtk.Separator.Gtk_Separator;
      Prompt_Status : Gtk.Separator.Gtk_Separator;
      use type Gtk.Window.Gtk_Window;
   begin
      if not T.Display_Available then
         return;
      end if;
      Coyote_App.Frontend.GUI.Create
        (Frontend, "coyote layout test", Pop_Under => True);
      Outer := Outer_Box (Frontend);
      Prompt := Prompt_Box (Frontend);
      Status := Status_Box (Frontend);
      Conv_Prompt := Conversation_Prompt_Separator (Frontend);
      Prompt_Status := Prompt_Status_Separator (Frontend);

      Assert (Outer /= null, "GUI creates an outer layout box");
      Assert (Conv_Prompt /= null,
              "GUI creates a conversation/prompt separator");
      Assert (Prompt_Status /= null,
              "GUI creates a prompt/status separator");
      Assert (Prompt /= null
              and then Gtk.Container.Get_Border_Width
                (Gtk.Container.Gtk_Container (Prompt)) = 4,
              "prompt area has a four-pixel breathing-room border");
      Assert (Status /= null
              and then Gtk.Container.Get_Border_Width
                (Gtk.Container.Gtk_Container (Status)) = 4,
              "status area has a four-pixel breathing-room border");

      Assert (Outer.Get_Child (2) = Gtk.Widget.Gtk_Widget (Conv_Prompt),
              "conversation is followed by the prompt separator");
      Assert (Outer.Get_Child (3) = Gtk.Widget.Gtk_Widget (Prompt),
              "prompt area follows the conversation separator");
      Assert (Outer.Get_Child (4) = Gtk.Widget.Gtk_Widget (Prompt_Status),
              "prompt area is followed by the status separator");
      Assert (Outer.Get_Child (5) = Gtk.Widget.Gtk_Widget (Status),
              "status area follows the prompt separator");

      declare
         task Reader is
            entry Complete;
         end Reader;

         Item : Coyote_GUI.Prompt_Queue.Item;

         task body Reader is
         begin
            Item := Frontend.Read_Item;
            accept Complete;
         end Reader;
      begin
         Frontend.Request_Shutdown;
         Reader.Complete;
         Assert
           (Item.Kind = Coyote_GUI.Prompt_Queue.Shutdown_Item,
            "application shutdown should release a blocked prompt reader");
      end;

      Assert
        (Coyote_Process_Control.Monitor_Should_Stop,
         "application shutdown should stop the process-control monitor");
      if Main_Window (Frontend) /= null then
         Main_Window (Frontend).Destroy;
      end if;
   end Test_Layout_And_Shutdown_Lifecycle;

   procedure Test_Product_Information_Icon
     (T : in out Test)
   is
      use Coyote_App.Frontend.GUI.Testing;
      Frontend : Coyote_App.Frontend.GUI.Instance;
      Dialog   : Gtk.Dialog.Gtk_Dialog;
      Image    : Gtk.Image.Gtk_Image;
   begin
      if not T.Display_Available then
         return;
      end if;
      Coyote_App.Frontend.GUI.Create
        (Frontend, "coyote product information test", Pop_Under => True);

      Build_Product_Information (Frontend, Dialog, Image);
      Assert (Dialog /= null,
              "Product Information creates a dialog");
      Assert (Dialog.Get_Title = "coyote : Product Information",
              "Product Information uses the application title");
      Assert (Image /= null,
              "Product Information includes the application icon");
      Assert (Gtk.Image.Get_Storage_Type (Image)
              = Gtk.Image.Image_Icon_Name,
              "Product Information uses the themed icon representation");
      Assert (Gtk.Image.Get_Pixel_Size (Image) = 96,
              "Product Information icon uses the prominent pixel size");
      declare
         Icon_Name : GNAT.Strings.String_Access := null;
         Icon_Size : Gtk.Enums.Gtk_Icon_Size;
      begin
         Gtk.Image.Get_Icon_Name (Image, Icon_Name, Icon_Size);
         Assert (Icon_Name /= null and then Icon_Name.all = "coyote",
                 "Product Information uses the coyote icon name");
         GNAT.OS_Lib.Free (Icon_Name);
      exception
         when others =>
            if Icon_Name /= null then
               GNAT.OS_Lib.Free (Icon_Name);
            end if;
            raise;
      end;
      Assert (Gtk.Widget.Is_Visible (Gtk.Widget.Gtk_Widget (Image)),
              "Product Information icon is visible");
      Dialog.Destroy;
      Main_Window (Frontend).Destroy;
   end Test_Product_Information_Icon;

end Coyote_App_Frontend_GUI_Tests;
