with AUnit.Test_Caller;
--  Coyote_Signal_Shutdown_Tests body.
--
--  Project: coyote

with Ada.Directories;
with Ada.Strings.Unbounded;
with Coyote_Utils;
with GNATCOLL.OS.Process;
with AUnit.Assertions;

package body Coyote_Signal_Shutdown_Tests is

   use AUnit.Assertions;

   procedure Run_Worker (Mode : String) is
      use GNATCOLL.OS.Process;
      Bin : constant String := Ada.Directories.Containing_Directory
        (Coyote_Utils.Active_Executable_Path);
      Args : Argument_List;
      Status : Integer;
   begin
      Args.Append ("timeout");
      Args.Append ("10");
      Args.Append (Bin & "/signal_shutdown_worker");
      Args.Append (Mode);
      declare
         Output : constant Ada.Strings.Unbounded.Unbounded_String :=
           Run (Args, Status => Status, Strip => False);
      begin
         Assert
           (Status = 0,
            "isolated shutdown worker (" & Mode & ") failed: "
            & Ada.Strings.Unbounded.To_String (Output));
      end;
   end Run_Worker;

   procedure Test_Grace_Waits_For_Deadline (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Run_Worker ("grace");
   end Test_Grace_Waits_For_Deadline;

   procedure Test_Second_Signal_Escalates (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Run_Worker ("escalate");
   end Test_Second_Signal_Escalates;

   package Coyote_Signal_Shutdown_Caller is new AUnit.Test_Caller (Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test
        (Coyote_Signal_Shutdown_Caller.Create
           ("Coyote.Signal_Shutdown grace waits full interval",
            Test_Grace_Waits_For_Deadline'Access));
      Result.Add_Test
        (Coyote_Signal_Shutdown_Caller.Create
           ("Coyote.Signal_Shutdown second signal escalates",
            Test_Second_Signal_Escalates'Access));
      return Result;
   end Suite;

end Coyote_Signal_Shutdown_Tests;
