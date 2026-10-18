with AUnit.Test_Caller;
--  Coyote_App_Agent_RPC_Service_Tests — coordinator RPC service tests.
--
--  Project: coyote

with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Coyote_App.Agent_RPC;
with Coyote_App.Agent_RPC.Service;
with Coyote_App.Agent_RPC.Transport;
with GNAT.OS_Lib;

package body Coyote_App_Agent_RPC_Service_Tests is

   use AUnit.Assertions;
   use Ada.Strings.Unbounded;
   use Coyote_App.Agent_RPC;
   use Coyote_App.Agent_RPC.Transport;
   use type Coyote_App.Agent_RPC.Service.Generation_Id;

   procedure Remove_Path (Path : String) is
      Deleted : Boolean;
   begin
      GNAT.OS_Lib.Delete_File (Path, Deleted);
   end Remove_Path;

   function Test_Endpoint (Stem : String) return String is
      Pid_Image : constant String :=
        Ada.Strings.Fixed.Trim
          (Integer'Image
             (GNAT.OS_Lib.Pid_To_Integer (GNAT.OS_Lib.Current_Process_Id)),
           Ada.Strings.Both);
   begin
      return "/tmp/" & Stem & "-" & Pid_Image & ".sock";
   end Test_Endpoint;

   type Event_Kind is (Frame_Event, Generation_Event);
   type Captured_Event is record
      Kind : Event_Kind;
      Generation : Coyote_App.Agent_RPC.Service.Generation_Id;
   end record;

   type Event_Array is array (Positive range 1 .. 100) of Captured_Event;

   protected Collector is
      procedure Add
        (Value : Frame;
         Generation : Coyote_App.Agent_RPC.Service.Generation_Id);
      procedure Mark_Generation
        (Generation : Coyote_App.Agent_RPC.Service.Generation_Id);
      function Event (Index : Positive) return Captured_Event;
      function Event_Count return Natural;
      function Count return Natural;
      function Last return Frame;
      function Last_Generation
        return Coyote_App.Agent_RPC.Service.Generation_Id;
      procedure Clear;
   private
      Events : Event_Array;
      Number : Natural := 0;
      Event_Number : Natural := 0;
      Latest : Frame :=
        (Kind => Handshake,
         Version => Current_Version,
         Agent_Id => Null_Unbounded_String,
         Payload_Json => Null_Unbounded_String,
         Parent_Agent_Id => Null_Unbounded_String,
         Session_Id => Null_Unbounded_String,
         Label => Null_Unbounded_String);
      Latest_Generation : Coyote_App.Agent_RPC.Service.Generation_Id := 0;
   end Collector;

   protected body Collector is
      procedure Add
        (Value : Frame;
         Generation : Coyote_App.Agent_RPC.Service.Generation_Id)
      is
      begin
         Latest := Value;
         Latest_Generation := Generation;
         Number := Number + 1;
         Event_Number := Event_Number + 1;
         Events (Event_Number) :=
           (Kind => Frame_Event, Generation => Generation);
      end Add;

      procedure Mark_Generation
        (Generation : Coyote_App.Agent_RPC.Service.Generation_Id)
      is
      begin
         Event_Number := Event_Number + 1;
         Events (Event_Number) :=
           (Kind => Generation_Event, Generation => Generation);
      end Mark_Generation;

      function Event (Index : Positive) return Captured_Event is
        (Events (Index));
      function Event_Count return Natural is (Event_Number);
      function Count return Natural is (Number);
      function Last return Frame is (Latest);
      function Last_Generation
        return Coyote_App.Agent_RPC.Service.Generation_Id
      is (Latest_Generation);

      procedure Clear is
      begin
         Number := 0;
         Event_Number := 0;
      end Clear;
   end Collector;

   procedure On_Frame
     (Value : Frame; Generation : Coyote_App.Agent_RPC.Service.Generation_Id)
   is
   begin
      Collector.Add (Value, Generation);
   end On_Frame;

   procedure On_Generation
     (Generation : Coyote_App.Agent_RPC.Service.Generation_Id)
   is
   begin
      Collector.Mark_Generation (Generation);
   end On_Generation;

   procedure Wait_For_Count (Expected : Natural) is
   begin
      for Attempt in 1 .. 100 loop
         exit when Collector.Count >= Expected;
         delay 0.01;
      end loop;
   end Wait_For_Count;

   procedure Test_Listener_Registers_Child (T : in out Test) is
      pragma Unreferenced (T);
      Service : Coyote_App.Agent_RPC.Service.Service;
      Child : Channel;
      Path : constant String := Test_Endpoint ("coyote-rpc-service-register");
   begin
      Remove_Path (Path);
      Collector.Clear;
      Coyote_App.Agent_RPC.Service.Start (Service, Path, On_Frame'Access);
      Connect (Child, Path);
      Send_Frame
        (Child,
         Make_Handshake
           (Agent_Id => "worker",
            Parent_Agent_Id => "root",
            Label => "worker"));
      Wait_For_Count (1);
      Assert (Collector.Count >= 1, "service must receive child handshake");
      Assert
        (Collector.Last.Kind = Handshake,
         "first service callback must be handshake");
      Assert
        (Collector.Last_Generation = 1,
         "initial handshake must carry generation one");
      Close (Child);
      Coyote_App.Agent_RPC.Service.Stop (Service);
   end Test_Listener_Registers_Child;

   procedure Test_Command_Routes_To_Child (T : in out Test) is
      pragma Unreferenced (T);
      Service : Coyote_App.Agent_RPC.Service.Service;
      Child : Channel;
      Path : constant String := Test_Endpoint ("coyote-rpc-service-command");
      Value : Frame;
      Status : Receive_Status;
      Error : Unbounded_String;
   begin
      Remove_Path (Path);
      Collector.Clear;
      Coyote_App.Agent_RPC.Service.Start (Service, Path, On_Frame'Access);
      Connect (Child, Path);
      Send_Frame (Child, Make_Handshake (Agent_Id => "worker"));
      Wait_For_Count (1);
      Coyote_App.Agent_RPC.Service.Send_Command
        (Service,
         Agent_Id => "worker",
         Request_Id => "request-1",
         Command => Prompt,
         Payload => "{""text"":""hello""}");
      Assert
        (Receive_Frame (Child, Value, Status, Error),
         "child must receive routed command");
      Assert (Value.Kind = Command, "routed frame must be command");
      Assert
        (Value.Command_Name = Prompt,
         "routed command kind must be prompt");
      Assert
        (To_String (Value.Request_Id) = "request-1",
         "routed request identity must survive");
      Close (Child);
      Coyote_App.Agent_RPC.Service.Stop (Service);
   end Test_Command_Routes_To_Child;

   procedure Test_Disconnect_Is_Reported (T : in out Test) is
      pragma Unreferenced (T);
      Service : Coyote_App.Agent_RPC.Service.Service;
      Child : Channel;
      Path : constant String :=
        Test_Endpoint ("coyote-rpc-service-disconnect");
   begin
      Remove_Path (Path);
      Collector.Clear;
      Coyote_App.Agent_RPC.Service.Start (Service, Path, On_Frame'Access);
      Connect (Child, Path);
      Send_Frame (Child, Make_Handshake (Agent_Id => "worker"));
      Wait_For_Count (1);
      Close (Child);
      Wait_For_Count (2);
      Assert
        (Collector.Count >= 2, "service must report a disconnected child");
      Assert
        (Collector.Last.Kind = Terminal,
         "disconnect callback must be terminal");
      Assert
        (Collector.Last.Status = Disconnected,
         "disconnect callback must use disconnected status");
      Coyote_App.Agent_RPC.Service.Stop (Service);
   end Test_Disconnect_Is_Reported;

   procedure Test_Rotate_Closes_Old_Connection_And_Admits_Fresh
     (T : in out Test)
   is
      pragma Unreferenced (T);
      Service : Coyote_App.Agent_RPC.Service.Service;
      Old_Child : Channel;
      New_Child : Channel;
      Old_Path : constant String :=
        Test_Endpoint ("coyote-rpc-generation-old");
      New_Path : constant String :=
        Test_Endpoint ("coyote-rpc-generation-new");
      Old_Generation : Coyote_App.Agent_RPC.Service.Generation_Id;
      Closed_Status : Receive_Status;
      Closed_Error : Unbounded_String;
      Closed_Ready : Boolean;
      Closed_Frame : Frame;
      Closed_Result : Boolean;
      Connect_Failed : Boolean := False;
   begin
      Remove_Path (Old_Path);
      Remove_Path (New_Path);
      Collector.Clear;
      Coyote_App.Agent_RPC.Service.Start
        (Service, Old_Path, On_Frame'Access);
      Connect (Old_Child, Old_Path);
      Send_Frame (Old_Child, Make_Handshake (Agent_Id => "old-worker"));
      Wait_For_Count (1);
      Old_Generation := Coyote_App.Agent_RPC.Service.Generation (Service);
      Coyote_App.Agent_RPC.Service.Rotate
        (Service, New_Path, On_Generation'Access);
      Assert
        (Collector.Event_Count = 2
           and then Collector.Event (1).Kind = Frame_Event
           and then Collector.Event (1).Generation = Old_Generation
           and then Collector.Event (2).Kind = Generation_Event
           and then Collector.Event (2).Generation = Old_Generation + 1,
         "marker must follow old callbacks and carry new generation");
      Closed_Result := Receive_Frame
        (Old_Child, Closed_Frame, Closed_Status, Closed_Error,
         Timeout => 0.05, Ready => Closed_Ready);
      Assert
        (Closed_Result and then Closed_Ready
           and then Closed_Frame.Kind = Command
           and then Closed_Frame.Command_Name = Shutdown,
         "rotation must deliver shutdown before closing worker channel");
      Closed_Result := Receive_Frame
        (Old_Child, Closed_Frame, Closed_Status, Closed_Error,
         Timeout => 0.05, Ready => Closed_Ready);
      Assert
        (not Closed_Result and then Closed_Ready,
         "rotation must close old worker connection after shutdown");
      Assert
        (Coyote_App.Agent_RPC.Service.Generation (Service) =
           Old_Generation + 1,
         "rotation must advance service generation once");
      Assert
        (Coyote_App.Agent_RPC.Service.Endpoint (Service) = New_Path,
         "rotation must publish its fresh endpoint");
      begin
         Connect (New_Child, Old_Path);
      exception
         when Transport_Error =>
            Connect_Failed := True;
      end;
      Assert (Connect_Failed, "old endpoint must refuse new handshakes");
      Connect (New_Child, New_Path);
      Send_Frame (New_Child, Make_Handshake (Agent_Id => "new-worker"));
      Wait_For_Count (2);
      Assert
        (Collector.Last.Kind = Handshake,
         "fresh worker handshake must be delivered");
      Assert
        (Collector.Last_Generation = Old_Generation + 1,
         "fresh handshake callback must carry new generation");
      Assert
        (Collector.Event_Count = 3
           and then Collector.Event (3).Kind = Frame_Event
           and then Collector.Event (3).Generation = Old_Generation + 1,
         "new callbacks must follow the generation marker");
      Coyote_App.Agent_RPC.Service.Stop (Service);
      Close (Old_Child);
      Close (New_Child);
   exception
      when others =>
         Coyote_App.Agent_RPC.Service.Stop (Service);
         Close (Old_Child);
         Close (New_Child);
         raise;
   end Test_Rotate_Closes_Old_Connection_And_Admits_Fresh;

   procedure Test_Failed_Rotate_Retains_Service (T : in out Test) is
      pragma Unreferenced (T);
      Service : Coyote_App.Agent_RPC.Service.Service;
      Child : Channel;
      Occupant : Listener;
      Old_Path : constant String :=
        Test_Endpoint ("coyote-rpc-rotate-retained");
      Occupied_Path : constant String :=
        Test_Endpoint ("coyote-rpc-rotate-occupied");
      Value : Frame;
      Status : Receive_Status;
      Error : Unbounded_String;
      Failed : Boolean := False;
   begin
      Remove_Path (Old_Path);
      Remove_Path (Occupied_Path);
      Collector.Clear;
      Create_Listener (Occupant, Occupied_Path);
      Coyote_App.Agent_RPC.Service.Start
        (Service, Old_Path, On_Frame'Access);
      Connect (Child, Old_Path);
      Send_Frame (Child, Make_Handshake (Agent_Id => "retained-worker"));
      Wait_For_Count (1);
      begin
         Coyote_App.Agent_RPC.Service.Rotate (Service, Occupied_Path);
      exception
         when Coyote_App.Agent_RPC.Service.Service_Error =>
            Failed := True;
      end;
      Assert (Failed, "rotation onto occupied path must fail");
      Assert
        (Collector.Event_Count = 1
           and then Collector.Event (1).Kind = Frame_Event,
         "failed listener preparation must not issue a marker");
      Assert
        (Coyote_App.Agent_RPC.Service.Is_Running (Service),
         "failed rotation must leave service running");
      Assert
        (Coyote_App.Agent_RPC.Service.Endpoint (Service) = Old_Path,
         "failed rotation must retain original endpoint");
      Assert
        (Coyote_App.Agent_RPC.Service.Generation (Service) = 1,
         "failed rotation must retain generation");
      Coyote_App.Agent_RPC.Service.Send_Command
        (Service,
         Agent_Id => "retained-worker",
         Request_Id => "after-failure",
         Command => Prompt,
         Payload => "{""text"":""still connected""}");
      Assert
        (Receive_Frame (Child, Value, Status, Error),
         "original service must still route commands after failed rotation");
      Assert
        (Value.Kind = Command and then Value.Command_Name = Prompt,
         "retained listener must preserve the original worker connection");
      Coyote_App.Agent_RPC.Service.Stop (Service);
      Close (Child);
      Close (Occupant);
   exception
      when others =>
         Coyote_App.Agent_RPC.Service.Stop (Service);
         Close (Child);
         Close (Occupant);
         raise;
   end Test_Failed_Rotate_Retains_Service;

   procedure Test_Detach_And_Rotate_Recovers (T : in out Test) is
      pragma Unreferenced (T);
      Service : Coyote_App.Agent_RPC.Service.Service;
      Child : Channel;
      Fresh_Child : Channel;
      Old_Path : constant String :=
        Test_Endpoint ("coyote-rpc-detach-old");
      Fresh_Path : constant String :=
        Test_Endpoint ("coyote-rpc-detach-fresh");
      Before : Coyote_App.Agent_RPC.Service.Generation_Id;
      Value : Frame;
      Status : Receive_Status;
      Error : Unbounded_String;
      Ready : Boolean;
      Connected : Boolean := False;
   begin
      Remove_Path (Old_Path);
      Remove_Path (Fresh_Path);
      Collector.Clear;
      Coyote_App.Agent_RPC.Service.Start
        (Service, Old_Path, On_Frame'Access);
      Connect (Child, Old_Path);
      Send_Frame (Child, Make_Handshake (Agent_Id => "detach-worker"));
      Wait_For_Count (1);
      Before := Coyote_App.Agent_RPC.Service.Generation (Service);
      Coyote_App.Agent_RPC.Service.Detach
        (Service, On_Generation'Access);
      Assert
        (Collector.Event_Count = 2
           and then Collector.Event (1).Kind = Frame_Event
           and then Collector.Event (2).Kind = Generation_Event
           and then Collector.Event (2).Generation = Before + 1,
         "detach marker must follow worker callbacks");
      Assert
        (Receive_Frame (Child, Value, Status, Error)
           and then Value.Kind = Command
           and then Value.Command_Name = Shutdown,
         "detach must send shutdown before closing workers");
      Assert
        (not Receive_Frame
           (Child, Value, Status, Error, Timeout => 0.05, Ready => Ready)
           and then Ready,
         "detach must close worker channel after shutdown");
      Assert
        (Coyote_App.Agent_RPC.Service.Is_Running (Service),
         "detach must leave service task running");
      Assert
        (Coyote_App.Agent_RPC.Service.Endpoint (Service) = "",
         "detach must clear endpoint");
      Assert
        (Coyote_App.Agent_RPC.Service.Generation (Service) = Before + 1,
         "detach must advance generation");
      begin
         Connect (Fresh_Child, Old_Path);
         Connected := True;
      exception
         when Transport_Error =>
            null;
      end;
      Assert (not Connected, "detached endpoint must refuse connections");
      Coyote_App.Agent_RPC.Service.Rotate
        (Service, Fresh_Path, On_Generation'Access);
      Assert
        (Coyote_App.Agent_RPC.Service.Endpoint (Service) = Fresh_Path,
         "rotation must publish recovered listener endpoint");
      Connect (Fresh_Child, Fresh_Path);
      Send_Frame (Fresh_Child, Make_Handshake (Agent_Id => "fresh-worker"));
      Wait_For_Count (2);
      Assert
        (Collector.Last.Kind = Handshake
           and then Collector.Last_Generation = Before + 2,
         "recovered listener must register workers at new generation");
      Coyote_App.Agent_RPC.Service.Stop (Service);
      Close (Child);
      Close (Fresh_Child);
   exception
      when others =>
         Coyote_App.Agent_RPC.Service.Stop (Service);
         Close (Child);
         Close (Fresh_Child);
         raise;
   end Test_Detach_And_Rotate_Recovers;

   procedure Test_Rotate_After_Disconnect (T : in out Test) is
      pragma Unreferenced (T);
      Service : Coyote_App.Agent_RPC.Service.Service;
      Child : Channel;
      Old_Path : constant String :=
        Test_Endpoint ("coyote-rpc-disconnect-rotate-old");
      New_Path : constant String :=
        Test_Endpoint ("coyote-rpc-disconnect-rotate-new");
   begin
      Remove_Path (Old_Path);
      Remove_Path (New_Path);
      Collector.Clear;
      Coyote_App.Agent_RPC.Service.Start
        (Service, Old_Path, On_Frame'Access);
      Connect (Child, Old_Path);
      Send_Frame (Child, Make_Handshake (Agent_Id => "gone-worker"));
      Wait_For_Count (1);
      Close (Child);
      Wait_For_Count (2);
      Coyote_App.Agent_RPC.Service.Rotate
        (Service, New_Path, On_Generation'Access);
      Assert
        (Coyote_App.Agent_RPC.Service.Generation (Service) = 2,
         "rotation must succeed after disconnect");
      Assert
        (Collector.Event_Count >= 3
           and then Collector.Event (Collector.Event_Count).Kind =
             Generation_Event
           and then Collector.Event (Collector.Event_Count).Generation = 2,
         "rotation marker must follow all disconnect callbacks");
      Coyote_App.Agent_RPC.Service.Stop (Service);
   exception
      when others =>
         Coyote_App.Agent_RPC.Service.Stop (Service);
         Close (Child);
         raise;
   end Test_Rotate_After_Disconnect;

   package Agent_RPC_Service_Caller is new AUnit.Test_Caller
     (Coyote_App_Agent_RPC_Service_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test
        (Agent_RPC_Service_Caller.Create
           ("Agent RPC service registers child handshakes",
            Coyote_App_Agent_RPC_Service_Tests.Test_Listener_Registers_Child'
              Access));
      Result.Add_Test
        (Agent_RPC_Service_Caller.Create
           ("Agent RPC service routes commands",
            Coyote_App_Agent_RPC_Service_Tests.Test_Command_Routes_To_Child'
              Access));
      Result.Add_Test
        (Agent_RPC_Service_Caller.Create
           ("Agent RPC service reports disconnects",
            Coyote_App_Agent_RPC_Service_Tests.Test_Disconnect_Is_Reported'
              Access));
      Result.Add_Test
        (Agent_RPC_Service_Caller.Create
           ("Agent RPC service rotates worker generation",
            Coyote_App_Agent_RPC_Service_Tests
              .Test_Rotate_Closes_Old_Connection_And_Admits_Fresh'Access));
      Result.Add_Test
        (Agent_RPC_Service_Caller.Create
           ("Agent RPC service retains listener after failed rotation",
            Coyote_App_Agent_RPC_Service_Tests
              .Test_Failed_Rotate_Retains_Service'Access));
      Result.Add_Test
        (Agent_RPC_Service_Caller.Create
           ("Agent RPC service detaches and recovers listener",
            Coyote_App_Agent_RPC_Service_Tests
              .Test_Detach_And_Rotate_Recovers'Access));
      Result.Add_Test
        (Agent_RPC_Service_Caller.Create
           ("Agent RPC service rotates after worker disconnect",
            Coyote_App_Agent_RPC_Service_Tests
              .Test_Rotate_After_Disconnect'Access));

      return Result;
   end Suite;

end Coyote_App_Agent_RPC_Service_Tests;
