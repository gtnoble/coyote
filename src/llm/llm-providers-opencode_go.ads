--  LLM.Providers.OpenCode_Go — OpenCode Go provider adapter.
--
--  Routes requests to either the OpenAI chat-completions or Anthropic
--  messages wire format depending on the model, using the OpenCode Go
--  API endpoint at https://opencode.ai/zen/go.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with LLM.Providers;
with LLM.Types;

package LLM.Providers.OpenCode_Go is

   type Provider is new LLM.Providers.Provider with null record;

   --  Construct an OpenCode Go provider.
   function Create return Provider;

   overriding
   procedure Send
     (P             : in out Provider;
      Model_Id      :        String;
      System_Prompt :        String;
      Messages      :        LLM.Types.Message_Vectors.Vector;
      Tools_Json    :        String;
      Thinking      :        LLM.Providers.Thinking_Level;
      Max_Tokens    :        Positive;
      Handler       :        LLM.Providers.Event_Handler);

end LLM.Providers.OpenCode_Go;