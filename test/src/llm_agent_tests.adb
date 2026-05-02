with AUnit.Assertions;
with Ada.Calendar;
with Ada.Containers;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNATCOLL.JSON;
with GNATCOLL.OS.Process; use GNATCOLL.OS.Process;
with LLM.Agent;
with LLM.Agent.Testing;
with LLM.Events;
with LLM.Session_Store;
with LLM.Types;

package body LLM_Agent_Tests is

   use AUnit.Assertions;
   use type Ada.Containers.Count_Type;
   use type GNATCOLL.JSON.JSON_Value_Type;
   use type LLM.Types.Content_Block_Kind;
   use type LLM.Types.Role;

   function C_Kill
     (Process_Id : Integer;
      Signal     : Integer) return Integer
     with Import, Convention => C, External_Name => "kill";

   function Current_Unix_S return Long_Long_Integer is
      use Ada.Calendar;

      Epoch : constant Time :=
        Time_Of (Year => 1970, Month => 1, Day => 1, Seconds => 0.0);
   begin
      return Long_Long_Integer (Clock - Epoch);
   end Current_Unix_S;

   function Long_Long_Image (Value : Long_Long_Integer) return String is
      Image : constant String := Long_Long_Integer'Image (Value);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Long_Long_Image;

   function Natural_Image (Value : Natural) return String is
      Image : constant String := Natural'Image (Value);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Natural_Image;

   procedure Restore_Env (Name : String; Was_Set : Boolean; Value : String) is
   begin
      if Was_Set then
         Ada.Environment_Variables.Set (Name, Value);
      else
         Ada.Environment_Variables.Clear (Name);
      end if;
   end Restore_Env;

   procedure Prepare_Test_Home (Home : String) is
   begin
      if Ada.Directories.Exists (Home) then
         Ada.Directories.Delete_Tree (Home);
      end if;

      Ada.Directories.Create_Path (Home & "/.pi/agent");
   end Prepare_Test_Home;

   procedure Cleanup_Test_Home (Home : String) is
   begin
      if Ada.Directories.Exists (Home) then
         Ada.Directories.Delete_Tree (Home);
      end if;
   exception
      when others =>
         null;
   end Cleanup_Test_Home;

   function Read_File (Path : String) return String is
      File    : Ada.Text_IO.File_Type;
      Content : Unbounded_String;
   begin
      if not Ada.Directories.Exists (Path) then
         return "";
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);

      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (File);
         begin
            Append (Content, Line);
            Append (Content, ASCII.LF);
         end;
      end loop;

      Ada.Text_IO.Close (File);
      return To_String (Content);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;

         raise;
   end Read_File;

   procedure Write_File (Path : String; Content : String) is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (File, Content);
      Ada.Text_IO.Close (File);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;

         raise;
   end Write_File;

   function Fixture_Data_Array return String is
      Parsed : constant GNATCOLL.JSON.Read_Result :=
        GNATCOLL.JSON.Read
          (Read_File
             (Ada.Directories.Current_Directory
              & "/fixtures/openrouter_models.json"));
   begin
      if not Parsed.Success then
         raise Constraint_Error with
           "Failed to parse OpenRouter fixture";
      end if;

      if Parsed.Value.Kind /= GNATCOLL.JSON.JSON_Object_Type
        or else not Parsed.Value.Has_Field ("data")
      then
         raise Constraint_Error with
           "OpenRouter fixture is missing the data field";
      end if;

      return GNATCOLL.JSON.Write (Parsed.Value.Get ("data"));
   end Fixture_Data_Array;

   procedure Write_OpenRouter_Cache (Home : String) is
   begin
      Write_File
        (Home & "/.pi/agent/openrouter_models_cache.json",
         "{""fetched_at"":" & Long_Long_Image (Current_Unix_S)
         & ",""data"":" & Fixture_Data_Array & "}");
   end Write_OpenRouter_Cache;

   function Spawn_Server (Script : String) return Process_Handle is
      Args : Argument_List;
   begin
      Args.Append ("python3");
      Args.Append ("-u");
      Args.Append ("-c");
      Args.Append (Script);
      return Start (Args => Args);
   end Spawn_Server;

   procedure Wait_For_Server is
   begin
      delay 0.20;
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

   function Assistant_Text (Msg : LLM.Types.Message) return String is
      Result : Unbounded_String;
   begin
      for Block of Msg.Content loop
         if Block.Kind = LLM.Types.Text_Block then
            Append (Result, To_String (Block.Text));
         end if;
      end loop;

      return To_String (Result);
   end Assistant_Text;

   function Single_Turn_Server_Script (Port : Positive) return String is
   begin
      return
        "import http.server, json" & ASCII.LF
        & "class S(http.server.HTTPServer):" & ASCII.LF
        & "    allow_reuse_address = True" & ASCII.LF
        & "class H(http.server.BaseHTTPRequestHandler):" & ASCII.LF
        & "    def do_POST(self):" & ASCII.LF
        & "        try:" & ASCII.LF
        & "            assert self.path == '/api/v1/chat/completions'"
        & ASCII.LF
        & "            assert self.headers['Authorization'] == "
        & "'Bearer test-key'" & ASCII.LF
        & "            n = int(self.headers.get('Content-Length', '0'))"
        & ASCII.LF
        & "            body = json.loads(self.rfile.read(n))" & ASCII.LF
        & "            assert body['model'] == 'openai/gpt-4o-mini'"
        & ASCII.LF
        & "            assert len(body['messages']) == 1" & ASCII.LF
        & "            assert body['messages'][0]['role'] == 'user'"
        & ASCII.LF
        & "            assert body['messages'][0]['content'] == 'Say hello'"
        & ASCII.LF
        & "            assert 'tools' not in body" & ASCII.LF
        & "            events = [" & ASCII.LF
        & "                {'choices': [{'delta': {'content': 'Hello'},"
        & " 'finish_reason': None}]}," & ASCII.LF
        & "                {'choices': [{'delta': {}, 'finish_reason': "
        & "'stop'}], 'usage': {'prompt_tokens': 10,"
        & " 'completion_tokens': 5}}]" & ASCII.LF
        & "            payload = ''.join(" & ASCII.LF
        & "                'data: ' + json.dumps(event) + '\n\n'"
        & ASCII.LF
        & "                for event in events).encode()" & ASCII.LF
        & "            payload += b'data: [DONE]\n\n'" & ASCII.LF
        & "            self.send_response(200)" & ASCII.LF
        & "            self.send_header('Content-Type', 'text/event-stream')"
        & ASCII.LF
        & "            self.send_header('Content-Length', str(len(payload)))"
        & ASCII.LF
        & "            self.end_headers()" & ASCII.LF
        & "            self.wfile.write(payload)" & ASCII.LF
        & "            self.wfile.flush()" & ASCII.LF
        & "        except Exception as exc:" & ASCII.LF
        & "            self.send_response(500)" & ASCII.LF
        & "            self.send_header('Content-Type', 'text/plain')"
        & ASCII.LF
        & "            self.end_headers()" & ASCII.LF
        & "            self.wfile.write(str(exc).encode())" & ASCII.LF
        & "    def log_message(self, *a): pass" & ASCII.LF
        & "s = S(('127.0.0.1', " & Natural_Image (Port) & "), H)"
        & ASCII.LF
        & "s.timeout = 5" & ASCII.LF
        & "s.handle_request()" & ASCII.LF
        & "s.server_close()" & ASCII.LF;
   end Single_Turn_Server_Script;

   function Tool_Call_Server_Script (Port : Positive) return String is
   begin
      return
        "import http.server, json" & ASCII.LF
        & "class S(http.server.HTTPServer):" & ASCII.LF
        & "    allow_reuse_address = True" & ASCII.LF
        & "class H(http.server.BaseHTTPRequestHandler):" & ASCII.LF
        & "    count = 0" & ASCII.LF
        & "    def do_POST(self):" & ASCII.LF
        & "        try:" & ASCII.LF
        & "            H.count += 1" & ASCII.LF
        & "            assert self.path == '/api/v1/chat/completions'"
        & ASCII.LF
        & "            assert self.headers['Authorization'] == "
        & "'Bearer test-key'" & ASCII.LF
        & "            n = int(self.headers.get('Content-Length', '0'))"
        & ASCII.LF
        & "            body = json.loads(self.rfile.read(n))" & ASCII.LF
        & "            assert body['model'] == 'openai/gpt-4o-mini'"
        & ASCII.LF
        & "            if H.count == 1:" & ASCII.LF
        & "                assert len(body['messages']) == 1" & ASCII.LF
        & "                assert body['messages'][0]['content'] == "
        & "'Use a tool'" & ASCII.LF
        & "                assert len(body['tools']) > 0" & ASCII.LF
        & "                events = [" & ASCII.LF
        & "                    {'choices': [{'delta': {'tool_calls': ["
        & "{'index': 0, 'id': 'call_1', 'type': 'function',"
        & " 'function': {'name': 'bash', 'arguments': "
        & "'{""command"":""echo tool-ok""}'}}]},"
        & " 'finish_reason': None}]}," & ASCII.LF
        & "                    {'choices': [{'delta': {}, 'finish_reason':"
        & " 'tool_calls'}], 'usage': {'prompt_tokens': 12,"
        & " 'completion_tokens': 6}}]" & ASCII.LF
        & "            else:" & ASCII.LF
        & "                assert len(body['messages']) == 3" & ASCII.LF
        & "                assert body['messages'][1]['tool_calls'][0]['id']"
        & " == 'call_1'" & ASCII.LF
        & "                assert body['messages'][2]['role'] == 'tool'"
        & ASCII.LF
        & "                assert 'tool-ok' in body['messages'][2]['content']"
        & ASCII.LF
        & "                events = [" & ASCII.LF
        & "                    {'choices': [{'delta': {'content': 'Done'},"
        & " 'finish_reason': None}]}," & ASCII.LF
        & "                    {'choices': [{'delta': {}, 'finish_reason':"
        & " 'stop'}], 'usage': {'prompt_tokens': 20,"
        & " 'completion_tokens': 4}}]" & ASCII.LF
        & "            payload = ''.join(" & ASCII.LF
        & "                'data: ' + json.dumps(event) + '\n\n'"
        & ASCII.LF
        & "                for event in events).encode()" & ASCII.LF
        & "            payload += b'data: [DONE]\n\n'" & ASCII.LF
        & "            self.send_response(200)" & ASCII.LF
        & "            self.send_header('Content-Type', 'text/event-stream')"
        & ASCII.LF
        & "            self.send_header('Content-Length', str(len(payload)))"
        & ASCII.LF
        & "            self.end_headers()" & ASCII.LF
        & "            self.wfile.write(payload)" & ASCII.LF
        & "            self.wfile.flush()" & ASCII.LF
        & "        except Exception as exc:" & ASCII.LF
        & "            self.send_response(500)" & ASCII.LF
        & "            self.send_header('Content-Type', 'text/plain')"
        & ASCII.LF
        & "            self.end_headers()" & ASCII.LF
        & "            self.wfile.write(str(exc).encode())" & ASCII.LF
        & "    def log_message(self, *a): pass" & ASCII.LF
        & "s = S(('127.0.0.1', " & Natural_Image (Port) & "), H)"
        & ASCII.LF
        & "s.timeout = 5" & ASCII.LF
        & "s.handle_request()" & ASCII.LF
        & "s.handle_request()" & ASCII.LF
        & "s.server_close()" & ASCII.LF;
   end Tool_Call_Server_Script;

   function Two_Tool_Call_Server_Script (Port : Positive) return String is
   begin
      return
        "import http.server, json" & ASCII.LF
        & "class S(http.server.HTTPServer):" & ASCII.LF
        & "    allow_reuse_address = True" & ASCII.LF
        & "class H(http.server.BaseHTTPRequestHandler):" & ASCII.LF
        & "    def do_POST(self):" & ASCII.LF
        & "        try:" & ASCII.LF
        & "            assert self.path == '/api/v1/chat/completions'"
        & ASCII.LF
        & "            assert self.headers['Authorization'] == "
        & "'Bearer test-key'" & ASCII.LF
        & "            n = int(self.headers.get('Content-Length', '0'))"
        & ASCII.LF
        & "            body = json.loads(self.rfile.read(n))" & ASCII.LF
        & "            assert body['model'] == 'openai/gpt-4o-mini'"
        & ASCII.LF
        & "            assert len(body['messages']) == 1" & ASCII.LF
        & "            assert body['messages'][0]['role'] == 'user'"
        & ASCII.LF
        & "            assert body['messages'][0]['content'] == "
        & "'Use two tools'" & ASCII.LF
        & "            assert len(body['tools']) > 0" & ASCII.LF
        & "            events = [" & ASCII.LF
        & "                {'choices': [{'delta': {'tool_calls': ["
        & "{'index': 0, 'id': 'call_1', 'type': 'function',"
        & " 'function': {'name': 'bash', 'arguments': "
        & "'{""command"":""printf first-ok""}'}},"
        & " {'index': 1, 'id': 'call_2', 'type': 'function',"
        & " 'function': {'name': 'bash', 'arguments': "
        & "'{""command"":""printf second-ok""}'}}]},"
        & " 'finish_reason': None}]}," & ASCII.LF
        & "                {'choices': [{'delta': {}, 'finish_reason':"
        & " 'tool_calls'}], 'usage': {'prompt_tokens': 14,"
        & " 'completion_tokens': 7}}]" & ASCII.LF
        & "            payload = ''.join(" & ASCII.LF
        & "                'data: ' + json.dumps(event) + '\n\n'"
        & ASCII.LF
        & "                for event in events).encode()" & ASCII.LF
        & "            payload += b'data: [DONE]\n\n'" & ASCII.LF
        & "            self.send_response(200)" & ASCII.LF
        & "            self.send_header('Content-Type', 'text/event-stream')"
        & ASCII.LF
        & "            self.send_header('Content-Length', str(len(payload)))"
        & ASCII.LF
        & "            self.end_headers()" & ASCII.LF
        & "            self.wfile.write(payload)" & ASCII.LF
        & "            self.wfile.flush()" & ASCII.LF
        & "        except Exception as exc:" & ASCII.LF
        & "            self.send_response(500)" & ASCII.LF
        & "            self.send_header('Content-Type', 'text/plain')"
        & ASCII.LF
        & "            self.end_headers()" & ASCII.LF
        & "            self.wfile.write(str(exc).encode())" & ASCII.LF
        & "    def log_message(self, *a): pass" & ASCII.LF
        & "s = S(('127.0.0.1', " & Natural_Image (Port) & "), H)"
        & ASCII.LF
        & "s.timeout = 5" & ASCII.LF
        & "s.handle_request()" & ASCII.LF
        & "s.server_close()" & ASCII.LF;
   end Two_Tool_Call_Server_Script;

   function Two_Tool_Loop_Server_Script (Port : Positive) return String is
   begin
      return
        "import http.server, json" & ASCII.LF
        & "class S(http.server.HTTPServer):" & ASCII.LF
        & "    allow_reuse_address = True" & ASCII.LF
        & "class H(http.server.BaseHTTPRequestHandler):" & ASCII.LF
        & "    count = 0" & ASCII.LF
        & "    def do_POST(self):" & ASCII.LF
        & "        try:" & ASCII.LF
        & "            H.count += 1" & ASCII.LF
        & "            assert self.path == '/api/v1/chat/completions'"
        & ASCII.LF
        & "            assert self.headers['Authorization'] == "
        & "'Bearer test-key'" & ASCII.LF
        & "            n = int(self.headers.get('Content-Length', '0'))"
        & ASCII.LF
        & "            body = json.loads(self.rfile.read(n))" & ASCII.LF
        & "            assert body['model'] == 'openai/gpt-4o-mini'"
        & ASCII.LF
        & "            if H.count == 1:" & ASCII.LF
        & "                assert len(body['messages']) == 1" & ASCII.LF
        & "                assert body['messages'][0]['content'] == "
        & "'Use two tools'" & ASCII.LF
        & "                events = [" & ASCII.LF
        & "                    {'choices': [{'delta': {'tool_calls': ["
        & "{'index': 0, 'id': 'call_1', 'type': 'function',"
        & " 'function': {'name': 'bash', 'arguments': "
        & "'{""command"":""printf first-ok""}'}},"
        & " {'index': 1, 'id': 'call_2', 'type': 'function',"
        & " 'function': {'name': 'bash', 'arguments': "
        & "'{""command"":""printf second-ok""}'}}]},"
        & " 'finish_reason': None}]}," & ASCII.LF
        & "                    {'choices': [{'delta': {}, 'finish_reason':"
        & " 'tool_calls'}], 'usage': {'prompt_tokens': 14,"
        & " 'completion_tokens': 7}}]" & ASCII.LF
        & "            else:" & ASCII.LF
        & "                assert len(body['messages']) == 4" & ASCII.LF
        & "                assert body['messages'][1]['role'] == 'assistant'"
        & ASCII.LF
        & "                assert len(body['messages'][1]['tool_calls']) == 2"
        & ASCII.LF
        & "                assert body['messages'][2]['role'] == 'tool'"
        & ASCII.LF
        & "                assert body['messages'][2]['tool_call_id'] =="
        & " 'call_1'" & ASCII.LF
        & "                assert 'first-ok' in body['messages'][2]['content']"
        & ASCII.LF
        & "                assert body['messages'][3]['role'] == 'tool'"
        & ASCII.LF
        & "                assert body['messages'][3]['tool_call_id'] =="
        & " 'call_2'" & ASCII.LF
        & "                assert 'second-ok' in "
        & "body['messages'][3]['content']" & ASCII.LF
        & "                events = [" & ASCII.LF
        & "                    {'choices': [{'delta': {'content': "
        & "'All done'}, 'finish_reason': None}]}," & ASCII.LF
        & "                    {'choices': [{'delta': {}, 'finish_reason':"
        & " 'stop'}], 'usage': {'prompt_tokens': 24,"
        & " 'completion_tokens': 5}}]" & ASCII.LF
        & "            payload = ''.join(" & ASCII.LF
        & "                'data: ' + json.dumps(event) + '\n\n'"
        & ASCII.LF
        & "                for event in events).encode()" & ASCII.LF
        & "            payload += b'data: [DONE]\n\n'" & ASCII.LF
        & "            self.send_response(200)" & ASCII.LF
        & "            self.send_header('Content-Type', 'text/event-stream')"
        & ASCII.LF
        & "            self.send_header('Content-Length', str(len(payload)))"
        & ASCII.LF
        & "            self.end_headers()" & ASCII.LF
        & "            self.wfile.write(payload)" & ASCII.LF
        & "            self.wfile.flush()" & ASCII.LF
        & "        except Exception as exc:" & ASCII.LF
        & "            self.send_response(500)" & ASCII.LF
        & "            self.send_header('Content-Type', 'text/plain')"
        & ASCII.LF
        & "            self.end_headers()" & ASCII.LF
        & "            self.wfile.write(str(exc).encode())" & ASCII.LF
        & "    def log_message(self, *a): pass" & ASCII.LF
        & "s = S(('127.0.0.1', " & Natural_Image (Port) & "), H)"
        & ASCII.LF
        & "s.timeout = 5" & ASCII.LF
        & "s.handle_request()" & ASCII.LF
        & "s.handle_request()" & ASCII.LF
        & "s.server_close()" & ASCII.LF;
   end Two_Tool_Loop_Server_Script;

   function Tool_Failure_Server_Script (Port : Positive) return String is
   begin
      return
        "import http.server, json" & ASCII.LF
        & "class S(http.server.HTTPServer):" & ASCII.LF
        & "    allow_reuse_address = True" & ASCII.LF
        & "class H(http.server.BaseHTTPRequestHandler):" & ASCII.LF
        & "    count = 0" & ASCII.LF
        & "    def do_POST(self):" & ASCII.LF
        & "        try:" & ASCII.LF
        & "            H.count += 1" & ASCII.LF
        & "            assert self.path == '/api/v1/chat/completions'"
        & ASCII.LF
        & "            n = int(self.headers.get('Content-Length', '0'))"
        & ASCII.LF
        & "            body = json.loads(self.rfile.read(n))" & ASCII.LF
        & "            assert body['model'] == 'openai/gpt-4o-mini'"
        & ASCII.LF
        & "            if H.count == 1:" & ASCII.LF
        & "                assert len(body['messages']) == 1" & ASCII.LF
        & "                assert body['messages'][0]['content'] == "
        & "'Use failing tool'" & ASCII.LF
        & "                events = [" & ASCII.LF
        & "                    {'choices': [{'delta': {'tool_calls': ["
        & "{'index': 0, 'id': 'call_1', 'type': 'function',"
        & " 'function': {'name': 'read', 'arguments': "
        & "'{""path"":""/tmp/pi_acme_missing_tool_input_"
        & Natural_Image (Port)
        & ".txt""}'}}]},"
        & " 'finish_reason': None}]}," & ASCII.LF
        & "                    {'choices': [{'delta': {}, 'finish_reason':"
        & " 'tool_calls'}], 'usage': {'prompt_tokens': 12,"
        & " 'completion_tokens': 6}}]" & ASCII.LF
        & "            else:" & ASCII.LF
        & "                assert len(body['messages']) == 3" & ASCII.LF
        & "                assert body['messages'][2]['role'] == 'tool'"
        & ASCII.LF
        & "                assert body['messages'][2]['tool_call_id'] =="
        & " 'call_1'" & ASCII.LF
        & "                assert 'file not found' in"
        & " body['messages'][2]['content']" & ASCII.LF
        & "                events = [" & ASCII.LF
        & "                    {'choices': [{'delta': {'content': "
        & "'Handled failure'}, 'finish_reason': None}]}," & ASCII.LF
        & "                    {'choices': [{'delta': {}, 'finish_reason':"
        & " 'stop'}], 'usage': {'prompt_tokens': 18,"
        & " 'completion_tokens': 4}}]" & ASCII.LF
        & "            payload = ''.join(" & ASCII.LF
        & "                'data: ' + json.dumps(event) + '\n\n'"
        & ASCII.LF
        & "                for event in events).encode()" & ASCII.LF
        & "            payload += b'data: [DONE]\n\n'" & ASCII.LF
        & "            self.send_response(200)" & ASCII.LF
        & "            self.send_header('Content-Type', 'text/event-stream')"
        & ASCII.LF
        & "            self.send_header('Content-Length', str(len(payload)))"
        & ASCII.LF
        & "            self.end_headers()" & ASCII.LF
        & "            self.wfile.write(payload)" & ASCII.LF
        & "            self.wfile.flush()" & ASCII.LF
        & "        except Exception as exc:" & ASCII.LF
        & "            self.send_response(500)" & ASCII.LF
        & "            self.send_header('Content-Type', 'text/plain')"
        & ASCII.LF
        & "            self.end_headers()" & ASCII.LF
        & "            self.wfile.write(str(exc).encode())" & ASCII.LF
        & "    def log_message(self, *a): pass" & ASCII.LF
        & "s = S(('127.0.0.1', " & Natural_Image (Port) & "), H)"
        & ASCII.LF
        & "s.timeout = 5" & ASCII.LF
        & "s.handle_request()" & ASCII.LF
        & "s.handle_request()" & ASCII.LF
        & "s.server_close()" & ASCII.LF;
   end Tool_Failure_Server_Script;

   function Capture_Request_Server_Script
     (Port         : Positive;
      Capture_Path : String;
      Reply_Text   : String) return String
   is
   begin
      return
        "import http.server, json" & ASCII.LF
        & "class S(http.server.HTTPServer):" & ASCII.LF
        & "    allow_reuse_address = True" & ASCII.LF
        & "class H(http.server.BaseHTTPRequestHandler):" & ASCII.LF
        & "    def do_POST(self):" & ASCII.LF
        & "        try:" & ASCII.LF
        & "            assert self.path == '/api/v1/chat/completions'"
        & ASCII.LF
        & "            n = int(self.headers.get('Content-Length', '0'))"
        & ASCII.LF
        & "            body = self.rfile.read(n)" & ASCII.LF
        & "            with open('" & Capture_Path
        & "', 'wb') as out:" & ASCII.LF
        & "                out.write(body)" & ASCII.LF
        & "            events = [" & ASCII.LF
        & "                {'choices': [{'delta': {'content': '" & Reply_Text
        & "'}, 'finish_reason': None}]}," & ASCII.LF
        & "                {'choices': [{'delta': {}, 'finish_reason':"
        & " 'stop'}], 'usage': {'prompt_tokens': 16,"
        & " 'completion_tokens': 3}}]" & ASCII.LF
        & "            payload = ''.join(" & ASCII.LF
        & "                'data: ' + json.dumps(event) + '\n\n'"
        & ASCII.LF
        & "                for event in events).encode()" & ASCII.LF
        & "            payload += b'data: [DONE]\n\n'" & ASCII.LF
        & "            self.send_response(200)" & ASCII.LF
        & "            self.send_header('Content-Type', 'text/event-stream')"
        & ASCII.LF
        & "            self.send_header('Content-Length', str(len(payload)))"
        & ASCII.LF
        & "            self.end_headers()" & ASCII.LF
        & "            self.wfile.write(payload)" & ASCII.LF
        & "            self.wfile.flush()" & ASCII.LF
        & "        except Exception as exc:" & ASCII.LF
        & "            self.send_response(500)" & ASCII.LF
        & "            self.send_header('Content-Type', 'text/plain')"
        & ASCII.LF
        & "            self.end_headers()" & ASCII.LF
        & "            self.wfile.write(str(exc).encode())" & ASCII.LF
        & "    def log_message(self, *a): pass" & ASCII.LF
        & "s = S(('127.0.0.1', " & Natural_Image (Port) & "), H)"
        & ASCII.LF
        & "s.timeout = 5" & ASCII.LF
        & "s.handle_request()" & ASCII.LF
        & "s.server_close()" & ASCII.LF;
   end Capture_Request_Server_Script;

   function Delayed_Tool_Call_Server_Script (Port : Positive) return String is
   begin
      return
        "import http.server, json, time" & ASCII.LF
        & "class S(http.server.HTTPServer):" & ASCII.LF
        & "    allow_reuse_address = True" & ASCII.LF
        & "class H(http.server.BaseHTTPRequestHandler):" & ASCII.LF
        & "    count = 0" & ASCII.LF
        & "    def do_POST(self):" & ASCII.LF
        & "        try:" & ASCII.LF
        & "            H.count += 1" & ASCII.LF
        & "            assert self.path == '/api/v1/chat/completions'"
        & ASCII.LF
        & "            n = int(self.headers.get('Content-Length', '0'))"
        & ASCII.LF
        & "            body = json.loads(self.rfile.read(n))" & ASCII.LF
        & "            assert body['model'] == 'openai/gpt-4o-mini'"
        & ASCII.LF
        & "            if H.count == 1:" & ASCII.LF
        & "                assert len(body['messages']) == 1" & ASCII.LF
        & "                assert body['messages'][0]['content'] == "
        & "'Use delayed tool'" & ASCII.LF
        & "                assert len(body['tools']) > 0" & ASCII.LF
        & "                events = [" & ASCII.LF
        & "                    {'choices': [{'delta': {'tool_calls': ["
        & "{'index': 0, 'id': 'call_1', 'type': 'function',"
        & " 'function': {'name': 'bash', 'arguments': "
        & "'{""command"":""printf slow-ok""}'}}]},"
        & " 'finish_reason': None}]}," & ASCII.LF
        & "                    {'choices': [{'delta': {}, 'finish_reason':"
        & " 'tool_calls'}], 'usage': {'prompt_tokens': 12,"
        & " 'completion_tokens': 6}}]" & ASCII.LF
        & "            else:" & ASCII.LF
        & "                assert len(body['messages']) == 3" & ASCII.LF
        & "                assert body['messages'][1]['role'] == 'assistant'"
        & ASCII.LF
        & "                assert body['messages'][1]['tool_calls'][0]['id']"
        & " == 'call_1'" & ASCII.LF
        & "                assert body['messages'][2]['role'] == 'tool'"
        & ASCII.LF
        & "                assert 'slow-ok' in body['messages'][2]['content']"
        & ASCII.LF
        & "                time.sleep(1.0)" & ASCII.LF
        & "                events = [" & ASCII.LF
        & "                    {'choices': [{'delta': {'content': 'Done'},"
        & " 'finish_reason': None}]}," & ASCII.LF
        & "                    {'choices': [{'delta': {}, 'finish_reason':"
        & " 'stop'}], 'usage': {'prompt_tokens': 20,"
        & " 'completion_tokens': 4}}]" & ASCII.LF
        & "            payload = ''.join(" & ASCII.LF
        & "                'data: ' + json.dumps(event) + '\n\n'"
        & ASCII.LF
        & "                for event in events).encode()" & ASCII.LF
        & "            payload += b'data: [DONE]\n\n'" & ASCII.LF
        & "            self.send_response(200)" & ASCII.LF
        & "            self.send_header('Content-Type', 'text/event-stream')"
        & ASCII.LF
        & "            self.send_header('Content-Length', str(len(payload)))"
        & ASCII.LF
        & "            self.end_headers()" & ASCII.LF
        & "            self.wfile.write(payload)" & ASCII.LF
        & "            self.wfile.flush()" & ASCII.LF
        & "        except Exception as exc:" & ASCII.LF
        & "            self.send_response(500)" & ASCII.LF
        & "            self.send_header('Content-Type', 'text/plain')"
        & ASCII.LF
        & "            self.end_headers()" & ASCII.LF
        & "            self.wfile.write(str(exc).encode())" & ASCII.LF
        & "    def log_message(self, *a): pass" & ASCII.LF
        & "s = S(('127.0.0.1', " & Natural_Image (Port) & "), H)"
        & ASCII.LF
        & "s.timeout = 5" & ASCII.LF
        & "s.handle_request()" & ASCII.LF
        & "s.handle_request()" & ASCII.LF
        & "s.server_close()" & ASCII.LF;
   end Delayed_Tool_Call_Server_Script;

   function Delayed_Server_Script (Port : Positive) return String is
   begin
      return
        "import http.server, json, time" & ASCII.LF
        & "class S(http.server.HTTPServer):" & ASCII.LF
        & "    allow_reuse_address = True" & ASCII.LF
        & "class H(http.server.BaseHTTPRequestHandler):" & ASCII.LF
        & "    def do_POST(self):" & ASCII.LF
        & "        try:" & ASCII.LF
        & "            time.sleep(1.0)" & ASCII.LF
        & "            events = [" & ASCII.LF
        & "                {'choices': [{'delta': {'content': 'Too late'},"
        & " 'finish_reason': None}]}," & ASCII.LF
        & "                {'choices': [{'delta': {}, 'finish_reason': "
        & "'stop'}], 'usage': {'prompt_tokens': 1,"
        & " 'completion_tokens': 1}}]" & ASCII.LF
        & "            payload = ''.join(" & ASCII.LF
        & "                'data: ' + json.dumps(event) + '\n\n'"
        & ASCII.LF
        & "                for event in events).encode()" & ASCII.LF
        & "            payload += b'data: [DONE]\n\n'" & ASCII.LF
        & "            self.send_response(200)" & ASCII.LF
        & "            self.send_header('Content-Type', 'text/event-stream')"
        & ASCII.LF
        & "            self.send_header('Content-Length', str(len(payload)))"
        & ASCII.LF
        & "            self.end_headers()" & ASCII.LF
        & "            self.wfile.write(payload)" & ASCII.LF
        & "            self.wfile.flush()" & ASCII.LF
        & "        except Exception as exc:" & ASCII.LF
        & "            self.send_response(500)" & ASCII.LF
        & "            self.send_header('Content-Type', 'text/plain')"
        & ASCII.LF
        & "            self.end_headers()" & ASCII.LF
        & "            self.wfile.write(str(exc).encode())" & ASCII.LF
        & "    def log_message(self, *a): pass" & ASCII.LF
        & "s = S(('127.0.0.1', " & Natural_Image (Port) & "), H)"
        & ASCII.LF
        & "s.timeout = 5" & ASCII.LF
        & "s.handle_request()" & ASCII.LF
        & "s.server_close()" & ASCII.LF;
   end Delayed_Server_Script;

   function Resume_Server_Script
     (Port            : Positive;
      Expect_First    : String;
      Expect_Response : String;
      Reply_Text      : String) return String
   is
   begin
      return
        "import http.server, json" & ASCII.LF
        & "class S(http.server.HTTPServer):" & ASCII.LF
        & "    allow_reuse_address = True" & ASCII.LF
        & "class H(http.server.BaseHTTPRequestHandler):" & ASCII.LF
        & "    def do_POST(self):" & ASCII.LF
        & "        try:" & ASCII.LF
        & "            n = int(self.headers.get('Content-Length', '0'))"
        & ASCII.LF
        & "            body = json.loads(self.rfile.read(n))" & ASCII.LF
        & "            assert len(body['messages']) == 3" & ASCII.LF
        & "            assert body['messages'][0]['role'] == 'user'"
        & ASCII.LF
        & "            assert body['messages'][0]['content'] == '"
        & Expect_First & "'" & ASCII.LF
        & "            assert body['messages'][1]['role'] == 'assistant'"
        & ASCII.LF
        & "            assert body['messages'][1]['content'] == '"
        & Expect_Response & "'" & ASCII.LF
        & "            assert body['messages'][2]['role'] == 'user'"
        & ASCII.LF
        & "            assert body['messages'][2]['content'] == "
        & "'Second prompt'" & ASCII.LF
        & "            events = [" & ASCII.LF
        & "                {'choices': [{'delta': {'content': '"
        & Reply_Text & "'}, 'finish_reason': None}]}," & ASCII.LF
        & "                {'choices': [{'delta': {}, 'finish_reason':"
        & " 'stop'}], 'usage': {'prompt_tokens': 9,"
        & " 'completion_tokens': 3}}]" & ASCII.LF
        & "            payload = ''.join(" & ASCII.LF
        & "                'data: ' + json.dumps(event) + '\n\n'"
        & ASCII.LF
        & "                for event in events).encode()" & ASCII.LF
        & "            payload += b'data: [DONE]\n\n'" & ASCII.LF
        & "            self.send_response(200)" & ASCII.LF
        & "            self.send_header('Content-Type', 'text/event-stream')"
        & ASCII.LF
        & "            self.send_header('Content-Length', str(len(payload)))"
        & ASCII.LF
        & "            self.end_headers()" & ASCII.LF
        & "            self.wfile.write(payload)" & ASCII.LF
        & "            self.wfile.flush()" & ASCII.LF
        & "        except Exception as exc:" & ASCII.LF
        & "            self.send_response(500)" & ASCII.LF
        & "            self.send_header('Content-Type', 'text/plain')"
        & ASCII.LF
        & "            self.end_headers()" & ASCII.LF
        & "            self.wfile.write(str(exc).encode())" & ASCII.LF
        & "    def log_message(self, *a): pass" & ASCII.LF
        & "s = S(('127.0.0.1', " & Natural_Image (Port) & "), H)"
        & ASCII.LF
        & "s.timeout = 5" & ASCII.LF
        & "s.handle_request()" & ASCII.LF
        & "s.server_close()" & ASCII.LF;
   end Resume_Server_Script;

   procedure Test_Single_Turn_Prompt (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/pi_acme_llm_agent_test_1";
      Port         : constant Positive := 18_781;
      Handle       : Process_Handle := Invalid_Handle;
      Agent_Session : LLM.Agent.Session;
      Messages     : LLM.Types.Message_Vectors.Vector;
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set  : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key      : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set  : constant Boolean :=
        Ada.Environment_Variables.Exists ("PI_ACME_OPENROUTER_BASE_URL");
      Old_Url      : constant String :=
        Ada.Environment_Variables.Value ("PI_ACME_OPENROUTER_BASE_URL", "");

      procedure Ignore_Event (E : LLM.Events.Agent_Event'Class) is
         pragma Unreferenced (E);
      begin
         null;
      end Ignore_Event;
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("PI_ACME_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);

      Handle := Spawn_Server (Single_Turn_Server_Script (Port));
      Wait_For_Server;

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Say hello",
         On_Event => Ignore_Event'Access);

      Stop_Server (Handle);

      Messages := LLM.Session_Store.Load_Messages
        (LLM.Agent.Session_Id (Agent_Session));

      Assert (Messages.Length = 2, "Expected user + assistant messages");
      Assert
        (Messages.Element (0).Role = LLM.Types.User,
         "First message should be the user prompt");
      Assert
        (Messages.Element (1).Role = LLM.Types.Assistant,
         "Second message should be the assistant reply");
      Assert
        (Assistant_Text (Messages.Element (1)) = "Hello",
         "Assistant text should round-trip through session storage");
      Assert
        (Ada.Directories.Exists
           (LLM.Session_Store.Session_File_Path
              (LLM.Agent.Session_Id (Agent_Session))),
         "Session file should exist on disk after Run_Prompt");

      Restore_Env ("PI_ACME_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Stop_Server (Handle);
         Restore_Env ("PI_ACME_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Single_Turn_Prompt;

   procedure Test_Tool_Call_Loop (T : in out Test) is
      pragma Unreferenced (T);

      Home          : constant String := "/tmp/pi_acme_llm_agent_test_2";
      Port          : constant Positive := 18_782;
      Handle        : Process_Handle := Invalid_Handle;
      Agent_Session : LLM.Agent.Session;
      Messages      : LLM.Types.Message_Vectors.Vector;
      Home_Was_Set  : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home      : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key       : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("PI_ACME_OPENROUTER_BASE_URL");
      Old_Url       : constant String :=
        Ada.Environment_Variables.Value ("PI_ACME_OPENROUTER_BASE_URL", "");

      procedure Ignore_Event (E : LLM.Events.Agent_Event'Class) is
         pragma Unreferenced (E);
      begin
         null;
      end Ignore_Event;
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("PI_ACME_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => False);

      Handle := Spawn_Server (Tool_Call_Server_Script (Port));
      Wait_For_Server;

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Use a tool",
         On_Event => Ignore_Event'Access);

      Stop_Server (Handle);

      Messages := LLM.Session_Store.Load_Messages
        (LLM.Agent.Session_Id (Agent_Session));

      Assert
        (Messages.Length = 4,
         "Expected user, tool call, tool result, reply");
      Assert
        (Messages.Element (1).Role = LLM.Types.Assistant,
         "Second message should be the assistant tool-call message");
      Assert
        (Messages.Element (1).Content.Element (0).Kind
           = LLM.Types.Tool_Call_Block,
         "Assistant tool-call message should contain a tool call block");
      Assert
        (Messages.Element (2).Role = LLM.Types.Tool_Result,
         "Third message should be the tool result");
      Assert
        (Messages.Element (3).Role = LLM.Types.Assistant,
         "Fourth message should be the final assistant reply");
      Assert
        (Assistant_Text (Messages.Element (3)) = "Done",
         "Final assistant text should round-trip through session storage");

      Restore_Env ("PI_ACME_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Stop_Server (Handle);
         Restore_Env ("PI_ACME_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Tool_Call_Loop;

   procedure Test_Two_Tool_Call_Loop (T : in out Test) is
      pragma Unreferenced (T);

      Home          : constant String := "/tmp/pi_acme_llm_agent_test_7";
      Port          : constant Positive := 18_789;
      Handle        : Process_Handle := Invalid_Handle;
      Agent_Session : LLM.Agent.Session;
      Messages      : LLM.Types.Message_Vectors.Vector;
      Home_Was_Set  : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home      : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key       : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("PI_ACME_OPENROUTER_BASE_URL");
      Old_Url       : constant String :=
        Ada.Environment_Variables.Value ("PI_ACME_OPENROUTER_BASE_URL", "");

      procedure Ignore_Event (E : LLM.Events.Agent_Event'Class) is
         pragma Unreferenced (E);
      begin
         null;
      end Ignore_Event;
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("PI_ACME_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => False);

      Handle := Spawn_Server (Two_Tool_Loop_Server_Script (Port));
      Wait_For_Server;

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Use two tools",
         On_Event => Ignore_Event'Access);

      Stop_Server (Handle);

      Messages := LLM.Session_Store.Load_Messages
        (LLM.Agent.Session_Id (Agent_Session));

      Assert
        (Messages.Length = 5,
         "Expected user, assistant tool batch, two results, and reply");
      Assert
        (Messages.Element (1).Role = LLM.Types.Assistant,
         "Second message should be the assistant tool-call batch");
      Assert
        (Messages.Element (1).Content.Length = 2,
         "Assistant tool-call batch should contain two tool-call blocks");
      Assert
        (Messages.Element (1).Content.Element (0).Kind
           = LLM.Types.Tool_Call_Block,
         "First assistant block should be a tool call");
      Assert
        (Messages.Element (1).Content.Element (1).Kind
           = LLM.Types.Tool_Call_Block,
         "Second assistant block should be a tool call");
      Assert
        (Messages.Element (2).Role = LLM.Types.Tool_Result,
         "Third message should be the first tool result");
      Assert
        (Messages.Element (3).Role = LLM.Types.Tool_Result,
         "Fourth message should be the second tool result");
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Messages.Element (2).Content.Element (0).Result_Text),
            "first-ok") > 0,
         "First tool result should contain first-ok");
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Messages.Element (3).Content.Element (0).Result_Text),
            "second-ok") > 0,
         "Second tool result should contain second-ok");
      Assert
        (Messages.Element (4).Role = LLM.Types.Assistant,
         "Fifth message should be the final assistant reply");
      Assert
        (Assistant_Text (Messages.Element (4)) = "All done",
         "Final assistant reply should round-trip through session storage");

      Restore_Env ("PI_ACME_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Stop_Server (Handle);
         Restore_Env ("PI_ACME_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Two_Tool_Call_Loop;

   procedure Test_Tool_Execution_Failure (T : in out Test) is
      pragma Unreferenced (T);

      Home               : constant String := "/tmp/pi_acme_llm_agent_test_8";
      Port               : constant Positive := 18_793;
      Handle             : Process_Handle := Invalid_Handle;
      Agent_Session      : LLM.Agent.Session;
      Messages           : LLM.Types.Message_Vectors.Vector;
      Saw_Tool_End       : Boolean := False;
      Tool_End_Is_Error  : Boolean := False;
      Tool_End_Result    : Unbounded_String := Null_Unbounded_String;
      Home_Was_Set       : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home           : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set        : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key            : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set        : constant Boolean :=
        Ada.Environment_Variables.Exists ("PI_ACME_OPENROUTER_BASE_URL");
      Old_Url            : constant String :=
        Ada.Environment_Variables.Value ("PI_ACME_OPENROUTER_BASE_URL", "");

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         if E in LLM.Events.Tool_Execution_End_Event then
            declare
               Event : constant LLM.Events.Tool_Execution_End_Event :=
                 LLM.Events.Tool_Execution_End_Event (E);
            begin
               Saw_Tool_End := True;
               Tool_End_Is_Error := Event.Is_Error;
               Tool_End_Result := Event.Result_Text;
            end;
         end if;
      end On_Event;
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("PI_ACME_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => False);

      Handle := Spawn_Server (Tool_Failure_Server_Script (Port));
      Wait_For_Server;

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Use failing tool",
         On_Event => On_Event'Access);

      Stop_Server (Handle);

      Messages := LLM.Session_Store.Load_Messages
        (LLM.Agent.Session_Id (Agent_Session));

      Assert (Saw_Tool_End, "Tool_Execution_End_Event should be emitted");
      Assert
        (Tool_End_Is_Error,
         "Tool_Execution_End_Event.Is_Error should be True");
      Assert
        (Ada.Strings.Fixed.Index (To_String (Tool_End_Result),
           "file not found") > 0,
         "Tool failure result text should describe the missing file");
      Assert
        (Messages.Length = 4,
         "Failed tool turn should persist user, tool call, result, and reply");
      Assert
        (Messages.Element (2).Role = LLM.Types.Tool_Result,
         "Third message should be the persisted tool result");
      Assert
        (Messages.Element (2).Content.Element (0).Is_Error,
         "Persisted tool result block should preserve Is_Error=True");
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Messages.Element (2).Content.Element (0).Result_Text),
            "file not found") > 0,
         "Persisted tool result text should describe the missing file");
      Assert
        (Assistant_Text (Messages.Element (3)) = "Handled failure",
         "Final assistant reply should still complete after tool failure");

      Restore_Env ("PI_ACME_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Stop_Server (Handle);
         Restore_Env ("PI_ACME_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Tool_Execution_Failure;

   procedure Test_Switch_Session_Loads_History (T : in out Test) is
      pragma Unreferenced (T);

      Home          : constant String := "/tmp/pi_acme_llm_agent_test_9";
      Agent_Session : LLM.Agent.Session;
      Existing_Id   : Unbounded_String;
      User_Content  : LLM.Types.Content_Block_Vectors.Vector;
      Reply_Content : LLM.Types.Content_Block_Vectors.Vector;
      Home_Was_Set  : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home      : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key       : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");

      Existing_Id := To_Unbounded_String
        (LLM.Session_Store.Create_Session (Ada.Directories.Current_Directory));

      User_Content.Append
        ((Kind => LLM.Types.Text_Block,
          Text => To_Unbounded_String ("Earlier question")));
      LLM.Session_Store.Append_Message
        (To_String (Existing_Id),
         (Role      => LLM.Types.User,
          Content   => User_Content,
          Tok_Usage => (others => 0),
          Stop      => LLM.Types.Unknown_Stop,
          Timestamp => Null_Unbounded_String));

      Reply_Content.Append
        ((Kind => LLM.Types.Text_Block,
          Text => To_Unbounded_String ("Earlier answer")));
      LLM.Session_Store.Append_Message
        (To_String (Existing_Id),
         (Role      => LLM.Types.Assistant,
          Content   => Reply_Content,
          Tok_Usage => (Input => 3, Output => 2, Cache_Read => 0,
                        Cache_Write => 0),
          Stop      => LLM.Types.Stop,
          Timestamp => Null_Unbounded_String));

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);

      LLM.Agent.Switch_Session (Agent_Session, To_String (Existing_Id));

      Assert
        (LLM.Agent.Session_Id (Agent_Session) = To_String (Existing_Id),
         "Switch_Session should update the active session id");
      Assert
        (LLM.Agent.Testing.History_Length (Agent_Session) = 2,
         "Switch_Session should pre-load the persisted history");
      Assert
        (LLM.Agent.Testing.History_Element (Agent_Session, 0).Role
           = LLM.Types.User,
         "First pre-loaded message should be the stored user message");
      Assert
        (To_String
           (LLM.Agent.Testing.History_Element
              (Agent_Session, 0).Content.Element (0).Text)
         = "Earlier question",
         "Stored user text should be pre-loaded into S.History");
      Assert
        (LLM.Agent.Testing.History_Element (Agent_Session, 1).Role
           = LLM.Types.Assistant,
         "Second pre-loaded message should be the stored assistant reply");
      Assert
        (Assistant_Text
           (LLM.Agent.Testing.History_Element (Agent_Session, 1))
         = "Earlier answer",
         "Stored assistant text should be pre-loaded into S.History");

      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Switch_Session_Loads_History;

   procedure Test_Abort_Request (T : in out Test) is
      pragma Unreferenced (T);

      Home          : constant String := "/tmp/pi_acme_llm_agent_test_3";
      Port          : constant Positive := 18_783;
      Handle        : Process_Handle := Invalid_Handle;
      Agent_Session : LLM.Agent.Session;
      Messages      : LLM.Types.Message_Vectors.Vector;
      Home_Was_Set  : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home      : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key       : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("PI_ACME_OPENROUTER_BASE_URL");
      Old_Url       : constant String :=
        Ada.Environment_Variables.Value ("PI_ACME_OPENROUTER_BASE_URL", "");

      protected State is
         procedure Note_End (Was_Aborted : Boolean);
         procedure Note_Error;
         function Saw_Aborted_End return Boolean;
         function Had_Error return Boolean;
      private
         Aborted_End : Boolean := False;
         Task_Error  : Boolean := False;
      end State;

      protected body State is
         procedure Note_End (Was_Aborted : Boolean) is
         begin
            Aborted_End := Was_Aborted;
         end Note_End;

         procedure Note_Error is
         begin
            Task_Error := True;
         end Note_Error;

         function Saw_Aborted_End return Boolean is
         begin
            return Aborted_End;
         end Saw_Aborted_End;

         function Had_Error return Boolean is
         begin
            return Task_Error;
         end Had_Error;
      end State;

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         if E in LLM.Events.Agent_End_Event then
            State.Note_End (LLM.Events.Agent_End_Event (E).Was_Aborted);
         end if;
      end On_Event;

   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("PI_ACME_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);

      Handle := Spawn_Server (Delayed_Server_Script (Port));
      Wait_For_Server;

      declare
         task Runner;

         task body Runner is
         begin
            LLM.Agent.Run_Prompt
              (S        => Agent_Session,
               Prompt   => "Abort this prompt",
               On_Event => On_Event'Access);
         exception
            when others =>
               State.Note_Error;
         end Runner;
      begin
         delay 0.10;
         LLM.Agent.Request_Abort (Agent_Session);

         while not Runner'Terminated loop
            delay 0.05;
         end loop;
      end;

      Stop_Server (Handle);

      Messages := LLM.Session_Store.Load_Messages
        (LLM.Agent.Session_Id (Agent_Session));

      Assert
        (not State.Had_Error,
         "Run_Prompt task should not raise");
      Assert
        (State.Saw_Aborted_End,
         "Agent_End_Event should report Was_Aborted=True");
      Assert
        (Messages.Length = 1,
         "Abort should preserve only the user prompt");

      Restore_Env ("PI_ACME_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Stop_Server (Handle);
         Restore_Env ("PI_ACME_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Abort_Request;

   procedure Test_Abort_Batched_Tools_Keep_History_Valid
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home           : constant String := "/tmp/pi_acme_llm_agent_test_5";
      Capture_Path   : constant String := Home & "/resume_request.json";
      Abort_Port     : constant Positive := 18_786;
      Resume_Port    : constant Positive := 18_787;
      Abort_Handle   : Process_Handle := Invalid_Handle;
      Resume_Handle  : Process_Handle := Invalid_Handle;
      Agent_Session  : LLM.Agent.Session;
      Messages       : LLM.Types.Message_Vectors.Vector;
      Home_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home       : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key        : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("PI_ACME_OPENROUTER_BASE_URL");
      Old_Url        : constant String :=
        Ada.Environment_Variables.Value ("PI_ACME_OPENROUTER_BASE_URL", "");

      protected State is
         procedure Note_First_Tool_End;
         procedure Note_End (Was_Aborted : Boolean);
         procedure Note_Error;
         function Saw_First_Tool_End return Boolean;
         function Saw_Aborted_End return Boolean;
         function Had_Error return Boolean;
      private
         First_Tool_Ended : Boolean := False;
         Aborted_End      : Boolean := False;
         Task_Error       : Boolean := False;
      end State;

      protected body State is
         procedure Note_First_Tool_End is
         begin
            First_Tool_Ended := True;
         end Note_First_Tool_End;

         procedure Note_End (Was_Aborted : Boolean) is
         begin
            Aborted_End := Was_Aborted;
         end Note_End;

         procedure Note_Error is
         begin
            Task_Error := True;
         end Note_Error;

         function Saw_First_Tool_End return Boolean is
         begin
            return First_Tool_Ended;
         end Saw_First_Tool_End;

         function Saw_Aborted_End return Boolean is
         begin
            return Aborted_End;
         end Saw_Aborted_End;

         function Had_Error return Boolean is
         begin
            return Task_Error;
         end Had_Error;
      end State;

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         if E in LLM.Events.Tool_Execution_End_Event then
            declare
               Tool_End : constant LLM.Events.Tool_Execution_End_Event :=
                 LLM.Events.Tool_Execution_End_Event (E);
            begin
               if To_String (Tool_End.Tool_Call_Id) = "call_1" then
                  State.Note_First_Tool_End;
                  LLM.Agent.Request_Abort (Agent_Session);
               end if;
            end;
         elsif E in LLM.Events.Agent_End_Event then
            State.Note_End (LLM.Events.Agent_End_Event (E).Was_Aborted);
         end if;
      end On_Event;

      procedure Ignore_Event (E : LLM.Events.Agent_Event'Class) is
         pragma Unreferenced (E);
      begin
         null;
      end Ignore_Event;
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("PI_ACME_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Abort_Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => False);

      Abort_Handle := Spawn_Server (Two_Tool_Call_Server_Script (Abort_Port));
      Wait_For_Server;

      declare
         task Runner;

         task body Runner is
         begin
            LLM.Agent.Run_Prompt
              (S        => Agent_Session,
               Prompt   => "Use two tools",
               On_Event => On_Event'Access);
         exception
            when others =>
               State.Note_Error;
         end Runner;
      begin
         for I in 1 .. 100 loop
            exit when State.Saw_First_Tool_End;
            delay 0.05;
         end loop;

         Assert
           (State.Saw_First_Tool_End,
            "First tool should complete before the abort callback fires");

         for I in 1 .. 100 loop
            exit when Runner'Terminated;
            delay 0.05;
         end loop;

         Assert (Runner'Terminated, "Aborted Run_Prompt should terminate");
      end;

      Stop_Server (Abort_Handle);

      Assert (not State.Had_Error, "Aborted Run_Prompt should not raise");
      Assert
        (State.Saw_Aborted_End,
         "Agent_End_Event should report Was_Aborted=True");

      Messages := LLM.Session_Store.Load_Messages
        (LLM.Agent.Session_Id (Agent_Session));
      Assert
        (Messages.Length = 1,
         "Aborted multi-tool turn should not persist assistant or tools");

      Ada.Environment_Variables.Set
        ("PI_ACME_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Resume_Port) & "/api/v1");
      Resume_Handle := Spawn_Server
        (Capture_Request_Server_Script
           (Port         => Resume_Port,
            Capture_Path => Capture_Path,
            Reply_Text   => "Recovered"));
      Wait_For_Server;

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "After abort",
         On_Event => Ignore_Event'Access);

      Stop_Server (Resume_Handle);

      declare
         Parsed : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (Read_File (Capture_Path));
      begin
         Assert (Parsed.Success, "Captured resume request should parse");

         declare
            function Json_String
              (Value : GNATCOLL.JSON.JSON_Value;
               Field : String) return String
            is
            begin
               return Value.Get (Field).Get;
            end Json_String;

            Request : constant GNATCOLL.JSON.JSON_Value := Parsed.Value;
            Msgs    : constant GNATCOLL.JSON.JSON_Array :=
              Request.Get ("messages").Get;
            Calls   : constant GNATCOLL.JSON.JSON_Array :=
              GNATCOLL.JSON.Get (Msgs, 2).Get ("tool_calls").Get;
         begin
            Assert
              (GNATCOLL.JSON.Length (Msgs) = 5,
               "Resume request should include the aborted tool batch"
               & " in memory");
            Assert
              (Json_String (GNATCOLL.JSON.Get (Msgs, 1), "role") = "user",
               "First request message should be the original user prompt");
            Assert
              (Json_String (GNATCOLL.JSON.Get (Msgs, 1), "content")
                 = "Use two tools",
               "Original user prompt should remain in history");
            Assert
              (Json_String (GNATCOLL.JSON.Get (Msgs, 2), "role")
                 = "assistant",
               "Assistant tool-call message should precede tool results");
            Assert
              (GNATCOLL.JSON.Length (Calls) = 2,
               "Assistant history message should include both tool calls");
            Assert
              (Json_String (GNATCOLL.JSON.Get (Calls, 1), "id") = "call_1",
               "First tool call id should be preserved");
            Assert
              (Json_String (GNATCOLL.JSON.Get (Calls, 2), "id") = "call_2",
               "Second tool call id should be preserved");
            Assert
              (Json_String (GNATCOLL.JSON.Get (Msgs, 3), "role") = "tool",
               "First tool result should follow the assistant tool call");
            Assert
              (Json_String (GNATCOLL.JSON.Get (Msgs, 3), "tool_call_id")
                 = "call_1",
               "First tool result should match call_1");
            Assert
              (Ada.Strings.Fixed.Index
                 (Json_String (GNATCOLL.JSON.Get (Msgs, 3), "content"),
                  "first-ok") > 0,
               "First tool result should contain the real command output");
            Assert
              (Json_String (GNATCOLL.JSON.Get (Msgs, 4), "role") = "tool",
               "Second tool result should be present after abort");
            Assert
              (Json_String (GNATCOLL.JSON.Get (Msgs, 4), "tool_call_id")
                 = "call_2",
               "Second tool result should match call_2");
            Assert
              (Json_String (GNATCOLL.JSON.Get (Msgs, 4), "content")
                 = "Aborted",
               "Second tool result should be the synthesized Aborted stub");
            Assert
              (Json_String (GNATCOLL.JSON.Get (Msgs, 5), "role") = "user",
               "Second prompt should be appended after the aborted batch");
            Assert
              (Json_String (GNATCOLL.JSON.Get (Msgs, 5), "content")
                 = "After abort",
               "Second prompt text should be preserved");
         end;
      end;

      Messages := LLM.Session_Store.Load_Messages
        (LLM.Agent.Session_Id (Agent_Session));
      Assert
        (Messages.Length = 3,
         "Only completed turns should be persisted to the session file");
      Assert
        (Assistant_Text (Messages.Element (2)) = "Recovered",
         "Second prompt should still complete after the aborted turn");

      Restore_Env ("PI_ACME_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Stop_Server (Abort_Handle);
         Stop_Server (Resume_Handle);
         Restore_Env ("PI_ACME_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Abort_Batched_Tools_Keep_History_Valid;

   procedure Test_Session_File_Written_Only_After_Turn_End
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home          : constant String := "/tmp/pi_acme_llm_agent_test_6";
      Port          : constant Positive := 18_788;
      Handle        : Process_Handle := Invalid_Handle;
      Agent_Session : LLM.Agent.Session;
      Mid_Messages  : LLM.Types.Message_Vectors.Vector;
      End_Messages  : LLM.Types.Message_Vectors.Vector;
      Home_Was_Set  : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home      : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key       : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("PI_ACME_OPENROUTER_BASE_URL");
      Old_Url       : constant String :=
        Ada.Environment_Variables.Value ("PI_ACME_OPENROUTER_BASE_URL", "");

      protected State is
         procedure Note_Tool_End;
         procedure Note_Error;
         function Saw_Tool_End return Boolean;
         function Had_Error return Boolean;
      private
         Tool_Ended : Boolean := False;
         Task_Error : Boolean := False;
      end State;

      protected body State is
         procedure Note_Tool_End is
         begin
            Tool_Ended := True;
         end Note_Tool_End;

         procedure Note_Error is
         begin
            Task_Error := True;
         end Note_Error;

         function Saw_Tool_End return Boolean is
         begin
            return Tool_Ended;
         end Saw_Tool_End;

         function Had_Error return Boolean is
         begin
            return Task_Error;
         end Had_Error;
      end State;

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         if E in LLM.Events.Tool_Execution_End_Event then
            State.Note_Tool_End;
         end if;
      end On_Event;
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("PI_ACME_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => False);

      Handle := Spawn_Server (Delayed_Tool_Call_Server_Script (Port));
      Wait_For_Server;

      declare
         task Runner;

         task body Runner is
         begin
            LLM.Agent.Run_Prompt
              (S        => Agent_Session,
               Prompt   => "Use delayed tool",
               On_Event => On_Event'Access);
         exception
            when others =>
               State.Note_Error;
         end Runner;
      begin
         for I in 1 .. 100 loop
            exit when State.Saw_Tool_End;
            delay 0.05;
         end loop;

         Assert
           (State.Saw_Tool_End,
            "Tool execution should finish before checking mid-turn storage");

         delay 0.20;
         Mid_Messages := LLM.Session_Store.Load_Messages
           (LLM.Agent.Session_Id (Agent_Session));

         Assert
           (Mid_Messages.Length = 1,
            "Session file should contain only the user prompt mid-turn");
         Assert
           (Mid_Messages.Element (0).Role = LLM.Types.User,
            "Mid-turn session file should contain the user message");

         for I in 1 .. 100 loop
            exit when Runner'Terminated;
            delay 0.05;
         end loop;

         Assert
           (Runner'Terminated,
            "Run_Prompt should finish after the delayed final response");
      end;

      Stop_Server (Handle);

      Assert (not State.Had_Error, "Delayed Run_Prompt should not raise");

      End_Messages := LLM.Session_Store.Load_Messages
        (LLM.Agent.Session_Id (Agent_Session));

      Assert
        (End_Messages.Length = 4,
         "Completed turn should persist user, tool call, tool result, reply");
      Assert
        (End_Messages.Element (1).Role = LLM.Types.Assistant,
         "Second persisted message should be the assistant tool call");
      Assert
        (End_Messages.Element (2).Role = LLM.Types.Tool_Result,
         "Third persisted message should be the tool result");
      Assert
        (Assistant_Text (End_Messages.Element (3)) = "Done",
         "Final assistant reply should persist after the turn ends");

      Restore_Env ("PI_ACME_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Stop_Server (Handle);
         Restore_Env ("PI_ACME_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Session_File_Written_Only_After_Turn_End;

   procedure Test_Session_Resume (T : in out Test) is
      pragma Unreferenced (T);

      Home            : constant String := "/tmp/pi_acme_llm_agent_test_4";
      First_Port      : constant Positive := 18_784;
      Second_Port     : constant Positive := 18_785;
      First_Handle    : Process_Handle := Invalid_Handle;
      Second_Handle   : Process_Handle := Invalid_Handle;
      First_Session   : LLM.Agent.Session;
      Resume_Session  : LLM.Agent.Session;
      Session_UUID    : Unbounded_String;
      Messages        : LLM.Types.Message_Vectors.Vector;
      Home_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home        : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set     : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key         : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set     : constant Boolean :=
        Ada.Environment_Variables.Exists ("PI_ACME_OPENROUTER_BASE_URL");
      Old_Url         : constant String :=
        Ada.Environment_Variables.Value ("PI_ACME_OPENROUTER_BASE_URL", "");

      procedure Ignore_Event (E : LLM.Events.Agent_Event'Class) is
         pragma Unreferenced (E);
      begin
         null;
      end Ignore_Event;
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("PI_ACME_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (First_Port) & "/api/v1");

      LLM.Agent.Create
        (S          => First_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);

      First_Handle := Spawn_Server (Single_Turn_Server_Script (First_Port));
      Wait_For_Server;
      LLM.Agent.Run_Prompt
        (S        => First_Session,
         Prompt   => "Say hello",
         On_Event => Ignore_Event'Access);
      Stop_Server (First_Handle);

      Session_UUID :=
        To_Unbounded_String (LLM.Agent.Session_Id (First_Session));

      Ada.Environment_Variables.Set
        ("PI_ACME_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Second_Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Resume_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True,
         Session_Id => To_String (Session_UUID));

      Second_Handle := Spawn_Server
        (Resume_Server_Script
           (Port            => Second_Port,
            Expect_First    => "Say hello",
            Expect_Response => "Hello",
            Reply_Text      => "Resumed"));
      Wait_For_Server;

      LLM.Agent.Run_Prompt
        (S        => Resume_Session,
         Prompt   => "Second prompt",
         On_Event => Ignore_Event'Access);
      Stop_Server (Second_Handle);

      Messages := LLM.Session_Store.Load_Messages (To_String (Session_UUID));

      Assert
        (Messages.Length = 4,
         "Resumed session should contain four messages");
      Assert
        (Assistant_Text (Messages.Element (1)) = "Hello",
         "Resumed session should preserve the original assistant reply");
      Assert
        (Assistant_Text (Messages.Element (3)) = "Resumed",
         "Second Run_Prompt should append the resumed reply");

      Restore_Env ("PI_ACME_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Stop_Server (First_Handle);
         Stop_Server (Second_Handle);
         Restore_Env ("PI_ACME_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Session_Resume;

end LLM_Agent_Tests;
