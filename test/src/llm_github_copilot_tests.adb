with AUnit.Assertions;
with Ada.Calendar;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNATCOLL.JSON;
with GNATCOLL.OS.Process;   use GNATCOLL.OS.Process;
with LLM.Events;
with LLM.HTTP;
with LLM.Providers;
with LLM.Providers.GitHub_Copilot;
with LLM.Types;

package body LLM_GitHub_Copilot_Tests is

   use AUnit.Assertions;
   use type GNATCOLL.JSON.JSON_Value_Type;
   use type LLM.Events.Message_Update_Kind;

   function C_Kill
      (Process_Id : Integer;
     Signal     : Integer) return Integer
      with Import, Convention => C, External_Name => "kill";

   type Response_Mode is (Anthropic_Mode, OpenAI_Mode);

   Last_Text : Unbounded_String;

   function Current_Unix_S return Long_Long_Integer is
      use Ada.Calendar;

      Epoch : constant Time :=
         Time_Of (Year => 1970, Month => 1, Day => 1, Seconds => 0.0);
   begin
      return Long_Long_Integer (Clock - Epoch);
   end Current_Unix_S;

   function Natural_Image (Value : Natural) return String is
      Image : constant String := Natural'Image (Value);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Natural_Image;

   function Long_Long_Image (Value : Long_Long_Integer) return String is
      Image : constant String := Long_Long_Integer'Image (Value);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Long_Long_Image;

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
      Delete_If_Exists (Agent_Dir & "/auth.json");
      Delete_If_Exists (Agent_Dir & "/auth.json.tmp");
      Delete_If_Exists (Agent_Dir & "/github_copilot_models_cache.json");
      Delete_If_Exists (Agent_Dir & "/github_copilot_models_cache.json.tmp");

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

   function Fixture_Path return String is
   begin
      return Ada.Directories.Current_Directory
         & "/fixtures/copilot_models_catalogue.json";
   end Fixture_Path;

   function Fixture_Data_Array return String is
      Parsed : constant GNATCOLL.JSON.Read_Result :=
         GNATCOLL.JSON.Read (Read_File (Fixture_Path));
   begin
      if not Parsed.Success then
         raise Constraint_Error with
            "Failed to parse GitHub Copilot catalogue fixture";
      end if;

      if Parsed.Value.Kind /= GNATCOLL.JSON.JSON_Object_Type
         or else not Parsed.Value.Has_Field ("data")
      then
         raise Constraint_Error with "Fixture is missing the data field";
      end if;

      return GNATCOLL.JSON.Write (Parsed.Value.Get ("data"));
   end Fixture_Data_Array;

   procedure Write_Credentials (Home : String) is
   begin
      Write_File
         (Home & "/.coyote/auth.json",
          "{""github-copilot"":{"
          & """type"":""oauth"","
          & """refresh"":""fixture-refresh"","
          & """access"":""copilot-access-token"","
          & """expires"":9999999999000}}");
   end Write_Credentials;

   procedure Write_Expired_Credentials (Home : String) is
   begin
      Write_File
         (Home & "/.coyote/auth.json",
          "{""github-copilot"":{"
          & """type"":""oauth"","
          & """refresh"":""refresh-token"","
          & """access"":""expired-token"","
          & """expires"":0}}");
   end Write_Expired_Credentials;

   procedure Write_Cache (Home : String; Base_Url : String) is
   begin
      Write_File
         (Home & "/.coyote/github_copilot_models_cache.json",
       "{""fetched_at"":" & Long_Long_Image (Current_Unix_S)
       & ",""base_url"":""" & Base_Url & """,""data"":"
       & Fixture_Data_Array & "}");
   end Write_Cache;

   function Load_Capture (Path : String) return GNATCOLL.JSON.JSON_Value is
      Parsed : constant GNATCOLL.JSON.Read_Result :=
         GNATCOLL.JSON.Read (Read_File (Path));
   begin
      if not Parsed.Success then
         raise Constraint_Error with "Failed to parse request capture file";
      end if;

      return Parsed.Value;
   end Load_Capture;

   function Get_Object_Field
      (Value : GNATCOLL.JSON.JSON_Value;
     Field : String) return GNATCOLL.JSON.JSON_Value
   is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
         and then Value.Has_Field (Field)
         and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_Object_Type
      then
         return Value.Get (Field);
      end if;

      return GNATCOLL.JSON.JSON_Null;
   end Get_Object_Field;

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

   function Build_User_Messages return LLM.Types.Message_Vectors.Vector is
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
   end Build_User_Messages;

   function Build_Assistant_Messages return LLM.Types.Message_Vectors.Vector is
      Messages : LLM.Types.Message_Vectors.Vector;
      Content  : LLM.Types.Content_Block_Vectors.Vector;
   begin
      Content.Append
         ((Kind => LLM.Types.Text_Block,
            Text => To_Unbounded_String ("Prior answer")));
      Messages.Append
         ((Role      => LLM.Types.Assistant,
            Content   => Content,
            Tok_Usage => (others => 0),
            Stop      => LLM.Types.Stop,
            Timestamp => Null_Unbounded_String));
      return Messages;
   end Build_Assistant_Messages;

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
      (P        : in out LLM.Providers.GitHub_Copilot.Provider;
     Model_Id :        String;
     Messages :        LLM.Types.Message_Vectors.Vector)
   is
   begin
      Retry_Loop :
      for Attempt in 1 .. 20 loop
         begin
            P.Send
               (Model_Id      => Model_Id,
           System_Prompt => "Be helpful.",
           Messages      => Messages,
           Tools_Json    => "[]",
           Thinking      => LLM.Providers.Off,
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

   function Anthropic_Server_Script
      (Port         : Positive;
     Capture_Path : String) return String
   is
   begin
      return
         "import http.server, json, pathlib" & ASCII.LF
         & "capture = pathlib.Path('" & Capture_Path & "')" & ASCII.LF
         & "events = [" & ASCII.LF
         & "    ('message_start', {'type': 'message_start', 'message': {"
         & "'id': 'msg_1', 'type': 'message', 'role': 'assistant',"
         & " 'content': [], 'usage': {'input_tokens': 1,"
         & " 'output_tokens': 0}}}),"
         & ASCII.LF
         & "    ('content_block_start', {'type': 'content_block_start',"
         & " 'index': 0, 'content_block': {'type': 'text'}})," & ASCII.LF
         & "    ('content_block_delta', {'type': 'content_block_delta',"
         & " 'index': 0, 'delta': {'type': 'text_delta', 'text': 'Claude'}}),"
         & ASCII.LF
         & "    ('content_block_stop', {'type': 'content_block_stop',"
         & " 'index': 0})," & ASCII.LF
         & "    ('message_delta', {'type': 'message_delta', 'delta': {"
         & "'stop_reason': 'end_turn'}, 'usage': {'output_tokens': 2}}),"
         & ASCII.LF
         & "    ('message_stop', {'type': 'message_stop'})]" & ASCII.LF
         & "payload = ''.join(" & ASCII.LF
         & "    'event: ' + name + '\n' + 'data: ' + json.dumps(data)"
         & " + '\n\n' for name, data in events).encode()" & ASCII.LF
         & "class S(http.server.HTTPServer):" & ASCII.LF
         & "    allow_reuse_address = True" & ASCII.LF
         & "class H(http.server.BaseHTTPRequestHandler):" & ASCII.LF
         & "    def do_POST(self):" & ASCII.LF
         & "        try:" & ASCII.LF
         & "            n = int(self.headers.get('Content-Length', '0'))"
         & ASCII.LF
         & "            body = json.loads(self.rfile.read(n))" & ASCII.LF
         & "            capture.write_text(json.dumps({'path': self.path,"
         & " 'headers': {k.lower(): v for k, v in self.headers.items()},"
         & " 'body': body}))" & ASCII.LF
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
   end Anthropic_Server_Script;

   function OpenAI_Server_Script
      (Port         : Positive;
     Capture_Path : String) return String
   is
   begin
      return
         "import http.server, json, pathlib" & ASCII.LF
         & "capture = pathlib.Path('" & Capture_Path & "')" & ASCII.LF
         & "events = [" & ASCII.LF
         & "    {'choices': [{'delta': {'content': 'GPT'},"
         & " 'finish_reason': None}]},"
         & ASCII.LF
         & "    {'choices': [{'delta': {}, 'finish_reason': 'stop'}],"
         & " 'usage': {'prompt_tokens': 1, 'completion_tokens': 1}}]"
         & ASCII.LF
         & "payload = ''.join(" & ASCII.LF
         & "    'data: ' + json.dumps(event) + '\n\n'"
         & " for event in events).encode() + b'data: [DONE]\n\n'"
         & ASCII.LF
         & "class S(http.server.HTTPServer):" & ASCII.LF
         & "    allow_reuse_address = True" & ASCII.LF
         & "class H(http.server.BaseHTTPRequestHandler):" & ASCII.LF
         & "    def do_POST(self):" & ASCII.LF
         & "        try:" & ASCII.LF
         & "            n = int(self.headers.get('Content-Length', '0'))"
         & ASCII.LF
         & "            body = json.loads(self.rfile.read(n))" & ASCII.LF
         & "            capture.write_text(json.dumps({'path': self.path,"
         & " 'headers': {k.lower(): v for k, v in self.headers.items()},"
         & " 'body': body}))" & ASCII.LF
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
   end OpenAI_Server_Script;

   function Refresh_Then_Send_Server_Script
      (Port         : Positive;
     Capture_Path : String;
     Fixture_File : String) return String
   is
   begin
      return
         "import http.server, json, pathlib, time" & ASCII.LF
         & "capture = pathlib.Path('" & Capture_Path & "')" & ASCII.LF
         & "fixture = pathlib.Path('" & Fixture_File & "')" & ASCII.LF
         & "state = {" & ASCII.LF
         & "    'token_calls': 0," & ASCII.LF
         & "    'models_calls': 0," & ASCII.LF
         & "    'message_calls': 0," & ASCII.LF
         & "    'models_authorization': ''," & ASCII.LF
         & "    'message_authorization': ''}" & ASCII.LF
         & "def save():" & ASCII.LF
         & "    capture.write_text(json.dumps(state))" & ASCII.LF
         & "events = [" & ASCII.LF
         & "    ('message_start', {'type': 'message_start', 'message': {"
         & "'id': 'msg_refresh', 'type': 'message', 'role': 'assistant',"
         & " 'content': [], 'usage': {'input_tokens': 1,"
         & " 'output_tokens': 0}}})," & ASCII.LF
         & "    ('content_block_start', {'type': 'content_block_start',"
         & " 'index': 0, 'content_block': {'type': 'text'}})," & ASCII.LF
         & "    ('content_block_delta', {'type': 'content_block_delta',"
         & " 'index': 0, 'delta': {'type': 'text_delta',"
         & " 'text': 'Fresh Claude'}})," & ASCII.LF
         & "    ('content_block_stop', {'type': 'content_block_stop',"
         & " 'index': 0})," & ASCII.LF
         & "    ('message_delta', {'type': 'message_delta', 'delta': {"
         & "'stop_reason': 'end_turn'}, 'usage': {'output_tokens': 2}}),"
         & ASCII.LF
         & "    ('message_stop', {'type': 'message_stop'})]" & ASCII.LF
         & "payload = ''.join(" & ASCII.LF
         & "    'event: ' + name + '\n' + 'data: ' + json.dumps(data)"
         & " + '\n\n' for name, data in events).encode()" & ASCII.LF
         & "class S(http.server.HTTPServer):" & ASCII.LF
         & "    allow_reuse_address = True" & ASCII.LF
         & "class H(http.server.BaseHTTPRequestHandler):" & ASCII.LF
         & "    def do_GET(self):" & ASCII.LF
         & "        try:" & ASCII.LF
         & "            if self.path == '/copilot_internal/v2/token':"
         & ASCII.LF
         & "                state['token_calls'] += 1" & ASCII.LF
         & "                save()" & ASCII.LF
         & "                body = json.dumps({'token': 'fresh_token_abc',"
         & " 'expires_at': int(time.time()) + 7200})"
         & ".encode()" & ASCII.LF
         & "                self.send_response(200)" & ASCII.LF
         & "                self.send_header('Content-Type', "
         & "'application/json')" & ASCII.LF
         & "                self.send_header('Content-Length', str(len(body)))"
         & ASCII.LF
         & "                self.end_headers()" & ASCII.LF
         & "                self.wfile.write(body)" & ASCII.LF
         & "                self.wfile.flush()" & ASCII.LF
         & "            elif self.path == '/models':" & ASCII.LF
         & "                state['models_calls'] += 1" & ASCII.LF
         & "                state['models_authorization'] = "
         & "self.headers.get('Authorization', '')" & ASCII.LF
         & "                save()" & ASCII.LF
         & "                body = fixture.read_bytes()" & ASCII.LF
         & "                self.send_response(200)" & ASCII.LF
         & "                self.send_header('Content-Type', "
         & "'application/json')" & ASCII.LF
         & "                self.send_header('Content-Length', str(len(body)))"
         & ASCII.LF
         & "                self.end_headers()" & ASCII.LF
         & "                self.wfile.write(body)" & ASCII.LF
         & "                self.wfile.flush()" & ASCII.LF
         & "            else:" & ASCII.LF
         & "                self.send_response(404)" & ASCII.LF
         & "                self.end_headers()" & ASCII.LF
         & "        except Exception as exc:" & ASCII.LF
         & "            self.send_response(500)" & ASCII.LF
         & "            self.send_header('Content-Type', 'text/plain')"
         & ASCII.LF
         & "            self.end_headers()" & ASCII.LF
         & "            self.wfile.write(str(exc).encode())" & ASCII.LF
         & "    def do_POST(self):" & ASCII.LF
         & "        try:" & ASCII.LF
         & "            if self.path != '/v1/messages':" & ASCII.LF
         & "                self.send_response(404)" & ASCII.LF
         & "                self.end_headers()" & ASCII.LF
         & "                return" & ASCII.LF
         & "            n = int(self.headers.get('Content-Length', '0'))"
         & ASCII.LF
         & "            json.loads(self.rfile.read(n))" & ASCII.LF
         & "            state['message_calls'] += 1" & ASCII.LF
         & "            state['message_authorization'] = "
         & "self.headers.get('Authorization', '')" & ASCII.LF
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
         & "s.timeout = 1" & ASCII.LF
         & "for _ in range(10):" & ASCII.LF
         & "    if state['token_calls'] and state['models_calls'] and"
         & " state['message_calls']:" & ASCII.LF
         & "        break" & ASCII.LF
         & "    s.handle_request()" & ASCII.LF
         & "save()" & ASCII.LF
         & "s.server_close()" & ASCII.LF;
   end Refresh_Then_Send_Server_Script;

   procedure Run_Case
      (Home         : String;
     Base_Url     : String;
     Capture_Path : String;
     Port         : Positive;
     Model_Id     : String;
     Mode         : Response_Mode;
     Messages     : LLM.Types.Message_Vectors.Vector;
     Request      : out GNATCOLL.JSON.JSON_Value)
   is
      Handle          : Process_Handle := Invalid_Handle;
      Provider        : LLM.Providers.GitHub_Copilot.Provider :=
         LLM.Providers.GitHub_Copilot.Create;
      Home_Was_Set    : constant Boolean :=
         Ada.Environment_Variables.Exists ("HOME");
      Old_Home        : constant String :=
         Ada.Environment_Variables.Value ("HOME", "");
      Base_Was_Set    : constant Boolean :=
         Ada.Environment_Variables.Exists
            ("COYOTE_GITHUB_COPILOT_BASE_URL");
      Old_Base_Url    : constant String :=
         Ada.Environment_Variables.Value
            ("COYOTE_GITHUB_COPILOT_BASE_URL", "");
      Server_Script   : constant String :=
         (if Mode = Anthropic_Mode
       then Anthropic_Server_Script (Port, Capture_Path)
       else OpenAI_Server_Script (Port, Capture_Path));
   begin
      Reset_Collector;
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);
      Write_Credentials (Home);
      Write_Cache (Home, Base_Url);
      Delete_If_Exists (Capture_Path);

      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set
         ("COYOTE_GITHUB_COPILOT_BASE_URL", Base_Url);

      Handle := Spawn_Server (Server_Script);
      delay 0.05;

      Send_With_Retry
         (P        => Provider,
       Model_Id => Model_Id,
       Messages => Messages);

      Stop_Server (Handle);
      Request := Load_Capture (Capture_Path);

      Restore_Env
         ("COYOTE_GITHUB_COPILOT_BASE_URL", Base_Was_Set, Old_Base_Url);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Stop_Server (Handle);
         Restore_Env
            ("COYOTE_GITHUB_COPILOT_BASE_URL", Base_Was_Set, Old_Base_Url);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Run_Case;

   procedure Test_Send_Adds_Static_Headers (T : in out Test) is
      pragma Unreferenced (T);

      Request : GNATCOLL.JSON.JSON_Value;
      Headers : GNATCOLL.JSON.JSON_Value;
   begin
      Run_Case
         (Home         => "/tmp/coyote_github_copilot_test_1",
       Base_Url     => "http://127.0.0.1:18790",
       Capture_Path => "/tmp/coyote_github_copilot_capture_1.json",
       Port         => 18_790,
       Model_Id     => "claude-sonnet-4.6",
       Mode         => Anthropic_Mode,
       Messages     => Build_User_Messages,
       Request      => Request);

      Headers := Get_Object_Field (Request, "headers");

      Assert
         (Get_String_Field (Headers, "user-agent")
         = "GitHubCopilotChat/0.35.0",
       "User-Agent header should be added to Copilot requests");
      Assert
         (Get_String_Field (Headers, "editor-version") = "vscode/1.107.0",
       "Editor-Version header should be added to Copilot requests");
      Assert
         (Get_String_Field (Headers, "editor-plugin-version")
         = "copilot-chat/0.35.0",
       "Editor-Plugin-Version header should be added to Copilot requests");
      Assert
         (Get_String_Field (Headers, "copilot-integration-id")
         = "vscode-chat",
       "Copilot-Integration-Id header should be added");
      Assert
         (Get_String_Field (Headers, "openai-intent")
         = "conversation-edits",
       "Openai-Intent header should be added");
      Assert
         (Get_String_Field (Headers, "authorization")
         = "Bearer copilot-access-token",
          "Copilot bearer token should be forwarded to the API request");
      Assert
         (To_String (Last_Text) = "Claude",
          "Expected Anthropic text delta");
   end Test_Send_Adds_Static_Headers;

   procedure Test_Send_Sets_X_Initiator_User (T : in out Test) is
      pragma Unreferenced (T);

      Request : GNATCOLL.JSON.JSON_Value;
      Headers : GNATCOLL.JSON.JSON_Value;
   begin
      Run_Case
         (Home         => "/tmp/coyote_github_copilot_test_2",
       Base_Url     => "http://127.0.0.1:18791",
       Capture_Path => "/tmp/coyote_github_copilot_capture_2.json",
       Port         => 18_791,
       Model_Id     => "claude-sonnet-4.6",
       Mode         => Anthropic_Mode,
       Messages     => Build_User_Messages,
       Request      => Request);

      Headers := Get_Object_Field (Request, "headers");

      Assert
         (Get_String_Field (Headers, "x-initiator") = "user",
       "Last user message should set X-Initiator to user");
   end Test_Send_Sets_X_Initiator_User;

   procedure Test_Send_Sets_X_Initiator_Agent (T : in out Test) is
      pragma Unreferenced (T);

      Request : GNATCOLL.JSON.JSON_Value;
      Headers : GNATCOLL.JSON.JSON_Value;
   begin
      Run_Case
         (Home         => "/tmp/coyote_github_copilot_test_3",
       Base_Url     => "http://127.0.0.1:18792",
       Capture_Path => "/tmp/coyote_github_copilot_capture_3.json",
       Port         => 18_792,
       Model_Id     => "gpt-4o",
       Mode         => OpenAI_Mode,
       Messages     => Build_Assistant_Messages,
       Request      => Request);

      Headers := Get_Object_Field (Request, "headers");

      Assert
         (Get_String_Field (Headers, "x-initiator") = "agent",
       "Last assistant message should set X-Initiator to agent");
   end Test_Send_Sets_X_Initiator_Agent;

   procedure Test_Send_Selects_Anthropic_Path (T : in out Test) is
      pragma Unreferenced (T);

      Request : GNATCOLL.JSON.JSON_Value;
   begin
      Run_Case
         (Home         => "/tmp/coyote_github_copilot_test_4",
       Base_Url     => "http://127.0.0.1:18793",
       Capture_Path => "/tmp/coyote_github_copilot_capture_4.json",
       Port         => 18_793,
       Model_Id     => "claude-sonnet-4.6",
       Mode         => Anthropic_Mode,
       Messages     => Build_User_Messages,
       Request      => Request);

      Assert
         (Get_String_Field (Request, "path") = "/v1/messages",
          "Claude models should use the Anthropic Messages endpoint");
      Assert
         (To_String (Last_Text) = "Claude",
          "Expected Anthropic text delta");
   end Test_Send_Selects_Anthropic_Path;

   procedure Test_Send_Selects_OpenAI_Path (T : in out Test) is
      pragma Unreferenced (T);

      Request : GNATCOLL.JSON.JSON_Value;
   begin
      Run_Case
         (Home         => "/tmp/coyote_github_copilot_test_5",
       Base_Url     => "http://127.0.0.1:18794",
       Capture_Path => "/tmp/coyote_github_copilot_capture_5.json",
       Port         => 18_794,
       Model_Id     => "gpt-4o",
       Mode         => OpenAI_Mode,
       Messages     => Build_User_Messages,
       Request      => Request);

      Assert
         (Get_String_Field (Request, "path") = "/chat/completions",
       "GPT models should use the OpenAI chat completions endpoint");
      Assert (To_String (Last_Text) = "GPT", "Expected OpenAI text delta");
   end Test_Send_Selects_OpenAI_Path;

   procedure Test_Copilot_Refreshes_Expired_Token_Then_Sends
      (T : in out Test)
   is
      pragma Unreferenced (T);

      Port           : constant Positive := 18_795;
      Home           : constant String :=
         "/tmp/coyote_github_copilot_test_6";
      Base_Url       : constant String := "http://127.0.0.1:18795";
      Capture_Path   : constant String :=
         "/tmp/coyote_github_copilot_capture_6.json";
      Handle         : Process_Handle := Invalid_Handle;
      Provider       : LLM.Providers.GitHub_Copilot.Provider :=
         LLM.Providers.GitHub_Copilot.Create;
      Home_Was_Set   : constant Boolean :=
         Ada.Environment_Variables.Exists ("HOME");
      Old_Home       : constant String :=
         Ada.Environment_Variables.Value ("HOME", "");
      Base_Was_Set   : constant Boolean :=
         Ada.Environment_Variables.Exists
            ("COYOTE_GITHUB_COPILOT_BASE_URL");
      Old_Base_Url   : constant String :=
         Ada.Environment_Variables.Value
            ("COYOTE_GITHUB_COPILOT_BASE_URL", "");
      Token_Was_Set  : constant Boolean :=
         Ada.Environment_Variables.Exists
            ("COYOTE_GITHUB_COPILOT_TOKEN_URL");
      Old_Token_Url  : constant String :=
         Ada.Environment_Variables.Value
            ("COYOTE_GITHUB_COPILOT_TOKEN_URL", "");
      Request        : GNATCOLL.JSON.JSON_Value;
   begin
      Reset_Collector;
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);
      Write_Expired_Credentials (Home);
      Delete_If_Exists (Capture_Path);

      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set
         ("COYOTE_GITHUB_COPILOT_BASE_URL", Base_Url);
      Ada.Environment_Variables.Set
         ("COYOTE_GITHUB_COPILOT_TOKEN_URL",
          Base_Url & "/copilot_internal/v2/token");

      Handle := Spawn_Server
         (Refresh_Then_Send_Server_Script
             (Port         => Port,
              Capture_Path => Capture_Path,
              Fixture_File => Fixture_Path));
      delay 0.05;

      Send_With_Retry
         (P        => Provider,
       Model_Id => "claude-sonnet-4.6",
       Messages => Build_User_Messages);

      Stop_Server (Handle);
      Request := Load_Capture (Capture_Path);

      Assert
         (To_String (Last_Text) = "Fresh Claude",
          "Expired tokens should be refreshed before the Claude send");
      Assert
         (Get_Natural_Field (Request, "token_calls") = 1,
          "Provider should refresh the expired Copilot token exactly once");
      Assert
         (Get_Natural_Field (Request, "models_calls") = 1,
          "Provider should fetch the live Copilot catalogue");
      Assert
         (Get_Natural_Field (Request, "message_calls") = 1,
          "Provider should send exactly one Anthropic request");
      Assert
         (Get_String_Field (Request, "models_authorization")
            = "Bearer fresh_token_abc",
          "Catalogue fetch should use the refreshed access token");
      Assert
         (Get_String_Field (Request, "message_authorization")
            = "Bearer fresh_token_abc",
          "Claude request should use the refreshed access token");

      Restore_Env
         ("COYOTE_GITHUB_COPILOT_TOKEN_URL", Token_Was_Set, Old_Token_Url);
      Restore_Env
         ("COYOTE_GITHUB_COPILOT_BASE_URL", Base_Was_Set, Old_Base_Url);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
      Delete_If_Exists (Capture_Path);
   exception
      when others =>
         Stop_Server (Handle);
         Restore_Env
            ("COYOTE_GITHUB_COPILOT_TOKEN_URL", Token_Was_Set,
             Old_Token_Url);
         Restore_Env
            ("COYOTE_GITHUB_COPILOT_BASE_URL", Base_Was_Set, Old_Base_Url);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         Delete_If_Exists (Capture_Path);
         raise;
   end Test_Copilot_Refreshes_Expired_Token_Then_Sends;

end LLM_GitHub_Copilot_Tests;
