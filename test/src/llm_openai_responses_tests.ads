with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package LLM_OpenAI_Responses_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Stream_Text_Response (T : in out Test);
   procedure Test_Stream_Tool_Call_Response (T : in out Test);
   procedure Test_Stream_Thinking_Response (T : in out Test);
   procedure Test_Compaction_Summary_Encodes_As_User (T : in out Test);
   procedure Test_Non_Streaming_Response (T : in out Test);
   procedure Test_HTTP_Error_Propagates (T : in out Test);
   procedure Test_Usage_Includes_Cache_Write (T : in out Test);
   procedure Test_Tool_Result_Image_Serialised (T : in out Test);
   procedure Test_Reasoning_Item_Replayed (T : in out Test);
   procedure Test_Omits_Store_And_Previous_Response (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end LLM_OpenAI_Responses_Tests;
