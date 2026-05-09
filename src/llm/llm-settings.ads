--  LLM.Settings — read native harness configuration from coyote settings.
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
   function Resolve_Api_Key (Provider : String) return String;

end LLM.Settings;
