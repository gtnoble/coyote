--  Coyote_App_Agent_RPC_Transport_Tests — local RPC channel tests.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Coyote_App_Agent_RPC_Transport_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Pair_Round_Trip (T : in out Test);
   procedure Test_Handshake_Ordering (T : in out Test);
   procedure Test_Event_Sequence_Must_Increase (T : in out Test);
   procedure Test_Terminal_Closes_Send_Side (T : in out Test);
   procedure Test_Peer_Close_Is_Reported (T : in out Test);
   procedure Test_Receive_Times_Out_When_Idle (T : in out Test);
   procedure Test_Unix_Listener_Times_Out_When_Idle (T : in out Test);
   procedure Test_Unix_Listener_Accepts_Client (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Coyote_App_Agent_RPC_Transport_Tests;
