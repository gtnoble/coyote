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

package Coyote_App.Agent_RPC.Service is

   Max_Connections : constant Positive := 32;

   type Generation_Id is new Natural;
   type Frame_Handler is access procedure
     (Value : Coyote_App.Agent_RPC.Frame; Generation : Generation_Id);
   type Generation_Handler is access procedure
     (Generation : Generation_Id);

   type Service is limited private;

   procedure Start
     (S : in out Service; Path : String; Handler : not null Frame_Handler);

   --  Close current workers and replace the listener with a fresh endpoint.
   --  Path must be unique for this coordinator-session generation.
   --  On_Rotate executes on the service task after replacement and before
   --  connection polling resumes.
   procedure Rotate
     (S : in out Service;
      Path : String;
      On_Rotate : Generation_Handler := null);

   --  Retire the endpoint while leaving the service task responsive.
   procedure Detach
     (S : in out Service;
      On_Rotate : Generation_Handler := null);

   procedure Send_Command
     (S          : in out Service;
      Agent_Id   :        String;
      Request_Id :        String;
      Command    :        Coyote_App.Agent_RPC.Command_Kind;
      Payload    :        String := "{}");

   procedure Stop (S : in out Service);
   function Endpoint (S : Service) return String;
   function Generation (S : Service) return Generation_Id;
   function Is_Running (S : Service) return Boolean;

   Service_Error : exception;

private

   task type Service_Task is
      entry Start (Path : String; Callback : not null Frame_Handler);
      entry Rotate
        (Path : String;
         Generation : Generation_Id;
         On_Rotate : Generation_Handler;
         Succeeded : out Boolean;
         Error : out Ada.Strings.Unbounded.Unbounded_String);
      entry Detach
        (Generation : Generation_Id;
         On_Rotate : Generation_Handler;
         Error : out Ada.Strings.Unbounded.Unbounded_String);
      entry Send_Command
        (Agent_Id   :     String;
         Request_Id :     String;
         Command    :     Coyote_App.Agent_RPC.Command_Kind;
         Payload    :     String;
         Sent       : out Boolean);
      entry Stop;
   end Service_Task;

   type Service is limited record
      Worker     : Service_Task;
      Endpoint   : Ada.Strings.Unbounded.Unbounded_String;
      Current_Generation : Generation_Id := 0;
      Running    : Boolean := False;
   end record;

end Coyote_App.Agent_RPC.Service;
