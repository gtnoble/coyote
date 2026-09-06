with AUnit.Assertions;
with Ada.Calendar;
with Ada.Containers;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with AUnit.Test_Caller;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNATCOLL.JSON;
with Test_HTTP_Server;
with LLM.Providers.GitHub_Copilot.Catalogue;

package body LLM_Catalogue_Tests is

   use AUnit.Assertions;
   use type Ada.Containers.Count_Type;
   use type GNATCOLL.JSON.JSON_Value_Type;
   use LLM.Providers.GitHub_Copilot.Catalogue;

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
      Delete_If_Exists (Agent_Dir & "/github_copilot_models_cache.json");
      Delete_If_Exists (Agent_Dir & "/github_copilot_models_cache.json.tmp");

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

   function Fixture_Path return String is
   begin
      return Ada.Directories.Current_Directory
        & "/fixtures/copilot_models_catalogue.json";
   end Fixture_Path;

   function Stale_Fixture_Path return String is
   begin
      return Ada.Directories.Current_Directory
        & "/fixtures/copilot_models_catalogue_stale_array.json";
   end Stale_Fixture_Path;

   function Fixture_Data_Array return String is
      Parsed : constant GNATCOLL.JSON.Read_Result :=
        GNATCOLL.JSON.Read (Read_File (Fixture_Path));
   begin
      if not Parsed.Success then
         raise Constraint_Error with
           "Failed to parse Copilot catalogue fixture";
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
      return Read_File (Stale_Fixture_Path);
   end Stale_Data_Array;

   procedure Write_Cache
     (Home       : String;
      Base_Url   : String;
      Fetched_At : Long_Long_Integer;
      Data_Array : String)
   is
   begin
      Write_File
        (Home & "/.coyote/github_copilot_models_cache.json",
         "{""fetched_at"":" & Long_Long_Image (Fetched_At)
         & ",""base_url"":""" & Base_Url & """,""data"":"
         & Data_Array & "}");
   end Write_Cache;

   function Find_Model
     (Models   : Catalogue_Vectors.Vector;
      Model_Id : String) return Natural
   is
   begin
      if Models.Is_Empty then
         return 0;
      end if;

      for I in Models.First_Index .. Models.Last_Index loop
         if To_String (Models.Element (I).Model_Id) = Model_Id then
            return I;
         end if;
      end loop;

      return 0;
   end Find_Model;

   procedure Test_Load_From_Fresh_Cache (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_llm_catalogue_test_1";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Models       : Catalogue_Vectors.Vector;
      Claude_Index : Natural := 0;
      Gpt_Index    : Natural := 0;
      O3_Index     : Natural := 0;
   begin
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);
      Write_Cache
        (Home       => Home,
         Base_Url   => "https://api.individual.githubcopilot.com",
         Fetched_At => Current_Unix_S,
         Data_Array => Fixture_Data_Array);

      Ada.Environment_Variables.Set ("HOME", Home);

      Load_Catalogue
        (Base_Url => "https://api.individual.githubcopilot.com",
         Token    => "unused-token",
         Models   => Models);

      Claude_Index := Find_Model (Models, "claude-sonnet-4.6");
      Gpt_Index := Find_Model (Models, "gpt-4o");
      O3_Index := Find_Model (Models, "o3-mini");

      Assert (Models.Length = 3, "Only chat models should be included");
      Assert (Claude_Index > 0, "Claude model should be parsed from cache");
      Assert (Gpt_Index > 0, "GPT model should be parsed from cache");
      Assert (O3_Index > 0, "o3-mini model should be parsed from cache");
      Assert
        (Find_Model (Models, "text-embedding-3-small") = 0,
         "Non-chat catalogue entries should be excluded");
      Assert
        (Models.Element (Claude_Index).Context_Window = 200_000,
         "Context window should be parsed from capabilities.limits");
      Assert
        (Models.Element (Claude_Index).Supports_Tools,
         "Tool support should be parsed from capabilities.supports");
      Assert
        (Models.Element (Claude_Index).Reasoning,
         "Non-empty reasoning_effort should enable reasoning support");
      Assert
        (Models.Element (Claude_Index).Max_Thinking_Budget = 16_384,
         "Max thinking budget should be parsed correctly");
      Assert
        (Models.Element (Claude_Index).Supports_Anthropic,
         "/v1/messages should enable the Anthropic wire format");
      Assert
        (Models.Element (Claude_Index).Supports_OpenAI,
         "/chat/completions should enable the OpenAI wire format");
      Assert
        (not Models.Element (Gpt_Index).Reasoning,
         "Empty reasoning_effort arrays should disable reasoning support");
      Assert
        (not Models.Element (Gpt_Index).Supports_Anthropic,
         "Models without /v1/messages should not use Anthropic format");
      Assert
        (not Models.Element (O3_Index).Supports_Tools,
         "tool_calls=false should disable tool support");

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Load_From_Fresh_Cache;

   procedure Test_Stale_Cache_Triggers_Live_Fetch (T : in out Test) is
      pragma Unreferenced (T);

      Port         : constant Positive := 18_770;
      Home         : constant String := "/tmp/coyote_llm_catalogue_test_2";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Models       : Catalogue_Vectors.Vector;

      procedure Live_Handler
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
      begin
         Assert
           (To_String (Req.Path) = "/models",
            "Catalogue request should target the models endpoint");
         Assert
           (Test_HTTP_Server.Get_Header (Req.Headers, "Authorization")
              = "Bearer live-token",
            "Catalogue request should carry the live token");
         Assert
           (Test_HTTP_Server.Get_Header (Req.Headers, "User-Agent")
              = "GitHubCopilotChat/0.35.0",
            "Catalogue request should carry the Copilot User-Agent");
         Assert
           (Test_HTTP_Server.Get_Header (Req.Headers, "Editor-Version")
              = "vscode/1.107.0",
            "Catalogue request should carry the Editor-Version header");
         Assert
           (Test_HTTP_Server.Get_Header
              (Req.Headers, "Editor-Plugin-Version")
              = "copilot-chat/0.35.0",
            "Catalogue request should carry the Editor-Plugin-Version header");
         Assert
           (Test_HTTP_Server.Get_Header
              (Req.Headers, "Copilot-Integration-Id")
              = "vscode-chat",
            "Catalogue request should carry the"
            & " Copilot-Integration-Id header");
         Assert
           (Test_HTTP_Server.Get_Header (Req.Headers, "Openai-Intent")
              = "conversation-edits",
            "Catalogue request should carry the Openai-Intent header");
         Res.Status := 200;
         Res.Headers.Append
           ((Name  => To_Unbounded_String ("Content-Type"),
             Value => To_Unbounded_String ("application/json")));
         Append (Res.Body_Data, Read_File (Fixture_Path));
      end Live_Handler;

      Srv : Test_HTTP_Server.Server
        (Handler => Live_Handler'Unrestricted_Access);

   begin
      Srv.Bind (Port);
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);
      Write_Cache
        (Home       => Home,
         Base_Url   => "http://127.0.0.1:18770",
         Fetched_At => Current_Unix_S - 172_800,
         Data_Array => Stale_Data_Array);

      Ada.Environment_Variables.Set ("HOME", Home);

      Load_Catalogue
        (Base_Url => "http://127.0.0.1:18770",
         Token    => "live-token",
         Models   => Models);

      Srv.Stop;

      Assert
        (Models.Length = 3,
         "A stale cache should trigger a live fetch of the fresh catalogue");
      Assert
        (Find_Model (Models, "stale-model") = 0,
         "Live fetch results should replace stale cache contents");
      Assert
        (Ada.Directories.Exists
           (Home & "/.coyote/github_copilot_models_cache.json"),
         "Live fetch should rewrite the catalogue cache file");
      Assert
        (Ada.Strings.Fixed.Index
           (Read_File (Home & "/.coyote/github_copilot_models_cache.json"),
            "http://127.0.0.1:18770") > 0,
         "Rewritten cache should be keyed to the requested base URL");

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Srv.Stop;
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Stale_Cache_Triggers_Live_Fetch;

   procedure Test_Stale_Cache_Fallback (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_llm_catalogue_test_3";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Models       : Catalogue_Vectors.Vector;
   begin
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);
      Write_Cache
        (Home       => Home,
         Base_Url   => "http://127.0.0.1:9",
         Fetched_At => Current_Unix_S - 172_800,
         Data_Array => Fixture_Data_Array);

      Ada.Environment_Variables.Set ("HOME", Home);

      Load_Catalogue
        (Base_Url => "http://127.0.0.1:9",
         Token    => "unused-token",
         Models   => Models);

      Assert
        (Models.Length = 3,
         "A stale matching cache should be used when live fetch fails");
      Assert
        (Find_Model (Models, "claude-sonnet-4.6") > 0,
         "Stale fallback should still parse the cached model entries");

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Stale_Cache_Fallback;

   package LLM_Catalogue_Caller is
     new AUnit.Test_Caller (LLM_Catalogue_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (LLM_Catalogue_Caller.Create
        ("LLM.Catalogue loads and parses a fresh cached Copilot model list",
         LLM_Catalogue_Tests.Test_Load_From_Fresh_Cache'Access));
      Result.Add_Test (LLM_Catalogue_Caller.Create
        ("LLM.Catalogue uses live fetch when the Copilot cache is stale",
         LLM_Catalogue_Tests.Test_Stale_Cache_Triggers_Live_Fetch'Access));
      Result.Add_Test (LLM_Catalogue_Caller.Create
        ("LLM.Catalogue falls back to a stale cache on fetch failure",
         LLM_Catalogue_Tests.Test_Stale_Cache_Fallback'Access));

      return Result;
   end Suite;

end LLM_Catalogue_Tests;
