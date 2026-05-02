--  LLM.Providers.GitHub_Copilot -- GitHub Copilot provider adapter.
--
--  Chooses the correct wire format for each GitHub Copilot model by reading
--  the authenticated live catalogue and then delegating to either the
--  Anthropic Messages or OpenAI Chat Completions provider.
--
--  Project: pi_acme
--  For revision history, see the project version-control log.

with LLM.Providers;
with LLM.Types;

package LLM.Providers.GitHub_Copilot is

   type Provider is new LLM.Providers.Provider with private;

   --  Construct a GitHub Copilot provider adapter.
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

private

   type Provider is new LLM.Providers.Provider with null record;

end LLM.Providers.GitHub_Copilot;
