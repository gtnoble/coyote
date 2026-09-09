--  LLM.Providers.Codex -- OpenAI Codex subscription provider adapter.
--
--  Routes requests to the ChatGPT backend Codex Responses endpoint using
--  OAuth subscription credentials from ~/.coyote/auth.json.  The wire
--  format is the OpenAI Responses API; this provider adds the
--  subscription-specific headers (chatgpt-account-id, originator,
--  session-id), forces store:false semantics, and clamps the
--  prompt-cache key to the Codex session identifier.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;
with LLM.Providers;
with LLM.Types;

package LLM.Providers.Codex is

   --  Default Codex backend endpoint prefix.
   Default_Base_Url : constant String := "https://chatgpt.com/backend-api";

   type Provider is new LLM.Providers.Provider with private;

   --  Construct a Codex provider.  Session_Id is the stable conversation
   --  identifier sent as session-id / x-client-request-id headers and as
   --  the prompt_cache_key body field (clamped to 64 characters).
   function Create (Session_Id : String := "") return Provider;

   overriding procedure Send
     (P             : in out Provider;
      Model_Id      :        String;
      System_Prompt :        String;
      Messages      :        LLM.Types.Message_Vectors.Vector;
      Tools_Json    :        String;
      Thinking      :        LLM.Providers.Thinking_Level;
      Max_Tokens    :        Positive;
      Handler       :        LLM.Providers.Event_Handler;
      Abort_Check   :        LLM.Providers.Abort_Callback := null);

private

   type Provider is new LLM.Providers.Provider with record
      Session_Id : Ada.Strings.Unbounded.Unbounded_String;
   end record;

end LLM.Providers.Codex;
