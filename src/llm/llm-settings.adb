--  LLM.Settings body.
--
--  Project: pi_acme
--  For revision history, see the project version-control log.

with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNATCOLL.JSON;

package body LLM.Settings is

   use type GNATCOLL.JSON.JSON_Value_Type;

   function Agent_Dir return String is
      Home : constant String := Ada.Environment_Variables.Value ("HOME", "");
   begin
      if Home'Length = 0 then
         return "";
      end if;

      return Home & "/.pi/agent";
   end Agent_Dir;

   function Settings_Path return String is
      Base : constant String := Agent_Dir;
   begin
      if Base'Length = 0 then
         return "";
      end if;

      return Base & "/settings.json";
   end Settings_Path;

   function Models_Path return String is
      Base : constant String := Agent_Dir;
   begin
      if Base'Length = 0 then
         return "";
      end if;

      return Base & "/models.json";
   end Models_Path;

   function Read_File (Path : String) return String is
      File    : Ada.Text_IO.File_Type;
      Content : Unbounded_String;
   begin
      if Path'Length = 0 or else not Ada.Directories.Exists (Path) then
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

         return "";
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
             (Get_String_Field (Root, "defaultThinkingLevel")));
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

end LLM.Settings;
