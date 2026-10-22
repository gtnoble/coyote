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

   protected Captured_Frame is
      procedure Store (Value : Frame);
      procedure Read (Value : out Frame; Available : out Boolean);
   private
      Item : Frame;
      Has_Item : Boolean := False;
   end Captured_Frame;

   protected body Captured_Frame is
      procedure Store (Value : Frame) is
      begin
         Item := Value;
         Has_Item := True;
      end Store;

      procedure Read (Value : out Frame; Available : out Boolean) is
      begin
         Value := Item;
         Available := Has_Item;
      end Read;
   end Captured_Frame;

   procedure On_Frame
     (Value : Frame; Generation : Coyote_App.Agent_RPC.Service.Generation_Id)
   is
      pragma Unreferenced (Generation);
   begin
      Captured_Frame.Store (Value);
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

   procedure Test_Source_Directory_Is_Forwarded (T : in out Test) is
      pragma Unreferenced (T);
      Service   : Coyote_App.Agent_RPC.Service.Service;
      Frontend  : Coyote_App.Frontend.RPC.Instance;
      Path      : constant String := Test_Endpoint;
      Value     : Frame;
      Available : Boolean := False;
   begin
      Remove_Path (Path);
      Coyote_App.Agent_RPC.Service.Start (Service, Path, On_Frame'Access);
      Frontend.Create (Path, "worker", "root");
      delay 0.1;
      Frontend.Set_Source_Directory ("/tmp/source-root");
      for Attempt in 1 .. 20 loop
         Captured_Frame.Read (Value, Available);
         exit when Available and then Value.Kind = Event;
         delay 0.01;
      end loop;
      Assert (Available, "source directory event must reach RPC service");
      Assert (Value.Event_Name = Source_Directory,
              "source directory must be forwarded as an event");
      Assert
        (To_String (Value.Payload_Json) =
           "{""directory"":""/tmp/source-root""}",
         "source directory payload must contain the directory");
      Frontend.Shutdown;
      Coyote_App.Agent_RPC.Service.Stop (Service);
   exception
      when others =>
         Frontend.Shutdown;
         Coyote_App.Agent_RPC.Service.Stop (Service);
         raise;
   end Test_Source_Directory_Is_Forwarded;

   package Caller is new AUnit.Test_Caller (Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test
        (Caller.Create
           ("RPC frontend demultiplexes prompt and abort commands",
            Test_Reader_Demultiplexes_Prompts_And_Controls'Access));
      Result.Add_Test
        (Caller.Create
           ("RPC frontend forwards source directory",
            Test_Source_Directory_Is_Forwarded'Access));
      return Result;
   end Suite;

end Coyote_App_Frontend_RPC_Tests;
