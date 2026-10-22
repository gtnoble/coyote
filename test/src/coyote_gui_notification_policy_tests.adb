with AUnit.Test_Caller;
--  Coyote_GUI_Notification_Policy_Tests body.
--
--  Project: coyote

with Ada.Directories;
with Ada.Strings.Unbounded;
with Coyote_Utils;
with GNATCOLL.OS.Process;
with AUnit.Assertions;
with Coyote_GUI.Notification_Policy;

package body Coyote_GUI_Notification_Policy_Tests is

   use AUnit.Assertions;

   procedure Test_Notify_When_Allowed_Enabled_And_Inactive (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (Coyote_GUI.Notification_Policy.Should_Notify_Completion
           (Allowed => True, Enabled => True, Window_Active => False),
         "enabled interactive inactive GUI should notify");
   end Test_Notify_When_Allowed_Enabled_And_Inactive;

   procedure Test_Suppress_When_Window_Is_Active (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (not Coyote_GUI.Notification_Policy.Should_Notify_Completion
           (Allowed => True, Enabled => True, Window_Active => True),
         "active GUI should suppress notification");
   end Test_Suppress_When_Window_Is_Active;

   procedure Test_Suppress_When_Disabled (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (not Coyote_GUI.Notification_Policy.Should_Notify_Completion
           (Allowed => True, Enabled => False, Window_Active => False),
         "disabled preference should suppress notification");
   end Test_Suppress_When_Disabled;

   procedure Test_Suppress_When_Not_Allowed (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (not Coyote_GUI.Notification_Policy.Should_Notify_Completion
           (Allowed => False, Enabled => True, Window_Active => False),
         "noninteractive mode should suppress notification");
   end Test_Suppress_When_Not_Allowed;

   procedure Test_Completion_Notification_Is_Global (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (Coyote_GUI.Notification_Policy.Should_Apply_Update
           (Runtime_Agent_Id  => "root",
            Selected_Agent_Id => "child",
            Is_Global         => True),
         "root completion notification should pass for a selected child");
   end Test_Completion_Notification_Is_Global;

   procedure Test_Agent_Update_Requires_Selection (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (not Coyote_GUI.Notification_Policy.Should_Apply_Update
           (Runtime_Agent_Id  => "root",
            Selected_Agent_Id => "child",
            Is_Global         => False),
         "root updates stay hidden while a child is selected");
   end Test_Agent_Update_Requires_Selection;

   procedure Test_Notify_Lifecycle_In_Isolated_Process (T : in out Test) is
      pragma Unreferenced (T);
      use GNATCOLL.OS.Process;
      Bin : constant String := Ada.Directories.Containing_Directory
        (Coyote_Utils.Active_Executable_Path);
      Args : Argument_List;
      Status : Integer;
   begin
      Args.Append ("timeout");
      Args.Append ("10");
      Args.Append ("/usr/bin/env");
      Args.Append
        ("DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent-coyote-bus");
      Args.Append (Bin & "/notify_test_worker");
      declare
         Output : constant Ada.Strings.Unbounded.Unbounded_String :=
           Run (Args, Status => Status, Strip => False);
      begin
         Assert
           (Status = 0,
            "isolated notification lifecycle worker failed: "
            & Ada.Strings.Unbounded.To_String (Output));
      end;
   end Test_Notify_Lifecycle_In_Isolated_Process;

   package Coyote_GUI_Notification_Policy_Caller is new AUnit.Test_Caller
     (Coyote_GUI_Notification_Policy_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test
        (Coyote_GUI_Notification_Policy_Caller.Create
           ("Coyote.GUI.Notification_Policy eligibility",
            Coyote_GUI_Notification_Policy_Tests
              .Test_Notify_When_Allowed_Enabled_And_Inactive'
              Access));
      Result.Add_Test
        (Coyote_GUI_Notification_Policy_Caller.Create
           ("Coyote.GUI.Notification_Policy active window suppresses",
            Coyote_GUI_Notification_Policy_Tests
              .Test_Suppress_When_Window_Is_Active'
              Access));
      Result.Add_Test
        (Coyote_GUI_Notification_Policy_Caller.Create
           ("Coyote.GUI.Notification_Policy disabled suppresses",
            Coyote_GUI_Notification_Policy_Tests.Test_Suppress_When_Disabled'
              Access));
      Result.Add_Test
        (Coyote_GUI_Notification_Policy_Caller.Create
           ("Coyote.GUI.Notification_Policy noninteractive suppresses",
            Coyote_GUI_Notification_Policy_Tests
              .Test_Suppress_When_Not_Allowed'
              Access));
      Result.Add_Test
        (Coyote_GUI_Notification_Policy_Caller.Create
           ("Coyote.GUI.Notification_Policy notification is global",
            Coyote_GUI_Notification_Policy_Tests
              .Test_Completion_Notification_Is_Global'Access));
      Result.Add_Test
        (Coyote_GUI_Notification_Policy_Caller.Create
           ("Coyote.GUI.Notification_Policy agent update selection",
            Coyote_GUI_Notification_Policy_Tests
              .Test_Agent_Update_Requires_Selection'Access));
      Result.Add_Test
        (Coyote_GUI_Notification_Policy_Caller.Create
           ("Coyote.Notify isolated lifecycle smoke test",
            Coyote_GUI_Notification_Policy_Tests
              .Test_Notify_Lifecycle_In_Isolated_Process'Access));
      return Result;
   end Suite;

end Coyote_GUI_Notification_Policy_Tests;
