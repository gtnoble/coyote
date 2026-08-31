--  Coyote_App_Agent_RPC_Service_Tests — coordinator RPC service tests.
--
--  Project: coyote

with Ada.Directories;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Coyote_App.Agent_RPC;
with Coyote_App.Agent_RPC.Service;
with Coyote_App.Agent_RPC.Transport;

package body Coyote_App_Agent_RPC_Service_Tests is

   use AUnit.Assertions;
   use Ada.Strings.Unbounded;
   use Coyote_App.Agent_RPC;
   use Coyote_App.Agent_RPC.Transport;

   protected Collector is
      procedure Add (Value : Frame);
      function Count return Natural;
      function Last return Frame;
      procedure Clear;
   private
      Number : Natural := 0;
      Latest : Frame :=
        (Kind => Handshake,
         Version => Current_Version,
         Agent_Id => Null_Unbounded_String,
         Payload_Json => Null_Unbounded_String,
         Parent_Agent_Id => Null_Unbounded_String,
         Session_Id => Null_Unbounded_String,
         Label => Null_Unbounded_String);
   end Collector;

   protected body Collector is
      procedure Add (Value : Frame) is
      begin
         Latest := Value;
         Number := Number + 1;
      end Add;

      function Count return Natural is (Number);
      function Last return Frame is (Latest);

      procedure Clear is
      begin
         Number := 0;
      end Clear;
   end Collector;

   procedure On_Frame (Value : Frame) is
   begin
      Collector.Add (Value);
   end On_Frame;

   procedure Wait_For_Count (Expected : Natural) is
   begin
      for Attempt in 1 .. 100 loop
         exit when Collector.Count >= Expected;
         delay 0.01;
      end loop;
   end Wait_For_Count;

   procedure Remove_Path (Path : String) is
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_File (Path);
      end if;
   end Remove_Path;

   procedure Test_Listener_Registers_Child (T : in out Test) is
      pragma Unreferenced (T);
      Service : Coyote_App.Agent_RPC.Service.Service;
      Child : Channel;
      Path : constant String := "/tmp/coyote-rpc-service-register.sock";
   begin
      Remove_Path (Path);
      Collector.Clear;
      Coyote_App.Agent_RPC.Service.Start
        (Service, Path, On_Frame'Access);
      Connect (Child, Path);
      Send_Frame
        (Child,
         Make_Handshake
           (Agent_Id => "worker", Parent_Agent_Id => "root", Label => "worker"));
      Wait_For_Count (1);
      Close (Child);
      Coyote_App.Agent_RPC.Service.Stop (Service);
      Assert (Collector.Count >= 1,
              "service must receive child handshake");
      Assert (Collector.Last.Kind = Handshake,
              "first service callback must be handshake");
   end Test_Listener_Registers_Child;

   procedure Test_Command_Routes_To_Child (T : in out Test) is
      pragma Unreferenced (T);
      Service : Coyote_App.Agent_RPC.Service.Service;
      Child : Channel;
      Path : constant String := "/tmp/coyote-rpc-service-command.sock";
      Value : Frame;
      Status : Receive_Status;
      Error : Unbounded_String;
   begin
      Remove_Path (Path);
      Collector.Clear;
      Coyote_App.Agent_RPC.Service.Start
        (Service, Path, On_Frame'Access);
      Connect (Child, Path);
      Send_Frame (Child, Make_Handshake (Agent_Id => "worker"));
      Wait_For_Count (1);
      Coyote_App.Agent_RPC.Service.Send_Command
        (Service,
         Agent_Id   => "worker",
         Request_Id => "request-1",
         Command    => Prompt,
         Payload    => "{""text"":""hello""}");
      Assert (Receive_Frame (Child, Value, Status, Error),
              "child must receive routed command");
      Assert (Value.Kind = Command, "routed frame must be command");
      Assert (Value.Command_Name = Prompt,
              "routed command kind must be prompt");
      Assert (To_String (Value.Request_Id) = "request-1",
              "routed request identity must survive");
      Close (Child);
      Coyote_App.Agent_RPC.Service.Stop (Service);
   end Test_Command_Routes_To_Child;

   procedure Test_Disconnect_Is_Reported (T : in out Test) is
      pragma Unreferenced (T);
      Service : Coyote_App.Agent_RPC.Service.Service;
      Child : Channel;
      Path : constant String := "/tmp/coyote-rpc-service-disconnect.sock";
   begin
      Remove_Path (Path);
      Collector.Clear;
      Coyote_App.Agent_RPC.Service.Start
        (Service, Path, On_Frame'Access);
      Connect (Child, Path);
      Send_Frame (Child, Make_Handshake (Agent_Id => "worker"));
      Wait_For_Count (1);
      Close (Child);
      Wait_For_Count (2);
      Assert (Collector.Count >= 2,
              "service must report a disconnected child");
      Assert (Collector.Last.Kind = Terminal,
              "disconnect callback must be terminal");
      Assert (Collector.Last.Status = Disconnected,
              "disconnect callback must use disconnected status");
      Coyote_App.Agent_RPC.Service.Stop (Service);
   end Test_Disconnect_Is_Reported;

end Coyote_App_Agent_RPC_Service_Tests;
