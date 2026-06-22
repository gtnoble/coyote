--  LLM.Settings — read native harness configuration from coyote settings.
with GNATCOLL.JSON;
--
--  Loads default provider/model/thinking values and appendSystemPrompt
--  from settings.json, and resolves provider API keys from models.json
--  and the environment.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;

package LLM.Settings is

   --  Base configuration directory for coyote.
   --  Returns $HOME/.coyote, or "" when $HOME is not set.
   function Agent_Dir return String;

   type Settings is record
      Default_Provider     : Ada.Strings.Unbounded.Unbounded_String;
      Default_Model        : Ada.Strings.Unbounded.Unbounded_String;
      Default_Thinking     : Ada.Strings.Unbounded.Unbounded_String;
      Append_System_Prompt : Ada.Strings.Unbounded.Unbounded_String;
      --  Shell command line through which interactive prompts are filtered
      --  before being sent to the agent.  The raw prompt is written to stdin
      --  and stdout is used as the filtered prompt.  Empty means no filter.
      Prompt_Filter        : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   --  Load ~/.coyote/settings.json.
   --  Missing fields are returned as empty strings.
   function Load_Settings return Settings;

   --  Resolve an API key for Provider.
   --  Resolution order:
   --    1. providers.<provider>.apiKey in ~/.coyote/models.json when it is
   --       a literal non-empty value.
   --    2. ${ENV_VAR} interpolation in models.json.
   --    3. Provider-specific environment variable fallback.
   --  Returns "" when no key is configured for that provider.

   --  Path to ~/.coyote/models.json.  Empty when $HOME is not set.
   function Models_Path return String;

   --  Read a file and parse it as JSON, returning JSON_Null on error or
   --  when the file is absent.
   function Load_Json_File (Path : String) return GNATCOLL.JSON.JSON_Value;
   function Resolve_Api_Key (Provider : String) return String;

   --  Return the providers.<name> object from a loaded models.json root.
   --  Returns JSON_Null when the field is missing or is not an object.
   function Find_Provider_Config
     (Root : GNATCOLL.JSON.JSON_Value; Provider : String)
      return GNATCOLL.JSON.JSON_Value;


   --  Write the current default model (Provider/Id) and thinking level
   --  to ~/.coyote/settings.json, preserving all other existing fields.
   procedure Save_Defaults
     (Provider    : String;
      Model_Id    : String;
      Think_Level : String);
end LLM.Settings;
