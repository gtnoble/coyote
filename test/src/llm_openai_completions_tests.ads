with AUnit;
with AUnit.Test_Fixtures;

package LLM_OpenAI_Completions_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Stream_Text_Response (T : in out Test);
   procedure Test_Stream_Tool_Call_Response (T : in out Test);
   procedure Test_Stream_Multi_Tool_Response (T : in out Test);
   procedure Test_Stream_Thinking_Response (T : in out Test);
   procedure Test_Compaction_Summary_Encodes_As_User_OpenAI
     (T : in out Test);
   procedure Test_Non_Streaming_Response (T : in out Test);
   procedure Test_OpenAI_Non_Streaming_Tool_Calls (T : in out Test);
   procedure Test_OpenAI_HTTP_Error_Propagates (T : in out Test);
   procedure Test_OpenAI_Stream_Error_Propagates (T : in out Test);
   procedure Test_OpenAI_Stream_Terminates_Early (T : in out Test);
   procedure Test_OpenAI_System_Cache_Control (T : in out Test);
   procedure Test_OpenAI_Last_Tool_Cache_Control (T : in out Test);
   procedure Test_OpenAI_Cached_Tokens_In_Usage (T : in out Test);

   procedure Test_Tool_Result_Image_Serialised (T : in out Test);

end LLM_OpenAI_Completions_Tests;
