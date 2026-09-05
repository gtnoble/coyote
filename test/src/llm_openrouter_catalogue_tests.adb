with AUnit.Assertions;
with Ada.Calendar;
with Ada.Containers;
with Ada.Directories;
with Ada.Environment_Variables;
with AUnit.Test_Caller;
with AUnit.Test_Suites;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNATCOLL.JSON;
with Test_HTTP_Server;
with LLM.Providers.OpenRouter.Catalogue;

package body LLM_OpenRouter_Catalogue_Tests is

   use AUnit.Assertions;
   use type Ada.Containers.Count_Type;
   use type GNATCOLL.JSON.JSON_Value_Type;
   use LLM.Providers.OpenRouter.Catalogue;

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
         "[{""id"":""stale-model"",""name"":""Stale"","
         & """context_length"":1024,""architecture"":{"
         & """input_modalities"":[""text""],"
         & """output_modalities"":[""text""]},"
         & """pricing"":{""prompt"":""0"",""completion"":""0""},"
         & """top_provider"":{""context_length"":1024,"
         & """max_completion_tokens"":128},"
         & """supported_parameters"":[""tools""]}]";
   end Stale_Data_Array;

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

      Home         : constant String := "/tmp/coyote_openrouter_catalogue_1";
      Home_Was_Set : constant Boolean :=
         Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
         Ada.Environment_Variables.Value ("HOME", "");
      Base_Was_Set : constant Boolean :=
         Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Base     : constant String :=
         Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");
      Models       : Catalogue_Vectors.Vector;
      Claude       : Natural := 0;
      Llama        : Natural := 0;
      Grok         : Natural := 0;
   begin
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);
      Write_Cache
         (Home       => Home,
       Fetched_At => Current_Unix_S,
       Data_Array => Fixture_Data_Array);

      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Clear ("COYOTE_OPENROUTER_BASE_URL");

      Load_Catalogue (Models);

      Claude := Find_Model (Models, "anthropic/claude-sonnet-4-20250514");
      Llama := Find_Model (Models, "meta-llama/llama-3.2-3b-instruct");
      Grok := Find_Model (Models, "x-ai/grok-4.3");

      Assert (Models.Length = 4, "Expected four fixture models");
      Assert (Claude > 0, "Claude model should be parsed from cache");
      Assert (Llama > 0, "Llama model should be parsed from cache");
      Assert (Grok > 0, "Grok model should be parsed from cache");
      Assert
         (Models.Element (Claude).Cost_Input = 3.0,
       "0.000003 prompt pricing should become $3.0/M tokens");
      Assert
         (Models.Element (Claude).Cost_Cache_Write = 4.0,
       "0.000004 input_cache_write pricing should become $4.0/M tokens");
      Assert
         (Models.Element (Claude).Reasoning,
       "reasoning support should require the reasoning parameter");
      Assert
         (not Models.Element (Llama).Supports_Tools,
       "models without tools should disable tool support");
      Assert
         (Models.Element (Llama).Max_Tokens = 4_096,
       "null max_completion_tokens should fall back to 4096");
      Assert
         (not Models.Element (Grok).Reasoning,
       "include_reasoning alone should not enable reasoning support");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Base_Was_Set, Old_Base);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Base_Was_Set, Old_Base);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Load_From_Fresh_Cache;

   procedure Test_Stale_Cache_Triggers_Live_Fetch (T : in out Test) is
      pragma Unreferenced (T);

      Port         : constant Positive := 18_773;
      Home         : constant String := "/tmp/coyote_openrouter_catalogue_2";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Base_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Base     : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");
      Models       : Catalogue_Vectors.Vector;

      procedure Live_Handler
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
      begin
         Assert
           (To_String (Req.Path) = "/api/v1/models",
            "OpenRouter catalogue request should target /api/v1/models");
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
         Fetched_At => 0,
         Data_Array => Stale_Data_Array);

      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL", "http://127.0.0.1:18773/api/v1");

      Load_Catalogue (Models);

      Srv.Stop;

      Assert
        (Models.Length = 4,
         "A stale cache should trigger a live fetch of the fixture catalogue");
      Assert
        (Find_Model (Models, "stale-model") = 0,
         "Live fetch results should replace stale cache contents");
      Assert
        (Find_Model (Models, "anthropic/claude-sonnet-4-20250514") > 0,
         "Live fetch should parse the fixture models");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Base_Was_Set, Old_Base);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Srv.Stop;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Base_Was_Set, Old_Base);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Stale_Cache_Triggers_Live_Fetch;

   procedure Test_Stale_Cache_Fallback (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_openrouter_catalogue_3";
      Home_Was_Set : constant Boolean :=
         Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
         Ada.Environment_Variables.Value ("HOME", "");
      Base_Was_Set : constant Boolean :=
         Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Base     : constant String :=
         Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");
      Models       : Catalogue_Vectors.Vector;
   begin
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);
      Write_Cache
         (Home       => Home,
       Fetched_At => 0,
       Data_Array => Fixture_Data_Array);

      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set
         ("COYOTE_OPENROUTER_BASE_URL", "http://127.0.0.1:9/api/v1");

      Load_Catalogue (Models);

      Assert
         (Models.Length = 4,
       "A stale cache should be used when the live fetch fails");
      Assert
         (Find_Model (Models, "anthropic/claude-sonnet-4-20250514") > 0,
       "Stale cache fallback should preserve cached models");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Base_Was_Set, Old_Base);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Base_Was_Set, Old_Base);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Stale_Cache_Fallback;


   package LLM_OpenRouter_Catalogue_Caller is
     new AUnit.Test_Caller (LLM_OpenRouter_Catalogue_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (LLM_OpenRouter_Catalogue_Caller.Create
        ("LLM.OpenRouter.Catalogue loads and parses a fresh cached model list",
         LLM_OpenRouter_Catalogue_Tests.Test_Load_From_Fresh_Cache'Access));
      Result.Add_Test (LLM_OpenRouter_Catalogue_Caller.Create
        ("LLM.OpenRouter.Catalogue uses live fetch when the cache is stale",
         LLM_OpenRouter_Catalogue_Tests
           .Test_Stale_Cache_Triggers_Live_Fetch'Access));
      Result.Add_Test (LLM_OpenRouter_Catalogue_Caller.Create
        ("LLM.OpenRouter.Catalogue falls back to stale cache on fetch failure",
         LLM_OpenRouter_Catalogue_Tests.Test_Stale_Cache_Fallback'Access));

      return Result;
   end Suite;

end LLM_OpenRouter_Catalogue_Tests;
