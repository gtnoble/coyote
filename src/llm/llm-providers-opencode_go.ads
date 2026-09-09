--  LLM.Providers.OpenCode_Go — OpenCode Go provider adapter.
--
--  Routes requests to either the OpenAI chat-completions or Anthropic
--  messages wire format depending on the model, using the OpenCode Go
--  API endpoint at https://opencode.ai/zen/go.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;
with LLM.Providers;
with LLM.Types;

package LLM.Providers.OpenCode_Go is

   type Provider is new LLM.Providers.Provider with record
      Session_Id : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   --  Construct an OpenCode Go provider.
   --
   --  Session_Id is the stable conversation identifier sent as the
   --  x-opencode-session HTTP header on every request.  OpenCode Go
   --  rejects requests without it (HTTP 400 MissingSessionID).
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

end LLM.Providers.OpenCode_Go;
