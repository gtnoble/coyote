--  LLM.Providers.OpenRouter.Catalogue — live OpenRouter model list.
--
--  Loads the public OpenRouter model catalogue, with a 24-hour disk cache
--  stored under ~/.pi/agent.
--
--  Project: pi_acme
--  For revision history, see the project version-control log.

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

package LLM.Providers.OpenRouter.Catalogue is

   type Model_Info is record
      Model_Id        : Ada.Strings.Unbounded.Unbounded_String;
      Name            : Ada.Strings.Unbounded.Unbounded_String;
      Context_Window  : Natural := 128_000;
      Max_Tokens      : Natural := 4_096;
      Supports_Tools  : Boolean := True;
      Supports_Images : Boolean := False;
      Reasoning       : Boolean := False;
      Cost_Input      : Long_Float := 0.0;
      Cost_Output     : Long_Float := 0.0;
      Cost_Cache_Read : Long_Float := 0.0;
   end record;

   package Catalogue_Vectors is new Ada.Containers.Vectors
      (Index_Type   => Positive,
     Element_Type => Model_Info);

   --  Load the model catalogue from GET https://openrouter.ai/api/v1/models.
   --
   --  Cache file: ~/.pi/agent/openrouter_models_cache.json.
   --  Max_Age_Hours selects how long cached data is considered fresh.
   --  When a live fetch fails, stale cached data is used when available;
   --  otherwise Models is returned empty.
   procedure Load_Catalogue
      (Models        :    out Catalogue_Vectors.Vector;
     Max_Age_Hours :        Natural := 24);

end LLM.Providers.OpenRouter.Catalogue;
