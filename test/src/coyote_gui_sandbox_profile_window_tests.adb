--  Coyote_GUI_Sandbox_Profile_Window_Tests body.
--
--  Project: coyote

with Ada.Environment_Variables;
with AUnit.Assertions;
with Coyote_GUI.Prompt_Queue;
with Coyote_GUI.Sandbox_Profile_Window;
with Gtk.Enums;
with Gtk.Main;
with Gtk.Window;
with LLM.Tools.Sandbox;

package body Coyote_GUI_Sandbox_Profile_Window_Tests is

   use AUnit.Assertions;
   use type Gtk.Window.Gtk_Window;

   function Display_Detected return Boolean is
   begin
      return Ada.Environment_Variables.Exists ("DISPLAY")
        or else Ada.Environment_Variables.Exists ("WAYLAND_DISPLAY");
   exception
      when others =>
         return False;
   end Display_Detected;

   overriding procedure Set_Up (T : in out Test) is
   begin
      if Display_Detected then
         Gtk.Main.Init;
         T.Display_Available := True;
      end if;
   end Set_Up;

   procedure Test_Profile_Name_Validation (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (LLM.Tools.Sandbox.Is_Valid_Profile_Name ("profile-copy"),
         "a normal profile name must be accepted");
      Assert
        (not LLM.Tools.Sandbox.Is_Valid_Profile_Name (""),
         "an empty profile name must be rejected");
      Assert
        (not LLM.Tools.Sandbox.Is_Valid_Profile_Name ("a/b"),
         "a path separator must be rejected in a profile name");
   end Test_Profile_Name_Validation;

   procedure Test_Create_Is_Idempotent (T : in out Test) is
      Parent : Gtk.Window.Gtk_Window;
      Queue  : aliased Coyote_GUI.Prompt_Queue.Queue;
      Window : aliased Coyote_GUI.Sandbox_Profile_Window.Instance;
   begin
      if not T.Display_Available then
         return;
      end if;
      Gtk.Window.Gtk_New (Parent, Gtk.Enums.Window_Toplevel);
      Coyote_GUI.Sandbox_Profile_Window.Create
        (S               => Window,
         Main_Window     => Parent.all'Access,
         Prompt_Queue    => Queue'Access,
         Target_Agent_Id => "test-agent");
      Assert
        (Coyote_GUI.Sandbox_Profile_Window.Is_Created (Window),
         "create must construct the profile manager");
      Assert
        (Coyote_GUI.Sandbox_Profile_Window.Window_Title (Window) =
           "coyote : Sandbox Profiles",
         "the manager must use the required title");
      Coyote_GUI.Sandbox_Profile_Window.Create
        (S               => Window,
         Main_Window     => Parent.all'Access,
         Prompt_Queue    => Queue'Access,
         Target_Agent_Id => "test-agent");
      Coyote_GUI.Sandbox_Profile_Window.Show (Window);
      Coyote_GUI.Sandbox_Profile_Window.Refresh (Window);
      Coyote_GUI.Sandbox_Profile_Window.Show (Window);
      Coyote_GUI.Sandbox_Profile_Window.Refresh (Window);
      Assert
        (Coyote_GUI.Sandbox_Profile_Window.Is_Created (Window),
         "repeated show and refresh must retain the window");
      Parent.Destroy;
   end Test_Create_Is_Idempotent;

end Coyote_GUI_Sandbox_Profile_Window_Tests;
