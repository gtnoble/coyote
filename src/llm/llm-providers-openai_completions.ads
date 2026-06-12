--  LLM.Providers.OpenAI_Completions — OpenAI chat-completions adapter.
--
--  Implements the base OpenAI `/chat/completions` wire format used by
--  OpenRouter and GitHub Copilot models that do not use the Anthropic
--  Messages endpoint.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with GNATCOLL.JSON;
with LLM.Providers;
with LLM.Types;

package LLM.Providers.OpenAI_Completions is

   type Provider is new LLM.Providers.Provider with private;

   --  Construct a provider with Base_Url and Api_Key.
   --
   --  Requests are sent to Base_Url & "/chat/completions" using bearer
   --  authentication.
   function Create
      (Base_Url : String;
     Api_Key  : String) return Provider;

   --  Replace the configured base URL.
   procedure Set_Base_Url
      (P        : in out Provider;
     Base_Url :        String);

   --  Return the configured base URL.
   function Get_Base_Url (P : Provider) return String;

   --  Replace the configured bearer token.
   procedure Set_Api_Key
      (P       : in out Provider;
     Api_Key :        String);

   --  Return the configured bearer token.
   function Get_Api_Key (P : Provider) return String;

   --  Add one extra HTTP request header.
   --
   --  This is used for provider-specific extensions such as Copilot's
   --  editor headers or OpenRouter metadata headers.
   procedure Add_Header
      (P     : in out Provider;
     Name  :        String;
     Value :        String);

   --  Inject standard reasoning-effort configuration into the request.
   --
   --  Maps Thinking_Level to the OpenAI reasoning.effort field ("low",
   --  "medium", "high").  When Thinking is Off this is a no-op.
   --  Descendants may override to add provider-specific logic.
   procedure Customize_Request
      (P        : in out Provider;
     Model_Id :        String;
     Thinking :        LLM.Providers.Thinking_Level;
     Request  :        GNATCOLL.JSON.JSON_Value);

   --  Internal helper used by derived providers after they resolve any
   --  provider-specific configuration. Dispatching on Customize_Request is
   --  preserved when P is a descendant object.
   procedure Send_Request
      (P             : in out Provider'Class;
     Model_Id      :        String;
     System_Prompt :        String;
     Messages      :        LLM.Types.Message_Vectors.Vector;
     Tools_Json    :        String;
     Thinking      :        LLM.Providers.Thinking_Level;
     Max_Tokens    :        Positive;
     Handler       :        LLM.Providers.Event_Handler);

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
      Use_Streaming : Boolean := True;
   end record;

end LLM.Providers.OpenAI_Completions;
