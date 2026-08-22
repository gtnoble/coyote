with AUnit.Assertions;
with Ada.Containers;
with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Tags;
with GNATCOLL.JSON;
with LLM.Events;
with LLM.HTTP;
with LLM.Providers;
with LLM.Providers.OpenAI_Responses;
with LLM.Providers.OpenAI_Responses.Testing;
with LLM.Types;
with Test_HTTP_Server;

package body LLM_OpenAI_Responses_Tests is

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
     (P             : in out LLM.Providers.OpenAI_Responses.Provider;
      Model_Id      :        String;
      System_Prompt :        String;
      Messages      :        LLM.Types.Message_Vectors.Vector;
      Tools_Json    :        String;
      Thinking      :        LLM.Providers.Thinking_Level :=
        LLM.Providers.Off;
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
               Thinking      => Thinking,
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

   function Json_String (Val : GNATCOLL.JSON.JSON_Value) return String is
      S : constant String := Val.Get;
   begin
      return S;
   end Json_String;

   function SSE_Event (Event_Type : String; Data : String) return String is
   begin
      return
        "event: " & Event_Type & ASCII.LF
        & "data: " & Data & ASCII.LF & ASCII.LF;
   end SSE_Event;

   function SSE_Event
     (Event_Type : String;
      Data       : GNATCOLL.JSON.JSON_Value) return String
   is
   begin
      return SSE_Event (Event_Type, GNATCOLL.JSON.Write (Data));
   end SSE_Event;

   function Usage_Object
     (Input_Tokens       : Natural;
      Output_Tokens      : Natural;
      Cached_Tokens      : Natural := 0;
      Cache_Write_Tokens : Natural := 0;
      Reasoning_Tokens   : Natural := 0)
      return GNATCOLL.JSON.JSON_Value
   is
      use GNATCOLL.JSON;
      Usage      : constant JSON_Value := Create_Object;
      Input_Det  : constant JSON_Value := Create_Object;
      Output_Det : constant JSON_Value := Create_Object;
   begin
      Usage.Set_Field ("input_tokens", Integer (Input_Tokens));
      Usage.Set_Field ("output_tokens", Integer (Output_Tokens));
      Usage.Set_Field
        ("total_tokens", Integer (Input_Tokens + Output_Tokens));
      Input_Det.Set_Field ("cached_tokens", Integer (Cached_Tokens));
      Input_Det.Set_Field
        ("cache_write_tokens", Integer (Cache_Write_Tokens));
      Output_Det.Set_Field
        ("reasoning_tokens", Integer (Reasoning_Tokens));
      Usage.Set_Field ("input_tokens_details", Input_Det);
      Usage.Set_Field ("output_tokens_details", Output_Det);
      return Usage;
   end Usage_Object;

   function Completed_Response
     (Text          : String;
      Input_Tokens  : Natural;
      Output_Tokens : Natural;
      Cached        : Natural := 0;
      Cache_Write   : Natural := 0;
      Reasoning     : Natural := 0) return GNATCOLL.JSON.JSON_Value
   is
      use GNATCOLL.JSON;
      Response : constant JSON_Value := Create_Object;
      Item     : constant JSON_Value := Create_Object;
      Part     : constant JSON_Value := Create_Object;
      Output   : JSON_Array := Empty_Array;
      Content  : JSON_Array := Empty_Array;
   begin
      Part.Set_Field ("type", "output_text");
      Part.Set_Field ("text", Text);
      Append (Content, Part);
      Item.Set_Field ("id", "msg_test");
      Item.Set_Field ("type", "message");
      Item.Set_Field ("role", "assistant");
      Item.Set_Field ("status", "completed");
      Item.Set_Field ("content", Content);
      Append (Output, Item);
      Response.Set_Field ("id", "resp_test");
      Response.Set_Field ("object", "response");
      Response.Set_Field ("status", "completed");
      Response.Set_Field ("output", Output);
      Response.Set_Field
        ("usage",
         Usage_Object
           (Input_Tokens, Output_Tokens, Cached, Cache_Write, Reasoning));
      return Response;
   end Completed_Response;

   function Build_Text_SSE
     (Text          : String;
      Input_Tokens  : Natural;
      Output_Tokens : Natural;
      Cached        : Natural := 0;
      Cache_Write   : Natural := 0) return String
   is
      use GNATCOLL.JSON;
      Created       : constant JSON_Value := Create_Object;
      Added         : constant JSON_Value := Create_Object;
      Item          : constant JSON_Value := Create_Object;
      Delta_Value   : constant JSON_Value := Create_Object;
      Text_Done       : constant JSON_Value := Create_Object;
      Item_Done       : constant JSON_Value := Create_Object;
      Item_Done_Event : constant JSON_Value := Create_Object;
      Done_Part       : constant JSON_Value := Create_Object;
      Done_Content    : JSON_Array := Empty_Array;
      Completed       : constant JSON_Value := Create_Object;
   begin
      Created.Set_Field ("type", "response.created");
      Created.Set_Field ("sequence_number", Integer (0));
      Item.Set_Field ("id", "msg_test");
      Item.Set_Field ("type", "message");
      Item.Set_Field ("role", "assistant");
      Item.Set_Field ("status", "in_progress");
      Item.Set_Field ("content", Empty_Array);
      Added.Set_Field ("type", "response.output_item.added");
      Added.Set_Field ("output_index", Integer (0));
      Added.Set_Field ("item", Item);
      Delta_Value.Set_Field ("type", "response.output_text.delta");
      Delta_Value.Set_Field ("item_id", "msg_test");
      Delta_Value.Set_Field ("output_index", Integer (0));
      Delta_Value.Set_Field ("content_index", Integer (0));
      Delta_Value.Set_Field ("delta", Text);
      Text_Done.Set_Field ("type", "response.output_text.done");
      Text_Done.Set_Field ("item_id", "msg_test");
      Text_Done.Set_Field ("output_index", Integer (0));
      Text_Done.Set_Field ("content_index", Integer (0));
      Text_Done.Set_Field ("text", Text);
      Done_Part.Set_Field ("type", "output_text");
      Done_Part.Set_Field ("text", Text);
      Append (Done_Content, Done_Part);
      Item_Done.Set_Field ("id", "msg_test");
      Item_Done.Set_Field ("type", "message");
      Item_Done.Set_Field ("role", "assistant");
      Item_Done.Set_Field ("status", "completed");
      Item_Done.Set_Field ("content", Done_Content);
      Text_Done.Set_Field ("text", Text);
      Item_Done_Event.Set_Field ("type", "response.output_item.done");
      Item_Done_Event.Set_Field ("output_index", Integer (0));
      Item_Done_Event.Set_Field ("item", Item_Done);
      Completed.Set_Field ("type", "response.completed");
      Completed.Set_Field
        ("response",
         Completed_Response
           (Text, Input_Tokens, Output_Tokens, Cached, Cache_Write));
      return
        SSE_Event ("response.created", Created)
        & SSE_Event ("response.output_item.added", Added)
        & SSE_Event ("response.output_text.delta", Delta_Value)
        & SSE_Event ("response.output_text.done", Text_Done)
        & SSE_Event ("response.output_item.done", Item_Done_Event)
        & SSE_Event ("response.completed", Completed);
   end Build_Text_SSE;

   function Build_Tool_SSE
     (Call_Id   : String;
      Name      : String;
      Arguments : String) return String
   is
      use GNATCOLL.JSON;
      Added      : constant JSON_Value := Create_Object;
      Item       : constant JSON_Value := Create_Object;
      Delta_Value : constant JSON_Value := Create_Object;
      Done       : constant JSON_Value := Create_Object;
      Completed  : constant JSON_Value := Create_Object;
      Response   : constant JSON_Value := Create_Object;
      Output     : JSON_Array := Empty_Array;
      Out_Item   : constant JSON_Value := Create_Object;
   begin
      Item.Set_Field ("id", "fc_test");
      Item.Set_Field ("type", "function_call");
      Item.Set_Field ("call_id", Call_Id);
      Item.Set_Field ("name", Name);
      Item.Set_Field ("arguments", "");
      Item.Set_Field ("status", "in_progress");
      Added.Set_Field ("type", "response.output_item.added");
      Added.Set_Field ("output_index", Integer (0));
      Added.Set_Field ("item", Item);
      Delta_Value.Set_Field ("type", "response.function_call_arguments.delta");
      Delta_Value.Set_Field ("item_id", "fc_test");
      Delta_Value.Set_Field ("output_index", Integer (0));
      Delta_Value.Set_Field ("delta", Arguments);
      Done.Set_Field ("type", "response.function_call_arguments.done");
      Done.Set_Field ("item_id", "fc_test");
      Done.Set_Field ("name", Name);
      Done.Set_Field ("output_index", Integer (0));
      Done.Set_Field ("arguments", Arguments);
      Out_Item.Set_Field ("id", "fc_test");
      Out_Item.Set_Field ("type", "function_call");
      Out_Item.Set_Field ("call_id", Call_Id);
      Out_Item.Set_Field ("name", Name);
      Out_Item.Set_Field ("arguments", Arguments);
      Out_Item.Set_Field ("status", "completed");
      Append (Output, Out_Item);
      Response.Set_Field ("id", "resp_tool");
      Response.Set_Field ("status", "completed");
      Response.Set_Field ("output", Output);
      Response.Set_Field ("usage", Usage_Object (20, 8));
      Completed.Set_Field ("type", "response.completed");
      Completed.Set_Field ("response", Response);
      return
        SSE_Event ("response.output_item.added", Added)
        & SSE_Event ("response.function_call_arguments.delta", Delta_Value)
        & SSE_Event ("response.function_call_arguments.done", Done)
        & SSE_Event ("response.completed", Completed);
   end Build_Tool_SSE;

   function Build_Thinking_SSE
     (Thinking : String;
      Text     : String) return String
   is
      use GNATCOLL.JSON;
      Reason_Delta_Value : constant JSON_Value := Create_Object;
      Text_Delta_Value : constant JSON_Value := Create_Object;
      Completed    : constant JSON_Value := Create_Object;
      Response     : constant JSON_Value := Create_Object;
      R_Item       : constant JSON_Value := Create_Object;
      M_Item       : constant JSON_Value := Create_Object;
      Part         : constant JSON_Value := Create_Object;
      Output       : JSON_Array := Empty_Array;
      Content      : JSON_Array := Empty_Array;
      Summary      : JSON_Array := Empty_Array;
   begin
      Reason_Delta_Value.Set_Field ("type", "response.reasoning_text.delta");
      Reason_Delta_Value.Set_Field ("item_id", "rs_test");
      Reason_Delta_Value.Set_Field ("delta", Thinking);
      Text_Delta_Value.Set_Field ("type", "response.output_text.delta");
      Text_Delta_Value.Set_Field ("item_id", "msg_test");
      Text_Delta_Value.Set_Field ("delta", Text);
      R_Item.Set_Field ("type", "reasoning");
      R_Item.Set_Field ("id", "rs_test");
      R_Item.Set_Field ("encrypted_content", "enc-secret");
      Append (Summary, Create_Object);
      R_Item.Set_Field ("summary", Summary);
      Part.Set_Field ("type", "output_text");
      Part.Set_Field ("text", Text);
      Append (Content, Part);
      M_Item.Set_Field ("type", "message");
      M_Item.Set_Field ("role", "assistant");
      M_Item.Set_Field ("content", Content);
      Append (Output, R_Item);
      Append (Output, M_Item);
      Response.Set_Field ("id", "resp_think");
      Response.Set_Field ("status", "completed");
      Response.Set_Field ("output", Output);
      Response.Set_Field ("usage", Usage_Object (10, 20, 0, 0, 7));
      Completed.Set_Field ("type", "response.completed");
      Completed.Set_Field ("response", Response);
      declare
         Reason_Added : constant JSON_Value := Create_Object;
         Reason_Item  : constant JSON_Value := Create_Object;
      begin
         Reason_Item.Set_Field ("type", "reasoning");
         Reason_Item.Set_Field ("id", "rs_test");
         Reason_Item.Set_Field ("encrypted_content", "enc-secret");
         Reason_Added.Set_Field
           ("type", "response.output_item.added");
         Reason_Added.Set_Field ("output_index", Integer (0));
         Reason_Added.Set_Field ("item", Reason_Item);
         return
           SSE_Event ("response.output_item.added", Reason_Added)
           & SSE_Event ("response.reasoning_text.delta", Reason_Delta_Value)
           & SSE_Event ("response.output_text.delta", Text_Delta_Value)
           & SSE_Event ("response.completed", Completed);
      end;
   end Build_Thinking_SSE;

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

   function Count_Event (Value : String) return Natural is
      Result : Natural := 0;
   begin
      for Item of Current_Collector.Sequence loop
         if Item = Value then
            Result := Result + 1;
         end if;
      end loop;
      return Result;
   end Count_Event;

   function Field_String
     (Value : GNATCOLL.JSON.JSON_Value;
      Field : String) return String
   is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_String_Type
      then
         return Value.Get (Field).Get;
      end if;
      return "";
   end Field_String;

   function User_Hello return LLM.Types.Message_Vectors.Vector is
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
   end User_Hello;

   procedure Test_Stream_Text_Response (T : in out Test) is
      pragma Unreferenced (T);

      Port     : constant Positive := 19_101;
      Provider : LLM.Providers.OpenAI_Responses.Provider :=
        LLM.Providers.OpenAI_Responses.Create
          (Base_Url => "http://127.0.0.1:19101",
           Api_Key  => "test-key");
      Messages : constant LLM.Types.Message_Vectors.Vector := User_Hello;
      Payload  : constant String :=
        Build_Text_SSE ("Hello", 10, 5);

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         Parsed  : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (To_String (Req.Body_Data));
         Body_JS : GNATCOLL.JSON.JSON_Value;
         Input   : GNATCOLL.JSON.JSON_Array;
         Item_0  : GNATCOLL.JSON.JSON_Value;
      begin
         Assert
           (To_String (Req.Path) = "/responses",
            "Expected path /responses");
         Assert
           (Test_HTTP_Server.Get_Header
              (Req.Headers, "Authorization") = "Bearer test-key",
            "Expected Bearer test-key authorization");
         Assert (Parsed.Success, "Failed to parse request body as JSON");
         Body_JS := Parsed.Value;
         Assert
           (Json_String (Body_JS.Get ("model")) = "test-model",
            "Wrong model in request");
         Assert
           (Boolean'(Body_JS.Get ("stream").Get),
            "stream should be true");
         Assert
           (Integer'(Body_JS.Get ("max_output_tokens").Get) = 128,
            "max_output_tokens should be 128");
         Assert
           (Json_String (Body_JS.Get ("instructions")) = "Be helpful.",
            "instructions should carry the system prompt");
         Assert
           (not Body_JS.Has_Field ("messages"),
            "Responses request must not use messages");
         Assert
           (not Body_JS.Has_Field ("store")
            or else Body_JS.Get ("store").Kind = GNATCOLL.JSON.JSON_Boolean_Type,
            "store field unexpected shape");
         if Body_JS.Has_Field ("store") then
            Assert
              (not Boolean'(Body_JS.Get ("store").Get),
               "store must not be true");
         end if;
         Assert
           (not Body_JS.Has_Field ("previous_response_id")
            or else Body_JS.Get ("previous_response_id").Kind
              = GNATCOLL.JSON.JSON_Null_Type,
            "previous_response_id must not be sent");
         Input  := Body_JS.Get ("input").Get;
         Item_0 := GNATCOLL.JSON.Get (Input, 1);
         Assert
           (Json_String (Item_0.Get ("role")) = "user",
            "input[0].role should be user");
         Res.Status := 200;
         Ada.Strings.Unbounded.Append (Res.Body_Data, Payload);
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
   begin
      Reset_Collector;
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
        (Current_Collector.Sequence.Find_Index ("text_delta:Hello") > 0,
         "Text delta should contain Hello: " & Sequence_Image);
      Assert
        (Count_Event ("text_delta:Hello") = 1,
         "Completed output must not duplicate streamed text: "
         & Sequence_Image);
      Assert
        (Current_Collector.Last_Stop = LLM.Types.Stop,
         "Stop reason should map to Stop");
      Assert (Current_Collector.Usage.Input = 10, "Usage.Input should be 10");
      Assert
        (Current_Collector.Usage.Output = 5, "Usage.Output should be 5");
   exception
      when others =>
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_Stream_Text_Response;

   procedure Test_Stream_Tool_Call_Response (T : in out Test) is
      pragma Unreferenced (T);

      Port     : constant Positive := 19_102;
      Provider : LLM.Providers.OpenAI_Responses.Provider :=
        LLM.Providers.OpenAI_Responses.Create
          (Base_Url => "http://127.0.0.1:19102",
           Api_Key  => "test-key");
      Messages : constant LLM.Types.Message_Vectors.Vector := User_Hello;
      Tools    : constant String :=
        "[{""type"":""function"",""name"":""read"","
        & """description"":""Read file"","
        & """parameters"":{""type"":""object""}}]";
      Payload  : constant String :=
        Build_Tool_SSE ("call_abc", "read", "{""path"":""a.adb""}");
      Saw_Flat_Tool : Boolean := False;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         Parsed : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (To_String (Req.Body_Data));
         Tools_A : GNATCOLL.JSON.JSON_Array;
         Tool_0  : GNATCOLL.JSON.JSON_Value;
      begin
         Assert (To_String (Req.Path) = "/responses", "path");
         Assert (Parsed.Success, "parse body");
         Tools_A := Parsed.Value.Get ("tools").Get;
         Tool_0 := GNATCOLL.JSON.Get (Tools_A, 1);
         Assert
           (Json_String (Tool_0.Get ("type")) = "function",
            "tool type");
         Assert
           (Tool_0.Has_Field ("name"),
            "Responses tools must be flat (name at top level)");
         Assert
           (not Tool_0.Has_Field ("function"),
            "Responses tools must not nest a function object");
         Saw_Flat_Tool := True;
         Res.Status := 200;
         Ada.Strings.Unbounded.Append (Res.Body_Data, Payload);
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
   begin
      Reset_Collector;
      Srv.Bind (Port);
      Send_With_Retry
        (P             => Provider,
         Model_Id      => "test-model",
         System_Prompt => "",
         Messages      => Messages,
         Tools_Json    => Tools,
         Max_Tokens    => 64,
         Handler       => On_Event'Access);
      Srv.Stop;
      Server_Stopped := True;
      Assert (Saw_Flat_Tool, "handler should have seen a flat tool");
      Assert
        (Current_Collector.Sequence.Find_Index
           ("tool_call_start:call_abc:read") > 0,
         "tool start: " & Sequence_Image);
      Assert
        (Current_Collector.Last_Stop = LLM.Types.Tool_Use,
         "function_call output should map to Tool_Use");
   exception
      when others =>
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_Stream_Tool_Call_Response;

   procedure Test_Stream_Thinking_Response (T : in out Test) is
      pragma Unreferenced (T);

      Port     : constant Positive := 19_103;
      Provider : LLM.Providers.OpenAI_Responses.Provider :=
        LLM.Providers.OpenAI_Responses.Create
          (Base_Url => "http://127.0.0.1:19103",
           Api_Key  => "test-key");
      Messages : constant LLM.Types.Message_Vectors.Vector := User_Hello;
      Payload  : constant String :=
        Build_Thinking_SSE ("pondering", "done");

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 200;
         Ada.Strings.Unbounded.Append (Res.Body_Data, Payload);
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
   begin
      Reset_Collector;
      Srv.Bind (Port);
      Send_With_Retry
        (P             => Provider,
         Model_Id      => "o4-mini",
         System_Prompt => "",
         Messages      => Messages,
         Tools_Json    => "[]",
         Thinking      => LLM.Providers.High,
         Max_Tokens    => 64,
         Handler       => On_Event'Access);
      Srv.Stop;
      Server_Stopped := True;
      Assert
        (Current_Collector.Sequence.Find_Index
           ("thinking_delta:pondering") > 0,
         "thinking delta: " & Sequence_Image);
      Assert
        (Current_Collector.Sequence.Find_Index
           ("thinking_end") > 0,
         "thinking end should be emitted: " & Sequence_Image);
      Assert
        (Current_Collector.Sequence.Find_Index ("text_delta:done") > 0,
         "text after thinking: " & Sequence_Image);
      Assert
        (Current_Collector.Usage.Thinking = 7,
         "reasoning_tokens should map to Usage.Thinking");
   exception
      when others =>
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_Stream_Thinking_Response;

   procedure Test_Compaction_Summary_Encodes_As_User (T : in out Test) is
      pragma Unreferenced (T);

      Port     : constant Positive := 19_104;
      Provider : LLM.Providers.OpenAI_Responses.Provider :=
        LLM.Providers.OpenAI_Responses.Create
          (Base_Url => "http://127.0.0.1:19104",
           Api_Key  => "test-key");
      Messages : LLM.Types.Message_Vectors.Vector;
      Content  : LLM.Types.Content_Block_Vectors.Vector;
      Role_OK  : Boolean := False;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         Parsed : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (To_String (Req.Body_Data));
         Input  : GNATCOLL.JSON.JSON_Array;
         Item   : GNATCOLL.JSON.JSON_Value;
      begin
         Assert (Parsed.Success, "parse");
         Input := Parsed.Value.Get ("input").Get;
         Item := GNATCOLL.JSON.Get (Input, 1);
         Assert
           (Json_String (Item.Get ("role")) = "user",
            "compaction summary must encode as user");
         Role_OK := True;
         Res.Status := 200;
         Ada.Strings.Unbounded.Append (Res.Body_Data, Build_Text_SSE ("ok", 1, 1));
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
   begin
      Reset_Collector;
      Content.Append
        ((Kind => LLM.Types.Text_Block,
          Text => To_Unbounded_String ("prior conversation summary")));
      Messages.Append
        ((Role      => LLM.Types.Compaction_Summary,
          Content   => Content,
          Tok_Usage => (others => 0),
          Stop      => LLM.Types.Unknown_Stop,
          Timestamp => Null_Unbounded_String));
      Srv.Bind (Port);
      Send_With_Retry
        (P             => Provider,
         Model_Id      => "test-model",
         System_Prompt => "",
         Messages      => Messages,
         Tools_Json    => "[]",
         Max_Tokens    => 32,
         Handler       => On_Event'Access);
      Srv.Stop;
      Server_Stopped := True;
      Assert (Role_OK, "handler should have seen user-encoded summary");
   exception
      when others =>
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_Compaction_Summary_Encodes_As_User;

   procedure Test_Non_Streaming_Response (T : in out Test) is
      pragma Unreferenced (T);

      Port     : constant Positive := 19_105;
      Provider : LLM.Providers.OpenAI_Responses.Provider :=
        LLM.Providers.OpenAI_Responses.Create
          (Base_Url => "http://127.0.0.1:19105",
           Api_Key  => "test-key");
      Messages : constant LLM.Types.Message_Vectors.Vector := User_Hello;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
         Payload : constant String :=
           GNATCOLL.JSON.Write (Completed_Response ("Hi", 4, 2));
      begin
         Res.Status := 200;
         Ada.Strings.Unbounded.Append (Res.Body_Data, Payload);
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
   begin
      Reset_Collector;
      LLM.Providers.OpenAI_Responses.Testing.Set_Streaming
        (Provider, False);
      Srv.Bind (Port);
      Send_With_Retry
        (P             => Provider,
         Model_Id      => "test-model",
         System_Prompt => "",
         Messages      => Messages,
         Tools_Json    => "[]",
         Max_Tokens    => 32,
         Handler       => On_Event'Access);
      Srv.Stop;
      Server_Stopped := True;
      Assert
        (Current_Collector.Sequence.Find_Index ("text_delta:Hi") > 0,
         "non-streaming text: " & Sequence_Image);
      Assert (Current_Collector.Last_Stop = LLM.Types.Stop, "stop");
   exception
      when others =>
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_Non_Streaming_Response;

   procedure Test_HTTP_Error_Propagates (T : in out Test) is
      pragma Unreferenced (T);

      Port     : constant Positive := 19_106;
      Provider : LLM.Providers.OpenAI_Responses.Provider :=
        LLM.Providers.OpenAI_Responses.Create
          (Base_Url => "http://127.0.0.1:19106",
           Api_Key  => "bad-key");
      Messages : constant LLM.Types.Message_Vectors.Vector := User_Hello;
      Raised   : Boolean := False;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 401;
         Ada.Strings.Unbounded.Append (Res.Body_Data, "{""error"":{""message"":""nope""}}");
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
            Model_Id      => "test-model",
            System_Prompt => "",
            Messages      => Messages,
            Tools_Json    => "[]",
            Max_Tokens    => 16,
            Handler       => On_Event'Access);
      exception
         when Constraint_Error =>
            Raised := True;
      end;
      Srv.Stop;
      Server_Stopped := True;
      Assert (Raised, "HTTP 401 should raise Constraint_Error");
      Assert
        (Current_Collector.Sequence.Find_Index ("agent_end") > 0,
         "agent_end should still fire");
   exception
      when others =>
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_HTTP_Error_Propagates;

   procedure Test_Usage_Includes_Cache_Write (T : in out Test) is
      pragma Unreferenced (T);

      Port     : constant Positive := 19_107;
      Provider : LLM.Providers.OpenAI_Responses.Provider :=
        LLM.Providers.OpenAI_Responses.Create
          (Base_Url => "http://127.0.0.1:19107",
           Api_Key  => "test-key");
      Messages : constant LLM.Types.Message_Vectors.Vector := User_Hello;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 200;
         Append
           (Res.Body_Data,
            Build_Text_SSE
              ("ok", 100, 10, Cached => 40, Cache_Write => 12));
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
   begin
      Reset_Collector;
      Srv.Bind (Port);
      Send_With_Retry
        (P             => Provider,
         Model_Id      => "test-model",
         System_Prompt => "",
         Messages      => Messages,
         Tools_Json    => "[]",
         Max_Tokens    => 32,
         Handler       => On_Event'Access);
      Srv.Stop;
      Server_Stopped := True;
      Assert
        (Current_Collector.Usage.Cache_Read = 40, "cached_tokens");
      Assert
        (Current_Collector.Usage.Cache_Write = 12, "cache_write_tokens");
   exception
      when others =>
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_Usage_Includes_Cache_Write;

   procedure Test_Tool_Result_Image_Serialised (T : in out Test) is
      pragma Unreferenced (T);

      Port     : constant Positive := 19_108;
      Provider : LLM.Providers.OpenAI_Responses.Provider :=
        LLM.Providers.OpenAI_Responses.Create
          (Base_Url => "http://127.0.0.1:19108",
           Api_Key  => "test-key");
      Messages       : LLM.Types.Message_Vectors.Vector;
      User_Content   : LLM.Types.Content_Block_Vectors.Vector;
      Asst_Content   : LLM.Types.Content_Block_Vectors.Vector;
      Result_Content : LLM.Types.Content_Block_Vectors.Vector;
      Image_OK       : Boolean := False;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         Parsed : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (To_String (Req.Body_Data));
         Input  : GNATCOLL.JSON.JSON_Array;
         Found  : Boolean := False;
      begin
         Assert (Parsed.Success, "parse");
         Input := Parsed.Value.Get ("input").Get;
         for I in 1 .. GNATCOLL.JSON.Length (Input) loop
            declare
               Item : constant GNATCOLL.JSON.JSON_Value :=
                 GNATCOLL.JSON.Get (Input, I);
            begin
               if Field_String (Item, "type") = "function_call_output"
               then
                  declare
                     Output : constant GNATCOLL.JSON.JSON_Value :=
                       Item.Get ("output");
                     Part   : GNATCOLL.JSON.JSON_Value;
                  begin
                     Assert
                       (Output.Kind = GNATCOLL.JSON.JSON_Array_Type,
                        "image output should be an array");
                     Part := GNATCOLL.JSON.Get (Output.Get, 1);
                     Assert
                       (Json_String (Part.Get ("type")) = "input_image",
                        "part type");
                     Assert
                       (Json_String (Part.Get ("image_url")) =
                          "data:image/png;base64,SGVsbG8=",
                        "data uri");
                     Found := True;
                  end;
               end if;
            end;
         end loop;
         Assert (Found, "function_call_output with image not found");
         Image_OK := True;
         Res.Status := 200;
         Ada.Strings.Unbounded.Append (Res.Body_Data, Build_Text_SSE ("seen", 1, 1));
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
   begin
      Reset_Collector;
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
          Tool_Call_Id   => To_Unbounded_String ("call_img"),
          Tool_Name      => To_Unbounded_String ("shell"),
          Arguments_Json => To_Unbounded_String ("{}")));
      Messages.Append
        ((Role      => LLM.Types.Assistant,
          Content   => Asst_Content,
          Tok_Usage => (others => 0),
          Stop      => LLM.Types.Tool_Use,
          Timestamp => Null_Unbounded_String));
      Result_Content.Append
        ((Kind        => LLM.Types.Tool_Result_Block,
          Result_Id   => To_Unbounded_String ("call_img"),
          Result_Text => To_Unbounded_String ("SGVsbG8="),
          Media_Type  => To_Unbounded_String ("image/png"),
          Is_Error    => False));
      Messages.Append
        ((Role      => LLM.Types.Tool_Result,
          Content   => Result_Content,
          Tok_Usage => (others => 0),
          Stop      => LLM.Types.Unknown_Stop,
          Timestamp => Null_Unbounded_String));
      Srv.Bind (Port);
      Send_With_Retry
        (P             => Provider,
         Model_Id      => "test-model",
         System_Prompt => "",
         Messages      => Messages,
         Tools_Json    => "[]",
         Max_Tokens    => 32,
         Handler       => On_Event'Access);
      Srv.Stop;
      Server_Stopped := True;
      Assert (Image_OK, "image encoding assertions should have run");
   exception
      when others =>
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_Tool_Result_Image_Serialised;

   procedure Test_Reasoning_Item_Replayed (T : in out Test) is
      pragma Unreferenced (T);

      Port     : constant Positive := 19_109;
      Provider : LLM.Providers.OpenAI_Responses.Provider :=
        LLM.Providers.OpenAI_Responses.Create
          (Base_Url => "http://127.0.0.1:19109",
           Api_Key  => "test-key");
      Messages : LLM.Types.Message_Vectors.Vector;
      User_C   : LLM.Types.Content_Block_Vectors.Vector;
      Asst_C   : LLM.Types.Content_Block_Vectors.Vector;
      Replayed : Boolean := False;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         Parsed : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (To_String (Req.Body_Data));
         Input           : GNATCOLL.JSON.JSON_Array;
         Found           : Boolean := False;
         Reasoning_Count : Natural := 0;
      begin
         Assert (Parsed.Success, "parse");
         Input := Parsed.Value.Get ("input").Get;
         for I in 1 .. GNATCOLL.JSON.Length (Input) loop
            declare
               Item : constant GNATCOLL.JSON.JSON_Value :=
                 GNATCOLL.JSON.Get (Input, I);
            begin
               if Item.Has_Field ("type")
                 and then Item.Get ("type").Kind = GNATCOLL.JSON.JSON_String_Type
                 and then String'(Item.Get ("type").Get) = "reasoning"
               then
                  Reasoning_Count := Reasoning_Count + 1;
                  Assert
                    (Item.Has_Field ("encrypted_content"),
                     "encrypted_content should be replayed");
                  Assert
                    (Json_String (Item.Get ("encrypted_content")) =
                       "enc-secret",
                     "encrypted_content value");
                  Assert
                    (Json_String (Item.Get ("id")) = "rs_test",
                     "reasoning item id value");
                  Found := True;
               end if;
            end;
         end loop;
         Assert (Found, "reasoning item missing from input");
         Assert
           (Reasoning_Count = 1,
            "opaque signatures must not become Responses reasoning items");
         Replayed := True;
         Res.Status := 200;
         Ada.Strings.Unbounded.Append (Res.Body_Data, Build_Text_SSE ("ok", 1, 1));
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
   begin
      Reset_Collector;
      User_C.Append
        ((Kind => LLM.Types.Text_Block,
          Text => To_Unbounded_String ("why?")));
      Messages.Append
        ((Role      => LLM.Types.User,
          Content   => User_C,
          Tok_Usage => (others => 0),
          Stop      => LLM.Types.Unknown_Stop,
          Timestamp => Null_Unbounded_String));
      Asst_C.Append
        ((Kind            => LLM.Types.Thinking_Block,
          Thinking        => To_Unbounded_String ("because"),
          Signature       => To_Unbounded_String
            ("{""id"":""rs_test"",""encrypted_content"":""enc-secret""}"),
          Origin_Provider => To_Unbounded_String ("openrouter"),
          Origin_Model    => To_Unbounded_String ("test-model")));
      Asst_C.Append
        ((Kind            => LLM.Types.Thinking_Block,
          Thinking        => To_Unbounded_String ("foreign thinking"),
          Signature       => To_Unbounded_String
            ("opaque-anthropic-signature"),
          Origin_Provider => To_Unbounded_String ("anthropic"),
          Origin_Model    => To_Unbounded_String ("claude-test")));
      Asst_C.Append
        ((Kind => LLM.Types.Text_Block,
          Text => To_Unbounded_String ("answer")));
      Messages.Append
        ((Role      => LLM.Types.Assistant,
          Content   => Asst_C,
          Tok_Usage => (others => 0),
          Stop      => LLM.Types.Stop,
          Timestamp => Null_Unbounded_String));
      Srv.Bind (Port);
      Send_With_Retry
        (P             => Provider,
         Model_Id      => "test-model",
         System_Prompt => "",
         Messages      => Messages,
         Tools_Json    => "[]",
         Max_Tokens    => 32,
         Handler       => On_Event'Access);
      Srv.Stop;
      Server_Stopped := True;
      Assert (Replayed, "reasoning replay assertions should have run");
   exception
      when others =>
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_Reasoning_Item_Replayed;

   procedure Test_Omits_Store_And_Previous_Response (T : in out Test) is
      pragma Unreferenced (T);

      Port     : constant Positive := 19_110;
      Provider : LLM.Providers.OpenAI_Responses.Provider :=
        LLM.Providers.OpenAI_Responses.Create
          (Base_Url => "http://127.0.0.1:19110",
           Api_Key  => "test-key");
      Messages : constant LLM.Types.Message_Vectors.Vector := User_Hello;
      Clean    : Boolean := False;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         Parsed : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (To_String (Req.Body_Data));
      begin
         Assert (Parsed.Success, "parse");
         Assert
           (not Parsed.Value.Has_Field ("store"),
            "store must be omitted");
         Assert
           (not Parsed.Value.Has_Field ("previous_response_id"),
            "previous_response_id must be omitted");
         Assert
           (Parsed.Value.Has_Field ("include"),
            "include should request encrypted reasoning");
         Clean := True;
         Res.Status := 200;
         Ada.Strings.Unbounded.Append (Res.Body_Data, Build_Text_SSE ("ok", 1, 1));
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
   begin
      Reset_Collector;
      Srv.Bind (Port);
      Send_With_Retry
        (P             => Provider,
         Model_Id      => "test-model",
         System_Prompt => "",
         Messages      => Messages,
         Tools_Json    => "[]",
         Max_Tokens    => 16,
         Handler       => On_Event'Access);
      Srv.Stop;
      Server_Stopped := True;
      Assert (Clean, "stateless-field assertions should have run");
   exception
      when others =>
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_Omits_Store_And_Previous_Response;

end LLM_OpenAI_Responses_Tests;
