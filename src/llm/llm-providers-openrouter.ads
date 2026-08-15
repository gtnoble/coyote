--  LLM.Providers.OpenRouter — OpenRouter Responses API adapter.
--
--  Uses the OpenAI Responses provider with OpenRouter's default base URL,
--  metadata headers, and API-key resolution. Reasoning-effort configuration
--  is inherited from the Responses provider.
--
--  Project: coyote
--  For revision history, see the project version-control log.
with LLM.Providers.OpenAI_Responses;
with LLM.Types;

package LLM.Providers.OpenRouter is

   type Provider is new LLM.Providers.OpenAI_Responses.Provider with private;

   --  Construct an OpenRouter provider.
   --
   --  Api_Key may be empty when OPENROUTER_API_KEY or the coyote models.json
   --  configuration supplies the key at send time.
   function Create (Api_Key : String := "") return Provider;

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

   type Provider is new LLM.Providers.OpenAI_Responses.Provider with null record;

end LLM.Providers.OpenRouter;
