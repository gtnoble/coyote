with AUnit;
with AUnit.Test_Fixtures;

package LLM_GitHub_Copilot_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Send_Adds_Static_Headers (T : in out Test);
   procedure Test_Send_Sets_X_Initiator_User (T : in out Test);
   procedure Test_Send_Sets_X_Initiator_Agent (T : in out Test);
   procedure Test_Send_Selects_Anthropic_Path (T : in out Test);
   procedure Test_Send_Selects_OpenAI_Path (T : in out Test);
   procedure Test_Copilot_Refreshes_Expired_Token_Then_Sends
      (T : in out Test);

end LLM_GitHub_Copilot_Tests;
