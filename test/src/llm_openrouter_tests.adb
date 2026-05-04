with AUnit.Assertions;
with Ada.Calendar;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNATCOLL.JSON;
with LLM.Events;
with LLM.HTTP;
with LLM.Providers;
with LLM.Providers.OpenRouter;
with LLM.Types;
with Test_HTTP_Server;

package body LLM_OpenRouter_Tests is

   use AUnit.Assertions;
   use type GNATCOLL.JSON.JSON_Value_Type;
   use type LLM.Events.Message_Update_Kind;

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
   begin
      Delete_If_Exists (Agent_Dir & "/openrouter_models_cache.json");
      Delete_If_Exists (Agent_Dir & "/openrouter_models_cache.json.tmp");
      Delete_If_Exists (Agent_Dir & "/models.json");

      if Ada.Directories.Exists (Agent_Dir) then
         Ada.Directories.Delete_Directory (Agent_Dir);
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

   procedure Send_With_Retry
      (P             : in out LLM.Providers.OpenRouter.Provider;
       Model_Id      :        String;
       Messages      :        LLM.Types.Message_Vectors.Vector;
       Thinking      :        LLM.Providers.Thinking_Level :=
                                 LLM.Providers.Off)
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

   function Build_Text_SSE_Payload
      (Text              : String;
       Prompt_Tokens     : Natural;
       Completion_Tokens : Natural) return String
   is
      use GNATCOLL.JSON;

      Delta_Event  : constant JSON_Value := Create_Object;
      Delta_Choice : constant JSON_Value := Create_Object;
      Delta_Value        : constant JSON_Value := Create_Object;
      Finish_Event : constant JSON_Value := Create_Object;
      Finish_Choice : constant JSON_Value := Create_Object;
      Finish_Delta : constant JSON_Value := Create_Object;
      Usage        : constant JSON_Value := Create_Object;
      Choices      : JSON_Array := Empty_Array;
   begin
      Delta_Value.Set_Field ("content", Text);
      Delta_Choice.Set_Field ("delta", Delta_Value);
      Delta_Choice.Set_Field ("finish_reason", JSON_Null);
      Append (Choices, Delta_Choice);
      Delta_Event.Set_Field ("choices", Choices);

      Choices := Empty_Array;
      Finish_Choice.Set_Field ("delta", Finish_Delta);
      Finish_Choice.Set_Field ("finish_reason", "stop");
      Append (Choices, Finish_Choice);
      Finish_Event.Set_Field ("choices", Choices);
      Usage.Set_Field ("prompt_tokens", Integer (Prompt_Tokens));
      Usage.Set_Field ("completion_tokens", Integer (Completion_Tokens));
      Finish_Event.Set_Field ("usage", Usage);

      return SSE_Record (Delta_Event)
         & SSE_Record (Finish_Event)
         & SSE_Record ("[DONE]");
   end Build_Text_SSE_Payload;

   function Build_Live_Models_Body return String is
      use GNATCOLL.JSON;

      Root                 : constant JSON_Value := Create_Object;
      Model                : constant JSON_Value := Create_Object;
      Architecture         : constant JSON_Value := Create_Object;
      Pricing              : constant JSON_Value := Create_Object;
      Top_Provider         : constant JSON_Value := Create_Object;
      Data_Array           : JSON_Array := Empty_Array;
      Input_Modalities     : JSON_Array := Empty_Array;
      Output_Modalities    : JSON_Array := Empty_Array;
      Supported_Parameters : JSON_Array := Empty_Array;
   begin
      Model.Set_Field ("id", "test/model");
      Model.Set_Field ("name", "Test Model");
      Model.Set_Field ("context_length", Integer (4096));
      Append (Input_Modalities, Create ("text"));
      Append (Output_Modalities, Create ("text"));
      Architecture.Set_Field ("input_modalities", Input_Modalities);
      Architecture.Set_Field ("output_modalities", Output_Modalities);
      Model.Set_Field ("architecture", Architecture);
      Pricing.Set_Field ("prompt", "0.000001");
      Pricing.Set_Field ("completion", "0.000002");
      Model.Set_Field ("pricing", Pricing);
      Top_Provider.Set_Field ("context_length", Integer (4096));
      Top_Provider.Set_Field ("max_completion_tokens", Integer (256));
      Model.Set_Field ("top_provider", Top_Provider);
      Append (Supported_Parameters, Create ("reasoning"));
      Model.Set_Field ("supported_parameters", Supported_Parameters);
      Append (Data_Array, Model);
      Root.Set_Field ("data", Data_Array);
      return Write (Root);
   end Build_Live_Models_Body;

   --  SSE payload used by header and reasoning tests: streams "Hello".
   Hello_SSE_Payload : constant String :=
      Build_Text_SSE_Payload
         (Text              => "Hello",
          Prompt_Tokens     => 1,
          Completion_Tokens => 1);

   --  SSE payload used by the settings fallback test: streams "Settings".
   Settings_SSE_Payload : constant String :=
      Build_Text_SSE_Payload
         (Text              => "Settings",
          Prompt_Tokens     => 1,
          Completion_Tokens => 1);

   --  SSE payload used by the live-fetch-then-send test: streams "Live".
   Live_SSE_Payload : constant String :=
      Build_Text_SSE_Payload
         (Text              => "Live",
          Prompt_Tokens     => 1,
          Completion_Tokens => 1);

   --  Models catalogue JSON body served by the live-fetch-then-send handler.
   Live_Models_Body : constant String := Build_Live_Models_Body;

   procedure Test_Send_Adds_OpenRouter_Headers (T : in out Test) is
      pragma Unreferenced (T);

      Port        : constant Positive := 18_771;
      Messages    : constant LLM.Types.Message_Vectors.Vector :=
         Build_Messages;
      Provider    : LLM.Providers.OpenRouter.Provider :=
         LLM.Providers.OpenRouter.Create;
      Key_Was_Set : constant Boolean :=
         Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key     : constant String :=
         Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         Parsed  : constant GNATCOLL.JSON.Read_Result :=
            GNATCOLL.JSON.Read (To_String (Req.Body_Data));
         Body_JS : GNATCOLL.JSON.JSON_Value;
      begin
         Assert
            (To_String (Req.Path) = "/api/v1/chat/completions",
             "Expected path /api/v1/chat/completions");
         Assert
            (Test_HTTP_Server.Get_Header
                (Req.Headers, "Authorization") = "Bearer env-test-key",
             "Expected Authorization: Bearer env-test-key");
         Assert
            (Test_HTTP_Server.Get_Header
                (Req.Headers, "HTTP-Referer")
             = "https://github.com/gtnoble/coyote",
             "Expected HTTP-Referer header");
         Assert
            (Test_HTTP_Server.Get_Header
                (Req.Headers, "X-Title") = "coyote",
             "Expected X-Title: coyote");
         Assert (Parsed.Success, "Failed to parse request body as JSON");
         Body_JS := Parsed.Value;
         Assert
            (Body_JS.Has_Field ("model")
             and then Body_JS.Get ("model").Kind
                = GNATCOLL.JSON.JSON_String_Type
             and then String'(Body_JS.Get ("model").Get)
                = "openai/gpt-4o-mini",
             "Expected model openai/gpt-4o-mini");
         Assert
            (not Body_JS.Has_Field ("reasoning"),
             "Expected no reasoning field for Off thinking level");
         Res.Status := 200;
         Append (Res.Body_Data, Hello_SSE_Payload);
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
   begin
      Reset_Collector;
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "env-test-key");
      LLM.Providers.OpenRouter.Set_Base_Url
         (Provider, "http://127.0.0.1:18771/api/v1");

      Srv.Bind (Port);

      Send_With_Retry
         (P        => Provider,
          Model_Id => "openai/gpt-4o-mini",
          Messages => Messages);

      Srv.Stop;
      Server_Stopped := True;

      Assert (To_String (Last_Text) = "Hello", "Expected streamed Hello text");

      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
   exception
      when others =>
         if not Server_Stopped then
            Srv.Stop;
         end if;
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         raise;
   end Test_Send_Adds_OpenRouter_Headers;

   procedure Test_Send_Includes_Reasoning_Effort (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_openrouter_test_home";
      Port         : constant Positive := 18_772;
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

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         Parsed  : constant GNATCOLL.JSON.Read_Result :=
            GNATCOLL.JSON.Read (To_String (Req.Body_Data));
         Body_JS : GNATCOLL.JSON.JSON_Value;
      begin
         Assert
            (To_String (Req.Path) = "/api/v1/chat/completions",
             "Expected path /api/v1/chat/completions");
         Assert
            (Test_HTTP_Server.Get_Header
                (Req.Headers, "Authorization") = "Bearer reasoning-key",
             "Expected Authorization: Bearer reasoning-key");
         Assert (Parsed.Success, "Failed to parse request body as JSON");
         Body_JS := Parsed.Value;
         Assert
            (Body_JS.Has_Field ("model")
             and then Body_JS.Get ("model").Kind
                = GNATCOLL.JSON.JSON_String_Type
             and then String'(Body_JS.Get ("model").Get)
                = "anthropic/claude-sonnet-4-20250514",
             "Expected model anthropic/claude-sonnet-4-20250514");
         Assert
            (Body_JS.Has_Field ("reasoning")
             and then Body_JS.Get ("reasoning").Kind
                = GNATCOLL.JSON.JSON_Object_Type
             and then Body_JS.Get ("reasoning").Has_Field ("effort")
             and then String'(Body_JS.Get ("reasoning").Get ("effort").Get)
                = "medium",
             "Expected reasoning.effort = medium");
         Res.Status := 200;
         Append (Res.Body_Data, Hello_SSE_Payload);
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
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

      Srv.Bind (Port);

      Send_With_Retry
         (P        => Provider,
          Model_Id => "anthropic/claude-sonnet-4-20250514",
          Messages => Messages,
          Thinking => LLM.Providers.Medium);

      Srv.Stop;
      Server_Stopped := True;

      Assert (To_String (Last_Text) = "Hello", "Expected streamed Hello text");

      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            Srv.Stop;
         end if;
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
      Capture    : GNATCOLL.JSON.JSON_Value;
      Cache_Text : Unbounded_String;

      --  Protected object to track which endpoints have been served.
      --  Also accumulates captured fields for the chat POST request.
      protected type Endpoint_State is
         procedure Set_Models_Served;
         procedure Set_Chat_Served
            (Auth    : String;
             Effort  : String;
             Model   : String);
         function Models_Calls return Natural;
         function Chat_Calls   return Natural;
         function Chat_Authorization return String;
         function Reasoning_Effort    return String;
         function Chat_Model          return String;
      private
         Models_Count : Natural := 0;
         Chat_Count   : Natural := 0;
         Auth_Val     : Unbounded_String;
         Effort_Val   : Unbounded_String;
         Model_Val    : Unbounded_String;
      end Endpoint_State;

      protected body Endpoint_State is
         procedure Set_Models_Served is
         begin
            Models_Count := Models_Count + 1;
         end Set_Models_Served;

         procedure Set_Chat_Served
            (Auth    : String;
             Effort  : String;
             Model   : String)
         is
         begin
            Chat_Count   := Chat_Count + 1;
            Auth_Val     := To_Unbounded_String (Auth);
            Effort_Val   := To_Unbounded_String (Effort);
            Model_Val    := To_Unbounded_String (Model);
         end Set_Chat_Served;

         function Models_Calls return Natural is
         begin
            return Models_Count;
         end Models_Calls;

         function Chat_Calls return Natural is
         begin
            return Chat_Count;
         end Chat_Calls;

         function Chat_Authorization return String is
         begin
            return To_String (Auth_Val);
         end Chat_Authorization;

         function Reasoning_Effort return String is
         begin
            return To_String (Effort_Val);
         end Reasoning_Effort;

         function Chat_Model return String is
         begin
            return To_String (Model_Val);
         end Chat_Model;
      end Endpoint_State;

      State : Endpoint_State;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         Method : constant String := To_String (Req.Method);
         Path   : constant String := To_String (Req.Path);
      begin
         if Method = "GET" and then Path = "/api/v1/models" then
            State.Set_Models_Served;
            Res.Status := 200;
            declare
               Header : Test_HTTP_Server.Header_Pair;
            begin
               Header.Name  := To_Unbounded_String ("Content-Type");
               Header.Value := To_Unbounded_String ("application/json");
               Res.Headers.Append (Header);
            end;
            Append (Res.Body_Data, Live_Models_Body);

         elsif Method = "POST"
               and then Path = "/api/v1/chat/completions"
         then
            declare
               Parsed : constant GNATCOLL.JSON.Read_Result :=
                  GNATCOLL.JSON.Read (To_String (Req.Body_Data));
               Auth   : constant String :=
                  Test_HTTP_Server.Get_Header
                     (Req.Headers, "Authorization");
               Effort : Unbounded_String;
               Model  : Unbounded_String;
            begin
               if Parsed.Success then
                  declare
                     Body_JS : constant GNATCOLL.JSON.JSON_Value :=
                        Parsed.Value;
                  begin
                     if Body_JS.Has_Field ("model")
                        and then Body_JS.Get ("model").Kind
                           = GNATCOLL.JSON.JSON_String_Type
                     then
                        Model :=
                           To_Unbounded_String
                              (String'(Body_JS.Get ("model").Get));
                     end if;

                     if Body_JS.Has_Field ("reasoning")
                        and then Body_JS.Get ("reasoning").Kind
                           = GNATCOLL.JSON.JSON_Object_Type
                        and then Body_JS.Get ("reasoning").Has_Field ("effort")
                     then
                        Effort :=
                           To_Unbounded_String
                              (String'(Body_JS.Get ("reasoning")
                               .Get ("effort").Get));
                     end if;
                  end;
               end if;

               State.Set_Chat_Served
                  (Auth   => Auth,
                   Effort => To_String (Effort),
                   Model  => To_String (Model));
            end;

            Res.Status := 200;
            declare
               Header : Test_HTTP_Server.Header_Pair;
            begin
               Header.Name  := To_Unbounded_String ("Content-Type");
               Header.Value := To_Unbounded_String ("text/event-stream");
               Res.Headers.Append (Header);
            end;
            Append (Res.Body_Data, Live_SSE_Payload);

         else
            Res.Status := 404;
         end if;

         --  Write the capture file after every request.
         declare
            Capture_JS : constant GNATCOLL.JSON.JSON_Value :=
               GNATCOLL.JSON.Create_Object;
            File       : Ada.Text_IO.File_Type;
         begin
            Capture_JS.Set_Field
               ("models_calls",
                Integer (State.Models_Calls));
            Capture_JS.Set_Field
               ("chat_calls",
                Integer (State.Chat_Calls));
            Capture_JS.Set_Field
               ("chat_authorization",
                State.Chat_Authorization);
            Capture_JS.Set_Field
               ("reasoning_effort",
                State.Reasoning_Effort);
            Capture_JS.Set_Field
               ("model",
                State.Chat_Model);
            Ada.Text_IO.Create
               (File, Ada.Text_IO.Out_File, Capture_Path);
            Ada.Text_IO.Put
               (File, GNATCOLL.JSON.Write (Capture_JS));
            Ada.Text_IO.Close (File);
         exception
            when others =>
               if Ada.Text_IO.Is_Open (File) then
                  Ada.Text_IO.Close (File);
               end if;
         end;
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
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

      Srv.Bind (Port);

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

      Srv.Stop;
      Server_Stopped := True;

      Wait_For_File (Capture_Path);
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
         (Ada.Strings.Fixed.Index
             (To_String (Cache_Text), "test/model") > 0,
          "The live catalogue should overwrite the stale cache contents");
      Assert
         (Ada.Strings.Fixed.Index
             (To_String (Cache_Text), "stale/model") = 0,
          "The stale cache entry should be replaced after the live fetch");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Base_Was_Set, Old_Base);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
      Delete_If_Exists (Capture_Path);
   exception
      when others =>
         if not Server_Stopped then
            Srv.Stop;
         end if;
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

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         Parsed : constant GNATCOLL.JSON.Read_Result :=
            GNATCOLL.JSON.Read (To_String (Req.Body_Data));
         Auth   : constant String :=
            Test_HTTP_Server.Get_Header (Req.Headers, "Authorization");
         Model  : Unbounded_String;
         File   : Ada.Text_IO.File_Type;
      begin
         if To_String (Req.Path) /= "/api/v1/chat/completions" then
            Res.Status := 404;
            return;
         end if;

         if Parsed.Success then
            declare
               Body_JS : constant GNATCOLL.JSON.JSON_Value := Parsed.Value;
            begin
               if Body_JS.Has_Field ("model")
                  and then Body_JS.Get ("model").Kind
                     = GNATCOLL.JSON.JSON_String_Type
               then
                  Model :=
                     To_Unbounded_String
                        (String'(Body_JS.Get ("model").Get));
               end if;
            end;
         end if;

         declare
            Capture_JS : constant GNATCOLL.JSON.JSON_Value :=
               GNATCOLL.JSON.Create_Object;
         begin
            Capture_JS.Set_Field ("authorization", Auth);
            Capture_JS.Set_Field ("model", To_String (Model));
            Ada.Text_IO.Create
               (File, Ada.Text_IO.Out_File, Capture_Path);
            Ada.Text_IO.Put
               (File, GNATCOLL.JSON.Write (Capture_JS));
            Ada.Text_IO.Close (File);
         exception
            when others =>
               if Ada.Text_IO.Is_Open (File) then
                  Ada.Text_IO.Close (File);
               end if;
         end;

         Res.Status := 200;
         declare
            Header : Test_HTTP_Server.Header_Pair;
         begin
            Header.Name  := To_Unbounded_String ("Content-Type");
            Header.Value := To_Unbounded_String ("text/event-stream");
            Res.Headers.Append (Header);
         end;
         Append (Res.Body_Data, Settings_SSE_Payload);
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
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

      Srv.Bind (Port);

      Send_With_Retry
         (P        => Provider,
          Model_Id => "openai/gpt-4o-mini",
          Messages => Messages);

      Srv.Stop;
      Server_Stopped := True;

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
         if not Server_Stopped then
            Srv.Stop;
         end if;
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         Delete_If_Exists (Capture_Path);
         raise;
   end Test_OpenRouter_Settings_Api_Key_Fallback;

end LLM_OpenRouter_Tests;
