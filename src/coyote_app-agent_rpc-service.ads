--  Coyote_App.Agent_RPC.Service — coordinator-side local RPC service.
--
--  Owns the Unix-domain listener and short-lived child connections.  Frame
--  delivery is callback-based so GUI state can be marshalled through its
--  protected update queue rather than touched by service tasks.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;
with Coyote_App.Agent_RPC;
with Coyote_App.Agent_RPC.Transport;

package Coyote_App.Agent_RPC.Service is

   Max_Connections : constant Positive := 32;

   type Frame_Handler is access procedure
     (Value : Coyote_App.Agent_RPC.Frame);

   type Service is limited private;

   procedure Start
     (S       : in out Service;
      Path    : String;
      Handler : not null Frame_Handler);

   procedure Send_Command
     (S          : in out Service;
      Agent_Id   : String;
      Request_Id : String;
      Command    : Coyote_App.Agent_RPC.Command_Kind;
      Payload    : String := "{}");

   procedure Stop (S : in out Service);
   function Endpoint (S : Service) return String;
   function Is_Running (S : Service) return Boolean;

   Service_Error : exception;

private

   task type Service_Task is
      entry Start (Path : String; Callback : not null Frame_Handler);
      entry Send_Command
        (Agent_Id   : String;
         Request_Id : String;
         Command    : Coyote_App.Agent_RPC.Command_Kind;
         Payload    : String;
         Sent       : out Boolean);
      entry Stop;
   end Service_Task;

   type Service is limited record
      Worker   : Service_Task;
      Endpoint : Ada.Strings.Unbounded.Unbounded_String;
      Running  : Boolean := False;
   end record;

end Coyote_App.Agent_RPC.Service;
