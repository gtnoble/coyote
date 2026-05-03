with AUnit.Assertions;
with Ada.Calendar;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNATCOLL.JSON;
with GNATCOLL.OS.Process; use GNATCOLL.OS.Process;
with LLM.Events;
with LLM.HTTP;
with LLM.Providers;
with LLM.Providers.OpenRouter;
with LLM.Types;

package body LLM_OpenRouter_Tests is

   use AUnit.Assertions;
   use type GNATCOLL.JSON.JSON_Value_Type;
   use type LLM.Events.Message_Update_Kind;

   function C_Kill
      (Process_Id : Integer;
     Signal     : Integer) return Integer
      with Import, Convention => C, External_Name => "kill";

   Last_Text : Unbounded_String;

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

   procedure Reset_Collector is
   begin
      Last_Text := Null_Unbounded_String;
   end Reset_Collector;

   procedure On_Event (E : LLM.Events.Agent_Event'Class) is
   begin
      if E in LLM.Events.Message_Update_Event then
         declare
            Event : constant LLM.Events.Message_Update_Event :=
               LLM.Events.Message_Update_Event (E);
         begin
            if Event.Kind = LLM.Events.Text_Delta then
               Append (Last_Text, To_String (Event.Delta_Text));
            end if;
         end;
      end if;
   end On_Event;

   procedure Restore_Env (Name : String; Was_Set : Boolean; Value : String) is
   begin
      if Was_Set then
         Ada.Environment_Variables.Set (Name, Value);
      else
         Ada.Environment_Variables.Clear (Name);
      end if;
   end Restore_Env;

   procedure Ensure_Test_Home (Home : String) is
   begin
      Ada.Directories.Create_Path (Home & "/.coyote");
   end Ensure_Test_Home;

   procedure Delete_If_Exists (Path : String) is
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_File (Path);
      end if;
   exception
      when others =>
         null;
   end Delete_If_Exists;

   procedure Cleanup_Test_Home (Home : String) is
      Agent_Dir : constant String := Home & "/.coyote";
      Pi_Dir    : constant String := Home & "/.pi";
   begin
      Delete_If_Exists (Agent_Dir & "/openrouter_models_cache.json");
      Delete_If_Exists (Agent_Dir & "/openrouter_models_cache.json.tmp");
      Delete_If_Exists (Agent_Dir & "/models.json");

      if Ada.Directories.Exists (Agent_Dir) then
         Ada.Directories.Delete_Directory (Agent_Dir);
      end if;

      if Ada.Directories.Exists (Pi_Dir) then
         Ada.Directories.Delete_Directory (Pi_Dir);
      end if;

      if Ada.Directories.Exists (Home) then
         Ada.Directories.Delete_Directory (Home);
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

   procedure Wait_For_File
      (Path         : String;
     Max_Attempts : Positive := 100)
   is
   begin
      for Attempt in 1 .. Max_Attempts loop
         if Ada.Directories.Exists (Path) then
            return;
         end if;

         delay 0.01;
      end loop;
   end Wait_For_File;

   function Fixture_Path return String is
   begin
      return
        Ada.Directories.Current_Directory
        & "/fixtures/openrouter_models.json";
   end Fixture_Path;

   function Fixture_Data_Array return String is
      Parsed : constant GNATCOLL.JSON.Read_Result :=
         GNATCOLL.JSON.Read (Read_File (Fixture_Path));
   begin
      if not Parsed.Success then
         raise Constraint_Error with
            "Failed to parse OpenRouter catalogue fixture";
      end if;

      if Parsed.Value.Kind /= GNATCOLL.JSON.JSON_Object_Type
         or else not Parsed.Value.Has_Field ("data")
      then
         raise Constraint_Error with "Fixture is missing the data field";
      end if;

      return GNATCOLL.JSON.Write (Parsed.Value.Get ("data"));
   end Fixture_Data_Array;

   function Stale_Data_Array return String is
   begin
      return
         "[{""id"":""stale/model"",""name"":""Stale Model"","
         & """context_length"":1024,"
         & """architecture"":{"
         & """input_modalities"":[""text""],"
         & """output_modalities"":[""text""]},"
         & """pricing"":{""prompt"":""0"",""completion"":""0""},"
         & """top_provider"":{""context_length"":1024,"
         & """max_completion_tokens"":128},"
         & """supported_parameters"":[""tools""]}]";
   end Stale_Data_Array;

   function Load_Capture (Path : String) return GNATCOLL.JSON.JSON_Value is
      Parsed : constant GNATCOLL.JSON.Read_Result :=
         GNATCOLL.JSON.Read (Read_File (Path));
   begin
      if not Parsed.Success then
         raise Constraint_Error with
            "Failed to parse OpenRouter capture file";
      end if;

      return Parsed.Value;
   end Load_Capture;

   function Get_String_Field
      (Value   : GNATCOLL.JSON.JSON_Value;
     Field   : String;
     Default : String := "") return String
   is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
         and then Value.Has_Field (Field)
         and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_String_Type
      then
         return Value.Get (Field).Get;
      end if;

      return Default;
   end Get_String_Field;

   function Get_Natural_Field
      (Value   : GNATCOLL.JSON.JSON_Value;
     Field   : String;
     Default : Natural := 0) return Natural
   is
      Raw : Long_Integer;
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
         and then Value.Has_Field (Field)
         and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_Int_Type
      then
         Raw := Value.Get (Field).Get;

         if Raw >= 0 then
            return Natural (Raw);
         end if;
      end if;

      return Default;
   end Get_Natural_Field;

   procedure Write_Cache
      (Home       : String;
     Fetched_At : Long_Long_Integer;
     Data_Array : String)
   is
   begin
      Write_File
         (Home & "/.coyote/openrouter_models_cache.json",
       "{""fetched_at"":" & Long_Long_Image (Fetched_At)
       & ",""data"":" & Data_Array & "}");
   end Write_Cache;

   function Spawn_Server (Script : String) return Process_Handle is
      Args : Argument_List;
   begin
      Args.Append ("python3");
      Args.Append ("-u");
      Args.Append ("-c");
      Args.Append (Script);
      return Start (Args => Args);
   end Spawn_Server;

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

   procedure Send_With_Retry
      (P             : in out LLM.Providers.OpenRouter.Provider;
     Model_Id      :        String;
     Messages      :        LLM.Types.Message_Vectors.Vector;
     Thinking      :        LLM.Providers.Thinking_Level := LLM.Providers.Off)
   is
   begin
      Retry_Loop :
      for Attempt in 1 .. 20 loop
         begin
            P.Send
               (Model_Id      => Model_Id,
           System_Prompt => "",
           Messages      => Messages,
           Tools_Json    => "[]",
           Thinking      => Thinking,
           Max_Tokens    => 128,
           Handler       => On_Event'Access);
            exit Retry_Loop;
         exception
            when LLM.HTTP.Curl_Error =>
               if Attempt = 20 then
                  raise;
               end if;

               delay 0.05;
         end;
      end loop Retry_Loop;
   end Send_With_Retry;

   function Build_Messages return LLM.Types.Message_Vectors.Vector is
      Messages : LLM.Types.Message_Vectors.Vector;
      Content  : LLM.Types.Content_Block_Vectors.Vector;
   begin
      Content.Append
         ((Kind => LLM.Types.Text_Block,
            Text => To_Unbounded_String ("Say hello")));
      Messages.Append
         ((Role      => LLM.Types.User,
            Content   => Content,
            Tok_Usage => (others => 0),
            Stop      => LLM.Types.Unknown_Stop,
            Timestamp => Null_Unbounded_String));
      return Messages;
   end Build_Messages;

   function Header_Server_Script (Port : Positive) return String is
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
         & "'Bearer env-test-key'" & ASCII.LF
         & "            assert self.headers['HTTP-Referer'] == "
         & "'https://github.com/gtnoble/coyote'" & ASCII.LF
         & "            assert self.headers['X-Title'] == 'coyote'"
         & ASCII.LF
         & "            n = int(self.headers.get('Content-Length', '0'))"
         & ASCII.LF
         & "            body = json.loads(self.rfile.read(n))" & ASCII.LF
         & "            assert body['model'] == 'openai/gpt-4o-mini'"
         & ASCII.LF
         & "            assert 'reasoning' not in body" & ASCII.LF
         & "            events = [" & ASCII.LF
         & "                {'choices': [{'delta': {'content': 'Hello'},"
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
   end Header_Server_Script;

   function Reasoning_Server_Script (Port : Positive) return String is
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
         & "'Bearer reasoning-key'" & ASCII.LF
         & "            n = int(self.headers.get('Content-Length', '0'))"
         & ASCII.LF
         & "            body = json.loads(self.rfile.read(n))" & ASCII.LF
         & "            assert body['model'] == "
         & "'anthropic/claude-sonnet-4-20250514'" & ASCII.LF
         & "            assert body['reasoning']['effort'] == 'medium'"
         & ASCII.LF
         & "            events = [" & ASCII.LF
         & "                {'choices': [{'delta': {'content': 'Hello'},"
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
   end Reasoning_Server_Script;

   function Live_Fetch_Then_Send_Server_Script
      (Port         : Positive;
     Capture_Path : String) return String
   is
   begin
      return
         "import http.server, json, pathlib" & ASCII.LF
         & "capture = pathlib.Path('" & Capture_Path & "')" & ASCII.LF
         & "state = {'models_calls': 0, 'chat_calls': 0," & ASCII.LF
         & "         'chat_authorization': '', 'reasoning_effort': '',"
         & ASCII.LF
         & "         'model': ''}" & ASCII.LF
         & "def save():" & ASCII.LF
         & "    capture.write_text(json.dumps(state))" & ASCII.LF
         & "save()" & ASCII.LF
         & "models_body = json.dumps({'data': [{" & ASCII.LF
         & "    'id': 'test/model', 'name': 'Test Model'," & ASCII.LF
         & "    'context_length': 4096," & ASCII.LF
         & "    'architecture': {'input_modalities': ['text'],"
         & " 'output_modalities': ['text']}," & ASCII.LF
         & "    'pricing': {'prompt': '0.000001',"
         & " 'completion': '0.000002'}," & ASCII.LF
         & "    'top_provider': {'context_length': 4096,"
         & " 'max_completion_tokens': 256}," & ASCII.LF
         & "    'supported_parameters': ['reasoning']}]}).encode()"
         & ASCII.LF
         & "events = [" & ASCII.LF
         & "    {'choices': [{'delta': {'content': 'Live'},"
         & " 'finish_reason': None}]}," & ASCII.LF
         & "    {'choices': [{'delta': {}, 'finish_reason': 'stop'}],"
         & " 'usage': {'prompt_tokens': 1, 'completion_tokens': 1}}]"
         & ASCII.LF
         & "payload = ''.join(" & ASCII.LF
         & "    'data: ' + json.dumps(event) + '\n\n'" & ASCII.LF
         & "    for event in events).encode()" & ASCII.LF
         & "payload += b'data: [DONE]\n\n'" & ASCII.LF
         & "class S(http.server.HTTPServer):" & ASCII.LF
         & "    allow_reuse_address = True" & ASCII.LF
         & "class H(http.server.BaseHTTPRequestHandler):" & ASCII.LF
         & "    def do_GET(self):" & ASCII.LF
         & "        try:" & ASCII.LF
         & "            if self.path != '/api/v1/models':" & ASCII.LF
         & "                self.send_response(404)" & ASCII.LF
         & "                self.end_headers()" & ASCII.LF
         & "                return" & ASCII.LF
         & "            state['models_calls'] += 1" & ASCII.LF
         & "            save()" & ASCII.LF
         & "            self.send_response(200)" & ASCII.LF
         & "            self.send_header('Content-Type', 'application/json')"
         & ASCII.LF
         & "            self.send_header('Content-Length', "
         & "str(len(models_body)))" & ASCII.LF
         & "            self.end_headers()" & ASCII.LF
         & "            self.wfile.write(models_body)" & ASCII.LF
         & "            self.wfile.flush()" & ASCII.LF
         & "        except Exception as exc:" & ASCII.LF
         & "            self.send_response(500)" & ASCII.LF
         & "            self.send_header('Content-Type', 'text/plain')"
         & ASCII.LF
         & "            self.end_headers()" & ASCII.LF
         & "            self.wfile.write(str(exc).encode())" & ASCII.LF
         & "    def do_POST(self):" & ASCII.LF
         & "        try:" & ASCII.LF
         & "            if self.path != '/api/v1/chat/completions':"
         & ASCII.LF
         & "                self.send_response(404)" & ASCII.LF
         & "                self.end_headers()" & ASCII.LF
         & "                return" & ASCII.LF
         & "            n = int(self.headers.get('Content-Length', '0'))"
         & ASCII.LF
         & "            body = json.loads(self.rfile.read(n))" & ASCII.LF
         & "            state['chat_calls'] += 1" & ASCII.LF
         & "            state['chat_authorization'] = "
         & "self.headers.get('Authorization', '')" & ASCII.LF
         & "            state['reasoning_effort'] = body.get('reasoning', {})"
         & " .get('effort', '')" & ASCII.LF
         & "            state['model'] = body.get('model', '')" & ASCII.LF
         & "            save()" & ASCII.LF
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
         & "save()" & ASCII.LF
         & "s.timeout = 1" & ASCII.LF
         & "for _ in range(10):" & ASCII.LF
         & "    if state['models_calls'] and state['chat_calls']:"
         & ASCII.LF
         & "        break" & ASCII.LF
         & "    s.handle_request()" & ASCII.LF
         & "save()" & ASCII.LF
         & "s.server_close()" & ASCII.LF;
   end Live_Fetch_Then_Send_Server_Script;

   function Capture_Authorization_Server_Script
      (Port         : Positive;
     Capture_Path : String) return String
   is
   begin
      return
         "import http.server, json, pathlib" & ASCII.LF
         & "capture = pathlib.Path('" & Capture_Path & "')" & ASCII.LF
         & "state = {'authorization': '', 'model': ''}" & ASCII.LF
         & "def save():" & ASCII.LF
         & "    capture.write_text(json.dumps(state))" & ASCII.LF
         & "events = [" & ASCII.LF
         & "    {'choices': [{'delta': {'content': 'Settings'},"
         & " 'finish_reason': None}]}," & ASCII.LF
         & "    {'choices': [{'delta': {}, 'finish_reason': 'stop'}],"
         & " 'usage': {'prompt_tokens': 1, 'completion_tokens': 1}}]"
         & ASCII.LF
         & "payload = ''.join(" & ASCII.LF
         & "    'data: ' + json.dumps(event) + '\n\n'" & ASCII.LF
         & "    for event in events).encode()" & ASCII.LF
         & "payload += b'data: [DONE]\n\n'" & ASCII.LF
         & "class S(http.server.HTTPServer):" & ASCII.LF
         & "    allow_reuse_address = True" & ASCII.LF
         & "class H(http.server.BaseHTTPRequestHandler):" & ASCII.LF
         & "    def do_POST(self):" & ASCII.LF
         & "        try:" & ASCII.LF
         & "            if self.path != '/api/v1/chat/completions':"
         & ASCII.LF
         & "                self.send_response(404)" & ASCII.LF
         & "                self.end_headers()" & ASCII.LF
         & "                return" & ASCII.LF
         & "            n = int(self.headers.get('Content-Length', '0'))"
         & ASCII.LF
         & "            body = json.loads(self.rfile.read(n))" & ASCII.LF
         & "            state['authorization'] = "
         & "self.headers.get('Authorization', '')" & ASCII.LF
         & "            state['model'] = body.get('model', '')" & ASCII.LF
         & "            save()" & ASCII.LF
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
         & "save()" & ASCII.LF
         & "s.server_close()" & ASCII.LF;
   end Capture_Authorization_Server_Script;

   procedure Test_Send_Adds_OpenRouter_Headers (T : in out Test) is
      pragma Unreferenced (T);

      Port        : constant Positive := 18_771;
      Handle      : Process_Handle := Invalid_Handle;
      Messages    : constant LLM.Types.Message_Vectors.Vector :=
         Build_Messages;
      Provider    : LLM.Providers.OpenRouter.Provider :=
         LLM.Providers.OpenRouter.Create;
      Key_Was_Set : constant Boolean :=
         Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key     : constant String :=
         Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
   begin
      Reset_Collector;
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "env-test-key");
      LLM.Providers.OpenRouter.Set_Base_Url
         (Provider, "http://127.0.0.1:18771/api/v1");

      Handle := Spawn_Server (Header_Server_Script (Port));

      Send_With_Retry
         (P        => Provider,
       Model_Id => "openai/gpt-4o-mini",
       Messages => Messages);

      Stop_Server (Handle);

      Assert (To_String (Last_Text) = "Hello", "Expected streamed Hello text");

      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
   exception
      when others =>
         Stop_Server (Handle);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         raise;
   end Test_Send_Adds_OpenRouter_Headers;

   procedure Test_Send_Includes_Reasoning_Effort (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_openrouter_test_home";
      Port         : constant Positive := 18_772;
      Handle       : Process_Handle := Invalid_Handle;
      Messages     : constant LLM.Types.Message_Vectors.Vector :=
         Build_Messages;
      Provider     : LLM.Providers.OpenRouter.Provider :=
         LLM.Providers.OpenRouter.Create;
      Home_Was_Set : constant Boolean :=
         Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
         Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set  : constant Boolean :=
         Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key      : constant String :=
         Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
   begin
      Reset_Collector;
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);
      Write_Cache
         (Home       => Home,
       Fetched_At => Current_Unix_S,
       Data_Array => Fixture_Data_Array);

      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "reasoning-key");
      LLM.Providers.OpenRouter.Set_Base_Url
         (Provider, "http://127.0.0.1:18772/api/v1");

      Handle := Spawn_Server (Reasoning_Server_Script (Port));

      Send_With_Retry
         (P        => Provider,
       Model_Id => "anthropic/claude-sonnet-4-20250514",
       Messages => Messages,
       Thinking => LLM.Providers.Medium);

      Stop_Server (Handle);

      Assert (To_String (Last_Text) = "Hello", "Expected streamed Hello text");

      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Stop_Server (Handle);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Send_Includes_Reasoning_Effort;

   procedure Test_OpenRouter_Stale_Cache_Fetches_Live_Then_Sends
      (T : in out Test)
   is
      pragma Unreferenced (T);

      Home         : constant String :=
         "/tmp/coyote_openrouter_test_home_2";
      Port         : constant Positive := 18_774;
      Capture_Path : constant String :=
         "/tmp/coyote_openrouter_capture_1.json";
      Handle       : Process_Handle := Invalid_Handle;
      Messages     : constant LLM.Types.Message_Vectors.Vector :=
         Build_Messages;
      Home_Was_Set : constant Boolean :=
         Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
         Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set  : constant Boolean :=
         Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key      : constant String :=
         Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Base_Was_Set : constant Boolean :=
         Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Base     : constant String :=
         Ada.Environment_Variables.Value
            ("COYOTE_OPENROUTER_BASE_URL", "");
      Capture      : GNATCOLL.JSON.JSON_Value;
      Cache_Text   : Unbounded_String;
   begin
      Reset_Collector;
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);
      Delete_If_Exists (Capture_Path);
      Write_Cache
         (Home       => Home,
       Fetched_At => Current_Unix_S - 172_800,
       Data_Array => Stale_Data_Array);

      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set
         ("OPENROUTER_API_KEY", "live-openrouter-key");
      Ada.Environment_Variables.Set
         ("COYOTE_OPENROUTER_BASE_URL", "http://127.0.0.1:18774/api/v1");

      Handle := Spawn_Server
         (Live_Fetch_Then_Send_Server_Script
             (Port => Port, Capture_Path => Capture_Path));
      Wait_For_File (Capture_Path);
      delay 0.20;

      declare
         Provider : LLM.Providers.OpenRouter.Provider :=
            LLM.Providers.OpenRouter.Create;
      begin
         LLM.Providers.OpenRouter.Set_Base_Url
            (Provider, "http://127.0.0.1:18774/api/v1");

         Send_With_Retry
            (P        => Provider,
          Model_Id => "test/model",
          Messages => Messages,
          Thinking => LLM.Providers.Medium);
      end;

      Stop_Server (Handle);
      Capture := Load_Capture (Capture_Path);
      Cache_Text :=
         To_Unbounded_String
            (Read_File (Home & "/.coyote/openrouter_models_cache.json"));

      Assert (To_String (Last_Text) = "Live", "Expected streamed Live text");
      Assert
         (Get_Natural_Field (Capture, "models_calls") = 1,
          "A stale cache should trigger one live catalogue fetch");
      Assert
         (Get_Natural_Field (Capture, "chat_calls") = 1,
          "Provider should send one OpenRouter chat request");
      Assert
         (Get_String_Field (Capture, "chat_authorization")
            = "Bearer live-openrouter-key",
          "The chat request should use the configured API key");
      Assert
         (Get_String_Field (Capture, "reasoning_effort") = "medium",
          "A reasoning send should use the refreshed live catalogue");
      Assert
         (Get_String_Field (Capture, "model") = "test/model",
          "The live model id should be sent after the stale-cache refresh");
      Assert
         (Ada.Strings.Fixed.Index (To_String (Cache_Text), "test/model") > 0,
          "The live catalogue should overwrite the stale cache contents");
      Assert
         (Ada.Strings.Fixed.Index (To_String (Cache_Text), "stale/model") = 0,
          "The stale cache entry should be replaced after the live fetch");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Base_Was_Set, Old_Base);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
      Delete_If_Exists (Capture_Path);
   exception
      when others =>
         Stop_Server (Handle);
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Base_Was_Set, Old_Base);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         Delete_If_Exists (Capture_Path);
         raise;
   end Test_OpenRouter_Stale_Cache_Fetches_Live_Then_Sends;

   procedure Test_OpenRouter_Settings_Api_Key_Fallback
      (T : in out Test)
   is
      pragma Unreferenced (T);

      Home         : constant String :=
         "/tmp/coyote_openrouter_test_home_3";
      Port         : constant Positive := 18_775;
      Capture_Path : constant String :=
         "/tmp/coyote_openrouter_capture_2.json";
      Handle       : Process_Handle := Invalid_Handle;
      Messages     : constant LLM.Types.Message_Vectors.Vector :=
         Build_Messages;
      Provider     : LLM.Providers.OpenRouter.Provider :=
         LLM.Providers.OpenRouter.Create;
      Home_Was_Set : constant Boolean :=
         Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
         Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set  : constant Boolean :=
         Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key      : constant String :=
         Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Capture      : GNATCOLL.JSON.JSON_Value;
   begin
      Reset_Collector;
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);
      Delete_If_Exists (Capture_Path);
      Write_File
         (Home & "/.coyote/models.json",
          "{""providers"":{""openrouter"":{"
          & """apiKey"":""literal-settings-key""}}}");

      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Clear ("OPENROUTER_API_KEY");
      LLM.Providers.OpenRouter.Set_Base_Url
         (Provider, "http://127.0.0.1:18775/api/v1");

      Handle := Spawn_Server
         (Capture_Authorization_Server_Script
             (Port => Port, Capture_Path => Capture_Path));
      delay 0.05;

      Send_With_Retry
         (P        => Provider,
       Model_Id => "openai/gpt-4o-mini",
       Messages => Messages);

      Stop_Server (Handle);
      Capture := Load_Capture (Capture_Path);

      Assert
         (To_String (Last_Text) = "Settings",
          "Expected the OpenRouter settings fallback response text");
      Assert
         (Get_String_Field (Capture, "authorization")
            = "Bearer literal-settings-key",
          "OpenRouter should fall back to the literal models.json apiKey");
      Assert
         (Get_String_Field (Capture, "model") = "openai/gpt-4o-mini",
          "The request should target the selected OpenRouter model");

      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
      Delete_If_Exists (Capture_Path);
   exception
      when others =>
         Stop_Server (Handle);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         Delete_If_Exists (Capture_Path);
         raise;
   end Test_OpenRouter_Settings_Api_Key_Fallback;

end LLM_OpenRouter_Tests;
