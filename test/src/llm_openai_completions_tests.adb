with AUnit.Assertions;
with Ada.Containers;
with Ada.Containers.Indefinite_Vectors;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;       use Ada.Strings.Unbounded;
with Ada.Tags;
with GNATCOLL.OS.Process;         use GNATCOLL.OS.Process;
with LLM.Events;
with LLM.HTTP;
with LLM.Providers;
with LLM.Providers.OpenAI_Completions;
with LLM.Providers.OpenAI_Completions.Testing;
with LLM.Types;

package body LLM_OpenAI_Completions_Tests is

   use AUnit.Assertions;
   use type Ada.Containers.Count_Type;
   use type Ada.Tags.Tag;
   use type LLM.Types.Stop_Reason;

   function C_Kill
     (Process_Id : Integer;
      Signal     : Integer) return Integer
     with Import, Convention => C, External_Name => "kill";

   package String_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type   => Positive,
      Element_Type => String);

   type Event_Collector is record
      Sequence  : String_Vectors.Vector;
      Last_Stop : LLM.Types.Stop_Reason := LLM.Types.Unknown_Stop;
      Usage     : LLM.Types.Usage := (others => 0);
   end record;

   Current_Collector : Event_Collector;

   function Natural_Image (Value : Natural) return String is
      Image : constant String := Natural'Image (Value);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Natural_Image;

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

   procedure Send_With_Retry
     (P             : in out LLM.Providers.OpenAI_Completions.Provider;
      Model_Id      :        String;
      System_Prompt :        String;
      Messages      :        LLM.Types.Message_Vectors.Vector;
      Tools_Json    :        String;
      Max_Tokens    :        Positive;
      Handler       :        LLM.Providers.Event_Handler)
   is
   begin
      Retry_Loop :
      for Attempt in 1 .. 20 loop
         begin
            P.Send
              (Model_Id      => Model_Id,
               System_Prompt => System_Prompt,
               Messages      => Messages,
               Tools_Json    => Tools_Json,
               Thinking      => LLM.Providers.Off,
               Max_Tokens    => Max_Tokens,
               Handler       => Handler);
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

   procedure Reset_Collector is
   begin
      Current_Collector.Sequence.Clear;
      Current_Collector.Last_Stop := LLM.Types.Unknown_Stop;
      Current_Collector.Usage := (others => 0);
   end Reset_Collector;

   procedure Collect_Event
     (Collector : in out Event_Collector;
      E         :        LLM.Events.Agent_Event'Class)
   is
   begin
      if E'Tag = LLM.Events.Agent_Start_Event'Tag then
         Collector.Sequence.Append ("agent_start");
      elsif E'Tag = LLM.Events.Message_Start_Event'Tag then
         Collector.Sequence.Append ("message_start");
      elsif E'Tag = LLM.Events.Message_End_Event'Tag then
         declare
            Event : constant LLM.Events.Message_End_Event :=
              LLM.Events.Message_End_Event (E);
         begin
            Collector.Last_Stop := Event.Stop;
            Collector.Usage := Event.Tok_Usage;
            Collector.Sequence.Append ("message_end");
         end;
      elsif E'Tag = LLM.Events.Agent_End_Event'Tag then
         Collector.Sequence.Append ("agent_end");
      elsif E'Tag = LLM.Events.Message_Update_Event'Tag then
         declare
            Event : constant LLM.Events.Message_Update_Event :=
              LLM.Events.Message_Update_Event (E);
         begin
            case Event.Kind is
               when LLM.Events.Thinking_Start =>
                  Collector.Sequence.Append ("thinking_start");
               when LLM.Events.Thinking_Delta =>
                  Collector.Sequence.Append
                    ("thinking_delta:" & To_String (Event.Delta_Text));
               when LLM.Events.Thinking_End =>
                  Collector.Sequence.Append ("thinking_end");
               when LLM.Events.Text_Start =>
                  Collector.Sequence.Append ("text_start");
               when LLM.Events.Text_Delta =>
                  Collector.Sequence.Append
                    ("text_delta:" & To_String (Event.Delta_Text));
               when LLM.Events.Text_End =>
                  Collector.Sequence.Append ("text_end");
               when LLM.Events.Tool_Call_Start =>
                  Collector.Sequence.Append
                    ("tool_call_start:" & To_String (Event.Tool_Call_Id)
                     & ":" & To_String (Event.Tool_Name));
               when LLM.Events.Tool_Call_Delta =>
                  Collector.Sequence.Append
                    ("tool_call_delta:" & To_String (Event.Delta_Text));
               when LLM.Events.Tool_Call_End =>
                  Collector.Sequence.Append
                    ("tool_call_end:" & To_String (Event.Tool_Call_Id)
                     & ":" & To_String (Event.Delta_Text));
            end case;
         end;
      else
         Collector.Sequence.Append ("other_event");
      end if;
   end Collect_Event;

   procedure On_Event (E : LLM.Events.Agent_Event'Class) is
   begin
      Collect_Event (Current_Collector, E);
   end On_Event;

   function Sequence_Image return String is
      Result : Unbounded_String;
   begin
      for Item of Current_Collector.Sequence loop
         if Length (Result) > 0 then
            Append (Result, " | ");
         end if;
         Append (Result, Item);
      end loop;
      return To_String (Result);
   end Sequence_Image;

   function Text_Server_Script (Port : Positive) return String is
   begin
      return
        "import http.server, json" & ASCII.LF
        & "class S(http.server.HTTPServer):" & ASCII.LF
        & "    allow_reuse_address = True" & ASCII.LF
        & "class H(http.server.BaseHTTPRequestHandler):" & ASCII.LF
        & "    def do_POST(self):" & ASCII.LF
        & "        try:" & ASCII.LF
        & "            assert self.path == '/chat/completions'" & ASCII.LF
        & "            assert self.headers['Authorization'] == "
        & "'Bearer test-key'" & ASCII.LF
        & "            assert self.headers['Content-Type'] == "
        & "'application/json'" & ASCII.LF
        & "            n = int(self.headers.get('Content-Length', '0'))"
        & ASCII.LF
        & "            body = json.loads(self.rfile.read(n))" & ASCII.LF
        & "            assert body['model'] == 'test-model'" & ASCII.LF
        & "            assert body['stream'] is True" & ASCII.LF
        & "            assert body['max_completion_tokens'] == 128"
        & ASCII.LF
        & "            assert body['messages'][0] == {" & ASCII.LF
        & "                'role': 'system'," & ASCII.LF
        & "                'content': 'Be helpful.'}" & ASCII.LF
        & "            assert body['messages'][1] == {" & ASCII.LF
        & "                'role': 'user'," & ASCII.LF
        & "                'content': 'Say hello'}" & ASCII.LF
        & "            assert 'tools' not in body" & ASCII.LF
        & "            events = [" & ASCII.LF
        & "                {'choices': [{'delta': {'role': 'assistant',"
        & " 'content': 'Hello'}, 'finish_reason': None}]}," & ASCII.LF
        & "                {'choices': [{'delta': {}, 'finish_reason': "
        & "'stop'}], 'usage': {'prompt_tokens': 10,"
        & " 'completion_tokens': 5, 'total_tokens': 15}}]" & ASCII.LF
        & "            payload = ''.join(" & ASCII.LF
        & "                'data: ' + json.dumps(event) + '\n\n'"
        & ASCII.LF
        & "                for event in events).encode()"
        & ASCII.LF
        & "            payload += b'data: [DONE]\n\n'" & ASCII.LF
        & "            self.send_response(200)" & ASCII.LF
        & "            self.send_header('Content-Type', "
        & "'text/event-stream')" & ASCII.LF
        & "            self.send_header('Content-Length', "
        & "str(len(payload)))" & ASCII.LF
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
   end Text_Server_Script;

   function Tool_Server_Script (Port : Positive) return String is
   begin
      return
        "import http.server, json" & ASCII.LF
        & "class S(http.server.HTTPServer):" & ASCII.LF
        & "    allow_reuse_address = True" & ASCII.LF
        & "class H(http.server.BaseHTTPRequestHandler):" & ASCII.LF
        & "    def do_POST(self):" & ASCII.LF
        & "        try:" & ASCII.LF
        & "            assert self.path == '/chat/completions'" & ASCII.LF
        & "            assert self.headers['Authorization'] == "
        & "'Bearer test-key'" & ASCII.LF
        & "            assert self.headers['X-Test-Header'] == 'ok'"
        & ASCII.LF
        & "            n = int(self.headers.get('Content-Length', '0'))"
        & ASCII.LF
        & "            body = json.loads(self.rfile.read(n))" & ASCII.LF
        & "            assert body['model'] == 'tool-model'" & ASCII.LF
        & "            assert body['messages'][0]['role'] == 'user'"
        & ASCII.LF
        & "            assert body['messages'][0]['content'] == "
        & "'Use a tool'" & ASCII.LF
        & "            assert body['messages'][1]['role'] == 'assistant'"
        & ASCII.LF
        & "            assert body['messages'][1]['content'] is None"
        & ASCII.LF
        & "            tc = body['messages'][1]['tool_calls'][0]"
        & ASCII.LF
        & "            assert tc['id'] == 'call_1'" & ASCII.LF
        & "            assert tc['type'] == 'function'" & ASCII.LF
        & "            assert tc['function']['name'] == 'read'"
        & ASCII.LF
        & "            assert tc['function']['arguments'] == "
        & "'{""path"":""a.adb""}'" & ASCII.LF
        & "            assert body['messages'][2]['role'] == 'tool'"
        & ASCII.LF
        & "            assert body['messages'][2]['tool_call_id'] == "
        & "'call_1'" & ASCII.LF
        & "            assert body['messages'][2]['content'] == "
        & "'file contents'" & ASCII.LF
        & "            assert len(body['tools']) == 1" & ASCII.LF
        & "            events = [" & ASCII.LF
        & "                {'choices': [{'delta': {'tool_calls': [" & ASCII.LF
        & "                    {'index': 0, 'id': 'call_1',"
        & " 'type': 'function', 'function': {'name': 'read',"
        & " 'arguments': '{""path"":""'}}]},"
        & " 'finish_reason': None}]}," & ASCII.LF
        & "                {'choices': [{'delta': {'tool_calls': [" & ASCII.LF
        & "                    {'index': 0, 'function': {"
        & "'arguments': 'a.adb""}'}}]}, 'finish_reason': "
        & "'tool_calls'}], 'usage': {'prompt_tokens': 12,"
        & " 'completion_tokens': 7, 'total_tokens': 19}}]" & ASCII.LF
        & "            payload = ''.join(" & ASCII.LF
        & "                'data: ' + json.dumps(event) + '\n\n'"
        & ASCII.LF
        & "                for event in events).encode()"
        & ASCII.LF
        & "            payload += b'data: [DONE]\n\n'" & ASCII.LF
        & "            self.send_response(200)" & ASCII.LF
        & "            self.send_header('Content-Type', "
        & "'text/event-stream')" & ASCII.LF
        & "            self.send_header('Content-Length', "
        & "str(len(payload)))" & ASCII.LF
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
   end Tool_Server_Script;

   function Multi_Tool_Server_Script (Port : Positive) return String is
   begin
      return
        "import http.server, json" & ASCII.LF
        & "class S(http.server.HTTPServer):" & ASCII.LF
        & "    allow_reuse_address = True" & ASCII.LF
        & "class H(http.server.BaseHTTPRequestHandler):" & ASCII.LF
        & "    def do_POST(self):" & ASCII.LF
        & "        try:" & ASCII.LF
        & "            assert self.path == '/chat/completions'" & ASCII.LF
        & "            assert self.headers['Authorization'] == "
        & "'Bearer test-key'" & ASCII.LF
        & "            n = int(self.headers.get('Content-Length', '0'))"
        & ASCII.LF
        & "            body = json.loads(self.rfile.read(n))" & ASCII.LF
        & "            assert body['model'] == 'multi-tool-model'"
        & ASCII.LF
        & "            assert body['stream'] is True" & ASCII.LF
        & "            assert len(body['messages']) == 1" & ASCII.LF
        & "            events = [" & ASCII.LF
        & "                {'choices': [{'delta': {'tool_calls': ["
        & "{'index': 0, 'id': 'call_1', 'type': 'function',"
        & " 'function': {'name': 'read', 'arguments': "
        & "'{""path"":""alpha'}},"
        & " {'index': 1, 'id': 'call_2', 'type': 'function',"
        & " 'function': {'name': 'write', 'arguments': "
        & "'{""path"":""beta'}}]},"
        & " 'finish_reason': None}]}," & ASCII.LF
        & "                {'choices': [{'delta': {'tool_calls': ["
        & "{'index': 0, 'function': {'arguments': '.adb""}'}},"
        & " {'index': 1, 'function': {'arguments': '.adb""}'}}]},"
        & " 'finish_reason': None}]}," & ASCII.LF
        & "                {'choices': [{'delta': {}, 'finish_reason':"
        & " 'tool_calls'}], 'usage': {'prompt_tokens': 21,"
        & " 'completion_tokens': 9, 'total_tokens': 30}}]" & ASCII.LF
        & "            payload = ''.join(" & ASCII.LF
        & "                'data: ' + json.dumps(event) + '\n\n'"
        & ASCII.LF
        & "                for event in events).encode()" & ASCII.LF
        & "            payload += b'data: [DONE]\n\n'" & ASCII.LF
        & "            self.send_response(200)" & ASCII.LF
        & "            self.send_header('Content-Type', "
        & "'text/event-stream')" & ASCII.LF
        & "            self.send_header('Content-Length', "
        & "str(len(payload)))" & ASCII.LF
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
   end Multi_Tool_Server_Script;

   function Thinking_Server_Script (Port : Positive) return String is
   begin
      return
        "import http.server, json" & ASCII.LF
        & "class S(http.server.HTTPServer):" & ASCII.LF
        & "    allow_reuse_address = True" & ASCII.LF
        & "class H(http.server.BaseHTTPRequestHandler):" & ASCII.LF
        & "    def do_POST(self):" & ASCII.LF
        & "        try:" & ASCII.LF
        & "            assert self.path == '/chat/completions'" & ASCII.LF
        & "            n = int(self.headers.get('Content-Length', '0'))"
        & ASCII.LF
        & "            body = json.loads(self.rfile.read(n))" & ASCII.LF
        & "            assert body['stream'] is True" & ASCII.LF
        & "            events = [" & ASCII.LF
        & "                {'choices': [{'delta': {'reasoning': "
        & "'thinking text'}, 'finish_reason': None}]}," & ASCII.LF
        & "                {'choices': [{'delta': {}, 'finish_reason': "
        & "'stop'}], 'usage': {'prompt_tokens': 8,"
        & " 'completion_tokens': 3, 'total_tokens': 11}}]" & ASCII.LF
        & "            payload = ''.join(" & ASCII.LF
        & "                'data: ' + json.dumps(event) + '\n\n'"
        & ASCII.LF
        & "                for event in events).encode()" & ASCII.LF
        & "            payload += b'data: [DONE]\n\n'" & ASCII.LF
        & "            self.send_response(200)" & ASCII.LF
        & "            self.send_header('Content-Type', "
        & "'text/event-stream')" & ASCII.LF
        & "            self.send_header('Content-Length', "
        & "str(len(payload)))" & ASCII.LF
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
   end Thinking_Server_Script;

   function Compaction_Summary_Server_Script (Port : Positive)
     return String
   is
   begin
      return
        "import http.server, json" & ASCII.LF
        & "class S(http.server.HTTPServer):" & ASCII.LF
        & "    allow_reuse_address = True" & ASCII.LF
        & "class H(http.server.BaseHTTPRequestHandler):" & ASCII.LF
        & "    def do_POST(self):" & ASCII.LF
        & "        try:" & ASCII.LF
        & "            assert self.path == '/chat/completions'" & ASCII.LF
        & "            n = int(self.headers.get('Content-Length', '0'))"
        & ASCII.LF
        & "            body = json.loads(self.rfile.read(n))" & ASCII.LF
        & "            assert len(body['messages']) == 1" & ASCII.LF
        & "            assert body['messages'][0]['role'] == 'user'"
        & ASCII.LF
        & "            assert body['messages'][0]['content'] == "
        & "'Checkpoint summary text'" & ASCII.LF
        & "            events = [" & ASCII.LF
        & "                {'choices': [{'delta': {}, 'finish_reason': "
        & "'stop'}], 'usage': {'prompt_tokens': 4,"
        & " 'completion_tokens': 0, 'total_tokens': 4}}]" & ASCII.LF
        & "            payload = ''.join(" & ASCII.LF
        & "                'data: ' + json.dumps(event) + '\n\n'"
        & ASCII.LF
        & "                for event in events).encode()" & ASCII.LF
        & "            payload += b'data: [DONE]\n\n'" & ASCII.LF
        & "            self.send_response(200)" & ASCII.LF
        & "            self.send_header('Content-Type', "
        & "'text/event-stream')" & ASCII.LF
        & "            self.send_header('Content-Length', "
        & "str(len(payload)))" & ASCII.LF
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
   end Compaction_Summary_Server_Script;

   function Non_Streaming_Server_Script (Port : Positive) return String is
   begin
      return
        "import http.server, json" & ASCII.LF
        & "class S(http.server.HTTPServer):" & ASCII.LF
        & "    allow_reuse_address = True" & ASCII.LF
        & "class H(http.server.BaseHTTPRequestHandler):" & ASCII.LF
        & "    def do_POST(self):" & ASCII.LF
        & "        try:" & ASCII.LF
        & "            assert self.path == '/chat/completions'" & ASCII.LF
        & "            n = int(self.headers.get('Content-Length', '0'))"
        & ASCII.LF
        & "            body = json.loads(self.rfile.read(n))" & ASCII.LF
        & "            assert body['model'] == 'non-stream-model'"
        & ASCII.LF
        & "            assert body['stream'] is False" & ASCII.LF
        & "            payload = json.dumps({" & ASCII.LF
        & "                'choices': [{'message': {'role': 'assistant',"
        & " 'content': 'Non-stream hello'}, 'finish_reason': 'stop'}],"
        & ASCII.LF
        & "                'usage': {'prompt_tokens': 13,"
        & " 'completion_tokens': 4, 'total_tokens': 17}}).encode()"
        & ASCII.LF
        & "            self.send_response(200)" & ASCII.LF
        & "            self.send_header('Content-Type', 'application/json')"
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
   end Non_Streaming_Server_Script;

   function Non_Streaming_Tool_Server_Script (Port : Positive) return String is
   begin
      return
        "import http.server, json" & ASCII.LF
        & "class S(http.server.HTTPServer):" & ASCII.LF
        & "    allow_reuse_address = True" & ASCII.LF
        & "class H(http.server.BaseHTTPRequestHandler):" & ASCII.LF
        & "    def do_POST(self):" & ASCII.LF
        & "        try:" & ASCII.LF
        & "            assert self.path == '/chat/completions'" & ASCII.LF
        & "            n = int(self.headers.get('Content-Length', '0'))"
        & ASCII.LF
        & "            body = json.loads(self.rfile.read(n))" & ASCII.LF
        & "            assert body['model'] == 'non-stream-tool-model'"
        & ASCII.LF
        & "            assert body['stream'] is False" & ASCII.LF
        & "            assert len(body['tools']) == 1" & ASCII.LF
        & "            payload = json.dumps({" & ASCII.LF
        & "                'choices': [{'message': {'role': 'assistant',"
        & " 'content': None, 'tool_calls': [{'id': 'call_1',"
        & " 'type': 'function', 'function': {'name': 'read',"
        & " 'arguments': '{""path"":""nonstream.adb""}'}}]},"
        & " 'finish_reason': 'tool_calls'}]," & ASCII.LF
        & "                'usage': {'prompt_tokens': 14,"
        & " 'completion_tokens': 6, 'total_tokens': 20}}).encode()"
        & ASCII.LF
        & "            self.send_response(200)" & ASCII.LF
        & "            self.send_header('Content-Type', 'application/json')"
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
   end Non_Streaming_Tool_Server_Script;

   function HTTP_Error_Server_Script (Port : Positive) return String is
   begin
      return
        "import http.server" & ASCII.LF
        & "payload = b'{""error"":""internal""}'" & ASCII.LF
        & "class S(http.server.HTTPServer):" & ASCII.LF
        & "    allow_reuse_address = True" & ASCII.LF
        & "class H(http.server.BaseHTTPRequestHandler):" & ASCII.LF
        & "    def do_POST(self):" & ASCII.LF
        & "        self.send_response(500)" & ASCII.LF
        & "        self.send_header('Content-Type', 'application/json')"
        & ASCII.LF
        & "        self.send_header('Content-Length', str(len(payload)))"
        & ASCII.LF
        & "        self.end_headers()" & ASCII.LF
        & "        self.wfile.write(payload)" & ASCII.LF
        & "        self.wfile.flush()" & ASCII.LF
        & "    def log_message(self, *a): pass" & ASCII.LF
        & "s = S(('127.0.0.1', " & Natural_Image (Port) & "), H)"
        & ASCII.LF
        & "s.timeout = 5" & ASCII.LF
        & "s.handle_request()" & ASCII.LF
        & "s.server_close()" & ASCII.LF;
   end HTTP_Error_Server_Script;

   function Early_Close_Server_Script (Port : Positive) return String is
   begin
      return
        "import http.server, json" & ASCII.LF
        & "class S(http.server.HTTPServer):" & ASCII.LF
        & "    allow_reuse_address = True" & ASCII.LF
        & "class H(http.server.BaseHTTPRequestHandler):" & ASCII.LF
        & "    def do_POST(self):" & ASCII.LF
        & "        event = {'choices': [{'delta': {'content': 'partial'},"
        & " 'finish_reason': None}]}" & ASCII.LF
        & "        payload = ('data: ' + json.dumps(event) + '\n\n').encode()"
        & ASCII.LF
        & "        self.send_response(200)" & ASCII.LF
        & "        self.send_header('Content-Type', 'text/event-stream')"
        & ASCII.LF
        & "        self.send_header('Content-Length', str(len(payload)))"
        & ASCII.LF
        & "        self.end_headers()" & ASCII.LF
        & "        self.wfile.write(payload)" & ASCII.LF
        & "        self.wfile.flush()" & ASCII.LF
        & "    def log_message(self, *a): pass" & ASCII.LF
        & "s = S(('127.0.0.1', " & Natural_Image (Port) & "), H)"
        & ASCII.LF
        & "s.timeout = 5" & ASCII.LF
        & "s.handle_request()" & ASCII.LF
        & "s.server_close()" & ASCII.LF;
   end Early_Close_Server_Script;

   procedure Test_Stream_Text_Response (T : in out Test) is
      pragma Unreferenced (T);

      Port      : constant Positive := 18_767;
      Handle     : Process_Handle := Invalid_Handle;
      Provider   : LLM.Providers.OpenAI_Completions.Provider :=
        LLM.Providers.OpenAI_Completions.Create
          (Base_Url => "http://127.0.0.1:18767",
           Api_Key  => "test-key");
      Messages   : LLM.Types.Message_Vectors.Vector;
      Content    : LLM.Types.Content_Block_Vectors.Vector;
   begin
      Reset_Collector;
      Content.Append
        ((Kind => LLM.Types.Text_Block,
          Text => To_Unbounded_String ("Say hello")));
      Messages.Append
        ((Role      => LLM.Types.User,
          Content   => Content,
          Tok_Usage => (others => 0),
          Stop      => LLM.Types.Unknown_Stop,
          Timestamp => Null_Unbounded_String));

      Handle := Spawn_Server (Text_Server_Script (Port));
      Wait_For_Server;

      Send_With_Retry
        (P             => Provider,
         Model_Id      => "test-model",
         System_Prompt => "Be helpful.",
         Messages      => Messages,
         Tools_Json    => "[]",
         Max_Tokens    => 128,
         Handler       => On_Event'Access);

      Stop_Server (Handle);

      Assert
        (Current_Collector.Sequence.Length >= 4,
         "Expected streamed events");
      Assert
        (Current_Collector.Sequence.Element (1) = "agent_start",
         "Agent_Start_Event should fire first");
      Assert
        (Current_Collector.Sequence.Element
           (Current_Collector.Sequence.Last_Index) = "agent_end",
         "Agent_End_Event should fire last");
      Assert
        (Current_Collector.Sequence.Find_Index ("text_delta:Hello") > 0,
         "Text delta should contain Hello: " & Sequence_Image);
      Assert
        (Current_Collector.Last_Stop = LLM.Types.Stop,
         "Stop reason should map to Stop");
      Assert
        (Current_Collector.Usage.Input = 10,
         "Usage.Input should be 10");
      Assert
        (Current_Collector.Usage.Output = 5,
         "Usage.Output should be 5");
   exception
      when others =>
         Stop_Server (Handle);
         raise;
   end Test_Stream_Text_Response;

   procedure Test_Stream_Tool_Call_Response (T : in out Test) is
      pragma Unreferenced (T);

      Port             : constant Positive := 18_768;
      Handle           : Process_Handle := Invalid_Handle;
      Provider         : LLM.Providers.OpenAI_Completions.Provider :=
        LLM.Providers.OpenAI_Completions.Create
          (Base_Url => "http://127.0.0.1:18768",
           Api_Key  => "test-key");
      Messages         : LLM.Types.Message_Vectors.Vector;
      User_Content     : LLM.Types.Content_Block_Vectors.Vector;
      Assistant_Blocks : LLM.Types.Content_Block_Vectors.Vector;
      Tool_Content     : LLM.Types.Content_Block_Vectors.Vector;
      Tools_Json       : constant String :=
        "[{""type"":""function"",""function"":{"
        & """name"":""read"",""description"":""Read file"","
        & """parameters"":{""type"":""object"","
        & """properties"":{""path"":{""type"":""string""}},"
        & """required"":[""path""]}}}]";
   begin
      Reset_Collector;
      LLM.Providers.OpenAI_Completions.Add_Header
        (Provider, "X-Test-Header", "ok");

      User_Content.Append
        ((Kind => LLM.Types.Text_Block,
          Text => To_Unbounded_String ("Use a tool")));
      Messages.Append
        ((Role      => LLM.Types.User,
          Content   => User_Content,
          Tok_Usage => (others => 0),
          Stop      => LLM.Types.Unknown_Stop,
          Timestamp => Null_Unbounded_String));

      Assistant_Blocks.Append
        ((Kind           => LLM.Types.Tool_Call_Block,
          Tool_Call_Id   => To_Unbounded_String ("call_1"),
          Tool_Name      => To_Unbounded_String ("read"),
          Arguments_Json => To_Unbounded_String
            ("{""path"":""a.adb""}")));
      Messages.Append
        ((Role      => LLM.Types.Assistant,
          Content   => Assistant_Blocks,
          Tok_Usage => (others => 0),
          Stop      => LLM.Types.Tool_Use,
          Timestamp => Null_Unbounded_String));

      Tool_Content.Append
        ((Kind        => LLM.Types.Tool_Result_Block,
          Result_Id   => To_Unbounded_String ("call_1"),
          Result_Text => To_Unbounded_String ("file contents"),
          Is_Error    => False));
      Messages.Append
        ((Role      => LLM.Types.Tool_Result,
          Content   => Tool_Content,
          Tok_Usage => (others => 0),
          Stop      => LLM.Types.Stop,
          Timestamp => Null_Unbounded_String));

      Handle := Spawn_Server (Tool_Server_Script (Port));
      Wait_For_Server;

      Send_With_Retry
        (P             => Provider,
         Model_Id      => "tool-model",
         System_Prompt => "",
         Messages      => Messages,
         Tools_Json    => Tools_Json,
         Max_Tokens    => 256,
         Handler       => On_Event'Access);

      Stop_Server (Handle);

      Assert
        (Current_Collector.Sequence.Length >= 6,
         "Expected tool-call events");
      Assert
        (Current_Collector.Sequence.Element (1) = "agent_start",
         "Agent_Start_Event should fire first");
      Assert
        (Current_Collector.Sequence.Element
           (Current_Collector.Sequence.Last_Index) = "agent_end",
         "Agent_End_Event should fire last");
      Assert
        (Current_Collector.Sequence.Find_Index
           ("tool_call_start:call_1:read") > 0,
         "Tool_Call_Start should fire for call_1/read: "
         & Sequence_Image);
      Assert
        (Current_Collector.Sequence.Find_Index
           ("tool_call_delta:{""path"":""") > 0,
         "First tool-call delta should contain the opening JSON fragment");
      Assert
        (Current_Collector.Sequence.Find_Index
           ("tool_call_delta:a.adb""}") > 0,
         "Second tool-call delta should contain the closing JSON fragment");
      Assert
        (Current_Collector.Sequence.Find_Index
           ("tool_call_end:call_1:{""path"":""a.adb""}") > 0,
         "Tool_Call_End should carry the assembled arguments JSON");
      Assert
        (Current_Collector.Last_Stop = LLM.Types.Tool_Use,
         "Stop reason should map to Tool_Use");
      Assert
        (Current_Collector.Usage.Input = 12,
         "Usage.Input should be 12");
      Assert
        (Current_Collector.Usage.Output = 7,
         "Usage.Output should be 7");
   exception
      when others =>
         Stop_Server (Handle);
         raise;
   end Test_Stream_Tool_Call_Response;

   procedure Test_Stream_Multi_Tool_Response (T : in out Test) is
      pragma Unreferenced (T);

      Port         : constant Positive := 18_769;
      Handle       : Process_Handle := Invalid_Handle;
      Provider     : LLM.Providers.OpenAI_Completions.Provider :=
        LLM.Providers.OpenAI_Completions.Create
          (Base_Url => "http://127.0.0.1:18769",
           Api_Key  => "test-key");
      Messages     : LLM.Types.Message_Vectors.Vector;
      User_Content : LLM.Types.Content_Block_Vectors.Vector;
      Tools_Json   : constant String :=
        "[{""type"":""function"",""function"":{"
        & """name"":""read"",""description"":""Read file"","
        & """parameters"":{""type"":""object"","
        & """properties"":{""path"":{""type"":""string""}},"
        & """required"": [""path""]}}},"
        & "{""type"":""function"",""function"":{"
        & """name"":""write"",""description"":""Write file"","
        & """parameters"":{""type"":""object"","
        & """properties"":{""path"":{""type"":""string""}},"
        & """required"": [""path""]}}}]";
   begin
      Reset_Collector;
      User_Content.Append
        ((Kind => LLM.Types.Text_Block,
          Text => To_Unbounded_String ("Use two tools")));
      Messages.Append
        ((Role      => LLM.Types.User,
          Content   => User_Content,
          Tok_Usage => (others => 0),
          Stop      => LLM.Types.Unknown_Stop,
          Timestamp => Null_Unbounded_String));

      Handle := Spawn_Server (Multi_Tool_Server_Script (Port));
      Wait_For_Server;

      Send_With_Retry
        (P             => Provider,
         Model_Id      => "multi-tool-model",
         System_Prompt => "",
         Messages      => Messages,
         Tools_Json    => Tools_Json,
         Max_Tokens    => 256,
         Handler       => On_Event'Access);

      Stop_Server (Handle);

      Assert
        (Current_Collector.Sequence.Find_Index
           ("tool_call_start:call_1:read") > 0,
         "First tool-call start should include call_1/read: "
         & Sequence_Image);
      Assert
        (Current_Collector.Sequence.Find_Index
           ("tool_call_start:call_2:write") > 0,
         "Second tool-call start should include call_2/write: "
         & Sequence_Image);
      Assert
        (Current_Collector.Sequence.Find_Index
           ("tool_call_end:call_1:{""path"":""alpha.adb""}") > 0,
         "First tool-call end should assemble alpha.adb: "
         & Sequence_Image);
      Assert
        (Current_Collector.Sequence.Find_Index
           ("tool_call_end:call_2:{""path"":""beta.adb""}") > 0,
         "Second tool-call end should assemble beta.adb: "
         & Sequence_Image);
      Assert
        (Current_Collector.Last_Stop = LLM.Types.Tool_Use,
         "Stop reason should map to Tool_Use for multi-tool responses");
      Assert
        (Current_Collector.Usage.Input = 21,
         "Usage.Input should be parsed from the final chunk");
      Assert
        (Current_Collector.Usage.Output = 9,
         "Usage.Output should be parsed from the final chunk");
   exception
      when others =>
         Stop_Server (Handle);
         raise;
   end Test_Stream_Multi_Tool_Response;

   procedure Test_Stream_Thinking_Response (T : in out Test) is
      pragma Unreferenced (T);

      Port         : constant Positive := 18_770;
      Handle       : Process_Handle := Invalid_Handle;
      Provider     : LLM.Providers.OpenAI_Completions.Provider :=
        LLM.Providers.OpenAI_Completions.Create
          (Base_Url => "http://127.0.0.1:18770",
           Api_Key  => "test-key");
      Messages     : LLM.Types.Message_Vectors.Vector;
      User_Content : LLM.Types.Content_Block_Vectors.Vector;
   begin
      Reset_Collector;
      User_Content.Append
        ((Kind => LLM.Types.Text_Block,
          Text => To_Unbounded_String ("Think first")));
      Messages.Append
        ((Role      => LLM.Types.User,
          Content   => User_Content,
          Tok_Usage => (others => 0),
          Stop      => LLM.Types.Unknown_Stop,
          Timestamp => Null_Unbounded_String));

      Handle := Spawn_Server (Thinking_Server_Script (Port));
      Wait_For_Server;

      Send_With_Retry
        (P             => Provider,
         Model_Id      => "thinking-model",
         System_Prompt => "",
         Messages      => Messages,
         Tools_Json    => "[]",
         Max_Tokens    => 64,
         Handler       => On_Event'Access);

      Stop_Server (Handle);

      Assert
        (Current_Collector.Sequence.Find_Index ("thinking_start") > 0,
         "Thinking_Start should be emitted for reasoning deltas");
      Assert
        (Current_Collector.Sequence.Find_Index
           ("thinking_delta:thinking text") > 0,
         "Thinking_Delta should contain the streamed reasoning text: "
         & Sequence_Image);
      Assert
        (Current_Collector.Sequence.Find_Index ("thinking_end") > 0,
         "Thinking_End should be emitted after the reasoning block");
      Assert
        (Current_Collector.Last_Stop = LLM.Types.Stop,
         "Reasoning response should finish with Stop");
   exception
      when others =>
         Stop_Server (Handle);
         raise;
   end Test_Stream_Thinking_Response;

   procedure Test_Compaction_Summary_Encodes_As_User_OpenAI
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Port            : constant Positive := 18_772;
      Handle          : Process_Handle := Invalid_Handle;
      Provider        : LLM.Providers.OpenAI_Completions.Provider :=
        LLM.Providers.OpenAI_Completions.Create
          (Base_Url => "http://127.0.0.1:18772",
           Api_Key  => "test-key");
      Messages        : LLM.Types.Message_Vectors.Vector;
      Summary_Content : LLM.Types.Content_Block_Vectors.Vector;
   begin
      Reset_Collector;
      Summary_Content.Append
        ((Kind => LLM.Types.Text_Block,
          Text => To_Unbounded_String ("Checkpoint summary text")));
      Messages.Append
        ((Role      => LLM.Types.Compaction_Summary,
          Content   => Summary_Content,
          Tok_Usage => (others => 0),
          Stop      => LLM.Types.Unknown_Stop,
          Timestamp => Null_Unbounded_String));

      Handle := Spawn_Server (Compaction_Summary_Server_Script (Port));
      Wait_For_Server;

      Send_With_Retry
        (P             => Provider,
         Model_Id      => "summary-model",
         System_Prompt => "",
         Messages      => Messages,
         Tools_Json    => "[]",
         Max_Tokens    => 64,
         Handler       => On_Event'Access);

      Stop_Server (Handle);

      Assert
        (Current_Collector.Last_Stop = LLM.Types.Stop,
         "Compaction summary OpenAI request should complete successfully");
   exception
      when others =>
         Stop_Server (Handle);
         raise;
   end Test_Compaction_Summary_Encodes_As_User_OpenAI;

   procedure Test_Non_Streaming_Response (T : in out Test) is
      pragma Unreferenced (T);

      Port         : constant Positive := 18_771;
      Handle       : Process_Handle := Invalid_Handle;
      Provider     : LLM.Providers.OpenAI_Completions.Provider :=
        LLM.Providers.OpenAI_Completions.Create
          (Base_Url => "http://127.0.0.1:18771",
           Api_Key  => "test-key");
      Messages     : LLM.Types.Message_Vectors.Vector;
      User_Content : LLM.Types.Content_Block_Vectors.Vector;
   begin
      Reset_Collector;
      LLM.Providers.OpenAI_Completions.Testing.Set_Streaming
        (Provider, False);

      User_Content.Append
        ((Kind => LLM.Types.Text_Block,
          Text => To_Unbounded_String ("Say hello without SSE")));
      Messages.Append
        ((Role      => LLM.Types.User,
          Content   => User_Content,
          Tok_Usage => (others => 0),
          Stop      => LLM.Types.Unknown_Stop,
          Timestamp => Null_Unbounded_String));

      Handle := Spawn_Server (Non_Streaming_Server_Script (Port));
      Wait_For_Server;

      Send_With_Retry
        (P             => Provider,
         Model_Id      => "non-stream-model",
         System_Prompt => "",
         Messages      => Messages,
         Tools_Json    => "[]",
         Max_Tokens    => 64,
         Handler       => On_Event'Access);

      Stop_Server (Handle);

      Assert
        (Current_Collector.Sequence.Find_Index ("text_start") > 0,
         "Non-streaming responses should emit Text_Start");
      Assert
        (Current_Collector.Sequence.Find_Index
           ("text_delta:Non-stream hello") > 0,
         "Non-streaming response text should be parsed: "
         & Sequence_Image);
      Assert
        (Current_Collector.Sequence.Find_Index ("text_end") > 0,
         "Non-streaming responses should emit Text_End");
      Assert
        (Current_Collector.Last_Stop = LLM.Types.Stop,
         "Non-streaming finish_reason stop should map to Stop");
      Assert
        (Current_Collector.Usage.Input = 13,
         "Non-streaming usage.Input should be parsed");
      Assert
        (Current_Collector.Usage.Output = 4,
         "Non-streaming usage.Output should be parsed");
   exception
      when others =>
         Stop_Server (Handle);
         raise;
   end Test_Non_Streaming_Response;

   procedure Test_OpenAI_Non_Streaming_Tool_Calls (T : in out Test) is
      pragma Unreferenced (T);

      Port         : constant Positive := 18_796;
      Handle       : Process_Handle := Invalid_Handle;
      Provider     : LLM.Providers.OpenAI_Completions.Provider :=
        LLM.Providers.OpenAI_Completions.Create
          (Base_Url => "http://127.0.0.1:18796",
           Api_Key  => "test-key");
      Messages     : LLM.Types.Message_Vectors.Vector;
      User_Content : LLM.Types.Content_Block_Vectors.Vector;
      Tools_Json   : constant String :=
        "[{""type"":""function"",""function"":{"
        & """name"":""read"",""description"":""Read file"","
        & """parameters"":{""type"":""object"","
        & """properties"":{""path"":{""type"":""string""}},"
        & """required"":[""path""]}}}]";
   begin
      Reset_Collector;
      LLM.Providers.OpenAI_Completions.Testing.Set_Streaming
        (Provider, False);

      User_Content.Append
        ((Kind => LLM.Types.Text_Block,
          Text => To_Unbounded_String ("Use a tool without SSE")));
      Messages.Append
        ((Role      => LLM.Types.User,
          Content   => User_Content,
          Tok_Usage => (others => 0),
          Stop      => LLM.Types.Unknown_Stop,
          Timestamp => Null_Unbounded_String));

      Handle := Spawn_Server (Non_Streaming_Tool_Server_Script (Port));
      Wait_For_Server;

      Send_With_Retry
        (P             => Provider,
         Model_Id      => "non-stream-tool-model",
         System_Prompt => "",
         Messages      => Messages,
         Tools_Json    => Tools_Json,
         Max_Tokens    => 64,
         Handler       => On_Event'Access);

      Stop_Server (Handle);

      Assert
        (Current_Collector.Sequence.Find_Index
           ("tool_call_start:call_1:read") > 0,
         "Non-streaming tool calls should emit Tool_Call_Start: "
         & Sequence_Image);
      Assert
        (Current_Collector.Sequence.Find_Index
           ("tool_call_delta:{""path"":""nonstream.adb""}") > 0,
         "Non-streaming tool calls should emit Tool_Call_Delta: "
         & Sequence_Image);
      Assert
        (Current_Collector.Sequence.Find_Index
           ("tool_call_end:call_1:{""path"":""nonstream.adb""}") > 0,
         "Non-streaming tool calls should emit Tool_Call_End: "
         & Sequence_Image);
      Assert
        (Current_Collector.Last_Stop = LLM.Types.Tool_Use,
         "finish_reason tool_calls should map to Tool_Use");
      Assert
        (Current_Collector.Usage.Input = 14,
         "Non-streaming tool-call usage.Input should be parsed");
      Assert
        (Current_Collector.Usage.Output = 6,
         "Non-streaming tool-call usage.Output should be parsed");
   exception
      when others =>
         Stop_Server (Handle);
         raise;
   end Test_OpenAI_Non_Streaming_Tool_Calls;

   procedure Test_OpenAI_HTTP_Error_Propagates (T : in out Test) is
      pragma Unreferenced (T);

      Port          : constant Positive := 18_797;
      Handle        : Process_Handle := Invalid_Handle;
      Provider      : LLM.Providers.OpenAI_Completions.Provider :=
        LLM.Providers.OpenAI_Completions.Create
          (Base_Url => "http://127.0.0.1:18797",
           Api_Key  => "test-key");
      Messages      : LLM.Types.Message_Vectors.Vector;
      User_Content  : LLM.Types.Content_Block_Vectors.Vector;
      Raised        : Boolean := False;
      Error_Message : Unbounded_String;
   begin
      Reset_Collector;
      User_Content.Append
        ((Kind => LLM.Types.Text_Block,
          Text => To_Unbounded_String ("Trigger an HTTP error")));
      Messages.Append
        ((Role      => LLM.Types.User,
          Content   => User_Content,
          Tok_Usage => (others => 0),
          Stop      => LLM.Types.Unknown_Stop,
          Timestamp => Null_Unbounded_String));

      Handle := Spawn_Server (HTTP_Error_Server_Script (Port));
      Wait_For_Server;

      begin
         Send_With_Retry
           (P             => Provider,
            Model_Id      => "error-model",
            System_Prompt => "",
            Messages      => Messages,
            Tools_Json    => "[]",
            Max_Tokens    => 64,
            Handler       => On_Event'Access);
      exception
         when Error : others =>
            Raised := True;
            Error_Message := To_Unbounded_String
              (Ada.Exceptions.Exception_Message (Error));
      end;

      Stop_Server (Handle);

      Assert (Raised, "OpenAI HTTP 500 should propagate as an exception");
      Assert
        (Ada.Strings.Fixed.Index (To_String (Error_Message), "HTTP 500") > 0,
         "OpenAI HTTP errors should include the status code");
      Assert
        (Current_Collector.Sequence.Length = 3,
         "OpenAI HTTP errors should emit agent_start, message_start,"
         & " and agent_end only: " & Sequence_Image);
      Assert
        (Current_Collector.Sequence.Element (1) = "agent_start",
         "OpenAI HTTP errors should still emit Agent_Start_Event");
      Assert
        (Current_Collector.Sequence.Element (2) = "message_start",
         "OpenAI HTTP errors should still emit Message_Start_Event");
      Assert
        (Current_Collector.Sequence.Element (3) = "agent_end",
         "OpenAI HTTP errors should still emit Agent_End_Event");
   exception
      when others =>
         Stop_Server (Handle);
         raise;
   end Test_OpenAI_HTTP_Error_Propagates;

   procedure Test_OpenAI_Stream_Terminates_Early (T : in out Test) is
      pragma Unreferenced (T);

      Port         : constant Positive := 18_798;
      Handle       : Process_Handle := Invalid_Handle;
      Provider     : LLM.Providers.OpenAI_Completions.Provider :=
        LLM.Providers.OpenAI_Completions.Create
          (Base_Url => "http://127.0.0.1:18798",
           Api_Key  => "test-key");
      Messages     : LLM.Types.Message_Vectors.Vector;
      User_Content : LLM.Types.Content_Block_Vectors.Vector;
   begin
      Reset_Collector;
      User_Content.Append
        ((Kind => LLM.Types.Text_Block,
          Text => To_Unbounded_String ("Handle EOF gracefully")));
      Messages.Append
        ((Role      => LLM.Types.User,
          Content   => User_Content,
          Tok_Usage => (others => 0),
          Stop      => LLM.Types.Unknown_Stop,
          Timestamp => Null_Unbounded_String));

      Handle := Spawn_Server (Early_Close_Server_Script (Port));
      Wait_For_Server;

      Send_With_Retry
        (P             => Provider,
         Model_Id      => "early-close-model",
         System_Prompt => "",
         Messages      => Messages,
         Tools_Json    => "[]",
         Max_Tokens    => 64,
         Handler       => On_Event'Access);

      Stop_Server (Handle);

      Assert
        (Current_Collector.Sequence.Find_Index ("text_delta:partial") > 0,
         "OpenAI should emit the partial streamed text before EOF: "
         & Sequence_Image);
      Assert
        (Current_Collector.Sequence.Find_Index ("text_end") > 0,
         "OpenAI should close an open text block on early EOF: "
         & Sequence_Image);
      Assert
        (Current_Collector.Sequence.Find_Index ("message_end") > 0,
         "OpenAI should finalize the message on early EOF: "
         & Sequence_Image);
      Assert
        (Current_Collector.Sequence.Find_Index ("agent_end") > 0,
         "OpenAI should still emit Agent_End_Event on early EOF: "
         & Sequence_Image);
   exception
      when others =>
         Stop_Server (Handle);
         raise;
   end Test_OpenAI_Stream_Terminates_Early;

end LLM_OpenAI_Completions_Tests;
