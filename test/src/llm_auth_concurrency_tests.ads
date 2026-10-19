with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package LLM_Auth_Concurrency_Tests is
   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Concurrent_Ensure (T : in out Test);
   procedure Test_Concurrent_Recover (T : in out Test);
   procedure Test_Refresh_Blocked_By_Login_And_Logout (T : in out Test);
   procedure Test_Concurrent_Save_Merge (T : in out Test);
   procedure Test_Killed_Lock_Holder (T : in out Test);
   procedure Test_Lock_Close_On_Exec (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;
end LLM_Auth_Concurrency_Tests;
