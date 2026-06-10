with AUnit.Assertions;
with Ada.Characters.Handling;
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
    Delete_If_Exists (Agent_Dir & "/auth.json");
    Delete_If_Exists (Agent_Dir & "/auth.json.tmp");
    Delete_If_Exists (Agent_Dir & "/github_copilot_models_cache.json");
    Delete_If_Exists (Agent_Dir & "/github_copilot_models_cache.json.tmp");
    Delete_If_Exists (Agent_Dir & "/openrouter_models_cache.json");
    Delete_If_Exists (Agent_Dir & "/openrouter_models_cache.json.tmp");
    Delete_If_Exists (Agent_Dir & "/opencode_go_models_cache.json");
    Delete_If_Exists (Agent_Dir & "/opencode_go_models_cache.json.tmp");
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
      (Home & "/.coyote/auth.json",
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
      (Home & "/.coyote/github_copilot_models_cache.json",
       "{""fetched_at"":9999999999,"
       & """base_url"":""https://api.individual.githubcopilot.com"","
       & """data"":"
       & Fixture_Data_Array ("copilot_models_catalogue.json")
       & "}");
  end Write_GitHub_Copilot_Cache;

  procedure Write_OpenRouter_Cache (Home : String) is
  begin
    Write_File
      (Home & "/.coyote/openrouter_models_cache.json",
       "{""fetched_at"":9999999999,"
       & """data"":"
       & Fixture_Data_Array ("openrouter_models.json")
       & "}");
  end Write_OpenRouter_Cache;

  procedure Write_OpenCode_Go_Cache (Home : String) is
  begin
    Write_File
      (Home & "/.coyote/opencode_go_models_cache.json",
       "{""fetched_at"":9999999999,"
       & """data"":"
       & Fixture_Data_Array ("opencode_go_models.json")
       & "}");
  end Write_OpenCode_Go_Cache;

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

  procedure Prepare_OpenCode_Go_Fixture_Home (Home : String) is
  begin
    Cleanup_Test_Home (Home);
    Ensure_Test_Home (Home);
    Write_OpenCode_Go_Cache (Home);
  end Prepare_OpenCode_Go_Fixture_Home;

  procedure Test_GitHub_Copilot_Anthropic_Wire_Format (T : in out Test) is
    pragma Unreferenced (T);

    Home         : constant String := "/tmp/coyote_model_registry_test_1";
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

    Home         : constant String := "/tmp/coyote_model_registry_test_2";
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

  procedure Test_GitHub_Copilot_Default_Fallback (T : in out Test) is
    pragma Unreferenced (T);

    Home         : constant String := "/tmp/coyote_model_registry_test_3";
    Home_Was_Set : constant Boolean :=
      Ada.Environment_Variables.Exists ("HOME");
    Old_Home     : constant String :=
      Ada.Environment_Variables.Value ("HOME", "");
    Model        : LLM.Model_Registry.Model_Info;
  begin
    Prepare_GitHub_Copilot_Fixture_Home (Home);
    Ada.Environment_Variables.Set ("HOME", Home);

    LLM.Model_Registry.Refresh_GitHub_Copilot;

    --  Unknown models should return a default record rather than raising
    --  Not_Found, so the agent can start even when the Copilot catalogue
    --  is not populated.

    Model := LLM.Model_Registry.Lookup ("github-copilot", "nonexistent");
    Assert
      (To_String (Model.Provider) = "github-copilot",
       "Default fallback should have github-copilot provider");
    Assert
      (To_String (Model.Model_Id) = "nonexistent",
       "Default fallback should preserve the requested model ID");
    Assert
      (To_String (Model.Wire_Format) = "openai-completions",
       "Non-Claude default fallback should use openai-completions");

    --  Claude-like model IDs should get the Anthropic wire format.
    Model := LLM.Model_Registry.Lookup ("github-copilot", "claude-unknown");
    Assert
      (To_String (Model.Wire_Format) = "anthropic-messages",
       "Claude-like default fallback should use anthropic-messages");

    Restore_Env ("HOME", Home_Was_Set, Old_Home);
    Cleanup_Test_Home (Home);
  exception
    when others =>
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
      raise;
  end Test_GitHub_Copilot_Default_Fallback;

  procedure Test_OpenRouter_Cost_Loaded (T : in out Test) is
    pragma Unreferenced (T);

    Home         : constant String := "/tmp/coyote_model_registry_test_4";
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

    Home           : constant String := "/tmp/coyote_model_registry_test_5";
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

    Delete_If_Exists (Home & "/.coyote/auth.json");
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

    Home            : constant String := "/tmp/coyote_model_registry_test_6";
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

  --  Verify Available_Models returns entries sorted by provider then
  --  model identifier, both compared case-insensitively.
  procedure Test_Available_Models_Sorted (T : in out Test) is
    pragma Unreferenced (T);

    Home         : constant String :=
      "/tmp/coyote_model_registry_test_7";
    Home_Was_Set : constant Boolean :=
      Ada.Environment_Variables.Exists ("HOME");
    Old_Home     : constant String :=
      Ada.Environment_Variables.Value ("HOME", "");
    Key_Was_Set  : constant Boolean :=
      Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
    Old_Key      : constant String :=
      Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
    Available    : LLM.Model_Registry.Model_Info_Vectors.Vector;
    Prev_Prov    : Unbounded_String;
    Prev_Id      : Unbounded_String;
    Is_First     : Boolean := True;
  begin
    Prepare_GitHub_Copilot_Fixture_Home (Home);
    Write_OpenRouter_Cache (Home);

    Ada.Environment_Variables.Set ("HOME", Home);
    Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "fixture-or-key");

    LLM.Model_Registry.Refresh_GitHub_Copilot;
    LLM.Model_Registry.Refresh_OpenRouter;

    Available := LLM.Model_Registry.Available_Models;

    Assert
      (not Available.Is_Empty,
       "Available_Models should return at least one model");

    --  Check each adjacent pair satisfies (provider, model_id) ordering.
    for Model of Available loop
      if not Is_First then
        declare
          Cur_Prov : constant String :=
            Ada.Characters.Handling.To_Lower
              (To_String (Model.Provider));
          Pre_Prov : constant String :=
            Ada.Characters.Handling.To_Lower (To_String (Prev_Prov));
          Cur_Id   : constant String :=
            Ada.Characters.Handling.To_Lower
              (To_String (Model.Model_Id));
          Pre_Id   : constant String :=
            Ada.Characters.Handling.To_Lower (To_String (Prev_Id));
        begin
          if Pre_Prov = Cur_Prov then
            Assert
              (Pre_Id <= Cur_Id,
               "Within provider " & Pre_Prov
               & ": " & Pre_Id
               & " should sort before " & Cur_Id);
          else
            Assert
              (Pre_Prov < Cur_Prov,
               "Provider " & Pre_Prov
               & " should sort before " & Cur_Prov);
          end if;
        end;
      end if;
      Prev_Prov := Model.Provider;
      Prev_Id   := Model.Model_Id;
      Is_First  := False;
    end loop;

    Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
    Restore_Env ("HOME", Home_Was_Set, Old_Home);
    Cleanup_Test_Home (Home);
  exception
    when others =>
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
      raise;
  end Test_Available_Models_Sorted;

  --  Verify that MiniMax models use the Anthropic wire format.
  procedure Test_OpenCode_Go_Wire_Format_Anthropic (T : in out Test) is
    pragma Unreferenced (T);

    Home         : constant String := "/tmp/coyote_model_registry_test_8";
    Home_Was_Set : constant Boolean :=
      Ada.Environment_Variables.Exists ("HOME");
    Old_Home     : constant String :=
      Ada.Environment_Variables.Value ("HOME", "");
    Key_Was_Set  : constant Boolean :=
      Ada.Environment_Variables.Exists ("OPENCODE_API_KEY");
    Old_Key      : constant String :=
      Ada.Environment_Variables.Value ("OPENCODE_API_KEY", "");
    Model        : LLM.Model_Registry.Model_Info;
  begin
    Prepare_OpenCode_Go_Fixture_Home (Home);
    Ada.Environment_Variables.Set ("HOME", Home);
    Ada.Environment_Variables.Set ("OPENCODE_API_KEY", "fixture-key");

    LLM.Model_Registry.Refresh_OpenCode_Go;
    Model := LLM.Model_Registry.Lookup ("opencode-go", "minimax-m2.7");

    Assert
      (To_String (Model.Wire_Format) = "anthropic-messages",
       "MiniMax M2.7 should use the Anthropic Messages wire format");
    Assert
      (To_String (Model.Provider) = "opencode-go",
       "MiniMax M2.7 should have opencode-go provider");

    Restore_Env ("OPENCODE_API_KEY", Key_Was_Set, Old_Key);
    Restore_Env ("HOME", Home_Was_Set, Old_Home);
    Cleanup_Test_Home (Home);
  exception
    when others =>
      Restore_Env ("OPENCODE_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
      raise;
  end Test_OpenCode_Go_Wire_Format_Anthropic;

  --  Verify that non-MiniMax OpenCode Go models use OpenAI wire format.
  procedure Test_OpenCode_Go_Wire_Format_OpenAI (T : in out Test) is
    pragma Unreferenced (T);

    Home         : constant String := "/tmp/coyote_model_registry_test_9";
    Home_Was_Set : constant Boolean :=
      Ada.Environment_Variables.Exists ("HOME");
    Old_Home     : constant String :=
      Ada.Environment_Variables.Value ("HOME", "");
    Key_Was_Set  : constant Boolean :=
      Ada.Environment_Variables.Exists ("OPENCODE_API_KEY");
    Old_Key      : constant String :=
      Ada.Environment_Variables.Value ("OPENCODE_API_KEY", "");
    Model        : LLM.Model_Registry.Model_Info;
  begin
    Prepare_OpenCode_Go_Fixture_Home (Home);
    Ada.Environment_Variables.Set ("HOME", Home);
    Ada.Environment_Variables.Set ("OPENCODE_API_KEY", "fixture-key");

    LLM.Model_Registry.Refresh_OpenCode_Go;
    Model := LLM.Model_Registry.Lookup ("opencode-go", "deepseek-v4-pro");

    Assert
      (To_String (Model.Wire_Format) = "openai-completions",
       "DeepSeek V4 Pro should use the OpenAI completions wire format");

    Restore_Env ("OPENCODE_API_KEY", Key_Was_Set, Old_Key);
    Restore_Env ("HOME", Home_Was_Set, Old_Home);
    Cleanup_Test_Home (Home);
  exception
    when others =>
      Restore_Env ("OPENCODE_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
      raise;
  end Test_OpenCode_Go_Wire_Format_OpenAI;

  --  Verify that unknown opencode-go models get a sensible default.
  procedure Test_OpenCode_Go_Default_Fallback (T : in out Test) is
    pragma Unreferenced (T);

    Model : constant LLM.Model_Registry.Model_Info :=
      LLM.Model_Registry.Lookup ("opencode-go", "future-model-v9");
  begin
    Assert
      (To_String (Model.Provider) = "opencode-go",
       "Default OpenCode Go fallback should keep the provider name");
    Assert
      (To_String (Model.Model_Id) = "future-model-v9",
       "Default OpenCode Go fallback should preserve the requested id");
    Assert
      (To_String (Model.Wire_Format) = "openai-completions",
       "Default OpenCode Go fallback should use OpenAI completions");
  end Test_OpenCode_Go_Default_Fallback;

  --  Verify that OpenCode Go models appear in Available_Models only when
  --  an API key is configured.
  procedure Test_OpenCode_Go_Available_With_Key (T : in out Test) is
    pragma Unreferenced (T);

    Home         : constant String := "/tmp/coyote_model_registry_test_10";
    Home_Was_Set : constant Boolean :=
      Ada.Environment_Variables.Exists ("HOME");
    Old_Home     : constant String :=
      Ada.Environment_Variables.Value ("HOME", "");
    Key_Was_Set  : constant Boolean :=
      Ada.Environment_Variables.Exists ("OPENCODE_API_KEY");
    Old_Key      : constant String :=
      Ada.Environment_Variables.Value ("OPENCODE_API_KEY", "");
    Available    : LLM.Model_Registry.Model_Info_Vectors.Vector;
  begin
    Cleanup_Test_Home (Home);
    Ensure_Test_Home (Home);
    Ada.Environment_Variables.Set ("HOME", Home);
    Ada.Environment_Variables.Clear ("OPENCODE_API_KEY");

    LLM.Model_Registry.Refresh_OpenCode_Go;
    Available := LLM.Model_Registry.Available_Models;
    Assert
      (Count_Provider (Available, "opencode-go") = 0,
       "OpenCode Go models should be hidden without an API key");

    Ada.Environment_Variables.Set ("OPENCODE_API_KEY", "fixture-key");
    LLM.Model_Registry.Refresh_OpenCode_Go;
    Available := LLM.Model_Registry.Available_Models;
    Assert
      (Count_Provider (Available, "opencode-go") > 0,
       "OpenCode Go models should appear when OPENCODE_API_KEY is set");

    Restore_Env ("OPENCODE_API_KEY", Key_Was_Set, Old_Key);
    Restore_Env ("HOME", Home_Was_Set, Old_Home);
    Cleanup_Test_Home (Home);
  exception
    when others =>
      Restore_Env ("OPENCODE_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
      raise;
  end Test_OpenCode_Go_Available_With_Key;

end LLM_Model_Registry_Tests;
