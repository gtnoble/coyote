with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package LLM_Codex_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Make_Pkce (T : in out Test);
   procedure Test_New_State (T : in out Test);
   procedure Test_Build_Authorize_Url (T : in out Test);
   procedure Test_Account_Id_From_Jwt (T : in out Test);
   procedure Test_Token_Expired (T : in out Test);
   procedure Test_Refresh_Token (T : in out Test);
   procedure Test_Refresh_Token_Omitted_Rotation (T : in out Test);
   procedure Test_Recover_Rejected_Token_Refreshes_Valid (T : in out Test);
   procedure Test_Recover_Rejected_Token_Reuses_Latest (T : in out Test);
   procedure Test_Refresh_Token_Non_200_Raises (T : in out Test);
   procedure Test_Refresh_Token_Missing_Fields_Raises (T : in out Test);
   procedure Test_Send_Adds_Codex_Headers (T : in out Test);
   procedure Test_Send_Requires_Credentials (T : in out Test);
   procedure Test_Send_Requires_Account_Claim (T : in out Test);
   procedure Test_Send_Refreshes_Expired_Credentials (T : in out Test);
   procedure Test_Send_Recovers_401_And_Replays (T : in out Test);
   procedure Test_Send_Stops_After_Second_401 (T : in out Test);
   procedure Test_Send_Does_Not_Replay_When_Refresh_Fails (T : in out Test);
   procedure Test_Send_Cancellation_Prevents_Recovery (T : in out Test);
   procedure Test_Stream_Text_Response (T : in out Test);
   procedure Test_Stream_Thinking_Response (T : in out Test);
   procedure Test_Body_Omits_Store (T : in out Test);
   procedure Test_Registry_Refresh (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end LLM_Codex_Tests;
