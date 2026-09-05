with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package LLM_SSE_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Full_Event (T : in out Test);
   procedure Test_Multi_Chunk_Event (T : in out Test);
   procedure Test_Done_Event (T : in out Test);
   procedure Test_Ping_Skipped (T : in out Test);
   procedure Test_CRLF_Ping_Skipped (T : in out Test);
   procedure Test_Anthropic_Fixture (T : in out Test);
   procedure Test_OpenAI_Fixture (T : in out Test);
   procedure Test_Reset (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end LLM_SSE_Tests;
