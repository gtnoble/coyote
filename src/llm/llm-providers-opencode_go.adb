--  LLM.Providers.OpenCode_Go body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Environment_Variables;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with LLM.HTTP;
with LLM.Providers.Anthropic_Messages;
with LLM.Providers.OpenAI_Completions;
with LLM.Providers.OpenAI_Responses;
with LLM.Providers.OpenCode_Go.Catalogue;
use type LLM.Providers.OpenCode_Go.Catalogue.Wire_Kind;
with LLM.Settings;

package body LLM.Providers.OpenCode_Go is

   function Default_Base_Url return String is
   begin
      if Ada.Environment_Variables.Exists ("COYOTE_OPENCODE_GO_BASE_URL") then
         declare
            Value : constant String :=
              Ada.Environment_Variables.Value
                ("COYOTE_OPENCODE_GO_BASE_URL");
         begin
            if Value'Length > 0 then
               return Value;
            end if;
         end;
      end if;
      return "https://opencode.ai/zen/go";
   end Default_Base_Url;

   function Resolve_Api_Key return String is
      Env_Key : constant String := "OPENCODE_API_KEY";
   begin
      if Ada.Environment_Variables.Exists (Env_Key) then
         declare
            Value : constant String :=
              Ada.Environment_Variables.Value (Env_Key);
         begin
            if Value'Length > 0 then
               return Value;
            end if;
         end;
      end if;
      return LLM.Settings.Resolve_Api_Key ("opencode-go");
   end Resolve_Api_Key;

   function Create return Provider is
   begin
      return Result : Provider do
         null;
      end return;
   end Create;

   overriding
   procedure Send
     (P             : in out Provider;
      Model_Id      :        String;
      System_Prompt :        String;
      Messages      :        LLM.Types.Message_Vectors.Vector;
      Tools_Json    :        String;
      Thinking      :        LLM.Providers.Thinking_Level;
      Max_Tokens    :        Positive;
      Handler       :        LLM.Providers.Event_Handler;
      Abort_Check   :        LLM.Providers.Abort_Callback := null)
   is
      pragma Unreferenced (P);

      Api_Key  : constant String := Resolve_Api_Key;
      Base_Url : constant String := Default_Base_Url;
      Wire     : constant LLM.Providers.OpenCode_Go.Catalogue.Wire_Kind :=
        LLM.Providers.OpenCode_Go.Catalogue.Wire_Format_For (Model_Id);
   begin
      if Api_Key'Length = 0 then
         raise LLM.HTTP.Curl_Error with
           "OpenCode Go API key is not configured; "
           & "set OPENCODE_API_KEY or configure "
           & "providers.opencode-go.apiKey";
      end if;

      if Wire = LLM.Providers.OpenCode_Go.Catalogue.Anthropic_Messages_Wire
      then
         declare
            Delegate : LLM.Providers.Anthropic_Messages.Provider :=
              LLM.Providers.Anthropic_Messages.Create
                (Base_Url => Base_Url,
                 Api_Key  => Api_Key);
         begin
            --  The Anthropic_Messages provider uses Bearer auth for
            --  non-anthropic.com base URLs, which is correct for OpenCode Go.
            Delegate.Send
              (Model_Id      => Model_Id,
               System_Prompt => System_Prompt,
               Messages      => Messages,
               Tools_Json    => Tools_Json,
               Thinking      => Thinking,
               Max_Tokens    => Max_Tokens,
               Handler       => Handler,
               Abort_Check  => Abort_Check);
         end;
      elsif Wire = LLM.Providers.OpenCode_Go.Catalogue.OpenAI_Responses_Wire
      then
         declare
            V1_Base : constant String :=
              (if Base_Url'Length > 0
                    and then Base_Url (Base_Url'Last) = '/'
               then Base_Url & "v1"
               else Base_Url & "/v1");
            Delegate : LLM.Providers.OpenAI_Responses.Provider :=
              LLM.Providers.OpenAI_Responses.Create
                (Base_Url => V1_Base,
                 Api_Key  => Api_Key);
         begin
            LLM.Providers.OpenAI_Responses.Set_Inline_Cache_Hints
              (Delegate, False);
            LLM.Providers.OpenAI_Responses.Send_Request
              (P             => Delegate,
               Model_Id      => Model_Id,
               System_Prompt => System_Prompt,
               Messages      => Messages,
               Tools_Json    => Tools_Json,
               Thinking      => Thinking,
               Max_Tokens    => Max_Tokens,
               Handler       => Handler,
               Abort_Check  => Abort_Check);
         end;
      else
         declare
            --  OpenCode Go's OpenAI-compatible endpoint lives under
            --  /v1/chat/completions, so the base URL passed to the
            --  delegate must include the /v1 prefix.
            V1_Base : constant String :=
              (if Base_Url'Length > 0
                    and then Base_Url (Base_Url'Last) = '/'
               then Base_Url & "v1"
               else Base_Url & "/v1");
            Delegate : LLM.Providers.OpenAI_Completions.Provider :=
              LLM.Providers.OpenAI_Completions.Create
                (Base_Url => V1_Base,
                 Api_Key  => Api_Key);
         begin
            LLM.Providers.OpenAI_Completions.Set_Inline_Cache_Hints
              (Delegate, False);
            LLM.Providers.OpenAI_Completions.Send_Request
              (P             => Delegate,
               Model_Id      => Model_Id,
               System_Prompt => System_Prompt,
               Messages      => Messages,
               Tools_Json    => Tools_Json,
               Thinking      => Thinking,
               Max_Tokens    => Max_Tokens,
               Handler       => Handler,
               Abort_Check  => Abort_Check);
         end;
      end if;
   end Send;

end LLM.Providers.OpenCode_Go;