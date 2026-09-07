--  LLM.Providers.Codex.Catalogue — live Codex subscription model list.
--
--  Loads the ChatGPT Codex backend model catalogue with a 24-hour disk
--  cache stored under ~/.coyote.  Requires the OAuth credential entry
--  from ~/.coyote/auth.json; no live token refresh is performed here so
--  the registry refresh can stay synchronous at startup.  When the cached
--  access token is expired, the catalogue falls back to stale cache data
--  instead of contacting the backend.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

package LLM.Providers.Codex.Catalogue is

   type Model_Info is record
      Model_Id       : Ada.Strings.Unbounded.Unbounded_String;
      Name           : Ada.Strings.Unbounded.Unbounded_String;
      Description    : Ada.Strings.Unbounded.Unbounded_String;
      Context_Window : Natural := 272_000;
      Reasoning      : Boolean := True;
   end record;

   package Catalogue_Vectors is new Ada.Containers.Vectors
      (Index_Type   => Positive,
      Element_Type => Model_Info);

   --  Load the model catalogue from GET
   --  {base}/codex/models?client_version=<version>.
   --
   --  Requires ~/.coyote/auth.json to carry a codex OAuth credential;
   --  otherwise Models is returned empty without a network request.
   --
   --  Cache file: ~/.coyote/codex_models_cache.json.
   --  Max_Age_Hours selects how long cached data is considered fresh.
   --  When a live fetch fails, stale cached data is used when available;
   --  otherwise Models is returned empty.
   procedure Load_Catalogue
      (Models        :    out Catalogue_Vectors.Vector;
      Max_Age_Hours :        Natural := 24);

end LLM.Providers.Codex.Catalogue;
