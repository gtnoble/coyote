--  Coyote_Process_Control_Tests body.
--  Project: coyote

with AUnit.Assertions;
with Coyote_Process_Control;
with LLM.Settings;

package body Coyote_Process_Control_Tests is

   use AUnit.Assertions;

   procedure Test_Grace_Clamps (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Coyote_Process_Control.Set_Grace_Seconds
        (LLM.Settings.Max_Termination_Grace_Seconds + 1);
      Assert
        (Coyote_Process_Control.Grace_Seconds =
           LLM.Settings.Max_Termination_Grace_Seconds,
         "shutdown grace should clamp to the configured maximum");
      Coyote_Process_Control.Set_Grace_Seconds (0);
      Assert
        (Coyote_Process_Control.Grace_Seconds = 0,
         "zero shutdown grace should be accepted");
   end Test_Grace_Clamps;

   procedure Test_Launches_Reject_After_Shutdown (T : in out Test) is
      pragma Unreferenced (T);
      Accepted : Boolean;
      First    : Boolean;
   begin
      Coyote_Process_Control.Begin_Launch (Accepted);
      Assert (Accepted, "launch should be accepted before shutdown");
      Coyote_Process_Control.Cancel_Launch;
      Coyote_Process_Control.Begin_Shutdown (First);
      Assert (First, "first shutdown request should be identified");
      Coyote_Process_Control.Begin_Launch (Accepted);
      Assert (not Accepted, "launch should be rejected after shutdown");
   end Test_Launches_Reject_After_Shutdown;

   procedure Test_Persistence_Freezes (T : in out Test) is
      pragma Unreferenced (T);
      Accepted : Boolean;
   begin
      Coyote_Process_Control.Begin_Persistence_Write (Accepted);
      Assert (Accepted, "write should be accepted before freeze");
      Coyote_Process_Control.End_Persistence_Write;
      Coyote_Process_Control.Freeze_Persistence;
      Coyote_Process_Control.Begin_Persistence_Write (Accepted);
      Assert (not Accepted, "writes should be rejected after freeze");
   end Test_Persistence_Freezes;

end Coyote_Process_Control_Tests;
