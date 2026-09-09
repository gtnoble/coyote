--  LLM.Providers.Codex body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with LLM.Auth;
with LLM.Auth.Codex;
with LLM.Providers.OpenAI_Responses;

package body LLM.Providers.Codex is

   function Base_Url return String is
   begin
      if Ada.Environment_Variables.Exists ("COYOTE_CODEX_BASE_URL") then
         declare
            Value : constant String :=
              Ada.Environment_Variables.Value ("COYOTE_CODEX_BASE_URL");
         begin
            if Value'Length > 0 then
               return Value;
            end if;
         end;
      end if;
      return Default_Base_Url;
   end Base_Url;

   --  Clamp the session id to 64 characters for prompt_cache_key.
   function Clamped_Session_Key (Session_Id : String) return String is
   begin
      if Session_Id'Length <= 64 then
         return Session_Id;
      end if;
      return Session_Id (Session_Id'First .. Session_Id'First + 63);
   end Clamped_Session_Key;

   function Create (Session_Id : String := "") return Provider is
   begin
      return Result : Provider do
         Result.Session_Id :=
           Ada.Strings.Unbounded.To_Unbounded_String (Session_Id);
      end return;
   end Create;

   overriding procedure Send
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
      Session_Id : constant String := To_String (P.Session_Id);
      Creds      : LLM.Auth.Provider_Credentials           :=
        LLM.Auth.Load_Credentials ("codex");
      --  The Codex backend serves the Responses API under
      --  /codex/responses, so the delegate base URL carries the
      --  /codex prefix.
      Delegate   : LLM.Providers.OpenAI_Responses.Provider :=
        LLM.Providers.OpenAI_Responses.Create
          (Base_Url => Base_Url & "/codex",
           Api_Key  => To_String (Creds.Access_Token));

      procedure Configure_Delegate is
      begin
         --  Authorization and Content-Type headers are added by
         --  Send_Request itself; everything here is Codex-specific.
         LLM.Providers.OpenAI_Responses.Add_Header
           (P     => Delegate,
            Name  => "chatgpt-account-id",
            Value => To_String (Creds.Account_Id));
         LLM.Providers.OpenAI_Responses.Add_Header
           (P => Delegate, Name => "originator", Value => "coyote");
         LLM.Providers.OpenAI_Responses.Add_Header
           (P => Delegate, Name => "User-Agent", Value => "coyote/0.1.0-dev");
         LLM.Providers.OpenAI_Responses.Add_Header
           (P     => Delegate,
            Name  => "OpenAI-Beta",
            Value => "responses=experimental");
         LLM.Providers.OpenAI_Responses.Add_Header
           (P => Delegate, Name => "accept", Value => "text/event-stream");
         if Session_Id'Length > 0 then
            LLM.Providers.OpenAI_Responses.Add_Header
              (P => Delegate, Name => "session-id", Value => Session_Id);
            LLM.Providers.OpenAI_Responses.Add_Header
              (P     => Delegate,
               Name  => "x-client-request-id",
               Value => Session_Id);
         end if;
         LLM.Providers.OpenAI_Responses.Set_Inline_Cache_Hints
           (Delegate, False);
         LLM.Providers.OpenAI_Responses.Set_Omit_Max_Tokens (Delegate, True);
         --  The Codex backend requires store to be false and rejects
         --  requests that omit the field.
         LLM.Providers.OpenAI_Responses.Set_Store_Enabled (Delegate, False);
         if Session_Id'Length > 0 then
            LLM.Providers.OpenAI_Responses.Set_Prompt_Cache_Key
              (Delegate, Clamped_Session_Key (Session_Id));
         end if;
      end Configure_Delegate;
   begin
      if Length (Creds.Refresh_Token) = 0
        and then Length (Creds.Access_Token) = 0
      then
         raise LLM.Auth.Codex.Auth_Error
           with "OpenAI Codex subscription is not configured; "
           & "log in via Options > Subscriptions";
      end if;

      LLM.Auth.Codex.Ensure_Valid (Creds);

      if Length (Creds.Account_Id) = 0 then
         raise LLM.Auth.Codex.Auth_Error
           with "OpenAI Codex access token does not carry a "
           & "chatgpt_account_id claim; log in again via "
           & "Options > Subscriptions";
      end if;

      Configure_Delegate;

      LLM.Providers.OpenAI_Responses.Send_Request
        (P             => Delegate,
         Model_Id      => Model_Id,
         System_Prompt => System_Prompt,
         Messages      => Messages,
         Tools_Json    => Tools_Json,
         Thinking      => Thinking,
         Max_Tokens    => Max_Tokens,
         Handler       => Handler,
         Abort_Check   => Abort_Check);
   exception
      when E : LLM.Auth.Codex.Auth_Error =>
         --  Surface authentication failures as provider errors instead of
         --  transport exceptions so retry policy does not retry them.
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "[!] OpenAI Codex authentication failed: "
            & Ada.Exceptions.Exception_Message (E));
         raise Constraint_Error
           with "OpenAI Codex authentication failed: "
           & Ada.Exceptions.Exception_Message (E);
   end Send;

end LLM.Providers.Codex;
