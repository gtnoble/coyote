--  Coyote_App.Agent_RPC.Transport — local framed RPC channels.
--
--  Provides newline-delimited transport for versioned Agent_RPC frames over
--  Unix-domain stream sockets.  The codec remains independent of I/O.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;
with Coyote_App.Agent_RPC;
with GNAT.Sockets;

package Coyote_App.Agent_RPC.Transport is

   Max_Frame_Length : constant Positive := 1_048_576;

   type Channel is limited private;
   type Listener is limited private;

   type Receive_Status is
     (Frame_Received,
      Peer_Closed,
      Malformed_Frame,
      Unsupported_Frame_Version,
      Invalid_Frame);

   --  Create an endpoint at Path.  The caller owns the listener and must
   --  close it; Path is removed when the listener closes.
   procedure Create_Listener
     (L    : out Listener;
      Path : String);

   procedure Accept_Channel
     (L : in out Listener;
      C : out Channel);

   procedure Accept_Channel
     (L        : in out Listener;
      C        : out Channel;
      Timeout  : Duration;
      Accepted : out Boolean);

   procedure Connect
     (C    : out Channel;
      Path : String);

   --  Create a connected pair without a filesystem endpoint.  This is useful
   --  for deterministic transport tests and in-process coordination.
   procedure Create_Pair
     (Left  : out Channel;
      Right : out Channel);

   procedure Close (C : in out Channel);
   procedure Close (L : in out Listener);
   function Is_Open (C : Channel) return Boolean;

   procedure Send_Frame
     (C     : in out Channel;
      Value : Coyote_App.Agent_RPC.Frame);

   --  Receive one complete newline-delimited frame.  False means the peer
   --  closed or supplied an invalid frame; Status and Error identify why.
   function Receive_Frame
     (C      : in out Channel;
      Value  : out Coyote_App.Agent_RPC.Frame;
      Status : out Receive_Status;
      Error  : out Ada.Strings.Unbounded.Unbounded_String) return Boolean;

   function Receive_Frame
     (C       : in out Channel;
      Value   : out Coyote_App.Agent_RPC.Frame;
      Status  : out Receive_Status;
      Error   : out Ada.Strings.Unbounded.Unbounded_String;
      Timeout : Duration;
      Ready   : out Boolean) return Boolean;

   Transport_Error : exception;

private

   type Channel is limited record
      Socket           : GNAT.Sockets.Socket_Type := GNAT.Sockets.No_Socket;
      Input            : Ada.Strings.Unbounded.Unbounded_String;
      Sent_Handshake   : Boolean := False;
      Sent_Terminal    : Boolean := False;
      Got_Handshake    : Boolean := False;
      Got_Terminal     : Boolean := False;
      Last_Event_Sequence : Natural := 0;
   end record;

   type Listener is limited record
      Socket   : GNAT.Sockets.Socket_Type := GNAT.Sockets.No_Socket;
      Endpoint : Ada.Strings.Unbounded.Unbounded_String;
   end record;

end Coyote_App.Agent_RPC.Transport;
