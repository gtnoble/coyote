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
with Ada.Unchecked_Deallocation;
with Coyote_App.Agent_RPC;
with Coyote_App.Agent_RPC.Transport;

package body Coyote_App.Agent_RPC.Service is

   use Ada.Strings.Unbounded;
   use Coyote_App.Agent_RPC;
   use Coyote_App.Agent_RPC.Transport;

   type Channel_Access is access all Channel;
   type Listener_Access is access Listener;

   procedure Free_Channel is
     new Ada.Unchecked_Deallocation (Channel, Channel_Access);

   procedure Free_Listener is
     new Ada.Unchecked_Deallocation (Listener, Listener_Access);

   type Connection_Slot is record
      Channel : Channel_Access   := null;
      Agent   : Unbounded_String := Null_Unbounded_String;
   end record;

   type Connection_Slots is
     array (Positive range 1 .. Max_Connections) of Connection_Slot;

   procedure Close_Connections (Slots : in out Connection_Slots) is
   begin
      for Slot of Slots loop
         if Slot.Channel /= null then
            Close (Slot.Channel.all);
            Free_Channel (Slot.Channel);
            Slot.Agent := Null_Unbounded_String;
         end if;
      end loop;
   end Close_Connections;

   procedure Shutdown_Connections (Slots : in out Connection_Slots) is
   begin
      for Slot of Slots loop
         if Slot.Channel /= null then
            if Length (Slot.Agent) > 0 then
               declare
                  Sent : Boolean;
                  pragma Unreferenced (Sent);
               begin
                  --  A non-reading worker must not hold up a session reset.
                  Sent := Try_Send_Frame
                    (Slot.Channel.all,
                     Make_Command
                       (Agent_Id => To_String (Slot.Agent),
                        Request_Id => "rotate-shutdown",
                        Command_Name => Shutdown));
               exception
                  when others =>
                     null;
               end;
            end if;
         end if;
      end loop;
      Close_Connections (Slots);
   end Shutdown_Connections;

   task body Service_Task is
      L                 : Listener_Access := null;
      Handler           : Frame_Handler := null;
      Slots             : Connection_Slots;
      Stopping          : Boolean := False;
      Active_Generation : Generation_Id := 0;

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
            if Slot.Channel /= null and then Is_Open (Slot.Channel.all) then
               if Receive_Frame
                   (Slot.Channel.all, Value, Status, Error, Timeout => 0.01,
                    Ready => Ready) and then Ready
               then
                  if Value.Kind = Handshake then
                     Slot.Agent := Value.Agent_Id;
                  end if;
                  declare
                     Callback_Generation : constant Generation_Id :=
                       Active_Generation;
                  begin
                     Handler (Value, Callback_Generation);
                  end;
                  if Value.Kind = Terminal then
                     Close (Slot.Channel.all);
                     Free_Channel (Slot.Channel);
                     Slot.Agent := Null_Unbounded_String;
                  end if;
               elsif Ready then
                  if Length (Slot.Agent) > 0 then
                     begin
                        declare
                           Callback_Generation : constant Generation_Id :=
                             Active_Generation;
                        begin
                           Handler
                             (Make_Terminal
                                (Agent_Id => To_String (Slot.Agent),
                                 Status => Disconnected,
                                 Error_Text => To_String (Error)),
                              Callback_Generation);
                        end;
                     exception
                        when others =>
                           null;
                     end;
                  end if;
                  Close (Slot.Channel.all);
                  Free_Channel (Slot.Channel);
                  Slot.Agent := Null_Unbounded_String;
               end if;
            end if;
         end loop;
      end Poll_Connections;
   begin
      accept Start (Path : String; Callback : not null Frame_Handler) do
         Handler := Callback;
         Active_Generation := 1;
         L := new Listener;
         Create_Listener (L.all, Path);
      end Start;

      while not Stopping loop
         select
            accept Send_Command
              (Agent_Id : String;
               Request_Id : String;
               Command : Coyote_App.Agent_RPC.Command_Kind;
               Payload : String;
               Sent : out Boolean)
            do
               Sent := False;
               for Slot of Slots loop
                  if Slot.Channel /= null
                    and then To_String (Slot.Agent) = Agent_Id
                  then
                     Send_Frame
                       (Slot.Channel.all,
                        Make_Command
                          (Agent_Id => Agent_Id,
                           Request_Id => Request_Id,
                           Command_Name => Command,
                           Payload_Json => Payload));
                     Sent := True;
                     exit;
                  end if;
               end loop;
            end Send_Command;
         or
            accept Rotate
              (Path : String;
               Generation : Generation_Id;
               On_Rotate : Generation_Handler;
               Succeeded : out Boolean;
               Error : out Unbounded_String)
            do
               Succeeded := False;
               Error := Null_Unbounded_String;
               declare
                  Fresh_Listener : Listener_Access := null;
               begin
                  Fresh_Listener := new Listener;
                  begin
                     Create_Listener (Fresh_Listener.all, Path);
                  exception
                     when E : others =>
                        Error := To_Unbounded_String
                          (Ada.Exceptions.Exception_Message (E));
                        Free_Listener (Fresh_Listener);
                  end;

                  if Fresh_Listener /= null then
                     Shutdown_Connections (Slots);
                     if L /= null then
                        Close (L.all);
                        Free_Listener (L);
                     end if;
                     L := Fresh_Listener;
                     Fresh_Listener := null;
                     Active_Generation := Generation;
                     Succeeded := True;
                     if On_Rotate /= null then
                        On_Rotate (Active_Generation);
                     end if;
                  end if;
               exception
                  when E : others =>
                     if Fresh_Listener /= null then
                        Close (Fresh_Listener.all);
                        Free_Listener (Fresh_Listener);
                     end if;
                     Error := To_Unbounded_String
                       (Ada.Exceptions.Exception_Message (E));
                     Succeeded := L /= null;
               end;
            end Rotate;
         or
            accept Detach
              (Generation : Generation_Id;
               On_Rotate : Generation_Handler;
               Error : out Unbounded_String)
            do
               Error := Null_Unbounded_String;
               begin
                  Shutdown_Connections (Slots);
                  if L /= null then
                     Close (L.all);
                     Free_Listener (L);
                  end if;
                  L := null;
                  Active_Generation := Generation;
                  if On_Rotate /= null then
                     On_Rotate (Active_Generation);
                  end if;
               exception
                  when E : others =>
                     Error := To_Unbounded_String
                       (Ada.Exceptions.Exception_Message (E));
               end;
            end Detach;
         or
            accept Stop do
               Stopping := True;
               Close_Connections (Slots);
               if L /= null then
                  Close (L.all);
                  Free_Listener (L);
               end if;
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
               if L /= null and then Slot_Index > 0 then
                  New_Channel := new Channel;
                  begin
                     Accept_Channel
                       (L => L.all, C => New_Channel.all, Timeout => 0.01,
                        Accepted => Accepted);
                     if Accepted then
                        Slots (Slot_Index).Channel := New_Channel;
                        Slots (Slot_Index).Agent := Null_Unbounded_String;
                     else
                        Close (New_Channel.all);
                        Free_Channel (New_Channel);
                     end if;
                  exception
                     when others =>
                        if New_Channel /= null then
                           Close (New_Channel.all);
                           Free_Channel (New_Channel);
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
         if L /= null then
            Close (L.all);
            Free_Listener (L);
         end if;
   end Service_Task;

   procedure Start
     (S : in out Service; Path : String; Handler : not null Frame_Handler)
   is
   begin
      if S.Running then
         raise Service_Error with "RPC service is already running";
      end if;
      S.Worker.Start (Path, Handler);
      S.Endpoint := To_Unbounded_String (Path);
      S.Current_Generation := 1;
      S.Running := True;
   exception
      when E : Service_Error =>
         raise;
      when E : others =>
         raise Service_Error with Ada.Exceptions.Exception_Message (E);
   end Start;

   procedure Rotate
     (S : in out Service;
      Path : String;
      On_Rotate : Generation_Handler := null)
   is
      Fresh_Generation : constant Generation_Id :=
        S.Current_Generation + 1;
      Succeeded : Boolean;
      Error : Unbounded_String;
   begin
      if not S.Running then
         raise Service_Error with "RPC service is not running";
      end if;
      if Path = Endpoint (S) then
         raise Service_Error with "RPC rotation requires a unique endpoint";
      end if;
      S.Worker.Rotate
        (Path => Path, Generation => Fresh_Generation,
         On_Rotate => On_Rotate,
         Succeeded => Succeeded, Error => Error);
      if not Succeeded then
         raise Service_Error with "RPC listener rotation failed: " &
           To_String (Error);
      end if;
      S.Endpoint := To_Unbounded_String (Path);
      S.Current_Generation := Fresh_Generation;
      if Length (Error) > 0 then
         raise Service_Error with "RPC rotation callback failed: " &
           To_String (Error);
      end if;
   exception
      when E : Service_Error =>
         raise;
      when E : others =>
         raise Service_Error with Ada.Exceptions.Exception_Message (E);
   end Rotate;

   procedure Detach
     (S : in out Service;
      On_Rotate : Generation_Handler := null)
   is
      Next_Generation : constant Generation_Id :=
        S.Current_Generation + 1;
      Error : Unbounded_String;
   begin
      if not S.Running then
         raise Service_Error with "RPC service is not running";
      end if;
      S.Worker.Detach
        (Generation => Next_Generation,
         On_Rotate => On_Rotate,
         Error => Error);
      S.Endpoint := Null_Unbounded_String;
      S.Current_Generation := Next_Generation;
      if Length (Error) > 0 then
         raise Service_Error with "RPC service detach failed: " &
           To_String (Error);
      end if;
   exception
      when E : Service_Error =>
         raise;
      when E : others =>
         raise Service_Error with Ada.Exceptions.Exception_Message (E);
   end Detach;

   procedure Send_Command
     (S : in out Service;
      Agent_Id : String;
      Request_Id : String;
      Command : Coyote_App.Agent_RPC.Command_Kind;
      Payload : String := "{}")
   is
      Sent : Boolean;
   begin
      if not S.Running then
         raise Service_Error with "RPC service is not running";
      end if;
      S.Worker.Send_Command
        (Agent_Id => Agent_Id, Request_Id => Request_Id,
         Command => Command, Payload => Payload, Sent => Sent);
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

   function Generation (S : Service) return Generation_Id is
   begin
      return S.Current_Generation;
   end Generation;

   function Is_Running (S : Service) return Boolean is
   begin
      return S.Running;
   end Is_Running;

end Coyote_App.Agent_RPC.Service;
