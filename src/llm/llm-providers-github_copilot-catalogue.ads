--  LLM.Providers.GitHub_Copilot.Catalogue -- live Copilot model list.
--
--  Loads the authenticated GitHub Copilot model catalogue, with a 24-hour
--  disk cache stored under ~/.coyote.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

package LLM.Providers.GitHub_Copilot.Catalogue is

   type Model_Capability_Info is record
      Model_Id            : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
      Name                : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
      Context_Window      : Natural := 128_000;
      Max_Tokens          : Natural := 4_096;
      Supports_Tools      : Boolean := True;
      Supports_Images     : Boolean := False;
      Reasoning           : Boolean := False;
      Max_Thinking_Budget : Natural := 0;
      Min_Thinking_Budget : Natural := 0;
      Supports_Anthropic  : Boolean := False;
      Supports_OpenAI     : Boolean := True;
   end record;

   package Catalogue_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Model_Capability_Info);

   --  Load the model catalogue from GET <Base_Url>/models.
   --
   --  If a matching cache file exists and is fresh, the cached catalogue is
   --  used. Otherwise a live fetch is attempted, the cache is updated, and
   --  Models receives the fetched chat-capable models. When the live fetch
   --  fails but a stale matching cache exists, that stale cache is used and a
   --  warning is written to standard error. If no usable cache exists, Models
   --  is returned empty.
   procedure Load_Catalogue
     (Base_Url      :     String;
      Token         :     String;
      Models        : out Catalogue_Vectors.Vector;
      Max_Age_Hours :     Natural := 24);

end LLM.Providers.GitHub_Copilot.Catalogue;
