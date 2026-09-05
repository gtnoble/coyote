with AUnit.Test_Caller;
with AUnit.Test_Suites;
--  Coyote_GUI_Notification_Policy_Tests body.
--
--  Project: coyote

with AUnit.Assertions;
with Coyote_GUI.Notification_Policy;

package body Coyote_GUI_Notification_Policy_Tests is

   use AUnit.Assertions;

   procedure Test_Notify_When_Allowed_Enabled_And_Inactive
     (T : in out Test)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (Coyote_GUI.Notification_Policy.Should_Notify_Completion
           (Allowed       => True,
            Enabled       => True,
            Window_Active => False),
         "enabled interactive inactive GUI should notify");
   end Test_Notify_When_Allowed_Enabled_And_Inactive;

   procedure Test_Suppress_When_Window_Is_Active (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (not Coyote_GUI.Notification_Policy.Should_Notify_Completion
           (Allowed       => True,
            Enabled       => True,
            Window_Active => True),
         "active GUI should suppress notification");
   end Test_Suppress_When_Window_Is_Active;

   procedure Test_Suppress_When_Disabled (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (not Coyote_GUI.Notification_Policy.Should_Notify_Completion
           (Allowed       => True,
            Enabled       => False,
            Window_Active => False),
         "disabled preference should suppress notification");
   end Test_Suppress_When_Disabled;

   procedure Test_Suppress_When_Not_Allowed (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (not Coyote_GUI.Notification_Policy.Should_Notify_Completion
           (Allowed       => False,
            Enabled       => True,
            Window_Active => False),
         "noninteractive mode should suppress notification");
   end Test_Suppress_When_Not_Allowed;


   package Coyote_GUI_Notification_Policy_Caller is
     new AUnit.Test_Caller (Coyote_GUI_Notification_Policy_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Coyote_GUI_Notification_Policy_Caller.Create
        ("Coyote.GUI.Notification_Policy eligibility",
         Coyote_GUI_Notification_Policy_Tests
           .Test_Notify_When_Allowed_Enabled_And_Inactive'Access));
      Result.Add_Test (Coyote_GUI_Notification_Policy_Caller.Create
        ("Coyote.GUI.Notification_Policy active window suppresses",
         Coyote_GUI_Notification_Policy_Tests
           .Test_Suppress_When_Window_Is_Active'Access));
      Result.Add_Test (Coyote_GUI_Notification_Policy_Caller.Create
        ("Coyote.GUI.Notification_Policy disabled suppresses",
         Coyote_GUI_Notification_Policy_Tests
           .Test_Suppress_When_Disabled'Access));
      Result.Add_Test (Coyote_GUI_Notification_Policy_Caller.Create
        ("Coyote.GUI.Notification_Policy noninteractive suppresses",
         Coyote_GUI_Notification_Policy_Tests
           .Test_Suppress_When_Not_Allowed'Access));

      return Result;
   end Suite;

end Coyote_GUI_Notification_Policy_Tests;
