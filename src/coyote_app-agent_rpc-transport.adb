with Ada.Calendar;
--  Coyote_App.Agent_RPC.Transport — local framed RPC channels.
--
--  The transport reads arbitrary socket chunks into an unbounded buffer, then
--  extracts exactly one newline-delimited JSON frame per Receive_Frame call.
--  Protocol state is checked here so callers cannot send duplicate handshakes,
--  post-terminal frames, or out-of-order event sequences.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Characters.Latin_1;
with Ada.Exceptions;
with Ada.Streams;
with GNAT.OS_Lib;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with GNAT.Sockets;
with Coyote_App.Agent_RPC;

package body Coyote_App.Agent_RPC.Transport is

   use Ada.Strings.Unbounded;
   use GNAT.Sockets;
   use type Ada.Calendar.Time;
   use type Ada.Streams.Stream_Element_Offset;
   use type Coyote_App.Agent_RPC.Frame_Kind;
   use type Coyote_App.Agent_RPC.Event_Kind;

   procedure Require_Open (C : Channel) is
   begin
      if C.Socket = No_Socket then
         raise Transport_Error with "RPC channel is closed";
      end if;
   end Require_Open;

   procedure Create_Listener
     (L    : out Listener;
      Path : String)
   is
      Address : Sock_Addr_Type;
   begin
      if Path'Length = 0 then
         raise Transport_Error with "RPC listener path is empty";
      end if;
      Create_Socket (L.Socket, Family_Unix, Socket_Stream);
      Address := Unix_Socket_Address (Path);
      Bind_Socket (L.Socket, Address);
      Listen_Socket (L.Socket, 1);
      L.Endpoint := To_Unbounded_String (Path);
   exception
      when E : others =>
         if L.Socket /= No_Socket then
            Close_Socket (L.Socket);
            L.Socket := No_Socket;
         end if;
         raise Transport_Error with Ada.Exceptions.Exception_Message (E);
   end Create_Listener;

   procedure Initialize_Channel (C : out Channel) is
   begin
      C.Input := Null_Unbounded_String;
      C.Sent_Handshake := False;
      C.Sent_Terminal := False;
      C.Got_Handshake := False;
      C.Got_Terminal := False;
      C.Last_Event_Sequence := 0;
   end Initialize_Channel;

   procedure Accept_Channel
     (L : in out Listener;
      C : out Channel)
   is
      Accepted : Boolean;
   begin
      Accept_Channel (L, C, Forever, Accepted);
      if not Accepted then
         raise Transport_Error with "RPC listener accept timed out";
      end if;
   end Accept_Channel;

   procedure Accept_Channel
     (L        : in out Listener;
      C        : out Channel;
      Timeout  : Duration;
      Accepted : out Boolean)
   is
      Address        : Sock_Addr_Type;
      Selector_State : Selector_Status;
      Request        : Request_Type :=
        (Name => Non_Blocking_IO, Enabled => False);
   begin
      Accepted := False;
      if L.Socket = No_Socket then
         raise Transport_Error with "RPC listener is closed";
      end if;

      Accept_Socket
        (Server  => L.Socket,
         Socket  => C.Socket,
         Address => Address,
         Timeout => Selector_Duration (Timeout),
         Status  => Selector_State);
      if Selector_State = Completed then
         Control_Socket (C.Socket, Request);
         Initialize_Channel (C);
         Accepted := True;
      end if;
   exception
      when E : others =>
         raise Transport_Error with Ada.Exceptions.Exception_Message (E);
   end Accept_Channel;

   procedure Connect
     (C    : out Channel;
      Path : String)
   is
      Address : Sock_Addr_Type;
   begin
      if Path'Length = 0 then
         raise Transport_Error with "RPC endpoint path is empty";
      end if;
      Create_Socket (C.Socket, Family_Unix, Socket_Stream);
      Address := Unix_Socket_Address (Path);
      Connect_Socket (C.Socket, Address);
      C.Input := Null_Unbounded_String;
      C.Sent_Handshake := False;
      C.Sent_Terminal := False;
      C.Got_Handshake := False;
      C.Got_Terminal := False;
      C.Last_Event_Sequence := 0;
   exception
      when E : others =>
         if C.Socket /= No_Socket then
            Close_Socket (C.Socket);
            C.Socket := No_Socket;
         end if;
         raise Transport_Error with Ada.Exceptions.Exception_Message (E);
   end Connect;

   procedure Create_Pair
     (Left  : out Channel;
      Right : out Channel)
   is
   begin
      Create_Socket_Pair
        (Left.Socket, Right.Socket, Family_Unspec, Socket_Stream);
      Left.Input := Null_Unbounded_String;
      Right.Input := Null_Unbounded_String;
      Left.Sent_Handshake := False;
      Right.Sent_Handshake := False;
      Left.Sent_Terminal := False;
      Right.Sent_Terminal := False;
      Left.Got_Handshake := False;
      Right.Got_Handshake := False;
      Left.Got_Terminal := False;
      Right.Got_Terminal := False;
      Left.Last_Event_Sequence := 0;
      Right.Last_Event_Sequence := 0;
   exception
      when E : others =>
         raise Transport_Error with Ada.Exceptions.Exception_Message (E);
   end Create_Pair;

   procedure Close (C : in out Channel) is
   begin
      if C.Socket /= No_Socket then
         Close_Socket (C.Socket);
         C.Socket := No_Socket;
      end if;
      C.Input := Null_Unbounded_String;
   end Close;

   procedure Close (L : in out Listener) is
   begin
      if L.Socket /= No_Socket then
         Close_Socket (L.Socket);
         L.Socket := No_Socket;
      end if;
      if Length (L.Endpoint) > 0 then
         declare
            Deleted : Boolean;
         begin
            GNAT.OS_Lib.Delete_File (To_String (L.Endpoint), Deleted);
         end;
      end if;
      L.Endpoint := Null_Unbounded_String;
   end Close;

   function Is_Open (C : Channel) return Boolean is
   begin
      return C.Socket /= No_Socket;
   end Is_Open;

   procedure Send_Bytes
     (C     : in out Channel;
      Text  : String)
   is
      Data : Ada.Streams.Stream_Element_Array
        (1 .. Ada.Streams.Stream_Element_Offset (Text'Length));
      Last : Ada.Streams.Stream_Element_Offset;
      Offset : Ada.Streams.Stream_Element_Offset := Data'First;
   begin
      Require_Open (C);
      if Text'Length = 0 then
         return;
      end if;
      for Index in Text'Range loop
         Data (Offset) := Ada.Streams.Stream_Element
           (Character'Pos (Text (Index)));
         Offset := Offset + 1;
      end loop;
      Offset := Data'First;
      while Offset <= Data'Last loop
         Send_Socket
           (Socket => C.Socket,
            Item   => Data (Offset .. Data'Last),
            Last   => Last);
         if Last < Offset then
            raise Transport_Error with "RPC peer closed while sending";
         end if;
         Offset := Last + 1;
      end loop;
   end Send_Bytes;

   procedure Send_Frame
     (C     : in out Channel;
      Value : Coyote_App.Agent_RPC.Frame)
   is
      use Coyote_App.Agent_RPC;
      Text : constant String := Encode (Value) & Ada.Characters.Latin_1.LF;
   begin
      Require_Open (C);
      if C.Sent_Terminal then
         raise Transport_Error with "RPC frame follows terminal frame";
      end if;
      case Value.Kind is
         when Handshake =>
            if C.Sent_Handshake then
               raise Transport_Error with "duplicate RPC handshake";
            end if;
            C.Sent_Handshake := True;
         when Event =>
            if not C.Sent_Handshake then
               raise Transport_Error with "RPC event precedes handshake";
            end if;
            if Value.Sequence <= C.Last_Event_Sequence then
               raise Transport_Error with "RPC event sequence is not increasing";
            end if;
            C.Last_Event_Sequence := Value.Sequence;
         when Command =>
            null;
         when Terminal =>
            if not C.Sent_Handshake then
               raise Transport_Error with "RPC terminal precedes handshake";
            end if;
            C.Sent_Terminal := True;
      end case;
      Send_Bytes (C, Text);
   exception
      when E : Coyote_App.Agent_RPC.RPC_Error =>
         raise Transport_Error with Ada.Exceptions.Exception_Message (E);
   end Send_Frame;

   function Receive_Frame
     (C      : in out Channel;
      Value  : out Coyote_App.Agent_RPC.Frame;
      Status : out Receive_Status;
      Error  : out Unbounded_String) return Boolean
   is
      use Coyote_App.Agent_RPC;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. 4096);
      Last   : Ada.Streams.Stream_Element_Offset;
      Newline : Natural;
      Line : Unbounded_String;
      Decoded_Status : Decode_Status;
   begin
      Require_Open (C);
      Status := Invalid_Frame;
      Error := Null_Unbounded_String;

      loop
         Newline := Ada.Strings.Fixed.Index (To_String (C.Input), "" & ASCII.LF);
         exit when Newline > 0;
         if Length (C.Input) > Max_Frame_Length then
            Status := Invalid_Frame;
            Error := To_Unbounded_String ("RPC frame exceeds maximum length");
            return False;
         end if;
         Receive_Socket (C.Socket, Buffer, Last);
         if Last < Buffer'First then
            Close (C);
            Status := Peer_Closed;
            Error := To_Unbounded_String ("RPC peer closed the channel");
            return False;
         end if;
         for Index in Buffer'First .. Last loop
            Append (C.Input, Character'Val (Buffer (Index)));
         end loop;
      end loop;

      Line := To_Unbounded_String
        (To_String (C.Input) (To_String (C.Input)'First .. Newline - 1));
      Delete (C.Input, 1, Newline);
      if Length (Line) = 0 then
         return Receive_Frame (C, Value, Status, Error);
      end if;

      if Try_Decode
        (Text   => To_String (Line),
         Value  => Value,
         Status => Decoded_Status,
         Error  => Error)
      then
         if C.Got_Terminal then
            Status := Invalid_Frame;
            Error := To_Unbounded_String
              ("RPC frame follows terminal frame");
            return False;
         end if;
         case Value.Kind is
            when Handshake =>
               if C.Got_Handshake then
                  Status := Invalid_Frame;
                  Error := To_Unbounded_String ("duplicate RPC handshake");
                  return False;
               end if;
               C.Got_Handshake := True;
            when Event =>
               if not C.Got_Handshake then
                  Status := Invalid_Frame;
                  Error := To_Unbounded_String ("RPC event precedes handshake");
                  return False;
               end if;
               if Value.Sequence <= C.Last_Event_Sequence then
                  Status := Invalid_Frame;
                  Error := To_Unbounded_String
                    ("RPC event sequence is not increasing");
                  return False;
               end if;
               C.Last_Event_Sequence := Value.Sequence;
            when Command =>
               null;
            when Terminal =>
               if not C.Got_Handshake then
                  Status := Invalid_Frame;
                  Error := To_Unbounded_String ("RPC terminal precedes handshake");
                  return False;
               end if;
               C.Got_Terminal := True;
         end case;
         Status := Frame_Received;
         return True;
      end if;

      case Decoded_Status is
         when Malformed_JSON       => Status := Malformed_Frame;
         when Unsupported_Version  => Status := Unsupported_Frame_Version;
         when Invalid_Frame        => Status := Invalid_Frame;
         when Valid                 => Status := Invalid_Frame;
      end case;
      return False;
   exception
      when E : Transport_Error =>
         Status := Invalid_Frame;
         Error := To_Unbounded_String (Ada.Exceptions.Exception_Message (E));
         return False;
      when E : others =>
         Status := Invalid_Frame;
         Error := To_Unbounded_String (Ada.Exceptions.Exception_Message (E));
         return False;
   end Receive_Frame;

   function Receive_Frame
     (C       : in out Channel;
      Value   : out Coyote_App.Agent_RPC.Frame;
      Status  : out Receive_Status;
      Error   : out Unbounded_String;
      Timeout : Duration;
      Ready   : out Boolean) return Boolean
   is
      Buffer         : Ada.Streams.Stream_Element_Array (1 .. 4096);
      Last           : Ada.Streams.Stream_Element_Offset;
      Request        : Request_Type :=
        (Name => Non_Blocking_IO, Enabled => True);
      Selector       : Selector_Type;
      Read_Set       : Socket_Set_Type;
      Write_Set      : Socket_Set_Type;
      Selector_State : Selector_Status;
      Complete       : Boolean := False;
      Result         : Boolean := False;
      Timeout_Value  : constant Duration := Duration'Max (Timeout, 0.0);
   begin
      Require_Open (C);
      Ready := False;
      Status := Invalid_Frame;
      Error := Null_Unbounded_String;
      Create_Selector (Selector);
      begin
         Control_Socket (C.Socket, Request);

         if Ada.Strings.Fixed.Index
           (To_String (C.Input), "" & ASCII.LF) > 0
         then
            Result := Receive_Frame (C, Value, Status, Error);
            Complete := True;
         else
            Empty (Read_Set);
            Empty (Write_Set);
            Set (Read_Set, C.Socket);
            Check_Selector
              (Selector     => Selector,
               R_Socket_Set => Read_Set,
               W_Socket_Set => Write_Set,
               Status       => Selector_State,
               Timeout      => Selector_Duration (Timeout_Value));

            if Selector_State = Completed then
               begin
                  Receive_Socket (C.Socket, Buffer, Last);
                  if Last < Buffer'First then
                     Close (C);
                     Status := Peer_Closed;
                     Error := To_Unbounded_String
                       ("RPC peer closed the channel");
                     Complete := True;
                  else
                     for Index in Buffer'First .. Last loop
                        Append
                          (C.Input, Character'Val (Buffer (Index)));
                     end loop;
                     if Ada.Strings.Fixed.Index
                       (To_String (C.Input), "" & ASCII.LF) > 0
                     then
                        Result := Receive_Frame (C, Value, Status, Error);
                        Complete := True;
                     end if;
                  end if;
               exception
                  when E : Socket_Error =>
                     if Resolve_Exception (E) /=
                       Resource_Temporarily_Unavailable
                     then
                        raise;
                     end if;
               end;
            end if;
         end if;

         if Is_Open (C) then
            Request := (Name => Non_Blocking_IO, Enabled => False);
            Control_Socket (C.Socket, Request);
         end if;
         Close_Selector (Selector);
         Ready := Complete;
         return Result;
      exception
         when others =>
            if Is_Open (C) then
               Request := (Name => Non_Blocking_IO, Enabled => False);
               Control_Socket (C.Socket, Request);
            end if;
            Close_Selector (Selector);
            raise;
      end;
   exception
      when E : Transport_Error =>
         Ready := False;
         Status := Invalid_Frame;
         Error := To_Unbounded_String (Ada.Exceptions.Exception_Message (E));
         return False;
      when E : others =>
         Ready := False;
         Status := Invalid_Frame;
         Error := To_Unbounded_String (Ada.Exceptions.Exception_Message (E));
         return False;
   end Receive_Frame;

end Coyote_App.Agent_RPC.Transport;
