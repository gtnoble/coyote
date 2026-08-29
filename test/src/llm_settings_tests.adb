with AUnit.Assertions;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNATCOLL.JSON;
with LLM.Settings;
with Coyote_App.Utils;
with LLM.System_Prompt;

package body LLM_Settings_Tests is

   use AUnit.Assertions;

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

   procedure Write_File (Path : String; Content : String) is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (File, Content);
      Ada.Text_IO.Close (File);
   end Write_File;

   procedure Delete_If_Exists (Path : String) is
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_File (Path);
      end if;
   end Delete_If_Exists;

   procedure Cleanup_Test_Home (Home : String) is
      Agent_Dir : constant String := Home & "/.coyote";
   begin
      Delete_If_Exists (Agent_Dir & "/settings.json");
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

   procedure Test_Load_Settings (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String  := "/tmp/coyote_llm_settings_test_1";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String  :=
        Ada.Environment_Variables.Value ("HOME", "");
      Loaded       : LLM.Settings.Settings;
   begin
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);

      Write_File
        (Home & "/.coyote/settings.json",
         "{""defaultProvider"":""openrouter""," &
         """defaultModel"":""anthropic/claude-sonnet-4""," &
         """defaultThinkingLevel"":""medium""," &
         """defaultSubagentProvider"":""openrouter""," &
         """defaultSubagentModel"":""anthropic/claude-haiku""}");

      Ada.Environment_Variables.Set ("HOME", Home);
      Loaded := LLM.Settings.Load_Settings;

      Assert
        (To_String (Loaded.Default_Provider) = "openrouter",
         "defaultProvider should be loaded from settings.json");
      Assert
        (To_String (Loaded.Default_Model) = "anthropic/claude-sonnet-4",
         "defaultModel should be loaded from settings.json");
      Assert
        (To_String (Loaded.Default_Thinking) = "medium",
         "defaultThinkingLevel should be loaded from settings.json");
      Assert
        (To_String (Loaded.Default_Subagent_Provider) = "openrouter",
         "defaultSubagentProvider should be loaded from settings.json");
      Assert
        (To_String (Loaded.Default_Subagent_Model) = "anthropic/claude-haiku",
         "defaultSubagentModel should be loaded from settings.json");
      Assert
        (Loaded.Completion_Notifications,
         "completion notifications should default to enabled");

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Load_Settings;

   procedure Test_Append_System_Prompt_Loaded (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String  := "/tmp/coyote_llm_settings_test_5";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String  :=
        Ada.Environment_Variables.Value ("HOME", "");
      Loaded       : LLM.Settings.Settings;
   begin
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);

      Write_File
        (Home & "/.coyote/settings.json",
         "{""appendSystemPrompt"":""extra text""}");

      Ada.Environment_Variables.Set ("HOME", Home);
      Loaded := LLM.Settings.Load_Settings;

      Assert
        (To_String (Loaded.Append_System_Prompt) = "extra text",
         "appendSystemPrompt should be loaded from settings.json");

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Append_System_Prompt_Loaded;

   procedure Test_Append_System_Prompt_Missing (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String  := "/tmp/coyote_llm_settings_test_6";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String  :=
        Ada.Environment_Variables.Value ("HOME", "");
      Loaded       : LLM.Settings.Settings;
   begin
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);

      Write_File
        (Home & "/.coyote/settings.json",
         "{""defaultModel"":""x/y""}");

      Ada.Environment_Variables.Set ("HOME", Home);
      Loaded := LLM.Settings.Load_Settings;

      Assert
        (To_String (Loaded.Append_System_Prompt) = "",
         "Append_System_Prompt should default to the empty string");

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Append_System_Prompt_Missing;

   procedure Test_Append_Prompt_In_Built_Prompt (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String  := "/tmp/coyote_llm_settings_test_7";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String  :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);

      Ada.Environment_Variables.Set ("HOME", Home);

      declare
         Result : constant String :=
           LLM.System_Prompt.Build_System_Prompt
             (Cwd           => "/tmp/test_cwd",
              Agent => "APPEND_DIRECT");
      begin
         Assert
           (Ada.Strings.Fixed.Index (Result, "APPEND_DIRECT") > 0,
            "Agent parameter should appear in the built prompt");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Append_Prompt_In_Built_Prompt;

   procedure Test_Resolve_Api_Key_Literal (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String  := "/tmp/coyote_llm_settings_test_2";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String  :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set  : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key      : constant String  :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
   begin
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);

      Write_File
        (Home & "/.coyote/models.json",
         "{""providers"":{""openrouter"":{""apiKey"":""literal-key""}}}");

      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "env-key");

      Assert
        (LLM.Settings.Resolve_Api_Key ("openrouter") = "literal-key",
         "models.json literal apiKey should override environment");

      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Resolve_Api_Key_Literal;

   procedure Test_Resolve_Api_Key_Interpolated_Env (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String  := "/tmp/coyote_llm_settings_test_3";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String  :=
        Ada.Environment_Variables.Value ("HOME", "");
      Env_Was_Set  : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_TEST_OPENROUTER_KEY");
      Old_Env      : constant String  :=
        Ada.Environment_Variables.Value ("COYOTE_TEST_OPENROUTER_KEY", "");
      Key_Was_Set  : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key      : constant String  :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
   begin
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);

      Write_File
        (Home & "/.coyote/models.json",
         "{""providers"":{""openrouter"":{""apiKey"":""" &
         "${COYOTE_TEST_OPENROUTER_KEY}" & """}}}");

      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set
        ("COYOTE_TEST_OPENROUTER_KEY", "interpolated-key");
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "fallback-key");

      Assert
        (LLM.Settings.Resolve_Api_Key ("openrouter") = "interpolated-key",
         "${ENV_VAR} apiKey should read from the named environment");

      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("COYOTE_TEST_OPENROUTER_KEY", Env_Was_Set, Old_Env);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("COYOTE_TEST_OPENROUTER_KEY", Env_Was_Set, Old_Env);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Resolve_Api_Key_Interpolated_Env;

   procedure Test_Resolve_Api_Key_Default_Env (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String  := "/tmp/coyote_llm_settings_test_4";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String  :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set  : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key      : constant String  :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Git_Was_Set  : constant Boolean :=
        Ada.Environment_Variables.Exists ("GITHUB_TOKEN");
      Old_Git      : constant String  :=
        Ada.Environment_Variables.Value ("GITHUB_TOKEN", "");
   begin
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);

      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "default-env-key");
      Ada.Environment_Variables.Set ("GITHUB_TOKEN", "ignored-token");

      Assert
        (LLM.Settings.Resolve_Api_Key ("openrouter") = "default-env-key",
         "standard environment fallback should resolve openrouter");
      Assert
        (LLM.Settings.Resolve_Api_Key ("github-copilot") = "",
         "github-copilot should not resolve via generic env fallback");

      Restore_Env ("GITHUB_TOKEN", Git_Was_Set, Old_Git);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("GITHUB_TOKEN", Git_Was_Set, Old_Git);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Resolve_Api_Key_Default_Env;

   procedure Test_Prompt_Filter_Loaded (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String  := "/tmp/coyote_llm_settings_test_8";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String  :=
        Ada.Environment_Variables.Value ("HOME", "");
      Loaded       : LLM.Settings.Settings;
   begin
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);

      Write_File
        (Home & "/.coyote/settings.json",
         "{""promptFilter"":""m4 -""}");

      Ada.Environment_Variables.Set ("HOME", Home);
      Loaded := LLM.Settings.Load_Settings;

      Assert
        (To_String (Loaded.Prompt_Filter) = "m4 -",
         "promptFilter should be loaded from settings.json");

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Prompt_Filter_Loaded;

   procedure Test_Prompt_Filter_Missing (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String  := "/tmp/coyote_llm_settings_test_9";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String  :=
        Ada.Environment_Variables.Value ("HOME", "");
      Loaded       : LLM.Settings.Settings;
   begin
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);

      Write_File
        (Home & "/.coyote/settings.json",
         "{""defaultModel"":""x/y""}");

      Ada.Environment_Variables.Set ("HOME", Home);
      Loaded := LLM.Settings.Load_Settings;

      Assert
        (To_String (Loaded.Prompt_Filter) = "",
         "Prompt_Filter should default to the empty string when absent");

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Prompt_Filter_Missing;

   procedure Test_Default_Sandbox_Profile_Loaded (T : in out Test) is
      pragma Unreferenced (T);
      Home         : constant String := "/tmp/coyote_llm_settings_test_10";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Loaded       : LLM.Settings.Settings;
   begin
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);
      Write_File
        (Home & "/.coyote/settings.json",
         "{""defaultSandboxProfile"":""restricted""}");
      Ada.Environment_Variables.Set ("HOME", Home);
      Loaded := LLM.Settings.Load_Settings;
      Assert (To_String (Loaded.Default_Sandbox) = "restricted",
              "defaultSandboxProfile should be loaded");
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Default_Sandbox_Profile_Loaded;

   procedure Test_Max_Recursion_Depth_Invalid_Defaults (T : in out Test) is
      pragma Unreferenced (T);
      Home         : constant String := "/tmp/coyote_llm_settings_test_13";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Loaded       : LLM.Settings.Settings;
   begin
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);
      Write_File
        (Home & "/.coyote/settings.json",
         "{""maxRecursionDepth"":3}");
      Ada.Environment_Variables.Set ("HOME", Home);
      Loaded := LLM.Settings.Load_Settings;
      Assert (Loaded.Max_Recursion_Depth = 3,
              "maxRecursionDepth should load as a nonnegative integer");

      Write_File
        (Home & "/.coyote/settings.json", "{}");
      Loaded := LLM.Settings.Load_Settings;
      Assert (Loaded.Max_Recursion_Depth = 1,
              "absent maxRecursionDepth should use the default");

      Write_File
        (Home & "/.coyote/settings.json",
         "{""maxRecursionDepth"":-1}");
      Loaded := LLM.Settings.Load_Settings;
      Assert (Loaded.Max_Recursion_Depth = 1,
              "negative maxRecursionDepth should use the default");

      Write_File
        (Home & "/.coyote/settings.json",
         "{""maxRecursionDepth"":""bad""}");
      Loaded := LLM.Settings.Load_Settings;
      Assert (Loaded.Max_Recursion_Depth = 1,
              "non-integer maxRecursionDepth should use the default");

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Max_Recursion_Depth_Invalid_Defaults;

   procedure Test_Completion_Notifications_Default_Enabled
     (T : in out Test)
   is
      pragma Unreferenced (T);
      Home         : constant String := "/tmp/coyote_llm_settings_test_12";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Loaded       : LLM.Settings.Settings;
   begin
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);
      Write_File
        (Home & "/.coyote/settings.json",
         "{""completionNotifications"":false}");
      Ada.Environment_Variables.Set ("HOME", Home);
      Loaded := LLM.Settings.Load_Settings;
      Assert
        (not Loaded.Completion_Notifications,
         "explicit false completion notification setting should load");
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Completion_Notifications_Default_Enabled;

   procedure Test_Save_Preferences_Preserves_And_Clears (T : in out Test) is
      pragma Unreferenced (T);
      Home         : constant String := "/tmp/coyote_llm_settings_test_11";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Root         : GNATCOLL.JSON.JSON_Value;
   begin
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);
      Write_File
        (Home & "/.coyote/settings.json",
         "{""appendSystemPrompt"":""keep"",""future"":42," &
         """defaultProvider"":""old"",""defaultModel"":""old/model""," &
         """defaultThinkingLevel"":""low""," &
         """defaultSandboxProfile"":""old-profile""}");
      Ada.Environment_Variables.Set ("HOME", Home);

      LLM.Settings.Save_Preferences
        (Provider => "openrouter",
         Model_Id => "new/model",
         Think_Level       => "high",
         Sandbox                  => "restricted",
         Subagent_Provider        => "openrouter",
         Subagent_Model           => "new/fast-model",
         Max_Recursion_Depth      => 3,
         Completion_Notifications => False);
      Root := LLM.Settings.Load_Json_File (Home & "/.coyote/settings.json");
      Assert (Coyote_App.Utils.Get_String (Root, "defaultProvider") =
                "openrouter",
              "Save_Preferences should write provider");
      Assert (Coyote_App.Utils.Get_String (Root, "defaultModel") =
                "new/model",
              "Save_Preferences should write model");
      Assert (Coyote_App.Utils.Get_String (Root, "defaultThinkingLevel") =
                "high",
              "Save_Preferences should write thinking level");
      Assert (Coyote_App.Utils.Get_String (Root, "defaultSandboxProfile") =
                "restricted",
              "Save_Preferences should write sandbox profile");
      Assert
        (not Coyote_App.Utils.Get_Boolean
           (Root, "completionNotifications"),
         "Save_Preferences should write disabled completion notifications");
      Assert (Coyote_App.Utils.Get_String (Root, "appendSystemPrompt") =
                "keep",
              "Save_Preferences should preserve unrelated fields");
      Assert (Coyote_App.Utils.Get_Integer (Root, "future") = 42,
              "Save_Preferences should preserve unknown fields");
      Assert (Coyote_App.Utils.Get_String (Root, "appendSystemPrompt") =
                "keep",
              "clearing preferences should preserve unrelated fields");
      Assert (not Ada.Directories.Exists
                (Home & "/.coyote/settings.json.tmp"),
              "atomic save should remove its temporary file");

      LLM.Settings.Save_Preferences
        (Provider            => "",
         Model_Id            => "",
         Think_Level         => "",
         Sandbox             => "",
         Max_Recursion_Depth => 0);
      Root := LLM.Settings.Load_Json_File (Home & "/.coyote/settings.json");
      Assert (Coyote_App.Utils.Get_Integer (Root, "maxRecursionDepth") = 0,
              "zero recursion depth should be persisted");
      Assert (not Root.Has_Field ("defaultProvider"),
              "empty provider should clear the persisted field");
      Assert (not Root.Has_Field ("defaultModel"),
              "empty model should clear the persisted field");
      Assert (not Root.Has_Field ("defaultThinkingLevel"),
              "empty thinking should clear the persisted field");
      Assert (not Root.Has_Field ("defaultSandboxProfile"),
              "empty sandbox should clear the persisted field");
      Assert (not Root.Has_Field ("defaultSubagentProvider"),
              "empty subagent provider should clear the persisted field");
      Assert (not Root.Has_Field ("defaultSubagentModel"),
              "empty subagent model should clear the persisted field");
      Assert (Coyote_App.Utils.Get_String (Root, "appendSystemPrompt") =
                "keep",
              "clearing preferences should preserve unrelated fields");

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Save_Preferences_Preserves_And_Clears;

end LLM_Settings_Tests;
