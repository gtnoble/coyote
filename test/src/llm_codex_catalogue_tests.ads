with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package LLM_Codex_Catalogue_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Load_From_Fresh_Cache (T : in out Test);
   procedure Test_Cache_Missing_Triggers_Live_Fetch (T : in out Test);
   procedure Test_Expired_Token_Refreshes_Before_Fetch (T : in out Test);
   procedure Test_401_Recovers_And_Replays_Once (T : in out Test);
   procedure Test_401_Recovery_Failure_Uses_Stale_Cache (T : in out Test);
   procedure Test_Refresh_Failure_Uses_Stale_Cache (T : in out Test);
   procedure Test_Fetch_Failure_No_Cache_Yields_Empty (T : in out Test);
   procedure Test_No_Credentials_Yields_Empty (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end LLM_Codex_Catalogue_Tests;
