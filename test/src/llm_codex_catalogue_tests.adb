with AUnit.Assertions;
with Ada.Calendar;
with Ada.Containers;
with Ada.Directories;
with Ada.Environment_Variables;
with AUnit.Test_Caller;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNATCOLL.JSON;
with Test_HTTP_Server;
with LLM.Providers.Codex.Catalogue;
use LLM.Providers.Codex.Catalogue;

package body LLM_Codex_Catalogue_Tests is

   use AUnit.Assertions;
   use type Ada.Containers.Count_Type;
   use type GNATCOLL.JSON.JSON_Value_Type;

   --  A non-expiring fake JWT; the catalogue never decodes it, the
   --  expiry timestamp in the credential record is what matters.
   Sample_Access_Token : constant String := "codex-access-token";

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
      Delete_If_Exists (Agent_Dir & "/codex_models_cache.json");
      Delete_If_Exists (Agent_Dir & "/codex_models_cache.json.tmp");

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

   --  Credential record with a long-lived access token.
   procedure Write_Credentials (Home : String) is
   begin
      Write_File
        (Home & "/.coyote/auth.json",
         "{""codex"":{"
         & """type"":""oauth"","
         & """refresh"":""codex-refresh"","
         & """access"":""codex-access"","
         & """expires"":9999999999000,"
         & """accountId"":""acc-catalogue""}}");
   end Write_Credentials;

   --  Backend /codex/models response body used by the live-fetch test:
   --  one listed model plus one hidden review model.
   Catalogue_Payload : constant String :=
      "{""models"":[{""slug"":""gpt-5.4-mini"","
      & """display_name"":""GPT-5.4-Mini"","
      & """description"":""Small, fast model."","
      & """context_window"":272000,"
      & """visibility"":""list""},"
      & "{""slug"":""codex-auto-review"","
      & """display_name"":""Codex Auto Review"","
      & """description"":""Review model."","
      & """context_window"":272000,"
      & """visibility"":""hide""}]}";

   function Read_Fixture_File return String is
      File    : Ada.Text_IO.File_Type;
      Content : Unbounded_String;
      Line    : String (1 .. 4_096);
      Last    : Natural;
   begin
      Ada.Text_IO.Open
        (File, Ada.Text_IO.In_File,
         Ada.Directories.Current_Directory
         & "/fixtures/codex_models.json");
      while not Ada.Text_IO.End_Of_File (File) loop
         Ada.Text_IO.Get_Line (File, Line, Last);
         Append (Content, Line (1 .. Last));
         if not Ada.Text_IO.End_Of_File (File) then
            Append (Content, (1 => ASCII.LF));
         end if;
      end loop;
      Ada.Text_IO.Close (File);
      return To_String (Content);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;

         raise;
   end Read_Fixture_File;

   function Fixture_Data_Array return String is
      Parsed : constant GNATCOLL.JSON.Read_Result :=
         GNATCOLL.JSON.Read (Read_Fixture_File);
   begin
      if not Parsed.Success then
         raise Constraint_Error with
            "Failed to parse Codex catalogue fixture";
      end if;

      if Parsed.Value.Kind /= GNATCOLL.JSON.JSON_Object_Type
         or else not Parsed.Value.Has_Field ("models")
      then
         raise Constraint_Error with "Fixture is missing the models field";
      end if;

      return GNATCOLL.JSON.Write (Parsed.Value.Get ("models"));
   end Fixture_Data_Array;

   procedure Write_Cache
      (Home       : String;
      Fetched_At : Long_Long_Integer;
      Data_Array : String)
   is
   begin
      Write_File
         (Home & "/.coyote/codex_models_cache.json",
       "{""fetched_at"":" & Long_Long_Image (Fetched_At)
       & ",""models"":" & Data_Array & "}");
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

      Home         : constant String := "/tmp/coyote_codex_catalogue_1";
      Home_Was_Set : constant Boolean :=
         Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
         Ada.Environment_Variables.Value ("HOME", "");
      Base_Was_Set : constant Boolean :=
         Ada.Environment_Variables.Exists ("COYOTE_CODEX_BASE_URL");
      Old_Base     : constant String :=
         Ada.Environment_Variables.Value ("COYOTE_CODEX_BASE_URL", "");
      Models       : Catalogue_Vectors.Vector;
      Astra        : Natural := 0;
   begin
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);
      Write_Cache
         (Home       => Home,
       Fetched_At => Current_Unix_S,
       Data_Array => Fixture_Data_Array);

      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Clear ("COYOTE_CODEX_BASE_URL");

      Load_Catalogue (Models);

      Astra := Find_Model (Models, "gpt-6-astra");

      Assert (Models.Length = 6, "Expected six listed fixture models");
      Assert (Astra > 0, "Astra model should be parsed from cache");
      Assert
         (Find_Model (Models, "gpt-reserve") = 0,
       "Hidden models should be excluded from the catalogue");
      Assert
         (Find_Model (Models, "codex-auto-review") = 0,
       "Hidden review model should be excluded from the catalogue");
      Assert
         (Models.Element (Astra).Context_Window = 272_000,
       "context_window should be parsed from the fixture");
      Assert
         (To_String (Models.Element (Astra).Name) /= "",
       "display_name should become the model name");

      Restore_Env ("COYOTE_CODEX_BASE_URL", Base_Was_Set, Old_Base);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("COYOTE_CODEX_BASE_URL", Base_Was_Set, Old_Base);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Load_From_Fresh_Cache;

   procedure Test_Cache_Missing_Triggers_Live_Fetch (T : in out Test) is
      pragma Unreferenced (T);

      Port         : constant Positive := 18_779;
      Home         : constant String := "/tmp/coyote_codex_catalogue_2";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Base_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_CODEX_BASE_URL");
      Old_Base     : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_CODEX_BASE_URL", "");
      Models       : Catalogue_Vectors.Vector;

      procedure Live_Handler
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
      begin
         Assert
           (To_String (Req.Path) = "/codex/models?client_version=99.0.0",
            "Codex catalogue request should target /codex/models with a "
            & "client_version query");
         Assert
           (Test_HTTP_Server.Get_Header (Req.Headers, "Authorization")
              = "Bearer codex-access",
            "Codex catalogue request should carry the bearer token");
         Res.Status := 200;
         Res.Headers.Append
           ((Name  => To_Unbounded_String ("Content-Type"),
             Value => To_Unbounded_String ("application/json")));
         Append (Res.Body_Data, Catalogue_Payload);
      end Live_Handler;

      Srv : Test_HTTP_Server.Server
        (Handler => Live_Handler'Unrestricted_Access);

   begin
      Srv.Bind (Port);
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);
      Write_Credentials (Home);

      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set
        ("COYOTE_CODEX_BASE_URL", "http://127.0.0.1:18779");

      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, "[dbg] before load");
      Load_Catalogue (Models);
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, "[dbg] after load, count="
         & Ada.Containers.Count_Type'Image (Models.Length));

      Srv.Stop;

      Assert
        (Find_Model (Models, "gpt-5.4-mini") > 0,
         "Live fetch should parse the fixture models");
      Assert
        (Find_Model (Models, "codex-auto-review") = 0,
         "Live fetch should exclude hidden models");

      Restore_Env ("COYOTE_CODEX_BASE_URL", Base_Was_Set, Old_Base);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Srv.Stop;
         Restore_Env ("COYOTE_CODEX_BASE_URL", Base_Was_Set, Old_Base);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Cache_Missing_Triggers_Live_Fetch;

   procedure Test_Fetch_Failure_No_Cache_Yields_Empty (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_codex_catalogue_3";
      Home_Was_Set : constant Boolean :=
         Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
         Ada.Environment_Variables.Value ("HOME", "");
      Base_Was_Set : constant Boolean :=
         Ada.Environment_Variables.Exists ("COYOTE_CODEX_BASE_URL");
      Old_Base     : constant String :=
         Ada.Environment_Variables.Value ("COYOTE_CODEX_BASE_URL", "");
      Models       : Catalogue_Vectors.Vector;
   begin
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);
      Write_Credentials (Home);

      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set
         ("COYOTE_CODEX_BASE_URL", "http://127.0.0.1:9");

      Load_Catalogue (Models);

      Assert
         (Models.Is_Empty,
       "A failed live fetch without cache should yield an empty catalogue");

      Restore_Env ("COYOTE_CODEX_BASE_URL", Base_Was_Set, Old_Base);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("COYOTE_CODEX_BASE_URL", Base_Was_Set, Old_Base);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Fetch_Failure_No_Cache_Yields_Empty;

   procedure Test_No_Credentials_Yields_Empty (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_codex_catalogue_4";
      Home_Was_Set : constant Boolean :=
         Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
         Ada.Environment_Variables.Value ("HOME", "");
      Base_Was_Set : constant Boolean :=
         Ada.Environment_Variables.Exists ("COYOTE_CODEX_BASE_URL");
      Old_Base     : constant String :=
         Ada.Environment_Variables.Value ("COYOTE_CODEX_BASE_URL", "");
      Models       : Catalogue_Vectors.Vector;
   begin
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);

      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set
         ("COYOTE_CODEX_BASE_URL", "http://127.0.0.1:9");

      Load_Catalogue (Models);

      Assert
         (Models.Is_Empty,
       "No credentials should yield an empty catalogue without a fetch");

      Restore_Env ("COYOTE_CODEX_BASE_URL", Base_Was_Set, Old_Base);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("COYOTE_CODEX_BASE_URL", Base_Was_Set, Old_Base);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_No_Credentials_Yields_Empty;

   package LLM_Codex_Catalogue_Caller is
     new AUnit.Test_Caller (LLM_Codex_Catalogue_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (LLM_Codex_Catalogue_Caller.Create
        ("LLM.Codex.Catalogue loads and parses a fresh cached model list",
         LLM_Codex_Catalogue_Tests.Test_Load_From_Fresh_Cache'Access));
      Result.Add_Test (LLM_Codex_Catalogue_Caller.Create
        ("LLM.Codex.Catalogue fetches live when the cache is missing",
         LLM_Codex_Catalogue_Tests
           .Test_Cache_Missing_Triggers_Live_Fetch'Access));
      Result.Add_Test (LLM_Codex_Catalogue_Caller.Create
        ("LLM.Codex.Catalogue yields empty on fetch failure without cache",
         LLM_Codex_Catalogue_Tests
           .Test_Fetch_Failure_No_Cache_Yields_Empty'Access));
      Result.Add_Test (LLM_Codex_Catalogue_Caller.Create
        ("LLM.Codex.Catalogue yields empty without credentials",
         LLM_Codex_Catalogue_Tests.Test_No_Credentials_Yields_Empty'Access));

      return Result;
   end Suite;

end LLM_Codex_Catalogue_Tests;
