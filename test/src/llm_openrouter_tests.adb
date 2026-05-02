with AUnit.Assertions;
with Ada.Calendar;
with Ada.Directories;
with Ada.Environment_Variables;
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
      Ada.Directories.Create_Path (Home & "/.pi/agent");
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
      Agent_Dir : constant String := Home & "/.pi/agent";
      Pi_Dir    : constant String := Home & "/.pi";
   begin
      Delete_If_Exists (Agent_Dir & "/openrouter_models_cache.json");
      Delete_If_Exists (Agent_Dir & "/openrouter_models_cache.json.tmp");

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

   procedure Write_Cache
      (Home       : String;
     Fetched_At : Long_Long_Integer;
     Data_Array : String)
   is
   begin
      Write_File
         (Home & "/.pi/agent/openrouter_models_cache.json",
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
         & "'https://github.com/gtnoble/pi_acme'" & ASCII.LF
         & "            assert self.headers['X-Title'] == 'pi_acme'"
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

      Home         : constant String := "/tmp/pi_acme_openrouter_test_home";
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

end LLM_OpenRouter_Tests;
