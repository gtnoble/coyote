--  LLM.Providers.Ollama.Catalogue — live Ollama model list.
--
--  Fetches the available models from the Ollama /api/tags endpoint,
--  with a 24-hour disk cache stored under ~/.coyote, and annotates each
--  model with its wire format (Ollama native chat).
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

package LLM.Providers.Ollama.Catalogue is

   type Model_Info is record
      Model_Id        : Ada.Strings.Unbounded.Unbounded_String;
      Name            : Ada.Strings.Unbounded.Unbounded_String;
      Context_Window  : Natural := 128_000;
      Max_Tokens      : Natural := 16_384;
      Reasoning       : Boolean := False;
      Supports_Tools  : Boolean := True;
      Supports_Images : Boolean := False;
   end record;

   package Catalogue_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Model_Info);

   --  Load the model catalogue from the Ollama /api/tags endpoint.
   --
   --  Cache file: ~/.coyote/ollama_models_cache.json.
   --  Max_Age_Hours selects how long cached data is considered fresh.
   --  When a live fetch fails, stale cached data is used when available;
   --  otherwise Models is returned empty.
   procedure Load_Catalogue
     (Models        :    out Catalogue_Vectors.Vector;
      Base_Url      :        String := "";
      Api_Key       :        String := "";
      Max_Age_Hours :        Natural := 24);

end LLM.Providers.Ollama.Catalogue;
