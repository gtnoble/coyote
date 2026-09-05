with AUnit.Test_Caller;
with AUnit.Test_Suites;
--  Coyote_GUI_Mode_Tests body.
--
--  Project: coyote

with AUnit.Assertions;
with Coyote_GUI;

package body Coyote_GUI_Mode_Tests is

   use AUnit.Assertions;
   use Coyote_GUI;

   procedure Test_Agent_Actions_Follow_Run_Mode (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (not Stop_Available (Idle),
              "Stop is unavailable while idle");
      Assert (not Pause_Available (Idle),
              "Pause is unavailable while idle");
      Assert (not Resume_Available (Idle),
              "Resume is unavailable while idle");

      Assert (Stop_Available (Running),
              "Stop is available while running");
      Assert (Pause_Available (Running),
              "Pause is available while running");
      Assert (not Resume_Available (Running),
              "Resume is unavailable while running");

      Assert (Stop_Available (Armed),
              "Stop remains available after Pause is armed");
      Assert (not Pause_Available (Armed),
              "Pause is unavailable once already armed");
      Assert (not Resume_Available (Armed),
              "Resume is unavailable until the turn is paused");

      Assert (Stop_Available (Paused),
              "Stop remains available while paused");
      Assert (not Pause_Available (Paused),
              "Pause is unavailable while already paused");
      Assert (Resume_Available (Paused),
              "Resume is available while paused");
   end Test_Agent_Actions_Follow_Run_Mode;


   package Coyote_GUI_Mode_Caller is
     new AUnit.Test_Caller (Coyote_GUI_Mode_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Coyote_GUI_Mode_Caller.Create
        ("Coyote.GUI agent actions follow run mode",
         Coyote_GUI_Mode_Tests.Test_Agent_Actions_Follow_Run_Mode'Access));

      return Result;
   end Suite;

end Coyote_GUI_Mode_Tests;
