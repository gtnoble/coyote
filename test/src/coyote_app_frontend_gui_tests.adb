--  Coyote_App_Frontend_GUI_Tests body.
--
--  Project: coyote

with Ada.Environment_Variables;
with AUnit.Assertions;
with Coyote_App.Frontend.GUI.Testing;
with Glib;
with Gtk.Box;
with Gtk.Container;
with Gtk.Main;
with Gtk.Separator;
with Gtk.Widget;
with Gtk.Window;

package body Coyote_App_Frontend_GUI_Tests is

   use AUnit.Assertions;
   use type Glib.Guint;
   use type Gtk.Box.Gtk_Box;
   use type Gtk.Separator.Gtk_Separator;
   use type Gtk.Window.Gtk_Window;
   use type Gtk.Widget.Gtk_Widget;

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
         Coyote_App.Frontend.GUI.Create
           (T.Frontend, "coyote layout test", Pop_Under => True);
      end if;
   end Set_Up;

   overriding procedure Tear_Down (T : in out Test) is
      use Coyote_App.Frontend.GUI.Testing;
   begin
      if T.Display_Available and then Main_Window (T.Frontend) /= null then
         Main_Window (T.Frontend).Destroy;
      end if;
   end Tear_Down;

   procedure Test_Separates_Conversation_Prompt_And_Status
     (T : in out Test)
   is
      use Coyote_App.Frontend.GUI.Testing;
      Outer         : constant Gtk.Box.Gtk_Box := Outer_Box (T.Frontend);
      Prompt        : constant Gtk.Box.Gtk_Box := Prompt_Box (T.Frontend);
      Status        : constant Gtk.Box.Gtk_Box := Status_Box (T.Frontend);
      Conv_Prompt   : constant Gtk.Separator.Gtk_Separator :=
        Conversation_Prompt_Separator (T.Frontend);
      Prompt_Status : constant Gtk.Separator.Gtk_Separator :=
        Prompt_Status_Separator (T.Frontend);
   begin
      if not T.Display_Available then
         return;
      end if;

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
   end Test_Separates_Conversation_Prompt_And_Status;

end Coyote_App_Frontend_GUI_Tests;
