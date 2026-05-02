with AUnit;
with AUnit.Test_Fixtures;

package LLM_OpenAI_Completions_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Stream_Text_Response (T : in out Test);
   procedure Test_Stream_Tool_Call_Response (T : in out Test);
   procedure Test_Stream_Multi_Tool_Response (T : in out Test);
   procedure Test_Stream_Thinking_Response (T : in out Test);
   procedure Test_Non_Streaming_Response (T : in out Test);

end LLM_OpenAI_Completions_Tests;
