with AUnit;
with AUnit.Test_Fixtures;

package LLM_OpenCode_Go_Catalogue_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Verify that known models get their correct wire format.
   procedure Test_Wire_Format_MiniMax_Anthropic (T : in out Test);

   --  Verify that OpenAI-completions models get the correct wire format.
   procedure Test_Wire_Format_DeepSeek_OpenAI (T : in out Test);

   --  Verify that unknown models default to OpenAI completions.
   procedure Test_Wire_Format_Unknown_Defaults_OpenAI (T : in out Test);

   --  Verify that known models get correct static metadata.
   procedure Test_Static_Metadata_Known_Model (T : in out Test);

   --  Verify that unknown models get default metadata.
   procedure Test_Static_Metadata_Unknown_Model (T : in out Test);

end LLM_OpenCode_Go_Catalogue_Tests;