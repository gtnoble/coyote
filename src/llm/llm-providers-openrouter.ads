--  LLM.Providers.OpenRouter — OpenRouter chat-completions adapter.
--
--  Extends the base OpenAI chat-completions provider with OpenRouter's
--  default base URL, metadata headers, API-key resolution, and optional
--  reasoning-effort request field.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with GNATCOLL.JSON;
with LLM.Providers;
with LLM.Providers.OpenAI_Completions;
with LLM.Types;

package LLM.Providers.OpenRouter is

   type Provider is new LLM.Providers.OpenAI_Completions.Provider with private;

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

   type Provider is new LLM.Providers.OpenAI_Completions.Provider with null record;

   overriding
   procedure Customize_Request
      (P        : in out Provider;
     Model_Id :        String;
     Thinking :        LLM.Providers.Thinking_Level;
     Request  :        GNATCOLL.JSON.JSON_Value);

end LLM.Providers.OpenRouter;
