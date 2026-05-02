with AUnit;
with AUnit.Test_Fixtures;

package LLM_OpenRouter_Catalogue_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Load_From_Fresh_Cache (T : in out Test);
   procedure Test_Stale_Cache_Triggers_Live_Fetch (T : in out Test);
   procedure Test_Stale_Cache_Fallback (T : in out Test);

end LLM_OpenRouter_Catalogue_Tests;
