--  LLM.Providers.Anthropic_Messages -- Anthropic Messages adapter.
--
--  Implements the Anthropic `/v1/messages` wire format used by GitHub
--  Copilot Claude models and, later, direct Anthropic access.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with LLM.Providers;
with LLM.Types;

package LLM.Providers.Anthropic_Messages is

   type Provider is new LLM.Providers.Provider with private;

   --  Construct a provider with Base_Url and Api_Key.
   --
   --  Requests are sent to Base_Url & "/v1/messages". For GitHub Copilot
   --  this uses bearer authentication; direct Anthropic endpoints may use
   --  x-api-key based on the configured base URL.
   function Create
      (Base_Url : String;
     Api_Key  : String) return Provider;

   --  Add one extra HTTP request header.
   --
   --  This is used for provider-specific extensions such as GitHub Copilot's
   --  editor headers and X-Initiator routing hint.
   procedure Add_Header
      (P     : in out Provider;
     Name  :        String;
     Value :        String);

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

   type Header_Entry is record
      Name  : Ada.Strings.Unbounded.Unbounded_String;
      Value : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   package Header_Entry_Vectors is new Ada.Containers.Vectors
      (Index_Type   => Positive,
     Element_Type => Header_Entry);

   type Provider is new LLM.Providers.Provider with record
      Base_Url      : Ada.Strings.Unbounded.Unbounded_String;
      Api_Key       : Ada.Strings.Unbounded.Unbounded_String;
      Extra_Headers : Header_Entry_Vectors.Vector;
   end record;

end LLM.Providers.Anthropic_Messages;
