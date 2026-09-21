--  Coyote_App_Frontend_RPC_Tests — RPC frontend reader tests.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Coyote_App_Frontend_RPC_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Reader_Demultiplexes_Prompts_And_Controls
     (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Coyote_App_Frontend_RPC_Tests;
