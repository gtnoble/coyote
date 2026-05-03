--  Nine_P_Mock_Server body — native Ada 9P2000 TCP mock server.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Exceptions;
with Ada.Streams;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with GNAT.Sockets;          use GNAT.Sockets;
with Interfaces;            use Interfaces;
with Nine_P.Proto;          use Nine_P.Proto;

package body Nine_P_Mock_Server is

   use Nine_P;

   --  ── Server_Result body ────────────────────────────────────────────────

   protected body Server_Result is

      procedure Append_Event (Rec : Event_Record) is
      begin
         Event_List.Append (Rec);
      end Append_Event;

      procedure Set_Error (Msg : String) is
      begin
         Err := To_Unbounded_String (Msg);
      end Set_Error;

      function Events return Event_Vectors.Vector is
      begin
         return Event_List;
      end Events;

      function Error return String is
      begin
         return To_String (Err);
      end Error;

      procedure Mark_Done is
      begin
         Done := True;
      end Mark_Done;

      entry Wait_Done when Done is
      begin
         null;
      end Wait_Done;

   end Server_Result;

   --  ── Socket I/O primitives ─────────────────────────────────────────────

   --  Read exactly Data'Length stream elements from Socket.
   --  Raises P9_Error when the remote end closes the connection.
   procedure Read_Exactly
     (Socket :        Socket_Type;
      Data   :    out Ada.Streams.Stream_Element_Array)
   is
      use Ada.Streams;
      Offset : Stream_Element_Offset := Data'First;
      Last   : Stream_Element_Offset;
   begin
      Read_Exactly_Loop :
      while Offset <= Data'Last loop
         Receive_Socket (Socket, Data (Offset .. Data'Last), Last);
         if Last < Offset then
            raise P9_Error with "connection closed unexpectedly";
         end if;
         Offset := Last + 1;
      end loop Read_Exactly_Loop;
   end Read_Exactly;

   --  Write all elements of Data to Socket.
   --  Raises P9_Error when the send fails.
   procedure Send_All
     (Socket : Socket_Type;
      Data   : Ada.Streams.Stream_Element_Array)
   is
      use Ada.Streams;
      Offset : Stream_Element_Offset := Data'First;
      Last   : Stream_Element_Offset;
   begin
      Send_All_Loop :
      while Offset <= Data'Last loop
         Send_Socket (Socket, Data (Offset .. Data'Last), Last);
         if Last < Offset then
            raise P9_Error with "send failed unexpectedly";
         end if;
         Offset := Last + 1;
      end loop Send_All_Loop;
   end Send_All;

   --  Read one complete 9P2000 message from Socket and return it as a
   --  Byte_Array that includes the 4-byte little-endian size prefix.
   function Read_P9_Message (Socket : Socket_Type) return Byte_Array is
      use Ada.Streams;
      Header : Stream_Element_Array (0 .. 3);
      Size   : Uint32;
   begin
      Read_Exactly (Socket, Header);
      Size :=
        Uint32 (Header (0))
        or Shift_Left (Uint32 (Header (1)),  8)
        or Shift_Left (Uint32 (Header (2)), 16)
        or Shift_Left (Uint32 (Header (3)), 24);
      declare
         Rest_Len : constant Stream_Element_Offset :=
           Stream_Element_Offset (Size) - 4;
         Rest     : Stream_Element_Array (0 .. Rest_Len - 1);
         Result   : Byte_Array (0 .. Natural (Size) - 1);
      begin
         Read_Exactly (Socket, Rest);
         Result (0) := Uint8 (Header (0));
         Result (1) := Uint8 (Header (1));
         Result (2) := Uint8 (Header (2));
         Result (3) := Uint8 (Header (3));
         for I in Rest'Range loop
            Result (4 + Natural (I)) := Uint8 (Rest (I));
         end loop;
         return Result;
      end;
   end Read_P9_Message;

   --  Encode Msg and send it to Socket.
   procedure Write_P9_Message
     (Socket : Socket_Type;
      Msg    : Message)
   is
      use Ada.Streams;
      Data : constant Byte_Array := Pack (Msg);
      SEA  : Stream_Element_Array
        (0 .. Stream_Element_Offset (Data'Length) - 1);
   begin
      for I in Data'Range loop
         SEA (Stream_Element_Offset (I - Data'First)) :=
           Stream_Element (Data (I));
      end loop;
      Send_All (Socket, SEA);
   end Write_P9_Message;

   --  ── Protocol helpers ──────────────────────────────────────────────────

   --  Build an Event_Record from Msg and append it to the event log.
   procedure Record_Msg
     (Result : not null access Server_Result;
      Msg    :                 Message)
   is
      Rec : Event_Record;
   begin
      case Msg.Kind is
         when Kind_Tversion =>
            Rec.Msg_Type := To_Unbounded_String ("Tversion");
         when Kind_Tattach  =>
            Rec.Msg_Type := To_Unbounded_String ("Tattach");
         when Kind_Twalk    =>
            Rec.Msg_Type := To_Unbounded_String ("Twalk");
         when Kind_Topen    =>
            Rec.Msg_Type := To_Unbounded_String ("Topen");
         when Kind_Tread    =>
            Rec.Msg_Type := To_Unbounded_String ("Tread");
         when Kind_Twrite   =>
            Rec.Msg_Type  := To_Unbounded_String ("Twrite");
            Rec.Wr_Offset := Msg.Wr_Offset;
            Rec.Wr_Count  := Length (Msg.Wr_Data);
         when Kind_Tclunk   =>
            Rec.Msg_Type   := To_Unbounded_String ("Tclunk");
            Rec.Simple_Fid := Msg.Simple_Fid;
         when others        =>
            Rec.Msg_Type := To_Unbounded_String (Msg.Kind'Image);
      end case;
      Result.Append_Event (Rec);
   end Record_Msg;

   --  Receive one message, record it, and return it.
   function Recv_Any
     (Socket : Socket_Type;
      Result : not null access Server_Result) return Message
   is
      Msg : constant Message := Unpack (Read_P9_Message (Socket));
   begin
      Record_Msg (Result, Msg);
      return Msg;
   end Recv_Any;

   --  Receive and record one message; raise P9_Error if the kind does not
   --  match Expected, and store a description in Result.
   function Expect
     (Socket   : Socket_Type;
      Result   : not null access Server_Result;
      Expected : Message_Kind) return Message
   is
      Msg : constant Message := Recv_Any (Socket, Result);
   begin
      if Msg.Kind /= Expected then
         declare
            Err_Str : constant String :=
              "expected " & Expected'Image
              & " but got " & Msg.Kind'Image;
         begin
            Result.Set_Error (Err_Str);
            raise P9_Error with Err_Str;
         end;
      end if;
      return Msg;
   end Expect;

   --  Send a Rerror response to the client.
   procedure Send_Error
     (Socket : Socket_Type;
      Tag    : Uint16;
      Ename  : String)
   is
   begin
      Write_P9_Message
        (Socket,
         (Kind  => Kind_Rerror,
          Tag   => Tag,
          Ename => To_Unbounded_String (Ename)));
   end Send_Error;

   --  Drain remaining client messages until socket timeout or EOF.
   --  Tclunk messages receive an Rclunk.  Twrite messages receive an
   --  Rwrite when Allow_Write is True; otherwise they receive a Rerror.
   --  All other messages receive a Rerror.
   procedure Drain
     (Socket      : Socket_Type;
      Result      : not null access Server_Result;
      Allow_Write : Boolean)
   is
   begin
      Drain_Loop :
      loop
         begin
            declare
               Msg : constant Message := Recv_Any (Socket, Result);
            begin
               case Msg.Kind is
                  when Kind_Tclunk =>
                     Write_P9_Message
                       (Socket,
                        (Kind => Kind_Rclunk, Tag => Msg.Tag));
                  when Kind_Twrite =>
                     if Allow_Write then
                        Write_P9_Message
                          (Socket,
                           (Kind     => Kind_Rwrite,
                            Tag      => Msg.Tag,
                            Wr_Count => Uint32
                                          (Length (Msg.Wr_Data))));
                     else
                        Send_Error
                          (Socket, Msg.Tag, "unexpected Twrite");
                     end if;
                  when others =>
                     Send_Error
                       (Socket, Msg.Tag,
                        "unexpected " & Msg.Kind'Image);
               end case;
            end;
         exception
            when Socket_Error | P9_Error =>
               exit Drain_Loop;
         end;
      end loop Drain_Loop;
   end Drain;

   --  ── Scenario protocol ─────────────────────────────────────────────────

   --  Execute the full 9P2000 protocol for Scenario on the already-
   --  accepted Socket, recording all incoming messages into Result.
   procedure Run_Protocol
     (Scenario : Scenario_Kind;
      Socket   : Socket_Type;
      Result   : not null access Server_Result)
   is
   begin
      --  ── Version negotiation ──────────────────────────────────────────
      declare
         Tver : constant Message :=
           Expect (Socket, Result, Kind_Tversion);
      begin
         if Scenario = Rversion_Fail then
            Write_P9_Message
              (Socket,
               (Kind    => Kind_Rversion,
                Tag     => Tver.Tag,
                MSize   => Tver.MSize,
                Version => To_Unbounded_String ("unknown")));
            return;
         end if;
         Write_P9_Message
           (Socket,
            (Kind    => Kind_Rversion,
             Tag     => Tver.Tag,
             MSize   =>
               (if Scenario = Write_Split then 64 else Tver.MSize),
             Version => To_Unbounded_String ("9P2000")));
      end;

      --  ── Attach ───────────────────────────────────────────────────────
      declare
         Tatt : constant Message :=
           Expect (Socket, Result, Kind_Tattach);
      begin
         Write_P9_Message
           (Socket,
            (Kind    => Kind_Rattach,
             Tag     => Tatt.Tag,
             Att_Qid => (Qtype => QT_FILE, Vers => 0, Path => 1)));
      end;

      --  ── Walk ─────────────────────────────────────────────────────────
      declare
         Twalk_Msg : constant Message :=
           Expect (Socket, Result, Kind_Twalk);
      begin
         if Scenario = Walk_Failure then
            Send_Error (Socket, Twalk_Msg.Tag, "file not found");
            Drain (Socket, Result, Allow_Write => False);
            return;
         end if;
         declare
            Nwqid : constant Walk_Count := Twalk_Msg.Walk_Nwname;
            Qids  : Qid_Array;
         begin
            for I in 1 .. Nwqid loop
               Qids (I) :=
                 (Qtype => QT_FILE, Vers => 0, Path => Uint64 (I));
            end loop;
            Write_P9_Message
              (Socket,
               (Kind       => Kind_Rwalk,
                Tag        => Twalk_Msg.Tag,
                Walk_Nwqid => Nwqid,
                Walk_Qids  => Qids));
         end;
      end;

      --  ── Open ─────────────────────────────────────────────────────────
      declare
         Topen_Msg : constant Message :=
           Expect (Socket, Result, Kind_Topen);
      begin
         Write_P9_Message
           (Socket,
            (Kind          => Kind_Ropen,
             Tag           => Topen_Msg.Tag,
             Opened_Qid    => (Qtype => QT_FILE, Vers => 0, Path => 7),
             Opened_Iounit => 0));
      end;

      --  ── Scenario-specific exchange ───────────────────────────────────
      case Scenario is

         when Read_Once =>
            declare
               Tread_Msg : constant Message :=
                 Expect (Socket, Result, Kind_Tread);
            begin
               Write_P9_Message
                 (Socket,
                  (Kind    => Kind_Rread,
                   Tag     => Tread_Msg.Tag,
                   Rd_Data => To_Unbounded_String ("hello")));
            end;
            Drain (Socket, Result, Allow_Write => False);

         when Read_Aggregate =>
            for Pass in 1 .. 3 loop
               declare
                  Payload   : constant String :=
                    (case Pass is
                        when 1      => "abcd",
                        when 2      => "EFGH",
                        when others => "");
                  Tread_Msg : constant Message :=
                    Expect (Socket, Result, Kind_Tread);
               begin
                  Write_P9_Message
                    (Socket,
                     (Kind    => Kind_Rread,
                      Tag     => Tread_Msg.Tag,
                      Rd_Data => To_Unbounded_String (Payload)));
               end;
            end loop;
            Drain (Socket, Result, Allow_Write => False);

         when Write_Split =>
            Drain (Socket, Result, Allow_Write => True);

         when Read_Error =>
            declare
               Tread_Msg : constant Message :=
                 Expect (Socket, Result, Kind_Tread);
            begin
               Send_Error
                 (Socket, Tread_Msg.Tag, "permission denied");
            end;
            Drain (Socket, Result, Allow_Write => False);

         when Finalize_Clunk =>
            Drain (Socket, Result, Allow_Write => False);

         when Walk_Failure | Rversion_Fail =>
            null;  --  Already handled in walk / version blocks above.

      end case;
   end Run_Protocol;

   --  ── Run_Scenario ──────────────────────────────────────────────────────

   --  Accept one TCP connection on Server_Socket, run the protocol, and
   --  close both the connection socket and the server socket.  Any
   --  exception is re-raised after socket cleanup.
   procedure Run_Scenario
     (Scenario_V    : Scenario_Kind;
      Server_Socket : Socket_Type;
      Result_V      : access Server_Result)
   is
      My_Server   : Socket_Type := Server_Socket;
      Conn_Socket : Socket_Type := No_Socket;
      Conn_Addr   : Sock_Addr_Type;
   begin
      Accept_Socket (My_Server, Conn_Socket, Conn_Addr);
      Close_Socket (My_Server);
      My_Server := No_Socket;

      Set_Socket_Option
        (Conn_Socket, Socket_Level,
         (Name => Receive_Timeout, Timeout => 2.0));

      Run_Protocol (Scenario_V, Conn_Socket, Result_V);

      Close_Socket (Conn_Socket);
   exception
      when others =>
         if My_Server /= No_Socket then
            Close_Socket (My_Server);
         end if;
         if Conn_Socket /= No_Socket then
            Close_Socket (Conn_Socket);
         end if;
         raise;
   end Run_Scenario;

   --  ── Mock_Server task body ─────────────────────────────────────────────

   task body Mock_Server is
      Scenario_V    : Scenario_Kind;
      Server_Socket : Socket_Type := No_Socket;
   begin
      --  Wait for the caller to provide parameters and bind the socket.
      --  The or-terminate alternative lets the task exit cleanly if the
      --  enclosing scope terminates before Start is called.
      select
         accept Start
           (Scenario : Scenario_Kind;
            Port     : Positive)
         do
            Scenario_V := Scenario;
            --  Bind and listen inside the rendezvous so that Start
            --  returns only once the OS accept queue is active.
            Create_Socket (Server_Socket, Family_Inet, Socket_Stream);
            Set_Socket_Option
              (Server_Socket, Socket_Level,
               (Name => Reuse_Address, Enabled => True));
            Set_Socket_Option
              (Server_Socket, Socket_Level,
               (Name => Receive_Timeout, Timeout => 5.0));
            declare
               Addr : Sock_Addr_Type (Family_Inet);
            begin
               Addr.Addr := Inet_Addr ("127.0.0.1");
               Addr.Port := Port_Type (Port);
               Bind_Socket (Server_Socket, Addr);
            end;
            Listen_Socket (Server_Socket, 1);
         end Start;
      or
         terminate;
      end select;

      Run_Scenario (Scenario_V, Server_Socket, Result);
      Result.Mark_Done;

   exception
      when E : others =>
         if Server_Socket /= No_Socket then
            Close_Socket (Server_Socket);
         end if;
         Result.Set_Error
           (Ada.Exceptions.Exception_Message (E));
         Result.Mark_Done;
   end Mock_Server;

end Nine_P_Mock_Server;
