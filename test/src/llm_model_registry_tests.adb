with AUnit.Assertions;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNATCOLL.JSON;
with LLM.Model_Registry;

package body LLM_Model_Registry_Tests is

  use AUnit.Assertions;
  use type GNATCOLL.JSON.JSON_Value_Type;

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
    Ada.Directories.Create_Path (Home & "/.pi/agent");
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
    Agent_Dir : constant String := Home & "/.pi/agent";
    Pi_Dir    : constant String := Home & "/.pi";
  begin
    Delete_If_Exists (Agent_Dir & "/auth.json");
    Delete_If_Exists (Agent_Dir & "/auth.json.tmp");
    Delete_If_Exists (Agent_Dir & "/github_copilot_models_cache.json");
    Delete_If_Exists (Agent_Dir & "/github_copilot_models_cache.json.tmp");
    Delete_If_Exists (Agent_Dir & "/openrouter_models_cache.json");
    Delete_If_Exists (Agent_Dir & "/openrouter_models_cache.json.tmp");
    Delete_If_Exists (Agent_Dir & "/models.json");

    if Ada.Directories.Exists (Agent_Dir) then
      Ada.Directories.Delete_Directory (Agent_Dir);
    end if;

    if Ada.Directories.Exists (Pi_Dir) then
      Ada.Directories.Delete_Directory (Pi_Dir);
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

  function Fixture_Data_Array (Fixture_Name : String) return String is
    Parsed : constant GNATCOLL.JSON.Read_Result :=
      GNATCOLL.JSON.Read
        (Read_File
           (Ada.Directories.Current_Directory & "/fixtures/" & Fixture_Name));
  begin
    if not Parsed.Success then
      raise Constraint_Error with "Failed to parse fixture: " & Fixture_Name;
    end if;

    if Parsed.Value.Kind /= GNATCOLL.JSON.JSON_Object_Type
      or else not Parsed.Value.Has_Field ("data")
    then
      raise Constraint_Error with "Fixture is missing the data field";
    end if;

    return GNATCOLL.JSON.Write (Parsed.Value.Get ("data"));
  end Fixture_Data_Array;

  procedure Write_GitHub_Copilot_Auth (Home : String) is
  begin
    Write_File
      (Home & "/.pi/agent/auth.json",
       "{""github-copilot"":{"
       & """type"":""oauth"","
       & """refresh"":""fixture-refresh"","
       & """access"":""tid=test;proxy-ep=proxy.individual.githubcopilot"
       & ".com;"","
       & """expires"":9999999999000}}");
  end Write_GitHub_Copilot_Auth;

  procedure Write_GitHub_Copilot_Cache (Home : String) is
  begin
    Write_File
      (Home & "/.pi/agent/github_copilot_models_cache.json",
       "{""fetched_at"":9999999999,"
       & """base_url"":""https://api.individual.githubcopilot.com"","
       & """data"":"
       & Fixture_Data_Array ("copilot_models_catalogue.json")
       & "}");
  end Write_GitHub_Copilot_Cache;

  procedure Write_OpenRouter_Cache (Home : String) is
  begin
    Write_File
      (Home & "/.pi/agent/openrouter_models_cache.json",
       "{""fetched_at"":9999999999,"
       & """data"":"
       & Fixture_Data_Array ("openrouter_models.json")
       & "}");
  end Write_OpenRouter_Cache;

  function Count_Provider
    (Models   : LLM.Model_Registry.Model_Info_Vectors.Vector;
     Provider : String) return Natural
  is
    Result : Natural := 0;
  begin
    for Model of Models loop
      if To_String (Model.Provider) = Provider then
        Result := Result + 1;
      end if;
    end loop;

    return Result;
  end Count_Provider;

  function Has_Model
    (Models    : LLM.Model_Registry.Model_Info_Vectors.Vector;
     Provider  : String;
     Model_Id  : String) return Boolean
  is
  begin
    for Model of Models loop
      if To_String (Model.Provider) = Provider
        and then To_String (Model.Model_Id) = Model_Id
      then
        return True;
      end if;
    end loop;

    return False;
  end Has_Model;

  procedure Prepare_GitHub_Copilot_Fixture_Home (Home : String) is
  begin
    Cleanup_Test_Home (Home);
    Ensure_Test_Home (Home);
    Write_GitHub_Copilot_Auth (Home);
    Write_GitHub_Copilot_Cache (Home);
  end Prepare_GitHub_Copilot_Fixture_Home;

  procedure Prepare_OpenRouter_Fixture_Home (Home : String) is
  begin
    Cleanup_Test_Home (Home);
    Ensure_Test_Home (Home);
    Write_OpenRouter_Cache (Home);
  end Prepare_OpenRouter_Fixture_Home;

  procedure Test_GitHub_Copilot_Anthropic_Wire_Format (T : in out Test) is
    pragma Unreferenced (T);

    Home         : constant String := "/tmp/pi_acme_model_registry_test_1";
    Home_Was_Set : constant Boolean :=
      Ada.Environment_Variables.Exists ("HOME");
    Old_Home     : constant String :=
      Ada.Environment_Variables.Value ("HOME", "");
    Model        : LLM.Model_Registry.Model_Info;
  begin
    Prepare_GitHub_Copilot_Fixture_Home (Home);
    Ada.Environment_Variables.Set ("HOME", Home);

    LLM.Model_Registry.Refresh_GitHub_Copilot;
    Model :=
      LLM.Model_Registry.Lookup ("github-copilot", "claude-sonnet-4.6");

    Assert
      (To_String (Model.Wire_Format) = "anthropic-messages",
       "Claude Copilot models should prefer the Anthropic wire format");

    Restore_Env ("HOME", Home_Was_Set, Old_Home);
    Cleanup_Test_Home (Home);
  exception
    when others =>
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
      raise;
  end Test_GitHub_Copilot_Anthropic_Wire_Format;

  procedure Test_GitHub_Copilot_OpenAI_Wire_Format (T : in out Test) is
    pragma Unreferenced (T);

    Home         : constant String := "/tmp/pi_acme_model_registry_test_2";
    Home_Was_Set : constant Boolean :=
      Ada.Environment_Variables.Exists ("HOME");
    Old_Home     : constant String :=
      Ada.Environment_Variables.Value ("HOME", "");
    Model        : LLM.Model_Registry.Model_Info;
  begin
    Prepare_GitHub_Copilot_Fixture_Home (Home);
    Ada.Environment_Variables.Set ("HOME", Home);

    LLM.Model_Registry.Refresh_GitHub_Copilot;
    Model := LLM.Model_Registry.Lookup ("github-copilot", "gpt-4o");

    Assert
      (To_String (Model.Wire_Format) = "openai-completions",
       "GPT Copilot models should use the OpenAI wire format");

    Restore_Env ("HOME", Home_Was_Set, Old_Home);
    Cleanup_Test_Home (Home);
  exception
    when others =>
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
      raise;
  end Test_GitHub_Copilot_OpenAI_Wire_Format;

  procedure Test_GitHub_Copilot_Not_Found (T : in out Test) is
    pragma Unreferenced (T);

    Home         : constant String := "/tmp/pi_acme_model_registry_test_3";
    Home_Was_Set : constant Boolean :=
      Ada.Environment_Variables.Exists ("HOME");
    Old_Home     : constant String :=
      Ada.Environment_Variables.Value ("HOME", "");
    Raised       : Boolean := False;
  begin
    Prepare_GitHub_Copilot_Fixture_Home (Home);
    Ada.Environment_Variables.Set ("HOME", Home);

    LLM.Model_Registry.Refresh_GitHub_Copilot;

    begin
      declare
        Model : constant LLM.Model_Registry.Model_Info :=
          LLM.Model_Registry.Lookup ("github-copilot", "nonexistent");
      begin
        pragma Unreferenced (Model);
      end;
    exception
      when LLM.Model_Registry.Not_Found =>
        Raised := True;
    end;

    Assert (Raised, "Unknown GitHub Copilot models should raise Not_Found");

    Restore_Env ("HOME", Home_Was_Set, Old_Home);
    Cleanup_Test_Home (Home);
  exception
    when others =>
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
      raise;
  end Test_GitHub_Copilot_Not_Found;

  procedure Test_OpenRouter_Cost_Loaded (T : in out Test) is
    pragma Unreferenced (T);

    Home         : constant String := "/tmp/pi_acme_model_registry_test_4";
    Home_Was_Set : constant Boolean :=
      Ada.Environment_Variables.Exists ("HOME");
    Old_Home     : constant String :=
      Ada.Environment_Variables.Value ("HOME", "");
    Model        : LLM.Model_Registry.Model_Info;
  begin
    Prepare_OpenRouter_Fixture_Home (Home);
    Ada.Environment_Variables.Set ("HOME", Home);

    LLM.Model_Registry.Refresh_OpenRouter;
    Model :=
      LLM.Model_Registry.Lookup
        ("openrouter", "anthropic/claude-sonnet-4-20250514");

    Assert
      (Model.Cost.Input > 0.0,
       "OpenRouter models should preserve non-zero prompt pricing");

    Restore_Env ("HOME", Home_Was_Set, Old_Home);
    Cleanup_Test_Home (Home);
  exception
    when others =>
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
      raise;
  end Test_OpenRouter_Cost_Loaded;

  procedure Test_OpenRouter_Default_Fallback (T : in out Test) is
    pragma Unreferenced (T);

    Model : constant LLM.Model_Registry.Model_Info :=
      LLM.Model_Registry.Lookup
        ("openrouter", "some/new-model-not-in-registry");
  begin
    Assert
      (To_String (Model.Provider) = "openrouter",
       "Default OpenRouter fallback should keep the provider name");
    Assert
      (To_String (Model.Model_Id) = "some/new-model-not-in-registry",
       "Default OpenRouter fallback should preserve the requested id");
    Assert
      (To_String (Model.Wire_Format) = "openai-completions",
       "Default OpenRouter fallback should use OpenAI completions");
  end Test_OpenRouter_Default_Fallback;

  procedure Test_Unknown_Provider_Not_Found (T : in out Test) is
    pragma Unreferenced (T);

    Raised : Boolean := False;
  begin
    begin
      declare
        Model : constant LLM.Model_Registry.Model_Info :=
          LLM.Model_Registry.Lookup ("unknown-provider", "foo");
      begin
        pragma Unreferenced (Model);
      end;
    exception
      when LLM.Model_Registry.Not_Found =>
        Raised := True;
    end;

    Assert (Raised, "Unknown providers should raise Not_Found");
  end Test_Unknown_Provider_Not_Found;

  procedure Test_Available_Models_Filtering (T : in out Test) is
    pragma Unreferenced (T);

    Home           : constant String := "/tmp/pi_acme_model_registry_test_5";
    Home_Was_Set   : constant Boolean :=
      Ada.Environment_Variables.Exists ("HOME");
    Old_Home       : constant String :=
      Ada.Environment_Variables.Value ("HOME", "");
    Key_Was_Set    : constant Boolean :=
      Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
    Old_Key        : constant String :=
      Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
    Available      : LLM.Model_Registry.Model_Info_Vectors.Vector;
  begin
    Cleanup_Test_Home (Home);
    Ensure_Test_Home (Home);
    Write_GitHub_Copilot_Auth (Home);
    Write_GitHub_Copilot_Cache (Home);
    Write_OpenRouter_Cache (Home);

    Ada.Environment_Variables.Set ("HOME", Home);
    Ada.Environment_Variables.Clear ("OPENROUTER_API_KEY");

    LLM.Model_Registry.Refresh_GitHub_Copilot;
    LLM.Model_Registry.Refresh_OpenRouter;

    Available := LLM.Model_Registry.Available_Models;
    Assert
      (Count_Provider (Available, "github-copilot") = 3,
       "Copilot models should be available when auth.json is present");
    Assert
      (Count_Provider (Available, "openrouter") = 0,
       "OpenRouter models should be hidden without an API key");

    Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "fixture-or-key");
    Available := LLM.Model_Registry.Available_Models;

    Assert
      (Count_Provider (Available, "github-copilot") = 3,
       "Copilot availability should not change when the OpenRouter key "
       & "is set");
    Assert
      (Count_Provider (Available, "openrouter") = 4,
       "OpenRouter models should appear once an API key is configured");

    Delete_If_Exists (Home & "/.pi/agent/auth.json");
    Available := LLM.Model_Registry.Available_Models;

    Assert
      (Count_Provider (Available, "github-copilot") = 0,
       "Copilot models should be hidden when auth.json is absent");
    Assert
      (Count_Provider (Available, "openrouter") = 4,
       "OpenRouter models should remain available while the key is set");

    Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
    Restore_Env ("HOME", Home_Was_Set, Old_Home);
    Cleanup_Test_Home (Home);
  exception
    when others =>
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
      raise;
  end Test_Available_Models_Filtering;

  procedure Test_Anthropic_Available_Models (T : in out Test) is
    pragma Unreferenced (T);

    Home            : constant String := "/tmp/pi_acme_model_registry_test_6";
    Home_Was_Set    : constant Boolean :=
      Ada.Environment_Variables.Exists ("HOME");
    Old_Home        : constant String :=
      Ada.Environment_Variables.Value ("HOME", "");
    Key_Was_Set     : constant Boolean :=
      Ada.Environment_Variables.Exists ("ANTHROPIC_API_KEY");
    Old_Key         : constant String :=
      Ada.Environment_Variables.Value ("ANTHROPIC_API_KEY", "");
    Available       : LLM.Model_Registry.Model_Info_Vectors.Vector;
    Sonnet_Model_Id : constant String := "claude-sonnet-4-20250514";
  begin
    Cleanup_Test_Home (Home);
    Ensure_Test_Home (Home);

    Ada.Environment_Variables.Set ("HOME", Home);
    Ada.Environment_Variables.Clear ("ANTHROPIC_API_KEY");

    LLM.Model_Registry.Refresh_Anthropic;
    Available := LLM.Model_Registry.Available_Models;
    Assert
      (not Has_Model (Available, "anthropic", Sonnet_Model_Id),
       "Anthropic models should be hidden without an API key");

    Ada.Environment_Variables.Set ("ANTHROPIC_API_KEY", "fixture-key");
    LLM.Model_Registry.Refresh_Anthropic;
    Available := LLM.Model_Registry.Available_Models;
    Assert
      (Has_Model (Available, "anthropic", Sonnet_Model_Id),
       "Anthropic models should appear once ANTHROPIC_API_KEY is set");

    Restore_Env ("ANTHROPIC_API_KEY", Key_Was_Set, Old_Key);
    Restore_Env ("HOME", Home_Was_Set, Old_Home);
    Cleanup_Test_Home (Home);
  exception
    when others =>
      Restore_Env ("ANTHROPIC_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
      raise;
  end Test_Anthropic_Available_Models;

end LLM_Model_Registry_Tests;
