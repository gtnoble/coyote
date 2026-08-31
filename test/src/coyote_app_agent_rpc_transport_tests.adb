--  Coyote_App_Agent_RPC_Transport_Tests — local RPC channel tests.
--
--  Project: coyote

with Ada.Directories;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Coyote_App.Agent_RPC;
with Coyote_App.Agent_RPC.Transport;

package body Coyote_App_Agent_RPC_Transport_Tests is

   use AUnit.Assertions;
   use Ada.Strings.Unbounded;
   use Coyote_App.Agent_RPC;
   use Coyote_App.Agent_RPC.Transport;

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

   procedure Test_Unix_Listener_Accepts_Client (T : in out Test) is
      pragma Unreferenced (T);
      Listener : Coyote_App.Agent_RPC.Transport.Listener;
      Client   : Channel;
      Server   : Channel;
      Path     : constant String := "/tmp/coyote-rpc-transport-listener.sock";
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
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_File (Path);
      end if;
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

end Coyote_App_Agent_RPC_Transport_Tests;
