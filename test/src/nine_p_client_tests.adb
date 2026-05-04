with AUnit.Assertions;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Streams;                use Ada.Streams;
with Ada.Strings.Unbounded;      use Ada.Strings.Unbounded;
with GNAT.Sockets;               use GNAT.Sockets;
with Interfaces;                 use Interfaces;
with Nine_P;                     use Nine_P;
with Nine_P.Client;
with Nine_P.Proto;               use Nine_P.Proto;
with Nine_P_Buffer_Stream;       use Nine_P_Buffer_Stream;

package body Nine_P_Client_Tests is

   use AUnit.Assertions;

   function Getpid return Integer;
   pragma Import (C, Getpid, "getpid");

   type Server_Scenario is (Connect_Only, Open_Once);

   protected type Server_Result is
      procedure Set_Error (Msg : String);
      function Error return String;
      procedure Mark_Done;
      entry Wait_Done;
   private
      Err  : Unbounded_String;
      Done : Boolean := False;
   end Server_Result;

   task type Unix_Mock_Server
     (Result : not null access Server_Result)
   is
      entry Start
        (Path       : String;
         Scenario   : Server_Scenario;
         Fail_Count : Natural := 0);
   end Unix_Mock_Server;

   protected body Server_Result is

      procedure Set_Error (Msg : String) is
      begin
         Err := To_Unbounded_String (Msg);
      end Set_Error;

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

   function Process_Id_String return String is
      Image : constant String := Integer'Image (Getpid);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Process_Id_String;

   function Namespace_Dir (Suffix : String) return String is
   begin
      return "/tmp/coyote-nine-p-client-"
        & Process_Id_String & "-" & Suffix;
   end Namespace_Dir;

   procedure Cleanup_Namespace
     (Dir        : String;
      Socket_Path : String)
   is
   begin
      begin
         if Ada.Directories.Exists (Socket_Path) then
            Ada.Directories.Delete_File (Socket_Path);
         end if;
      exception
         when others =>
            null;
      end;

      begin
         if Ada.Directories.Exists (Dir) then
            Ada.Directories.Delete_Tree (Dir);
         end if;
      exception
         when others =>
            null;
      end;
   end Cleanup_Namespace;

   --  Save, set, and restore a single environment variable around a block.
   procedure With_Env (Name : String; Val : String;
                       Action : not null access procedure)
   is
      use Ada.Environment_Variables;
      Had_Old : constant Boolean := Exists (Name);
      Old     : constant String  := (if Had_Old then Value (Name) else "");
   begin
      Set (Name, Val);
      begin
         Action.all;
      exception
         when others =>
            if Had_Old then
               Set (Name, Old);
            else
               Clear (Name);
            end if;
            raise;
      end;
      if Had_Old then
         Set (Name, Old);
      else
         Clear (Name);
      end if;
   end With_Env;

   procedure Read_Exactly
     (Socket :     Socket_Type;
      Data   : out Stream_Element_Array)
   is
      Offset : Stream_Element_Offset := Data'First;
      Last   : Stream_Element_Offset;
   begin
      while Offset <= Data'Last loop
         Receive_Socket (Socket, Data (Offset .. Data'Last), Last);
         if Last < Offset then
            raise P9_Error with "connection closed unexpectedly";
         end if;
         Offset := Last + 1;
      end loop;
   end Read_Exactly;

   function Read_P9_Message (Socket : Socket_Type) return Byte_Array is
      Header : Stream_Element_Array (0 .. 3);
      Size   : Uint32;
   begin
      Read_Exactly (Socket, Header);
      Size := Uint32 (Header (0))
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

   procedure Send_All
     (Socket : Socket_Type;
      Data   : Stream_Element_Array)
   is
      Offset : Stream_Element_Offset := Data'First;
      Last   : Stream_Element_Offset;
   begin
      while Offset <= Data'Last loop
         Send_Socket (Socket, Data (Offset .. Data'Last), Last);
         if Last < Offset then
            raise P9_Error with "send failed unexpectedly";
         end if;
         Offset := Last + 1;
      end loop;
   end Send_All;

   procedure Write_P9_Message
     (Socket : Socket_Type;
      Msg    : Message)
   is
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

   function Expect
     (Socket   : Socket_Type;
      Expected : Message_Kind) return Message
   is
      Msg : constant Message := Unpack (Read_P9_Message (Socket));
   begin
      if Msg.Kind /= Expected then
         raise P9_Error with
           "expected " & Expected'Image & " but got " & Msg.Kind'Image;
      end if;
      return Msg;
   end Expect;

   procedure Drain_Clunks (Socket : Socket_Type) is
   begin
      loop
         declare
            Msg : constant Message := Unpack (Read_P9_Message (Socket));
         begin
            if Msg.Kind /= Kind_Tclunk then
               raise P9_Error with
                 "expected " & Kind_Tclunk'Image
                 & " but got " & Msg.Kind'Image;
            end if;
            Write_P9_Message
              (Socket,
               (Kind => Kind_Rclunk,
                Tag  => Msg.Tag));
         end;
      end loop;
   exception
      when Socket_Error =>
         null;
      when E : P9_Error =>
         if Ada.Exceptions.Exception_Message (E) /=
           "connection closed unexpectedly"
         then
            raise;
         end if;
   end Drain_Clunks;

   procedure Run_Protocol
     (Scenario : Server_Scenario;
      Socket   : Socket_Type)
   is
   begin
      declare
         Tversion_Msg : constant Message :=
           Expect (Socket, Kind_Tversion);
      begin
         Write_P9_Message
           (Socket,
            (Kind    => Kind_Rversion,
             Tag     => Tversion_Msg.Tag,
             MSize   => Tversion_Msg.MSize,
             Version => To_Unbounded_String (VERSION_9P)));
      end;

      declare
         Tattach_Msg : constant Message :=
           Expect (Socket, Kind_Tattach);
      begin
         Write_P9_Message
           (Socket,
            (Kind    => Kind_Rattach,
             Tag     => Tattach_Msg.Tag,
             Att_Qid => (Qtype => QT_FILE, Vers => 0, Path => 1)));
      end;

      case Scenario is
         when Connect_Only =>
            null;

         when Open_Once =>
            declare
               Twalk_Msg : constant Message :=
                 Expect (Socket, Kind_Twalk);
               Qids      : Qid_Array :=
                 (others => (Qtype => QT_FILE, Vers => 0, Path => 0));
            begin
               for I in 1 .. Twalk_Msg.Walk_Nwname loop
                  Qids (I) :=
                    (Qtype => QT_FILE, Vers => 0, Path => Uint64 (I));
               end loop;
               Write_P9_Message
                 (Socket,
                  (Kind       => Kind_Rwalk,
                   Tag        => Twalk_Msg.Tag,
                   Walk_Nwqid => Twalk_Msg.Walk_Nwname,
                   Walk_Qids  => Qids));
            end;

            declare
               Topen_Msg : constant Message :=
                 Expect (Socket, Kind_Topen);
            begin
               Write_P9_Message
                 (Socket,
                  (Kind          => Kind_Ropen,
                   Tag           => Topen_Msg.Tag,
                   Opened_Qid    => (Qtype => QT_FILE, Vers => 0, Path => 7),
                   Opened_Iounit => 0));
            end;
      end case;

      Drain_Clunks (Socket);
   end Run_Protocol;

   procedure Run_Scenario
     (Socket_Path   : String;
      Scenario      : Server_Scenario;
      Server_Socket : Socket_Type)
   is
      Listener    : Socket_Type := Server_Socket;
      Conn_Socket : Socket_Type := No_Socket;
      Conn_Addr   : Sock_Addr_Type;
      pragma Unreferenced (Socket_Path);
   begin
      Accept_Socket (Listener, Conn_Socket, Conn_Addr);
      Close_Socket (Listener);
      Listener := No_Socket;

      Set_Socket_Option
        (Conn_Socket, Socket_Level,
         (Name => Receive_Timeout, Timeout => 2.0));

      Run_Protocol (Scenario, Conn_Socket);

      Close_Socket (Conn_Socket);
   exception
      when others =>
         if Listener /= No_Socket then
            Close_Socket (Listener);
         end if;
         if Conn_Socket /= No_Socket then
            Close_Socket (Conn_Socket);
         end if;
         raise;
   end Run_Scenario;

   task body Unix_Mock_Server is
      Scenario_V    : Server_Scenario;
      Socket_Path_V : Unbounded_String;
      Fail_Count_V  : Natural        := 0;
      Server_Socket : Socket_Type    := No_Socket;
   begin
      select
         accept Start
           (Path       : String;
            Scenario   : Server_Scenario;
            Fail_Count : Natural := 0)
         do
            Socket_Path_V := To_Unbounded_String (Path);
            Scenario_V    := Scenario;
            Fail_Count_V  := Fail_Count;
            Create_Socket (Server_Socket, Family_Unix, Socket_Stream);
            Bind_Socket
              (Server_Socket,
               Unix_Socket_Address (To_String (Socket_Path_V)));
            Listen_Socket (Server_Socket, 5);
         end Start;
      or
         terminate;
      end select;

      --  Fail the first Fail_Count_V connections immediately.
      for I in 1 .. Fail_Count_V loop
         pragma Warnings (Off, I);
         declare
            Conn_Socket : Socket_Type  := No_Socket;
            Conn_Addr   : Sock_Addr_Type;
         begin
            Accept_Socket (Server_Socket, Conn_Socket, Conn_Addr);
            Close_Socket (Conn_Socket);
         end;
      end loop;

      Run_Scenario
        (To_String (Socket_Path_V), Scenario_V, Server_Socket);
      Result.Mark_Done;
   exception
      when E : others =>
         if Server_Socket /= No_Socket then
            Close_Socket (Server_Socket);
         end if;
         Result.Set_Error (Ada.Exceptions.Exception_Message (E));
         Result.Mark_Done;
   end Unix_Mock_Server;

   procedure With_Unix_Mock_Service
     (Suffix     : String;
      Scenario   : Server_Scenario;
      Action     : not null access procedure;
      Fail_Count : Natural := 0)
   is
      Dir         : constant String := Namespace_Dir (Suffix);
      Socket_Path : constant String := Dir & "/mock";
      Result      : aliased Server_Result;
      Server      : Unix_Mock_Server (Result'Access);

      procedure Run_Action is
      begin
         Action.all;
      end Run_Action;
   begin
      Cleanup_Namespace (Dir, Socket_Path);
      Ada.Directories.Create_Path (Dir);
      begin
         Server.Start (Socket_Path, Scenario, Fail_Count);
         With_Env ("NAMESPACE", Dir, Run_Action'Access);
         Result.Wait_Done;
         Assert (Result.Error = "",
                 "Mock server failed: " & Result.Error);
      exception
         when others =>
            begin
               Result.Wait_Done;
            exception
               when others =>
                  null;
            end;
            Cleanup_Namespace (Dir, Socket_Path);
            raise;
      end;
      Cleanup_Namespace (Dir, Socket_Path);
   end With_Unix_Mock_Service;

   --  ── Namespace ────────────────────────────────────────────────────────

   procedure Test_Namespace_Uses_Env (T : in out Test) is
      pragma Unreferenced (T);
      procedure Check is
      begin
         Assert (Nine_P.Client.Namespace = "/tmp/test.ns",
                 "Should return $NAMESPACE verbatim");
      end Check;
   begin
      With_Env ("NAMESPACE", "/tmp/test.ns", Check'Access);
   end Test_Namespace_Uses_Env;

   procedure Test_Namespace_Fallback (T : in out Test) is
      pragma Unreferenced (T);
      use Ada.Environment_Variables;

      NS_Saved : constant Boolean := Exists ("NAMESPACE");
      NS_Old   : constant String :=
        (if NS_Saved then Value ("NAMESPACE") else "");
      Verified : Boolean := False;

      procedure Set_User is
         procedure Set_Display is
            procedure Check is
            begin
               Assert (Nine_P.Client.Namespace = "/tmp/ns.tuser.:99",
                       "Fallback should be /tmp/ns.<USER>.<DISPLAY>");
               Verified := True;
            end Check;
         begin
            With_Env ("DISPLAY", ":99", Check'Access);
         end Set_Display;
      begin
         With_Env ("USER", "tuser", Set_Display'Access);
      end Set_User;
   begin
      Clear ("NAMESPACE");
      begin
         Set_User;
      exception
         when others =>
            if NS_Saved then
               Set ("NAMESPACE", NS_Old);
            end if;
            raise;
      end;
      if NS_Saved then
         Set ("NAMESPACE", NS_Old);
      end if;
      Assert (Verified, "Test body did not execute");
   end Test_Namespace_Fallback;

   --  ── Connection and in-place open operations ──────────────────────────

   procedure Test_Connect (T : in out Test) is
      pragma Unreferenced (T);

      procedure Client_Action is
      begin
         declare
            FS : Nine_P.Client.Fs;
         begin
            Nine_P.Client.Connect (FS, "mock");
         end;
      end Client_Action;
   begin
      With_Unix_Mock_Service
        (Suffix   => "connect",
         Scenario => Connect_Only,
         Action   => Client_Action'Access);
   end Test_Connect;

   procedure Test_Open_Procedure (T : in out Test) is
      pragma Unreferenced (T);

      procedure Client_Action is
      begin
         declare
            FS     : aliased Nine_P.Client.Fs;
            F      : Nine_P.Client.File;
            Raised : Boolean := False;
         begin
            Nine_P.Client.Connect (FS, "mock");
            Nine_P.Client.Open (F, FS'Access, "/mock/path", O_READ);
            begin
               Nine_P.Client.Open (F, FS'Access, "/mock/path", O_READ);
            exception
               when P9_Error =>
                  Raised := True;
            end;
            Assert (Raised,
                    "Procedure Open should reject an already-open File");
         end;
      end Client_Action;
   begin
      With_Unix_Mock_Service
        (Suffix   => "open-procedure",
         Scenario => Open_Once,
         Action   => Client_Action'Access);
   end Test_Open_Procedure;

   procedure Test_Connect_Reconnect (T : in out Test) is
      pragma Unreferenced (T);

      FS : Nine_P.Client.Fs;

      procedure First_Connect is
      begin
         Nine_P.Client.Connect (FS, "mock");
      end First_Connect;

      procedure Second_Connect is
      begin
         Nine_P.Client.Connect (FS, "mock");
         Assert (True, "Reconnect should succeed without raising");
      end Second_Connect;
   begin
      With_Unix_Mock_Service
        (Suffix   => "reconnect-first",
         Scenario => Connect_Only,
         Action   => First_Connect'Access);
      --  FS is now connected to the first (finished) mock; the next
      --  Connect must Finalize the old socket before opening the new one.
      With_Unix_Mock_Service
        (Suffix   => "reconnect-second",
         Scenario => Connect_Only,
         Action   => Second_Connect'Access);
   end Test_Connect_Reconnect;

   procedure Test_Connect_Failure (T : in out Test) is
      pragma Unreferenced (T);

      FS     : Nine_P.Client.Fs;
      Raised : Boolean := False;

      procedure Try_Connect is
      begin
         Nine_P.Client.Connect (FS, "no-such-service");
      exception
         when others =>
            Raised := True;
      end Try_Connect;
   begin
      With_Env
        ("NAMESPACE", "/tmp/coyote-connect-failure-test",
         Try_Connect'Access);
      Assert (Raised, "Connect to absent service should raise");
   end Test_Connect_Failure;

   --  ── Read_Message / Write_Message ─────────────────────────────────────

   procedure Test_Read_Write_Message (T : in out Test) is
      pragma Unreferenced (T);
      BS     : aliased Buffer_Stream;
      Orig   : constant Message :=
        (Kind  => Kind_Rerror,
         Tag   => 42,
         Ename => To_Unbounded_String ("something went wrong"));
      Packed : constant Byte_Array := Pack (Orig);
   begin
      Nine_P.Client.Write_Message (BS'Access, Packed);
      declare
         Got : constant Byte_Array :=
           Nine_P.Client.Read_Message (BS'Access);
      begin
         Assert (Got'Length = Packed'Length,
                 "Round-trip length should match");
         for I in 0 .. Packed'Length - 1 loop
            Assert (Got (I) = Packed (I),
                    "Byte mismatch at index" & I'Image);
         end loop;
         Assert (Available (BS) = 0, "Buffer should be fully consumed");
      end;
   end Test_Read_Write_Message;

   procedure Test_Read_Message_Framing (T : in out Test) is
      pragma Unreferenced (T);
      BS   : aliased Buffer_Stream;
      Msg1 : constant Message := (Kind => Kind_Rflush, Tag => 10);
      Msg2 : constant Message := (Kind => Kind_Rclunk, Tag => 20);
   begin
      Nine_P.Client.Write_Message (BS'Access, Pack (Msg1));
      Nine_P.Client.Write_Message (BS'Access, Pack (Msg2));
      Assert (Available (BS) = 14,
              "Two 7-byte messages should occupy 14 bytes");
      declare
         Got1 : constant Message :=
           Unpack (Nine_P.Client.Read_Message (BS'Access));
         Got2 : constant Message :=
           Unpack (Nine_P.Client.Read_Message (BS'Access));
      begin
         Assert (Got1.Kind = Kind_Rflush, "First message should be Rflush");
         Assert (Got1.Tag  = 10,          "First message tag should be 10");
         Assert (Got2.Kind = Kind_Rclunk, "Second message should be Rclunk");
         Assert (Got2.Tag  = 20,          "Second message tag should be 20");
         Assert (Available (BS) = 0,
                 "Buffer should be empty after two reads");
      end;
   end Test_Read_Message_Framing;

   --  ── Connect_With_Retry ───────────────────────────────────────────────

   procedure Test_Connect_With_Retry_Happy_Path (T : in out Test) is
      pragma Unreferenced (T);
      procedure Action is
         FS : Nine_P.Client.Fs;
      begin
         Nine_P.Client.Connect_With_Retry
           (FS, "mock", Max_Retries => 3, Retry_Delay => 0.0);
         Assert (True, "Connect_With_Retry should succeed on first attempt");
      end Action;
   begin
      With_Unix_Mock_Service
        (Suffix     => "retry-happy",
         Scenario   => Connect_Only,
         Fail_Count => 0,
         Action     => Action'Access);
   end Test_Connect_With_Retry_Happy_Path;

   procedure Test_Connect_With_Retry_Succeeds_On_Second_Attempt
     (T : in out Test)
   is
      pragma Unreferenced (T);
      procedure Action is
         FS : Nine_P.Client.Fs;
      begin
         Nine_P.Client.Connect_With_Retry
           (FS, "mock", Max_Retries => 3, Retry_Delay => 0.0);
         Assert (True, "Connect_With_Retry should succeed on second attempt");
      end Action;
   begin
      With_Unix_Mock_Service
        (Suffix     => "retry-second",
         Scenario   => Connect_Only,
         Fail_Count => 1,
         Action     => Action'Access);
   end Test_Connect_With_Retry_Succeeds_On_Second_Attempt;

   procedure Test_Connect_With_Retry_Exhausted (T : in out Test) is
      pragma Unreferenced (T);
      Raised : Boolean := False;
      procedure Action is
         FS : Nine_P.Client.Fs;
      begin
         Nine_P.Client.Connect_With_Retry
           (FS, "mock", Max_Retries => 3, Retry_Delay => 0.0);
      exception
         when others =>
            Raised := True;
      end Action;
   begin
      With_Env
        ("NAMESPACE", "/tmp/coyote-retry-exhausted",
         Action'Access);
      Assert (Raised,
              "Connect_With_Retry should raise after all retries exhausted");
   end Test_Connect_With_Retry_Exhausted;

end Nine_P_Client_Tests;
