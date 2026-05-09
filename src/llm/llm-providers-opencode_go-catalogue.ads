--  LLM.Providers.OpenCode_Go.Catalogue — live OpenCode Go model list.
--
--  Fetches the available models from the OpenCode Go /v1/models endpoint,
--  with a 24-hour disk cache stored under ~/.coyote, and annotates each
--  model with its wire format (OpenAI completions or Anthropic messages)
--  and approximate capability metadata.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

package LLM.Providers.OpenCode_Go.Catalogue is

   --  Wire format used by a model.
   type Wire_Kind is
     (OpenAI_Completions_Wire,
      Anthropic_Messages_Wire);

   type Model_Info is record
      Model_Id        : Ada.Strings.Unbounded.Unbounded_String;
      Name            : Ada.Strings.Unbounded.Unbounded_String;
      Context_Window  : Natural := 128_000;
      Max_Tokens      : Natural := 16_384;
      Reasoning       : Boolean := False;
      Supports_Tools  : Boolean := True;
      Supports_Images : Boolean := False;
      Wire            : Wire_Kind := OpenAI_Completions_Wire;
   end record;

   package Catalogue_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Model_Info);

   --  Load the model catalogue from the OpenCode Go endpoint.
   --
   --  Cache file: ~/.coyote/opencode_go_models_cache.json.
   --  Max_Age_Hours selects how long cached data is considered fresh.
   --  When a live fetch fails, stale cached data is used when available;
   --  otherwise Models is returned empty.
   procedure Load_Catalogue
     (Models        :    out Catalogue_Vectors.Vector;
      Max_Age_Hours :        Natural := 24);

   --  Determine the wire format for a given model identifier.
   --
   --  Models using the Anthropic /v1/messages endpoint are minmax-m2.5
   --  and minimax-m2.7; all others use OpenAI /chat/completions.
   function Wire_Format_For (Model_Id : String) return Wire_Kind;

end LLM.Providers.OpenCode_Go.Catalogue;