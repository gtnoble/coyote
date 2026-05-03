with AUnit.Assertions;
with Ada.Calendar;
with Ada.Containers;
with Ada.Containers.Vectors;
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
with Test_HTTP_Server;

package body LLM_Agent_Tests is

   use AUnit.Assertions;
   use type Ada.Containers.Count_Type;
   use type GNATCOLL.JSON.JSON_Value_Type;
   use type LLM.Events.Message_Update_Kind;
   use type LLM.Types.Content_Block_Kind;
   use type LLM.Types.Role;
   use type LLM.Types.Stop_Reason;

   type Recorded_Event_Kind is
     (Other_Event_Kind,
      Model_Select_Kind,
      Agent_Start_Kind,
      Message_Start_Kind,
      Message_Update_Kind,
      Message_End_Kind,
      Tool_Execution_Start_Kind,
      Tool_Execution_End_Kind,
      Agent_End_Kind,
      Session_Stats_Kind,
      Auto_Retry_Start_Kind,
      Auto_Retry_End_Kind,
      Auto_Compaction_Start_Kind,
      Auto_Compaction_End_Kind);

   package Recorded_Event_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Recorded_Event_Kind);

   No_Event_Index : constant Natural := Natural'Last;

   function To_Recorded_Event_Kind
     (E : LLM.Events.Agent_Event'Class) return Recorded_Event_Kind
   is
   begin
      if E in LLM.Events.Model_Select_Event then
         return Model_Select_Kind;
      elsif E in LLM.Events.Agent_Start_Event then
         return Agent_Start_Kind;
      elsif E in LLM.Events.Message_Start_Event then
         return Message_Start_Kind;
      elsif E in LLM.Events.Message_Update_Event then
         return Message_Update_Kind;
      elsif E in LLM.Events.Message_End_Event then
         return Message_End_Kind;
      elsif E in LLM.Events.Tool_Execution_Start_Event then
         return Tool_Execution_Start_Kind;
      elsif E in LLM.Events.Tool_Execution_End_Event then
         return Tool_Execution_End_Kind;
      elsif E in LLM.Events.Agent_End_Event then
         return Agent_End_Kind;
      elsif E in LLM.Events.Session_Stats_Event then
         return Session_Stats_Kind;
      elsif E in LLM.Events.Auto_Retry_Start_Event then
         return Auto_Retry_Start_Kind;
      elsif E in LLM.Events.Auto_Retry_End_Event then
         return Auto_Retry_End_Kind;
      elsif E in LLM.Events.Auto_Compaction_Start_Event then
         return Auto_Compaction_Start_Kind;
      elsif E in LLM.Events.Auto_Compaction_End_Event then
         return Auto_Compaction_End_Kind;
      else
         return Other_Event_Kind;
      end if;
   end To_Recorded_Event_Kind;

   function First_Event_Index
     (Events : Recorded_Event_Vectors.Vector;
      Kind   : Recorded_Event_Kind;
      Start  : Natural := 0) return Natural
   is
   begin
      if Events.Is_Empty then
         return No_Event_Index;
      end if;

      for Index in Events.First_Index .. Events.Last_Index loop
         if Index >= Start
           and then Events.Element (Index) = Kind
         then
            return Index;
         end if;
      end loop;

      return No_Event_Index;
   end First_Event_Index;

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

      Ada.Directories.Create_Path (Home & "/.coyote");
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
        (Home & "/.coyote/openrouter_models_cache.json",
         "{""fetched_at"":" & Long_Long_Image (Current_Unix_S)
         & ",""data"":" & Fixture_Data_Array & "}");
   end Write_OpenRouter_Cache;

   procedure Write_Settings_File
     (Home             : String;
      Default_Provider : String := "";
      Default_Model    : String := "";
      Default_Thinking : String := "")
   is
   begin
      Write_File
        (Home & "/.coyote/settings.json",
         "{""defaultProvider"":""" & Default_Provider
         & """,""defaultModel"":""" & Default_Model
         & """,""defaultThinkingLevel"":"""
         & Default_Thinking & """}");
   end Write_Settings_File;

   procedure Write_OpenRouter_Models_File
     (Home    : String;
      Api_Key : String)
   is
   begin
      Write_File
        (Home & "/.coyote/models.json",
         "{""providers"":{""openrouter"":{""apiKey"":"""
         & Api_Key & """}}}");
   end Write_OpenRouter_Models_File;

   procedure Write_Minimal_OpenRouter_Cache
     (Home     : String;
      Model_Id : String)
   is
   begin
      Write_File
        (Home & "/.coyote/openrouter_models_cache.json",
         "{""fetched_at"":9999999999,""data"":[{""id"":"""
         & Model_Id
         & """,""name"":"""
         & Model_Id
         & """,""context_length"":128000,"
         & """architecture"":{""input_modalities"":[""text""],"
         & """output_modalities"":[""text""]},"
         & """pricing"":{""prompt"":""0.000001"","
         & """completion"":""0.000002"","
         & """input_cache_read"":""0.0000005""},"
         & """top_provider"":{""context_length"":128000,"
         & """max_completion_tokens"":4096},"
         & """supported_parameters"":[""max_tokens"",""tools""]}]}"
        );
   end Write_Minimal_OpenRouter_Cache;

   --  Build a two-event SSE payload that streams Text then closes with stop.
   --  The payload matches the OpenAI chat-completions streaming format:
   --    data: <delta-content event>\n\n
   --    data: <finish event with usage>\n\n
   --    data: [DONE]\n\n
   function Text_SSE_Payload
     (Text              : String;
      Prompt_Tokens     : Natural := 8;
      Completion_Tokens : Natural := 3) return String
   is
   begin
      return
        "data: {""choices"":[{""delta"":{""content"":"
        & GNATCOLL.JSON.Write (GNATCOLL.JSON.Create (Text))
        & "},""finish_reason"":null}]}"
        & ASCII.LF & ASCII.LF
        & "data: {""choices"":[{""delta"":{},""finish_reason"":""stop""}],"
        & """usage"":{""prompt_tokens"":"
        & Natural_Image (Prompt_Tokens)
        & ",""completion_tokens"":"
        & Natural_Image (Completion_Tokens)
        & "}}"
        & ASCII.LF & ASCII.LF
        & "data: [DONE]"
        & ASCII.LF & ASCII.LF;
   end Text_SSE_Payload;

   --  Append a Content-Type: text/event-stream header to a response.
   procedure Add_SSE_Header (Res : in out Test_HTTP_Server.Response) is
   begin
      Res.Headers.Append
        ((Name  => To_Unbounded_String ("Content-Type"),
          Value => To_Unbounded_String ("text/event-stream")));
   end Add_SSE_Header;








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
      delay 2.0;
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

   procedure Append_Text_Message
     (Session_Id : String;
      Role       : LLM.Types.Role;
      Text       : String) is
      Content : LLM.Types.Content_Block_Vectors.Vector;
   begin
      Content.Append
        ((Kind => LLM.Types.Text_Block,
          Text => To_Unbounded_String (Text)));

      LLM.Session_Store.Append_Message
        (Session_Id,
         (Role      => Role,
          Content   => Content,
          Tok_Usage => (others => 0),
          Stop      =>
            (if Role = LLM.Types.Assistant
             then LLM.Types.Stop
             else LLM.Types.Unknown_Stop),
          Timestamp => Null_Unbounded_String));
   end Append_Text_Message;

   procedure Seed_Compaction_History
     (S : in out LLM.Agent.Session)
   is
      Session_UUID : constant String := LLM.Agent.Session_Id (S);
      Large_User_1 : constant String := (1 .. 50_000 => 'u');
      Large_Asst_1 : constant String := (1 .. 50_000 => 'a');
      Large_User_2 : constant String := (1 .. 50_000 => 'v');
      Large_Asst_2 : constant String := (1 .. 50_000 => 'b');
   begin
      Append_Text_Message (Session_UUID, LLM.Types.User, Large_User_1);
      Append_Text_Message (Session_UUID, LLM.Types.Assistant, Large_Asst_1);
      Append_Text_Message (Session_UUID, LLM.Types.User, Large_User_2);
      Append_Text_Message (Session_UUID, LLM.Types.Assistant, Large_Asst_2);
      LLM.Agent.Switch_Session (S, Session_UUID);
   end Seed_Compaction_History;



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
        & "            msgs = [m for m in body['messages']"
        & " if m.get('role') != 'system']" & ASCII.LF
        & "            assert body['model'] == 'openai/gpt-4o-mini'"
        & ASCII.LF
        & "            if H.count == 1:" & ASCII.LF
        & "                assert len(msgs) == 1" & ASCII.LF
        & "                assert msgs[0]['content'] == "
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
        & "                assert len(msgs) == 3" & ASCII.LF
        & "                assert msgs[1]['tool_calls'][0]['id']"
        & " == 'call_1'" & ASCII.LF
        & "                assert msgs[2]['role'] == 'tool'"
        & ASCII.LF
        & "                assert 'tool-ok' in msgs[2]['content']"
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
        & "            msgs = [m for m in body['messages']"
        & " if m.get('role') != 'system']" & ASCII.LF
        & "            assert body['model'] == 'openai/gpt-4o-mini'"
        & ASCII.LF
        & "            assert len(msgs) == 1" & ASCII.LF
        & "            assert msgs[0]['role'] == 'user'"
        & ASCII.LF
        & "            assert msgs[0]['content'] == "
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
        & "            msgs = [m for m in body['messages']"
        & " if m.get('role') != 'system']" & ASCII.LF
        & "            assert body['model'] == 'openai/gpt-4o-mini'"
        & ASCII.LF
        & "            if H.count == 1:" & ASCII.LF
        & "                assert len(msgs) == 1" & ASCII.LF
        & "                assert msgs[0]['content'] == "
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
        & "                assert len(msgs) == 4" & ASCII.LF
        & "                assert msgs[1]['role'] == 'assistant'"
        & ASCII.LF
        & "                assert len(msgs[1]['tool_calls']) == 2"
        & ASCII.LF
        & "                assert msgs[2]['role'] == 'tool'"
        & ASCII.LF
        & "                assert msgs[2]['tool_call_id'] =="
        & " 'call_1'" & ASCII.LF
        & "                assert 'first-ok' in msgs[2]['content']"
        & ASCII.LF
        & "                assert msgs[3]['role'] == 'tool'"
        & ASCII.LF
        & "                assert msgs[3]['tool_call_id'] =="
        & " 'call_2'" & ASCII.LF
        & "                assert 'second-ok' in "
        & "msgs[3]['content']" & ASCII.LF
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
        & "            msgs = [m for m in body['messages']"
        & " if m.get('role') != 'system']" & ASCII.LF
        & "            assert body['model'] == 'openai/gpt-4o-mini'"
        & ASCII.LF
        & "            if H.count == 1:" & ASCII.LF
        & "                assert len(msgs) == 1" & ASCII.LF
        & "                assert msgs[0]['content'] == "
        & "'Use failing tool'" & ASCII.LF
        & "                events = [" & ASCII.LF
        & "                    {'choices': [{'delta': {'tool_calls': ["
        & "{'index': 0, 'id': 'call_1', 'type': 'function',"
        & " 'function': {'name': 'read', 'arguments': "
        & "'{""path"":""/tmp/coyote_missing_tool_input_"
        & Natural_Image (Port)
        & ".txt""}'}}]},"
        & " 'finish_reason': None}]}," & ASCII.LF
        & "                    {'choices': [{'delta': {}, 'finish_reason':"
        & " 'tool_calls'}], 'usage': {'prompt_tokens': 12,"
        & " 'completion_tokens': 6}}]" & ASCII.LF
        & "            else:" & ASCII.LF
        & "                assert len(msgs) == 3" & ASCII.LF
        & "                assert msgs[2]['role'] == 'tool'"
        & ASCII.LF
        & "                assert msgs[2]['tool_call_id'] =="
        & " 'call_1'" & ASCII.LF
        & "                assert 'file not found' in"
        & " msgs[2]['content']" & ASCII.LF
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

   function Prompt_Then_Compaction_Server_Script
     (Port              : Positive;
      Reply_Text        : String;
      Summary_Text      : String;
      Prompt_Tokens     : Natural;
      Completion_Tokens : Natural) return String
   is
      Encoded_Summary : constant String :=
        GNATCOLL.JSON.Write (GNATCOLL.JSON.Create (Summary_Text));
   begin
      return
        "import http.server, json, time" & ASCII.LF
        & "class S(http.server.HTTPServer):" & ASCII.LF
        & "    allow_reuse_address = True" & ASCII.LF
        & "def make_payload(text, prompt_tokens, completion_tokens):"
        & ASCII.LF
        & "    events = [" & ASCII.LF
        & "        {'choices': [{'delta': {'content': text},"
        & " 'finish_reason': None}]}," & ASCII.LF
        & "        {'choices': [{'delta': {}, 'finish_reason': 'stop'}],"
        & " 'usage': {'prompt_tokens': prompt_tokens,"
        & " 'completion_tokens': completion_tokens}}]"
        & ASCII.LF
        & "    payload = ''.join(" & ASCII.LF
        & "        'data: ' + json.dumps(event) + '\n\n'"
        & ASCII.LF
        & "        for event in events).encode()" & ASCII.LF
        & "    return payload + b'data: [DONE]\n\n'" & ASCII.LF
        & "class H(http.server.BaseHTTPRequestHandler):" & ASCII.LF
        & "    count = 0" & ASCII.LF
        & "    def do_POST(self):" & ASCII.LF
        & "        try:" & ASCII.LF
        & "            H.count += 1" & ASCII.LF
        & "            assert self.path == '/api/v1/chat/completions'"
        & ASCII.LF
        & "            n = int(self.headers.get('Content-Length', '0'))"
        & ASCII.LF
        & "            json.loads(self.rfile.read(n))" & ASCII.LF
        & "            if H.count == 1:" & ASCII.LF
        & "                payload = make_payload('" & Reply_Text & "', "
        & Natural_Image (Prompt_Tokens) & ", "
        & Natural_Image (Completion_Tokens) & ")" & ASCII.LF
        & "            else:" & ASCII.LF
        & "                assert H.count == 2" & ASCII.LF
        & "                payload = make_payload(" & Encoded_Summary
        & ", 8, 3)" & ASCII.LF
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
        & "s.timeout = 0.25" & ASCII.LF
        & "deadline = time.time() + 10.0" & ASCII.LF
        & "while H.count < 2 and time.time() < deadline:" & ASCII.LF
        & "    s.handle_request()" & ASCII.LF
        & "s.server_close()" & ASCII.LF;
   end Prompt_Then_Compaction_Server_Script;

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
        & "            msgs = [m for m in body['messages']"
        & " if m.get('role') != 'system']" & ASCII.LF
        & "            assert body['model'] == 'openai/gpt-4o-mini'"
        & ASCII.LF
        & "            if H.count == 1:" & ASCII.LF
        & "                assert len(msgs) == 1" & ASCII.LF
        & "                assert msgs[0]['content'] == "
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
        & "                assert len(msgs) == 3" & ASCII.LF
        & "                assert msgs[1]['role'] == 'assistant'"
        & ASCII.LF
        & "                assert msgs[1]['tool_calls'][0]['id']"
        & " == 'call_1'" & ASCII.LF
        & "                assert msgs[2]['role'] == 'tool'"
        & ASCII.LF
        & "                assert 'slow-ok' in msgs[2]['content']"
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
        & "            msgs = [m for m in body['messages']"
        & " if m.get('role') != 'system']" & ASCII.LF
        & "            assert len(msgs) == 3" & ASCII.LF
        & "            assert msgs[0]['role'] == 'user'"
        & ASCII.LF
        & "            assert msgs[0]['content'] == '"
        & Expect_First & "'" & ASCII.LF
        & "            assert msgs[1]['role'] == 'assistant'"
        & ASCII.LF
        & "            assert msgs[1]['content'] == '"
        & Expect_Response & "'" & ASCII.LF
        & "            assert msgs[2]['role'] == 'user'"
        & ASCII.LF
        & "            assert msgs[2]['content'] == "
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

      Home           : constant String := "/tmp/coyote_llm_agent_test_1";
      Port           : constant Positive := 18_781;
      Agent_Session  : LLM.Agent.Session;
      Messages       : LLM.Types.Message_Vectors.Vector;
      Server_Stopped : Boolean := False;
      Home_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home       : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key        : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url        : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure Ignore_Event (E : LLM.Events.Agent_Event'Class) is
         pragma Unreferenced (E);
      begin
         null;
      end Ignore_Event;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 200;
         Add_SSE_Header (Res);
         Append (Res.Body_Data, Text_SSE_Payload ("Hello", 10, 5));
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);

      Srv.Bind (Port);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Say hello",
         On_Event => Ignore_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

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

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Single_Turn_Prompt;

   procedure Test_Tool_Call_Loop (T : in out Test) is
      pragma Unreferenced (T);

      Home          : constant String := "/tmp/coyote_llm_agent_test_2";
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
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url       : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

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
        ("COYOTE_OPENROUTER_BASE_URL",
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

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Stop_Server (Handle);
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Tool_Call_Loop;

   procedure Test_Two_Tool_Call_Loop (T : in out Test) is
      pragma Unreferenced (T);

      Home          : constant String := "/tmp/coyote_llm_agent_test_7";
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
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url       : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

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
        ("COYOTE_OPENROUTER_BASE_URL",
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

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Stop_Server (Handle);
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Two_Tool_Call_Loop;

   procedure Test_Tool_Execution_Failure (T : in out Test) is
      pragma Unreferenced (T);

      Home               : constant String := "/tmp/coyote_llm_agent_test_8";
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
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url            : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

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
        ("COYOTE_OPENROUTER_BASE_URL",
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

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Stop_Server (Handle);
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Tool_Execution_Failure;

   procedure Test_Switch_Session_Loads_History (T : in out Test) is
      pragma Unreferenced (T);

      Home          : constant String := "/tmp/coyote_llm_agent_test_9";
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

      Home          : constant String := "/tmp/coyote_llm_agent_test_3";
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
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url       : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

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
        ("COYOTE_OPENROUTER_BASE_URL",
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

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Stop_Server (Handle);
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Abort_Request;

   procedure Test_Abort_Batched_Tools_Keep_History_Valid
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home           : constant String := "/tmp/coyote_llm_agent_test_5";
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
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url        : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

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
        ("COYOTE_OPENROUTER_BASE_URL",
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
        ("COYOTE_OPENROUTER_BASE_URL",
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

            Request    : constant GNATCOLL.JSON.JSON_Value := Parsed.Value;
            Msgs       : constant GNATCOLL.JSON.JSON_Array :=
              Request.Get ("messages").Get;
            Sys_Offset : constant Natural :=
              (if GNATCOLL.JSON.Length (Msgs) > 0
                 and then Json_String
                   (GNATCOLL.JSON.Get (Msgs, 1), "role") = "system"
               then 1 else 0);
            Calls      : constant GNATCOLL.JSON.JSON_Array :=
              GNATCOLL.JSON.Get
                (Msgs, 2 + Sys_Offset).Get ("tool_calls").Get;
         begin
            Assert
              (GNATCOLL.JSON.Length (Msgs) = 5 + Sys_Offset,
               "Resume request should include the aborted tool batch"
               & " in memory");
            Assert
              (Json_String
                 (GNATCOLL.JSON.Get (Msgs, 1 + Sys_Offset), "role")
                 = "user",
               "First request message should be the original user prompt");
            Assert
              (Json_String
                 (GNATCOLL.JSON.Get (Msgs, 1 + Sys_Offset), "content")
                 = "Use two tools",
               "Original user prompt should remain in history");
            Assert
              (Json_String
                 (GNATCOLL.JSON.Get (Msgs, 2 + Sys_Offset), "role")
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
              (Json_String
                 (GNATCOLL.JSON.Get (Msgs, 3 + Sys_Offset), "role")
                 = "tool",
               "First tool result should follow the assistant tool call");
            Assert
              (Json_String
                 (GNATCOLL.JSON.Get (Msgs, 3 + Sys_Offset), "tool_call_id")
                 = "call_1",
               "First tool result should match call_1");
            Assert
              (Ada.Strings.Fixed.Index
                 (Json_String
                    (GNATCOLL.JSON.Get (Msgs, 3 + Sys_Offset), "content"),
                  "first-ok") > 0,
               "First tool result should contain the real command output");
            Assert
              (Json_String
                 (GNATCOLL.JSON.Get (Msgs, 4 + Sys_Offset), "role")
                 = "tool",
               "Second tool result should be present after abort");
            Assert
              (Json_String
                 (GNATCOLL.JSON.Get
                    (Msgs, 4 + Sys_Offset), "tool_call_id")
                 = "call_2",
               "Second tool result should match call_2");
            Assert
              (Json_String
                 (GNATCOLL.JSON.Get (Msgs, 5 + Sys_Offset), "role")
                 = "user",
               "Final message should be the after-abort user prompt");
            Assert
              (Json_String
                 (GNATCOLL.JSON.Get (Msgs, 5 + Sys_Offset), "content")
                 = "After abort",
               "After-abort user prompt should be preserved in history");
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

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Stop_Server (Abort_Handle);
         Stop_Server (Resume_Handle);
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Abort_Batched_Tools_Keep_History_Valid;

   procedure Test_Session_File_Written_Only_After_Turn_End
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home          : constant String := "/tmp/coyote_llm_agent_test_6";
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
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url       : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

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
        ("COYOTE_OPENROUTER_BASE_URL",
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

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Stop_Server (Handle);
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Session_File_Written_Only_After_Turn_End;

   procedure Test_Session_Resume (T : in out Test) is
      pragma Unreferenced (T);

      Home                 : constant String :=
        "/tmp/coyote_llm_agent_test_4";
      First_Port           : constant Positive := 18_784;
      Second_Port          : constant Positive := 18_785;
      Second_Handle        : Process_Handle := Invalid_Handle;
      First_Session        : LLM.Agent.Session;
      Resume_Session       : LLM.Agent.Session;
      Session_UUID         : Unbounded_String;
      Messages             : LLM.Types.Message_Vectors.Vector;
      First_Server_Stopped : Boolean := False;
      Home_Was_Set         : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home             : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set          : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key              : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set          : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url              : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure Ignore_Event (E : LLM.Events.Agent_Event'Class) is
         pragma Unreferenced (E);
      begin
         null;
      end Ignore_Event;

      procedure Handle_First_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 200;
         Add_SSE_Header (Res);
         Append (Res.Body_Data, Text_SSE_Payload ("Hello", 10, 5));
      end Handle_First_Request;

      Srv_First : Test_HTTP_Server.Server
        (Handle_First_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (First_Port) & "/api/v1");

      LLM.Agent.Create
        (S          => First_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);

      Srv_First.Bind (First_Port);
      LLM.Agent.Run_Prompt
        (S        => First_Session,
         Prompt   => "Say hello",
         On_Event => Ignore_Event'Access);
      Srv_First.Stop;
      First_Server_Stopped := True;

      Session_UUID :=
        To_Unbounded_String (LLM.Agent.Session_Id (First_Session));

      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
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

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not First_Server_Stopped then
            begin
               Srv_First.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Stop_Server (Second_Handle);
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Session_Resume;

   procedure Test_Create_Without_Model_Spec_Uses_Settings_Default
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home           : constant String := "/tmp/coyote_llm_agent_test_10";
      Port           : constant Positive := 18_794;
      Agent_Session  : LLM.Agent.Session;
      Saw_Model      : Boolean := False;
      Selected_Prov  : Unbounded_String := Null_Unbounded_String;
      Selected_Model : Unbounded_String := Null_Unbounded_String;
      Server_Stopped : Boolean := False;
      Home_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home       : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key        : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url        : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         if E in LLM.Events.Model_Select_Event then
            declare
               Event : constant LLM.Events.Model_Select_Event :=
                 LLM.Events.Model_Select_Event (E);
            begin
               Saw_Model := True;
               Selected_Prov := Event.Provider;
               Selected_Model := Event.Model_Id;
            end;
         end if;
      end On_Event;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 200;
         Add_SSE_Header (Res);
         Append (Res.Body_Data, Text_SSE_Payload ("default reply", 8, 3));
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_Settings_File
        (Home             => Home,
         Default_Provider => "openrouter",
         Default_Model    => "test/default-model");
      Write_OpenRouter_Models_File (Home, "settings-key");
      Write_Minimal_OpenRouter_Cache
        (Home     => Home,
         Model_Id => "test/default-model");

      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Clear ("OPENROUTER_API_KEY");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "",
         No_Tools   => True);

      Assert
        (LLM.Agent.Current_Model_Spec (Agent_Session)
           = "openrouter/test/default-model",
         "Create should use the settings.json default model");

      Srv.Bind (Port);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Use the default model",
         On_Event => On_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Assert (Saw_Model, "Model_Select_Event should be emitted");
      Assert
        (To_String (Selected_Prov) = "openrouter",
         "Default provider should resolve to openrouter");
      Assert
        (To_String (Selected_Model) = "test/default-model",
         "Default model id should come from settings.json");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Create_Without_Model_Spec_Uses_Settings_Default;

   procedure Test_Multi_Turn_Same_Session_Carries_History
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home           : constant String := "/tmp/coyote_llm_agent_test_11";
      Port           : constant Positive := 18_795;
      Agent_Session  : LLM.Agent.Session;
      Server_Stopped : Boolean := False;
      Request_Count  : Natural := 0;
      Home_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home       : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key        : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url        : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure Ignore_Event (E : LLM.Events.Agent_Event'Class) is
         pragma Unreferenced (E);
      begin
         null;
      end Ignore_Event;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Request_Count := Request_Count + 1;
         Res.Status := 200;
         Add_SSE_Header (Res);
         if Request_Count = 1 then
            Append (Res.Body_Data,
                    Text_SSE_Payload ("turn one reply", 8, 3));
         else
            Append (Res.Body_Data,
                    Text_SSE_Payload ("turn two reply", 8, 3));
         end if;
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);

      Srv.Bind (Port);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "first question",
         On_Event => Ignore_Event'Access);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "second question",
         On_Event => Ignore_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Assert
        (LLM.Agent.Testing.History_Length (Agent_Session) >= 4,
         "Same session should retain both user and assistant turns");
      Assert
        (Assistant_Text
           (LLM.Agent.Testing.History_Element (Agent_Session, 1))
         = "turn one reply",
         "First assistant reply should remain in the in-memory history");
      Assert
        (Assistant_Text
           (LLM.Agent.Testing.History_Element (Agent_Session, 3))
         = "turn two reply",
         "Second assistant reply should be appended to the same session");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Multi_Turn_Same_Session_Carries_History;

   procedure Test_New_Session_Clears_History_And_Uses_Fresh_File
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home                  : constant String :=
        "/tmp/coyote_llm_agent_test_12";
      First_Port            : constant Positive := 18_796;
      Second_Port           : constant Positive := 18_797;
      Agent_Session         : LLM.Agent.Session;
      Original_Id           : Unbounded_String := Null_Unbounded_String;
      Original_Path         : Unbounded_String := Null_Unbounded_String;
      Fresh_Path            : Unbounded_String := Null_Unbounded_String;
      First_Server_Stopped  : Boolean := False;
      Second_Server_Stopped : Boolean := False;
      Home_Was_Set          : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home              : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set           : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key               : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set           : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url               : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure Ignore_Event (E : LLM.Events.Agent_Event'Class) is
         pragma Unreferenced (E);
      begin
         null;
      end Ignore_Event;

      procedure Handle_First_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 200;
         Add_SSE_Header (Res);
         Append (Res.Body_Data, Text_SSE_Payload ("old reply", 8, 3));
      end Handle_First_Request;

      Srv_First : Test_HTTP_Server.Server
        (Handle_First_Request'Unrestricted_Access);

      procedure Handle_Second_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 200;
         Add_SSE_Header (Res);
         Append (Res.Body_Data, Text_SSE_Payload ("fresh reply", 8, 3));
      end Handle_Second_Request;

      Srv_Second : Test_HTTP_Server.Server
        (Handle_Second_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (First_Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);

      Srv_First.Bind (First_Port);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "old prompt",
         On_Event => Ignore_Event'Access);

      Srv_First.Stop;
      First_Server_Stopped := True;

      Original_Id :=
        To_Unbounded_String (LLM.Agent.Session_Id (Agent_Session));
      Original_Path := To_Unbounded_String
        (LLM.Session_Store.Session_File_Path (To_String (Original_Id)));

      LLM.Agent.New_Session (Agent_Session);

      Fresh_Path := To_Unbounded_String
        (LLM.Session_Store.Session_File_Path
           (LLM.Agent.Session_Id (Agent_Session)));

      Assert
        (LLM.Agent.Testing.History_Length (Agent_Session) = 0,
         "New_Session should clear the in-memory transcript");
      Assert
        (LLM.Agent.Session_Id (Agent_Session) /= To_String (Original_Id),
         "New_Session should allocate a fresh session UUID");
      Assert
        (Ada.Directories.Exists (To_String (Original_Path)),
         "New_Session should leave the old session file on disk");
      Assert
        (To_String (Fresh_Path)'Length > 0
           and then Ada.Directories.Exists (To_String (Fresh_Path)),
         "New_Session should create a fresh session file immediately");

      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Second_Port) & "/api/v1");

      Srv_Second.Bind (Second_Port);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "fresh prompt",
         On_Event => Ignore_Event'Access);

      Srv_Second.Stop;
      Second_Server_Stopped := True;

      Assert
        (LLM.Agent.Testing.History_Length (Agent_Session) = 2,
         "Fresh session history should contain only the second turn");
      Assert
        (Assistant_Text
           (LLM.Agent.Testing.History_Element (Agent_Session, 1))
         = "fresh reply",
         "Fresh session should record only the new assistant reply");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not First_Server_Stopped then
            begin
               Srv_First.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         if not Second_Server_Stopped then
            begin
               Srv_Second.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_New_Session_Clears_History_And_Uses_Fresh_File;

   procedure Test_Event_Sequence_Agent_Start_Through_Session_Stats
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home               : constant String :=
        "/tmp/coyote_llm_agent_test_13";
      Port               : constant Positive := 18_798;
      Agent_Session      : LLM.Agent.Session;
      Events             : Recorded_Event_Vectors.Vector;
      Model_Select_Pos   : Natural;
      Agent_Start_Pos    : Natural;
      Message_Update_Pos : Natural;
      Message_End_Pos    : Natural;
      Agent_End_Pos      : Natural;
      Session_Stats_Pos  : Natural;
      Server_Stopped     : Boolean := False;
      Home_Was_Set       : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home           : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set        : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key            : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set        : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url            : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         Events.Append (To_Recorded_Event_Kind (E));
      end On_Event;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 200;
         Add_SSE_Header (Res);
         Append (Res.Body_Data, Text_SSE_Payload ("event reply", 8, 3));
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);

      Srv.Bind (Port);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Show the event sequence",
         On_Event => On_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Model_Select_Pos := First_Event_Index (Events, Model_Select_Kind);
      Assert
        (Model_Select_Pos /= No_Event_Index,
         "Model_Select_Event should be present");

      Agent_Start_Pos :=
        First_Event_Index (Events, Agent_Start_Kind, Model_Select_Pos + 1);
      Assert
        (Agent_Start_Pos /= No_Event_Index,
         "Agent_Start_Event should occur after model selection");

      Message_Update_Pos :=
        First_Event_Index (Events, Message_Update_Kind, Agent_Start_Pos + 1);
      Assert
        (Message_Update_Pos /= No_Event_Index,
         "At least one Message_Update_Event should be emitted");

      Message_End_Pos :=
        First_Event_Index (Events, Message_End_Kind, Message_Update_Pos + 1);
      Assert
        (Message_End_Pos /= No_Event_Index,
         "Message_End_Event should follow the message updates");

      Agent_End_Pos :=
        First_Event_Index (Events, Agent_End_Kind, Message_End_Pos + 1);
      Assert
        (Agent_End_Pos /= No_Event_Index,
         "Agent_End_Event should be emitted after Message_End_Event");

      Session_Stats_Pos :=
        First_Event_Index (Events, Session_Stats_Kind, Agent_End_Pos + 1);
      Assert
        (Session_Stats_Pos /= No_Event_Index,
         "Session_Stats_Event should follow Agent_End_Event");

      Assert
        (Agent_Start_Pos < Agent_End_Pos,
         "Agent_Start_Event should precede Agent_End_Event");
      Assert
        (Message_End_Pos < Agent_End_Pos,
         "Message_End_Event should precede Agent_End_Event");
      Assert
        (Agent_End_Pos < Session_Stats_Pos,
         "Session_Stats_Event should follow Agent_End_Event");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Event_Sequence_Agent_Start_Through_Session_Stats;

   procedure Test_Unknown_Tool_Becomes_Error_And_Agent_Continues
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home              : constant String := "/tmp/coyote_llm_agent_test_14";
      Port              : constant Positive := 18_799;
      Agent_Session     : LLM.Agent.Session;
      Saw_Tool_Start    : Boolean := False;
      Saw_Tool_End      : Boolean := False;
      Saw_Agent_End     : Boolean := False;
      Tool_End_Error    : Boolean := False;
      End_Was_Aborted   : Boolean := True;
      Tool_Name         : Unbounded_String := Null_Unbounded_String;
      Session_Text      : Unbounded_String := Null_Unbounded_String;
      Server_Stopped    : Boolean := False;
      Request_Count     : Natural := 0;
      Home_Was_Set      : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home          : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set       : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key           : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set       : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url           : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         if E in LLM.Events.Tool_Execution_Start_Event then
            declare
               Event : constant LLM.Events.Tool_Execution_Start_Event :=
                 LLM.Events.Tool_Execution_Start_Event (E);
            begin
               Saw_Tool_Start := True;
               Tool_Name := Event.Tool_Name;
            end;
         elsif E in LLM.Events.Tool_Execution_End_Event then
            declare
               Event : constant LLM.Events.Tool_Execution_End_Event :=
                 LLM.Events.Tool_Execution_End_Event (E);
            begin
               Saw_Tool_End := True;
               Tool_End_Error := Event.Is_Error;
            end;
         elsif E in LLM.Events.Agent_End_Event then
            Saw_Agent_End := True;
            End_Was_Aborted := LLM.Events.Agent_End_Event (E).Was_Aborted;
         end if;
      end On_Event;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
         Tool_SSE : constant String :=
           "data: {""choices"":[{""delta"":{""tool_calls"":[{""index"":0,"
           & """id"":""call_1"",""type"":""function"","
           & """function"":{""name"":""nonexistent_tool_xyz"","
           & """arguments"":""{}""}}"
           & "]},"
           & """finish_reason"":null}]}"
           & ASCII.LF & ASCII.LF
           & "data: {""choices"":[{""delta"":{},"
           & """finish_reason"":""tool_calls""}],"
           & """usage"":{""prompt_tokens"":11,""completion_tokens"":5}}"
           & ASCII.LF & ASCII.LF
           & "data: [DONE]"
           & ASCII.LF & ASCII.LF;
      begin
         Request_Count := Request_Count + 1;
         Res.Status := 200;
         Add_SSE_Header (Res);
         if Request_Count = 1 then
            Append (Res.Body_Data, Tool_SSE);
         else
            Append (Res.Body_Data, Text_SSE_Payload ("done", 15, 3));
         end if;
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => False);

      Srv.Bind (Port);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Call the unknown tool",
         On_Event => On_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Session_Text := To_Unbounded_String
        (Read_File
           (LLM.Session_Store.Session_File_Path
              (LLM.Agent.Session_Id (Agent_Session))));

      Assert
        (Saw_Tool_Start,
         "Tool_Execution_Start_Event should be emitted for the unknown tool");
      Assert
        (To_String (Tool_Name) = "nonexistent_tool_xyz",
         "Tool start event should preserve the requested tool name");
      Assert
        (Saw_Tool_End,
         "Tool_Execution_End_Event should be emitted for the unknown tool");
      Assert
        (Tool_End_Error,
         "Unknown tools should become tool errors rather than hard failures");
      Assert
        (Saw_Agent_End and then not End_Was_Aborted,
         "Agent should continue after an unknown tool and end normally");
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Session_Text), """role"":""toolResult""") > 0,
         "Session file should contain a persisted tool-result record");
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Session_Text), """isError"":true") > 0,
         "Persisted tool-result record should preserve Is_Error=True");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Unknown_Tool_Becomes_Error_And_Agent_Continues;

   procedure Test_Auto_Retry_On_HTTP_500_Then_Success
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home            : constant String := "/tmp/coyote_llm_agent_test_15";
      Port            : constant Positive := 18_800;
      Agent_Session   : LLM.Agent.Session;
      Saw_Retry       : Boolean := False;
      Saw_Text_Delta  : Boolean := False;
      End_Was_Aborted : Boolean := True;
      Text_Result     : Unbounded_String := Null_Unbounded_String;
      Server_Stopped  : Boolean := False;
      Request_Count   : Natural := 0;
      Home_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home        : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set     : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key         : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set     : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url         : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         if E in LLM.Events.Auto_Retry_Start_Event then
            Saw_Retry := True;
         elsif E in LLM.Events.Message_Update_Event then
            declare
               Event : constant LLM.Events.Message_Update_Event :=
                 LLM.Events.Message_Update_Event (E);
            begin
               if Event.Kind = LLM.Events.Text_Delta then
                  Saw_Text_Delta := True;
                  Append (Text_Result, To_String (Event.Delta_Text));
               end if;
            end;
         elsif E in LLM.Events.Agent_End_Event then
            End_Was_Aborted := LLM.Events.Agent_End_Event (E).Was_Aborted;
         end if;
      end On_Event;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Request_Count := Request_Count + 1;
         if Request_Count = 1 then
            Res.Status := 500;
            Res.Headers.Append
              ((Name  => To_Unbounded_String ("Content-Type"),
                Value => To_Unbounded_String ("application/json")));
            Append (Res.Body_Data, "{""error"":""server error""}");
         else
            Res.Status := 200;
            Add_SSE_Header (Res);
            Append (Res.Body_Data,
                    Text_SSE_Payload ("retried reply", 8, 3));
         end if;
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);

      Srv.Bind (Port);

      --  The current implementation uses a fixed two-second first retry.
      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Retry this prompt",
         On_Event => On_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Assert (Saw_Retry, "HTTP 500 should trigger Auto_Retry_Start_Event");
      Assert
        (not End_Was_Aborted,
         "Successful retry should still end the turn normally");
      Assert
        (Saw_Text_Delta and then To_String (Text_Result) = "retried reply",
         "Retry success should still stream the final assistant text");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Auto_Retry_On_HTTP_500_Then_Success;

   procedure Test_Is_Context_Overflow_Error_Detects_Known_Phrases
     (T : in out Test)
   is
      pragma Unreferenced (T);

      type Phrase_Array is array (Positive range <>) of Unbounded_String;

      Home         : constant String := "/tmp/coyote_llm_agent_test_24";
      Summary_Text : constant String :=
        "## Goal" & ASCII.LF & "overflow detection";
      Reply_Text   : constant String := "overflow detection reply";
      Exact_Phrases : constant Phrase_Array :=
        (To_Unbounded_String ("prompt is too long"),
         To_Unbounded_String ("context_length_exceeded"),
         To_Unbounded_String ("maximum context length"),
         To_Unbounded_String ("too many tokens"),
         To_Unbounded_String ("reduce the length of the messages"));
      Mixed_Phrases : constant Phrase_Array :=
        (To_Unbounded_String ("Prompt Is Too Long"),
         To_Unbounded_String ("Context_Length_Exceeded"),
         To_Unbounded_String ("Maximum Context Length"),
         To_Unbounded_String ("Too Many Tokens"),
         To_Unbounded_String ("Reduce The Length Of The Messages"));
      Next_Port    : Positive := 18_810;
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set  : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key      : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set  : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url      : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure Run_Case
        (Port            : Positive;
         Error_Text      : String;
         Expect_Overflow : Boolean)
      is
         Agent_Session        : LLM.Agent.Session;
         Saw_Compaction_Start : Boolean := False;
         Text_Result          : Unbounded_String := Null_Unbounded_String;
         Raised               : Boolean := False;
         Server_Stopped       : Boolean := False;
         Request_Count        : Natural := 0;

         procedure On_Event (E : LLM.Events.Agent_Event'Class) is
         begin
            if E in LLM.Events.Auto_Compaction_Start_Event then
               Saw_Compaction_Start := True;
            elsif E in LLM.Events.Message_Update_Event then
               declare
                  Event : constant LLM.Events.Message_Update_Event :=
                    LLM.Events.Message_Update_Event (E);
               begin
                  if Event.Kind = LLM.Events.Text_Delta then
                     Append (Text_Result, To_String (Event.Delta_Text));
                  end if;
               end;
            end if;
         end On_Event;

         procedure Handle_Request
           (Req :     Test_HTTP_Server.Request;
            Res : out Test_HTTP_Server.Response)
         is
            pragma Unreferenced (Req);
         begin
            Request_Count := Request_Count + 1;
            if Expect_Overflow then
               case Request_Count is
                  when 1 =>
                     Res.Status := 400;
                     Append (Res.Body_Data, Error_Text);
                  when 2 =>
                     Res.Status := 200;
                     Add_SSE_Header (Res);
                     Append (Res.Body_Data,
                             Text_SSE_Payload (Summary_Text, 8, 3));
                  when others =>
                     Res.Status := 200;
                     Add_SSE_Header (Res);
                     Append (Res.Body_Data,
                             Text_SSE_Payload (Reply_Text, 8, 3));
               end case;
            else
               Res.Status := 400;
               Append (Res.Body_Data, Error_Text);
            end if;
         end Handle_Request;

         Srv : Test_HTTP_Server.Server
           (Handle_Request'Unrestricted_Access);
      begin
         Ada.Environment_Variables.Set
           ("COYOTE_OPENROUTER_BASE_URL",
            "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

         LLM.Agent.Create
           (S          => Agent_Session,
            Model_Spec => "openrouter/openai/gpt-4o-mini",
            No_Tools   => True);
         Seed_Compaction_History (Agent_Session);

         Srv.Bind (Port);

         begin
            LLM.Agent.Run_Prompt
              (S        => Agent_Session,
               Prompt   => "Detect overflow text",
               On_Event => On_Event'Access);
         exception
            when others =>
               Raised := True;
         end;

         Srv.Stop;
         Server_Stopped := True;

         if Expect_Overflow then
            Assert (not Raised, "Overflow case should recover and return");
            Assert
              (Saw_Compaction_Start,
               "Known overflow phrase should trigger compaction");
            Assert
              (To_String (Text_Result) = Reply_Text,
               "Recovered overflow case should still return the reply");
         else
            Assert (Raised, "Non-overflow error should still raise");
            Assert
              (not Saw_Compaction_Start,
               "Non-overflow error should not trigger compaction");
         end if;
      exception
         when others =>
            if not Server_Stopped then
               begin
                  Srv.Stop;
               exception
                  when Tasking_Error => null;
               end;
            end if;
            raise;
      end Run_Case;
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");

      for Phrase of Exact_Phrases loop
         Run_Case
           (Port            => Next_Port,
            Error_Text      => To_String (Phrase),
            Expect_Overflow => True);
         Next_Port := Next_Port + 1;
      end loop;

      for Phrase of Mixed_Phrases loop
         Run_Case
           (Port            => Next_Port,
            Error_Text      => To_String (Phrase),
            Expect_Overflow => True);
         Next_Port := Next_Port + 1;
      end loop;

      Run_Case
        (Port            => Next_Port,
         Error_Text      => "validation failed",
         Expect_Overflow => False);

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Is_Context_Overflow_Error_Detects_Known_Phrases;

   procedure Test_Overflow_Triggers_Compact_And_Retry
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home                  : constant String :=
        "/tmp/coyote_llm_agent_test_25";
      Port                  : constant Positive := 18_821;
      Agent_Session         : LLM.Agent.Session;
      Saw_Compaction_Start  : Boolean := False;
      Compaction_Reason     : Unbounded_String := Null_Unbounded_String;
      Final_Text            : Unbounded_String := Null_Unbounded_String;
      Final_Stop            : LLM.Types.Stop_Reason := LLM.Types.Unknown_Stop;
      End_Was_Aborted       : Boolean := True;
      Summary_Text          : constant String :=
        "## Goal" & ASCII.LF & "overflow retry";
      Reply_Text            : constant String := "overflow recovered";
      Server_Stopped        : Boolean := False;
      Request_Count         : Natural := 0;
      Home_Was_Set          : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home              : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set           : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key               : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set           : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url               : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         if E in LLM.Events.Auto_Compaction_Start_Event then
            Saw_Compaction_Start := True;
            Compaction_Reason :=
              LLM.Events.Auto_Compaction_Start_Event (E).Reason;
         elsif E in LLM.Events.Message_Update_Event then
            declare
               Event : constant LLM.Events.Message_Update_Event :=
                 LLM.Events.Message_Update_Event (E);
            begin
               if Event.Kind = LLM.Events.Text_Delta then
                  Append (Final_Text, To_String (Event.Delta_Text));
               end if;
            end;
         elsif E in LLM.Events.Message_End_Event then
            Final_Stop := LLM.Events.Message_End_Event (E).Stop;
         elsif E in LLM.Events.Agent_End_Event then
            End_Was_Aborted := LLM.Events.Agent_End_Event (E).Was_Aborted;
         end if;
      end On_Event;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Request_Count := Request_Count + 1;
         case Request_Count is
            when 1 =>
               Res.Status := 400;
               Append (Res.Body_Data, "prompt is too long");
            when 2 =>
               Res.Status := 200;
               Add_SSE_Header (Res);
               Append (Res.Body_Data,
                       Text_SSE_Payload (Summary_Text, 8, 3));
            when others =>
               Res.Status := 200;
               Add_SSE_Header (Res);
               Append (Res.Body_Data,
                       Text_SSE_Payload (Reply_Text, 8, 3));
         end case;
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);
      Seed_Compaction_History (Agent_Session);

      Srv.Bind (Port);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Recover from overflow",
         On_Event => On_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Assert
        (Saw_Compaction_Start,
         "Overflow should emit Auto_Compaction_Start_Event");
      Assert
        (To_String (Compaction_Reason) = "overflow",
         "Overflow compaction should record the overflow reason");
      Assert
        (not End_Was_Aborted,
         "Recovered overflow turn should end normally");
      Assert
        (Final_Stop = LLM.Types.Stop,
         "Recovered overflow turn should finish with Stop");
      Assert
        (To_String (Final_Text) = Reply_Text,
         "Recovered overflow turn should stream the retried reply");
      Assert
        (LLM.Agent.Testing.History_Element (Agent_Session, 0).Role
           = LLM.Types.Compaction_Summary,
         "Overflow recovery should compact the in-memory history");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Overflow_Triggers_Compact_And_Retry;

   procedure Test_Overflow_Recovery_Not_Attempted_Twice
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home                 : constant String :=
        "/tmp/coyote_llm_agent_test_26";
      Port                 : constant Positive := 18_822;
      Agent_Session        : LLM.Agent.Session;
      Saw_Aborted_End      : Boolean := False;
      Aborted_Error_Text   : Unbounded_String := Null_Unbounded_String;
      Saw_Agent_End        : Boolean := False;
      Summary_Text         : constant String :=
        "## Goal" & ASCII.LF & "overflow retry failure";
      Server_Stopped       : Boolean := False;
      Request_Count        : Natural := 0;
      Home_Was_Set         : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home             : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set          : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key              : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set          : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url              : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         if E in LLM.Events.Auto_Compaction_End_Event then
            declare
               Event : constant LLM.Events.Auto_Compaction_End_Event :=
                 LLM.Events.Auto_Compaction_End_Event (E);
            begin
               if Event.Aborted then
                  Saw_Aborted_End := True;
                  Aborted_Error_Text := Event.Err_Msg;
               end if;
            end;
         elsif E in LLM.Events.Agent_End_Event then
            Saw_Agent_End := True;
         end if;
      end On_Event;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Request_Count := Request_Count + 1;
         if Request_Count = 2 then
            Res.Status := 200;
            Add_SSE_Header (Res);
            Append (Res.Body_Data,
                    Text_SSE_Payload (Summary_Text, 8, 3));
         else
            Res.Status := 400;
            Append (Res.Body_Data, "prompt is too long");
         end if;
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);
      Seed_Compaction_History (Agent_Session);

      Srv.Bind (Port);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Overflow twice",
         On_Event => On_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Assert
        (Saw_Aborted_End,
         "Second overflow should emit an aborted compaction end event");
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Aborted_Error_Text),
            "Context overflow recovery failed after one attempt.") > 0,
         "Second overflow should report the one-attempt failure message");
      Assert
        (Saw_Agent_End,
         "Run_Prompt should still emit Agent_End and return");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Overflow_Recovery_Not_Attempted_Twice;

   procedure Test_Overflow_Will_Retry_Event_Emitted
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home              : constant String :=
        "/tmp/coyote_llm_agent_test_27";
      Port              : constant Positive := 18_823;
      Agent_Session     : LLM.Agent.Session;
      Event_Count       : Natural := 0;
      Will_Retry_Pos    : Natural := No_Event_Index;
      Final_Text_Pos    : Natural := No_Event_Index;
      Summary_Text      : constant String :=
        "## Goal" & ASCII.LF & "overflow retry event";
      Server_Stopped    : Boolean := False;
      Request_Count     : Natural := 0;
      Home_Was_Set      : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home          : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set       : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key           : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set       : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url           : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         Event_Count := Event_Count + 1;

         if E in LLM.Events.Auto_Compaction_End_Event then
            declare
               Event : constant LLM.Events.Auto_Compaction_End_Event :=
                 LLM.Events.Auto_Compaction_End_Event (E);
            begin
               if Event.Will_Retry and then Will_Retry_Pos = No_Event_Index
               then
                  Will_Retry_Pos := Event_Count;
               end if;
            end;
         elsif E in LLM.Events.Message_Update_Event then
            declare
               Event : constant LLM.Events.Message_Update_Event :=
                 LLM.Events.Message_Update_Event (E);
            begin
               if Event.Kind = LLM.Events.Text_Delta
                 and then Final_Text_Pos = No_Event_Index
               then
                  Final_Text_Pos := Event_Count;
               end if;
            end;
         end if;
      end On_Event;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Request_Count := Request_Count + 1;
         case Request_Count is
            when 1 =>
               Res.Status := 400;
               Append (Res.Body_Data, "prompt is too long");
            when 2 =>
               Res.Status := 200;
               Add_SSE_Header (Res);
               Append (Res.Body_Data,
                       Text_SSE_Payload (Summary_Text, 8, 3));
            when others =>
               Res.Status := 200;
               Add_SSE_Header (Res);
               Append (Res.Body_Data,
                       Text_SSE_Payload ("retry reply", 8, 3));
         end case;
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);
      Seed_Compaction_History (Agent_Session);

      Srv.Bind (Port);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Emit retry event",
         On_Event => On_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Assert
        (Will_Retry_Pos /= No_Event_Index,
         "Overflow recovery should emit an Auto_Compaction_End"
         & " will-retry event");
      Assert
        (Final_Text_Pos /= No_Event_Index,
         "Successful retry should eventually emit streamed text");
      Assert
        (Will_Retry_Pos < Final_Text_Pos,
         "Will_Retry event should be emitted before the retried text"
         & " arrives");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Overflow_Will_Retry_Event_Emitted;

   procedure Test_Compact_Produces_Summary_Message
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home           : constant String := "/tmp/coyote_llm_agent_test_16";
      Port           : constant Positive := 18_801;
      Agent_Session  : LLM.Agent.Session;
      Summary_Text   : constant String :=
        "## Goal" & ASCII.LF
        & "Verify compact creates a summary." & ASCII.LF & ASCII.LF
        & "## Constraints & Preferences" & ASCII.LF
        & "- (none)";
      Server_Stopped : Boolean := False;
      Home_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home       : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key        : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url        : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure Ignore_Event (E : LLM.Events.Agent_Event'Class) is
         pragma Unreferenced (E);
      begin
         null;
      end Ignore_Event;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 200;
         Add_SSE_Header (Res);
         Append (Res.Body_Data, Text_SSE_Payload (Summary_Text, 8, 3));
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);
      Seed_Compaction_History (Agent_Session);

      Srv.Bind (Port);

      LLM.Agent.Compact
        (S        => Agent_Session,
         On_Event => Ignore_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Assert
        (LLM.Agent.Testing.History_Length (Agent_Session) = 3,
         "Compact should replace old history with summary plus kept tail");
      Assert
        (LLM.Agent.Testing.History_Element (Agent_Session, 0).Role
           = LLM.Types.Compaction_Summary,
         "First history message should be the synthetic summary");
      Assert
        (Assistant_Text
           (LLM.Agent.Testing.History_Element (Agent_Session, 0))
         = Summary_Text,
         "Summary text should be stored in the first history message");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Compact_Produces_Summary_Message;

   procedure Test_Compact_Emits_Start_And_End_Events
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home           : constant String := "/tmp/coyote_llm_agent_test_17";
      Port           : constant Positive := 18_802;
      Agent_Session  : LLM.Agent.Session;
      Events         : Recorded_Event_Vectors.Vector;
      End_Aborted    : Boolean := True;
      Server_Stopped : Boolean := False;
      Home_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home       : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key        : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url        : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         Events.Append (To_Recorded_Event_Kind (E));
         if E in LLM.Events.Auto_Compaction_End_Event then
            End_Aborted := LLM.Events.Auto_Compaction_End_Event (E).Aborted;
         end if;
      end On_Event;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 200;
         Add_SSE_Header (Res);
         Append (Res.Body_Data,
                 Text_SSE_Payload
                   ("## Goal" & ASCII.LF & "event test", 8, 3));
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);
      Seed_Compaction_History (Agent_Session);

      Srv.Bind (Port);

      LLM.Agent.Compact
        (S        => Agent_Session,
         On_Event => On_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      declare
         Start_Pos : constant Natural :=
           First_Event_Index (Events, Auto_Compaction_Start_Kind);
         End_Pos   : constant Natural :=
           First_Event_Index (Events, Auto_Compaction_End_Kind);
      begin
         Assert
           (Start_Pos /= No_Event_Index,
            "Compact should emit Auto_Compaction_Start_Event");
         Assert
           (End_Pos /= No_Event_Index,
            "Compact should emit Auto_Compaction_End_Event");
         Assert
           (Start_Pos < End_Pos,
            "Auto_Compaction_Start_Event should precede end event");
         Assert (not End_Aborted, "Successful compaction should not abort");
      end;

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Compact_Emits_Start_And_End_Events;

   procedure Test_Compact_Short_History_Aborts
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home              : constant String := "/tmp/coyote_llm_agent_test_18";
      Agent_Session     : LLM.Agent.Session;
      Saw_End           : Boolean := False;
      End_Aborted       : Boolean := False;
      Original_Length   : Ada.Containers.Count_Type;
      Original_Text     : Unbounded_String := Null_Unbounded_String;
      Home_Was_Set      : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home          : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set       : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key           : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         if E in LLM.Events.Auto_Compaction_End_Event then
            Saw_End := True;
            End_Aborted := LLM.Events.Auto_Compaction_End_Event (E).Aborted;
         end if;
      end On_Event;
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);
      Append_Text_Message
        (LLM.Agent.Session_Id (Agent_Session),
         LLM.Types.User,
         "Only one message");
      LLM.Agent.Switch_Session
        (Agent_Session, LLM.Agent.Session_Id (Agent_Session));

      Original_Length := LLM.Agent.Testing.History_Length (Agent_Session);
      Original_Text := To_Unbounded_String
        (Assistant_Text
           (LLM.Agent.Testing.History_Element (Agent_Session, 0)));

      LLM.Agent.Compact
        (S        => Agent_Session,
         On_Event => On_Event'Access);

      Assert (Saw_End, "Short-history compaction should emit an end event");
      Assert (End_Aborted, "Short histories should abort compaction");
      Assert
        (LLM.Agent.Testing.History_Length (Agent_Session) = Original_Length,
         "Short-history abort should leave history unchanged");
      Assert
        (Assistant_Text (LLM.Agent.Testing.History_Element (Agent_Session, 0))
           = To_String (Original_Text),
         "Short-history abort should preserve the original message text");

      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Compact_Short_History_Aborts;

   procedure Test_Compact_Persists_Entry
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home           : constant String := "/tmp/coyote_llm_agent_test_19";
      Port           : constant Positive := 18_803;
      Agent_Session  : LLM.Agent.Session;
      Messages       : LLM.Types.Message_Vectors.Vector;
      Server_Stopped : Boolean := False;
      Home_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home       : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key        : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url        : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure Ignore_Event (E : LLM.Events.Agent_Event'Class) is
         pragma Unreferenced (E);
      begin
         null;
      end Ignore_Event;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 200;
         Add_SSE_Header (Res);
         Append (Res.Body_Data,
                 Text_SSE_Payload
                   ("## Goal" & ASCII.LF & "persist", 8, 3));
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);
      Seed_Compaction_History (Agent_Session);

      Srv.Bind (Port);

      LLM.Agent.Compact
        (S        => Agent_Session,
         On_Event => Ignore_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Messages := LLM.Session_Store.Load_Messages
        (LLM.Agent.Session_Id (Agent_Session));
      Assert
        (not Messages.Is_Empty,
         "Compacted session should reload from disk with synthetic history");
      Assert
        (Messages.First_Element.Role = LLM.Types.Compaction_Summary,
         "Reloaded session should begin with Compaction_Summary");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Compact_Persists_Entry;

   procedure Test_Auto_Compact_Fires_At_Threshold
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home                  : constant String :=
        "/tmp/coyote_llm_agent_test_21";
      Port                  : constant Positive := 18_805;
      Handle                : Process_Handle := Invalid_Handle;
      Agent_Session         : LLM.Agent.Session;
      Saw_Compaction_Start  : Boolean := False;
      Compaction_Reason     : Unbounded_String := Null_Unbounded_String;
      Summary_Text          : constant String :=
        "## Goal" & ASCII.LF & "threshold compaction";
      Home_Was_Set          : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home              : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set           : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key               : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set           : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url               : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         if E in LLM.Events.Auto_Compaction_Start_Event then
            Saw_Compaction_Start := True;
            Compaction_Reason :=
              LLM.Events.Auto_Compaction_Start_Event (E).Reason;
         end if;
      end On_Event;
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);

      Handle := Spawn_Server
        (Prompt_Then_Compaction_Server_Script
           (Port              => Port,
            Reply_Text        => "threshold reply",
            Summary_Text      => Summary_Text,
            Prompt_Tokens     => 120_000,
            Completion_Tokens => 616));
      Wait_For_Server;

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Trigger threshold compaction",
         On_Event => On_Event'Access);

      Stop_Server (Handle);

      Assert
        (Saw_Compaction_Start,
         "Threshold usage should emit Auto_Compaction_Start_Event");
      Assert
        (To_String (Compaction_Reason) = "threshold",
         "Auto-compaction reason should be threshold");
      Assert
        (LLM.Agent.Testing.History_Length (Agent_Session) >= 1,
         "Auto-compaction should leave a non-empty in-memory history");
      Assert
        (LLM.Agent.Testing.History_Element (Agent_Session, 0).Role
           = LLM.Types.Compaction_Summary,
         "Auto-compaction should prepend a Compaction_Summary message");
      Assert
        (Assistant_Text
           (LLM.Agent.Testing.History_Element (Agent_Session, 0))
         = Summary_Text,
         "Threshold compaction should store the returned summary text");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Stop_Server (Handle);
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Auto_Compact_Fires_At_Threshold;

   procedure Test_Auto_Compact_Does_Not_Fire_Below_Threshold
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home                  : constant String :=
        "/tmp/coyote_llm_agent_test_22";
      Capture_Path          : constant String :=
        Home & "/threshold_request.json";
      Port                  : constant Positive := 18_806;
      Handle                : Process_Handle := Invalid_Handle;
      Agent_Session         : LLM.Agent.Session;
      Saw_Compaction_Start  : Boolean := False;
      Home_Was_Set          : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home              : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set           : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key               : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set           : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url               : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         if E in LLM.Events.Auto_Compaction_Start_Event then
            Saw_Compaction_Start := True;
         end if;
      end On_Event;
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);

      Handle := Spawn_Server
        (Capture_Request_Server_Script
           (Port         => Port,
            Capture_Path => Capture_Path,
            Reply_Text   => "small reply"));
      Wait_For_Server;

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Stay below the threshold",
         On_Event => On_Event'Access);

      Stop_Server (Handle);

      Assert
        (not Saw_Compaction_Start,
         "Below-threshold usage should not emit auto-compaction events");
      Assert
        (LLM.Agent.Testing.History_Length (Agent_Session) = 2,
         "Below-threshold prompt should leave just user and assistant turns");
      Assert
        (LLM.Agent.Testing.History_Element (Agent_Session, 0).Role
           = LLM.Types.User,
         "Below-threshold history should remain un-compacted");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Stop_Server (Handle);
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Auto_Compact_Does_Not_Fire_Below_Threshold;

   procedure Test_Auto_Compact_Session_Persisted_After_Threshold
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home           : constant String := "/tmp/coyote_llm_agent_test_23";
      Port           : constant Positive := 18_807;
      Handle         : Process_Handle := Invalid_Handle;
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
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url        : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
         pragma Unreferenced (E);
      begin
         null;
      end On_Event;
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);

      Handle := Spawn_Server
        (Prompt_Then_Compaction_Server_Script
           (Port              => Port,
            Reply_Text        => "persisted reply",
            Summary_Text      => "## Goal" & ASCII.LF & "persisted threshold",
            Prompt_Tokens     => 120_000,
            Completion_Tokens => 616));
      Wait_For_Server;

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Persist threshold compaction",
         On_Event => On_Event'Access);

      Stop_Server (Handle);

      Messages := LLM.Session_Store.Load_Messages
        (LLM.Agent.Session_Id (Agent_Session));
      Assert
        (not Messages.Is_Empty,
         "Threshold compaction should leave a reloadable session history");
      Assert
        (Messages.First_Element.Role = LLM.Types.Compaction_Summary,
         "Reloaded threshold-compacted session should start with summary");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Stop_Server (Handle);
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Auto_Compact_Session_Persisted_After_Threshold;

   procedure Test_Compact_Then_Resume
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home           : constant String := "/tmp/coyote_llm_agent_test_20";
      Port           : constant Positive := 18_804;
      Agent_Session  : LLM.Agent.Session;
      Session_UUID   : Unbounded_String := Null_Unbounded_String;
      Server_Stopped : Boolean := False;
      Home_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home       : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key        : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url        : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure Ignore_Event (E : LLM.Events.Agent_Event'Class) is
         pragma Unreferenced (E);
      begin
         null;
      end Ignore_Event;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 200;
         Add_SSE_Header (Res);
         Append (Res.Body_Data,
                 Text_SSE_Payload
                   ("## Goal" & ASCII.LF & "resume", 8, 3));
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);
      Seed_Compaction_History (Agent_Session);
      Session_UUID :=
        To_Unbounded_String (LLM.Agent.Session_Id (Agent_Session));

      Srv.Bind (Port);

      LLM.Agent.Compact
        (S        => Agent_Session,
         On_Event => Ignore_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      LLM.Agent.Switch_Session (Agent_Session, To_String (Session_UUID));
      Assert
        (LLM.Agent.Testing.History_Length (Agent_Session) >= 1,
         "Switch_Session should reload compacted history");
      Assert
        (LLM.Agent.Testing.History_Element (Agent_Session, 0).Role
           = LLM.Types.Compaction_Summary,
         "Reloaded in-memory history should start with Compaction_Summary");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Compact_Then_Resume;

   procedure Test_Compact_Live_Summarises_Conversation
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Guard_Name : constant String := "COYOTE_RUN_GITHUB_COPILOT_LIVE";
      Auth_Path  : constant String :=
        Ada.Environment_Variables.Value ("HOME", "") & "/.pi/agent/auth.json";
      Agent_Session : LLM.Agent.Session;

      procedure Ignore_Event (E : LLM.Events.Agent_Event'Class) is
         pragma Unreferenced (E);
      begin
         null;
      end Ignore_Event;
   begin
      if Ada.Environment_Variables.Value (Guard_Name, "") /= "1" then
         return;
      end if;

      if not Ada.Directories.Exists (Auth_Path) then
         Ada.Text_IO.Put_Line
           ("[SKIP] GitHub Copilot live compaction test requires "
            & Auth_Path);
         return;
      end if;

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "github-copilot/claude-sonnet-4.6",
         No_Tools   => True);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   =>
           "We are testing live context compaction. Please note that the"
           & " goal is to verify the summary format.",
         On_Event => Ignore_Event'Access);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   =>
           "Constraint: keep the summary concise and preserve exact phrases"
           & " when possible.",
         On_Event => Ignore_Event'Access);

      LLM.Agent.Compact
        (S        => Agent_Session,
         On_Event => Ignore_Event'Access);

      Assert
        (LLM.Agent.Testing.History_Length (Agent_Session) >= 1,
         "Live compaction should leave a non-empty history");
      Assert
        (LLM.Agent.Testing.History_Element (Agent_Session, 0).Role
           = LLM.Types.Compaction_Summary,
         "Live compaction should prepend a Compaction_Summary message");
      declare
         Summary : constant String :=
           Assistant_Text
             (LLM.Agent.Testing.History_Element (Agent_Session, 0));
      begin
         Assert
           (Summary'Length > 0,
            "Live compaction summary text should not be empty");
         Assert
           (Ada.Strings.Fixed.Index (Summary, "## Goal") > 0,
            "Live compaction summary should contain the required heading");
      end;
   end Test_Compact_Live_Summarises_Conversation;

end LLM_Agent_Tests;
