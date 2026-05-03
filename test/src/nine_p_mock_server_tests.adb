with AUnit.Assertions;
with Ada.Strings.Unbounded;
with GNAT.Sockets;
with Nine_P;                use Nine_P;
with Nine_P.Client;
with Nine_P.Proto;          use Nine_P.Proto;
with Nine_P_Mock_Server;

package body Nine_P_Mock_Server_Tests is

   use AUnit.Assertions;
   use type Nine_P.Uint64;
   use type Nine_P.Uint32;

   --  ── Local helpers ─────────────────────────────────────────────────────

   function Natural_Image (Value : Natural) return String is
      Image : constant String := Natural'Image (Value);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Natural_Image;

   function Decode_Bytes (Data : Byte_Array) return String is
   begin
      if Data'Length = 0 then
         return "";
      end if;
      return Result : String (1 .. Data'Length) do
         for I in Data'Range loop
            Result (I - Data'First + 1) := Character'Val (Data (I));
         end loop;
      end return;
   end Decode_Bytes;

   function Make_Test_Data (Length : Positive) return String is
   begin
      return Result : String (1 .. Length) do
         for I in Result'Range loop
            Result (I) := Character'Val
              (Character'Pos ('A') + ((I - 1) mod 26));
         end loop;
      end return;
   end Make_Test_Data;

   function Dial_With_Retry (Port : Positive) return Nine_P.Client.Fs is
      Addr : constant String := "tcp!127.0.0.1!" & Natural_Image (Port);
   begin
      Retry_Loop :
      for Attempt in 1 .. 20 loop
         begin
            return Nine_P.Client.Dial (Addr);
         exception
            when GNAT.Sockets.Socket_Error =>
               if Attempt = 20 then
                  raise;
               end if;
               delay 0.05;
         end;
      end loop Retry_Loop;
      raise Program_Error with "unreachable";
   end Dial_With_Retry;

   --  Return the number of events in Events whose Msg_Type equals Kind.
   function Count_Events
     (Events : Nine_P_Mock_Server.Event_Vectors.Vector;
      Kind   : String) return Natural
   is
      Count : Natural := 0;
   begin
      for Evt of Events loop
         if Ada.Strings.Unbounded.To_String (Evt.Msg_Type) = Kind then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Count_Events;

   --  Return the Index-th event in Events whose Msg_Type equals Kind.
   --  Raises Constraint_Error when fewer than Index matching events exist.
   function Nth_Event_Of_Kind
     (Events : Nine_P_Mock_Server.Event_Vectors.Vector;
      Kind   : String;
      Index  : Positive) return Nine_P_Mock_Server.Event_Record
   is
      Seen : Natural := 0;
   begin
      for Evt of Events loop
         if Ada.Strings.Unbounded.To_String (Evt.Msg_Type) = Kind then
            Seen := Seen + 1;
            if Seen = Index then
               return Evt;
            end if;
         end if;
      end loop;
      raise Constraint_Error with "missing event kind " & Kind;
   end Nth_Event_Of_Kind;

   --  ── Test procedures ───────────────────────────────────────────────────

   procedure Test_Read_Once_Returns_Single_Tread
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Port   : constant Positive := 28_901;
      Result : aliased Nine_P_Mock_Server.Server_Result;
      Srv    : Nine_P_Mock_Server.Mock_Server (Result'Access);
   begin
      Srv.Start (Nine_P_Mock_Server.Read_Once, Port);

      declare
         FS          : aliased Nine_P.Client.Fs := Dial_With_Retry (Port);
         Opened_File : aliased Nine_P.Client.File :=
           Nine_P.Client.Open (FS'Access, "/mock/file", O_READ);
         Data        : constant Byte_Array :=
           Nine_P.Client.Read_Once (Opened_File'Access);
      begin
         Assert
           (Decode_Bytes (Data) = "hello",
            "Read_Once should return the single Rread payload");
      end;

      Result.Wait_Done;

      Assert
        (Result.Error = "",
         "Mock server failed: " & Result.Error);
      Assert
        (Count_Events (Result.Events, "Tread") = 1,
         "Read_Once should issue exactly one Tread");
   end Test_Read_Once_Returns_Single_Tread;

   procedure Test_Read_Aggregates_Chunks_Until_EOF
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Port   : constant Positive := 28_902;
      Result : aliased Nine_P_Mock_Server.Server_Result;
      Srv    : Nine_P_Mock_Server.Mock_Server (Result'Access);
   begin
      Srv.Start
        (Nine_P_Mock_Server.Read_Aggregate, Port);

      declare
         FS          : aliased Nine_P.Client.Fs := Dial_With_Retry (Port);
         Opened_File : aliased Nine_P.Client.File :=
           Nine_P.Client.Open (FS'Access, "/mock/file", O_READ);
         Data        : constant Byte_Array :=
           Nine_P.Client.Read (Opened_File'Access);
      begin
         Assert
           (Decode_Bytes (Data) = "abcdEFGH",
            "Read should concatenate Rread payloads until EOF");
      end;

      Result.Wait_Done;

      Assert
        (Result.Error = "",
         "Mock server failed: " & Result.Error);
      Assert
        (Count_Events (Result.Events, "Tread") = 3,
         "Read should continue issuing Tread until zero-length EOF");
   end Test_Read_Aggregates_Chunks_Until_EOF;

   procedure Test_Write_Splits_By_IOunit
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Port    : constant Positive := 28_903;
      Payload : constant String   := Make_Test_Data (95);
      Result  : aliased Nine_P_Mock_Server.Server_Result;
      Srv     : Nine_P_Mock_Server.Mock_Server (Result'Access);
   begin
      Srv.Start (Nine_P_Mock_Server.Write_Split, Port);

      declare
         FS          : aliased Nine_P.Client.Fs := Dial_With_Retry (Port);
         Opened_File : aliased Nine_P.Client.File :=
           Nine_P.Client.Open (FS'Access, "/mock/file", O_WRITE);
         Written     : constant Natural :=
           Nine_P.Client.Write (Opened_File'Access, Payload);
      begin
         Assert
           (Written = Payload'Length,
            "Write should report all bytes written");
      end;

      Result.Wait_Done;

      declare
         Events  : constant Nine_P_Mock_Server.Event_Vectors.Vector :=
           Result.Events;
         Write_1 : constant Nine_P_Mock_Server.Event_Record :=
           Nth_Event_Of_Kind (Events, "Twrite", 1);
         Write_2 : constant Nine_P_Mock_Server.Event_Record :=
           Nth_Event_Of_Kind (Events, "Twrite", 2);
         Write_3 : constant Nine_P_Mock_Server.Event_Record :=
           Nth_Event_Of_Kind (Events, "Twrite", 3);
      begin
         Assert
           (Result.Error = "",
            "Mock server failed: " & Result.Error);
         Assert
           (Count_Events (Events, "Twrite") = 3,
            "Write should split a 95-byte payload into three Twrite");
         Assert
           (Write_1.Wr_Offset = 0 and then Write_1.Wr_Count = 40,
            "First Twrite: offset 0, count 40");
         Assert
           (Write_2.Wr_Offset = 40 and then Write_2.Wr_Count = 40,
            "Second Twrite: offset 40, count 40");
         Assert
           (Write_3.Wr_Offset = 80 and then Write_3.Wr_Count = 15,
            "Third Twrite: offset 80, count 15");
      end;
   end Test_Write_Splits_By_IOunit;

   procedure Test_Walk_Failure_Raises_P9_Error
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Port   : constant Positive := 28_904;
      Raised : Boolean := False;
      Result : aliased Nine_P_Mock_Server.Server_Result;
      Srv    : Nine_P_Mock_Server.Mock_Server (Result'Access);
   begin
      Srv.Start (Nine_P_Mock_Server.Walk_Failure, Port);

      declare
         FS : aliased Nine_P.Client.Fs := Dial_With_Retry (Port);
      begin
         begin
            declare
               Opened_File : Nine_P.Client.File :=
                 Nine_P.Client.Open
                   (FS'Access, "/missing/file", O_READ);
               pragma Unreferenced (Opened_File);
            begin
               null;
            end;
         exception
            when P9_Error =>
               Raised := True;
         end;
      end;

      Result.Wait_Done;

      Assert
        (Result.Error = "",
         "Mock server failed: " & Result.Error);
      Assert (Raised, "Rerror on Twalk should raise P9_Error");
      Assert
        (Count_Events (Result.Events, "Twalk") = 1,
         "Open should attempt one Twalk before failing");
   end Test_Walk_Failure_Raises_P9_Error;

   procedure Test_Rerror_On_Read_Raises_P9_Error
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Port   : constant Positive := 28_905;
      Raised : Boolean := False;
      Result : aliased Nine_P_Mock_Server.Server_Result;
      Srv    : Nine_P_Mock_Server.Mock_Server (Result'Access);
   begin
      Srv.Start (Nine_P_Mock_Server.Read_Error, Port);

      declare
         FS          : aliased Nine_P.Client.Fs := Dial_With_Retry (Port);
         Opened_File : aliased Nine_P.Client.File :=
           Nine_P.Client.Open (FS'Access, "/mock/file", O_READ);
      begin
         begin
            declare
               Data : constant Byte_Array :=
                 Nine_P.Client.Read_Once (Opened_File'Access);
               pragma Unreferenced (Data);
            begin
               null;
            end;
         exception
            when P9_Error =>
               Raised := True;
         end;
      end;

      Result.Wait_Done;

      Assert
        (Result.Error = "",
         "Mock server failed: " & Result.Error);
      Assert (Raised, "Rerror on Tread should raise P9_Error");
      Assert
        (Count_Events (Result.Events, "Tread") = 1,
         "Read_Once should issue one Tread before failing");
   end Test_Rerror_On_Read_Raises_P9_Error;

   procedure Test_Rversion_Failure_Raises_P9_Error
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Port   : constant Positive := 28_906;
      Raised : Boolean := False;
      Result : aliased Nine_P_Mock_Server.Server_Result;
      Srv    : Nine_P_Mock_Server.Mock_Server (Result'Access);
   begin
      Srv.Start
        (Nine_P_Mock_Server.Rversion_Fail, Port);

      --  Use Dial_With_Retry so that we retry if the server socket
      --  is not yet ready to accept (race-window safety).
      begin
         declare
            FS : Nine_P.Client.Fs := Dial_With_Retry (Port);
            pragma Unreferenced (FS);
         begin
            null;
         end;
      exception
         when P9_Error =>
            Raised := True;
      end;

      Result.Wait_Done;

      Assert
        (Result.Error = "",
         "Mock server failed: " & Result.Error);
      Assert
        (Raised,
         "Unsupported Rversion value should raise P9_Error during Dial");
      Assert
        (Count_Events (Result.Events, "Tattach") = 0,
         "Dial should fail before sending Tattach");
      Assert
        (Count_Events (Result.Events, "Twalk") = 0,
         "Dial should fail before any Twalk");
   end Test_Rversion_Failure_Raises_P9_Error;

   procedure Test_Finalize_Sends_Tclunk
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Port   : constant Positive := 28_907;
      Result : aliased Nine_P_Mock_Server.Server_Result;
      Srv    : Nine_P_Mock_Server.Mock_Server (Result'Access);
   begin
      Srv.Start
        (Nine_P_Mock_Server.Finalize_Clunk, Port);

      declare
         FS          : aliased Nine_P.Client.Fs := Dial_With_Retry (Port);
         Opened_File : Nine_P.Client.File :=
           Nine_P.Client.Open (FS'Access, "/mock/file", O_READ);
         pragma Unreferenced (Opened_File);
      begin
         null;
      end;

      Result.Wait_Done;

      declare
         Events  : constant Nine_P_Mock_Server.Event_Vectors.Vector :=
           Result.Events;
         Clunk_1 : constant Nine_P_Mock_Server.Event_Record :=
           Nth_Event_Of_Kind (Events, "Tclunk", 1);
         Clunk_2 : constant Nine_P_Mock_Server.Event_Record :=
           Nth_Event_Of_Kind (Events, "Tclunk", 2);
      begin
         Assert
           (Result.Error = "",
            "Mock server failed: " & Result.Error);
         Assert
           (Count_Events (Events, "Tclunk") = 2,
            "Finalization should clunk the walked fid and the root fid");
         Assert
           (Clunk_1.Simple_Fid = 2,
            "File finalization should clunk the opened file fid first");
         Assert
           (Clunk_2.Simple_Fid = 1,
            "Fs finalization should clunk the root fid second");
      end;
   end Test_Finalize_Sends_Tclunk;

end Nine_P_Mock_Server_Tests;
