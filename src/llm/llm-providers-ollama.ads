--  LLM.Providers.Ollama — Ollama native chat API adapter.
--
--  Implements the Ollama POST /api/chat wire format with newline-delimited
--  JSON (NDJSON) streaming.  Supports both the Ollama Cloud endpoint
--  (https://ollama.com) and locally-running Ollama instances (default
--  http://localhost:11434).
--
--  Authentication uses a bearer token resolved from OLLAMA_API_KEY or
--  providers.ollama.apiKey in ~/.coyote/models.json.  When no key is
--  configured and the effective base URL is a localhost address, the
--  Authorization header is omitted.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;
with LLM.Providers;
with LLM.Types;

package LLM.Providers.Ollama is

   type Provider is new LLM.Providers.Provider with private;

   --  Construct an Ollama provider.
   --
   --  Base_Url selects the API endpoint root:
   --    ""                     -> resolved at Send time from models.json,
   --                              then defaults to https://ollama.com.
   --    "https://ollama.com"   -> Ollama Cloud.
   --    "http://localhost:N"   -> locally-running Ollama instance.
   --
   --  Api_Key may be empty; when empty it is resolved at Send time from
   --  models.json / OLLAMA_API_KEY.  For localhost base URLs the key is
   --  optional and the Authorization header is omitted when absent.
   function Create
      (Base_Url : String := "";
       Api_Key  : String := "") return Provider;

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

   type Provider is new LLM.Providers.Provider with record
      Base_Url : Ada.Strings.Unbounded.Unbounded_String;
      Api_Key  : Ada.Strings.Unbounded.Unbounded_String;
   end record;

end LLM.Providers.Ollama;
