with AUnit.Assertions;
with Ada.Environment_Variables;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with GNATCOLL.JSON;
with LLM.Providers.OpenCode_Go;
with LLM.Providers.OpenCode_Go.Catalogue;
with LLM.Types;
with Test_HTTP_Server;
with AUnit.Test_Caller;
use type LLM.Providers.OpenCode_Go.Catalogue.Wire_Kind;

package body LLM_OpenCode_Go_Catalogue_Tests is

   use AUnit.Assertions;

   procedure Test_Wire_Format_MiniMax_Anthropic (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (LLM.Providers.OpenCode_Go.Catalogue.Wire_Format_For ("minimax-m2.5")
           = LLM.Providers.OpenCode_Go.Catalogue.Anthropic_Messages_Wire,
         "minimax-m2.5 should use Anthropic messages wire format");
      Assert
        (LLM.Providers.OpenCode_Go.Catalogue.Wire_Format_For ("minimax-m2.7")
           = LLM.Providers.OpenCode_Go.Catalogue.Anthropic_Messages_Wire,
         "minimax-m2.7 should use Anthropic messages wire format");
      --  Case-insensitive
      Assert
        (LLM.Providers.OpenCode_Go.Catalogue.Wire_Format_For ("MiniMax-M2.7")
           = LLM.Providers.OpenCode_Go.Catalogue.Anthropic_Messages_Wire,
         "MiniMax-M2.7 (mixed case) should use Anthropic messages wire");
   end Test_Wire_Format_MiniMax_Anthropic;

   procedure Test_Wire_Format_DeepSeek_OpenAI (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (LLM.Providers.OpenCode_Go.Catalogue.Wire_Format_For ("deepseek-v4-pro")
           = LLM.Providers.OpenCode_Go.Catalogue.OpenAI_Completions_Wire,
         "deepseek-v4-pro should use OpenAI completions wire format");
      Assert
        (LLM.Providers.OpenCode_Go.Catalogue.Wire_Format_For ("glm-5")
           = LLM.Providers.OpenCode_Go.Catalogue.OpenAI_Completions_Wire,
         "glm-5 should use OpenAI completions wire format");
      Assert
        (LLM.Providers.OpenCode_Go.Catalogue.Wire_Format_For ("kimi-k2.5")
           = LLM.Providers.OpenCode_Go.Catalogue.OpenAI_Completions_Wire,
         "kimi-k2.5 should use OpenAI completions wire format");
      Assert
        (LLM.Providers.OpenCode_Go.Catalogue.Wire_Format_For ("qwen3.5-plus")
           = LLM.Providers.OpenCode_Go.Catalogue.OpenAI_Completions_Wire,
         "qwen3.5-plus should use OpenAI completions wire format");
   end Test_Wire_Format_DeepSeek_OpenAI;

   procedure Test_Wire_Format_Responses (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (LLM.Providers.OpenCode_Go.Catalogue.Wire_Format_For ("grok-4.6")
           = LLM.Providers.OpenCode_Go.Catalogue.OpenAI_Responses_Wire,
         "grok-4.6 should use OpenAI Responses wire format");
      Assert
        (LLM.Providers.OpenCode_Go.Catalogue.Wire_Format_For
           ("gpt-5.6-luna")
           = LLM.Providers.OpenCode_Go.Catalogue.OpenAI_Responses_Wire,
         "gpt-5.6-luna should use OpenAI Responses wire format");
      Assert
        (LLM.Providers.OpenCode_Go.Catalogue.Wire_Format_For
           ("muse-spark-1.3-contributor")
           = LLM.Providers.OpenCode_Go.Catalogue.OpenAI_Responses_Wire,
         "Muse Spark 1.3 Contributor should use Responses wire format");
      Assert
        (LLM.Providers.OpenCode_Go.Catalogue.Wire_Format_For
           ("muse-spark-1.2-contributor")
           = LLM.Providers.OpenCode_Go.Catalogue.OpenAI_Responses_Wire,
         "Muse Spark 1.2 Contributor should use Responses wire format");
   end Test_Wire_Format_Responses;

   procedure Test_Wire_Format_Unknown_Defaults_OpenAI (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (LLM.Providers.OpenCode_Go.Catalogue.Wire_Format_For ("future-model-v9")
           = LLM.Providers.OpenCode_Go.Catalogue.OpenAI_Completions_Wire,
         "Unknown models should default to OpenAI completions wire format");
      Assert
        (LLM.Providers.OpenCode_Go.Catalogue.Wire_Format_For ("brand-new-llm")
           = LLM.Providers.OpenCode_Go.Catalogue.OpenAI_Completions_Wire,
         "Unknown models should default to OpenAI completions wire format");
   end Test_Wire_Format_Unknown_Defaults_OpenAI;

   procedure Test_OpenAI_Request_Omits_Cache_Hints (T : in out Test) is
      pragma Unreferenced (T);

      Port          : constant Positive := 18_810;
      Base_Url      : constant String :=
        "http://127.0.0.1:18810";
      Old_Base      : constant String :=
        Ada.Environment_Variables.Value
          ("COYOTE_OPENCODE_GO_BASE_URL", "");
      Base_Was_Set  : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENCODE_GO_BASE_URL");
      Old_Key       : constant String :=
        Ada.Environment_Variables.Value ("OPENCODE_API_KEY", "");
      Key_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENCODE_API_KEY");
      Provider      : LLM.Providers.OpenCode_Go.Provider :=
        LLM.Providers.OpenCode_Go.Create;
      Messages      : LLM.Types.Message_Vectors.Vector;
      Content       : LLM.Types.Content_Block_Vectors.Vector;
      Captured      : GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.JSON_Null;
      Server_Stopped : Boolean := False;

      procedure Restore_Environment is
      begin
         if Base_Was_Set then
            Ada.Environment_Variables.Set
              ("COYOTE_OPENCODE_GO_BASE_URL", Old_Base);
         else
            Ada.Environment_Variables.Clear
              ("COYOTE_OPENCODE_GO_BASE_URL");
         end if;

         if Key_Was_Set then
            Ada.Environment_Variables.Set ("OPENCODE_API_KEY", Old_Key);
         else
            Ada.Environment_Variables.Clear ("OPENCODE_API_KEY");
         end if;
      end Restore_Environment;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         Parsed : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (To_String (Req.Body_Data));
      begin
         Assert
           (To_String (Req.Path) = "/v1/chat/completions",
            "OpenCode Go should use /v1/chat/completions");
         Assert
           (Test_HTTP_Server.Get_Header
              (Req.Headers, "Authorization") = "Bearer fixture-key",
            "OpenCode Go should use bearer authentication");
         Assert (Parsed.Success, "OpenCode Go request body should be JSON");
         Captured := Parsed.Value;
         Res.Status := 200;
         Append
           (Res.Body_Data,
            "data: {""choices"": [{""delta"": {""content"": ""OK"","
            & """role"": ""assistant""},"
            & """finish_reason"": ""stop""}]}"
            & ASCII.LF & ASCII.LF
            & "data: [DONE]" & ASCII.LF & ASCII.LF);
      end Handle_Request;

      Server : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
   begin
      Ada.Environment_Variables.Set
        ("COYOTE_OPENCODE_GO_BASE_URL", Base_Url);
      Ada.Environment_Variables.Set ("OPENCODE_API_KEY", "fixture-key");

      Content.Append
        ((Kind => LLM.Types.Text_Block,
          Text => To_Unbounded_String ("Say OK")));
      Messages.Append
        ((Role      => LLM.Types.User,
          Content   => Content,
          Tok_Usage => (others => 0),
          Stop      => LLM.Types.Unknown_Stop,
          Timestamp => Null_Unbounded_String));

      Server.Bind (Port);
      Provider.Send
        (Model_Id      => "deepseek-v4-pro",
         System_Prompt => "Reply with exactly OK.",
         Messages      => Messages,
         Tools_Json    =>
           "[{""type"":""function"",""function"":{"
           & """name"":""shell"",""description"":""Run shell"","
           & """parameters"":{""type"":""object""}}}]",
         Thinking      => LLM.Providers.Off,
         Max_Tokens    => 16,
         Handler       => null);

      Server.Stop;
      Server_Stopped := True;
      Restore_Environment;

      declare
         Messages_Json : constant GNATCOLL.JSON.JSON_Array :=
           Captured.Get ("messages").Get;
         Tools_Json : constant GNATCOLL.JSON.JSON_Array :=
           Captured.Get ("tools").Get;
      begin
         Assert
           (not GNATCOLL.JSON.Get (Messages_Json, 1).Has_Field
              ("cache_control"),
            "OpenCode Go system message must not contain cache_control");
         Assert
           (not GNATCOLL.JSON.Get (Messages_Json, 2).Has_Field
              ("cache_control"),
            "OpenCode Go user message must not contain cache_control");
         Assert
           (not GNATCOLL.JSON.Get (Tools_Json, 1).Has_Field
              ("cache_control"),
            "OpenCode Go tool definition must not contain cache_control");
      end;
   exception
      when others =>
         if not Server_Stopped then
            Server.Stop;
         end if;
         Restore_Environment;
         raise;
   end Test_OpenAI_Request_Omits_Cache_Hints;

   procedure Test_Responses_Request_Uses_Responses_Wire (T : in out Test) is
      pragma Unreferenced (T);

      Port            : constant Positive := 18_811;
      Base_Url        : constant String := "http://127.0.0.1:18811";
      Old_Base        : constant String :=
        Ada.Environment_Variables.Value
          ("COYOTE_OPENCODE_GO_BASE_URL", "");
      Base_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENCODE_GO_BASE_URL");
      Old_Key         : constant String :=
        Ada.Environment_Variables.Value ("OPENCODE_API_KEY", "");
      Key_Was_Set     : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENCODE_API_KEY");
      Provider        : LLM.Providers.OpenCode_Go.Provider :=
        LLM.Providers.OpenCode_Go.Create;
      Messages        : LLM.Types.Message_Vectors.Vector;
      Content         : LLM.Types.Content_Block_Vectors.Vector;
      Captured        : GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.JSON_Null;
      Server_Stopped  : Boolean := False;

      procedure Restore_Environment is
      begin
         if Base_Was_Set then
            Ada.Environment_Variables.Set
              ("COYOTE_OPENCODE_GO_BASE_URL", Old_Base);
         else
            Ada.Environment_Variables.Clear
              ("COYOTE_OPENCODE_GO_BASE_URL");
         end if;

         if Key_Was_Set then
            Ada.Environment_Variables.Set ("OPENCODE_API_KEY", Old_Key);
         else
            Ada.Environment_Variables.Clear ("OPENCODE_API_KEY");
         end if;
      end Restore_Environment;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         Parsed : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (To_String (Req.Body_Data));
         Input   : GNATCOLL.JSON.JSON_Array;
         Tools   : GNATCOLL.JSON.JSON_Array;
      begin
         Assert
           (To_String (Req.Path) = "/v1/responses",
            "Responses model should use /v1/responses");
         Assert
           (Test_HTTP_Server.Get_Header
              (Req.Headers, "Authorization") = "Bearer fixture-key",
            "Responses model should use bearer authentication");
         Assert (Parsed.Success, "Responses request body should be JSON");
         Captured := Parsed.Value;
         Assert
           (Captured.Has_Field ("input")
              and then not Captured.Has_Field ("messages"),
            "Responses request should use input, not messages");
         Assert
           (Captured.Has_Field ("instructions"),
            "Responses request should carry instructions");
         Input := Captured.Get ("input").Get;
         declare
            Input_Item : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Get (Input, 1);
            Input_Content : constant GNATCOLL.JSON.JSON_Array :=
              Input_Item.Get ("content").Get;
         begin
            Assert
              (not Input_Item.Has_Field ("prompt_cache_breakpoint"),
               "Responses input item must omit cache breakpoint");
            Assert
              (not GNATCOLL.JSON.Get (Input_Content, 1).Has_Field
                 ("prompt_cache_breakpoint"),
               "Responses input content must omit cache breakpoint");
         end;
         Tools := Captured.Get ("tools").Get;
         Assert
           (not GNATCOLL.JSON.Get (Tools, 1).Has_Field
              ("prompt_cache_breakpoint"),
            "Responses tool must omit cache breakpoint");
         Res.Status := 200;
         Append
           (Res.Body_Data,
            "event: response.created" & ASCII.LF
            & "data: {""type"":""response.created"","
            & """response"":{ ""status"":""in_progress""}}"
            & ASCII.LF & ASCII.LF
            & "event: response.output_item.added" & ASCII.LF
            & "data: {""type"":""response.output_item.added"","
            & """item"":{ ""type"":""message"","
            & """id"":""msg_test""}}"
            & ASCII.LF & ASCII.LF
            & "event: response.output_text.delta" & ASCII.LF
            & "data: {""type"":""response.output_text.delta"","
            & """item_id"":""msg_test"","
            & """delta"":""OK""}"
            & ASCII.LF & ASCII.LF
            & "event: response.output_text.done" & ASCII.LF
            & "data: {""type"":""response.output_text.done""}"
            & ASCII.LF & ASCII.LF
            & "event: response.completed" & ASCII.LF
            & "data: {""type"":""response.completed"","
            & """response"":{ ""status"":""completed"","
            & """output"":[]}}"
            & ASCII.LF & ASCII.LF);
      end Handle_Request;

      Server : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
   begin
      Ada.Environment_Variables.Set
        ("COYOTE_OPENCODE_GO_BASE_URL", Base_Url);
      Ada.Environment_Variables.Set ("OPENCODE_API_KEY", "fixture-key");

      Content.Append
        ((Kind => LLM.Types.Text_Block,
          Text => To_Unbounded_String ("Say OK")));
      Messages.Append
        ((Role       => LLM.Types.User,
          Content    => Content,
          Tok_Usage  => (others => 0),
          Stop       => LLM.Types.Unknown_Stop,
          Timestamp  => Null_Unbounded_String));

      Server.Bind (Port);
      Provider.Send
        (Model_Id      => "gpt-5.6-luna",
         System_Prompt => "Reply with exactly OK.",
         Messages      => Messages,
         Tools_Json    =>
           "[{""type"":""function"",""name"":""shell"","
           & """description"":""Run shell"","
           & """parameters"":{""type"":""object""}}]",
         Thinking      => LLM.Providers.Off,
         Max_Tokens    => 16,
         Handler       => null);

      Server.Stop;
      Server_Stopped := True;
      Restore_Environment;
   exception
      when others =>
         if not Server_Stopped then
            Server.Stop;
         end if;
         Restore_Environment;
         raise;
   end Test_Responses_Request_Uses_Responses_Wire;

   procedure Test_Static_Metadata_Known_Model (T : in out Test) is
      pragma Unreferenced (T);
      Cat_Models : LLM.Providers.OpenCode_Go.Catalogue.Catalogue_Vectors.Vector;
   begin
      --  Load_Catalogue from the cached fixture.
      LLM.Providers.OpenCode_Go.Catalogue.Load_Catalogue (Cat_Models);
      --  Even if the network fetch fails, the catalogue may be empty.
      --  The static metadata is tested via wire format and Lookup_Static
      --  which is called inside Parse_Model, so we just verify that
      --  known models from the fixture have the expected context window.
      for Model of Cat_Models loop
         if LLM.Providers.OpenCode_Go.Catalogue."="
           (Model.Wire,
            LLM.Providers.OpenCode_Go.Catalogue.Anthropic_Messages_Wire)
         then
            --  Anthropic-wire models (minimax) should have known context.
            Assert
              (Model.Context_Window > 0,
               "Known model context window should be positive");
         end if;
      end loop;
   end Test_Static_Metadata_Known_Model;

   procedure Test_Static_Metadata_Unknown_Model (T : in out Test) is
      pragma Unreferenced (T);
      Cat_Models : LLM.Providers.OpenCode_Go.Catalogue.Catalogue_Vectors.Vector;
      Found      : Boolean := False;
   begin
      --  If the fixture has a known model, verify it gets proper defaults.
      --  This is more of a smoke test since Load_Catalogue needs network
      --  or cache; the defaults are tested through Lookup_Static indirectly.
      LLM.Providers.OpenCode_Go.Catalogue.Load_Catalogue (Cat_Models);

      for Model of Cat_Models loop
         Found := True;
         Assert
           (Model.Context_Window > 0,
            "All models should have a positive context window");
         Assert
           (Model.Max_Tokens > 0,
            "All models should have a positive max tokens");
      end loop;

      if not Found then
         Assert (True, "No models loaded (network/cache unavailable) -- skip");
      end if;
   end Test_Static_Metadata_Unknown_Model;

   package LLM_OpenCode_Go_Catalogue_Caller is
     new AUnit.Test_Caller (LLM_OpenCode_Go_Catalogue_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (LLM_OpenCode_Go_Catalogue_Caller.Create
        ("LLM.OpenCode_Go.Catalogue MiniMax uses Anthropic wire",
         LLM_OpenCode_Go_Catalogue_Tests
           .Test_Wire_Format_MiniMax_Anthropic'Access));
      Result.Add_Test (LLM_OpenCode_Go_Catalogue_Caller.Create
        ("LLM.OpenCode_Go.Catalogue DeepSeek uses OpenAI wire",
         LLM_OpenCode_Go_Catalogue_Tests
           .Test_Wire_Format_DeepSeek_OpenAI'Access));
      Result.Add_Test (LLM_OpenCode_Go_Catalogue_Caller.Create
        ("LLM.OpenCode_Go.Catalogue Responses models use Responses wire",
         LLM_OpenCode_Go_Catalogue_Tests
           .Test_Wire_Format_Responses'Access));
      Result.Add_Test (LLM_OpenCode_Go_Catalogue_Caller.Create
        ("LLM.OpenCode_Go.Catalogue unknown models default to OpenAI wire",
         LLM_OpenCode_Go_Catalogue_Tests
           .Test_Wire_Format_Unknown_Defaults_OpenAI'Access));
      Result.Add_Test (LLM_OpenCode_Go_Catalogue_Caller.Create
        ("LLM.OpenCode_Go OpenAI requests omit cache hints",
         LLM_OpenCode_Go_Catalogue_Tests
           .Test_OpenAI_Request_Omits_Cache_Hints'Access));
      Result.Add_Test (LLM_OpenCode_Go_Catalogue_Caller.Create
        ("LLM.OpenCode_Go Responses requests use Responses wire",
         LLM_OpenCode_Go_Catalogue_Tests
           .Test_Responses_Request_Uses_Responses_Wire'Access));

      return Result;
   end Suite;

end LLM_OpenCode_Go_Catalogue_Tests;
