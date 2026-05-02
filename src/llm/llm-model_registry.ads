--  LLM.Model_Registry — live in-memory model catalogue registry.
--
--  Unifies provider-specific catalogue data from GitHub Copilot and
--  OpenRouter into one in-memory registry that can be refreshed at startup
--  and queried by provider/model identifier.
--
--  Project: pi_acme
--  For revision history, see the project version-control log.

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with LLM.Types;

package LLM.Model_Registry is

  --  Unified model information record combining data from both providers.
  type Model_Info is record
    Model_Id            : Ada.Strings.Unbounded.Unbounded_String;
    Name                : Ada.Strings.Unbounded.Unbounded_String;
    Provider            : Ada.Strings.Unbounded.Unbounded_String;
    Context_Window      : Natural := 128_000;
    Max_Tokens          : Natural := 4_096;
    Reasoning           : Boolean := False;
    Supports_Tools      : Boolean := True;
    Supports_Images     : Boolean := False;
    Max_Thinking_Budget : Natural := 0;
    Min_Thinking_Budget : Natural := 0;
    --  Wire format: "anthropic-messages" or "openai-completions".
    Wire_Format         : Ada.Strings.Unbounded.Unbounded_String;
    Cost                : LLM.Types.Model_Cost;
  end record;

  package Model_Info_Vectors is new Ada.Containers.Vectors
    (Index_Type   => Positive,
     Element_Type => Model_Info);

  Not_Found : exception;

  --  Populate the registry from the live GitHub Copilot catalogue.
  --
  --  Calls LLM.Auth.Load_Credentials, Ensure_Valid, Get_Base_Url, and then
  --  LLM.Providers.GitHub_Copilot.Catalogue.Load_Catalogue.
  --
  --  All existing "github-copilot" entries are cleared before the refreshed
  --  catalogue data is appended. When no Copilot credentials are configured,
  --  the GitHub Copilot portion of the registry becomes empty.
  procedure Refresh_GitHub_Copilot;

  --  Populate the registry from the live OpenRouter catalogue.
  --
  --  Calls LLM.Providers.OpenRouter.Catalogue.Load_Catalogue.
  --
  --  All existing "openrouter" entries are cleared before the refreshed
  --  catalogue data is appended.
  procedure Refresh_OpenRouter;

  --  Populate the registry with the direct Anthropic model subset.
  --
  --  When an Anthropic API key resolves from the environment or models.json,
  --  the registry gains a curated set of well-known Claude models using the
  --  Anthropic Messages wire format. All existing "anthropic" entries are
  --  cleared before the refreshed data is appended.
  procedure Refresh_Anthropic;

  --  Look up one model by provider and model identifier.
  --
  --  For "openrouter", an unknown Model_Id returns a default record with
  --  OpenAI-completions wire format and conservative limits rather than
  --  raising an exception.
  --
  --  For "github-copilot", a missing Model_Id raises Not_Found.
  --
  --  Unknown providers also raise Not_Found.
  function Lookup
    (Provider : String;
     Model_Id : String) return Model_Info;

  --  Return all registered models for providers that are currently
  --  configured.
  --
  --  GitHub Copilot models are included when auth.json contains a
  --  github-copilot credential entry. OpenRouter and Anthropic models are
  --  included when an API key resolves from the environment or models.json.
  function Available_Models return Model_Info_Vectors.Vector;

end LLM.Model_Registry;
