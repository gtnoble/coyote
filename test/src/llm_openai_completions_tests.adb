with AUnit.Assertions;
with Ada.Containers;
with Ada.Containers.Indefinite_Vectors;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;       use Ada.Strings.Unbounded;
with Ada.Tags;
with GNATCOLL.JSON;
with LLM.Events;
with LLM.HTTP;
with LLM.Providers;
with LLM.Providers.OpenAI_Completions;
with LLM.Providers.OpenAI_Completions.Testing;
with LLM.Types;
with Test_HTTP_Server;

package body LLM_OpenAI_Completions_Tests is

   use AUnit.Assertions;
   use type Ada.Containers.Count_Type;
   use type Ada.Tags.Tag;
   use type GNATCOLL.JSON.JSON_Value_Type;
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

   --  Return the string content of a JSON value as a plain String.
   --  The explicit return type resolves the GNATCOLL.JSON Get overloading
   --  ambiguity that arises when Ada.Strings.Unbounded is in use.
   function Json_String (Val : GNATCOLL.JSON.JSON_Value) return String is
      S : constant String := Val.Get;
   begin
      return S;
   end Json_String;

   function SSE_Record (Data : String) return String is
   begin
      return "data: " & Data & ASCII.LF & ASCII.LF;
   end SSE_Record;

   function SSE_Record
     (Data : GNATCOLL.JSON.JSON_Value) return String
   is
   begin
      return SSE_Record (GNATCOLL.JSON.Write (Data));
   end SSE_Record;

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

   --  ── Test procedures ───────────────────────────────────────────────────

   procedure Test_Stream_Text_Response (T : in out Test) is
      pragma Unreferenced (T);

      Port     : constant Positive := 18_767;
      Provider : LLM.Providers.OpenAI_Completions.Provider :=
        LLM.Providers.OpenAI_Completions.Create
          (Base_Url => "http://127.0.0.1:18767",
           Api_Key  => "test-key");
      Messages : LLM.Types.Message_Vectors.Vector;
      Content  : LLM.Types.Content_Block_Vectors.Vector;

      --  SSE payload: text delta then stop with usage.
      SSE_Payload : constant String :=
         "data: {""choices"":[{""delta"":{""role"":""assistant"","
         & """content"":""Hello""},""finish_reason"":null}]}"
         & ASCII.LF & ASCII.LF
         & "data: {""choices"":[{""delta"":{},""finish_reason"":""stop""}],"
         & """usage"":{""prompt_tokens"":10,""completion_tokens"":5,"
         & """total_tokens"":15}}"
         & ASCII.LF & ASCII.LF
         & "data: [DONE]" & ASCII.LF & ASCII.LF;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         Parsed  : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (To_String (Req.Body_Data));
         Body_JS : GNATCOLL.JSON.JSON_Value;
         Msgs    : GNATCOLL.JSON.JSON_Array;
         Msg_0   : GNATCOLL.JSON.JSON_Value;
         Msg_1   : GNATCOLL.JSON.JSON_Value;
      begin
         Assert
           (To_String (Req.Path) = "/chat/completions",
            "Expected path /chat/completions");
         Assert
           (Test_HTTP_Server.Get_Header
              (Req.Headers, "Authorization") = "Bearer test-key",
            "Expected Bearer test-key authorization");
         Assert
           (Test_HTTP_Server.Get_Header
              (Req.Headers, "Content-Type") = "application/json",
            "Expected application/json content type");
         Assert (Parsed.Success, "Failed to parse request body as JSON");
         Body_JS := Parsed.Value;
         Assert
           (Json_String (Body_JS.Get ("model")) = "test-model",
            "Wrong model in request");
         Assert
           (Boolean'(Body_JS.Get ("stream").Get),
            "stream should be true");
         Assert
           (Integer'(Body_JS.Get ("max_completion_tokens").Get) = 128,
            "max_completion_tokens should be 128");
         Msgs  := Body_JS.Get ("messages").Get;
         Msg_0 := GNATCOLL.JSON.Get (Msgs, 1);
         Assert
           (Json_String (Msg_0.Get ("role")) = "system",
            "messages[0].role should be system");
         Assert
           (Json_String (Msg_0.Get ("content")) = "Be helpful.",
            "messages[0].content should be Be helpful.");
         Msg_1 := GNATCOLL.JSON.Get (Msgs, 2);
         Assert
           (Json_String (Msg_1.Get ("role")) = "user",
            "messages[1].role should be user");
         Assert
           (Json_String (Msg_1.Get ("content")) = "Say hello",
            "messages[1].content should be Say hello");
         Assert
           (not Body_JS.Has_Field ("tools"),
            "tools should not be present when Tools_Json is empty");
         Res.Status := 200;
         Append (Res.Body_Data, SSE_Payload);
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
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

      Srv.Bind (Port);

      Send_With_Retry
        (P             => Provider,
         Model_Id      => "test-model",
         System_Prompt => "Be helpful.",
         Messages      => Messages,
         Tools_Json    => "[]",
         Max_Tokens    => 128,
         Handler       => On_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

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
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_Stream_Text_Response;

   procedure Test_Stream_Tool_Call_Response (T : in out Test) is
      pragma Unreferenced (T);

      Port             : constant Positive := 18_768;
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

      --  SSE payload: two chunks delivering a tool call.
      --  Chunk 1: opening partial arguments "{\"path\":\"".
      --  Chunk 2: closing fragment "a.adb\"}" with finish_reason.
      function Build_SSE_Payload return String is
         Root_1       : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
         Choices_1    : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
         Choice_1     : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
         Delta_1      : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
         Tool_Calls_1 : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
         Tool_Call_1  : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
         Func_1       : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;

         Root_2       : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
         Choices_2    : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
         Choice_2     : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
         Delta_2      : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
         Tool_Calls_2 : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
         Tool_Call_2  : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
         Func_2       : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
         Usage_2      : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
      begin
         Tool_Call_1.Set_Field ("index", Integer (0));
         Tool_Call_1.Set_Field ("id", "call_1");
         Tool_Call_1.Set_Field ("type", "function");
         Func_1.Set_Field ("name", "read");
         Func_1.Set_Field ("arguments", "{""path"":""");
         Tool_Call_1.Set_Field ("function", Func_1);
         GNATCOLL.JSON.Append (Tool_Calls_1, Tool_Call_1);
         Delta_1.Set_Field ("tool_calls", Tool_Calls_1);
         Choice_1.Set_Field ("delta", Delta_1);
         Choice_1.Set_Field ("finish_reason", GNATCOLL.JSON.JSON_Null);
         GNATCOLL.JSON.Append (Choices_1, Choice_1);
         Root_1.Set_Field ("choices", Choices_1);

         Tool_Call_2.Set_Field ("index", Integer (0));
         Func_2.Set_Field ("arguments", "a.adb""}");
         Tool_Call_2.Set_Field ("function", Func_2);
         GNATCOLL.JSON.Append (Tool_Calls_2, Tool_Call_2);
         Delta_2.Set_Field ("tool_calls", Tool_Calls_2);
         Choice_2.Set_Field ("delta", Delta_2);
         Choice_2.Set_Field ("finish_reason", "tool_calls");
         GNATCOLL.JSON.Append (Choices_2, Choice_2);
         Root_2.Set_Field ("choices", Choices_2);
         Usage_2.Set_Field ("prompt_tokens", Integer (12));
         Usage_2.Set_Field ("completion_tokens", Integer (7));
         Usage_2.Set_Field ("total_tokens", Integer (19));
         Root_2.Set_Field ("usage", Usage_2);

         return SSE_Record (Root_1)
           & SSE_Record (Root_2)
           & SSE_Record ("[DONE]");
      end Build_SSE_Payload;

      SSE_Payload : constant String := Build_SSE_Payload;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         Parsed   : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (To_String (Req.Body_Data));
         Body_JS  : GNATCOLL.JSON.JSON_Value;
         Msgs     : GNATCOLL.JSON.JSON_Array;
         Msg_1    : GNATCOLL.JSON.JSON_Value;
         Msg_2    : GNATCOLL.JSON.JSON_Value;
         Msg_3    : GNATCOLL.JSON.JSON_Value;
         TC_Array : GNATCOLL.JSON.JSON_Array;
         TC       : GNATCOLL.JSON.JSON_Value;
         TC_Func  : GNATCOLL.JSON.JSON_Value;
         Tools    : GNATCOLL.JSON.JSON_Array;
      begin
         Assert
           (To_String (Req.Path) = "/chat/completions",
            "Expected path /chat/completions");
         Assert
           (Test_HTTP_Server.Get_Header
              (Req.Headers, "Authorization") = "Bearer test-key",
            "Expected Bearer test-key authorization");
         Assert
           (Test_HTTP_Server.Get_Header
              (Req.Headers, "X-Test-Header") = "ok",
            "Expected X-Test-Header: ok");
         Assert (Parsed.Success, "Failed to parse request body as JSON");
         Body_JS := Parsed.Value;
         Assert
           (Json_String (Body_JS.Get ("model")) = "tool-model",
            "Wrong model in request");
         Msgs  := Body_JS.Get ("messages").Get;
         Msg_1 := GNATCOLL.JSON.Get (Msgs, 1);
         Assert
           (Json_String (Msg_1.Get ("role")) = "user",
            "messages[0].role should be user");
         Assert
           (Json_String (Msg_1.Get ("content")) = "Use a tool",
            "messages[0].content should be Use a tool");
         Msg_2 := GNATCOLL.JSON.Get (Msgs, 2);
         Assert
           (Json_String (Msg_2.Get ("role")) = "assistant",
            "messages[1].role should be assistant");
         Assert
           (Msg_2.Get ("content").Kind = GNATCOLL.JSON.JSON_Null_Type,
            "messages[1].content should be null");
         TC_Array := Msg_2.Get ("tool_calls").Get;
         TC       := GNATCOLL.JSON.Get (TC_Array, 1);
         TC_Func  := TC.Get ("function");
         Assert
           (Json_String (TC.Get ("id")) = "call_1",
            "tool_calls[0].id should be call_1");
         Assert
           (Json_String (TC.Get ("type")) = "function",
            "tool_calls[0].type should be function");
         Assert
           (Json_String (TC_Func.Get ("name")) = "read",
            "tool_calls[0].function.name should be read");
         Assert
           (Json_String (TC_Func.Get ("arguments")) = "{""path"":""a.adb""}",
            "tool_calls[0].function.arguments mismatch");
         Msg_3 := GNATCOLL.JSON.Get (Msgs, 3);
         Assert
           (Json_String (Msg_3.Get ("role")) = "tool",
            "messages[2].role should be tool");
         Assert
           (Json_String (Msg_3.Get ("tool_call_id")) = "call_1",
            "messages[2].tool_call_id should be call_1");
         Assert
           (Json_String (Msg_3.Get ("content")) = "file contents",
            "messages[2].content should be file contents");
         Tools := Body_JS.Get ("tools").Get;
         Assert
           (GNATCOLL.JSON.Length (Tools) = 1,
            "tools array should have 1 element");
         Res.Status := 200;
         Append (Res.Body_Data, SSE_Payload);
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
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

      Srv.Bind (Port);

      Send_With_Retry
        (P             => Provider,
         Model_Id      => "tool-model",
         System_Prompt => "",
         Messages      => Messages,
         Tools_Json    => Tools_Json,
         Max_Tokens    => 256,
         Handler       => On_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

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
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_Stream_Tool_Call_Response;

   procedure Test_Stream_Multi_Tool_Response (T : in out Test) is
      pragma Unreferenced (T);

      Port         : constant Positive := 18_769;
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

      --  SSE payload: three chunks for two simultaneous tool calls.
      --  Chunk 1: opening fragments for both tools.
      --  Chunk 2: closing fragments for both tools, finish_reason null.
      --  Chunk 3: empty delta with finish_reason tool_calls and usage.
      function Build_SSE_Payload return String is
         Root_1       : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
         Choices_1    : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
         Choice_1     : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
         Delta_1      : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
         Tool_Calls_1 : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
         Read_Call_1  : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
         Read_Func_1  : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
         Write_Call_1 : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
         Write_Func_1 : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;

         Root_2       : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
         Choices_2    : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
         Choice_2     : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
         Delta_2      : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
         Tool_Calls_2 : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
         Read_Call_2  : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
         Read_Func_2  : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
         Write_Call_2 : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
         Write_Func_2 : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;

         Root_3    : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
         Choices_3 : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
         Choice_3  : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
         Delta_3   : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
         Usage_3   : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
      begin
         Read_Call_1.Set_Field ("index", Integer (0));
         Read_Call_1.Set_Field ("id", "call_1");
         Read_Call_1.Set_Field ("type", "function");
         Read_Func_1.Set_Field ("name", "read");
         Read_Func_1.Set_Field ("arguments", "{""path"":""alpha");
         Read_Call_1.Set_Field ("function", Read_Func_1);
         GNATCOLL.JSON.Append (Tool_Calls_1, Read_Call_1);

         Write_Call_1.Set_Field ("index", Integer (1));
         Write_Call_1.Set_Field ("id", "call_2");
         Write_Call_1.Set_Field ("type", "function");
         Write_Func_1.Set_Field ("name", "write");
         Write_Func_1.Set_Field ("arguments", "{""path"":""beta");
         Write_Call_1.Set_Field ("function", Write_Func_1);
         GNATCOLL.JSON.Append (Tool_Calls_1, Write_Call_1);

         Delta_1.Set_Field ("tool_calls", Tool_Calls_1);
         Choice_1.Set_Field ("delta", Delta_1);
         Choice_1.Set_Field ("finish_reason", GNATCOLL.JSON.JSON_Null);
         GNATCOLL.JSON.Append (Choices_1, Choice_1);
         Root_1.Set_Field ("choices", Choices_1);

         Read_Call_2.Set_Field ("index", Integer (0));
         Read_Func_2.Set_Field ("arguments", ".adb""}");
         Read_Call_2.Set_Field ("function", Read_Func_2);
         GNATCOLL.JSON.Append (Tool_Calls_2, Read_Call_2);

         Write_Call_2.Set_Field ("index", Integer (1));
         Write_Func_2.Set_Field ("arguments", ".adb""}");
         Write_Call_2.Set_Field ("function", Write_Func_2);
         GNATCOLL.JSON.Append (Tool_Calls_2, Write_Call_2);

         Delta_2.Set_Field ("tool_calls", Tool_Calls_2);
         Choice_2.Set_Field ("delta", Delta_2);
         Choice_2.Set_Field ("finish_reason", GNATCOLL.JSON.JSON_Null);
         GNATCOLL.JSON.Append (Choices_2, Choice_2);
         Root_2.Set_Field ("choices", Choices_2);

         Choice_3.Set_Field ("delta", Delta_3);
         Choice_3.Set_Field ("finish_reason", "tool_calls");
         GNATCOLL.JSON.Append (Choices_3, Choice_3);
         Root_3.Set_Field ("choices", Choices_3);
         Usage_3.Set_Field ("prompt_tokens", Integer (21));
         Usage_3.Set_Field ("completion_tokens", Integer (9));
         Usage_3.Set_Field ("total_tokens", Integer (30));
         Root_3.Set_Field ("usage", Usage_3);

         return SSE_Record (Root_1)
           & SSE_Record (Root_2)
           & SSE_Record (Root_3)
           & SSE_Record ("[DONE]");
      end Build_SSE_Payload;

      SSE_Payload : constant String := Build_SSE_Payload;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         Parsed  : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (To_String (Req.Body_Data));
         Body_JS : GNATCOLL.JSON.JSON_Value;
         Msgs    : GNATCOLL.JSON.JSON_Array;
      begin
         Assert (Parsed.Success, "Failed to parse request body as JSON");
         Body_JS := Parsed.Value;
         Assert
           (Json_String (Body_JS.Get ("model")) = "multi-tool-model",
            "Wrong model in request");
         Assert
           (Boolean'(Body_JS.Get ("stream").Get),
            "stream should be true");
         Msgs := Body_JS.Get ("messages").Get;
         Assert
           (GNATCOLL.JSON.Length (Msgs) = 1,
            "messages should have 1 element");
         Res.Status := 200;
         Append (Res.Body_Data, SSE_Payload);
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
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

      Srv.Bind (Port);

      Send_With_Retry
        (P             => Provider,
         Model_Id      => "multi-tool-model",
         System_Prompt => "",
         Messages      => Messages,
         Tools_Json    => Tools_Json,
         Max_Tokens    => 256,
         Handler       => On_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

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
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_Stream_Multi_Tool_Response;

   procedure Test_Stream_Thinking_Response (T : in out Test) is
      pragma Unreferenced (T);

      Port         : constant Positive := 18_770;
      Provider     : LLM.Providers.OpenAI_Completions.Provider :=
        LLM.Providers.OpenAI_Completions.Create
          (Base_Url => "http://127.0.0.1:18770",
           Api_Key  => "test-key");
      Messages     : LLM.Types.Message_Vectors.Vector;
      User_Content : LLM.Types.Content_Block_Vectors.Vector;

      --  SSE payload: reasoning delta then stop with usage.
      SSE_Payload : constant String :=
         "data: {""choices"":[{""delta"":{""reasoning"":"
         & """thinking text""},""finish_reason"":null}]}"
         & ASCII.LF & ASCII.LF
         & "data: {""choices"":[{""delta"":{},""finish_reason"":""stop""}],"
         & """usage"":{""prompt_tokens"":8,""completion_tokens"":3,"
         & """total_tokens"":11}}"
         & ASCII.LF & ASCII.LF
         & "data: [DONE]" & ASCII.LF & ASCII.LF;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         Parsed  : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (To_String (Req.Body_Data));
         Body_JS : GNATCOLL.JSON.JSON_Value;
      begin
         Assert
           (To_String (Req.Path) = "/chat/completions",
            "Expected path /chat/completions");
         Assert (Parsed.Success, "Failed to parse request body as JSON");
         Body_JS := Parsed.Value;
         Assert
           (Boolean'(Body_JS.Get ("stream").Get),
            "stream should be true");
         Res.Status := 200;
         Append (Res.Body_Data, SSE_Payload);
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
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

      Srv.Bind (Port);

      Send_With_Retry
        (P             => Provider,
         Model_Id      => "thinking-model",
         System_Prompt => "",
         Messages      => Messages,
         Tools_Json    => "[]",
         Max_Tokens    => 64,
         Handler       => On_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

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
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_Stream_Thinking_Response;

   procedure Test_Compaction_Summary_Encodes_As_User_OpenAI
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Port            : constant Positive := 18_772;
      Provider        : LLM.Providers.OpenAI_Completions.Provider :=
        LLM.Providers.OpenAI_Completions.Create
          (Base_Url => "http://127.0.0.1:18772",
           Api_Key  => "test-key");
      Messages        : LLM.Types.Message_Vectors.Vector;
      Summary_Content : LLM.Types.Content_Block_Vectors.Vector;

      --  SSE payload: empty delta with stop reason and usage.
      SSE_Payload : constant String :=
         "data: {""choices"":[{""delta"":{},""finish_reason"":""stop""}],"
         & """usage"":{""prompt_tokens"":4,""completion_tokens"":0,"
         & """total_tokens"":4}}"
         & ASCII.LF & ASCII.LF
         & "data: [DONE]" & ASCII.LF & ASCII.LF;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         Parsed  : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (To_String (Req.Body_Data));
         Body_JS : GNATCOLL.JSON.JSON_Value;
         Msgs    : GNATCOLL.JSON.JSON_Array;
         Msg_0   : GNATCOLL.JSON.JSON_Value;
      begin
         Assert
           (To_String (Req.Path) = "/chat/completions",
            "Expected path /chat/completions");
         Assert (Parsed.Success, "Failed to parse request body as JSON");
         Body_JS := Parsed.Value;
         Msgs    := Body_JS.Get ("messages").Get;
         Assert
           (GNATCOLL.JSON.Length (Msgs) = 1,
            "messages should have exactly 1 element");
         Msg_0 := GNATCOLL.JSON.Get (Msgs, 1);
         Assert
           (Json_String (Msg_0.Get ("role")) = "user",
            "Compaction summary should be encoded as user role");
         Assert
           (Json_String (Msg_0.Get ("content")) = "Checkpoint summary text",
            "Compaction summary content mismatch");
         Res.Status := 200;
         Append (Res.Body_Data, SSE_Payload);
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
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

      Srv.Bind (Port);

      Send_With_Retry
        (P             => Provider,
         Model_Id      => "summary-model",
         System_Prompt => "",
         Messages      => Messages,
         Tools_Json    => "[]",
         Max_Tokens    => 64,
         Handler       => On_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Assert
        (Current_Collector.Last_Stop = LLM.Types.Stop,
         "Compaction summary OpenAI request should complete successfully");
   exception
      when others =>
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_Compaction_Summary_Encodes_As_User_OpenAI;

   procedure Test_Non_Streaming_Response (T : in out Test) is
      pragma Unreferenced (T);

      Port         : constant Positive := 18_771;
      Provider     : LLM.Providers.OpenAI_Completions.Provider :=
        LLM.Providers.OpenAI_Completions.Create
          (Base_Url => "http://127.0.0.1:18771",
           Api_Key  => "test-key");
      Messages     : LLM.Types.Message_Vectors.Vector;
      User_Content : LLM.Types.Content_Block_Vectors.Vector;

      --  Non-streaming JSON response payload.
      JSON_Payload : constant String :=
         "{""choices"":[{""message"":{""role"":""assistant"","
         & """content"":""Non-stream hello""},""finish_reason"":""stop""}],"
         & """usage"":{""prompt_tokens"":13,""completion_tokens"":4,"
         & """total_tokens"":17}}";

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         Parsed  : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (To_String (Req.Body_Data));
         Body_JS : GNATCOLL.JSON.JSON_Value;
      begin
         Assert
           (To_String (Req.Path) = "/chat/completions",
            "Expected path /chat/completions");
         Assert (Parsed.Success, "Failed to parse request body as JSON");
         Body_JS := Parsed.Value;
         Assert
           (Json_String (Body_JS.Get ("model")) = "non-stream-model",
            "Wrong model in request");
         Assert
           (not Boolean'(Body_JS.Get ("stream").Get),
            "stream should be false for non-streaming request");
         Res.Status := 200;
         Append (Res.Body_Data, JSON_Payload);
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
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

      Srv.Bind (Port);

      Send_With_Retry
        (P             => Provider,
         Model_Id      => "non-stream-model",
         System_Prompt => "",
         Messages      => Messages,
         Tools_Json    => "[]",
         Max_Tokens    => 64,
         Handler       => On_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

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
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_Non_Streaming_Response;

   procedure Test_OpenAI_Non_Streaming_Tool_Calls (T : in out Test) is
      pragma Unreferenced (T);

      Port         : constant Positive := 18_796;
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

      --  Non-streaming JSON response with a tool call.
      --  arguments value: {"path":"nonstream.adb"}
      JSON_Payload : constant String :=
         "{""choices"":[{""message"":{""role"":""assistant"","
         & """content"":null,""tool_calls"":[{""id"":""call_1"","
         & """type"":""function"",""function"":{""name"":""read"","
         & """arguments"":""{\""path\"":\""nonstream.adb\""}"""
         & "}}]},""finish_reason"":""tool_calls""}],"
         & """usage"":{""prompt_tokens"":14,""completion_tokens"":6,"
         & """total_tokens"":20}}";

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         Parsed  : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (To_String (Req.Body_Data));
         Body_JS : GNATCOLL.JSON.JSON_Value;
         Tools   : GNATCOLL.JSON.JSON_Array;
      begin
         Assert
           (To_String (Req.Path) = "/chat/completions",
            "Expected path /chat/completions");
         Assert (Parsed.Success, "Failed to parse request body as JSON");
         Body_JS := Parsed.Value;
         Assert
           (Json_String (Body_JS.Get ("model")) = "non-stream-tool-model",
            "Wrong model in request");
         Assert
           (not Boolean'(Body_JS.Get ("stream").Get),
            "stream should be false for non-streaming request");
         Tools := Body_JS.Get ("tools").Get;
         Assert
           (GNATCOLL.JSON.Length (Tools) = 1,
            "tools array should have 1 element");
         Res.Status := 200;
         Append (Res.Body_Data, JSON_Payload);
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
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

      Srv.Bind (Port);

      Send_With_Retry
        (P             => Provider,
         Model_Id      => "non-stream-tool-model",
         System_Prompt => "",
         Messages      => Messages,
         Tools_Json    => Tools_Json,
         Max_Tokens    => 64,
         Handler       => On_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

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
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_OpenAI_Non_Streaming_Tool_Calls;

   procedure Test_OpenAI_HTTP_Error_Propagates (T : in out Test) is
      pragma Unreferenced (T);

      Port          : constant Positive := 18_797;
      Provider      : LLM.Providers.OpenAI_Completions.Provider :=
        LLM.Providers.OpenAI_Completions.Create
          (Base_Url => "http://127.0.0.1:18797",
           Api_Key  => "test-key");
      Messages      : LLM.Types.Message_Vectors.Vector;
      User_Content  : LLM.Types.Content_Block_Vectors.Vector;
      Raised        : Boolean := False;
      Error_Message : Unbounded_String;

      --  HTTP 500 error JSON payload.
      Error_Payload : constant String := "{""error"":""internal""}";

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 500;
         Append (Res.Body_Data, Error_Payload);
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
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

      Srv.Bind (Port);

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

      Srv.Stop;
      Server_Stopped := True;

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
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_OpenAI_HTTP_Error_Propagates;

   procedure Test_OpenAI_Stream_Terminates_Early (T : in out Test) is
      pragma Unreferenced (T);

      Port         : constant Positive := 18_798;
      Provider     : LLM.Providers.OpenAI_Completions.Provider :=
        LLM.Providers.OpenAI_Completions.Create
          (Base_Url => "http://127.0.0.1:18798",
           Api_Key  => "test-key");
      Messages     : LLM.Types.Message_Vectors.Vector;
      User_Content : LLM.Types.Content_Block_Vectors.Vector;

      --  Partial SSE response: one data event, no [DONE] terminator.
      SSE_Payload : constant String :=
         "data: {""choices"":[{""delta"":{""content"":""partial""},"
         & """finish_reason"":null}]}"
         & ASCII.LF & ASCII.LF;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 200;
         Append (Res.Body_Data, SSE_Payload);
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
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

      Srv.Bind (Port);

      Send_With_Retry
        (P             => Provider,
         Model_Id      => "early-close-model",
         System_Prompt => "",
         Messages      => Messages,
         Tools_Json    => "[]",
         Max_Tokens    => 64,
         Handler       => On_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

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
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_OpenAI_Stream_Terminates_Early;

end LLM_OpenAI_Completions_Tests;
