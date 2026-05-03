with AUnit.Assertions;
with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNAT.Sockets;
with GNATCOLL.JSON;         use GNATCOLL.JSON;
with GNATCOLL.OS.Process;   use GNATCOLL.OS.Process;
with Nine_P;                use Nine_P;
with Nine_P.Client;
with Nine_P.Proto;          use Nine_P.Proto;

package body Nine_P_Mock_Server_Tests is

   use AUnit.Assertions;

   function C_Kill
     (Process_Id : Integer;
      Signal     : Integer) return Integer
      with Import, Convention => C, External_Name => "kill";

   function Natural_Image (Value : Natural) return String is
      Image : constant String := Natural'Image (Value);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Natural_Image;

   procedure Delete_If_Exists (Path : String) is
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_File (Path);
      end if;
   exception
      when others =>
         null;
   end Delete_If_Exists;

   function Read_File (Path : String) return String is
      File    : Ada.Text_IO.File_Type;
      Content : Ada.Strings.Unbounded.Unbounded_String;
   begin
      if not Ada.Directories.Exists (Path) then
         return "";
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (File);
         begin
            Ada.Strings.Unbounded.Append (Content, Line);
            if not Ada.Text_IO.End_Of_File (File) then
               Ada.Strings.Unbounded.Append (Content, ASCII.LF);
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (File);
      return Ada.Strings.Unbounded.To_String (Content);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         raise;
   end Read_File;

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

   function Mock_Server_Script return String is
   begin
      return
        "import json, socket, struct, sys, traceback" & ASCII.LF &
        "scenario = sys.argv[1]" & ASCII.LF &
        "port = int(sys.argv[2])" & ASCII.LF &
        "log_path = sys.argv[3]" & ASCII.LF &
        "TYPE_NAMES = {100: 'Tversion', 104: 'Tattach', 110: 'Twalk'," &
        ASCII.LF &
        "              112: 'Topen', 116: 'Tread', 118: 'Twrite'," &
        ASCII.LF &
        "              120: 'Tclunk'}" & ASCII.LF &
        "events = []" & ASCII.LF &
        "result = {'events': events, 'error': '', 'traceback': ''}" &
        ASCII.LF &
        "def readn(sock, count):" & ASCII.LF &
        "    data = b''" & ASCII.LF &
        "    while len(data) < count:" & ASCII.LF &
        "        chunk = sock.recv(count - len(data))" & ASCII.LF &
        "        if not chunk:" & ASCII.LF &
        "            raise EOFError()" & ASCII.LF &
        "        data += chunk" & ASCII.LF &
        "    return data" & ASCII.LF &
        "def read_str(buf, pos):" & ASCII.LF &
        "    count = struct.unpack_from('<H', buf, pos)[0]" & ASCII.LF &
        "    pos += 2" & ASCII.LF &
        "    text = buf[pos:pos + count].decode('latin1')" & ASCII.LF &
        "    pos += count" & ASCII.LF &
        "    return text, pos" & ASCII.LF &
        "def recv_msg(sock):" & ASCII.LF &
        "    header = readn(sock, 4)" & ASCII.LF &
        "    size = struct.unpack('<I', header)[0]" & ASCII.LF &
        "    data = header + readn(sock, size - 4)" & ASCII.LF &
        "    mtype = data[4]" & ASCII.LF &
        "    tag = struct.unpack_from('<H', data, 5)[0]" & ASCII.LF &
        "    pos = 7" & ASCII.LF &
        "    msg = {'type': TYPE_NAMES.get(mtype, str(mtype)), 'tag': tag}" &
        ASCII.LF &
        "    if mtype in (100, 101):" & ASCII.LF &
        "        msg['msize'] = struct.unpack_from('<I', data, pos)[0]" &
        ASCII.LF &
        "        pos += 4" & ASCII.LF &
        "        msg['version'], pos = read_str(data, pos)" & ASCII.LF &
        "    elif mtype == 104:" & ASCII.LF &
        "        msg['fid'] = struct.unpack_from('<I', data, pos)[0]" &
        ASCII.LF &
        "        pos += 4" & ASCII.LF &
        "        msg['afid'] = struct.unpack_from('<I', data, pos)[0]" &
        ASCII.LF &
        "        pos += 4" & ASCII.LF &
        "        msg['uname'], pos = read_str(data, pos)" & ASCII.LF &
        "        msg['aname'], pos = read_str(data, pos)" & ASCII.LF &
        "    elif mtype == 110:" & ASCII.LF &
        "        msg['fid'] = struct.unpack_from('<I', data, pos)[0]" &
        ASCII.LF &
        "        pos += 4" & ASCII.LF &
        "        msg['newfid'] = struct.unpack_from('<I', data, pos)[0]" &
        ASCII.LF &
        "        pos += 4" & ASCII.LF &
        "        nwname = struct.unpack_from('<H', data, pos)[0]" & ASCII.LF &
        "        pos += 2" & ASCII.LF &
        "        names = []" & ASCII.LF &
        "        for _ in range(nwname):" & ASCII.LF &
        "            name, pos = read_str(data, pos)" & ASCII.LF &
        "            names.append(name)" & ASCII.LF &
        "        msg['names'] = names" & ASCII.LF &
        "    elif mtype == 112:" & ASCII.LF &
        "        msg['fid'] = struct.unpack_from('<I', data, pos)[0]" &
        ASCII.LF &
        "        pos += 4" & ASCII.LF &
        "        msg['mode'] = data[pos]" & ASCII.LF &
        "    elif mtype == 116:" & ASCII.LF &
        "        msg['fid'] = struct.unpack_from('<I', data, pos)[0]" &
        ASCII.LF &
        "        pos += 4" & ASCII.LF &
        "        msg['offset'] = struct.unpack_from('<Q', data, pos)[0]" &
        ASCII.LF &
        "        pos += 8" & ASCII.LF &
        "        msg['count'] = struct.unpack_from('<I', data, pos)[0]" &
        ASCII.LF &
        "    elif mtype == 118:" & ASCII.LF &
        "        msg['fid'] = struct.unpack_from('<I', data, pos)[0]" &
        ASCII.LF &
        "        pos += 4" & ASCII.LF &
        "        msg['offset'] = struct.unpack_from('<Q', data, pos)[0]" &
        ASCII.LF &
        "        pos += 8" & ASCII.LF &
        "        msg['count'] = struct.unpack_from('<I', data, pos)[0]" &
        ASCII.LF &
        "    elif mtype == 120:" & ASCII.LF &
        "        msg['fid'] = struct.unpack_from('<I', data, pos)[0]" &
        ASCII.LF &
        "    return msg" & ASCII.LF &
        "def pstr(text):" & ASCII.LF &
        "    data = text.encode('latin1')" & ASCII.LF &
        "    return struct.pack('<H', len(data)) + data" & ASCII.LF &
        "def qid(path_value=1):" & ASCII.LF &
        "    return struct.pack('<BIQ', 0, 0, path_value)" & ASCII.LF &
        "def send_msg(sock, code, tag, body=b''):" & ASCII.LF &
        "    packet = struct.pack('<I', 7 + len(body))" & ASCII.LF &
        "    packet += bytes([code]) + struct.pack('<H', tag) + body" &
        ASCII.LF &
        "    sock.sendall(packet)" & ASCII.LF &
        "def send_rversion(sock, tag, msize, version):" & ASCII.LF &
        "    send_msg(sock, 101, tag, struct.pack('<I', msize) + " &
        "pstr(version))" & ASCII.LF &
        "def send_rattach(sock, tag):" & ASCII.LF &
        "    send_msg(sock, 105, tag, qid(1))" & ASCII.LF &
        "def send_rwalk(sock, tag, count):" & ASCII.LF &
        "    body = struct.pack('<H', count) + b''.join(qid(i + 1) for i " &
        "in range(count))" & ASCII.LF &
        "    send_msg(sock, 111, tag, body)" & ASCII.LF &
        "def send_ropen(sock, tag, iounit):" & ASCII.LF &
        "    send_msg(sock, 113, tag, qid(7) + struct.pack('<I', iounit))" &
        ASCII.LF &
        "def send_rread(sock, tag, payload):" & ASCII.LF &
        "    send_msg(sock, 117, tag, struct.pack('<I', len(payload)) + " &
        "payload)" & ASCII.LF &
        "def send_rwrite(sock, tag, count):" & ASCII.LF &
        "    send_msg(sock, 119, tag, struct.pack('<I', count))" & ASCII.LF &
        "def send_rclunk(sock, tag):" & ASCII.LF &
        "    send_msg(sock, 121, tag, b'')" & ASCII.LF &
        "def send_rerror(sock, tag, name):" & ASCII.LF &
        "    send_msg(sock, 107, tag, pstr(name))" & ASCII.LF &
        "def expect(sock, name):" & ASCII.LF &
        "    msg = recv_msg(sock)" & ASCII.LF &
        "    events.append(msg)" & ASCII.LF &
        "    assert msg['type'] == name, f'expected {name}, got ' + " &
        "msg['type']" & ASCII.LF &
        "    return msg" & ASCII.LF &
        "def drain(sock, allow_twrite=False):" & ASCII.LF &
        "    while True:" & ASCII.LF &
        "        try:" & ASCII.LF &
        "            msg = recv_msg(sock)" & ASCII.LF &
        "        except (EOFError, socket.timeout):" & ASCII.LF &
        "            return" & ASCII.LF &
        "        events.append(msg)" & ASCII.LF &
        "        if msg['type'] == 'Tclunk':" & ASCII.LF &
        "            send_rclunk(sock, msg['tag'])" & ASCII.LF &
        "        elif msg['type'] == 'Twrite' and allow_twrite:" & ASCII.LF &
        "            send_rwrite(sock, msg['tag'], msg['count'])" & ASCII.LF &
        "        else:" & ASCII.LF &
        "            send_rerror(sock, msg['tag'], 'unexpected ' + " &
        "msg['type'])" & ASCII.LF &
        "server = None" & ASCII.LF &
        "conn = None" & ASCII.LF &
        "try:" & ASCII.LF &
        "    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)" &
        ASCII.LF &
        "    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)" &
        ASCII.LF &
        "    server.bind(('127.0.0.1', port))" & ASCII.LF &
        "    server.listen(1)" & ASCII.LF &
        "    server.settimeout(5.0)" & ASCII.LF &
        "    conn, _ = server.accept()" & ASCII.LF &
        "    conn.settimeout(2.0)" & ASCII.LF &
        "    tversion = expect(conn, 'Tversion')" & ASCII.LF &
        "    if scenario == 'rversion_fail':" & ASCII.LF &
        "        send_rversion(conn, tversion['tag'], tversion['msize'], " &
        "'unknown')" & ASCII.LF &
        "    else:" & ASCII.LF &
        "        reply_msize = 64 if scenario == 'write_split' else " &
        "tversion['msize']" & ASCII.LF &
        "        send_rversion(conn, tversion['tag'], reply_msize, " &
        "'9P2000')" & ASCII.LF &
        "        tattach = expect(conn, 'Tattach')" & ASCII.LF &
        "        send_rattach(conn, tattach['tag'])" & ASCII.LF &
        "        if scenario == 'walk_failure':" & ASCII.LF &
        "            twalk = expect(conn, 'Twalk')" & ASCII.LF &
        "            send_rerror(conn, twalk['tag'], 'file not found')" &
        ASCII.LF &
        "            drain(conn, allow_twrite=False)" & ASCII.LF &
        "        else:" & ASCII.LF &
        "            twalk = expect(conn, 'Twalk')" & ASCII.LF &
        "            send_rwalk(conn, twalk['tag'], len(twalk['names']))" &
        ASCII.LF &
        "            topen = expect(conn, 'Topen')" & ASCII.LF &
        "            send_ropen(conn, topen['tag'], 0)" & ASCII.LF &
        "            if scenario == 'read_once':" & ASCII.LF &
        "                tread = expect(conn, 'Tread')" & ASCII.LF &
        "                send_rread(conn, tread['tag'], b'hello')" & ASCII.LF &
        "                drain(conn, allow_twrite=False)" & ASCII.LF &
        "            elif scenario == 'read_aggregate':" & ASCII.LF &
        "                for payload in (b'abcd', b'EFGH', b''):" & ASCII.LF &
        "                    tread = expect(conn, 'Tread')" & ASCII.LF &
        "                    send_rread(conn, tread['tag'], payload)" &
        ASCII.LF &
        "                drain(conn, allow_twrite=False)" & ASCII.LF &
        "            elif scenario == 'write_split':" & ASCII.LF &
        "                drain(conn, allow_twrite=True)" & ASCII.LF &
        "            elif scenario == 'read_error':" & ASCII.LF &
        "                tread = expect(conn, 'Tread')" & ASCII.LF &
        "                send_rerror(conn, tread['tag'], " &
        "'permission denied')" & ASCII.LF &
        "                drain(conn, allow_twrite=False)" & ASCII.LF &
        "            elif scenario == 'finalize_clunk':" & ASCII.LF &
        "                drain(conn, allow_twrite=False)" & ASCII.LF &
        "            else:" & ASCII.LF &
        "                raise AssertionError('unknown scenario ' + " &
        "scenario)" & ASCII.LF &
        "except Exception as exc:" & ASCII.LF &
        "    result['error'] = str(exc)" & ASCII.LF &
        "    result['traceback'] = traceback.format_exc()" & ASCII.LF &
        "finally:" & ASCII.LF &
        "    if conn is not None:" & ASCII.LF &
        "        conn.close()" & ASCII.LF &
        "    if server is not None:" & ASCII.LF &
        "        server.close()" & ASCII.LF &
        "    with open(log_path, 'w', encoding='utf-8') as out:" & ASCII.LF &
        "        json.dump(result, out)" & ASCII.LF;
   end Mock_Server_Script;

   function Spawn_Server
     (Scenario : String;
      Port     : Positive;
      Log_Path : String) return Process_Handle
   is
      Args : Argument_List;
   begin
      Args.Append ("python3");
      Args.Append ("-u");
      Args.Append ("-c");
      Args.Append (Mock_Server_Script);
      Args.Append (Scenario);
      Args.Append (Natural_Image (Port));
      Args.Append (Log_Path);
      return Start (Args => Args);
   end Spawn_Server;

   procedure Wait_For_Server (Handle : in out Process_Handle) is
   begin
      if Handle = Invalid_Handle then
         return;
      end if;

      declare
         Exit_Code : constant Integer := Wait (Handle);
         pragma Unreferenced (Exit_Code);
      begin
         null;
      end;

      Handle := Invalid_Handle;
   end Wait_For_Server;

   procedure Stop_Server (Handle : in out Process_Handle) is
      Dummy : Integer;
      pragma Unreferenced (Dummy);
   begin
      if Handle = Invalid_Handle then
         return;
      end if;

      if State (Handle) = RUNNING then
         Dummy := C_Kill (Integer (Handle), 15);
      end if;

      declare
         Exit_Code : constant Integer := Wait (Handle);
         pragma Unreferenced (Exit_Code);
      begin
         null;
      end;

      Handle := Invalid_Handle;
   exception
      when others =>
         Handle := Invalid_Handle;
   end Stop_Server;

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

   function Load_Log (Path : String) return JSON_Value is
      Content : constant String := Read_File (Path);
      Parsed  : constant Read_Result := Read (Content);
   begin
      Assert (Content'Length > 0, "Mock-server log file is empty: " & Path);
      Assert (Parsed.Success, "Mock-server log is not valid JSON: " & Path);
      return Parsed.Value;
   end Load_Log;

   function Json_String_Field
     (Value : JSON_Value;
      Field : String) return String
   is
   begin
      if Value.Kind = JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = JSON_String_Type
      then
         return Value.Get (Field).Get;
      end if;

      return "";
   end Json_String_Field;

   function Json_Int_Field
     (Value   : JSON_Value;
      Field   : String;
      Default : Long_Integer := 0) return Long_Integer
   is
   begin
      if Value.Kind = JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = JSON_Int_Type
      then
         return Value.Get (Field).Get;
      end if;

      return Default;
   end Json_Int_Field;

   procedure Assert_No_Server_Error (Log : JSON_Value) is
      Error_Text : constant String := Json_String_Field (Log, "error");
   begin
      Assert
        (Error_Text = "",
         "Mock server failed: " & Error_Text
         & (if Json_String_Field (Log, "traceback")'Length > 0
            then ASCII.LF & Json_String_Field (Log, "traceback")
            else ""));
   end Assert_No_Server_Error;

   function Count_Events
     (Events : JSON_Array;
      Kind   : String) return Natural
   is
      Count : Natural := 0;
   begin
      for I in 1 .. Length (Events) loop
         if Json_String_Field
              (GNATCOLL.JSON.Get (Events, I), "type") = Kind
         then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Count_Events;

   function Nth_Event_Of_Kind
     (Events : JSON_Array;
      Kind   : String;
      Index  : Positive) return JSON_Value
   is
      Seen : Natural := 0;
   begin
      for I in 1 .. Length (Events) loop
         declare
            Event : constant JSON_Value := GNATCOLL.JSON.Get (Events, I);
         begin
            if Json_String_Field (Event, "type") = Kind then
               Seen := Seen + 1;
               if Seen = Index then
                  return Event;
               end if;
            end if;
         end;
      end loop;

      raise Constraint_Error with "missing event kind " & Kind;
   end Nth_Event_Of_Kind;

   function Events_Of (Log : JSON_Value) return JSON_Array is
   begin
      Assert
        (Log.Kind = JSON_Object_Type,
         "Mock-server log must be JSON object");
      Assert
        (Log.Has_Field ("events"),
         "Mock-server log missing events field");
      Assert
        (Log.Get ("events").Kind = JSON_Array_Type,
         "Mock-server log events field must be a JSON array");
      return Log.Get ("events").Get;
   end Events_Of;

   procedure Test_Read_Once_Returns_Single_Tread
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Port    : constant Positive := 28_901;
      Log_File : constant String := "/tmp/nine_p_mock_read_once.json";
      Handle   : Process_Handle := Invalid_Handle;
   begin
      Delete_If_Exists (Log_File);
      Handle := Spawn_Server ("read_once", Port, Log_File);

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

      Wait_For_Server (Handle);

      declare
         Log    : constant JSON_Value := Load_Log (Log_File);
         Events : constant JSON_Array := Events_Of (Log);
      begin
         Assert_No_Server_Error (Log);
         Assert
           (Count_Events (Events, "Tread") = 1,
            "Read_Once should issue exactly one Tread");
      end;
   exception
      when others =>
         Stop_Server (Handle);
         raise;
   end Test_Read_Once_Returns_Single_Tread;

   procedure Test_Read_Aggregates_Chunks_Until_EOF
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Port    : constant Positive := 28_902;
      Log_File : constant String := "/tmp/nine_p_mock_read_aggregate.json";
      Handle   : Process_Handle := Invalid_Handle;
   begin
      Delete_If_Exists (Log_File);
      Handle := Spawn_Server ("read_aggregate", Port, Log_File);

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

      Wait_For_Server (Handle);

      declare
         Log    : constant JSON_Value := Load_Log (Log_File);
         Events : constant JSON_Array := Events_Of (Log);
      begin
         Assert_No_Server_Error (Log);
         Assert
           (Count_Events (Events, "Tread") = 3,
            "Read should continue issuing Tread until zero-length EOF");
      end;
   exception
      when others =>
         Stop_Server (Handle);
         raise;
   end Test_Read_Aggregates_Chunks_Until_EOF;

   procedure Test_Write_Splits_By_IOunit
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Port     : constant Positive := 28_903;
      Log_File : constant String := "/tmp/nine_p_mock_write_split.json";
      Handle   : Process_Handle := Invalid_Handle;
      Payload  : constant String := Make_Test_Data (95);
   begin
      Delete_If_Exists (Log_File);
      Handle := Spawn_Server ("write_split", Port, Log_File);

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

      Wait_For_Server (Handle);

      declare
         Log      : constant JSON_Value := Load_Log (Log_File);
         Events   : constant JSON_Array := Events_Of (Log);
         Write_1  : constant JSON_Value :=
           Nth_Event_Of_Kind (Events, "Twrite", 1);
         Write_2  : constant JSON_Value :=
           Nth_Event_Of_Kind (Events, "Twrite", 2);
         Write_3  : constant JSON_Value :=
           Nth_Event_Of_Kind (Events, "Twrite", 3);
      begin
         Assert_No_Server_Error (Log);
         Assert
           (Count_Events (Events, "Twrite") = 3,
            "Write should split a 95-byte payload into three Twrite calls");
         Assert
           (Json_Int_Field (Write_1, "offset") = 0
            and then Json_Int_Field (Write_1, "count") = 40,
            "First Twrite should start at offset 0 and carry 40 bytes");
         Assert
           (Json_Int_Field (Write_2, "offset") = 40
            and then Json_Int_Field (Write_2, "count") = 40,
            "Second Twrite should start at offset 40 and carry 40 bytes");
         Assert
           (Json_Int_Field (Write_3, "offset") = 80
            and then Json_Int_Field (Write_3, "count") = 15,
            "Third Twrite should start at offset 80 and carry 15 bytes");
      end;
   exception
      when others =>
         Stop_Server (Handle);
         raise;
   end Test_Write_Splits_By_IOunit;

   procedure Test_Walk_Failure_Raises_P9_Error
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Port     : constant Positive := 28_904;
      Log_File : constant String := "/tmp/nine_p_mock_walk_failure.json";
      Handle   : Process_Handle := Invalid_Handle;
      Raised   : Boolean := False;
   begin
      Delete_If_Exists (Log_File);
      Handle := Spawn_Server ("walk_failure", Port, Log_File);

      declare
         FS : aliased Nine_P.Client.Fs := Dial_With_Retry (Port);
      begin
         begin
            declare
               Opened_File : Nine_P.Client.File :=
                 Nine_P.Client.Open (FS'Access, "/missing/file", O_READ);
               pragma Unreferenced (Opened_File);
            begin
               null;
            end;
         exception
            when P9_Error =>
               Raised := True;
         end;
      end;

      Wait_For_Server (Handle);

      declare
         Log    : constant JSON_Value := Load_Log (Log_File);
         Events : constant JSON_Array := Events_Of (Log);
      begin
         Assert_No_Server_Error (Log);
         Assert (Raised, "Rerror on Twalk should raise P9_Error");
         Assert
           (Count_Events (Events, "Twalk") = 1,
            "Open should attempt one Twalk before failing");
      end;
   exception
      when others =>
         Stop_Server (Handle);
         raise;
   end Test_Walk_Failure_Raises_P9_Error;

   procedure Test_Rerror_On_Read_Raises_P9_Error
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Port     : constant Positive := 28_905;
      Log_File : constant String := "/tmp/nine_p_mock_read_error.json";
      Handle   : Process_Handle := Invalid_Handle;
      Raised   : Boolean := False;
   begin
      Delete_If_Exists (Log_File);
      Handle := Spawn_Server ("read_error", Port, Log_File);

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

      Wait_For_Server (Handle);

      declare
         Log    : constant JSON_Value := Load_Log (Log_File);
         Events : constant JSON_Array := Events_Of (Log);
      begin
         Assert_No_Server_Error (Log);
         Assert (Raised, "Rerror on Tread should raise P9_Error");
         Assert
           (Count_Events (Events, "Tread") = 1,
            "Read_Once should issue one Tread before failing");
      end;
   exception
      when others =>
         Stop_Server (Handle);
         raise;
   end Test_Rerror_On_Read_Raises_P9_Error;

   procedure Test_Rversion_Failure_Raises_P9_Error
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Port     : constant Positive := 28_906;
      Log_File : constant String := "/tmp/nine_p_mock_rversion_failure.json";
      Handle   : Process_Handle := Invalid_Handle;
      Raised   : Boolean := False;
   begin
      Delete_If_Exists (Log_File);
      Handle := Spawn_Server ("rversion_fail", Port, Log_File);

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

      Wait_For_Server (Handle);

      declare
         Log    : constant JSON_Value := Load_Log (Log_File);
         Events : constant JSON_Array := Events_Of (Log);
      begin
         Assert_No_Server_Error (Log);
         Assert
           (Raised,
            "Unsupported Rversion value should raise P9_Error during Dial");
         Assert
           (Count_Events (Events, "Tattach") = 0,
            "Dial should fail before sending Tattach");
         Assert
           (Count_Events (Events, "Twalk") = 0,
            "Dial should fail before any Twalk");
      end;
   exception
      when others =>
         Stop_Server (Handle);
         raise;
   end Test_Rversion_Failure_Raises_P9_Error;

   procedure Test_Finalize_Sends_Tclunk
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Port     : constant Positive := 28_907;
      Log_File : constant String := "/tmp/nine_p_mock_finalize.json";
      Handle   : Process_Handle := Invalid_Handle;
   begin
      Delete_If_Exists (Log_File);
      Handle := Spawn_Server ("finalize_clunk", Port, Log_File);

      declare
         FS          : aliased Nine_P.Client.Fs := Dial_With_Retry (Port);
         Opened_File : Nine_P.Client.File :=
           Nine_P.Client.Open (FS'Access, "/mock/file", O_READ);
         pragma Unreferenced (Opened_File);
      begin
         null;
      end;

      Wait_For_Server (Handle);

      declare
         Log      : constant JSON_Value := Load_Log (Log_File);
         Events   : constant JSON_Array := Events_Of (Log);
         Clunk_1  : constant JSON_Value :=
           Nth_Event_Of_Kind (Events, "Tclunk", 1);
         Clunk_2  : constant JSON_Value :=
           Nth_Event_Of_Kind (Events, "Tclunk", 2);
      begin
         Assert_No_Server_Error (Log);
         Assert
           (Count_Events (Events, "Tclunk") = 2,
            "Finalization should clunk the walked fid and the root fid");
         Assert
           (Json_Int_Field (Clunk_1, "fid") = 2,
            "File finalization should clunk the opened file fid first");
         Assert
           (Json_Int_Field (Clunk_2, "fid") = 1,
            "Fs finalization should clunk the root fid second");
      end;
   exception
      when others =>
         Stop_Server (Handle);
         raise;
   end Test_Finalize_Sends_Tclunk;

end Nine_P_Mock_Server_Tests;
