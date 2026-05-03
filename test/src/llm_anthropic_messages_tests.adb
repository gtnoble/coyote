with AUnit.Assertions;
with Ada.Characters.Handling;
with Ada.Containers;
with Ada.Containers.Indefinite_Vectors;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Tags;
with Ada.Text_IO;
with GNATCOLL.JSON;
with LLM.Events;
with LLM.HTTP;
with LLM.Providers;
with LLM.Providers.Anthropic_Messages;
with LLM.Types;
with Test_HTTP_Server;

package body LLM_Anthropic_Messages_Tests is

   use AUnit.Assertions;
   use type Ada.Containers.Count_Type;
   use type Ada.Tags.Tag;
   use type GNATCOLL.JSON.JSON_Value_Type;
   use type LLM.Providers.Thinking_Level;
   use type LLM.Types.Stop_Reason;

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

   --  SSE response payload served by the Anthropic capture handler.
   --  Contains thinking + text blocks, end_turn stop reason.
   Anthropic_SSE_Payload : constant String :=
      "event: message_start" & ASCII.LF
      & "data: {""type"":""message_start"","
      & """message"":{""id"":""msg_1"","
      & """type"":""message"",""role"":""assistant"","
      & """content"":[],""usage"":"
      & "{""input_tokens"":11,""output_tokens"":0}}}"
      & ASCII.LF & ASCII.LF
      & "event: content_block_start" & ASCII.LF
      & "data: {""type"":""content_block_start"","
      & """index"":0,""content_block"":{""type"":""thinking""}}"
      & ASCII.LF & ASCII.LF
      & "event: content_block_delta" & ASCII.LF
      & "data: {""type"":""content_block_delta"","
      & """index"":0,""delta"":{""type"":""thinking_delta"","
      & """thinking"":""ponder""}}"
      & ASCII.LF & ASCII.LF
      & "event: content_block_stop" & ASCII.LF
      & "data: {""type"":""content_block_stop"",""index"":0}"
      & ASCII.LF & ASCII.LF
      & "event: content_block_start" & ASCII.LF
      & "data: {""type"":""content_block_start"","
      & """index"":1,""content_block"":{""type"":""text""}}"
      & ASCII.LF & ASCII.LF
      & "event: content_block_delta" & ASCII.LF
      & "data: {""type"":""content_block_delta"","
      & """index"":1,""delta"":{""type"":""text_delta"","
      & """text"":""Hello""}}"
      & ASCII.LF & ASCII.LF
      & "event: content_block_stop" & ASCII.LF
      & "data: {""type"":""content_block_stop"",""index"":1}"
      & ASCII.LF & ASCII.LF
      & "event: message_delta" & ASCII.LF
      & "data: {""type"":""message_delta"","
      & """delta"":{""stop_reason"":""end_turn""},"
      & """usage"":{""output_tokens"":7}}"
      & ASCII.LF & ASCII.LF
      & "event: message_stop" & ASCII.LF
      & "data: {""type"":""message_stop""}"
      & ASCII.LF & ASCII.LF;

   --  SSE response payload for the tool-use test.
   --  partial_json fields contain embedded JSON-escaped double quotes.
   Tool_Use_SSE_Payload : constant String :=
      "event: message_start" & ASCII.LF
      & "data: {""type"":""message_start"","
      & """message"":{""id"":""msg_tool"","
      & """type"":""message"",""role"":""assistant"","
      & """content"":[],""usage"":"
      & "{""input_tokens"":9,""output_tokens"":0}}}"
      & ASCII.LF & ASCII.LF
      & "event: content_block_start" & ASCII.LF
      & "data: {""type"":""content_block_start"","
      & """index"":0,""content_block"":"
      & "{""type"":""tool_use"",""id"":""tool_1"","
      & """name"":""read""}}"
      & ASCII.LF & ASCII.LF
      & "event: content_block_delta" & ASCII.LF
      & "data: {""type"":""content_block_delta"","
      & """index"":0,""delta"":{""type"":""input_json_delta"","
      & """partial_json"":""{\""path\"":\""tool""}}"
      & ASCII.LF & ASCII.LF
      & "event: content_block_delta" & ASCII.LF
      & "data: {""type"":""content_block_delta"","
      & """index"":0,""delta"":{""type"":""input_json_delta"","
      & """partial_json"":""-input.adb\""}""}}"
      & ASCII.LF & ASCII.LF
      & "event: content_block_stop" & ASCII.LF
      & "data: {""type"":""content_block_stop"",""index"":0}"
      & ASCII.LF & ASCII.LF
      & "event: message_delta" & ASCII.LF
      & "data: {""type"":""message_delta"","
      & """delta"":{""stop_reason"":""tool_use""},"
      & """usage"":{""output_tokens"":5}}"
      & ASCII.LF & ASCII.LF
      & "event: message_stop" & ASCII.LF
      & "data: {""type"":""message_stop""}"
      & ASCII.LF & ASCII.LF;

   --  Truncated SSE payload for the early-close test (no message_stop).
   Early_Close_SSE_Payload : constant String :=
      "event: message_start" & ASCII.LF
      & "data: {""type"":""message_start"","
      & """message"":{""id"":""msg_early"","
      & """type"":""message"",""role"":""assistant"","
      & """content"":[],""usage"":"
      & "{""input_tokens"":4,""output_tokens"":0}}}"
      & ASCII.LF & ASCII.LF
      & "event: content_block_start" & ASCII.LF
      & "data: {""type"":""content_block_start"","
      & """index"":0,""content_block"":{""type"":""text""}}"
      & ASCII.LF & ASCII.LF
      & "event: content_block_delta" & ASCII.LF
      & "data: {""type"":""content_block_delta"","
      & """index"":0,""delta"":{""type"":""text_delta"","
      & """text"":""partial""}}"
      & ASCII.LF & ASCII.LF;

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

   --  Build a JSON capture record from Req and write it to Path.
   --  Stores path, headers (lowercased names), and parsed body, mirroring
   --  the Python server scripts that saved these fields for inspection.
   procedure Write_Capture
      (Req  :     Test_HTTP_Server.Request;
       Path : String)
   is
      use GNATCOLL.JSON;
      use Ada.Characters.Handling;

      Root    : constant JSON_Value := Create_Object;
      Hdrs_JS : constant JSON_Value := Create_Object;
      Body_Res : constant Read_Result :=
         Read (To_String (Req.Body_Data));
      File     : Ada.Text_IO.File_Type;
   begin
      Root.Set_Field ("path", To_String (Req.Path));

      for H of Req.Headers loop
         Hdrs_JS.Set_Field
            (To_Lower (To_String (H.Name)),
             To_String (H.Value));
      end loop;

      Root.Set_Field ("headers", Hdrs_JS);

      if Body_Res.Success then
         Root.Set_Field ("body", Body_Res.Value);
      end if;

      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (File, Write (Root));
      Ada.Text_IO.Close (File);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         raise;
   end Write_Capture;

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

   function Build_Compaction_Summary_Messages
     return LLM.Types.Message_Vectors.Vector
   is
      Messages : LLM.Types.Message_Vectors.Vector;
      Content  : LLM.Types.Content_Block_Vectors.Vector;
   begin
      Content.Append
         ((Kind => LLM.Types.Text_Block,
           Text => To_Unbounded_String ("Checkpoint summary text")));
      Messages.Append
         ((Role      => LLM.Types.Compaction_Summary,
           Content   => Content,
           Tok_Usage => (others => 0),
           Stop      => LLM.Types.Unknown_Stop,
           Timestamp => Null_Unbounded_String));
      return Messages;
   end Build_Compaction_Summary_Messages;

   procedure Test_Stream_Thinking_And_Text_Response (T : in out Test) is
      pragma Unreferenced (T);

      Port     : constant Positive := 18_773;
      Capture  : constant String :=
         "/tmp/coyote_anthropic_capture_1.json";
      Provider : LLM.Providers.Anthropic_Messages.Provider :=
         LLM.Providers.Anthropic_Messages.Create
            (Base_Url => "http://127.0.0.1:18773",
             Api_Key  => "test-key");
      Messages : constant LLM.Types.Message_Vectors.Vector :=
         Build_Messages;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
      begin
         Write_Capture (Req, Capture);
         Res.Status := 200;
         Append (Res.Body_Data, Anthropic_SSE_Payload);
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
   begin
      Reset_Collector;
      Delete_If_Exists (Capture);
      Srv.Bind (Port);

      Send_With_Retry
         (P             => Provider,
          Model_Id      => "claude-sonnet-4.6",
          System_Prompt => "Be helpful.",
          Messages      => Messages,
          Thinking      => LLM.Providers.Medium,
          Handler       => On_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

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
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_Stream_Thinking_And_Text_Response;

   procedure Test_Request_Headers (T : in out Test) is
      pragma Unreferenced (T);

      Port     : constant Positive := 18_774;
      Capture  : constant String :=
         "/tmp/coyote_anthropic_capture_2.json";
      Provider : LLM.Providers.Anthropic_Messages.Provider :=
         LLM.Providers.Anthropic_Messages.Create
            (Base_Url => "http://127.0.0.1:18774",
             Api_Key  => "test-key");
      Messages : constant LLM.Types.Message_Vectors.Vector :=
         Build_Messages;
      Request  : GNATCOLL.JSON.JSON_Value;
      Headers  : GNATCOLL.JSON.JSON_Value;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
      begin
         Write_Capture (Req, Capture);
         Res.Status := 200;
         Append (Res.Body_Data, Anthropic_SSE_Payload);
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
   begin
      Delete_If_Exists (Capture);
      Srv.Bind (Port);

      Send_With_Retry
         (P             => Provider,
          Model_Id      => "claude-sonnet-4.6",
          System_Prompt => "Be helpful.",
          Messages      => Messages,
          Thinking      => LLM.Providers.Medium,
          Handler       => null);

      Srv.Stop;
      Server_Stopped := True;

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
         if not Server_Stopped then
            Srv.Stop;
         end if;
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
            Port    : constant Positive := 18_780 + Index;
            Capture : constant String :=
               "/tmp/coyote_anthropic_budget_"
               & Natural_Image (Index) & ".json";
            Provider : LLM.Providers.Anthropic_Messages.Provider :=
               LLM.Providers.Anthropic_Messages.Create
                  (Base_Url => "http://127.0.0.1:"
                   & Natural_Image (Port),
                   Api_Key  => "test-key");
            Request  : GNATCOLL.JSON.JSON_Value;
            Payload  : GNATCOLL.JSON.JSON_Value;

            procedure Handle_Request
              (Req :     Test_HTTP_Server.Request;
               Res : out Test_HTTP_Server.Response)
            is
            begin
               Write_Capture (Req, Capture);
               Res.Status := 200;
               Append (Res.Body_Data, Anthropic_SSE_Payload);
            end Handle_Request;

            Server_Stopped : Boolean := False;
            Srv            : Test_HTTP_Server.Server
              (Handler => Handle_Request'Unrestricted_Access);
         begin
            Delete_If_Exists (Capture);
            Srv.Bind (Port);

            Send_With_Retry
               (P             => Provider,
                Model_Id      => "claude-sonnet-4.6",
                System_Prompt => "Be helpful.",
                Messages      => Messages,
                Thinking      => Cases (Index).Level,
                Handler       => null);

            Srv.Stop;
            Server_Stopped := True;

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
               if not Server_Stopped then
                  Srv.Stop;
               end if;
               raise;
         end;
      end loop;
   end Test_Thinking_Budget_Injection;

   procedure Test_Compaction_Summary_Encodes_As_User_Anthropic
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Port     : constant Positive := 18_789;
      Capture  : constant String :=
         "/tmp/coyote_anthropic_capture_compaction_summary.json";
      Provider : LLM.Providers.Anthropic_Messages.Provider :=
         LLM.Providers.Anthropic_Messages.Create
            (Base_Url => "http://127.0.0.1:18789",
             Api_Key  => "test-key");
      Messages : constant LLM.Types.Message_Vectors.Vector :=
         Build_Compaction_Summary_Messages;
      Request  : GNATCOLL.JSON.JSON_Value;
      Payload  : GNATCOLL.JSON.JSON_Value;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
      begin
         Write_Capture (Req, Capture);
         Res.Status := 200;
         Append (Res.Body_Data, Anthropic_SSE_Payload);
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
   begin
      Delete_If_Exists (Capture);
      Srv.Bind (Port);

      Send_With_Retry
         (P             => Provider,
          Model_Id      => "claude-sonnet-4.6",
          System_Prompt => "",
          Messages      => Messages,
          Thinking      => LLM.Providers.Off,
          Handler       => null);

      Srv.Stop;
      Server_Stopped := True;

      Request := Load_Capture (Capture);
      Payload := Get_Object_Field (Request, "body");

      Assert
         (Payload.Has_Field ("messages"),
          "Anthropic compaction summary test should capture messages");
      Assert
         (Payload.Get ("messages").Kind = GNATCOLL.JSON.JSON_Array_Type,
          "Anthropic captured messages should be a JSON array");

      declare
         Request_Messages : constant GNATCOLL.JSON.JSON_Array :=
            Payload.Get ("messages").Get;
         Message          : constant GNATCOLL.JSON.JSON_Value :=
            GNATCOLL.JSON.Get (Request_Messages, 1);
         Content          : constant GNATCOLL.JSON.JSON_Array :=
            Message.Get ("content").Get;
         Block            : constant GNATCOLL.JSON.JSON_Value :=
            GNATCOLL.JSON.Get (Content, 1);
      begin
         Assert
            (Get_String_Field (Message, "role") = "user",
             "Anthropic should encode compaction summaries as user turns");
         Assert
            (Get_String_Field (Block, "type") = "text",
             "Anthropic compaction summaries should contain text blocks");
         Assert
            (Get_String_Field (Block, "text") = "Checkpoint summary text",
             "Anthropic compaction summary text should round-trip"
             & " into the request body");
      end;
   exception
      when others =>
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_Compaction_Summary_Encodes_As_User_Anthropic;

   procedure Test_Stream_Tool_Use_Response (T : in out Test) is
      pragma Unreferenced (T);

      Port      : constant Positive := 18_790;
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

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 200;
         Append (Res.Body_Data, Tool_Use_SSE_Payload);
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
   begin
      Srv.Bind (Port);

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

      Srv.Stop;
      Server_Stopped := True;

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
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_Stream_Tool_Use_Response;

   procedure Test_Stop_Reason_Mappings (T : in out Test) is
      pragma Unreferenced (T);

      type Stop_Case is record
         Port        : Positive;
         Stop_Reason : String (1 .. 10);
         Expected    : LLM.Types.Stop_Reason;
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
            Provider : LLM.Providers.Anthropic_Messages.Provider :=
               LLM.Providers.Anthropic_Messages.Create
                  (Base_Url => "http://127.0.0.1:"
                   & Natural_Image (Case_Item.Port),
                   Api_Key  => "test-key");
            Last_Stop : LLM.Types.Stop_Reason := LLM.Types.Unknown_Stop;
            Reason    : constant String :=
               Ada.Strings.Fixed.Trim
                  (Case_Item.Stop_Reason, Ada.Strings.Both);
            --  Build an SSE payload with the parameterised stop reason
            --  embedded in the message_delta event.
            Stop_Payload : constant String :=
               "event: message_start" & ASCII.LF
               & "data: {""type"":""message_start"","
               & """message"":{""id"":""msg_stop"","
               & """type"":""message"",""role"":""assistant"","
               & """content"":[],""usage"":"
               & "{""input_tokens"":7,""output_tokens"":0}}}"
               & ASCII.LF & ASCII.LF
               & "event: content_block_start" & ASCII.LF
               & "data: {""type"":""content_block_start"","
               & """index"":0,""content_block"":{""type"":""text""}}"
               & ASCII.LF & ASCII.LF
               & "event: content_block_delta" & ASCII.LF
               & "data: {""type"":""content_block_delta"","
               & """index"":0,""delta"":"
               & "{""type"":""text_delta"",""text"":""Hi""}}"
               & ASCII.LF & ASCII.LF
               & "event: content_block_stop" & ASCII.LF
               & "data: {""type"":""content_block_stop"","
               & """index"":0}"
               & ASCII.LF & ASCII.LF
               & "event: message_delta" & ASCII.LF
               & "data: {""type"":""message_delta"","
               & """delta"":{""stop_reason"":"""
               & Reason
               & """},""usage"":{""output_tokens"":2}}"
               & ASCII.LF & ASCII.LF
               & "event: message_stop" & ASCII.LF
               & "data: {""type"":""message_stop""}"
               & ASCII.LF & ASCII.LF;

            procedure On_Event (E : LLM.Events.Agent_Event'Class) is
            begin
               if E in LLM.Events.Message_End_Event then
                  Last_Stop := LLM.Events.Message_End_Event (E).Stop;
               end if;
            end On_Event;

            procedure Handle_Request
              (Req :     Test_HTTP_Server.Request;
               Res : out Test_HTTP_Server.Response)
            is
               pragma Unreferenced (Req);
            begin
               Res.Status := 200;
               Append (Res.Body_Data, Stop_Payload);
            end Handle_Request;

            Server_Stopped : Boolean := False;
            Srv            : Test_HTTP_Server.Server
              (Handler => Handle_Request'Unrestricted_Access);
         begin
            Srv.Bind (Case_Item.Port);

            Send_With_Retry
               (P             => Provider,
                Model_Id      => "claude-sonnet-4.6",
                System_Prompt => "",
                Messages      => Messages,
                Thinking      => LLM.Providers.Off,
                Handler       => On_Event'Unrestricted_Access);

            Srv.Stop;
            Server_Stopped := True;

            Assert
               (Last_Stop = Case_Item.Expected,
                "Stop reason " & Reason & " should map correctly");
         exception
            when others =>
               if not Server_Stopped then
                  Srv.Stop;
               end if;
               raise;
         end;
      end loop;
   end Test_Stop_Reason_Mappings;

   procedure Test_Anthropic_Uses_X_Api_Key_Header (T : in out Test) is
      pragma Unreferenced (T);

      Port     : constant Positive := 18_793;
      Capture  : constant String :=
         "/tmp/coyote_anthropic_capture_x_api_key.json";
      --  The provider keys off any Base_Url containing the anthropic.com
      --  substring, so a loopback path component exercises the x-api-key
      --  branch without depending on external DNS.
      Provider : LLM.Providers.Anthropic_Messages.Provider :=
         LLM.Providers.Anthropic_Messages.Create
            (Base_Url => "http://127.0.0.1:18793/anthropic.com",
             Api_Key  => "test-key");
      Messages : constant LLM.Types.Message_Vectors.Vector := Build_Messages;
      Request  : GNATCOLL.JSON.JSON_Value;
      Headers  : GNATCOLL.JSON.JSON_Value;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
      begin
         Write_Capture (Req, Capture);
         Res.Status := 200;
         Append (Res.Body_Data, Anthropic_SSE_Payload);
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
   begin
      Delete_If_Exists (Capture);
      Srv.Bind (Port);

      Send_With_Retry
         (P             => Provider,
          Model_Id      => "claude-sonnet-4.6",
          System_Prompt => "Be helpful.",
          Messages      => Messages,
          Thinking      => LLM.Providers.Off,
          Handler       => null);

      Srv.Stop;
      Server_Stopped := True;

      Request := Load_Capture (Capture);
      Headers := Get_Object_Field (Request, "headers");

      Assert
         (Get_String_Field (Headers, "x-api-key") = "test-key",
          "Anthropic direct-style URLs should send x-api-key");
      Assert
         (Get_String_Field (Headers, "authorization") = "",
          "Anthropic direct-style URLs should omit Authorization: Bearer");
   exception
      when others =>
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_Anthropic_Uses_X_Api_Key_Header;

   procedure Test_Anthropic_HTTP_Error_Propagates (T : in out Test) is
      pragma Unreferenced (T);

      Port          : constant Positive := 18_794;
      Provider      : LLM.Providers.Anthropic_Messages.Provider :=
         LLM.Providers.Anthropic_Messages.Create
            (Base_Url => "http://127.0.0.1:18794",
             Api_Key  => "test-key");
      Messages      : constant LLM.Types.Message_Vectors.Vector :=
         Build_Messages;
      Raised        : Boolean := False;
      Error_Message : Unbounded_String;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 500;
         Append (Res.Body_Data, "{""error"":""internal""}");
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
   begin
      Reset_Collector;
      Srv.Bind (Port);

      begin
         Send_With_Retry
            (P             => Provider,
             Model_Id      => "claude-sonnet-4.6",
             System_Prompt => "",
             Messages      => Messages,
             Thinking      => LLM.Providers.Off,
             Handler       => On_Event'Access);
      exception
         when Error : others =>
            Raised := True;
            Error_Message := To_Unbounded_String
               (Ada.Exceptions.Exception_Message (Error));
      end;

      Srv.Stop;
      Server_Stopped := True;

      Assert (Raised, "Anthropic HTTP 500 should propagate as an exception");
      Assert
         (Ada.Strings.Fixed.Index
             (To_String (Error_Message), "HTTP 500") > 0,
          "Anthropic HTTP errors should include the status code");
      Assert
         (Current_Collector.Sequence.Length = 2,
          "Anthropic HTTP errors should only bracket the turn with agent"
          & " events: " & Sequence_Image);
      Assert
         (Current_Collector.Sequence.Element (1) = "agent_start",
          "Anthropic HTTP errors should still emit Agent_Start_Event");
      Assert
         (Current_Collector.Sequence.Element (2) = "agent_end",
          "Anthropic HTTP errors should still emit Agent_End_Event");
   exception
      when others =>
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_Anthropic_HTTP_Error_Propagates;

   procedure Test_Anthropic_Stream_Terminates_Early (T : in out Test) is
      pragma Unreferenced (T);

      Port     : constant Positive := 18_795;
      Provider : LLM.Providers.Anthropic_Messages.Provider :=
         LLM.Providers.Anthropic_Messages.Create
            (Base_Url => "http://127.0.0.1:18795",
             Api_Key  => "test-key");
      Messages : constant LLM.Types.Message_Vectors.Vector := Build_Messages;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 200;
         Append (Res.Body_Data, Early_Close_SSE_Payload);
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
   begin
      Reset_Collector;
      Srv.Bind (Port);

      Send_With_Retry
         (P             => Provider,
          Model_Id      => "claude-sonnet-4.6",
          System_Prompt => "",
          Messages      => Messages,
          Thinking      => LLM.Providers.Off,
          Handler       => On_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Assert
         (Current_Collector.Sequence.Find_Index ("text_delta:partial") > 0,
          "Anthropic should emit any streamed partial text before EOF: "
          & Sequence_Image);
      Assert
         (Current_Collector.Sequence.Find_Index ("text_end") > 0,
          "Anthropic should close an open text block on early EOF: "
          & Sequence_Image);
      Assert
         (Current_Collector.Sequence.Find_Index ("message_end") > 0,
          "Anthropic should finalize the message on early EOF: "
          & Sequence_Image);
      Assert
         (Current_Collector.Sequence.Find_Index ("agent_end") > 0,
          "Anthropic should still emit Agent_End_Event on early EOF: "
          & Sequence_Image);
   exception
      when others =>
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_Anthropic_Stream_Terminates_Early;

end LLM_Anthropic_Messages_Tests;
