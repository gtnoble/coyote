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

end Coyote_GUI_Notification_Policy_Tests;
