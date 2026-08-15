--  Coyote_GUI_Notification_Policy_Tests — completion notification policy tests.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;

package Coyote_GUI_Notification_Policy_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Notify_When_Allowed_Enabled_And_Inactive
     (T : in out Test);
   procedure Test_Suppress_When_Window_Is_Active (T : in out Test);
   procedure Test_Suppress_When_Disabled (T : in out Test);
   procedure Test_Suppress_When_Not_Allowed (T : in out Test);

end Coyote_GUI_Notification_Policy_Tests;
