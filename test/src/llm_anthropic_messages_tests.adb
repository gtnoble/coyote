with AUnit.Assertions;
with Ada.Containers;
with Ada.Containers.Indefinite_Vectors;
with Ada.Directories;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Tags;
with Ada.Text_IO;
with GNATCOLL.JSON;
with GNATCOLL.OS.Process;   use GNATCOLL.OS.Process;
with LLM.Events;
with LLM.HTTP;
with LLM.Providers;
with LLM.Providers.Anthropic_Messages;
with LLM.Types;

package body LLM_Anthropic_Messages_Tests is

   use AUnit.Assertions;
   use type Ada.Containers.Count_Type;
   use type Ada.Tags.Tag;
   use type GNATCOLL.JSON.JSON_Value_Type;
   use type LLM.Providers.Thinking_Level;
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

   procedure Reset_Collector is
   begin
      Current_Collector.Sequence.Clear;
      Current_Collector.Last_Stop := LLM.Types.Unknown_Stop;
      Current_Collector.Usage := (others => 0);
   end Reset_Collector;

   procedure Collect_Event (E : LLM.Events.Agent_Event'Class) is
   begin
      if E'Tag = LLM.Events.Agent_Start_Event'Tag then
         Current_Collector.Sequence.Append ("agent_start");
      elsif E'Tag = LLM.Events.Message_Start_Event'Tag then
         Current_Collector.Sequence.Append ("message_start");
      elsif E'Tag = LLM.Events.Message_End_Event'Tag then
         declare
            Event : constant LLM.Events.Message_End_Event :=
               LLM.Events.Message_End_Event (E);
         begin
            Current_Collector.Last_Stop := Event.Stop;
            Current_Collector.Usage := Event.Tok_Usage;
            Current_Collector.Sequence.Append ("message_end");
         end;
      elsif E'Tag = LLM.Events.Agent_End_Event'Tag then
         Current_Collector.Sequence.Append ("agent_end");
      elsif E'Tag = LLM.Events.Message_Update_Event'Tag then
         declare
            Event : constant LLM.Events.Message_Update_Event :=
               LLM.Events.Message_Update_Event (E);
         begin
            case Event.Kind is
               when LLM.Events.Thinking_Start =>
                  Current_Collector.Sequence.Append ("thinking_start");
               when LLM.Events.Thinking_Delta =>
                  Current_Collector.Sequence.Append
                     ("thinking_delta:" & To_String (Event.Delta_Text));
               when LLM.Events.Thinking_End =>
                  Current_Collector.Sequence.Append ("thinking_end");
               when LLM.Events.Text_Start =>
                  Current_Collector.Sequence.Append ("text_start");
               when LLM.Events.Text_Delta =>
                  Current_Collector.Sequence.Append
                     ("text_delta:" & To_String (Event.Delta_Text));
               when LLM.Events.Text_End =>
                  Current_Collector.Sequence.Append ("text_end");
               when LLM.Events.Tool_Call_Start =>
                  Current_Collector.Sequence.Append ("tool_call_start");
               when LLM.Events.Tool_Call_Delta =>
                  Current_Collector.Sequence.Append ("tool_call_delta");
               when LLM.Events.Tool_Call_End =>
                  Current_Collector.Sequence.Append ("tool_call_end");
            end case;
         end;
      end if;
   end Collect_Event;

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

   procedure On_Event (E : LLM.Events.Agent_Event'Class) is
   begin
      Collect_Event (E);
   end On_Event;

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
      (P             : in out LLM.Providers.Anthropic_Messages.Provider;
     Model_Id      :        String;
     System_Prompt :        String;
     Messages      :        LLM.Types.Message_Vectors.Vector;
     Thinking      :        LLM.Providers.Thinking_Level;
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
           Tools_Json    => "[]",
           Thinking      => Thinking,
           Max_Tokens    => 128,
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

   procedure Delete_If_Exists (Path : String) is
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_File (Path);
      end if;
   exception
      when others =>
         null;
   end Delete_If_Exists;

   function Load_Capture (Path : String) return GNATCOLL.JSON.JSON_Value is
      Parsed : constant GNATCOLL.JSON.Read_Result := GNATCOLL.JSON.Read
         (Read_File (Path));
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

   function Build_Messages return LLM.Types.Message_Vectors.Vector is
      Messages : LLM.Types.Message_Vectors.Vector;
      Content  : LLM.Types.Content_Block_Vectors.Vector;
   begin
      Content.Append
         ((Kind => LLM.Types.Text_Block,
            Text => To_Unbounded_String ("Explain hello")));
      Messages.Append
         ((Role      => LLM.Types.User,
            Content   => Content,
            Tok_Usage => (others => 0),
            Stop      => LLM.Types.Unknown_Stop,
            Timestamp => Null_Unbounded_String));
      return Messages;
   end Build_Messages;

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
         & " 'content': [], 'usage': {'input_tokens': 11,"
         & " 'output_tokens': 0}}}),"
         & ASCII.LF
         & "    ('content_block_start', {'type': 'content_block_start',"
         & " 'index': 0, 'content_block': {'type': 'thinking'}})," & ASCII.LF
         & "    ('content_block_delta', {'type': 'content_block_delta',"
         & " 'index': 0, 'delta': {'type': 'thinking_delta',"
         & " 'thinking': 'ponder'}})," & ASCII.LF
         & "    ('content_block_stop', {'type': 'content_block_stop',"
         & " 'index': 0})," & ASCII.LF
         & "    ('content_block_start', {'type': 'content_block_start',"
         & " 'index': 1, 'content_block': {'type': 'text'}})," & ASCII.LF
         & "    ('content_block_delta', {'type': 'content_block_delta',"
         & " 'index': 1, 'delta': {'type': 'text_delta', 'text': 'Hello'}}),"
         & ASCII.LF
         & "    ('content_block_stop', {'type': 'content_block_stop',"
         & " 'index': 1})," & ASCII.LF
         & "    ('message_delta', {'type': 'message_delta', 'delta': {"
         & "'stop_reason': 'end_turn'}, 'usage': {'output_tokens': 7}}),"
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

   procedure Test_Stream_Thinking_And_Text_Response (T : in out Test) is
      pragma Unreferenced (T);

      Port        : constant Positive := 18_773;
      Capture     : constant String := "/tmp/pi_acme_anthropic_capture_1.json";
      Handle      : Process_Handle := Invalid_Handle;
      Provider    : LLM.Providers.Anthropic_Messages.Provider :=
         LLM.Providers.Anthropic_Messages.Create
            (Base_Url => "http://127.0.0.1:18773",
             Api_Key  => "test-key");
      Messages    : constant LLM.Types.Message_Vectors.Vector :=
         Build_Messages;
   begin
      Reset_Collector;
      Delete_If_Exists (Capture);
      Handle := Spawn_Server (Anthropic_Server_Script (Port, Capture));
      Wait_For_Server;

      Send_With_Retry
         (P             => Provider,
       Model_Id      => "claude-sonnet-4.6",
       System_Prompt => "Be helpful.",
       Messages      => Messages,
       Thinking      => LLM.Providers.Medium,
       Handler       => On_Event'Access);

      Stop_Server (Handle);

      Assert
         (Current_Collector.Sequence.Length = 10,
       "Expected exact Anthropic event sequence: " & Sequence_Image);
      Assert
         (Current_Collector.Sequence.Element (1) = "agent_start",
       "Agent_Start_Event should fire first");
      Assert
         (Current_Collector.Sequence.Element (2) = "message_start",
       "Message_Start_Event should follow agent_start");
      Assert
         (Current_Collector.Sequence.Element (3) = "thinking_start",
       "Thinking_Start should be emitted");
      Assert
         (Current_Collector.Sequence.Element (4) = "thinking_delta:ponder",
       "Thinking delta should contain the streamed text");
      Assert
         (Current_Collector.Sequence.Element (5) = "thinking_end",
       "Thinking_End should be emitted");
      Assert
         (Current_Collector.Sequence.Element (6) = "text_start",
       "Text_Start should be emitted");
      Assert
         (Current_Collector.Sequence.Element (7) = "text_delta:Hello",
       "Text delta should contain Hello");
      Assert
         (Current_Collector.Sequence.Element (8) = "text_end",
       "Text_End should be emitted");
      Assert
         (Current_Collector.Sequence.Element (9) = "message_end",
       "Message_End_Event should precede agent_end");
      Assert
         (Current_Collector.Sequence.Element (10) = "agent_end",
       "Agent_End_Event should fire last");
      Assert
         (Current_Collector.Sequence.Find_Index ("message_end") > 0,
       "Message_End_Event should be emitted: " & Sequence_Image);
      Assert
         (Current_Collector.Last_Stop = LLM.Types.Stop,
       "end_turn should map to Stop");
      Assert
         (Current_Collector.Usage.Input = 11,
       "Input token usage should be parsed from message_start");
      Assert
         (Current_Collector.Usage.Output = 7,
       "Output token usage should be parsed from message_delta");
   exception
      when others =>
         Stop_Server (Handle);
         raise;
   end Test_Stream_Thinking_And_Text_Response;

   procedure Test_Request_Headers (T : in out Test) is
      pragma Unreferenced (T);

      Port        : constant Positive := 18_774;
      Capture     : constant String := "/tmp/pi_acme_anthropic_capture_2.json";
      Handle      : Process_Handle := Invalid_Handle;
      Provider    : LLM.Providers.Anthropic_Messages.Provider :=
         LLM.Providers.Anthropic_Messages.Create
            (Base_Url => "http://127.0.0.1:18774",
             Api_Key  => "test-key");
      Messages    : constant LLM.Types.Message_Vectors.Vector :=
         Build_Messages;
      Request     : GNATCOLL.JSON.JSON_Value;
      Headers     : GNATCOLL.JSON.JSON_Value;
   begin
      Delete_If_Exists (Capture);
      Handle := Spawn_Server (Anthropic_Server_Script (Port, Capture));
      Wait_For_Server;

      Send_With_Retry
         (P             => Provider,
       Model_Id      => "claude-sonnet-4.6",
       System_Prompt => "Be helpful.",
       Messages      => Messages,
       Thinking      => LLM.Providers.Medium,
       Handler       => null);

      Stop_Server (Handle);

      Request := Load_Capture (Capture);
      Headers := Get_Object_Field (Request, "headers");

      Assert
         (Get_String_Field (Request, "path") = "/v1/messages",
       "Anthropic requests should target /v1/messages");
      Assert
         (Get_String_Field (Headers, "anthropic-version") = "2023-06-01",
       "anthropic-version header should be present");
      Assert
         (Get_String_Field (Headers, "anthropic-beta")
         = "interleaved-thinking-2025-05-14",
       "anthropic-beta header should be present");
      Assert
         (Get_String_Field (Headers, "content-type") = "application/json",
       "Content-Type should be application/json");
   exception
      when others =>
         Stop_Server (Handle);
         raise;
   end Test_Request_Headers;

   procedure Test_Thinking_Budget_Injection (T : in out Test) is
      pragma Unreferenced (T);

      type Budget_Case is record
         Level    : LLM.Providers.Thinking_Level;
         Expected : Natural := 0;
      end record;

      Cases : constant array (Positive range 1 .. 6) of Budget_Case :=
         ((Level => LLM.Providers.Off,     Expected => 0),
       (Level => LLM.Providers.Minimal, Expected => 1_024),
       (Level => LLM.Providers.Low,     Expected => 2_048),
       (Level => LLM.Providers.Medium,  Expected => 8_192),
       (Level => LLM.Providers.High,    Expected => 16_384),
       (Level => LLM.Providers.X_High,  Expected => 32_768));
      Messages : constant LLM.Types.Message_Vectors.Vector := Build_Messages;
   begin
      for Index in Cases'Range loop
         declare
            Port      : constant Positive := 18_780 + Index;
            Port_Text : constant String := Natural_Image (Port);
            Capture   : constant String :=
               "/tmp/pi_acme_anthropic_budget_" & Natural_Image (Index)
               & ".json";
            Handle    : Process_Handle := Invalid_Handle;
            Provider  : LLM.Providers.Anthropic_Messages.Provider :=
               LLM.Providers.Anthropic_Messages.Create
                  (Base_Url => "http://127.0.0.1:" & Port_Text,
             Api_Key  => "test-key");
            Request   : GNATCOLL.JSON.JSON_Value;
            Payload    : GNATCOLL.JSON.JSON_Value;
         begin
            Delete_If_Exists (Capture);
            Handle := Spawn_Server (Anthropic_Server_Script (Port, Capture));
            Wait_For_Server;

            Send_With_Retry
               (P             => Provider,
           Model_Id      => "claude-sonnet-4.6",
           System_Prompt => "Be helpful.",
           Messages      => Messages,
           Thinking      => Cases (Index).Level,
           Handler       => null);

            Stop_Server (Handle);

            Request := Load_Capture (Capture);
            Payload := Get_Object_Field (Request, "body");

            if Cases (Index).Level = LLM.Providers.Off then
               Assert
                  (not Payload.Has_Field ("thinking"),
             "Thinking field should be omitted when level is Off");
            else
               declare
                  Thinking : constant GNATCOLL.JSON.JSON_Value :=
                     Get_Object_Field (Payload, "thinking");
               begin
                  Assert
                     (Get_String_Field (Thinking, "type") = "enabled",
               "Thinking payload should enable Anthropic thinking");
                  Assert
                     (Get_Natural_Field (Thinking, "budget_tokens")
                 = Cases (Index).Expected,
               "Thinking budget mismatch for case "
               & Natural_Image (Index));
               end;
            end if;
         exception
            when others =>
               Stop_Server (Handle);
               raise;
         end;
      end loop;
   end Test_Thinking_Budget_Injection;

   function Tool_Use_Server_Script (Port : Positive) return String is
   begin
      return
         "import http.server, json" & ASCII.LF
         & "events = [" & ASCII.LF
         & "    ('message_start', {'type': 'message_start', 'message': {"
         & "'id': 'msg_tool', 'type': 'message', 'role': 'assistant',"
         & " 'content': [], 'usage': {'input_tokens': 9,"
         & " 'output_tokens': 0}}})," & ASCII.LF
         & "    ('content_block_start', {'type': 'content_block_start',"
         & " 'index': 0, 'content_block': {'type': 'tool_use',"
         & " 'id': 'tool_1', 'name': 'read'}})," & ASCII.LF
         & "    ('content_block_delta', {'type': 'content_block_delta',"
         & " 'index': 0, 'delta': {'type': 'input_json_delta',"
         & " 'partial_json': '{""path"":""tool'}})," & ASCII.LF
         & "    ('content_block_delta', {'type': 'content_block_delta',"
         & " 'index': 0, 'delta': {'type': 'input_json_delta',"
         & " 'partial_json': '-input.adb""}'}})," & ASCII.LF
         & "    ('content_block_stop', {'type': 'content_block_stop',"
         & " 'index': 0})," & ASCII.LF
         & "    ('message_delta', {'type': 'message_delta', 'delta': {"
         & "'stop_reason': 'tool_use'}, 'usage': {'output_tokens': 5}}),"
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
         & "            assert self.path == '/v1/messages'" & ASCII.LF
         & "            assert len(body['tools']) == 1" & ASCII.LF
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
   end Tool_Use_Server_Script;

   function Stop_Reason_Server_Script
      (Port        : Positive;
       Stop_Reason : String) return String
   is
   begin
      return
         "import http.server, json" & ASCII.LF
         & "events = [" & ASCII.LF
         & "    ('message_start', {'type': 'message_start', 'message': {"
         & "'id': 'msg_stop', 'type': 'message', 'role': 'assistant',"
         & " 'content': [], 'usage': {'input_tokens': 7,"
         & " 'output_tokens': 0}}})," & ASCII.LF
         & "    ('content_block_start', {'type': 'content_block_start',"
         & " 'index': 0, 'content_block': {'type': 'text'}})," & ASCII.LF
         & "    ('content_block_delta', {'type': 'content_block_delta',"
         & " 'index': 0, 'delta': {'type': 'text_delta', 'text': 'Hi'}}),"
         & ASCII.LF
         & "    ('content_block_stop', {'type': 'content_block_stop',"
         & " 'index': 0})," & ASCII.LF
         & "    ('message_delta', {'type': 'message_delta', 'delta': {"
         & "'stop_reason': '" & Stop_Reason & "'},"
         & " 'usage': {'output_tokens': 2}})," & ASCII.LF
         & "    ('message_stop', {'type': 'message_stop'})]" & ASCII.LF
         & "payload = ''.join(" & ASCII.LF
         & "    'event: ' + name + '\n' + 'data: ' + json.dumps(data)"
         & " + '\n\n' for name, data in events).encode()" & ASCII.LF
         & "class S(http.server.HTTPServer):" & ASCII.LF
         & "    allow_reuse_address = True" & ASCII.LF
         & "class H(http.server.BaseHTTPRequestHandler):" & ASCII.LF
         & "    def do_POST(self):" & ASCII.LF
         & "        try:" & ASCII.LF
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
   end Stop_Reason_Server_Script;

   procedure Test_Stream_Tool_Use_Response (T : in out Test) is
      pragma Unreferenced (T);

      Port      : constant Positive := 18_790;
      Handle    : Process_Handle := Invalid_Handle;
      Provider  : LLM.Providers.Anthropic_Messages.Provider :=
         LLM.Providers.Anthropic_Messages.Create
            (Base_Url => "http://127.0.0.1:18790",
             Api_Key  => "test-key");
      Messages  : constant LLM.Types.Message_Vectors.Vector :=
         Build_Messages;
      Sequence  : String_Vectors.Vector;
      Last_Stop : LLM.Types.Stop_Reason := LLM.Types.Unknown_Stop;
      Tools_Json : constant String :=
         "[{""name"":""read"",""description"":""Read file"","
         & """input_schema"":{""type"":""object"","
         & """properties"":{""path"":{""type"":""string""}},"
         & """required"": [""path""]}}]";

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         if E in LLM.Events.Message_Update_Event then
            declare
               Event : constant LLM.Events.Message_Update_Event :=
                  LLM.Events.Message_Update_Event (E);
            begin
               case Event.Kind is
                  when LLM.Events.Tool_Call_Start =>
                     Sequence.Append
                        ("tool_call_start:" & To_String (Event.Tool_Call_Id)
                         & ":" & To_String (Event.Tool_Name));
                  when LLM.Events.Tool_Call_Delta =>
                     Sequence.Append
                        ("tool_call_delta:" & To_String (Event.Delta_Text));
                  when LLM.Events.Tool_Call_End =>
                     Sequence.Append
                        ("tool_call_end:" & To_String (Event.Tool_Call_Id)
                         & ":" & To_String (Event.Tool_Name)
                         & ":" & To_String (Event.Delta_Text));
                  when others =>
                     null;
               end case;
            end;
         elsif E in LLM.Events.Message_End_Event then
            Last_Stop := LLM.Events.Message_End_Event (E).Stop;
         end if;
      end On_Event;
   begin
      Handle := Spawn_Server (Tool_Use_Server_Script (Port));
      Wait_For_Server;

      Retry_Loop :
      for Attempt in 1 .. 20 loop
         begin
            Provider.Send
               (Model_Id      => "claude-sonnet-4.6",
                System_Prompt => "Be helpful.",
                Messages      => Messages,
                Tools_Json    => Tools_Json,
                Thinking      => LLM.Providers.Off,
                Max_Tokens    => 128,
                Handler       => On_Event'Unrestricted_Access);
            exit Retry_Loop;
         exception
            when LLM.HTTP.Curl_Error =>
               if Attempt = 20 then
                  raise;
               end if;

               delay 0.05;
         end;
      end loop Retry_Loop;

      Stop_Server (Handle);

      Assert
         (Sequence.Find_Index ("tool_call_start:tool_1:read") > 0,
          "Tool_Call_Start should include the streamed id/name");
      Assert
         (Sequence.Find_Index ("tool_call_delta:{""path"":""tool") > 0,
          "First Tool_Call_Delta should carry the partial JSON fragment");
      Assert
         (Sequence.Find_Index ("tool_call_delta:-input.adb""}") > 0,
          "Second Tool_Call_Delta should carry the closing JSON fragment");
      Assert
         (Sequence.Find_Index
             ("tool_call_end:tool_1:read:{""path"":""tool-input.adb""}")
           > 0,
          "Tool_Call_End should carry the assembled tool input JSON");
      Assert
         (Last_Stop = LLM.Types.Tool_Use,
          "Anthropic tool_use should map to Tool_Use");
   exception
      when others =>
         Stop_Server (Handle);
         raise;
   end Test_Stream_Tool_Use_Response;

   procedure Test_Stop_Reason_Mappings (T : in out Test) is
      pragma Unreferenced (T);

      type Stop_Case is record
         Port         : Positive;
         Stop_Reason  : String (1 .. 10);
         Expected     : LLM.Types.Stop_Reason;
      end record;

      Cases : constant array (Positive range 1 .. 2) of Stop_Case :=
         ((Port        => 18_791,
           Stop_Reason => "tool_use  ",
           Expected    => LLM.Types.Tool_Use),
          (Port        => 18_792,
           Stop_Reason => "max_tokens",
           Expected    => LLM.Types.Length));
      Messages : constant LLM.Types.Message_Vectors.Vector := Build_Messages;
   begin
      for Case_Item of Cases loop
         declare
            Handle    : Process_Handle := Invalid_Handle;
            Provider  : LLM.Providers.Anthropic_Messages.Provider :=
               LLM.Providers.Anthropic_Messages.Create
                  (Base_Url => "http://127.0.0.1:"
                   & Natural_Image (Case_Item.Port),
                   Api_Key  => "test-key");
            Last_Stop : LLM.Types.Stop_Reason := LLM.Types.Unknown_Stop;

            procedure On_Event (E : LLM.Events.Agent_Event'Class) is
            begin
               if E in LLM.Events.Message_End_Event then
                  Last_Stop := LLM.Events.Message_End_Event (E).Stop;
               end if;
            end On_Event;
         begin
            Handle := Spawn_Server
               (Stop_Reason_Server_Script
                  (Port        => Case_Item.Port,
                   Stop_Reason => Ada.Strings.Fixed.Trim
                     (Case_Item.Stop_Reason, Ada.Strings.Both)));
            Wait_For_Server;

            Send_With_Retry
               (P             => Provider,
                Model_Id      => "claude-sonnet-4.6",
                System_Prompt => "",
                Messages      => Messages,
                Thinking      => LLM.Providers.Off,
                Handler       => On_Event'Unrestricted_Access);

            Stop_Server (Handle);

            Assert
               (Last_Stop = Case_Item.Expected,
                "Stop reason "
                & Ada.Strings.Fixed.Trim
                    (Case_Item.Stop_Reason, Ada.Strings.Both)
                & " should map correctly");
         exception
            when others =>
               Stop_Server (Handle);
               raise;
         end;
      end loop;
   end Test_Stop_Reason_Mappings;

end LLM_Anthropic_Messages_Tests;
