--  Coyote_GUI_Notification_Policy_Tests — completion notification tests.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Coyote_GUI_Notification_Policy_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Notify_When_Allowed_Enabled_And_Inactive (T : in out Test);
   procedure Test_Suppress_When_Window_Is_Active (T : in out Test);
   procedure Test_Suppress_When_Disabled (T : in out Test);
   procedure Test_Suppress_When_Not_Allowed (T : in out Test);
   procedure Test_Completion_Notification_Is_Global (T : in out Test);
   procedure Test_Agent_Update_Requires_Selection (T : in out Test);
   procedure Test_Notify_Lifecycle_In_Isolated_Process (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Coyote_GUI_Notification_Policy_Tests;
