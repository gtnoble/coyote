with AUnit;
with AUnit.Test_Fixtures;

package LLM_Anthropic_Messages_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Stream_Thinking_And_Text_Response (T : in out Test);
   procedure Test_Request_Headers (T : in out Test);
   procedure Test_Thinking_Budget_Injection (T : in out Test);
   procedure Test_Compaction_Summary_Encodes_As_User_Anthropic
     (T : in out Test);
   procedure Test_Stream_Tool_Use_Response (T : in out Test);
   procedure Test_Stop_Reason_Mappings (T : in out Test);
   procedure Test_Anthropic_Uses_X_Api_Key_Header (T : in out Test);
   procedure Test_Anthropic_HTTP_Error_Propagates (T : in out Test);
   procedure Test_Anthropic_Stream_Terminates_Early (T : in out Test);

end LLM_Anthropic_Messages_Tests;
