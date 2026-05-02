--  LLM.Settings — read native harness configuration from pi settings.
--
--  Loads default provider/model/thinking values from settings.json and
--  resolves provider API keys from models.json and the environment.
--
--  Project: pi_acme
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;

package LLM.Settings is

   type Settings is record
      Default_Provider : Ada.Strings.Unbounded.Unbounded_String;
      Default_Model    : Ada.Strings.Unbounded.Unbounded_String;
      Default_Thinking : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   --  Load ~/.pi/agent/settings.json.
   --  Missing fields are returned as empty strings.
   function Load_Settings return Settings;

   --  Resolve an API key for Provider.
   --  Resolution order:
   --    1. providers.<provider>.apiKey in ~/.pi/agent/models.json when it is
   --       a literal non-empty value.
   --    2. ${ENV_VAR} interpolation in models.json.
   --    3. Provider-specific environment variable fallback.
   --  Returns "" when no key is configured for that provider.
   function Resolve_Api_Key (Provider : String) return String;

end LLM.Settings;
