--  Coyote_App.Agent_RPC.Service — coordinator-side local RPC service.
--
--  A single service task owns the listener and all accepted channels.  It
--  polls each channel without blocking, which keeps command rendezvous and
--  shutdown responsive while preserving bounded multi-agent fan-out.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Exceptions;
with Ada.Strings.Unbounded;
with Coyote_App.Agent_RPC;
with Coyote_App.Agent_RPC.Transport;

package body Coyote_App.Agent_RPC.Service is

   use Ada.Strings.Unbounded;
   use Coyote_App.Agent_RPC;
   use Coyote_App.Agent_RPC.Transport;

   type Channel_Access is access all Channel;

   type Connection_Slot is record
      Channel : Channel_Access := null;
      Agent   : Unbounded_String := Null_Unbounded_String;
   end record;

   type Connection_Slots is array (Positive range 1 .. Max_Connections)
     of Connection_Slot;

   procedure Close_Connections (Slots : in out Connection_Slots) is
   begin
      for Slot of Slots loop
         if Slot.Channel /= null then
            Close (Slot.Channel.all);
            Slot.Channel := null;
            Slot.Agent := Null_Unbounded_String;
         end if;
      end loop;
   end Close_Connections;

   task body Service_Task is
      L        : Listener;
      Handler  : Frame_Handler := null;
      Slots    : Connection_Slots;
      Stopping : Boolean := False;

      function Find_Free return Natural is
      begin
         for Index in Slots'Range loop
            if Slots (Index).Channel = null then
               return Index;
            end if;
         end loop;
         return 0;
      end Find_Free;

      procedure Poll_Connections is
         Value  : Frame;
         Status : Receive_Status;
         Error  : Unbounded_String;
         Ready  : Boolean;
      begin
         for Slot of Slots loop
            if Slot.Channel /= null
              and then Is_Open (Slot.Channel.all)
            then
               if Receive_Frame
                 (Slot.Channel.all, Value, Status, Error,
                  Timeout => 0.01, Ready => Ready)
                 and then Ready
               then
                  if Value.Kind = Handshake then
                     Slot.Agent := Value.Agent_Id;
                  end if;
                  Handler (Value);
                  if Value.Kind = Terminal then
                     Close (Slot.Channel.all);
                     Slot.Channel := null;
                     Slot.Agent := Null_Unbounded_String;
                  end if;
               elsif Ready then
                  if Length (Slot.Agent) > 0 then
                     begin
                        Handler
                          (Make_Terminal
                             (Agent_Id   => To_String (Slot.Agent),
                              Status     => Disconnected,
                              Error_Text => To_String (Error)));
                     exception
                        when others => null;
                     end;
                  end if;
                  Close (Slot.Channel.all);
                  Slot.Channel := null;
                  Slot.Agent := Null_Unbounded_String;
               end if;
            end if;
         end loop;
      end Poll_Connections;
   begin
      accept Start
        (Path :  String;
         Callback : not null Frame_Handler)
      do
         Handler := Callback;
         Create_Listener (L, Path);
      end Start;

      while not Stopping loop
         select
            accept Send_Command
              (Agent_Id   : String;
               Request_Id : String;
               Command    : Coyote_App.Agent_RPC.Command_Kind;
               Payload    : String;
               Sent       : out Boolean)
            do
               Sent := False;
               for Slot of Slots loop
                  if Slot.Channel /= null
                    and then To_String (Slot.Agent) = Agent_Id
                  then
                     Send_Frame
                       (Slot.Channel.all,
                        Make_Command
                          (Agent_Id     => Agent_Id,
                           Request_Id   => Request_Id,
                           Command_Name => Command,
                           Payload_Json => Payload));
                     Sent := True;
                     exit;
                  end if;
               end loop;
            end Send_Command;
         or
            accept Stop do
               Stopping := True;
               Close_Connections (Slots);
               Close (L);
            end Stop;
         or
            delay 0.01;
         end select;

         if not Stopping then
            declare
               Slot_Index : constant Natural := Find_Free;
               New_Channel : Channel_Access := null;
               Accepted : Boolean := False;
            begin
               if Slot_Index > 0 then
                  New_Channel := new Channel;
                  begin
                     Accept_Channel
                       (L        => L,
                        C        => New_Channel.all,
                        Timeout  => 0.01,
                        Accepted => Accepted);
                     if Accepted then
                        Slots (Slot_Index).Channel := New_Channel;
                        Slots (Slot_Index).Agent := Null_Unbounded_String;
                     else
                        Close (New_Channel.all);
                        New_Channel := null;
                     end if;
                  exception
                     when others =>
                        if New_Channel /= null then
                           Close (New_Channel.all);
                        end if;
                  end;
               end if;
            end;
            Poll_Connections;
         end if;
      end loop;
   exception
      when others =>
         Close_Connections (Slots);
         Close (L);
   end Service_Task;

   procedure Start
     (S       : in out Service;
      Path    : String;
      Handler : not null Frame_Handler)
   is
   begin
      if S.Running then
         raise Service_Error with "RPC service is already running";
      end if;
      S.Worker.Start (Path, Handler);
      S.Endpoint := To_Unbounded_String (Path);
      S.Running := True;
   exception
      when E : Service_Error =>
         raise;
      when E : others =>
         raise Service_Error with Ada.Exceptions.Exception_Message (E);
   end Start;

   procedure Send_Command
     (S          : in out Service;
      Agent_Id   : String;
      Request_Id : String;
      Command    : Coyote_App.Agent_RPC.Command_Kind;
      Payload    : String := "{}")
   is
      Sent : Boolean;
   begin
      if not S.Running then
         raise Service_Error with "RPC service is not running";
      end if;
      S.Worker.Send_Command
        (Agent_Id   => Agent_Id,
         Request_Id => Request_Id,
         Command    => Command,
         Payload    => Payload,
         Sent       => Sent);
      if not Sent then
         raise Service_Error with "unknown or inactive RPC agent: " & Agent_Id;
      end if;
   exception
      when E : Service_Error =>
         raise;
      when E : others =>
         raise Service_Error with Ada.Exceptions.Exception_Message (E);
   end Send_Command;

   procedure Stop (S : in out Service) is
   begin
      if S.Running then
         S.Worker.Stop;
         S.Running := False;
      end if;
      S.Endpoint := Null_Unbounded_String;
   exception
      when E : others =>
         S.Running := False;
         S.Endpoint := Null_Unbounded_String;
         raise Service_Error with Ada.Exceptions.Exception_Message (E);
   end Stop;

   function Endpoint (S : Service) return String is
   begin
      return To_String (S.Endpoint);
   end Endpoint;

   function Is_Running (S : Service) return Boolean is
   begin
      return S.Running;
   end Is_Running;

end Coyote_App.Agent_RPC.Service;
