--  Coyote_App_Agent_RPC_Tests — versioned RPC frame codec tests.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;

package Coyote_App_Agent_RPC_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Handshake_Round_Trip (T : in out Test);
   procedure Test_Event_Round_Trip (T : in out Test);
   procedure Test_Command_Round_Trip (T : in out Test);
   procedure Test_Terminal_Round_Trip (T : in out Test);
   procedure Test_JSON_Escaping (T : in out Test);
   procedure Test_Encode_Has_No_Trailing_Newline (T : in out Test);
   procedure Test_Malformed_JSON (T : in out Test);
   procedure Test_Non_Object_Frame (T : in out Test);
   procedure Test_Wrong_Protocol (T : in out Test);
   procedure Test_Unsupported_Version (T : in out Test);
   procedure Test_Missing_Required_Field (T : in out Test);
   procedure Test_Invalid_Payload (T : in out Test);

end Coyote_App_Agent_RPC_Tests;
