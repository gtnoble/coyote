with AUnit.Assertions;
with AUnit.Test_Caller;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Coyote_App.Agent_RPC;
with Coyote_App.Agent_RPC.Service;
with Coyote_App.Frontend;
with Coyote_App.Frontend.RPC;
with GNAT.OS_Lib;

package body Coyote_App_Frontend_RPC_Tests is

   use AUnit.Assertions;
   use Ada.Strings.Unbounded;
   use Coyote_App.Agent_RPC;
   use type Coyote_App.Frontend.Control_Command_Kind;

   procedure On_Frame (Value : Frame) is
      pragma Unreferenced (Value);
   begin
      null;
   end On_Frame;

   function Test_Endpoint return String is
      Pid_Image : constant String :=
        Ada.Strings.Fixed.Trim
          (Integer'Image
             (GNAT.OS_Lib.Pid_To_Integer (GNAT.OS_Lib.Current_Process_Id)),
           Ada.Strings.Both);
   begin
      return "/tmp/coyote-rpc-frontend-" & Pid_Image & ".sock";
   end Test_Endpoint;

   procedure Remove_Path (Path : String) is
      Deleted : Boolean;
   begin
      GNAT.OS_Lib.Delete_File (Path, Deleted);
   end Remove_Path;

   procedure Test_Reader_Demultiplexes_Prompts_And_Controls
     (T : in out Test)
   is
      pragma Unreferenced (T);
      Service  : Coyote_App.Agent_RPC.Service.Service;
      Frontend : Coyote_App.Frontend.RPC.Instance;
      Path     : constant String := Test_Endpoint;
      Command  : Coyote_App.Frontend.Control_Command;
   begin
      Remove_Path (Path);
      Coyote_App.Agent_RPC.Service.Start (Service, Path, On_Frame'Access);
      Frontend.Create (Path, "worker", "root");
      delay 0.1;
      Coyote_App.Agent_RPC.Service.Send_Command
        (Service, "worker", "prompt-1", Prompt, "{""text"":""hello""}");
      Coyote_App.Agent_RPC.Service.Send_Command
        (Service, "worker", "abort-1", Abort_Tool,
         "{""toolId"":""call-1""}");
      delay 0.1;
      Assert
        (Frontend.Read_Prompt = "hello", "prompt must reach prompt reader");
      for Attempt in 1 .. 20 loop
         exit when Frontend.Read_Control (Command);
         delay 0.01;
      end loop;
      Assert (Command.Kind = Coyote_App.Frontend.Control_Abort_Tool,
              "abort command must reach control reader");
      Assert (To_String (Command.Tool_Id) = "call-1",
              "abort tool ID must survive demultiplexing");
      Frontend.Shutdown;
      Coyote_App.Agent_RPC.Service.Stop (Service);
   exception
      when others =>
         Frontend.Shutdown;
         Coyote_App.Agent_RPC.Service.Stop (Service);
         raise;
   end Test_Reader_Demultiplexes_Prompts_And_Controls;

   package Caller is new AUnit.Test_Caller (Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test
        (Caller.Create
           ("RPC frontend demultiplexes prompt and abort commands",
            Test_Reader_Demultiplexes_Prompts_And_Controls'Access));
      return Result;
   end Suite;

end Coyote_App_Frontend_RPC_Tests;
