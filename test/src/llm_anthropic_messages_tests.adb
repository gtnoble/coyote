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
      Sequence             : String_Vectors.Vector;
      Last_Stop            : LLM.Types.Stop_Reason := LLM.Types.Unknown_Stop;
      Usage                : LLM.Types.Usage := (others => 0);
      Last_Thinking_Sig    : Unbounded_String;
   end record;

   Current_Collector : Event_Collector;

   function Natural_Image (Value : Natural) return String is
      Image : constant String := Natural'Image (Value);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Natural_Image;

   function Event_Record
      (Event_Name : String;
       Data       : GNATCOLL.JSON.JSON_Value) return String
   is
   begin
      return "event: " & Event_Name & ASCII.LF
         & "data: " & GNATCOLL.JSON.Write (Data)
         & ASCII.LF & ASCII.LF;
   end Event_Record;

   function Build_Tool_Use_SSE_Payload return String is
      use GNATCOLL.JSON;

      Message_Start     : constant JSON_Value := Create_Object;
      Message_Value     : constant JSON_Value := Create_Object;
      Message_Usage     : constant JSON_Value := Create_Object;
      Content_Block_1   : constant JSON_Value := Create_Object;
      Block_Start       : constant JSON_Value := Create_Object;
      Delta_Event_1     : constant JSON_Value := Create_Object;
      Delta_Value_1     : constant JSON_Value := Create_Object;
      Delta_Event_2     : constant JSON_Value := Create_Object;
      Delta_Value_2     : constant JSON_Value := Create_Object;
      Block_Stop        : constant JSON_Value := Create_Object;
      Message_Delta     : constant JSON_Value := Create_Object;
      Message_Delta_Val : constant JSON_Value := Create_Object;
      Delta_Usage       : constant JSON_Value := Create_Object;
      Message_Stop      : constant JSON_Value := Create_Object;
   begin
      Message_Start.Set_Field ("type", "message_start");
      Message_Value.Set_Field ("id", "msg_tool");
      Message_Value.Set_Field ("type", "message");
      Message_Value.Set_Field ("role", "assistant");
      Message_Value.Set_Field ("content", Empty_Array);
      Message_Usage.Set_Field ("input_tokens", Integer (9));
      Message_Usage.Set_Field ("output_tokens", Integer (0));
      Message_Value.Set_Field ("usage", Message_Usage);
      Message_Start.Set_Field ("message", Message_Value);

      Block_Start.Set_Field ("type", "content_block_start");
      Block_Start.Set_Field ("index", Integer (0));
      Content_Block_1.Set_Field ("type", "tool_use");
      Content_Block_1.Set_Field ("id", "tool_1");
      Content_Block_1.Set_Field ("name", "read");
      Block_Start.Set_Field ("content_block", Content_Block_1);

      Delta_Event_1.Set_Field ("type", "content_block_delta");
      Delta_Event_1.Set_Field ("index", Integer (0));
      Delta_Value_1.Set_Field ("type", "input_json_delta");
      Delta_Value_1.Set_Field ("partial_json", "{""path"":""tool");
      Delta_Event_1.Set_Field ("delta", Delta_Value_1);

      Delta_Event_2.Set_Field ("type", "content_block_delta");
      Delta_Event_2.Set_Field ("index", Integer (0));
      Delta_Value_2.Set_Field ("type", "input_json_delta");
      Delta_Value_2.Set_Field ("partial_json", "-input.adb""}");
      Delta_Event_2.Set_Field ("delta", Delta_Value_2);

      Block_Stop.Set_Field ("type", "content_block_stop");
      Block_Stop.Set_Field ("index", Integer (0));

      Message_Delta.Set_Field ("type", "message_delta");
      Message_Delta_Val.Set_Field ("stop_reason", "tool_use");
      Message_Delta.Set_Field ("delta", Message_Delta_Val);
      Delta_Usage.Set_Field ("output_tokens", Integer (5));
      Message_Delta.Set_Field ("usage", Delta_Usage);

      Message_Stop.Set_Field ("type", "message_stop");

      return Event_Record ("message_start", Message_Start)
         & Event_Record ("content_block_start", Block_Start)
         & Event_Record ("content_block_delta", Delta_Event_1)
         & Event_Record ("content_block_delta", Delta_Event_2)
         & Event_Record ("content_block_stop", Block_Stop)
         & Event_Record ("message_delta", Message_Delta)
         & Event_Record ("message_stop", Message_Stop);
   end Build_Tool_Use_SSE_Payload;

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
   --  partial_json fields are emitted from JSON builders.
   Tool_Use_SSE_Payload : constant String := Build_Tool_Use_SSE_Payload;

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
      Current_Collector.Last_Thinking_Sig := Null_Unbounded_String;
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
                  Current_Collector.Last_Thinking_Sig := Event.Signature;
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
       Handler       :        LLM.Providers.Event_Handler;
       Tools_Json   :        String := "[]")
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

   function Get_Array_Field
      (Value : GNATCOLL.JSON.JSON_Value;
       Field : String) return GNATCOLL.JSON.JSON_Array
   is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
         and then Value.Has_Field (Field)
         and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_Array_Type
      then
         return Value.Get (Field).Get;
      end if;

      return GNATCOLL.JSON.Empty_Array;
   end Get_Array_Field;

   function Parse_Json
      (Data    : String;
       Context : String) return GNATCOLL.JSON.JSON_Value
   is
      Result : constant GNATCOLL.JSON.Read_Result := GNATCOLL.JSON.Read (Data);
   begin
      if not Result.Success then
         raise Constraint_Error with
            Context & ": " & GNATCOLL.JSON.Format_Parsing_Error (Result.Error);
      end if;

      return Result.Value;
   end Parse_Json;

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

   --  ── Test_Signature_Parsed_From_SSE ───────────────────────────────────
   --  Verify that a signature_delta event in the SSE stream is captured
   --  and delivered in the Thinking_End Message_Update_Event.Signature field.

   procedure Test_Signature_Parsed_From_SSE (T : in out Test) is
      pragma Unreferenced (T);

      --  Minimal SSE payload: one thinking block with both a thinking_delta
      --  and a signature_delta, followed by a message_delta + message_stop.
      SSE_With_Signature : constant String :=
         "event: message_start" & ASCII.LF
         & "data: {""type"":""message_start"","
         & """message"":{""id"":""msg_sig"","
         & """type"":""message"",""role"":""assistant"","
         & """content"":[],""usage"":"
         & "{""input_tokens"":5,""output_tokens"":0}}}"
         & ASCII.LF & ASCII.LF
         & "event: content_block_start" & ASCII.LF
         & "data: {""type"":""content_block_start"","
         & """index"":0,""content_block"":{""type"":""thinking""}}"
         & ASCII.LF & ASCII.LF
         & "event: content_block_delta" & ASCII.LF
         & "data: {""type"":""content_block_delta"","
         & """index"":0,""delta"":{""type"":""thinking_delta"","
         & """thinking"":""I reason""}}"
         & ASCII.LF & ASCII.LF
         & "event: content_block_delta" & ASCII.LF
         & "data: {""type"":""content_block_delta"","
         & """index"":0,""delta"":{""type"":""signature_delta"","
         & """signature"":""sig-xyz-123""}}"
         & ASCII.LF & ASCII.LF
         & "event: content_block_stop" & ASCII.LF
         & "data: {""type"":""content_block_stop"",""index"":0}"
         & ASCII.LF & ASCII.LF
         & "event: message_delta" & ASCII.LF
         & "data: {""type"":""message_delta"","
         & """delta"":{""stop_reason"":""end_turn""},"
         & """usage"":{""output_tokens"":3}}"
         & ASCII.LF & ASCII.LF
         & "event: message_stop" & ASCII.LF
         & "data: {""type"":""message_stop""}"
         & ASCII.LF & ASCII.LF;

      Port     : constant Positive := 18_774;
      Provider : LLM.Providers.Anthropic_Messages.Provider :=
         LLM.Providers.Anthropic_Messages.Create
            (Base_Url => "http://127.0.0.1:18774",
             Api_Key  => "test-key");
      Messages : constant LLM.Types.Message_Vectors.Vector :=
         Build_Messages;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 200;
         Append (Res.Body_Data, SSE_With_Signature);
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
   begin
      Reset_Collector;
      Srv.Bind (Port);

      Send_With_Retry
         (P             => Provider,
          Model_Id      => "claude-sonnet-4-5",
          System_Prompt => "Be helpful.",
          Messages      => Messages,
          Thinking      => LLM.Providers.Medium,
          Handler       => On_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Assert
         (To_String (Current_Collector.Last_Thinking_Sig) = "sig-xyz-123",
          "Signature from signature_delta should be delivered in "
          & "Thinking_End event; got: "
          & To_String (Current_Collector.Last_Thinking_Sig));
   exception
      when others =>
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_Signature_Parsed_From_SSE;

   --  ── Test_Thinking_Block_Serialised_In_Request ─────────────────────────
   --  Verify that when the history contains an assistant message with a
   --  Thinking_Block (carrying a signature), the outgoing request body
   --  includes a content item of type "thinking" with both the thinking text
   --  and the signature echoed back verbatim.

   procedure Test_Thinking_Block_Serialised_In_Request (T : in out Test) is
      pragma Unreferenced (T);

      Port     : constant Positive := 18_775;
      Capture  : constant String :=
         "/tmp/coyote_anthropic_thinking_request.json";

      --  History: assistant message with a thinking block + text block,
      --  as would appear after a previous sub-turn in the agentic loop.
      function Build_History return LLM.Types.Message_Vectors.Vector is
         Messages      : LLM.Types.Message_Vectors.Vector;
         User_Content  : LLM.Types.Content_Block_Vectors.Vector;
         Asst_Content  : LLM.Types.Content_Block_Vectors.Vector;
      begin
         User_Content.Append
            ((Kind => LLM.Types.Text_Block,
              Text => To_Unbounded_String ("What is 2+2?")));
         Messages.Append
            ((Role      => LLM.Types.User,
              Content   => User_Content,
              Tok_Usage => (others => 0),
              Stop      => LLM.Types.Unknown_Stop,
              Timestamp => Null_Unbounded_String));

         Asst_Content.Append
            ((Kind      => LLM.Types.Thinking_Block,
              Thinking  => To_Unbounded_String ("Let me add these."),
              Signature => To_Unbounded_String ("opaque-sig-abc")));
         Asst_Content.Append
            ((Kind => LLM.Types.Text_Block,
              Text => To_Unbounded_String ("The answer is 4.")));
         Messages.Append
            ((Role      => LLM.Types.Assistant,
              Content   => Asst_Content,
              Tok_Usage => (others => 0),
              Stop      => LLM.Types.Stop,
              Timestamp => Null_Unbounded_String));

         return Messages;
      end Build_History;

      --  Minimal SSE response — content is irrelevant for this test.
      Minimal_SSE : constant String :=
         "event: message_start" & ASCII.LF
         & "data: {""type"":""message_start"","
         & """message"":{""id"":""msg_x"","
         & """type"":""message"",""role"":""assistant"","
         & """content"":[],""usage"":"
         & "{""input_tokens"":10,""output_tokens"":0}}}"
         & ASCII.LF & ASCII.LF
         & "event: content_block_start" & ASCII.LF
         & "data: {""type"":""content_block_start"","
         & """index"":0,""content_block"":{""type"":""text""}}"
         & ASCII.LF & ASCII.LF
         & "event: content_block_delta" & ASCII.LF
         & "data: {""type"":""content_block_delta"","
         & """index"":0,""delta"":{""type"":""text_delta"","
         & """text"":""OK""}}"
         & ASCII.LF & ASCII.LF
         & "event: content_block_stop" & ASCII.LF
         & "data: {""type"":""content_block_stop"",""index"":0}"
         & ASCII.LF & ASCII.LF
         & "event: message_delta" & ASCII.LF
         & "data: {""type"":""message_delta"","
         & """delta"":{""stop_reason"":""end_turn""},"
         & """usage"":{""output_tokens"":1}}"
         & ASCII.LF & ASCII.LF
         & "event: message_stop" & ASCII.LF
         & "data: {""type"":""message_stop""}"
         & ASCII.LF & ASCII.LF;

      Provider : LLM.Providers.Anthropic_Messages.Provider :=
         LLM.Providers.Anthropic_Messages.Create
            (Base_Url => "http://127.0.0.1:18775",
             Api_Key  => "test-key");
      Messages : constant LLM.Types.Message_Vectors.Vector :=
         Build_History;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
      begin
         Write_Capture (Req, Capture);
         Res.Status := 200;
         Append (Res.Body_Data, Minimal_SSE);
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
          Model_Id      => "claude-sonnet-4-5",
          System_Prompt => "Be helpful.",
          Messages      => Messages,
          Thinking      => LLM.Providers.Medium,
          Handler       => On_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      declare
         use GNATCOLL.JSON;

         Captured  : constant JSON_Value :=
            Parse_Json (Read_File (Capture), "captured request");
         Body_Val  : constant JSON_Value :=
            Get_Object_Field (Captured, "body");
         Msg_Array : constant JSON_Array :=
            Get_Array_Field (Body_Val, "messages");
         --  messages[0] = system(skipped), [1] = user, [2] = assistant
         Asst_Msg  : constant JSON_Value :=
            GNATCOLL.JSON.Get (Msg_Array, 2);
         Content   : constant JSON_Array :=
            Get_Array_Field (Asst_Msg, "content");
         --  First content item should be the thinking block.
         Think_Item : constant JSON_Value :=
            GNATCOLL.JSON.Get (Content, 1);
      begin
         Assert
            (Get_String_Field (Think_Item, "type") = "thinking",
             "First assistant content item should have type=thinking");
         Assert
            (Get_String_Field (Think_Item, "thinking") = "Let me add these.",
             "Thinking text should be echoed verbatim");
         Assert
            (Get_String_Field (Think_Item, "signature") = "opaque-sig-abc",
             "Signature should be echoed verbatim; got: "
             & Get_String_Field (Think_Item, "signature"));
      end;
   exception
      when others =>
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_Thinking_Block_Serialised_In_Request;
   --  ── Test_Tool_Result_Is_Error_Serialised ──────────────────────────────
   --  Verify that a Tool_Result message with Is_Error = True emits the
   --  "is_error" field in the Anthropic wire format so the model receives
   --  an explicit failure signal.

   procedure Test_Tool_Result_Is_Error_Serialised (T : in out Test) is
      pragma Unreferenced (T);

      Port     : constant Positive := 18_796;
      Capture  : constant String :=
         "/tmp/coyote_anthropic_tool_result_is_error.json";

      --  Build a conversation: user -> assistant (tool_call) -> tool_result.
      function Build_Tool_Result_Messages
         return LLM.Types.Message_Vectors.Vector
      is
         Messages      : LLM.Types.Message_Vectors.Vector;
         User_Content  : LLM.Types.Content_Block_Vectors.Vector;
         Asst_Content  : LLM.Types.Content_Block_Vectors.Vector;
         Result_Content : LLM.Types.Content_Block_Vectors.Vector;
      begin
         --  User message
         User_Content.Append
            ((Kind => LLM.Types.Text_Block,
              Text => To_Unbounded_String ("Run the tool")));
         Messages.Append
            ((Role      => LLM.Types.User,
              Content   => User_Content,
              Tok_Usage => (others => 0),
              Stop      => LLM.Types.Unknown_Stop,
              Timestamp => Null_Unbounded_String));

         --  Assistant message with a tool call
         Asst_Content.Append
            ((Kind          => LLM.Types.Tool_Call_Block,
              Tool_Call_Id   => To_Unbounded_String ("tool_abc"),
              Tool_Name      => To_Unbounded_String ("shell"),
              Arguments_Json => To_Unbounded_String
                 ("{""command"":""bad_cmd""}")));
         Messages.Append
            ((Role      => LLM.Types.Assistant,
              Content   => Asst_Content,
              Tok_Usage => (others => 0),
              Stop      => LLM.Types.Tool_Use,
              Timestamp => Null_Unbounded_String));

         --  Tool result with Is_Error = True
         Result_Content.Append
            ((Kind        => LLM.Types.Tool_Result_Block,
              Result_Id   => To_Unbounded_String ("tool_abc"),
              Result_Text => To_Unbounded_String
                 ("invalid JSON arguments for shell tool"),
              Media_Type  => Null_Unbounded_String,
              Is_Error    => True));
         Messages.Append
            ((Role      => LLM.Types.Tool_Result,
              Content   => Result_Content,
              Tok_Usage => (others => 0),
              Stop      => LLM.Types.Unknown_Stop,
              Timestamp => Null_Unbounded_String));

         return Messages;
      end Build_Tool_Result_Messages;

      Provider : LLM.Providers.Anthropic_Messages.Provider :=
         LLM.Providers.Anthropic_Messages.Create
            (Base_Url => "http://127.0.0.1:18796",
             Api_Key  => "test-key");
      Messages : constant LLM.Types.Message_Vectors.Vector :=
         Build_Tool_Result_Messages;

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
          Model_Id      => "claude-sonnet-4-5",
          System_Prompt => "",
          Messages      => Messages,
          Thinking      => LLM.Providers.Off,
          Handler       => null);

      Srv.Stop;
      Server_Stopped := True;

      declare
         use GNATCOLL.JSON;

         Captured  : constant JSON_Value :=
            Parse_Json (Read_File (Capture), "captured request");
         Body_Val  : constant JSON_Value :=
            Get_Object_Field (Captured, "body");
         Msg_Array : constant JSON_Array :=
            Get_Array_Field (Body_Val, "messages");
         --  messages: user, assistant, tool_result (as user role)
         Tool_Msg  : constant JSON_Value :=
            GNATCOLL.JSON.Get (Msg_Array, 3);
         Content_Arr : constant JSON_Array :=
            Get_Array_Field (Tool_Msg, "content");
         Block      : constant JSON_Value :=
            GNATCOLL.JSON.Get (Content_Arr, 1);
      begin
         Assert
            (Get_String_Field (Block, "type") = "tool_result",
             "Tool result block should have type=tool_result");
         Assert
            (Get_String_Field (Block, "tool_use_id") = "tool_abc",
             "Tool result block should carry tool_use_id=tool_abc");
         Assert
            (Block.Has_Field ("is_error"),
             "Tool result block should include is_error field");
         Assert
            (Block.Get ("is_error").Kind = JSON_Boolean_Type
             and then Block.Get ("is_error").Get,
             "is_error should be true for a failed tool result");
      end;
   exception
      when others =>
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_Tool_Result_Is_Error_Serialised;

   --  ── Test_System_Prompt_Is_Content_Block_Array ──────────────────────────
   --  Verify that the system prompt is serialised as an array of content
   --  blocks with cache_control rather than a plain string, matching the
   --  Anthropic prompt-caching wire format.

   procedure Test_System_Prompt_Is_Content_Block_Array (T : in out Test) is
      pragma Unreferenced (T);

      Port     : constant Positive := 18_797;
      Capture  : constant String :=
         "/tmp/coyote_anthropic_cache_system.json";
      Provider : LLM.Providers.Anthropic_Messages.Provider :=
         LLM.Providers.Anthropic_Messages.Create
            (Base_Url => "http://127.0.0.1:18797",
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
      Delete_If_Exists (Capture);
      Srv.Bind (Port);

      Send_With_Retry
         (P             => Provider,
          Model_Id      => "claude-sonnet-4-5",
          System_Prompt => "You are a helpful assistant.",
          Messages      => Messages,
          Thinking      => LLM.Providers.Off,
          Handler       => null);

      Srv.Stop;
      Server_Stopped := True;

      declare
         use GNATCOLL.JSON;

         Captured     : constant JSON_Value :=
            Parse_Json (Read_File (Capture), "captured request");
         Body_Val     : constant JSON_Value :=
            Get_Object_Field (Captured, "body");
         System_Field : constant JSON_Value := Body_Val.Get ("system");
      begin
         --  system should be an array, not a string
         Assert
           (System_Field.Kind = JSON_Array_Type,
            "system field should be a JSON array for caching; got type "
            & JSON_Value_Type'Image (System_Field.Kind));

         declare
            Blocks : constant JSON_Array := System_Field.Get;
         begin
            Assert
              (Length (Blocks) = 1,
               "system array should have exactly one block");

            declare
               Block : constant JSON_Value := Get (Blocks, 1);
               CC    : constant JSON_Value :=
                 Get_Object_Field (Block, "cache_control");
            begin
               Assert
                 (Get_String_Field (Block, "type") = "text",
                  "system block type should be text");
               Assert
                 (Get_String_Field (Block, "text")
                  = "You are a helpful assistant.",
                  "system block text should match the prompt");
               Assert
                 (CC.Kind = JSON_Object_Type
                  and then Get_String_Field (CC, "type") = "ephemeral",
                  "system block should have cache_control ephemeral");
            end;
         end;
      end;
   exception
      when others =>
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_System_Prompt_Is_Content_Block_Array;

   --  ── Test_Cache_Control_On_Last_Tool ────────────────────────────────────
   --  Verify that the last tool definition in the tools array has a
   --  cache_control marker when tools are present.

   procedure Test_Cache_Control_On_Last_Tool (T : in out Test) is
      pragma Unreferenced (T);

      Port     : constant Positive := 18_798;
      Capture  : constant String :=
         "/tmp/coyote_anthropic_cache_tools.json";
      Provider : LLM.Providers.Anthropic_Messages.Provider :=
         LLM.Providers.Anthropic_Messages.Create
            (Base_Url => "http://127.0.0.1:18798",
             Api_Key  => "test-key");
      Messages : constant LLM.Types.Message_Vectors.Vector :=
         Build_Messages;
      Tools_Json : constant String :=
         "[{""name"":""read"",""description"":""read file""," &
         """input_schema"":{""type"":""object""," &
         """properties"":{""path"":{""type"":""string""}}}}," &
         "{""name"":""shell"",""description"":""run command""," &
         """input_schema"":{""type"":""object""," &
         """properties"":{""command"":{""type"":""string""}}}}]";
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
          Model_Id      => "claude-sonnet-4-5",
          System_Prompt => "Be helpful.",
          Messages      => Messages,
          Thinking      => LLM.Providers.Off,
          Handler       => null,
          Tools_Json   => Tools_Json);

      Srv.Stop;
      Server_Stopped := True;

      declare
         use GNATCOLL.JSON;

         Captured : constant JSON_Value :=
            Parse_Json (Read_File (Capture), "captured request");
         Body_Val : constant JSON_Value :=
            Get_Object_Field (Captured, "body");
         Tools    : constant JSON_Array :=
            Get_Array_Field (Body_Val, "tools");
      begin
         Assert
           (Length (Tools) = 2,
            "tools array should have 2 elements");

         --  First tool should NOT have cache_control
         declare
            Tool_1 : constant JSON_Value := Get (Tools, 1);
         begin
            Assert
              (not Tool_1.Has_Field ("cache_control"),
               "first tool should not have cache_control");
         end;

         --  Last tool should have cache_control with type ephemeral
         declare
            Tool_2   : constant JSON_Value := Get (Tools, 2);
            CC       : constant JSON_Value :=
              Get_Object_Field (Tool_2, "cache_control");
         begin
            Assert
              (Tool_2.Has_Field ("cache_control"),
               "last tool should have cache_control");
            Assert
              (CC.Kind = JSON_Object_Type
               and then Get_String_Field (CC, "type") = "ephemeral",
               "last tool cache_control should be ephemeral");
         end;
      end;
   exception
      when others =>
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_Cache_Control_On_Last_Tool;

   --  ── Test_Cache_Control_On_Last_User_Message ────────────────────────────
   --  Verify that the last user-role message's final content block has a
   --  cache_control marker so the growing conversation prefix is cached.

   procedure Test_Cache_Control_On_Last_User_Message (T : in out Test) is
      pragma Unreferenced (T);

      Port     : constant Positive := 18_799;
      Capture  : constant String :=
         "/tmp/coyote_anthropic_cache_user_msg.json";
      Provider : LLM.Providers.Anthropic_Messages.Provider :=
         LLM.Providers.Anthropic_Messages.Create
            (Base_Url => "http://127.0.0.1:18799",
             Api_Key  => "test-key");

      --  Two-user-message history: first without cache_control, second with.
      function Build_Two_User_Messages
        return LLM.Types.Message_Vectors.Vector
      is
         Messages      : LLM.Types.Message_Vectors.Vector;
         Content_1     : LLM.Types.Content_Block_Vectors.Vector;
         Content_2     : LLM.Types.Content_Block_Vectors.Vector;
      begin
         Content_1.Append
           ((Kind => LLM.Types.Text_Block,
             Text => To_Unbounded_String ("First message")));
         Messages.Append
           ((Role      => LLM.Types.User,
             Content   => Content_1,
             Tok_Usage => (others => 0),
             Stop      => LLM.Types.Unknown_Stop,
             Timestamp => Null_Unbounded_String));

         Content_2.Append
           ((Kind => LLM.Types.Text_Block,
             Text => To_Unbounded_String ("Second message")));
         Messages.Append
           ((Role      => LLM.Types.User,
             Content   => Content_2,
             Tok_Usage => (others => 0),
             Stop      => LLM.Types.Unknown_Stop,
             Timestamp => Null_Unbounded_String));

         return Messages;
      end Build_Two_User_Messages;

      Messages : constant LLM.Types.Message_Vectors.Vector :=
         Build_Two_User_Messages;

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
          Model_Id      => "claude-sonnet-4-5",
          System_Prompt => "Be helpful.",
          Messages      => Messages,
          Thinking      => LLM.Providers.Off,
          Handler       => null);

      Srv.Stop;
      Server_Stopped := True;

      declare
         use GNATCOLL.JSON;

         Captured  : constant JSON_Value :=
            Parse_Json (Read_File (Capture), "captured request");
         Body_Val  : constant JSON_Value :=
            Get_Object_Field (Captured, "body");
         Msg_Array : constant JSON_Array :=
            Get_Array_Field (Body_Val, "messages");
      begin
         --  msg[1] = first user message, msg[2] = second user message
         declare
            Msg_1 : constant JSON_Value := Get (Msg_Array, 1);
            C1    : constant JSON_Array :=
              Get_Array_Field (Msg_1, "content");
            Block_1 : constant JSON_Value := Get (C1, 1);
         begin
            Assert
              (not Block_1.Has_Field ("cache_control"),
               "first user message content block should NOT have"
               & " cache_control");
         end;

         declare
            Msg_2   : constant JSON_Value := Get (Msg_Array, 2);
            C2      : constant JSON_Array :=
              Get_Array_Field (Msg_2, "content");
            Block_2 : constant JSON_Value := Get (C2, 1);
            CC      : constant JSON_Value :=
              Get_Object_Field (Block_2, "cache_control");
         begin
            Assert
              (Block_2.Has_Field ("cache_control"),
               "last user message block should have cache_control");
            Assert
              (CC.Kind = JSON_Object_Type
               and then Get_String_Field (CC, "type") = "ephemeral",
               "last user message cache_control should be ephemeral");
         end;
      end;
   exception
      when others =>
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_Cache_Control_On_Last_User_Message;

   --  ── Test_Tool_Result_Image_Serialised ─────────────────────────────────
   --  Verify that a Tool_Result message with a non-empty Media_Type is
   --  serialised as an Anthropic image content block rather than a plain
   --  "content" string.

   procedure Test_Tool_Result_Image_Serialised (T : in out Test) is
      pragma Unreferenced (T);

      Port    : constant Positive := 18_803;
      Capture : constant String :=
        "/tmp/coyote_anthropic_tool_result_image.json";

      function Build_Image_Tool_Result_Messages
        return LLM.Types.Message_Vectors.Vector
      is
         Messages       : LLM.Types.Message_Vectors.Vector;
         User_Content   : LLM.Types.Content_Block_Vectors.Vector;
         Asst_Content   : LLM.Types.Content_Block_Vectors.Vector;
         Result_Content : LLM.Types.Content_Block_Vectors.Vector;
      begin
         User_Content.Append
           ((Kind => LLM.Types.Text_Block,
             Text => To_Unbounded_String ("Take a screenshot")));
         Messages.Append
           ((Role      => LLM.Types.User,
             Content   => User_Content,
             Tok_Usage => (others => 0),
             Stop      => LLM.Types.Unknown_Stop,
             Timestamp => Null_Unbounded_String));

         Asst_Content.Append
           ((Kind           => LLM.Types.Tool_Call_Block,
             Tool_Call_Id   => To_Unbounded_String ("tool_img"),
             Tool_Name      => To_Unbounded_String ("shell"),
             Arguments_Json => To_Unbounded_String
               ("{""command"":""screenshot"",""media_type"":""image/png""}")));
         Messages.Append
           ((Role      => LLM.Types.Assistant,
             Content   => Asst_Content,
             Tok_Usage => (others => 0),
             Stop      => LLM.Types.Tool_Use,
             Timestamp => Null_Unbounded_String));

         Result_Content.Append
           ((Kind        => LLM.Types.Tool_Result_Block,
             Result_Id   => To_Unbounded_String ("tool_img"),
             Result_Text => To_Unbounded_String ("SGVsbG8="),
             Media_Type  => To_Unbounded_String ("image/png"),
             Is_Error    => False));
         Messages.Append
           ((Role      => LLM.Types.Tool_Result,
             Content   => Result_Content,
             Tok_Usage => (others => 0),
             Stop      => LLM.Types.Unknown_Stop,
             Timestamp => Null_Unbounded_String));

         return Messages;
      end Build_Image_Tool_Result_Messages;

      Provider : LLM.Providers.Anthropic_Messages.Provider :=
        LLM.Providers.Anthropic_Messages.Create
          (Base_Url => "http://127.0.0.1:18803",
           Api_Key  => "test-key");
      Messages : constant LLM.Types.Message_Vectors.Vector :=
        Build_Image_Tool_Result_Messages;

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
         Model_Id      => "claude-sonnet-4-5",
         System_Prompt => "",
         Messages      => Messages,
         Thinking      => LLM.Providers.Off,
         Handler       => null);

      Srv.Stop;
      Server_Stopped := True;

      declare
         use GNATCOLL.JSON;

         Captured    : constant JSON_Value :=
           Parse_Json (Read_File (Capture), "captured request");
         Body_Val    : constant JSON_Value :=
           Get_Object_Field (Captured, "body");
         Msg_Array   : constant JSON_Array :=
           Get_Array_Field (Body_Val, "messages");
         --  messages: user, assistant, tool_result (as user role)
         Tool_Msg    : constant JSON_Value :=
           GNATCOLL.JSON.Get (Msg_Array, 3);
         Content_Arr : constant JSON_Array :=
           Get_Array_Field (Tool_Msg, "content");
         Block       : constant JSON_Value :=
           GNATCOLL.JSON.Get (Content_Arr, 1);
         --  The tool_result "content" field should be an array for images
         Inner_Arr   : constant JSON_Array :=
           Get_Array_Field (Block, "content");
         Image_Block : constant JSON_Value :=
           GNATCOLL.JSON.Get (Inner_Arr, 1);
         Source      : constant JSON_Value :=
           Get_Object_Field (Image_Block, "source");
      begin
         Assert
           (Get_String_Field (Block, "type") = "tool_result",
            "Outer block should have type=tool_result");
         Assert
           (Get_String_Field (Image_Block, "type") = "image",
            "Inner block should have type=image");
         Assert
           (Get_String_Field (Source, "type") = "base64",
            "Source type should be base64");
         Assert
           (Get_String_Field (Source, "media_type") = "image/png",
            "Source media_type should be image/png");
         Assert
           (Get_String_Field (Source, "data") = "SGVsbG8=",
            "Source data should be the base64 payload");
      end;
   exception
      when others =>
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_Tool_Result_Image_Serialised;

end LLM_Anthropic_Messages_Tests;
