with AUnit.Test_Caller;
--  Coyote_App_Agent_RPC_Transport_Tests — local RPC channel tests.
--
--  Project: coyote

with Ada.Calendar;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Coyote_App.Agent_RPC;
with Coyote_App.Agent_RPC.Transport;
with GNAT.OS_Lib;

package body Coyote_App_Agent_RPC_Transport_Tests is

   use AUnit.Assertions;
   use Ada.Strings.Unbounded;
   use Coyote_App.Agent_RPC;
   use type Ada.Calendar.Time;
   use Coyote_App.Agent_RPC.Transport;

   procedure Remove_Path (Path : String) is
      Deleted : Boolean;
   begin
      GNAT.OS_Lib.Delete_File (Path, Deleted);
   end Remove_Path;

   function Test_Endpoint (Stem : String) return String is
      Pid_Image : constant String :=
        Ada.Strings.Fixed.Trim
          (Integer'Image
             (GNAT.OS_Lib.Pid_To_Integer
                (GNAT.OS_Lib.Current_Process_Id)),
           Ada.Strings.Both);
   begin
      return "/tmp/" & Stem & "-" & Pid_Image & ".sock";
   end Test_Endpoint;

   procedure Test_Pair_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      Left, Right : Channel;
      Sent : constant Frame :=
        Make_Handshake
          (Agent_Id        => "worker",
           Parent_Agent_Id => "root",
           Label           => "worker");
      Received : Frame;
      Status : Receive_Status;
      Error  : Unbounded_String;
   begin
      Create_Pair (Left, Right);
      Send_Frame (Left, Sent);
      Assert (Receive_Frame (Right, Received, Status, Error),
              "peer must receive a complete handshake frame");
      Assert (Status = Frame_Received, "handshake status must be received");
      Assert (Received.Kind = Handshake,
              "received frame kind must be handshake");
      Assert (To_String (Received.Agent_Id) = "worker",
              "received agent identity must survive transport");
      Close (Left);
      Close (Right);
   end Test_Pair_Round_Trip;

   procedure Test_Handshake_Ordering (T : in out Test) is
      pragma Unreferenced (T);
      Left, Right : Channel;
      Event : constant Frame :=
        Make_Event
          (Agent_Id => "worker", Sequence => 1, Event_Name => Agent_Start);
      Received : Frame;
      Status : Receive_Status;
      Error  : Unbounded_String;
      Rejected : Boolean := False;
   begin
      Create_Pair (Left, Right);
      begin
         Send_Frame (Left, Event);
      exception
         when Transport_Error =>
            Rejected := True;
      end;
      Assert (Rejected, "event before handshake must be rejected");
      Send_Frame (Left, Make_Handshake (Agent_Id => "worker"));
      Assert (Receive_Frame (Right, Received, Status, Error),
              "handshake must be received");
      Send_Frame (Left, Event);
      Assert (Receive_Frame (Right, Received, Status, Error),
              "ordered event must be received");
      Close (Left);
      Close (Right);
   end Test_Handshake_Ordering;

   procedure Test_Event_Sequence_Must_Increase (T : in out Test) is
      pragma Unreferenced (T);
      Left, Right : Channel;
      Received : Frame;
      Status : Receive_Status;
      Error  : Unbounded_String;
      First_Event : constant Frame :=
        Make_Event
          (Agent_Id => "worker", Sequence => 1, Event_Name => Agent_Start);
      Duplicate_Event : constant Frame :=
        Make_Event
          (Agent_Id => "worker", Sequence => 1, Event_Name => Text_End);
      Rejected : Boolean := False;
   begin
      Create_Pair (Left, Right);
      Send_Frame (Left, Make_Handshake (Agent_Id => "worker"));
      Assert (Receive_Frame (Right, Received, Status, Error),
              "handshake must be received");
      Send_Frame (Left, First_Event);
      Assert (Receive_Frame (Right, Received, Status, Error),
              "first event must be received");
      begin
         Send_Frame (Left, Duplicate_Event);
      exception
         when Transport_Error =>
            Rejected := True;
      end;
      Assert (Rejected, "duplicate event sequence must be rejected");
      Close (Left);
      Close (Right);
   end Test_Event_Sequence_Must_Increase;

   procedure Test_Terminal_Closes_Send_Side (T : in out Test) is
      pragma Unreferenced (T);
      Left, Right : Channel;
      Received : Frame;
      Status : Receive_Status;
      Error  : Unbounded_String;
      Event : constant Frame :=
        Make_Event
          (Agent_Id => "worker", Sequence => 1, Event_Name => Agent_Start);
      Rejected : Boolean := False;
   begin
      Create_Pair (Left, Right);
      Send_Frame (Left, Make_Handshake (Agent_Id => "worker"));
      Assert (Receive_Frame (Right, Received, Status, Error),
              "handshake must be received");
      Send_Frame
        (Left, Make_Terminal (Agent_Id => "worker", Status => Completed));
      Assert (Receive_Frame (Right, Received, Status, Error),
              "terminal frame must be received");
      begin
         Send_Frame (Left, Event);
      exception
         when Transport_Error =>
            Rejected := True;
      end;
      Assert (Rejected, "frames after terminal must be rejected");
      Close (Left);
      Close (Right);
   end Test_Terminal_Closes_Send_Side;

   procedure Test_Peer_Close_Is_Reported (T : in out Test) is
      pragma Unreferenced (T);
      Left, Right : Channel;
      Received : Frame;
      Status : Receive_Status;
      Error  : Unbounded_String;
   begin
      Create_Pair (Left, Right);
      Close (Left);
      Assert (not Receive_Frame (Right, Received, Status, Error),
              "peer close must return false");
      Assert (Status = Peer_Closed,
              "peer close must have the peer-closed status");
      Close (Right);
   end Test_Peer_Close_Is_Reported;

   procedure Test_Receive_Times_Out_When_Idle (T : in out Test) is
      pragma Unreferenced (T);
      Left, Right : Channel;
      Value        : Frame;
      Status       : Receive_Status;
      Error        : Unbounded_String;
      Ready        : Boolean := True;
      Started      : constant Ada.Calendar.Time := Ada.Calendar.Clock;
      Result       : Boolean;
   begin
      Create_Pair (Left, Right);
      Result := Receive_Frame
        (Right, Value, Status, Error, Timeout => 0.05, Ready => Ready);
      Assert (not Result, "idle receive must not produce a frame");
      Assert (not Ready, "idle receive must report not ready");
      Assert (Ada.Calendar.Clock - Started < 0.5,
              "idle receive must return within its timeout");
      Close (Left);
      Close (Right);
   exception
      when others =>
         Close (Left);
         Close (Right);
         raise;
   end Test_Receive_Times_Out_When_Idle;

   procedure Test_Unix_Listener_Times_Out_When_Idle (T : in out Test) is
      pragma Unreferenced (T);
      Listener : Coyote_App.Agent_RPC.Transport.Listener;
      Client   : Channel;
      Path     : constant String := Test_Endpoint
        ("coyote-rpc-transport-timeout");
      Accepted : Boolean := True;
      Started  : constant Ada.Calendar.Time := Ada.Calendar.Clock;
   begin
      Remove_Path (Path);
      Create_Listener (Listener, Path);
      Accept_Channel (Listener, Client, 0.05, Accepted);
      Assert (not Accepted, "idle listener must report a timeout");
      Assert (Ada.Calendar.Clock - Started < 0.5,
              "idle listener must return within its timeout");
      Close (Listener);
   exception
      when others =>
         Close (Client);
         Close (Listener);
         raise;
   end Test_Unix_Listener_Times_Out_When_Idle;

   procedure Test_Unix_Listener_Accepts_Client (T : in out Test) is
      pragma Unreferenced (T);
      Listener : Coyote_App.Agent_RPC.Transport.Listener;
      Client   : Channel;
      Server   : Channel;
      Path     : constant String := Test_Endpoint
        ("coyote-rpc-transport-listener");
      Value    : Frame;
      Status   : Receive_Status;
      Error    : Unbounded_String;
      Accepted : Boolean := False;

      task Acceptor is
         entry Start;
      end Acceptor;
      task body Acceptor is
      begin
         accept Start;
         Coyote_App.Agent_RPC.Transport.Accept_Channel
           (Listener, Server, 2.0, Accepted);
      exception
         when others =>
            Accepted := False;
      end Acceptor;
   begin
      Remove_Path (Path);
      Create_Listener (Listener, Path);
      Acceptor.Start;
      Connect (Client, Path);
      Send_Frame (Client, Make_Handshake (Agent_Id => "worker"));
      delay 0.05;
      Assert (Accepted, "Unix listener must accept a connected client");
      Assert (Receive_Frame (Server, Value, Status, Error),
              "accepted channel must receive client handshake");
      Assert (Value.Kind = Handshake,
              "accepted channel frame must be a handshake");
      Close (Client);
      Close (Server);
      Close (Listener);
   end Test_Unix_Listener_Accepts_Client;

   package Agent_RPC_Transport_Caller is
     new AUnit.Test_Caller (Coyote_App_Agent_RPC_Transport_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Agent_RPC_Transport_Caller.Create
        ("Agent RPC transport pair round-trips a handshake",
         Coyote_App_Agent_RPC_Transport_Tests.Test_Pair_Round_Trip'Access));
      Result.Add_Test (Agent_RPC_Transport_Caller.Create
        ("Agent RPC transport enforces handshake ordering",
         Coyote_App_Agent_RPC_Transport_Tests.Test_Handshake_Ordering'Access));
      Result.Add_Test (Agent_RPC_Transport_Caller.Create
        ("Agent RPC transport enforces increasing event sequence",
         Coyote_App_Agent_RPC_Transport_Tests
           .Test_Event_Sequence_Must_Increase'Access));
      Result.Add_Test (Agent_RPC_Transport_Caller.Create
        ("Agent RPC transport rejects frames after terminal",
         Coyote_App_Agent_RPC_Transport_Tests
           .Test_Terminal_Closes_Send_Side'Access));
      Result.Add_Test (Agent_RPC_Transport_Caller.Create
        ("Agent RPC transport reports peer close",
         Coyote_App_Agent_RPC_Transport_Tests
           .Test_Peer_Close_Is_Reported'Access));
      Result.Add_Test (Agent_RPC_Transport_Caller.Create
        ("Agent RPC transport receive times out when idle",
         Coyote_App_Agent_RPC_Transport_Tests
           .Test_Receive_Times_Out_When_Idle'Access));
      Result.Add_Test (Agent_RPC_Transport_Caller.Create
        ("Agent RPC transport listener times out when idle",
         Coyote_App_Agent_RPC_Transport_Tests
           .Test_Unix_Listener_Times_Out_When_Idle'Access));
      Result.Add_Test (Agent_RPC_Transport_Caller.Create
        ("Agent RPC transport accepts Unix clients",
         Coyote_App_Agent_RPC_Transport_Tests
           .Test_Unix_Listener_Accepts_Client'Access));

      return Result;
   end Suite;

end Coyote_App_Agent_RPC_Transport_Tests;
