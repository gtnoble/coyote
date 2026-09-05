with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

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
   procedure Test_Signature_Parsed_From_SSE (T : in out Test);
   procedure Test_Thinking_Block_Serialised_In_Request (T : in out Test);
   procedure Test_Tool_Result_Is_Error_Serialised (T : in out Test);

   procedure Test_System_Prompt_Is_Content_Block_Array (T : in out Test);
   procedure Test_Cache_Control_On_Last_Tool (T : in out Test);
   procedure Test_Cache_Control_On_Last_User_Message (T : in out Test);

   procedure Test_Tool_Result_Image_Serialised (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end LLM_Anthropic_Messages_Tests;
