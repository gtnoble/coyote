--  Coyote_App_Agent_RPC_Service_Tests — coordinator RPC service tests.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;

package Coyote_App_Agent_RPC_Service_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Listener_Registers_Child (T : in out Test);
   procedure Test_Command_Routes_To_Child (T : in out Test);
   procedure Test_Disconnect_Is_Reported (T : in out Test);

end Coyote_App_Agent_RPC_Service_Tests;
