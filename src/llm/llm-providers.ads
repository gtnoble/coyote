--  LLM.Providers — abstract provider interface for native LLM backends.
--
--  Defines the common streaming Send entry point implemented by concrete
--  provider adapters such as OpenAI Chat Completions and Anthropic
--  Messages.
--
--  Project: pi_acme
--  For revision history, see the project version-control log.

with LLM.Events;
with LLM.Types;

package LLM.Providers is

   --  Callback invoked for each streamed provider event.
   type Event_Handler is access procedure
     (E : LLM.Events.Agent_Event'Class);

   --  Requested reasoning or thinking budget level.
   type Thinking_Level is (Off, Minimal, Low, Medium, High, X_High);

   --  Abstract base for all concrete LLM API providers.
   type Provider is abstract tagged limited null record;

   --  Send a request and stream events to Handler.
   --
   --  Messages contains the full conversation so far.
   --  System_Prompt may be empty.
   --  Tools_Json is the JSON array string of tool definitions and may be
   --  "[]".
   --  Thinking selects the requested extended-reasoning level.
   --  Model_Id is the provider-specific model identifier.
   --  Max_Tokens limits output tokens for the response.
   procedure Send
     (P             : in out Provider;
      Model_Id      :        String;
      System_Prompt :        String;
      Messages      :        LLM.Types.Message_Vectors.Vector;
      Tools_Json    :        String;
      Thinking      :        Thinking_Level;
      Max_Tokens    :        Positive;
      Handler       :        Event_Handler)
   is abstract;

end LLM.Providers;
