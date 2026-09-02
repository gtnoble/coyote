--  LLM.Settings — read native harness configuration from coyote settings.
with GNATCOLL.JSON;
--
--  Loads default provider/model/thinking values and appendSystemPrompt
--  from settings.json, and resolves provider API keys from models.json
--  and the environment.
--
--  Project: coyote

with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Unbounded;

package LLM.Settings is

   --  Grace period after shutdown sends SIGTERM to shell process groups.
   --  Zero requests immediate SIGKILL after SIGTERM; values above the
   --  maximum are clamped when settings are loaded or saved.
   Default_Termination_Grace_Seconds : constant Natural := 2;
   Max_Termination_Grace_Seconds     : constant Natural := 30;

   --  Price units shown in the GTK model picker.
   type Price_Display_Mode is (SI_Prefixes, Decibels);

   --  Base configuration directory for coyote.
   --  Returns $HOME/.coyote, or "" when $HOME is not set.

   function Agent_Dir return String;

   package String_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type   => Positive,
      Element_Type => String);

   type Settings is record
      Default_Provider          : Ada.Strings.Unbounded.Unbounded_String;
      Default_Model             : Ada.Strings.Unbounded.Unbounded_String;
      Default_Thinking          : Ada.Strings.Unbounded.Unbounded_String;
      Default_Sandbox           : Ada.Strings.Unbounded.Unbounded_String;
      Default_Subagent_Provider : Ada.Strings.Unbounded.Unbounded_String;
      Default_Subagent_Model    : Ada.Strings.Unbounded.Unbounded_String;
      --  Maximum number of nested --subagent processes.  A value of zero
      --  disables subagent spawning; the default permits one child level.
      Max_Recursion_Depth       : Natural := 1;
      --  Grace period after process shutdown sends SIGTERM to shell groups.
      Shell_Termination_Grace_Seconds : Natural :=
        Default_Termination_Grace_Seconds;
      Append_System_Prompt      : Ada.Strings.Unbounded.Unbounded_String;
      --  Shell command line through which interactive prompts are filtered
      --  before being sent to the agent.  The raw prompt is written to stdin
      --  and stdout is used as the filtered prompt.  Empty means no filter.
      Prompt_Filter             : Ada.Strings.Unbounded.Unbounded_String;
      --  Whether interactive GUI completion notifications are enabled.
      Completion_Notifications  : Boolean := True;
      --  Price units shown in the GTK model picker.
      Price_Display             : Price_Display_Mode := SI_Prefixes;
      --  Additional skill roots from the skillPaths JSON array.
      Skill_Paths               : String_Vectors.Vector;
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

   --  Write model, thinking, sandbox, price-display, recursion,
   --  notification, skill-path, and shell-termination defaults to
   --  settings.json.  Price_Display is persisted as "si" or "db".
   --  Empty string values clear the corresponding string preference.
   --  Unrelated fields are preserved and the replacement is atomic.
   procedure Save_Preferences
     (Provider                 : String;
      Model_Id                 : String;
      Think_Level              : String;
      Sandbox                  : String;
      Price_Display            : Price_Display_Mode;
      Subagent_Provider        : String := "";
      Subagent_Model           : String := "";
      Max_Recursion_Depth      : Natural := 1;
      Completion_Notifications : Boolean := True;
      Skill_Paths               : String_Vectors.Vector :=
        String_Vectors.Empty_Vector;
      Termination_Grace_Seconds : Natural :=
        Default_Termination_Grace_Seconds);

end LLM.Settings;
