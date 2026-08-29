--  LLM.Settings body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.IO_Exceptions;
with Ada.Text_IO;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with GNAT.OS_Lib;
with Coyote_Utils;

package body LLM.Settings is

   use type GNATCOLL.JSON.JSON_Value_Type;

   function Agent_Dir return String is
      Home : constant String := Ada.Environment_Variables.Value ("HOME", "");
   begin
      if Home'Length = 0 then
         return "";
      end if;

      return Home & "/.coyote";
   end Agent_Dir;

   function Settings_Path return String is
      Base : constant String := Agent_Dir;
   begin
      if Base'Length = 0 then
         return "";
      end if;

      return Base & "/settings.json";
   end Settings_Path;

   function Temp_Path (Path : String) return String is
   begin
      return Path & ".tmp";
   end Temp_Path;

   function Models_Path return String is
      Base : constant String := Agent_Dir;
   begin
      if Base'Length = 0 then
         return "";
      end if;

      return Base & "/models.json";
   end Models_Path;

   function Read_File (Path : String) return String is
   begin
      if Path'Length = 0 or else not Ada.Directories.Exists (Path) then
         return "";
      end if;

      return Coyote_Utils.Read_Whole_File (Path);
   end Read_File;

   function Load_Json_File (Path : String) return GNATCOLL.JSON.JSON_Value is
      Content : constant String := Read_File (Path);
   begin
      if Content'Length = 0 then
         return GNATCOLL.JSON.JSON_Null;
      end if;

      declare
         Parsed : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (Content);
      begin
         if Parsed.Success then
            return Parsed.Value;
         end if;
      end;

      return GNATCOLL.JSON.JSON_Null;
   end Load_Json_File;

   function Get_String_Field
     (Value : GNATCOLL.JSON.JSON_Value; Field : String) return String
   is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_String_Type
      then
         return Value.Get (Field).Get;
      end if;

      return "";
   end Get_String_Field;

   function Get_Boolean_Field
     (Value   : GNATCOLL.JSON.JSON_Value;
      Field   : String;
      Default : Boolean) return Boolean
   is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_Boolean_Type
      then
         return Value.Get (Field).Get;
      end if;

      return Default;
   end Get_Boolean_Field;

   function Get_Array_Field
     (Value : GNATCOLL.JSON.JSON_Value; Field : String)
      return GNATCOLL.JSON.JSON_Array
   is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_Array_Type
      then
         return Value.Get (Field).Get;
      end if;

      return GNATCOLL.JSON.Empty_Array;
   end Get_Array_Field;

   function Get_Natural_Field
     (Value   : GNATCOLL.JSON.JSON_Value;
      Field   : String;
      Default : Natural) return Natural
   is
      Raw : Long_Integer;
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_Int_Type
      then
         Raw := Value.Get (Field).Get;
         if Raw >= 0 and then Raw <= Long_Integer (Natural'Last) then
            return Natural (Raw);
         end if;
      end if;

      return Default;
   end Get_Natural_Field;

   function Get_Object_Field
     (Value : GNATCOLL.JSON.JSON_Value; Field : String)
      return GNATCOLL.JSON.JSON_Value
   is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_Object_Type
      then
         return Value.Get (Field);
      end if;

      return GNATCOLL.JSON.JSON_Null;
   end Get_Object_Field;

   function Find_Provider_Config
     (Root : GNATCOLL.JSON.JSON_Value; Provider : String)
      return GNATCOLL.JSON.JSON_Value
   is
      Providers : constant GNATCOLL.JSON.JSON_Value :=
        Get_Object_Field (Root, "providers");
      Lower : constant String := Ada.Characters.Handling.To_Lower (Provider);
   begin
      if Providers.Kind /= GNATCOLL.JSON.JSON_Object_Type then
         return GNATCOLL.JSON.JSON_Null;
      end if;

      if Providers.Has_Field (Provider)
        and then Providers.Get (Provider).Kind = GNATCOLL.JSON.JSON_Object_Type
      then
         return Providers.Get (Provider);
      end if;

      if Lower /= Provider and then Providers.Has_Field (Lower)
        and then Providers.Get (Lower).Kind = GNATCOLL.JSON.JSON_Object_Type
      then
         return Providers.Get (Lower);
      end if;

      return GNATCOLL.JSON.JSON_Null;
   end Find_Provider_Config;

   function Standard_Env_Name (Provider : String) return String is
      Lower : constant String := Ada.Characters.Handling.To_Lower (Provider);
   begin
      if Lower = "anthropic" then
         return "ANTHROPIC_API_KEY";
      elsif Lower = "openai" then
         return "OPENAI_API_KEY";
      elsif Lower = "azure-openai-responses" then
         return "AZURE_OPENAI_API_KEY";
      elsif Lower = "google" then
         return "GEMINI_API_KEY";
      elsif Lower = "groq" then
         return "GROQ_API_KEY";
      elsif Lower = "cerebras" then
         return "CEREBRAS_API_KEY";
      elsif Lower = "xai" then
         return "XAI_API_KEY";
      elsif Lower = "openrouter" then
         return "OPENROUTER_API_KEY";
      elsif Lower = "vercel-ai-gateway" then
         return "AI_GATEWAY_API_KEY";
      elsif Lower = "zai" then
         return "ZAI_API_KEY";
      elsif Lower = "mistral" then
         return "MISTRAL_API_KEY";
      elsif Lower = "minimax" then
         return "MINIMAX_API_KEY";
      elsif Lower = "minimax-cn" then
         return "MINIMAX_CN_API_KEY";
      elsif Lower = "huggingface" then
         return "HF_TOKEN";
      elsif Lower = "opencode" or else Lower = "opencode-go" then
         return "OPENCODE_API_KEY";
      elsif Lower = "ollama" then
         return "OLLAMA_API_KEY";
      elsif Lower = "kimi-coding" then
         return "KIMI_API_KEY";
      else
         return "";
      end if;
   end Standard_Env_Name;

   function Interpolated_Env_Name (Value : String) return String is
   begin
      if Value'Length >= 4
        and then Value (Value'First .. Value'First + 1) = "${"
        and then Value (Value'Last) = '}'
      then
         return Value (Value'First + 2 .. Value'Last - 1);
      end if;

      return "";
   end Interpolated_Env_Name;

   function Get_Skill_Paths
     (Root : GNATCOLL.JSON.JSON_Value) return String_Vectors.Vector
   is
      Paths : String_Vectors.Vector;
      Items : constant GNATCOLL.JSON.JSON_Array :=
        Get_Array_Field (Root, "skillPaths");
   begin
      for I in 1 .. GNATCOLL.JSON.Length (Items) loop
         declare
            Item : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Get (Items, I);
         begin
            if Item.Kind = GNATCOLL.JSON.JSON_String_Type then
               declare
                  Item_Text : constant String := Item.Get;
               begin
                  if Item_Text'Length > 0 then
                     Paths.Append (Item_Text);
                  end if;
               end;
            end if;
         end;
      end loop;
      return Paths;
   end Get_Skill_Paths;

   function Load_Settings return Settings is
      Root : constant GNATCOLL.JSON.JSON_Value :=
        Load_Json_File (Settings_Path);
   begin
      return
        (Default_Provider =>
           To_Unbounded_String (Get_String_Field (Root, "defaultProvider")),
         Default_Model    =>
           To_Unbounded_String (Get_String_Field (Root, "defaultModel")),
         Default_Thinking =>
           To_Unbounded_String
             (Get_String_Field (Root, "defaultThinkingLevel")),
         Default_Sandbox           =>
           To_Unbounded_String
             (Get_String_Field (Root, "defaultSandboxProfile")),
         Default_Subagent_Provider =>
           To_Unbounded_String
             (Get_String_Field (Root, "defaultSubagentProvider")),
         Default_Subagent_Model    =>
           To_Unbounded_String
             (Get_String_Field (Root, "defaultSubagentModel")),
         Max_Recursion_Depth       =>
           Get_Natural_Field (Root, "maxRecursionDepth", 1),
         Append_System_Prompt      =>
           To_Unbounded_String
             (Get_String_Field (Root, "appendSystemPrompt")),
         Prompt_Filter =>
           To_Unbounded_String
             (Get_String_Field (Root, "promptFilter")),
         Completion_Notifications =>
           Get_Boolean_Field (Root, "completionNotifications", True),
         Skill_Paths => Get_Skill_Paths (Root));
   end Load_Settings;

   function Resolve_Api_Key (Provider : String) return String is
      Root : constant GNATCOLL.JSON.JSON_Value := Load_Json_File (Models_Path);
      Provider_J  : constant GNATCOLL.JSON.JSON_Value :=
        Find_Provider_Config (Root, Provider);
      Configured  : constant String := Get_String_Field (Provider_J, "apiKey");
      Env_Name    : constant String := Interpolated_Env_Name (Configured);
      Default_Env : constant String := Standard_Env_Name (Provider);
   begin
      if Configured'Length > 0 and then Env_Name'Length = 0 then
         return Configured;
      end if;

      if Env_Name'Length > 0
        and then Ada.Environment_Variables.Exists (Env_Name)
      then
         return Ada.Environment_Variables.Value (Env_Name);
      end if;

      if Default_Env'Length > 0
        and then Ada.Environment_Variables.Exists (Default_Env)
      then
         return Ada.Environment_Variables.Value (Default_Env);
      end if;

      return "";
   end Resolve_Api_Key;

   procedure Delete_If_Exists (Path : String) is
   begin
      if Path'Length > 0 and then Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_File (Path);
      end if;
   exception
      when others =>
         null;
   end Delete_If_Exists;

   procedure Write_Atomically (Path : String; Content : String) is
      File      : Ada.Text_IO.File_Type;
      Tmp_Path  : constant String := Temp_Path (Path);
      Renamed   : Boolean         := False;
      Dir_Path  : constant String :=
        Ada.Directories.Containing_Directory (Path);
   begin
      if Path'Length = 0 then
         raise Ada.IO_Exceptions.Use_Error with
           "HOME is not set; cannot write settings";
      end if;

      Ada.Directories.Create_Path (Dir_Path);
      Delete_If_Exists (Tmp_Path);

      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Tmp_Path);
      Ada.Text_IO.Put (File, Content);
      Ada.Text_IO.Close (File);

      GNAT.OS_Lib.Rename_File (Tmp_Path, Path, Renamed);

      if not Renamed then
         Delete_If_Exists (Tmp_Path);
         raise Ada.IO_Exceptions.Use_Error with
           "Failed to rename temporary settings file";
      end if;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;

         raise;
   end Write_Atomically;

   procedure Save_Defaults
     (Provider    : String;
      Model_Id    : String;
      Think_Level : String)
   is
      Path     : constant String := Settings_Path;
      Existing : constant GNATCOLL.JSON.JSON_Value :=
        Load_Json_File (Path);
      Root     : constant GNATCOLL.JSON.JSON_Value :=
        (if Existing.Kind = GNATCOLL.JSON.JSON_Object_Type
         then Existing
         else GNATCOLL.JSON.Create_Object);
   begin
      if Path'Length = 0 then
         return;
      end if;

      if Provider'Length > 0 then
         Root.Set_Field ("defaultProvider", Provider);
      end if;
      if Model_Id'Length > 0 then
         Root.Set_Field ("defaultModel", Model_Id);
      end if;
      if Think_Level'Length > 0 then
         Root.Set_Field ("defaultThinkingLevel", Think_Level);
      end if;

      Write_Atomically (Path, GNATCOLL.JSON.Write (Root));
   end Save_Defaults;

   procedure Save_Preferences
     (Provider                 : String;
      Model_Id                 : String;
      Think_Level              : String;
      Sandbox                  : String;
      Subagent_Provider        : String := "";
      Subagent_Model           : String := "";
      Max_Recursion_Depth      : Natural := 1;
      Completion_Notifications : Boolean := True;
      Skill_Paths               : String_Vectors.Vector :=
        String_Vectors.Empty_Vector)
   is
      Path     : constant String := Settings_Path;
      Existing : constant GNATCOLL.JSON.JSON_Value :=
        Load_Json_File (Path);
      Root     : constant GNATCOLL.JSON.JSON_Value :=
        (if Existing.Kind = GNATCOLL.JSON.JSON_Object_Type
         then Existing
         else GNATCOLL.JSON.Create_Object);
   begin
      if Path'Length = 0 then
         raise Ada.IO_Exceptions.Use_Error with
           "HOME is not set; cannot write settings";
      end if;

      if Provider'Length > 0 then
         Root.Set_Field ("defaultProvider", Provider);
      else
         Root.Unset_Field ("defaultProvider");
      end if;

      if Model_Id'Length > 0 then
         Root.Set_Field ("defaultModel", Model_Id);
      else
         Root.Unset_Field ("defaultModel");
      end if;

      if Think_Level'Length > 0 then
         Root.Set_Field ("defaultThinkingLevel", Think_Level);
      else
         Root.Unset_Field ("defaultThinkingLevel");
      end if;

      if Sandbox'Length > 0 then
         Root.Set_Field ("defaultSandboxProfile", Sandbox);
      else
         Root.Unset_Field ("defaultSandboxProfile");
      end if;

      if Subagent_Provider'Length > 0 then
         Root.Set_Field ("defaultSubagentProvider", Subagent_Provider);
      else
         Root.Unset_Field ("defaultSubagentProvider");
      end if;

      if Subagent_Model'Length > 0 then
         Root.Set_Field ("defaultSubagentModel", Subagent_Model);
      else
         Root.Unset_Field ("defaultSubagentModel");
      end if;

      Root.Set_Field
        ("maxRecursionDepth", Long_Integer (Max_Recursion_Depth));
      Root.Set_Field ("completionNotifications", Completion_Notifications);

      if Skill_Paths.Is_Empty then
         Root.Unset_Field ("skillPaths");
      else
         declare
            Paths : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
         begin
            for Path_Name of Skill_Paths loop
               GNATCOLL.JSON.Append (Paths, GNATCOLL.JSON.Create (Path_Name));
            end loop;
            Root.Set_Field ("skillPaths", Paths);
         end;
      end if;

      Write_Atomically (Path, GNATCOLL.JSON.Write (Root));
   end Save_Preferences;
end LLM.Settings;
