--  Coyote_GUI_Sandbox_Profile_Window_Tests body.
--
--  Project: coyote

with Ada.Environment_Variables;
with AUnit.Assertions;
with AUnit.Test_Caller;
with Coyote_GUI.Prompt_Queue;
with Coyote_GUI.Sandbox_Profile_Window;
with Coyote_GUI.Sandbox_Profile_Window.Testing;
with Gtk.Button;
with Glib;
with Gtk.Enums;
with Gtk.Tree_Model;
with Gtk.Tree_View;
with Gtk.Tree_View_Column;
with Gtk.Main;
with Gtk.Window;
with LLM.Tools.Sandbox;

package body Coyote_GUI_Sandbox_Profile_Window_Tests is

   use AUnit.Assertions;
   use type Glib.Gint;
   use type Gtk.Tree_Model.Gtk_Tree_Model;
   use type Gtk.Tree_View.Gtk_Tree_View;
   use type Gtk.Tree_View_Column.Gtk_Tree_View_Column;
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

   procedure Test_Path_Editors_Use_Tree_Views (T : in out Test) is
      Parent : Gtk.Window.Gtk_Window;
      Queue  : aliased Coyote_GUI.Prompt_Queue.Queue;
      Window : aliased Coyote_GUI.Sandbox_Profile_Window.Instance;
      View   : Gtk.Tree_View.Gtk_Tree_View;
      Model  : Gtk.Tree_Model.Gtk_Tree_Model;
      First  : Gtk.Tree_View_Column.Gtk_Tree_View_Column;
      Second : Gtk.Tree_View_Column.Gtk_Tree_View_Column;
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
      View := Coyote_GUI.Sandbox_Profile_Window.Testing.Path_View (Window);
      Model := View.Get_Model;
      Assert (View /= null, "combined path view must exist");
      Assert
        (Model /= Gtk.Tree_Model.Null_Gtk_Tree_Model,
         "combined path view must have a model");
      Assert
        (Gtk.Tree_Model.Get_N_Columns (Model) = 3,
         "combined model must have category, path, and rule-key columns");
      First := View.Get_Column (0);
      Second := View.Get_Column (1);
      Assert (First /= null, "category column must exist");
      Assert (Second /= null, "path column must exist");
      Assert
        (First.Get_Title = "Rule category",
         "first column must identify the rule category");
      Assert
        (Second.Get_Title = "Path",
         "second column must display the path");
      Assert
        (Coyote_GUI.Sandbox_Profile_Window.Testing.Add_Path_Button
           (Window).Get_Label = "_Add Path",
         "shared add button must be present");
      Assert
        (Coyote_GUI.Sandbox_Profile_Window.Testing.Edit_Path_Button
           (Window).Get_Label = "_Edit Selected",
         "shared edit button must be present");
      Assert
        (Coyote_GUI.Sandbox_Profile_Window.Testing.Remove_Path_Button
           (Window).Get_Label = "_Remove Selected",
         "shared remove button must be present");
      Assert
        (not Coyote_GUI.Sandbox_Profile_Window.Testing.Edit_Path_Button
           (Window).Get_Sensitive,
         "edit must start disabled without a selected path");
      Assert
        (not Coyote_GUI.Sandbox_Profile_Window.Testing.Remove_Path_Button
           (Window).Get_Sensitive,
         "remove must start disabled without a selected path");
      Parent.Destroy;
   end Test_Path_Editors_Use_Tree_Views;

   package Sandbox_Profile_Window_Caller is
     new AUnit.Test_Caller (Coyote_GUI_Sandbox_Profile_Window_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Sandbox_Profile_Window_Caller.Create
        ("sandbox profile manager create is idempotent",
         Coyote_GUI_Sandbox_Profile_Window_Tests
           .Test_Create_Is_Idempotent'Access));
      Result.Add_Test (Sandbox_Profile_Window_Caller.Create
        ("sandbox profile names are validated",
         Coyote_GUI_Sandbox_Profile_Window_Tests
           .Test_Profile_Name_Validation'Access));
      Result.Add_Test (Sandbox_Profile_Window_Caller.Create
        ("sandbox profile path editors use tree views",
         Coyote_GUI_Sandbox_Profile_Window_Tests
           .Test_Path_Editors_Use_Tree_Views'Access));
      return Result;
   end Suite;

end Coyote_GUI_Sandbox_Profile_Window_Tests;
